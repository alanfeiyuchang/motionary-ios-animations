import SwiftUI

extension Effect {
    static let inputsColorWheel = Effect(
        id: "inputs.color-wheel",
        category: .inputs,
        interaction: .gesture,
        name: L("Polar Colour Wheel", "极坐标色轮"),
        summary: L("A hue and saturation wheel whose thumb travels in polar space under a loupe, wrapped by a brightness ring that takes on the picked colour.", "色相与饱和度色轮：滑块在放大镜下沿极坐标移动，外圈亮度环随所选颜色变色。"),
        prompt: L(
            "A 176 pt colour wheel, hue around the angle and saturation along the radius, wrapped by a 270° brightness arc with a hex swatch chip in its gap. Touching the wheel sends the 26 pt thumb to the finger in polar space: angle and radius are animated separately on one spring (response 0.55 s, damping 0.82), so it sweeps along an arc through the hues. While held, the thumb lifts 46 pt above the finger and grows into a 48 pt loupe filled with the picked colour (response 0.3 s, damping 0.6), leaving a small ring at the exact point. The brightness arc's gradient, its knob and the swatch re-tint continuously along the same path and the hex digits tick. Dragging the outer arc dims the whole wheel. Releasing drops the loupe back with a bounce (damping 0.55).",
            "176pt 色轮：角度是色相，半径是饱和度；外面包着一段 270° 的亮度弧，缺口处是带十六进制色值的色块胶囊。触碰色轮时，26pt 的滑块沿极坐标飞向手指：角度和半径由同一个弹簧（响应 0.55 秒、阻尼 0.82）分别插值，于是它沿弧线扫过各个色相。按住期间滑块抬到手指上方 46pt，长成一枚 48pt、填满所选颜色的放大镜（响应 0.3 秒、阻尼 0.6），原处留一个小圆环。亮度弧、旋钮和色块沿同一路径连续换色。拖动外圈亮度弧会压暗整个色轮。松手后放大镜带一点弹跳落回（阻尼 0.55）。"
        ),
        implementation: L(
            "Angle (unwrapped, so it takes the short way), radius, brightness and loupe lift are the animatable data of one overlay view, which derives every colour from them each frame. A single DragGesture decides at touch-down whether it drives the wheel or the brightness arc from the distance to the centre.",
            "角度（不取模，保证走近路）、半径、亮度与放大镜抬升量是同一个覆盖层视图的动画数据，每帧由它们推出所有颜色。单个 DragGesture 在按下时根据到圆心的距离决定驱动色轮还是亮度弧。"
        ),
        apis: ["Animatable", "AngularGradient", "RadialGradient", "DragGesture", "Color(hue:saturation:brightness:)", "spring(response:dampingFraction:)"],
        tags: ["color", "wheel", "picker", "hue", "loupe", "brightness", "色轮", "取色", "色相", "放大镜", "亮度"],
        params: [
            .slider("lift", L("Loupe lift", "放大镜抬升"), 30...70, default: 46, decimals: 0, unit: "pt"),
            .slider("loupe", L("Loupe size", "放大镜尺寸"), 36...64, default: 48, decimals: 0, unit: "pt"),
            .slider("travel", L("Travel response", "移动响应"), 0.3...0.9, default: 0.55, unit: "s"),
        ]
    ) { ctx in
        InputColorWheelDemo(ctx: ctx)
    }
}

private enum InputWheelMetrics {
    static let disc: CGFloat = 176
    static let ringRadius: CGFloat = 108
    static let ringWidth: CGFloat = 12
    static let side: CGFloat = 240
    static let arcStart: Double = 135
    static let arcSweep: Double = 270
}

private struct InputColorWheelDemo: View {
    private enum Mode { case wheel, ring }

    let ctx: DemoContext
    /// Radians, unwrapped so animation takes the short way round.
    @State private var angle: Double = -0.75
    @State private var radius: CGFloat = 0.78
    @State private var brightness: CGFloat = 1
    @State private var loupe: CGFloat
    @State private var mode: Mode?
    @State private var step = 0
    @State private var playTask: Task<Void, Never>?
    @GestureState private var touching = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _loupe = State(initialValue: ctx.isStill ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                wheel
                InputWheelOverlay(
                    angle: angle,
                    radius: radius,
                    brightness: brightness,
                    loupe: loupe,
                    lift: ctx.cg("lift"),
                    loupeSize: ctx.cg("loupe")
                )
            }
            .frame(width: InputWheelMetrics.side, height: InputWheelMetrics.side + 12)
            .contentShape(Rectangle())
            .gesture(drag)
            Spacer(minLength: 0)
            DemoHint(text: L("Drag on the wheel or the outer ring", "在色轮或外圈上拖动"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: touching) { _, down in
            if !down { release() }
        }
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.5) { play() }
        .onDisappear { playTask?.cancel() }
    }

    private var wheel: some View {
        let hues: [Color] = (0...12).map { Color(hue: Double($0) / 12, saturation: 1, brightness: 1) }
        return Circle()
            .fill(AngularGradient(colors: hues, center: .center))
            .overlay(Circle().fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: InputWheelMetrics.disc / 2)))
            .frame(width: InputWheelMetrics.disc, height: InputWheelMetrics.disc)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }

    // MARK: Gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { gesture in
                let center = CGPoint(x: InputWheelMetrics.side / 2, y: (InputWheelMetrics.side + 12) / 2)
                let dx = gesture.location.x - center.x
                let dy = gesture.location.y - center.y
                let distance = sqrt(dx * dx + dy * dy)
                let first = mode == nil
                if first {
                    playTask?.cancel()
                    mode = distance > InputWheelMetrics.disc / 2 + 8 ? .ring : .wheel
                    Haptics.tap(.light)
                }
                switch mode {
                case .ring:
                    setBrightness(dx: dx, dy: dy, animated: first)
                case .wheel:
                    pick(theta: atan2(Double(dy), Double(dx)), radius: min(distance / (InputWheelMetrics.disc / 2), 1), animated: first)
                    if first { liftLoupe() }
                case nil:
                    break
                }
            }
            .onEnded { _ in release() }
    }

    /// Finger and autoplay both land here: move the thumb in polar space.
    private func pick(theta: Double, radius target: CGFloat, animated: Bool) {
        // Unwrap to the equivalent angle nearest the current one.
        var delta = (theta - angle).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        let animation: Animation = animated
            ? .spring(response: ctx["travel"], dampingFraction: 0.82)
            : .interactiveSpring(response: 0.12, dampingFraction: 0.9)
        withAnimation(animation) {
            angle += delta
            radius = target
        }
    }

    private func setBrightness(dx: CGFloat, dy: CGFloat, animated: Bool) {
        var degrees = atan2(Double(dy), Double(dx)) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        if degrees < 90 { degrees += 360 }
        let value = ((degrees - InputWheelMetrics.arcStart) / InputWheelMetrics.arcSweep).clamped(to: 0...1)
        withAnimation(animated ? .spring(response: 0.35, dampingFraction: 0.8) : .interactiveSpring(response: 0.12, dampingFraction: 0.9)) {
            brightness = max(CGFloat(value), 0.12)
        }
    }

    private func liftLoupe() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { loupe = 1 }
    }

    private func release() {
        guard mode != nil || loupe != 0 else { return }
        if mode != nil { Haptics.tap(.soft) }
        mode = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { loupe = 0 }
    }

    private func play() {
        guard !touching else { return }
        let script: [(Double, CGFloat, CGFloat)] = [(0.9, 0.86, 1), (2.7, 0.55, 0.72), (4.3, 0.9, 1), (5.5, 0.42, 0.9)]
        let target = script[step % script.count]
        step += 1
        playTask?.cancel()
        playTask = Task { @MainActor in
            liftLoupe()
            pick(theta: target.0, radius: target.1, animated: true)
            withAnimation(.smooth(duration: 0.6)) { brightness = target.2 }
            try? await Task.sleep(for: .seconds(0.95))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { loupe = 0 }
        }
    }
}

/// Everything that depends on the picked colour. Animatable, so a polar move re-tints along its arc.
private struct InputWheelOverlay: View, Animatable {
    var angle: Double
    var radius: CGFloat
    var brightness: CGFloat
    var loupe: CGFloat
    let lift: CGFloat
    let loupeSize: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<Double, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(angle, radius), AnimatablePair(brightness, loupe)) }
        set {
            angle = newValue.first.first
            radius = newValue.first.second
            brightness = newValue.second.first
            loupe = newValue.second.second
        }
    }

    private var hue: Double {
        let turns = angle / (2 * .pi)
        return turns - floor(turns)
    }

    private var saturation: Double { Double(min(max(radius, 0), 1)) }
    private var value: Double { Double(min(max(brightness, 0), 1)) }

    var body: some View {
        let picked = Color(hue: hue, saturation: saturation, brightness: value)
        let full = Color(hue: hue, saturation: saturation, brightness: 1)
        let discRadius = InputWheelMetrics.disc / 2
        let reach = discRadius * min(max(radius, 0), 1)
        let point = CGSize(width: cos(angle) * reach, height: sin(angle) * reach)
        return ZStack {
            Circle()
                .fill(Color.black.opacity((1 - value) * 0.82))
                .frame(width: InputWheelMetrics.disc, height: InputWheelMetrics.disc)
            brightnessRing(full: full)
            swatch(picked)
            Circle()
                .strokeBorder(Color.white, lineWidth: 2)
                .frame(width: 10, height: 10)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .opacity(Double(min(max(loupe, 0), 1)))
                .offset(point)
            thumb(picked)
                .offset(x: point.width, y: point.height - lift * loupe)
        }
    }

    private func thumb(_ color: Color) -> some View {
        let size = 26 + (loupeSize - 26) * loupe
        return Circle()
            .fill(color)
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
            .frame(width: max(size, 8), height: max(size, 8))
            .shadow(color: .black.opacity(0.28), radius: 4 + 8 * max(loupe, 0), y: 2 + 6 * max(loupe, 0))
    }

    private func brightnessRing(full: Color) -> some View {
        let start = InputWheelMetrics.arcStart
        let sweep = InputWheelMetrics.arcSweep
        let dark = Color(hue: hue, saturation: saturation, brightness: 0.1)
        let ringRadius = InputWheelMetrics.ringRadius
        let knobAngle = (start + sweep * value) * .pi / 180
        return ZStack {
            InputWheelArc(start: start, sweep: sweep)
                .stroke(Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: InputWheelMetrics.ringWidth + 3, lineCap: .round))
            InputWheelArc(start: start, sweep: sweep)
                .stroke(
                    AngularGradient(colors: [dark, full], center: .center, startAngle: .degrees(start), endAngle: .degrees(start + sweep)),
                    style: StrokeStyle(lineWidth: InputWheelMetrics.ringWidth, lineCap: .butt)
                )
            cap(dark, at: start)
            cap(full, at: start + sweep)
            Circle()
                .fill(Color(hue: hue, saturation: saturation, brightness: value))
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .offset(x: cos(knobAngle) * ringRadius, y: sin(knobAngle) * ringRadius)
        }
        .frame(width: ringRadius * 2, height: ringRadius * 2)
    }

    private func cap(_ color: Color, at degrees: Double) -> some View {
        let radians = degrees * .pi / 180
        return Circle()
            .fill(color)
            .frame(width: InputWheelMetrics.ringWidth, height: InputWheelMetrics.ringWidth)
            .offset(x: cos(radians) * InputWheelMetrics.ringRadius, y: sin(radians) * InputWheelMetrics.ringRadius)
    }

    private func swatch(_ color: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                .frame(width: 16, height: 16)
            Text(verbatim: hex)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Palette.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        .offset(y: InputWheelMetrics.ringRadius + 4)
    }

    private var hex: String {
        let h = hue * 6
        let c = value * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = value - c
        let rgb: (Double, Double, Double)
        switch Int(h) {
        case 0: rgb = (c, x, 0)
        case 1: rgb = (x, c, 0)
        case 2: rgb = (0, c, x)
        case 3: rgb = (0, x, c)
        case 4: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        func channel(_ v: Double) -> Int { Int(((v + m) * 255).rounded()).clamped(to: 0...255) }
        return String(format: "#%02X%02X%02X", channel(rgb.0), channel(rgb.1), channel(rgb.2))
    }
}

private struct InputWheelArc: Shape {
    let start: Double
    let sweep: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: .degrees(start),
            endAngle: .degrees(start + sweep),
            clockwise: false
        )
        return path
    }
}
