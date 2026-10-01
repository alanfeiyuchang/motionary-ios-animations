import SwiftUI

extension Effect {
    static let gesturesSwipeReply = Effect(
        id: "gestures.swipe-reply",
        category: .gestures,
        interaction: .gesture,
        name: L("Swipe to Reply", "右滑引用回复"),
        summary: L("Swipe a chat bubble sideways: it resists, a reply arrow fills and pops, and on release the bubble snaps back while its quote docks above the composer.", "把聊天气泡往旁边滑：它带着阻力跟随，回复箭头逐渐充满并弹出，松手后气泡弹回，引用条落在输入框上方。"),
        prompt: L(
            "A chat thread of four bubbles above a composer. Dragging a bubble right moves it with rubber-band resistance toward a 120 pt limit. Behind it a 30 pt reply arrow fades and scales in from 50%, its ring trimming from 0 to full as the pull approaches the 56 pt threshold; crossing it the arrow fills with the accent colour, pops to 1.25× and settles, with a medium haptic. Releasing before the threshold just springs the bubble back (response 0.35 s, damping 0.7). Releasing past it springs the bubble back the same way while a quote bar with a coloured edge, the sender's name and the first line slides up above the composer and the send button lights. Sending drops a reply bubble carrying the quote into the thread and the older bubbles shift up. Quick, conversational, precise.",
            "输入框上方是四条气泡组成的聊天记录。向右拖动某条气泡，它以橡皮筋阻力跟随，逼近120 pt的上限。气泡身后，30 pt的回复箭头从50%大小淡入放大，外圈随拉动接近56 pt阈值从0描到满圈；越过阈值时箭头填充为强调色，放大到1.25倍再回落，伴随中等触感。未到阈值松手，气泡以弹簧（响应0.35秒、阻尼0.7）弹回；越过阈值松手，气泡同样弹回，同时带彩色竖条、发送者名字和首行文字的引用条从输入框上方滑入，发送按钮亮起。发送后，带着引用的回复气泡落入对话，旧气泡上移。"
        ),
        implementation: L(
            "Each row attaches a horizontal drag that leaves vertical swipes to the page; the bubble's offset is the translation passed through a rubber-band curve, and the arrow's trim, scale and fill derive from offset ÷ threshold. Release animates the offset to zero with a spring and, when armed, sets the quoted message, which inserts the quote bar with a move-and-fade transition.",
            "每一行挂一个水平拖拽手势，垂直滑动仍交给页面；气泡偏移量是经过橡皮筋曲线的拖动距离，箭头的描边、缩放与填充都由“偏移 ÷ 阈值”推导。松手时用弹簧把偏移归零；若已越过阈值，则设置被引用的消息，引用条以位移加淡入的转场插入。"
        ),
        apis: ["DragGesture", "rubberBand", "Circle().trim", "transition(.move)", "spring(response:dampingFraction:)"],
        tags: ["swipe", "reply", "quote", "chat", "message", "bubble", "滑动", "回复", "引用", "聊天", "消息", "气泡"],
        params: [
            .slider("threshold", L("Trigger distance", "触发距离"), 36...90, default: 56, step: 2, decimals: 0, unit: "pt"),
            .slider("limit", L("Pull limit", "拉动上限"), 80...180, default: 120, step: 5, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.8, default: 0.35, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.7),
        ]
    ) { ctx in
        SwipeReplyDemo(ctx: ctx)
    }
}

private struct ChatMessage: Identifiable, Equatable {
    let id: Int
    let text: LocalizedText
    let mine: Bool
    var quote: LocalizedText?
    var quoteMine = false
}

private enum Chat {
    static let size = CGSize(width: 300, height: 286)
    static let seed: [ChatMessage] = [
        ChatMessage(id: 0, text: L("Dinner on Friday?", "周五一起吃饭？"), mine: false),
        ChatMessage(id: 1, text: L("Yes! Where to?", "好呀，去哪儿？"), mine: true),
        ChatMessage(id: 2, text: L("That new ramen place", "新开的那家拉面"), mine: false),
        ChatMessage(id: 3, text: L("Does 7 pm work?", "七点可以吗？"), mine: false),
    ]
    static let replies: [LocalizedText] = [
        L("Perfect, see you then", "可以，到时见"),
        L("Sounds great", "听起来不错"),
        L("Count me in", "算我一个"),
    ]
    static let incoming: [LocalizedText] = [
        L("I'll book a table", "那我去订位"),
        L("Bring an umbrella", "记得带伞"),
        L("Should we invite Leo?", "要不要叫上小磊？"),
    ]
    static let me = L("You", "你")
    static let them = L("Mina", "小敏")
}

private struct SwipeReplyDemo: View {
    let ctx: DemoContext
    @State private var messages: [ChatMessage] = Chat.seed
    @State private var quoted: ChatMessage?
    @State private var dragID: Int?
    @State private var dragX: CGFloat = 0
    @State private var armed = false
    @State private var nextID = 4
    @State private var sent = 0
    @State private var script: Task<Void, Never>?
    @State private var followUp: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        if ctx.isStill {
            _quoted = State(initialValue: Chat.seed[3])
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                thread
                if let quoted {
                    QuoteBar(message: quoted, language: ctx.language) { dismissQuote() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Composer(active: quoted != nil, language: ctx.language) { send() }
            }
            .frame(width: Chat.size.width, height: Chat.size.height)
            .background(Palette.elevated, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)

            DemoHint(text: L("Swipe a message to the right", "把一条消息向右滑"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.6, delay: 0.6) { autoSwipe() }
        .onDisappear {
            script?.cancel()
            followUp?.cancel()
        }
    }

    private var thread: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)
            ForEach(messages) { message in
                ChatRow(
                    message: message,
                    offset: dragID == message.id ? dragX : 0,
                    progress: dragID == message.id ? min(dragX / ctx.cg("threshold"), 1) : 0,
                    armed: dragID == message.id && armed,
                    language: ctx.language
                )
                .pageSafeHorizontalDrag(minimumDistance: 8) { value in
                    script?.cancel()
                    dragChanged(message.id, translation: value.translation.width)
                } onEnded: { _ in
                    dragEnded()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .clipped()
    }

    /// The finger (or the scripted one) is `translation` points right of where it started on row `id`.
    private func dragChanged(_ id: Int, translation: CGFloat) {
        if dragID != id {
            dragID = id
            armed = false
        }
        dragX = translation > 0 ? rubberBand(translation, limit: ctx.cg("limit"), coefficient: 1.1) : -rubberBand(-translation, limit: 14)
        let nowArmed: Bool = dragX >= ctx.cg("threshold")
        if nowArmed != armed {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { armed = nowArmed }
            if !ctx.isPreview { Haptics.tap(nowArmed ? .medium : .light) }
        }
    }

    private func dragEnded() {
        guard let id = dragID else { return }
        let commit: Bool = armed
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            dragX = 0
            armed = false
            if commit, let message = messages.first(where: { $0.id == id }) {
                quoted = message
            }
        }
        // Keep the row identified until the spring has carried it home.
        let finished: Int = id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            if dragID == finished && dragX == 0 { dragID = nil }
        }
    }

    private func dismissQuote() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { quoted = nil }
        if !ctx.isPreview { Haptics.tap(.light) }
    }

    private func send() {
        guard let source = quoted else { return }
        let reply = ChatMessage(
            id: nextID,
            text: Chat.replies[sent % Chat.replies.count],
            mine: true,
            quote: source.text,
            quoteMine: source.mine
        )
        let follow = ChatMessage(id: nextID + 1, text: Chat.incoming[sent % Chat.incoming.count], mine: false)
        nextID += 2
        sent += 1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            quoted = nil
            append(reply)
        }
        if !ctx.isPreview { Haptics.tap(.soft) }
        followUp?.cancel()
        followUp = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { append(follow) }
        }
    }

    private func append(_ message: ChatMessage) {
        messages.append(message)
        // Room for four rows; a quoted reply is taller and counts double.
        while messages.reduce(0, { $0 + ($1.quote == nil ? 1 : 2) }) > 4 { messages.removeFirst() }
        if messages.count > 4 { messages.removeFirst() }
    }

    /// A scripted finger swipes the newest incoming bubble past the threshold, then the reply is sent.
    private func autoSwipe() {
        guard dragID == nil, quoted == nil, let target = messages.last(where: { !$0.mine }) else { return }
        let reach: CGFloat = ctx.cg("threshold") * 1.9 + 20
        script?.cancel()
        script = Task { @MainActor in
            let finished = await GhostFinger.drag(from: .zero, to: CGPoint(x: reach, y: 0), duration: 0.6) { point in
                dragChanged(target.id, translation: point.x)
            }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            dragEnded()
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            send()
        }
    }
}

// MARK: - Pieces

private struct ChatRow: View {
    let message: ChatMessage
    let offset: CGFloat
    let progress: CGFloat
    let armed: Bool
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 0) {
            if message.mine { Spacer(minLength: 40) }
            bubble
                .offset(x: offset)
                .background(alignment: .leading) {
                    ReplyArrow(progress: progress, armed: armed)
                        .offset(x: max(offset, 0) * 0.5 - 22)
                }
            if !message.mine { Spacer(minLength: 40) }
        }
        .contentShape(Rectangle())
    }

    private var bubble: some View {
        let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)
        return VStack(alignment: .leading, spacing: 5) {
            if let quote = message.quote {
                HStack(spacing: 6) {
                    Capsule().fill(.white.opacity(0.9)).frame(width: 2.5, height: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(message.quoteMine ? Chat.me : Chat.them, language)
                            .font(.system(size: 10, weight: .bold))
                        Text(quote, language)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 7)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            Text(message.text, language)
                .font(.system(size: 14))
                .foregroundStyle(message.mine ? Color.white : Color.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if message.mine {
                shape.fill(Palette.primaryStrong)
            } else {
                shape.fill(Color.primary.opacity(0.08))
            }
        }
    }
}

/// The reply glyph behind a swiped bubble: its ring draws with the pull and it fills once armed.
private struct ReplyArrow: View {
    let progress: CGFloat
    let armed: Bool

    var body: some View {
        let p: CGFloat = min(max(progress, 0), 1)
        ZStack {
            Circle()
                .fill(armed ? Palette.indigo : Color.primary.opacity(0.06))
            Circle()
                .trim(from: 0, to: p)
                .stroke(Palette.indigo, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(armed ? 0 : 1)
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(armed ? Color.white : Palette.indigo)
        }
        .frame(width: 30, height: 30)
        .scaleEffect((0.5 + 0.5 * p) * (armed ? 1.25 : 1))
        .opacity(Double(min(p * 1.6, 1)))
    }
}

private struct QuoteBar: View {
    let message: ChatMessage
    let language: AppLanguage
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.indigo)
            Capsule().fill(Palette.indigo).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(message.mine ? Chat.me : Chat.them, language)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.indigo)
                Text(message.text, language)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.04))
    }
}

private struct Composer: View {
    let active: Bool
    let language: AppLanguage
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Text(L("Message", "发消息"), language)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(Color.primary.opacity(0.06), in: Capsule())
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(active ? Color.white : Color.secondary)
                    .frame(width: 34, height: 34)
                    .background {
                        if active {
                            Circle().fill(Palette.primaryStrong)
                        } else {
                            Circle().fill(Color.primary.opacity(0.08))
                        }
                    }
                    .scaleEffect(active ? 1 : 0.9)
            }
            .buttonStyle(.plain)
            .disabled(!active)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: active)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.stroke).frame(height: 1)
        }
    }
}
