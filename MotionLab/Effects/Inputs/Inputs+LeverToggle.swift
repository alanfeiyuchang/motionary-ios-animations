import SwiftUI

extension Effect {
    static let inputsLeverToggle = Effect(
        id: "inputs.lever-toggle",
        category: .inputs,
        interaction: .gesture,
        name: L("Lever Switch", "拨杆开关"),
        summary: L("A chrome lever throws through its arc, bounces off the stop with a click, and a pilot lamp warms up.", "镀铬拨杆划过弧线，撞上限位弹一下并“咔”地到位，指示灯随后慢慢热起来。"),
        prompt: L(
            "A hardware toggle lever on a 190 × 250 pt brushed plate with four screws, engraved ON / OFF marks and a jewel pilot lamp. The chrome lever is seen head-on and pivots ±38° toward and away from the viewer: its ball tip travels about 53 pt, the rod foreshortens to nothing at mid-throw and the ball swells 14% as it swings closest. Tapping, or dragging the lever past centre, throws it on an underdamped spring (response 0.26 s, damping 0.5) whose overshoot is folded back, so it hits the stop, rebounds a few degrees and settles. On impact a rigid haptic fires and the plate jolts 2 pt. A soft shadow of rod and ball slides across the plate, longest at mid-throw. The lamp warms from dark glass to full glow over 0.6 s and cools with a slower afterglow. Industrial, decisive, analog.",
            "190 × 250pt 拉丝面板上的硬件拨杆开关：刻印的 ON / OFF 与一颗宝石指示灯。镀铬拨杆为正视视角，朝向或远离观察者摆动 ±38°：球头上下移动约 53pt，行程中点时杆身缩短到几乎消失，球头最靠近时放大 14%。点击或把拨杆拖过中点，它以欠阻尼弹簧（响应 0.26 秒、阻尼 0.5）甩向另一端，过冲被折回，于是撞上限位、回弹几度后停稳；撞击瞬间一次硬朗触觉，面板微震 2pt。杆与球头的柔和投影在面板上滑动，中点处最长。指示灯在 0.6 秒内从暗玻璃升温到全亮，关闭时带着更慢的余辉冷却。"
        ),
        implementation: L(
            "An Animatable view receives the spring-driven throw value, folds any overshoot back off the stop, and derives the tip position, rod foreshortening, ball size and shadow offset from the lever angle with sin/cos. The lamp is a stack of gradients whose lit layers fade with a separately timed warm-up animation.",
            "Animatable 视图接收弹簧驱动的行程值，把过冲折回成撞限位的回弹，并用 sin/cos 由拨杆角度推导球头位置、杆身缩短、球头大小与投影偏移。指示灯由多层渐变叠成，点亮层按独立计时的升温动画淡入。"
        ),
        apis: ["Animatable", "spring(response:dampingFraction:)", "DragGesture", "RadialGradient", "Path"],
        tags: ["toggle", "lever", "switch", "hardware", "skeuomorphic", "开关", "拨杆", "拟物", "指示灯"],
        params: [
            .slider("angle", L("Throw angle", "行程角度"), 24...50, default: 38, decimals: 0, unit: "°"),
            .slider("bounce", L("Stop damping", "限位阻尼"), 0.3...1.0, default: 0.5),
            .slider("warm", L("Lamp warm-up", "指示灯升温"), 0.1...1.5, default: 0.6, unit: "s"),
            .choice("lamp", L("Lamp", "灯色"), [L("Amber", "琥珀"), L("Green", "绿"), L("Red", "红")], default: 0),
        ]
    ) { ctx in
        InputLeverToggleDemo(ctx: ctx)
    }
}

private struct InputLeverToggleDemo: View {
    let ctx: DemoContext
    @State private var isOn: Bool
    /// Throw: 0 = off (down), 1 = on (up). The spring may overshoot; `InputLeverArm` folds that back.
    @State private var throwValue: CGFloat
    @State private var lamp: Double
    @State private var kick: CGFloat = 0
    @State private var dragBase: CGFloat?
    @State private var snapped = false
    @State private var clickTask: Task<Void, Never>?
    @GestureState private var touching = false

    private let plate = CGSize(width: 190, height: 250)
    private let response: Double = 0.26

    init(ctx: DemoContext) {
        self.ctx = ctx
        _isOn = State(initialValue: ctx.isStill)
        _throwValue = State(initialValue: ctx.isStill ? 1 : 0)
        _lamp = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var lampColor: Color {
        switch ctx.int("lamp") {
        case 1: return Color(hex: 0x3DDC84)
        case 2: return Color(hex: 0xFF4D5E)
        default: return Color(hex: 0xFFB02E)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            panel
                .scaleEffect(ctx.isPreview ? 1.08 : 1)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap, or drag the lever past centre", "点击，或把拨杆拖过中点"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.8, delay: 0.5) { throwLever(to: !isOn) }
        .onDisappear { clickTask?.cancel() }
    }

    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return ZStack {
            shape
                .fill(LinearGradient(
                    colors: [Color.adaptive(light: 0xFAFBFD, dark: 0x3C3D45), Color.adaptive(light: 0xD5D8E0, dark: 0x222328)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.7), .black.opacity(0.18)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
            screws
            InputLeverLamp(level: lamp, color: lampColor)
                .offset(y: -92)
            marks
            InputLeverArm(throwValue: throwValue, maxAngle: ctx["angle"])
                .offset(y: 26)
        }
        .frame(width: plate.width, height: plate.height)
        .shadow(color: .black.opacity(0.22), radius: 18, y: 12)
        .offset(y: kick)
        .contentShape(shape)
        .gesture(drag)
        .onChange(of: touching) { _, down in
            if !down { endDrag(moved: 100) }
        }
    }

    private var screws: some View {
        ForEach(0..<4, id: \.self) { index in
            let sx: CGFloat = index % 2 == 0 ? -1 : 1
            let sy: CGFloat = index < 2 ? -1 : 1
            ZStack {
                Circle().fill(LinearGradient(colors: [.white.opacity(0.9), Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
                Capsule()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 7, height: 1.5)
                    .rotationEffect(.degrees(Double(index) * 37 + 20))
            }
            .frame(width: 11, height: 11)
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            .offset(x: sx * (plate.width / 2 - 20), y: sy * (plate.height / 2 - 20))
        }
    }

    private var marks: some View {
        ZStack {
            Text(verbatim: "ON")
                .foregroundStyle(lampColor.opacity(0.35 + 0.65 * lamp))
                .shadow(color: lampColor.opacity(0.7 * lamp), radius: 6)
                .offset(x: -56, y: -26)
            Text(verbatim: "OFF")
                .foregroundStyle(Color.primary.opacity(0.4 - 0.15 * lamp))
                .offset(x: -56, y: 78)
        }
        .font(.system(size: 12, weight: .heavy, design: .rounded))
        .tracking(1.5)
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if dragBase == nil {
                    dragBase = isOn ? 1 : 0
                    snapped = false
                }
                guard !snapped, let base = dragBase else { return }
                let raw: CGFloat = base - value.translation.height / 106
                let crossed = base > 0.5 ? raw < 0.5 : raw > 0.5
                if crossed {
                    // Over-centre: the lever takes over and throws itself to the far stop.
                    snapped = true
                    throwLever(to: !isOn)
                } else {
                    clickTask?.cancel()
                    withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.9)) {
                        throwValue = raw.clamped(to: 0...1)
                    }
                }
            }
            .onEnded { value in
                endDrag(moved: hypot(value.translation.width, value.translation.height))
            }
    }

    private func endDrag(moved: CGFloat) {
        guard dragBase != nil else { return }
        dragBase = nil
        guard !snapped else { return }
        if moved < 6 {
            throwLever(to: !isOn)
        } else {
            // Let go before centre: the spring pulls it back to its own stop.
            withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) { throwValue = isOn ? 1 : 0 }
        }
    }

    /// The one throw used by tap, over-centre drag and autoplay.
    private func throwLever(to target: Bool) {
        isOn = target
        withAnimation(.spring(response: response, dampingFraction: ctx["bounce"])) { throwValue = target ? 1 : 0 }
        clickTask?.cancel()
        let quiet = ctx.isPreview
        let warm = ctx["warm"]
        clickTask = Task { @MainActor in
            // The spring first reaches the stop a little before half its response.
            try? await Task.sleep(for: .seconds(response * 0.42))
            guard !Task.isCancelled else { return }
            if !quiet { Haptics.tap(.rigid) }
            withAnimation(.easeOut(duration: 0.05)) { kick = target ? -2 : 2 }
            if target {
                withAnimation(.timingCurve(0.35, 0, 0.2, 1, duration: warm)) { lamp = 1 }
            } else {
                withAnimation(.easeOut(duration: warm * 1.4)) { lamp = 0 }
            }
            try? await Task.sleep(for: .seconds(0.05))
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { kick = 0 }
        }
    }
}

/// Lever seen head-on. Animatable so every frame of the spring re-derives the projection.
private struct InputLeverArm: View, Animatable {
    var throwValue: CGFloat
    let maxAngle: Double

    var animatableData: CGFloat {
        get { throwValue }
        set { throwValue = newValue }
    }

    private let length: CGFloat = 86

    var body: some View {
        // Fold the spring's overshoot back: the lever cannot pass its stop, it bounces off it.
        let folded: CGFloat = throwValue > 1 ? 1 - (throwValue - 1) * 0.7 : (throwValue < 0 ? -throwValue * 0.7 : throwValue)
        let limit: Double = maxAngle * .pi / 180
        let phi: Double = Double(1 - 2 * folded) * limit
        let tipY: CGFloat = length * CGFloat(sin(phi))
        let height: CGFloat = length * CGFloat(cos(phi))
        let near: CGFloat = CGFloat((cos(phi) - cos(limit)) / max(1 - cos(limit), 0.001))
        let ball: CGFloat = 38 * (1 + 0.14 * near)
        let slot: CGFloat = length * CGFloat(sin(limit))
        let shadow = CGSize(width: height * 0.2, height: height * 0.26)

        return ZStack {
            // Recessed slot the lever travels in.
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.05), Color(white: 0.22)], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: slot * 2 + 34)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1).blendMode(.plusLighter))
            // Cast shadow: longest when the lever stands straight out of the plate.
            InputLeverRod(tip: CGPoint(x: shadow.width, y: tipY + shadow.height), baseWidth: 20, tipWidth: 22)
                .fill(Color.black.opacity(0.32))
                .blur(radius: 5 + near * 3)
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: ball, height: ball)
                .blur(radius: 6 + near * 3)
                .offset(x: shadow.width, y: tipY + shadow.height)
            // Collar nut.
            Circle()
                .fill(AngularGradient(
                    colors: [Color(white: 0.95), Color(white: 0.5), Color(white: 0.85), Color(white: 0.4), Color(white: 0.95)],
                    center: .center
                ))
                .frame(width: 44, height: 44)
                .overlay(Circle().fill(Color(white: 0.12)).frame(width: 24, height: 24))
            InputLeverRod(tip: CGPoint(x: 0, y: tipY), baseWidth: 19, tipWidth: 15)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x7C8089), Color(hex: 0xF6F8FB), Color(hex: 0xB4B8C1), Color(hex: 0x62666F)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 20)
            Circle()
                .fill(RadialGradient(
                    colors: [.white, Color(hex: 0xD4D8E0), Color(hex: 0x7B7F89)],
                    center: UnitPoint(x: 0.36, y: 0.3 + 0.12 * CGFloat(phi / max(limit, 0.001))),
                    startRadius: 1,
                    endRadius: ball * 0.72
                ))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5))
                .frame(width: ball, height: ball)
                .offset(y: tipY)
        }
        .frame(width: 120, height: 200)
    }
}

/// Tapered rod from the pivot (the shape's centre) to `tip`.
private struct InputLeverRod: Shape {
    var tip: CGPoint
    let baseWidth: CGFloat
    let tipWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let origin = CGPoint(x: rect.midX, y: rect.midY)
        let end = CGPoint(x: origin.x + tip.x, y: origin.y + tip.y)
        var path = Path()
        path.move(to: CGPoint(x: origin.x - baseWidth / 2, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + baseWidth / 2, y: origin.y))
        path.addLine(to: CGPoint(x: end.x + tipWidth / 2, y: end.y))
        path.addLine(to: CGPoint(x: end.x - tipWidth / 2, y: end.y))
        path.closeSubpath()
        return path
    }
}

/// Jewel pilot lamp: dark glass at 0, glowing at 1.
private struct InputLeverLamp: View {
    let level: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 70, height: 70)
                .blur(radius: 22)
                .opacity(level * 0.75)
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.45)], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 30)
            Circle()
                .fill(Color(white: 0.1))
                .frame(width: 22, height: 22)
            Circle()
                .fill(color.opacity(0.22 + 0.78 * level))
                .frame(width: 22, height: 22)
            Circle()
                .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: 8))
                .frame(width: 22, height: 22)
                .opacity(level * 0.85)
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 6, height: 4)
                .offset(x: -4, y: -5)
        }
    }
}
