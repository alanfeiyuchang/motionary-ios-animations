import SwiftUI

extension Effect {
    static let navigationPageControlScrub = Effect(
        id: "navigation.page-control-scrub",
        category: .navigation,
        interaction: .gesture,
        name: L("Scrubbable Page Control", "可拖擦页码控件"),
        summary: L(
            "Touch the dots and a platter rises under them: slide along it to flick through every page, the indicator stretching behind your finger.",
            "按住页码圆点，底下浮起一块托盘：沿着它滑动即可快速翻过所有页面，指示条在手指身后被拉长。"
        ),
        prompt: L(
            "A carousel of six weather cards (210 × 200 pt, neighbours peeking at 88% scale) above a row of 8 pt page dots, 20 pt apart. Dragging across the dots turns them into a scrubber, as in the iOS page control: a frosted capsule platter fades in beneath over 0.25 s, the dots swell to 125%, and the pages follow the finger continuously, one page per dot. The active indicator is a solid capsule whose head tracks the finger on a 0.18 s interactive spring while its tail trails on a slower one, so it stretches with speed and contracts when the finger rests; a selection tick fires on each page crossed. On release everything springs to the nearest page (response 0.4 s, damping 0.8) and the platter melts away 0.7 s later. A tap left or right of the indicator steps one page; the cards can be swiped too.",
            "六张天气卡片的轮播（210 × 200 pt，相邻卡片缩到 88%），下方是一排间隔 20 pt 的 8 pt 页码圆点。在圆点上横向拖动，它们就变成 iOS 页码控件那样的拖擦条：磨砂托盘在 0.25 秒内浮现，圆点胀到 125%，页面连续跟随手指，每个圆点对应一页。当前指示是一枚实心胶囊，头部以 0.18 秒的交互弹簧紧跟手指，尾部用更慢的弹簧拖在后面，随速度拉长、停下时收拢；每跨一页触发一次选择触感。松手弹回最近一页（响应 0.4 秒、阻尼 0.8），托盘 0.7 秒后消融。"
        ),
        implementation: L(
            "A fractional page and a lagging copy of it are the only state. Animatable layers interpolate them, so cards, scale and the indicator's two ends stay exact mid-flight; the control maps the finger's x to a page with a horizontal-intent drag.",
            "状态只有一个小数页码和它的滞后副本。Animatable 图层对二者插值，卡片、缩放与指示条的两端在动画途中都保持精确；控件用横向意图拖拽把手指的 x 坐标换算为页码。"
        ),
        apis: ["Animatable", "DragGesture", "interactiveSpring", "onTapGesture(coordinateSpace:)", "Material", "spring(response:dampingFraction:)"],
        tags: ["page control", "scrub", "dots", "carousel", "页码控件", "拖擦", "圆点", "轮播"],
        params: [
            .slider("response", L("Settle response", "落定响应"), 0.2...0.8, default: 0.4, unit: "s"),
            .slider("stretch", L("Indicator stretch", "指示条拉伸"), 0...1.5, default: 0.6),
            .slider("side", L("Neighbour scale", "相邻卡片缩放"), 0.7...1.0, default: 0.88),
            .toggle("platter", L("Platter while scrubbing", "拖擦时显示托盘"), default: true),
        ]
    ) { ctx in
        PageControlScrubDemo(ctx: ctx)
    }
}

private struct ScrubCity {
    let name: LocalizedText
    let condition: LocalizedText
    let temperature: Int
    let symbol: String
    let colors: [Color]
}

private let scrubCities: [ScrubCity] = [
    ScrubCity(name: L("Seattle", "西雅图"), condition: L("Light rain", "小雨"), temperature: 14, symbol: "cloud.rain.fill", colors: [Color(hex: 0x4A6FA5), Color(hex: 0x23395B)]),
    ScrubCity(name: L("Lisbon", "里斯本"), condition: L("Sunny", "晴"), temperature: 27, symbol: "sun.max.fill", colors: [Color(hex: 0x3AA0FF), Color(hex: 0x6FD3FF)]),
    ScrubCity(name: L("Kyoto", "京都"), condition: L("Partly cloudy", "多云"), temperature: 21, symbol: "cloud.sun.fill", colors: [Color(hex: 0x5B8CFF), Color(hex: 0xA9C6FF)]),
    ScrubCity(name: L("Reykjavik", "雷克雅未克"), condition: L("Snow", "雪"), temperature: -3, symbol: "snowflake", colors: [Color(hex: 0x7C8BA8), Color(hex: 0xB9C4D6)]),
    ScrubCity(name: L("Marrakesh", "马拉喀什"), condition: L("Hot", "炎热"), temperature: 36, symbol: "sun.haze.fill", colors: [Color(hex: 0xFF8A3D), Color(hex: 0xFFC247)]),
    ScrubCity(name: L("Auckland", "奥克兰"), condition: L("Clear night", "晴夜"), temperature: 12, symbol: "moon.stars.fill", colors: [Color(hex: 0x241B5C), Color(hex: 0x5B4FC9)]),
]

private enum ScrubMetrics {
    static let spacing: CGFloat = 20
    static let dot: CGFloat = 8
    static let inset: CGFloat = 10
    static let cardStep: CGFloat = 218
    static var controlWidth: CGFloat { spacing * CGFloat(scrubCities.count) + inset * 2 }
    static func centre(_ page: CGFloat) -> CGFloat { inset + spacing * (page + 0.5) }
}

private struct PageControlScrubDemo: View {
    let ctx: DemoContext
    @State private var progress: CGFloat = 0
    @State private var tail: CGFloat = 0
    @State private var scrubbing = false
    @State private var platterShown = false
    @State private var platterToken = 0
    @State private var lastPage = 0
    @State private var swipeStart: CGFloat?
    @State private var autoForward = true

    private var lastIndex: CGFloat { CGFloat(scrubCities.count - 1) }

    var body: some View {
        VStack(spacing: 14) {
            ScrubCardsLayer(progress: progress, sideScale: ctx.cg("side"), language: ctx.language)
                .frame(height: 216)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .pageSafeHorizontalDrag(onChanged: swipeChanged, onEnded: swipeEnded)
            control
            DemoHint(text: L("Slide along the dots, or swipe the cards", "沿圆点滑动，或左右滑动卡片"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .autoplay(ctx.isPreview, every: 2.7) { simulateScrub() }
    }

    // MARK: Control

    private var control: some View {
        let enlarged: Bool = scrubbing || platterShown
        return ZStack {
            DemoMaterial(Capsule(), material: .regularMaterial)
                .overlay(Capsule().strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
                .frame(height: 32)
                .opacity(platterShown && ctx.bool("platter") ? 1 : 0)
                .scaleEffect(platterShown ? 1 : 0.9)
            HStack(spacing: ScrubMetrics.spacing - ScrubMetrics.dot) {
                ForEach(0..<scrubCities.count, id: \.self) { _ in
                    Circle()
                        .fill(Color.primary.opacity(0.22))
                        .frame(width: ScrubMetrics.dot, height: ScrubMetrics.dot)
                        .scaleEffect(enlarged ? 1.25 : 1)
                }
            }
            ScrubIndicatorHead(progress: progress, tail: tail, enlarged: enlarged)
        }
        .frame(width: ScrubMetrics.controlWidth, height: 44)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            step(location.x < ScrubMetrics.centre(progress) ? -1 : 1)
        }
        .pageSafeHorizontalDrag(minimumDistance: 2, onChanged: scrubChanged, onEnded: scrubEnded)
    }

    // MARK: Scrub

    private func beginScrub() {
        scrubbing = true
        platterToken += 1
        withAnimation(.easeOut(duration: 0.25)) { platterShown = true }
    }

    private func scrubChanged(_ value: DragGesture.Value) {
        if !scrubbing {
            beginScrub()
            if !ctx.isPreview { Haptics.tap(.light) }
        }
        let raw: CGFloat = (value.location.x - ScrubMetrics.inset) / ScrubMetrics.spacing - 0.5
        let page: CGFloat = min(max(raw, 0), lastIndex)
        let stretch: Double = ctx["stretch"]
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.86)) { progress = page }
        withAnimation(.interactiveSpring(response: 0.18 + 0.4 * stretch, dampingFraction: 0.9)) { tail = page }
        tick(Int(page.rounded()))
    }

    private func scrubEnded(_ value: DragGesture.Value?) {
        guard scrubbing else { return }
        settle(to: Int(progress.rounded()))
    }

    private func tick(_ page: Int) {
        guard page != lastPage else { return }
        lastPage = page
        if !ctx.isPreview { Haptics.selection() }
    }

    /// Springs to a page: the head first, the tail on a softer spring, then the platter melts away.
    private func settle(to page: Int) {
        let clamped: Int = min(max(page, 0), scrubCities.count - 1)
        let response: Double = ctx["response"]
        let stretch: Double = ctx["stretch"]
        scrubbing = false
        lastPage = clamped
        withAnimation(.spring(response: response, dampingFraction: 0.8)) { progress = CGFloat(clamped) }
        withAnimation(.spring(response: response * (1 + 0.6 * stretch), dampingFraction: 0.86)) { tail = CGFloat(clamped) }
        platterToken += 1
        let token = platterToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            guard token == platterToken, !scrubbing else { return }
            withAnimation(.easeInOut(duration: 0.35)) { platterShown = false }
        }
    }

    private func step(_ delta: Int) {
        let target: Int = Int(progress.rounded()) + delta
        guard target >= 0, target < scrubCities.count else { return }
        if !ctx.isPreview { Haptics.selection() }
        settle(to: target)
    }

    // MARK: Card swipe

    private func swipeChanged(_ value: DragGesture.Value) {
        let start: CGFloat = swipeStart ?? progress
        if swipeStart == nil { swipeStart = progress }
        var page: CGFloat = start - value.translation.width / ScrubMetrics.cardStep
        if page < 0 { page = -rubberBand(-page, limit: 0.6) }
        if page > lastIndex { page = lastIndex + rubberBand(page - lastIndex, limit: 0.6) }
        progress = page
        tail = page
    }

    private func swipeEnded(_ value: DragGesture.Value?) {
        guard let start = swipeStart else { return }
        swipeStart = nil
        let projected: CGFloat = value.map { start - $0.predictedEndTranslation.width / ScrubMetrics.cardStep } ?? progress
        let limited: CGFloat = min(max(projected, start.rounded() - 1), start.rounded() + 1)
        let target: Int = Int(limited.rounded())
        if !ctx.isPreview && target != Int(start.rounded()) { Haptics.selection() }
        settle(to: target)
    }

    // MARK: Autoplay

    /// Preview: a simulated scrub from one end of the dots to the other, released at the far page.
    private func simulateScrub() {
        let target: Int = autoForward ? scrubCities.count - 1 : 0
        autoForward.toggle()
        beginScrub()
        let lag: Double = 0.06 + 0.12 * ctx["stretch"]
        withAnimation(.easeInOut(duration: 1.3)) { progress = CGFloat(target) }
        withAnimation(.easeInOut(duration: 1.3).delay(lag)) { tail = CGFloat(target) }
        let token = platterToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.45))
            guard token == platterToken else { return }
            settle(to: target)
        }
    }
}

// MARK: - Layers

/// Interpolates the fractional page, so every card's offset, scale and parallax are exact mid-animation.
private struct ScrubCardsLayer: View, Animatable {
    var progress: CGFloat
    let sideScale: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            ForEach(0..<scrubCities.count, id: \.self) { index in
                let distance: CGFloat = CGFloat(index) - progress
                let near: CGFloat = min(abs(distance), 1)
                ScrubCard(city: scrubCities[index], language: language, parallax: distance)
                    .scaleEffect(1 - (1 - sideScale) * near)
                    .opacity(Double(1 - 0.4 * near))
                    .offset(x: distance * ScrubMetrics.cardStep)
                    .zIndex(Double(1 - near))
            }
        }
    }
}

private struct ScrubCard: View {
    let city: ScrubCity
    let language: AppLanguage
    let parallax: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: city.colors, startPoint: .top, endPoint: .bottom))
            Image(systemName: city.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 62))
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(18)
                .offset(x: parallax * -34)
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name, language)
                    .font(.headline)
                Text("\(city.temperature)°")
                    .font(.system(size: 54, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text(city.condition, language)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.85)
            }
            .foregroundStyle(Color.white)
            .padding(18)
        }
        .frame(width: 210, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: city.colors[0].opacity(0.35), radius: 14, y: 8)
    }
}

/// Interpolates the indicator's head (the page under the finger).
private struct ScrubIndicatorHead: View, Animatable {
    var progress: CGFloat
    let tail: CGFloat
    let enlarged: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ScrubIndicatorTail(progress: progress, tail: tail, enlarged: enlarged)
    }
}

/// Interpolates the lagging tail and draws the capsule between the two.
private struct ScrubIndicatorTail: View, Animatable {
    let progress: CGFloat
    var tail: CGFloat
    let enlarged: Bool

    var animatableData: CGFloat {
        get { tail }
        set { tail = newValue }
    }

    var body: some View {
        let last: CGFloat = CGFloat(scrubCities.count - 1)
        let head: CGFloat = min(max(progress, 0), last)
        let back: CGFloat = min(max(tail, 0), last)
        let low: CGFloat = ScrubMetrics.centre(min(head, back))
        let high: CGFloat = ScrubMetrics.centre(max(head, back))
        let size: CGFloat = ScrubMetrics.dot * (enlarged ? 1.25 : 1)
        Capsule()
            .fill(Color.primary)
            .frame(width: high - low + size, height: size)
            .position(x: (low + high) / 2, y: 22)
            .frame(width: ScrubMetrics.controlWidth, height: 44)
            .allowsHitTesting(false)
    }
}
