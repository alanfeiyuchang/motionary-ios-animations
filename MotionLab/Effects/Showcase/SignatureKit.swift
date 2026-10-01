import SwiftUI

/// The "Signature Interactions" category: dark, glossy, widget-style cards with a warm orange accent
/// (think premium outdoor / travel dashboards). Shared styling lives here so every entry feels like one product.
enum ShowcaseEffects {
    static let all: [Effect] = ShowcaseSportEffects.all + ShowcaseTravelEffects.all + ShowcaseLifeEffects.all + ShowcaseStudioEffects.all
}

enum Signature {
    /// Warm accent (orange) and supporting tones.
    static let accent = Color(hex: 0xFF8A1F)
    static let accentHot = Color(hex: 0xFF5A1F)
    static let accentSoft = Color(hex: 0xFFB45C)
    static let lime = Color(hex: 0xC8F560)
    static let ink = Color(hex: 0x0B0B0D)
    static let card = Color(hex: 0x17171A)
    static let cardHigh = Color(hex: 0x222226)
    static let paper = Color(hex: 0xF3F1EC)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let hairline = Color.white.opacity(0.09)

    static let accentGradient = LinearGradient(colors: [accentSoft, accent, accentHot], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Rounded "label" font for big numbers: `.font(Signature.number(46))`
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }

    /// Small caps-like eyebrow label font.
    static let eyebrow = Font.system(size: 10, weight: .bold, design: .rounded)
}

extension View {
    /// Glossy dark widget card: near-black gradient, hairline border, top inner highlight, deep soft shadow.
    func signatureCard(cornerRadius: CGFloat = 26, light: Bool = false) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        light
                            ? AnyShapeStyle(LinearGradient(colors: [Signature.paper, Color(hex: 0xE4E1DA)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(LinearGradient(colors: [Signature.cardHigh, Signature.card], startPoint: .top, endPoint: .bottom))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(light ? 0.9 : 0.16), Color.white.opacity(light ? 0.3 : 0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
    }

    /// Small uppercase eyebrow styling (e.g. "FRESH SNOW", "TOP SPEED").
    func signatureEyebrow(light: Bool = false) -> some View {
        self
            .font(Signature.eyebrow)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(light ? Color.black.opacity(0.45) : Signature.textSecondary)
    }
}

/// Dark stage backdrop used behind showcase demos so cards read like the reference shots.
struct SignatureStage<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1C1C20), Signature.ink], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Signature.accent.opacity(0.12), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
            content()
        }
        .environment(\.colorScheme, .dark)
    }
}

/// A procedurally drawn "landscape photo" (sky gradient, sun, layered mountain ridges) so demos
/// can show photo cards without bundling images. `seed` picks one of several moods.
struct LandscapeArt: View {
    var seed: Int = 0

    private var palette: (sky: [Color], sun: Color, ridges: [Color]) {
        switch seed % 5 {
        case 1: // dusk coast
            return ([Color(hex: 0x2B2E5A), Color(hex: 0xE0785A), Color(hex: 0xF5C27A)], Color(hex: 0xFFE2A8),
                    [Color(hex: 0x6A4B6E), Color(hex: 0x3B2C4A), Color(hex: 0x1C1726)])
        case 2: // alpine lake
            return ([Color(hex: 0x8FC9F0), Color(hex: 0xD8EEF8)], Color.white,
                    [Color(hex: 0xA9B8C8), Color(hex: 0x4F7A8A), Color(hex: 0x1F4A55)])
        case 3: // desert
            return ([Color(hex: 0xF7B267), Color(hex: 0xF4845F)], Color(hex: 0xFFF1C1),
                    [Color(hex: 0xD2693C), Color(hex: 0xA2482A), Color(hex: 0x5E2A1C)])
        case 4: // night
            return ([Color(hex: 0x0B1026), Color(hex: 0x27305E)], Color(hex: 0xE8ECFF),
                    [Color(hex: 0x323A66), Color(hex: 0x1D2347), Color(hex: 0x0D1129)])
        default: // snowy peaks, golden hour
            return ([Color(hex: 0x3D5A80), Color(hex: 0xF2A65A), Color(hex: 0xFFD8A8)], Color(hex: 0xFFF3D6),
                    [Color(hex: 0xE9EEF5), Color(hex: 0x7C8BA1), Color(hex: 0x2E3A4D)])
        }
    }

    var body: some View {
        let p = palette
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                LinearGradient(colors: p.sky, startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(p.sun)
                    .frame(width: w * 0.22, height: w * 0.22)
                    .blur(radius: 1)
                    .shadow(color: p.sun.opacity(0.8), radius: 20)
                    .position(x: w * (0.25 + Double(seed % 3) * 0.22), y: h * 0.34)
                ForEach(0..<3, id: \.self) { layer in
                    RidgeShape(seed: seed * 7 + layer * 3, baseline: 0.5 + Double(layer) * 0.14, amplitude: 0.2 - Double(layer) * 0.04)
                        .fill(p.ridges[layer])
                }
            }
        }
    }
}

/// A jagged mountain ridge filled to the bottom edge.
struct RidgeShape: Shape {
    var seed: Int
    var baseline: Double
    var amplitude: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 9
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let n = sin(Double(seed) * 12.9898 + Double(i) * 78.233) * 43758.5453
            let jitter = n - n.rounded(.down)
            let y = baseline - amplitude * (i % 2 == 0 ? jitter * 0.5 : 0.6 + jitter * 0.4)
            path.addLine(to: CGPoint(x: rect.minX + rect.width * t, y: rect.minY + rect.height * y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
