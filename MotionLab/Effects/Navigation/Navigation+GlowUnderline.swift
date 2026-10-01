import SwiftUI

extension Effect {
    static let navigationGlowUnderline = Effect(
        id: "navigation.glow-underline",
        category: .navigation,
        interaction: .tap,
        name: L("Light-Source Underline", "发光下划线"),
        summary: L(
            "The underline is a lamp: it slides along the bar's bottom edge and throws a cone of light up through whichever label it passes.",
            "下划线就是一盏灯：它沿标签栏底边滑动，把一束光向上打穿它经过的每个标签。"
        ),
        prompt: L(
            "A dark screen with four icon-and-label tabs along the bottom. The indicator is a 30 × 3 pt bar on the bottom edge that behaves as a light source: above it a blurred cone rises 96 pt, widening by 22 pt per side and fading to nothing, added to the scene with a plus-lighter blend, plus a faint ambient wash on the screen. Labels are lit by distance, not by state: each one's brightness, coloured glow and 2 pt lift follow a Gaussian falloff from the lamp, so tabs it passes flare briefly. On tap the beam dims to 35% in 0.1 s, the lamp slides on a spring (response 0.45 s, damping 0.8) while its hue blends between the two tabs' colours, then re-ignites with an underdamped spring (0.3 s, damping 0.45) that makes the cone overshoot in height. Dragging along the bar moves the lamp directly.",
            "深色屏幕底部有四个带图标的标签。指示器是底边上一根 30 × 3 pt 的短条，它就是光源：上方升起 96 pt 高的模糊光锥，每侧展宽 22 pt 并渐隐，以加亮混合叠到画面上，外加一层环境光。标签亮度由距离而非选中状态决定：亮度、彩色辉光与 2 pt 上抬都按到灯的高斯衰减计算，灯经过的标签短暂亮起。点击后光束在 0.1 秒内暗到 35%，灯以弹簧（响应 0.45 秒、阻尼 0.8）滑动，色相在两个标签的颜色间混合；到位后以欠阻尼弹簧（0.3 秒、阻尼 0.45）重新点亮，光锥略微过冲。也可沿标签栏直接拖动灯。"
        ),
        implementation: L(
            "Two Animatable views read one fractional tab index: the beam (cone, ambient wash and bar, colour from Color.mix) and the labels (Gaussian brightness). The beam's power is a separate opacity/scale value animated in its own transactions, so dimming and re-ignition never retarget the slide.",
            "两个 Animatable 视图读取同一个小数标签索引：光束（光锥、环境光与短条，颜色来自 Color.mix）和标签（高斯亮度）。光束的强度是独立的透明度与缩放数值，在各自的事务里动画，因此变暗与重新点亮不会打断滑动。"
        ),
        apis: ["Animatable", "Color.mix(with:by:)", "blendMode(.plusLighter)", "blur(radius:)", "spring(response:dampingFraction:)"],
        tags: ["underline", "glow", "light", "tab indicator", "下划线", "发光", "光源", "标签指示器"],
        params: [
            .slider("response", L("Slide response", "滑动响应"), 0.25...0.9, default: 0.45, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("height", L("Beam height", "光束高度"), 40...150, default: 96, decimals: 0, unit: "pt"),
            .slider("spread", L("Beam spread", "光束展宽"), 0...44, default: 22, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        GlowUnderlineDemo(ctx: ctx)
    }
}

private struct GlowTab {
    let symbol: String
    let label: LocalizedText
    let headline: LocalizedText
    let color: Color
}

private let glowTabs: [GlowTab] = [
    GlowTab(symbol: "bolt.fill", label: L("Feed", "动态"), headline: L("12 new posts", "12 条新动态"), color: Palette.sky),
    GlowTab(symbol: "safari.fill", label: L("Explore", "探索"), headline: L("Trending nearby", "附近热门"), color: Palette.violet),
    GlowTab(symbol: "bookmark.fill", label: L("Saved", "收藏"), headline: L("48 saved items", "48 项收藏"), color: Palette.amber),
    GlowTab(symbol: "person.fill", label: L("Me", "我的"), headline: L("Profile 80% complete", "资料已完成 80%"), color: Palette.pink),
]

private enum GlowMetrics {
    static let frame = CGSize(width: 300, height: 252)
    static let cell: CGFloat = frame.width / 4
    static let barWidth: CGFloat = 30
    static let barHeight: CGFloat = 3
    static let rowHeight: CGFloat = 64

    static func color(at x: CGFloat) -> Color {
        let clamped: CGFloat = min(max(x, 0), CGFloat(glowTabs.count - 1))
        let lower: Int = Int(clamped.rounded(.down))
        let upper: Int = min(lower + 1, glowTabs.count - 1)
        return glowTabs[lower].color.mix(with: glowTabs[upper].color, by: Double(clamped - CGFloat(lower)))
    }

    static func centre(_ x: CGFloat) -> CGFloat { (x + 0.5) * cell }
}

private struct GlowUnderlineDemo: View {
    let ctx: DemoContext
    @State private var x: CGFloat = 0
    @State private var selection = 0
    @State private var power: CGFloat = 1
    @State private var igniteTask: Task<Void, Never>?
    @State private var dragging = false

    var body: some View {
        VStack(spacing: 14) {
            screen
            DemoHint(text: L("Tap a tab, or drag along the bar", "点击标签，或沿标签栏拖动"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { select((selection + 1) % glowTabs.count) }
        .onDisappear { igniteTask?.cancel() }
    }

    private var screen: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: 0x15161D), Color(hex: 0x0A0B0F)], startPoint: .top, endPoint: .bottom)
            headline
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 34)
            GlowBeam(x: x, height: ctx.cg("height"), spread: ctx.cg("spread"))
                .scaleEffect(x: 1, y: 0.55 + 0.45 * power, anchor: .bottom)
                .opacity(Double(min(max(power, 0), 1)))
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            GlowLabels(x: x, language: ctx.language)
            GlowBar(x: x)
                .opacity(0.55 + 0.45 * Double(min(power, 1)))
                .allowsHitTesting(false)
            tapTargets
        }
        .frame(width: GlowMetrics.frame.width, height: GlowMetrics.frame.height)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
        .shadow(color: Color.black.opacity(0.28), radius: 20, y: 12)
    }

    private var headline: some View {
        let tab: GlowTab = glowTabs[selection]
        return VStack(spacing: 10) {
            Image(systemName: tab.symbol)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Color.white, tab.color], startPoint: .top, endPoint: .bottom))
                .shadow(color: tab.color.opacity(0.6), radius: 16)
                .frame(height: 52)
            Text(tab.headline, ctx.language)
                .font(.headline)
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .id(selection)
        .transition(.blurReplace)
    }

    private var tapTargets: some View {
        HStack(spacing: 0) {
            ForEach(0..<glowTabs.count, id: \.self) { index in
                Color.clear
                    .frame(width: GlowMetrics.cell, height: GlowMetrics.rowHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { select(index) }
            }
        }
        .pageSafeHorizontalDrag(onChanged: dragChanged, onEnded: dragEnded)
    }

    // MARK: Actions

    private func select(_ index: Int) {
        guard index != selection || x != CGFloat(index) else { return }
        igniteTask?.cancel()
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.easeOut(duration: 0.1)) { power = 0.35 }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            x = CGFloat(index)
            selection = index
        }
        let wait: Double = ctx["response"] * 0.6
        let silent: Bool = ctx.isPreview
        igniteTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { power = 1 }
            if !silent { Haptics.tap(.soft) }
        }
    }

    private func dragChanged(_ value: DragGesture.Value) {
        igniteTask?.cancel()
        if !dragging {
            dragging = true
            withAnimation(.easeOut(duration: 0.12)) { power = 0.8 }
        }
        let position: CGFloat = value.location.x / GlowMetrics.cell - 0.5
        let clamped: CGFloat = min(max(position, -0.2), CGFloat(glowTabs.count - 1) + 0.2)
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.86)) { x = clamped }
        let nearest: Int = min(max(Int(clamped.rounded()), 0), glowTabs.count - 1)
        if nearest != selection {
            if !ctx.isPreview { Haptics.selection() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = nearest }
        }
    }

    private func dragEnded(_ value: DragGesture.Value?) {
        dragging = false
        let nearest: Int = min(max(Int(x.rounded()), 0), glowTabs.count - 1)
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            x = CGFloat(nearest)
            selection = nearest
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { power = 1 }
    }
}

// MARK: - Light

/// The cone of light and the ambient wash, drawn for a fractional tab index.
private struct GlowBeam: View, Animatable {
    var x: CGFloat
    let height: CGFloat
    let spread: CGFloat

    var animatableData: CGFloat {
        get { x }
        set { x = newValue }
    }

    var body: some View {
        let color: Color = GlowMetrics.color(at: x)
        let centre: CGFloat = GlowMetrics.centre(x)
        ZStack(alignment: .bottomLeading) {
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.3), color.opacity(0)], center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .scaleEffect(x: 1, y: 0.72)
                .offset(x: centre - 150, y: 150)
            GlowCone(spread: spread)
                .fill(LinearGradient(colors: [color.opacity(0.85), color.opacity(0.28), color.opacity(0)], startPoint: .bottom, endPoint: .top))
                .frame(width: GlowMetrics.barWidth + spread * 2, height: height)
                .blur(radius: 7)
                .offset(x: centre - GlowMetrics.barWidth / 2 - spread, y: -4)
        }
        .frame(width: GlowMetrics.frame.width, height: GlowMetrics.frame.height, alignment: .bottomLeading)
    }
}

/// A trapezoid: bar-wide at the bottom, `spread` wider on each side at the top.
private struct GlowCone: Shape {
    var spread: CGFloat

    var animatableData: CGFloat {
        get { spread }
        set { spread = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + spread, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - spread, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// The lamp itself: a short bright bar on the bottom edge.
private struct GlowBar: View, Animatable {
    var x: CGFloat

    var animatableData: CGFloat {
        get { x }
        set { x = newValue }
    }

    var body: some View {
        let color: Color = GlowMetrics.color(at: x)
        Capsule()
            .fill(Color.white.mix(with: color, by: 0.45))
            .frame(width: GlowMetrics.barWidth, height: GlowMetrics.barHeight)
            .shadow(color: color, radius: 6)
            .shadow(color: color.opacity(0.8), radius: 14)
            .offset(x: GlowMetrics.centre(x) - GlowMetrics.barWidth / 2, y: -5)
            .frame(width: GlowMetrics.frame.width, alignment: .leading)
    }
}

/// Icons and labels lit by their distance to the lamp.
private struct GlowLabels: View, Animatable {
    var x: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { x }
        set { x = newValue }
    }

    var body: some View {
        let color: Color = GlowMetrics.color(at: x)
        HStack(spacing: 0) {
            ForEach(0..<glowTabs.count, id: \.self) { index in
                let distance: Double = Double(CGFloat(index) - x)
                let lit: Double = exp(-(distance * distance) / (2 * 0.42 * 0.42))
                VStack(spacing: 5) {
                    Image(systemName: glowTabs[index].symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(height: 22)
                    Text(glowTabs[index].label, language)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color(white: 0.4).mix(with: Color.white, by: lit))
                .shadow(color: color.opacity(0.9 * lit), radius: 9)
                .offset(y: -2 * lit)
                .frame(width: GlowMetrics.cell, height: GlowMetrics.rowHeight)
            }
        }
        .padding(.bottom, 6)
    }
}
