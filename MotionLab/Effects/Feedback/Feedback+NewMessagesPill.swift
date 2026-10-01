import SwiftUI

// MARK: - New messages pill

extension Effect {
    static let feedbackNewMessagesPill = Effect(
        id: "feedback.new-messages-pill",
        category: .feedback,
        interaction: .tap,
        name: L("New Messages Pill", "新消息胶囊"),
        summary: L("A 'new messages' pill pops in when you are scrolled up, bumps and rolls its count with every arrival, then dives away as the chat jumps to the bottom.", "停在上方时，“新消息”胶囊弹出；每来一条就跳一下、数字滚动；点它一头扎下去，会话随即滚到底部。"),
        prompt: L(
            "A chat scrolled up to older messages. When a new message arrives below the fold, a 36 pt indigo pill with a bobbing down-arrow and '1 new message' pops up 14 pt above the bottom edge, growing from 60% on a spring (response 0.4 s, damping 0.62). Each further arrival rolls the number upward and bumps the pill: it swells to 116% and hops 5 pt in 110 ms, then settles on a bouncy spring, while a soft glow pulses along the bottom edge. Tapping the pill makes it dive: it lifts 7 pt in 110 ms as anticipation, then drops 80 pt on a 0.22 s ease-in, shrinking to 82% and fading. At the same moment the thread scrolls to the newest message on a spring (response 0.5 s, damping 0.86) and the unread bubbles pop in 60 ms apart.",
            "会话停在较早的消息处。视野下方来了新消息时，一枚 36 pt 的靛蓝胶囊（轻晃的向下箭头与“1 条新消息”）在距底边 14 pt 处弹出，从 60% 以弹簧（响应 0.4 秒、阻尼 0.62）放大。之后每来一条，数字向上滚动，胶囊一跳：110 毫秒内鼓到 116% 并上跃 5 pt，再弹跳落定，底边泛起一道柔光。点击胶囊，它一头扎下去：先 110 毫秒上抬 7 pt 作预备，再以 0.22 秒缓入下坠 80 pt，缩到 82% 并淡出。同时会话以弹簧（响应 0.5 秒、阻尼 0.86）滚到最新一条，未读气泡间隔 60 毫秒依次弹出。"
        ),
        implementation: L(
            "The pill's presence is a three-state enum driving offset, scale and opacity; a keyframeAnimator keyed on the arrival count adds the bump and another keyed on the dive adds the anticipation. The count uses a numericText content transition, and the thread is a VStack shifted by an animated offset.",
            "胶囊的出现与离开由三态枚举驱动位移、缩放与透明度；以到达数为触发器的 keyframeAnimator 叠加跳动，以下潜为触发器的另一个负责预备动作。计数使用 numericText 内容转场，会话是由动画 offset 平移的 VStack。"
        ),
        apis: ["keyframeAnimator(initialValue:trigger:)", "contentTransition(.numericText)", "phaseAnimator", "spring(response:dampingFraction:)", "offset"],
        tags: ["chat", "unread", "scroll to bottom", "pill", "badge", "聊天", "未读", "回到底部", "胶囊", "新消息"],
        params: [
            .slider("bump", L("Bump scale", "跳动缩放"), 1.0...1.4, default: 1.16),
            .slider("response", L("Pop response", "弹出响应"), 0.25...0.8, default: 0.4, unit: "s"),
            .slider("damping", L("Pop damping", "弹出阻尼"), 0.4...1.0, default: 0.62),
        ]
    ) { ctx in
        NewMessagesPillDemo(ctx: ctx)
    }
}

private enum NewMessagesPillState {
    case hidden
    case shown
    case dived
}

private struct NewMessagesBubble {
    let text: LocalizedText
    let mine: Bool
}

private enum NewMessagesData {
    static let older: [NewMessagesBubble] = [
        NewMessagesBubble(text: L("Did the build go out?", "新版本发出去了吗？"), mine: false),
        NewMessagesBubble(text: L("Yes, 2.4 is live", "发了，2.4 已上线"), mine: true),
        NewMessagesBubble(text: L("Nice. Any crashes?", "不错，有崩溃吗？"), mine: false),
        NewMessagesBubble(text: L("None so far", "目前没有"), mine: true),
        NewMessagesBubble(text: L("I'll watch the charts", "我盯着数据"), mine: true),
        NewMessagesBubble(text: L("Thanks!", "辛苦啦！"), mine: false),
    ]
    static let incoming: [LocalizedText] = [
        L("Reviews are coming in", "评价开始进来了"),
        L("4.9 stars so far", "目前 4.9 星"),
        L("Someone loved the haptics", "有人夸触感做得好"),
        L("Featured in Today?!", "上 Today 推荐了？！"),
        L("Screenshot coming", "截图马上发你"),
    ]
    static let rowHeight: CGFloat = 44
}

private struct NewMessagesPillDemo: View {
    let ctx: DemoContext
    /// Messages that arrived below the fold since the last reset.
    @State private var arrived: Int
    /// The number shown in the pill.
    @State private var unread: Int
    @State private var pill: NewMessagesPillState
    /// Whether the thread has jumped to the newest message.
    @State private var atBottom = false
    @State private var bumps = 0
    @State private var dives = 0
    @State private var glow = 0
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the pill with three unread messages.
        _arrived = State(initialValue: ctx.isStill ? 3 : 0)
        _unread = State(initialValue: ctx.isStill ? 3 : 0)
        _pill = State(initialValue: ctx.isStill ? .shown : .hidden)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                thread
                edgeGlow
                pillView
                    .padding(.bottom, 14)
            }
            .feedbackScene(height: 270)
            .contentShape(Rectangle())
            .onTapGesture { receive() }
            DemoHint(text: L("Tap the chat to receive, tap the pill to jump", "点会话收一条消息，点胶囊跳到底部"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.0, delay: 0.6) { tick() }
    }

    // MARK: Thread

    private var thread: some View {
        let shift: CGFloat = atBottom ? -CGFloat(arrived) * NewMessagesData.rowHeight : 0
        return VStack(spacing: 0) {
            ForEach(NewMessagesData.older.indices, id: \.self) { index in
                bubble(NewMessagesData.older[index], fresh: false)
            }
            ForEach(0..<arrived, id: \.self) { index in
                let text: LocalizedText = NewMessagesData.incoming[index % NewMessagesData.incoming.count]
                bubble(NewMessagesBubble(text: text, mine: false), fresh: true)
                    .scaleEffect(atBottom ? 1 : 0.7, anchor: .bottomLeading)
                    .opacity(atBottom ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.68).delay(atBottom ? 0.16 + Double(index) * 0.06 : 0), value: atBottom)
            }
        }
        .padding(.top, 8)
        .offset(y: shift)
        .frame(width: 300, height: 270, alignment: .top)
    }

    private func bubble(_ bubble: NewMessagesBubble, fresh: Bool) -> some View {
        Text(bubble.text, ctx.language)
            .font(.footnote)
            .foregroundStyle(bubble.mine ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background {
                if bubble.mine {
                    Capsule().fill(Palette.primaryStrong)
                } else {
                    Capsule().fill(fresh ? Palette.indigo.opacity(0.16) : Color.primary.opacity(0.08))
                }
            }
            .frame(maxWidth: .infinity, alignment: bubble.mine ? .trailing : .leading)
            .padding(.horizontal, 14)
            .frame(height: NewMessagesData.rowHeight)
    }

    /// A glow along the bottom edge each time something lands below the fold.
    private var edgeGlow: some View {
        LinearGradient(colors: [Palette.indigo.opacity(0), Palette.indigo.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            .frame(width: 300, height: 46)
            .keyframeAnimator(initialValue: 0.0, trigger: glow) { content, opacity in
                content.opacity(opacity)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(1, duration: 0.14)
                    CubicKeyframe(0, duration: 0.5)
                }
            }
            .allowsHitTesting(false)
    }

    // MARK: Pill

    private var pillView: some View {
        let zh = ctx.language == .zh
        let bump: CGFloat = ctx.cg("bump")
        let offset: CGFloat
        let scale: CGFloat
        switch pill {
        case .hidden:
            offset = 30
            scale = 0.6
        case .shown:
            offset = 0
            scale = 1
        case .dived:
            offset = 80
            scale = 0.82
        }
        return Button(action: dive) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .heavy))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.22), in: Circle())
                    .phaseAnimator([false, true]) { content, down in
                        content.offset(y: down ? 1.5 : -1.5)
                    } animation: { _ in
                        .easeInOut(duration: 0.6)
                    }
                Text(zh ? "\(max(unread, 1)) 条新消息" : (unread > 1 ? "\(unread) new messages" : "1 new message"))
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(unread)))
            }
            .foregroundStyle(.white)
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .frame(height: 36)
            .background(Palette.primaryStrong, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
            .shadow(color: Palette.indigo.opacity(0.45), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: NewMessagesBump(), trigger: bumps) { content, value in
            content.scaleEffect(value.scale).offset(y: value.lift)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(bump, duration: 0.11)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(-5, duration: 0.11)
                SpringKeyframe(0, duration: 0.45, spring: .bouncy)
            }
        }
        .keyframeAnimator(initialValue: CGFloat(0), trigger: dives) { content, lift in
            content.offset(y: lift)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(-7, duration: 0.11)
                CubicKeyframe(0, duration: 0.12)
            }
        }
        .scaleEffect(scale)
        .offset(y: offset)
        .opacity(pill == .shown ? 1 : 0)
        .allowsHitTesting(pill == .shown)
    }

    // MARK: Actions

    /// Preview loop and intro: three arrivals, the dive, then back up to the older messages.
    private func tick() {
        if atBottom {
            reset()
        } else if unread < 3 {
            arrive()
        } else {
            dive()
        }
    }

    /// A tap on the chat: a message comes in (after scrolling back up if the thread is at the bottom).
    private func receive() {
        guard atBottom else {
            arrive()
            return
        }
        reset()
        token += 1
        let current = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            arrive()
        }
    }

    private func arrive() {
        guard !atBottom else { return }
        Haptics.tap(.soft)
        arrived += 1
        glow += 1
        if pill == .shown {
            withAnimation(.snappy(duration: 0.3)) { unread += 1 }
            bumps += 1
        } else {
            unread = 1
            withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) { pill = .shown }
        }
    }

    private func dive() {
        guard pill == .shown else { return }
        Haptics.tap(.medium)
        dives += 1
        withAnimation(.easeIn(duration: 0.22).delay(0.11)) { pill = .dived }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86).delay(0.12)) { atBottom = true }
    }

    private func reset() {
        token += 1
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { pill = .hidden }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { atBottom = false }
        unread = 0
        let current = token
        Task { @MainActor in
            // Forget the read messages once the thread is back at the older ones.
            try? await Task.sleep(for: .seconds(0.4))
            guard token == current, !atBottom else { return }
            arrived = 0
        }
    }
}

private struct NewMessagesBump {
    var scale: CGFloat = 1
    var lift: CGFloat = 0
}
