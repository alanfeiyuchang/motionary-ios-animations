import SwiftUI

extension Effect {
    static let backgroundsMarbling = Effect(
        id: "backgrounds.marbling",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Ink Marbling", "湿拓流彩"),
        summary: L(
            "Paper-marbling inks float on water: tap to drop a new colour, drag to comb the bands into swirls.",
            "颜料浮在水面上的湿拓画：点击滴入新色，拖动把色带梳成漩涡纹。"
        ),
        prompt: L(
            "A tray of water covered edge to edge with floating ink in five colours, already combed into classic marbled bands with crisp, hair-thin pale outlines. Tapping drops ink: a new disc swells to 46 pt radius with an exponential ease of 9/s, and because the surface is incompressible every existing band is pushed outward by exactly the area added (r' = √(r² + R²)), so rings nest instead of overlapping. Dragging combs the surface like a stylus: ink under the finger follows it fully and the pull fades with distance d as 1 / (1 + (d/34)²)^1.5, drawing bands into feathers and swirls. At rest three broad vortices turn the whole sheet a few degrees back and forth on an 18 s cycle so it never freezes. A soft haptic marks each drop. Hand-made, fluid, meditative.",
            "一盘水面被五种颜色的浮墨铺满，已梳成经典的大理石纹，色带边缘带着发丝般的浅色描线。点击滴墨：新墨滴以 9/s 的指数缓动扩张到半径 46pt；水面不可压缩，原有色带都按新增面积被精确向外推开（r' = √(r² + R²)），墨环层层相套而不互相覆盖。拖动像拓笔一样梳理水面：指尖下的墨完全跟随手指，牵引力随距离 d 按 1 / (1 + (d/34)²)^1.5 衰减，把色带拉成羽纹与漩涡。静止时三个宽大的涡流以 18 秒为周期带着画面来回转动几度，永不凝固。每次滴墨伴随轻柔触感。手工感、流动、令人沉静。"
        ),
        implementation: L(
            "Every ink ring is a closed polyline held in a reference model. Drops and strokes are closed-form displacements applied to all vertices (mathematical marbling), followed by adaptive resampling; a Canvas fills the rings oldest-first and strokes a hairline.",
            "每个墨环是保存在引用类型模型中的闭合折线。滴墨与梳理都是作用于全部顶点的闭式位移（数学湿拓），随后自适应重采样；Canvas 按从旧到新的顺序填充墨环并描一道细线。"
        ),
        apis: ["Canvas", "Path", "TimelineView(.animation)", "SpatialTapGesture", "DragGesture", "Haptics"],
        tags: ["marbling", "ink", "swirl", "ebru", "湿拓", "大理石纹", "流体", "墨"],
        params: [
            .slider("drop", L("Drop size", "墨滴大小"), 24...80, default: 46, decimals: 0, unit: "pt"),
            .slider("tine", L("Comb width", "梳理宽度"), 14...70, default: 34, decimals: 0, unit: "pt"),
            .slider("swirl", L("Idle swirl", "静态涡流"), 0...2.5, default: 1.0, unit: "×"),
            .choice("palette", L("Inks", "配色"), [L("Classic", "经典"), L("Lagoon", "泻湖"), L("Neon", "霓虹")]),
        ]
    ) { ctx in
        MarblingDemo(ctx: ctx)
    }
}

private struct MarblePalette {
    let base: Color
    let inks: [Color]
    let line: Color

    static let all: [MarblePalette] = [
        MarblePalette(
            base: Color(hex: 0x1D2A44),
            inks: [Color(hex: 0xE8D9B5), Color(hex: 0xC8553D), Color(hex: 0x2F6F8F), Color(hex: 0xE0A93B), Color(hex: 0x12203A)],
            line: Color(hex: 0xFFF6E0)
        ),
        MarblePalette(
            base: Color(hex: 0x0E3B43),
            inks: [Color(hex: 0xF4F1DE), Color(hex: 0xE07A5F), Color(hex: 0x3D9A8B), Color(hex: 0xF2CC8F), Color(hex: 0x14535E)],
            line: Color(hex: 0xFFFFFF)
        ),
        MarblePalette(
            base: Color(hex: 0x120C2C),
            inks: [Color(hex: 0xFF5FA2), Color(hex: 0x6E7BFF), Color(hex: 0x21D4A8), Color(hex: 0xFFC247), Color(hex: 0x24124F)],
            line: Color(hex: 0xFFFFFF)
        ),
    ]
}

private struct MarbleRing {
    var points: [CGPoint]
    let ink: Int
}

private struct MarbleGrowth {
    let centre: CGPoint
    var current: CGFloat
    let target: CGFloat
}

private final class MarbleModel {
    private(set) var rings: [MarbleRing] = []
    private var growths: [MarbleGrowth] = []
    private var size: CGSize = .zero
    private var last: Double?
    private var time: Double = 0
    private var inkCursor = 0
    private var actions = 0
    /// A scripted comb stroke (autoplay): from → to over `duration`, starting at `time`.
    private var script: (from: CGPoint, to: CGPoint, start: Double, done: CGFloat)?
    var touchPrevious: CGPoint?

    // MARK: Building

    private func rebuild(for newSize: CGSize) {
        size = newSize
        rings = []
        growths = []
        script = nil
        var rng = BackgroundRNG(seed: 20)
        let unit = min(newSize.width, newSize.height)
        addDrop(at: CGPoint(x: newSize.width / 2, y: newSize.height / 2), radius: unit * 0.5, animated: false)
        for _ in 0..<13 {
            let point = CGPoint(x: newSize.width * CGFloat(rng.range(0.1...0.9)), y: newSize.height * CGFloat(rng.range(0.1...0.9)))
            addDrop(at: point, radius: unit * CGFloat(rng.range(0.13...0.24)), animated: false)
        }
        // Comb it: alternating vertical passes, then one diagonal pull.
        for k in 0..<4 {
            let x = newSize.width * (CGFloat(k) + 0.5) / 4
            let up = k % 2 == 0
            let a = CGPoint(x: x, y: up ? newSize.height + 30 : -30)
            let b = CGPoint(x: x, y: up ? -30 : newSize.height + 30)
            comb(from: a, to: b, width: 30)
            resample()
        }
        comb(from: CGPoint(x: -20, y: newSize.height * 0.3), to: CGPoint(x: newSize.width + 20, y: newSize.height * 0.62), width: 26)
        resample()
    }

    // MARK: Operations

    func addDrop(at centre: CGPoint, radius: CGFloat, animated: Bool = true) {
        let start: CGFloat = animated ? 3 : radius
        push(from: centre, areaDelta: start * start)
        var points: [CGPoint] = []
        let count = 72
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(count) * 2 * .pi
            points.append(CGPoint(x: centre.x + start * cos(angle), y: centre.y + start * sin(angle)))
        }
        rings.append(MarbleRing(points: points, ink: inkCursor))
        inkCursor += 1
        if animated {
            growths.append(MarbleGrowth(centre: centre, current: start * start, target: radius * radius))
        }
        if rings.count > 26 { rings.removeFirst(rings.count - 26) }
    }

    /// Incompressible radial push: a disc of area π·areaDelta appears at `centre`.
    private func push(from centre: CGPoint, areaDelta: CGFloat) {
        guard areaDelta > 0 else { return }
        for r in rings.indices {
            for i in rings[r].points.indices {
                let dx = rings[r].points[i].x - centre.x
                let dy = rings[r].points[i].y - centre.y
                let d2 = max(dx * dx + dy * dy, 0.25)
                let scale = (1 + areaDelta / d2).squareRoot()
                rings[r].points[i] = CGPoint(x: centre.x + dx * scale, y: centre.y + dy * scale)
            }
        }
    }

    /// Stylus stroke from `a` to `b`, split into short steps so the falloff follows the tip.
    func comb(from a: CGPoint, to b: CGPoint, width: CGFloat) {
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length > 0.01 else { return }
        let steps = max(Int((length / 8).rounded(.up)), 1)
        let step = CGVector(dx: (b.x - a.x) / CGFloat(steps), dy: (b.y - a.y) / CGFloat(steps))
        let w2 = max(width * width, 1)
        for s in 0..<steps {
            let tip = CGPoint(x: a.x + step.dx * CGFloat(s), y: a.y + step.dy * CGFloat(s))
            for r in rings.indices {
                for i in rings[r].points.indices {
                    let dx = rings[r].points[i].x - tip.x
                    let dy = rings[r].points[i].y - tip.y
                    let q = 1 + (dx * dx + dy * dy) / w2
                    let weight = 1 / (q * q.squareRoot())
                    guard weight > 0.004 else { continue }
                    rings[r].points[i].x += step.dx * weight
                    rings[r].points[i].y += step.dy * weight
                }
            }
        }
    }

    private func resample() {
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -60, dy: -60)
        for r in rings.indices {
            let source = rings[r].points
            guard source.count > 2 else { continue }
            var result: [CGPoint] = []
            result.reserveCapacity(source.count + 32)
            let budget = 900
            for i in source.indices {
                let p = source[i]
                let q = source[(i + 1) % source.count]
                let d = hypot(q.x - p.x, q.y - p.y)
                // Off-stage geometry can stay coarse.
                let visible = bounds.contains(p) || bounds.contains(q)
                let limit: CGFloat = visible ? 7 : 40
                if d < 1.6, result.count > 12, let lastPoint = result.last, hypot(p.x - lastPoint.x, p.y - lastPoint.y) < 1.6 {
                    continue
                }
                result.append(p)
                if d > limit, result.count < budget {
                    let pieces = min(Int(d / limit) + 1, 6)
                    for k in 1..<pieces {
                        let u = CGFloat(k) / CGFloat(pieces)
                        result.append(CGPoint(x: p.x + (q.x - p.x) * u, y: p.y + (q.y - p.y) * u))
                    }
                }
            }
            rings[r].points = result
        }
        // Ink that has been pushed completely off the stage is gone.
        let keep = CGRect(origin: .zero, size: size).insetBy(dx: -30, dy: -30)
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        if rings.count > 6 {
            rings.removeAll { ring in
                !ring.points.contains { keep.contains($0) } && !MarbleModel.polygon(ring.points, contains: middle)
            }
        }
    }

    /// Even-odd ray cast. A ring with no vertex on stage may still cover it entirely.
    private static func polygon(_ points: [CGPoint], contains p: CGPoint) -> Bool {
        var inside = false
        var j = points.count - 1
        for i in points.indices {
            let a = points[i]
            let b = points[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    // MARK: Frame

    func step(now: Double, size newSize: CGSize, swirl: Double, frozen: Bool) {
        if newSize != size || rings.isEmpty { rebuild(for: newSize) }
        guard !frozen else { return }
        var dt = 0.0
        if let last = last { dt = min(max(now - last, 0), 1.0 / 20.0) }
        last = now
        time += dt
        guard dt > 0 else { return }

        // Growing drops.
        let ease = CGFloat(1 - exp(-dt * 9))
        for g in growths.indices {
            let delta = (growths[g].target - growths[g].current) * ease
            push(from: growths[g].centre, areaDelta: delta)
            growths[g].current += delta
        }
        growths.removeAll { $0.target - $0.current < 4 }

        // Scripted comb stroke.
        if let s = script {
            let u = CGFloat(BackgroundMath.smoothstep(0, 1, (time - s.start) / 1.1))
            if u > s.done {
                let a = CGPoint(x: s.from.x + (s.to.x - s.from.x) * s.done, y: s.from.y + (s.to.y - s.from.y) * s.done)
                let b = CGPoint(x: s.from.x + (s.to.x - s.from.x) * u, y: s.from.y + (s.to.y - s.from.y) * u)
                comb(from: a, to: b, width: 34)
                script?.done = u
            }
            if u >= 1 { script = nil }
        }

        // Idle swirl: three static vortices whose strength oscillates, so the sheet rocks instead of mixing.
        if swirl > 0.001 {
            let strength = CGFloat(cos(time * BackgroundMath.tau / 18) * 0.05 * swirl * dt)
            let unit = min(size.width, size.height)
            let vortices: [(CGPoint, CGFloat, CGFloat)] = [
                (CGPoint(x: size.width * 0.3, y: size.height * 0.34), unit * 0.5, 1),
                (CGPoint(x: size.width * 0.72, y: size.height * 0.6), unit * 0.45, -1.2),
                (CGPoint(x: size.width * 0.4, y: size.height * 0.85), unit * 0.4, 0.8),
            ]
            for r in rings.indices {
                for i in rings[r].points.indices {
                    let p = rings[r].points[i]
                    var vx: CGFloat = 0
                    var vy: CGFloat = 0
                    for (centre, radius, spin) in vortices {
                        let dx = p.x - centre.x
                        let dy = p.y - centre.y
                        let falloff = exp(-(dx * dx + dy * dy) / (radius * radius)) * spin
                        vx += -dy * falloff
                        vy += dx * falloff
                    }
                    rings[r].points[i] = CGPoint(x: p.x + vx * strength, y: p.y + vy * strength)
                }
            }
        }
        resample()
    }

    // MARK: Input

    func drag(to point: CGPoint, width: CGFloat) {
        if let previous = touchPrevious {
            comb(from: previous, to: point, width: width)
        }
        touchPrevious = point
    }

    /// Autoplay / intro: alternately drop ink and pull one stroke through the sheet.
    func playNext(dropRadius: CGFloat) {
        guard size.width > 0 else { return }
        actions += 1
        var rng = BackgroundRNG(seed: UInt64(actions) &* 7919)
        if actions % 2 == 1 {
            let point = CGPoint(x: size.width * CGFloat(rng.range(0.25...0.75)), y: size.height * CGFloat(rng.range(0.25...0.75)))
            addDrop(at: point, radius: dropRadius)
        } else {
            let angle = rng.range(0...BackgroundMath.tau)
            let reach = Double(min(size.width, size.height)) * 0.42
            let centre = CGPoint(x: size.width * CGFloat(rng.range(0.4...0.6)), y: size.height * CGFloat(rng.range(0.4...0.6)))
            let offset = CGVector(dx: CGFloat(cos(angle) * reach), dy: CGFloat(sin(angle) * reach))
            script = (
                from: CGPoint(x: centre.x - offset.dx, y: centre.y - offset.dy),
                to: CGPoint(x: centre.x + offset.dx, y: centre.y + offset.dy),
                start: time,
                done: 0
            )
        }
    }
}

private struct MarblingDemo: View {
    let ctx: DemoContext
    @State private var model = MarbleModel()

    var body: some View {
        let palette = MarblePalette.all[min(max(ctx.int("palette"), 0), MarblePalette.all.count - 1)]
        ZStack {
            palette.base
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    model.step(now: now, size: size, swirl: ctx["swirl"], frozen: ctx.isStill)
                    MarblingDemo.draw(&context, size: size, rings: model.rings, palette: palette)
                }
            }
        }
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                Haptics.tap(.soft)
                model.addDrop(at: value.location, radius: ctx.cg("drop"))
            }
        )
        .backgroundsTouch { location in
            model.drag(to: location, width: ctx.cg("tine"))
        } onEnded: {
            model.touchPrevious = nil
        }
        .autoplay(ctx.isPreview, every: 2.4, delay: 0.5) {
            model.playNext(dropRadius: ctx.cg("drop"))
        }
        // The inks are too varied for plain caption text, so the hint sits on a dark chip.
        .backgroundsChipHint(L("Tap to drop ink · swipe sideways to comb", "点击滴墨 · 横向拖动梳理"), ctx)
    }

    private static func draw(_ context: inout GraphicsContext, size: CGSize, rings: [MarbleRing], palette: MarblePalette) {
        for ring in rings {
            guard ring.points.count > 2 else { continue }
            var path = Path()
            path.addLines(ring.points)
            path.closeSubpath()
            context.fill(path, with: .color(palette.inks[ring.ink % palette.inks.count]))
            context.stroke(path, with: .color(palette.line.opacity(0.22)), lineWidth: 0.6)
        }
        // Wet gloss.
        let gloss = Gradient(stops: [
            .init(color: .white.opacity(0.14), location: 0),
            .init(color: .white.opacity(0), location: 0.45),
            .init(color: .black.opacity(0.18), location: 1),
        ])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(gloss, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
        )
    }
}
