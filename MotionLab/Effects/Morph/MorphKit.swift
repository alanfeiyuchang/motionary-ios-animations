import SwiftUI

/// Rebuilds `content` on every frame while `value` animates, handing it the in-flight value.
///
/// A plain `@State` read in `body` only ever sees the model value (the end of the animation), so geometry that is
/// *computed* from a progress (a frame interpolated between two rects, a fold line, an aperture) would jump. Wrapping
/// the computation in `MorphAnimated` makes SwiftUI interpolate the number itself, so springs, interruptions and
/// overshoot all carry through to whatever the closure derives from it.
struct MorphAnimated<Value: VectorArithmetic, Content: View>: View, Animatable {
    var value: Value
    private let content: (Value) -> Content

    init(_ value: Value, @ViewBuilder content: @escaping (Value) -> Content) {
        self.value = value
        self.content = content
    }

    var animatableData: Value {
        get { value }
        set { value = newValue }
    }

    var body: some View { content(value) }
}

enum MorphMath {
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
    }

    /// Interpolates centre and size, so an overshooting `t` keeps the rect well-formed.
    static func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        let width: CGFloat = max(lerp(a.width, b.width, t), 1)
        let height: CGFloat = max(lerp(a.height, b.height, t), 1)
        let midX: CGFloat = lerp(a.midX, b.midX, t)
        let midY: CGFloat = lerp(a.midY, b.midY, t)
        return CGRect(x: midX - width / 2, y: midY - height / 2, width: width, height: height)
    }

    static func unit(_ x: CGFloat) -> CGFloat {
        min(max(x, 0), 1)
    }

    /// Smoothstep of `x` between `a` and `b`, clamped to 0…1.
    static func smooth(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let t: CGFloat = unit((x - a) / (b - a))
        return t * t * (3 - 2 * t)
    }

    static func rect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
}

/// Secondary content that rises out of a blur a moment after it is inserted (settled at once in a still).
struct MorphReveal: ViewModifier {
    var delay: Double = 0
    var rise: CGFloat = 10
    @State private var shown = false
    @Environment(\.demoIsStill) private var isStill

    func body(content: Content) -> some View {
        let visible: Bool = shown || isStill
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : rise)
            .blur(radius: visible ? 0 : 5)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86).delay(delay)) { shown = true }
            }
    }
}
