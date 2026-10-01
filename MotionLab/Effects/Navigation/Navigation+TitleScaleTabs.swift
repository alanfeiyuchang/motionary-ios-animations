import SwiftUI
import UIKit

extension Effect {
    static let navigationTitleScaleTabs = Effect(
        id: "navigation.title-scale-tabs",
        category: .navigation,
        interaction: .gesture,
        name: L("Large-Title Tabs", "大标题标签"),
        summary: L(
            "The tabs are the page titles: the current one is large and bright at the leading edge, the rest shrink into a quiet queue behind it, and the row re-seats itself as you swipe.",
            "标签就是页面标题：当前标题又大又亮地停在最前，其余缩小成一列安静的队伍跟在后面，滑动时整行随之重新就位。"
        ),
        prompt: L(
            "A screen whose tab row is a line of titles set in 32 pt bold. Only the current title is full size and fully opaque, pinned 22 pt from the leading edge; the others are scaled to 50% on a shared baseline and dimmed to 40%, queued to its right. Swiping the content pages drives everything 1:1 from one fractional page index: the outgoing title shrinks and fades to 0 as it slides off the leading edge, the next one grows from 50% to 100% while the whole row slides so that it lands exactly on the 22 pt margin, and the pages below move with a 26 pt parallax on their artwork. Release settles to the nearest page with a spring (response 0.5 s, damping 0.82) and a selection tick; tapping any title plays the same motion. Editorial and confident.",
            "页面的标签栏就是一行 32 pt 粗体标题。只有当前标题是原尺寸、完全不透明，固定在距左缘 22 pt 处；其余沿同一条基线缩到 50%、透明度 40%，排在右侧。横滑内容页时，一切由同一个小数页码 1:1 驱动：离开的标题边缩小边淡出到 0，从左缘滑走；下一个标题从 50% 长到 100%，整行同时平移，让它恰好落在 22 pt 的边距上；下方页面的插图带 26 pt 视差。松手后以弹簧（响应 0.5 秒、阻尼 0.82）吸附到最近的页面，伴随一次选择触感；点击任意标题播放同样的动作。有杂志感，从容自信。"
        ),
        implementation: L(
            "An Animatable scene takes the fractional page index and derives each title's scale, opacity and x from it (widths are measured with UIFont, positions are the running sum of scaled widths), so the drag and the settling spring share one code path; titles are drawn once at full size and scaled from the baseline.",
            "一个 Animatable 场景视图接收小数页码，并由它推导每个标题的缩放、透明度与横坐标（宽度用 UIFont 测量，位置是缩放后宽度的累加），拖拽与落定弹簧走同一段代码；标题只以原尺寸绘制一次，再以基线为锚点缩放。"
        ),
        apis: ["Animatable", "scaleEffect(_:anchor:)", "DragGesture", "predictedEndTranslation", "spring(response:dampingFraction:)"],
        tags: ["large title", "pivot", "tabs", "pager", "大标题", "标签", "分页", "枢轴"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .slider("small", L("Inactive scale", "未选中缩放"), 0.35...0.8, default: 0.5),
            .slider("dim", L("Inactive opacity", "未选中透明度"), 0.15...0.8, default: 0.4),
        ]
    ) { ctx in
        TitleScaleTabsDemo(ctx: ctx)
    }
}

private struct TitlePage {
    let title: LocalizedText
    let symbol: String
    let colors: [Color]
    let caption: LocalizedText
}

private let titlePages: [TitlePage] = [
    TitlePage(title: L("Today", "今日"), symbol: "sun.max.fill", colors: [Palette.amber, Palette.coral], caption: L("Morning mix", "晨间精选")),
    TitlePage(title: L("Discover", "发现"), symbol: "sparkles", colors: [Palette.indigo, Palette.violet], caption: L("New for you", "为你上新")),
    TitlePage(title: L("Library", "资料库"), symbol: "square.stack.fill", colors: [Palette.mint, Palette.sky], caption: L("Recently added", "最近添加")),
    TitlePage(title: L("Profile", "我的"), symbol: "person.fill", colors: [Palette.pink, Palette.violet], caption: L("Your year so far", "你的这一年")),
]

private enum TitleTabsMetrics {
    static let frame = CGSize(width: 290, height: 284)
    static let fontSize: CGFloat = 32
    static let inset: CGFloat = 22
    static let gap: CGFloat = 16
    static let rowHeight: CGFloat = 44
    static let parallax: CGFloat = 26

    static var font: UIFont { UIFont.systemFont(ofSize: fontSize, weight: .bold) }

    static func widths(_ language: AppLanguage) -> [CGFloat] {
        titlePages.map { ceil(($0.title(language) as NSString).size(withAttributes: [.font: font]).width) }
    }

    static func nearness(_ index: Int, _ progress: CGFloat) -> CGFloat {
        max(0, 1 - abs(CGFloat(index) - progress))
    }

    /// Leading x of every title for a fractional page, already shifted so the current title sits on the inset.
    static func positions(progress: CGFloat, widths: [CGFloat], small: CGFloat) -> [CGFloat] {
        var xs: [CGFloat] = []
        var x: CGFloat = 0
        for index in widths.indices {
            xs.append(x)
            let scale: CGFloat = small + (1 - small) * nearness(index, progress)
            x += widths[index] * scale + gap
        }
        let clamped: CGFloat = min(max(progress, 0), CGFloat(widths.count - 1))
        let lower: Int = Int(clamped.rounded(.down))
        let upper: Int = min(lower + 1, widths.count - 1)
        let fraction: CGFloat = clamped - CGFloat(lower)
        let anchor: CGFloat = xs[lower] * (1 - fraction) + xs[upper] * fraction
        // Past either end the row follows the rubber-banding pages a little.
        let overshoot: CGFloat = (progress - clamped) * 60
        return xs.map { $0 - anchor + inset - overshoot }
    }
}

private struct TitleScaleTabsDemo: View {
    let ctx: DemoContext
    @State private var progress: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var autoForward = true

    private var lastIndex: CGFloat { CGFloat(titlePages.count - 1) }

    var body: some View {
        VStack(spacing: 14) {
            TitleTabsScene(progress: progress, small: ctx.cg("small"), dim: ctx["dim"], language: ctx.language)
                .frame(width: TitleTabsMetrics.frame.width, height: TitleTabsMetrics.frame.height)
                .background(Palette.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
                .overlay(alignment: .topLeading) { titleTargets }
                .contentShape(Rectangle())
                .pageSafeHorizontalDrag(onChanged: dragChanged, onEnded: dragEnded)
            DemoHint(text: L("Swipe the page, or tap a title", "左右滑动页面，或点击标题"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoplayStep() }
    }

    /// Invisible tap targets laid over the titles at their settled positions.
    private var titleTargets: some View {
        let widths: [CGFloat] = TitleTabsMetrics.widths(ctx.language)
        let page: CGFloat = progress.rounded()
        let xs: [CGFloat] = TitleTabsMetrics.positions(progress: page, widths: widths, small: ctx.cg("small"))
        return ZStack(alignment: .topLeading) {
            ForEach(0..<titlePages.count, id: \.self) { index in
                let scale: CGFloat = CGFloat(index) == page ? 1 : ctx.cg("small")
                Color.clear
                    .frame(width: widths[index] * scale + 8, height: TitleTabsMetrics.rowHeight + 8)
                    .contentShape(Rectangle())
                    .onTapGesture { tapped(index) }
                    .offset(x: xs[index] - 4, y: 14)
            }
        }
        .frame(width: TitleTabsMetrics.frame.width, height: 70, alignment: .topLeading)
        .clipped()
    }

    private func tapped(_ index: Int) {
        guard index != Int(progress.rounded()) else { return }
        settle(to: index)
    }

    private func dragChanged(_ value: DragGesture.Value) {
        let start: CGFloat = dragStart ?? progress
        if dragStart == nil { dragStart = progress }
        var page: CGFloat = start - value.translation.width / TitleTabsMetrics.frame.width
        if page < 0 { page = -rubberBand(-page, limit: 0.5) }
        if page > lastIndex { page = lastIndex + rubberBand(page - lastIndex, limit: 0.5) }
        progress = page
    }

    private func dragEnded(_ value: DragGesture.Value?) {
        guard let start = dragStart else { return }
        dragStart = nil
        let projected: CGFloat = value.map { start - $0.predictedEndTranslation.width / TitleTabsMetrics.frame.width } ?? progress
        let limited: CGFloat = min(max(projected, start.rounded() - 1), start.rounded() + 1)
        settle(to: Int(limited.rounded()))
    }

    private func settle(to index: Int) {
        let clamped: Int = min(max(index, 0), titlePages.count - 1)
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            progress = CGFloat(clamped)
        }
    }

    private func autoplayStep() {
        let current: Int = Int(progress.rounded())
        var next: Int = current + (autoForward ? 1 : -1)
        if next >= titlePages.count {
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

private struct TitleTabsScene: View, Animatable {
    var progress: CGFloat
    let small: CGFloat
    let dim: Double
    let language: AppLanguage

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titles
                .padding(.top, 18)
            pages
                .padding(.top, 10)
        }
        .frame(width: TitleTabsMetrics.frame.width, height: TitleTabsMetrics.frame.height, alignment: .topLeading)
    }

    private var titles: some View {
        let widths: [CGFloat] = TitleTabsMetrics.widths(language)
        let xs: [CGFloat] = TitleTabsMetrics.positions(progress: progress, widths: widths, small: small)
        let descent: CGFloat = abs(TitleTabsMetrics.font.descender)
        return ZStack(alignment: .bottomLeading) {
            ForEach(0..<titlePages.count, id: \.self) { index in
                let near: CGFloat = TitleTabsMetrics.nearness(index, progress)
                let scale: CGFloat = small + (1 - small) * near
                // Titles already passed fade out completely; the queue ahead stays at the dim level.
                let passed: Bool = CGFloat(index) < progress
                let rest: Double = passed ? 0 : dim
                Text(titlePages[index].title, language)
                    .font(.system(size: TitleTabsMetrics.fontSize, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .fixedSize()
                    .scaleEffect(scale, anchor: .bottomLeading)
                    // Keeps every size on the large title's baseline.
                    .offset(x: xs[index], y: -descent * (1 - scale))
                    .opacity(rest + (1 - rest) * Double(near))
            }
        }
        .frame(width: TitleTabsMetrics.frame.width, height: TitleTabsMetrics.rowHeight, alignment: .bottomLeading)
    }

    private var pages: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<titlePages.count, id: \.self) { index in
                let distance: CGFloat = CGFloat(index) - progress
                if abs(distance) < 1.5 {
                    page(titlePages[index], distance: distance)
                        .offset(x: distance * TitleTabsMetrics.frame.width)
                }
            }
        }
        .frame(width: TitleTabsMetrics.frame.width, alignment: .topLeading)
    }

    private func page(_ item: TitlePage, distance: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: item.symbol)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 20)
                    .offset(x: distance * TitleTabsMetrics.parallax)
                Text(item.caption, language)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .padding(14)
            }
            .frame(height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.colors[row % item.colors.count].opacity(0.3))
                        .frame(width: 34, height: 34)
                    PlaceholderLines(count: 2, color: Color.primary.opacity(0.1))
                }
            }
        }
        .padding(.horizontal, TitleTabsMetrics.inset)
        .frame(width: TitleTabsMetrics.frame.width, alignment: .topLeading)
        .opacity(Double(1 - min(abs(distance), 1) * 0.5))
    }
}
