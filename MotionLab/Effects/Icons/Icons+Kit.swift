import SwiftUI

/// Curve helpers for the icon demos that compute their choreography from elapsed time
/// (each sub-motion is a function of the seconds since the tap, so stagger and overlap stay exact).
enum IconsCurve {
    static func unit(_ x: Double) -> Double { min(max(x, 0), 1) }

    /// Linear progress of `t` through the window `a…b`, clamped to 0…1.
    static func seg(_ t: Double, _ a: Double, _ b: Double) -> Double {
        guard b > a else { return t >= b ? 1 : 0 }
        return unit((t - a) / (b - a))
    }

    static func easeOut(_ x: Double) -> Double {
        let u: Double = unit(x)
        return 1 - pow(1 - u, 3)
    }

    static func easeIn(_ x: Double) -> Double {
        let u: Double = unit(x)
        return u * u * u
    }

    static func easeInOut(_ x: Double) -> Double {
        let u: Double = unit(x)
        return u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2
    }

    static func smooth(_ x: Double) -> Double {
        let u: Double = unit(x)
        return u * u * (3 - 2 * u)
    }

    /// 0 → 1 → 0 across the unit interval.
    static func bump(_ x: Double) -> Double { sin(.pi * unit(x)) }

    static func mix(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * p }

    /// Step response of a damped spring: 0 at `t = 0`, settles on 1, overshoots when `damping < 1`.
    static func spring(_ t: Double, response: Double, damping: Double) -> Double {
        guard t > 0 else { return 0 }
        guard t < 20 else { return 1 }
        let omega: Double = 2 * .pi / max(response, 0.05)
        let zeta: Double = min(max(damping, 0.05), 1)
        if zeta >= 0.999 {
            return 1 - exp(-omega * t) * (1 + omega * t)
        }
        let damped: Double = omega * (1 - zeta * zeta).squareRoot()
        let envelope: Double = exp(-zeta * omega * t)
        return 1 - envelope * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }

    /// A decaying wobble that starts at 1 when `t = 0` (impact squash, thumps): `e^(-decay·t)·cos(frequency·t)`.
    static func ring(_ t: Double, decay: Double, frequency: Double) -> Double {
        guard t >= 0, t < 20 else { return 0 }
        return exp(-decay * t) * cos(frequency * t)
    }

    /// A decaying shake that starts at 0: `e^(-decay·t)·sin(frequency·t)`.
    static func shake(_ t: Double, decay: Double, frequency: Double) -> Double {
        guard t >= 0, t < 20 else { return 0 }
        return exp(-decay * t) * sin(frequency * t)
    }

    /// A stable pseudo-random number in 0…1 for an integer seed.
    static func hash(_ seed: Int) -> Double {
        let x: Double = sin(Double(seed) * 12.9898 + 4.1414) * 43758.5453
        return x - floor(x)
    }
}

/// A two-state play head: which state the icon is heading to and when that play began.
/// Toggling half-way through starts the opposite play from the matching point, so a quick second tap
/// reverses the motion instead of jumping to the other pose.
struct IconsPlayhead: Equatable {
    var isOn: Bool
    var start: Date = .distantPast

    init(isOn: Bool = false) {
        self.isOn = isOn
    }

    /// Seconds since the current play began (a large number once settled).
    func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    mutating func toggle(onDuration: Double, offDuration: Double, at now: Date = .now) {
        let current: Double = isOn ? onDuration : offDuration
        let done: Double = IconsCurve.unit(elapsed(at: now) / max(current, 0.01))
        isOn.toggle()
        let next: Double = isOn ? onDuration : offDuration
        start = now.addingTimeInterval(-(1 - done) * next)
    }
}

/// A phase that stays continuous when its rate changes (tempo sliders).
struct IconsPhaseClock {
    var anchorDate = Date()
    var anchorPhase: Double = 0

    func phase(at date: Date, rate: Double) -> Double {
        anchorPhase + date.timeIntervalSince(anchorDate) * rate
    }

    mutating func rebase(at date: Date = .now, oldRate: Double) {
        anchorPhase = phase(at: date, rate: oldRate)
        anchorDate = date
    }
}

/// The frame clock of the time-driven icon demos: 30 fps in grid previews, display rate on the stage.
struct IconsTimeline<Content: View>: View {
    let preview: Bool
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview))) { timeline in
            content(timeline.date)
        }
    }
}

enum IconsHaptics {
    /// Fires `action` after `delay`, unless the play was started by autoplay or the detail intro.
    static func later(_ delay: Double, preview: Bool, _ action: @escaping () -> Void) {
        guard !preview, !Haptics.isMuted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { action() }
    }
}

enum IconsPath {
    /// A closed polygon whose corners are rounded with tangent arcs; `radius` gives each vertex its own radius.
    static func roundedPolygon(_ points: [CGPoint], radius: (Int) -> CGFloat) -> Path {
        var path = Path()
        let count: Int = points.count
        guard count > 2 else { return path }
        path.move(to: mid(points[count - 1], points[0]))
        for index in 0..<count {
            let corner: CGPoint = points[index]
            let next: CGPoint = points[(index + 1) % count]
            path.addArc(tangent1End: corner, tangent2End: mid(corner, next), radius: radius(index))
        }
        path.closeSubpath()
        return path
    }

    static func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

/// A four-point sparkle with concave sides.
struct IconsSparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<4 {
            let angle: CGFloat = CGFloat(index) * .pi / 2 - .pi / 2
            let tip = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 {
                path.move(to: tip)
            } else {
                path.addQuadCurve(to: tip, control: center)
            }
        }
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: center)
        path.closeSubpath()
        return path
    }
}

/// A straight stroke between two unit points of its rect (slashes, check legs).
struct IconsLine: Shape {
    var from: UnitPoint
    var to: UnitPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * from.x, y: rect.minY + rect.height * from.y))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * to.x, y: rect.minY + rect.height * to.y))
        return path
    }
}

/// A check mark drawn inside its rect.
struct IconsCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.86))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.16))
        return path
    }
}
