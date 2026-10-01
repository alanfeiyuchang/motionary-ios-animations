import SwiftUI

// Extra shared pieces for the second batch of round-2 chart demos (diverging, pyramid, drill-down, …).

extension ChartRGB {
    static let mint = ChartRGB(0x21D4A8)
    static let blue = ChartRGB(0x4F7CFF)
    static let grey = ChartRGB(0x8E8E99)
}

extension ChartKit {
    /// Deterministic 0…1 noise for an index, so "random" data is the same on every launch and in every still.
    static func hash(_ index: Int, _ salt: Int = 0) -> Double {
        let x = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return x - floor(x)
    }

    /// Ease-out with an overshoot (a "back" curve): 0 → 1, peaking slightly above 1 on the way.
    static func backOut(_ t: Double, overshoot: Double = 1.4) -> Double {
        let x = min(max(t, 0), 1) - 1
        return 1 + x * x * ((overshoot + 1) * x + overshoot)
    }

    /// Local 0…1 progress of an element that starts at `delay` (0…1 of the timeline) and lasts `span`.
    static func stagger(_ t: Double, delay: Double, span: Double) -> Double {
        guard span > 0 else { return t >= delay ? 1 : 0 }
        return min(max((t - delay) / span, 0), 1)
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
    }

    /// Convex hull (monotone chain), counter-clockwise.
    static func convexHull(_ input: [CGPoint]) -> [CGPoint] {
        let points = input.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard points.count > 2 else { return points }
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [CGPoint] = []
        for point in points {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in points.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    /// A closed Catmull-Rom loop through `points`.
    static func smoothLoop(_ points: [CGPoint]) -> Path {
        var path = Path()
        let count = points.count
        guard count > 2 else { return path }
        path.move(to: points[0])
        for index in 0..<count {
            let p0 = points[(index - 1 + count) % count]
            let p1 = points[index]
            let p2 = points[(index + 1) % count]
            let p3 = points[(index + 2) % count]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }
}

/// The small caption + big rolling figure most chart cards open with.
struct ChartHeadline: View {
    let title: String
    let value: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ChartRollText(value: value, format: format)
                .font(.system(size: 26, weight: .bold, design: .rounded))
        }
    }
}
