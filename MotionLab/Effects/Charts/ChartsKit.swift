import SwiftUI

// Shared pieces for the chart demos added in round 2 (waterfall, lollipop, range brush, stacked area, …).

/// An array of Doubles SwiftUI can interpolate element by element, so one spring moves a whole series.
struct ChartVector: VectorArithmetic {
    var values: [Double]

    init(_ values: [Double]) { self.values = values }
    init(repeating value: Double, count: Int) { values = Array(repeating: value, count: count) }

    static var zero: ChartVector { ChartVector([]) }

    subscript(index: Int) -> Double {
        get { index >= 0 && index < values.count ? values[index] : 0 }
        set { if index >= 0 && index < values.count { values[index] = newValue } }
    }

    static func + (lhs: ChartVector, rhs: ChartVector) -> ChartVector { combine(lhs, rhs) { $0 + $1 } }
    static func - (lhs: ChartVector, rhs: ChartVector) -> ChartVector { combine(lhs, rhs) { $0 - $1 } }

    mutating func scale(by rhs: Double) {
        for index in values.indices { values[index] *= rhs }
    }

    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

    private static func combine(_ a: ChartVector, _ b: ChartVector, _ op: (Double, Double) -> Double) -> ChartVector {
        let count = max(a.values.count, b.values.count)
        var out = [Double](repeating: 0, count: count)
        for index in 0..<count { out[index] = op(a[index], b[index]) }
        return ChartVector(out)
    }
}

/// A number that passes through every intermediate value while it animates.
struct ChartRollText: View, Animatable {
    var value: Double
    let format: (Double) -> String

    init(value: Double, format: @escaping (Double) -> String) {
        self.value = value
        self.format = format
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(verbatim: format(value)).monospacedDigit()
    }
}

/// sRGB triple for colours that have to blend continuously inside an animation.
struct ChartRGB {
    let r: Double
    let g: Double
    let b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func mixed(_ other: ChartRGB, _ amount: Double) -> ChartRGB {
        let t = min(max(amount, 0), 1)
        return ChartRGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func color(_ opacity: Double = 1) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    static let green = ChartRGB(0x34C77B)
    static let red = ChartRGB(0xFF4D5E)
    static let amber = ChartRGB(0xF5A623)
    static let indigo = ChartRGB(0x6E7BFF)
    static let violet = ChartRGB(0xA46BFF)
    static let pink = ChartRGB(0xFF5FA2)
    static let coral = ChartRGB(0xFF7A5C)
    static let sky = ChartRGB(0x3AC4FF)

    /// Red → amber → green for a tone in -1…1, so a sign flip never passes through mud.
    static func trend(_ tone: Double) -> ChartRGB {
        let t = min(max(tone, -1), 1)
        return t >= 0 ? amber.mixed(green, t) : amber.mixed(red, -t)
    }
}

enum ChartKit {
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 != edge0 else { return x < edge0 ? 0 : 1 }
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Appends a Catmull-Rom curve through `points` (as cubic Béziers). `move` starts a new subpath at the first point.
    static func addSmooth(_ path: inout Path, _ points: [CGPoint], move: Bool = true) {
        guard let first = points.first else { return }
        if move { path.move(to: first) } else { path.addLine(to: first) }
        guard points.count > 1 else { return }
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
    }

    static func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        addSmooth(&path, points)
        return path
    }

    /// Uniform Catmull-Rom resampling of `keys` into `perSegment` steps per interval.
    static func resample(_ keys: [Double], perSegment: Int) -> [Double] {
        guard keys.count > 1, perSegment > 0 else { return keys }
        var out: [Double] = []
        for index in 0..<(keys.count - 1) {
            let p0 = keys[max(index - 1, 0)]
            let p1 = keys[index]
            let p2 = keys[index + 1]
            let p3 = keys[min(index + 2, keys.count - 1)]
            for step in 0..<perSegment {
                let t = Double(step) / Double(perSegment)
                let t2 = t * t
                let t3 = t2 * t
                let a = 2 * p1
                let b = (p2 - p0) * t
                let c = (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                let d = (-p0 + 3 * p1 - 3 * p2 + p3) * t3
                out.append(0.5 * (a + b + c + d))
            }
        }
        out.append(keys[keys.count - 1])
        return out
    }

    /// Linear lookup in a uniformly sampled series; `x` in 0…1.
    static func sample(_ values: [Double], at x: Double) -> Double {
        guard let last = values.last, values.count > 1 else { return values.first ?? 0 }
        let position = min(max(x, 0), 1) * Double(values.count - 1)
        let index = Int(position)
        guard index < values.count - 1 else { return last }
        let t = position - Double(index)
        return values[index] + (values[index + 1] - values[index]) * t
    }

    /// Height (1 → 0) of a ball dropped at `t = 0` that lands and rebounds `bounces` times with the given
    /// restitution; `t` in 0…1 covers the whole fall plus every rebound. Each rebound is a true parabola,
    /// so the ball reflects off the floor instead of sinking through it like a spring would.
    static func bounceHeight(_ t: Double, restitution: Double, bounces: Int = 3) -> Double {
        let e = min(max(restitution, 0), 0.9)
        let count = max(bounces, 1)
        var spans: [Double] = [1]
        for k in 1...count { spans.append(2 * pow(e, Double(k))) }
        let total = spans.reduce(0, +)
        var x = min(max(t, 0), 1) * total
        if x <= 1 { return 1 - x * x }
        x -= 1
        for k in 1...count {
            let span = spans[k]
            if x <= span || k == count {
                guard span > 0.0001 else { return 0 }
                let u = min(x / span, 1) * 2 - 1
                return pow(e, Double(2 * k)) * (1 - u * u)
            }
            x -= span
        }
        return 0
    }

    /// Fraction of the bounce timeline at which the first impact happens.
    static func firstImpact(restitution: Double, bounces: Int = 3) -> Double {
        let e = min(max(restitution, 0), 0.9)
        var total = 1.0
        for k in 1...max(bounces, 1) { total += 2 * pow(e, Double(k)) }
        return 1 / total
    }

    /// Squash (0…~0.2) while the ball touches the floor, fading out as it comes to rest.
    static func bounceSquash(_ t: Double, restitution: Double) -> Double {
        let h = bounceHeight(t, restitution: restitution)
        let fallen = t > 0.0001 && t < 0.999
        guard fallen else { return 0 }
        return max(0, 1 - h / 0.045) * 0.2 * (1 - t)
    }
}

/// Centres a chart card on the stage with its hint underneath (the hint is hidden in previews).
struct ChartStage<Content: View>: View {
    let hint: LocalizedText?
    let ctx: DemoContext
    let content: Content

    init(hint: LocalizedText?, ctx: DemoContext, @ViewBuilder content: () -> Content) {
        self.hint = hint
        self.ctx = ctx
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 10) {
            content
            if let hint {
                ChartTapCue(text: hint, ctx: ctx)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Runs `body(0…steps-1)` on the main actor with `gap` seconds between steps. Each step is its own
/// transaction, so every element of a `ChartVector` gets its own spring.
@MainActor
func chartSequence(steps: Int, gap: Double, first: Double = 0, _ body: @escaping @MainActor (Int) -> Void) -> Task<Void, Never> {
    Task { @MainActor in
        if first > 0 { try? await Task.sleep(for: .seconds(first)) }
        for step in 0..<steps {
            guard !Task.isCancelled else { return }
            body(step)
            if gap > 0 { try? await Task.sleep(for: .seconds(gap)) }
        }
    }
}

/// Sets state with animations disabled (the reset half of a replay).
@MainActor
func chartInstant(_ body: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, body)
}
