import SwiftUI

extension Effect {
    static let cardsSpotlightBorder = Effect(
        id: "cards.spotlight-border",
        category: .cards,
        interaction: .gesture,
        name: L("Spotlight Border Grid", "聚光描边卡片组"),
        summary: L("One soft light follows the finger across a bento of dark cards, lighting each border and surface it reaches.", "一束柔光跟随手指扫过一组深色卡片，照到哪里，哪里的描边与表面就被点亮。"),
        prompt: L(
            "Three near-black cards (22 pt corners, 12 pt gaps) form a bento: one wide card above two square ones. A single light, 170 pt in radius, lives in the grid's coordinate space, so every card is lit by the same source: its 1.5 pt border glows white-hot where the light is closest and fades to nothing along the edge, a blurred halo spills outside, the surface takes a faint tinted wash, and each icon brightens and glows as the light nears it. The light trails the finger on a spring (response 0.3 s, damping 0.8); on release it drifts halfway back to the centre and dims to 55% over 0.9 s. Untouched, it wanders on a slow Lissajous path. Quiet, technical and expensive.",
            "三张近黑色卡片（圆角22 pt、间距12 pt）拼成便当布局：上方一张宽卡，下方两张方卡。一束半径170 pt的光位于整个网格的坐标系中，所有卡片共用同一个光源：离光最近的1.5 pt描边亮到发白，沿边缘渐隐至无；卡片外溢出一圈模糊光晕，表面染上一层极淡的色光，图标也随光靠近而变亮发光。光以弹簧（响应0.3秒、阻尼0.8）追随手指；松手后用0.9秒退回到距中心一半的位置，并减弱到55%。无人触摸时它沿缓慢的利萨如曲线游走。克制、精密，质感高级。"
        ),
        implementation: L(
            "An Animatable grid holds the light point; each card converts it to its own UnitPoint and uses it as the centre of two RadialGradients (strokeBorder and fill), so the gradients line up across cards. A TimelineView moves the light until the first touch.",
            "Animatable 网格持有光源坐标，每张卡片把它换算成自己的 UnitPoint，作为两个 RadialGradient（strokeBorder 与填充）的圆心，因此跨卡片的光是连续的；首次触摸前由 TimelineView 驱动光源游走。"
        ),
        apis: ["RadialGradient", "strokeBorder", "Animatable", "TimelineView", "DragGesture", "blendMode(.plusLighter)"],
        tags: ["spotlight", "border glow", "bento", "hover light", "聚光", "描边发光", "便当布局", "光标跟随"],
        params: [
            .slider("radius", L("Light radius", "光照半径"), 90...260, default: 170, step: 5, decimals: 0, unit: "pt"),
            .slider("intensity", L("Intensity", "强度"), 0.3...1.0, default: 0.85),
            .slider("lag", L("Follow lag", "跟随滞后"), 0.1...0.8, default: 0.3, unit: "s"),
            .choice("tint", L("Light colour", "光色"), [L("White", "白"), L("Indigo", "靛蓝"), L("Ember", "橙")], default: 1),
        ]
    ) { ctx in
        CardsSpotlightDemo(ctx: ctx)
    }
}

private enum CardsSpotlightLayout {
    static let area = CGSize(width: 308, height: 268)
    static let cards: [CGRect] = [
        CGRect(x: 0, y: 0, width: 308, height: 120),
        CGRect(x: 0, y: 132, width: 148, height: 136),
        CGRect(x: 160, y: 132, width: 148, height: 136),
    ]
}

private struct CardsSpotlightDemo: View {
    let ctx: DemoContext
    @State private var light = CGPoint(x: 205, y: 104)
    @State private var strength: Double = 1
    @State private var touched = false
    @State private var held = false
    /// Resets on system cancellation too, so a stolen touch still lets the light drift back.
    @GestureState private var pressing = false

    private var area: CGSize { CardsSpotlightLayout.area }

    var body: some View {
        VStack(spacing: 20) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: touched || ctx.isStill)) { timeline in
                CardsSpotlightGrid(
                    light: touched || ctx.isStill ? light : idleLight(at: timeline.date.timeIntervalSinceReferenceDate),
                    strength: strength * ctx["intensity"],
                    radius: ctx.cg("radius"),
                    tint: tint,
                    language: ctx.language
                )
            }
            .frame(width: area.width, height: area.height)
            .contentShape(Rectangle())
            .gesture(drag)
            DemoHint(text: L("Drag across the cards", "在卡片上拖动"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release() }
        }
    }

    private var tint: Color {
        switch ctx.int("tint") {
        case 0: return Color.white
        case 2: return Palette.ember
        default: return Color(hex: 0x8E9BFF)
        }
    }

    private func idleLight(at t: Double) -> CGPoint {
        CGPoint(
            x: area.width / 2 + CGFloat(cos(t * 0.7)) * area.width * 0.42,
            y: area.height / 2 + CGFloat(sin(t * 1.1)) * area.height * 0.4
        )
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in moveLight(to: value.location) }
            .onEnded { _ in release() }
    }

    private func moveLight(to location: CGPoint) {
        if !touched {
            // Take over from wherever the wandering light is, so nothing jumps.
            light = idleLight(at: Date().timeIntervalSinceReferenceDate)
            touched = true
        }
        if !held {
            held = true
            Haptics.tap(.soft)
        }
        withAnimation(.spring(response: ctx["lag"], dampingFraction: 0.8)) {
            light = CGPoint(
                x: location.x.clamped(to: -30...(area.width + 30)),
                y: location.y.clamped(to: -30...(area.height + 30))
            )
            strength = 1
        }
    }

    /// Single, guarded end of a touch (lift or system cancellation).
    private func release() {
        guard held else { return }
        held = false
        withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
            light = CGPoint(x: (light.x + area.width / 2) / 2, y: (light.y + area.height / 2) / 2)
            strength = 0.55
        }
    }
}

/// Animatable so the gradients' centres travel with the lagging spring.
private struct CardsSpotlightGrid: View, Animatable {
    var light: CGPoint
    var strength: Double
    let radius: CGFloat
    let tint: Color
    let language: AppLanguage

    var animatableData: AnimatablePair<CGPoint.AnimatableData, Double> {
        get { AnimatablePair(light.animatableData, strength) }
        set {
            light.animatableData = newValue.first
            strength = newValue.second
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<CardsSpotlightLayout.cards.count, id: \.self) { index in
                let rect = CardsSpotlightLayout.cards[index]
                CardsSpotlightCard(
                    index: index,
                    size: rect.size,
                    light: CGPoint(x: light.x - rect.minX, y: light.y - rect.minY),
                    strength: strength,
                    radius: radius,
                    tint: tint,
                    language: language
                )
                .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: CardsSpotlightLayout.area.width, height: CardsSpotlightLayout.area.height, alignment: .topLeading)
    }
}

private struct CardsSpotlightCard: View {
    let index: Int
    let size: CGSize
    /// Light position in this card's own coordinates (may lie outside the card).
    let light: CGPoint
    let strength: Double
    let radius: CGFloat
    let tint: Color
    let language: AppLanguage

    private static let symbols = ["bolt.horizontal.fill", "lock.shield.fill", "chart.line.uptrend.xyaxis"]
    private static let titles = [L("Realtime sync", "实时同步"), L("Private", "私密"), L("Insights", "洞察")]
    private static let details = [
        L("Every change lands on all devices in 40 ms.", "每次改动 40 毫秒内到达所有设备。"),
        L("End-to-end encrypted.", "端到端加密。"),
        L("Trends, at a glance.", "趋势一目了然。"),
    ]

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }

    var body: some View {
        let centre = UnitPoint(x: light.x / size.width, y: light.y / size.height)
        // The icon sits 34 pt in from the top-left corner.
        let iconDistance = hypot(light.x - 34, light.y - 34)
        let iconLit = Double(max(0, 1 - iconDistance / radius)) * strength
        ZStack(alignment: .topLeading) {
            shape.fill(Color(hex: 0x0E0F13))
            shape.fill(
                RadialGradient(
                    colors: [tint.opacity(0.3 * strength), tint.opacity(0)],
                    center: centre,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            content(iconLit: iconLit)
        }
        .frame(width: size.width, height: size.height)
        .overlay { shape.strokeBorder(Color.white.opacity(0.07), lineWidth: 1) }
        .overlay { rim(centre: centre, width: 3).blur(radius: 5).blendMode(.plusLighter) }
        .overlay { rim(centre: centre, width: 1.5) }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
    }

    private func rim(centre: UnitPoint, width: CGFloat) -> some View {
        let stops: [Gradient.Stop] = [
            .init(color: Color.white.opacity(0.95 * strength), location: 0),
            .init(color: tint.opacity(0.75 * strength), location: 0.35),
            .init(color: tint.opacity(0), location: 1),
        ]
        return shape
            .strokeBorder(
                RadialGradient(stops: stops, center: centre, startRadius: 0, endRadius: radius * 0.9),
                lineWidth: width
            )
            .allowsHitTesting(false)
    }

    private func content(iconLit: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: Self.symbols[index])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.42 + 0.58 * iconLit))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.05 + 0.09 * iconLit), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: tint.opacity(0.85 * iconLit), radius: 9)
                Spacer(minLength: 0)
                if index == 0 { statusPill }
            }
            Spacer(minLength: 0)
            Text(Self.titles[index], language)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.94))
            Text(Self.details[index], language)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.white.opacity(0.46))
                .lineLimit(2)
                .padding(.top, 3)
        }
        .padding(16)
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Palette.green)
                .frame(width: 6, height: 6)
            Text(L("Live", "在线"), language)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: Capsule())
    }
}
