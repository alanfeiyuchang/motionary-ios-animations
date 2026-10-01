import SwiftUI

extension Effect {
    static let scrollStackUnderHeader = Effect(
        id: "scroll.stack-under-header",
        category: .scroll,
        interaction: .scroll,
        name: L("Stack Under Header", "顶部叠放列表"),
        summary: L("Rows that reach the top do not scroll away: they stop under the header, shrink and tuck behind the next one, building a little deck.", "滚到顶部的行不会滚走：它们停在头部下方，缩小并塞到下一行身后，叠成一小摞。"),
        prompt: L(
            "A list of 66 pt cards under a frosted header. A card that reaches the pin line just below the header stops there instead of leaving. As the following card rides up over it, the pinned one scales down about its top edge by 5% per level, lifts 7 pt so a sliver of its top stays visible above the card in front, and darkens slightly; up to three levels are visible and anything deeper fades out behind them. All of it is scrubbed by the scroll position, so the deck builds and deals itself back out exactly with the finger, with each card's shadow separating it from the one beneath. A chip in the header counts the stacked cards with rolling digits; tapping it scrolls to the top in 0.6 s and the deck fans back out into a list.",
            "磨砂头部下方是一列 66 pt 高的卡片。卡片到达头部下面的固定线后就停在那里，不再离开。后面的卡片滑上来盖住它时，被固定的卡片以顶边为锚点每深一层缩小 5%，同时上移 7 pt，让自己的顶边在前一张卡片上方露出一小条，并略微变暗；最多能看到三层，更深的卡片在它们身后淡出。这一切都由滚动位置直接驱动，所以这一摞卡片随手指叠起来，也随手指一张张发回去；每张卡片的阴影把它和下面那张分开。头部的小标签用滚动数字显示已叠放的张数；点一下它，列表在 0.6 秒内滚回顶部，整摞卡片重新散开成列表。"
        ),
        implementation: L(
            "Each row's visualEffect compares its minY in the scroll view with the pin line. Past the line it is offset back to it, and the overshoot divided by the row pitch gives a continuous depth that drives scale (anchored at the top), lift, brightness and opacity. Rows are drawn in order, so later ones cover earlier ones.",
            "每一行的 visualEffect 把自己在滚动视图里的 minY 与固定线比较。越过这条线后被偏移回线上，越过的距离除以行距得到一个连续的“深度”，用来驱动缩放（以顶边为锚点）、上移、亮度和透明度。各行按顺序绘制，所以后面的行会盖住前面的行。"
        ),
        apis: ["visualEffect", "scaleEffect(_:anchor:)", "onScrollGeometryChange", "ScrollPosition", "contentTransition(.numericText)"],
        tags: ["stack", "sticky", "deck", "list", "pinned", "堆叠", "吸顶", "卡片堆", "列表", "固定"],
        params: [
            .slider("scale", L("Shrink per level", "每层缩小"), 0.02...0.1, default: 0.05),
            .slider("peek", L("Edge peek", "露出高度"), 2...12, default: 7, step: 1, decimals: 0, unit: "pt"),
            .slider("depth", L("Visible levels", "可见层数"), 1...4, default: 3, step: 1, decimals: 0),
        ]
    ) { ctx in
        ScrollStackHeaderDemo(ctx: ctx)
    }
}

private let scrollStackHeader: CGFloat = 50
private let scrollStackRow: CGFloat = 66
private let scrollStackPitch: CGFloat = 76
private let scrollStackCount = 16

private struct ScrollStackHeaderDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var down = false

    var body: some View {
        let step: CGFloat = ctx.cg("scale")
        let peek: CGFloat = ctx.cg("peek")
        let levels: CGFloat = max(ctx.cg("depth").rounded(), 1)
        // The pin line leaves room above it for the slivers of the stacked cards.
        let pin: CGFloat = scrollStackHeader + 8 + peek * levels
        let stacked = Int((offset / scrollStackPitch).rounded(.up)).clamped(to: 0...(scrollStackCount - 1))
        return ScrollView {
            VStack(spacing: scrollStackPitch - scrollStackRow) {
                ForEach(0..<scrollStackCount, id: \.self) { i in
                    ScrollKitRow(index: i + 2, language: ctx.language)
                        .frame(height: scrollStackRow)
                        .shadow(color: .black.opacity(0.14), radius: 7, y: 3)
                        .visualEffect { content, proxy in
                            let over: CGFloat = pin - proxy.frame(in: .scrollView).minY
                            let depth: CGFloat = max(over, 0) / scrollStackPitch
                            let shown: CGFloat = min(depth, levels)
                            return content
                                .scaleEffect(1 - step * shown, anchor: .top)
                                .brightness(-0.015 * Double(shown))
                                .opacity(Double(1 - ScrollMath.unit(depth, levels, levels + 0.8)))
                                .offset(y: max(over, 0) - peek * shown)
                        }
                }
            }
            .padding(.top, pin)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        }, action: { _, newValue in
            offset = newValue
        })
        .overlay(alignment: .top) {
            ScrollStackBar(
                stacked: stacked,
                lifted: ScrollMath.unit(offset, 0, 20),
                // The detail stage keeps its Reset button in the top-trailing corner.
                trailingInset: ctx.isPreview ? 14 : 52,
                language: ctx.language,
                onTap: { dealOut() }
            )
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6) {
            down.toggle()
            if down {
                withAnimation(.easeInOut(duration: 2.0)) { position.scrollTo(y: scrollStackPitch * 6) }
            } else {
                dealOut()
            }
        }
    }

    /// The chip's tap: back to the top, dealing the deck out again.
    private func dealOut() {
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.easeInOut(duration: 0.6)) { position.scrollTo(y: 0) }
    }
}

private struct ScrollStackBar: View {
    let stacked: Int
    /// 0 at the top … 1 once rows are under the bar.
    let lifted: CGFloat
    let trailingInset: CGFloat
    let language: AppLanguage
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(L("Inbox", "收件箱"), language)
                .font(.system(size: 22, weight: .bold))
            Spacer(minLength: 0)
            Button(action: onTap) {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(verbatim: String(stacked))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText(value: Double(stacked)))
                    Text(L("stacked", "张已叠放"), language)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(stacked > 0 ? AnyShapeStyle(Color.white) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(Palette.primaryStrong).opacity(stacked > 0 ? 1 : 0)
                }
            }
            .buttonStyle(.plain)
            .animation(.snappy(duration: 0.25), value: stacked)
        }
        .padding(.leading, 16)
        .padding(.trailing, trailingInset)
        .frame(height: scrollStackHeader)
        .demoGlass(Rectangle(), material: .regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.1 * Double(lifted)))
                .frame(height: 0.5)
        }
    }
}
