import SwiftUI

/// Ski / outdoor dashboard entries of the "Signature Interactions" category.
/// Each effect lives in its own `Sport+<Name>.swift` file; shared sport-only helpers are below.
enum ShowcaseSportEffects {
    static let all: [Effect] = [
        Effect.showcaseSlideToStart,
        Effect.showcaseSpeedLine,
        Effect.showcaseFreshSnow,
        Effect.showcaseBoardCard,
        Effect.showcaseBestLine,
        Effect.showcasePhotoPlay,
        Effect.showcaseSpotsGrid,
        Effect.showcaseGoCountdown,
        Effect.showcaseSummitBadge,
        Effect.showcaseAltitudeRuler,
        Effect.showcaseLiftStatus,
        Effect.showcaseHeartZone,
        Effect.showcaseRunSummary,
        Effect.showcaseWeatherWidget,
        Effect.showcaseGearChecklist,
    ]
}

// MARK: - Shared sport helpers

/// Press feedback used by tappable showcase cards: sink + dim on touch-down, springy release.
struct SportPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var dim: Double = 0.08

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -dim : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// Makes a whole signature card one button with the category's touch-down sink (98 %, slight dim),
    /// so the card answers the finger before the tap ends.
    func sportCardTap(cornerRadius: CGFloat = 26, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self
                .foregroundStyle(Color.white)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(SportPressStyle(scale: 0.98, dim: 0.04))
    }
}

/// Eyebrow row: optional orange glyph, uppercase title, optional trailing caption.
struct SportEyebrowRow: View {
    let title: String
    var symbol: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(Signature.accent)
            }
            Text(title)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
            }
        }
        .signatureEyebrow()
    }
}

/// A small "live" dot with a ring that keeps pulsing outward.
struct SportLiveDot: View {
    var color: Color = Signature.accent
    var size: CGFloat = 8
    var period: Double = 1.4
    /// Grid previews tick at 30 fps (see `MotionFrameRate`).
    var preview: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview))) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let p = CGFloat(t.truncatingRemainder(dividingBy: period) / period)
            ZStack {
                Circle()
                    .stroke(color.opacity(Double(1 - p)), lineWidth: 1.5)
                    .frame(width: size, height: size)
                    .scaleEffect(1 + p * 1.8)
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.8), radius: 4)
            }
        }
        .frame(width: size * 3, height: size * 3)
    }
}

/// Deterministic pseudo-random value in 0..<1 for procedural drawing.
func sportHash(_ x: Double) -> Double {
    let n = sin(x * 12.9898 + 78.233) * 43758.5453
    return n - n.rounded(.down)
}
