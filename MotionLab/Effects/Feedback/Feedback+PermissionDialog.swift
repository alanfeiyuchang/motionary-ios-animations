import SwiftUI

// MARK: - Permission dialog

extension Effect {
    static let feedbackPermissionDialog = Effect(
        id: "feedback.permission-dialog",
        category: .feedback,
        interaction: .tap,
        name: L("Permission Prompt", "权限请求弹窗"),
        summary: L("A permission prompt whose icon acts out the request, whose buttons rise in one after another, and which shrinks into a small result pill once you choose.", "权限弹窗里的图标把请求“演”出来，按钮依次升起；做出选择后，弹窗收缩成一枚结果小胶囊。"),
        prompt: L(
            "Over a dimmed, slightly blurred page a 248 × 214 pt dialog with 28 pt corners scales in from 86% out of an 8 pt blur on a spring (response 0.45 s, damping 0.72). Its icon tile acts out the request: the bell swings ±20° from its top in a decaying ring while a red dot pops and two sound arcs flash, repeating every 2.4 s; for location, the pin hops and two radar rings spread beneath it. Title, message and both buttons rise 14 pt and fade in, staggered 70 ms. Choosing presses the button to 96%, then the same surface contracts to a 196 × 48 pt pill: a green check and 'Notifications on', or a grey slashed bell and 'Maybe later', blur-replacing the content with a success haptic. After 1.3 s the pill drops 26 pt and fades as the page clears.",
            "压暗模糊的页面上，248 × 214 pt、圆角 28 pt 的弹窗从 86%、8 pt 模糊中放大清晰（弹簧响应 0.45 秒、阻尼 0.72）。图标演出请求：铃铛绕顶部摆动 ±20°，红点弹出，两侧闪过声波，每 2.4 秒重复；位置权限则是定位针一跳，脚下扩散两圈波纹。标题、说明与两枚按钮依次上浮 14 pt 淡入，间隔 70 毫秒。选择时按钮压到 96%，同一块表面收缩成 196 × 48 pt 的胶囊：绿色对勾加“通知已开启”，或灰色划线铃铛加“以后再说”，内容模糊替换并伴随成功触感。1.3 秒后胶囊下落 26 pt 淡出。"
        ),
        implementation: L(
            "The enum of what the surface shows sets its frame and corner radius inside a spring, so dialog and result pill are the same view; their contents swap with a blurReplace transition. The bell is a keyframeAnimator on rotation anchored at the top, retriggered by a looping task; entrance rows use per-index delayed springs.",
            "表示“表面当前内容”的枚举在弹簧中设定它的尺寸与圆角，因此弹窗与结果胶囊是同一个视图，内容以 blurReplace 转场互换。铃铛是以顶部为锚点的旋转 keyframeAnimator，由循环任务反复触发；入场的各行使用按序号递增延迟的弹簧。"
        ),
        apis: ["keyframeAnimator(initialValue:trigger:)", "transition(.blurReplace)", "spring(response:dampingFraction:)", "ButtonStyle", "symbolEffect(.bounce)"],
        tags: ["permission", "dialog", "notifications", "location", "prompt", "权限", "弹窗", "通知", "定位", "授权"],
        params: [
            .choice("kind", L("Permission", "权限类型"), [L("Notifications", "通知"), L("Location", "位置")]),
            .slider("stagger", L("Entrance stagger", "入场间隔"), 0.02...0.16, default: 0.07, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.72),
        ]
    ) { ctx in
        PermissionDialogDemo(ctx: ctx)
    }
}

/// What the surface currently shows; it keeps showing it while it leaves.
private enum PermissionFace: Equatable {
    case question
    case result(allowed: Bool)
}

private struct PermissionDialogDemo: View {
    let ctx: DemoContext
    @State private var visible: Bool
    @State private var face: PermissionFace = .question
    /// Rows of the dialog have risen in.
    @State private var settled: Bool
    @State private var rings = 0
    /// The button a scripted choice is pressing (0 = allow, 1 = not now).
    @State private var forced: Int?
    @State private var autoAllow = true
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the prompt.
        _visible = State(initialValue: ctx.isStill)
        _settled = State(initialValue: ctx.isStill)
    }

    private var zh: Bool { ctx.language == .zh }
    private var location: Bool { ctx.int("kind") == 1 }
    private var asking: Bool { visible && face == .question }
    private var surfaceSpring: Animation { .spring(response: 0.45, dampingFraction: ctx["damping"]) }

    var body: some View {
        let covered: Bool = visible
        VStack(spacing: 14) {
            ZStack {
                page
                    .blur(radius: covered ? 3 : 0)
                    .overlay(Color.black.opacity(covered ? 0.32 : 0))
                surface
            }
            .feedbackScene(height: 276)
            DemoHint(text: L("Choose an answer", "选一个回答"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.5, delay: 0.5) { step() }
        .task(id: asking) {
            // The icon repeats its little act while the question is open.
            guard asking, !ctx.isStill else { return }
            try? await Task.sleep(for: .seconds(0.45))
            while !Task.isCancelled {
                rings += 1
                try? await Task.sleep(for: .seconds(2.4))
            }
        }
    }

    private var page: some View {
        VStack(spacing: 0) {
            FeedbackMockHeader(title: zh ? "订单" : "Orders", symbol: location ? "location.fill" : "bell.fill")
            FeedbackMockRows(count: 3, rowHeight: 48)
            Spacer(minLength: 0)
            Button(action: present) {
                Text(location ? (zh ? "查找附近门店" : "Find stores nearby") : (zh ? "开启发货提醒" : "Turn on shipping alerts"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 268, height: 42)
                    .background(Palette.primaryStrong, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)
        }
        .frame(width: 300, height: 276)
    }

    // MARK: Surface

    private var surface: some View {
        let question: Bool = face == .question
        let hidden: Bool = !visible
        let size: CGSize = question ? CGSize(width: 248, height: 214) : CGSize(width: 196, height: 48)
        let shape = RoundedRectangle(cornerRadius: question ? 28 : 24, style: .continuous)
        return ZStack {
            switch face {
            case .question:
                dialog
                    .transition(.blurReplace)
            case .result(let allowed):
                resultPill(allowed)
                    .transition(.blurReplace)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(shape.fill(Palette.elevated))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
        // Enters small and blurred as the question; leaves as the pill, dropping away.
        .scaleEffect(hidden ? (question ? 0.86 : 0.94) : 1)
        .blur(radius: hidden ? 8 : 0)
        .opacity(hidden ? 0 : 1)
        .offset(y: hidden && !question ? 26 : 0)
        .allowsHitTesting(asking)
    }

    private var dialog: some View {
        VStack(spacing: 0) {
            PermissionIcon(location: location, rings: rings)
                .frame(width: 56, height: 56)
                .padding(.top, 20)
            Text(location ? (zh ? "允许使用你的位置？" : "Use your location?") : (zh ? "允许发送通知？" : "Allow notifications?"))
                .font(.headline)
                .padding(.top, 12)
                .modifier(rise(0))
            Text(location ? (zh ? "用于查找附近门店和预计送达时间。" : "To find nearby stores and delivery times.") : (zh ? "订单发货时提醒你，绝不打扰。" : "We'll ping you when an order ships. No spam."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 204, height: 36)
                .padding(.top, 2)
                .modifier(rise(1))
            HStack(spacing: 8) {
                Button { choose(false) } label: {
                    Text(zh ? "以后再说" : "Not now")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                .buttonStyle(PermissionPressStyle(forced: forced == 1))
                .modifier(rise(2))
                Button { choose(true) } label: {
                    Text(zh ? "允许" : "Allow")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Palette.primaryStrong, in: Capsule())
                }
                .buttonStyle(PermissionPressStyle(forced: forced == 0))
                .modifier(rise(3))
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .frame(width: 248, height: 214)
    }

    private func resultPill(_ allowed: Bool) -> some View {
        let title: String
        if allowed {
            title = location ? (zh ? "位置已开启" : "Location on") : (zh ? "通知已开启" : "Notifications on")
        } else {
            title = zh ? "以后再说" : "Maybe later"
        }
        let symbol: String = allowed ? "checkmark.circle.fill" : (location ? "location.slash.fill" : "bell.slash.fill")
        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(allowed ? Palette.green : Color.secondary)
            Text(verbatim: title)
                .font(.subheadline.weight(.semibold))
        }
        .frame(width: 196, height: 48)
    }

    private func rise(_ index: Int) -> PermissionRise {
        let delay: Double = 0.16 + Double(index) * ctx["stagger"]
        return PermissionRise(shown: settled, animation: settled ? Animation.spring(response: 0.42, dampingFraction: 0.78).delay(delay) : Animation.linear(duration: 0.01))
    }

    // MARK: Actions

    /// Preview loop and intro: ask, then answer (allow and decline alternate).
    private func step() {
        guard visible else {
            present()
            return
        }
        if asking {
            let allow: Bool = autoAllow
            autoAllow.toggle()
            token += 1
            let current = token
            forced = allow ? 0 : 1
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.2))
                forced = nil
                guard token == current, asking else { return }
                choose(allow)
            }
        }
    }

    private func present() {
        guard !visible else { return }
        token += 1
        Haptics.tap()
        // Start from the small, blurred entrance pose (not from where the result pill left).
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            face = .question
            settled = false
        }
        let current = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.03))
            guard token == current else { return }
            withAnimation(surfaceSpring) { visible = true }
            settled = true
        }
    }

    private func choose(_ allowed: Bool) {
        guard asking else { return }
        token += 1
        let current = token
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        if buzz {
            if allowed { Haptics.success() } else { Haptics.tap() }
        }
        withAnimation(surfaceSpring) { face = .result(allowed: allowed) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            guard token == current else { return }
            withAnimation(.easeIn(duration: 0.26)) { visible = false }
        }
    }
}

/// A dialog row rising in after the surface has landed.
private struct PermissionRise: ViewModifier {
    let shown: Bool
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .animation(animation, value: shown)
    }
}

private struct PermissionPressStyle: ButtonStyle {
    let forced: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed: Bool = configuration.isPressed || forced
        return configuration.label
            .scaleEffect(pressed ? 0.96 : 1)
            .brightness(pressed ? -0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
    }
}

// MARK: - Icon

private struct PermissionBell {
    var angle: Double = 0
    var badge: CGFloat = 1
    var waves: Double = 0
}

private struct PermissionPin {
    var lift: CGFloat = 0
    var ring: CGFloat = 0
}

/// The tile that acts out the request: a ringing bell or a hopping pin with radar rings.
private struct PermissionIcon: View {
    let location: Bool
    let rings: Int

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            if location {
                shape.fill(Palette.ocean)
                pin
            } else {
                shape.fill(Palette.sunset)
                bell
            }
        }
        .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: (location ? Palette.blue : Palette.coral).opacity(0.4), radius: 10, y: 5)
    }

    private var bell: some View {
        ZStack {
            Image(systemName: "bell.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
        .keyframeAnimator(initialValue: PermissionBell(), trigger: rings) { content, value in
            ZStack {
                PermissionWaves()
                    .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 50, height: 22)
                    .offset(y: -4)
                    .opacity(value.waves)
                content
                    .rotationEffect(.degrees(value.angle), anchor: UnitPoint(x: 0.5, y: 0.22))
                Circle()
                    .fill(Palette.red)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                    .scaleEffect(value.badge)
                    .offset(x: 10, y: -11)
            }
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                CubicKeyframe(20, duration: 0.09)
                CubicKeyframe(-18, duration: 0.13)
                CubicKeyframe(14, duration: 0.13)
                CubicKeyframe(-10, duration: 0.13)
                CubicKeyframe(6, duration: 0.13)
                CubicKeyframe(-3, duration: 0.13)
                CubicKeyframe(0, duration: 0.14)
            }
            KeyframeTrack(\.badge) {
                CubicKeyframe(0.2, duration: 0.05)
                SpringKeyframe(1, duration: 0.5, spring: Spring(response: 0.3, dampingRatio: 0.45))
            }
            KeyframeTrack(\.waves) {
                LinearKeyframe(1, duration: 0.12)
                LinearKeyframe(1, duration: 0.4)
                LinearKeyframe(0, duration: 0.36)
            }
        }
    }

    private var pin: some View {
        Image(systemName: "mappin")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .keyframeAnimator(initialValue: PermissionPin(), trigger: rings) { content, value in
                ZStack {
                    ForEach(0..<2, id: \.self) { index in
                        let progress: CGFloat = min(max(value.ring - CGFloat(index) * 0.3, 0), 1)
                        Ellipse()
                            .stroke(Color.white.opacity(Double(1 - progress) * 0.9), lineWidth: 1.6)
                            .frame(width: 10 + 34 * progress, height: 4 + 12 * progress)
                            .offset(y: 15)
                    }
                    content
                        .offset(y: value.lift)
                }
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    CubicKeyframe(-9, duration: 0.16)
                    SpringKeyframe(0, duration: 0.5, spring: Spring(response: 0.3, dampingRatio: 0.45))
                }
                KeyframeTrack(\.ring) {
                    MoveKeyframe(0)
                    LinearKeyframe(0, duration: 0.26)
                    CubicKeyframe(1.3, duration: 0.9)
                    MoveKeyframe(0)
                }
            }
    }
}

/// Two short arcs either side of the bell.
private struct PermissionWaves: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: .degrees(160), endAngle: .degrees(200), clockwise: false)
        path.move(to: CGPoint(x: rect.midX + rect.width / 2 * cos(-20 * .pi / 180), y: rect.midY + rect.width / 2 * sin(-20 * .pi / 180)))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: .degrees(-20), endAngle: .degrees(20), clockwise: false)
        return path
    }
}
