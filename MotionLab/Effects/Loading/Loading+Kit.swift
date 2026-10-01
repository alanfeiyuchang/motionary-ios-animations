import SwiftUI

/// A phase (in cycles) that stays continuous when its rate changes. Shared by the looping loading demos.
struct LoadingPhaseClock {
    var anchorDate = Date()
    var anchorPhase: Double = 0

    func phase(at date: Date, rate: Double) -> Double {
        anchorPhase + date.timeIntervalSince(anchorDate) * rate
    }

    /// Call from `onChange` of the rate's parameter, with the rate that was in effect until now.
    mutating func rebase(at date: Date, oldRate: Double) {
        anchorPhase = phase(at: date, rate: oldRate)
        anchorDate = date
    }

    mutating func restart(at date: Date = .now) {
        anchorDate = date
        anchorPhase = 0
    }
}

/// Small curve helpers for demos that compute their motion from time instead of from SwiftUI animations.
enum LoadingCurve {
    static func smoothstep(_ x: Double) -> Double {
        let u: Double = min(max(x, 0), 1)
        return u * u * (3 - 2 * u)
    }

    static func easeOutCubic(_ x: Double) -> Double {
        let u: Double = min(max(x, 0), 1)
        return 1 - pow(1 - u, 3)
    }

    static func easeInOutCubic(_ x: Double) -> Double {
        let u: Double = min(max(x, 0), 1)
        return u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2
    }

    /// Step response of a damped spring: 0 at `t = 0`, settles on 1, overshoots when `damping < 1`.
    static func spring(_ t: Double, response: Double, damping: Double) -> Double {
        guard t > 0 else { return 0 }
        let omega: Double = 2 * .pi / max(response, 0.05)
        let zeta: Double = min(max(damping, 0.05), 1)
        if zeta >= 0.999 {
            return 1 - exp(-omega * t) * (1 + omega * t)
        }
        let damped: Double = omega * (1 - zeta * zeta).squareRoot()
        let envelope: Double = exp(-zeta * omega * t)
        return 1 - envelope * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }

    /// A stable pseudo-random number in 0…1 for an integer seed.
    static func hash(_ seed: Int) -> Double {
        let x: Double = sin(Double(seed) * 12.9898 + 4.1414) * 43758.5453
        return x - floor(x)
    }
}
