import SwiftUI

/// A flat view placed in 3D and projected back onto the screen with a one-point perspective.
///
/// SwiftUI's `rotation3DEffect` turns a view about one axis through one anchor. The folding, bending and
/// prism card effects need several panels that share hinges and one vanishing point, so they describe each
/// panel as a plane (where the view's origin lands, and where its x and y axes point) and feed the result
/// to `projectionEffect`. Units are points; +z comes toward the viewer.
struct CardsPlane3D {
    struct Vec {
        var x: CGFloat
        var y: CGFloat
        var z: CGFloat

        init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    /// Where the view's (0, 0) lands.
    var origin: Vec
    /// Where one point along the view's x axis goes.
    var u: Vec
    /// Where one point along the view's y axis goes.
    var v: Vec

    /// The untouched plane of the screen.
    static let flat = CardsPlane3D(origin: Vec(0, 0, 0), u: Vec(1, 0, 0), v: Vec(0, 1, 0))

    /// Hinge on the horizontal line `y = lineY`. A positive angle (radians) brings what is below the line
    /// toward the viewer and sends what is above it away. `lift` moves the whole plane toward the viewer.
    static func hingeX(lineY: CGFloat, angle: CGFloat, lift: CGFloat = 0) -> CardsPlane3D {
        let c = cos(angle)
        let s = sin(angle)
        return CardsPlane3D(
            origin: Vec(0, lineY - lineY * c, -lineY * s + lift),
            u: Vec(1, 0, 0),
            v: Vec(0, c, s)
        )
    }

    /// Hinge on the vertical line `x = lineX`. A positive angle (radians) brings what is right of the line
    /// toward the viewer and sends what is left of it away.
    static func hingeY(lineX: CGFloat, angle: CGFloat, lift: CGFloat = 0) -> CardsPlane3D {
        let c = cos(angle)
        let s = sin(angle)
        return CardsPlane3D(
            origin: Vec(lineX - lineX * c, 0, -lineX * s + lift),
            u: Vec(c, 0, s),
            v: Vec(0, 1, 0)
        )
    }

    /// Screen position of the view-local point `p` (for shadows and attachments that follow a panel).
    func project(_ p: CGPoint, eye: CGPoint, depth: CGFloat) -> CGPoint {
        let x3: CGFloat = origin.x + p.x * u.x + p.y * v.x
        let y3: CGFloat = origin.y + p.x * u.y + p.y * v.y
        let z3: CGFloat = origin.z + p.x * u.z + p.y * v.z
        let w: CGFloat = max(1 - z3 / depth, 0.05)
        return CGPoint(x: eye.x + (x3 - eye.x) / w, y: eye.y + (y3 - eye.y) / w)
    }

    /// The projective transform for `projectionEffect`. `eye` is the vanishing point in the view's own
    /// coordinates and `depth` the viewer's distance: a point at height z is magnified by 1 / (1 − z / depth).
    func projection(eye: CGPoint, depth: CGFloat) -> ProjectionTransform {
        var m = ProjectionTransform()
        // [x y 1] · M = [X·w, Y·w, w] with w = 1 − z / depth.
        m.m13 = -u.z / depth
        m.m23 = -v.z / depth
        m.m33 = 1 - origin.z / depth
        m.m11 = u.x + eye.x * m.m13
        m.m21 = v.x + eye.x * m.m23
        m.m31 = origin.x - eye.x + eye.x * m.m33
        m.m12 = u.y + eye.y * m.m13
        m.m22 = v.y + eye.y * m.m23
        m.m32 = origin.y - eye.y + eye.y * m.m33
        return m
    }
}
