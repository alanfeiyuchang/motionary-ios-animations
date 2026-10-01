import SwiftUI

extension Effect {
    static let navigationTitleHandoff = Effect(
        id: "navigation.title-handoff",
        category: .navigation,
        interaction: .tap,
        name: L("Title Hand-off Push", "标题交接式推入"),
        summary: L(
            "On push the large title shrinks into the back button while the tapped row's label grows into the new large title; a swipe back scrubs both the other way.",
            "推入时，大标题缩进返回按钮，被点那一行的文字长成新的大标题；侧滑返回时，两者都跟着手指倒回去。"
        ),
        prompt: L(
            "A list screen with a 30 pt bold large title. Tapping a row pushes its detail page, and two pieces of text travel instead of cross-fading. The old large title scales to 57% (17 pt), turns from primary to the accent blue and moves up to sit beside a chevron that fades in: it becomes the back button. At the same time the tapped row's own label lifts off its row, grows from 17 to 30 pt and lands in the large-title position of the new page. Beneath them the list slides left at 30% of the page's speed and dims, the detail page slides in from the right with an edge shadow, and its tiles trail in 18 pt apart. One spring drives everything (response 0.5 s, damping 0.86). Swiping right scrubs the whole hand-off 1:1 and releases to whichever side is nearer.",
            "带 30 pt 粗体大标题的列表页。点击某一行推入详情页，其间有两段文字是飞过去而不是交叉淡化。旧的大标题缩到 57%（17 pt），由正文色变为强调蓝，上移停到一枚渐显的箭头旁：它变成了返回按钮。同时，被点那一行自己的文字离开行内，从 17 pt 长到 30 pt，落到新页面的大标题位置。下方，列表以页面速度的 30% 向左滑动并变暗，详情页带着边缘投影从右侧滑入，色块相隔 18 pt 依次跟进。全程由同一根弹簧驱动（响应 0.5 秒、阻尼 0.86）。向右滑动可 1:1 拖动整个交接，松手后归到较近的一侧。"
        ),
        implementation: L(
            "An Animatable scene takes one push progress. Both travelling texts are drawn once at 30 pt in an overlay above the two pages and interpolate position, top-leading-anchored scale and colour from it; the pages only translate. Tap and the interactive back drag write the same progress.",
            "一个 Animatable 场景视图接收单一的推入进度。两段飞行的文字都以 30 pt 在两个页面之上的覆盖层里只绘制一次，由进度插值位置、以左上角为锚点的缩放与颜色；页面本身只做平移。点击与可交互的返回拖拽写入的是同一个进度。"
        ),
        apis: ["Animatable", "scaleEffect(_:anchor:)", "Color.mix(with:by:)", "DragGesture", "spring(response:dampingFraction:)"],
        tags: ["navigation bar", "large title", "back button", "push", "导航栏", "大标题", "返回按钮", "推入"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.86),
            .slider("parallax", L("List parallax", "列表视差"), 0...0.6, default: 0.3),
        ]
    ) { ctx in
        TitleHandoffDemo(ctx: ctx)
    }
}

private struct HandoffRow {
    let symbol: String
    let title: LocalizedText
    let colors: [Color]
}

private let handoffRows: [HandoffRow] = [
    HandoffRow(symbol: "music.note.list", title: L("Playlists", "播放列表"), colors: [Palette.pink, Palette.coral]),
    HandoffRow(symbol: "music.mic", title: L("Artists", "艺人"), colors: [Palette.indigo, Palette.violet]),
    HandoffRow(symbol: "square.stack.fill", title: L("Albums", "专辑"), colors: [Palette.mint, Palette.sky]),
    HandoffRow(symbol: "arrow.down.circle.fill", title: L("Downloads", "已下载"), colors: [Palette.amber, Palette.coral]),
]

private enum HandoffMetrics {
    static let frame = CGSize(width: 290, height: 284)
    static let largeSize: CGFloat = 30
    static let smallScale: CGFloat = 17.0 / 30.0
    /// Line height of the 30 pt title, used to centre its scaled copy on a row or in the bar.
    static let lineHeight: CGFloat = 36
    static let largeOrigin = CGPoint(x: 18, y: 46)
    static let backOrigin = CGPoint(x: 32, y: 27 - lineHeight * smallScale / 2)
    static let rowTop: CGFloat = 96
    static let rowPitch: CGFloat = 45
    static let rowHeight: CGFloat = 43
    static let rowLabelX: CGFloat = 58
    static let rootTitle = L("Library", "资料库")

    static func rowLabelOrigin(_ index: Int) -> CGPoint {
        let centre: CGFloat = rowTop + CGFloat(index) * rowPitch + rowHeight / 2
        return CGPoint(x: rowLabelX, y: centre - lineHeight * smallScale / 2)
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}

private struct TitleHandoffDemo: View {
    let ctx: DemoContext
    @State private var progress: CGFloat
    @State private var source: Int
    @State private var dragging = false
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 1 : 0)
        _source = State(initialValue: 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            HandoffScene(progress: progress, source: source, parallax: ctx.cg("parallax"), language: ctx.language)
                .frame(width: HandoffMetrics.frame.width, height: HandoffMetrics.frame.height)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
                .overlay(alignment: .topLeading) { targets }
                .contentShape(Rectangle())
                .pageSafeHorizontalDrag(onChanged: dragChanged, onEnded: dragEnded)
            DemoHint(text: L("Tap a row, then swipe right to go back", "点击一行，再向右滑动返回"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoplayStep() }
    }

    /// Row targets on the list, the back button on the detail page.
    @ViewBuilder
    private var targets: some View {
        if progress < 0.5 {
            VStack(spacing: HandoffMetrics.rowPitch - HandoffMetrics.rowHeight) {
                ForEach(0..<handoffRows.count, id: \.self) { index in
                    Color.clear
                        .frame(width: HandoffMetrics.frame.width, height: HandoffMetrics.rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { push(index) }
                }
            }
            .padding(.top, HandoffMetrics.rowTop)
        } else {
            Color.clear
                .frame(width: 130, height: 48)
                .contentShape(Rectangle())
                .onTapGesture { pop() }
        }
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    private func push(_ index: Int) {
        guard progress < 0.01 else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        source = index
        withAnimation(spring) { progress = 1 }
    }

    private func pop() {
        guard progress > 0.5 else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(spring) { progress = 0 }
    }

    private func dragChanged(_ value: DragGesture.Value) {
        if !dragging {
            guard progress > 0.99, value.translation.width > 0 else { return }
            dragging = true
        }
        progress = min(max(1 - value.translation.width / HandoffMetrics.frame.width, 0), 1)
    }

    private func dragEnded(_ value: DragGesture.Value?) {
        guard dragging else { return }
        dragging = false
        let projected: CGFloat = value.map { 1 - $0.predictedEndTranslation.width / HandoffMetrics.frame.width } ?? progress
        let stay: Bool = projected > 0.5
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(spring) { progress = stay ? 1 : 0 }
    }

    private func autoplayStep() {
        if progress > 0.5 {
            pop()
        } else {
            push(autoStep % handoffRows.count)
            autoStep += 1
        }
    }
}

// MARK: - Scene

private struct HandoffScene: View, Animatable {
    var progress: CGFloat
    let source: Int
    let parallax: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p: CGFloat = min(max(progress, 0), 1)
        ZStack(alignment: .topLeading) {
            listPage(p)
            detailPage(p)
            travellers(p)
        }
        .frame(width: HandoffMetrics.frame.width, height: HandoffMetrics.frame.height, alignment: .topLeading)
        .background(Palette.elevated)
    }

    // MARK: Pages

    private func listPage(_ p: CGFloat) -> some View {
        VStack(spacing: HandoffMetrics.rowPitch - HandoffMetrics.rowHeight) {
            ForEach(0..<handoffRows.count, id: \.self) { index in
                let row: HandoffRow = handoffRows[index]
                HStack(spacing: 12) {
                    Image(systemName: row.symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 28, height: 28)
                        .background(
                            LinearGradient(colors: row.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    // The tapped row's label is drawn by the travelling copy while the push is under way.
                    Text(row.title, language)
                        .font(.system(size: 17, weight: .semibold))
                        .opacity(index == source && p > 0.001 ? 0 : 1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .padding(.horizontal, 18)
                .frame(height: HandoffMetrics.rowHeight)
                .background(Color.primary.opacity(index == source ? 0.06 * Double(min(p * 4, 1)) : 0))
            }
        }
        .padding(.top, HandoffMetrics.rowTop)
        .frame(width: HandoffMetrics.frame.width, height: HandoffMetrics.frame.height, alignment: .top)
        .background(Palette.elevated)
        .overlay(Color.black.opacity(0.12 * Double(p)))
        .offset(x: -p * parallax * HandoffMetrics.frame.width)
    }

    private func detailPage(_ p: CGFloat) -> some View {
        let row: HandoffRow = handoffRows[source]
        let columns: [GridItem] = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: row.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .opacity(1 - Double(index) * 0.17)
                    .frame(height: 78)
                    .overlay(alignment: .bottomLeading) {
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 46, height: 7)
                            .padding(10)
                    }
                    // Tiles trail in one after another.
                    .offset(x: (1 - p) * 18 * CGFloat(index + 1))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, HandoffMetrics.rowTop)
        .frame(width: HandoffMetrics.frame.width, height: HandoffMetrics.frame.height, alignment: .top)
        .background(Palette.elevated)
        .shadow(color: Color.black.opacity(0.22 * Double(min(p * 4, 1) * min((1 - p) * 4, 1))), radius: 14, x: -6)
        .offset(x: (1 - p) * HandoffMetrics.frame.width)
    }

    // MARK: Travelling text

    private func travellers(_ p: CGFloat) -> some View {
        let small: CGFloat = HandoffMetrics.smallScale
        let rowOrigin: CGPoint = HandoffMetrics.rowLabelOrigin(source)
        let large: CGPoint = HandoffMetrics.largeOrigin
        let back: CGPoint = HandoffMetrics.backOrigin
        return ZStack(alignment: .topLeading) {
            // Old large title → back button label.
            Text(HandoffMetrics.rootTitle, language)
                .font(.system(size: HandoffMetrics.largeSize, weight: .bold))
                .foregroundStyle(Color.primary.mix(with: Palette.blue, by: Double(p)))
                .fixedSize()
                .scaleEffect(HandoffMetrics.lerp(1, small, p), anchor: .topLeading)
                .offset(x: HandoffMetrics.lerp(large.x, back.x, p), y: HandoffMetrics.lerp(large.y, back.y, p))
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.blue)
                .opacity(Double(max(p * 2 - 1, 0)))
                .offset(x: 14 + (1 - p) * 10, y: 16.5)
            // Row label → new large title.
            Text(handoffRows[source].title, language)
                .font(.system(size: HandoffMetrics.largeSize, weight: .bold))
                .foregroundStyle(Color.primary)
                .fixedSize()
                .scaleEffect(HandoffMetrics.lerp(small, 1, p), anchor: .topLeading)
                .offset(x: HandoffMetrics.lerp(rowOrigin.x, large.x, p), y: HandoffMetrics.lerp(rowOrigin.y, large.y, p))
                .opacity(p > 0.001 ? 1 : 0)
        }
        .allowsHitTesting(false)
    }
}
