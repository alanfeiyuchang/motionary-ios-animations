import SwiftUI

extension Effect {
    static let gesturesPullToCreate = Effect(
        id: "gestures.pull-to-create",
        category: .gestures,
        interaction: .gesture,
        name: L("Pull to Create", "下拉新建"),
        summary: L("Pull a to-do list down and a new row unfolds from its top edge in 3D; let go past the threshold to keep it.", "把待办列表往下拉，新的一行从顶边以 3D 方式翻折展开；越过阈值松手即保留。"),
        prompt: L(
            "A full-bleed to-do list of five 52 pt rows in a heat-map gradient (red at the top to amber at the bottom) inside a 280 pt rounded panel. Dragging down moves the list 1:1 and a new row hinged on the list's top edge unfolds into the gap: its angle is acos(pull ∕ row height), so it starts edge-on and lies flat exactly when the gap equals one row, darkened by up to 55% while folded with a soft shadow under the hinge. Past the threshold its label flips from \"Pull to create\" to \"Release to create\" with a medium haptic, and further pull rubber-bands. Releasing there springs the row flat (response 0.3 s, damping 0.85), inserts it and types a title at 35 ms per character while every row re-tints; releasing early folds it away. Direct, spatial and rewarding.",
            "280 pt宽的圆角面板里是通栏待办列表：五行、每行52 pt，按热力渐变着色（顶部红、底部琥珀）。向下拖动时列表1:1跟手，一条铰接在列表顶边的新行翻折着填进空隙：角度为 acos(下拉距离 ∕ 行高)，起初侧立，空隙等于一行时恰好放平；折叠时最多压暗55%，铰链下有柔和阴影。越过阈值，文字从“下拉新建”换成“松手创建”，一次中等触感，继续下拉有橡皮筋阻尼。此时松手，新行以弹簧（响应0.3秒、阻尼0.85）放平并插入，标题以每字35毫秒打出，各行重新着色；提前松手则折回。"
        ),
        implementation: L(
            "A DragGesture writes the pull distance; an Animatable modifier turns it into rotation3DEffect about the row's bottom edge with angle acos(pull ∕ height), so the projected height always matches the gap, even mid-spring. On commit the spring's completion inserts the real row with animations disabled, which is visually identical to the unfolded one.",
            "DragGesture 写入下拉距离；一个 Animatable 修饰器把它换算成绕行底边的 rotation3DEffect，角度为 acos(下拉距离 ∕ 行高)，因此投影高度始终等于空隙，弹簧过程中也不例外。提交时在弹簧的 completion 中关闭动画插入真实的行，它与展开后的折叠行在视觉上完全一致。"
        ),
        apis: ["DragGesture", "rotation3DEffect", "Animatable", "withAnimation(_:completionCriteria:_:completion:)", "withTransaction"],
        tags: ["pull", "create", "fold", "3D", "to-do", "list", "下拉", "新建", "翻折", "待办", "列表"],
        params: [
            .slider("row", L("Row height", "行高"), 44...60, default: 52, step: 2, decimals: 0, unit: "pt"),
            .slider("threshold", L("Commit threshold", "提交阈值"), 0.6...1.3, default: 1.0, unit: "×"),
            .slider("perspective", L("Perspective", "透视强度"), 0.1...1.0, default: 0.6),
        ]
    ) { ctx in
        PullToCreateDemo(ctx: ctx)
    }
}

private struct PullTask: Identifiable, Equatable {
    let id: Int
    let title: LocalizedText

    static func == (lhs: PullTask, rhs: PullTask) -> Bool { lhs.id == rhs.id }
}

private let pullSeedTitles: [LocalizedText] = [
    L("Reply to Mina", "回复小敏"),
    L("Renew passport", "续签护照"),
    L("Fix the tab bar bug", "修复标签栏问题"),
    L("Book dentist", "预约牙医"),
    L("Plan the weekend", "安排周末"),
]

private let pullNewTitles: [LocalizedText] = [
    L("Buy coffee beans", "买咖啡豆"),
    L("Call the landlord", "给房东打电话"),
    L("Ship version 2.0", "发布 2.0 版本"),
    L("Water the plants", "给植物浇水"),
]

private enum PullHeat {
    /// Heat-map tint for a (fractional) row position.
    static func color(_ position: CGFloat) -> Color {
        let t: Double = Double((position / 5).clamped(to: 0...1))
        let top: (Double, Double, Double) = (0.93, 0.20, 0.30)
        let bottom: (Double, Double, Double) = (1.0, 0.70, 0.22)
        return Color(
            .sRGB,
            red: top.0 + (bottom.0 - top.0) * t,
            green: top.1 + (bottom.1 - top.1) * t,
            blue: top.2 + (bottom.2 - top.2) * t,
            opacity: 1
        )
    }
}

private struct PullToCreateDemo: View {
    let ctx: DemoContext
    @State private var items: [PullTask] = pullSeedTitles.enumerated().map { PullTask(id: $0.offset, title: $0.element) }
    @State private var pull: CGFloat = 0
    @State private var armed = false
    @State private var committing = false
    @State private var held = false
    @State private var nextID = 100
    @State private var typingID: Int?
    @State private var typed = 0
    @State private var script: Task<Void, Never>?
    @State private var typist: Task<Void, Never>?
    /// Resets on system cancellation too, so a stolen touch never leaves the list pulled down.
    @GestureState private var pressing = false

    private let width: CGFloat = 280

    var body: some View {
        let row = ctx.cg("row")
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        VStack(spacing: 12) {
            ZStack(alignment: .top) {
                Color.black.opacity(0.82)
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        PullRow(
                            text: rowText(item),
                            caret: typingID == item.id,
                            height: row
                        )
                        .modifier(PullTint(position: CGFloat(index), pull: pull, row: row))
                    }
                }
                .modifier(PullShift(pull: pull, row: row))

                PullRow(
                    text: (armed || committing ? L("Release to create", "松手创建") : L("Pull to create", "下拉新建"))(ctx.language),
                    caret: false,
                    height: row,
                    dim: committing
                )
                .background(PullHeat.color(0))
                .modifier(PullFold(pull: pull, row: row, perspective: ctx.cg("perspective")))
            }
            .frame(width: width, height: row * 5, alignment: .top)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 16, y: 10)
            .contentShape(shape)
            .gesture(drag)

            DemoHint(text: L("Pull the list down", "把列表往下拉"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.5) { autoPull() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing && held { release() }
        }
        .onDisappear {
            script?.cancel()
            typist?.cancel()
        }
    }

    private func rowText(_ item: PullTask) -> String {
        let full: String = item.title(ctx.language)
        guard typingID == item.id else { return full }
        return String(full.prefix(typed))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                guard !committing else { return }
                if !held {
                    held = true
                    script?.cancel()
                }
                dragChanged(value.translation.height)
            }
            .onEnded { _ in
                if held { release() }
            }
    }

    /// Finger (or ghost finger) moved: `translation` is the vertical drag distance.
    private func dragChanged(_ translation: CGFloat) {
        pull = max(translation, 0)
        let nowArmed: Bool = pull >= ctx.cg("row") * ctx.cg("threshold")
        if nowArmed != armed {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { armed = nowArmed }
            if held && !ctx.isPreview { Haptics.tap(.medium) }
        }
    }

    private func release() {
        held = false
        guard !committing else { return }
        let row = ctx.cg("row")
        if armed {
            committing = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85), completionCriteria: .logicallyComplete) {
                pull = row
            } completion: {
                finishCommit()
            }
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { pull = 0 }
        }
    }

    /// Swaps the unfolded placeholder for a real row. Nothing moves: the two look identical.
    private func finishCommit() {
        let task = PullTask(id: nextID, title: pullNewTitles[nextID % pullNewTitles.count])
        nextID += 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            items.insert(task, at: 0)
            if items.count > 5 { items.removeLast() }
            pull = 0
            armed = false
            committing = false
            typingID = task.id
            typed = ctx.isStill ? 99 : 0
        }
        if !ctx.isPreview { Haptics.success() }
        let length: Int = task.title(ctx.language).count
        typist?.cancel()
        typist = Task { @MainActor in
            for count in 0...length {
                try? await Task.sleep(for: .milliseconds(35))
                guard !Task.isCancelled else { return }
                typed = count
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            typingID = nil
        }
    }

    /// A scripted finger pulls past the threshold and lets go, through the same handlers as the drag.
    private func autoPull() {
        guard !held, !committing, pull == 0 else { return }
        let reach: CGFloat = ctx.cg("row") * max(ctx.cg("threshold"), 1) + 16
        script?.cancel()
        script = Task { @MainActor in
            let finished = await GhostFinger.drag(from: .zero, to: CGPoint(x: 0, y: reach), duration: 0.85) { point in
                dragChanged(point.y)
            }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            release()
        }
    }
}

/// How far the list really moves for a raw pull: 1:1 up to one row, rubber-banded beyond.
private func pullDisplayed(_ pull: CGFloat, row: CGFloat) -> CGFloat {
    pull <= row ? pull : row + rubberBand(pull - row, limit: 110)
}

private struct PullRow: View {
    let text: String
    let caret: Bool
    let height: CGFloat
    var dim = false

    var body: some View {
        HStack(spacing: 2) {
            Text(verbatim: text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.interpolate)
            if caret {
                Capsule()
                    .fill(.white)
                    .frame(width: 2, height: 18)
                    .phaseAnimator([1.0, 0.15]) { view, phase in
                        view.opacity(phase)
                    } animation: { _ in .easeInOut(duration: 0.45) }
            }
            Spacer(minLength: 0)
        }
        .opacity(dim ? 0 : 1)
        .padding(.horizontal, 18)
        .frame(height: height)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.black.opacity(0.14)).frame(height: 1)
        }
    }
}

/// Row tint that slides down the heat map as the new row makes room above.
private struct PullTint: ViewModifier, Animatable {
    let position: CGFloat
    var pull: CGFloat
    let row: CGFloat

    var animatableData: CGFloat {
        get { pull }
        set { pull = newValue }
    }

    func body(content: Content) -> some View {
        content.background(PullHeat.color(position + min(pull, row) / max(row, 1)))
    }
}

private struct PullShift: ViewModifier, Animatable {
    var pull: CGFloat
    let row: CGFloat

    var animatableData: CGFloat {
        get { pull }
        set { pull = newValue }
    }

    func body(content: Content) -> some View {
        let unfolded: CGFloat = 1 - (min(pull, row) / max(row, 1))
        content
            .overlay(alignment: .top) {
                // The folded row shades the list just under its hinge.
                LinearGradient(colors: [.black.opacity(0.3 * unfolded), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 14)
                    .allowsHitTesting(false)
            }
            .offset(y: pullDisplayed(pull, row: row))
    }
}

/// The new row: hinged on its bottom edge (the list's top), unfolding as the gap opens.
private struct PullFold: ViewModifier, Animatable {
    var pull: CGFloat
    let row: CGFloat
    let perspective: CGFloat

    var animatableData: CGFloat {
        get { pull }
        set { pull = newValue }
    }

    func body(content: Content) -> some View {
        let open: CGFloat = (min(pull, row) / max(row, 1)).clamped(to: 0...1)
        let angle: Double = acos(Double(open))
        content
            .overlay(Color.black.opacity(0.55 * (1 - Double(open))))
            .rotation3DEffect(.radians(angle), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: perspective)
            .offset(y: pullDisplayed(pull, row: row) - row)
            .opacity(pull > 0.5 ? 1 : 0)
    }
}
