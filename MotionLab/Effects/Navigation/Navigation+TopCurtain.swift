import SwiftUI

extension Effect {
    static let navigationTopCurtain = Effect(
        id: "navigation.top-curtain",
        category: .navigation,
        interaction: .gesture,
        name: L("Top Curtain Sheet", "顶部幕帘面板"),
        summary: L(
            "A panel hangs above the screen by its handle: pull it and it drops like a weighted curtain, bouncing at the bottom while its rows swing down after it.",
            "一块面板靠拉手挂在屏幕上方：一拉，它像带配重的幕帘一样落下，在底部弹一下，里面的各行跟着荡下来。"
        ),
        prompt: L(
            "Only a 26 pt lip of a panel shows at the top of the screen, carrying a pull handle. Dragging the lip down pulls the panel out 1:1, rubber-banding once it passes its 196 pt height; releasing past half-way, flicking, or tapping the handle drops it on an underdamped spring (response 0.5 s, damping 0.62), so it overshoots about 14 pt and bounces once like a weighted blind. Inside, the rows are offset upward by 10 pt plus 8 pt per row times the closed fraction, so they unfurl as the panel falls and overshoot more the lower they hang. The page behind recedes to 94%, dims 30% and blurs 3 pt in step with the travel. The handle bends from a flat bar into a chevron pointing up once open. A soft haptic lands with the panel; closing reverses everything.",
            "屏幕顶部只露出面板 26 pt 的下沿，上面有一个拉手。向下拖动，面板 1:1 跟手拉出，超过 196 pt 的高度后进入橡皮筋；过半松手、轻甩或点击拉手，面板以欠阻尼弹簧（响应 0.5 秒、阻尼 0.62）落下，过冲约 14 pt 再弹回一次，像带配重的卷帘。面板内各行按「10 pt 加每行 8 pt」乘以未展开比例向上偏移，随面板下落逐行舒展，越靠下过冲越大。背后的页面同步后退到 94%、压暗 30%、模糊 3 pt。打开后，拉手从平条弯成向上的箭头。落定时有一次柔和触感；收起时一切反向。"
        ),
        implementation: L(
            "One value, the pulled-out distance, drives the panel offset, each row's lag, the page's scale, dim and blur and the handle's bend. A UIKit-bridged vertical pan writes it directly with rubberBand() past the end; release animates it with a spring whose overshoot is left unclamped for the rows.",
            "只有「拉出的距离」这一个数值，驱动面板偏移、各行的滞后、页面的缩放与压暗模糊，以及拉手的弯折。一个桥接 UIKit 的纵向 pan 直接写入它，越界部分用 rubberBand() 处理；松手后以弹簧动画落定，各行使用未截断的过冲值。"
        ),
        apis: ["UIGestureRecognizerRepresentable", "UnevenRoundedRectangle", "spring(response:dampingFraction:)", "blur(radius:)", "rotationEffect"],
        tags: ["top sheet", "curtain", "pull down", "control panel", "顶部面板", "幕帘", "下拉", "控制面板"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.35...1.0, default: 0.62),
            .slider("depth", L("Page recede", "页面后退"), 0...0.14, default: 0.06),
            .slider("dim", L("Dim", "压暗"), 0...0.6, default: 0.3),
        ]
    ) { ctx in
        TopCurtainDemo(ctx: ctx)
    }
}

private struct CurtainToggle {
    let symbol: String
    let label: LocalizedText
    let color: Color
}

private let curtainToggles: [CurtainToggle] = [
    CurtainToggle(symbol: "wifi", label: L("Wi-Fi", "无线网络"), color: Palette.blue),
    CurtainToggle(symbol: "moon.fill", label: L("Focus", "专注"), color: Palette.violet),
    CurtainToggle(symbol: "airplane", label: L("Flight", "飞行"), color: Palette.coral),
    CurtainToggle(symbol: "flashlight.on.fill", label: L("Torch", "手电"), color: Palette.amber),
]

private enum CurtainMetrics {
    static let frame = CGSize(width: 290, height: 284)
    static let height: CGFloat = 196
    static let lip: CGFloat = 26
    static var travel: CGFloat { height - lip }
}

private struct TopCurtainDemo: View {
    let ctx: DemoContext
    /// How far the panel is pulled out: 0 (only the lip shows) … travel (fully open).
    @State private var pulled: CGFloat
    @State private var isOpen: Bool
    @State private var dragBase: CGFloat?
    @State private var toggles: [Bool] = [true, false, false, true]
    @State private var level: CGFloat = 0.6

    init(ctx: DemoContext) {
        self.ctx = ctx
        _pulled = State(initialValue: ctx.isStill ? CurtainMetrics.travel : 0)
        _isOpen = State(initialValue: ctx.isStill)
    }

    private var fraction: CGFloat { pulled / CurtainMetrics.travel }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                page
                panel
            }
            .frame(width: CurtainMetrics.frame.width, height: CurtainMetrics.frame.height)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
            DemoHint(text: L("Pull the handle down, or tap it", "向下拉动拉手，或点击它"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7) { settle(open: !isOpen) }
    }

    // MARK: Page

    private var page: some View {
        let t: CGFloat = min(max(fraction, 0), 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Today", "今天"), ctx.language)
                .font(.title2.weight(.bold))
                .padding(.top, 34)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.aurora)
                .frame(height: 96)
                .overlay(alignment: .bottomLeading) {
                    Text(L("3 tasks left", "还剩 3 项任务"), ctx.language)
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .padding(14)
                }
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 34, height: 34)
                    PlaceholderLines(count: 2, color: Color.primary.opacity(0.1))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(width: CurtainMetrics.frame.width, height: CurtainMetrics.frame.height)
        .background(Palette.surface)
        .overlay(Color.black.opacity(ctx["dim"] * Double(t)))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .blur(radius: 3 * t)
        .scaleEffect(1 - ctx.cg("depth") * t, anchor: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            if isOpen { settle(open: false) }
        }
    }

    // MARK: Panel

    private var panel: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
        return VStack(spacing: 0) {
            // Extra fill above the content, so an overshooting panel never shows a gap at the top.
            Color.clear.frame(height: 80)
            VStack(spacing: 10) {
                row(0) { toggleGrid }
                row(1) { brightness }
                row(2) { shortcuts }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .frame(height: CurtainMetrics.height - CurtainMetrics.lip, alignment: .top)
            handle
                .frame(height: CurtainMetrics.lip)
        }
        .frame(width: CurtainMetrics.frame.width)
        .background(Palette.elevated, in: shape)
        .overlay(shape.strokeBorder(Palette.stroke))
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.22), radius: 16, y: 8)
        .contentShape(Rectangle())
        .gesture(
            PageSafePan(
                directions: [.down, .up],
                onChanged: { dragChanged($0.height) },
                onEnded: { dragEnded($0) }
            )
        )
        .offset(y: -80 - CurtainMetrics.travel + pulled)
    }

    /// Rows hang inside the panel: the less it is open, the higher they are tucked, lower rows more so.
    private func row<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        let tuck: CGFloat = (1 - fraction) * (10 + 8 * CGFloat(index + 1))
        return content()
            .offset(y: -tuck)
    }

    private var toggleGrid: some View {
        HStack(spacing: 8) {
            ForEach(0..<curtainToggles.count, id: \.self) { index in
                let item: CurtainToggle = curtainToggles[index]
                let on: Bool = toggles[index]
                VStack(spacing: 6) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(on ? Color.white : Color.primary.opacity(0.7))
                        .symbolEffect(.bounce, value: on)
                        .frame(width: 46, height: 46)
                        .background(on ? AnyShapeStyle(item.color.gradient) : AnyShapeStyle(Color.primary.opacity(0.08)), in: Circle())
                    Text(item.label, ctx.language)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !ctx.isPreview { Haptics.tap(.light) }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toggles[index].toggle() }
                }
            }
        }
    }

    private var brightness: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.min.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Palette.amber.gradient)
                        .frame(width: max(proxy.size.height, proxy.size.width * level))
                }
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    if !ctx.isPreview { Haptics.tap(.light) }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        level = min(max(location.x / proxy.size.width, 0.1), 1)
                    }
                }
            }
            .frame(height: 22)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    private var shortcuts: some View {
        HStack(spacing: 8) {
            shortcut("timer", L("Timer", "计时器"))
            shortcut("qrcode.viewfinder", L("Scan", "扫码"))
        }
    }

    private func shortcut(_ symbol: String, _ label: LocalizedText) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
            Text(label, ctx.language)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(Color.primary.opacity(0.8))
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    /// A bar that bends into an upward chevron once the panel is open.
    private var handle: some View {
        let bend: Double = isOpen ? 16 : 0
        return HStack(spacing: -1) {
            Capsule()
                .frame(width: 19, height: 5)
                .rotationEffect(.degrees(-bend), anchor: .trailing)
            Capsule()
                .frame(width: 19, height: 5)
                .rotationEffect(.degrees(bend), anchor: .leading)
        }
        .foregroundStyle(Color.primary.opacity(0.28))
        .offset(y: isOpen ? 2 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { settle(open: !isOpen) }
    }

    // MARK: Actions

    private func dragChanged(_ translation: CGFloat) {
        let base: CGFloat = dragBase ?? pulled
        if dragBase == nil { dragBase = pulled }
        var value: CGFloat = base + translation
        let travel: CGFloat = CurtainMetrics.travel
        if value > travel { value = travel + rubberBand(value - travel, limit: 60) }
        if value < 0 { value = -rubberBand(-value, limit: 14) }
        pulled = value
    }

    private func dragEnded(_ end: PageSafePanEnd?) {
        guard dragBase != nil else { return }
        dragBase = nil
        let projected: CGFloat = pulled + (end?.velocity.height ?? 0) * 0.2
        settle(open: projected > CurtainMetrics.travel / 2)
    }

    private func settle(open: Bool) {
        if !ctx.isPreview { Haptics.tap(open ? .soft : .light) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: open ? ctx["damping"] : max(ctx["damping"], 0.85))) {
            pulled = open ? CurtainMetrics.travel : 0
            isOpen = open
        }
    }
}
