import SwiftUI

extension Effect {
    static let inputsAIComposer = Effect(
        id: "inputs.ai-composer",
        category: .inputs,
        interaction: .state,
        name: L("AI Prompt Composer", "AI 提示词输入框"),
        summary: L("A breathing gradient border, a field that grows line by line, and one button that morphs mic → send → stop.", "会呼吸的渐变描边、逐行长高的输入框，以及在麦克风、发送、停止之间变形的按钮。"),
        prompt: L(
            "An AI chat composer: a 300 pt field with 26 pt corners, a plus button and a 36 pt round action button. A 1.5 pt angular-gradient border (indigo, pink, amber, mint, sky) rotates at 0.25 turns per second over a blurred copy whose opacity breathes on a 3.5 s sine. As text wraps, the field grows upward line by line, up to four, on a spring (response 0.35 s, damping 0.72). The action button morphs with symbol replace and a pop to 118%: a grey mic when empty, a gradient-filled up arrow once there is text, and after sending a stop square inside a ring that pulses from 100% to 140% every 1.1 s. Sending springs the text up into a bubble, the border spins three times faster and glows brighter, shimmer lines stand in for the reply, and after 2.6 s the answer blurs in and the mic returns.",
            "AI 对话输入框：宽 300pt、26pt 圆角，内含 36pt 圆形操作按钮。1.5pt 角向渐变描边以每秒 0.25 圈旋转，下方模糊副本按 3.5 秒正弦呼吸。文字换行时，输入框以弹簧（响应 0.35 秒、阻尼 0.72）逐行向上长高，最多四行。操作按钮经符号替换变形并弹到 118%：无内容时是灰色麦克风，有文字后是渐变填充的向上箭头，发送后是停止方块，外圈光环每 1.1 秒从 100% 扩到 140%。发送时文字弹起成为气泡，描边转速提高三倍、光晕更亮，2.6 秒后答案以模糊过渡出现，按钮回到麦克风。"
        ),
        implementation: L(
            "A TimelineView rotates an AngularGradient stroke and modulates a blurred copy for the glow. The field's natural height is read with onGeometryChange and copied into a spring-animated background that also masks the content, so growth is elastic even though text layout is instant. One enum drives the button's symbol, fill and pulse ring.",
            "TimelineView 旋转 AngularGradient 描边，并调制一层模糊副本形成光晕。输入框的自然高度由 onGeometryChange 读取，再交给带弹簧动画的背景，该背景同时作为内容遮罩，因此即便文字排版是瞬时的，长高仍有弹性。一个枚举统一驱动按钮的符号、填充与脉冲光环。"
        ),
        apis: ["TimelineView", "AngularGradient", "TextField(axis: .vertical)", "onGeometryChange", "contentTransition(.symbolEffect(.replace))"],
        tags: ["ai", "chat", "composer", "prompt", "gradient border", "输入框", "对话", "渐变描边", "发送按钮", "生成中"],
        params: [
            .slider("speed", L("Border speed", "描边转速"), 0.05...1.0, default: 0.25, unit: "r/s"),
            .slider("glow", L("Glow", "光晕"), 0...1, default: 0.6),
            .slider("think", L("Generating time", "生成时长"), 1...5, default: 2.6, decimals: 1, unit: "s"),
            .slider("grow", L("Growth response", "长高响应"), 0.2...0.8, default: 0.35, unit: "s"),
        ]
    ) { ctx in
        InputAIComposerDemo(ctx: ctx)
    }
}

private enum InputAIPhase {
    case idle, generating, done
}

private enum InputAIAction {
    case mic, send, stop

    var symbol: String {
        switch self {
        case .mic: return "mic.fill"
        case .send: return "arrow.up"
        case .stop: return "stop.fill"
        }
    }
}

private struct InputAIComposerDemo: View {
    let ctx: DemoContext
    @State private var text = ""
    @State private var sent: String?
    @State private var phase: InputAIPhase
    @State private var stopped = false
    @State private var fieldHeight: CGFloat = 52
    @State private var micBounce = 0
    @State private var scriptTask: Task<Void, Never>?
    @State private var replyTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private let width: CGFloat = 300

    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? .done : .idle)
        _sent = State(initialValue: ctx.isStill ? Self.sample(ctx.language) : nil)
    }

    private static func sample(_ language: AppLanguage) -> String {
        L(
            "Write a SwiftUI spring where a button sinks to 94% on press and overshoots a little on release",
            "帮我写一个 SwiftUI 弹簧动画：按钮按下时缩小到 94%，松手后带一点过冲回弹"
        )(language)
    }

    private var isStatic: Bool { ctx.isPreview || ctx.isStill }

    private var action: InputAIAction {
        if phase == .generating { return .stop }
        return text.isEmpty ? .mic : .send
    }

    var body: some View {
        VStack(spacing: 0) {
            conversation
            composer
                .padding(.bottom, ctx.isPreview ? 22 : 10)
            DemoHint(text: L("Type, or tap the mic to dictate a sample, then send", "输入文字，或点麦克风口述一段示例，再发送"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { focused = false }
        .autoplay(ctx.isPreview, every: 7.4, delay: 0.4) { runScript() }
        .onDisappear {
            scriptTask?.cancel()
            replyTask?.cancel()
        }
    }

    // MARK: Conversation

    private var conversation: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            if let sent {
                Text(verbatim: sent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [Palette.indigo, Palette.violet], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .frame(maxWidth: 236, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 70).combined(with: .scale(scale: 0.7, anchor: .bottomTrailing)).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                reply
            } else {
                greeting
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                Spacer(minLength: 0)
            }
        }
        .frame(width: width)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var greeting: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Palette.indigo, Palette.pink, Palette.amber], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(L("What shall we make today?", "今天想做点什么？"), ctx.language)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    private var reply: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    LinearGradient(colors: [Palette.pink, Palette.amber], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
            ZStack(alignment: .topLeading) {
                if phase == .generating {
                    InputAIShimmer()
                        .transition(.opacity)
                } else {
                    Text(answer, ctx.language)
                        .font(.system(size: 14))
                        .foregroundStyle(stopped ? .secondary : .primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.blurReplace)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        }
        .transition(.opacity.combined(with: .offset(y: 10)))
    }

    private var answer: LocalizedText {
        stopped
            ? L("Stopped.", "已停止生成。")
            : L(
                "Drive scaleEffect with .spring(response: 0.35, dampingFraction: 0.6): 0.94 while pressed, back to 1 on release.",
                "用 .spring(response: 0.35, dampingFraction: 0.6) 驱动 scaleEffect：按下时 0.94，松手回到 1。"
            )
    }

    // MARK: Composer

    private var composer: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        let energy: Double = phase == .generating ? 1 : (text.isEmpty && !focused ? 0.45 : 0.75)
        return HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.07), in: Circle())
            input
                .padding(.vertical, 8)
            actionButton
        }
        .padding(8)
        .frame(width: width)
        // Text lays out instantly; the field copies that natural height into a spring-animated frame.
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            withAnimation(.spring(response: ctx["grow"], dampingFraction: 0.72)) { fieldHeight = height }
        }
        .frame(height: fieldHeight, alignment: .bottom)
        .clipShape(shape)
        .background {
            ZStack {
                shape.fill(Palette.elevated)
                InputAIBorder(
                    shape: shape,
                    turns: ctx["speed"],
                    glow: ctx["glow"] * energy,
                    fast: phase == .generating,
                    preview: ctx.isPreview
                )
            }
        }
    }

    @ViewBuilder
    private var input: some View {
        let placeholder = L("Ask anything", "问点什么")(ctx.language)
        if isStatic {
            Text(verbatim: text.isEmpty ? placeholder : text)
                .foregroundStyle(text.isEmpty ? Color.secondary.opacity(0.7) : Color.primary)
                .font(.system(size: 16))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(1...4)
                .focused($focused)
                .onChange(of: focused) { _, isFocused in
                    if isFocused, scriptTask != nil { stopScript() }
                }
        }
    }

    private var actionButton: some View {
        let kind = action
        return Button {
            switch kind {
            case .mic: dictate()
            case .send: send()
            case .stop: stop()
            }
        } label: {
            ZStack {
                if kind == .stop {
                    InputAIPulse()
                        .transition(.opacity)
                }
                Circle().fill(Color.primary.opacity(0.08))
                Circle()
                    .fill(LinearGradient(colors: [Palette.indigo, Palette.violet], startPoint: .top, endPoint: .bottom))
                    .opacity(kind == .send ? 1 : 0)
                Circle()
                    .fill(Color.primary)
                    .opacity(kind == .stop ? 1 : 0)
                Image(systemName: kind.symbol)
                    .font(.system(size: kind == .stop ? 12 : 16, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(kind == .mic ? Color.secondary : (kind == .stop ? Color(uiColor: .systemBackground) : Color.white))
                    .symbolEffect(.bounce, value: micBounce)
            }
            .frame(width: 36, height: 36)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: kind) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(1.18, duration: 0.1)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: kind)
    }

    // MARK: Actions

    private func send() {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, phase != .generating else { return }
        Haptics.tap(.medium)
        stopped = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.74)) {
            sent = message
            phase = .generating
        }
        text = ""
        replyTask?.cancel()
        let quiet = ctx.isPreview || scriptTask != nil
        replyTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(ctx["think"]))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.45)) { phase = .done }
            if !quiet { Haptics.success() }
        }
    }

    private func stop() {
        guard phase == .generating else { return }
        replyTask?.cancel()
        Haptics.tap(.rigid)
        stopped = true
        withAnimation(.smooth(duration: 0.35)) { phase = .done }
    }

    /// The mic "dictates" the sample prompt, so the field can be tried without the keyboard.
    private func dictate() {
        guard scriptTask == nil else { return }
        Haptics.tap(.light)
        micBounce += 1
        scriptTask = Task { @MainActor in
            await typeSample()
            scriptTask = nil
        }
    }

    private func typeSample() async {
        let sample = Self.sample(ctx.language)
        text = ""
        for index in sample.indices {
            try? await Task.sleep(for: .milliseconds(ctx.language == .zh ? 42 : 20))
            guard !Task.isCancelled else { return }
            text = String(sample[...index])
        }
    }

    /// Preview loop and detail intro: type, send, wait for the answer.
    private func runScript() {
        scriptTask?.cancel()
        replyTask?.cancel()
        scriptTask = Task { @MainActor in
            withAnimation(.smooth(duration: 0.3)) {
                sent = nil
                phase = .idle
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            await typeSample()
            try? await Task.sleep(for: .seconds(0.55))
            guard !Task.isCancelled else { return }
            send()
            scriptTask = nil
        }
    }

    private func stopScript() {
        scriptTask?.cancel()
        scriptTask = nil
        text = ""
    }
}

// MARK: - Pieces

/// Rotating gradient stroke with a breathing glow underneath.
private struct InputAIBorder: View {
    let shape: RoundedRectangle
    let turns: Double
    let glow: Double
    let fast: Bool
    let preview: Bool

    /// Phase bookkeeping, so changing the speed never makes the gradient jump.
    @State private var base: Double = 0
    @State private var since = Date()

    private static let colors: [Color] = [Palette.indigo, Palette.pink, Palette.amber, Palette.mint, Palette.sky, Palette.indigo]

    private var rate: Double { turns * 360 * (fast ? 3 : 1) }

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview))) { timeline in
            let elapsed = timeline.date.timeIntervalSince(since)
            let angle = base + elapsed * rate
            let breath = 0.75 + 0.25 * sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 3.5)
            let gradient = AngularGradient(colors: Self.colors, center: .center, angle: .degrees(angle))
            ZStack {
                shape
                    .stroke(gradient, lineWidth: 6)
                    .blur(radius: 9)
                    .opacity(glow * breath)
                shape
                    .strokeBorder(gradient, lineWidth: 1.5)
                    .opacity(0.55 + 0.45 * min(glow * 1.6, 1))
            }
        }
        .onChange(of: rate) { old, _ in
            let now = Date()
            base += now.timeIntervalSince(since) * old
            since = now
        }
        .allowsHitTesting(false)
    }
}

/// Ring that keeps radiating from the stop button while the reply is generating.
private struct InputAIPulse: View {
    @State private var expanded = false
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        Circle()
            .stroke(LinearGradient(colors: [Palette.indigo, Palette.pink], startPoint: .top, endPoint: .bottom), lineWidth: 2)
            .scaleEffect(expanded ? 1.4 : 1)
            .opacity(expanded ? 0 : 0.8)
            .onAppear {
                guard !isStill else { return }
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { expanded = true }
            }
    }
}

/// Three placeholder lines with a highlight sweeping across them.
private struct InputAIShimmer: View {
    @State private var sweep = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: index == 2 ? 110 : (index == 1 ? 190 : 220), height: 10)
            }
        }
        .overlay {
            LinearGradient(
                colors: [.clear, Palette.pink.opacity(0.55), Palette.amber.opacity(0.55), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120)
            .offset(x: sweep ? 190 : -190)
            .blendMode(.sourceAtop)
        }
        .compositingGroup()
        .padding(.top, 4)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { sweep = true }
        }
    }
}
