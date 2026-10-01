import Foundation
import SwiftUI

/// Small interpolation helpers shared by the scroll-driven demos.
enum ScrollMath {
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    /// Where `value` sits between `from` and `to`, clamped to 0…1.
    static func unit(_ value: CGFloat, _ from: CGFloat, _ to: CGFloat) -> CGFloat {
        guard to != from else { return value >= to ? 1 : 0 }
        return ((value - from) / (to - from)).clamped(to: 0...1)
    }

    /// Smoothstep easing of a 0…1 value.
    static func smooth(_ t: CGFloat) -> CGFloat {
        let x = t.clamped(to: 0...1)
        return x * x * (3 - 2 * x)
    }

    /// A Gaussian magnifier centred on distance 0: items are scaled by `base + (peak − base) · g(d)`
    /// with `g(d) = exp(−(d/σ)²)`. `position` is where an item at distance `d` has to sit so that the
    /// scaled items keep their spacing (the integral of the scale), which is what makes a fisheye
    /// push its neighbours apart instead of overlapping them.
    static func fisheye(distance d: CGFloat, sigma: CGFloat, peak: CGFloat, base: CGFloat = 1) -> (scale: CGFloat, position: CGFloat, weight: CGFloat) {
        let s = max(sigma, 1)
        let g = CGFloat(exp(-Double((d / s) * (d / s))))
        let area = (peak - base) * s * 0.886_226_9 * CGFloat(erf(Double(d / s)))
        return (base + (peak - base) * g, base * d + area, g)
    }
}

/// A top-edge pull for a ScrollView that lives inside another scroll view (the detail page).
///
/// Nested there, a list that is already at its top never rubber-bands: the drag goes to the page
/// instead. This claims a downward pan while `isEnabled` (the list is at its top), reports it
/// rubber-banded through `pull`, and springs it back on release, so "pull down" effects respond
/// to the finger wherever the demo is hosted. Upward drags fail the pan at once and scroll normally.
struct ScrollTopPull: ViewModifier {
    let isEnabled: Bool
    @Binding var pull: CGFloat
    var limit: CGFloat = 220
    /// Runs while `pull` still holds the released distance.
    var onRelease: () -> Void = {}

    func body(content: Content) -> some View {
        content.gesture(
            PageSafePan(
                directions: .down,
                isEnabled: isEnabled,
                onChanged: { translation in
                    pull = rubberBand(max(translation.height, 0), limit: limit, coefficient: 0.8)
                },
                onEnded: { _ in
                    onRelease()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { pull = 0 }
                }
            )
        )
    }
}
