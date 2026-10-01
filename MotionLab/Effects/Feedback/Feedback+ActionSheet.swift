import SwiftUI

// MARK: - Action sheet

extension Effect {
    static let feedbackActionSheet = Effect(
        id: "feedback.action-sheet",
        category: .feedback,
        interaction: .gesture,
        name: L("Cascading Action Sheet", "逐行升起的操作面板"),
        summary: L("An action sheet whose rows rise in one after another, whose destructive row blushes red under the finger, and which drops away at the speed you throw it.", "操作面板的各行依次升起，危险操作在指下泛红；向下一甩，面板以甩动的速度坠落离场。"),
        prompt: L(
            "Tapping the ••• button dims the page 32% and raises an action sheet on a spring (response 0.45 s, damping 0.8): a card of three 42 pt rows and a separate Cancel card. Each row rises a further 26 pt and fades in, staggered 50 ms from the top, so the list assembles as it arrives. A pressed row fills with an 8% tint and shrinks to 97%; the red Delete row fills red at 14% instead. Dragging the sheet down follows the finger while the dim lightens in proportion; upward drags rubber-band. Released past 70 pt or flicked faster than 500 pt/s, it falls on an accelerating curve lasting 0.14–0.34 s, set by the release velocity; otherwise it springs back. Choosing a row drops the sheet and a confirmation pill springs in at the top.",
            "点击“•••”，页面压暗 32%，操作面板以弹簧（响应 0.45 秒、阻尼 0.8）从底部升起：一张三行（每行 42 pt）的分组卡片和独立的“取消”卡片。每一行再各自上浮 26 pt 淡入，自上而下间隔 50 毫秒。按住的行填充 8% 底色并缩到 97%，红色“删除”行则填充 14% 的红。向下拖动时面板跟手，遮罩按比例变浅，向上拖有橡皮筋阻尼。松手时超过 70 pt 或速度大于 500 pt/s，面板沿加速曲线坠落，时长 0.14–0.34 秒由松手速度决定，否则弹回。选中一行后面板落下，顶部弹出确认胶囊。"
        ),
        implementation: L(
            "The sheet's offset is one value: its closed height when hidden, the live drag when open. Rows add their own delayed spring keyed on the open flag. A ButtonStyle tints the pressed row. The drag is a downward-only UIPanGestureRecognizer the page scroll waits for; on release the fall's duration is the remaining distance divided by the finger's velocity.",
            "面板位移是单一数值：隐藏时为自身高度，打开时为实时拖动量。各行以打开标志为键叠加各自带延迟的弹簧。按压着色由 ButtonStyle 完成。拖动来自只接受向下的 UIPanGestureRecognizer（页面滚动会等它失败）；松手后坠落时长等于剩余距离除以手指速度。"
        ),
        apis: ["UIGestureRecognizerRepresentable", "UIPanGestureRecognizer", "ButtonStyle", "animation(_:value:)", "timingCurve(_:_:_:_:duration:)", "spring(response:dampingFraction:)"],
        tags: ["action sheet", "menu", "destructive", "stagger", "dismiss", "操作面板", "菜单", "删除", "依次出现", "下拉关闭"],
        params: [
            .slider("stagger", L("Row stagger", "逐行间隔"), 0.0...0.12, default: 0.05, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.8, default: 0.45, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.55...1.0, default: 0.8),
        ]
    ) { ctx in
        ActionSheetDemo(ctx: ctx)
    }
}

private struct ActionSheetRow {
    let title: LocalizedText
    let done: LocalizedText
    let symbol: String
    let destructive: Bool
}

private enum ActionSheetData {
    static let rows: [ActionSheetRow] = [
        ActionSheetRow(title: L("Share", "分享"), done: L("Link shared", "已分享链接"), symbol: "square.and.arrow.up", destructive: false),
        ActionSheetRow(title: L("Duplicate", "复制一份"), done: L("Duplicated", "已复制一份"), symbol: "plus.square.on.square", destructive: false),
        ActionSheetRow(title: L("Delete", "删除"), done: L("Deleted", "已删除"), symbol: "trash", destructive: true),
    ]
    static let rowHeight: CGFloat = 42
    /// Rows + gap + Cancel + bottom inset.
    static let sheetHeight: CGFloat = 3 * 42 + 8 + 44 + 12
}

private struct ActionSheetDemo: View {
    let ctx: DemoContext
    @State private var open: Bool
    @State private var drag: CGFloat = 0
    @State private var forcedRow: Int?
    @State private var confirmation: Int?
    @State private var autoIndex = 0
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the sheet open.
        _open = State(initialValue: ctx.isStill)
    }

    private var zh: Bool { ctx.language == .zh }
    private var live: Bool { !ctx.isPreview && !ctx.isStill }
    private var closedOffset: CGFloat { ActionSheetData.sheetHeight + 20 }

    var body: some View {
        let openness: CGFloat = open ? max(0, 1 - max(drag, 0) / ActionSheetData.sheetHeight) : 0
        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                page
                Color.black
                    .opacity(0.32 * Double(openness))
                    .onTapGesture { close(velocity: 0) }
                    .allowsHitTesting(open)
                sheet
                    .offset(y: open ? drag : closedOffset)
                confirmationPill
                    .frame(width: 300, height: 280, alignment: .top)
            }
            .feedbackScene(height: 280)
            DemoHint(text: L("Tap •••, then pick a row or drag down", "点“•••”，再选一行或向下拖"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.6, delay: 0.5) { step() }
    }

    // MARK: Page

    private var page: some View {
        VStack(spacing: 0) {
            HStack {
                Text(zh ? "旅行计划" : "Trip plan")
                    .font(.headline)
                Spacer(minLength: 0)
                Button(action: present) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Palette.primaryStrong, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.aurora)
                .frame(width: 268, height: 84)
                .overlay(alignment: .bottomLeading) {
                    Text(zh ? "京都 · 5 天" : "Kyoto · 5 days")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                }
            FeedbackMockRows(count: 3, rowHeight: 44)
            Spacer(minLength: 0)
        }
        .frame(width: 300, height: 280)
    }

    // MARK: Sheet

    private var sheet: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                ForEach(ActionSheetData.rows.indices, id: \.self) { index in
                    row(index)
                }
            }
            .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .modifier(rise(0))
            Button { close(velocity: 0) } label: {
                Text(zh ? "取消" : "Cancel")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 276, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionSheetRowStyle(destructive: false, forced: false))
            .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .modifier(rise(ActionSheetData.rows.count))
        }
        .frame(width: 276)
        .padding(.bottom, 12)
        .shadow(color: .black.opacity(0.18), radius: 16, y: 4)
        .gesture(PageSafePan(directions: .down, isEnabled: live && open, onChanged: dragChanged, onEnded: dragEnded))
    }

    private func row(_ index: Int) -> some View {
        let item: ActionSheetRow = ActionSheetData.rows[index]
        return Button { choose(index) } label: {
            HStack {
                Text(item.title, ctx.language)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Image(systemName: item.symbol)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(item.destructive ? Palette.red : Color.primary)
            .padding(.horizontal, 16)
            .frame(width: 276, height: ActionSheetData.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(ActionSheetRowStyle(destructive: item.destructive, forced: forcedRow == index))
        .overlay(alignment: .top) {
            if index > 0 {
                Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5).padding(.leading, 16)
            }
        }
        .modifier(rise(index))
    }

    /// Each row lags the sheet a little more than the one above it.
    private func rise(_ index: Int) -> ActionSheetRise {
        let spring = Animation.spring(response: ctx["response"], dampingFraction: ctx["damping"]).delay(0.04 + Double(index) * ctx["stagger"])
        return ActionSheetRise(shown: open, animation: open ? spring : Animation.easeIn(duration: 0.15))
    }

    private var confirmationPill: some View {
        let item: ActionSheetRow? = confirmation.map { ActionSheetData.rows[$0] }
        let destructive: Bool = item?.destructive ?? false
        return HStack(spacing: 7) {
            Image(systemName: destructive ? "trash.fill" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(destructive ? Palette.red : Palette.green)
            Text(item?.done(ctx.language) ?? "")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Color(hex: 0x16161A), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .scaleEffect(confirmation == nil ? 0.8 : 1)
        .opacity(confirmation == nil ? 0 : 1)
        .offset(y: confirmation == nil ? -30 : 10)
        .allowsHitTesting(false)
    }

    // MARK: Actions

    /// Preview loop and intro: open, then press a row (Delete and Duplicate alternate).
    private func step() {
        guard open else {
            present()
            return
        }
        let index: Int = autoIndex % 2 == 0 ? 2 : 1
        autoIndex += 1
        token += 1
        let current = token
        forcedRow = index
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.32))
            forcedRow = nil
            guard token == current, open else { return }
            choose(index)
        }
    }

    private func present() {
        guard !open else { return }
        Haptics.tap()
        drag = 0
        withAnimation(.easeOut(duration: 0.15)) { confirmation = nil }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) { open = true }
    }

    /// Drops the sheet; a downward release velocity shortens the fall.
    private func close(velocity: CGFloat) {
        guard open else { return }
        let remaining: CGFloat = max(closedOffset - drag, 40)
        let speed: CGFloat = max(velocity, 760)
        let duration: Double = Double(min(max(remaining / speed, 0.14), 0.34))
        withAnimation(.timingCurve(0.4, 0.0, 0.9, 0.6, duration: duration)) {
            open = false
            drag = 0
        }
    }

    private func choose(_ index: Int) {
        guard open else { return }
        token += 1
        let current = token
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        if buzz {
            if ActionSheetData.rows[index].destructive { Haptics.tap(.rigid) } else { Haptics.tap() }
        }
        close(velocity: 0)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.22))
            guard token == current else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.68)) { confirmation = index }
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(1.5))
            guard token == current else { return }
            withAnimation(.easeIn(duration: 0.2)) { confirmation = nil }
        }
    }

    // MARK: Gesture

    private func dragChanged(_ translation: CGSize) {
        guard open else { return }
        let y: CGFloat = translation.height
        drag = y >= 0 ? y : rubberBand(y, limit: 50)
    }

    private func dragEnded(_ end: PageSafePanEnd?) {
        guard open else { return }
        let velocity: CGFloat = end?.velocity.height ?? 0
        if drag > 70 || velocity > 500 {
            Haptics.tap(.light)
            close(velocity: velocity)
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { drag = 0 }
        }
    }
}

/// A row's own rise inside the sheet.
private struct ActionSheetRise: ViewModifier {
    let shown: Bool
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .offset(y: shown ? 0 : 26)
            .opacity(shown ? 1 : 0)
            .animation(animation, value: shown)
    }
}

/// Tints the row under the finger: neutral for ordinary actions, red for the destructive one.
private struct ActionSheetRowStyle: ButtonStyle {
    let destructive: Bool
    let forced: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed: Bool = configuration.isPressed || forced
        let tint: Color = destructive ? Palette.red.opacity(0.14) : Color.primary.opacity(0.08)
        return configuration.label
            .scaleEffect(pressed ? 0.97 : 1)
            .background(tint.opacity(pressed ? 1 : 0))
            .animation(.easeOut(duration: pressed ? 0.08 : 0.25), value: pressed)
    }
}
