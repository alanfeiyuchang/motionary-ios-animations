import SwiftUI

extension Effect {
    static let buttonsSendFly = Effect(
        id: "buttons.send-fly",
        category: .buttons,
        interaction: .tap,
        name: L("Send & Fly", "发送起飞"),
        summary: L(
            "The paper plane winds up, climbs off the button along a curve with a fading trail, and the button turns to Sent.",
            "纸飞机先蓄力，再沿弧线带着渐隐尾迹飞离按钮，按钮随即变成“已发送”。"
        ),
        prompt: L(
            "A 200 × 58 pt gradient “Send” pill with a paper-plane icon. On tap the button dips to 95% and the plane winds up for 100 ms, sliding back 7 pt and tilting 16°. It then launches along a cubic Bézier that climbs steeply for about 80 pt, banks right and exits past the top right, covering the path in 0.7 s with accelerating progress (t^1.6), rotated to the tangent, shrinking to 60% and fading over the final 15%. Behind it a tapered trail covers the last 35% of the travelled path, fading from sky blue to nothing, and the button recoils 4 pt opposite the launch. At 55% of the flight the pill springs to 172 pt wide and turns green: a check mark draws itself in 0.3 s beside “Sent” with a success haptic. After 1.6 s it resets and a plane slides back in.",
            "200×58pt 的渐变“发送”胶囊，带纸飞机。点击时按钮下沉到 95%，飞机蓄力 100 毫秒：后撤 7pt 并仰起 16°。随后沿三次贝塞尔曲线起飞：先陡直爬升约 80pt，再向右压弯，从右上方飞出；全程 0.7 秒，进度按 t 的 1.6 次方加速，机身对准切线，缩小到 60%，在最后 15% 淡出。身后的渐细尾迹覆盖已飞路径的最后 35%，由天蓝渐隐；按钮向反方向后坐 4pt。飞到 55% 时，胶囊弹性收窄到 172pt 并变绿：对勾在 0.3 秒内画出，显示“已发送”，触发成功触感。1.6 秒后复位，纸飞机滑回。"
        ),
        implementation: L(
            "A keyframeAnimator supplies a linear flight clock plus wind-up, press and recoil tracks. The content closure evaluates the cubic Bézier and its derivative for the plane's position and heading, and a Canvas strokes the trail as graded segments of the same curve. A three-case phase drives the pill's width, colour and the trimmed check.",
            "keyframeAnimator 提供线性的飞行时钟，以及蓄力、按压、后坐等轨道。内容闭包对三次贝塞尔及其导数求值，得到飞机的位置与朝向；Canvas 把同一条曲线分段描出渐变尾迹。三态的阶段值驱动胶囊的宽度、颜色与裁剪绘制的对勾。"
        ),
        apis: ["keyframeAnimator", "Canvas", "Shape.trim(from:to:)", "contentTransition", "spring(response:dampingFraction:)"],
        tags: ["send", "paper plane", "fly", "trail", "sent", "发送", "纸飞机", "尾迹", "已发送", "状态"],
        params: [
            .slider("flight", L("Flight time", "飞行时长"), 0.4...1.2, default: 0.7, unit: "s"),
            .slider("curve", L("Climb height", "爬升高度"), 20...140, default: 80, decimals: 0, unit: "pt"),
            .slider("trail", L("Trail length", "尾迹长度"), 0.1...0.6, default: 0.35),
            .slider("hold", L("Reset delay", "复位延迟"), 0.8...3.0, default: 1.6, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        ButtonSendDemo(ctx: ctx)
    }
}

private enum ButtonSendPhase {
    case idle, sending, sent
}

private struct ButtonSendValues {
    /// Linear 0→1 clock of the flight.
    var clock: Double = 0
    var wind: Double = 0
    var press: CGFloat = 1
    var recoil: CGFloat = 0
}

/// The flight path in stage coordinates.
private struct ButtonSendPath {
    let start: CGPoint
    let c1: CGPoint
    let c2: CGPoint
    let end: CGPoint

    init(curve: CGFloat) {
        start = CGPoint(x: 135, y: 168)
        end = CGPoint(x: 338, y: 14)
        c1 = CGPoint(x: start.x + 8, y: start.y - curve)
        c2 = CGPoint(x: end.x - 150, y: end.y + 12)
    }

    func point(_ t: Double) -> CGPoint {
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return CGPoint(
            x: a * start.x + b * c1.x + c * c2.x + d * end.x,
            y: a * start.y + b * c1.y + c * c2.y + d * end.y
        )
    }

    func heading(_ t: Double) -> Double {
        let u = 1 - t
        let dx = 3 * u * u * (c1.x - start.x) + 6 * u * t * (c2.x - c1.x) + 3 * t * t * (end.x - c2.x)
        let dy = 3 * u * u * (c1.y - start.y) + 6 * u * t * (c2.y - c1.y) + 3 * t * t * (end.y - c2.y)
        return atan2(dy, dx)
    }
}

private struct ButtonSendDemo: View {
    let ctx: DemoContext
    @State private var phase: ButtonSendPhase
    @State private var flights = 0
    @State private var task: Task<Void, Never>?

    private static let stage = CGSize(width: 320, height: 250)
    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? .sending : .idle)
    }

    private var flight: Double { max(ctx["flight"], 0.1) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Group {
                if ctx.isStill {
                    scene(Self.stillValues)
                } else {
                    animatedScene
                }
            }
            .frame(width: Self.stage.width, height: Self.stage.height)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap Send", "点击发送"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: flight + ctx["hold"] + 1.3, delay: 0.5) { send(haptics: false) }
        .onDisappear { task?.cancel() }
    }

    private static var stillValues: ButtonSendValues {
        var values = ButtonSendValues()
        values.clock = 0.72
        return values
    }

    private var animatedScene: some View {
        let flight = flight
        let phase = phase
        let language = ctx.language
        let curve = ctx.cg("curve")
        let trail = ctx["trail"]
        let onTap: @MainActor () -> Void = tapped
        return scene(ButtonSendValues())
            .keyframeAnimator(initialValue: ButtonSendValues(), trigger: flights) { _, values in
                ButtonSendScene(values: values, phase: phase, language: language, curve: curve, trail: trail, onTap: onTap)
            } keyframes: { _ in
                KeyframeTrack(\.clock) {
                    LinearKeyframe(0, duration: 0.1)
                    LinearKeyframe(1, duration: flight)
                }
                KeyframeTrack(\.wind) {
                    CubicKeyframe(1, duration: 0.1)
                    CubicKeyframe(0, duration: 0.1)
                }
                KeyframeTrack(\.press) {
                    CubicKeyframe(0.95, duration: 0.1)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.recoil) {
                    LinearKeyframe(0, duration: 0.1)
                    CubicKeyframe(-4, duration: 0.07)
                    SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                }
            }
    }

    private func scene(_ values: ButtonSendValues) -> ButtonSendScene {
        ButtonSendScene(
            values: values,
            phase: phase,
            language: ctx.language,
            curve: ctx.cg("curve"),
            trail: ctx["trail"],
            onTap: tapped
        )
    }

    private func tapped() {
        Haptics.tap(.light)
        send(haptics: true)
    }

    // MARK: Behaviour

    private func send(haptics: Bool) {
        guard phase == .idle else { return }
        task?.cancel()
        phase = .sending
        flights += 1
        let flight = flight
        let hold = ctx["hold"]
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.1 + flight * 0.55))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) { phase = .sent }
            if haptics { Haptics.success() }
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { phase = .idle }
        }
    }
}

/// One frame of the whole scene: trail, pill and the flying plane for the given keyframe values.
private struct ButtonSendScene: View {
    let values: ButtonSendValues
    let phase: ButtonSendPhase
    let language: AppLanguage
    let curve: CGFloat
    let trail: Double
    let onTap: @MainActor () -> Void

    private static let center = CGPoint(x: 160, y: 168)

    var body: some View {
        let path = ButtonSendPath(curve: curve)
        let progress = pow(values.clock, 1.6)
        let airborne = phase == .sending || values.clock > 0.001
        ZStack {
            if airborne, progress > 0.001 {
                ButtonSendTrail(path: path, progress: progress, length: trail)
            }
            Button(action: onTap) {
                ButtonSendPill(phase: phase, language: language)
            }
            .buttonStyle(.plain)
            .scaleEffect(values.press)
            .offset(x: values.recoil, y: -values.recoil * 0.4)
            .position(Self.center)
            if airborne, values.clock < 0.999 {
                plane(path: path, progress: progress)
            }
        }
    }

    private func plane(path: ButtonSendPath, progress: Double) -> some View {
        let point = path.point(progress)
        // The glyph points up-right at rest (−45°), so add 45° to align it with the tangent;
        // the first 12% of the path blends from the wind-up tilt into that heading.
        let heading = path.heading(progress) * 180 / .pi + 45
        let blend = min(progress / 0.12, 1)
        let eased = blend * blend * (3 - 2 * blend)
        let angle = -16 * values.wind * (1 - eased) + heading * eased
        let lifted = min(progress / 0.18, 1)
        return Image(systemName: "paperplane.fill")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(Color.white.mix(with: Palette.sky, by: lifted))
            .shadow(color: Palette.sky.opacity(0.7 * lifted), radius: 6)
            .rotationEffect(.degrees(angle))
            .scaleEffect(1 - 0.4 * progress)
            .opacity(progress > 0.85 ? (1 - progress) / 0.15 : 1)
            .position(x: point.x - 7 * values.wind, y: point.y + 2 * values.wind)
            .allowsHitTesting(false)
    }
}

private struct ButtonSendPill: View {
    let phase: ButtonSendPhase
    let language: AppLanguage

    var body: some View {
        let sent = phase == .sent
        HStack(spacing: 9) {
            ZStack {
                if phase == .idle {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .transition(.offset(x: -30).combined(with: .opacity))
                }
                ButtonSendCheck()
                    .trim(from: 0, to: sent ? 1 : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 18, height: 14)
                    .animation(sent ? .easeOut(duration: 0.3).delay(0.12) : .none, value: sent)
            }
            .frame(width: 24, height: 24)
            Text(title, language)
                .font(.headline)
                .contentTransition(.opacity)
        }
        .foregroundStyle(.white)
        .frame(width: sent ? 172 : 200, height: 58)
        .background {
            ZStack {
                Capsule().fill(Palette.primaryStrong)
                Capsule().fill(Palette.successStrong).opacity(sent ? 1 : 0)
            }
        }
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        )
        .shadow(color: (sent ? Palette.green : Palette.indigo).opacity(0.4), radius: 14, y: 8)
        .contentShape(Capsule())
    }

    private var title: LocalizedText {
        switch phase {
        case .idle: return L("Send", "发送")
        case .sending: return L("Sending", "发送中")
        case .sent: return L("Sent", "已发送")
        }
    }
}

private struct ButtonSendCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// The trail: the last `length` of the travelled curve as graded, tapering segments under a soft glow.
private struct ButtonSendTrail: View {
    let path: ButtonSendPath
    let progress: Double
    let length: Double

    var body: some View {
        Canvas { context, _ in
            let start = max(progress - length, 0)
            guard progress - start > 0.002 else { return }
            // The whole trail thins out as the plane leaves.
            let presence = progress > 0.8 ? (1 - progress) / 0.2 : 1
            let segments = 16
            func stroke(_ target: inout GraphicsContext, width: CGFloat) {
                for index in 0..<segments {
                    let a = start + (progress - start) * Double(index) / Double(segments)
                    let b = start + (progress - start) * Double(index + 1) / Double(segments)
                    let heat = Double(index + 1) / Double(segments)
                    var piece = Path()
                    piece.move(to: path.point(a))
                    piece.addLine(to: path.point(b))
                    target.stroke(
                        piece,
                        with: .color(Palette.indigo.mix(with: Palette.sky, by: heat).opacity(heat * heat * presence)),
                        style: StrokeStyle(lineWidth: width * (0.25 + 0.75 * heat), lineCap: .round)
                    )
                }
            }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                stroke(&layer, width: 8)
            }
            stroke(&context, width: 3.2)
        }
        .allowsHitTesting(false)
    }
}
