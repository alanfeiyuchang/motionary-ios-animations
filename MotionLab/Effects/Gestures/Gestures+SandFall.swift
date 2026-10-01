import SwiftUI

extension Effect {
    static let gesturesSandFall = Effect(
        id: "gestures.sand-fall",
        category: .gestures,
        interaction: .gesture,
        name: L("Falling Sand", "落沙"),
        summary: L("Coloured sand pours from a wandering spout and piles into striped dunes; draw with your finger to add sand, build walls or erase.", "彩色细沙从游移的出沙口倾泻而下，堆成带条纹的沙丘；用手指画出更多沙子、筑墙或擦除。"),
        prompt: L(
            "A 300×264 pt tray is a 100×88 grid of 3 pt cells. A small spout drifts left and right along the top and drops a grain per step; each grain falls one cell per step, and when blocked it slides diagonally to a free side chosen at random, so piles settle at a natural 45° slope and avalanche when they get too steep. The grain colour cycles slowly through twelve pastel hues in two tones, laying grainy coloured strata into the dunes. A flat shelf heaps up and spills while a steep chute sheds its sand. Dragging a finger paints with a 12 pt brush: more sand, solid walls that sand runs off, or an eraser that lets a pile collapse. When the tray is 42% full the floor opens, everything drains out and the cycle starts again. The simulation runs 120 steps per second. Granular, soothing, endlessly watchable.",
            "300×264 pt的托盘是一张100×88、每格3 pt的网格。顶部一个小出沙口左右游移，每步落下一粒沙；沙粒每步下落一格，被挡住时随机挑一侧空位斜向滑落，沙堆自然形成45°的坡面，过陡时便会塌滑。沙粒颜色在12种柔和色相、深浅两档间缓慢轮换，在沙丘里留下一层层带颗粒感的彩色纹理。平搁板上的沙堆满后溢出，陡滑道则让沙滑走。手指拖动即以12 pt的笔刷作画：添更多的沙、筑起让沙滑落的实墙，或用橡皮擦让沙堆坍塌。托盘填到42%时底板打开，沙子全部漏空，循环重新开始。每秒模拟120步。"
        ),
        implementation: L(
            "A byte grid holds empty, wall or a sand colour index per cell. Each step scans rows bottom-up in alternating horizontal order and moves every grain down or diagonally using a small linear-congruential generator. A Canvas merges horizontal runs of equal cells into rectangles and fills one Path per colour. The drag paints cells along the segment between successive touch points.",
            "一个字节网格为每格记录空、墙或沙粒的颜色索引。每一步自下而上扫描各行（水平方向交替），用一个小型线性同余随机数决定每粒沙向下或斜向移动。Canvas 把同值的水平连续格合并成矩形，每种颜色只填充一个 Path。拖动时沿相邻触点之间的线段给格子上色。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture", "Path.addRect", "cellular automaton"],
        tags: ["sand", "falling sand", "cellular automaton", "particles", "draw", "pile", "落沙", "沙子", "元胞自动机", "粒子", "绘画", "沙堆"],
        params: [
            .choice("tool", L("Finger draws", "手指绘制"), [L("Sand", "沙子"), L("Wall", "墙"), L("Eraser", "橡皮")], default: 0),
            .slider("brush", L("Brush size", "笔刷大小"), 6...30, default: 12, step: 3, decimals: 0, unit: "pt"),
            .slider("pour", L("Pour rate", "出沙速度"), 0...5, default: 1, step: 1, decimals: 0),
            .slider("cycle", L("Colour cycle", "颜色轮换"), 0.2...3, default: 1.2, decimals: 1, unit: "/s"),
        ]
    ) { ctx in
        SandFallDemo(ctx: ctx)
    }
}

private enum Sand {
    static let cols = 100
    static let rows = 88
    static let cell: CGFloat = 3
    static let size = CGSize(width: CGFloat(cols) * cell, height: CGFloat(rows) * cell)
    static let hues = 12
    static let wall: UInt8 = 1
    static let firstGrain: UInt8 = 2
}

private final class SandModel {
    private(set) var cells: [UInt8]
    private(set) var grains = 0
    private(set) var draining = false
    private(set) var spoutX: CGFloat = CGFloat(Sand.cols) / 2
    private var time: Double = 0
    private var carry: Double = 0
    private var rng: UInt32 = 0x9E3779B9
    private var pass = 0
    private var moved = true
    var touching = false
    private var clock = GestureStepClock()

    init() {
        cells = Array(repeating: 0, count: Sand.cols * Sand.rows)
        // A shallow shelf that heaps up and spills, and a steep chute that sheds everything.
        ledge(from: (18, 34), to: (40, 34))
        ledge(from: (86, 40), to: (64, 66))
    }

    private func ledge(from a: (Int, Int), to b: (Int, Int)) {
        let steps: Int = max(abs(b.0 - a.0), abs(b.1 - a.1))
        for step in 0...steps {
            let t: Double = Double(step) / Double(max(steps, 1))
            let x: Int = Int((Double(a.0) + Double(b.0 - a.0) * t).rounded())
            let y: Int = Int((Double(a.1) + Double(b.1 - a.1) * t).rounded())
            for dy in 0..<2 { set(x, y + dy, Sand.wall) }
        }
    }

    private func next() -> UInt32 {
        rng = rng &* 1664525 &+ 1013904223
        return rng >> 16
    }

    private func set(_ x: Int, _ y: Int, _ value: UInt8) {
        guard x >= 0, x < Sand.cols, y >= 0, y < Sand.rows else { return }
        let i: Int = y * Sand.cols + x
        if cells[i] >= Sand.firstGrain { grains -= 1 }
        if value >= Sand.firstGrain { grains += 1 }
        cells[i] = value
    }

    var isSettled: Bool { !moved && !draining && !touching }

    /// A grain of the current hue: now and then the neighbouring hue, in a light or a dark tone,
    /// so piles look granular instead of flat.
    private func currentGrain(cycle: Double) -> UInt8 {
        let roll: UInt32 = next()
        let drift: Int = roll % 5 == 0 ? 1 : 0
        let hue: Int = (Int(time * cycle) + drift) % Sand.hues
        let tone: Int = Int((roll >> 3) & 1)
        return Sand.firstGrain + UInt8(hue * 2 + tone)
    }

    /// Paints a disc of cells around `point` (in points). `tool`: 0 sand, 1 wall, 2 eraser.
    func paint(at point: CGPoint, tool: Int, brush: CGFloat, cycle: Double) {
        let cx: Int = Int(point.x / Sand.cell)
        let cy: Int = Int(point.y / Sand.cell)
        let r: Int = max(Int((brush / Sand.cell / 2).rounded()), 1)
        for dy in -r...r {
            for dx in -r...r where dx * dx + dy * dy <= r * r {
                let x: Int = cx + dx
                let y: Int = cy + dy
                guard x >= 0, x < Sand.cols, y >= 0, y < Sand.rows else { continue }
                let existing: UInt8 = cells[y * Sand.cols + x]
                switch tool {
                case 0:
                    // Loose sand: sprinkle a fifth of the free cells per pass, so it falls as grains.
                    if existing == 0 && next() % 5 == 0 { set(x, y, currentGrain(cycle: cycle)) }
                case 1:
                    set(x, y, Sand.wall)
                default:
                    set(x, y, 0)
                }
            }
        }
        moved = true
    }

    func paintLine(from a: CGPoint, to b: CGPoint, tool: Int, brush: CGFloat, cycle: Double) {
        let distance: CGFloat = GestureMath.distance(a, b)
        let steps: Int = max(Int(distance / Sand.cell), 1)
        for step in 0...steps {
            paint(at: GestureMath.lerp(a, b, CGFloat(step) / CGFloat(steps)), tool: tool, brush: brush, cycle: cycle)
        }
    }

    func step(to date: Date, pour: Int, cycle: Double) {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return }
        carry += dt * 120
        let passes: Int = min(Int(carry), 5)
        carry -= Double(Int(carry))
        for _ in 0..<passes { advance(pour: pour, cycle: cycle) }
    }

    func advance(pour: Int, cycle: Double) {
        time += 1.0 / 120.0
        pass += 1
        spoutX = CGFloat(Sand.cols) / 2 + CGFloat(sin(time * 0.55) * 30 + sin(time * 1.7) * 6)

        if !draining && pour > 0 {
            for _ in 0..<pour {
                let x: Int = Int(spoutX) + Int(next() % 3) - 1
                if x >= 0 && x < Sand.cols && cells[x] == 0 { set(x, 0, currentGrain(cycle: cycle)) }
            }
            moved = true
        }

        if !draining && grains > Int(Double(Sand.cols * Sand.rows) * 0.42) { draining = true }
        if draining {
            // The floor is open: the bottom row falls out.
            if pass % 2 == 0 {
                for x in 0..<Sand.cols where cells[(Sand.rows - 1) * Sand.cols + x] >= Sand.firstGrain {
                    set(x, Sand.rows - 1, 0)
                }
            }
            moved = true
            if grains < 30 { draining = false }
        }

        var any = false
        let leftToRight: Bool = pass % 2 == 0
        var y: Int = Sand.rows - 2
        while y >= 0 {
            let row: Int = y * Sand.cols
            let below: Int = row + Sand.cols
            for n in 0..<Sand.cols {
                let x: Int = leftToRight ? n : Sand.cols - 1 - n
                let value: UInt8 = cells[row + x]
                guard value >= Sand.firstGrain else { continue }
                if cells[below + x] == 0 {
                    cells[below + x] = value
                    cells[row + x] = 0
                    any = true
                    continue
                }
                let first: Int = next() & 1 == 0 ? -1 : 1
                for dir in [first, -first] {
                    let nx: Int = x + dir
                    guard nx >= 0, nx < Sand.cols else { continue }
                    if cells[below + nx] == 0 && cells[row + nx] == 0 {
                        cells[below + nx] = value
                        cells[row + x] = 0
                        any = true
                        break
                    }
                }
            }
            y -= 1
        }
        if any { moved = true } else if pour == 0 && !draining { moved = false }
    }
}

private struct SandFallDemo: View {
    let ctx: DemoContext
    @State private var model: SandModel
    @State private var touching = false
    @State private var lastPoint: CGPoint = .zero
    @State private var wake = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = SandModel()
        // Start with dunes already on the floor (and a finished picture for the still).
        for _ in 0..<(ctx.isStill ? 2600 : 1100) { model.advance(pour: 1, cycle: 1.2) }
        _model = State(initialValue: model)
    }

    var body: some View {
        let pour = ctx.int("pour")
        let cycle = ctx["cycle"]
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let _ = ctx.isStill ? () : model.step(to: date, pour: pour, cycle: cycle)
                SandCanvas(model: model, showSpout: pour > 0, tick: date)
            }
            .frame(width: Sand.size.width, height: Sand.size.height)
            .gestureTray(cornerRadius: 22)
            .gesture(drag)

            DemoHint(text: hint, ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.2, delay: 0.8) { autoDraw() }
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touchEnded() }
        }
        .onDisappear { script?.cancel() }
    }

    private var hint: LocalizedText {
        switch ctx.int("tool") {
        case 1: return L("Draw walls with your finger", "用手指画出墙")
        case 2: return L("Rub to erase sand and walls", "涂抹以擦除沙子和墙")
        default: return L("Draw with your finger to pour sand", "用手指画出沙子")
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    script?.cancel()
                    touchBegan(at: value.startLocation)
                    Haptics.tap(.light)
                }
                touchMoved(to: value.location)
            }
            .onEnded { _ in touchEnded() }
    }

    private func touchBegan(at point: CGPoint) {
        touching = true
        model.touching = true
        lastPoint = point
        model.paint(at: point, tool: ctx.int("tool"), brush: ctx.cg("brush"), cycle: ctx["cycle"])
        wake += 1
    }

    private func touchMoved(to point: CGPoint) {
        guard touching else { return }
        model.paintLine(from: lastPoint, to: point, tool: ctx.int("tool"), brush: ctx.cg("brush"), cycle: ctx["cycle"])
        lastPoint = point
        wake += 1
    }

    private func touchEnded() {
        guard touching else { return }
        touching = false
        model.touching = false
        wake += 1
    }

    /// A scripted finger sweeps an arc across the upper half, through the touch handlers.
    private func autoDraw() {
        guard !touching else { return }
        autoStep += 1
        let leftward: Bool = autoStep % 2 == 0
        let from = CGPoint(x: leftward ? 250 : 50, y: 40)
        let to = CGPoint(x: leftward ? 60 : 240, y: 70)
        let control = CGPoint(x: 150, y: 6)
        script?.cancel()
        script = Task { @MainActor in
            touchBegan(at: from)
            _ = await GhostFinger.drag(from: from, to: to, control: control, duration: 1.1) { point in
                touchMoved(to: point)
            }
            touchEnded()
        }
    }
}

private struct SandCanvas: View {
    let model: SandModel
    let showSpout: Bool
    let tick: Date

    /// Two tones per hue: index = hue × 2 + tone.
    private static let palette: [Color] = (0..<(Sand.hues * 2)).map { (index: Int) -> Color in
        let light: Bool = index % 2 == 0
        let hue: Double = Double(index / 2) / Double(Sand.hues)
        let saturation: Double = light ? 0.52 : 0.64
        let brightness: Double = light ? 1.0 : 0.86
        return GestureRGB.hue(hue, saturation: saturation, brightness: brightness).color()
    }

    var body: some View {
        Canvas { context, size in
            var walls = Path()
            var grains: [Path] = Array(repeating: Path(), count: Sand.hues * 2)
            let cells: [UInt8] = model.cells
            let s: CGFloat = Sand.cell
            for y in 0..<Sand.rows {
                let row: Int = y * Sand.cols
                var x = 0
                while x < Sand.cols {
                    let value: UInt8 = cells[row + x]
                    if value == 0 {
                        x += 1
                        continue
                    }
                    // Merge the run of equal cells into one rectangle.
                    var end: Int = x + 1
                    while end < Sand.cols && cells[row + end] == value { end += 1 }
                    let rect = CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: CGFloat(end - x) * s, height: s)
                    if value == Sand.wall {
                        walls.addRect(rect)
                    } else {
                        grains[Int(value - Sand.firstGrain) % (Sand.hues * 2)].addRect(rect)
                    }
                    x = end
                }
            }
            for index in 0..<(Sand.hues * 2) where !grains[index].isEmpty {
                context.fill(grains[index], with: .color(SandCanvas.palette[index]))
            }
            context.fill(walls, with: .color(.primary.opacity(0.62)))

            if showSpout && !model.draining {
                let x: CGFloat = model.spoutX * s
                var spout = Path()
                spout.move(to: CGPoint(x: x - 8, y: 0))
                spout.addLine(to: CGPoint(x: x + 8, y: 0))
                spout.addLine(to: CGPoint(x: x + 3, y: 7))
                spout.addLine(to: CGPoint(x: x - 3, y: 7))
                spout.closeSubpath()
                context.fill(spout, with: .color(.primary.opacity(0.45)))
            }
            // Floor: solid while closed, dashed while it lets the sand out.
            var floor = Path()
            floor.move(to: CGPoint(x: 0, y: size.height - 1))
            floor.addLine(to: CGPoint(x: size.width, y: size.height - 1))
            context.stroke(
                floor,
                with: .color(model.draining ? Palette.coral.opacity(0.9) : Color.primary.opacity(0.2)),
                style: StrokeStyle(lineWidth: 2, dash: model.draining ? [6, 6] : [])
            )
        }
    }
}
