import SwiftUI

extension Effect {
    static let navigationAppSwitcher = Effect(
        id: "navigation.app-switcher",
        category: .navigation,
        interaction: .gesture,
        name: L("App Switcher Deck", "应用切换卡片组"),
        summary: L(
            "Open apps wait as a tilted, overlapping row of cards: swipe to leaf through them, flick one up to close it, tap one and it grows back into the full screen.",
            "打开的应用排成一行倾斜、相互叠压的卡片：横滑翻看，向上一甩关掉某一张，点一下则放大回全屏。"
        ),
        prompt: L(
            "A multitasking view: each open app is its full screen scaled to 56% with 40 pt corners, turned 12° about the vertical axis, with its icon and name above. Cards are placed from one fractional index: those ahead sit 120 pt apart, those already passed compress to 36% of that and darken, later cards overlapping earlier ones. Swiping scrubs the row 1:1 and settles on a spring (response 0.45 s, damping 0.8) at the card the flick predicts. Dragging a card upward lifts it with the finger while it shrinks and fades; past 70 pt or a fast flick it flies off the top in 0.22 s and the remaining cards slide over to close the gap. Tapping a card centres it, then un-tilts and scales it to 100% while its neighbours slide out sideways; the home bar brings the row back. Light haptics on settle, medium on close.",
            "多任务视图：每个应用都是完整界面缩到 56%、圆角 40 pt，绕竖轴转 12°，上方有图标与名称。卡片位置来自同一个小数索引：未翻到的相隔 120 pt，翻过的压缩到 36% 间距并变暗，后面的压住前面的。横滑 1:1 拖动整排，松手以弹簧（响应 0.45 秒、阻尼 0.8）停在甩动预测的那张上。向上拖动卡片，它跟手抬起并缩小变淡；超过 70 pt 或快速一甩，0.22 秒内飞出顶部，其余卡片滑来补位。点击卡片，它先居中，再回正放大到 100%，邻居向两侧滑出；底部横条带回整排。落定轻触感，关闭中等触感。"
        ),
        implementation: L(
            "Each card is the real full-size screen with scaleEffect, rotation3DEffect and offset derived from its index minus a fractional focus; closing removes it from the array inside a spring so the rest re-flow. Horizontal scrubbing is a page-safe drag on the row, the upward flick a UIKit-bridged pan per card.",
            "每张卡片都是真实的全尺寸界面，其 scaleEffect、rotation3DEffect 与 offset 由「序号减去小数焦点」推导得出；关闭时在弹簧动画里把它从数组中移除，其余卡片自然重新排布。横向拖动是加在整排上的页面安全拖拽，向上甩动则是每张卡片各自桥接 UIKit 的 pan。"
        ),
        apis: ["rotation3DEffect(_:axis:anchor:perspective:)", "UIGestureRecognizerRepresentable", "DragGesture", "zIndex", "spring(response:dampingFraction:)"],
        tags: ["app switcher", "multitasking", "cards", "flick to close", "应用切换", "多任务", "卡片", "上滑关闭"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.45, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("tilt", L("Tilt", "倾斜角度"), 0...28, default: 12, decimals: 0, unit: "°"),
            .slider("spacing", L("Card spacing", "卡片间距"), 80...170, default: 120, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        AppSwitcherDemo(ctx: ctx)
    }
}

private struct SwitcherApp: Identifiable {
    let id: Int
    let symbol: String
    let name: LocalizedText
    let colors: [Color]
}

private let switcherApps: [SwitcherApp] = [
    SwitcherApp(id: 0, symbol: "note.text", name: L("Notes", "记事"), colors: [Palette.amber, Palette.coral]),
    SwitcherApp(id: 1, symbol: "cloud.sun.fill", name: L("Weather", "天气"), colors: [Palette.sky, Palette.blue]),
    SwitcherApp(id: 2, symbol: "music.note", name: L("Music", "音乐"), colors: [Palette.pink, Palette.violet]),
    SwitcherApp(id: 3, symbol: "photo.fill", name: L("Photos", "相册"), colors: [Palette.mint, Palette.sky]),
]

private enum SwitcherMetrics {
    static let frame = CGSize(width: 290, height: 284)
    static let scale: CGFloat = 0.56
    /// Passed cards are packed this much tighter than upcoming ones.
    static let passed: CGFloat = 0.36
}

private struct AppSwitcherDemo: View {
    let ctx: DemoContext
    @State private var cards: [Int] = switcherApps.map(\.id)
    @State private var focus: CGFloat = 1
    @State private var dragStart: CGFloat?
    @State private var lifts: [Int: CGFloat] = [:]
    @State private var flying: Set<Int> = []
    @State private var zoomed: Int?
    @State private var workTask: Task<Void, Never>?
    @State private var autoStep = 0

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var lastIndex: CGFloat { CGFloat(max(cards.count - 1, 0)) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x23264A), Color(hex: 0x0E0F1C)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if cards.isEmpty {
                    Text(L("No recent apps", "没有最近使用的应用"), ctx.language)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .transition(.opacity)
                }
                ForEach(switcherApps) { app in
                    if let index = cards.firstIndex(of: app.id) {
                        card(app, index: index)
                            .zIndex(zoomed == app.id ? 100 : Double(index))
                    }
                }
                homeBar
            }
            .frame(width: SwitcherMetrics.frame.width, height: SwitcherMetrics.frame.height)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
            .shadow(color: Color.black.opacity(0.2), radius: 18, y: 10)
            .contentShape(Rectangle())
            .pageSafeHorizontalDrag(onChanged: dragChanged, onEnded: dragEnded)
            DemoHint(text: L("Swipe sideways, flick a card up, or tap one", "横向滑动，向上甩掉一张，或点开一张"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.3) { autoplayStep() }
        .onDisappear { workTask?.cancel() }
    }

    // MARK: Cards

    private func card(_ app: SwitcherApp, index: Int) -> some View {
        let distance: CGFloat = CGFloat(index) - focus
        let spacing: CGFloat = ctx.cg("spacing")
        let rest: CGFloat = (distance >= 0 ? distance * spacing : distance * spacing * SwitcherMetrics.passed) + 6
        let isZoomed: Bool = zoomed == app.id
        // When another card is zoomed, the rest leave sideways.
        let away: CGFloat = awayOffset(index: index)
        let lift: CGFloat = flying.contains(app.id) ? -340 : (lifts[app.id] ?? 0)
        let lifted: CGFloat = min(max(-lift / 160, 0), 1)
        let scale: CGFloat = isZoomed ? 1 : SwitcherMetrics.scale * (1 - 0.12 * lifted)
        let shade: Double = isZoomed ? 0 : 0.34 * Double(min(max(-distance, 0), 1))
        let radius: CGFloat = isZoomed ? 32 : 40
        return VStack(spacing: 0) {
            SwitcherScreen(app: app, language: ctx.language)
                .frame(width: SwitcherMetrics.frame.width, height: SwitcherMetrics.frame.height)
                .background(Palette.elevated)
                .overlay(Color.black.opacity(shade))
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .shadow(color: Color.black.opacity(isZoomed ? 0 : 0.4), radius: 24, x: -10, y: 14)
        }
        // Hit-testing is attached before the transforms, so each card is touched where it is drawn.
        .contentShape(Rectangle())
        .onTapGesture { tapped(app.id, index: index) }
        .gesture(
            PageSafePan(
                directions: [.up],
                isEnabled: zoomed == nil,
                onChanged: { liftChanged(app.id, $0.height) },
                onEnded: { liftEnded(app.id, $0) }
            )
        )
        .overlay(alignment: .top) {
            label(app)
                .scaleEffect(1 / SwitcherMetrics.scale, anchor: .bottom)
                .offset(y: -40)
                .opacity(isZoomed ? 0 : labelOpacity(distance) * Double(1 - lifted))
        }
        .scaleEffect(scale)
        .rotation3DEffect(.degrees(isZoomed ? 0 : -ctx["tilt"]), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.5)
        .opacity(Double(1 - 0.5 * lifted))
        .offset(x: isZoomed ? 0 : rest + away, y: isZoomed ? 0 : 18 + lift)
    }

    /// Labels of cards already passed fade out quickly (those cards overlap); upcoming ones only dim.
    private func labelOpacity(_ distance: CGFloat) -> Double {
        if distance < 0 { return Double(max(0, 1 + distance * 2.5)) }
        return Double(1 - min(distance, 1) * 0.4)
    }

    private func awayOffset(index: Int) -> CGFloat {
        guard let id = zoomed, let zoomIndex = cards.firstIndex(of: id), zoomIndex != index else { return 0 }
        return index < zoomIndex ? -260 : 260
    }

    private func label(_ app: SwitcherApp) -> some View {
        HStack(spacing: 6) {
            Image(systemName: app.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 20, height: 20)
                .background(
                    LinearGradient(colors: app.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            Text(app.name, ctx.language)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .fixedSize()
    }

    /// Home indicator shown while an app is open; tapping it returns to the switcher.
    private var homeBar: some View {
        Capsule()
            .fill(Color.primary.opacity(0.45))
            .frame(width: 96, height: 5)
            .padding(.vertical, 12)
            .padding(.horizontal, 60)
            .contentShape(Rectangle())
            .onTapGesture { unzoom() }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .opacity(zoomed == nil ? 0 : 1)
            .allowsHitTesting(zoomed != nil)
            .zIndex(200)
    }

    // MARK: Scrubbing

    private func dragChanged(_ value: DragGesture.Value) {
        guard zoomed == nil, !cards.isEmpty else { return }
        let start: CGFloat = dragStart ?? focus
        if dragStart == nil { dragStart = focus }
        var position: CGFloat = start - value.translation.width / ctx.cg("spacing")
        if position < 0 { position = -rubberBand(-position, limit: 0.5) }
        if position > lastIndex { position = lastIndex + rubberBand(position - lastIndex, limit: 0.5) }
        focus = position
    }

    private func dragEnded(_ value: DragGesture.Value?) {
        guard let start = dragStart else { return }
        dragStart = nil
        let projected: CGFloat = value.map { start - $0.predictedEndTranslation.width / ctx.cg("spacing") } ?? focus
        settle(to: Int(projected.rounded()))
    }

    private func settle(to index: Int) {
        let clamped: Int = min(max(index, 0), max(cards.count - 1, 0))
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(spring) { focus = CGFloat(clamped) }
    }

    // MARK: Flick to close

    private func liftChanged(_ id: Int, _ translation: CGFloat) {
        lifts[id] = translation < 0 ? translation : rubberBand(translation, limit: 20)
    }

    private func liftEnded(_ id: Int, _ end: PageSafePanEnd?) {
        let travel: CGFloat = end?.translation.height ?? 0
        let velocity: CGFloat = end?.velocity.height ?? 0
        if end != nil, travel < -70 || velocity < -600 {
            close(id)
        } else {
            withAnimation(spring) { lifts[id] = 0 }
        }
    }

    private func close(_ id: Int) {
        guard cards.contains(id), !flying.contains(id) else { return }
        if !ctx.isPreview { Haptics.tap(.medium) }
        withAnimation(.easeIn(duration: 0.22)) { _ = flying.insert(id) }
        let animation: Animation = spring
        workTask?.cancel()
        workTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            withAnimation(animation) {
                cards.removeAll { $0 == id }
                focus = min(max(focus.rounded(), 0), CGFloat(max(cards.count - 1, 0)))
            }
            flying.remove(id)
            lifts[id] = nil
            guard cards.isEmpty else { return }
            // Nothing left: deal the deck again after a beat.
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    private func reset() {
        withAnimation(spring) {
            cards = switcherApps.map(\.id)
            focus = 1
        }
    }

    // MARK: Zoom

    private func tapped(_ id: Int, index: Int) {
        if zoomed == id {
            return
        }
        guard zoomed == nil else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(spring) {
            focus = CGFloat(index)
            zoomed = id
        }
    }

    private func unzoom() {
        guard zoomed != nil else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(spring) { zoomed = nil }
    }

    // MARK: Autoplay

    private func autoplayStep() {
        let phase: Int = autoStep % 6
        autoStep += 1
        if cards.count <= 1 {
            reset()
            return
        }
        let current: Int = Int(focus.rounded())
        switch phase {
        case 0: settle(to: current + 1)
        case 1: settle(to: current + 1)
        case 2: close(cards[min(current, cards.count - 1)])
        case 3: tapped(cards[min(current, cards.count - 1)], index: min(current, cards.count - 1))
        case 4: unzoom()
        default: settle(to: max(current - 1, 0))
        }
    }
}

// MARK: - One app's screen

private struct SwitcherScreen: View {
    let app: SwitcherApp
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: app.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(colors: app.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                Text(app.name, language)
                    .font(.title2.weight(.bold))
                Spacer(minLength: 0)
            }
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: app.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 100)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: app.symbol)
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(14)
                }
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(app.colors[row % app.colors.count].opacity(0.3))
                        .frame(width: 36, height: 36)
                    PlaceholderLines(count: 2, color: Color.primary.opacity(0.1))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}
