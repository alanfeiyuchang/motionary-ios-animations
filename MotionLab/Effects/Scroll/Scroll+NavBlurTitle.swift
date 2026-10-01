import SwiftUI

extension Effect {
    static let scrollNavBlurTitle = Effect(
        id: "scroll.nav-blur-title",
        category: .scroll,
        interaction: .scroll,
        name: L("Large Title Hand-off", "大标题交接导航栏"),
        summary: L("The bar frosts over as the large title slides under it, and the inline title fades up at the instant the large one disappears.", "大标题滑到导航栏下面时，导航栏逐渐结出磨砂；大标题消失的那一刻，栏内的小标题上浮淡入。"),
        prompt: L(
            "A navigation screen: a transparent 46 pt bar (back chevron, action icon) over a list that begins with a 32 pt bold large title. The title is real content and scrolls away with the list. As its cap height passes under the bar's bottom edge (offset 6 → 30 pt) the bar's material fades from 0 to 100% in step with it, so the title is seen blurring behind the glass rather than being cut off, and a hairline grows in. The moment the title's baseline crosses the edge (31 pt), the inline title fades in over 0.22 s while rising 7 pt and sharpening from a 3 pt blur; scrolling back reverses it at the same threshold. Pulling down past the top scales the large title up to 112% from its leading baseline. The result reads as one title changing places, never two shown at once.",
            "导航界面：46 pt 高的透明导航栏下面是以 32 pt 粗体大标题开头的列表。大标题是真正的内容，会跟着列表滚走。它的字身从导航栏下沿下面穿过时（偏移 6 → 30 pt），磨砂材质同步从 0 淡到 100%，看到的是标题在玻璃后面被虚化而不是被切掉。标题基线越过下沿的那一刻（31 pt），栏内小标题在 0.22 秒内淡入，同时上移 7 pt、由 3 pt 的模糊变清晰；往回滚动时在同一阈值反转。在顶部继续下拉，大标题以左下为锚点放大到 112%。看起来是同一个标题换了位置，两者不会同时出现。"
        ),
        implementation: L(
            "onScrollGeometryChange publishes the offset. The bar's material opacity is a clamped linear function of it; the inline title is a Bool flipped at the threshold inside a short timed animation, so it is triggered by position but plays in time, like the system bar. The large title is ordinary scroll content with a pull-driven scaleEffect.",
            "onScrollGeometryChange 发布偏移量。导航栏材质的不透明度是它的一个截断线性函数；栏内小标题是一个在阈值处翻转的 Bool，翻转放在一段短的定时动画里，所以它由位置触发、按时间播放，和系统导航栏一样。大标题只是普通的滚动内容，加了一个由下拉驱动的 scaleEffect。"
        ),
        apis: ["onScrollGeometryChange", "Material", "mask", "scaleEffect(_:anchor:)", "withAnimation", "blur(radius:)"],
        tags: ["navigation bar", "large title", "blur", "inline title", "scroll edge", "导航栏", "大标题", "模糊", "小标题", "滚动边缘"],
        params: [
            .choice("edge", L("Bar edge", "栏底边缘"), [L("Hairline", "细线"), L("Soft fade", "柔和渐隐")], default: 0),
            .slider("handoff", L("Hand-off point", "交接位置"), 0.4...1.2, default: 1.0),
            .slider("fade", L("Title fade", "标题淡入时长"), 0.1...0.6, default: 0.22, unit: "s"),
        ]
    ) { ctx in
        ScrollNavBlurDemo(ctx: ctx)
    }
}

private let scrollNavBar: CGFloat = 46
/// Scroll offset at which the large title's baseline meets the bar's bottom edge.
private let scrollNavBaseline: CGFloat = 31

private struct ScrollNavBlurDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var inline = false
    @State private var fingerPull: CGFloat = 0
    @State private var down = false

    var body: some View {
        let pull: CGFloat = max(-offset, 0) + fingerPull
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Color.clear.frame(height: scrollNavBar + fingerPull - 10)
                ScrollNavLargeTitle(pull: pull, language: ctx.language)
                ForEach(0..<14, id: \.self) { i in
                    ScrollKitRow(index: i + 4, language: ctx.language)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        }, action: { _, newValue in
            offset = newValue
            let show = newValue >= scrollNavBaseline * ctx.cg("handoff")
            if show != inline {
                // Triggered by position, played in time.
                withAnimation(.easeOut(duration: ctx["fade"])) { inline = show }
            }
        })
        .overlay(alignment: .top) {
            ScrollNavBar(
                frost: ScrollMath.unit(offset, 6, 30),
                inline: inline,
                soft: ctx.int("edge") == 1,
                // The detail stage keeps its Reset button in the top-trailing corner.
                trailingInset: ctx.isPreview ? 14 : 52,
                language: ctx.language
            )
        }
        .clipped()
        .modifier(ScrollTopPull(isEnabled: !ctx.isPreview && offset <= 0.5, pull: $fingerPull))
        .autoplay(ctx.isPreview, every: 2.2) {
            down.toggle()
            withAnimation(.easeInOut(duration: 1.5)) {
                position.scrollTo(y: down ? 150 : 0)
            }
        }
    }
}

private struct ScrollNavLargeTitle: View {
    let pull: CGFloat
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("Library", "资料库"), language)
                .font(.system(size: 32, weight: .bold))
                .scaleEffect(1 + min(pull / 500, 0.12), anchor: .bottomLeading)
            Text(L("248 songs · 19 albums", "248 首歌曲 · 19 张专辑"), language)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }
}

private struct ScrollNavBar: View {
    /// 0 clear … 1 fully frosted.
    let frost: CGFloat
    let inline: Bool
    let soft: Bool
    let trailingInset: CGFloat
    let language: AppLanguage

    var body: some View {
        ZStack {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text(L("Music", "音乐"), language)
                    .font(.body)
                Spacer(minLength: 0)
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 19, weight: .regular))
                    .padding(.trailing, trailingInset - 14)
            }
            .foregroundStyle(Palette.violetText)
            .padding(.horizontal, 14)
            Text(L("Library", "资料库"), language)
                .font(.headline)
                .opacity(inline ? 1 : 0)
                .offset(y: inline ? 0 : 7)
                .blur(radius: inline ? 0 : 3)
        }
        .frame(height: scrollNavBar)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { backdrop }
    }

    /// The frosted backdrop: a hard edge with a hairline, or a soft edge that melts into the content.
    @ViewBuilder
    private var backdrop: some View {
        if soft {
            DemoMaterial(Rectangle(), material: .regularMaterial)
                .frame(height: scrollNavBar + 22)
                .mask {
                    VStack(spacing: 0) {
                        Color.black.frame(height: scrollNavBar - 6)
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    }
                }
                .opacity(Double(frost))
                .allowsHitTesting(false)
        } else {
            DemoMaterial(Rectangle(), material: .regularMaterial)
                .frame(height: scrollNavBar)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.14))
                        .frame(height: 0.5)
                }
                .opacity(Double(frost))
        }
    }
}
