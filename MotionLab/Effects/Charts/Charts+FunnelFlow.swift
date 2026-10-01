import SwiftUI

extension Effect {
    static let chartsFunnelFlow = Effect(
        id: "charts.funnel-flow",
        category: .charts,
        interaction: .tap,
        name: L("Funnel Particle Flow", "漏斗粒子流"),
        summary: L("Funnel stages fill top to bottom while particles stream through; the ones the walls squeeze out drift away, and the rates count up.", "漏斗各阶段自上而下填充，粒子从中流过；被收窄的漏斗壁挤出的粒子飘散，转化率同步计数。"),
        prompt: L(
            "A conversion funnel of four stacked stages (Visits, Sign-ups, Trials, Paid) with smoothly curved walls, each band 42 pt tall and coloured indigo → violet → pink → coral, beside rolling counts and percentage chips. On appear the stages fill in sequence, 0.4 s apart: each band wipes downward from its top edge on a spring (response 0.6 s, damping 0.86) and its figures count up from zero with it. A steady stream of 70 small white particles falls through the funnel in straight lanes, only as deep as the fill has reached; where the walls narrow, the outer lanes hit the wall, drift 14 pt sideways and fade, so the surviving density visibly matches each stage's rate. Tapping replays the fill with a soft haptic per stage. Explanatory, lively and honest about loss.",
            "四个阶段上下堆叠的转化漏斗（访问、注册、试用、付费），漏斗壁为平滑曲线，每段高 42pt，颜色依次为靛蓝 → 紫 → 粉 → 珊瑚，右侧是滚动的数量与百分比标签。出现时各阶段依次填充，间隔 0.4 秒：每段从上沿向下以弹簧（响应 0.6 秒、阻尼 0.86）擦出，旁边的数字随之从零计数。70 个白色小粒子沿直线通道持续落入漏斗，只流到已填充的深度；漏斗壁收窄处，外侧粒子撞壁后横向飘出 14pt 并淡出，留存的密度恰好对应各阶段转化率。点击重播，每阶段一次轻触感。直观、生动，如实呈现流失。"
        ),
        implementation: L(
            "Fill progress lives in a ChartVector animated stage by stage from a Task; an Animatable view inside a TimelineView draws the bands and the particles in one Canvas. Each particle is a closed-form function of time and its lane, with the wall-hit depth precomputed, so no simulation state is kept.",
            "填充进度保存在 ChartVector 中，由 Task 逐阶段驱动；TimelineView 内的 Animatable 视图在同一个 Canvas 中绘制色带与粒子。每个粒子都是时间与所在通道的闭式函数，撞壁深度预先算好，无需保存任何模拟状态。"
        ),
        apis: ["TimelineView", "Canvas", "Animatable", "VectorArithmetic", "Task.sleep", "spring(response:dampingFraction:)"],
        tags: ["funnel", "conversion", "particles", "flow", "漏斗图", "转化率", "粒子", "流失"],
        params: [
            .slider("flow", L("Flow speed", "流速"), 0.3...2.0, default: 1.0),
            .slider("count", L("Particles", "粒子数量"), 20...120, default: 70, step: 1, decimals: 0),
            .slider("stagger", L("Stage interval", "阶段间隔"), 0.15...0.8, default: 0.4, unit: "s"),
        ]
    ) { ctx in
        FunnelFlowDemo(ctx: ctx)
    }
}

private struct FunnelStage {
    let name: LocalizedText
    let count: Double
    let colors: [Color]
}

private let funnelStages: [FunnelStage] = [
    FunnelStage(name: L("Visits", "访问"), count: 12_400, colors: [Palette.indigo, Color(hex: 0x7F74FF)]),
    FunnelStage(name: L("Sign-ups", "注册"), count: 7_690, colors: [Color(hex: 0x8A6FFF), Palette.violet]),
    FunnelStage(name: L("Trials", "试用"), count: 4_710, colors: [Color(hex: 0xC566E8), Palette.pink]),
    FunnelStage(name: L("Paid", "付费"), count: 2_600, colors: [Color(hex: 0xFF6A8E), Palette.coral]),
]

private enum FunnelGeometry {
    static let band: CGFloat = 42
    static let gap: CGFloat = 2
    static let topWidth: CGFloat = 156
    static var height: CGFloat { CGFloat(funnelStages.count) * band + CGFloat(funnelStages.count - 1) * gap }

    static func rate(_ stage: Int) -> Double {
        guard funnelStages.indices.contains(stage) else { return (funnelStages.last?.count ?? 0) / funnelStages[0].count * 0.78 }
        return funnelStages[stage].count / funnelStages[0].count
    }

    static func top(_ stage: Int) -> CGFloat { CGFloat(stage) * (band + gap) }

    /// Half width of the funnel at depth `y` (walls ease between a stage's rate and the next one's).
    static func halfWidth(at y: CGFloat) -> CGFloat {
        let pitch = band + gap
        let stage = min(max(Int(y / pitch), 0), funnelStages.count - 1)
        let local = min(max((y - CGFloat(stage) * pitch) / band, 0), 1)
        let eased = local * local * (3 - 2 * local)
        let from = rate(stage)
        let to = rate(stage + 1)
        return topWidth / 2 * CGFloat(from + (to - from) * Double(eased))
    }

    /// Depth at which a lane (half-width fraction `m`) meets the wall, or nil if it survives.
    static func hitDepth(lane m: Double) -> CGFloat? {
        let laneX = CGFloat(m) * topWidth / 2
        var y: CGFloat = 0
        while y <= height {
            if halfWidth(at: y) < laneX { return y }
            y += 1.5
        }
        return nil
    }
}

private struct FunnelParticle {
    let lane: Double
    let side: Double
    let phase: Double
    let speed: Double
    let hit: CGFloat?
}

private let funnelParticles: [FunnelParticle] = (0..<120).map { index in
    // Golden-ratio scrambling: lanes cover the width evenly for any prefix of the array.
    let lane = (Double(index) * 0.6180339887).truncatingRemainder(dividingBy: 1)
    let phase = (Double(index) * 0.7548776662).truncatingRemainder(dividingBy: 1)
    let jitter = (Double(index) * 0.5698402910).truncatingRemainder(dividingBy: 1)
    let m = 0.04 + lane * 0.92
    return FunnelParticle(lane: m, side: index % 2 == 0 ? 1 : -1, phase: phase, speed: 0.85 + 0.3 * jitter, hit: FunnelGeometry.hitDepth(lane: m))
}

private struct FunnelFlowDemo: View {
    let ctx: DemoContext
    @State private var fill = ChartVector(repeating: 1, count: funnelStages.count)
    @State private var run: Task<Void, Never>?

    var body: some View {
        let flow = ctx["flow"]
        let count = ctx.int("count")
        ChartStage(hint: L("Tap to replay the funnel", "点击重播漏斗"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(ctx.language == .zh ? "转化漏斗 · 近 30 天" : "Conversion · last 30 days")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    ChartRollText(value: FunnelGeometry.rate(funnelStages.count - 1) * 100 * fill[funnelStages.count - 1]) { String(format: "%.0f%%", $0) }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.coral)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Palette.coral.opacity(0.14), in: Capsule())
                }
                TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                    FunnelPlot(
                        fill: fill,
                        time: ctx.isStill ? 4.2 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600),
                        flow: flow,
                        particles: count,
                        language: ctx.language
                    )
                }
                .frame(height: FunnelGeometry.height)
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap(.light)
                replay()
            }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                fill = ChartVector(repeating: 0, count: funnelStages.count)
            }, then: { pour() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 4.6, delay: 4.2, intro: false) { replay() }
    }

    /// Tap and autoplay: drain, then fill stage by stage again.
    private func replay() {
        run?.cancel()
        withAnimation(.easeIn(duration: 0.22)) {
            fill = ChartVector(repeating: 0, count: funnelStages.count)
        }
        pour(after: 0.3)
    }

    private func pour(after delay: Double = 0) {
        run?.cancel()
        let silent = ctx.isPreview
        run = chartSequence(steps: funnelStages.count, gap: ctx["stagger"], first: delay) { stage in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { fill[stage] = 1 }
            if !silent { Haptics.tap(.soft) }
        }
    }
}

private struct FunnelPlot: View, Animatable {
    var fill: ChartVector
    let time: Double
    let flow: Double
    let particles: Int
    let language: AppLanguage

    var animatableData: ChartVector {
        get { fill }
        set { fill = newValue }
    }

    var body: some View {
        HStack(spacing: 14) {
            funnel
                .frame(width: FunnelGeometry.topWidth + 32, height: FunnelGeometry.height)
            VStack(alignment: .leading, spacing: FunnelGeometry.gap) {
                ForEach(funnelStages.indices, id: \.self) { stage in
                    row(stage)
                        .frame(height: FunnelGeometry.band)
                }
            }
        }
    }

    private func row(_ stage: Int) -> some View {
        let progress = min(max(fill[stage], 0), 1)
        let count = funnelStages[stage].count * progress
        let percent = FunnelGeometry.rate(stage) * 100 * progress
        return VStack(alignment: .leading, spacing: 1) {
            Text(funnelStages[stage].name, language)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: Int(count.rounded()).formatted(.number.locale(language.locale)))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(verbatim: "\(Int(percent.rounded()))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(funnelStages[stage].colors[1])
        }
        .opacity(0.35 + 0.65 * progress)
        .lineLimit(1)
        .fixedSize()
    }

    private static func bandPath(stage: Int, centerX: CGFloat, depth: CGFloat) -> Path {
        let top = FunnelGeometry.top(stage)
        let bottom = top + min(max(depth, 0), FunnelGeometry.band)
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        var y = top
        while y < bottom {
            let half = FunnelGeometry.halfWidth(at: y)
            left.append(CGPoint(x: centerX - half, y: y))
            right.append(CGPoint(x: centerX + half, y: y))
            y += 3
        }
        let half = FunnelGeometry.halfWidth(at: min(bottom, top + FunnelGeometry.band - 0.01))
        left.append(CGPoint(x: centerX - half, y: bottom))
        right.append(CGPoint(x: centerX + half, y: bottom))
        var path = Path()
        path.addLines(left)
        for point in right.reversed() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private var funnel: some View {
        let progress = fill
        let now = time
        let speed = flow
        let active = min(max(particles, 0), funnelParticles.count)
        return Canvas { context, size in
            let centerX = size.width / 2
            // How deep the fill has reached: particles only travel that far.
            var front: CGFloat = 0
            for stage in funnelStages.indices {
                let p = CGFloat(min(max(progress[stage], 0), 1))
                front = max(front, p > 0.001 ? FunnelGeometry.top(stage) + FunnelGeometry.band * p : 0)
            }

            for stage in funnelStages.indices {
                let track = Self.bandPath(stage: stage, centerX: centerX, depth: FunnelGeometry.band)
                context.fill(track, with: .color(.primary.opacity(0.06)))
                let p = CGFloat(min(max(progress[stage], 0), 1.05))
                guard p > 0.002 else { continue }
                let band = Self.bandPath(stage: stage, centerX: centerX, depth: FunnelGeometry.band * p)
                let top = FunnelGeometry.top(stage)
                context.fill(
                    band,
                    with: .linearGradient(
                        Gradient(colors: funnelStages[stage].colors),
                        startPoint: CGPoint(x: centerX, y: top),
                        endPoint: CGPoint(x: centerX, y: top + FunnelGeometry.band)
                    )
                )
            }

            let travel = FunnelGeometry.height + 24
            for index in 0..<active {
                let particle = funnelParticles[index]
                let cycle = (now * 0.3 * speed * particle.speed + particle.phase).truncatingRemainder(dividingBy: 1)
                let depth = CGFloat(cycle) * travel - 12
                let laneX = CGFloat(particle.lane * particle.side) * FunnelGeometry.topWidth / 2
                var x = centerX + laneX
                var y = depth
                var alpha = 0.9
                // Inside the funnel a particle is white; once squeezed out it takes its stage's colour so it
                // stays visible on the card in light mode.
                var tint = Color.white
                if let hit = particle.hit, depth > hit {
                    let stage = min(max(Int(hit / (FunnelGeometry.band + FunnelGeometry.gap)), 0), funnelStages.count - 1)
                    tint = funnelStages[stage].colors[1]
                    let escape = Double((depth - hit) / 26)
                    guard escape < 1 else { continue }
                    x += CGFloat(particle.side) * 14 * CGFloat(escape)
                    y = hit + (depth - hit) * 0.35
                    alpha *= 1 - escape
                }
                // Fade in at the mouth, out at the fill front and at the bottom.
                alpha *= ChartKit.smoothstep(-12, 2, Double(depth))
                alpha *= 1 - ChartKit.smoothstep(Double(front) - 10, Double(front) + 4, Double(y))
                guard alpha > 0.02 else { continue }
                let radius: CGFloat = 1.7
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(tint.opacity(alpha)))
            }
        }
    }
}
