import SwiftUI

extension Effect {
    static let gesturesKanbanDrag = Effect(
        id: "gestures.kanban-drag",
        category: .gestures,
        interaction: .gesture,
        name: L("Kanban Drag", "看板拖拽"),
        summary: L("Lift a card off a board, carry it across columns while slots open under it, and drop it into place.", "从看板上提起卡片，跨列拖动时下方自动让出空位，松手落入其中。"),
        prompt: L(
            "A three-column board (To do, Doing, Done; 94 pt columns, 9 pt gutters) holds 52 pt task cards with a colour tag, a title and an avatar. Touching a card lifts it at once: it scales to 106%, its shadow grows from 4 to 20 pt blur and it leans up to 9° with its lower edge trailing the motion, the lean following the finger on a lagging spring so it swings level when the hand pauses. While it hovers, the column under it tints, the count in each header rolls, and cards part on a spring (response 0.36 s, damping 0.78) to open a slot at the nearest index while the gap it left closes; every slot change ticks. On release the card flies into the slot on the same spring, levels out, and its shadow settles with a haptic tap. Physical, legible, calm.",
            "三列看板（待办、进行中、完成；每列94 pt、间距9 pt）里是52 pt高的任务卡片，带彩色标签、标题和头像。手指一碰卡片即被提起：放大到106%，投影模糊从4 pt增到20 pt，下缘拖在运动后方、倾斜最多9°；倾斜由滞后的弹簧跟随手指，手一停卡片自己摆正。悬停时下方的列泛起色调，标题里的计数滚动，其他卡片以弹簧（响应0.36秒、阻尼0.78）让出最近的一格，原空位同时合拢，每次换格有选择触感。松手后卡片以同一弹簧飞入空格、回正，投影收回，伴随一次触感。有实体感、清晰、沉稳。"
        ),
        implementation: L(
            "Every card is positioned explicitly from a layout function that removes the lifted card and inserts a gap at the hover target, so one withAnimation moves all neighbours; the lifted card follows a DragGesture in the board's coordinate space with animations disabled for its position. Its lean comes from an Animatable modifier comparing the finger's x with a spring-lagged copy.",
            "每张卡片的位置都由布局函数显式给出：先移除被提起的卡片，再在悬停目标处插入空位，因此一次 withAnimation 就能带动所有邻居；被提起的卡片在看板坐标系中跟随 DragGesture，并对其位置关闭动画。倾斜来自一个 Animatable 修饰器，它比较手指的 x 与一个由弹簧滞后的副本。"
        ),
        apis: ["DragGesture", "coordinateSpace(.named)", "Animatable", "withAnimation", "contentTransition(.numericText)"],
        tags: ["kanban", "board", "drag and drop", "columns", "reorder", "看板", "拖放", "跨列", "卡片", "排序"],
        params: [
            .slider("lift", L("Lift scale", "提起缩放"), 1.0...1.15, default: 1.06),
            .slider("tilt", L("Max lean", "最大倾斜"), 0...16, default: 9, step: 1, decimals: 0, unit: "°"),
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.7, default: 0.36, unit: "s"),
        ]
    ) { ctx in
        KanbanDragDemo(ctx: ctx)
    }
}

private enum Board {
    static let column: CGFloat = 94
    static let gutter: CGFloat = 9
    static let header: CGFloat = 36
    static let card = CGSize(width: 86, height: 52)
    static let spacing: CGFloat = 8
    static let capacity = 4
    static let size = CGSize(width: column * 3 + gutter * 2, height: header + CGFloat(capacity) * (card.height + spacing) + 4)
    static let space = "kanbanBoard"

    static func centre(column index: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(index) * (column + gutter) + column / 2,
            y: header + CGFloat(row) * (card.height + spacing) + card.height / 2
        )
    }
}

private struct KanbanCard: Identifiable, Equatable {
    let id: Int
    let title: LocalizedText
    let tint: Color

    static func == (lhs: KanbanCard, rhs: KanbanCard) -> Bool { lhs.id == rhs.id }
}

private let kanbanSeed: [[KanbanCard]] = [
    [
        KanbanCard(id: 0, title: L("Onboarding", "引导页"), tint: Palette.indigo),
        KanbanCard(id: 1, title: L("Dark mode", "深色模式"), tint: Palette.violet),
        KanbanCard(id: 2, title: L("Search", "搜索"), tint: Palette.sky),
    ],
    [
        KanbanCard(id: 3, title: L("Checkout", "支付流程"), tint: Palette.coral),
        KanbanCard(id: 4, title: L("Push alerts", "推送通知"), tint: Palette.amber),
    ],
    [
        KanbanCard(id: 5, title: L("Sign-in", "登录页"), tint: Palette.mint),
    ],
]

private let kanbanTitles: [LocalizedText] = [L("To do", "待办"), L("Doing", "进行中"), L("Done", "完成")]

private struct KanbanSlot: Equatable {
    var column: Int
    var row: Int
}

private struct KanbanDragDemo: View {
    let ctx: DemoContext
    @State private var columns: [[KanbanCard]] = kanbanSeed
    @State private var draggingID: Int?
    @State private var origin = KanbanSlot(column: 0, row: 0)
    @State private var target = KanbanSlot(column: 0, row: 0)
    @State private var dragPoint: CGPoint = .zero
    @State private var lagX: CGFloat = 0
    @State private var grabOffset: CGSize = .zero
    @State private var held = false
    /// False on the frame a card is lifted, so the lagging copy starts under the finger without a swing.
    @State private var tracking = false
    @State private var script: Task<Void, Never>?
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        if ctx.isStill {
            // The thumbnail shows a card mid-carry, with its slot already open in the next column.
            _draggingID = State(initialValue: 1)
            _origin = State(initialValue: KanbanSlot(column: 0, row: 1))
            _target = State(initialValue: KanbanSlot(column: 1, row: 1))
            _dragPoint = State(initialValue: CGPoint(x: 112, y: 128))
            _lagX = State(initialValue: 96)
        }
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: 0.78) }

    var body: some View {
        let slots = layout()
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { index in
                    KanbanColumn(
                        title: kanbanTitles[index](ctx.language),
                        count: count(in: index),
                        highlighted: draggingID != nil && target.column == index
                    )
                    .frame(width: Board.column, height: Board.size.height)
                    .offset(x: CGFloat(index) * (Board.column + Board.gutter))
                }
                ForEach(columns.flatMap { $0 }) { card in
                    let lifted: Bool = draggingID == card.id
                    let slot: KanbanSlot = slots[card.id] ?? KanbanSlot(column: 0, row: 0)
                    KanbanCardView(card: card, language: ctx.language, lifted: lifted)
                        .frame(width: Board.card.width, height: Board.card.height)
                        .scaleEffect(lifted ? ctx.cg("lift") : 1)
                        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: lifted)
                        .modifier(KanbanLean(x: dragPoint.x, lagX: lagX, amount: lifted ? 1 : 0, limit: ctx["tilt"]))
                        .animation(tracking ? .spring(response: 0.34, dampingFraction: 0.72) : nil, value: lagX)
                        .gesture(drag(card))
                        .position(lifted ? dragPoint : Board.centre(column: slot.column, row: slot.row))
                        // The lifted card tracks the finger exactly, even on frames where neighbours animate.
                        .transaction { transaction in
                            if lifted { transaction.animation = nil }
                        }
                        .zIndex(lifted ? 10 : 0)
                }
            }
            .frame(width: Board.size.width, height: Board.size.height, alignment: .topLeading)
            .coordinateSpace(.named(Board.space))

            DemoHint(text: L("Drag a card to another column", "把卡片拖到另一列"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.5) { autoMove() }
        .onDisappear { script?.cancel() }
    }

    // MARK: Layout

    /// Where every resting card sits: the lifted card is taken out and a gap opens at the hover target.
    private func layout() -> [Int: KanbanSlot] {
        var result: [Int: KanbanSlot] = [:]
        for (columnIndex, cards) in columns.enumerated() {
            var row = 0
            for card in cards where card.id != draggingID {
                if draggingID != nil && target.column == columnIndex && target.row == row { row += 1 }
                result[card.id] = KanbanSlot(column: columnIndex, row: row)
                row += 1
            }
        }
        return result
    }

    private func count(in column: Int) -> Int {
        let resting: Int = columns[column].filter { $0.id != draggingID }.count
        return resting + (draggingID != nil && target.column == column ? 1 : 0)
    }

    private func slot(of id: Int) -> KanbanSlot? {
        for (columnIndex, cards) in columns.enumerated() {
            if let row = cards.firstIndex(where: { $0.id == id }) { return KanbanSlot(column: columnIndex, row: row) }
        }
        return nil
    }

    // MARK: Drag

    private func drag(_ card: KanbanCard) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Board.space))
            .onChanged { value in
                if draggingID == nil {
                    script?.cancel()
                    guard let home = slot(of: card.id) else { return }
                    let centre = Board.centre(column: home.column, row: home.row)
                    grabOffset = CGSize(width: value.startLocation.x - centre.x, height: value.startLocation.y - centre.y)
                    held = true
                    lift(card.id)
                    if !ctx.isPreview { Haptics.tap(.light) }
                }
                guard draggingID == card.id, held else { return }
                dragMoved(CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
            }
            .onEnded { _ in
                guard draggingID == card.id, held else { return }
                drop()
            }
    }

    private func lift(_ id: Int) {
        guard let home = slot(of: id) else { return }
        let centre = Board.centre(column: home.column, row: home.row)
        origin = home
        target = home
        dragPoint = centre
        tracking = false
        lagX = centre.x
        draggingID = id
    }

    /// The card's centre follows `point`; the hover target is the nearest free slot.
    private func dragMoved(_ point: CGPoint) {
        guard let id = draggingID else { return }
        dragPoint = CGPoint(
            x: point.x.clamped(to: 20...(Board.size.width - 20)),
            y: point.y.clamped(to: 20...(Board.size.height - 10))
        )
        tracking = true
        lagX = dragPoint.x

        let columnIndex: Int = Int((dragPoint.x / (Board.column + Board.gutter)).rounded(.down)).clamped(to: 0...2)
        let others: Int = columns[columnIndex].filter { $0.id != id }.count
        var next = target
        if others < Board.capacity {
            let raw: CGFloat = (dragPoint.y - Board.header - Board.card.height / 2) / (Board.card.height + Board.spacing)
            next = KanbanSlot(column: columnIndex, row: Int(raw.rounded()).clamped(to: 0...others))
        }
        if next != target {
            withAnimation(spring) { target = next }
            if held && !ctx.isPreview { Haptics.selection() }
        }
    }

    private func drop() {
        guard let id = draggingID, let home = slot(of: id) else { return }
        let card = columns[home.column][home.row]
        let moved: Bool = target != origin
        withAnimation(spring) {
            columns[home.column].remove(at: home.row)
            let row: Int = min(target.row, columns[target.column].count)
            columns[target.column].insert(card, at: row)
            draggingID = nil
            lagX = dragPoint.x
        }
        if held && !ctx.isPreview { Haptics.tap(moved ? .medium : .soft) }
        held = false
    }

    /// A scripted finger carries the top card of the fullest column to the next column, through the
    /// same lift / dragMoved / drop the real drag calls.
    private func autoMove() {
        guard draggingID == nil, !held else { return }
        autoStep += 1
        guard let from = columns.indices.max(by: { columns[$0].count < columns[$1].count }), let card = columns[from].first else { return }
        var to: Int = (from + 1 + autoStep % 2) % 3
        if columns[to].count >= Board.capacity { to = (to + 1) % 3 }
        guard to != from else { return }
        let start = Board.centre(column: from, row: 0)
        let end = Board.centre(column: to, row: min(columns[to].count, 1))
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) + 96)
        lift(card.id)
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            let finished = await GhostFinger.drag(from: start, to: end, control: control, duration: 0.95) { point in dragMoved(point) }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            drop()
        }
    }
}

// MARK: - Pieces

/// Leans the lifted card against its direction of travel: the angle is the gap between the finger
/// and a spring-lagged copy of it, so it swings level by itself when the hand pauses.
private struct KanbanLean: ViewModifier, Animatable {
    let x: CGFloat
    var lagX: CGFloat
    var amount: CGFloat
    let limit: Double

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(lagX, amount) }
        set {
            lagX = newValue.first
            amount = newValue.second
        }
    }

    func body(content: Content) -> some View {
        let degrees: Double = (Double(x - lagX) * 0.45).clamped(to: -abs(limit)...abs(limit)) * Double(amount)
        content.rotationEffect(.degrees(degrees), anchor: .top)
    }
}

private struct KanbanColumn: View {
    let title: String
    let count: Int
    let highlighted: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(verbatim: title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text(verbatim: "\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: Double(count)))
                    .foregroundStyle(highlighted ? Color.white : Color.secondary)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(highlighted ? Palette.indigo : Color.primary.opacity(0.08), in: Capsule())
            }
            .padding(.horizontal, 8)
            .frame(height: Board.header - 6)
            Spacer(minLength: 0)
        }
        .background(shape.fill(Palette.indigo.opacity(highlighted ? 0.14 : 0)))
        .background(shape.fill(Palette.elevated))
        .overlay(shape.strokeBorder(highlighted ? Palette.indigo.opacity(0.7) : Palette.stroke, lineWidth: highlighted ? 1.5 : 1))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: highlighted)
        .animation(.snappy(duration: 0.25), value: count)
    }
}

private struct KanbanCardView: View {
    let card: KanbanCard
    let language: AppLanguage
    let lifted: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(alignment: .leading, spacing: 5) {
            Capsule()
                .fill(card.tint)
                .frame(width: 22, height: 5)
            Text(card.title, language)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(spacing: 4) {
                Circle()
                    .fill(LinearGradient(colors: [card.tint, card.tint.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 11, height: 11)
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 30, height: 4)
            }
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(shape.fill(colorScheme == .dark ? Color(hex: 0x3A3A40) : Color.white))
        .overlay(shape.strokeBorder(lifted ? card.tint.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(lifted ? 0.28 : 0.1), radius: lifted ? 20 : 4, y: lifted ? 12 : 2)
        .contentShape(shape)
    }
}
