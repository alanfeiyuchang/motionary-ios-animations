import SwiftUI

// Scenes for the third batch of shader demos. Like the ones in Shaders+SceneKit.swift, each is drawn to make
// one shader readable: saturated reds for water to absorb, hard paint edges for wind to comb, a nearly black
// forest for an intensifier to amplify, clear outlines and tonal steps for a pencil to trace…

private extension GraphicsContext {
    func disc(_ centre: CGPoint, _ radius: CGFloat, _ color: Color) {
        fill(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }

    func box(_ rect: CGRect, _ color: Color, corner: CGFloat = 0) {
        fill(Path(roundedRect: rect, cornerRadius: corner), with: .color(color))
    }

    func vertical(_ rect: CGRect, _ hexes: [UInt32]) {
        fill(
            Path(rect),
            with: .linearGradient(ShaderKit.gradient(hexes), startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY))
        )
    }
}

/// A closed silhouette from the left edge to the right edge: `height(x)` is measured up from `base`.
private func ridgePath(width: CGFloat, base: CGFloat, floor: CGFloat, height: (CGFloat) -> CGFloat) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 0, y: floor))
    var x: CGFloat = 0
    while x <= width + 4 {
        path.addLine(to: CGPoint(x: x, y: base - height(x)))
        x += 4
    }
    path.addLine(to: CGPoint(x: width, y: floor))
    path.closeSubpath()
    return path
}

// MARK: - Reef

/// A sunlit reef: coral reds, orange fish and pale sand, the colours water takes away first.
struct ShaderReefScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.vertical(CGRect(origin: .zero, size: size), [0x8BEFFF, 0x35C3E8, 0x1B7FC4, 0x135A9E])
            // Distant rocks.
            context.fill(ridgePath(width: w, base: h * 0.74, floor: h) { x in 26 + 22 * sin(x / 37 + 1) + 12 * sin(x / 13) }, with: .color(Color(hex: 0x2C7FB8)))
            context.fill(ridgePath(width: w, base: h * 0.84, floor: h) { x in 10 + 9 * sin(x / 29 + 2.4) + 4 * sin(x / 9) }, with: .color(Color(hex: 0xF1DDA6)))
            for i in 0..<70 {
                let p = CGPoint(x: ShaderKit.rand(i, 61) * w, y: h * 0.86 + ShaderKit.rand(i, 62) * h * 0.14)
                context.disc(p, 0.8 + ShaderKit.rand(i, 63) * 1.2, Color(hex: 0xC9A66B, opacity: 0.7))
            }
            // Fan corals: a bunch of rounded branches from one foot.
            let corals: [(CGFloat, CGFloat, CGFloat, UInt32)] = [(52, 0.9, 1.0, 0xFF4D6D), (206, 0.92, 0.82, 0xFF8A3D), (132, 0.96, 0.6, 0xE83F9B)]
            for (index, coral) in corals.enumerated() {
                let foot = CGPoint(x: coral.0, y: h * coral.1)
                for k in 0..<9 {
                    let angle = -CGFloat.pi / 2 + (CGFloat(k) - 4) * 0.2 + (ShaderKit.rand(k, 70 + index) - 0.5) * 0.12
                    let length = (48 + ShaderKit.rand(k, 80 + index) * 34) * coral.2
                    var branch = Path()
                    branch.move(to: foot)
                    let tip = CGPoint(x: foot.x + cos(angle) * length, y: foot.y + sin(angle) * length)
                    branch.addQuadCurve(to: tip, control: CGPoint(x: foot.x + cos(angle) * length * 0.3, y: foot.y + sin(angle) * length * 0.75))
                    context.stroke(branch, with: .color(Color(hex: coral.3)), style: StrokeStyle(lineWidth: 7 * coral.2, lineCap: .round))
                    context.disc(tip, 5.5 * coral.2, Color(hex: coral.3))
                }
            }
            // Kelp.
            for k in 0..<5 {
                let x0 = [18, 96, 158, 178, 244][k] as CGFloat
                var kelp = Path()
                kelp.move(to: CGPoint(x: x0, y: h))
                var y = h
                while y > h * (0.5 + 0.07 * CGFloat(k % 3)) {
                    y -= 6
                    kelp.addLine(to: CGPoint(x: x0 + sin(y / 17 + CGFloat(k)) * 7, y: y))
                }
                context.stroke(kelp, with: .color(Color(hex: k % 2 == 0 ? 0x1FA37A : 0x4CC38A)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            // Fish.
            let fish: [(CGFloat, CGFloat, CGFloat, UInt32, Bool)] = [
                (150, 96, 1.2, 0xFF7A1A, true), (86, 132, 0.8, 0xFFD23F, false), (200, 150, 0.7, 0xFF4D6D, true),
                (112, 70, 0.55, 0xFFD23F, true), (60, 186, 0.6, 0xFF7A1A, false),
            ]
            for item in fish {
                let dir: CGFloat = item.4 ? 1 : -1
                let s = item.2
                let c = CGPoint(x: item.0, y: item.1)
                var tail = Path()
                tail.move(to: CGPoint(x: c.x - dir * 14 * s, y: c.y))
                tail.addLine(to: CGPoint(x: c.x - dir * 28 * s, y: c.y - 10 * s))
                tail.addLine(to: CGPoint(x: c.x - dir * 28 * s, y: c.y + 10 * s))
                tail.closeSubpath()
                context.fill(tail, with: .color(Color(hex: item.3)))
                context.fill(Path(ellipseIn: CGRect(x: c.x - 18 * s, y: c.y - 10 * s, width: 36 * s, height: 20 * s)), with: .color(Color(hex: item.3)))
                context.box(CGRect(x: c.x - 2 * s, y: c.y - 9 * s, width: 4.5 * s, height: 18 * s), .white.opacity(0.9), corner: 2 * s)
                context.disc(CGPoint(x: c.x + dir * 11 * s, y: c.y - 2.5 * s), 2.2 * s, Color(hex: 0x10203F))
            }
            context.draw(
                Text(verbatim: "−18 m").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Color.white),
                at: CGPoint(x: 20, y: 34), anchor: .leading
            )
            context.draw(
                Text(verbatim: "CORAL REEF  ·  24°C").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.85)),
                at: CGPoint(x: 21, y: 58), anchor: .leading
            )
        }
    }
}

// MARK: - Wet paint

/// Thick, hard-edged brush strokes on primed canvas: every edge is something for the wind to comb out.
struct ShaderPaintScene: View {
    var body: some View {
        ZStack {
            Color(hex: 0xF3EEE4)
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let strokes: [(CGPoint, CGPoint, CGFloat, UInt32)] = [
                    (CGPoint(x: 30, y: 62), CGPoint(x: 190, y: 40), 40, 0x2447C8),
                    (CGPoint(x: 96, y: 118), CGPoint(x: 236, y: 132), 34, 0xE8452F),
                    (CGPoint(x: 34, y: 150), CGPoint(x: 70, y: 262), 38, 0x18A078),
                    (CGPoint(x: 150, y: 196), CGPoint(x: 232, y: 250), 30, 0x16161C),
                ]
                for stroke in strokes {
                    var path = Path()
                    path.move(to: stroke.0)
                    path.addLine(to: stroke.1)
                    context.stroke(path, with: .color(Color(hex: stroke.3)), style: StrokeStyle(lineWidth: stroke.2, lineCap: .round))
                    // Bristle marks.
                    let dx = stroke.1.x - stroke.0.x
                    let dy = stroke.1.y - stroke.0.y
                    let len = max(hypot(dx, dy), 1)
                    for k in 0..<5 {
                        let off = (CGFloat(k) - 2) * stroke.2 * 0.17
                        var bristle = Path()
                        bristle.move(to: CGPoint(x: stroke.0.x - dy / len * off, y: stroke.0.y + dx / len * off))
                        bristle.addLine(to: CGPoint(x: stroke.1.x - dy / len * off, y: stroke.1.y + dx / len * off))
                        context.stroke(bristle, with: .color(.white.opacity(0.11)), lineWidth: 1.2)
                    }
                }
                context.disc(CGPoint(x: w * 0.62, y: h * 0.62), 34, Color(hex: 0xFFC83D))
                context.disc(CGPoint(x: w * 0.84, y: h * 0.28), 13, Color(hex: 0xFF5FA2))
                for i in 0..<16 {
                    let p = CGPoint(x: ShaderKit.rand(i, 91) * w, y: ShaderKit.rand(i, 92) * h)
                    let tints: [UInt32] = [0x2447C8, 0xE8452F, 0x16161C, 0xFFC83D]
                    context.disc(p, 1.5 + ShaderKit.rand(i, 93) * 2.5, Color(hex: tints[i % 4]))
                }
            }
            VStack(alignment: .leading, spacing: -6) {
                Text(verbatim: "WET")
                Text(verbatim: "PAINT")
            }
            .font(.system(size: 46, weight: .black, design: .rounded))
            .foregroundStyle(Color(hex: 0x16161C))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 92)
            .padding(.bottom, 16)
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

// MARK: - Gig flyer

/// A printed flyer on off-white stock: light paper shows creases and facet shading best.
struct ShaderFlyerScene: View {
    var body: some View {
        ZStack {
            Color(hex: 0xF7F2E7)
            Canvas { context, size in
                let w = size.width
                let h = size.height
                context.disc(CGPoint(x: w * 0.7, y: h * 0.3), 74, Color(hex: 0xF0462E))
                context.disc(CGPoint(x: w * 0.7, y: h * 0.3), 44, Color(hex: 0xF7F2E7))
                context.disc(CGPoint(x: w * 0.7, y: h * 0.3), 20, Color(hex: 0x15151A))
                var rules = Path()
                for k in 0..<6 {
                    let y = h * 0.62 + CGFloat(k) * 7
                    rules.move(to: CGPoint(x: 20, y: y))
                    rules.addLine(to: CGPoint(x: w - 20, y: y))
                }
                context.stroke(rules, with: .color(Color(hex: 0x15151A)), lineWidth: 2)
                context.box(CGRect(x: 20, y: h - 44, width: 64, height: 24), Color(hex: 0x1F4FD8), corner: 4)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "LIVE")
                    .font(.system(size: 64, weight: .black))
                    .tracking(-2)
                Text(verbatim: "AT THE ATLAS")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(2)
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline) {
                    Text(verbatim: "FRI 21")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 24)
                    Spacer()
                    Text(verbatim: "DOORS 8 PM")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
            }
            .foregroundStyle(Color(hex: 0x15151A))
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

// MARK: - Flow

/// Fine grid, type and hairlines on a gradient: a refracting ridge needs small, regular detail to bend.
struct ShaderFlowScene: View {
    var body: some View {
        ZStack {
            LinearGradient(gradient: ShaderKit.gradient([0x140F4A, 0x5B2AD0, 0xE8418E, 0xFFB45C]), startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var grid = Path()
                var x: CGFloat = 10
                while x < w {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: h))
                    x += 20
                }
                var y: CGFloat = 10
                while y < h {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: w, y: y))
                    y += 20
                }
                context.stroke(grid, with: .color(.white.opacity(0.16)), lineWidth: 1)
                for k in 0..<7 {
                    let r = 24 + CGFloat(k) * 22
                    context.stroke(
                        Path(ellipseIn: CGRect(x: w * 0.2 - r, y: h * 0.82 - r, width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(0.22)), lineWidth: 1.5
                    )
                }
                for k in 0..<5 {
                    context.box(CGRect(x: 22, y: 150 + CGFloat(k) * 13, width: [150, 196, 120, 180, 90][k], height: 5), .white.opacity(0.75), corner: 2.5)
                }
                context.disc(CGPoint(x: w * 0.78, y: h * 0.78), 26, Color(hex: 0xFFE27A))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "FLOW")
                    .font(.system(size: 78, weight: .black, design: .rounded))
                    .tracking(-2)
                Text(verbatim: "refractive index 1.33")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 20)
            .padding(.top, 22)
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

// MARK: - Landscapes

/// Four layered landscapes (dunes, alps, forest dusk, night sea) that the displacement fade pushes into each other.
struct ShaderLandscapeScene: View {
    let index: Int

    private struct Look {
        let sky: [UInt32]
        let sun: UInt32
        let sunAt: CGPoint
        let ridges: [UInt32]
        let title: String
        let stars: Bool
    }

    private var look: Look {
        switch ((index % 4) + 4) % 4 {
        case 1: return Look(sky: [0x1E5AA8, 0x6DB6E8, 0xE8F4FB], sun: 0xFFFFFF, sunAt: CGPoint(x: 0.24, y: 0.22), ridges: [0xB9D4EA, 0x6F93BD, 0x2E4E7E, 0x1B2E55], title: "ALPS  ·  02", stars: false)
        case 2: return Look(sky: [0x2A1458, 0xC2427C, 0xFFA35C], sun: 0xFFE9A8, sunAt: CGPoint(x: 0.5, y: 0.5), ridges: [0x8E3A6E, 0x4F2560, 0x2A1846, 0x130C28], title: "DUSK  ·  03", stars: false)
        case 3: return Look(sky: [0x040818, 0x0E2248, 0x1F4D7A], sun: 0xF4F1DC, sunAt: CGPoint(x: 0.72, y: 0.2), ridges: [0x1C4A70, 0x12365A, 0x0B2542, 0x06162C], title: "NIGHT  ·  04", stars: true)
        default: return Look(sky: [0xFF8A3D, 0xFFC56B, 0xFFE9B8], sun: 0xFFF6D8, sunAt: CGPoint(x: 0.7, y: 0.3), ridges: [0xF2A65A, 0xE0783A, 0xB8502A, 0x7A2E1C], title: "DUNES  ·  01", stars: false)
        }
    }

    var body: some View {
        let look = self.look
        let seed = CGFloat(((index % 4) + 4) % 4)
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.vertical(CGRect(x: 0, y: 0, width: w, height: h * 0.8), look.sky)
            if look.stars {
                for i in 0..<60 {
                    context.disc(CGPoint(x: ShaderKit.rand(i, 101) * w, y: ShaderKit.rand(i, 102) * h * 0.5), 0.5 + ShaderKit.rand(i, 103), .white.opacity(0.4 + 0.6 * ShaderKit.rand(i, 104)))
                }
            }
            let sun = CGPoint(x: look.sunAt.x * w, y: look.sunAt.y * h)
            context.disc(sun, 46, Color(hex: look.sun, opacity: 0.2))
            context.disc(sun, 26, Color(hex: look.sun))
            for (k, hex) in look.ridges.enumerated() {
                let fk = CGFloat(k)
                let base = h * (0.52 + 0.13 * fk)
                let amp = 30 - 5 * fk
                let path = ridgePath(width: w, base: base, floor: h) { x in
                    amp * (0.6 + 0.5 * sin(x / (58 - 7 * fk) + seed * 1.7 + fk * 2.1) + 0.28 * sin(x / (19 + 3 * fk) + seed + fk))
                }
                context.fill(path, with: .color(Color(hex: hex)))
            }
            context.draw(
                Text(verbatim: look.title).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.9)),
                at: CGPoint(x: 20, y: h - 22), anchor: .leading
            )
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

// MARK: - Book pages

/// Pages of an illustrated book on cream paper: a plate, a headline and lines of text.
struct ShaderPageScene: View {
    let index: Int

    private struct Look {
        let accent: UInt32
        let plate: [UInt32]
        let chapter: String
        let title: String
        let symbol: String
    }

    private var look: Look {
        switch ((index % 4) + 4) % 4 {
        case 1: return Look(accent: 0x1F6F8B, plate: [0x0B3954, 0x1F6F8B, 0x7FD1D8], chapter: "II", title: "The Tide", symbol: "sailboat.fill")
        case 2: return Look(accent: 0x7A3E9D, plate: [0x2D1B4E, 0x7A3E9D, 0xF2A7C3], chapter: "III", title: "Night Garden", symbol: "moon.stars.fill")
        case 3: return Look(accent: 0x2E7D4F, plate: [0x143D2B, 0x2E7D4F, 0xC9E265], chapter: "IV", title: "The Forest", symbol: "tree.fill")
        default: return Look(accent: 0xC8452F, plate: [0x7A1E12, 0xE0622F, 0xFFC56B], chapter: "I", title: "First Light", symbol: "sun.horizon.fill")
        }
    }

    var body: some View {
        let look = self.look
        let page = ((index % 4) + 4) % 4
        ZStack {
            Color(hex: 0xFBF7EE)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(verbatim: "CHAPTER \(look.chapter)")
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .tracking(2.5)
                        .foregroundStyle(Color(hex: look.accent))
                    Spacer()
                    Text(verbatim: "\(12 + page * 2)")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(hex: 0x6B6257))
                }
                ZStack {
                    LinearGradient(gradient: ShaderKit.gradient(look.plate), startPoint: .top, endPoint: .bottom)
                    Image(systemName: look.symbol)
                        .font(.system(size: 54, weight: .regular))
                        .foregroundStyle(Color(hex: 0xFBF7EE))
                }
                .frame(height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.top, 10)
                Text(verbatim: look.title)
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: 0x1F1B16))
                    .padding(.top, 12)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(0..<6, id: \.self) { row in
                        Capsule()
                            .fill(Color(hex: 0x1F1B16, opacity: 0.3))
                            .frame(width: [216, 204, 220, 190, 212, 128][row], height: 3.5)
                    }
                }
                .padding(.top, 12)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

// MARK: - Holiday

/// A beach holiday, the classic home-movie subject: sun, sea, a sailboat, a palm and a striped parasol.
struct ShaderHolidayScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let horizon = h * 0.5
            context.vertical(CGRect(x: 0, y: 0, width: w, height: horizon), [0x3F9BE8, 0x8FD0F5, 0xFFE9C4])
            context.disc(CGPoint(x: w * 0.74, y: h * 0.2), 40, Color(hex: 0xFFF3C0, opacity: 0.4))
            context.disc(CGPoint(x: w * 0.74, y: h * 0.2), 24, Color(hex: 0xFFF6D6))
            for cloud in [(CGFloat(48), CGFloat(52), CGFloat(1)), (CGFloat(150), CGFloat(92), CGFloat(0.7))] {
                for k in 0..<4 {
                    context.disc(CGPoint(x: cloud.0 + CGFloat(k) * 16 * cloud.2, y: cloud.1 - (k == 1 || k == 2 ? 7 : 0) * cloud.2), 13 * cloud.2, .white.opacity(0.95))
                }
            }
            context.vertical(CGRect(x: 0, y: horizon, width: w, height: h * 0.24), [0x1A6FC2, 0x2FB3D6, 0x8EE3E0])
            for i in 0..<26 {
                let y = horizon + 4 + ShaderKit.rand(i, 111) * h * 0.2
                let x = ShaderKit.rand(i, 112) * w
                context.box(CGRect(x: x, y: y, width: 8 + ShaderKit.rand(i, 113) * 14, height: 1.6), .white.opacity(0.7), corner: 0.8)
            }
            // Sailboat on the horizon.
            let boat = CGPoint(x: w * 0.3, y: horizon + 6)
            var sail = Path()
            sail.move(to: CGPoint(x: boat.x, y: boat.y - 44))
            sail.addLine(to: CGPoint(x: boat.x + 24, y: boat.y - 6))
            sail.addLine(to: CGPoint(x: boat.x, y: boat.y - 6))
            sail.closeSubpath()
            context.fill(sail, with: .color(.white))
            var jib = Path()
            jib.move(to: CGPoint(x: boat.x - 3, y: boat.y - 36))
            jib.addLine(to: CGPoint(x: boat.x - 18, y: boat.y - 6))
            jib.addLine(to: CGPoint(x: boat.x - 3, y: boat.y - 6))
            jib.closeSubpath()
            context.fill(jib, with: .color(Color(hex: 0xFF5A4D)))
            context.box(CGRect(x: boat.x - 22, y: boat.y - 4, width: 50, height: 8), Color(hex: 0x1C2B4A), corner: 4)
            // Beach.
            context.fill(ridgePath(width: w, base: h * 0.72, floor: h) { x in 6 + 5 * sin(x / 44 + 1) }, with: .color(Color(hex: 0xF6DFA6)))
            // Parasol and towel.
            let pole = CGPoint(x: w * 0.66, y: h * 0.93)
            var stick = Path()
            stick.move(to: pole)
            stick.addLine(to: CGPoint(x: pole.x - 10, y: pole.y - 78))
            context.stroke(stick, with: .color(Color(hex: 0x6B4A2E)), lineWidth: 3)
            let top = CGPoint(x: pole.x - 10, y: pole.y - 78)
            for k in 0..<6 {
                var wedge = Path()
                let a0 = CGFloat.pi + CGFloat(k) * CGFloat.pi / 6
                wedge.move(to: top)
                wedge.addArc(center: top, radius: 46, startAngle: .radians(Double(a0)), endAngle: .radians(Double(a0 + CGFloat.pi / 6)), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(Color(hex: k % 2 == 0 ? 0xFF5A4D : 0xFFF6E8)))
            }
            context.box(CGRect(x: w * 0.42, y: h * 0.9, width: 62, height: 12), Color(hex: 0x2B6FE0), corner: 3)
            context.disc(CGPoint(x: w * 0.9, y: h * 0.9), 11, Color(hex: 0xFFC83D))
            // Palm.
            var trunk = Path()
            trunk.move(to: CGPoint(x: 30, y: h))
            trunk.addQuadCurve(to: CGPoint(x: 58, y: h * 0.42), control: CGPoint(x: 28, y: h * 0.66))
            context.stroke(trunk, with: .color(Color(hex: 0x6B4A2E)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            let crown = CGPoint(x: 58, y: h * 0.42)
            for k in 0..<7 {
                let a = -CGFloat.pi * 0.95 + CGFloat(k) * CGFloat.pi * 0.17
                var leaf = Path()
                leaf.move(to: crown)
                leaf.addQuadCurve(
                    to: CGPoint(x: crown.x + cos(a) * 62, y: crown.y + sin(a) * 34 + 22),
                    control: CGPoint(x: crown.x + cos(a) * 40, y: crown.y + sin(a) * 44 - 10)
                )
                context.stroke(leaf, with: .color(Color(hex: k % 2 == 0 ? 0x1E8A4C : 0x2FAE62)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
        }
    }
}

// MARK: - Forest at night

/// A clearing in near-total darkness. Everything sits below ≈ 20% luminance (a deer, an owl, a tent, trunks),
/// so the eye sees almost nothing and an intensifier has something to find. Only the moon and the eyes are bright.
struct ShaderForestScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.vertical(CGRect(origin: .zero, size: size), [0x05070D, 0x0A1019, 0x0C141C])
            for i in 0..<40 {
                context.disc(CGPoint(x: ShaderKit.rand(i, 121) * w, y: ShaderKit.rand(i, 122) * h * 0.4), 0.5 + ShaderKit.rand(i, 123) * 0.7, Color(white: 0.75, opacity: 0.5 + 0.5 * ShaderKit.rand(i, 124)))
            }
            context.disc(CGPoint(x: w * 0.78, y: h * 0.14), 13, Color(hex: 0xE9EEDC))
            // Far tree line, then trunks.
            context.fill(ridgePath(width: w, base: h * 0.62, floor: h) { x in 34 + 18 * abs(sin(x / 9.5)) + 12 * sin(x / 41) }, with: .color(Color(hex: 0x121B22)))
            for k in 0..<7 {
                let x = [12, 54, 92, 148, 186, 222, 250][k] as CGFloat
                let width = [14, 9, 18, 8, 12, 20, 9][k] as CGFloat
                context.box(CGRect(x: x - width / 2, y: 0, width: width, height: h * (0.78 + 0.03 * CGFloat(k % 3))), Color(hex: k % 2 == 0 ? 0x1B262C : 0x151E24))
                for b in 0..<3 {
                    var branch = Path()
                    let y = h * (0.12 + 0.14 * CGFloat(b)) + CGFloat(k) * 6
                    branch.move(to: CGPoint(x: x, y: y + 16))
                    branch.addLine(to: CGPoint(x: x + (b % 2 == 0 ? 1 : -1) * (20 + width), y: y))
                    context.stroke(branch, with: .color(Color(hex: 0x1B262C)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
            context.fill(ridgePath(width: w, base: h * 0.82, floor: h) { x in 8 + 5 * sin(x / 31 + 2) }, with: .color(Color(hex: 0x1A2420)))
            // Tent with a faint lantern.
            var tent = Path()
            tent.move(to: CGPoint(x: 26, y: h * 0.86))
            tent.addLine(to: CGPoint(x: 62, y: h * 0.68))
            tent.addLine(to: CGPoint(x: 98, y: h * 0.86))
            tent.closeSubpath()
            context.fill(tent, with: .color(Color(hex: 0x2A3238)))
            var door = Path()
            door.move(to: CGPoint(x: 52, y: h * 0.86))
            door.addLine(to: CGPoint(x: 62, y: h * 0.74))
            door.addLine(to: CGPoint(x: 72, y: h * 0.86))
            door.closeSubpath()
            context.fill(door, with: .color(Color(hex: 0x4A4632)))
            // Deer.
            let deer = Color(hex: 0x2B3236)
            let d0 = CGPoint(x: w * 0.62, y: h * 0.74)
            context.fill(Path(ellipseIn: CGRect(x: d0.x - 26, y: d0.y - 13, width: 52, height: 26)), with: .color(deer))
            for leg in [-19, -9, 10, 19] as [CGFloat] {
                context.box(CGRect(x: d0.x + leg - 2, y: d0.y + 6, width: 4, height: 30), deer, corner: 2)
            }
            var neck = Path()
            neck.move(to: CGPoint(x: d0.x + 19, y: d0.y - 4))
            neck.addLine(to: CGPoint(x: d0.x + 31, y: d0.y - 30))
            context.stroke(neck, with: .color(deer), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: d0.x + 24, y: d0.y - 42, width: 20, height: 13)), with: .color(deer))
            var antlers = Path()
            for side in [-1, 1] as [CGFloat] {
                let root = CGPoint(x: d0.x + 31 + side * 3, y: d0.y - 41)
                antlers.move(to: root)
                antlers.addLine(to: CGPoint(x: root.x + side * 9, y: root.y - 18))
                antlers.move(to: CGPoint(x: root.x + side * 4, y: root.y - 9))
                antlers.addLine(to: CGPoint(x: root.x + side * 13, y: root.y - 10))
            }
            context.stroke(antlers, with: .color(deer), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            context.disc(CGPoint(x: d0.x + 37, y: d0.y - 36), 1.7, Color(hex: 0xF2FFE0))
            // Owl on a branch.
            let owl = CGPoint(x: 168, y: h * 0.25)
            context.fill(Path(ellipseIn: CGRect(x: owl.x - 9, y: owl.y - 12, width: 18, height: 24)), with: .color(Color(hex: 0x262E33)))
            context.disc(CGPoint(x: owl.x - 3.5, y: owl.y - 5), 1.6, Color(hex: 0xF2FFE0))
            context.disc(CGPoint(x: owl.x + 3.5, y: owl.y - 5), 1.6, Color(hex: 0xF2FFE0))
            // Grass.
            for i in 0..<46 {
                let x = ShaderKit.rand(i, 131) * w
                let y = h * 0.86 + ShaderKit.rand(i, 132) * h * 0.14
                var blade = Path()
                blade.move(to: CGPoint(x: x, y: y))
                blade.addLine(to: CGPoint(x: x + (ShaderKit.rand(i, 133) - 0.5) * 8, y: y - 8 - ShaderKit.rand(i, 134) * 10))
                context.stroke(blade, with: .color(Color(hex: 0x26332B)), lineWidth: 1.6)
            }
        }
    }
}

// MARK: - Cottage

/// A daylight cottage: clear outlines and distinct tonal steps (bright sky, mid greens, dark roof and trunk).
struct ShaderCottageScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.vertical(CGRect(origin: .zero, size: size), [0x6EC1F2, 0xBFE6FA, 0xF4FAFD])
            context.disc(CGPoint(x: w * 0.82, y: h * 0.16), 22, Color(hex: 0xFFD84D))
            for cloud in [(CGFloat(40), CGFloat(58), CGFloat(1)), (CGFloat(128), CGFloat(34), CGFloat(0.75))] {
                for k in 0..<4 {
                    context.disc(CGPoint(x: cloud.0 + CGFloat(k) * 17 * cloud.2, y: cloud.1 - (k == 1 || k == 2 ? 8 : 0) * cloud.2), 14 * cloud.2, .white)
                }
            }
            context.fill(ridgePath(width: w, base: h * 0.62, floor: h) { x in 30 + 26 * sin(x / 60 + 0.4) }, with: .color(Color(hex: 0x8CCB6B)))
            context.fill(ridgePath(width: w, base: h * 0.74, floor: h) { x in 16 + 12 * sin(x / 46 + 2.6) }, with: .color(Color(hex: 0x4FA356)))
            // Path to the door.
            var lane = Path()
            lane.move(to: CGPoint(x: 150, y: h * 0.74))
            lane.addQuadCurve(to: CGPoint(x: 70, y: h), control: CGPoint(x: 150, y: h * 0.9))
            lane.addLine(to: CGPoint(x: 130, y: h))
            lane.addQuadCurve(to: CGPoint(x: 170, y: h * 0.74), control: CGPoint(x: 182, y: h * 0.9))
            lane.closeSubpath()
            context.fill(lane, with: .color(Color(hex: 0xE8D3A2)))
            // House.
            let wall = CGRect(x: 108, y: h * 0.47, width: 106, height: 82)
            context.box(wall, Color(hex: 0xFFF3DC))
            var roof = Path()
            roof.move(to: CGPoint(x: wall.minX - 12, y: wall.minY + 2))
            roof.addLine(to: CGPoint(x: wall.midX, y: wall.minY - 48))
            roof.addLine(to: CGPoint(x: wall.maxX + 12, y: wall.minY + 2))
            roof.closeSubpath()
            context.box(CGRect(x: wall.maxX - 30, y: wall.minY - 46, width: 14, height: 34), Color(hex: 0x7A2E22))
            context.fill(roof, with: .color(Color(hex: 0xA83A2A)))
            context.box(CGRect(x: wall.midX - 11, y: wall.maxY - 42, width: 22, height: 42), Color(hex: 0x3B5B8C), corner: 3)
            context.disc(CGPoint(x: wall.midX + 6, y: wall.maxY - 20), 1.8, Color(hex: 0xFFD84D))
            for x in [wall.minX + 12, wall.maxX - 34] {
                let pane = CGRect(x: x, y: wall.minY + 18, width: 22, height: 22)
                context.box(pane, Color(hex: 0x24364F), corner: 2)
                var cross = Path()
                cross.move(to: CGPoint(x: pane.midX, y: pane.minY))
                cross.addLine(to: CGPoint(x: pane.midX, y: pane.maxY))
                cross.move(to: CGPoint(x: pane.minX, y: pane.midY))
                cross.addLine(to: CGPoint(x: pane.maxX, y: pane.midY))
                context.stroke(cross, with: .color(Color(hex: 0xFFF3DC)), lineWidth: 2)
            }
            context.disc(CGPoint(x: wall.midX, y: wall.minY - 18), 8, Color(hex: 0x24364F))
            // Tree.
            context.box(CGRect(x: 48, y: h * 0.5, width: 12, height: 86), Color(hex: 0x5A3A22), corner: 3)
            for blob in [(CGFloat(54), CGFloat(0.4), CGFloat(34)), (CGFloat(34), CGFloat(0.47), CGFloat(24)), (CGFloat(76), CGFloat(0.46), CGFloat(25))] {
                context.disc(CGPoint(x: blob.0, y: h * blob.1), blob.2, Color(hex: 0x2E7D46))
            }
            context.disc(CGPoint(x: 46, y: h * 0.36), 16, Color(hex: 0x4FA356))
            // Fence.
            for k in 0..<7 {
                let x = 190 + CGFloat(k) * 11
                context.box(CGRect(x: x, y: h * 0.8, width: 5, height: 26), Color(hex: 0xFFFDF6), corner: 1.5)
            }
            context.box(CGRect(x: 186, y: h * 0.83, width: 78, height: 4), Color(hex: 0xFFFDF6))
        }
    }
}

// MARK: - Rainy street

/// A city street at night seen from indoors: big soft lights, a neon sign and headlights — what rain refracts best.
struct ShaderStreetScene: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.vertical(CGRect(origin: .zero, size: size), [0x0A0D24, 0x1B1846, 0x3A1E55, 0x15122C])
            // Skyline silhouette.
            for k in 0..<6 {
                let x = CGFloat(k) * 46 - 8
                let top = h * (0.2 + 0.2 * ShaderKit.rand(k, 141))
                context.box(CGRect(x: x, y: top, width: 42, height: h * 0.72 - top), Color(hex: 0x0D0B24))
            }
            // Out-of-focus city lights: big soft discs far away, smaller and brighter ones near the street.
            let tints: [UInt32] = [0xFF4D6D, 0xFFC247, 0x3AC4FF, 0x21D4A8, 0xFF7A1A, 0xFFE9B0, 0xB86BFF]
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 6))
                for i in 0..<14 {
                    let r = 16 + ShaderKit.rand(i, 144) * 18
                    let p = CGPoint(x: ShaderKit.rand(i, 145) * w, y: h * 0.22 + ShaderKit.rand(i, 146) * h * 0.4)
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: tints[i % tints.count], opacity: 0.3 + 0.3 * Double(ShaderKit.rand(i, 147)))))
                }
            }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 2.5))
                for i in 0..<16 {
                    let r = 6 + ShaderKit.rand(i, 151) * 9
                    let p = CGPoint(x: ShaderKit.rand(i, 152) * w, y: h * 0.46 + ShaderKit.rand(i, 153) * h * 0.26)
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: tints[(i + 3) % tints.count], opacity: 0.6 + 0.35 * Double(ShaderKit.rand(i, 154)))))
                }
            }
            // Wet road with reflections.
            context.vertical(CGRect(x: 0, y: h * 0.72, width: w, height: h * 0.28), [0x15122C, 0x07060F])
            for i in 0..<9 {
                let x = 14 + CGFloat(i) * 29
                context.box(CGRect(x: x, y: h * 0.74, width: 5, height: 40 + ShaderKit.rand(i, 148) * 30), Color(hex: tints[i % tints.count], opacity: 0.35), corner: 2.5)
            }
            // Headlights.
            for car in [CGPoint(x: 70, y: h * 0.76), CGPoint(x: 190, y: h * 0.8)] {
                context.disc(CGPoint(x: car.x - 12, y: car.y), 6, Color(hex: 0xFFF6D6))
                context.disc(CGPoint(x: car.x + 12, y: car.y), 6, Color(hex: 0xFFF6D6))
            }
            // Neon sign.
            let sign = CGRect(x: 30, y: 34, width: 116, height: 44)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 7))
                layer.stroke(Path(roundedRect: sign, cornerRadius: 10), with: .color(Color(hex: 0xFF3D8B)), lineWidth: 6)
            }
            context.stroke(Path(roundedRect: sign, cornerRadius: 10), with: .color(Color(hex: 0xFF9CC6)), lineWidth: 2.5)
            context.draw(
                Text(verbatim: "RAMEN").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: 0xFFE3EF)),
                at: CGPoint(x: sign.midX, y: sign.midY), anchor: .center
            )
            context.draw(
                Text(verbatim: "TOKYO  ·  02:10  ·  RAIN").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.75)),
                at: CGPoint(x: 20, y: h - 18), anchor: .leading
            )
        }
    }
}
