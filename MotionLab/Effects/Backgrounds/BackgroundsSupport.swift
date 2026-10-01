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

// MARK: - Part B helpers

/// An sRGB triple for per-frame colour maths inside Canvas painters (mixing, ramps, shading).
struct BackgroundRGB {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    func mix(_ other: BackgroundRGB, _ t: Double) -> BackgroundRGB {
        let u = min(max(t, 0), 1)
        return BackgroundRGB(r + (other.r - r) * u, g + (other.g - g) * u, b + (other.b - b) * u)
    }

    /// Multiplies the brightness (shading a face of a solid, darkening a reflection).
    func scaled(_ k: Double) -> BackgroundRGB {
        BackgroundRGB(min(r * k, 1), min(g * k, 1), min(b * k, 1))
    }

    func color(_ opacity: Double = 1) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Piecewise-linear ramp through `stops` for `t` in 0...1.
    static func ramp(_ stops: [BackgroundRGB], _ t: Double) -> BackgroundRGB {
        guard let first = stops.first else { return BackgroundRGB(0, 0, 0) }
        guard stops.count > 1 else { return first }
        let x = min(max(t, 0), 1) * Double(stops.count - 1)
        let i = min(Int(x), stops.count - 2)
        return stops[i].mix(stops[i + 1], x - Double(i))
    }
}

extension BackgroundMath {
    /// Integer lattice hash in 0..<1.
    static func hash(_ x: Int, _ y: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFFFF) / Double(0x1000000)
    }

    /// Smooth 2D value noise in 0...1 (bilinear blend of lattice hashes with a smoothstep fade).
    static func valueNoise(_ x: Double, _ y: Double) -> Double {
        let xf = x.rounded(.down)
        let yf = y.rounded(.down)
        let fx = x - xf
        let fy = y - yf
        let u = fx * fx * (3 - 2 * fx)
        let v = fy * fy * (3 - 2 * fy)
        let ix = Int(xf)
        let iy = Int(yf)
        let a = hash(ix, iy)
        let b = hash(ix + 1, iy)
        let c = hash(ix, iy + 1)
        let d = hash(ix + 1, iy + 1)
        return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v
    }
}

extension GraphicsContext {
    /// A soft radial glow (colour → transparent), optionally flattened vertically.
    func backgroundsGlow(at centre: CGPoint, radius: CGFloat, color: Color, squash: CGFloat = 1) {
        guard radius > 0 else { return }
        var copy = self
        copy.translateBy(x: centre.x, y: centre.y)
        copy.scaleBy(x: 1, y: squash)
        copy.fill(
            Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(Gradient(colors: [color, color.opacity(0)]), center: .zero, startRadius: 0, endRadius: radius)
        )
    }
}

/// A point that follows the finger on a spring and wanders along an idle path when nothing touches the
/// stage, so a touch-driven background keeps demonstrating its response in previews through the same code.
final class BackgroundPointer {
    var touch: CGPoint?
    var userTouched = false
    private(set) var point = CGPoint(x: 170, y: 170)
    private(set) var velocity = CGVector.zero
    /// Eased 0 (idle) → 1 (finger down).
    private(set) var presence: Double = 0
    private var last: Double?
    private var seeded = false

    @discardableResult
    func step(now: Double, idle: CGPoint, stiffness: CGFloat = 60, damping: CGFloat = 0.6, frozen: Bool = false) -> CGPoint {
        if frozen {
            point = idle
            return point
        }
        let target = touch ?? idle
        if !seeded {
            seeded = true
            point = target
        }
        var dt = 1.0 / 60.0
        if let last = last { dt = min(max(now - last, 0), 1.0 / 30.0) }
        last = now
        (point, velocity) = BackgroundMath.spring(
            value: point, velocity: velocity, target: target, stiffness: stiffness, damping: damping, dt: CGFloat(dt)
        )
        presence += ((touch == nil ? 0 : 1) - presence) * (1 - exp(-dt * 6))
        return point
    }

    /// Idle strength blended up to 1 while a finger is down.
    func strength(idle: Double) -> Double {
        idle + (1 - idle) * presence
    }
}

extension View {
    /// Dark ink on a frosted chip, for the bright backgrounds. Hidden in previews.
    func backgroundsLightChipHint(_ text: LocalizedText, _ ctx: DemoContext) -> some View {
        overlay(alignment: .bottom) {
            if !ctx.isPreview {
                Text(text, ctx.language)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x1E2440).opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.6), in: Capsule())
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
    }
}
