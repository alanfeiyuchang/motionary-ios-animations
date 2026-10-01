import SwiftUI

extension Effect {
    static let scrollPageTurn = Effect(
        id: "scroll.page-turn",
        category: .scroll,
        interaction: .gesture,
        name: L("Magazine Page Turn", "杂志翻页"),
        summary: L("An open magazine: each leaf swings over the spine in perspective, shaded along the fold and casting a shadow on the page below.", "一本摊开的杂志：每一页带透视地绕书脊翻过去，折痕处有明暗变化，并在下面的书页上投下阴影。"),
        prompt: L(
            "An open magazine seen from above: two cream pages of 148 × 226 pt meeting at a spine, each with a soft gutter shadow, headline, artwork and a page number. Dragging left lifts the right-hand leaf and swings it about the spine through 180° with perspective 0.5, so its free edge grows as it rises. The leaf is two-sided: past 90° its back, the next left page, is showing. While it turns, a gradient darkens it toward the free edge (up to 35% at 90°), a narrow sheen crosses it, and it casts a shadow onto the page beneath whose width follows the leaf's projected width. The stacked page edges under each side grow and shrink with the pages left. Release settles with a spring (0.7 s, damping 0.9) on the nearer spread; tapping either page turns one leaf. A soft haptic marks each landing.",
            "俯视一本摊开的杂志：两页 148×226 pt 的米白书页在书脊相接，各有订口阴影、标题、插图和页码。向左拖动掀起右页，带 0.5 的透视绕书脊转过 180°，外侧边缘随之变大。书页有正反两面，转过 90° 后露出背面，即下一个左页。翻动途中，渐变让它向外缘变暗（90° 时最深 35%），一条窄高光扫过页面，它在下面那页投下的阴影宽度跟随自身的投影宽度；两侧露出的页边厚度随剩余页数增减。松手后以弹簧（0.7 秒、阻尼 0.9）停到更近的跨页，点击任意一页翻一张，落定时有一次柔和触感。"
        ),
        implementation: L(
            "A CGFloat turn position drives an Animatable book view. Only three leaves are drawn: the top turned one (flat on the left), the top unturned one (flat on the right) and the leaf in flight, a rotation3DEffect about its leading edge that swaps to a mirrored back face past 90°. Shade, sheen and the cast shadow are gradients computed from the angle's sine and cosine.",
            "用一个 CGFloat 的翻页位置驱动一个 Animatable 的书本视图。只绘制三张书页：最上面已翻过去的一张（平铺在左）、最上面还没翻的一张（平铺在右），以及正在翻的那张——绕自身前缘做 rotation3DEffect，转过 90° 后换成镜像的背面。明暗、高光和投影都是由角度的正弦、余弦算出的渐变。"
        ),
        apis: ["Animatable", "rotation3DEffect", "DragGesture", "LinearGradient", "UnevenRoundedRectangle", "SpatialTapGesture"],
        tags: ["page turn", "book", "magazine", "flip", "fold", "翻页", "书本", "杂志", "翻书", "折痕"],
        params: [
            .slider("perspective", L("Perspective", "透视强度"), 0.1...0.9, default: 0.5),
            .slider("shade", L("Fold shade", "折痕明暗"), 0...0.6, default: 0.35),
            .slider("response", L("Settle response", "落定响应"), 0.3...1.2, default: 0.7, unit: "s"),
        ]
    ) { ctx in
        ScrollPageTurnDemo(ctx: ctx)
    }
}

private let scrollPageLeaves = 5
private let scrollPageSize = CGSize(width: 148, height: 226)
private let scrollPagePaper = Color(hex: 0xFAF7F0)
private let scrollPageInk = Color(hex: 0x1F1C18)

private struct ScrollPageTurnDemo: View {
    let ctx: DemoContext
    /// Number of leaves turned to the left (fractional while one is in flight).
    @State private var turn: CGFloat = 1
    @State private var spread = 1
    @State private var dragStart: CGFloat?
    @State private var direction = 1

    var body: some View {
        VStack(spacing: 16) {
            ScrollPageBook(turn: turn, perspective: ctx.cg("perspective"), shade: ctx["shade"], language: ctx.language)
                .frame(width: scrollPageSize.width * 2, height: scrollPageSize.height)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        flip(to: spread + (value.location.x > scrollPageSize.width ? 1 : -1), haptic: true)
                    }
                )
                .pageSafeHorizontalDrag(
                    onChanged: { value in dragChanged(value.translation.width) },
                    onEnded: { value in dragEnded(value?.predictedEndTranslation.width) }
                )
            ScrollPageCounter(spread: spread, language: ctx.language)
            DemoHint(text: L("Drag a page across · tap to turn", "拖动书页翻过去 · 点击翻页"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.8) { autoStep() }
    }

    private func dragChanged(_ translation: CGFloat) {
        let start = dragStart ?? turn
        if dragStart == nil { dragStart = start }
        // The finger carries the page edge across both pages for one full turn.
        let raw: CGFloat = start - translation / (scrollPageSize.width * 1.7)
        let bounded: CGFloat = raw.clamped(to: max(start - 1, 0)...min(start + 1, CGFloat(scrollPageLeaves)))
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { turn = bounded }
    }

    private func dragEnded(_ predicted: CGFloat?) {
        let start = dragStart ?? turn
        dragStart = nil
        let projected: CGFloat = predicted.map { start - $0 / (scrollPageSize.width * 1.7) } ?? turn
        let target = Int(projected.rounded().clamped(to: (start.rounded() - 1)...(start.rounded() + 1)))
        flip(to: target, haptic: true)
    }

    /// Lands on a whole spread; the same path for drags, taps and autoplay.
    private func flip(to target: Int, haptic: Bool) {
        let clamped = target.clamped(to: 0...scrollPageLeaves)
        let changed = clamped != spread
        spread = clamped
        let response = ctx["response"]
        withAnimation(.spring(response: response, dampingFraction: 0.9)) {
            turn = CGFloat(clamped)
        }
        guard changed, haptic, !ctx.isPreview else { return }
        Task { @MainActor in
            // The page lands roughly when the spring has covered most of its travel.
            try? await Task.sleep(for: .seconds(response * 0.75))
            Haptics.tap(.soft)
        }
    }

    private func autoStep() {
        if spread + direction > scrollPageLeaves - 1 || spread + direction < 1 { direction = -direction }
        flip(to: spread + direction, haptic: false)
    }
}

// MARK: - Book

private struct ScrollPageBook: View, Animatable {
    var turn: CGFloat
    let perspective: CGFloat
    let shade: Double
    let language: AppLanguage

    var animatableData: CGFloat {
        get { turn }
        set { turn = newValue }
    }

    var body: some View {
        let bounded: CGFloat = turn.clamped(to: 0...CGFloat(scrollPageLeaves))
        let flying = Int(bounded.rounded(.down))
        let t: CGFloat = bounded - CGFloat(flying)
        let inFlight = t > 0.0005 && flying < scrollPageLeaves
        // Leaves lying flat: `flying − 1` shows its back on the left, the next unturned one its front on the right.
        let rightLeaf = inFlight ? flying + 1 : flying
        let angle: Double = Double(t) * 180
        let lift: Double = sin(angle * .pi / 180)
        let projected: CGFloat = scrollPageSize.width * CGFloat(abs(cos(angle * .pi / 180)))
        return ZStack {
            ScrollPageEdges(left: bounded, right: CGFloat(scrollPageLeaves) - bounded)
            HStack(spacing: 0) {
                leftBase(flying: flying)
                rightBase(rightLeaf: rightLeaf)
            }
            if inFlight {
                castShadow(onRight: t < 0.5, width: projected, strength: lift)
                flyingLeaf(index: flying, angle: angle, lift: lift)
            }
        }
        .frame(width: scrollPageSize.width * 2, height: scrollPageSize.height)
    }

    @ViewBuilder
    private func leftBase(flying: Int) -> some View {
        if flying == 0 {
            ScrollPagePaper(page: 0, isLeft: true, language: language)
        } else {
            ScrollPagePaper(page: (flying - 1) * 2 + 2, isLeft: true, language: language)
        }
    }

    @ViewBuilder
    private func rightBase(rightLeaf: Int) -> some View {
        if rightLeaf >= scrollPageLeaves {
            ScrollPagePaper(page: scrollPageLeaves * 2 + 1, isLeft: false, language: language)
        } else {
            ScrollPagePaper(page: rightLeaf * 2 + 1, isLeft: false, language: language)
        }
    }

    /// The shadow the lifted leaf throws on the page under it: as wide as the leaf's projection.
    private func castShadow(onRight: Bool, width: CGFloat, strength: Double) -> some View {
        let opacity: Double = (0.12 + shade * 0.7) * strength
        return LinearGradient(
            colors: [Color.black.opacity(opacity), Color.black.opacity(opacity * 0.5), .clear],
            startPoint: onRight ? .leading : .trailing,
            endPoint: onRight ? .trailing : .leading
        )
        .frame(width: min(width + 26, scrollPageSize.width), height: scrollPageSize.height)
        .frame(width: scrollPageSize.width, alignment: onRight ? .leading : .trailing)
        .offset(x: onRight ? scrollPageSize.width / 2 : -scrollPageSize.width / 2)
        .allowsHitTesting(false)
    }

    private func flyingLeaf(index: Int, angle: Double, lift: Double) -> some View {
        let showsBack = angle > 90
        return ZStack {
            if showsBack {
                ScrollPagePaper(page: index * 2 + 2, isLeft: true, language: language)
                    .overlay {
                        // The back catches less light until it lies flat again.
                        LinearGradient(
                            colors: [Color.black.opacity(shade * lift), Color.black.opacity(shade * lift * 0.25)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .scaleEffect(x: -1)
            } else {
                ScrollPagePaper(page: index * 2 + 1, isLeft: false, language: language)
                    .overlay {
                        LinearGradient(
                            colors: [Color.black.opacity(shade * lift * 0.2), Color.black.opacity(shade * lift)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
            }
            // A sheen that crosses the page while it stands up.
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.5 * lift), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 46)
            .offset(x: scrollPageSize.width * (0.5 - CGFloat(angle / 180)))
            .blendMode(.plusLighter)
        }
        .frame(width: scrollPageSize.width, height: scrollPageSize.height)
        .clipShape(ScrollPagePaper.shape(isLeft: false))
        .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: perspective)
        .offset(x: scrollPageSize.width / 2)
        .shadow(color: .black.opacity(0.16 * lift), radius: 10, y: 6)
        .allowsHitTesting(false)
    }
}

/// The stacked page edges peeking out under each side: thicker where more pages lie.
private struct ScrollPageEdges: View {
    let left: CGFloat
    let right: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                let step = CGFloat(3 - k)
                let leftShift: CGFloat = min(left, step) * 1.6
                let rightShift: CGFloat = min(right, step) * 1.6
                HStack(spacing: 0) {
                    ScrollPagePaper.shape(isLeft: true)
                        .fill(Color(hex: 0xE4DFD3))
                        .overlay(ScrollPagePaper.shape(isLeft: true).strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5))
                        .offset(x: -leftShift, y: leftShift * 0.7)
                    ScrollPagePaper.shape(isLeft: false)
                        .fill(Color(hex: 0xE4DFD3))
                        .overlay(ScrollPagePaper.shape(isLeft: false).strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5))
                        .offset(x: rightShift, y: rightShift * 0.7)
                }
            }
        }
        .shadow(color: .black.opacity(0.22), radius: 16, y: 12)
    }
}

// MARK: - Pages

/// One printed page. Page 0 is the inside front cover and the last one the inside back cover.
private struct ScrollPagePaper: View {
    let page: Int
    let isLeft: Bool
    let language: AppLanguage

    static func shape(isLeft: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isLeft ? 9 : 1.5,
            bottomLeadingRadius: isLeft ? 9 : 1.5,
            bottomTrailingRadius: isLeft ? 1.5 : 9,
            topTrailingRadius: isLeft ? 1.5 : 9,
            style: .continuous
        )
    }

    var body: some View {
        ZStack {
            scrollPagePaper
            content
                .padding(.horizontal, 13)
                .padding(.top, 14)
                .padding(.bottom, 22)
            // Gutter shadow along the spine.
            LinearGradient(
                colors: [Color.black.opacity(0.2), Color.black.opacity(0.05), .clear],
                startPoint: isLeft ? .trailing : .leading,
                endPoint: isLeft ? .leading : .trailing
            )
            .frame(width: 30)
            .frame(maxWidth: .infinity, alignment: isLeft ? .trailing : .leading)
            Text(verbatim: page == 0 || page > scrollPageLeaves * 2 ? "" : String(page))
                .font(.system(size: 9, weight: .semibold, design: .serif).monospacedDigit())
                .foregroundStyle(scrollPageInk.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLeft ? .bottomLeading : .bottomTrailing)
                .padding(10)
        }
        .frame(width: scrollPageSize.width, height: scrollPageSize.height)
        .clipShape(Self.shape(isLeft: isLeft))
    }

    @ViewBuilder
    private var content: some View {
        if page == 0 {
            cover(title: L("MOTION", "动效"), line: L("Quarterly · Issue 12", "季刊 · 第 12 期"))
        } else if page > scrollPageLeaves * 2 {
            cover(title: L("FIN", "完"), line: L("Next issue in spring", "下一期春季见"))
        } else {
            switch page % 3 {
            case 0: feature
            case 1: gallery
            default: quote
            }
        }
    }

    private func cover(title: LocalizedText, line: LocalizedText) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Text(title, language)
                .font(.system(size: 30, weight: .black, design: .serif))
                .tracking(2)
            Rectangle()
                .fill(scrollPageInk)
                .frame(width: 36, height: 2)
            Text(line, language)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .opacity(0.65)
            Spacer(minLength: 0)
        }
        .foregroundStyle(scrollPageInk)
        .frame(maxWidth: .infinity)
    }

    private var headlines: [LocalizedText] {
        [
            L("Springs with a memory", "有记忆的弹簧"), L("The weight of a swipe", "一次滑动的分量"),
            L("Light that follows", "跟着走的光"), L("Slow in, never out", "只缓入，不缓出"),
            L("Paper, glass, ink", "纸、玻璃与墨"),
        ]
    }

    private func art(height: CGFloat) -> some View {
        LinearGradient(colors: ScrollKit.colors(page + 1), startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: ScrollKit.symbol(page + 1))
                    .font(.system(size: height * 0.42, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func lines(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(scrollPageInk.opacity(0.16))
                    .frame(height: 3.5)
                    .frame(maxWidth: i == count - 1 ? 60 : .infinity, alignment: .leading)
            }
        }
    }

    private var feature: some View {
        VStack(alignment: .leading, spacing: 9) {
            art(height: 84)
            Text(headlines[page % headlines.count], language)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(scrollPageInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            lines(6)
            Spacer(minLength: 0)
        }
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headlines[page % headlines.count], language)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(scrollPageInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            lines(3)
            art(height: 62)
            lines(4)
            Spacer(minLength: 0)
        }
    }

    private var quote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "“")
                .font(.system(size: 44, weight: .black, design: .serif))
                .foregroundStyle(ScrollKit.colors(page + 1)[0])
                .frame(height: 30, alignment: .top)
            Text(headlines[page % headlines.count], language)
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(scrollPageInk)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            Rectangle()
                .fill(scrollPageInk.opacity(0.8))
                .frame(width: 26, height: 1.5)
            lines(7)
            Spacer(minLength: 0)
        }
    }
}

private struct ScrollPageCounter: View {
    let spread: Int
    let language: AppLanguage

    var body: some View {
        let total = scrollPageLeaves * 2
        let label: String
        if spread == 0 {
            label = language == .zh ? "封面内页" : "Inside cover"
        } else if spread == scrollPageLeaves {
            label = language == .zh ? "第 \(total) 页 · 共 \(total) 页" : "Page \(total) of \(total)"
        } else {
            label = language == .zh ? "第 \(spread * 2)–\(spread * 2 + 1) 页 · 共 \(total) 页" : "Pages \(spread * 2)–\(spread * 2 + 1) of \(total)"
        }
        return Text(verbatim: label)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
            .contentTransition(.numericText(value: Double(spread)))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.07), in: Capsule())
            .animation(.snappy, value: spread)
    }
}
