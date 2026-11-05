import SwiftUI

@main
struct MotionLabApp: App {
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = AppLanguage.systemDefault
    @AppStorage("app.appearance") private var appearance: Int = 0
    @State private var favorites = FavoritesStore()
    @State private var recents = RecentsStore()
    @State private var navigator = AppNavigator()

    init() {
        // First launch: follow the device language (zh* → 中文, otherwise English) and remember it.
        AppLanguage.registerInitialChoice()
        // "Animate previews" has no registered default: until someone flips the toggle it follows the
        // window's width class (`AnimatePreviews.isOn`), so it changes as an iPhone Duo folds and unfolds.
        if CatalogTools.shouldExport {
            CatalogTools.exportCatalog()
        }
        if CatalogTools.isTrailer {
            // The trailer only simulates touches: never fire a haptic.
            Haptics.isMuted = true
        }
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .environment(favorites)
                .environment(recents)
                .environment(navigator)
                .preferredColorScheme(colorScheme)
                .tint(Palette.accent)
                .onOpenURL { navigator.open($0) }
                .onAppear {
                    PerfLog.start()
                    LaunchWarmup.run()
                }
                .task {
                    // CI: measure every still thumbnail once the window is up (see `CatalogTools`).
                    if CatalogTools.shouldAuditStills {
                        await CatalogTools.auditStills()
                    }
                }
        }
    }

    /// CI video capture renders a single effect (or the promo trailer); everything else gets the full app.
    @ViewBuilder private var rootContent: some View {
        if PerfLog.enabled && UserDefaults.standard.bool(forKey: "ML_bench") {
            PreviewBench()
        } else if CatalogTools.isTrailer {
            TrailerView()
        } else if let stageID = CatalogTools.stageEffectID {
            StageOnlyView(effectID: stageID)
        } else {
            RootView()
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}

@Observable
final class FavoritesStore {
    private static let key = "app.favorites"

    private(set) var ids: [String]

    init() {
        ids = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    var count: Int { ids.count }

    func toggle(_ id: String) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.insert(id, at: 0)
        }
        UserDefaults.standard.set(ids, forKey: Self.key)
    }

    var effects: [Effect] { ids.compactMap { EffectLibrary.effect(id: $0) } }
}
