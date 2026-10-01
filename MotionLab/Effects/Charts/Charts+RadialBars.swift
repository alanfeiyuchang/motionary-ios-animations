import SwiftUI

extension Effect {
    static let chartsRadialBars = Effect(
        id: "charts.radial-bars",
        category: .charts,
        interaction: .tap,
        name: L("Radial Bars Sweep", "径向柱扫出"),
        summary: L("Twenty-four hour bars shoot outward around a dial with a clockwise stagger; tap or drag to spotlight one and dim the rest.", "24 根小时柱沿表盘顺时针错峰向外射出；点击或拖动可聚焦其中一根并压暗其余。"),
        prompt: L(
            "A 24-hour activity dial: capsule bars 7 pt wide radiate from an inner circle of radius 46 pt, their length encoding steps per hour and their colour running indigo at the root to pink at the tip, with 0 / 6 / 12 / 18 labels outside. On appear the dial turns in from −40° while the bars shoot outward clockwise, 30 ms apart, on an underdamped spring (response 0.55 s, damping 0.62) that overshoots their length before settling. Tapping a bar, or dragging around the ring, selects it: it extends 8 pt and glows, the others drop to 28% opacity and shrink to 94%, and the centre swaps the daily total for that hour's time and step count with a numeric roll (spring 0.35 s, damping 0.7). A selection tick marks each bar crossed. Tap the centre to clear. Rhythmic and radiant.",
            "24 小时活动表盘：7pt 宽的胶囊柱从半径 46pt 的内圈向外辐射，长度表示每小时步数，颜色由根部靛蓝过渡到顶端粉色，外侧标注 0 / 6 / 12 / 18。出现时表盘从 −40° 转入，柱子顺时针依次射出，间隔 30 毫秒，使用欠阻尼弹簧（响应 0.55 秒、阻尼 0.62），先过冲再回落。点击某根柱子或沿环拖动即可选中：它伸长 8pt 并发光，其余降到 28% 不透明度并缩到 94%，中心由全天总数换成该小时的时间与步数，数字滚动（弹簧 0.35 秒、阻尼 0.7）。每越过一根有一次选择触感，点中心取消。富有节奏感。"
        ),
        implementation: L(
            "Each bar is a Capsule whose height is driven by its own animated value, offset outward and rotated around the centre; selection is resolved from the touch angle with atan2 and animates length, opacity and the numericText centre label on one spring.",
            "每根柱子是一个 Capsule，高度由各自的动画值驱动，向外偏移后绕中心旋转；选中项由触点角度（atan2）求得，长度、不透明度与中心的 numericText 标签在同一个弹簧中变化。"
        ),
        apis: ["rotationEffect", "Animation.delay", "spring(response:dampingFraction:)", "contentTransition(.numericText)", "DragGesture", "atan2"],
        tags: ["radial bar", "circular chart", "polar", "24 hours", "径向柱状图", "环形图表", "极坐标", "小时分布"],
        params: [
            .slider("stagger", L("Stagger", "错峰间隔"), 0...0.08, default: 0.03, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1.0, default: 0.55, unit: "s"),
            .slider("inner", L("Inner radius", "内圈半径"), 30...60, default: 46, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        RadialBarsDemo(ctx: ctx)
    }
}

/// Steps per hour over a day: quiet night, commute, lunch and evening peaks.
private let radialSteps: [Double] = (0..<24).map { hour in
    let h = Double(hour)
    func peak(_ center: Double, _ width: Double, _ amp: Double) -> Double { amp * exp(-pow((h - center) / width, 2)) }
    let value = 230 + peak(8, 1.8, 760) + peak(12.5, 1.6, 520) + peak(18.5, 2.4, 900) + peak(15.5, 1.6, 300) + peak(22, 1.5, 160) + 70 * sin(h * 2.1)
    return max(value.rounded(), 120)
}

private let radialPeak: Double = radialSteps.max() ?? 1
private let radialTotal: Double = radialSteps.reduce(0, +)

private struct RadialBarsDemo: View {
    let ctx: DemoContext
    @State private var grow: [Double] = Array(repeating: 1, count: 24)
    @State private var turn: Double = 1
    @State private var selected: Int?
    @State private var engaged = false
    @State private var autoStep = 0
    @GestureState private var touching = false

    private let side: CGFloat = 250
    private let maxLength: CGFloat = 60
    private static let script: [Int?] = [8, 12, 18, nil]

    var body: some View {
        ChartStage(hint: L("Tap a bar, or drag around the ring", "点击柱子，或沿圆环拖动"), ctx: ctx) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    .frame(width: (ctx.cg("inner") - 5) * 2, height: (ctx.cg("inner") - 5) * 2)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .frame(width: (ctx.cg("inner") + maxLength) * 2, height: (ctx.cg("inner") + maxLength) * 2)
                ForEach(0..<24, id: \.self) { index in
                    bar(index)
                }
                ticks
                centerLabel
            }
            .rotationEffect(.degrees(-40 * (1 - turn)))
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .onTapGesture { location in tap(location) }
            .simultaneousGesture(ringGesture)
        }
        .onChange(of: touching) { _, isTouching in
            if !isTouching { engaged = false }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                grow = Array(repeating: 0, count: 24)
                turn = 0
            }, then: { sweepOut() })
        }
        .autoplay(ctx.isPreview, every: 1.2, delay: 1.9, intro: false) {
            select(Self.script[autoStep % Self.script.count])
            autoStep += 1
        }
    }

    private func bar(_ index: Int) -> some View {
        let inner = ctx.cg("inner")
        let fraction = radialSteps[index] / radialPeak
        let isSelected = selected == index
        let dimmed = selected != nil && !isSelected
        let base = 7 + (maxLength - 7) * CGFloat(fraction)
        let length = max((base + (isSelected ? 8 : 0)) * CGFloat(grow[index]) * (dimmed ? 0.94 : 1), 0.01)
        let tip = ChartRGB.indigo.mixed(ChartRGB.pink, 0.25 + 0.75 * fraction)
        return Capsule()
            .fill(LinearGradient(colors: [tip.color(), Palette.indigo], startPoint: .top, endPoint: .bottom))
            .frame(width: 7, height: length)
            .shadow(color: tip.color(isSelected ? 0.7 : 0), radius: 7)
            .offset(y: -(inner + length / 2))
            .rotationEffect(.degrees(Double(index) / 24 * 360 + 7.5))
            .opacity(grow[index] > 0.01 ? (dimmed ? 0.28 : 1) : 0)
    }

    private var ticks: some View {
        ForEach([0, 6, 12, 18], id: \.self) { hour in
            let angle = Double(hour) / 24 * 2 * Double.pi - Double.pi / 2
            let radius = ctx.cg("inner") + maxLength + 11
            Text(verbatim: "\(hour)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(40 * (1 - turn)))
                .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
                .opacity(turn)
        }
    }

    private var centerLabel: some View {
        let value = selected.map { radialSteps[$0] } ?? radialTotal
        let caption: String = {
            if let selected { return String(format: "%02d:00", selected) }
            return ctx.language == .zh ? "今日步数" : "Steps today"
        }()
        return VStack(spacing: 1) {
            Text(verbatim: Int(value).formatted(.number.locale(ctx.language.locale)))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
            Text(verbatim: caption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .frame(width: (ctx.cg("inner") - 8) * 2)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
        .rotationEffect(.degrees(40 * (1 - turn)))
        .scaleEffect(0.7 + 0.3 * turn)
        .opacity(turn)
        .allowsHitTesting(false)
    }

    private var ringGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if !engaged {
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    engaged = true
                }
                if let index = hour(at: value.location, strict: false) { select(index) }
            }
            .onEnded { _ in engaged = false }
    }

    /// The hour slot under a point; `strict` also requires the point to be on the ring.
    private func hour(at location: CGPoint, strict: Bool) -> Int? {
        let dx = location.x - side / 2
        let dy = location.y - side / 2
        let radius = (dx * dx + dy * dy).squareRoot()
        let inner = ctx.cg("inner")
        if radius < inner - 6 { return nil }
        if strict && radius > inner + maxLength + 22 { return nil }
        var fraction = (Double(atan2(dy, dx)) + Double.pi / 2) / (2 * Double.pi)
        if fraction < 0 { fraction += 1 }
        return min(Int(fraction * 24), 23)
    }

    private func tap(_ location: CGPoint) {
        let hit = hour(at: location, strict: true)
        select(hit == selected ? nil : hit)
    }

    /// Taps, the ring drag and autoplay share this.
    private func select(_ index: Int?) {
        guard index != selected else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = index }
    }

    private func sweepOut() {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) { turn = 1 }
        for index in 0..<24 {
            withAnimation(.spring(response: ctx["response"], dampingFraction: 0.62).delay(Double(index) * ctx["stagger"])) {
                grow[index] = 1
            }
        }
    }
}
