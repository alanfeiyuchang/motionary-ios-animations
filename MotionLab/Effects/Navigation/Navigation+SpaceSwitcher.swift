import SwiftUI

extension Effect {
    static let navigationSpaceSwitcher = Effect(
        id: "navigation.space-switcher",
        category: .navigation,
        interaction: .gesture,
        name: L("Sidebar Space Switcher", "侧栏空间切换"),
        summary: L(
            "Swipe the sidebar sideways to change space: rows fan out in a slanted wave, and the whole window blends to the next space's colour under your finger.",
            "横向滑动侧栏切换空间：各行斜着扇形散开，整个窗口的色调随手指渐变到下一个空间的颜色。"
        ),
        prompt: L(
            "A browser window with a floating 176 pt sidebar: a URL pill, a space title, four tab rows and three space icons at the bottom. Swiping the sidebar horizontally pages between spaces 1:1 with the finger, rubber-banding at both ends. The rows do not move as a block: each row is offset by an extra 10 pt per row index times the swipe fraction, so the list shears into a slanted wave, the title leading and the lowest row trailing, and straightens as it lands. Everything tinted (sidebar wash, window backdrop, page header, the highlight behind the active space icon) is a continuous colour mix between the two spaces, driven by the same fraction, and the highlight slides 34 pt per space. Release springs to the nearest space (response 0.5 s, damping 0.8) with a light haptic; tapping a space icon plays the same motion.",
            "浏览器窗口里有一块悬浮的 176 pt 侧栏：地址胶囊、空间标题、四行标签页，底部是三个空间图标。横向滑动侧栏，空间 1:1 跟手翻页，两端带橡皮筋。各行并不整块移动：每行按行号乘以滑动进度额外偏移 10 pt，列表被剪切成一道斜浪，标题领先、末行落后，落定时才对齐。所有带色调的部分（侧栏底色、窗口背景、页面顶栏、图标高亮）都由同一个进度在两个空间的颜色之间连续混合，高亮每个空间滑动 34 pt。松手后以弹簧（响应 0.5 秒、阻尼 0.8）吸附到最近的空间，伴随轻触感；点击空间图标效果相同。"
        ),
        implementation: L(
            "One fractional space index is the whole state. An Animatable scene view interpolates it and derives every row offset, opacity and Color.mix tint from it in body, so the drag and the settling spring render through the same code.",
            "全部状态只有一个小数空间索引。一个 Animatable 场景视图对它插值，并在 body 中由它推导出每一行的偏移、透明度与 Color.mix 混色，拖拽与落定弹簧走的是同一段渲染代码。"
        ),
        apis: ["Animatable", "Color.mix(with:by:)", "DragGesture", "predictedEndTranslation", "spring(response:dampingFraction:)"],
        tags: ["sidebar", "spaces", "workspace", "swipe", "侧栏", "空间", "工作区", "色调渐变"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("fan", L("Row shear", "行间错位"), 0...24, default: 10, decimals: 0, unit: "pt"),
            .slider("tint", L("Tint strength", "色调强度"), 0...1, default: 0.6),
        ]
    ) { ctx in
        SpaceSwitcherDemo(ctx: ctx)
    }
}

private struct SpaceTabItem {
    let symbol: String
    let title: LocalizedText
}

private struct BrowserSpace {
    let symbol: String
    let name: LocalizedText
    let color: Color
    let tabs: [SpaceTabItem]
}

private let browserSpaces: [BrowserSpace] = [
    BrowserSpace(symbol: "briefcase.fill", name: L("Work", "工作"), color: Palette.indigo, tabs: [
        SpaceTabItem(symbol: "list.bullet.rectangle.fill", title: L("Sprint board", "迭代看板")),
        SpaceTabItem(symbol: "pencil.and.ruler.fill", title: L("Design file", "设计稿")),
        SpaceTabItem(symbol: "chevron.left.forwardslash.chevron.right", title: L("Pull requests", "合并请求")),
        SpaceTabItem(symbol: "doc.text.fill", title: L("Launch notes", "发布说明")),
    ]),
    BrowserSpace(symbol: "heart.fill", name: L("Personal", "个人"), color: Palette.pink, tabs: [
        SpaceTabItem(symbol: "envelope.fill", title: L("Mail", "邮件")),
        SpaceTabItem(symbol: "photo.fill", title: L("Photos", "照片")),
        SpaceTabItem(symbol: "fork.knife", title: L("Recipes", "食谱")),
        SpaceTabItem(symbol: "music.note", title: L("Playlist", "歌单")),
    ]),
    BrowserSpace(symbol: "airplane", name: L("Travel", "旅行"), color: Palette.mint, tabs: [
        SpaceTabItem(symbol: "ticket.fill", title: L("Flights", "机票")),
        SpaceTabItem(symbol: "map.fill", title: L("Route map", "路线地图")),
        SpaceTabItem(symbol: "bed.double.fill", title: L("Hotels", "酒店")),
        SpaceTabItem(symbol: "list.clipboard.fill", title: L("Itinerary", "行程单")),
    ]),
]

private enum SpaceMetrics {
    static let frame = CGSize(width: 260, height: 290)
    static let sidebarWidth: CGFloat = 176
    static let iconStep: CGFloat = 34
}

private struct SpaceSwitcherDemo: View {
    let ctx: DemoContext
    @State private var progress: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var autoForward = true

    private var lastIndex: CGFloat { CGFloat(browserSpaces.count - 1) }

    var body: some View {
        VStack(spacing: 14) {
            SpaceScene(progress: progress, fan: ctx.cg("fan"), tint: ctx["tint"], language: ctx.language)
                .frame(width: SpaceMetrics.frame.width, height: SpaceMetrics.frame.height)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
                .overlay(alignment: .bottomLeading) { iconTargets }
                .contentShape(Rectangle())
                .pageSafeHorizontalDrag(onChanged: dragChanged, onEnded: dragEnded)
            DemoHint(text: L("Swipe the sidebar, or tap a space icon", "横向滑动侧栏，或点击空间图标"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoplayStep() }
    }

    /// Invisible tap targets over the three space icons drawn by the scene.
    private var iconTargets: some View {
        HStack(spacing: 0) {
            ForEach(0..<browserSpaces.count, id: \.self) { index in
                Color.clear
                    .frame(width: SpaceMetrics.iconStep, height: 40)
                    .contentShape(Rectangle())
                    .onTapGesture { tapped(index) }
            }
        }
        .padding(.leading, 18)
        .padding(.bottom, 14)
    }

    private func tapped(_ index: Int) {
        guard index != Int(progress.rounded()) else { return }
        settle(to: index)
    }

    private func dragChanged(_ value: DragGesture.Value) {
        let start: CGFloat = dragStart ?? progress
        if dragStart == nil { dragStart = progress }
        var page: CGFloat = start - value.translation.width / SpaceMetrics.sidebarWidth
        if page < 0 { page = -rubberBand(-page, limit: 0.5) }
        if page > lastIndex { page = lastIndex + rubberBand(page - lastIndex, limit: 0.5) }
        progress = page
    }

    /// Release projects the flick one space at most; a system cancellation (`nil`) settles from where it is.
    private func dragEnded(_ value: DragGesture.Value?) {
        guard let start = dragStart else { return }
        dragStart = nil
        let projected: CGFloat = value.map { start - $0.predictedEndTranslation.width / SpaceMetrics.sidebarWidth } ?? progress
        let limited: CGFloat = min(max(projected, start.rounded() - 1), start.rounded() + 1)
        settle(to: Int(limited.rounded()))
    }

    private func settle(to index: Int) {
        let clamped: Int = min(max(index, 0), browserSpaces.count - 1)
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            progress = CGFloat(clamped)
        }
    }

    private func autoplayStep() {
        let current: Int = Int(progress.rounded())
        var next: Int = current + (autoForward ? 1 : -1)
        if next >= browserSpaces.count {
            autoForward = false
            next = current - 1
        } else if next < 0 {
            autoForward = true
            next = current + 1
        }
        settle(to: next)
    }
}

// MARK: - Scene

/// Draws the whole window for a fractional space index; SwiftUI interpolates `progress` during the settle.
private struct SpaceScene: View, Animatable {
    var progress: CGFloat
    let fan: CGFloat
    let tint: Double
    let language: AppLanguage

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// The two neighbouring spaces' colours mixed by the fractional part.
    private var color: Color {
        let last: CGFloat = CGFloat(browserSpaces.count - 1)
        let clamped: CGFloat = min(max(progress, 0), last)
        let lower: Int = Int(clamped.rounded(.down))
        let upper: Int = min(lower + 1, browserSpaces.count - 1)
        return browserSpaces[lower].color.mix(with: browserSpaces[upper].color, by: Double(clamped - CGFloat(lower)))
    }

    var body: some View {
        let wash: Color = color
        ZStack(alignment: .topLeading) {
            Palette.elevated
            LinearGradient(
                colors: [wash.opacity(0.15 + 0.5 * tint), wash.opacity(0.05 + 0.2 * tint)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            page(wash)
                .offset(x: SpaceMetrics.sidebarWidth + 16, y: 8)
            sidebar(wash)
                .offset(x: 8, y: 8)
        }
        .frame(width: SpaceMetrics.frame.width, height: SpaceMetrics.frame.height, alignment: .topLeading)
    }

    // MARK: Sidebar

    private func sidebar(_ wash: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(verbatim: "motionary.app")
                    .font(.caption2.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            lists
            Spacer(minLength: 0)
            spaceIcons(wash)
        }
        .padding(10)
        .frame(width: SpaceMetrics.sidebarWidth, height: SpaceMetrics.frame.height - 16, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Palette.elevated)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(wash.opacity(0.04 + 0.12 * tint)))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.14), radius: 14, x: 4, y: 6)
        }
    }

    private var lists: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<browserSpaces.count, id: \.self) { index in
                let distance: CGFloat = CGFloat(index) - progress
                if abs(distance) < 1.6 {
                    spaceColumn(browserSpaces[index], distance: distance)
                }
            }
        }
        .frame(width: SpaceMetrics.sidebarWidth - 20, height: 178, alignment: .topLeading)
        .clipped()
    }

    /// One space's title and rows. `distance` is how many spaces away it is: the column slides by it, and each
    /// row shears a little further the lower it sits.
    private func spaceColumn(_ space: BrowserSpace, distance: CGFloat) -> some View {
        let width: CGFloat = SpaceMetrics.sidebarWidth - 20
        let fade: Double = Double(1 - min(abs(distance), 1) * 0.7)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Image(systemName: space.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(space.color)
                Text(space.name, language)
                    .font(.subheadline.weight(.bold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 30)
            ForEach(0..<space.tabs.count, id: \.self) { row in
                HStack(spacing: 9) {
                    Image(systemName: space.tabs[row].symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 22, height: 22)
                        .background(
                            Palette.spectrum[(row * 2 + 1) % Palette.spectrum.count].gradient,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                    Text(space.tabs[row].title, language)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                .frame(height: 32)
                .background {
                    if row == 0 {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(space.color.opacity(0.16))
                    }
                }
                .offset(x: distance * CGFloat(row + 1) * fan)
            }
        }
        .frame(width: width, alignment: .topLeading)
        .opacity(fade)
        .offset(x: distance * (width + 14))
    }

    private func spaceIcons(_ wash: Color) -> some View {
        let last: CGFloat = CGFloat(browserSpaces.count - 1)
        let clamped: CGFloat = min(max(progress, 0), last)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash.opacity(0.22))
                .frame(width: 30, height: 30)
                .offset(x: 2 + clamped * SpaceMetrics.iconStep)
            HStack(spacing: 0) {
                ForEach(0..<browserSpaces.count, id: \.self) { index in
                    let near: CGFloat = max(0, 1 - abs(CGFloat(index) - clamped))
                    Image(systemName: browserSpaces[index].symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.secondary.mix(with: browserSpaces[index].color, by: Double(near)))
                        .scaleEffect(1 + 0.12 * near)
                        .frame(width: SpaceMetrics.iconStep, height: 30)
                }
            }
        }
        .frame(height: 30)
    }

    // MARK: Page

    private func page(_ wash: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash.gradient)
                .frame(height: 64)
            PlaceholderLines(count: 3, color: Color.primary.opacity(0.1))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash.opacity(0.2))
                .frame(height: 70)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 150, height: SpaceMetrics.frame.height - 16, alignment: .topLeading)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
    }
}
