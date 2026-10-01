import SwiftUI

/// A plain RGB triple for colours that are mixed per frame inside a `Canvas`.
struct GestureRGB {
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

    func mixed(_ other: GestureRGB, _ t: Double) -> GestureRGB {
        GestureRGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }

    func color(_ opacity: Double = 1) -> Color {
        Color(.sRGB, red: min(max(r, 0), 1), green: min(max(g, 0), 1), blue: min(max(b, 0), 1), opacity: opacity)
    }

    /// A fully saturated colour for a hue in 0…1 (wraps), at the given saturation and brightness.
    static func hue(_ h: Double, saturation s: Double = 0.75, brightness v: Double = 1) -> GestureRGB {
        let hh: Double = (h - floor(h)) * 6
        let c: Double = v * s
        let x: Double = c * (1 - abs(hh.truncatingRemainder(dividingBy: 2) - 1))
        let m: Double = v - c
        let rgb: (Double, Double, Double)
        switch Int(hh) {
        case 0: rgb = (c, x, 0)
        case 1: rgb = (x, c, 0)
        case 2: rgb = (0, c, x)
        case 3: rgb = (0, x, c)
        case 4: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        return GestureRGB(rgb.0 + m, rgb.1 + m, rgb.2 + m)
    }
}

extension View {
    /// The recessed tray most of the physics toys play in: an elevated rounded surface with a hairline
    /// and a soft shadow, clipped to its shape.
    func gestureTray(cornerRadius: CGFloat = 30) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Palette.elevated, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            .contentShape(shape)
    }
}

/// Runs `body` on the next main-queue turn: for haptics decided while a view body steps a simulation.
@MainActor
func gestureAfterFrame(_ body: @escaping @MainActor () -> Void) {
    DispatchQueue.main.async { body() }
}
