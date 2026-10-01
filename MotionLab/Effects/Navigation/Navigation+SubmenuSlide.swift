import SwiftUI

extension Effect {
    static let navigationSubmenuSlide = Effect(
        id: "navigation.submenu-slide",
        category: .navigation,
        interaction: .tap,
        name: L("Sliding Submenu", "滑入式子菜单"),
        summary: L(
            "A popup menu that drills in place: the submenu slides in from the right while the panel resizes to fit it, and the back row sends everything the other way.",
            "一个原地下钻的弹出菜单：子菜单从右侧滑入，面板同时缩放到刚好容纳它；点返回行，一切朝反方向走。"
        ),
        prompt: L(
            "A frosted popup menu anchored under a ⋯ button, with rows such as \"Sort by ›\" and \"Tint ›\". Tapping a row with a chevron keeps the panel where it is and swaps its content sideways: the root rows slide left by the panel's width and fade out, the submenu slides in from the right, its rows arriving 25 ms apart with an extra 10 pt of travel each, and the panel's width and height spring to the submenu's size (response 0.42 s, damping 0.82), pinned to its top-trailing corner. The submenu's first row is a back row with a leading chevron; tapping it plays the same motion mirrored. Choosing an option slides the checkmark to that row, applies it to the list behind (rows reorder, icons re-tint) and returns to the root after 0.35 s, where the row's value text blur-replaces. Selection haptic per step.",
            "磨砂弹出菜单锚定在 ⋯ 按钮下方，含「排序方式 ›」「标记颜色 ›」等行。点击带箭头的行，面板原地不动，内容横向替换：根菜单各行向左滑出一个面板宽度并淡出，子菜单从右侧滑入，各行相隔 25 毫秒到达、每行多走 10 pt，面板宽高以弹簧（响应 0.42 秒、阻尼 0.82）变到子菜单的尺寸，始终钉在右上角。子菜单首行是带左箭头的返回行，点击后镜像播放。选中某个选项时，对勾滑到该行，并立即作用于背后的列表（行重排、图标换色），0.35 秒后回到根菜单，对应行的取值以模糊替换更新。每一步都有选择触感。"
        ),
        implementation: L(
            "All levels stay mounted in one clipped ZStack; each is offset and faded by whether it is the current level, so direction needs no transition bookkeeping. The panel's frame is a function of the level and animates in the same withAnimation spring; rows add an index-delayed offset; the checkmark is a matchedGeometryEffect.",
            "所有层级都常驻在一个被裁剪的 ZStack 里，各自根据是否为当前层级决定偏移与透明度，因此方向无需额外的转场管理。面板的尺寸是层级的函数，随同一个 withAnimation 弹簧变化；各行叠加按序号延迟的偏移；对勾是 matchedGeometryEffect。"
        ),
        apis: ["matchedGeometryEffect", "animation(_:value:)", "clipShape", "Material", "transition(.blurReplace)", "spring(response:dampingFraction:)"],
        tags: ["submenu", "nested menu", "drill-down", "popup", "子菜单", "多级菜单", "下钻", "弹出菜单"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.8, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .slider("stagger", L("Row stagger", "行错峰"), 0...0.06, default: 0.025, decimals: 3, unit: "s"),
        ]
    ) { ctx in
        SubmenuSlideDemo(ctx: ctx)
    }
}

private enum SubmenuLevel: Int {
    case root
    case sort
    case tint

    var size: CGSize {
        switch self {
        case .root: return CGSize(width: 208, height: SubmenuMetrics.row * 4 + 12)
        case .sort: return CGSize(width: 180, height: SubmenuMetrics.row * 5 + 12)
        case .tint: return CGSize(width: 220, height: SubmenuMetrics.row * 2 + 18)
        }
    }
}

private enum SubmenuMetrics {
    static let row: CGFloat = 40
}

private struct SubmenuFile: Identifiable {
    let id: Int
    let symbol: String
    let name: LocalizedText
    let detail: LocalizedText
}

private let submenuFiles: [SubmenuFile] = [
    SubmenuFile(id: 0, symbol: "doc.richtext.fill", name: L("Brand deck", "品牌方案"), detail: L("12 MB · May 3", "12 MB · 5月3日")),
    SubmenuFile(id: 1, symbol: "doc.text.fill", name: L("Invoice", "发票"), detail: L("240 KB · Jun 18", "240 KB · 6月18日")),
    SubmenuFile(id: 2, symbol: "photo.fill", name: L("Moodboard", "情绪板"), detail: L("48 MB · Apr 9", "48 MB · 4月9日")),
    SubmenuFile(id: 3, symbol: "note.text", name: L("Notes", "笔记"), detail: L("6 KB · Jun 2", "6 KB · 6月2日")),
]

private let submenuSortNames: [LocalizedText] = [L("Name", "名称"), L("Date", "日期"), L("Size", "大小"), L("Kind", "类型")]
/// File ids in display order for each sort option.
private let submenuSortOrders: [[Int]] = [[0, 1, 2, 3], [1, 3, 0, 2], [2, 0, 1, 3], [3, 2, 1, 0]]
private let submenuTints: [Color] = [Palette.indigo, Palette.coral, Palette.amber, Palette.mint, Palette.pink]

private struct SubmenuSlideDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var open: Bool
    @State private var level: SubmenuLevel
    @State private var sort = 0
    /// The sort name shown on the root row; it catches up once the root is back on screen.
    @State private var shownSort = 0
    @State private var tint = 0
    @State private var returnTask: Task<Void, Never>?
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _open = State(initialValue: ctx.isStill)
        _level = State(initialValue: ctx.isStill ? .sort : .root)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                fileList
                menu
                    .padding(.top, 58)
                    .padding(.trailing, 14)
            }
            .frame(width: 300, height: 284)
            .background(Palette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
            DemoHint(text: L("Open the menu and drill into a row", "打开菜单，点进带箭头的行"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.15) { autoplayStep() }
        .onDisappear { returnTask?.cancel() }
    }

    // MARK: Content behind the menu

    private var fileList: some View {
        let order: [Int] = submenuSortOrders[sort]
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("Files", "文件"), ctx.language)
                    .font(.title3.weight(.bold))
                Spacer(minLength: 0)
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(open ? Color.white : Color.primary)
                    .frame(width: 36, height: 36)
                    .background(open ? AnyShapeStyle(submenuTints[tint]) : AnyShapeStyle(Color.primary.opacity(0.08)), in: Circle())
                    .contentShape(Circle())
                    .onTapGesture { toggleMenu() }
            }
            .padding(.bottom, 4)
            ForEach(order, id: \.self) { id in
                let file: SubmenuFile = submenuFiles[id]
                HStack(spacing: 12) {
                    Image(systemName: file.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 34, height: 34)
                        .background(submenuTints[tint].gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name, ctx.language)
                            .font(.subheadline.weight(.semibold))
                        Text(file.detail, ctx.language)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 44)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if open { toggleMenu() }
        }
    }

    // MARK: Menu

    private var menu: some View {
        let size: CGSize = level.size
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack(alignment: .topLeading) {
            page(.root) { rootRows }
            page(.sort) { sortRows }
            page(.tint) { tintRows }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(shape)
        .demoGlass(shape, material: .regularMaterial)
        .overlay(shape.strokeBorder(Palette.stroke))
        .shadow(color: Color.black.opacity(0.22), radius: 20, y: 10)
        .scaleEffect(open ? 1 : 0.3, anchor: .topTrailing)
        .opacity(open ? 1 : 0)
        .blur(radius: open ? 0 : 6)
        .allowsHitTesting(open)
    }

    /// Every level stays mounted; the current one sits at 0, the root waits on the left, submenus on the right.
    private func page<Content: View>(_ target: SubmenuLevel, @ViewBuilder content: () -> Content) -> some View {
        let current: Bool = level == target
        let side: CGFloat = target == .root ? -1 : 1
        return VStack(spacing: 0) {
            content()
        }
        .padding(.vertical, 6)
        .frame(width: target.size.width, alignment: .top)
        .offset(x: current ? 0 : side * level.size.width)
        .opacity(current ? 1 : 0)
        .allowsHitTesting(current)
    }

    /// A row's own trailing motion: later rows start a little later and from a little further away.
    private func staggered<Content: View>(_ index: Int, in target: SubmenuLevel, _ content: Content) -> some View {
        let current: Bool = level == target
        let side: CGFloat = target == .root ? -1 : 1
        return content
            .offset(x: current ? 0 : side * 10 * CGFloat(index))
            .animation(spring.delay(current ? Double(index) * ctx["stagger"] : 0), value: level)
    }

    private var rootRows: some View {
        Group {
            staggered(0, in: .root, drillRow(symbol: "arrow.up.arrow.down", title: L("Sort by", "排序方式"), target: .sort) {
                Text(submenuSortNames[shownSort], ctx.language)
                    .id(shownSort)
                    .transition(.blurReplace)
            })
            staggered(1, in: .root, drillRow(symbol: "paintpalette", title: L("Tint", "标记颜色"), target: .tint) {
                Circle()
                    .fill(submenuTints[tint])
                    .frame(width: 12, height: 12)
            })
            staggered(2, in: .root, plainRow(symbol: "checkmark.circle", title: L("Select", "选择")))
            staggered(3, in: .root, plainRow(symbol: "folder.badge.plus", title: L("New folder", "新建文件夹")))
        }
    }

    private var sortRows: some View {
        Group {
            staggered(0, in: .sort, backRow(L("Sort by", "排序方式")))
            ForEach(0..<submenuSortNames.count, id: \.self) { index in
                staggered(index + 1, in: .sort, optionRow(index))
            }
        }
    }

    private var tintRows: some View {
        Group {
            staggered(0, in: .tint, backRow(L("Tint", "标记颜色")))
            staggered(1, in: .tint, swatchRow)
        }
    }

    private func drillRow<Value: View>(symbol: String, title: LocalizedText, target: SubmenuLevel, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 20)
            Text(title, ctx.language)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 4)
            value()
                .font(.footnote)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .frame(height: SubmenuMetrics.row)
        .contentShape(Rectangle())
        .onTapGesture { go(to: target) }
    }

    private func plainRow(symbol: String, title: LocalizedText) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 20)
            Text(title, ctx.language)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: SubmenuMetrics.row)
        .contentShape(Rectangle())
        .onTapGesture { toggleMenu() }
    }

    private func backRow(_ title: LocalizedText) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 20)
            Text(title, ctx.language)
                .font(.subheadline.weight(.bold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(submenuTints[tint])
        .padding(.horizontal, 14)
        .frame(height: SubmenuMetrics.row)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { go(to: .root) }
    }

    private func optionRow(_ index: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if sort == index {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(submenuTints[tint])
                        .matchedGeometryEffect(id: "check", in: ns)
                }
            }
            .frame(width: 20)
            Text(submenuSortNames[index], ctx.language)
                .font(.subheadline.weight(sort == index ? .semibold : .medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: SubmenuMetrics.row)
        .contentShape(Rectangle())
        .onTapGesture { chooseSort(index) }
    }

    private var swatchRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<submenuTints.count, id: \.self) { index in
                Circle()
                    .fill(submenuTints[index].gradient)
                    .frame(width: 24, height: 24)
                    .frame(maxWidth: .infinity)
                    .frame(height: SubmenuMetrics.row + 6)
                    .background {
                        if tint == index {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.7), lineWidth: 2)
                                .frame(width: 33, height: 33)
                                .matchedGeometryEffect(id: "ring", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { chooseTint(index) }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: Actions

    private func toggleMenu() {
        returnTask?.cancel()
        if !ctx.isPreview { Haptics.tap(.light) }
        let opening: Bool = !open
        if opening {
            // Always opens on the root level.
            level = .root
        }
        withAnimation(.spring(response: 0.36, dampingFraction: opening ? 0.74 : 0.9)) { open = opening }
    }

    private func go(to target: SubmenuLevel) {
        guard target != level else { return }
        returnTask?.cancel()
        if !ctx.isPreview { Haptics.selection() }
        if target == .root { shownSort = sort }
        withAnimation(spring) { level = target }
    }

    private func chooseSort(_ index: Int) {
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { sort = index }
        returnSoon()
    }

    private func chooseTint(_ index: Int) {
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { tint = index }
        returnSoon()
    }

    private func returnSoon() {
        returnTask?.cancel()
        let animation: Animation = spring
        returnTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { level = .root }
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.3)) { shownSort = sort }
        }
    }

    private func autoplayStep() {
        let phase: Int = autoStep % 6
        autoStep += 1
        switch phase {
        case 0:
            if !open { toggleMenu() }
        case 1: go(to: .sort)
        case 2: chooseSort((sort + 1) % submenuSortNames.count)
        case 3: go(to: .tint)
        case 4: chooseTint((tint + 1) % submenuTints.count)
        default:
            if open { toggleMenu() }
        }
    }
}
