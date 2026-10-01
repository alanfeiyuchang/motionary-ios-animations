import SwiftUI

enum ShaderEffects {
    static let all: [Effect] = [
        Effect.shaderRipple,
        Effect.shaderWave,
        Effect.shaderPixelate,
        Effect.shaderDissolve,
        Effect.shaderGlitch,
        Effect.shaderMagnifier,
        Effect.shaderSwirl,
        Effect.shaderPlasma,
        Effect.shaderCRT,
        Effect.shaderHalftone,
        Effect.shaderGlassmorphism,
        Effect.shaderLiquidGlassLens,
        Effect.shaderChromatic,
        Effect.shaderKaleidoscope,
        Effect.shaderEdgeScan,
        Effect.shaderProgressiveBlur,
        Effect.shaderCaustics,
        Effect.shaderJellyPress,
        Effect.shaderLiquidWipe,
        Effect.shaderTileScatter,
        Effect.shaderReededGlass,
        Effect.shaderDither,
        Effect.shaderVHS,
        Effect.shaderVoronoiCells,
        Effect.shaderTunnel,
        // Second batch
        Effect.shaderHeatHaze,
        Effect.shaderShockwave,
        Effect.shaderBlackHole,
        Effect.shaderMelt,
        Effect.shaderInkBleed,
        Effect.shaderZoomBlur,
        Effect.shaderAscii,
        Effect.shaderThermal,
        Effect.shaderFrostGrow,
        Effect.shaderPrism,
        Effect.shaderLiquidChrome,
        Effect.shaderNebula,
        // Third batch
        Effect.shaderUnderwater,
        Effect.shaderWindSmear,
        Effect.shaderCrumple,
        Effect.shaderTouchTrail,
        Effect.shaderDisplaceFade,
        Effect.shaderGlitchCut,
        Effect.shaderCurlFlip,
        Effect.shaderSuper8,
        Effect.shaderNightVision,
        Effect.shaderSketchEdges,
        Effect.shaderRainGlass,
        Effect.shaderGlassBlocks,
        Effect.shaderFire,
        Effect.shaderLightningArcs,
    ]
}

/// Colorful sample artwork that the shader demos distort.
/// Each demo picks its own variant (palette, glyph, word and motif layout) so no two stages look alike.
struct ShaderArtwork: View {
    var variant: Int = 0

    private struct Look {
        let colors: [Color]
        let accent: Color
        let symbol: String
        let word: String
        /// Offsets of the big soft disc and the small accent disc.
        let disc: CGSize
        let dot: CGSize
    }

    private var look: Look {
        switch variant {
        case 1:
            return Look(colors: [Palette.mint, Palette.sky, Palette.blue], accent: Palette.pink, symbol: "drop.fill", word: "SHADER",
                        disc: CGSize(width: 80, height: -100), dot: CGSize(width: -86, height: 84))
        case 2:
            return Look(colors: [Palette.sky, Palette.blue, Palette.indigo], accent: Palette.mint, symbol: "water.waves", word: "RIPPLE",
                        disc: CGSize(width: -70, height: -110), dot: CGSize(width: 90, height: 96))
        case 3:
            return Look(colors: [Color(hex: 0x1E1B4B), Palette.indigo, Palette.violet], accent: Palette.sky, symbol: "flame.fill", word: "EMBER",
                        disc: CGSize(width: 86, height: 110), dot: CGSize(width: -84, height: -96))
        case 4:
            return Look(colors: [Palette.violet, Palette.pink, Palette.coral], accent: Palette.amber, symbol: "tornado", word: "TWIRL",
                        disc: CGSize(width: -90, height: 90), dot: CGSize(width: 88, height: -104))
        case 5:
            return Look(colors: [Palette.pink, Palette.violet, Palette.sky], accent: Palette.mint, symbol: "bolt.fill", word: "SPEED",
                        disc: CGSize(width: 70, height: 104), dot: CGSize(width: -92, height: -70))
        case 6:
            return Look(colors: [Color(hex: 0x14B8A6), Palette.blue, Color(hex: 0x312E81)], accent: Palette.amber, symbol: "viewfinder", word: "SCAN",
                        disc: CGSize(width: -84, height: -96), dot: CGSize(width: 90, height: 90))
        case 7:
            return Look(colors: [Palette.coral, Palette.amber, Palette.pink], accent: Palette.sky, symbol: "flag.fill", word: "BREEZE",
                        disc: CGSize(width: -76, height: 104), dot: CGSize(width: 94, height: -92))
        default:
            return Look(colors: [Palette.indigo, Palette.violet, Palette.pink], accent: Palette.amber, symbol: "sparkles", word: "MOTION",
                        disc: CGSize(width: 80, height: -100), dot: CGSize(width: -86, height: 84))
        }
    }

    var body: some View {
        let look = self.look
        ZStack {
            LinearGradient(colors: look.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 190, height: 190)
                .offset(look.disc)
            Circle()
                .fill(look.accent.opacity(0.75))
                .frame(width: 96, height: 96)
                .offset(look.dot)
            VStack(spacing: 10) {
                Image(systemName: look.symbol)
                    .font(.system(size: 60, weight: .semibold))
                Text(verbatim: look.word)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .tracking(4)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .frame(width: 260, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

/// A grid of glyphs — reveals distortion clearly.
struct ShaderGridArtwork: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x14162B), Color(hex: 0x2A2360)], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                let step: CGFloat = 22
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1)
            }
            VStack(spacing: 6) {
                Text(verbatim: "Aa 永")
                    .font(.system(size: 64, weight: .bold, design: .serif))
                Text(verbatim: "The quick brown fox · 动效词典")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .opacity(0.8)
            }
            .foregroundStyle(
                LinearGradient(colors: [Palette.sky, Palette.violet, Palette.pink], startPoint: .leading, endPoint: .trailing)
            )
        }
    }
}

// MARK: - Time helper

/// Speed-scaled seconds since the view appeared, refreshed every frame.
/// Time accumulates, so changing `speed` (or resuming after `paused`) never makes the shader jump,
/// and grid previews (`preview: true`) tick at 30 fps to keep the category grid light.
struct ShaderClock<Content: View>: View {
    var paused: Bool = false
    var preview: Bool = false
    var speed: Double = 1
    @ViewBuilder var content: (Double) -> Content
    @State private var clock = BackgroundClock(start: 0)

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: paused)) { timeline in
            content(clock.advance(to: timeline.date.timeIntervalSinceReferenceDate, speed: speed))
        }
    }
}
