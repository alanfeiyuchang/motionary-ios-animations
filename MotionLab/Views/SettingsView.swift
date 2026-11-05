import SwiftUI

/// Settings in the shell's card language: glossy sections that rise in one after another, ember
/// segmented controls with a gliding pill, and a tiny live thumbnail next to "Animate previews"
/// that stops when previews are turned off.
struct SettingsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppLanguage.storageKey) private var storedLanguage: AppLanguage = AppLanguage.systemDefault
    @AppStorage("app.appearance") private var appearance: Int = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(AnimatePreviews.key) private var animatePreviewsChoice: Bool?

    /// The toggle shows the current behaviour (the width-class default until it is flipped) and stores an
    /// explicit choice once flipped.
    private var animatePreviews: Binding<Bool> {
        Binding {
            AnimatePreviews.isOn(choice: animatePreviewsChoice, sizeClass: sizeClass)
        } set: {
            animatePreviewsChoice = $0
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Language changes cross-fade the whole window (every label, the tab bar, the prompts).
    private var languageSelection: Binding<AppLanguage> {
        Binding {
            storedLanguage
        } set: { newValue in
            guard newValue != storedLanguage else { return }
            WindowCrossfade.perform { storedLanguage = newValue }
        }
    }

    /// Appearance changes cross-fade too, so light ↔ dark melts instead of snapping.
    private var appearanceSelection: Binding<Int> {
        Binding {
            appearance
        } set: { newValue in
            guard newValue != appearance else { return }
            WindowCrossfade.perform(duration: 0.45) { appearance = newValue }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: Strings.language(language), symbol: "globe") {
                    ShellSegmentedControl(
                        label: Strings.language(language),
                        segments: AppLanguage.allCases.map { item in
                            ShellSegmentedControl<AppLanguage>.Segment(value: item, title: item.displayName)
                        },
                        selection: languageSelection
                    )
                }
                .appearEntrance(index: 0, distance: 14)
                SettingsCard(title: Strings.appearance(language), symbol: "circle.lefthalf.filled") {
                    ShellSegmentedControl(
                        label: Strings.appearance(language),
                        segments: [
                            ShellSegmentedControl<Int>.Segment(value: 0, title: Strings.system(language)),
                            ShellSegmentedControl<Int>.Segment(value: 1, title: Strings.light(language)),
                            ShellSegmentedControl<Int>.Segment(value: 2, title: Strings.dark(language)),
                        ],
                        selection: appearanceSelection
                    )
                }
                .appearEntrance(index: 1, distance: 14)
                SettingsCard(title: Strings.motion(language), symbol: "sparkles") {
                    motionContent
                }
                .appearEntrance(index: 2, distance: 14)
                SettingsCard(title: Strings.about(language), symbol: "info.circle") {
                    aboutContent
                }
                .appearEntrance(index: 3, distance: 14)
            }
            .padding()
            // Comfortable reading width on iPad; centred.
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .shellPageScroll()
        .background(Palette.pageBackground)
        .navigationTitle(Strings.settings(language))
    }

    private var motionContent: some View {
        let playing = animatePreviews.wrappedValue && !reduceMotion
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MotionPreviewGlyph(active: playing)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                // Reduce Motion always wins: show the toggle as off and explain why.
                Toggle(isOn: reduceMotion ? .constant(false) : animatePreviews) {
                    Text(Strings.animatePreviews, language)
                        .font(.body)
                }
                .tint(Palette.ember)
                .disabled(reduceMotion)
                .sensoryFeedback(.impact(weight: .light), trigger: animatePreviews.wrappedValue)
            }
            Text(reduceMotion ? Strings.reduceMotionActive : Strings.animatePreviewsFooter, language)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.aboutBody, language)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // Browsing lives in the Browse tab; Settings only summarises the catalog.
            VStack(spacing: 0) {
                infoRow(Strings.allEffects(language), Strings.effectCount(EffectLibrary.all.count, language))
                Divider()
                infoRow(Strings.categories(language), Strings.categoryCount(EffectCategory.allCases.count, language))
                Divider()
                infoRow(Strings.families(language), Strings.familyCount(EffectFamilies.all.count, language))
                Divider()
                infoRow(Strings.version(language), versionString)
            }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: title)
                .font(.subheadline)
            Spacer(minLength: 8)
            Text(verbatim: value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// A glossy settings section: an ember icon tile and a title above the content.
private struct SettingsCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 30, height: 30)
                    .background(Palette.ember.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                Text(verbatim: title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glossCard(cornerRadius: CornerRadius.section)
    }
}

/// Tiny live thumbnail next to "Animate previews": three ember dots ripple like a spring loader
/// while previews animate, and rest in a line when they are off (or with Reduce Motion).
/// Ticks at 30 fps and only while active.
private struct MotionPreviewGlyph: View {
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            let time: Double = active ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, size in
                let radius: CGFloat = size.width * 0.085
                let baseline: CGFloat = size.height * 0.56
                let reach: CGFloat = size.height * 0.2
                for index in 0..<3 {
                    let cycle: Double = time / 1.2 - Double(index) * 0.14
                    let wave: Double = active ? max(0, sin(cycle * 2 * Double.pi)) : 0
                    let lift: CGFloat = CGFloat(wave) * reach
                    let x: CGFloat = size.width * (0.3 + 0.2 * CGFloat(index))
                    let y: CGFloat = baseline - lift
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    let color: Color = index == 1 ? Palette.emberHot : Palette.ember
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .background(Palette.chipOnCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(StageRim(cornerRadius: 12))
    }
}
