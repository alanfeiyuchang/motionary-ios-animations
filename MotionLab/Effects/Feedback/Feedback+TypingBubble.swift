import SwiftUI

// MARK: - Typing bubble

extension Effect {
    static let feedbackTypingBubble = Effect(
        id: "feedback.typing-bubble",
        category: .feedback,
        interaction: .tap,
        name: L("Typing Bubble Morph", "输入气泡变形"),
        summary: L("A typing indicator bubbles up dot by dot, waves, then stretches into the actual message without being replaced.", "输入指示气泡一粒粒冒出、三点起伏，随后原地伸展成真正的消息，而不是被替换。"),
        prompt: L(
            "In a chat, sending a message makes the other person start typing. Their indicator grows from its bottom-left corner like a thought bubble: a 6 pt circle, then an 11 pt circle, then the 62 × 38 pt grey bubble, 70 ms apart, each on a spring (response 0.38 s, damping 0.6). Inside, three 8 pt dots rise 5 pt in a travelling wave with a 1 s period, each 0.15 of a cycle behind the last, brightening at the top. After 1.6 s the same bubble becomes the reply: its frame springs to the text's size (response 0.42 s, damping 0.74) while the dots shrink away and the words blur-replace in, the two small circles retract into the corner, and a soft haptic lands. Older bubbles slide up on the same spring. Conversational, continuous, warm.",
            "聊天中发出一条消息后，对方开始输入。输入指示从左下角像思考气泡一样长出：先是 6 pt 小圆，再是 11 pt 圆，最后是 62 × 38 pt 的灰色气泡，间隔 70 毫秒，各自使用弹簧（响应 0.38 秒、阻尼 0.6）。气泡里三颗 8 pt 圆点以 1 秒为周期做行进波，各升起 5 pt，后一颗落后前一颗 0.15 个周期，升到顶时变亮。1.6 秒后，同一个气泡变成回复：外框弹到文字的尺寸（响应 0.42 秒、阻尼 0.74），圆点缩小消失、文字模糊浮现，两个小圆收回角落，伴随柔和触感。自然、连贯、有温度。"
        ),
        implementation: L(
            "The typing indicator and the reply are one message record with an isTyping flag, so flipping it inside a spring reshapes the same bubble (its background is sized by the content) instead of swapping views; the dots are driven by a TimelineView sine, and the thought-bubble circles scale from per-piece delayed springs.",
            "输入指示与回复是同一条带 isTyping 标记的消息记录，在弹簧动画里翻转它，同一个气泡（背景由内容决定尺寸）就会变形而不是换视图；圆点由 TimelineView 的正弦驱动，思考气泡的小圆用各自延迟的弹簧缩放。"
        ),
        apis: ["TimelineView(.animation)", "transition(.blurReplace)", "spring(response:dampingFraction:)", "scaleEffect(_:anchor:)", "withAnimation"],
        tags: ["typing", "chat", "bubble", "messages", "正在输入", "聊天", "气泡", "消息"],
        params: [
            .slider("typing", L("Typing time", "输入时长"), 0.6...4.0, default: 1.6, decimals: 1, unit: "s"),
            .slider("wave", L("Dot rise", "圆点起伏"), 2...10, default: 5, decimals: 0, unit: "pt"),
            .slider("period", L("Wave period", "波动周期"), 0.6...1.6, default: 1.0, decimals: 1, unit: "s"),
            .slider("morph", L("Morph response", "变形响应"), 0.25...0.8, default: 0.42, unit: "s"),
        ]
    ) { ctx in
        TypingBubbleDemo(ctx: ctx)
    }
}

private struct TypingChatMessage: Identifiable, Equatable {
    let id: Int
    let outgoing: Bool
    let text: String
    var isTyping: Bool
}

private struct TypingBubbleDemo: View {
    let ctx: DemoContext
    @State private var messages: [TypingChatMessage]
    @State private var nextID = 10
    @State private var round = 0
    @State private var busy = false
    @State private var sends = 0
    @State private var token = 0

    private static let script: [(LocalizedText, LocalizedText)] = [
        (L("Lunch today?", "中午一起吃饭？"), L("Yes! Ramen at 12:30?", "好呀！12:30 吃拉面？")),
        (L("Perfect, I'll book", "好，我来订位"), L("You're the best. See you there", "你最好了，一会儿见")),
        (L("Running 5 min late", "我晚到 5 分钟"), L("No rush, I just got us a table", "不急，我刚占到位置")),
    ]

    init(ctx: DemoContext) {
        self.ctx = ctx
        let zh = ctx.language == .zh
        var seeded: [TypingChatMessage] = [
            TypingChatMessage(id: 0, outgoing: false, text: zh ? "这周有空吗？" : "Free this week?", isTyping: false),
            TypingChatMessage(id: 1, outgoing: true, text: zh ? "周四可以" : "Thursday works", isTyping: false),
        ]
        // Still thumbnails show the indicator mid-typing.
        if ctx.isStill {
            seeded.append(TypingChatMessage(id: 2, outgoing: true, text: Self.script[0].0(ctx.language), isTyping: false))
            seeded.append(TypingChatMessage(id: 3, outgoing: false, text: Self.script[0].1(ctx.language), isTyping: true))
        }
        _messages = State(initialValue: seeded)
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                header
                thread
                composer
            }
            .frame(width: 300, height: 300)
            .background(Color.adaptive(light: 0xFFFFFF, dark: 0x0C0C0E))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.stroke))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
            .contentShape(Rectangle())
            .onTapGesture { send() }
            DemoHint(text: L("Tap to send a message", "点击发送一条消息"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["typing"] + 2.8, delay: 0.4) { send() }
    }

    // MARK: Scene

    private var header: some View {
        HStack(spacing: 9) {
            Text(verbatim: "M")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Palette.sunset, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Mia")
                    .font(.subheadline.weight(.semibold))
                Text(ctx.language == .zh ? "在线" : "online")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var thread: some View {
        VStack(spacing: 7) {
            ForEach(messages) { message in
                row(message)
                    .transition(
                        .asymmetric(
                            insertion: message.outgoing
                                ? AnyTransition.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity).combined(with: .offset(y: 26))
                                : AnyTransition.identity,
                            removal: .opacity
                        )
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .frame(width: 300, height: 204, alignment: .bottom)
        .clipped()
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12)], startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private func row(_ message: TypingChatMessage) -> some View {
        if message.outgoing {
            HStack(spacing: 0) {
                Spacer(minLength: 70)
                Text(verbatim: message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x3D95FF), Color(hex: 0x0A7AFF)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 19, style: .continuous)
                    )
            }
        } else {
            HStack(spacing: 0) {
                TypingIncomingBubble(
                    message: message,
                    rise: ctx.cg("wave"),
                    period: max(ctx["period"], 0.2),
                    preview: ctx.isPreview,
                    still: ctx.isStill
                )
                Spacer(minLength: 60)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Text(ctx.language == .zh ? "信息" : "Message")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.14)))
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white, Color(hex: 0x0A7AFF))
                .opacity(busy ? 0.4 : 1)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: sends) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(0.8, duration: 0.08)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    }
                }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }

    // MARK: Sequence

    private func send() {
        guard !busy else { return }
        busy = true
        token += 1
        let current = token
        let pair = Self.script[round % Self.script.count]
        round += 1
        let typing: Double = ctx["typing"]
        let morph: Double = ctx["morph"]
        let language = ctx.language
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let layout = Animation.spring(response: 0.42, dampingFraction: 0.8)
        if buzz { Haptics.tap() }
        sends += 1
        withAnimation(layout) {
            messages.append(TypingChatMessage(id: nextID, outgoing: true, text: pair.0(language), isTyping: false))
            trim()
        }
        let replyID: Int = nextID + 1
        nextID += 2
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))
            guard token == current else { return }
            // The row's height animates the thread up; the bubble's pieces spring in on their own.
            withAnimation(layout) {
                messages.append(TypingChatMessage(id: replyID, outgoing: false, text: pair.1(language), isTyping: true))
                trim()
            }
            try? await Task.sleep(for: .seconds(typing))
            guard token == current else { return }
            withAnimation(.spring(response: morph, dampingFraction: 0.74)) {
                if let index = messages.firstIndex(where: { $0.id == replyID }) {
                    messages[index].isTyping = false
                }
            }
            if buzz { Haptics.tap(.soft) }
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            busy = false
        }
    }

    /// Keeps the last five bubbles; older ones fade out above the thread's top edge.
    private func trim() {
        if messages.count > 5 { messages.removeFirst(messages.count - 5) }
    }
}

// MARK: - Incoming bubble

private struct TypingIncomingBubble: View {
    let message: TypingChatMessage
    let rise: CGFloat
    let period: Double
    let preview: Bool
    /// 0 = nothing, 1 = small circle, 2 = + big circle, 3 = + bubble.
    @State private var pieces: Int

    private static let grey = Color.adaptive(light: 0xE9E9EB, dark: 0x2E2E33)

    init(message: TypingChatMessage, rise: CGFloat, period: Double, preview: Bool, still: Bool) {
        self.message = message
        self.rise = rise
        self.period = period
        self.preview = preview
        // Bubbles that are already messages (and stills) are complete from the start.
        _pieces = State(initialValue: still || !message.isTyping ? 3 : 0)
    }

    var body: some View {
        let typing: Bool = message.isTyping
        ZStack(alignment: .leading) {
            if typing {
                TypingDots(rise: rise, period: period, preview: preview)
                    .frame(width: 34, height: 18)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Text(verbatim: message.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .transition(.blurReplace)
            }
        }
        .padding(.horizontal, typing ? 14 : 13)
        .padding(.vertical, typing ? 10 : 9)
        .background(Self.grey, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .scaleEffect(pieces >= 3 ? 1 : 0.01, anchor: .bottomLeading)
        .background(alignment: .bottomLeading) {
            // The thought-bubble tail: two circles that retract into the corner once the message arrives.
            ZStack(alignment: .bottomLeading) {
                Circle()
                    .fill(Self.grey)
                    .frame(width: 11, height: 11)
                    .scaleEffect(pieces >= 2 && typing ? 1 : 0.01)
                    .offset(x: -1, y: 2)
                Circle()
                    .fill(Self.grey)
                    .frame(width: 6, height: 6)
                    .scaleEffect(pieces >= 1 && typing ? 1 : 0.01)
                    .offset(x: -6, y: 7)
            }
        }
        .onAppear {
            guard pieces == 0 else { return }
            let spring = Animation.spring(response: 0.38, dampingFraction: 0.6)
            withAnimation(spring) { pieces = 1 }
            withAnimation(spring.delay(0.07)) { pieces = 2 }
            withAnimation(spring.delay(0.14)) { pieces = 3 }
        }
    }
}

private struct TypingDots: View {
    let rise: CGFloat
    let period: Double
    let preview: Bool
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: isStill)) { timeline in
            let t: Double = isStill ? period * 0.3 : timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    // A travelling wave: each dot is 0.15 of a cycle behind the previous one.
                    let cycle: Double = t / period - Double(index) * 0.15
                    let lift: Double = max(sin(cycle * 2 * .pi), 0)
                    Circle()
                        .fill(Color.primary.opacity(0.32 + 0.4 * lift))
                        .frame(width: 8, height: 8)
                        .offset(y: -rise * CGFloat(lift) + rise * 0.3)
                }
            }
        }
    }
}
