import SwiftUI

/// Everyday "studio" widgets of the "Signature Interactions" category: media, home, health and
/// utility tiles (turntable, voice memo, sun arc, live ticker, compass…) in the same dark glossy style.
/// Each effect lives in its own `Showcase+<Name>.swift` file; shared helpers are below.
enum ShowcaseStudioEffects {
    static let all: [Effect] = [
        .showcaseVinylScrub,
        .showcaseVoiceMemo,
        .showcaseSunArc,
        .showcaseTidePulse,
        .showcaseElevationProfile,
        .showcaseParcelTracker,
        .showcaseFocusTimer,
        .showcaseDimmerLamp,
        .showcaseBreathFlower,
        .showcaseCompassHeading,
        .showcaseReactionTime,
        // Part B
        .showcaseLapTimer,
        .showcaseBatteryWidget,
        .showcaseCalendarAgenda,
        .showcaseStepsRing,
        .showcaseWaterIntake,
        .showcaseMoonPhase,
        .showcasePodcastChapters,
        .showcaseAlbumFlip,
        .showcaseCameraShutter,
        .showcaseZoomDial,
        .showcaseTipSelector,
        .showcaseRideETA,
        .showcaseTurnByTurn,
        .showcaseXPLevel,
    ]
}

// MARK: - Shared studio helpers

/// Drives a simulated finger for previews and the arrival play: calls `step` with 0…1 over `duration`
/// at display rate. Returns `false` when the surrounding task was cancelled (a real finger took over).
@MainActor
func studioScript(_ duration: Double, _ step: @MainActor (Double) -> Void) async -> Bool {
    let start = Date()
    while true {
        if Task.isCancelled { return false }
        let t = min(1, Date().timeIntervalSince(start) / max(duration, 0.01))
        step(t)
        if t >= 1 { return true }
        try? await Task.sleep(for: .seconds(1.0 / 60.0))
    }
}

/// Waits `seconds`; `false` when cancelled.
@MainActor
func studioPause(_ seconds: Double) async -> Bool {
    try? await Task.sleep(for: .seconds(seconds))
    return !Task.isCancelled
}

/// Smoothstep ease for scripted drags.
func studioEase(_ t: Double) -> Double {
    let x = min(max(t, 0), 1)
    return x * x * (3 - 2 * x)
}

/// "m:ss" clock text.
func studioClock(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d", total / 60, total % 60)
}

/// Linear interpolation between two sRGB hex colours.
func studioMix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
    let k = min(max(t, 0), 1)
    func channel(_ shift: UInt32) -> Double {
        let x = Double((a >> shift) & 0xFF)
        let y = Double((b >> shift) & 0xFF)
        return (x + (y - x) * k) / 255
    }
    return Color(.sRGB, red: channel(16), green: channel(8), blue: channel(0), opacity: 1)
}

// MARK: - Part B helpers

/// Standard stage of a studio widget: the card centred on the dark stage, the hint pinned under it.
struct StudioScene<Card: View>: View {
    let hint: LocalizedText
    let ctx: DemoContext
    @ViewBuilder var card: () -> Card

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card()
                Spacer(minLength: 0)
                DemoHint(text: hint, ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A four-point sparkle centred on `c`.
func studioSparkle(at c: CGPoint, radius r: CGFloat) -> Path {
    var p = Path()
    let k = r * 0.2
    p.move(to: CGPoint(x: c.x, y: c.y - r))
    p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
    p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
    return p
}

/// One burst of sparkles flying out of the centre, drawn on a `TimelineView` clock from `start`.
/// `nil` (or a burst that has finished) draws nothing.
struct StudioBurst: View {
    let start: Date?
    var count: Int = 16
    var reach: CGFloat = 70
    var duration: Double = 0.95
    var colors: [Color] = [.white, Signature.accentSoft, Signature.lime, Signature.accent]
    var preview: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start, count > 0 else { return }
                let p = timeline.date.timeIntervalSince(start) / duration
                guard p >= 0, p < 1 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let ease = 1 - pow(1 - p, 3)
                for index in 0..<count {
                    let seed = Double(index)
                    let angle = seed / Double(count) * 2 * .pi + sportHash(seed * 1.7) * 0.7
                    let speed = 0.5 + sportHash(seed * 3.1) * 0.5
                    let distance = Double(reach) * speed * ease
                    let point = CGPoint(
                        x: center.x + CGFloat(cos(angle) * distance),
                        y: center.y + CGFloat(sin(angle) * distance + 16 * p * p)
                    )
                    let twinkle: Double = 0.75 + 0.25 * sin(p * 18 + seed)
                    let size: Double = 2.6 + sportHash(seed * 5.3) * 3.4
                    let shrink: Double = 1 - p * 0.55
                    let radius = CGFloat(size * shrink * twinkle)
                    context.opacity = min(1, (1 - p) * 2.4)
                    context.fill(studioSparkle(at: point, radius: radius), with: .color(colors[index % max(colors.count, 1)]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Three little equalizer bars that keep dancing (the "now playing" glyph).
struct StudioEqualizer: View {
    var color: Color = Signature.accent
    var bars: Int = 3
    var height: CGFloat = 12
    var speed: Double = 1
    var active: Bool = true
    var preview: Bool = false
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !active || isStill)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<bars, id: \.self) { index in
                    let seed = Double(index)
                    let wave = 0.5 + 0.3 * sin(t * (5.2 + seed * 1.7) + seed * 2.1) + 0.2 * sin(t * (9.1 - seed) + seed)
                    Capsule()
                        .fill(color)
                        .frame(width: 2.6, height: max(2.6, height * CGFloat(active ? wave : 0.25)))
                }
            }
            .frame(height: height, alignment: .bottom)
        }
    }
}
