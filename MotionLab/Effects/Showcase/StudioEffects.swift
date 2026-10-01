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
