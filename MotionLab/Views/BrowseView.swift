import SwiftUI

struct BrowseView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.launchIntroActive) private var introActive
    @Environment(RecentsStore.self) private var recents
    @Environment(AppNavigator.self) private var navigator
    /// Rolled once per appearance so the dice target is stable while the page is visible.
    @State private var randomID = EffectLibrary.all.randomElement()?.id
    /// First-appearance choreography (title glyphs, counters, sections) has been triggered.
    @State private var revealed = SessionFlags.browseRevealed
    /// The inline nav-bar title only fades in once the hero title has scrolled away.
    @State private var showsNavTitle = false
    @State private var isAppeared = false
    /// Scroll offset for the hero mesh, kept in its own observable so scrolling only re-renders the mesh.
    @State private var heroScroll = HeroScrollState()
    @State private var focusedFeatured = 0
    /// Bumped on every appearance: the dice "re-rolls" with a bounce.
    @State private var diceRolls = 0

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header(reader)
                    featured
                        .entrance(revealed, delay: 0.3, distance: 26, scale: 0.98, blur: 0)
                    familiesRow
                        .entrance(revealed, delay: 0.36, distance: 22, scale: 0.98, blur: 0)
                    if !recents.ids.isEmpty { recent }
                    categories.id(Self.categoriesAnchor)
                }
                .padding(.bottom, 8)
                .animation(.smooth, value: recents.ids)
            }
            .shellPageScroll()
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 44
            } action: { _, isPastTitle in
                withAnimation(.easeInOut(duration: 0.2)) { showsNavTitle = isPastTitle }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // Whole points are plenty for a parallax glow, and spare needless updates.
                (geometry.contentOffset.y + geometry.contentInsets.top).rounded()
            } action: { _, offset in
                heroScroll.offset = offset
            }
        }
        // The hero glow lives behind the scroll view, not in its content, so neither the scroll view
        // nor the navigation bar can clip it: it runs from the top of the screen, under the bar,
        // and fades into the page below the counters, drifting up (parallax) as the page scrolls.
        .background(alignment: .top) {
            HeroBackdrop(state: heroScroll, isAnimating: heroAnimating)
        }
        .background(Palette.pageBackground)
        // No flat bar band over the glow while the page rests at the top.
        .toolbarBackgroundVisibility(showsNavTitle ? .automatic : .hidden, for: .navigationBar)
        .modifier(SoftTopScrollEdge())
        .navigationTitle(Strings.appTitle(language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(Strings.appTitle, language)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showsNavTitle ? 1 : 0)
                    .accessibilityHidden(!showsNavTitle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let randomID {
                    // The surprise effect zooms out of the dice.
                    NavigationLink(value: Route.effect(randomID, source: Self.diceSource)) {
                        Image(systemName: "dice.fill")
                            .symbolEffect(.bounce, value: diceRolls)
                            .modifier(ZoomSource(id: Route.zoomID(effect: randomID, source: Self.diceSource)))
                    }
                    .accessibilityLabel(Strings.random(language))
                }
            }
        }
        .onAppear {
            isAppeared = true
            if !introActive { playReveal() }
        }
        .task(id: isAppeared) {
            // Re-roll once a pop back from the surprise effect has settled, so its zoom can still
            // land on the dice it came from.
            guard isAppeared else { return }
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            randomID = EffectLibrary.all.randomElement()?.id
            if !reduceMotion { diceRolls += 1 }
        }
        .onDisappear { isAppeared = false }
        .onChange(of: introActive) { _, active in
            if !active { playReveal() }
        }
    }

    private static let categoriesAnchor = "categories"
    private static let diceSource = "dice"

    /// "Browse by Family" row: each category's largest family, in catalog order.
    private static let spotlightFamilies: [EffectFamily] = EffectCategory.allCases.compactMap { category in
        EffectFamilies.families(in: category).max { lhs, rhs in
            EffectFamilies.effects(in: lhs).count < EffectFamilies.effects(in: rhs).count
        }
    }

    /// Starts the one-time header choreography (each element animates itself off `revealed`).
    private func playReveal() {
        guard !revealed else { return }
        SessionFlags.browseRevealed = true
        revealed = true
    }

    /// The mesh only ticks while its page is on screen (`HeroBackdrop` also stops it once scrolled away).
    private var heroAnimating: Bool {
        isAppeared && scenePhase == .active && !reduceMotion && navigator.tab == .browse
    }

    // MARK: Header

    private func header(_ reader: ScrollViewProxy) -> some View {
        let revealed = self.revealed
        // Counters roll up from zero on first reveal (never with Reduce Motion).
        let countsShown = revealed || reduceMotion
        return VStack(alignment: .leading, spacing: 10) {
            GlyphRevealTitle(text: Strings.appTitle(language), revealed: revealed)
                .accessibilityAddTraits(.isHeader)
            Text(Strings.appSubtitle, language)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .entrance(revealed, delay: 0.3, distance: 8)
            // One balanced row; wraps to a second row only when it cannot fit (large text sizes).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    statPills(countsShown: countsShown, reader: reader)
                }
                FlowLayout(spacing: 8) {
                    statPills(countsShown: countsShown, reader: reader)
                }
            }
            .entrance(revealed, delay: 0.38, distance: 10)
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statPills(countsShown: Bool, reader: ScrollViewProxy) -> some View {
        let effectCount = EffectLibrary.all.count
        let categoryCount = EffectCategory.allCases.count
        let familyCount = EffectFamilies.all.count
        StatPill(value: countsShown ? effectCount : 0, unit: Strings.effects(language)) {
            // "235 effects" → the whole catalog in Search.
            navigator.search("")
        }
        .accessibilityLabel(Text(verbatim: Strings.effectCount(effectCount, language)))
        .accessibilityHint(Text(Strings.showAllEffects, language))
        StatPill(value: countsShown ? categoryCount : 0, unit: Strings.categoriesUnit(language)) {
            withAnimation(reduceMotion ? nil : Animation.smooth) {
                reader.scrollTo(Self.categoriesAnchor, anchor: .top)
            }
        }
        .accessibilityLabel(Text(verbatim: Strings.categoryCount(categoryCount, language)))
        .accessibilityHint(Text(Strings.jumpToCategories, language))
        // "85 families" → the All Families index, zooming out of the pill.
        StatPill(value: countsShown ? familyCount : 0, unit: Strings.familiesUnit(language), route: .families(source: "statPill"))
            .accessibilityLabel(Text(verbatim: Strings.familyCount(familyCount, language)))
            .accessibilityHint(Text(Strings.showAllFamilies, language))
    }

    // MARK: Featured

    private var featured: some View {
        let items = EffectLibrary.featured
        let count = items.count
        let focused = focusedFeatured
        let motion = !reduceMotion
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: Strings.featured(language))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: FeaturedMetrics.spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, effect in
                        EffectLink(effect: effect, source: "featured", cornerRadius: CornerRadius.featuredCard) {
                            FeaturedCard(effect: effect, isFocused: index == focused)
                        }
                        .modifier(CoverFlowEffect(enabled: motion))
                        .environment(\.urgentSnapshots, index < 2)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, FeaturedMetrics.inset)
            }
            .scrollTargetBehavior(.viewAligned)
            // Lets the focused card's shadow spill below the row.
            .scrollClipDisabled()
            .onScrollGeometryChange(for: Int.self) { geometry in
                let maxOffset = geometry.contentSize.width - geometry.containerSize.width
                return FeaturedMetrics.focusIndex(offset: geometry.contentOffset.x, maxOffset: maxOffset, count: count)
            } action: { _, index in
                focusedFeatured = index
            }
            // A soft detent as each card snaps into focus.
            .sensoryFeedback(.selection, trigger: focusedFeatured)
            .pausesSnapshotsWhileScrolling()
        }
    }

    // MARK: Families

    /// Families are the catalog's main organising layer, so Browse surfaces them right under
    /// Featured: one live family card per category, plus "See All" into the All Families index.
    private var familiesRow: some View {
        let items = Self.spotlightFamilies
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: Strings.browseByFamily(language)) {
                ZoomRouteLink(route: Route.families(source: "familiesSeeAll")) {
                    HStack(spacing: 3) {
                        Text(Strings.seeAll, language)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityHint(Text(Strings.showAllFamilies, language))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, family in
                        let members = EffectFamilies.effects(in: family)
                        ZoomRouteLink(route: Route.family(family.id, source: "browseFamily"), cornerRadius: CornerRadius.card) {
                            FamilyCard(family: family, effects: members)
                                .frame(width: FamilyRowMetrics.cardWidth)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel(Text(verbatim: "\(family.name(language))\(Strings.listSeparator(language))\(Strings.variationCount(members.count, language))"))
                        .accessibilityHint(Text(family.summary, language))
                        .environment(\.urgentSnapshots, index < 2)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal)
            }
            .scrollTargetBehavior(.viewAligned)
            // Lets the cards' shadows spill below the row.
            .scrollClipDisabled()
            .pausesSnapshotsWhileScrolling()
        }
    }

    // MARK: Recent

    private var recent: some View {
        let motion = !reduceMotion
        let swap = CardSwapTransition(reduceMotion: reduceMotion, blur: 0)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: Strings.recent(language)) {
                Button(Strings.clear(language)) {
                    Haptics.tap()
                    recents.clear()
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(recents.effects) { effect in
                        EffectLink(effect: effect, source: "recent", cornerRadius: CornerRadius.compactThumbnail) {
                            CompactEffectCard(effect: effect)
                        }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            let v: Double = motion ? abs(phase.value) : 0
                            return content
                                .scaleEffect(1 - CGFloat(v) * 0.08)
                                .opacity(1 - v * 0.3)
                        }
                        .transition(swap)
                    }
                }
                .padding(.horizontal)
            }
            .scrollClipDisabled()
            .pausesSnapshotsWhileScrolling()
        }
        .transition(.opacity)
    }

    // MARK: Categories

    private var categories: some View {
        let revealed = self.revealed
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: Strings.categories(language))
                .entrance(revealed, delay: 0.42, distance: 12, blur: 0)
            LazyVGrid(columns: categoryColumns, spacing: 14) {
                ForEach(Array(EffectCategory.allCases.enumerated()), id: \.element) { index, category in
                    let count = EffectLibrary.effects(in: category).count
                    let familyCount = EffectFamilies.families(in: category).count
                    ZoomRouteLink(route: Route.category(category, source: "tile"), cornerRadius: CornerRadius.section) {
                        CategoryTile(category: category, count: count, familyCount: familyCount)
                    }
                    .buttonStyle(PressableCardStyle(depth: 10, tilt: true))
                    .accessibilityLabel(Text(verbatim: "\(category.title(language))\(Strings.listSeparator(language))\(Strings.familiesAndEffects(families: familyCount, effects: count, language))"))
                    .accessibilityHint(Text(category.subtitle, language))
                    .entrance(revealed, delay: 0.46 + ShellMotion.stagger(index, step: 0.05, cap: 6), distance: 22, scale: 0.95)
                    .scrollReveal()
                }
            }
            .padding(.horizontal)
        }
    }

    private var categoryColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 14)]
            : [GridItem(.adaptive(minimum: 160), spacing: 14)]
    }
}

// MARK: - Hero backdrop

@Observable
private final class HeroScrollState {
    /// Distance the Browse page has scrolled from its resting top (negative while over-pulling).
    var offset: CGFloat = 0
}

/// The Browse hero glow: a drifting mesh from the top of the screen (under the navigation bar)
/// down past the header, faded into the page. It rises at half the scroll speed and fades out over
/// the first 200 pt of scroll; its timeline pauses once it is invisible.
private struct HeroBackdrop: View {
    let state: HeroScrollState
    let isAnimating: Bool

    private static let height: CGFloat = 420
    private static let fadeDistance: CGFloat = 200

    var body: some View {
        let offset: CGFloat = state.offset
        let scrolled: CGFloat = max(offset, 0)
        let visibility: Double = Double(1 - min(scrolled / Self.fadeDistance, 1))
        // Over-pulling stretches the glow down with the content instead of uncovering a gap.
        let stretch: CGFloat = max(-offset, 0)
        HeroMeshBackground(isAnimating: isAnimating && visibility > 0)
            .frame(height: Self.height + stretch)
            .mask {
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .black, location: 0),
                        Gradient.Stop(color: .black, location: 0.6),
                        Gradient.Stop(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .offset(y: -scrolled * 0.5)
            .opacity(visibility)
            .frame(maxWidth: .infinity, alignment: .top)
            // Sideways too: on iPhone Duo the status bar is a strip down the trailing edge, and the
            // glow has to run behind it rather than stop short and leave a black column there.
            .ignoresSafeArea(edges: [.top, .horizontal])
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// iOS 26: a soft scroll-edge effect under the navigation bar, so the bar never lays a flat band
/// of page colour over the hero glow. Earlier systems are unchanged.
private struct SoftTopScrollEdge: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - Featured carousel geometry

private enum FamilyRowMetrics {
    static let cardWidth: CGFloat = 300
}

private enum FeaturedMetrics {
    static let cardWidth: CGFloat = 260
    static let spacing: CGFloat = 16
    static let inset: CGFloat = 16
    static var pitch: CGFloat { cardWidth + spacing }

    /// Index of the card snapped to the leading edge (the last one once the row hits its end).
    static func focusIndex(offset: CGFloat, maxOffset: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        if maxOffset > 0 && offset >= maxOffset - 2 { return count - 1 }
        let raw = Int((offset / pitch).rounded())
        return min(max(raw, 0), count - 1)
    }
}

/// Cover-flow: cards turn and shrink slightly as they leave the snapped (leading) position.
private struct CoverFlowEffect: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        let enabled = self.enabled
        return content.visualEffect { effect, proxy in
            let minX = proxy.frame(in: .scrollView).minX
            let raw: CGFloat = (minX - FeaturedMetrics.inset) / FeaturedMetrics.pitch
            let t: CGFloat = enabled ? min(max(raw, -1), 1) : 0
            let degrees = Double(-14 * t)
            let shrink: CGFloat = 1 - 0.08 * abs(t)
            return effect
                .rotation3DEffect(.degrees(degrees), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                .scaleEffect(shrink)
                .opacity(1 - 0.3 * Double(abs(t)))
        }
    }
}

// MARK: - Pieces

/// Tappable "235 effects" style pill on the Browse header; the number rolls up on first reveal.
/// Runs `action`, or pushes `route` (zooming out of the pill) when one is given.
private struct StatPill: View {
    let value: Int
    let unit: String
    var route: Route? = nil
    var action: () -> Void = {}

    var body: some View {
        if let route {
            ZoomRouteLink(route: route) { label }
                .buttonStyle(PressableCardStyle())
                .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })
        } else {
            Button {
                Haptics.selection()
                action()
            } label: {
                label
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: "\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Palette.accentInk)
                .contentTransition(.numericText(value: Double(value)))
                .animation(ShellMotion.count.delay(0.35), value: value)
            Text(verbatim: unit)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.edge))
        .contentShape(Capsule())
    }
}

/// Gradient rounded-square badge with the category's SF Symbol.
/// Bounces when `bounce` changes, and on touch-down inside a `PressableCardStyle` button.
struct CategoryIcon: View {
    let category: EffectCategory
    var size: CGFloat = 42
    var bounce: Int = 0
    @Environment(\.isCardPressed) private var isPressed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressBounces = 0

    var body: some View {
        Image(systemName: category.symbol)
            .fixedSymbolLocale()
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .symbolEffect(.bounce, value: bounce + pressBounces)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: category.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            )
            .shadow(color: (category.gradient.last ?? .clear).opacity(0.3), radius: size * 0.15, y: size * 0.08)
            .accessibilityHidden(true)
            .onChange(of: isPressed) { _, pressed in
                if pressed && !reduceMotion { pressBounces += 1 }
            }
    }
}

private struct FeaturedCard: View {
    let effect: Effect
    var isFocused = false
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let shape = RoundedRectangle(cornerRadius: CornerRadius.featuredCard, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            PreviewStage(effect: effect, cornerRadius: CornerRadius.featuredThumbnail, parallax: true)
                .frame(width: 240, height: 240)
            VStack(alignment: .leading, spacing: 3) {
                Label {
                    Text(effect.category.title, language)
                } icon: {
                    Image(systemName: effect.category.symbol)
                        .fixedSymbolLocale()
                        .foregroundStyle(LinearGradient(colors: effect.category.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(isLarge ? 2 : 1)
                Text(effect.name, language)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(isLarge ? 3 : 1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)
        }
        .padding(10)
        .frame(width: FeaturedMetrics.cardWidth, alignment: .leading)
        .background {
            // The snapped card lifts: its shadow deepens as it settles into focus.
            GlossCardBackground(cornerRadius: CornerRadius.featuredCard, tint: effect.category.gradient.first, lifted: isFocused)
                .animation(.smooth(duration: 0.45), value: isFocused)
        }
        .contentShape(shape)
    }
}

/// Small card used in the "Recently Viewed" row.
private struct CompactEffectCard: View {
    let effect: Effect
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PreviewStage(effect: effect, cornerRadius: CornerRadius.compactThumbnail)
                .frame(width: 128, height: 128)
            Text(effect.name, language)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 128, alignment: .leading)
                .padding(.horizontal, 2)
        }
        .padding(8)
        .glossCard(cornerRadius: CornerRadius.section)
    }
}

private struct CategoryTile: View {
    let category: EffectCategory
    let count: Int
    let familyCount: Int
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CategoryIcon(category: category)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title, language)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    .minimumScaleFactor(0.8)
                // "6 families · 17 effects"
                Text(verbatim: Strings.familiesAndEffects(families: familyCount, effects: count, language))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Palette.accent)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.8)
            }
            Text(category.subtitle, language)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 6 : 2, reservesSpace: !dynamicTypeSize.isAccessibilitySize)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The pressable tile style draws (and compresses) the shadow.
        .glossCard(cornerRadius: CornerRadius.section, tint: category.gradient.first, shadow: false)
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.section, style: .continuous))
    }
}

/// A category page. By default it lists the category's families (each with a live 3-up preview strip);
/// the "All Effects" segment shows the flat grid with the interaction filter chips.
struct CategoryView: View {
    let category: EffectCategory
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var chipNamespace
    @AppStorage("app.categoryMode") private var mode: CategoryBrowseMode = .families
    @State private var interaction: EffectInteraction?
    @State private var iconBounce = 0

    private var allEffects: [Effect] { EffectLibrary.effects(in: category) }

    private var effects: [Effect] {
        allEffects.filter { interaction == nil || $0.interaction == interaction }
    }

    private var availableInteractions: [EffectInteraction] {
        let used = Set(allEffects.map(\.interaction))
        return EffectInteraction.allCases.filter { used.contains($0) }
    }

    var body: some View {
        let all = allEffects
        let families = EffectFamilies.families(in: category)
        let showsFamilies = mode == .families
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(effectCount: all.count, familyCount: families.count)
                modePicker(effectCount: all.count, familyCount: families.count)
                    .padding(.horizontal)
                    .appearEntrance(index: 2, distance: 10, blur: 0)
                if showsFamilies {
                    familyList(families)
                        .transition(.opacity)
                } else {
                    allEffectsSection(all: all)
                        .transition(.opacity)
                }
            }
            .padding(.vertical)
            .animation(reduceMotion ? Animation.easeInOut(duration: 0.2) : ShellMotion.reveal, value: showsFamilies)
        }
        .shellPageScroll()
        .background(Palette.pageBackground)
        .navigationTitle(category.title(language))
        .task {
            // The badge greets you once the push has settled.
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            iconBounce += 1
        }
    }

    private func header(effectCount: Int, familyCount: Int) -> some View {
        HStack(alignment: .center, spacing: 14) {
            CategoryIcon(category: category, size: 52, bounce: iconBounce)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: Strings.familiesAndEffects(families: familyCount, effects: effectCount, language))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(category.subtitle, language)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .appearEntrance(index: 1, distance: 8)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private func modePicker(effectCount: Int, familyCount: Int) -> some View {
        ShellSegmentedControl(
            label: Strings.browseMode(language),
            segments: [
                ShellSegmentedControl<CategoryBrowseMode>.Segment(
                    value: .families,
                    title: "\(CategoryBrowseMode.families.title(language)) \(familyCount)"
                ),
                ShellSegmentedControl<CategoryBrowseMode>.Segment(
                    value: .all,
                    title: "\(CategoryBrowseMode.all.title(language)) \(effectCount)"
                ),
            ],
            selection: $mode
        )
    }

    // MARK: Families

    private var familyColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 14)]
            : [GridItem(.adaptive(minimum: 300), spacing: 14)]
    }

    private func familyList(_ families: [EffectFamily]) -> some View {
        LazyVGrid(columns: familyColumns, spacing: 14) {
            ForEach(Array(families.enumerated()), id: \.element.id) { index, family in
                let members = EffectFamilies.effects(in: family)
                ZoomRouteLink(route: Route.family(family.id, source: "familyCard"), cornerRadius: CornerRadius.card) {
                    FamilyCard(family: family, effects: members)
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel(Text(verbatim: "\(family.name(language))\(Strings.listSeparator(language))\(Strings.variationCount(members.count, language))"))
                .accessibilityHint(Text(family.summary, language))
                .appearEntrance(index: index, delay: 0.12, distance: 22, scale: 0.96, blur: 0)
                .scrollReveal(blur: 0)
                // The first two cards' stills render ahead of the rest.
                .environment(\.urgentSnapshots, index < 2)
            }
        }
        .padding(.horizontal)
    }

    // MARK: All effects

    private func allEffectsSection(all: [Effect]) -> some View {
        let interactions = availableInteractions
        return VStack(alignment: .leading, spacing: 16) {
            // A filter with a single option would only ever show everything.
            if interactions.count > 1 {
                interactionFilter(all: all, interactions: interactions)
            }
            EffectGrid(effects: effects)
                .padding(.horizontal)
                .animation(.smooth, value: interaction)
        }
    }

    private func interactionFilter(all: [Effect], interactions: [EffectInteraction]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: Strings.all(language), count: all.count, isSelected: interaction == nil, namespace: chipNamespace) {
                    interaction = nil
                }
                ForEach(interactions) { item in
                    Chip(title: item.title(language),
                         symbol: item.symbol,
                         count: all.filter { $0.interaction == item }.count,
                         isSelected: interaction == item,
                         namespace: chipNamespace) {
                        interaction = interaction == item ? nil : item
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}
