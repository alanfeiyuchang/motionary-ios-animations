import SwiftUI

extension Effect {
    static let backgroundsCircuitTraces = Effect(
        id: "backgrounds.circuit-traces",
        category: .backgrounds,
        interaction: .tap,
        name: L("Circuit Traces", "电路走线"),
        summary: L(
            "A printed circuit board fanning out from a chip: pulses of light run the traces, turn the 45° corners and flash the vias they reach.",
            "从芯片向四周铺开的印刷电路板：光脉冲沿走线奔跑，拐过 45° 折角，点亮抵达的过孔。"
        ),
        prompt: L(
            "A dark emerald circuit board. A black chip sits in the centre and 30 copper traces leave its pins on a 17 pt grid: each runs straight out, jogs at 45° now and then, never crosses another, and ends in a ring-shaped via or runs off the edge. At rest the traces are dull, with a faint sheen. Pulses of light travel outward at 140 pt/s, each a 56 pt comet with a white head and a fading tail in the board's accent colour, softly blooming; when a head reaches a via, the via flares and fades over 0.3 s. Each trace re-fires on its own irregular schedule, so the board twinkles like working logic. Tapping fires the seven traces nearest the finger at once, flashes the chip and spreads a faint ring from the touch, with a rigid haptic. Precise, electric, busy.",
            "深祖母绿电路板。中央一枚黑色芯片，30 条铜走线从引脚沿 17pt 网格伸出：先笔直向外，不时以 45° 拐折，互不交叉，终止于环形过孔或延伸出画面。静止时走线暗淡，略带微光。光脉冲以每秒 140pt 向外传播，每个是长 56pt 的彗星：头部发白，尾部以强调色渐隐并带柔和辉光；头部抵达过孔时，过孔亮起并在 0.3 秒内熄灭。每条走线按各自不规则的节奏反复触发，整块板子像运算中的逻辑电路一样闪烁。点击让离手指最近的七条走线同时发出脉冲，芯片闪亮，触点扩散出一圈淡淡光环，伴随硬朗触感。精确、带电。"
        ),
        implementation: L(
            "The layout is generated once per size from a seeded random walk on a grid with node and diagonal occupancy sets, and kept as polylines; a Canvas strokes the static copper, then draws each pulse as two trimmedPath(from:to:) slices of its trace in a blurred plusLighter layer and a sharp pass.",
            "布线对每个尺寸只生成一次：在网格上做带种子的随机游走，并用节点与对角线占用集合避免交叉，结果保存为折线；Canvas 先描出静态铜线，再把每个脉冲画成其走线上的两段 trimmedPath(from:to:)，各在模糊的 plusLighter 图层和清晰图层中绘制一次。"
        ),
        apis: ["Canvas", "Path.trimmedPath(from:to:)", "GraphicsContext.drawLayer", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "Haptics"],
        tags: ["circuit", "PCB", "traces", "pulse", "电路", "电路板", "走线", "脉冲"],
        params: [
            .slider("density", L("Traces", "走线数量"), 12...48, default: 30, step: 1, decimals: 0),
            .slider("speed", L("Pulse speed", "脉冲速度"), 0.3...3.0, default: 1.0, unit: "×"),
            .slider("length", L("Pulse length", "脉冲长度"), 20...120, default: 56, decimals: 0, unit: "pt"),
            .choice("tone", L("Board", "板色"), [L("Emerald", "祖母绿"), L("Cobalt", "钴蓝"), L("Gold", "黑金")]),
        ]
    ) { ctx in
        CircuitTracesDemo(ctx: ctx)
    }
}

private struct CircuitTrace {
    let points: [CGPoint]
    let path: Path
    let length: CGFloat
    let hasVia: Bool
    /// Extra distance between automatic pulses, and the pulse's offset in that cycle.
    let gap: CGFloat
    let offset: CGFloat
}

private struct CircuitLayout {
    var traces: [CircuitTrace] = []
    var chip: CGRect = .zero
    var pins = Path()

    static let pitch: CGFloat = 17
    private static let directions: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]

    static func make(size: CGSize, count: Int) -> CircuitLayout {
        var rng = BackgroundRNG(seed: 67)
        let cols = Int(size.width / pitch) + 1
        let rows = Int(size.height / pitch) + 1
        let ox = (size.width - CGFloat(cols - 1) * pitch) / 2
        let oy = (size.height - CGFloat(rows - 1) * pitch) / 2
        func point(_ x: Int, _ y: Int) -> CGPoint { CGPoint(x: ox + CGFloat(x) * pitch, y: oy + CGFloat(y) * pitch) }

        let half = 3
        let cx0 = cols / 2 - half
        let cy0 = rows / 2 - half
        let cx1 = cx0 + half * 2
        let cy1 = cy0 + half * 2
        var occupied = Set<Int>()
        var diagonals = Set<Int>()
        func key(_ x: Int, _ y: Int) -> Int { (y + 8) * 1000 + (x + 8) }
        for y in cy0...cy1 {
            for x in cx0...cx1 { occupied.insert(key(x, y)) }
        }

        // Pins along the four sides (corners excluded), with their outward direction.
        var starts: [(Int, Int, Int)] = []
        for k in 1..<(half * 2) {
            starts.append((cx0 + k, cy0, 6))
            starts.append((cx0 + k, cy1, 2))
            starts.append((cx0, cy0 + k, 4))
            starts.append((cx1, cy0 + k, 0))
        }
        starts.shuffle(using: &rng)
        // Extra traces start from free-standing pads out on the board.
        var guardCount = 0
        while starts.count < count, guardCount < 400 {
            guardCount += 1
            let x = Int(rng.range(0...Double(cols - 1)).rounded())
            let y = Int(rng.range(0...Double(rows - 1)).rounded())
            guard !occupied.contains(key(x, y)), !starts.contains(where: { abs($0.0 - x) < 2 && abs($0.1 - y) < 2 }) else { continue }
            starts.append((x, y, Int(rng.range(0...3.99)) * 2))
        }

        var layout = CircuitLayout()
        layout.chip = CGRect(origin: point(cx0, cy0), size: CGSize(width: CGFloat(half * 2) * pitch, height: CGFloat(half * 2) * pitch))
        for (index, start) in starts.prefix(count).enumerated() {
            var x = start.0
            var y = start.1
            let outward = start.2
            var heading = outward
            var straight = 2
            var nodes = [point(x, y)]
            occupied.insert(key(x, y))
            let limit = Int(rng.range(5...15))
            var ranOff = false
            for _ in 0..<limit {
                var options = [heading]
                if straight <= 0, rng.unit() < 0.34 {
                    let turn = rng.unit() < 0.5 ? 1 : -1
                    options = [(heading + turn + 8) % 8, heading, (heading - turn + 8) % 8]
                } else {
                    options.append(contentsOf: [(heading + 1) % 8, (heading + 7) % 8])
                }
                var moved = false
                for option in options {
                    // Stay within 45° of the trace's outward direction.
                    let diff = min((option - outward + 8) % 8, (outward - option + 8) % 8)
                    guard diff <= 1 else { continue }
                    let d = directions[option]
                    let nx = x + d.0
                    let ny = y + d.1
                    if nx < -1 || ny < -1 || nx > cols || ny > rows {
                        nodes.append(point(nx, ny))
                        ranOff = true
                        break
                    }
                    guard !occupied.contains(key(nx, ny)) else { continue }
                    if d.0 != 0, d.1 != 0 {
                        // A diagonal may not cross the other diagonal of the same grid cell.
                        let cell = key(min(x, nx), min(y, ny)) * 2
                        let kind = d.0 * d.1 > 0 ? 0 : 1
                        guard !diagonals.contains(cell + 1 - kind) else { continue }
                        diagonals.insert(cell + kind)
                    }
                    straight = option == heading ? straight - 1 : 2
                    heading = option
                    x = nx
                    y = ny
                    occupied.insert(key(x, y))
                    nodes.append(point(x, y))
                    moved = true
                    break
                }
                if !moved || ranOff { break }
            }
            guard nodes.count >= 3 else { continue }
            var path = Path()
            path.addLines(nodes)
            var length: CGFloat = 0
            for i in 1..<nodes.count { length += hypot(nodes[i].x - nodes[i - 1].x, nodes[i].y - nodes[i - 1].y) }
            let gap = CGFloat(rng.range(220...640))
            layout.traces.append(CircuitTrace(
                points: nodes, path: path, length: length, hasVia: !ranOff, gap: gap, offset: CGFloat(rng.unit()) * (length + gap)
            ))
            if index < (half * 2 - 1) * 4 {
                let p = nodes[0]
                layout.pins.addRect(CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
            } else {
                layout.pins.addEllipse(in: CGRect(x: nodes[0].x - 3.5, y: nodes[0].y - 3.5, width: 7, height: 7))
            }
        }
        return layout
    }
}

private struct CircuitShot {
    let trace: Int
    let born: Double
}

private struct CircuitTap {
    let point: CGPoint
    let born: Double
}

private final class CircuitModel {
    let clock = BackgroundClock()
    private(set) var layout = CircuitLayout()
    private(set) var shots: [CircuitShot] = []
    private(set) var taps: [CircuitTap] = []
    private var key = ""

    func step(now: Double, size: CGSize, count: Int, speed: Double) -> Double {
        let t = clock.advance(to: now, speed: speed)
        let newKey = "\(Int(size.width))x\(Int(size.height))-\(count)"
        if newKey != key {
            key = newKey
            layout = CircuitLayout.make(size: size, count: count)
            shots = []
        }
        shots.removeAll { t - $0.born > 8 }
        taps.removeAll { t - $0.born > 1.2 }
        return t
    }

    /// Fire the traces nearest to `location`.
    func fire(at location: CGPoint) {
        let ranked = layout.traces.indices
            .map { index -> (Int, CGFloat) in
                let nearest = layout.traces[index].points.map { hypot($0.x - location.x, $0.y - location.y) }.min() ?? .infinity
                return (index, nearest)
            }
            .sorted { $0.1 < $1.1 }
        for (index, _) in ranked.prefix(7) {
            shots.append(CircuitShot(trace: index, born: clock.phase))
        }
        taps.append(CircuitTap(point: location, born: clock.phase))
        if shots.count > 60 { shots.removeFirst(shots.count - 60) }
    }
}

private struct CircuitTracesDemo: View {
    let ctx: DemoContext
    @State private var model = CircuitModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        let tone = CircuitPainter.tones[min(max(ctx.int("tone"), 0), CircuitPainter.tones.count - 1)]
        ZStack {
            LinearGradient(colors: [Color(hex: tone.boardTop), Color(hex: tone.boardBottom)], startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.step(now: now, size: size, count: max(ctx.int("density"), 1), speed: ctx["speed"])
                    CircuitPainter.draw(
                        &context, size: size, t: t, layout: model.layout, shots: model.shots, taps: model.taps,
                        tail: max(ctx.cg("length"), 4), tone: tone
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.rigid)
            model.fire(at: location)
        }
        .autoplay(ctx.isPreview, every: 2.8, delay: 0.7) {
            model.fire(at: CGPoint(x: size.width * CGFloat.random(in: 0.15...0.85), y: size.height * CGFloat.random(in: 0.15...0.85)))
        }
        .backgroundsHint(L("Tap to fire the nearest traces", "点击触发最近的走线"), ctx)
    }
}

private struct CircuitTone {
    let boardTop: UInt32
    let boardBottom: UInt32
    let copper: UInt32
    let accent: UInt32
}

private enum CircuitPainter {
    static let tones: [CircuitTone] = [
        CircuitTone(boardTop: 0x063126, boardBottom: 0x02140F, copper: 0x2F9A76, accent: 0x5DFFC0),
        CircuitTone(boardTop: 0x08204A, boardBottom: 0x030B1E, copper: 0x3D7BD9, accent: 0x6FD2FF),
        CircuitTone(boardTop: 0x1A1710, boardBottom: 0x070605, copper: 0xA8842E, accent: 0xFFD56A),
    ]
    /// Points per unit of the (speed-scaled) clock.
    static let velocity: CGFloat = 140

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, layout: CircuitLayout, shots: [CircuitShot], taps: [CircuitTap],
        tail: CGFloat, tone: CircuitTone
    ) {
        let copper = Color(hex: tone.copper)
        let accent = Color(hex: tone.accent)
        var all = Path()
        var vias = Path()
        var holes = Path()
        for trace in layout.traces {
            all.addPath(trace.path)
            if trace.hasVia, let end = trace.points.last {
                vias.addEllipse(in: CGRect(x: end.x - 4.5, y: end.y - 4.5, width: 9, height: 9))
                holes.addEllipse(in: CGRect(x: end.x - 1.8, y: end.y - 1.8, width: 3.6, height: 3.6))
            }
        }
        let style = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        context.stroke(all, with: .color(copper.opacity(0.5)), style: style)
        // A thin lit edge on every trace.
        var sheen = context
        sheen.translateBy(x: -0.5, y: -0.6)
        sheen.stroke(all, with: .color(accent.opacity(0.14)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round))
        context.fill(vias, with: .color(copper.opacity(0.85)))
        context.fill(layout.pins, with: .color(copper.opacity(0.9)))
        context.fill(holes, with: .color(Color(hex: tone.boardBottom)))

        // Live pulses: (trace, head distance).
        var heads: [(Int, CGFloat)] = []
        for (index, trace) in layout.traces.enumerated() {
            let cycle = trace.length + trace.gap
            let s = (CGFloat(t) * velocity + trace.offset).truncatingRemainder(dividingBy: cycle)
            heads.append((index, s))
        }
        for shot in shots where shot.trace < layout.traces.count {
            heads.append((shot.trace, CGFloat(t - shot.born) * velocity))
        }

        var tails = Path()
        var cores = Path()
        var flares: [(CGPoint, Double)] = []
        for (index, s) in heads {
            let trace = layout.traces[index]
            guard trace.length > 0, s > 0 else { continue }
            if s - tail < trace.length {
                let from = max(s - tail, 0) / trace.length
                let mid = max(s - tail * 0.4, 0) / trace.length
                let to = min(s, trace.length) / trace.length
                if mid > from { tails.addPath(trace.path.trimmedPath(from: from, to: mid)) }
                if to > mid { cores.addPath(trace.path.trimmedPath(from: mid, to: to)) }
            }
            // The via flares as the head arrives (0.3 s at the base speed).
            let past = Double((s - trace.length) / velocity)
            if trace.hasVia, past > 0, past < 0.3, let end = trace.points.last {
                flares.append((end, 1 - past / 0.3))
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.blendMode = .plusLighter
            layer.stroke(tails, with: .color(accent.opacity(0.45)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            layer.stroke(cores, with: .color(accent.opacity(0.9)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        }
        context.stroke(tails, with: .color(accent.opacity(0.55)), style: style)
        context.stroke(cores, with: .color(.white.opacity(0.95)), style: style)
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            for (point, k) in flares {
                layer.backgroundsGlow(at: point, radius: 9 + 12 * CGFloat(1 - k), color: accent.opacity(k * 0.9))
                layer.fill(Path(ellipseIn: CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)), with: .color(.white.opacity(k * 0.8)))
            }
        }

        drawChip(&context, layout: layout, t: t, taps: taps, accent: accent)

        for tap in taps {
            let age = t - tap.born
            guard age >= 0, age < 0.9 else { continue }
            let r = 12 + 150 * CGFloat(1 - pow(1 - age / 0.9, 2.5))
            context.stroke(
                Path(ellipseIn: CGRect(x: tap.point.x - r, y: tap.point.y - r, width: r * 2, height: r * 2)),
                with: .color(accent.opacity(0.4 * (1 - age / 0.9))), lineWidth: 1.2
            )
        }
    }

    private static func drawChip(_ context: inout GraphicsContext, layout: CircuitLayout, t: Double, taps: [CircuitTap], accent: Color) {
        let body = layout.chip.insetBy(dx: 5, dy: 5)
        guard body.width > 0 else { return }
        var flash = 0.0
        for tap in taps { flash = max(flash, exp(-max(t - tap.born, 0) * 5)) }
        let clockTick = pow(max(sin(t * 2.6), 0), 6) * 0.25
        let shape = Path(roundedRect: body, cornerRadius: 7, style: .continuous)
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.backgroundsGlow(
                at: CGPoint(x: body.midX, y: body.midY), radius: body.width * 1.1, color: accent.opacity(0.22 + 0.6 * flash + clockTick)
            )
        }
        context.fill(shape, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x1C2226), Color(hex: 0x07090B)]),
            startPoint: CGPoint(x: body.minX, y: body.minY), endPoint: CGPoint(x: body.maxX, y: body.maxY)
        ))
        context.stroke(shape, with: .color(accent.opacity(0.3 + 0.6 * flash)), lineWidth: 1)
        // Pin-1 dot and an engraved label.
        context.fill(
            Path(ellipseIn: CGRect(x: body.minX + 8, y: body.minY + 8, width: 5, height: 5)),
            with: .color(accent.opacity(0.5 + 0.5 * min(flash + clockTick * 2, 1)))
        )
        context.draw(
            Text("U1").font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.34 + 0.5 * flash)),
            at: CGPoint(x: body.midX, y: body.midY)
        )
    }
}
