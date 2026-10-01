import SwiftUI

extension Effect {
    static let buttonsCometBorder = Effect(
        id: "buttons.comet-border",
        category: .buttons,
        interaction: .loop,
        name: L("Comet Border", "彗星描边"),
        summary: L(
            "A comet of light with a fading tail laps the border; pressing makes it race and flare.",
            "一颗拖着渐隐尾巴的光之彗星沿边框环绕；按下时它加速飞驰并迸发耀光。"
        ),
        prompt: L(
            "A 240 × 66 pt rounded button with a dark ink face and a hairline border. A comet travels clockwise around that border, one lap every 3.2 s: a white-hot head with a soft sky-blue halo, and a tapered tail covering 32% of the perimeter that cools from white through sky and violet to transparent pink, drawn crisp over a blurred copy of itself. A faint pool of the comet's light slides across the button face beneath the head, and tiny sparkles shed from the tail and twinkle out within 0.6 s. Pressing the button sinks it to 97% and the comet accelerates smoothly to 3.5× speed while it flares: the head grows about 80%, the tail lengthens by half and the whole rim lights up faintly. On release it eases back to cruising speed over roughly a second. Premium, energetic, alive.",
            "240×66pt 的圆角按钮，墨色表面，带一圈发丝描边。一颗彗星沿描边顺时针环绕，每 3.2 秒一圈：白热的头部带着柔和的天蓝光晕，渐细的尾巴覆盖周长的 32%，颜色由白经天蓝、紫罗兰冷却到透明的粉色，清晰的线条叠在自身的模糊副本之上。彗星的微光在头部下方的按钮表面上滑动；尾部洒落细小星点，闪烁着在 0.6 秒内熄灭。按下按钮时按钮下沉到 97%，彗星平滑加速到 3.5 倍速并迸发：头部增大约 80%，尾巴加长一半，整圈边缘微微亮起。松手后大约一秒内缓缓回到巡航速度。高级、充满能量、富有生命力。"
        ),
        implementation: L(
            "A small reference-type integrator advances the comet's phase each TimelineView frame, easing its speed and flare toward the pressed or cruising target so the phase never jumps. A Canvas trims the border path into graded tail segments (wrapping across the start point), strokes them under a blur layer and again crisp, then draws the head, the reflection and stateless sparkles.",
            "一个引用类型的小积分器在 TimelineView 的每一帧推进彗星相位，并把速度与耀光强度缓动到“按下”或“巡航”的目标值，因此相位不会跳变。Canvas 把边框路径裁成分级的尾巴小段（可跨越起点），先在模糊图层里描一遍，再清晰地描一遍，最后画出头部、表面反光与无状态的星点。"
        ),
        apis: ["TimelineView", "Canvas", "Path.trimmedPath(from:to:)", "GraphicsContext.addFilter(.blur)", "DragGesture"],
        tags: ["comet", "border", "glow", "orbit", "trail", "彗星", "描边", "辉光", "环绕", "尾迹"],
        params: [
            .slider("lap", L("Lap time", "单圈时长"), 1.5...6.0, default: 3.2, decimals: 1, unit: "s"),
            .slider("tail", L("Tail length", "尾巴长度"), 0.1...0.6, default: 0.32),
            .slider("boost", L("Pressed speed", "按下倍速"), 2...6, default: 3.5, decimals: 1, unit: "×"),
            .slider("comets", L("Comets", "彗星数量"), 1...3, default: 1, step: 1, decimals: 0),
        ]
    ) { ctx in
        ButtonCometDemo(ctx: ctx)
    }
}

/// Integrates the comet's phase so speed changes are smooth. A reference type: stepping it never invalidates the view.
private final class ButtonCometMotion {
    var phase: Double
    var speed: Double = 0
    var flare: Double = 0
    private var last: Date?

    init(phase: Double) {
        self.phase = phase
    }

    func step(to date: Date, pressed: Bool, lap: Double, boost: Double) {
        defer { last = date }
        let cruise = 1 / lap
        guard let last else {
            speed = cruise
            return
        }
        let dt = min(date.timeIntervalSince(last), 0.1)
        guard dt > 0 else { return }
        let target = cruise * (pressed ? boost : 1)
        speed += (target - speed) * (1 - exp(-dt * (pressed ? 9 : 2.4)))
        flare += ((pressed ? 1 : 0) - flare) * (1 - exp(-dt * (pressed ? 10 : 3)))
        phase = (phase + speed * dt).truncatingRemainder(dividingBy: 1)
    }
}

private struct ButtonCometDemo: View {
    let ctx: DemoContext
    @State private var motion: ButtonCometMotion
    @State private var pressed = false
    @State private var scriptTask: Task<Void, Never>?

    private static let stage = CGSize(width: 320, height: 150)
    private static let face = CGSize(width: 240, height: 66)

    init(ctx: DemoContext) {
        self.ctx = ctx
        _motion = State(initialValue: ButtonCometMotion(phase: ctx.isStill ? 0.2 : 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            control
            Spacer()
            DemoHint(text: L("Press and hold to make it race", "按住按钮，让它加速"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.4, delay: 1.2) { playScript() }
        .onDisappear { scriptTask?.cancel() }
    }

    private var control: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return ZStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color(hex: 0xC4A0FF))
                Text(ctx.language == .zh ? "升级专业版" : "Upgrade to Pro")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: Self.face.width, height: Self.face.height)
            .background(
                LinearGradient(colors: [Color(hex: 0x23213F), Color(hex: 0x121124)], startPoint: .top, endPoint: .bottom),
                in: shape
            )
            .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: Color(hex: 0x1B1740).opacity(0.35), radius: 14, y: 8)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                let _ = motion.step(to: timeline.date, pressed: pressed, lap: max(ctx["lap"], 0.3), boost: ctx["boost"])
                ButtonCometCanvas(
                    phase: motion.phase,
                    speed: motion.speed,
                    flare: ctx.isStill ? 0.25 : motion.flare,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    face: Self.face,
                    tail: ctx["tail"],
                    comets: min(max(ctx.int("comets"), 1), 3)
                )
            }
            .allowsHitTesting(false)
        }
        .frame(width: Self.stage.width, height: Self.stage.height)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: pressed)
        .contentShape(Rectangle().inset(by: 30))
        .gesture(pressGesture)
        .accessibilityAddTraits(.isButton)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !pressed else { return }
                scriptTask?.cancel()
                pressed = true
                Haptics.tap(.medium)
            }
            .onEnded { _ in
                pressed = false
                Haptics.tap(.light)
            }
    }

    private func playScript() {
        guard !pressed else { return }
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            pressed = true
            try? await Task.sleep(for: .seconds(0.85))
            guard !Task.isCancelled else { return }
            pressed = false
        }
    }
}

private struct ButtonCometCanvas: View {
    let phase: Double
    let speed: Double
    let flare: Double
    let time: Double
    let face: CGSize
    let tail: Double
    let comets: Int

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(
                x: (size.width - face.width) / 2,
                y: (size.height - face.height) / 2,
                width: face.width,
                height: face.height
            )
            let path = Self.loop(in: rect.insetBy(dx: 1.5, dy: 1.5), radius: 20.5)
            let faceShape = Path(roundedRect: rect, cornerRadius: 22, style: .continuous)
            let length = min(tail * (1 + 0.5 * flare), 0.9)

            // The rim lights up faintly while the comet flares.
            if flare > 0.01 {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 6))
                    layer.stroke(path, with: .color(Palette.sky.opacity(0.4 * flare)), lineWidth: 4)
                }
            }
            for index in 0..<comets {
                let head = (phase + Double(index) / Double(comets)).truncatingRemainder(dividingBy: 1)
                let point = Self.point(on: path, at: head)
                drawReflection(&context, clip: faceShape, at: point)
                drawSparkles(&context, path: path, head: head, length: length, slot: index)
                drawTail(&context, path: path, head: head, length: length)
                drawHead(&context, at: point)
            }
        }
    }

    /// The border as one closed path that starts at the top centre and runs clockwise.
    private static func loop(in rect: CGRect, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }

    private static func wrap(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }

    private static func point(on path: Path, at fraction: Double) -> CGPoint {
        path.trimmedPath(from: 0, to: max(wrap(fraction), 0.0001)).currentPoint ?? .zero
    }

    /// A piece of the loop between two fractions that may straddle the start point.
    private static func piece(of path: Path, from: Double, to: Double) -> Path {
        let a = wrap(from)
        let b = a + (to - from)
        if b <= 1 { return path.trimmedPath(from: a, to: b) }
        var joined = path.trimmedPath(from: a, to: 1)
        joined.addPath(path.trimmedPath(from: 0, to: b - 1))
        return joined
    }

    private func drawTail(_ context: inout GraphicsContext, path: Path, head: Double, length: Double) {
        let segments = 18
        func strokeSegments(_ target: inout GraphicsContext, width: CGFloat) {
            for index in 0..<segments {
                let a = head - length + length * Double(index) / Double(segments)
                let b = head - length + length * Double(index + 1) / Double(segments)
                let heat = Double(index + 1) / Double(segments)
                let color = Palette.pink
                    .mix(with: Palette.violet, by: min(heat * 2.2, 1))
                    .mix(with: Palette.sky, by: max(min((heat - 0.4) * 2.5, 1), 0))
                    .mix(with: .white, by: max(heat - 0.8, 0) * 5)
                target.stroke(
                    Self.piece(of: path, from: a, to: b),
                    with: .color(color.opacity(heat * heat)),
                    style: StrokeStyle(lineWidth: width * (0.3 + 0.7 * heat), lineCap: .round)
                )
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 6 + 3 * flare))
            strokeSegments(&layer, width: 8 + 4 * flare)
        }
        strokeSegments(&context, width: 3)
    }

    private func drawHead(_ context: inout GraphicsContext, at point: CGPoint) {
        let halo = CGFloat(13 * (1 + 0.8 * flare))
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - halo, y: point.y - halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.9), Palette.sky.opacity(0.45), .clear]),
                center: point,
                startRadius: 0,
                endRadius: halo
            )
        )
        let core = CGFloat(2.6 * (1 + 0.5 * flare))
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - core, y: point.y - core, width: core * 2, height: core * 2)),
            with: .color(.white)
        )
    }

    /// A pool of the comet's light on the button face, clipped to the face.
    private func drawReflection(_ context: inout GraphicsContext, clip: Path, at point: CGPoint) {
        context.drawLayer { layer in
            layer.clip(to: clip)
            let radius = CGFloat(58 * (1 + 0.3 * flare))
            layer.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [Palette.sky.opacity(0.2 + 0.18 * flare), Palette.violet.opacity(0.07), .clear]),
                    center: point,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }

    /// Sparkles are stateless: slot `n` was shed at time `n / rate` from where the head was then.
    private func drawSparkles(_ context: inout GraphicsContext, path: Path, head: Double, length: Double, slot: Int) {
        let rate = 12.0 + 22.0 * flare
        let life = 0.6
        let newest = Int((time * rate).rounded(.down))
        for index in 0..<Int(life * rate) {
            let n = newest - index
            let age = time - Double(n) / rate
            guard age >= 0, age < life else { continue }
            let home = Self.point(on: path, at: head - speed * age - 0.01)
            let angle = Self.hash(n + slot * 97, 1) * 2 * .pi
            let drift = 4 + 12 * Self.hash(n + slot * 97, 2)
            let x = home.x + CGFloat(cos(angle) * drift * age / life)
            let y = home.y + CGFloat(sin(angle) * drift * age / life)
            let fade = 1 - age / life
            let twinkle = 0.6 + 0.4 * sin(time * 30 + Double(n))
            let radius = CGFloat(0.5 + 0.9 * Self.hash(n, 3)) * CGFloat(0.4 + 0.6 * fade)
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Palette.sky.mix(with: .white, by: 0.6).opacity(fade * twinkle))
            )
        }
    }

    private static func hash(_ value: Int, _ channel: Int) -> Double {
        let x = sin(Double(value) * 12.9898 + Double(channel) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }
}
