import SwiftUI

extension Effect {
    static let backgroundsHexPulse = Effect(
        id: "backgrounds.hex-pulse",
        category: .backgrounds,
        interaction: .tap,
        name: L("Hex Pulse", "蜂巢脉冲"),
        summary: L(
            "A honeycomb of dark tiles: a tap lights one cell and the light hops outward cell by cell as a hexagonal ring, with a fainter echo behind it.",
            "一面暗色蜂巢：点击点亮一格，光便一格一格向外跳动，扩成一圈六边形光环，身后还跟着一道更淡的回波。"
        ),
        prompt: L(
            "A near-black field tiled with pointy-top hexagons of 16 pt radius, each a dim rounded tile with a hairline edge and a slow ambient shimmer. A tap, with a light haptic, starts a pulse at the touched cell: light spreads by hex-grid distance at 11 cells/s, so the wavefront is a crisp hexagonal ring rather than a circle. As the front reaches a cell it snaps to full brightness and swells from 86% to 100% of its slot, then decays exponentially over about 1 s, leaving a comet-like trail of cooling tiles; each cell fires up to 0.6 cell late at random so the ring sparkles, and a second front at 45% strength follows five cells behind. Brightness maps to a ramp from deep navy through cyan to white, and the brightest tiles bloom. Idle pulses fire softly every few seconds. Technical, rhythmic, satisfying.",
            "近乎全黑的背景铺满尖顶朝上、半径 16pt 的六边形，每格是带细边的暗色砖，并有缓慢的环境微光。点击（伴随轻触感）从被触到的那格发出脉冲：光按六边形网格距离以每秒 11 格扩散，波前因此是一圈六边形而不是圆。波前到达时，该格瞬间亮到最高，并从格位的 86% 胀到 100%，随后在约 1 秒内指数衰减，留下彗尾般逐渐冷却的砖块；每格随机晚到至多 0.6 格，使光环闪烁，另有一道强度 45% 的回波跟在五格之后。亮度映射到从深海军蓝经青色到白色的色带，最亮的砖带辉光。空闲时每隔几秒有柔和脉冲自行亮起。"
        ),
        implementation: L(
            "Cells live in axial coordinates (q, r); hex distance is (|Δq| + |Δr| + |Δq + Δr|)/2. Each frame a Canvas evaluates every cell's brightness as the max over live pulses of an analytic front-plus-decay envelope, appends a scaled hexagon to one of ten brightness Paths and blooms the top bins in a blurred plusLighter layer.",
            "格子用轴坐标 (q, r) 表示，六边形距离为 (|Δq| + |Δr| + |Δq + Δr|)/2。Canvas 每帧对每格取所有存活脉冲的“波前 + 衰减”解析包络的最大值作为亮度，把缩放后的六边形加入十条亮度 Path 之一，并在模糊的 plusLighter 图层中为最亮的几档叠加辉光。"
        ),
        apis: ["Canvas", "Path", "GraphicsContext.drawLayer", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "Haptics"],
        tags: ["hexagon", "honeycomb", "pulse", "grid", "六边形", "蜂巢", "脉冲", "网格"],
        params: [
            .slider("cell", L("Cell radius", "格子半径"), 12...34, default: 16, decimals: 0, unit: "pt"),
            .slider("speed", L("Pulse speed", "脉冲速度"), 4...24, default: 11, decimals: 0, unit: "/s"),
            .slider("trail", L("Afterglow", "余辉时长"), 0.3...2.5, default: 1.0, unit: "s"),
            .choice("tone", L("Light", "光色"), [L("Cyan", "青"), L("Magenta", "洋红"), L("Sunset", "落日")]),
        ]
    ) { ctx in
        HexPulseDemo(ctx: ctx)
    }
}

private struct HexPulse {
    let q: Int
    let r: Int
    let born: Double
    let strength: Double
}

/// Pointy-top hexagons in axial coordinates.
private struct HexLayout {
    let radius: CGFloat
    let size: CGSize

    func centre(q: Int, r: Int) -> CGPoint {
        CGPoint(
            x: size.width / 2 + radius * 1.7320508 * (CGFloat(q) + CGFloat(r) / 2),
            y: size.height / 2 + radius * 1.5 * CGFloat(r)
        )
    }

    /// The cell under a stage point (cube rounding).
    func cell(at p: CGPoint) -> (Int, Int) {
        let x = (p.x - size.width / 2) / radius
        let y = (p.y - size.height / 2) / radius
        let qf = Double(x * 0.57735027 - y / 3)
        let rf = Double(y * 2 / 3)
        let sf = -qf - rf
        var q = qf.rounded()
        var r = rf.rounded()
        let s = sf.rounded()
        let dq = abs(q - qf)
        let dr = abs(r - rf)
        let ds = abs(s - sf)
        if dq > dr, dq > ds {
            q = -r - s
        } else if dr > ds {
            r = -q - s
        }
        return (Int(q), Int(r))
    }

    var rowRange: ClosedRange<Int> {
        let n = Int((size.height / 2 / (radius * 1.5)).rounded(.up)) + 1
        return -n...n
    }

    func columnRange(row r: Int) -> ClosedRange<Int> {
        let half = Double(size.width / 2 / (radius * 1.7320508))
        let shift = Double(r) / 2
        return Int((-half - shift).rounded(.down)) - 1...Int((half - shift).rounded(.up)) + 1
    }

    static func distance(_ q1: Int, _ r1: Int, _ q2: Int, _ r2: Int) -> Int {
        let dq = q1 - q2
        let dr = r1 - r2
        return (abs(dq) + abs(dr) + abs(dq + dr)) / 2
    }
}

private final class HexPulseModel {
    let clock = BackgroundClock()
    private(set) var pulses: [HexPulse] = []
    private var rng = BackgroundRNG(seed: 53)
    private var nextIdle: Double = 101.2
    private var seededStill = false

    func step(now: Double, layout: HexLayout, frozen: Bool) -> Double {
        let t = clock.advance(to: now, speed: 1)
        if frozen {
            if !seededStill {
                seededStill = true
                pulses = [HexPulse(q: 0, r: 0, born: t - 0.5, strength: 1), HexPulse(q: -3, r: 4, born: t - 1.5, strength: 0.6)]
            }
            return t
        }
        pulses.removeAll { t - $0.born > 7 }
        if t >= nextIdle {
            let p = CGPoint(
                x: layout.size.width * CGFloat(rng.range(0.1...0.9)), y: layout.size.height * CGFloat(rng.range(0.1...0.9))
            )
            let (q, r) = layout.cell(at: p)
            add(HexPulse(q: q, r: r, born: t, strength: 0.5))
            nextIdle = t + rng.range(2.4...4.2)
        }
        return t
    }

    func fire(at location: CGPoint, layout: HexLayout) {
        let (q, r) = layout.cell(at: location)
        add(HexPulse(q: q, r: r, born: clock.phase, strength: 1))
        nextIdle = max(nextIdle, clock.phase + 2.5)
    }

    private func add(_ pulse: HexPulse) {
        pulses.append(pulse)
        if pulses.count > 8 { pulses.removeFirst(pulses.count - 8) }
    }
}

private struct HexPulseDemo: View {
    let ctx: DemoContext
    @State private var model = HexPulseModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        let radius = max(ctx.cg("cell"), 8)
        ZStack {
            LinearGradient(colors: [Color(hex: 0x05060E), Color(hex: 0x0A0C1C), Color(hex: 0x05060E)], startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let layout = HexLayout(radius: radius, size: size)
                    let t = model.step(now: now, layout: layout, frozen: ctx.isStill)
                    HexPulsePainter.draw(
                        &context, layout: layout, t: t, pulses: model.pulses, speed: max(ctx["speed"], 1),
                        trail: max(ctx["trail"], 0.1), tone: ctx.int("tone")
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.light)
            model.fire(at: location, layout: HexLayout(radius: radius, size: size))
        }
        .autoplay(ctx.isPreview, every: 2.4, delay: 0.5) {
            model.fire(
                at: CGPoint(x: size.width * CGFloat.random(in: 0.2...0.8), y: size.height * CGFloat.random(in: 0.2...0.8)),
                layout: HexLayout(radius: radius, size: size)
            )
        }
        .backgroundsHint(L("Tap a cell to send a pulse", "点击格子发出脉冲"), ctx)
    }
}

private enum HexPulsePainter {
    static let levels = 10
    static let ramps: [[BackgroundRGB]] = [
        [.init(hex: 0x0E1838), .init(hex: 0x1A4FA8), .init(hex: 0x21B8E8), .init(hex: 0x9FF0FF), .init(hex: 0xFFFFFF)],
        [.init(hex: 0x1C0E38), .init(hex: 0x6A2BC8), .init(hex: 0xE04FD0), .init(hex: 0xFFB0E8), .init(hex: 0xFFFFFF)],
        [.init(hex: 0x24103A), .init(hex: 0x9A2E7A), .init(hex: 0xFF5F5A), .init(hex: 0xFFC247), .init(hex: 0xFFF8E0)],
    ]

    static func hexagon(centre: CGPoint, radius: CGFloat, into path: inout Path) {
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let p = CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
    }

    /// Brightness left behind by one front `x` cells after it passed.
    static func envelope(_ x: Double, speed: Double, trail: Double) -> Double {
        guard x > 0 else { return 0 }
        return BackgroundMath.smoothstep(0, 0.5, x) * exp(-x / (speed * trail * 0.38))
    }

    static func draw(_ context: inout GraphicsContext, layout: HexLayout, t: Double, pulses: [HexPulse], speed: Double, trail: Double, tone: Int) {
        let ramp = ramps[min(max(tone, 0), ramps.count - 1)]
        var base = Path()
        var bins = [Path](repeating: Path(), count: levels)
        for r in layout.rowRange {
            for q in layout.columnRange(row: r) {
                let centre = layout.centre(q: q, r: r)
                let late = 0.6 * BackgroundMath.hash(q, r)
                var b = 0.0
                for pulse in pulses {
                    let d = Double(HexLayout.distance(q, r, pulse.q, pulse.r)) + late
                    let front = (t - pulse.born) * speed
                    let fall = pulse.strength / (1 + d * 0.05)
                    b = max(b, fall * envelope(front - d, speed: speed, trail: trail))
                    b = max(b, 0.45 * fall * envelope(front - 5 - d, speed: speed, trail: trail))
                }
                hexagon(centre: centre, radius: layout.radius * 0.86, into: &base)
                let shimmer = 0.06 + 0.05 * sin(t * 0.8 + Double(centre.x) * 0.021 + Double(centre.y) * 0.033)
                let value = min(b + shimmer, 1)
                guard value > 0.03 else { continue }
                let level = min(Int(value * Double(levels)), levels - 1)
                hexagon(centre: centre, radius: layout.radius * (0.86 + 0.14 * CGFloat(min(b * 1.4, 1))), into: &bins[level])
            }
        }
        let joined = StrokeStyle(lineWidth: 2, lineJoin: .round)
        context.fill(base, with: .color(ramp[1].color(0.08)))
        context.stroke(base, with: .color(ramp[2].color(0.12)), style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))
        for level in 0..<levels {
            let f = (Double(level) + 0.5) / Double(levels)
            let color = BackgroundRGB.ramp(ramp, f).color(0.12 + 0.88 * pow(f, 1.4))
            context.fill(bins[level], with: .color(color))
            context.stroke(bins[level], with: .color(color), style: joined)
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 9))
            layer.blendMode = .plusLighter
            for level in (levels - 5)..<levels {
                layer.fill(bins[level], with: .color(ramp[2].color(0.16 + 0.16 * Double(level - (levels - 5)))))
            }
        }
    }
}
