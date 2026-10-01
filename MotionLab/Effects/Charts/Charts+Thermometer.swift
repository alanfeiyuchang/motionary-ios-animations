import SwiftUI

extension Effect {
    static let chartsThermometer = Effect(
        id: "charts.thermometer",
        category: .charts,
        interaction: .tap,
        name: L("Goal Thermometer", "目标温度计"),
        summary: L("Each donation pushes the liquid up a glass tube with a slosh; milestones tick alight as it passes and the goal bursts.", "每一笔捐款把玻璃管里的液体推高并晃荡；经过的里程碑逐个点亮，达成目标时迸发粒子。"),
        prompt: L(
            "A fundraising thermometer: a 30 pt glass tube on a 54 pt bulb with a specular strip, milestone ticks at 25, 50, 75 and 100% beside it, next to the raised amount. Each tap adds a donation: the liquid column rises on an under-damped spring (natural period ≈ 0.66 s, damping ratio 0.38), so it overshoots and sloshes back, while a travelling sine wave of up to 4 pt ripples the surface and dies away with the motion; bubbles drift upward. The liquid warms from red to amber and turns green only as it reaches the goal. When the surface crosses a milestone its tick lights in the liquid's colour, the label pops with a back-out overshoot and a rigid haptic ticks. Crossing 100% fires a ring flash and 28 confetti particles under gravity with a success haptic. The amount rolls smoothly, without the overshoot. Generous, physical, celebratory.",
            "募款温度计：30pt 宽的玻璃管立在 54pt 的球泡上；右侧 25、50、75、100% 处有里程碑刻度，旁边是已筹金额。每次点击增加一笔捐款：液柱以欠阻尼弹簧（固有周期约 0.66 秒、阻尼比 0.38）上升，先过冲再晃回；液面泛起最大 4pt 的行进正弦波并随运动平息，小气泡缓缓上浮。液体由红渐变为琥珀色，临近目标时才转绿。液面越过里程碑时，刻度以液体颜色点亮，标签带回弹弹出，伴随硬朗触感。越过 100% 触发光环与 28 颗受重力的彩纸，以及成功触感。金额平滑滚动，不带过冲。有物理感，值得庆祝。"
        ),
        implementation: L(
            "A small reference-type model integrates the liquid's spring every frame inside a TimelineView and records when each milestone was crossed; a Canvas clips a wavy rectangle to the glass shape and derives tick pops and the confetti from those timestamps.",
            "一个引用类型的小模型在 TimelineView 中逐帧积分液柱的弹簧，并记录越过每个里程碑的时刻；Canvas 把带波浪顶边的矩形裁剪到玻璃形状内，刻度的弹出与彩纸粒子都由这些时间戳推算。"
        ),
        apis: ["TimelineView", "Canvas", "GraphicsContext.clip(to:)", "Path", "spring integration"],
        tags: ["thermometer", "goal", "fundraising", "liquid", "温度计", "目标进度", "募款", "液体晃动"],
        params: [
            .slider("damping", L("Damping ratio", "阻尼比"), 0.15...1, default: 0.38),
            .slider("wave", L("Wave height", "波浪高度"), 0...9, default: 4, decimals: 1, unit: "pt"),
            .slider("confetti", L("Confetti count", "彩纸数量"), 0...60, default: 28, step: 1, decimals: 0),
        ]
    ) { ctx in
        ThermometerDemo(ctx: ctx)
    }
}

/// Warm all the way up (red → coral → amber), turning green only over the last stretch to the goal.
private func thermometerTone(_ level: Double) -> ChartRGB {
    let warm = ChartRGB.red.mixed(.coral, ChartKit.smoothstep(0, 0.4, level)).mixed(.amber, ChartKit.smoothstep(0.35, 0.85, level))
    return warm.mixed(.green, ChartKit.smoothstep(0.88, 1, level))
}

private final class ThermometerModel {
    var level: Double
    var velocity: Double = 0
    var target: Double
    var shown: Double
    var ripple: Double = 0
    var last: Date?
    /// When each milestone (25/50/75/100%) lit up; `nil` while the liquid is below it.
    var lit: [Date?]
    var burst: Date?

    static let milestones: [Double] = [0.25, 0.5, 0.75, 1]

    init(level: Double) {
        self.level = level
        target = level
        shown = level
        lit = Self.milestones.map { level >= $0 ? Date.distantPast : nil }
    }

    func step(now: Date, damping: Double, silent: Bool) {
        let dt = min(max(now.timeIntervalSince(last ?? now), 0), 1.0 / 30.0)
        last = now
        guard dt > 0 else { return }
        let omega = 9.5
        // Two half steps keep the under-damped spring stable at 30 fps.
        for _ in 0..<2 {
            let h = dt / 2
            let acceleration = omega * omega * (target - level) - 2 * damping * omega * velocity
            velocity += acceleration * h
            level += velocity * h
        }
        ripple = max(ripple * exp(-dt * 2.4), min(abs(velocity) * 2.6, 1))
        shown += (target - shown) * (1 - exp(-dt * 6))
        for index in Self.milestones.indices {
            let mark = Self.milestones[index]
            if lit[index] == nil, level >= mark {
                lit[index] = now
                if index == 3 {
                    burst = now
                    if !silent { Haptics.success() }
                } else if !silent {
                    Haptics.tap(.rigid)
                }
            } else if lit[index] != nil, level < mark - 0.03 {
                lit[index] = nil
            }
        }
    }
}

private struct ThermometerDemo: View {
    let ctx: DemoContext
    @State private var model = ThermometerModel(level: 0.62)
    @State private var gifts = 0
    @State private var lastGift = 0

    private static let goal: Double = 10000
    private static let chunks: [Double] = [0.16, 0.12, 0.14, 0.2]

    var body: some View {
        ChartStage(hint: L("Tap to donate", "点击捐一笔"), ctx: ctx) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                let _ = model.step(now: timeline.date, damping: ctx["damping"], silent: ctx.isPreview)
                HStack(alignment: .center, spacing: 6) {
                    ThermometerGlass(model: model, now: timeline.date, wave: ctx.cg("wave"), confetti: ctx.int("confetti"), isStill: ctx.isStill)
                        .frame(width: 124, height: 236)
                    info
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { donate() }
        }
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.8) { donate() }
    }

    private var info: some View {
        let amount = max(model.shown, 0) * Self.goal
        let percent = Int((max(model.shown, 0) * 100).rounded())
        let reached = model.target >= 0.999
        let tone = thermometerTone(model.shown)
        return VStack(alignment: .leading, spacing: 4) {
            Text(L("Community garden", "社区花园募款"), ctx.language)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: "$\(Self.grouped(amount))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(verbatim: ctx.language == .zh ? "目标 $10,000" : "of $10,000 goal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: reached ? "checkmark.seal.fill" : "flame.fill")
                    .font(.system(size: 10, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                Text(verbatim: reached ? (ctx.language == .zh ? "目标达成" : "Goal reached") : "\(percent)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(tone.mixed(ChartRGB(0x000000), 0.15).color())
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tone.color(0.16), in: Capsule())
            .padding(.top, 6)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: reached)

            ZStack(alignment: .leading) {
                if gifts > 0 {
                    Text(verbatim: lastGift > 0 ? "+$\(Self.grouped(Double(lastGift)))" : (ctx.language == .zh ? "新一轮" : "New round"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(lastGift > 0 ? Palette.green : Color.secondary)
                        .id(gifts)
                        .transition(.asymmetric(
                            insertion: .offset(y: 14).combined(with: .opacity).combined(with: .scale(scale: 0.7, anchor: .leading)),
                            removal: .offset(y: -16).combined(with: .opacity)
                        ))
                }
            }
            .frame(height: 26, alignment: .leading)
            .padding(.top, 10)

            HStack(spacing: -7) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(Palette.spectrum[(index * 2 + 1) % Palette.spectrum.count].gradient)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(Palette.elevated, lineWidth: 2))
                }
                Text(verbatim: ctx.language == .zh ? "  \(128 + gifts) 人已捐" : "  \(128 + gifts) donors")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .padding(.leading, 9)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func grouped(_ value: Double) -> String {
        let number = Int(value.rounded())
        let thousands = number / 1000
        return thousands > 0 ? "\(thousands),\(String(format: "%03d", number % 1000))" : "\(number)"
    }

    /// Tap and autoplay: one more donation, or a fresh round once the goal has been reached.
    private func donate() {
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if model.target >= 0.999 {
                model.target = 0.14
                lastGift = 0
            } else {
                let chunk = Self.chunks[gifts % Self.chunks.count]
                let next = min(model.target + chunk, 1)
                lastGift = Int(((next - model.target) * Self.goal).rounded())
                model.target = next
            }
            gifts += 1
        }
    }
}

private struct ThermometerGlass: View {
    let model: ThermometerModel
    let now: Date
    let wave: CGFloat
    let confetti: Int
    let isStill: Bool

    var body: some View {
        Canvas { context, size in
            let time = isStill ? 0 : now.timeIntervalSinceReferenceDate
            let tubeWidth: CGFloat = 30
            let bulbRadius: CGFloat = 27
            let midX: CGFloat = 44
            let bulbCentre = CGPoint(x: midX, y: size.height - bulbRadius - 6)
            let tubeTop: CGFloat = 16
            let goalY = tubeTop + 16
            let zeroY = bulbCentre.y - bulbRadius + 6
            func surface(_ level: Double) -> CGFloat { zeroY + (goalY - zeroY) * CGFloat(level) }

            func glass(inset: CGFloat) -> Path {
                var path = Path()
                let w = tubeWidth - inset * 2
                path.addRoundedRect(
                    in: CGRect(x: midX - w / 2, y: tubeTop + inset, width: w, height: bulbCentre.y - tubeTop - inset),
                    cornerSize: CGSize(width: w / 2, height: w / 2)
                )
                let r = bulbRadius - inset
                path.addEllipse(in: CGRect(x: bulbCentre.x - r, y: bulbCentre.y - r, width: r * 2, height: r * 2))
                return path
            }

            let level = min(max(model.level, -0.05), 1.12)
            let tone = thermometerTone(level)
            context.fill(glass(inset: 0), with: .color(.primary.opacity(0.07)))

            // Liquid: a rectangle with a wavy top edge, clipped to the inside of the glass.
            let top = surface(level)
            let amplitude = wave * CGFloat(model.ripple)
            var liquid = Path()
            let left = midX - bulbRadius
            let right = midX + bulbRadius
            liquid.move(to: CGPoint(x: left, y: size.height))
            var x = left
            while x <= right {
                let offset = amplitude * CGFloat(sin(Double(x) * 0.42 + time * 9)) + amplitude * 0.4 * CGFloat(sin(Double(x) * 0.9 - time * 13))
                liquid.addLine(to: CGPoint(x: x, y: top + offset))
                x += 2
            }
            liquid.addLine(to: CGPoint(x: right, y: size.height))
            liquid.closeSubpath()
            var inside = context
            inside.clip(to: glass(inset: 4))
            inside.fill(liquid, with: .linearGradient(
                Gradient(colors: [tone.mixed(ChartRGB(0xFFFFFF), 0.25).color(), tone.color(), tone.mixed(ChartRGB(0x000000), 0.18).color()]),
                startPoint: CGPoint(x: midX, y: top),
                endPoint: CGPoint(x: midX, y: size.height)
            ))
            for bubble in 0..<5 {
                let travel = zeroY + 30 - top
                guard travel > 12 else { continue }
                let phase = (time * (0.16 + 0.05 * Double(bubble)) + ChartKit.hash(bubble, 3)).truncatingRemainder(dividingBy: 1)
                let centre = CGPoint(
                    x: midX + CGFloat(ChartKit.hash(bubble, 5) - 0.5) * 12 + CGFloat(sin(time * 2 + Double(bubble))) * 1.5,
                    y: zeroY + 30 - travel * CGFloat(phase)
                )
                let r: CGFloat = 1.2 + CGFloat(ChartKit.hash(bubble, 9)) * 1.4
                inside.fill(Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.4 * sin(Double.pi * phase))))
            }

            // Glass: rim and a specular strip.
            context.stroke(glass(inset: 0.5), with: .color(.primary.opacity(0.14)), lineWidth: 1)
            var shine = Path()
            shine.move(to: CGPoint(x: midX - 7, y: tubeTop + 12))
            shine.addLine(to: CGPoint(x: midX - 7, y: bulbCentre.y - bulbRadius - 2))
            context.stroke(shine, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            let glint = CGRect(x: bulbCentre.x - 15, y: bulbCentre.y - 15, width: 9, height: 9)
            context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.45)))

            // Milestones.
            for index in ThermometerModel.milestones.indices {
                let mark = ThermometerModel.milestones[index]
                let markY = surface(mark)
                let since = model.lit[index].map { now.timeIntervalSince($0) }
                let on = since != nil
                let pop = since.map { ChartKit.backOut(min($0 / 0.35, 1), overshoot: 3) } ?? 0
                var tick = Path()
                tick.move(to: CGPoint(x: midX + tubeWidth / 2 + 4, y: markY))
                tick.addLine(to: CGPoint(x: midX + tubeWidth / 2 + 10 + 4 * CGFloat(min(pop, 1)), y: markY))
                context.stroke(tick, with: .color(on ? tone.color() : Color.primary.opacity(0.25)), style: StrokeStyle(lineWidth: on ? 2.5 : 1.5, lineCap: .round))
                var label = context
                let anchorPoint = CGPoint(x: midX + tubeWidth / 2 + 20, y: markY)
                label.translateBy(x: anchorPoint.x, y: anchorPoint.y)
                let scale = on ? 0.7 + 0.3 * CGFloat(pop) : 0.9
                label.scaleBy(x: scale, y: scale)
                let text: Text = index == 3
                    ? Text("\(Image(systemName: "flag.fill")) 100%")
                    : Text(verbatim: "\(Int(mark * 100))%")
                label.draw(
                    text.font(.system(size: 11, weight: on ? .bold : .medium, design: .rounded))
                        .foregroundStyle(on ? Color.primary : Color.secondary.opacity(0.8)),
                    at: .zero,
                    anchor: .leading
                )
            }

            // Goal burst: a ring flash and confetti under gravity.
            if let burst = model.burst, !isStill {
                let t = now.timeIntervalSince(burst)
                if t >= 0, t < 1.4 {
                    let origin = CGPoint(x: midX, y: goalY)
                    let ringRadius = 8 + 46 * CGFloat(1 - pow(1 - min(t / 0.5, 1), 3))
                    let ringAlpha = max(0, 1 - t / 0.5)
                    context.stroke(
                        Path(ellipseIn: CGRect(x: origin.x - ringRadius, y: origin.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)),
                        with: .color(Palette.green.opacity(0.7 * ringAlpha)),
                        lineWidth: 3 * CGFloat(ringAlpha) + 0.5
                    )
                    for index in 0..<max(confetti, 0) {
                        let angle = -Double.pi / 2 + (ChartKit.hash(index, 11) - 0.5) * 2.4
                        let speed = 110 + 150 * ChartKit.hash(index, 13)
                        let px = origin.x + CGFloat(cos(angle) * speed * t)
                        let py = origin.y + CGFloat(sin(angle) * speed * t + 260 * t * t)
                        let alpha = max(0, 1 - t / 1.4)
                        var piece = context
                        piece.translateBy(x: px, y: py)
                        piece.rotate(by: .radians(t * (4 + 8 * ChartKit.hash(index, 17)) + Double(index)))
                        let w: CGFloat = 5 + 3 * CGFloat(ChartKit.hash(index, 19))
                        piece.fill(
                            Path(roundedRect: CGRect(x: -w / 2, y: -1.5, width: w, height: 3), cornerRadius: 1),
                            with: .color(Palette.spectrum[index % Palette.spectrum.count].opacity(alpha))
                        )
                    }
                }
            }
        }
    }
}
