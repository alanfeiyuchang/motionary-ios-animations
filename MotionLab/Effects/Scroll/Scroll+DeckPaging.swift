import SwiftUI

extension Effect {
    static let scrollDeckPaging = Effect(
        id: "scroll.deck-paging",
        category: .scroll,
        interaction: .scroll,
        name: L("Depth Deck Paging", "纵深卡片翻页"),
        summary: L("Full-height cards page vertically: the one you leave stays put, sinks back and dims while the next slides over it.", "整屏卡片纵向翻页：离开的那张留在原地，后退变暗，下一张从它上面滑过来盖住。"),
        prompt: L(
            "A vertical pager of full-height editorial cards (30 pt continuous corners, gradient art, a large index numeral, headline, reading time). Swiping up does not push the current card away: it stays pinned in place and recedes, scaling from 100% to 88% about its centre, darkening by 45% and blurring up to 3 pt, while the next card slides up over it at finger speed, casting a soft upward shadow on it. When the page settles (native paging deceleration), the receded card keeps a 10 pt sliver showing above the new one, like a deck seen from the front. Swiping down reverses every value exactly, so the old card comes forward as the top one leaves. A side rail of dots stretches the active one into a short bar with a spring (0.35 s, damping 0.7) and a selection haptic marks each page.",
            "一组整屏高度的纵向翻页卡片（30 pt 连续圆角、渐变画面、大号序号、标题与阅读时长）。上滑时当前卡片不会被推走：它钉在原位向后退，绕中心从 100% 缩到 88%，变暗 45%，模糊到 3 pt；下一张卡片跟着手指滑上来盖住它，并在它身上投下一道向上的柔和阴影。按系统分页减速落定后，退后的卡片仍在新卡片上方露出 10 pt 的边，像从正面看一摞卡片。下滑时所有数值原路返回。侧边圆点导轨里，当前圆点以弹簧（0.35 秒、阻尼 0.7）拉成短条，每翻一页有一次选择触感。"
        ),
        implementation: L(
            "A paging vertical ScrollView; each page's visualEffect reads its minY in the scroll view. A page that has moved above the viewport is offset back by the same amount (so it stays pinned), then scaled, dimmed and blurred by how far it has gone. Later pages draw above earlier ones, so the incoming card covers it.",
            "一个纵向分页 ScrollView；每一页的 visualEffect 读取自己在滚动视图里的 minY。已经移到视口上方的页面被反向偏移同样的距离（于是钉在原地），再按离开的比例缩小、变暗、模糊。后面的页面绘制在前面的页面之上，所以新卡片会把它盖住。"
        ),
        apis: ["scrollTargetBehavior(.paging)", "visualEffect", "containerRelativeFrame", "scrollPosition(id:)", "brightness"],
        tags: ["paging", "deck", "stack", "depth", "vertical pager", "翻页", "卡片堆", "纵深", "纵向分页", "堆叠"],
        params: [
            .slider("depth", L("Receded scale", "后退缩放"), 0.7...1.0, default: 0.88),
            .slider("dim", L("Dimming", "变暗程度"), 0...0.7, default: 0.45),
            .slider("peek", L("Deck peek", "露出高度"), 0...18, default: 10, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        ScrollDeckDemo(ctx: ctx)
    }
}

private struct ScrollDeckDemo: View {
    let ctx: DemoContext
    @State private var page: Int? = 0
    @State private var direction = 1

    private let count = 6

    var body: some View {
        pager
            .overlay(alignment: .trailing) {
                ScrollDeckRail(count: count, current: page ?? 0)
                    .padding(.trailing, 5)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: page) {
                if !ctx.isPreview { Haptics.selection() }
            }
            .autoplay(ctx.isPreview, every: 1.7) { advance() }
    }

    private var pager: some View {
        let depth: CGFloat = ctx.cg("depth")
        let dim: Double = ctx["dim"]
        let peek: CGFloat = ctx.cg("peek")
        return ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    ScrollDeckCard(index: i, total: count, language: ctx.language)
                        .padding(.horizontal, 18)
                        .padding(.top, 26)
                        .padding(.bottom, 12)
                        .containerRelativeFrame(.vertical)
                        .visualEffect { content, proxy in
                            let height: CGFloat = max(proxy.size.height, 1)
                            let y: CGFloat = proxy.frame(in: .scrollView).minY
                            // 0 while the page is in place, 1 once the next page fully covers it.
                            let gone: CGFloat = (-y / height).clamped(to: 0...1)
                            let scale: CGFloat = 1 - (1 - depth) * gone
                            // Scaling about the centre pulls the top edge down by this much; the lift puts it
                            // back and adds the sliver that stays visible above the covering card.
                            let shrink: CGFloat = (height - 38) * (1 - scale) / 2
                            let lift: CGFloat = (shrink + peek) * gone
                            // Two pages back the card is hidden anyway: let it go.
                            let buried: CGFloat = (-y / height - 1).clamped(to: 0...1)
                            return content
                                .scaleEffect(scale)
                                .brightness(-dim * Double(gone))
                                .blur(radius: 3 * gone)
                                .opacity(Double(1 - buried))
                                .offset(y: max(-y, 0) - lift)
                        }
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
    }

    private func advance() {
        let now = page ?? 0
        if now + direction >= count || now + direction < 0 { direction = -direction }
        withAnimation(.smooth(duration: 0.9)) {
            page = now + direction
        }
    }
}

// MARK: - Card

private let scrollDeckStories: [(kicker: LocalizedText, title: LocalizedText, minutes: Int)] = [
    (L("Field notes", "现场笔记"), L("The quiet craft of a good spring", "一条好弹簧里的安静功夫"), 4),
    (L("Interview", "访谈"), L("Why the best motion is felt, not seen", "最好的动效是被感觉到的"), 7),
    (L("Teardown", "拆解"), L("Sixty frames inside one swipe", "一次滑动里的六十帧"), 5),
    (L("Opinion", "观点"), L("Stop easing everything in and out", "别再什么都用缓入缓出"), 3),
    (L("Studio visit", "工作室探访"), L("A week with people who draw curves", "和画曲线的人待一周"), 9),
    (L("Archive", "档案"), L("How the rubber band was invented", "橡皮筋回弹是怎么来的"), 6),
]

private struct ScrollDeckCard: View {
    let index: Int
    let total: Int
    let language: AppLanguage

    var body: some View {
        let story = scrollDeckStories[index % scrollDeckStories.count]
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: ScrollKit.colors(index + 2), startPoint: .topLeading, endPoint: .bottomTrailing)
            ScrollDeckDecor(index: index)
            LinearGradient(colors: [.clear, .black.opacity(0.34)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(verbatim: String(format: "%02d", index + 1))
                        .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                    Text(verbatim: "/ " + String(format: "%02d", total))
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .opacity(0.7)
                        .padding(.top, 10)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                Text(story.kicker, language)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(language == .zh ? 2 : 0.8)
                    .opacity(0.85)
                Text(story.title, language)
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(verbatim: language == .zh ? "\(story.minutes) 分钟" : "\(story.minutes) min read")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 20, weight: .semibold))
                        .opacity(index == total - 1 ? 0 : 0.8)
                }
                .font(.caption.weight(.semibold))
                .opacity(0.9)
                .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        // Cast upward, onto the card this one slides over.
        .shadow(color: .black.opacity(0.3), radius: 16, y: -5)
    }
}

private struct ScrollDeckDecor: View {
    let index: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.24))
                .frame(width: 190, height: 190)
                .blur(radius: 30)
                .offset(x: 90, y: -70)
            Circle()
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 18)
                .frame(width: 170, height: 170)
                .offset(x: 110, y: 20)
            Image(systemName: ScrollKit.symbol(index + 2))
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
                .offset(x: 72, y: -38)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Side rail: one dot per page, the current one stretched into a short bar.
private struct ScrollDeckRail: View {
    let count: Int
    let current: Int

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? AnyShapeStyle(Palette.primary) : AnyShapeStyle(Color.primary.opacity(0.2)))
                    .frame(width: 5, height: i == current ? 20 : 5)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: current)
    }
}
