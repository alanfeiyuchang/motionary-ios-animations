import SwiftUI

extension Effect {
    static let scrollTextReveal = Effect(
        id: "scroll.text-reveal",
        category: .scroll,
        interaction: .scroll,
        name: L("Scroll-lit Text", "滚动点亮文字"),
        summary: L("A bold paragraph lights up word by word, in reading order, as it scrolls through a focus line.", "粗体段落在滚过焦点线时，按阅读顺序一个词一个词地亮起。"),
        prompt: L(
            "A long statement set in 23 pt bold type, wrapped across many lines, starts at 16% opacity. A focus line sits at 60% of the viewport height. As the text scrolls up through it, words light to full opacity one after another in reading order: each word's trigger point is its vertical position plus a share of one line height proportional to how far along the line it sits, so a line fills left to right instead of all at once. The fade for a single word spans a 44 pt band, and inside that band the word is tinted with an indigo-violet gradient that peaks at the wavefront and drains to plain text behind it. Scrolling back dims the words in reverse. No timers: the reader's finger is the playhead. Editorial, deliberate, like a keynote.",
            "一段很长的陈述用23 pt粗体排成多行，初始不透明度只有16%。焦点线位于视口高度的60%处。文字向上滚过这条线时，各个词按阅读顺序依次亮到完全不透明：每个词的触发点等于它的纵向位置，再加上与行内横向位置成比例的一部分行高，所以一行字是从左到右填满，而不是整行同时亮起。单个词的渐变跨越44 pt的过渡带，在带内它会染上靛蓝到紫色的渐变，波前处最浓，随后褪成普通文字。往回滚动时按相反顺序暗下去。没有计时器：读者的手指就是播放头。克制而有编辑感，像发布会上的大字幕。"
        ),
        implementation: L(
            "Words are separate Text views placed by a custom flow Layout. Each word's visualEffect reads its frame in the .scrollView space, adds a line-height share of its x position to get a reading-order coordinate and maps that across the band to opacity; an overlaid gradient copy uses a triangular weight for the wavefront tint.",
            "每个词是独立的 Text，由自定义的流式 Layout 排版。每个词的 visualEffect 读取自身在 .scrollView 坐标空间中的位置，加上按横向位置折算的一部分行高，得到阅读顺序坐标，再跨过渡带映射为不透明度；叠在上面的渐变副本用三角形权重实现波前着色。"
        ),
        apis: ["Layout", "visualEffect", "coordinateSpace(.scrollView)", "ScrollPosition", "onGeometryChange"],
        tags: ["text reveal", "scroll-driven", "highlight", "words", "reading", "文字点亮", "滚动驱动", "高亮", "逐词", "阅读"],
        params: [
            .slider("focus", L("Focus line", "焦点线位置"), 0.3...0.7, default: 0.6),
            .slider("band", L("Fade band", "过渡带"), 20...140, default: 44, step: 5, decimals: 0, unit: "pt"),
            .slider("dim", L("Unlit opacity", "未点亮不透明度"), 0.05...0.4, default: 0.16),
            .toggle("tint", L("Wavefront tint", "波前着色"), default: true),
        ]
    ) { ctx in
        ScrollTextRevealDemo(ctx: ctx)
    }
}

private let scrollRevealParagraphs: [LocalizedText] = [
    L(
        "Motion is not decoration. It is how an interface explains itself: where things came from, where they went, and what just changed.",
        "动效不是装饰。它是界面解释自己的方式：东西从哪里来，到哪里去，刚才又发生了什么变化。"
    ),
    L(
        "When the finger drives the timeline, nothing has to be waited for. You read at your own pace and the page keeps up.",
        "当手指掌控时间轴，就没有什么需要等待。你按自己的节奏阅读，页面始终跟得上。"
    ),
    L(
        "A spring remembers speed. An easing curve only remembers time. That is why one feels alive and the other merely correct.",
        "弹簧记得速度，缓动曲线只记得时间。所以前者显得鲜活，后者只是正确。"
    ),
    L(
        "Give every pixel a reason to move, and a place to rest.",
        "让每个像素的移动都有理由，停下时都有归处。"
    ),
    L(
        "The best animation is the one you only notice when it is gone.",
        "最好的动画，是它消失之后你才察觉到的那一个。"
    ),
]

private let scrollRevealLineHeight: CGFloat = 34

private struct ScrollTextRevealDemo: View {
    let ctx: DemoContext
    @State private var position = ScrollPosition(edge: .top)
    @State private var size = CGSize(width: 340, height: 340)
    @State private var down = false

    var body: some View {
        let focusY: CGFloat = size.height * ctx.cg("focus")
        let style = ScrollRevealStyle(
            focusY: focusY,
            band: max(ctx.cg("band"), 1),
            dim: ctx["dim"],
            tint: ctx.bool("tint"),
            width: max(size.width, 1)
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text(L("ON MOTION", "关于动效"), ctx.language)
                    .font(.caption.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Palette.violetText)
                ForEach(scrollRevealParagraphs.indices, id: \.self) { i in
                    ScrollRevealParagraph(text: scrollRevealParagraphs[i](ctx.language), isChinese: ctx.language == .zh, style: style)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 30)
            // Lets the last word reach the focus line.
            .padding(.bottom, max(size.height - focusY, 0) + 12)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .overlay(alignment: .top) {
            ScrollRevealFocusMarks()
                .offset(y: focusY)
                .opacity(ctx.isPreview ? 0 : 1)
                .allowsHitTesting(false)
        }
        .onGeometryChange(for: CGSize.self, of: { proxy in proxy.size }, action: { newSize in
            size = newSize
        })
        .autoplay(ctx.isPreview, every: 5.2) {
            guard ctx.isPreview else {
                // Detail intro: read the first few lines, then hand over to the finger.
                withAnimation(.easeInOut(duration: 2.2)) { position.scrollTo(y: 170) }
                return
            }
            down.toggle()
            withAnimation(.easeInOut(duration: 4.6)) {
                position.scrollTo(edge: down ? .bottom : .top)
            }
        }
    }
}

private struct ScrollRevealStyle {
    let focusY: CGFloat
    let band: CGFloat
    let dim: Double
    let tint: Bool
    let width: CGFloat

    /// 0 (unlit) … 1 (lit) for a word frame, in reading order: words further along a line trigger later.
    func lit(_ frame: CGRect) -> CGFloat {
        let along: CGFloat = (frame.midX / width).clamped(to: 0...1) - 0.5
        let y: CGFloat = frame.midY + along * scrollRevealLineHeight
        return ((focusY + band / 2 - y) / band).clamped(to: 0...1)
    }
}

private struct ScrollRevealParagraph: View {
    let text: String
    let isChinese: Bool
    let style: ScrollRevealStyle

    var body: some View {
        let words = ScrollRevealParagraph.tokens(text, isChinese: isChinese)
        let style = self.style
        ScrollRevealFlow(spacing: isChinese ? 0 : 6, lineHeight: scrollRevealLineHeight) {
            ForEach(words.indices, id: \.self) { i in
                Text(verbatim: words[i])
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.primary)
                    .visualEffect { content, proxy in
                        let t = Double(style.lit(proxy.frame(in: .scrollView)))
                        return content.opacity(style.dim + (1 - style.dim) * t)
                    }
                    .overlay {
                        if style.tint {
                            Text(verbatim: words[i])
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(Palette.primary)
                                .visualEffect { content, proxy in
                                    let t = Double(style.lit(proxy.frame(in: .scrollView)))
                                    // Triangular weight: strongest at the wavefront, gone once fully lit.
                                    return content.opacity(1 - abs(2 * t - 1))
                                }
                        }
                    }
            }
        }
    }

    /// English splits on spaces; Chinese splits per character, with punctuation kept on the previous
    /// character so a line never starts with a comma or full stop.
    static func tokens(_ text: String, isChinese: Bool) -> [String] {
        guard isChinese else { return text.split(separator: " ").map(String.init) }
        var result: [String] = []
        let closers: Set<Character> = ["，", "。", "：", "；", "、", "！", "？", "”", "）"]
        for character in text {
            if closers.contains(character), let last = result.popLast() {
                result.append(last + String(character))
            } else {
                result.append(String(character))
            }
        }
        return result
    }
}

/// A minimal left-aligned flow layout with a fixed line height.
private struct ScrollRevealFlow: Layout {
    let spacing: CGFloat
    let lineHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let lines = arrange(width: width, subviews: subviews).lines
        return CGSize(width: width, height: CGFloat(lines) * lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let points = arrange(width: bounds.width, subviews: subviews).points
        for (index, subview) in subviews.enumerated() {
            let point = points[index]
            subview.place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y + lineHeight / 2),
                anchor: .leading,
                proposal: .unspecified
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], lines: Int) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var line = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                line += 1
            }
            points.append(CGPoint(x: x, y: CGFloat(line) * lineHeight))
            x += size.width + spacing
        }
        return (points, subviews.isEmpty ? 0 : line + 1)
    }
}

/// Two small ticks at the edges of the stage marking the focus line.
private struct ScrollRevealFocusMarks: View {
    var body: some View {
        HStack {
            Capsule().frame(width: 10, height: 2)
            Spacer(minLength: 0)
            Capsule().frame(width: 10, height: 2)
        }
        .foregroundStyle(Palette.violetText.opacity(0.7))
        .padding(.horizontal, 5)
    }
}
