import SwiftUI

extension Effect {
    static let gesturesSlinky = Effect(
        id: "gestures.slinky",
        category: .gestures,
        interaction: .gesture,
        name: L("Slinky on Stairs", "下楼梯的彩虹圈"),
        summary: L("Lift the top coil of a rainbow slinky and set it on the next step: the rest pours over in an arch and it keeps walking down.", "提起彩虹圈最上面一圈放到下一级台阶：其余各圈拱成弧线倾泻过去，并自己一级级走下楼。"),
        prompt: L(
            "A rainbow slinky of 16 flat coils (68 pt wide, 4.2 pt apart) rests stacked on the top of three steps. Dragging the top coil lifts it: coils peel off the stack one by one and string along an arch between the stack and the finger, each chasing its place on a spring (stiffness 700, damping 30) so the arch lags and wobbles; coils turn edge-on at the apex. Released over another step, the top coil drops at 2,200 pt/s², lands with a tick, and the remaining coils pour over the arch at 34 coils per second and re-stack in reverse order. If it moved down a step, the new top coil tips over in a 0.34 s hop to the next step and the walk repeats to the bottom. Released near its stack it collapses back. Springy, mesmerising, toy-like.",
            "16圈扁平线圈组成的彩虹圈（宽68 pt、圈距4.2 pt）叠放在三级台阶的最高一级。拖动顶圈将它提起：线圈一圈圈从叠堆上剥离，沿叠堆与手指之间的拱形排开，每圈以弹簧（劲度700、阻尼30）追赶自己的位置，拱形因此带着滞后与晃动；到拱顶时线圈转为侧立。在另一级台阶上方松手，顶圈以2200 pt/s²落下，“嗒”地着地，其余线圈以每秒34圈越过拱形倾泻过去，并按相反顺序重新叠好。若是往下走了一级，新的顶圈会在0.34秒内翻向再下一级，一路走到底；在原处附近松手则缩回。"
        ),
        implementation: L(
            "Every coil has a target on a quadratic Bézier between the old stack's top and the head coil (or the growing new stack), parameterised by how many coils have transferred; each coil follows its target with a stepped spring. A small state machine (held, falling, pouring, hopping, collapsing) moves the head. A Canvas paints the coils back to front as filled ellipses turned along the path tangent.",
            "每圈线圈的目标点位于旧叠堆顶端与顶圈（或正在长高的新叠堆）之间的二次贝塞尔曲线上，由“已转移圈数”参数化；每圈再以逐帧弹簧追随目标。一个小状态机（按住、下落、倾泻、翻越、缩回）驱动顶圈。Canvas 由后向前绘制线圈：填充的椭圆沿路径切线方向转动。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture", "Path(ellipseIn:)", "GraphicsContext.rotate"],
        tags: ["slinky", "spring toy", "stairs", "coil", "follow", "delay", "彩虹圈", "弹簧玩具", "楼梯", "线圈", "跟随"],
        params: [
            .slider("coils", L("Coils", "圈数"), 10...22, default: 16, step: 1, decimals: 0),
            .slider("rate", L("Pour rate", "倾泻速度"), 14...60, default: 34, step: 1, decimals: 0, unit: "/s"),
            .slider("stiffness", L("Coil stiffness", "线圈劲度"), 200...1400, default: 700, step: 20, decimals: 0),
            .toggle("walk", L("Keep walking down", "自动走下楼"), default: true),
        ]
    ) { ctx in
        SlinkyDemo(ctx: ctx)
    }
}

private enum Slinky {
    static let size = CGSize(width: 300, height: 270)
    static let rx: CGFloat = 34
    static let ry: CGFloat = 10
    static let gap: CGFloat = 4.2
    static let edges: [CGFloat] = [104, 200]
    static let floors: [CGFloat] = [140, 196, 252]
    static let centres: [CGFloat] = [54, 152, 250]

    static func level(_ x: CGFloat) -> Int {
        x < edges[0] ? 0 : (x < edges[1] ? 1 : 2)
    }

    static func floorY(_ x: CGFloat) -> CGFloat {
        floors[level(x)]
    }

    /// Keeps a coil fully on the step under `x`.
    static func seat(_ x: CGFloat) -> CGFloat {
        let lvl: Int = level(x)
        let lower: CGFloat = (lvl == 0 ? 0 : edges[lvl - 1]) + rx + 6
        let upper: CGFloat = (lvl == 2 ? size.width : edges[lvl]) - rx - 6
        return x.clamped(to: lower...upper)
    }
}

private final class SlinkyModel {
    enum Mode {
        case rest, held, falling, pouring, hopping, collapsing
    }

    enum Event {
        case none, landed, tick
    }

    private(set) var count: Int
    private(set) var positions: [CGPoint] = []
    private var velocities: [CGVector] = []
    /// Coil colour slots: reversed every time the slinky re-stacks upside down.
    private(set) var tints: [Int] = []
    private(set) var mode: Mode = .rest
    private var base: CGPoint
    private var head: CGPoint = .zero
    private var headVelocity: CGFloat = 0
    private var landingX: CGFloat = 0
    private var moved: CGFloat = 1
    private var startLevel = 0
    private var hopFrom: CGPoint = .zero
    private var hopTo: CGPoint = .zero
    private var hopTime: Double = 0
    private var lastTick = 0
    private var clock = GestureStepClock()

    init(count: Int, level: Int = 0) {
        self.count = count
        base = CGPoint(x: Slinky.centres[level], y: Slinky.floors[level])
        rebuild()
    }

    var isSettled: Bool {
        guard mode == .rest else { return false }
        return velocities.allSatisfy { abs($0.dx) + abs($0.dy) < 2 }
    }

    var level: Int { Slinky.level(base.x) }

    var stackTop: CGPoint {
        CGPoint(x: base.x, y: base.y - Slinky.ry - CGFloat(count - 1) * Slinky.gap)
    }

    var headPoint: CGPoint { mode == .rest ? stackTop : head }

    func setCount(_ newCount: Int) {
        guard newCount != count else { return }
        count = newCount
        mode = .rest
        rebuild()
    }

    private func rebuild() {
        positions = (0..<count).map { CGPoint(x: base.x, y: base.y - Slinky.ry - CGFloat($0) * Slinky.gap) }
        velocities = Array(repeating: .zero, count: count)
        tints = Array(0..<count)
        head = stackTop
        moved = 1
    }

    func canGrab(at point: CGPoint) -> Bool {
        guard mode == .rest || mode == .collapsing || mode == .falling else { return false }
        let top: CGPoint = headPoint
        let inStack: Bool = abs(point.x - base.x) < Slinky.rx + 14 && point.y > stackTop.y - 26 && point.y < base.y + 12
        return GestureMath.distance(point, top) < 48 || (mode == .rest && inStack)
    }

    func grab() {
        head = headPoint
        mode = .held
        moved = 1
        startLevel = level
    }

    func move(to point: CGPoint) {
        guard mode == .held else { return }
        var p = CGPoint(x: point.x.clamped(to: Slinky.rx...(Slinky.size.width - Slinky.rx)), y: max(point.y, 24))
        p.y = min(p.y, Slinky.floorY(p.x) - Slinky.ry)
        head = p
    }

    func release() {
        guard mode == .held else { return }
        let sameStep: Bool = Slinky.level(head.x) == level && abs(head.x - base.x) < 46
        if sameStep {
            mode = .collapsing
        } else {
            mode = .falling
            headVelocity = 0
            landingX = Slinky.seat(head.x)
        }
    }

    // MARK: Targets

    private func target(_ index: Int, flight: CGFloat, from a: CGPoint, to z: CGPoint, control c: CGPoint) -> CGPoint {
        let k: CGFloat = CGFloat(count - 1 - index)
        let g: CGFloat = k - (moved - 1)
        if g <= 0 {
            return CGPoint(x: head.x, y: head.y - k * Slinky.gap)
        }
        if g < flight {
            let f: CGFloat = g / flight
            let p: CGPoint = GestureMath.lerp(a, c, f)
            let q: CGPoint = GestureMath.lerp(c, z, f)
            return GestureMath.lerp(p, q, f)
        }
        return CGPoint(x: base.x, y: base.y - Slinky.ry - CGFloat(index) * Slinky.gap)
    }

    func step(to date: Date, rate: CGFloat, stiffness: CGFloat, walk: Bool) -> Event {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return .none }
        var event: Event = .none
        let h: CGFloat = CGFloat(dt)

        switch mode {
        case .rest:
            head = stackTop
        case .held:
            break
        case .falling:
            headVelocity += 2200 * h
            head.y += headVelocity * h
            head.x += (landingX - head.x) * CGFloat(1 - exp(-dt * 16))
            let ground: CGFloat = Slinky.floorY(landingX) - Slinky.ry
            if head.y >= ground {
                head = CGPoint(x: landingX, y: ground)
                mode = .pouring
                lastTick = 1
                event = .landed
            }
        case .hopping:
            hopTime += dt
            let t: CGFloat = CGFloat(min(hopTime / 0.34, 1))
            let eased: CGFloat = t * t * (1.6 - 0.6 * t)
            let control = CGPoint(x: (hopFrom.x + hopTo.x) / 2, y: hopFrom.y - 34)
            let p: CGPoint = GestureMath.lerp(hopFrom, control, eased)
            let q: CGPoint = GestureMath.lerp(control, hopTo, eased)
            head = GestureMath.lerp(p, q, eased)
            if t >= 1 {
                head = hopTo
                mode = .pouring
                lastTick = 1
                event = .landed
            }
        case .pouring:
            // Starts gently and speeds up as the weight shifts over.
            let progress: CGFloat = (moved / CGFloat(count)).clamped(to: 0...1)
            moved += rate * (0.55 + 0.9 * progress) * h
            if Int(moved) >= lastTick + 4 {
                lastTick = Int(moved)
                event = .tick
            }
            if moved >= CGFloat(count) { finishPour(walk: walk) }
        case .collapsing:
            let top: CGPoint = stackTop
            let blend: CGFloat = CGFloat(1 - exp(-dt * 13))
            head.x += (top.x - head.x) * blend
            head.y += (top.y - head.y) * blend
            if GestureMath.distance(head, top) < 0.6 { mode = .rest }
        }

        follow(dt: dt, stiffness: stiffness)
        return event
    }

    private func finishPour(walk: Bool) {
        base = CGPoint(x: head.x, y: head.y + Slinky.ry)
        positions.reverse()
        velocities.reverse()
        tints.reverse()
        moved = 1
        head = stackTop
        let landedLevel: Int = level
        if walk && landedLevel > startLevel && landedLevel < 2 {
            startLevel = landedLevel
            hopFrom = stackTop
            hopTo = CGPoint(x: Slinky.centres[landedLevel + 1], y: Slinky.floors[landedLevel + 1] - Slinky.ry)
            hopTime = 0
            mode = .hopping
        } else {
            mode = .rest
        }
    }

    private func follow(dt: Double, stiffness: CGFloat) {
        let top: CGFloat = CGFloat(count) - moved
        let oldTopEstimate = CGPoint(x: base.x, y: base.y - Slinky.ry - max(top, 0) * Slinky.gap * 0.5)
        let a = CGPoint(x: head.x, y: head.y - (moved - 1) * Slinky.gap)
        let roughArch: CGFloat = min(abs(a.x - base.x) * 0.5, 90)
        let flight: CGFloat = ((GestureMath.distance(a, oldTopEstimate) + roughArch) / 6.5).clamped(to: 1...CGFloat(count - 1))
        let remaining: CGFloat = max(CGFloat(count) - moved - flight, 0)
        let z = CGPoint(x: base.x, y: base.y - Slinky.ry - remaining * Slinky.gap)
        let arch: CGFloat = min(abs(a.x - z.x) * 0.5, 90)
        let control = CGPoint(x: (a.x + z.x) / 2, y: min(a.y, z.y) - arch)

        let substeps: Int = 3
        let h: CGFloat = CGFloat(dt) / CGFloat(substeps)
        let damping: CGFloat = 30
        for index in 0..<count {
            let goal: CGPoint = target(index, flight: flight, from: a, to: z, control: control)
            if index == count - 1 && mode != .rest {
                // The head coil is driven directly (finger, fall, hop).
                positions[index] = goal
                velocities[index] = .zero
                continue
            }
            for _ in 0..<substeps {
                let ax: CGFloat = (goal.x - positions[index].x) * stiffness - velocities[index].dx * damping
                let ay: CGFloat = (goal.y - positions[index].y) * stiffness - velocities[index].dy * damping
                velocities[index].dx += ax * h
                velocities[index].dy += ay * h
                positions[index].x += velocities[index].dx * h
                positions[index].y += velocities[index].dy * h
            }
        }
    }

    /// Used for the still thumbnail: an arch frozen between two steps.
    func poseArch() {
        grab()
        head = CGPoint(x: Slinky.centres[1], y: Slinky.floors[1] - Slinky.ry)
        mode = .pouring
        moved = CGFloat(count) * 0.36
        for _ in 0..<240 { follow(dt: 1.0 / 60.0, stiffness: 700) }
    }
}

private struct SlinkyDemo: View {
    let ctx: DemoContext
    @State private var model: SlinkyModel
    @State private var touching = false
    @State private var grabOffset: CGSize = .zero
    @State private var userTouched = false
    @State private var wake = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = SlinkyModel(count: ctx.int("coils"))
        if ctx.isStill { model.poseArch() }
        _model = State(initialValue: model)
    }

    var body: some View {
        let rate = ctx.cg("rate")
        let stiffness = ctx.cg("stiffness")
        let walk = ctx.bool("walk")
        let haptics = !ctx.isPreview && userTouched
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let event = ctx.isStill ? SlinkyModel.Event.none : model.step(to: date, rate: rate, stiffness: stiffness, walk: walk)
                let _ = haptics ? buzz(event) : ()
                SlinkyCanvas(model: model, tick: date)
            }
            .frame(width: Slinky.size.width, height: Slinky.size.height)
            .gestureTray()
            .gesture(drag)

            DemoHint(text: L("Lift the top coil onto another step", "提起顶圈，放到另一级台阶上"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.6, delay: 0.6) { autoCarry() }
        .onChange(of: ctx.params) {
            model.setCount(ctx.int("coils"))
            wake += 1
        }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touchEnded() }
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    touching = true
                    userTouched = true
                    script?.cancel()
                    if model.mode == .held { model.release() }
                    if model.canGrab(at: value.startLocation) {
                        let head = model.headPoint
                        grabOffset = CGSize(width: value.startLocation.x - head.x, height: value.startLocation.y - head.y)
                        model.grab()
                        Haptics.tap(.light)
                    }
                }
                touchMoved(to: CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
            }
            .onEnded { _ in touchEnded() }
    }

    private func touchMoved(to point: CGPoint) {
        model.move(to: point)
        wake += 1
    }

    private func touchEnded() {
        touching = false
        model.release()
        wake += 1
    }

    private func buzz(_ event: SlinkyModel.Event) {
        switch event {
        case .none: break
        case .landed: gestureAfterFrame { Haptics.tap(.rigid) }
        case .tick: gestureAfterFrame { Haptics.tap(.soft) }
        }
    }

    /// A scripted finger lifts the top coil over to the next step (or back to the top one) and lets go.
    private func autoCarry() {
        guard !touching, model.mode == .rest else { return }
        let from: CGPoint = model.headPoint
        let goingDown: Bool = model.level < 2
        let targetLevel: Int = goingDown ? model.level + 1 : 0
        let to = CGPoint(x: Slinky.centres[targetLevel], y: Slinky.floors[targetLevel] - (goingDown ? 30 : 46))
        let control = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - 44)
        script?.cancel()
        script = Task { @MainActor in
            model.grab()
            let finished = await GhostFinger.drag(from: from, to: to, control: control, duration: goingDown ? 0.6 : 0.95) { point in
                touchMoved(to: point)
            }
            guard finished else {
                if !touching { touchEnded() }
                return
            }
            if !touching { touchEnded() }
        }
    }
}

private struct SlinkyCanvas: View {
    let model: SlinkyModel
    let tick: Date

    var body: some View {
        Canvas { context, size in
            drawStairs(&context, size: size)
            drawCoils(&context)
        }
    }

    private func drawStairs(_ context: inout GraphicsContext, size: CGSize) {
        var block = Path()
        block.move(to: CGPoint(x: 0, y: Slinky.floors[0]))
        block.addLine(to: CGPoint(x: Slinky.edges[0], y: Slinky.floors[0]))
        block.addLine(to: CGPoint(x: Slinky.edges[0], y: Slinky.floors[1]))
        block.addLine(to: CGPoint(x: Slinky.edges[1], y: Slinky.floors[1]))
        block.addLine(to: CGPoint(x: Slinky.edges[1], y: Slinky.floors[2]))
        block.addLine(to: CGPoint(x: size.width, y: Slinky.floors[2]))
        var fill = block
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        context.fill(fill, with: .linearGradient(
            Gradient(colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.03)]),
            startPoint: CGPoint(x: 0, y: Slinky.floors[0]),
            endPoint: CGPoint(x: 0, y: size.height)
        ))
        context.stroke(block, with: .color(.primary.opacity(0.18)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
    }

    private func drawCoils(_ context: inout GraphicsContext) {
        let count: Int = model.count
        let pts: [CGPoint] = model.positions
        guard pts.count == count, count > 1 else { return }
        // Painter's order: lower on screen first, so every coil overlaps the back of the one beneath it.
        let order: [Int] = (0..<count).sorted { pts[$0].y > pts[$1].y }
        for index in order {
            let p: CGPoint = pts[index]
            let before: CGPoint = pts[max(index - 1, 0)]
            let after: CGPoint = pts[min(index + 1, count - 1)]
            var dx: CGFloat = after.x - before.x
            var dy: CGFloat = after.y - before.y
            let length: CGFloat = (dx * dx + dy * dy).squareRoot()
            if length < 0.5 {
                dx = 0
                dy = -1
            } else {
                dx /= length
                dy /= length
            }
            // Coils seen from slightly above: full ellipse when the path runs vertically, edge-on at an apex.
            let minor: CGFloat = max(Slinky.ry * abs(dy), 2.6)
            let turn: Double = atan2(Double(dy), Double(dx)) + .pi / 2
            let t: Double = Double(model.tints[index]) / Double(max(count - 1, 1))
            let rgb: GestureRGB = GestureRGB.hue(0.93 - 0.8 * t, saturation: 0.72, brightness: 1)
            var layer = context
            layer.translateBy(x: p.x, y: p.y)
            layer.rotate(by: .radians(turn))
            let ellipse = Path(ellipseIn: CGRect(x: -Slinky.rx, y: -minor, width: Slinky.rx * 2, height: minor * 2))
            layer.fill(ellipse, with: .color(rgb.mixed(GestureRGB(0.06, 0.05, 0.14), 0.62).color()))
            layer.stroke(ellipse, with: .color(rgb.color()), lineWidth: 3.2)
            layer.stroke(ellipse, with: .color(.white.opacity(0.32)), lineWidth: 0.8)
        }
    }
}
