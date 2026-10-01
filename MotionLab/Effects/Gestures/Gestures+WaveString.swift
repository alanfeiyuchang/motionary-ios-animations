import SwiftUI

extension Effect {
    static let gesturesWaveString = Effect(
        id: "gestures.wave-string",
        category: .gestures,
        interaction: .gesture,
        name: L("Plucked Wave String", "拨弦波动"),
        summary: L("Pull a taut string into a peak and let go: two kinks race apart, flip at the ends and cross again until the string calms down.", "把绷紧的弦拉出一个尖角再松手：两道折角分头奔向两端，在端点翻转后再次交汇，直到弦渐渐平静。"),
        prompt: L(
            "A horizontal string 252 pt long, made of 72 spring-linked points, is stretched between two posts, drawn as a 4 pt line with a mint-to-violet gradient and small beads every sixth point. Pulling it with a finger bends it into a straight-sided peak at the finger, exactly like a plucked guitar string. On release the peak splits into two kinks that travel outward at 380 pt/s, reflect upside-down from the fixed posts, pass through each other and return, decaying at 0.5/s; five fading afterimages of earlier frames blur the motion and the line glows with its energy. A quick tap instead launches a single bump that runs to both ends. Switch the right end to a free sliding ring and reflections there come back upright. A light haptic on pluck. Musical, physical, clear.",
            "252 pt长的水平弦由72个以弹簧相连的质点组成，绷在两根立柱之间，画成4 pt粗、薄荷绿到紫色渐变的线，每隔六个点有一颗小珠。用手指拉它，弦在指下弯成两边笔直的尖角，和拨吉他弦一样。松手后尖角分裂成两道折角，以380 pt/s向两侧传播，在固定的立柱处上下翻转反射，彼此穿过再返回，并以0.5/s衰减；五道淡去的残影带来模糊感，线条随能量发光。快速轻点则激起一个小鼓包，向两端跑去。把右端换成可自由滑动的圆环后，那里的反射不再翻转。拨弦时有轻触感。"
        ),
        implementation: L(
            "The string is the 1D wave equation on 72 samples: each 1/480 s substep accelerates every point by c²/Δx² times the discrete second difference of the heights, minus damping, with the ends held at zero (or the last point copying its neighbour for a free end). While held, the heights ease toward a triangle through the finger. A Canvas strokes stored past shapes as afterimages, then the string and beads.",
            "弦即72个采样点上的一维波动方程：每个1/480秒子步里，各点的加速度等于 c²/Δx² 乘以高度的离散二阶差分，再减去阻尼；两端固定为零（自由端则让末点复制相邻点）。按住时，各点高度向经过手指的三角形缓动。Canvas 先描出保存下来的历史形状作为残影，再画弦与小珠。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture", "wave equation", "GraphicsContext.Shading.linearGradient"],
        tags: ["wave", "string", "pluck", "vibration", "reflection", "guitar", "波", "弦", "拨弦", "振动", "反射", "吉他"],
        params: [
            .slider("speed", L("Wave speed", "波速"), 150...700, default: 380, step: 10, decimals: 0, unit: "pt/s"),
            .slider("damping", L("Damping", "阻尼"), 0.05...3, default: 0.5, unit: "/s"),
            .choice("end", L("Right end", "右端"), [L("Fixed", "固定"), L("Free", "自由")], default: 0),
        ]
    ) { ctx in
        WaveStringDemo(ctx: ctx)
    }
}

private enum StringRig {
    static let size = CGSize(width: 300, height: 262)
    static let count = 72
    static let left: CGFloat = 24
    static let length: CGFloat = 252
    static let baseline: CGFloat = 131
    static let limit: CGFloat = 104
    static var dx: CGFloat { length / CGFloat(count - 1) }

    static func x(_ index: Int) -> CGFloat {
        left + dx * CGFloat(index)
    }
}

private final class WaveStringModel {
    private(set) var heights: [CGFloat]
    private var velocities: [CGFloat]
    private(set) var history: [[CGFloat]] = []
    private(set) var held = false
    private var beforeGrab: [CGFloat] = []
    private var pluckIndex = 0
    private var pluckHeight: CGFloat = 0
    private(set) var energy: CGFloat = 0
    private var clock = GestureStepClock()
    private let h: CGFloat = 1.0 / 480.0

    init() {
        heights = Array(repeating: 0, count: StringRig.count)
        velocities = Array(repeating: 0, count: StringRig.count)
    }

    var isSettled: Bool { !held && energy < 0.02 && history.count < 2 }

    func index(at x: CGFloat) -> Int {
        Int(((x - StringRig.left) / StringRig.dx).rounded()).clamped(to: 4...(StringRig.count - 5))
    }

    func grab(at point: CGPoint) {
        held = true
        beforeGrab = heights
        pluckIndex = index(at: point.x)
        pluckHeight = heights[pluckIndex]
    }

    func move(to point: CGPoint) {
        pluckIndex = index(at: point.x)
        let raw: CGFloat = point.y - StringRig.baseline
        let soft: CGFloat = 70
        // One to one for the first 70 pt, then the string resists.
        pluckHeight = abs(raw) <= soft ? raw : (raw < 0 ? -1 : 1) * (soft + rubberBand(abs(raw) - soft, limit: StringRig.limit - soft))
    }

    func release() {
        held = false
    }

    /// A tap: a narrow bump of upward velocity.
    func pulse(at point: CGPoint) {
        // Undo the little pull the tap itself made, so only the bump remains.
        if beforeGrab.count == heights.count { heights = beforeGrab }
        let centre: Int = index(at: point.x)
        for index in 1..<(StringRig.count - 1) {
            let d: Double = Double(index - centre)
            velocities[index] -= 900 * CGFloat(exp(-d * d / 18))
        }
    }

    func step(to date: Date, speed: CGFloat, damping: CGFloat, freeEnd: Bool) {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return }
        let steps: Int = min(max(Int((dt / Double(h)).rounded()), 1), 20)
        for _ in 0..<steps { advance(speed: speed, damping: damping, freeEnd: freeEnd) }
        // Afterimages: keep the last few frames while the string is alive.
        if energy > 0.05 || held {
            remember()
        } else if !history.isEmpty {
            history.removeFirst()
        }
    }

    func remember() {
        history.append(heights)
        if history.count > 5 { history.removeFirst() }
    }

    func advance(speed: CGFloat, damping: CGFloat, freeEnd: Bool) {
        let n: Int = StringRig.count
        if held {
            // Ease toward the triangle a finger makes of a taut string.
            for index in 1..<(n - 1) {
                let goal: CGFloat
                if index <= pluckIndex {
                    goal = pluckHeight * CGFloat(index) / CGFloat(pluckIndex)
                } else if freeEnd {
                    goal = pluckHeight
                } else {
                    goal = pluckHeight * CGFloat(n - 1 - index) / CGFloat(n - 1 - pluckIndex)
                }
                heights[index] += (goal - heights[index]) * 0.06
                velocities[index] = 0
            }
            heights[n - 1] = freeEnd ? heights[n - 2] : 0
            energy = 1
            return
        }
        let k: CGFloat = speed * speed / (StringRig.dx * StringRig.dx)
        let decay: CGFloat = CGFloat(exp(-Double(damping * h)))
        var total: CGFloat = 0
        for index in 1..<(n - 1) {
            let second: CGFloat = heights[index - 1] - 2 * heights[index] + heights[index + 1]
            velocities[index] = (velocities[index] + k * second * h) * decay
        }
        for index in 1..<(n - 1) {
            heights[index] = (heights[index] + velocities[index] * h).clamped(to: -StringRig.limit...StringRig.limit)
            total += abs(heights[index]) + abs(velocities[index]) * 0.004
        }
        heights[0] = 0
        heights[n - 1] = freeEnd ? heights[n - 2] : 0
        energy = total / CGFloat(n)
    }
}

private struct WaveStringDemo: View {
    let ctx: DemoContext
    @State private var model: WaveStringModel
    @State private var touching = false
    @State private var touchStart = Date()
    @State private var travelled: CGFloat = 0
    @State private var wake = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = WaveStringModel()
        if ctx.isStill {
            // A still shows the string just after a pluck, kinks on their way out.
            model.grab(at: CGPoint(x: 100, y: StringRig.baseline))
            model.move(to: CGPoint(x: 100, y: StringRig.baseline - 84))
            for _ in 0..<200 { model.advance(speed: 380, damping: 0.5, freeEnd: false) }
            model.release()
            for _ in 0..<5 {
                for _ in 0..<10 { model.advance(speed: 380, damping: 0.5, freeEnd: false) }
                model.remember()
            }
        }
        _model = State(initialValue: model)
    }

    var body: some View {
        let speed = ctx.cg("speed")
        let damping = ctx.cg("damping")
        let freeEnd = ctx.int("end") == 1
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let _ = ctx.isStill ? () : model.step(to: date, speed: speed, damping: damping, freeEnd: freeEnd)
                WaveStringCanvas(model: model, freeEnd: freeEnd, tick: date)
            }
            .frame(width: StringRig.size.width, height: StringRig.size.height)
            .gestureTray()
            .gesture(drag)

            DemoHint(text: L("Pull the string and let go, or tap it", "拉开弦再松手，或轻点一下"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.4, delay: 0.5) { autoPluck() }
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touchEnded(at: nil) }
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    touching = true
                    touchStart = value.time
                    travelled = 0
                    script?.cancel()
                    touchBegan(at: value.startLocation)
                }
                travelled = max(travelled, abs(value.translation.width) + abs(value.translation.height))
                touchMoved(to: value.location)
            }
            .onEnded { value in
                // A short, still touch is a tap: send a bump instead of a pluck.
                let quick: Bool = value.time.timeIntervalSince(touchStart) < 0.25 && travelled < 8
                touchEnded(at: quick ? value.location : nil)
            }
    }

    private func touchBegan(at point: CGPoint) {
        model.grab(at: point)
        wake += 1
    }

    private func touchMoved(to point: CGPoint) {
        guard model.held else { return }
        model.move(to: point)
        wake += 1
    }

    private func touchEnded(at tap: CGPoint?) {
        touching = false
        guard model.held else { return }
        model.release()
        if let tap { model.pulse(at: tap) }
        if !ctx.isPreview { Haptics.tap(.light) }
        wake += 1
    }

    /// A scripted finger pulls the string into a peak and lets go.
    private func autoPluck() {
        guard !touching, !model.held else { return }
        autoStep += 1
        let spots: [CGFloat] = [0.26, 0.62, 0.4, 0.8]
        let x: CGFloat = StringRig.left + StringRig.length * spots[autoStep % spots.count]
        let lift: CGFloat = autoStep % 2 == 0 ? -80 : 76
        let from = CGPoint(x: x, y: StringRig.baseline)
        let to = CGPoint(x: x, y: StringRig.baseline + lift)
        script?.cancel()
        script = Task { @MainActor in
            touchBegan(at: from)
            let finished = await GhostFinger.drag(from: from, to: to, duration: 0.5) { point in
                touchMoved(to: point)
            }
            guard finished else {
                if !touching { touchEnded(at: nil) }
                return
            }
            try? await Task.sleep(for: .seconds(0.12))
            if !touching { touchEnded(at: nil) }
        }
    }
}

private struct WaveStringCanvas: View {
    let model: WaveStringModel
    let freeEnd: Bool
    let tick: Date

    var body: some View {
        Canvas { context, _ in
            drawRig(&context)
            let shading: GraphicsContext.Shading = .linearGradient(
                Gradient(colors: [Palette.mint, Palette.sky, Palette.violet]),
                startPoint: CGPoint(x: StringRig.left, y: 0),
                endPoint: CGPoint(x: StringRig.left + StringRig.length, y: 0)
            )
            // Afterimages, oldest first.
            let history = model.history
            for (index, shape) in history.enumerated() {
                let alpha: Double = 0.05 + 0.16 * Double(index) / Double(max(history.count, 1))
                var ghost = context
                ghost.opacity = alpha
                ghost.stroke(path(shape), with: shading, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            let line: Path = path(model.heights)
            let glow: CGFloat = min(model.energy / 14, 1)
            var lit = context
            lit.addFilter(.shadow(color: Palette.sky.opacity(0.25 + 0.55 * Double(glow)), radius: 3 + 8 * glow))
            lit.stroke(line, with: shading, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            context.stroke(line, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

            for index in stride(from: 6, to: StringRig.count - 3, by: 6) {
                let p = CGPoint(x: StringRig.x(index), y: StringRig.baseline + model.heights[index])
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3.6, y: p.y - 3.6, width: 7.2, height: 7.2)), with: .color(.white))
                context.stroke(Path(ellipseIn: CGRect(x: p.x - 3.6, y: p.y - 3.6, width: 7.2, height: 7.2)), with: shading, lineWidth: 1.6)
            }
            drawEnds(&context)
        }
    }

    private func path(_ heights: [CGFloat]) -> Path {
        var path = Path()
        guard heights.count == StringRig.count else { return path }
        path.move(to: CGPoint(x: StringRig.x(0), y: StringRig.baseline + heights[0]))
        for index in 1..<heights.count {
            path.addLine(to: CGPoint(x: StringRig.x(index), y: StringRig.baseline + heights[index]))
        }
        return path
    }

    private func drawRig(_ context: inout GraphicsContext) {
        var rest = Path()
        rest.move(to: CGPoint(x: StringRig.left, y: StringRig.baseline))
        rest.addLine(to: CGPoint(x: StringRig.left + StringRig.length, y: StringRig.baseline))
        context.stroke(rest, with: .color(.primary.opacity(0.1)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
        if freeEnd {
            // The rod the free end slides on.
            var rod = Path()
            let x: CGFloat = StringRig.left + StringRig.length
            rod.move(to: CGPoint(x: x, y: StringRig.baseline - StringRig.limit - 8))
            rod.addLine(to: CGPoint(x: x, y: StringRig.baseline + StringRig.limit + 8))
            context.stroke(rod, with: .color(.primary.opacity(0.22)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    private func drawEnds(_ context: inout GraphicsContext) {
        let post = CGSize(width: 12, height: 34)
        let leftRect = CGRect(x: StringRig.left - post.width / 2, y: StringRig.baseline - post.height / 2, width: post.width, height: post.height)
        context.fill(Path(roundedRect: leftRect, cornerRadius: 5), with: .color(Color(hex: 0x767C90)))
        context.fill(Path(roundedRect: leftRect.insetBy(dx: 3.5, dy: 4), cornerRadius: 2), with: .color(.white.opacity(0.3)))
        let x: CGFloat = StringRig.left + StringRig.length
        if freeEnd {
            let y: CGFloat = StringRig.baseline + (model.heights.last ?? 0)
            let ring = CGRect(x: x - 7, y: y - 7, width: 14, height: 14)
            context.fill(Path(ellipseIn: ring), with: .color(Palette.violet))
            context.stroke(Path(ellipseIn: ring.insetBy(dx: 1, dy: 1)), with: .color(.white.opacity(0.7)), lineWidth: 1.5)
        } else {
            let rightRect = CGRect(x: x - post.width / 2, y: StringRig.baseline - post.height / 2, width: post.width, height: post.height)
            context.fill(Path(roundedRect: rightRect, cornerRadius: 5), with: .color(Color(hex: 0x767C90)))
            context.fill(Path(roundedRect: rightRect.insetBy(dx: 3.5, dy: 4), cornerRadius: 2), with: .color(.white.opacity(0.3)))
        }
    }
}
