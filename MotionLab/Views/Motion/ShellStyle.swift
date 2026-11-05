import CoreImage
import SwiftUI

// MARK: - Glossy widget card

/// Surface of every shell card (effect cards, family cards, category tiles, detail sections).
///
/// - Dark mode: a glossy widget card like the Signature demos: a top-lit near-black gradient,
///   a 0.5 pt rim light that fades down the sides, an optional faint tinted glow in the
///   top-trailing corner and a deep, soft shadow on the ink page.
/// - Light mode: clean white with a hairline that darkens slightly towards the bottom edge and a
///   soft, wide shadow, so cards read as gently elevated rather than flat slabs.
///
/// Shapes only, and the shadow is a pre-blurred, stretchable image (`ShadowPlate`): a SwiftUI `.shadow` is
/// re-blurred every frame while anything in the same layer animates, and a grid of cards around live demos
/// then costs one large blur per card per frame (measured on an A12X iPad: the grid lost ~20 % of its
/// frames to it). The image is drawn once per style and only copied afterwards.
struct GlossCardBackground: View {
    var cornerRadius: CGFloat
    /// Faint radial glow in the top-trailing corner (e.g. the category colour).
    var tint: Color? = nil
    /// Focused / featured cards cast a deeper shadow.
    var lifted = false
    /// The card moves between resting and `lifted` (Featured): both shadows are mounted and cross-fade.
    var liftable = false
    /// Off when the enclosing button style already draws a (pressable) shadow.
    var shadow = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let dark = colorScheme == .dark
        let glowOpacity: Double = dark ? 0.2 : 0.1
        shape
            .fill(dark ? GlossTokens.darkFill : GlossTokens.lightFill)
            .overlay {
                if let tint {
                    shape.fill(
                        RadialGradient(
                            colors: [tint.opacity(glowOpacity), tint.opacity(0)],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(dark ? GlossTokens.darkRim : GlossTokens.lightRim, lineWidth: 0.5)
            }
            .background {
                if shadow && liftable {
                    // Both shadows stay mounted and only their opacities change, so lifting or settling a card
                    // animates in the compositor. Swapping one plate for the other re-laid the card out on
                    // every frame of the lift, which was most of the Featured row's cost on an unfolded
                    // iPhone Duo (5% of frame time lost in an automated sweep of the row, 0–1% with this).
                    ZStack {
                        ShadowPlate(cornerRadius: cornerRadius, radius: dark ? 16 : 12, opacity: dark ? 0.45 : 0.06)
                            .offset(y: 6)
                            .opacity(lifted ? 0 : 1)
                        ShadowPlate(cornerRadius: cornerRadius, radius: 22, opacity: dark ? 0.62 : 0.13)
                            .offset(y: 12)
                            .opacity(lifted ? 1 : 0)
                    }
                } else if shadow {
                    if lifted {
                        ShadowPlate(cornerRadius: cornerRadius, radius: 22, opacity: dark ? 0.62 : 0.13)
                            .offset(y: 12)
                    } else {
                        ShadowPlate(cornerRadius: cornerRadius, radius: dark ? 16 : 12, opacity: dark ? 0.45 : 0.06)
                            .offset(y: 6)
                    }
                }
            }
    }
}

/// A rounded rectangle's soft drop shadow as a nine-slice image: blurred once per (corner, radius,
/// opacity, scale), then stretched to any card size. Matches `.shadow(color: .black.opacity(opacity),
/// radius: radius)` around an opaque shape.
struct ShadowPlate: View {
    let cornerRadius: CGFloat
    let radius: CGFloat
    let opacity: Double
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let plate = ShadowPlateCache.plate(cornerRadius: cornerRadius, radius: radius, opacity: opacity, scale: displayScale)
        Image(uiImage: plate.image)
            .resizable(capInsets: plate.insets, resizingMode: .stretch)
            .padding(-plate.pad)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

@MainActor
private enum ShadowPlateCache {
    struct Plate {
        let image: UIImage
        let insets: EdgeInsets
        let pad: CGFloat
    }

    private static var plates: [String: Plate] = [:]

    static func plate(cornerRadius: CGFloat, radius: CGFloat, opacity: Double, scale: CGFloat) -> Plate {
        let key = "\(cornerRadius)|\(radius)|\(opacity)|\(scale)"
        if let plate = plates[key] { return plate }
        // The blur reaches about 3 sigma; SwiftUI's shadow radius is about 2 sigma.
        let pad: CGFloat = (radius * 1.6).rounded(.up)
        // Wide enough that the middle of each edge is a full-strength edge profile (6 sigma = 3 × radius).
        let core: CGFloat = max(cornerRadius * 2, radius * 3).rounded(.up) + 2
        let side: CGFloat = core + pad * 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let shape = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let rect = CGRect(x: pad, y: pad, width: core, height: core)
            UIColor.black.withAlphaComponent(opacity).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).fill()
        }
        // The shadow is the shape blurred (sigma = radius / 2, as SwiftUI's), so the part below an offset card
        // fades out exactly like `.shadow`.
        var image = shape
        if let input = CIImage(image: shape) {
            let blurred = input.clampedToExtent()
                .applyingGaussianBlur(sigma: Double(radius / 2 * scale))
                .cropped(to: input.extent)
            if let cgImage = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(blurred, from: input.extent) {
                image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
            }
        }
        let inset: CGFloat = pad + (core - 2) / 2
        let plate = Plate(image: image, insets: EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset), pad: pad)
        plates[key] = plate
        return plate
    }
}

private enum GlossTokens {
    static let darkFill = LinearGradient(
        colors: [Color(hex: 0x1D1D22), Color(hex: 0x131316)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let lightFill = LinearGradient(
        colors: [Color.white, Color(hex: 0xFCFCFD)],
        startPoint: .top,
        endPoint: .bottom
    )
    /// Top-lit rim: bright along the top edge, fading out over the first ~40 % of the sides.
    static let darkRim = LinearGradient(
        stops: [
            Gradient.Stop(color: Color.white.opacity(0.17), location: 0),
            Gradient.Stop(color: Color.white.opacity(0.06), location: 0.4),
            Gradient.Stop(color: Color.white.opacity(0.03), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let lightRim = LinearGradient(
        colors: [Color.black.opacity(0.05), Color.black.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension View {
    /// Places a `GlossCardBackground` behind the view.
    func glossCard(
        cornerRadius: CGFloat = CornerRadius.card,
        tint: Color? = nil,
        lifted: Bool = false,
        shadow: Bool = true
    ) -> some View {
        background {
            GlossCardBackground(cornerRadius: cornerRadius, tint: tint, lifted: lifted, shadow: shadow)
        }
    }
}

// MARK: - Stage rim

/// Inner edge of a demo stage: a 1 pt top-lit rim in dark mode, so dark demos keep a visible edge on
/// dark cards; a faint hairline in light mode.
struct StageRim: View {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if colorScheme == .dark {
            shape.strokeBorder(StageRimTokens.dark, lineWidth: 1)
        } else {
            shape.strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        }
    }
}

private enum StageRimTokens {
    static let dark = LinearGradient(
        colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Segmented control

/// Capsule segmented control whose ember selection pill glides between segments (matched
/// geometry) on the shell's selection spring. Replaces the stock segmented `Picker` so view-mode
/// switches match the chip rows. Each segment is a button with the selected trait for VoiceOver.
struct ShellSegmentedControl<Value: Hashable>: View {
    struct Segment {
        let value: Value
        let title: String
    }

    /// Accessibility name of the whole control.
    let label: String
    let segments: [Segment]
    @Binding var selection: Value
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments.indices, id: \.self) { index in
                segmentButton(segments[index])
            }
        }
        .padding(3)
        .background(Palette.chipOnPage, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.edge))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: label))
    }

    private func segmentButton(_ segment: Segment) -> some View {
        let isSelected = segment.value == selection
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : ShellMotion.selection
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            withAnimation(animation) { selection = segment.value }
        } label: {
            Text(verbatim: segment.title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Palette.onAccent : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Palette.accentFill)
                            .shadow(color: Palette.accentGlow, radius: 6, y: 3)
                            .matchedGeometryEffect(id: "segment.pill", in: pill)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Glass circle

/// Small round glass button surface: Liquid Glass on iOS 26, a material disc with a rim before.
struct GlassCircleBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Palette.edge))
            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
    }
}

// MARK: - Scroll pages

/// Bottom breathing room on every scrolling page, on top of the tab bar's own safe-area inset, so
/// the last card never sits flush against the floating tab bar.
enum ShellLayout {
    static let bottomMargin: CGFloat = 28
}

/// Pauses still-frame rendering (`SnapshotGate`) while this scroll view moves, so an
/// `ImageRenderer` pass never lands in a scrolling frame.
private struct SnapshotScrollPause: ViewModifier {
    @State private var token = UUID()

    func body(content: Content) -> some View {
        let token = self.token
        return content
            .onScrollPhaseChange { _, phase in
                if case .idle = phase {
                    SnapshotGate.endScroll(token)
                } else {
                    SnapshotGate.beginScroll(token)
                }
            }
            .onDisappear { SnapshotGate.endScroll(token) }
    }
}

extension View {
    /// Apply to a scroll view: stills wait until it stops moving.
    func pausesSnapshotsWhileScrolling() -> some View {
        modifier(SnapshotScrollPause())
    }

    /// Standard page scroll view setup: bottom breathing room above the tab bar and no still
    /// rendering while scrolling.
    func shellPageScroll() -> some View {
        self
            .contentMargins(.bottom, ShellLayout.bottomMargin, for: .scrollContent)
            .pausesSnapshotsWhileScrolling()
    }
}

// MARK: - Symbols

extension View {
    /// Draws SF Symbols with their base (English) artwork. Some symbols localize (e.g. `textformat`
    /// becomes "格式" under zh-Hans), which changes their meaning and repeats the label next to them.
    /// Apply to an `Image(systemName:)` only; text must keep the app's locale.
    func fixedSymbolLocale() -> some View {
        environment(\.locale, Locale(identifier: "en"))
    }
}

// MARK: - Dim press

/// Press feedback for full-width rows and headers that must not change size (e.g. a section header
/// pinned over scrolling content): a quick dim, no scale.
struct PressDimStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(configuration.isPressed ? ShellMotion.pressDown : ShellMotion.pressUp, value: configuration.isPressed)
    }
}
