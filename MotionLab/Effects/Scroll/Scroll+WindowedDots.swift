import SwiftUI

extension Effect {
    static let scrollWindowedDots = Effect(
        id: "scroll.windowed-dots",
        category: .scroll,
        interaction: .scroll,
        name: L("Windowed Page Dots", "滑动窗口页码点"),
        summary: L("Page dots for long galleries: only a window of them is shown, the ones at its edges shrink away, and the strip slides when you page past the edge.", "给长图集用的页码点：只显示一个窗口内的圆点，窗口边缘的圆点逐级缩小，翻过边缘时整条圆点带滑动一格。"),
        prompt: L(
            "A twelve-photo paging gallery with a compact indicator beneath it. Instead of twelve dots, a window of five full-size 7 pt dots is shown; the next dot outside each end is drawn at 66%, the one after at 36%, and the rest are hidden, so the row tapers and hints that more pages exist. The active dot is a 16 pt pill whose width and accent colour are scrubbed by the scroll: as a page slides in, the pill deflates on one dot and inflates on the next in proportion to the drag. When the active page moves past the window's edge, the whole strip slides one dot and the edge dots rescale on a spring (0.35 s, damping 0.8), so the pill appears to push the window along. A counter chip on the photo rolls its digits, and each page change gives a selection haptic.",
            "十二张照片的翻页图集，下方是紧凑的页码指示器。它只显示一个窗口：五个 7 pt 的完整圆点；窗口两端外侧第一个点缩到 66%，再外一个缩到 36%，其余隐藏，整排两头渐细，暗示还有更多页。当前页是一枚 16 pt 的胶囊，宽度和强调色由滚动直接驱动：新的一页滑入时，胶囊在一个点上按拖动比例瘪下去，同时在下一个点上鼓起来。当前页越过窗口边缘时，整条圆点带滑动一格，边缘圆点以弹簧（0.35 秒、阻尼 0.8）重新缩放，像是胶囊推着窗口往前走。照片上的计数标签滚动更新数字，每翻一页有一次选择触感。"
        ),
        implementation: L(
            "onScrollGeometryChange turns the pager's offset into a fractional page; each dot's pill weight is max(0, 1 − |i − page|). The window's first index is state that moves when the settled page leaves it; a dot's scale depends on how far it lies outside the window, and the HStack is offset by the window start, both animated with one spring.",
            "onScrollGeometryChange 把分页器的偏移量换算成带小数的页码；每个圆点的胶囊权重是 max(0, 1 − |i − 页码|)。窗口的起始下标是一个状态，在落定的页面离开窗口时移动；圆点的缩放取决于它在窗口外多远，HStack 按窗口起点做偏移，两者用同一个弹簧做动画。"
        ),
        apis: ["onScrollGeometryChange", "scrollTargetBehavior(.paging)", "scrollPosition(id:)", "spring(response:dampingFraction:)", "contentTransition(.numericText)"],
        tags: ["page control", "dots", "pagination", "gallery", "indicator", "页码点", "分页", "指示器", "图集", "轮播"],
        params: [
            .slider("window", L("Window size", "窗口大小"), 3...7, default: 5, step: 1, decimals: 0),
            .slider("response", L("Slide response", "滑动响应"), 0.2...0.7, default: 0.35, unit: "s"),
            .toggle("scrub", L("Scrub the pill", "胶囊跟随滚动"), default: true),
        ]
    ) { ctx in
        ScrollWindowDotsDemo(ctx: ctx)
    }
}

private let scrollWindowCount = 12

private struct ScrollWindowDotsDemo: View {
    let ctx: DemoContext
    @State private var page: Int? = 0
    /// The pager's position in pages, fractional while a page is in transit.
    @State private var fraction: CGFloat = 0
    @State private var direction = 1

    var body: some View {
        VStack(spacing: 16) {
            pager
            ScrollWindowDots(
                count: scrollWindowCount,
                page: page ?? 0,
                fraction: ctx.bool("scrub") ? fraction : CGFloat(page ?? 0),
                window: ctx.int("window"),
                response: ctx["response"]
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: page) {
            if !ctx.isPreview { Haptics.selection() }
        }
        .autoplay(ctx.isPreview, every: 1.15) { advance() }
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<scrollWindowCount, id: \.self) { i in
                    ScrollWindowPhoto(index: i, language: ctx.language)
                        .padding(.horizontal, 22)
                        .containerRelativeFrame(.horizontal)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.x / max(geometry.containerSize.width, 1)
        }, action: { _, newValue in
            fraction = newValue
        })
        .frame(height: 236)
        .overlay(alignment: .topLeading) {
            ScrollWindowCounter(page: page ?? 0)
                .padding(.leading, 34)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
    }

    private func advance() {
        let now = page ?? 0
        if now + direction >= scrollWindowCount || now + direction < 0 { direction = -direction }
        withAnimation(.smooth(duration: 0.7)) {
            page = now + direction
        }
    }
}

// MARK: - Indicator

private struct ScrollWindowDots: View {
    let count: Int
    let page: Int
    let fraction: CGFloat
    let window: Int
    let response: Double

    @State private var start = 0

    private let dot: CGFloat = 7
    private let gap: CGFloat = 6
    private let pill: CGFloat = 16

    private var size: Int { window.clamped(to: 1...count) }
    private var pitch: CGFloat { dot + gap }

    var body: some View {
        // The window plus two tapering dots on each side, plus the pill's extra width.
        let width: CGFloat = CGFloat(size + 4) * pitch - gap + (pill - dot)
        return HStack(spacing: gap) {
            ForEach(0..<count, id: \.self) { i in
                let weight: CGFloat = max(0, 1 - abs(CGFloat(i) - fraction))
                Capsule()
                    .fill(Color.primary.opacity(0.22))
                    .overlay(Capsule().fill(Palette.primary).opacity(Double(weight)))
                    .frame(width: dot + (pill - dot) * weight, height: dot)
                    .scaleEffect(scale(i))
            }
        }
        .frame(width: width, alignment: .leading)
        .offset(x: -CGFloat(start - 2) * pitch)
        .frame(width: width, height: 16)
        .clipped()
        .animation(.spring(response: response, dampingFraction: 0.8), value: start)
        .animation(.spring(response: response, dampingFraction: 0.8), value: fraction == fraction.rounded() ? page : -1)
        .onChange(of: page) { _, newPage in slide(to: newPage) }
        .onChange(of: size) { slide(to: page) }
    }

    /// 1 inside the window, tapering over the two dots outside each end, 0 beyond.
    private func scale(_ i: Int) -> CGFloat {
        let outside: Int = i < start ? start - i : max(i - (start + size - 1), 0)
        switch outside {
        case 0: return 1
        case 1: return 0.66
        case 2: return 0.36
        default: return 0.001
        }
    }

    /// Moves the window just far enough to contain `target`.
    private func slide(to target: Int) {
        var next = start
        if target < next { next = target }
        if target > next + size - 1 { next = target - size + 1 }
        next = next.clamped(to: 0...max(count - size, 0))
        if next != start { start = next }
    }
}

// MARK: - Photo

private struct ScrollWindowPhoto: View {
    let index: Int
    let language: AppLanguage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return Color.clear
            .overlay {
                // The picture is wider than its frame and drifts against the paging for depth.
                ScrollKitArt(index: index + 5, language: language, showsTitle: false)
                    .padding(.horizontal, -30)
                    .visualEffect { content, proxy in
                        let viewport: CGFloat = max(proxy.bounds(of: .scrollView)?.width ?? 340, 1)
                        let t: CGFloat = (proxy.frame(in: .scrollView).midX / viewport - 0.5).clamped(to: -1...1)
                        return content.offset(x: -t * 30)
                    }
            }
            .overlay(alignment: .bottomLeading) {
                // The caption belongs to the frame, not to the drifting picture.
                VStack(alignment: .leading, spacing: 2) {
                    Text(ScrollKit.title(index + 5), language)
                        .font(.headline.weight(.bold))
                    Text(ScrollKit.subtitle(index + 5), language)
                        .font(.caption.weight(.medium))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
            .padding(.vertical, 4)
    }
}

private struct ScrollWindowCounter: View {
    let page: Int

    var body: some View {
        HStack(spacing: 3) {
            Text(verbatim: String(page + 1))
                .contentTransition(.numericText(value: Double(page)))
            Text(verbatim: "/ \(scrollWindowCount)")
                .opacity(0.7)
        }
        .font(.caption.weight(.bold).monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.32), in: Capsule())
        .animation(.snappy(duration: 0.25), value: page)
    }
}
