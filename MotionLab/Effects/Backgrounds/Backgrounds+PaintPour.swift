import SwiftUI

extension Effect {
    static let backgroundsPaintPour = Effect(
        id: "backgrounds.paint-pour",
        category: .backgrounds,
        interaction: .tap,
        name: L("Paint Pour", "流体倾倒画"),
        summary: L(
            "Thick acrylic poured from above: each new colour lands inside the last and pushes the earlier ones out into glossy, wobbling rings.",
            "从上方倒下的浓稠丙烯：每一种新颜色都落在上一层中央，把先前的颜色向外推成一圈圈带光泽、微微晃动的色环。"
        ),
        prompt: L(
            "A top-down acrylic ring pour on a gesso-white canvas. Paint lands at one point and a new colour starts every 0.55 s, nine in all, each inside the previous; because the puddle's area grows at a constant rate, every boundary sits at r = √(14000·age) pt, so rings burst outward fast, then slow and thin as they are pushed toward the edges, while the last colour keeps flowing. Boundaries are not circles: three low-frequency lobes (3, 5 and 8 per turn) wobble them by up to 8% and drift slowly, adjacent rings sharing the same wobble so bands never cross. Every ring is thick paint: a soft dark rim below its edge, a thin highlight above, and a glossy bead where the stream lands. A new pour starts every 4.2 s, or under a tap with a medium haptic, and floods over the old one. Viscous, glossy, satisfying.",
            "俯视的丙烯环形倾倒画，底为石膏白画布。颜料落在一点，每 0.55 秒换一种颜色、共九层，每层都落在上一层之内；摊开的面积匀速增长，每条边界位于 r = √(14000·存在时间) pt 处，色环先迅速迸开，再在被推向边缘时变慢变薄，末色持续流出。边界并非正圆：每圈 3、5、8 瓣的低频起伏让它最多偏离 8% 并缓慢漂移，相邻色环共用同一组起伏，色带不交叉。每环都有厚度：边缘下方一道暗边，上方一线高光，落点处有一颗发亮的颜料珠。每 4.2 秒自动倾倒一次，点击则在手指处倾倒伴随中等触感。黏稠、油亮。"
        ),
        implementation: L(
            "Each pour stores its origin and start time; a Canvas rebuilds every ring boundary as a smooth closed Path from 72 polar samples of r·(1 + wobble(θ, r)), fills them oldest-first with an offset dark stroke and a light stroke for thickness, and discards pours once a newer one covers the stage.",
            "每次倾倒只保存落点与起始时间；Canvas 用 r·(1 + 起伏(θ, r)) 的 72 个极坐标采样重建每条色环边界的平滑闭合 Path，按由旧到新填充，并以一道偏移的暗描边和一道亮描边做出厚度；被更新的倾倒完全覆盖后，旧的即被丢弃。"
        ),
        apis: ["Canvas", "Path.addQuadCurve(to:control:)", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "Haptics"],
        tags: ["paint", "pour", "acrylic", "fluid art", "颜料", "倾倒", "流体画", "丙烯"],
        params: [
            .slider("flow", L("Flow rate", "流量"), 0.4...2.0, default: 1.0, unit: "×"),
            .slider("band", L("Colour interval", "换色间隔"), 0.25...1.2, default: 0.55, unit: "s"),
            .slider("wobble", L("Wobble", "边缘起伏"), 0...1, default: 0.5),
            .choice("palette", L("Palette", "配色"), [L("Tropical", "热带"), L("Ocean", "海洋"), L("Earth", "大地")]),
        ]
    ) { ctx in
        PaintPourDemo(ctx: ctx)
    }
}

private struct PaintPour {
    let origin: CGPoint
    let born: Double
    let seed: Int
    /// Index of the first colour, chosen to contrast with the paint it lands on.
    let offset: Int
}

private final class PaintPourModel {
    static let layers = 9
    static let area: Double = 14000

    let clock = BackgroundClock()
    private(set) var pours: [PaintPour] = []
    private var rng = BackgroundRNG(seed: 31)
    private var nextAuto: Double = 100.2
    private var counter = 0
    private var size: CGSize = .zero
    private var interval = 0.55

    func step(now: Double, size newSize: CGSize, flow: Double, interval: Double, frozen: Bool) -> Double {
        self.interval = interval
        let t = clock.advance(to: now, speed: 1)
        if newSize != size {
            size = newSize
            if frozen {
                pours = [
                    PaintPour(origin: CGPoint(x: newSize.width * 0.36, y: newSize.height * 0.4), born: t - 13, seed: 0, offset: 0),
                    PaintPour(origin: CGPoint(x: newSize.width * 0.66, y: newSize.height * 0.62), born: t - 3.4, seed: 1, offset: 4),
                ]
                counter = 2
            }
        }
        guard !frozen else { return t }
        if t >= nextAuto {
            let p = CGPoint(x: size.width * CGFloat(rng.range(0.22...0.78)), y: size.height * CGFloat(rng.range(0.22...0.78)))
            add(at: p, born: t)
            nextAuto = t + 4.2
        }
        // Drop everything under a pour that already covers the whole stage.
        if let cover = pours.lastIndex(where: { covers($0, t: t, flow: flow) }), cover > 0 {
            pours.removeFirst(cover)
        }
        return t
    }

    func pour(at location: CGPoint) {
        add(at: location, born: clock.phase)
        nextAuto = clock.phase + 5
    }

    private func add(at location: CGPoint, born: Double) {
        // Start three colours away from whatever the previous pour is pouring right now.
        var offset = 0
        if let last = pours.last {
            let layer = min(Int(max(born - last.born, 0) / interval), PaintPourModel.layers - 1)
            offset = last.offset + layer + 3
        }
        pours.append(PaintPour(origin: location, born: born, seed: counter, offset: offset))
        counter += 1
        if pours.count > 7 { pours.removeFirst(pours.count - 7) }
    }

    private func covers(_ pour: PaintPour, t: Double, flow: Double) -> Bool {
        let far = max(
            hypot(pour.origin.x, pour.origin.y), hypot(size.width - pour.origin.x, pour.origin.y),
            hypot(pour.origin.x, size.height - pour.origin.y), hypot(size.width - pour.origin.x, size.height - pour.origin.y)
        )
        let r = (PaintPourModel.area * flow * max(t - pour.born, 0)).squareRoot()
        return CGFloat(r) * 0.82 > far
    }
}

private struct PaintPourDemo: View {
    let ctx: DemoContext
    @State private var model = PaintPourModel()

    var body: some View {
        ZStack {
            Color(hex: 0xF4EFE6)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let flow = max(ctx["flow"], 0.1)
                    let t = model.step(now: now, size: size, flow: flow, interval: max(ctx["band"], 0.1), frozen: ctx.isStill)
                    PaintPourPainter.draw(
                        &context, size: size, t: t, pours: model.pours, flow: flow, interval: max(ctx["band"], 0.1),
                        wobble: ctx["wobble"], palette: ctx.int("palette")
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.medium)
            model.pour(at: location)
        }
        .backgroundsChipHint(L("Tap to pour paint there", "点击在那里倒下颜料"), ctx)
    }
}

private enum PaintPourPainter {
    static let palettes: [[UInt32]] = [
        [0xFF5A7A, 0xFFC247, 0x18C8B4, 0xFFF4E0, 0x7B4DFF, 0xFF8A3C],
        [0x0B3C6E, 0x1FA7C9, 0xE9F7F4, 0x19C6A0, 0x12224F, 0x7FD9F0],
        [0xB5532A, 0xF0D9B0, 0x3F5B4A, 0xE0A040, 0x2A2420, 0xD98A6A],
    ]

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, pours: [PaintPour], flow: Double, interval: Double,
        wobble: Double, palette: Int
    ) {
        let colors = palettes[min(max(palette, 0), palettes.count - 1)]
        for pour in pours {
            let age = t - pour.born
            guard age > 0 else { continue }
            let last = min(Int(age / interval), PaintPourModel.layers - 1)
            for k in 0...last {
                let ringAge = age - Double(k) * interval
                let r = (PaintPourModel.area * flow * ringAge).squareRoot()
                guard r > 0.5 else { continue }
                let color = Color(hex: colors[(k + pour.offset) % colors.count])
                let path = boundary(origin: pour.origin, radius: r, seed: pour.seed, t: t, wobble: wobble)
                // Thick paint: a dark rim under the edge, the body, then a thin highlight on the upper edge.
                var rim = context
                rim.translateBy(x: 0, y: 2.2)
                rim.stroke(path, with: .color(.black.opacity(0.2)), lineWidth: 4)
                context.fill(path, with: .color(color))
                var gloss = context
                gloss.translateBy(x: -0.7, y: -1.1)
                gloss.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1.1)
            }
            // The bead where the stream lands, while colours are still changing.
            let pouring = Double(PaintPourModel.layers) * interval
            if age < pouring + 0.6 {
                let fade = 1 - BackgroundMath.smoothstep(pouring, pouring + 0.6, age)
                let pulse = 1 + 0.12 * sin(age * 14)
                let r = CGFloat(7.5 * pulse)
                let bead = CGRect(x: pour.origin.x - r, y: pour.origin.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: bead.offsetBy(dx: 0, dy: 2)), with: .color(.black.opacity(0.22 * fade)))
                context.fill(Path(ellipseIn: bead), with: .color(Color(hex: colors[(last + pour.offset) % colors.count]).opacity(fade)))
                context.fill(
                    Path(ellipseIn: CGRect(x: pour.origin.x - r * 0.55, y: pour.origin.y - r * 0.62, width: r * 0.7, height: r * 0.45)),
                    with: .color(.white.opacity(0.75 * fade))
                )
            }
        }
        // Wet gloss over the whole surface.
        let sheen = Gradient(stops: [
            .init(color: .white.opacity(0.16), location: 0),
            .init(color: .white.opacity(0), location: 0.45),
            .init(color: .black.opacity(0.1), location: 1),
        ])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(sheen, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
        )
    }

    /// A wobbling closed boundary. The wobble depends on the angle and (slowly) on the radius, so neighbouring
    /// rings share it and never cross.
    private static func boundary(origin: CGPoint, radius: Double, seed: Int, t: Double, wobble: Double) -> Path {
        let samples = 72
        let s1 = BackgroundMath.rand(seed, 2401) * BackgroundMath.tau
        let s2 = BackgroundMath.rand(seed, 2402) * BackgroundMath.tau
        let s3 = BackgroundMath.rand(seed, 2403) * BackgroundMath.tau
        let amount = wobble * 0.16 * BackgroundMath.smoothstep(0, 70, radius)
        var points: [CGPoint] = []
        points.reserveCapacity(samples)
        for i in 0..<samples {
            let theta = Double(i) / Double(samples) * BackgroundMath.tau
            let n = 0.5 * sin(3 * theta + s1 + radius * 0.006)
                + 0.3 * sin(5 * theta + s2 - radius * 0.011 + t * 0.05)
                + 0.2 * sin(8 * theta + s3 + radius * 0.017 - t * 0.08)
            let r = radius * (1 + amount * n)
            points.append(CGPoint(x: origin.x + CGFloat(cos(theta) * r), y: origin.y + CGFloat(sin(theta) * r)))
        }
        // Smooth closed curve through the midpoints.
        var path = Path()
        let first = CGPoint(x: (points[samples - 1].x + points[0].x) / 2, y: (points[samples - 1].y + points[0].y) / 2)
        path.move(to: first)
        for i in 0..<samples {
            let next = points[(i + 1) % samples]
            let mid = CGPoint(x: (points[i].x + next.x) / 2, y: (points[i].y + next.y) / 2)
            path.addQuadCurve(to: mid, control: points[i])
        }
        path.closeSubpath()
        return path
    }
}
