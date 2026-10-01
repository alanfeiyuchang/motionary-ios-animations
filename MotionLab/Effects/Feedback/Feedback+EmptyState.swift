import SwiftUI

// MARK: - Empty state

extension Effect {
    static let feedbackEmptyState = Effect(
        id: "feedback.empty-state",
        category: .feedback,
        interaction: .tap,
        name: L("Living Empty State", "有生命的空状态"),
        summary: L("A little ghost floats and blinks over an empty page; tap and it looks your way, glances around, then down at the button, which nudges.", "空页面上漂着一只会眨眼的小幽灵；点一下，它先看向你点的地方，左右张望，再低头看向按钮，按钮随之轻轻一动。"),
        prompt: L(
            "An empty notes screen: a 104 pt ghost hovers above its ground shadow, bobbing 6 pt on a 2.6 s sine while its scalloped hem ripples and the shadow tightens as it rises. It blinks every 3.2 s, the eyes closing to a line for 130 ms, and three small sparkles drift around it. Tapping makes it look toward the touch: the pupils shift up to 7 pt and the body leans 6° on a spring (response 0.4 s, damping 0.6). It then glances to the opposite side, down at the 'New note' button, and back to centre, about 0.5 s per look. As it looks down, the button nudges: scaling to 106%, rocking ±3° twice and settling, while a gloss band sweeps across it. Tapping the button makes the ghost hop 18 pt with happy arched eyes. Charming, never demanding.",
            "空的笔记页上，一只 104 pt 的小幽灵悬在影子上方，以 2.6 秒的正弦上下浮动 6 pt，扇形裙摆随之起伏，升高时影子收紧。它每 3.2 秒眨一次眼（130 毫秒），身边三颗星光缓缓漂动。点击时它看向触点：瞳孔最多偏移 7 pt，身体以弹簧（响应 0.4 秒、阻尼 0.6）倾斜 6°；随后看向另一侧，再低头看“新建笔记”按钮，最后回正，每次约 0.5 秒。低头时按钮轻推：放大到 106%，左右摆动 ±3° 两次后停稳，一道高光扫过。点按钮，小幽灵跳起 18 pt，眼睛弯成开心的弧线。讨喜，但从不催促。"
        ),
        implementation: L(
            "A TimelineView supplies the bob, the hem phase and the blink (a function of time modulo the blink interval); the look direction is ordinary state animated by a spring, so both layers compose. The ghost's body is a Shape with a sine hem; the button's nudge and the hop are keyframeAnimators.",
            "TimelineView 提供浮动、裙摆相位与眨眼（时间对眨眼间隔取模的函数）；视线方向是由弹簧驱动的普通状态，两层动画互相叠加。幽灵的身体是带正弦裙摆的 Shape，按钮的轻推与跳跃由 keyframeAnimator 完成。"
        ),
        apis: ["TimelineView(.animation(minimumInterval:paused:))", "Shape", "SpatialTapGesture", "keyframeAnimator(initialValue:trigger:)", "spring(response:dampingFraction:)"],
        tags: ["empty state", "illustration", "character", "blink", "idle", "空状态", "插画", "角色", "眨眼", "待机"],
        params: [
            .slider("float", L("Float height", "浮动幅度"), 0...14, default: 6, decimals: 0, unit: "pt"),
            .slider("blink", L("Blink interval", "眨眼间隔"), 1.5...6.0, default: 3.2, decimals: 1, unit: "s"),
            .slider("nudge", L("Button nudge every", "按钮轻推间隔"), 2.0...9.0, default: 4.5, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        EmptyStateDemo(ctx: ctx)
    }
}

private struct EmptyStateNudge {
    var scale: CGFloat = 1
    var angle: Double = 0
    var shine: CGFloat = -0.4
}

private struct EmptyStateDemo: View {
    let ctx: DemoContext
    @State private var look: CGSize = .zero
    @State private var happy = false
    @State private var nudges = 0
    @State private var hops = 0
    @State private var token = 0

    private static let ghostCentre = CGPoint(x: 150, y: 86)

    private var zh: Bool { ctx.language == .zh }
    private var live: Bool { !ctx.isPreview && !ctx.isStill }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                    let t: Double = ctx.isStill ? 0.4 : timeline.date.timeIntervalSinceReferenceDate
                    EmptyStateGhost(time: t, float: ctx.cg("float"), blinkEvery: ctx["blink"], look: look, happy: happy)
                }
                .frame(width: 300, height: 168)
                .keyframeAnimator(initialValue: CGFloat(0), trigger: hops) { content, lift in
                    content.offset(y: lift)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(4, duration: 0.1)
                        CubicKeyframe(-18, duration: 0.2)
                        SpringKeyframe(0, duration: 0.5, spring: Spring(response: 0.35, dampingRatio: 0.5))
                    }
                }
                Text(zh ? "这里还空着" : "Nothing here yet")
                    .font(.headline)
                Text(zh ? "写下的第一条笔记会出现在这里" : "Your first note will show up here")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
                cta
                    .padding(.top, 14)
            }
            .frame(width: 300, height: 276)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in lookAround(toward: value.location) })
            DemoHint(text: L("Tap anywhere, or the button", "点任意位置，或点按钮"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.4, delay: 0.8) { lookAround(toward: CGPoint(x: 36, y: 60)) }
        .task(id: ctx["nudge"]) {
            // On the detail stage the button asks for attention on its own every few seconds.
            guard live else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(ctx["nudge"]))
                guard !Task.isCancelled else { return }
                glanceDown()
            }
        }
    }

    private var cta: some View {
        Button(action: create) {
            Label {
                Text(zh ? "新建笔记" : "New note")
            } icon: {
                Image(systemName: "plus")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 150, height: 42)
            .background(Palette.primaryStrong, in: Capsule())
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: EmptyStateNudge(), trigger: nudges) { content, value in
            content
                .overlay {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, Color.white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 44)
                            .rotationEffect(.degrees(20))
                            .offset(x: proxy.size.width * value.shine)
                    }
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
                }
                .scaleEffect(value.scale)
                .rotationEffect(.degrees(value.angle))
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.06, duration: 0.14)
                CubicKeyframe(1.06, duration: 0.32)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
            KeyframeTrack(\.angle) {
                CubicKeyframe(-3, duration: 0.1)
                CubicKeyframe(3, duration: 0.12)
                CubicKeyframe(-3, duration: 0.12)
                CubicKeyframe(3, duration: 0.12)
                SpringKeyframe(0, duration: 0.4, spring: .bouncy)
            }
            KeyframeTrack(\.shine) {
                MoveKeyframe(-0.4)
                LinearKeyframe(-0.4, duration: 0.1)
                CubicKeyframe(1.2, duration: 0.6)
                MoveKeyframe(-0.4)
            }
        }
    }

    // MARK: Actions

    private var lookSpring: Animation { .spring(response: 0.4, dampingFraction: 0.6) }

    /// Looks toward `point` (in the scene's space), then to the other side, down at the button, and back.
    private func lookAround(toward point: CGPoint) {
        token += 1
        let current = token
        let dx: CGFloat = point.x - Self.ghostCentre.x
        let dy: CGFloat = point.y - Self.ghostCentre.y
        let length: CGFloat = max(sqrt(dx * dx + dy * dy), 1)
        let reach: CGFloat = min(length / 60, 1)
        let first = CGSize(width: dx / length * reach, height: dy / length * reach)
        let side: CGFloat = abs(first.width) > 0.15 ? first.width : 0.8
        happy = false
        Haptics.tap(.soft)
        withAnimation(lookSpring) { look = first }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))
            guard token == current else { return }
            withAnimation(lookSpring) { look = CGSize(width: -side, height: -0.15) }
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            withAnimation(lookSpring) { look = CGSize(width: 0, height: 1) }
            try? await Task.sleep(for: .seconds(0.16))
            guard token == current else { return }
            nudges += 1
            try? await Task.sleep(for: .seconds(0.75))
            guard token == current else { return }
            withAnimation(lookSpring) { look = .zero }
        }
    }

    /// The idle reminder: a glance at the button, which nudges.
    private func glanceDown() {
        guard look == .zero else { return }
        token += 1
        let current = token
        withAnimation(lookSpring) { look = CGSize(width: 0, height: 1) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard token == current else { return }
            nudges += 1
            try? await Task.sleep(for: .seconds(0.75))
            guard token == current else { return }
            withAnimation(lookSpring) { look = .zero }
        }
    }

    private func create() {
        token += 1
        let current = token
        Haptics.success()
        hops += 1
        withAnimation(lookSpring) {
            look = .zero
            happy = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            guard token == current else { return }
            withAnimation(.smooth(duration: 0.25)) { happy = false }
        }
    }
}

// MARK: - Ghost

private struct EmptyStateGhost: View {
    let time: Double
    let float: CGFloat
    let blinkEvery: Double
    /// Unit-ish direction the ghost looks in (−1…1 on both axes).
    let look: CGSize
    let happy: Bool

    var body: some View {
        let bob: CGFloat = CGFloat(sin(time * 2 * .pi / 2.6))
        let lift: CGFloat = -bob * float
        // Closed for 130 ms at the start of each interval, with a quick second blink now and then.
        let phase: Double = time.truncatingRemainder(dividingBy: max(blinkEvery, 0.5))
        let twice: Bool = Int(time / max(blinkEvery, 0.5)) % 3 == 2
        let closing: Double = Self.blink(phase) + (twice ? Self.blink(phase - 0.3) : 0)
        let open: CGFloat = CGFloat(1 - min(closing, 1))
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.16 + 0.05 * Double(bob)))
                .frame(width: 70 + 10 * bob, height: 10)
                .blur(radius: 4)
                .offset(y: 70)
            sparkles
            ZStack {
                EmptyStateGhostBody(phase: CGFloat(time * 2.4))
                    .fill(LinearGradient(colors: [Color.white, Color(hex: 0xDAD6FF)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        EmptyStateGhostBody(phase: CGFloat(time * 2.4))
                            .stroke(Color(hex: 0x6E7BFF).opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: Palette.indigo.opacity(0.3), radius: 14, y: 8)
                face(open: open)
                    .offset(x: look.width * 7, y: -12 + look.height * 5)
            }
            .frame(width: 92, height: 104)
            .rotationEffect(.degrees(Double(look.width) * 6), anchor: .bottom)
            // Two modifiers: the look is spring-animated state, the bob changes every frame.
            .offset(x: look.width * 6)
            .offset(y: lift)
        }
    }

    private static func blink(_ phase: Double) -> Double {
        guard phase >= 0, phase < 0.13 else { return 0 }
        return sin(phase / 0.13 * .pi)
    }

    private func face(open: CGFloat) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 20) {
                eye(open: open)
                eye(open: open)
            }
            Capsule()
                .fill(Color(hex: 0x2A2550))
                .frame(width: happy ? 14 : 8, height: happy ? 6 : 3.5)
        }
        .overlay {
            HStack(spacing: 42) {
                Circle().fill(Palette.pink.opacity(0.45)).frame(width: 9, height: 9)
                Circle().fill(Palette.pink.opacity(0.45)).frame(width: 9, height: 9)
            }
            .offset(y: 6)
        }
    }

    @ViewBuilder
    private func eye(open: CGFloat) -> some View {
        if happy {
            EmptyStateArc()
                .stroke(Color(hex: 0x2A2550), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .frame(width: 13, height: 8)
                .frame(width: 13, height: 17)
        } else {
            Ellipse()
                .fill(Color(hex: 0x2A2550))
                .frame(width: 12, height: 17)
                .overlay(alignment: .topTrailing) {
                    Circle().fill(.white).frame(width: 4.5, height: 4.5).offset(x: -1.5, y: 2.5)
                }
                .scaleEffect(y: max(open, 0.12))
        }
    }

    private var sparkles: some View {
        ZStack {
            sparkle(radius: 72, speed: 0.35, offset: 0.4, size: 13, colour: Palette.amber)
            sparkle(radius: 84, speed: -0.28, offset: 2.6, size: 10, colour: Palette.sky)
            sparkle(radius: 66, speed: 0.22, offset: 4.4, size: 9, colour: Palette.pink)
        }
    }

    private func sparkle(radius: CGFloat, speed: Double, offset: Double, size: CGFloat, colour: Color) -> some View {
        let angle: Double = time * speed + offset
        let twinkle: Double = 0.55 + 0.45 * sin(time * 2.1 + offset * 3)
        return Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(colour)
            .opacity(twinkle)
            .scaleEffect(0.8 + 0.3 * twinkle)
            .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius * 0.5 - 6)
    }
}

/// An upward arc: a closed, smiling eye.
private struct EmptyStateArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        return path
    }
}

/// A ghost: round head, straight sides and a hem of sine scallops whose phase travels sideways.
private struct EmptyStateGhostBody: Shape {
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = rect.width / 2
        let hem: CGFloat = rect.maxY - 9
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: hem))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: hem))
        let steps = 36
        for step in 0...steps {
            let u: CGFloat = CGFloat(step) / CGFloat(steps)
            let x: CGFloat = rect.maxX - rect.width * u
            // Three scallops; the edges stay pinned so the sides remain straight.
            let wave: CGFloat = sin(u * 3 * 2 * .pi + phase)
            let pin: CGFloat = sin(u * .pi)
            path.addLine(to: CGPoint(x: x, y: hem + 7 * wave * min(pin * 3, 1)))
        }
        path.closeSubpath()
        return path
    }
}
