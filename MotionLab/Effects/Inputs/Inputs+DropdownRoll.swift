import SwiftUI

extension Effect {
    static let inputsDropdownRoll = Effect(
        id: "inputs.dropdown-roll",
        category: .inputs,
        interaction: .tap,
        name: L("Unrolling Select Menu", "卷轴下拉选择"),
        summary: L("The field unrolls into a list around the selected row, which never moves; your choice draws a check and the list rolls back into it.", "输入框以当前选项为中心展开成列表，选中行原地不动；选择后勾号画出，列表再卷回输入框。"),
        prompt: L(
            "A select field, 280 × 48 pt with 16 pt corners, showing the current option and an up-down chevron. Tapping unrolls it into a five-row list in place: the selected row stays where the field was while the other rows hinge out of it above and below, each rotating from 75° to flat around the edge it shares with its neighbour, fading in and pushing the next row outward. Rows are staggered 20% per step away from the selection and driven by one spring (response 0.42 s, damping 0.74); the panel and its shadow grow with them and the chevron fades into a checkmark. Choosing a row draws its check with a 220 ms trim while the old one un-draws, with a selection haptic; 260 ms later the list rolls back up into the chosen row, which glides to the field's position (damping 0.86).",
            "280 × 48pt、16pt 圆角的选择框，带上下箭头。点击后它在原位展开成五行列表：选中行停在输入框原位不动，其余各行从它上下两侧像合页一样翻出，每行绕与相邻行共用的边从 75° 转到平放，同时淡入并把下一行向外推。各行按离选中行的距离逐级错开 20%，由同一个弹簧驱动（响应 0.42 秒、阻尼 0.74）；面板与阴影随之长大，箭头淡出换成勾号。选择某一行时，勾号以 220 毫秒的 trim 画出，旧勾号同时擦除；260 毫秒后列表卷回被选中的那一行，它滑到输入框的位置（阻尼 0.86）。"
        ),
        implementation: L(
            "An Animatable view over one open value lays the rows out by hand: each row's own progress is the open value delayed by its distance from the selection, its position is the running sum of the progress of the rows before it, and rotation3DEffect hinges it on the shared edge. Re-anchoring on the chosen row is an extra offset multiplied by the open value, so it is continuous at both ends.",
            "以单个展开值为动画数据的 Animatable 视图手动排布各行：每行的进度是展开值按其与选中行的距离延迟后的结果，偏移量是它之前各行进度的累加，rotation3DEffect 让它绕共用的边翻转。重新锚定到新选中行靠的是一个乘以展开值的附加偏移，因此首尾两端都连续。"
        ),
        apis: ["Animatable", "rotation3DEffect(_:axis:anchor:perspective:)", "trim(from:to:)", "spring(response:dampingFraction:)", "zIndex"],
        tags: ["dropdown", "select", "menu", "picker", "unroll", "下拉", "选择器", "菜单", "展开", "勾选"],
        params: [
            .slider("stagger", L("Row stagger", "逐行错开"), 0...0.4, default: 0.2),
            .slider("response", L("Unroll response", "展开响应"), 0.25...0.8, default: 0.42, unit: "s"),
            .slider("damping", L("Unroll damping", "展开阻尼"), 0.5...1.0, default: 0.74),
            .slider("tilt", L("Hinge angle", "翻转角度"), 0...90, default: 75, decimals: 0, unit: "°"),
        ]
    ) { ctx in
        InputDropdownRollDemo(ctx: ctx)
    }
}

private struct InputRollOption {
    let symbol: String
    let tint: Color
    let title: LocalizedText
    let price: LocalizedText
    let arrival: LocalizedText

    static let all: [InputRollOption] = [
        InputRollOption(symbol: "shippingbox.fill", tint: Palette.blue, title: L("Standard", "标准配送"), price: L("Free", "免费"), arrival: L("Arrives Friday", "预计周五送达")),
        InputRollOption(symbol: "hare.fill", tint: Palette.mint, title: L("Next day", "次日达"), price: L("$4.99", "¥12"), arrival: L("Arrives tomorrow", "预计明天送达")),
        InputRollOption(symbol: "bolt.fill", tint: Palette.amber, title: L("Same day", "当日达"), price: L("$9.99", "¥25"), arrival: L("Arrives by 9 pm today", "预计今晚 9 点前送达")),
        InputRollOption(symbol: "storefront.fill", tint: Palette.coral, title: L("Store pickup", "到店自取"), price: L("Free", "免费"), arrival: L("Ready in 2 hours", "2 小时后可取")),
        InputRollOption(symbol: "calendar", tint: Palette.violet, title: L("Scheduled", "预约配送"), price: L("$2.99", "¥8"), arrival: L("Pick a time slot", "自选送达时段")),
    ]
}

private struct InputDropdownRollDemo: View {
    let ctx: DemoContext
    @State private var selected = 1
    /// The row the open list is anchored on (it stays where the field was).
    @State private var origin = 1
    @State private var checked = 1
    @State private var open: CGFloat
    @State private var isOpen: Bool
    @State private var step = 0
    @State private var closeTask: Task<Void, Never>?
    @State private var introTask: Task<Void, Never>?

    private static let targets = [3, 0, 2, 4, 1]

    init(ctx: DemoContext) {
        self.ctx = ctx
        _open = State(initialValue: ctx.isStill ? 1 : 0)
        _isOpen = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                if isOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { close(picking: selected) }
                }
                context
                InputRollMenu(
                    open: open,
                    selected: selected,
                    origin: origin,
                    checked: checked,
                    stagger: ctx.cg("stagger"),
                    tilt: ctx["tilt"],
                    interactive: isOpen,
                    language: ctx.language
                ) { index in
                    if isOpen { pick(index) } else { unroll() }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap the field, then choose a row", "点击选择框，再选一行"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.25, delay: 0.5) {
            if ctx.isPreview { previewTick() } else { intro() }
        }
        .onDisappear {
            closeTask?.cancel()
            introTask?.cancel()
        }
    }

    /// Label above and result line below the field; the open list covers them like a real menu.
    private var context: some View {
        VStack(spacing: 0) {
            Text(L("Delivery method", "配送方式"), ctx.language)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 272, alignment: .leading)
            Color.clear.frame(height: 48 + 16)
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(InputRollOption.all[selected].arrival, ctx.language)
                    .id(selected)
                    .transition(.blurReplace)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 272, alignment: .leading)
            .animation(.smooth(duration: 0.35), value: selected)
        }
        .opacity(1 - Double(min(max(open, 0), 1)) * 0.6)
    }

    // MARK: Actions

    private func unroll() {
        closeTask?.cancel()
        Haptics.tap(.light)
        origin = selected
        isOpen = true
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) { open = 1 }
    }

    /// Check the row, then roll the list back up into it.
    private func pick(_ index: Int) {
        guard isOpen else { return }
        Haptics.selection()
        checked = index
        closeTask?.cancel()
        closeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(index == selected ? 0.05 : 0.26))
            guard !Task.isCancelled else { return }
            close(picking: index)
        }
    }

    private func close(picking index: Int) {
        closeTask?.cancel()
        checked = index
        selected = index
        isOpen = false
        withAnimation(.spring(response: ctx["response"] * 0.9, dampingFraction: 0.86)) { open = 0 }
    }

    private func previewTick() {
        let phase = step % 2
        if phase == 0 {
            unroll()
        } else {
            pick(Self.targets[(step / 2) % Self.targets.count])
        }
        step += 1
    }

    /// Detail arrival: open, choose, close, so the page never rests with the menu hanging open.
    private func intro() {
        introTask?.cancel()
        introTask = Task { @MainActor in
            unroll()
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled, isOpen else { return }
            Haptics.isMuted = true
            pick(3)
            Haptics.isMuted = false
        }
    }
}

/// Field and list in one. Animatable over `open`, so each frame lays the rows out again.
private struct InputRollMenu: View, Animatable {
    var open: CGFloat
    let selected: Int
    let origin: Int
    let checked: Int
    let stagger: CGFloat
    let tilt: Double
    let interactive: Bool
    let language: AppLanguage
    let onTap: (Int) -> Void

    var animatableData: CGFloat {
        get { open }
        set { open = newValue }
    }

    private let rowHeight: CGFloat = 48
    private let width: CGFloat = 280
    private let reach: CGFloat = 144
    private var count: Int { InputRollOption.all.count }

    /// Progress of a row `distance` steps from the selection: the open value, delayed by distance.
    private func progress(_ distance: Int) -> CGFloat {
        guard distance > 0 else { return 1 }
        let furthest = CGFloat(max(selected, count - 1 - selected))
        let raw = open * (1 + stagger * furthest) - stagger * CGFloat(distance)
        return min(max(raw, 0), max(open, 1))
    }

    /// Extra offset that keeps the list anchored on `origin` and inside the stage while it is open.
    private var anchorShift: CGFloat {
        let top = -CGFloat(origin) * rowHeight - rowHeight / 2
        let bottom = CGFloat(count - 1 - origin) * rowHeight + rowHeight / 2
        var fit: CGFloat = 0
        if bottom > reach { fit = reach - bottom }
        if top < -reach { fit = -reach - top }
        return (CGFloat(selected - origin) * rowHeight + fit) * open
    }

    /// Height, in rows, unrolled so far by the first `distance` rows on one side of the selection.
    private func extent(_ distance: Int) -> CGFloat {
        guard distance > 0 else { return 0 }
        var sum: CGFloat = 0
        for step in 1...distance { sum += progress(step) }
        return sum
    }

    /// Centre of a row. Each row hangs from the far edge of the one before it, so its frame sits one
    /// full row beyond the rows already unrolled, and its hinge rotation does the unfolding.
    private func offset(_ index: Int) -> CGFloat {
        let distance = abs(index - selected)
        guard distance > 0 else { return anchorShift }
        let rows = 1 + extent(distance - 1)
        return (index < selected ? -rows : rows) * rowHeight + anchorShift
    }

    var body: some View {
        let clamped = min(max(open, 0), 1)
        let first = anchorShift - rowHeight / 2 - extent(selected) * rowHeight
        let last = anchorShift + rowHeight / 2 + extent(count - 1 - selected) * rowHeight
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return ZStack {
            shape
                .fill(Palette.elevated)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.1 + 0.14 * Double(clamped)), radius: 8 + 18 * clamped, y: 4 + 10 * clamped)
                .frame(width: width, height: max(last - first, rowHeight))
                .offset(y: (first + last) / 2)
            ForEach(0..<count, id: \.self) { index in
                row(index, clamped: clamped)
            }
        }
        .frame(width: width, height: rowHeight)
    }

    private func row(_ index: Int, clamped: CGFloat) -> some View {
        let option = InputRollOption.all[index]
        let isSelected = index == selected
        let amount = progress(abs(index - selected))
        let above = index < selected
        let angle: Double = isSelected ? 0 : Double(1 - min(amount, 1)) * tilt * (above ? 1 : -1)
        return HStack(spacing: 10) {
            Image(systemName: option.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(option.tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(option.title, language)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(option.price, language)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            ZStack {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .opacity(isSelected ? Double(1 - clamped) : 0)
                InputRollCheck()
                    .trim(from: 0, to: index == checked ? 1 : 0)
                    .stroke(Palette.indigo, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 14, height: 11)
                    .opacity(Double(clamped))
                    .animation(.easeOut(duration: 0.22), value: checked)
            }
            .frame(width: 18)
        }
        .padding(.horizontal, 12)
        .frame(width: width, height: rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Palette.indigo.opacity(index == checked ? 0.12 * Double(clamped) : 0))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .animation(.easeOut(duration: 0.2), value: checked)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(index) }
        .allowsHitTesting(isSelected || interactive)
        .opacity(isSelected ? 1 : Double(min(amount * 1.4, 1)))
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: above ? .bottom : .top, perspective: 0.6)
        .offset(y: offset(index))
        .zIndex(isSelected ? 2 : 1)
    }
}

private struct InputRollCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
