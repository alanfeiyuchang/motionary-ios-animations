import SwiftUI

extension Effect {
    static let scrollDateBubble = Effect(
        id: "scroll.date-bubble",
        category: .scroll,
        interaction: .gesture,
        name: L("Scrubber Date Bubble", "拖动滚动条的日期气泡"),
        summary: L("Grab the scrollbar thumb of a photo library and a bubble pops out naming the month under it; the faster you drag, the more it squashes and lags.", "抓住相册的滚动条滑块，旁边弹出一个气泡，显示当前位置的月份；拖得越快，气泡被压得越扁、拖得越靠后。"),
        prompt: L(
            "A photo library grid of two years grouped by month, with a slim scrollbar thumb at the right edge. Touching the scrollbar grabs it: the thumb thickens from 5 to 8 pt and a pointed bubble pops out to its left on a spring (0.3 s, damping 0.6), scaling from 40% about its tip. Dragging moves the thumb with the finger and jumps the grid in proportion, so two years pass in one stroke. The bubble names the month at the top of the grid; the label rolls as months change, each with a selection haptic, and year marks fade in along the track. Speed deforms it: up to 22% flatter and 18% wider at 4000 pt/s, trailing up to 10 pt behind the motion, then wobbling back to round (spring 0.25 s, damping 0.55) when the finger slows. On release it shrinks back into the thumb in 0.2 s.",
            "跨两年的相册网格，右边缘有一条细滚动条滑块。手指碰到滚动条就抓住它：滑块从 5 pt 加粗到 8 pt，一个带尖角的气泡以弹簧（0.3 秒、阻尼 0.6）从左侧弹出，从 40% 放大。拖动时滑块跟着手指走，网格按比例跳转。气泡显示网格顶部所在的月份，月份变化时文字滚动切换并有一次选择触感，轨道旁淡入年份刻度。速度让气泡变形：4000 pt/s 时最多压扁 22%、加宽 18%，并落后运动方向最多 10 pt；手指慢下来时以弹簧（0.25 秒、阻尼 0.55）晃回圆润。松手后气泡在 0.2 秒内缩回滑块。"
        ),
        implementation: L(
            "The thumb's position is the scroll offset divided by the scrollable height. A zero-distance DragGesture on the scrollbar strip claims the touch and writes ScrollPosition.scrollTo(y:) without animation. A frame-rate-independent velocity tracker on the offset feeds the bubble's scale and lag, and month boundaries come from the grid's known row heights.",
            "滑块的位置是滚动偏移量除以可滚动高度。滚动条区域上一个最小距离为零的 DragGesture 接管触摸，并不带动画地写入 ScrollPosition.scrollTo(y:)。对偏移量做与帧率无关的速度估计，用来驱动气泡的缩放和滞后；月份边界由网格已知的行高直接算出。"
        ),
        apis: ["DragGesture", "ScrollPosition", "onScrollGeometryChange", "contentTransition(.numericText)", "scaleEffect(x:y:anchor:)", "LazyVStack"],
        tags: ["scrollbar", "fast scroll", "date", "bubble", "photo library", "滚动条", "快速滚动", "日期", "气泡", "相册"],
        params: [
            .slider("squash", L("Speed squash", "速度形变"), 0...1.5, default: 1.0),
            .slider("response", L("Pop response", "弹出响应"), 0.15...0.6, default: 0.3, unit: "s"),
            .toggle("ticks", L("Year marks", "年份刻度"), default: true),
        ]
    ) { ctx in
        ScrollDateBubbleDemo(ctx: ctx)
    }
}

// MARK: - Library model

private enum ScrollDateLibrary {
    static let months = 24
    static let columns = 4
    static let gap: CGFloat = 3
    static let header: CGFloat = 30
    static let inset: CGFloat = 12

    /// Photos in month `m` (0 is the newest: September 2026).
    static func count(_ m: Int) -> Int { [7, 12, 5, 9, 4, 8, 11, 6][m % 8] }

    static func rows(_ m: Int) -> Int { (count(m) + columns - 1) / columns }

    static func tile(width: CGFloat) -> CGFloat {
        max((width - inset * 2 - gap * CGFloat(columns - 1)) / CGFloat(columns), 20)
    }

    static func height(_ m: Int, width: CGFloat) -> CGFloat {
        header + CGFloat(rows(m)) * (tile(width: width) + gap)
    }

    /// Content y where each month begins.
    static func starts(width: CGFloat) -> [CGFloat] {
        var y: CGFloat = 0
        var result: [CGFloat] = []
        for m in 0..<months {
            result.append(y)
            y += height(m, width: width)
        }
        return result
    }

    static func year(_ m: Int) -> Int { 2026 - (m + 3) / 12 }

    /// 1…12, counting back from September.
    static func month(_ m: Int) -> Int { ((8 - m) % 12 + 12) % 12 + 1 }

    static let namesEN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func label(_ m: Int, _ language: AppLanguage) -> String {
        language == .zh ? "\(year(m))年\(month(m))月" : "\(namesEN[month(m) - 1]) \(year(m))"
    }
}

// MARK: - Demo

private struct ScrollDateBubbleDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var maxOffset: CGFloat = 1
    @State private var viewport = CGSize(width: 340, height: 340)
    @State private var position = ScrollPosition(edge: .top)
    @State private var scrubbing = false
    /// Signed speed, −1…1 (positive while moving down the library).
    @State private var stretch: CGFloat = 0
    @State private var tracker = ScrollVelocityTracker()
    @State private var calmToken = 0
    @State private var grabFraction: CGFloat = 0
    @State private var grabbed = false
    @GestureState private var touching = false
    @State private var month = 0
    @State private var down = false

    private let thumbHeight: CGFloat = 46

    // The detail stage keeps its Reset button in the top-trailing corner.
    private var trackTop: CGFloat { ctx.isPreview ? 10 : 50 }
    private var travel: CGFloat { max(viewport.height - trackTop - 10 - thumbHeight, 1) }
    private var fraction: CGFloat { (offset / max(maxOffset, 1)).clamped(to: 0...1) }
    private var thumbY: CGFloat { trackTop + fraction * travel }

    var body: some View {
        grid
            .overlay(alignment: .topTrailing) { scrollbar }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .autoplay(ctx.isPreview, every: 2.5) { autoScrub() }
    }

    // MARK: Grid

    private var grid: some View {
        let width = viewport.width
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<ScrollDateLibrary.months, id: \.self) { m in
                    ScrollDateMonth(month: m, width: width, language: ctx.language)
                }
            }
            .padding(.horizontal, ScrollDateLibrary.inset)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGRect.self, of: { geometry in
            CGRect(
                x: geometry.contentSize.height - geometry.containerSize.height,
                y: geometry.contentOffset.y + geometry.contentInsets.top,
                width: geometry.containerSize.width,
                height: geometry.containerSize.height
            )
        }, action: { _, newValue in
            geometryChanged(newValue)
        })
    }

    private func geometryChanged(_ value: CGRect) {
        offset = value.origin.y
        maxOffset = max(value.origin.x, 1)
        if value.width > 0 { viewport = value.size }
        let starts = ScrollDateLibrary.starts(width: value.width)
        var current = 0
        for (m, start) in starts.enumerated() where start <= value.origin.y + 24 { current = m }
        if current != month {
            month = current
            if scrubbing && !ctx.isPreview { Haptics.selection() }
        }
        guard scrubbing else { return }
        let speed: CGFloat = tracker.sample(value.origin.y, limit: 6000) / 4000
        stretch = speed.clamped(to: -1...1)
        // No new offsets for a moment means the thumb is being held still: relax.
        calmToken += 1
        let token = calmToken
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            guard token == calmToken else { return }
            tracker.reset()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { stretch = 0 }
        }
    }

    // MARK: Scrollbar

    private var scrollbar: some View {
        let squash: CGFloat = ctx.cg("squash")
        let speed: CGFloat = abs(stretch) * squash
        return ZStack(alignment: .topTrailing) {
            if ctx.bool("ticks") {
                ScrollDateYearMarks(
                    width: viewport.width,
                    maxOffset: maxOffset,
                    trackTop: trackTop + thumbHeight / 2,
                    travel: travel,
                    visible: scrubbing
                )
            }
            Capsule()
                .fill(scrubbing ? AnyShapeStyle(Palette.primary) : AnyShapeStyle(Color.primary.opacity(0.32)))
                .frame(width: scrubbing ? 8 : 5, height: thumbHeight)
                .padding(.trailing, 5)
                .offset(y: thumbY)
            ScrollDateBubble(text: ScrollDateLibrary.label(month, ctx.language), value: month)
                .scaleEffect(x: 1 + 0.18 * speed, y: 1 - 0.22 * speed, anchor: .trailing)
                .scaleEffect(scrubbing ? 1 : 0.4, anchor: .trailing)
                .opacity(scrubbing ? 1 : 0)
                .padding(.trailing, 22)
                // It trails the motion: up while moving down, down while moving up.
                .offset(y: thumbY + (thumbHeight - 34) / 2 - 10 * stretch * squash)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) {
            // The strip that claims vertical drags from the grid and from the page.
            Color.clear
                .frame(width: 34)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(grab)
                .onChange(of: touching) { _, isTouching in
                    // Also covers a drag the system cancelled.
                    if !isTouching && grabbed {
                        grabbed = false
                        endScrub()
                    }
                }
        }
    }

    /// Claims the touch at once (no minimum distance), so neither the grid nor the page scrolls instead.
    private var grab: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if !grabbed {
                    grabbed = true
                    beginScrub(at: value.startLocation.y)
                }
                scrub(to: grabFraction + value.translation.height / travel)
            }
    }

    // MARK: Scrubbing (finger and autoplay share these)

    private func beginScrub(at y: CGFloat?) {
        if let y {
            // A touch on the track outside the thumb brings the thumb under the finger first.
            let onThumb = y >= thumbY - 8 && y <= thumbY + thumbHeight + 8
            grabFraction = onThumb ? fraction : ((y - trackTop - thumbHeight / 2) / travel).clamped(to: 0...1)
            Haptics.tap(.light)
        }
        tracker.reset()
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.6)) { scrubbing = true }
    }

    private func scrub(to target: CGFloat) {
        let clamped: CGFloat = target.clamped(to: 0...1)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            position.scrollTo(y: clamped * maxOffset)
        }
    }

    private func endScrub() {
        calmToken += 1
        withAnimation(.easeIn(duration: 0.2)) { scrubbing = false }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { stretch = 0 }
    }

    private func autoScrub() {
        down.toggle()
        beginScrub(at: nil)
        withAnimation(.easeInOut(duration: 1.5)) {
            position.scrollTo(y: (down ? 0.72 : 0.06) * maxOffset)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.75))
            endScrub()
        }
    }
}

// MARK: - Pieces

private struct ScrollDateBubble: View {
    let text: String
    let value: Int

    var body: some View {
        Text(verbatim: text)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .contentTransition(.numericText(value: Double(-value)))
            .animation(.snappy(duration: 0.22), value: value)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background {
                ZStack(alignment: .trailing) {
                    // The pointer: a rounded square turned 45°, half hidden behind the capsule.
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: 0x7A45D6))
                        .frame(width: 17, height: 17)
                        .rotationEffect(.degrees(45))
                        .offset(x: 5)
                    Capsule().fill(Palette.primaryStrong)
                }
            }
            .shadow(color: Palette.indigo.opacity(0.4), radius: 10, y: 5)
            .fixedSize()
    }
}

/// Year labels beside the track, at the height where the thumb sits when that year starts.
private struct ScrollDateYearMarks: View {
    let width: CGFloat
    let maxOffset: CGFloat
    let trackTop: CGFloat
    let travel: CGFloat
    let visible: Bool

    var body: some View {
        let starts = ScrollDateLibrary.starts(width: width)
        return ZStack(alignment: .topTrailing) {
            ForEach(0..<ScrollDateLibrary.months, id: \.self) { m in
                if m == 0 || ScrollDateLibrary.year(m) != ScrollDateLibrary.year(m - 1) {
                    HStack(spacing: 4) {
                        Text(verbatim: String(ScrollDateLibrary.year(m)))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Capsule()
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: 8, height: 1.5)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Palette.stage.opacity(0.85), in: Capsule())
                    .padding(.trailing, 16)
                    .offset(y: trackTop + (starts[m] / max(maxOffset, 1)).clamped(to: 0...1) * travel - 9)
                }
            }
        }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
    }
}

private struct ScrollDateMonth: View {
    let month: Int
    let width: CGFloat
    let language: AppLanguage

    var body: some View {
        let tile = ScrollDateLibrary.tile(width: width)
        let count = ScrollDateLibrary.count(month)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: ScrollDateLibrary.label(month, language))
                    .font(.subheadline.weight(.bold))
                Text(verbatim: language == .zh ? "\(count) 张" : "\(count) photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: ScrollDateLibrary.header, alignment: .bottomLeading)
            .padding(.bottom, 0)
            VStack(alignment: .leading, spacing: ScrollDateLibrary.gap) {
                ForEach(0..<ScrollDateLibrary.rows(month), id: \.self) { row in
                    HStack(spacing: ScrollDateLibrary.gap) {
                        ForEach(0..<ScrollDateLibrary.columns, id: \.self) { column in
                            let index = row * ScrollDateLibrary.columns + column
                            if index < count {
                                ScrollDateTile(seed: month * 17 + index * 5)
                                    .frame(width: tile, height: tile)
                            }
                        }
                    }
                }
            }
            .padding(.top, ScrollDateLibrary.gap)
        }
        .frame(height: ScrollDateLibrary.height(month, width: width), alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScrollDateTile: View {
    let seed: Int

    var body: some View {
        let colors = ScrollKit.colors(seed)
        return LinearGradient(colors: colors, startPoint: seed % 2 == 0 ? .topLeading : .top, endPoint: .bottomTrailing)
            .overlay {
                if seed % 3 == 0 {
                    Image(systemName: ScrollKit.symbol(seed))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .blur(radius: 10)
                        .offset(x: CGFloat(seed % 5) * 6 - 12, y: CGFloat(seed % 4) * 6 - 10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
