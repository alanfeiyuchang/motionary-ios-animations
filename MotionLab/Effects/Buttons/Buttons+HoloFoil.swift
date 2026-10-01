import SwiftUI

extension Effect {
    static let buttonsHoloFoil = Effect(
        id: "buttons.holo-foil",
        category: .buttons,
        interaction: .gesture,
        name: L("Holographic Foil", "镭射箔按钮"),
        summary: L(
            "An iridescent foil button whose rainbow sheen and glitter shift with the finger and flash on press.",
            "镭射箔质感的按钮：彩虹光泽与闪点随手指变换，按下时整片闪亮。"
        ),
        prompt: L(
            "A 244 × 68 pt near-black capsule laminated with holographic foil. Two systems of soft rainbow streaks cross it at different angles over a hairline grating and slide in opposite directions, so hues travel through each streak as the viewing angle changes; about sixty tiny four-point glints twinkle in turn, and a soft specular bar lies across the pill under a rainbow rim. Idle, the foil drifts slowly. Dragging across the button moves the light: the streak angle swings up to ±35°, the bands slide half a period, the specular bar tracks the finger and the pill tilts up to 8° in 3D toward the touch, all on one spring (response 0.3 s, damping 0.75), while the rainbow strengthens from 55% to full. Lifting on the button flashes the foil: a bright bar sweeps across in 0.55 s and the pill dips to 96% and rebounds with a medium haptic.",
            "244×68pt 的近黑色胶囊，表面覆着镭射箔。两组柔和的彩虹光条以不同角度交叠在细密的光栅纹上，朝相反方向滑动，色相随视角在光条中流动；约六十个四角闪点依次闪烁，一道柔和高光横过胶囊，外圈是彩虹描边。静止时箔面缓缓流动。拖动即可移动光源：光条角度最多摆动 ±35°，滑动半个周期，高光跟随手指，胶囊向触点做最多 8° 的 3D 倾斜，全部由同一弹簧（响应 0.3 秒、阻尼 0.75）驱动，彩虹强度从 55% 升到饱满。在按钮上抬手，一道亮带在 0.55 秒内扫过，胶囊压到 96% 再回弹，伴随中等触感。"
        ),
        implementation: L(
            "An Animatable face takes a unit light vector and an energy value: two periodic rainbow LinearGradient strips, each masked by wider soft streaks, are rotated and offset from them (the second in plusLighter), a Canvas draws glints whose brightness is a sharpened sine of position·light, and rotation3DEffect tilts the pill. A TimelineView supplies the idle drift; a keyframeAnimator plays the press flash.",
            "Animatable 的按钮面接收单位光源向量与能量值：两条周期性的彩虹 LinearGradient 各自被更宽的柔和光条遮罩，并据此旋转与偏移（第二条用 plusLighter 混合），Canvas 绘制闪点，其亮度是“位置·光向”的锐化正弦，rotation3DEffect 负责倾斜。TimelineView 提供静止时的流动，keyframeAnimator 播放按下的闪光。"
        ),
        apis: ["Animatable", "LinearGradient", "mask", "blendMode(.plusLighter)", "Canvas", "rotation3DEffect"],
        tags: ["holographic", "foil", "iridescent", "rainbow", "镭射", "全息", "彩虹", "流光"],
        params: [
            .slider("bands", L("Rainbow bands", "彩虹光带数"), 1...4, default: 2, decimals: 1),
            .slider("intensity", L("Foil intensity", "箔面强度"), 0.3...1.0, default: 0.8),
            .slider("tilt", L("3D tilt", "3D 倾斜"), 0...14, default: 8, decimals: 0, unit: "°"),
            .slider("drift", L("Idle drift", "静止流速"), 0...1, default: 0.35),
        ]
    ) { ctx in
        ButtonHoloDemo(ctx: ctx)
    }
}

private struct ButtonHoloDemo: View {
    let ctx: DemoContext
    /// Unit light vector relative to the button centre (−1…1 on each axis).
    @State private var light = CGSize.zero
    @State private var energy: CGFloat = 0
    @State private var flashes = 0
    @State private var step = 0
    @State private var introTask: Task<Void, Never>?
    @GestureState private var touching = false

    private static let size = CGSize(width: 244, height: 68)
    private static let area = CGSize(width: 312, height: 150)
    private static let path: [CGSize] = [
        CGSize(width: 0.9, height: -0.7),
        CGSize(width: 0.2, height: 0.8),
        CGSize(width: -0.9, height: 0.3),
        CGSize(width: -0.3, height: -0.9),
    ]

    private var follow: Animation { .spring(response: 0.3, dampingFraction: 0.75) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                ButtonHoloFace(
                    lightX: light.width,
                    lightY: light.height,
                    energy: ctx.isStill ? 0.6 : energy,
                    time: ctx.isStill ? 3.2 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600),
                    title: ctx.language == .zh ? "领取奖励" : "Claim reward",
                    bands: ctx["bands"],
                    intensity: ctx["intensity"],
                    tilt: ctx["tilt"],
                    drift: ctx["drift"],
                    flashes: flashes,
                    size: Self.size
                )
            }
            .frame(width: Self.area.width, height: Self.area.height)
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
            .onChange(of: touching) { _, isTouching in
                if !isTouching { release() }
            }
            .accessibilityAddTraits(.isButton)
            Spacer()
            DemoHint(text: L("Drag across the foil, then tap it", "在箔面上拖动，再点一下"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.9, delay: 0.3) {
            if ctx.isPreview { stepPreview() } else { playIntro() }
        }
        .onDisappear { stopIntro() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                stopIntro()
                if energy < 1 { Haptics.tap(.soft) }
                withAnimation(follow) {
                    light = lightVector(for: value.location)
                    energy = 1
                }
            }
            .onEnded { value in
                if isOnButton(value.location) {
                    Haptics.tap(.medium)
                    flashes += 1
                }
                release()
            }
    }

    private func lightVector(for point: CGPoint) -> CGSize {
        let x = (point.x - Self.area.width / 2) / (Self.size.width / 2)
        let y = (point.y - Self.area.height / 2) / (Self.size.height / 2)
        return CGSize(width: x.clamped(to: -1...1), height: y.clamped(to: -1...1))
    }

    private func isOnButton(_ point: CGPoint) -> Bool {
        abs(point.x - Self.area.width / 2) < Self.size.width / 2
            && abs(point.y - Self.area.height / 2) < Self.size.height / 2
    }

    private func release() {
        guard energy != 0 || light != .zero else { return }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            light = .zero
            energy = 0
        }
    }

    private func stepPreview() {
        let next = Self.path[step % Self.path.count]
        step += 1
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            light = next
            energy = 1
        }
        if step % 3 == 0 { flashes += 1 }
    }

    private func playIntro() {
        stopIntro()
        introTask = Task { @MainActor in
            for _ in 0..<3 {
                stepPreview()
                try? await Task.sleep(for: .seconds(0.85))
                guard !Task.isCancelled else { return }
            }
            release()
            introTask = nil
        }
    }

    private func stopIntro() {
        introTask?.cancel()
        introTask = nil
    }
}

private enum ButtonHoloPalette {
    static let colors: [Color] = [
        Color(hex: 0xFF5FA2), Color(hex: 0xFFC247), Color(hex: 0x9BE86B),
        Color(hex: 0x21D4A8), Color(hex: 0x3AC4FF), Color(hex: 0xA46BFF),
    ]

    /// `cycles` repeats that end on the first colour, so sliding by one period is seamless.
    static func repeating(_ colors: [Color], cycles: Int) -> [Color] {
        var result: [Color] = []
        for _ in 0..<cycles { result.append(contentsOf: colors) }
        if let first = colors.first { result.append(first) }
        return result
    }
}

private struct ButtonHoloFace: View, Animatable {
    var lightX: CGFloat
    var lightY: CGFloat
    var energy: CGFloat
    let time: Double
    let title: String
    let bands: Double
    let intensity: Double
    let tilt: Double
    let drift: Double
    let flashes: Int
    let size: CGSize

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(lightX, lightY), energy) }
        set {
            lightX = newValue.first.first
            lightY = newValue.first.second
            energy = newValue.second
        }
    }

    /// Idle travel of the bands, in periods.
    private var flow: Double { time * drift * 0.14 }

    var body: some View {
        ZStack {
            Capsule().fill(LinearGradient(colors: [Color(hex: 0x2A2C3A), Color(hex: 0x0D0E13)], startPoint: .top, endPoint: .bottom))
            // Foil = rainbow seen only through soft diagonal streaks. Colours and streaks slide at different
            // rates, so hues travel through each streak as the light moves.
            streaks(
                period: size.width / bands,
                angle: 24 + Double(lightY) * 35 + Double(lightX) * 8,
                shift: Double(lightX) * 0.5 + flow
            )
            .opacity(intensity * (0.55 + 0.45 * Double(energy)))
            // A finer second system at a crossing angle, moving the other way: the interference look.
            streaks(
                period: size.width / bands * 0.46,
                angle: -38 - Double(lightY) * 22,
                shift: -Double(lightX) * 0.8 - flow * 1.7
            )
            .opacity(intensity * 0.5)
            .blendMode(.plusLighter)
            grating
            glints
            specular
            Capsule()
                .fill(LinearGradient(colors: [Color.white.opacity(0.2), .clear], startPoint: .top, endPoint: .center))
                .padding(1.5)
            label
        }
        .frame(width: size.width, height: size.height)
        .clipShape(Capsule())
        .overlay(rim)
        .keyframeAnimator(initialValue: ButtonHoloFlash(), trigger: flashes) { content, flash in
            content
                .overlay { ButtonHoloFlashBar(travel: flash.travel, size: size) }
                .brightness(flash.glow)
                .scaleEffect(flash.scale)
        } keyframes: { _ in
            KeyframeTrack(\.travel) {
                MoveKeyframe(-1)
                CubicKeyframe(1, duration: 0.55)
            }
            KeyframeTrack(\.glow) {
                CubicKeyframe(0.16, duration: 0.12)
                CubicKeyframe(0, duration: 0.43)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.96, duration: 0.09)
                SpringKeyframe(1, duration: 0.5, spring: .bouncy)
            }
        }
        .shadow(color: Palette.violet.opacity(0.25 + 0.25 * Double(energy)), radius: 18, y: 10)
        .rotation3DEffect(.degrees(-tilt * Double(lightY)), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(tilt * Double(lightX)), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }

    /// A rainbow band system masked by wider soft streaks, both rotated to `angle`.
    private func streaks(period: CGFloat, angle: Double, shift: Double) -> some View {
        strip(ButtonHoloPalette.colors, period: period, angle: angle, shift: shift)
            .mask {
                strip([.clear, .white], period: period * 1.7, angle: angle + 9, shift: shift * 0.55 + 0.2)
            }
    }

    /// A seamless periodic gradient strip, rotated to `angle` and slid by `shift` periods.
    private func strip(_ colors: [Color], period: CGFloat, angle: Double, shift: Double) -> some View {
        let cycles = Int((420 / period).rounded(.up)) + 2
        let wrapped = shift - shift.rounded(.down)
        return Rectangle()
            .fill(LinearGradient(colors: ButtonHoloPalette.repeating(colors, cycles: cycles), startPoint: .leading, endPoint: .trailing))
            .frame(width: period * CGFloat(cycles), height: 420)
            .offset(x: (CGFloat(wrapped) - 0.5) * period)
            .rotationEffect(.degrees(angle))
            .frame(width: size.width, height: size.height)
    }

    /// The diffraction grating: hairlines that give the foil its fine grain.
    private var grating: some View {
        Canvas { context, canvas in
            var x: CGFloat = -canvas.height
            var lines = Path()
            while x < canvas.width {
                lines.move(to: CGPoint(x: x, y: canvas.height))
                lines.addLine(to: CGPoint(x: x + canvas.height, y: 0))
                x += 3
            }
            context.stroke(lines, with: .color(Color.white.opacity(0.07)), lineWidth: 0.5)
        }
        .blendMode(.plusLighter)
    }

    private var glints: some View {
        Canvas { context, canvas in
            let lightPhase = Double(lightX) * 3.1 + Double(lightY) * 2.3 + flow * 9
            for index in 0..<60 {
                let seed = Double(index)
                let x = canvas.width * CGFloat(Self.noise(seed, 1))
                let y = canvas.height * CGFloat(Self.noise(seed, 2))
                // Each glint only catches the light at its own angle.
                let facing = sin(Self.noise(seed, 3) * 2 * .pi + lightPhase * (0.6 + Self.noise(seed, 4)))
                let brightness = pow(max(facing, 0), 6) * (0.45 + 0.55 * Double(energy))
                guard brightness > 0.03 else { continue }
                let reach = CGFloat(1.6 + 3.2 * Self.noise(seed, 5)) * CGFloat(0.6 + 0.4 * brightness)
                var star = Path()
                star.move(to: CGPoint(x: x, y: y - reach))
                star.addQuadCurve(to: CGPoint(x: x + reach, y: y), control: CGPoint(x: x, y: y))
                star.addQuadCurve(to: CGPoint(x: x, y: y + reach), control: CGPoint(x: x, y: y))
                star.addQuadCurve(to: CGPoint(x: x - reach, y: y), control: CGPoint(x: x, y: y))
                star.addQuadCurve(to: CGPoint(x: x, y: y - reach), control: CGPoint(x: x, y: y))
                context.fill(star, with: .color(Color.white.opacity(brightness * intensity)))
            }
        }
        .blendMode(.plusLighter)
    }

    private var specular: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(width: 84, height: size.height * 2.4)
            .rotationEffect(.degrees(22))
            .offset(x: lightX * (size.width / 2 - 20) + CGFloat(sin(flow * 5)) * 30 * (1 - energy))
            .opacity(0.28 + 0.34 * Double(energy))
            .blendMode(.plusLighter)
    }

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
            Text(title)
        }
        .font(.headline.weight(.bold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
        .offset(x: -lightX * 2, y: -lightY * 1.5)
    }

    private var rim: some View {
        Capsule()
            .strokeBorder(
                AngularGradient(
                    colors: ButtonHoloPalette.repeating(ButtonHoloPalette.colors, cycles: 1),
                    center: .center,
                    angle: .degrees(Double(lightX) * 120 + Double(lightY) * 60 + flow * 360)
                ),
                lineWidth: 1.5
            )
            .opacity(0.55 + 0.45 * Double(energy))
    }

    /// Cheap deterministic 0…1 noise per (seed, channel).
    private static func noise(_ seed: Double, _ channel: Double) -> Double {
        let value = sin(seed * 12.9898 + channel * 78.233) * 43758.5453
        return value - value.rounded(.down)
    }
}

/// The bright bar that sweeps the foil after a tap.
private struct ButtonHoloFlashBar: View {
    let travel: Double
    let size: CGSize

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(width: 110, height: size.height * 2.4)
            .rotationEffect(.degrees(22))
            .offset(x: CGFloat(travel) * (size.width / 2 + 90))
            .blendMode(.plusLighter)
            .mask(Capsule().frame(width: size.width, height: size.height))
            .allowsHitTesting(false)
    }
}

private struct ButtonHoloFlash {
    var travel: Double = 1
    var glow: Double = 0
    var scale: CGFloat = 1
}
