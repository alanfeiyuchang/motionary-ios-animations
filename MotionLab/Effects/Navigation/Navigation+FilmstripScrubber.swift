import SwiftUI

extension Effect {
    static let navigationFilmstripScrubber = Effect(
        id: "navigation.filmstrip-scrubber",
        category: .navigation,
        interaction: .gesture,
        name: L("Filmstrip Page Scrubber", "胶片条页码拖动器"),
        summary: L(
            "The page indicator is a strip of tiny thumbnails: the current one stands wide with air around it, and dragging the strip flings through every page with inertia.",
            "页码指示器是一条迷你缩略图：当前那张变宽、两侧留出空隙，拖动胶片条就能带着惯性翻过所有页面。"
        ),
        prompt: L(
            "A photo pager with a filmstrip beneath it instead of dots: ten 16 × 34 pt thumbnails, 2 pt apart, whose edges fade out. The thumbnail of the current page is 44 pt wide with an extra 6 pt of air on each side and sits exactly under the centre; the strip is positioned from one fractional page index, so as pages change each thumbnail widens while it approaches the centre and narrows as it leaves, the neighbours parting to make room. Dragging the strip scrubs the pager directly, one page per 18 pt of travel, with a selection tick at every page crossed; on release the flick's predicted end picks the landing page and everything settles on a spring (response 0.42 s, damping 0.82). Swiping the photo or tapping a thumbnail runs the same motion. Dense, quick, tactile.",
            "照片翻页器下方不是圆点，而是一条胶片：十张 16 × 34 pt 的缩略图，间距 2 pt，两端渐隐。当前页的缩略图宽 44 pt，两侧各多留 6 pt 空隙，正好停在中心下方；整条胶片由同一个小数页码定位，所以翻页时每张缩略图在接近中心时变宽、离开时变窄，邻居随之让位。拖动胶片条可直接拖动翻页，每移动 18 pt 翻一页，每越过一页有一次选择触感；松手后由甩动的预测终点决定落在哪一页，一切以弹簧（响应 0.42 秒、阻尼 0.82）落定。滑动照片或点击某张缩略图，播放的是同一套动作。紧凑、迅速、有手感。"
        ),
        implementation: L(
            "An Animatable scene lays the strip out from the fractional page: each thumbnail's width and margin come from its nearness to that page, x is the running sum, and the whole strip is shifted so the interpolated current centre stays in the middle. Drags write the page directly; release animates it with a spring.",
            "一个 Animatable 场景视图根据小数页码排布胶片：每张缩略图的宽度与边距取决于它离该页码的远近，横坐标是累加值，整条胶片再平移，使插值出的当前中心始终位于正中。拖拽直接写入页码，松手后用弹簧动画落定。"
        ),
        apis: ["Animatable", "DragGesture", "predictedEndTranslation", "SpatialTapGesture", "mask(_:)", "spring(response:dampingFraction:)"],
        tags: ["filmstrip", "thumbnails", "scrubber", "page indicator", "胶片条", "缩略图", "拖动翻页", "页码指示器"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.9, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .slider("width", L("Current width", "当前页宽度"), 20...64, default: 44, decimals: 0, unit: "pt"),
            .slider("gap", L("Side gap", "两侧空隙"), 0...14, default: 6, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        FilmstripScrubberDemo(ctx: ctx)
    }
}

private struct FilmPhoto {
    let symbol: String
    let colors: [Color]
}

private let filmPhotos: [FilmPhoto] = [
    FilmPhoto(symbol: "mountain.2.fill", colors: [Palette.sky, Palette.indigo]),
    FilmPhoto(symbol: "sun.horizon.fill", colors: [Palette.amber, Palette.coral]),
    FilmPhoto(symbol: "leaf.fill", colors: [Palette.mint, Palette.green]),
    FilmPhoto(symbol: "sailboat.fill", colors: [Palette.sky, Palette.mint]),
    FilmPhoto(symbol: "camera.macro", colors: [Palette.pink, Palette.violet]),
    FilmPhoto(symbol: "moon.stars.fill", colors: [Palette.indigo, Color(hex: 0x241B5C)]),
    FilmPhoto(symbol: "flame.fill", colors: [Palette.coral, Palette.red]),
    FilmPhoto(symbol: "snowflake", colors: [Color(hex: 0x9AD8FF), Palette.blue]),
    FilmPhoto(symbol: "tree.fill", colors: [Palette.green, Color(hex: 0x1F7A5A)]),
    FilmPhoto(symbol: "cloud.sun.fill", colors: [Palette.amber, Palette.sky]),
]

private enum FilmMetrics {
    static let frame = CGSize(width: 290, height: 284)
    static let photo = CGSize(width: 262, height: 186)
    static let thumb = CGSize(width: 16, height: 34)
    static let spacing: CGFloat = 2
    static let stripHeight: CGFloat = 48
    /// Strip travel that scrubs one page.
    static var pitch: CGFloat { thumb.width + spacing }

    static func nearness(_ index: Int, _ progress: CGFloat) -> CGFloat {
        max(0, 1 - abs(CGFloat(index) - progress))
    }

    /// Thumbnail rects (x, width) for a fractional page, centred on the strip's middle.
    static func rects(progress: CGFloat, expanded: CGFloat, gap: CGFloat) -> [CGRect] {
        let last: CGFloat = CGFloat(filmPhotos.count - 1)
        let clamped: CGFloat = min(max(progress, 0), last)
        var result: [CGRect] = []
        var x: CGFloat = 0
        for index in filmPhotos.indices {
            let near: CGFloat = nearness(index, clamped)
            let width: CGFloat = thumb.width + (expanded - thumb.width) * near
            let margin: CGFloat = gap * near
            x += margin
            result.append(CGRect(x: x, y: (stripHeight - thumb.height) / 2, width: width, height: thumb.height))
            x += width + margin + spacing
        }
        let lower: Int = Int(clamped.rounded(.down))
        let upper: Int = min(lower + 1, filmPhotos.count - 1)
        let fraction: CGFloat = clamped - CGFloat(lower)
        let centre: CGFloat = result[lower].midX * (1 - fraction) + result[upper].midX * fraction
        let shift: CGFloat = frame.width / 2 - centre - (progress - clamped) * pitch
        return result.map { $0.offsetBy(dx: shift, dy: 0) }
    }
}

private struct FilmstripScrubberDemo: View {
    let ctx: DemoContext
    @State private var progress: CGFloat
    @State private var dragStart: CGFloat?
    @State private var lastTick = 0
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 3 : 0)
    }

    private var lastIndex: CGFloat { CGFloat(filmPhotos.count - 1) }

    var body: some View {
        VStack(spacing: 14) {
            FilmScene(progress: progress, expanded: ctx.cg("width"), gap: ctx.cg("gap"))
                .frame(width: FilmMetrics.frame.width, height: FilmMetrics.frame.height)
                .background(Palette.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
                .overlay(alignment: .top) { photoTarget }
                .overlay(alignment: .bottom) { stripTarget }
            DemoHint(text: L("Drag the filmstrip, or swipe the photo", "拖动胶片条，或滑动照片"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.3) { autoplayStep() }
    }

    private var photoTarget: some View {
        Color.clear
            .frame(width: FilmMetrics.frame.width, height: FilmMetrics.photo.height + 20)
            .contentShape(Rectangle())
            .pageSafeHorizontalDrag(
                onChanged: { dragChanged($0, unit: FilmMetrics.photo.width) },
                onEnded: { dragEnded($0, unit: FilmMetrics.photo.width, limit: 1) }
            )
    }

    private var stripTarget: some View {
        Color.clear
            .frame(width: FilmMetrics.frame.width, height: FilmMetrics.stripHeight + 20)
            .contentShape(Rectangle())
            .simultaneousGesture(SpatialTapGesture().onEnded { stripTapped(at: $0.location.x) })
            .pageSafeHorizontalDrag(
                minimumDistance: 6,
                onChanged: { dragChanged($0, unit: FilmMetrics.pitch) },
                onEnded: { dragEnded($0, unit: FilmMetrics.pitch, limit: lastIndex) }
            )
    }

    private func stripTapped(at x: CGFloat) {
        guard dragStart == nil else { return }
        let rects: [CGRect] = FilmMetrics.rects(progress: progress.rounded(), expanded: ctx.cg("width"), gap: ctx.cg("gap"))
        guard let index = rects.firstIndex(where: { x >= $0.minX - 1 && x <= $0.maxX + 1 }) else { return }
        settle(to: index)
    }

    private func dragChanged(_ value: DragGesture.Value, unit: CGFloat) {
        let start: CGFloat = dragStart ?? progress
        if dragStart == nil {
            dragStart = progress
            lastTick = Int(progress.rounded())
        }
        var page: CGFloat = start - value.translation.width / unit
        if page < 0 { page = -rubberBand(-page, limit: 0.6) }
        if page > lastIndex { page = lastIndex + rubberBand(page - lastIndex, limit: 0.6) }
        progress = page
        let tick: Int = min(max(Int(page.rounded()), 0), filmPhotos.count - 1)
        if tick != lastTick {
            lastTick = tick
            if !ctx.isPreview { Haptics.selection() }
        }
    }

    /// `limit` is how many pages one gesture may travel (1 for a photo swipe, all of them for the strip).
    private func dragEnded(_ value: DragGesture.Value?, unit: CGFloat, limit: CGFloat) {
        guard let start = dragStart else { return }
        dragStart = nil
        let projected: CGFloat = value.map { start - $0.predictedEndTranslation.width / unit } ?? progress
        let limited: CGFloat = min(max(projected, start.rounded() - limit), start.rounded() + limit)
        settle(to: Int(limited.rounded()))
    }

    private func settle(to index: Int) {
        let clamped: Int = min(max(index, 0), filmPhotos.count - 1)
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            progress = CGFloat(clamped)
        }
    }

    /// Preview loop: single steps, then a long fling each way.
    private func autoplayStep() {
        let tour: [Int] = [1, 2, 3, 8, 9, 5, 0]
        settle(to: tour[autoStep % tour.count])
        autoStep += 1
    }
}

// MARK: - Scene

private struct FilmScene: View, Animatable {
    var progress: CGFloat
    let expanded: CGFloat
    let gap: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        VStack(spacing: 10) {
            pager
                .padding(.top, 14)
            strip
            Spacer(minLength: 0)
        }
        .frame(width: FilmMetrics.frame.width, height: FilmMetrics.frame.height)
    }

    private var pager: some View {
        let page: Int = min(max(Int(progress.rounded()), 0), filmPhotos.count - 1)
        return ZStack {
            ForEach(0..<filmPhotos.count, id: \.self) { index in
                let distance: CGFloat = CGFloat(index) - progress
                if abs(distance) < 1.4 {
                    photo(filmPhotos[index], distance: distance)
                }
            }
        }
        .frame(width: FilmMetrics.frame.width, height: FilmMetrics.photo.height)
        .overlay(alignment: .topTrailing) {
            Text(verbatim: "\(page + 1) / \(filmPhotos.count)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(Color.black.opacity(0.35), in: Capsule())
                .padding(.top, 10)
                .padding(.trailing, 24)
        }
    }

    private func photo(_ item: FilmPhoto, distance: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: item.symbol)
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    .offset(x: distance * 36)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .frame(width: FilmMetrics.photo.width, height: FilmMetrics.photo.height)
            .scaleEffect(1 - min(abs(distance), 1) * 0.06)
            .offset(x: distance * (FilmMetrics.photo.width + 10))
    }

    private var strip: some View {
        let rects: [CGRect] = FilmMetrics.rects(progress: progress, expanded: expanded, gap: gap)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<filmPhotos.count, id: \.self) { index in
                let rect: CGRect = rects[index]
                let near: CGFloat = FilmMetrics.nearness(index, progress)
                RoundedRectangle(cornerRadius: 4 + 4 * near, style: .continuous)
                    .fill(LinearGradient(colors: filmPhotos[index].colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        Image(systemName: filmPhotos[index].symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .opacity(Double(near))
                    }
                    .frame(width: rect.width, height: rect.height + 6 * near)
                    .shadow(color: Color.black.opacity(0.18 * Double(near)), radius: 6, y: 3)
                    .offset(x: rect.minX, y: rect.minY - 3 * near)
            }
        }
        .frame(width: FilmMetrics.frame.width, height: FilmMetrics.stripHeight, alignment: .topLeading)
        .mask {
            LinearGradient(
                stops: [
                    Gradient.Stop(color: Color.black.opacity(0), location: 0),
                    Gradient.Stop(color: Color.black, location: 0.14),
                    Gradient.Stop(color: Color.black, location: 0.86),
                    Gradient.Stop(color: Color.black.opacity(0), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
