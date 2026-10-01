import SwiftUI

extension Effect {
    static let loadingLaunchButton = Effect(
        id: "loading.launch-button",
        category: .loading,
        interaction: .tap,
        name: L("Launch Button", "起飞发送按钮"),
        summary: L("The paper plane leaves the button, arcs over it on a dotted trail and lands as a check.", "纸飞机飞离按钮，拖着虚线尾迹划过上方，落回另一端变成对勾。"),
        prompt: L(
            "A 230 × 58 pt indigo → violet capsule reads 'Send', with a white paper plane in its leading slot. On tap the button recoils 0.96 → 1.03 → 1 and the plane tips onto its heading on a spring (response 0.25 s, damping 0.6). After 160 ms it takes off along a cubic arc that peaks 70 pt above the button and comes down on the trailing slot, 1.4 s on a (0.45, 0, 0.55, 1) curve: it banks with the tangent, grows 35% at the apex, turns violet outside the button and drags a dotted trail that fades toward its tail. Below, a translucent fill tracks the flight and the label reads 'Sending…'. On landing the plane shrinks into a check that springs in, the capsule turns green, six sparks fly, a success haptic fires. Playful, legible, rewarding.",
            "一枚 230 × 58 pt 的靛蓝 → 紫罗兰胶囊写着“发送”，左端停着白色纸飞机。点击后按钮以 0.96 → 1.03 → 1 后坐，飞机以弹簧（响应 0.25 秒、阻尼 0.6）昂头对准航向；160 毫秒后沿三次曲线起飞，最高点在按钮上方 70 pt，落到右端，全程 1.4 秒，曲线 (0.45, 0, 0.55, 1)：机身随切线倾转，在最高点放大 35%，飞出按钮后变紫，拖着渐淡的虚线尾迹。半透明填充与飞行同步推进，文字变为“发送中…”。落地时飞机缩成弹入的对勾，胶囊变绿，六颗火花迸出，伴随成功触感。俏皮、清晰。"
        ),
        implementation: L(
            "One animated value t drives everything: an Animatable view places the plane on a cubic Bézier and rotates it to the tangent, an animatable Shape strokes the trail behind it, and the fill's width is t × the button width.",
            "一个动画值 t 驱动全部：Animatable 视图把飞机放到三次贝塞尔曲线上并按切线旋转，可动画的 Shape 描出它身后的尾迹，填充宽度等于 t × 按钮宽度。"
        ),
        apis: ["Animatable", "Shape.animatableData", "timingCurve(_:_:_:_:duration:)", "keyframeAnimator", "ButtonStyle"],
        tags: ["send", "paper plane", "launch", "trail", "发送", "纸飞机", "起飞", "尾迹"],
        params: [
            .slider("flight", L("Flight time", "飞行时长"), 0.8...2.5, default: 1.4, decimals: 1, unit: "s"),
            .slider("arc", L("Arc height", "弧线高度"), 30...110, default: 70, decimals: 0, unit: "pt"),
            .toggle("trail", L("Dotted trail", "虚线尾迹"), default: true),
        ]
    ) { ctx in
        LaunchButtonDemo(ctx: ctx)
    }
}

/// The flight path, in points relative to the button's centre.
private struct LaunchPath {
    let arc: CGFloat

    static let slot: CGFloat = 86

    private var p0: CGPoint { CGPoint(x: -LaunchPath.slot, y: 0) }
    // A cubic's apex sits at 3/4 of its control height, so the controls go 4/3 above the wanted peak.
    private var p1: CGPoint { CGPoint(x: -46, y: -arc * 4 / 3) }
    private var p2: CGPoint { CGPoint(x: 52, y: -arc * 4 / 3) }
    private var p3: CGPoint { CGPoint(x: LaunchPath.slot, y: 0) }

    func point(_ t: Double) -> CGPoint {
        let u: CGFloat = CGFloat(min(max(t, 0), 1))
        let v: CGFloat = 1 - u
        let a: CGFloat = v * v * v
        let b: CGFloat = 3 * v * v * u
        let c: CGFloat = 3 * v * u * u
        let d: CGFloat = u * u * u
        return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x, y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }

    /// Heading in degrees (0 = right, positive = clockwise on screen).
    func heading(_ t: Double) -> Double {
        let u: CGFloat = CGFloat(min(max(t, 0), 1))
        let v: CGFloat = 1 - u
        let dx: CGFloat = 3 * v * v * (p1.x - p0.x) + 6 * v * u * (p2.x - p1.x) + 3 * u * u * (p3.x - p2.x)
        let dy: CGFloat = 3 * v * v * (p1.y - p0.y) + 6 * v * u * (p2.y - p1.y) + 3 * u * u * (p3.y - p2.y)
        return Double(atan2(dy, dx)) * 180 / .pi
    }
}

/// A stretch of the path that ends `lag` behind the plane and is `length` long (in path parameter).
private struct LaunchTrail: Shape {
    var head: Double
    let lag: Double
    let length: Double
    let arc: CGFloat

    var animatableData: Double {
        get { head }
        set { head = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let flight = LaunchPath(arc: arc)
        let to: Double = max(head - lag, 0)
        let from: Double = max(to - length, 0)
        var path = Path()
        guard to - from > 0.004 else { return path }
        let steps: Int = 14
        for step in 0...steps {
            let t: Double = from + (to - from) * Double(step) / Double(steps)
            let p = flight.point(t)
            let point = CGPoint(x: rect.midX + p.x, y: rect.midY + p.y)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

private struct LaunchPlane: View, Animatable {
    var t: Double
    var aim: Double
    let arc: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(t, aim) }
        set {
            t = newValue.first
            aim = newValue.second
        }
    }

    var body: some View {
        let flight = LaunchPath(arc: arc)
        let point = flight.point(t)
        // The glyph points up and to the right (-45°) when it is not rotated.
        let turn: Double = (flight.heading(t) + 45) * aim
        let outside: Double = Double(((-point.y - 24) / 12).clamped(to: 0...1))
        Image(systemName: "paperplane.fill")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(Color.white.mix(with: Palette.violet, by: outside))
            .shadow(color: Palette.violet.opacity(0.5 * outside), radius: 6, y: 3)
            .rotationEffect(.degrees(turn))
            .scaleEffect(1 + 0.35 * CGFloat(sin(.pi * min(max(t, 0), 1))))
            .offset(x: point.x, y: point.y)
    }
}

/// The dotted trail: three overlapping stretches, each fainter than the one ahead of it. Animatable, so the
/// fade at both ends of the flight follows the in-flight value of `t`, not its target.
private struct LaunchTrailView: View, Animatable {
    var t: Double
    let flying: Bool
    let arc: CGFloat

    var animatableData: Double {
        get { t }
        set { t = newValue }
    }

    var body: some View {
        let fade: Double = flying ? min(t * 8, 1) * min((1 - t) * 6, 1) : 0
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                LaunchTrail(head: t, lag: 0.04 + 0.12 * Double(index), length: 0.12, arc: arc)
                    .stroke(
                        index == 0 ? Palette.pink : Palette.violet,
                        style: StrokeStyle(lineWidth: 3 - 0.5 * CGFloat(index), lineCap: .round, dash: [0.5, 7])
                    )
                    .opacity(0.95 - 0.3 * Double(index))
            }
        }
        .opacity(fade)
    }
}

/// Six sparks that fly out of the landing slot.
private struct LaunchSparks: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let eased: CGFloat = CGFloat(1 - pow(1 - progress, 3))
        let r: CGFloat = 2.6 * CGFloat(1 - progress) + 0.4
        for index in 0..<6 {
            let angle: Double = -.pi * (0.12 + 0.76 * Double(index) / 5)
            let distance: CGFloat = 16 + 26 * eased * (index % 2 == 0 ? 1 : 0.7)
            let x: CGFloat = center.x + distance * CGFloat(cos(angle))
            let y: CGFloat = center.y + distance * CGFloat(sin(angle))
            path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        return path
    }
}

private enum LaunchState {
    case idle
    case flying
    case done
}

private struct LaunchButtonDemo: View {
    let ctx: DemoContext
    @State private var state: LaunchState
    @State private var t: Double
    @State private var aim: Double
    @State private var entering = false
    @State private var sparks = false
    @State private var kicks = 0
    @State private var pops = 0
    @State private var task: Task<Void, Never>?

    private let width: CGFloat = 230
    private let height: CGFloat = 58

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills show the plane in mid-flight with its trail.
        _state = State(initialValue: ctx.isStill ? .flying : .idle)
        _t = State(initialValue: ctx.isStill ? 0.56 : 0)
        _aim = State(initialValue: ctx.isStill ? 1 : 0)
    }

    var body: some View {
        let arc: CGFloat = ctx.cg("arc")
        VStack(spacing: 22) {
            ZStack {
                Button(action: tap) { face }
                    .buttonStyle(LaunchPressStyle())
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: kicks) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.self) {
                            CubicKeyframe(0.96, duration: 0.09)
                            SpringKeyframe(1.03, duration: 0.16, spring: .snappy)
                            SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                        }
                    }
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.self) {
                            CubicKeyframe(1.05, duration: 0.12)
                            SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                        }
                    }
                if ctx.bool("trail") {
                    LaunchTrailView(t: t, flying: state == .flying, arc: arc)
                        .frame(width: width, height: height)
                        .allowsHitTesting(false)
                }
                LaunchPlane(t: t, aim: aim, arc: arc)
                    .scaleEffect(state == .done ? 0.2 : (entering ? 0.5 : 1))
                    .opacity(state == .done || entering ? 0 : 1)
                    .offset(x: entering ? -28 : 0)
                    .allowsHitTesting(false)
                LaunchSparks(progress: sparks ? 1 : 0)
                    .fill(Palette.amber)
                    .frame(width: 100, height: 100)
                    .opacity(sparks ? 0 : (state == .done ? 1 : 0))
                    .offset(x: LaunchPath.slot)
                    .allowsHitTesting(false)
            }
            .frame(width: width, height: height)
            // Room for the flight above the button.
            .padding(.top, 118)
            DemoHint(text: L("Tap the button", "点击按钮"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Only an idle button is tapped, so a flight is never cut short; the button resets itself after landing.
        .autoplay(ctx.isPreview, every: 1.0, delay: 0.6) {
            if state == .idle { tap() }
        }
        .onDisappear {
            task?.cancel()
            task = nil
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                state = .idle
                t = 0
                aim = 0
                sparks = false
                entering = false
            }
        }
    }

    private var title: String {
        let zh = ctx.language == .zh
        switch state {
        case .idle: return zh ? "发送" : "Send"
        case .flying: return zh ? "发送中…" : "Sending…"
        case .done: return zh ? "已发送" : "Sent"
        }
    }

    private var face: some View {
        let done: Bool = state == .done
        return ZStack(alignment: .leading) {
            Capsule().fill(Palette.primaryStrong)
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: width * CGFloat(min(max(t, 0), 1)))
                .opacity(state == .flying ? 1 : 0)
            // successStrong keeps the white label above 4.5:1.
            Capsule().fill(Palette.successStrong).opacity(done ? 1 : 0)
            Capsule()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .frame(width: width)
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(done ? 1 : 0.2)
                .opacity(done ? 1 : 0)
                .frame(width: width, alignment: .center)
                .offset(x: LaunchPath.slot)
        }
        .frame(width: width, height: height)
        .clipShape(Capsule())
        .shadow(color: (done ? Palette.green : Palette.indigo).opacity(0.35), radius: 14, y: 8)
    }

    private func tap() {
        switch state {
        case .flying:
            return
        case .done:
            task?.cancel()
            reset()
            return
        case .idle:
            break
        }
        if !ctx.isPreview { Haptics.tap(.medium) }
        kicks += 1
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { sparks = false }
        withAnimation(.smooth(duration: 0.3)) { state = .flying }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { aim = 1 }
        let duration: Double = max(ctx["flight"], 0.3)
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let loops: Bool = ctx.isPreview
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.45, 0, 0.55, 1, duration: duration)) { t = 1 }
            try? await Task.sleep(for: .seconds(duration - 0.06))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) { state = .done }
            withAnimation(.easeOut(duration: 0.55)) { sparks = true }
            pops += 1
            if buzz { Haptics.success() }
            // Hold the result, then hand the button back with a fresh plane.
            try? await Task.sleep(for: .seconds(loops ? 1.5 : 2.2))
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    /// Back to idle: the check leaves and a fresh plane springs into the leading slot.
    private func reset() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            t = 0
            aim = 0
            entering = true
        }
        withAnimation(.smooth(duration: 0.3)) { state = .idle }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.1)) { entering = false }
    }
}

private struct LaunchPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
