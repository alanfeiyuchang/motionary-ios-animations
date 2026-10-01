import SwiftUI

extension Effect {
    static let navigationGlassTabBar = Effect(
        id: "navigation.glass-tab-bar",
        category: .navigation,
        interaction: .gesture,
        name: L("Liquid Glass Tab Bar", "液态玻璃标签栏"),
        summary: L(
            "The selection is a glass lens: it lifts, stretches to the next tab, magnifies the icons under it and settles; the bar shrinks to one icon on scroll.",
            "选中态是一枚玻璃透镜：抬起、拉伸着滑向下一个标签，放大其下的图标后落定；滚动时标签栏收成单个图标。"
        ),
        prompt: L(
            "A floating 240 × 60 pt frosted capsule tab bar with four icon-and-label tabs and a separate round search button. The selection is a 52 pt-tall glass lens with a bright rim. Tapping a tab lifts the lens (18% taller, deeper shadow, spring 0.24 s) and sends it across: the edge facing the target moves on a 0.4 s spring (damping 0.72), the other edge follows on a spring 1.5× slower, so the lens stretches like a droplet and then contracts. Icons inside the lens are redrawn tinted and magnified to 122% around its centre, clipped exactly to its outline, so glyphs split mid-pass. On arrival it drops back with a soft overshoot. The lens can also be dragged along the bar with selection ticks. Scrolling down 30 pt collapses the bar into a single 60 pt disc holding the active icon; scrolling up or tapping restores it.",
            "悬浮的 240 × 60 pt 磨砂胶囊标签栏，四个带文字的图标。选中态是一枚 52 pt 高、带亮边的玻璃透镜。点击标签时透镜先抬起（增高 18%、阴影加深，弹簧 0.24 秒）再滑过去：朝向目标的一侧以 0.4 秒弹簧（阻尼 0.72）先行，另一侧的弹簧慢 1.5 倍，透镜像水滴一样拉长再收拢。透镜内的图标以强调色重绘并放大到 122%，严格裁切在透镜轮廓内，经过时字形被一分为二。到位后带过冲落回。透镜也可拖动，逐格触感。向下滚动 30 pt，标签栏收成只含当前图标的 60 pt 圆片，上滚或点击恢复。"
        ),
        implementation: L(
            "Three nested Animatable views interpolate the lens's leading edge, trailing edge and lift separately, so each keeps its own spring. The icon row is drawn twice: the base copy masked with the lens punched out (destinationOut), and a tinted copy scaled around the lens centre and masked to the lens.",
            "三层嵌套的 Animatable 视图分别插值透镜的前缘、后缘与抬起量，使三者各用各的弹簧。图标行绘制两遍：底层用 destinationOut 挖去透镜区域，另一份着色副本围绕透镜中心缩放后以透镜形状作遮罩。"
        ),
        apis: ["Animatable", "mask(alignment:_:)", "blendMode(.destinationOut)", "scaleEffect(_:anchor:)", "onScrollGeometryChange", "Material"],
        tags: ["tab bar", "liquid glass", "lens", "iOS 26", "标签栏", "液态玻璃", "透镜", "放大"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.7, default: 0.4, unit: "s"),
            .slider("lag", L("Tail lag", "尾部滞后"), 1.0...2.2, default: 1.5, unit: "×"),
            .slider("magnify", L("Lens magnification", "透镜放大"), 1.0...1.5, default: 1.22, unit: "×"),
            .toggle("minimize", L("Minimise on scroll", "滚动时收起"), default: true),
        ]
    ) { ctx in
        GlassTabBarDemo(ctx: ctx)
    }
}

private struct GlassTab {
    let symbol: String
    let title: LocalizedText
}

private let glassTabs: [GlassTab] = [
    GlassTab(symbol: "house.fill", title: L("Home", "首页")),
    GlassTab(symbol: "square.grid.2x2.fill", title: L("Browse", "浏览")),
    GlassTab(symbol: "heart.fill", title: L("Saved", "收藏")),
    GlassTab(symbol: "person.fill", title: L("Me", "我的")),
]

/// The lens tint: a deeper blue on light glass, a lighter one on dark glass.
private let glassTint = Color.adaptive(light: 0x1F62F2, dark: 0x8FC0FF)

private enum GlassBarMetrics {
    static let slot: CGFloat = 58
    static let pad: CGFloat = 4
    static let height: CGFloat = 60
    static var width: CGFloat { slot * CGFloat(glassTabs.count) + pad * 2 }
}

private struct GlassTabBarDemo: View {
    let ctx: DemoContext
    @State private var selected = 0
    @State private var hovered = 0
    @State private var lead: CGFloat = GlassBarMetrics.pad
    @State private var trail: CGFloat = GlassBarMetrics.pad + GlassBarMetrics.slot
    @State private var lift: CGFloat = 0
    @State private var dragging = false
    @State private var minimized = false
    @State private var moveToken = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var travel: CGFloat = 0
    @State private var autoStep = 0

    private var slot: CGFloat { GlassBarMetrics.slot }
    private var pad: CGFloat { GlassBarMetrics.pad }

    var body: some View {
        content
            .overlay(alignment: .bottom) {
                bar.padding(.bottom, 16)
            }
            .autoplay(ctx.isPreview, every: 1.25) { autoplayStep() }
    }

    /// A scrolling feed live; a plain clipped column in a still (`ImageRenderer` cannot draw scroll views).
    @ViewBuilder
    private var content: some View {
        if ctx.isStill {
            feed(count: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else {
            scrollingFeed
        }
    }

    private func feed(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(glassTabs[selected].title, ctx.language)
                    .font(.title2.weight(.bold))
                    .contentTransition(.opacity)
                DemoHint(text: L("Tap a tab or drag the lens · scroll to minimise", "点击标签或拖动透镜 · 滚动可收起"), ctx: ctx)
            }
            .padding(.horizontal, 4)
            ForEach(0..<count, id: \.self) { index in
                GlassFeedCard(index: index)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var scrollingFeed: some View {
        ScrollView {
            feed(count: 9)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { oldValue, newValue in
            handleScroll(from: oldValue, to: newValue)
        }
    }

    // MARK: Bar

    private var bar: some View {
        HStack(spacing: 10) {
            tabCapsule
            Spacer(minLength: 0)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.8))
                .frame(width: GlassBarMetrics.height, height: GlassBarMetrics.height)
                .background(GlassBarSurface())
        }
        .frame(width: 310)
    }

    private var tabCapsule: some View {
        let width: CGFloat = minimized ? GlassBarMetrics.height : GlassBarMetrics.width
        return ZStack(alignment: .leading) {
            GlassLensLeadLayer(
                lead: lead,
                trail: trail,
                lift: lift,
                magnify: ctx.cg("magnify"),
                language: ctx.language
            )
            .frame(width: GlassBarMetrics.width, height: GlassBarMetrics.height)
            .opacity(minimized ? 0 : 1)
            .blur(radius: minimized ? 6 : 0)

            Image(systemName: glassTabs[selected].symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(glassTint)
                .frame(width: GlassBarMetrics.height, height: GlassBarMetrics.height)
                .opacity(minimized ? 1 : 0)
                .scaleEffect(minimized ? 1 : 0.5)
        }
        .frame(width: width, height: GlassBarMetrics.height, alignment: .leading)
        // Clipped at the sides only: the lifted lens may rise a little above and below the bar.
        .mask {
            RoundedRectangle(cornerRadius: GlassBarMetrics.height / 2 + 10, style: .continuous)
                .padding(.vertical, -10)
        }
        .background(GlassBarSurface())
        .contentShape(Capsule())
        .onTapGesture(coordinateSpace: .local) { location in
            tapped(at: location.x)
        }
        .pageSafeHorizontalDrag(minimumDistance: 6, onChanged: dragChanged, onEnded: dragEnded)
    }

    // MARK: Selection

    private func index(at x: CGFloat) -> Int {
        let raw = Int(((x - pad) / slot).rounded(.down))
        return min(max(raw, 0), glassTabs.count - 1)
    }

    private func tapped(at x: CGFloat) {
        if minimized {
            if !ctx.isPreview { Haptics.tap(.light) }
            travel = 0
            setMinimized(false)
            return
        }
        select(index(at: x))
    }

    private func select(_ index: Int) {
        guard index != selected else { return }
        if !ctx.isPreview { Haptics.selection() }
        move(to: index, response: ctx["response"])
    }

    /// Sends the lens to a slot: the edge facing the target leads, the other one lags, and the lift pulses.
    private func move(to index: Int, response: Double) {
        let targetLead: CGFloat = pad + CGFloat(index) * slot
        let targetTrail: CGFloat = targetLead + slot
        let goingRight: Bool = (targetLead + targetTrail) > (lead + trail)
        let fast: Animation = .spring(response: response, dampingFraction: 0.72)
        let slow: Animation = .spring(response: response * ctx["lag"], dampingFraction: 0.82)
        withAnimation(.easeInOut(duration: 0.2)) {
            selected = index
            hovered = index
        }
        withAnimation(goingRight ? fast : slow) { trail = targetTrail }
        withAnimation(goingRight ? slow : fast) { lead = targetLead }

        moveToken += 1
        let token = moveToken
        withAnimation(.spring(response: 0.24, dampingFraction: 0.7)) { lift = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(response * 0.85))
            guard token == moveToken, !dragging else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { lift = 0 }
        }
    }

    // MARK: Drag

    private func dragChanged(_ value: DragGesture.Value) {
        guard !minimized else { return }
        if !dragging {
            dragging = true
            moveToken += 1
            withAnimation(.spring(response: 0.24, dampingFraction: 0.7)) { lift = 1 }
        }
        let half: CGFloat = slot / 2
        let centre: CGFloat = min(max(value.location.x, pad + half), GlassBarMetrics.width - pad - half)
        let goingRight: Bool = centre > (lead + trail) / 2
        let fast: Animation = .interactiveSpring(response: 0.16, dampingFraction: 0.86)
        let slow: Animation = .interactiveSpring(response: 0.2 * ctx["lag"], dampingFraction: 0.86)
        withAnimation(goingRight ? fast : slow) { trail = centre + half }
        withAnimation(goingRight ? slow : fast) { lead = centre - half }
        let now = index(at: centre)
        if now != hovered {
            hovered = now
            withAnimation(.easeInOut(duration: 0.2)) { selected = now }
            Haptics.selection()
        }
    }

    /// Release (or a system cancellation) snaps the lens onto the slot it hovers.
    private func dragEnded(_ value: DragGesture.Value?) {
        guard dragging else { return }
        dragging = false
        if !ctx.isPreview { Haptics.tap(.light) }
        move(to: hovered, response: ctx["response"] * 0.8)
    }

    // MARK: Minimise

    private func handleScroll(from oldValue: CGFloat, to newValue: CGFloat) {
        guard ctx.bool("minimize") else {
            setMinimized(false)
            return
        }
        let delta: CGFloat = newValue - oldValue
        guard newValue >= 20 else {
            travel = 0
            setMinimized(false)
            return
        }
        guard delta != 0 else { return }
        if travel != 0 && (delta > 0) != (travel > 0) { travel = 0 }
        travel += delta
        if travel > 30 {
            setMinimized(true)
        } else if travel < -15 {
            setMinimized(false)
        }
    }

    private func setMinimized(_ target: Bool) {
        guard target != minimized else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { minimized = target }
    }

    // MARK: Autoplay

    /// Preview loop: three tab changes, a scroll that minimises the bar, a scroll back, then the first tab again.
    private func autoplayStep() {
        let canMinimize: Bool = ctx.bool("minimize") && ctx.isPreview
        let step = autoStep % (canMinimize ? 6 : 4)
        autoStep += 1
        switch step {
        case 0, 1, 2:
            select(step + 1)
        case 3:
            if canMinimize {
                withAnimation(.smooth(duration: 0.9)) { position.scrollTo(y: 260) }
            } else {
                select(0)
            }
        case 4:
            withAnimation(.smooth(duration: 0.9)) { position.scrollTo(y: 0) }
        default:
            select(0)
        }
    }
}

// MARK: - Lens layers

/// Interpolates only the lens's leading edge, so its spring stays independent of the trailing edge's.
private struct GlassLensLeadLayer: View, Animatable {
    var lead: CGFloat
    let trail: CGFloat
    let lift: CGFloat
    let magnify: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { lead }
        set { lead = newValue }
    }

    var body: some View {
        GlassLensTrailLayer(lead: lead, trail: trail, lift: lift, magnify: magnify, language: language)
    }
}

/// Interpolates only the trailing edge.
private struct GlassLensTrailLayer: View, Animatable {
    let lead: CGFloat
    var trail: CGFloat
    let lift: CGFloat
    let magnify: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { trail }
        set { trail = newValue }
    }

    var body: some View {
        GlassLensLiftLayer(lead: lead, trail: trail, lift: lift, magnify: magnify, language: language)
    }
}

/// Interpolates the lift and draws the bar's content: base icons with the lens punched out, the lens, and the
/// tinted, magnified icons seen through it.
private struct GlassLensLiftLayer: View, Animatable {
    let lead: CGFloat
    let trail: CGFloat
    var lift: CGFloat
    let magnify: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { lift }
        set { lift = newValue }
    }

    private var lensSize: CGSize {
        let width: CGFloat = max(trail - lead, 24) * (1 + 0.08 * lift)
        let height: CGFloat = (GlassBarMetrics.height - GlassBarMetrics.pad * 2) * (1 + 0.18 * lift)
        return CGSize(width: width, height: height)
    }

    private var centre: CGPoint {
        CGPoint(x: (lead + trail) / 2, y: GlassBarMetrics.height / 2)
    }

    var body: some View {
        let size = lensSize
        let anchor = UnitPoint(x: centre.x / GlassBarMetrics.width, y: 0.5)
        ZStack {
            GlassIconRow(language: language, active: false)
                .mask {
                    Rectangle()
                        .padding(-12)
                        .overlay {
                            Capsule()
                                .frame(width: size.width, height: size.height)
                                .position(centre)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
            GlassLens(lift: lift)
                .frame(width: size.width, height: size.height)
                .position(centre)
            GlassIconRow(language: language, active: true)
                .scaleEffect(1 + (magnify - 1) * lift, anchor: anchor)
                .mask {
                    Capsule()
                        .frame(width: size.width, height: size.height)
                        .position(centre)
                }
        }
        .frame(width: GlassBarMetrics.width, height: GlassBarMetrics.height)
    }
}

private struct GlassIconRow: View {
    let language: AppLanguage
    let active: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<glassTabs.count, id: \.self) { index in
                VStack(spacing: 3) {
                    Image(systemName: glassTabs[index].symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(height: 20)
                    Text(glassTabs[index].title, language)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                }
                .frame(width: GlassBarMetrics.slot)
            }
        }
        .foregroundStyle(active ? glassTint : Color.primary.opacity(0.7))
        .frame(width: GlassBarMetrics.width, height: GlassBarMetrics.height)
    }
}

/// The glass lens itself: a clear body, a specular cap that brightens as it lifts, a bright rim and a
/// shadow that deepens with the lift.
private struct GlassLens: View {
    let lift: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark: Bool = colorScheme == .dark
        let glass: Double = dark ? 0.12 + 0.06 * Double(lift) : 0.42 + 0.14 * Double(lift)
        let rim = LinearGradient(
            colors: [Color.white.opacity(0.95), Color.white.opacity(dark ? 0.12 : 0.4), Color.white.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
        let cap = LinearGradient(
            colors: [Color.white.opacity(0.12 + 0.3 * Double(lift)), Color.white.opacity(0)],
            startPoint: .top,
            endPoint: .center
        )
        Capsule()
            .fill(Color.white.opacity(glass))
            .overlay(Capsule().fill(cap))
            .overlay(Capsule().strokeBorder(rim, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.1 + 0.16 * Double(lift)), radius: 5 + 10 * lift, y: 2 + 6 * lift)
    }
}

/// Frosted bar surface with a top-lit rim (still-safe through `DemoMaterial`).
private struct GlassBarSurface: View {
    var body: some View {
        let rim = LinearGradient(
            colors: [Color.white.opacity(0.7), Color.white.opacity(0.08), Color.white.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        DemoMaterial(Capsule(), material: .ultraThinMaterial)
            .overlay(Capsule().strokeBorder(rim, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 8)
    }
}

private struct GlassFeedCard: View {
    let index: Int

    private static let symbols: [String] = ["sun.horizon.fill", "leaf.fill", "sparkles", "mountain.2.fill", "drop.fill", "flame.fill"]

    var body: some View {
        let a: Color = Palette.spectrum[index % Palette.spectrum.count]
        let b: Color = Palette.spectrum[(index + 2) % Palette.spectrum.count]
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 104)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(Color.white.opacity(0.85)).frame(width: 110, height: 9)
                    Capsule().fill(Color.white.opacity(0.5)).frame(width: 70, height: 7)
                }
                .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: Self.symbols[index % Self.symbols.count])
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(16)
            }
    }
}
