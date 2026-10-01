import SwiftUI

// Shared pieces of the second batch of shader demos: card metrics, bespoke scenes drawn with Canvas
// (each one built to make its shader readable: straight lines for distortion, bokeh for frost, hard
// white type for dispersion…) and a scroll-friendly touch tracker.

enum ShaderKit {
    /// Every card demo uses this size; the shaders receive it as `size`.
    static let card = CGSize(width: 260, height: 300)
    static let corner: CGFloat = 30

    static func rand(_ index: Int, _ salt: Int = 0) -> CGFloat {
        let seed = sin(Double(index) * 12.9898 + Double(salt) * 78.233 + 0.5) * 43758.5453
        return CGFloat(seed - seed.rounded(.down))
    }

    static func gradient(_ hexes: [UInt32]) -> Gradient {
        Gradient(colors: hexes.map { Color(hex: $0) })
    }
}

extension View {
    /// Sizes a scene to the shared card, clips it and gives it the card chrome (hairline + soft shadow).
    /// Apply it *after* the shader so distortion never bends the card's own outline.
    func shaderCard(glow: Color = .black.opacity(0.22)) -> some View {
        let shape = RoundedRectangle(cornerRadius: ShaderKit.corner, style: .continuous)
        return self
            .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: glow, radius: 20, y: 12)
    }
}

extension View {
    /// Bottom hint for full-bleed generative stages: sits on a small glass capsule so it stays legible over
    /// any picture (bright chrome as well as dark space). Hidden in previews.
    func shaderStageHint(_ text: LocalizedText, _ ctx: DemoContext) -> some View {
        overlay(alignment: .bottom) {
            if !ctx.isPreview {
                Text(text, ctx.language)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.38)))
                    .padding(.bottom, 14)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Touch

/// A drag that follows the finger in any direction but never traps the page's vertical scroll: it is attached
/// simultaneously and only engages after an 80 ms hold or a sideways-first move; a vertical-first move hands the
/// touch to the scroll view. A quick tap reports `onTap`. `@GestureState` resets on system cancellation, so
/// `onEnded` always runs.
private struct ShaderTouchModifier: ViewModifier {
    let onBegan: (CGPoint) -> Void
    let onMoved: (CGPoint, CGSize) -> Void
    let onEnded: () -> Void
    let onTap: (CGPoint) -> Void

    @State private var engaged = false
    @State private var vetoed = false
    @State private var armScheduled = false
    @State private var armToken = 0
    @State private var lastLocation = CGPoint.zero
    @GestureState private var touching = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(drag)
            .onChange(of: touching) { _, isTouching in
                if !isTouching { finish() }
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                lastLocation = value.location
                if !engaged {
                    guard !vetoed else { return }
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    if dy > 6 && dy >= dx {
                        vetoed = true
                        armToken += 1
                        return
                    }
                    if dx > 6 && dx > dy {
                        engage(at: value.location)
                    } else {
                        scheduleArm()
                        return
                    }
                }
                onMoved(value.location, value.velocity)
            }
            .onEnded { value in
                let dx = abs(value.translation.width)
                let dy = abs(value.translation.height)
                let wasTap = !engaged && !vetoed && dx < 6 && dy < 6
                finish()
                if wasTap { onTap(value.location) }
            }
    }

    private func scheduleArm() {
        guard !armScheduled else { return }
        armScheduled = true
        armToken += 1
        let token = armToken
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard token == armToken, !engaged, !vetoed else { return }
            engage(at: lastLocation)
            onMoved(lastLocation, .zero)
        }
    }

    private func engage(at location: CGPoint) {
        armToken += 1
        engaged = true
        onBegan(location)
    }

    private func finish() {
        armToken += 1
        armScheduled = false
        vetoed = false
        if engaged {
            engaged = false
            onEnded()
        }
    }
}

extension View {
    /// See `ShaderTouchModifier`: free drag after an 80 ms hold or a sideways move, tap, scroll-friendly.
    func shaderTouch(
        onBegan: @escaping (CGPoint) -> Void = { _ in },
        onMoved: @escaping (CGPoint, CGSize) -> Void,
        onEnded: @escaping () -> Void = {},
        onTap: @escaping (CGPoint) -> Void = { _ in }
    ) -> some View {
        modifier(ShaderTouchModifier(onBegan: onBegan, onMoved: onMoved, onEnded: onEnded, onTap: onTap))
    }
}

// MARK: - Scenes

/// Desert highway at sunset: a hard horizon, a sun disc, a road and poles, all straight lines that shimmer well.
struct ShaderDesertScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let horizon = h * 0.6
            let mid = w * 0.5
            context.fill(
                Path(CGRect(x: 0, y: 0, width: w, height: horizon)),
                with: .linearGradient(
                    ShaderKit.gradient([0x3B1D5E, 0xB23A5E, 0xFF8F4A, 0xFFD98A]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
                )
            )
            let sun = CGRect(x: mid - 46, y: horizon - 70, width: 92, height: 92)
            context.fill(Path(ellipseIn: sun.insetBy(dx: -22, dy: -22)), with: .color(Color(hex: 0xFFE9B0, opacity: 0.22)))
            context.fill(
                Path(ellipseIn: sun),
                with: .linearGradient(
                    ShaderKit.gradient([0xFFF8DC, 0xFFB84A]),
                    startPoint: CGPoint(x: 0, y: sun.minY), endPoint: CGPoint(x: 0, y: sun.maxY)
                )
            )
            // Mesas on the horizon.
            var mesa = Path()
            mesa.move(to: CGPoint(x: 0, y: horizon))
            let profile: [(CGFloat, CGFloat)] = [
                (0, 26), (0.1, 26), (0.13, 40), (0.24, 40), (0.27, 14), (0.38, 12), (0.62, 10),
                (0.68, 30), (0.8, 30), (0.83, 46), (0.93, 46), (0.96, 18), (1, 18),
            ]
            for (x, up) in profile { mesa.addLine(to: CGPoint(x: x * w, y: horizon - up)) }
            mesa.addLine(to: CGPoint(x: w, y: horizon))
            mesa.closeSubpath()
            context.fill(mesa, with: .color(Color(hex: 0x4A1D3A)))
            context.fill(
                Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
                with: .linearGradient(
                    ShaderKit.gradient([0xA5482A, 0x3A1612]),
                    startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)
                )
            )
            // Road to the vanishing point with a dashed centre line.
            var road = Path()
            road.move(to: CGPoint(x: mid - 4, y: horizon))
            road.addLine(to: CGPoint(x: mid + 4, y: horizon))
            road.addLine(to: CGPoint(x: mid + 96, y: h))
            road.addLine(to: CGPoint(x: mid - 96, y: h))
            road.closeSubpath()
            context.fill(road, with: .color(Color(hex: 0x21151B)))
            let depth = h - horizon
            for k in 0..<7 {
                let a = pow(CGFloat(k) / 7, 2)
                let b = pow((CGFloat(k) + 0.55) / 7, 2)
                var dash = Path()
                dash.move(to: CGPoint(x: mid - 0.6 - 4 * a, y: horizon + depth * a))
                dash.addLine(to: CGPoint(x: mid + 0.6 + 4 * a, y: horizon + depth * a))
                dash.addLine(to: CGPoint(x: mid + 0.6 + 4 * b, y: horizon + depth * b))
                dash.addLine(to: CGPoint(x: mid - 0.6 - 4 * b, y: horizon + depth * b))
                dash.closeSubpath()
                context.fill(dash, with: .color(Color(hex: 0xFFD98A, opacity: 0.9)))
            }
            // Telegraph poles receding on the right, cacti on the left.
            for k in 0..<5 {
                let d = 1 / (1 + CGFloat(k) * 0.95)
                let x = mid + 118 * d + 6
                let base = horizon + depth * d * 0.82
                let height = 132 * d
                var pole = Path()
                pole.move(to: CGPoint(x: x, y: base))
                pole.addLine(to: CGPoint(x: x, y: base - height))
                pole.move(to: CGPoint(x: x - 11 * d, y: base - height * 0.86))
                pole.addLine(to: CGPoint(x: x + 11 * d, y: base - height * 0.86))
                context.stroke(pole, with: .color(Color(hex: 0x1A0E14)), style: StrokeStyle(lineWidth: max(3.2 * d, 0.8), lineCap: .round))
            }
            for (x, scale) in [(CGFloat(34), CGFloat(1)), (CGFloat(78), CGFloat(0.55))] {
                let base = horizon + depth * (scale > 0.8 ? 0.62 : 0.2)
                let trunk = CGRect(x: x - 6 * scale, y: base - 62 * scale, width: 12 * scale, height: 62 * scale)
                var cactus = Path(roundedRect: trunk, cornerRadius: 6 * scale)
                cactus.addRoundedRect(in: CGRect(x: x - 20 * scale, y: base - 44 * scale, width: 9 * scale, height: 24 * scale), cornerSize: CGSize(width: 4.5 * scale, height: 4.5 * scale))
                cactus.addRect(CGRect(x: x - 20 * scale, y: base - 28 * scale, width: 16 * scale, height: 8 * scale))
                cactus.addRoundedRect(in: CGRect(x: x + 11 * scale, y: base - 54 * scale, width: 9 * scale, height: 26 * scale), cornerSize: CGSize(width: 4.5 * scale, height: 4.5 * scale))
                cactus.addRect(CGRect(x: x + 4 * scale, y: base - 36 * scale, width: 16 * scale, height: 8 * scale))
                context.fill(cactus, with: .color(Color(hex: 0x1E2A22)))
            }
            context.draw(
                Text(verbatim: "48°C").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Color.white.opacity(0.92)),
                at: CGPoint(x: 22, y: 30), anchor: .leading
            )
            context.draw(
                Text(verbatim: "ROUTE 66").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.7)),
                at: CGPoint(x: 22, y: 50), anchor: .leading
            )
        }
    }
}

/// Night skyline with lit windows and a moon: lots of small, regular detail for a refractive ring to bend.
struct ShaderCityScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    ShaderKit.gradient([0x080C26, 0x2A1B5E, 0xA8407A, 0xFF9966]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.86)
                )
            )
            for i in 0..<46 {
                let p = CGPoint(x: ShaderKit.rand(i, 1) * w, y: ShaderKit.rand(i, 2) * h * 0.5)
                let r = 0.5 + ShaderKit.rand(i, 3) * 1.1
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.35 + 0.6 * ShaderKit.rand(i, 4))))
            }
            let moon = CGRect(x: w * 0.68, y: h * 0.1, width: 46, height: 46)
            context.fill(Path(ellipseIn: moon.insetBy(dx: -14, dy: -14)), with: .color(Color(hex: 0xFFF3C9, opacity: 0.16)))
            context.fill(Path(ellipseIn: moon), with: .color(Color(hex: 0xFFF3C9)))
            // Far skyline.
            var x: CGFloat = -6
            var i = 0
            while x < w {
                let bw = 22 + ShaderKit.rand(i, 11) * 22
                let bh = h * (0.2 + ShaderKit.rand(i, 12) * 0.22)
                context.fill(Path(CGRect(x: x, y: h - bh - 26, width: bw, height: bh + 26)), with: .color(Color(hex: 0x2E2166)))
                x += bw + 2
                i += 1
            }
            // Near skyline with windows.
            x = -10
            i = 0
            while x < w {
                let bw = 34 + ShaderKit.rand(i, 21) * 26
                let bh = h * (0.16 + ShaderKit.rand(i, 22) * 0.34)
                let top = h - bh
                context.fill(Path(CGRect(x: x, y: top, width: bw, height: bh)), with: .color(Color(hex: 0x0E0B26)))
                var wy = top + 9
                var row = 0
                while wy < h - 22 {
                    var wx = x + 6
                    var col = 0
                    while wx < x + bw - 7 {
                        if ShaderKit.rand(i * 97 + row * 13 + col, 23) > 0.42 {
                            let warm = ShaderKit.rand(i * 31 + row * 7 + col, 24) > 0.3
                            context.fill(
                                Path(CGRect(x: wx, y: wy, width: 3.5, height: 4.5)),
                                with: .color(warm ? Color(hex: 0xFFD27A, opacity: 0.95) : Color(hex: 0x8ADFFF, opacity: 0.9))
                            )
                        }
                        wx += 8
                        col += 1
                    }
                    wy += 10
                    row += 1
                }
                x += bw + 3
                i += 1
            }
            context.fill(Path(CGRect(x: 0, y: h - 16, width: w, height: 16)), with: .color(Color(hex: 0x06051A)))
        }
    }
}

/// Deep space with a coordinate grid, stars and a ringed planet: lensing needs straight lines and point lights.
struct ShaderSpaceScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    ShaderKit.gradient([0x232A6B, 0x0C0F2E, 0x04050D]),
                    center: CGPoint(x: w * 0.4, y: h * 0.55), startRadius: 0, endRadius: h * 0.8
                )
            )
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 26))
                layer.fill(Path(ellipseIn: CGRect(x: w * 0.02, y: h * 0.58, width: 150, height: 110)), with: .color(Color(hex: 0xC24BFF, opacity: 0.5)))
                layer.fill(Path(ellipseIn: CGRect(x: w * 0.5, y: h * 0.05, width: 130, height: 100)), with: .color(Color(hex: 0x2BD9FE, opacity: 0.4)))
                layer.fill(Path(ellipseIn: CGRect(x: w * 0.55, y: h * 0.68, width: 110, height: 90)), with: .color(Color(hex: 0xFF7A5C, opacity: 0.38)))
            }
            var grid = Path()
            var gx: CGFloat = 13
            while gx < w {
                grid.move(to: CGPoint(x: gx, y: 0))
                grid.addLine(to: CGPoint(x: gx, y: h))
                gx += 26
            }
            var gy: CGFloat = 20
            while gy < h {
                grid.move(to: CGPoint(x: 0, y: gy))
                grid.addLine(to: CGPoint(x: w, y: gy))
                gy += 26
            }
            context.stroke(grid, with: .color(.white.opacity(0.13)), lineWidth: 1)
            for i in 0..<150 {
                let p = CGPoint(x: ShaderKit.rand(i, 31) * w, y: ShaderKit.rand(i, 32) * h)
                let r = 0.5 + pow(ShaderKit.rand(i, 33), 3) * 2.2
                let tint: Color = ShaderKit.rand(i, 34) > 0.75 ? Color(hex: 0xFFD9A8) : (ShaderKit.rand(i, 34) < 0.2 ? Color(hex: 0xA8D8FF) : .white)
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(0.5 + 0.5 * ShaderKit.rand(i, 35))))
            }
            let planet = CGRect(x: w * 0.7, y: h * 0.14, width: 44, height: 44)
            var ring = Path(ellipseIn: CGRect(x: planet.midX - 38, y: planet.midY - 9, width: 76, height: 18))
            ring = ring.applying(CGAffineTransform(translationX: -planet.midX, y: -planet.midY).concatenating(CGAffineTransform(rotationAngle: -0.35)).concatenating(CGAffineTransform(translationX: planet.midX, y: planet.midY)))
            context.stroke(ring, with: .color(Color(hex: 0xFFE2B8, opacity: 0.8)), lineWidth: 2.5)
            context.fill(
                Path(ellipseIn: planet),
                with: .linearGradient(ShaderKit.gradient([0xFFC27A, 0xD9573B]), startPoint: CGPoint(x: planet.minX, y: planet.minY), endPoint: CGPoint(x: planet.maxX, y: planet.maxY))
            )
            context.draw(
                Text(verbatim: "SGR A*  ·  26 000 ly").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.7)),
                at: CGPoint(x: 18, y: h - 20), anchor: .leading
            )
        }
    }
}

/// Bold numbered posters that the transitions cycle through; each has its own palette, pattern and glyph.
struct ShaderPosterScene: View {
    let index: Int

    private struct Look {
        let colors: [UInt32]
        let number: String
        let word: String
        let symbol: String
        let ink: UInt32
    }

    private var look: Look {
        switch ((index % 4) + 4) % 4 {
        case 1: return Look(colors: [0x0B2B3A, 0x136A7A, 0x21D4A8], number: "02", word: "TIDE", symbol: "water.waves", ink: 0xE9FFF8)
        case 2: return Look(colors: [0x3A0CA3, 0x9D1FE0, 0xFF5FA2], number: "03", word: "NEON", symbol: "bolt.fill", ink: 0xFFF1FA)
        case 3: return Look(colors: [0x10203F, 0x2B59C3, 0x7AD7FF], number: "04", word: "DRIFT", symbol: "wind", ink: 0xF2FAFF)
        default: return Look(colors: [0xE8452F, 0xFF8A3D, 0xFFD166], number: "01", word: "DAWN", symbol: "sun.max.fill", ink: 0xFFF8E7)
        }
    }

    var body: some View {
        let look = self.look
        let kind = ((index % 4) + 4) % 4
        ZStack {
            LinearGradient(gradient: ShaderKit.gradient(look.colors), startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let line = Color.white.opacity(0.16)
                switch kind {
                case 1:
                    for k in 0..<9 {
                        var wave = Path()
                        let y0 = h * 0.5 + CGFloat(k) * 18
                        wave.move(to: CGPoint(x: 0, y: y0))
                        var x: CGFloat = 0
                        while x <= w {
                            wave.addLine(to: CGPoint(x: x, y: y0 + sin(x / 26 + CGFloat(k) * 0.7) * 7))
                            x += 6
                        }
                        context.stroke(wave, with: .color(line), lineWidth: 2)
                    }
                case 2:
                    var y: CGFloat = 12
                    while y < h {
                        var x: CGFloat = 12
                        while x < w {
                            context.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)), with: .color(line))
                            x += 16
                        }
                        y += 16
                    }
                case 3:
                    var x: CGFloat = -h
                    while x < w {
                        var stripe = Path()
                        stripe.move(to: CGPoint(x: x, y: h))
                        stripe.addLine(to: CGPoint(x: x + h, y: 0))
                        context.stroke(stripe, with: .color(line), lineWidth: 5)
                        x += 26
                    }
                default:
                    for k in 1..<8 {
                        let r = CGFloat(k) * 30
                        context.stroke(Path(ellipseIn: CGRect(x: w * 0.82 - r, y: h * 0.2 - r, width: r * 2, height: r * 2)), with: .color(line), lineWidth: 2)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: look.symbol)
                    .font(.system(size: 34, weight: .bold))
                Spacer(minLength: 0)
                Text(verbatim: look.number)
                    .font(.system(size: 112, weight: .black, design: .rounded))
                    .tracking(-4)
                    .padding(.bottom, -14)
                Text(verbatim: look.word)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .tracking(8)
            }
            .foregroundStyle(Color(hex: look.ink))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

/// High-contrast type poster: white letters and hairlines on black, where spectral fringes read best.
struct ShaderTypeScene: View {
    var body: some View {
        ZStack {
            Color(hex: 0x09090C)
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var rules = Path()
                for y in [h * 0.12, h * 0.88] {
                    rules.move(to: CGPoint(x: 22, y: y))
                    rules.addLine(to: CGPoint(x: w - 22, y: y))
                }
                context.stroke(rules, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                var ticks = Path()
                var x: CGFloat = 24
                while x < w - 22 {
                    ticks.move(to: CGPoint(x: x, y: h * 0.8))
                    ticks.addLine(to: CGPoint(x: x, y: h * 0.8 + (Int(x) % 40 == 24 ? 12 : 6)))
                    x += 8
                }
                context.stroke(ticks, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
            }
            VStack(alignment: .leading, spacing: -20) {
                Text(verbatim: "SPE")
                Text(verbatim: "CTR")
                Text(verbatim: "UM.")
            }
            .font(.system(size: 84, weight: .black, design: .default))
            .tracking(-1)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .offset(y: -8)
            Text(verbatim: "REFRACTION  n = 1.52")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 22)
                .padding(.bottom, 14)
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

/// A night window: soft city bokeh behind the glass, the classic subject for frost.
struct ShaderWindowScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(ShaderKit.gradient([0x070B1E, 0x16264A, 0x2A1E4A]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h))
            )
            let tints: [UInt32] = [0xFFC247, 0xFF7A5C, 0xFF5FA2, 0x3AC4FF, 0x21D4A8, 0xFFE9B0]
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                for i in 0..<34 {
                    let r = 9 + ShaderKit.rand(i, 41) * 19
                    let p = CGPoint(x: ShaderKit.rand(i, 42) * w, y: h * 0.22 + ShaderKit.rand(i, 43) * h * 0.74)
                    let tint = Color(hex: tints[i % tints.count], opacity: 0.3 + 0.5 * Double(ShaderKit.rand(i, 44)))
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(tint))
                }
            }
            for i in 0..<22 {
                let r = 1.2 + ShaderKit.rand(i, 45) * 1.8
                let p = CGPoint(x: ShaderKit.rand(i, 46) * w, y: h * 0.3 + ShaderKit.rand(i, 47) * h * 0.6)
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: tints[(i + 2) % tints.count])))
            }
            context.draw(
                Text(verbatim: "−12°").font(.system(size: 44, weight: .thin, design: .rounded)).foregroundStyle(Color.white.opacity(0.95)),
                at: CGPoint(x: 24, y: 48), anchor: .leading
            )
            context.draw(
                Text(verbatim: "HELSINKI  ·  23:40").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.7)),
                at: CGPoint(x: 26, y: 82), anchor: .leading
            )
        }
    }
}
