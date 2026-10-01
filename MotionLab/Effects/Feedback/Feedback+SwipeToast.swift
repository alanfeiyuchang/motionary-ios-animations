import SwiftUI

// MARK: - Swipe toast

extension Effect {
    static let feedbackSwipeToast = Effect(
        id: "feedback.swipe-toast",
        category: .feedback,
        interaction: .gesture,
        name: L("Fling-Away Toast", "甩走式吐司"),
        summary: L("A stacked toast you can grab and throw: it tilts with the drag, leaves at the speed of your flick, and the next one steps forward.", "叠放的吐司可以抓住甩出去：随拖动倾斜，以甩动的速度离场，后一条随即顶上来。"),
        prompt: L(
            "Three dark toasts, 268 × 58 pt with 20 pt corners, sit stacked at the bottom of a list: each one behind is 6% smaller, 11 pt higher and dimmer. Dragging the front toast sideways moves it 1:1 and tilts it 7° per 100 pt around its bottom edge; passing 90 pt arms it with a selection tick. On release, a drag past the threshold or a flick faster than 600 pt/s throws it: it keeps travelling in that direction and leaves in 0.16–0.4 s, the time set by the finger's speed, still rotating. The stack then steps forward on a spring (response 0.42 s, damping 0.72) and a new toast fades in at the back. A short drag springs back upright. Direct, physical, disposable.",
            "三条深色吐司（268 × 58 pt，圆角 20 pt）叠放在列表底部：越靠后的越小 6%、高出 11 pt、也更暗。横向拖动最前面一条，它 1:1 跟手，并绕底边每 100 pt 倾斜 7°；越过 90 pt 时以一次选择触感提示“可以甩了”。松手时若已过阈值，或甩动速度超过 600 pt/s，它就沿该方向继续飞出，离场时间 0.16–0.4 秒，由手指速度决定，途中继续旋转。随后整叠以弹簧（响应 0.42 秒、阻尼 0.72）向前递进，新的一条在最后淡入。拖得不够则弹回摆正。直接、有分量、用完即弃。"
        ),
        implementation: L(
            "The toasts are a ForEach over a queue; depth in the queue drives scale and lift through a value-keyed spring. The front toast adds the live drag as offset and rotation; a throw stores a fly-out offset for that id inside an ease-out whose duration is distance ÷ release velocity, and the id is removed after the flight.",
            "吐司是对队列的 ForEach，队列中的深度通过按值触发的弹簧驱动缩放与抬升。最前面一条叠加实时拖动的位移与旋转；甩出时为该 id 记录飞出位移，放在时长为“距离 ÷ 松手速度”的缓出动画里，飞行结束后再移除该 id。"
        ),
        apis: ["DragGesture", "DragGesture.Value.velocity", "rotationEffect(_:anchor:)", "animation(_:value:)", "spring(response:dampingFraction:)"],
        tags: ["toast", "swipe", "dismiss", "fling", "stack", "吐司", "滑动关闭", "甩动", "堆叠"],
        params: [
            .slider("threshold", L("Throw distance", "甩出距离"), 50...160, default: 90, decimals: 0, unit: "pt"),
            .slider("tilt", L("Tilt per 100 pt", "每 100 pt 倾斜"), 0...16, default: 7, decimals: 0, unit: "°"),
            .slider("damping", L("Stack damping", "递进阻尼"), 0.45...1.0, default: 0.72),
        ]
    ) { ctx in
        SwipeToastDemo(ctx: ctx)
    }
}

private struct SwipeToastItem {
    let symbol: String
    let tint: Color
    let title: LocalizedText
    let detail: LocalizedText
    let action: LocalizedText
}

private struct SwipeToastDemo: View {
    let ctx: DemoContext
    /// Toast ids, front first. A thrown toast stays here until its flight ends.
    @State private var queue: [Int] = [0, 1, 2]
    @State private var nextID = 3
    /// Live drag of the front toast.
    @State private var drag: CGSize
    /// Fly-out offsets of toasts that were thrown.
    @State private var thrown: [Int: CGSize] = [:]
    @State private var armed = false
    @State private var autoDirection: CGFloat = 1
    @State private var token = 0

    private static let items: [SwipeToastItem] = [
        SwipeToastItem(symbol: "archivebox.fill", tint: Palette.indigo, title: L("Conversation archived", "会话已归档"), detail: L("Design review · 12 messages", "设计评审 · 12 条消息"), action: L("Undo", "撤销")),
        SwipeToastItem(symbol: "link", tint: Palette.mint, title: L("Link copied", "链接已复制"), detail: L("Anyone with the link can view", "拿到链接的人都能查看"), action: L("Share", "分享")),
        SwipeToastItem(symbol: "tray.and.arrow.down.fill", tint: Palette.coral, title: L("Draft saved", "草稿已保存"), detail: L("Trip notes · just now", "旅行笔记 · 刚刚"), action: L("Open", "打开")),
        SwipeToastItem(symbol: "photo.on.rectangle.angled", tint: Palette.amber, title: L("2 photos moved", "已移动 2 张照片"), detail: L("To album Kyoto", "移至相簿“京都”"), action: L("View", "查看")),
        SwipeToastItem(symbol: "bell.slash.fill", tint: Palette.violet, title: L("Muted for 1 hour", "已静音 1 小时"), detail: L("Team channel", "团队频道"), action: L("Undo", "撤销")),
    ]

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the front toast mid-drag, tilted.
        _drag = State(initialValue: ctx.isStill ? CGSize(width: 62, height: -3) : .zero)
    }

    /// Toasts still in the stack (not flying away), front first.
    private var waiting: [Int] { queue.filter { thrown[$0] == nil } }
    private var front: Int? { waiting.first }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                page
                toasts
                    .padding(.bottom, 14)
            }
            .feedbackScene(height: 270)
            DemoHint(text: L("Swipe the toast away", "把吐司甩出去"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.0, delay: 0.7) { simulate() }
    }

    private var page: some View {
        VStack(spacing: 0) {
            FeedbackMockHeader(title: ctx.language == .zh ? "收件箱" : "Inbox", symbol: "square.and.pencil")
            FeedbackMockRows(count: 4, rowHeight: 48)
            Spacer(minLength: 0)
        }
        .frame(width: 300, height: 270)
    }

    private var toasts: some View {
        let order: [Int] = waiting
        return ZStack(alignment: .bottom) {
            ForEach(queue.reversed(), id: \.self) { id in
                toast(id: id, depth: order.firstIndex(of: id) ?? 0)
                    .transition(.opacity)
            }
        }
        .frame(width: 300, height: 100, alignment: .bottom)
        .contentShape(Rectangle())
        .pageSafeHorizontalDrag(onChanged: dragChanged, onEnded: dragEnded)
    }

    private func toast(id: Int, depth: Int) -> some View {
        let item: SwipeToastItem = Self.items[id % Self.items.count]
        let flying: CGSize? = thrown[id]
        let isFront: Bool = flying == nil && depth == 0
        let offset: CGSize = flying ?? (isFront ? drag : .zero)
        let level: CGFloat = flying == nil ? CGFloat(min(depth, 3)) : 0
        let tilt: Double = Double(offset.width) / 100 * ctx["tilt"]
        return SwipeToastCard(item: item, language: ctx.language, shade: Double(level) * 0.1)
            .scaleEffect(1 - 0.06 * level, anchor: .bottom)
            .offset(y: -11 * level)
            .opacity(level > 2 ? 0 : 1)
            .animation(.spring(response: 0.42, dampingFraction: ctx["damping"]), value: level)
            .rotationEffect(.degrees(tilt), anchor: .bottom)
            .offset(offset)
            .zIndex(flying == nil ? -Double(depth) : 1)
    }

    // MARK: Gesture

    private func dragChanged(_ value: DragGesture.Value) {
        guard front != nil else { return }
        token += 1
        drag = CGSize(width: value.translation.width, height: value.translation.height * 0.2)
        let nowArmed: Bool = abs(drag.width) > ctx.cg("threshold")
        if nowArmed != armed {
            armed = nowArmed
            Haptics.selection()
        }
    }

    private func dragEnded(_ value: DragGesture.Value?) {
        armed = false
        guard let id = front else { return }
        guard let value else {
            settle()
            return
        }
        let velocity: CGFloat = value.velocity.width
        let flicked: Bool = abs(velocity) > 600 && velocity * drag.width >= 0
        guard abs(drag.width) > ctx.cg("threshold") || flicked else {
            settle()
            return
        }
        let direction: CGFloat = (flicked ? velocity : drag.width) >= 0 ? 1 : -1
        throwAway(id, direction: direction, velocity: velocity, buzz: true)
    }

    private func settle() {
        withAnimation(.spring(response: 0.4, dampingFraction: ctx["damping"])) { drag = .zero }
    }

    /// The toast keeps the finger's direction and speed; the stack steps forward behind it.
    private func throwAway(_ id: Int, direction: CGFloat, velocity: CGFloat, buzz: Bool) {
        let start: CGSize = drag
        let distance: CGFloat = max(360 - abs(start.width), 120)
        let speed: CGFloat = max(abs(velocity), 760)
        let duration: Double = Double(min(max(distance / speed, 0.16), 0.4))
        if buzz { Haptics.tap(.light) }
        let arriving: Int = nextID
        nextID += 1
        withAnimation(.easeOut(duration: duration)) {
            thrown[id] = CGSize(width: direction * 360, height: start.height + 26)
            drag = .zero
            queue.append(arriving)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.1))
            queue.removeAll { $0 == id }
            thrown[id] = nil
        }
    }

    /// Preview and intro: a scripted drag, then the same throw a finger would trigger.
    private func simulate() {
        guard let id = front, thrown.isEmpty else { return }
        token += 1
        let current = token
        let direction: CGFloat = autoDirection
        autoDirection = -direction
        withAnimation(.easeInOut(duration: 0.5)) { drag = CGSize(width: direction * 66, height: -3) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.56))
            guard token == current, front == id else { return }
            throwAway(id, direction: direction, velocity: direction * 900, buzz: false)
        }
    }
}

private struct SwipeToastCard: View {
    let item: SwipeToastItem
    let language: AppLanguage
    /// Darkening of toasts further back in the stack.
    let shade: Double

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: item.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title, language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.detail, language)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(item.action, language)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hex: 0x9DB2FF))
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(width: 268, height: 58)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x26262D), Color(hex: 0x17171B)], startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(shade))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
    }
}
