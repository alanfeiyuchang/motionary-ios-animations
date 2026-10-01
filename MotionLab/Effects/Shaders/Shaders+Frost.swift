import SwiftUI

extension Effect {
    static let shaderFrostGrow = Effect(
        id: "shader.frost-grow",
        category: .shaders,
        interaction: .gesture,
        name: L("Growing Frost", "霜花蔓延"),
        summary: L(
            "Ice crystals creep over a window from its edges; wipe with a finger to melt a path that slowly refreezes.",
            "冰晶从窗玻璃四周向内蔓延；用手指擦出一道融化的痕迹，它会慢慢重新结霜。"
        ),
        prompt: L(
            "A night window showing city bokeh frosts over. Ice advances from all four edges over 3.5 s until it has crept about 60% of the way to the middle, leaving a clear window there, led by feathers of ice — spines with slanted barbs — in three orientations 60° apart. Frosted glass refracts what is behind it by up to 7 pt along the crystal grain, blurs it, hazes it toward icy white and twinkles on the ridges. Wiping a finger melts a clear path about 70 pt wide with a bright water rim; each touched spot refreezes over 3.5 s, the crystals growing back in from its border, so a stroke closes tail-first. A soft haptic marks the first contact. Cold, quiet and tactile.",
            "一扇映着城市光斑的夜窗渐渐结霜。冰从四条边向内推进，用 3.5 秒爬到通往中央约 60% 的位置，中间留出一块透亮的窗；走在最前面的是羽毛状的冰花——主脉两侧斜生细枝——朝向相隔 60° 的三个方向。结霜的玻璃沿晶体纹理把后方景物折射最多 7pt，使其模糊、泛出冰白色的雾感，并在晶脊上闪烁微光。手指擦过会融出一道宽约 70pt 的清晰通道，边缘带一圈明亮的水痕；每个被触碰的位置在 3.5 秒内重新冻结，冰晶从通道边缘向内长回，于是一笔擦痕总是从尾部先合拢。初次接触时有一次轻柔的触感。清冷而安静。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader thresholds grow − edge distance + a procedural feather pattern − melt, then refracts along the crystal gradient, blurs with five taps and adds haze and sparkle; the melt field is ten Gaussian points (position + life) fed from a ring buffer that the drag fills and a TimelineView ages.",
            "[[stitchable]] layerEffect 着色器对“生长量 − 到边缘的距离 + 程序化羽状冰花 − 融化量”取阈值，再沿晶体梯度折射、五点采样模糊，并叠加雾感与闪光；融化场由十个高斯点（位置 + 寿命）构成，来自拖动写入、TimelineView 逐帧老化的环形缓冲。"
        ),
        apis: ["layerEffect", "TimelineView", "DragGesture", "Shader.Argument.float3", "Metal"],
        tags: ["frost", "ice", "freeze", "window", "crystal", "结霜", "冰晶", "冻结", "玻璃"],
        params: [
            .slider("coverage", L("Coverage", "覆盖范围"), 0.3...1, default: 0.6),
            .slider("growTime", L("Growth time", "生长时间"), 1...8, default: 3.5, decimals: 1, unit: "s"),
            .slider("refreeze", L("Refreeze time", "回冻时间"), 1...8, default: 3.5, decimals: 1, unit: "s"),
            .slider("refraction", L("Refraction", "折射"), 0...14, default: 7, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        FrostDemo(ctx: ctx)
    }
}

private struct MeltPoint {
    var position: CGPoint
    var time: Double
}

private struct FrostState {
    let time: Double
    let grow: Double
    /// Always ten entries: x, y, life.
    let points: [(Float, Float, Float)]
}

private final class FrostModel {
    static let capacity = 10
    static let radius: Double = 34

    let clock = BackgroundClock(start: 0)
    private var grow: Double = 0
    private var points: [MeltPoint] = []
    private var anchor = CGPoint.zero
    /// A scripted wipe (autoplay / intro): the simulated finger travels `from` → `to` through `add`.
    private var wipe: (start: Double, from: CGPoint, to: CGPoint)?

    func add(_ point: CGPoint, now: Double) {
        // The newest point is the moving head under the finger. Once it has travelled 20 pt from where it was
        // dropped it stays behind as part of the trail and a new head starts, so a stroke spends one slot per
        // 20 pt and holding still keeps reheating the same spot.
        if let last = points.indices.last, now - points[last].time < 0.3,
           hypot(anchor.x - point.x, anchor.y - point.y) < 20 {
            points[last].time = now
            points[last].position = point
            return
        }
        anchor = point
        points.append(MeltPoint(position: point, time: now))
        if points.count > Self.capacity { points.removeFirst(points.count - Self.capacity) }
    }

    func startWipe(from: CGPoint, to: CGPoint, now: Double) {
        wipe = (now, from, to)
    }

    func step(now: Double, coverage: Double, growTime: Double, refreeze: Double) -> FrostState {
        let time = clock.advance(to: now, speed: 1)
        // Constant-speed growth toward the chosen coverage (also retreats when the slider is lowered).
        let rate = clock.delta / max(growTime, 0.1) * max(coverage, 0.3)
        if grow < coverage { grow = min(coverage, grow + rate) } else { grow = max(coverage, grow - rate * 2) }
        if let script = wipe {
            let t = (now - script.start) / 1.1
            if t >= 1 {
                wipe = nil
            } else if t >= 0 {
                let e = t * t * (3 - 2 * t)
                let arc = sin(e * .pi) * 14
                add(CGPoint(x: script.from.x + (script.to.x - script.from.x) * e, y: script.from.y + (script.to.y - script.from.y) * e - arc), now: now)
            }
        }
        points.removeAll { now - $0.time > refreeze }
        return FrostState(time: time, grow: grow, points: packed(now: now, refreeze: refreeze))
    }

    /// A settled picture for stills: fully grown, with one wiped stroke.
    func still(coverage: Double) -> FrostState {
        let stroke: [(Float, Float, Float)] = (0..<Self.capacity).map { index in
            let t = Double(index) / Double(Self.capacity - 1)
            return (Float(34 + 180 * t), Float(246 + 22 * t - sin(t * .pi) * 14), Float(0.35 + 0.65 * t))
        }
        return FrostState(time: 1.2, grow: coverage, points: stroke)
    }

    private func packed(now: Double, refreeze: Double) -> [(Float, Float, Float)] {
        var out: [(Float, Float, Float)] = points.map { point in
            let life = max(0, 1 - (now - point.time) / max(refreeze, 0.1))
            return (Float(point.position.x), Float(point.position.y), Float(life))
        }
        while out.count < Self.capacity { out.append((0, 0, 0)) }
        return out
    }
}

private struct FrostDemo: View {
    let ctx: DemoContext
    @State private var model = FrostModel()
    @State private var flip = false

    var body: some View {
        let coverage = ctx["coverage"]
        let growTime = ctx["growTime"]
        let refreeze = ctx["refreeze"]
        let refraction = ctx["refraction"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let state = ctx.isStill
                    ? model.still(coverage: coverage)
                    : model.step(now: timeline.date.timeIntervalSinceReferenceDate, coverage: coverage, growTime: growTime, refreeze: refreeze)
                FrostSurface(state: state, refraction: refraction)
            }
            .shaderCard(glow: Color(hex: 0x3AC4FF, opacity: 0.28))
            .shaderTouch(
                onBegan: { _ in Haptics.tap(.soft) },
                onMoved: { point, _ in model.add(point, now: Date().timeIntervalSinceReferenceDate) },
                onTap: { point in
                    Haptics.tap(.soft)
                    model.add(point, now: Date().timeIntervalSinceReferenceDate)
                }
            )
            DemoHint(text: L("Wipe the glass with a finger", "用手指擦拭玻璃"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Waits for the frost to grow in before the first simulated wipe. The detail stage's arrival play is
        // the growth itself (it starts in the first frame), so no intro wipe on barely frosted glass.
        .autoplay(ctx.isPreview, every: 3.6, delay: 2.4, intro: false) { wipe() }
    }

    /// Simulated finger: an arcing stroke across the pane, alternating direction.
    private func wipe() {
        let now = Date().timeIntervalSinceReferenceDate
        if flip {
            model.startWipe(from: CGPoint(x: 236, y: 70), to: CGPoint(x: 30, y: 44), now: now)
        } else {
            model.startWipe(from: CGPoint(x: 26, y: 236), to: CGPoint(x: 232, y: 270), now: now)
        }
        flip.toggle()
    }
}

private struct FrostSurface: View {
    let state: FrostState
    let refraction: Double

    var body: some View {
        let m = state.points
        ShaderWindowScene()
            .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
            .layerEffect(
                ShaderLibrary.mlFrost(
                    .float2(ShaderKit.card),
                    .float(state.grow),
                    .float(refraction),
                    .float(state.time),
                    .float3(m[0].0, m[0].1, m[0].2),
                    .float3(m[1].0, m[1].1, m[1].2),
                    .float3(m[2].0, m[2].1, m[2].2),
                    .float3(m[3].0, m[3].1, m[3].2),
                    .float3(m[4].0, m[4].1, m[4].2),
                    .float3(m[5].0, m[5].1, m[5].2),
                    .float3(m[6].0, m[6].1, m[6].2),
                    .float3(m[7].0, m[7].1, m[7].2),
                    .float3(m[8].0, m[8].1, m[8].2),
                    .float3(m[9].0, m[9].1, m[9].2),
                    .float(FrostModel.radius)
                ),
                maxSampleOffset: CGSize(width: refraction * 1.6 + 5, height: refraction * 1.6 + 5)
            )
    }
}
