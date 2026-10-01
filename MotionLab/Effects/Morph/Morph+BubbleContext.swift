import SwiftUI

extension Effect {
    static let morphBubbleContext = Effect(
        id: "morph.bubble-context",
        category: .morph,
        interaction: .gesture,
        name: L("Bubble Context Lift", "气泡上下文浮起"),
        summary: L(
            "Hold a chat bubble: it dips, lifts out of the thread, and a reaction bar and menu grow from its corners while everything else blurs.",
            "按住聊天气泡：它先下沉再浮出对话，表情栏和菜单从它的边角长出来，其余内容随之模糊。"
        ),
        prompt: L(
            "A chat thread of rounded bubbles. Touching a bubble dips it to 96%; after a 0.3 s hold it lifts on a spring (response 0.42 s, damping 0.74) to 104% with a deep shadow and glides to a spot where its attachments fit, while the rest of the thread blurs 6 pt, dims and sinks to 97%. A capsule reaction bar grows from the bubble's top corner (scale 0.3 → 1), its six glyphs popping in 35 ms apart with an overshoot; a three-row menu unfolds from the bottom corner 70 ms later, rows fading in sequence. Choosing a reaction makes that glyph jump to 145%, then everything retracts and a small badge pops onto the bubble's corner. Tapping the dimmed thread dismisses. Tactile, layered, with a medium haptic at lift-off.",
            "由圆角气泡组成的聊天对话。手指按上气泡，它先缩到 96%；按住 0.3 秒后乘弹簧（响应 0.42 秒、阻尼 0.74）浮起到 104%，投下深阴影，并滑到能放下附属控件的位置，其余对话模糊 6pt、压暗并缩到 97%。胶囊形表情栏从气泡上角长出（缩放 0.3 → 1），六个符号间隔 35 毫秒带过冲依次弹出；70 毫秒后三行菜单从下角展开，各行依次淡入。选中一个表情时它先跳到 145%，随后一切收回，气泡角上弹出一枚小角标。点压暗的对话即可取消。有触感、有层次，浮起瞬间给一次中等触觉反馈。"
        ),
        implementation: L(
            "The thread is drawn twice: a blurred layer with the selected bubble hidden, and a clear overlay holding only that bubble at the same frame, so lifting never pops. The bar and menu are scaled from the anchor nearest the bubble, and each glyph has its own delayed spring keyed to the lifted flag.",
            "对话画两层：一层可模糊，隐藏被选中的气泡；另一层只在同一位置画这枚气泡，所以浮起时不会跳变。表情栏和菜单从最靠近气泡的锚点缩放，每个符号各带一条延迟弹簧，统一由「已浮起」状态驱动。"
        ),
        apis: ["onLongPressGesture", "scaleEffect(_:anchor:)", "blur", "spring(response:dampingFraction:)", "UnevenRoundedRectangle"],
        tags: ["context menu", "reaction", "tapback", "chat", "long press", "上下文菜单", "表情回应", "聊天", "长按"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.9, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.74),
            .slider("stagger", L("Glyph stagger", "符号错峰"), 0...0.1, default: 0.035, decimals: 3, unit: "s"),
            .slider("blur", L("Thread blur", "对话模糊"), 0...12, default: 6, decimals: 1, unit: "pt"),
        ]
    ) { ctx in
        BubbleContextDemo(ctx: ctx)
    }
}

private struct BubbleMessage {
    let text: LocalizedText
    let mine: Bool
    let size: CGSize
    let top: CGFloat

    var rect: CGRect {
        let x: CGFloat = mine ? BubbleLayout.size.width - 12 - size.width : 12
        return CGRect(x: x, y: top, width: size.width, height: size.height)
    }
}

private enum BubbleLayout {
    static let size = CGSize(width: 316, height: 306)
    static let barSize = CGSize(width: 236, height: 44)
    static let menuSize = CGSize(width: 172, height: 114)
    static let gap: CGFloat = 8
}

private let bubbleMessages: [BubbleMessage] = [
    BubbleMessage(text: L("Did you see the venue photos?", "场地的照片你看了吗？"), mine: false, size: CGSize(width: 214, height: 36), top: 14),
    BubbleMessage(text: L("Yes! The rooftop is perfect", "看了！那个露台太合适了"), mine: true, size: CGSize(width: 200, height: 36), top: 58),
    BubbleMessage(text: L("Let's book it for the 14th before someone else does", "那就订 14 号吧，别被别人抢先了"), mine: false, size: CGSize(width: 218, height: 54), top: 102),
    BubbleMessage(text: L("Booking now", "我这就订"), mine: true, size: CGSize(width: 112, height: 36), top: 164),
    BubbleMessage(text: L("You're the best", "你最靠谱了"), mine: false, size: CGSize(width: 128, height: 36), top: 208),
]

private struct BubbleGlyph {
    let symbol: String
    let color: Color
}

private let bubbleGlyphs: [BubbleGlyph] = [
    BubbleGlyph(symbol: "heart.fill", color: Palette.pink),
    BubbleGlyph(symbol: "hand.thumbsup.fill", color: Palette.blue),
    BubbleGlyph(symbol: "hand.thumbsdown.fill", color: Palette.indigo),
    BubbleGlyph(symbol: "face.smiling.inverse", color: Palette.amber),
    BubbleGlyph(symbol: "exclamationmark.2", color: Palette.coral),
    BubbleGlyph(symbol: "questionmark", color: Palette.violet),
]

private struct BubbleContextDemo: View {
    let ctx: DemoContext
    @State private var selected: Int
    @State private var lifted: Bool
    @State private var pressed: Int?
    @State private var chosen: Int?
    @State private var reactions: [Int: Int]
    @State private var autoStep = 0
    @State private var task: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _selected = State(initialValue: 2)
        _lifted = State(initialValue: ctx.isStill)
        _reactions = State(initialValue: ctx.isStill ? [1: 0] : [:])
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        VStack(spacing: 10) {
            screen
            DemoHint(
                text: lifted ? L("Pick a reaction", "选一个表情") : L("Touch and hold a bubble", "按住一条气泡"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.35) { autoplayStep() }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private var screen: some View {
        ZStack(alignment: .topLeading) {
            Palette.surface
            thread
                .scaleEffect(lifted ? 0.97 : 1)
                .blur(radius: lifted ? ctx.cg("blur") : 0)
            Color.black
                .opacity(lifted ? 0.22 : 0)
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .allowsHitTesting(lifted)
            focus
        }
        .morphScreen()
    }

    /// Everything that can blur: the bubbles (minus the selected one) and the composer.
    private var thread: some View {
        ZStack(alignment: .topLeading) {
            ForEach(bubbleMessages.indices, id: \.self) { index in
                let message: BubbleMessage = bubbleMessages[index]
                BubbleView(message: message, reaction: reactions[index], language: ctx.language)
                    .scaleEffect(pressed == index && index != selected ? 0.96 : 1)
                    // Not fully transparent, so a hold that began here keeps tracking once the overlay copy takes over.
                    .opacity(index == selected ? 0.001 : 1)
                    .position(x: message.rect.midX, y: message.rect.midY)
                    .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 24) {
                        lift(index)
                    } onPressingChanged: { pressing in
                        press(index, pressing)
                    }
            }
            BubbleComposer(zh: zh)
                .position(x: BubbleLayout.size.width / 2, y: BubbleLayout.size.height - 28)
        }
        .frame(width: BubbleLayout.size.width, height: BubbleLayout.size.height)
    }

    /// The selected bubble with its reaction bar and menu, above the blur.
    private var focus: some View {
        let message: BubbleMessage = bubbleMessages[selected]
        let rect: CGRect = message.rect
        let lowest: CGFloat = BubbleLayout.size.height - 10 - BubbleLayout.menuSize.height - BubbleLayout.gap - rect.height
        let highest: CGFloat = BubbleLayout.barSize.height + BubbleLayout.gap + 8
        let top: CGFloat = min(max(rect.minY, highest), lowest)
        let shift: CGFloat = lifted ? top - rect.minY : 0
        let barX: CGFloat = message.mine
            ? BubbleLayout.size.width - 30 - BubbleLayout.barSize.width / 2
            : 12 + BubbleLayout.barSize.width / 2
        let menuX: CGFloat = message.mine
            ? BubbleLayout.size.width - 12 - BubbleLayout.menuSize.width / 2
            : 12 + BubbleLayout.menuSize.width / 2
        let stagger: Double = ctx["stagger"]
        return ZStack(alignment: .topLeading) {
            BubbleReactionBar(lifted: lifted, chosen: chosen, stagger: stagger) { react($0) }
                .scaleEffect(lifted ? 1 : 0.3, anchor: message.mine ? .bottomTrailing : .bottomLeading)
                .opacity(lifted ? 1 : 0)
                .position(x: barX, y: rect.minY + shift - BubbleLayout.gap - BubbleLayout.barSize.height / 2)
                .allowsHitTesting(lifted)
            BubbleMenu(lifted: lifted, zh: zh) { dismiss() }
                .scaleEffect(lifted ? 1 : 0.3, anchor: message.mine ? .topTrailing : .topLeading)
                .opacity(lifted ? 1 : 0)
                .animation(spring.delay(lifted ? 0.07 : 0), value: lifted)
                .position(x: menuX, y: rect.maxY + shift + BubbleLayout.gap + BubbleLayout.menuSize.height / 2)
                .allowsHitTesting(lifted)
            BubbleView(message: message, reaction: reactions[selected], language: ctx.language)
                .scaleEffect(pressed == selected && !lifted ? 0.96 : (lifted ? 1.04 : 1))
                .shadow(color: .black.opacity(lifted ? 0.3 : 0), radius: lifted ? 18 : 0, y: lifted ? 10 : 0)
                .position(x: rect.midX, y: rect.midY + shift)
                .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 24) {
                    lift(selected)
                } onPressingChanged: { pressing in
                    press(selected, pressing)
                }
        }
        .frame(width: BubbleLayout.size.width, height: BubbleLayout.size.height)
    }

    // MARK: Actions

    private func press(_ index: Int, _ pressing: Bool) {
        guard !lifted else { return }
        if pressing {
            // The overlay copy takes over the pressed bubble before it moves, with no animation.
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { selected = index }
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { pressed = pressing ? index : nil }
    }

    private func lift(_ index: Int) {
        guard !lifted else { return }
        task?.cancel()
        if !ctx.isPreview { Haptics.tap(.medium) }
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) {
            selected = index
            chosen = nil
        }
        withAnimation(spring) {
            lifted = true
            pressed = nil
        }
    }

    private func dismiss() {
        guard lifted else { return }
        task?.cancel()
        withAnimation(spring) { lifted = false }
    }

    private func react(_ glyph: Int) {
        guard lifted, chosen == nil else { return }
        let preview: Bool = ctx.isPreview
        if !preview { Haptics.tap(.rigid) }
        let index: Int = selected
        withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) { chosen = glyph }
        let settle: Animation = spring
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.26))
            guard !Task.isCancelled else { return }
            withAnimation(settle) { lifted = false }
            try? await Task.sleep(for: .seconds(0.14))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) {
                if reactions[index] == glyph { reactions[index] = nil } else { reactions[index] = glyph }
            }
        }
    }

    private func autoplayStep() {
        switch autoStep % 4 {
        case 0: lift(2)
        case 1: react(autoStep / 4 % 2 == 0 ? 0 : 3)
        case 2: lift(1)
        default: react(autoStep / 4 % 2 == 0 ? 1 : 4)
        }
        autoStep += 1
    }
}

private struct BubbleView: View {
    let message: BubbleMessage
    let reaction: Int?
    let language: AppLanguage

    var body: some View {
        let mine: Bool = message.mine
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: mine ? 18 : 6,
            bottomTrailingRadius: mine ? 6 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
        Text(message.text, language)
            .font(.system(size: 14))
            .lineSpacing(1)
            .multilineTextAlignment(.leading)
            .foregroundStyle(mine ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
            .padding(.horizontal, 13)
            .frame(width: message.size.width, height: message.size.height, alignment: .leading)
            .background {
                if mine {
                    shape.fill(Palette.primaryStrong)
                } else {
                    shape.fill(Palette.elevated)
                }
            }
            .contentShape(shape)
            .overlay(alignment: mine ? .topLeading : .topTrailing) {
                if let reaction {
                    let glyph: BubbleGlyph = bubbleGlyphs[reaction]
                    Image(systemName: glyph.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(glyph.color, in: Circle())
                        .overlay(Circle().strokeBorder(Palette.surface, lineWidth: 2))
                        .offset(x: mine ? -9 : 9, y: -11)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
    }
}

private struct BubbleReactionBar: View {
    let lifted: Bool
    let chosen: Int?
    let stagger: Double
    let onPick: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(bubbleGlyphs.indices, id: \.self) { index in
                let glyph: BubbleGlyph = bubbleGlyphs[index]
                let isChosen: Bool = chosen == index
                Button { onPick(index) } label: {
                    Image(systemName: glyph.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isChosen ? AnyShapeStyle(Color.white) : AnyShapeStyle(glyph.color))
                        .frame(width: 36, height: 36)
                        .background(glyph.color.opacity(isChosen ? 1 : 0), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect(isChosen ? 1.45 : 1)
                .offset(y: isChosen ? -8 : 0)
                .zIndex(isChosen ? 1 : 0)
                .scaleEffect(lifted ? 1 : 0.2)
                .opacity(lifted ? 1 : 0)
                .animation(
                    .spring(response: 0.34, dampingFraction: 0.55).delay(lifted ? 0.06 + Double(index) * stagger : 0),
                    value: lifted
                )
            }
        }
        .frame(width: BubbleLayout.barSize.width, height: BubbleLayout.barSize.height)
        .background(Palette.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.stroke))
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
    }
}

private struct BubbleMenu: View {
    let lifted: Bool
    let zh: Bool
    let onPick: () -> Void

    private static let rows: [(LocalizedText, String)] = [
        (L("Reply", "回复"), "arrowshape.turn.up.left"),
        (L("Copy", "拷贝"), "doc.on.doc"),
        (L("Delete", "删除"), "trash"),
    ]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 0) {
            ForEach(BubbleMenu.rows.indices, id: \.self) { index in
                let row = BubbleMenu.rows[index]
                let destructive: Bool = index == 2
                Button(action: onPick) {
                    HStack {
                        Text(row.0, zh ? .zh : .en)
                            .font(.system(size: 14))
                        Spacer()
                        Image(systemName: row.1)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(destructive ? AnyShapeStyle(Palette.red) : AnyShapeStyle(Color.primary))
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(lifted ? 1 : 0)
                .animation(.easeOut(duration: 0.2).delay(lifted ? 0.14 + Double(index) * 0.05 : 0), value: lifted)
                .overlay(alignment: .top) {
                    if index > 0 {
                        Rectangle()
                            .fill(Palette.stroke)
                            .frame(height: 1)
                    }
                }
            }
        }
        .frame(width: BubbleLayout.menuSize.width, height: BubbleLayout.menuSize.height)
        .background(Palette.elevated, in: shape)
        .overlay(shape.strokeBorder(Palette.stroke))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }
}

private struct BubbleComposer: View {
    let zh: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Palette.elevated, in: Circle())
            HStack {
                Text(verbatim: zh ? "发消息" : "Message")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                Spacer()
                Image(systemName: "mic.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Palette.elevated, in: Capsule())
        }
        .padding(.horizontal, 12)
        .frame(width: BubbleLayout.size.width)
        .allowsHitTesting(false)
    }
}
