import SwiftUI

// Shared helpers for the Backgrounds category. Names are prefixed to stay unique across the app.

/// Deterministic pseudo-random helpers: every particle derives its look and motion from its index,
/// so demos need no per-particle state and stay perfectly stable across frames.
enum BackgroundMath {
    /// Fractional part, always in 0..<1 (also for negative inputs).
    static func fract(_ x: Double) -> Double {
        x - x.rounded(.down)
    }

    /// Stable pseudo-random value in 0..<1 for an index and a salt.
    static func rand(_ index: Int, _ salt: Int = 0) -> Double {
        let seed = sin(Double(index) * 12.9898 + Double(salt) * 78.233 + 0.5) * 43758.5453
        return fract(seed)
    }

    /// Same as `rand`, as a CGFloat.
    static func unit(_ index: Int, _ salt: Int = 0) -> CGFloat {
        CGFloat(rand(index, salt))
    }

    static let tau: Double = .pi * 2
}

// `MotionFrameRate` lives in Core/DemoKit.swift (it is shared by every category).

/// Accumulates speed-scaled time, so changing a speed parameter (or easing it) never makes a loop jump.
final class BackgroundClock {
    private var last: Double?
    private(set) var phase: Double
    /// Real seconds elapsed during the last `advance` call (clamped).
    private(set) var delta: Double = 0

    init(start: Double = 100) {
        phase = start
    }

    @discardableResult
    func advance(to now: Double, speed: Double) -> Double {
        if let last = last {
            delta = min(max(now - last, 0), 1.0 / 20.0)
        } else {
            delta = 0
        }
        last = now
        phase += delta * speed
        return phase
    }

    /// Frame-rate independent exponential smoothing factor for the last frame.
    func follow(rate: Double) -> Double {
        1 - exp(-delta * rate)
    }
}

/// A small sample headline laid over a background so it reads in context.
struct BackgroundSampleTitle: View {
    let title: LocalizedText
    let subtitle: LocalizedText
    let language: AppLanguage
    var color: Color = .white
    var size: CGFloat = 30

    var body: some View {
        VStack(spacing: 6) {
            Text(title, language)
                .font(.system(size: size, weight: .bold, design: .rounded))
            Text(subtitle, language)
                .font(.subheadline.weight(.medium))
                .opacity(0.78)
        }
        .foregroundStyle(color)
        .multilineTextAlignment(.center)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(.horizontal, 24)
        .allowsHitTesting(false)
    }
}

extension View {
    /// Bottom hint that stays legible on the (mostly dark) background demos. Hidden in previews.
    func backgroundsHint(_ text: LocalizedText, _ ctx: DemoContext) -> some View {
        overlay(alignment: .bottom) {
            DemoHint(text: text, ctx: ctx)
                .padding(.bottom, 14)
                .environment(\.colorScheme, .dark)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Bottom hint on a dark chip, for backgrounds too busy or too bright for plain caption text. Hidden in previews.
    func backgroundsChipHint(_ text: LocalizedText, _ ctx: DemoContext) -> some View {
        overlay(alignment: .bottom) {
            if !ctx.isPreview {
                Text(text, ctx.language)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Stage-wide touch tracking for ambient backgrounds that never traps the page's vertical scroll:
/// the drag is attached *simultaneously*, so the page's scroll view always keeps vertical swipes, and it only
/// engages after 10 pt of mostly horizontal travel (then follows the finger in any direction).
/// A `@GestureState` flag resets on system cancellation too (Control Center pull, scroll takeover, multi-touch),
/// so `onEnded` always runs and no demo is left holding a touch. A plain tap "pokes" the stage: the touch is
/// reported for a moment, then released.
private struct BackgroundsTouchModifier: ViewModifier {
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void
    @State private var engaged = false
    @State private var pokeToken = 0
    @GestureState private var touching = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(drag)
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in poke(at: value.location) }
            )
            .onChange(of: touching) { _, isTouching in
                if !isTouching { release() }
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if !engaged {
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    engaged = true
                }
                pokeToken += 1
                onChanged(value.location)
            }
            .onEnded { _ in release() }
    }

    /// Normal end or cancellation; runs `onEnded` once per engaged drag.
    private func release() {
        guard engaged else { return }
        engaged = false
        onEnded()
    }

    private func poke(at location: CGPoint) {
        pokeToken += 1
        let token = pokeToken
        onChanged(location)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            if token == pokeToken && !engaged { onEnded() }
        }
    }
}

extension View {
    /// See `BackgroundsTouchModifier`: horizontal-first drag plus tap-to-poke, scroll-friendly.
    func backgroundsTouch(onChanged: @escaping (CGPoint) -> Void, onEnded: @escaping () -> Void = {}) -> some View {
        modifier(BackgroundsTouchModifier(onChanged: onChanged, onEnded: onEnded))
    }
}

/// Small deterministic generator (SplitMix64) for demos that seed a scene once: the same seed always
/// gives the same layout, so stills and previews look alike.
struct BackgroundRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform value in 0..<1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// Uniform value in `range`.
    mutating func range(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }
}

extension BackgroundMath {
    /// Hermite smoothstep of `x` between `a` and `b`, clamped to 0...1.
    static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        guard a != b else { return x < a ? 0 : 1 }
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// A 2D spring step (semi-implicit Euler): moves `value` toward `target` with the given stiffness
    /// and damping ratio, returning the new value and velocity.
    static func spring(
        value: CGPoint, velocity: CGVector, target: CGPoint, stiffness: CGFloat, damping: CGFloat, dt: CGFloat
    ) -> (CGPoint, CGVector) {
        let c = 2 * stiffness.squareRoot() * damping
        var v = velocity
        v.dx += (stiffness * (target.x - value.x) - c * v.dx) * dt
        v.dy += (stiffness * (target.y - value.y) - c * v.dy) * dt
        return (CGPoint(x: value.x + v.dx * dt, y: value.y + v.dy * dt), v)
    }
}
