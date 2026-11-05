import SwiftUI

enum Route: Hashable {
    /// `source` (here and on `.family`) names the placement of a zoom-source link, e.g. "tile" or
    /// "familyCard"; empty pushes without a zoom source.
    case category(EffectCategory, source: String = "")
    /// A family of variations (`EffectFamily.id`), e.g. "inputs.slider".
    case family(String, source: String = "")
    /// Every family, grouped by category (`source` as for `.family`).
    case families(source: String = "")
    /// `source` names the placement the link lives in (e.g. "featured", "recent", "grid") so the
    /// zoom transition's source id is unique even when one effect is visible in two places at once.
    /// An empty source (dice, launch arguments) pushes without a zoom source.
    case effect(String, source: String = "")

    /// Id shared by `matchedTransitionSource` and `.zoom(sourceID:)`.
    static func zoomID(effect id: String, source: String) -> String { "\(source)/\(id)" }

    /// The screen this route shows, ignoring where the link lives ("family:inputs.slider").
    var destination: String {
        switch self {
        case .category(let category, _): return "category:\(category.rawValue)"
        case .family(let id, _): return "family:\(id)"
        case .families(_): return "families"
        case .effect(let id, _): return "effect:\(id)"
        }
    }

    /// Placement of the link that opened this route ("" when it has no zoom source).
    var source: String {
        switch self {
        case .category(_, let source), .family(_, let source), .effect(_, let source), .families(let source): return source
        }
    }

    /// Zoom id for this route's source link (effects keep their historic "<source>/<id>" form).
    var zoomID: String {
        switch self {
        case .effect(let id, let source): return Route.zoomID(effect: id, source: source)
        default: return Route.zoomID(effect: destination, source: source)
        }
    }
}

/// The path of one tab's NavigationStack. Links that point back at a screen already on the stack
/// (a detail page's category chip, a family page's category link, …) pop back to it instead of
/// pushing another copy, so detail → family → detail → family never grows the stack.
/// An effect opened from another effect's page (More in This Category) replaces that page, so
/// exploring related effects keeps the stack at "list → one detail" and Back returns to the list.
@Observable
final class StackRouter {
    var path: [Route] = []

    func open(_ route: Route) {
        let key = route.destination
        if let index = path.lastIndex(where: { $0.destination == key }) {
            if index < path.count - 1 { path.removeSubrange((index + 1)...) }
        } else if case .effect(let id, _) = route, let last = path.last, case .effect = last {
            // The link lives on the page being replaced, so there is no zoom source to return to.
            path[path.count - 1] = Route.effect(id)
        } else {
            path.append(route)
        }
    }
}

/// A link to a route that pops back when that screen is already on the stack (see `StackRouter`).
/// Style it like a `NavigationLink` (e.g. `.buttonStyle(PressableCardStyle())`).
struct RouteLink<Label: View>: View {
    let route: Route
    @ViewBuilder var label: () -> Label
    @Environment(StackRouter.self) private var router: StackRouter?

    var body: some View {
        if let router {
            Button {
                router.open(route)
            } label: {
                label()
            }
        } else {
            NavigationLink(value: route) { label() }
        }
    }
}

/// Marks a view as the zoom-transition source with `id` (when a zoom namespace is available).
struct ZoomSource: ViewModifier {
    let id: String
    @Environment(\.zoomNamespace) private var namespace

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

/// A navigation link that zooms its destination out of `label` (category tiles, family cards).
struct ZoomRouteLink<Label: View>: View {
    let route: Route
    /// Corner radius of a card label, so the zoom back doesn't square off its corners (see `EffectLink`).
    var cornerRadius: CGFloat? = nil
    @ViewBuilder var label: () -> Label
    @Environment(\.zoomNamespace) private var namespace

    var body: some View {
        NavigationLink(value: route) {
            if let namespace, !route.source.isEmpty, let cornerRadius {
                label().matchedTransitionSource(id: route.zoomID, in: namespace) { source in
                    source.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            } else if let namespace, !route.source.isEmpty {
                label().matchedTransitionSource(id: route.zoomID, in: namespace)
            } else {
                label()
            }
        }
    }
}

private struct ZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Namespace used for the iOS 18 zoom navigation transition from cards into detail.
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

/// "Animate previews" (Settings): whether list thumbnails play their demos or show a still frame.
///
/// Until someone flips the toggle, regular-width windows show stills and compact ones play: a regular
/// grid puts 12–20 thumbnails on screen, more live demos than an older iPad keeps at frame rate, and on
/// an iPhone Duo's unfolded inner screen scrolling stuttered with them playing. It follows the width
/// class rather than the device, so a Duo animates when folded and goes still when opened.
enum AnimatePreviews {
    static let key = "app.animatePreviews"

    static func isOn(choice: Bool?, sizeClass: UserInterfaceSizeClass?) -> Bool {
        choice ?? (sizeClass != .regular)
    }
}

struct RootView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppNavigator.self) private var navigator
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(AnimatePreviews.key) private var animatePreviewsChoice: Bool?
    /// The launch intro overlay is mounted.
    @State private var showsIntro = LaunchIntro.shouldPlay
    /// The intro still hides the UI (until its circular reveal starts).
    @State private var introCovers = LaunchIntro.shouldPlay

    var body: some View {
        tabs
            .environment(\.launchIntroActive, introCovers)
            .overlay {
                if showsIntro {
                    LaunchIntroView {
                        introCovers = false
                    } onFinish: {
                        withAnimation(.easeOut(duration: 0.22)) { showsIntro = false }
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                // Reduce Motion may have been read differently by UIKit at launch; SwiftUI's value wins.
                if reduceMotion && showsIntro {
                    showsIntro = false
                    introCovers = false
                    LaunchIntro.didFinish = true
                }
            }
    }

    private var tabs: some View {
        @Bindable var router = navigator
        return TabView(selection: $router.tab) {
            Tab(Strings.browse(language), systemImage: "square.grid.2x2.fill", value: AppTab.browse) {
                RoutedStack(initialPath: LaunchOptions.initialPath, acceptsLinks: true) { BrowseView() }
            }
            Tab(Strings.search(language), systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                RoutedStack(popsToRootOnSearch: true) { SearchView() }
            }
            Tab(Strings.favorites(language), systemImage: "heart.fill", value: AppTab.favorites) {
                RoutedStack { FavoritesView() }
            }
            Tab(Strings.settings(language), systemImage: "gearshape.fill", value: AppTab.settings) {
                RoutedStack { SettingsView() }
            }
        }
        .environment(\.previewMotionEnabled, AnimatePreviews.isOn(choice: animatePreviewsChoice, sizeClass: sizeClass) && !reduceMotion)
        // iOS 26: the floating tab bar tucks away while reading down a page.
        .modifier(TabBarMinimizeOnScroll())
        // A light detent tick on every tab switch (tap or programmatic, e.g. a tag search).
        .sensoryFeedback(.selection, trigger: navigator.tab)
    }
}

/// On iOS 26 the floating tab bar minimises while scrolling down; earlier systems are unchanged.
private struct TabBarMinimizeOnScroll: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Launch arguments used for automated screenshots, e.g.
/// `-ML_route effect:shader.ripple`, `-ML_route category:buttons`, `-ML_route family:inputs.slider`,
/// `-ML_route families`, `-ML_tab 3`, `-ML_anchor prompt`, `-ML_freshState YES` (no recents are read
/// or written, so every launch starts from the same Browse page).
/// (`-app.language en` / `-app.appearance 2` / `-app.familyMode compare` also work because
/// @AppStorage reads the argument domain.)
/// Intentionally available in every build configuration.
enum LaunchOptions {
    static var initialTab: AppTab { AppTab(rawValue: UserDefaults.standard.integer(forKey: "ML_tab")) ?? .browse }

    static var initialPath: [Route] {
        guard let raw = UserDefaults.standard.string(forKey: "ML_route") else { return [] }
        return route(from: raw).map { [$0] } ?? []
    }

    /// Parses "effect:<id>", "category:<id>", "family:<id>" or "families"; nil for unknown ids.
    static func route(from raw: String) -> Route? {
        if raw == "families" { return .families() }
        if raw.hasPrefix("effect:") {
            let id = String(raw.dropFirst("effect:".count))
            return EffectLibrary.effect(id: id) == nil ? nil : .effect(id)
        }
        if raw.hasPrefix("category:") {
            return EffectCategory(rawValue: String(raw.dropFirst("category:".count))).map { Route.category($0) }
        }
        if raw.hasPrefix("family:") {
            let id = String(raw.dropFirst("family:".count))
            return EffectFamilies.family(id: id) == nil ? nil : .family(id)
        }
        return nil
    }

    static var detailAnchor: String? { UserDefaults.standard.string(forKey: "ML_anchor") }

    nonisolated(unsafe) private static var anchorTaken = false

    /// `detailAnchor` for the first detail page of the launch only (later pages open at the top).
    static func takeDetailAnchor() -> String? {
        guard !anchorTaken, let anchor = detailAnchor, !anchor.isEmpty else { return nil }
        anchorTaken = true
        return anchor
    }

    /// Screenshot runs: start without persisted recents and never record new ones.
    static var freshState: Bool { UserDefaults.standard.bool(forKey: "ML_freshState") }
}

/// A NavigationStack that knows how to show categories, families and effects (with zoom transitions
/// from the link that opened them).
struct RoutedStack<Content: View>: View {
    @Namespace private var namespace
    @State private var router = StackRouter()
    @State private var appliedInitialPath = false
    @Environment(AppNavigator.self) private var navigator
    private let initialPath: [Route]
    private let popsToRootOnSearch: Bool
    private let acceptsLinks: Bool
    private let content: () -> Content

    init(
        initialPath: [Route] = [],
        popsToRootOnSearch: Bool = false,
        acceptsLinks: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.initialPath = initialPath
        self.popsToRootOnSearch = popsToRootOnSearch
        self.acceptsLinks = acceptsLinks
        self.content = content
    }

    var body: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.path) {
            content()
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .environment(\.zoomNamespace, namespace)
        .environment(self.router)
        .task {
            // Launch-argument routes are pushed once the stack and its destinations exist
            // (a path set before the root has registered `navigationDestination` can resolve to
            // SwiftUI's "missing destination" placeholder).
            guard !appliedInitialPath else { return }
            appliedInitialPath = true
            // A `motionlexicon://` link that arrived during launch, before this stack existed.
            let linked: [Route] = acceptsLinks ? navigator.linkedRoute.map { [$0] } ?? [] : []
            let path = linked.isEmpty ? initialPath : linked
            guard !path.isEmpty else { return }
            await Task.yield()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { self.router.path = path }
        }
        .onChange(of: router.path) { _, path in
            PerfLog.log("nav \(path.last?.destination ?? "root")")
        }
        .onChange(of: navigator.searchRevision) {
            if popsToRootOnSearch { self.router.path = [] }
        }
        .onChange(of: navigator.linkRevision) {
            guard acceptsLinks, let route = navigator.linkedRoute else { return }
            self.router.path = [route]
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .category(let category, _):
            CategoryView(category: category)
                .modifier(ZoomDestination(route: route, namespace: namespace))
        case .family(let id, _):
            if let family = EffectFamilies.family(id: id) {
                FamilyView(family: family)
                    .modifier(ZoomDestination(route: route, namespace: namespace))
            }
        case .families(_):
            AllFamiliesView()
                .modifier(ZoomDestination(route: route, namespace: namespace))
        case .effect(let id, _):
            if let effect = EffectLibrary.effect(id: id) {
                EffectDetailView(effect: effect)
                    .modifier(ZoomDestination(route: route, namespace: namespace))
            }
        }
    }
}

/// Zooms a pushed screen out of its source link when the route names one.
private struct ZoomDestination: ViewModifier {
    let route: Route
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if route.source.isEmpty {
            content
        } else {
            content.navigationTransition(.zoom(sourceID: route.zoomID, in: namespace))
        }
    }
}

/// A navigation link to an effect's detail page, acting as the zoom transition's source.
struct EffectLink<Label: View>: View {
    let effect: Effect
    /// Placement name, unique per screen region (see `Route.effect`).
    let source: String
    /// Corner radius of the card the label draws. The zoom transition snapshots its source as a plain
    /// rectangle, so without it the card's corners turn square and black while zooming back in.
    var cornerRadius: CGFloat = CornerRadius.card
    @ViewBuilder var label: () -> Label
    @Environment(\.zoomNamespace) private var namespace
    @Environment(\.appLanguage) private var language
    @Environment(FavoritesStore.self) private var favorites

    @Environment(StackRouter.self) private var router: StackRouter?

    var body: some View {
        let route = Route.effect(effect.id, source: source)
        Group {
            if let router {
                // Through the router: an effect already on the stack pops back to it, and an effect
                // opened from another effect's page replaces it (see `StackRouter.open`).
                Button {
                    router.open(route)
                } label: {
                    sourceLabel
                }
            } else {
                NavigationLink(value: route) { sourceLabel }
            }
        }
        .buttonStyle(PressableCardStyle())
        .effectContextMenu(effect)
        // A link is already one VoiceOver stop; give it "<name>, <category>" and the summary as the hint.
        .accessibilityLabel(Text(verbatim: "\(effect.name(language))\(Strings.listSeparator(language))\(effect.category.title(language))"))
        .accessibilityValue(Text(verbatim: favorites.contains(effect.id) ? Strings.favorited(language) : ""))
        .accessibilityHint(Text(effect.summary, language))
    }

    @ViewBuilder
    private var sourceLabel: some View {
        if let namespace {
            label().matchedTransitionSource(id: Route.zoomID(effect: effect.id, source: source), in: namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            label()
        }
    }
}

/// Tactile press used on every card, chip and pill in the app: a quick spring down-scale with a
/// slight dim, released with a little overshoot. `depth` adds a resting shadow that compresses
/// while pressed; `tilt` leans the top edge back a few degrees, like pressing a physical tile.
/// The label can read `\.isCardPressed` to react (e.g. bounce an icon).
/// With Reduce Motion on, the press is shown as a dim instead of a scale.
struct PressableCardStyle: ButtonStyle {
    var depth: CGFloat = 0
    var tilt = false

    func makeBody(configuration: Configuration) -> some View {
        PressableCardBody(label: configuration.label, isPressed: configuration.isPressed, depth: depth, tilt: tilt)
    }
}

private struct PressableCardBody: View {
    let label: ButtonStyleConfiguration.Label
    let isPressed: Bool
    let depth: CGFloat
    let tilt: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let moves = isPressed && !reduceMotion
        let lean: Double = moves && tilt ? 4 : 0
        label
            .environment(\.isCardPressed, isPressed)
            .modifier(PressDepth(depth: depth, isPressed: isPressed, isDark: colorScheme == .dark))
            .rotation3DEffect(.degrees(lean), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .scaleEffect(moves ? 0.96 : 1)
            .opacity(isPressed && reduceMotion ? 0.7 : 1)
            .animation(isPressed ? ShellMotion.pressDown : ShellMotion.pressUp, value: isPressed)
    }
}

/// Resting elevation that flattens (and a slight dim) while pressed. Only applied when `depth > 0`
/// (tiles), so grid cards with live previews never carry an extra filter or shadow pass.
private struct PressDepth: ViewModifier {
    let depth: CGFloat
    let isPressed: Bool
    let isDark: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if depth > 0 {
            let dim: Double = isPressed ? (isDark ? 0.05 : -0.035) : 0
            // Deeper on the ink page so glossy tiles still float in dark mode.
            // Two pre-blurred plates cross-fade instead of animating a live `.shadow`, which would re-blur the
            // whole tile every frame while anything else on the page animates (see `ShadowPlate`).
            let restOpacity: Double = isDark ? 0.5 : 0.09
            let pressedOpacity: Double = isDark ? 0.3 : 0.05
            content
                .brightness(dim)
                .background {
                    ZStack {
                        ShadowPlate(cornerRadius: CornerRadius.section, radius: depth, opacity: restOpacity)
                            .offset(y: depth * 0.5)
                            .opacity(isPressed ? 0 : 1)
                        ShadowPlate(cornerRadius: CornerRadius.section, radius: depth * 0.35, opacity: pressedOpacity)
                            .offset(y: depth * 0.15)
                            .opacity(isPressed ? 1 : 0)
                    }
                }
        } else {
            content
        }
    }
}
