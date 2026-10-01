import SwiftUI

extension Effect {
    static let gesturesBalloonTether = Effect(
        id: "gestures.balloon-tether",
        category: .gestures,
        interaction: .gesture,
        name: L("Tethered Balloon", "系绳气球"),
        summary: L("A balloon tied to a weight: pull it down and the string goes slack; let go and it floats up, snaps the string taut and bobs.", "拴在配重上的气球：往下拽，绳子松垂；松手后它飘起，把绳子绷直并上下晃荡。"),
        prompt: L(
            "A glossy coral balloon (84×100 pt, soft highlight, small knot) floats above a weight on the floor, tied by a 118 pt string of 16 simulated links. Buoyancy pulls it up at 800 pt/s² against air drag 1.6, and a gentle breeze makes it sway. Dragging the balloon moves its knot with the finger; the string goes slack and hangs in a loose curve, and the balloon stays upright. On release it accelerates upward, the string whips straight with a lag that travels down the links, and the instant it goes taut the balloon squashes about 12% and bobs two or three times, tilting along the string before settling. A floor shadow shrinks and fades with height; a soft haptic marks the snap. Weightless, playful, calm.",
            "一只亮面珊瑚色气球（84×100 pt，带柔和高光与小绳结）浮在地面配重上方，由一根118 pt、16节模拟的细绳拴住。浮力以800 pt/s²向上拉，空气阻力1.6，微风让它轻轻摇摆。拖动气球时绳结跟随手指，绳子松弛垂成一道弧线，气球保持直立。松手后它向上加速，绳子带着沿各节传递的滞后甩直；绷紧的瞬间气球被压扁约12%，上下晃两三次，并顺着绳子方向倾斜后稳住。地面阴影随高度缩小变淡，绷紧时有一次柔和触感。轻盈、俏皮而平静。"
        ),
        implementation: L(
            "A Verlet rope of 16 points is pinned to the weight; its last point is the balloon knot, which gets an upward acceleration instead of gravity and a larger mass in the distance constraints. While held the knot is kinematic. The tension impulse feeds a squash spring and the balloon's tilt follows the last links through an angular spring; a Canvas draws string, balloon and shadow.",
            "16个质点的 Verlet 绳索固定在配重上，末端质点就是气球绳结：它不受重力而受向上的加速度，并在距离约束中拥有更大的质量。按住时绳结为运动学物体。绷紧时的张力冲量驱动压扁弹簧，气球倾角通过角弹簧跟随末端几节绳子；Canvas 绘制绳子、气球与阴影。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture", "Verlet integration", "GraphicsContext.Shading.radialGradient"],
        tags: ["balloon", "string", "buoyancy", "tether", "verlet", "bob", "气球", "绳子", "浮力", "系绳", "晃荡"],
        params: [
            .slider("lift", L("Buoyancy", "浮力"), 300...1600, default: 800, step: 50, decimals: 0, unit: "pt/s²"),
            .slider("length", L("String length", "绳长"), 70...140, default: 118, step: 2, decimals: 0, unit: "pt"),
            .slider("breeze", L("Breeze", "微风"), 0...200, default: 60, step: 10, decimals: 0),
            .slider("drag", L("Air drag", "空气阻力"), 0.5...4, default: 1.6, decimals: 1),
        ]
    ) { ctx in
        BalloonTetherDemo(ctx: ctx)
    }
}

private enum Balloon {
    static let size = CGSize(width: 300, height: 270)
    static let anchor = CGPoint(x: 150, y: 242)
    static let floor: CGFloat = 250
    static let width: CGFloat = 84
    static let height: CGFloat = 100
    static let links = 16
}

private final class BalloonModel {
    private(set) var points: [CGPoint]
    private var previous: [CGPoint]
    private(set) var held = false
    private var target: CGPoint = .zero
    private(set) var angle: Double = 0
    private var angleVelocity: Double = 0
    private(set) var squash: Double = 0
    private var squashVelocity: Double = 0
    private var time: Double = 0
    private var wasTaut = true
    private var clock = GestureStepClock()
    private let h: Double = 1.0 / 180.0

    init(length: CGFloat) {
        var pts: [CGPoint] = []
        for index in 0..<Balloon.links {
            let t: CGFloat = CGFloat(index) / CGFloat(Balloon.links - 1)
            pts.append(CGPoint(x: Balloon.anchor.x, y: Balloon.anchor.y - length * t))
        }
        points = pts
        previous = pts
    }

    var knot: CGPoint { points[Balloon.links - 1] }

    var isSettledWithoutBreeze: Bool {
        guard !held else { return false }
        let last: Int = Balloon.links - 1
        let v: CGFloat = GestureMath.distance(points[last], previous[last])
        return v < 0.01 && abs(angleVelocity) < 0.01 && abs(squashVelocity) < 0.01
    }

    func contains(_ point: CGPoint) -> Bool {
        let centre = CGPoint(x: knot.x + CGFloat(sin(angle)) * 54, y: knot.y - CGFloat(cos(angle)) * 54)
        return GestureMath.distance(centre, point) < 72 || GestureMath.distance(knot, point) < 40
    }

    func grab() {
        held = true
        target = knot
    }

    func move(to point: CGPoint, length: CGFloat) {
        // The string cannot stretch: past its length the finger pulls against a rubber band.
        let dx: CGFloat = point.x - Balloon.anchor.x
        let dy: CGFloat = point.y - Balloon.anchor.y
        let d: CGFloat = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let reach: CGFloat = d > length ? length + rubberBand(d - length, limit: 14) : d
        var p = CGPoint(x: Balloon.anchor.x + dx / d * reach, y: Balloon.anchor.y + dy / d * reach)
        p.y = min(p.y, Balloon.floor - 14)
        target = p
    }

    func release() {
        held = false
    }

    /// Returns `true` on the frame the string snaps taut.
    func step(to date: Date, lift: CGFloat, length: CGFloat, breeze: CGFloat, drag: CGFloat) -> Bool {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return false }
        let steps: Int = min(max(Int((dt / h).rounded()), 1), 8)
        var snapped = false
        for _ in 0..<steps {
            if integrate(lift: lift, length: length, breeze: breeze, drag: drag) { snapped = true }
        }
        return snapped
    }

    func integrate(lift: CGFloat, length: CGFloat, breeze: CGFloat, drag: CGFloat) -> Bool {
        time += h
        let last: Int = Balloon.links - 1
        let gust: CGFloat = breeze * CGFloat(sin(time * 0.9) + 0.5 * sin(time * 2.3 + 1.0))
        let ropeDamp: CGFloat = CGFloat(exp(-h * 2.2))
        let balloonDamp: CGFloat = CGFloat(exp(-h * Double(drag)))
        let hh: CGFloat = CGFloat(h * h)
        for index in 1...last {
            let p: CGPoint = points[index]
            if index == last && held {
                previous[index] = p
                points[index] = GestureMath.lerp(p, target, 0.35)
                continue
            }
            let damp: CGFloat = index == last ? balloonDamp : ropeDamp
            let vx: CGFloat = (p.x - previous[index].x) * damp
            let vy: CGFloat = (p.y - previous[index].y) * damp
            let ax: CGFloat = index == last ? gust : gust * 0.12
            let ay: CGFloat = index == last ? -lift : 90
            previous[index] = p
            points[index] = CGPoint(x: p.x + vx + ax * hh, y: p.y + vy + ay * hh)
        }

        let segment: CGFloat = length / CGFloat(last)
        var knotPull: CGFloat = 0
        for iteration in 0..<12 {
            for index in 0..<last {
                let a: CGPoint = points[index]
                let b: CGPoint = points[index + 1]
                let dx: CGFloat = b.x - a.x
                let dy: CGFloat = b.y - a.y
                let d: CGFloat = (dx * dx + dy * dy).squareRoot()
                // A string only resists stretching.
                guard d > segment, d > 0.0001 else { continue }
                let wa: CGFloat = index == 0 ? 0 : 1
                let wb: CGFloat = index + 1 == last ? (held ? 0 : 0.22) : 1
                let total: CGFloat = wa + wb
                guard total > 0 else { continue }
                let excess: CGFloat = (d - segment) / d
                points[index].x += dx * excess * wa / total
                points[index].y += dy * excess * wa / total
                points[index + 1].x -= dx * excess * wb / total
                points[index + 1].y -= dy * excess * wb / total
                if index + 1 == last && iteration == 0 { knotPull = (d - segment) * wb / total }
            }
            for index in 1...last {
                points[index].y = min(points[index].y, Balloon.floor - 2)
                points[index].x = points[index].x.clamped(to: 8...(Balloon.size.width - 8))
            }
        }

        // Tilt: along the last links when the string is taut, upright when it is slack.
        let k: CGPoint = points[last]
        let span: CGFloat = GestureMath.distance(Balloon.anchor, k)
        let taut: Double = GestureMath.smoothstep(0.9, 1.0, Double(span / length))
        let ref: CGPoint = points[last - 4]
        let along: Double = atan2(Double(k.x - ref.x), Double(ref.y - k.y))
        let lean: Double = Double(k.x - previous[last].x) / h * -0.0009
        let goal: Double = (along * taut + lean).clamped(to: -1.0...1.0)
        angleVelocity += ((goal - angle) * 60 - angleVelocity * 5.5) * h
        angle += angleVelocity * h

        // Squash: kicked the moment a slack string goes taut.
        var snapped = false
        let isTaut: Bool = taut > 0.6
        if isTaut && !wasTaut && !held {
            let speed: Double = Double(GestureMath.distance(k, previous[last])) / h
            squashVelocity += min(speed * 0.012 + Double(knotPull) * 4, 5.5)
            snapped = speed > 60
        }
        wasTaut = isTaut
        squashVelocity += (-squash * 190 - squashVelocity * 9) * h
        squash = (squash + squashVelocity * h).clamped(to: -0.25...0.25)
        return snapped
    }
}

private struct BalloonTetherDemo: View {
    let ctx: DemoContext
    @State private var model: BalloonModel
    @State private var touching = false
    @State private var grabOffset: CGSize = .zero
    @State private var userTouched = false
    @State private var wake = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = BalloonModel(length: ctx.cg("length"))
        if ctx.isStill {
            // A still catches the balloon swaying on a taut string.
            for _ in 0..<420 { _ = model.integrate(lift: 800, length: ctx.cg("length"), breeze: 150, drag: 1.6) }
        }
        _model = State(initialValue: model)
    }

    var body: some View {
        let lift = ctx.cg("lift")
        let length = ctx.cg("length")
        let breeze = ctx.cg("breeze")
        let drag = ctx.cg("drag")
        let haptics = !ctx.isPreview && userTouched
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { breeze == 0 && model.isSettledWithoutBreeze }) { date in
                let snapped = ctx.isStill ? false : model.step(to: date, lift: lift, length: length, breeze: breeze, drag: drag)
                let _ = snapped && haptics ? gestureAfterFrame { Haptics.tap(.soft) } : ()
                BalloonCanvas(model: model, tick: date)
            }
            .frame(width: Balloon.size.width, height: Balloon.size.height)
            .gestureTray()
            .gesture(dragGesture)

            DemoHint(text: L("Pull the balloon down and let go", "把气球往下拽，再松手"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.4, delay: 0.7) { autoPull() }
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touchEnded() }
        }
        .onDisappear { script?.cancel() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    touching = true
                    userTouched = true
                    script?.cancel()
                    if model.held { model.release() }
                    if model.contains(value.startLocation) {
                        let knot = model.knot
                        grabOffset = CGSize(width: value.startLocation.x - knot.x, height: value.startLocation.y - knot.y)
                        model.grab()
                        Haptics.tap(.light)
                    }
                }
                if model.held {
                    touchMoved(to: CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
                }
            }
            .onEnded { _ in touchEnded() }
    }

    private func touchMoved(to knot: CGPoint) {
        model.move(to: knot, length: ctx.cg("length"))
        wake += 1
    }

    private func touchEnded() {
        touching = false
        guard model.held else { return }
        model.release()
        wake += 1
    }

    /// A scripted finger takes the knot, pulls it down to one side and lets go.
    private func autoPull() {
        guard !touching, !model.held else { return }
        autoStep += 1
        let start: CGPoint = model.knot
        let side: CGFloat = autoStep % 2 == 0 ? -1 : 1
        let end = CGPoint(x: Balloon.anchor.x + side * 78, y: Balloon.anchor.y - 34)
        script?.cancel()
        script = Task { @MainActor in
            model.grab()
            let finished = await GhostFinger.drag(from: start, to: end, duration: 0.75) { point in
                touchMoved(to: point)
            }
            guard finished else {
                if !touching { touchEnded() }
                return
            }
            try? await Task.sleep(for: .seconds(0.25))
            if !touching { touchEnded() }
        }
    }
}

private struct BalloonCanvas: View {
    let model: BalloonModel
    let tick: Date

    var body: some View {
        Canvas { context, size in
            drawFloor(&context, size: size)
            drawString(&context)
            drawBalloon(&context)
        }
    }

    private func drawFloor(_ context: inout GraphicsContext, size: CGSize) {
        var line = Path()
        line.move(to: CGPoint(x: 24, y: Balloon.floor))
        line.addLine(to: CGPoint(x: size.width - 24, y: Balloon.floor))
        context.stroke(line, with: .color(.primary.opacity(0.1)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Shadow under the balloon: smaller and fainter the higher it floats.
        let knot: CGPoint = model.knot
        let centreX: CGFloat = knot.x + CGFloat(sin(model.angle)) * 56
        let lift: CGFloat = ((Balloon.floor - knot.y) / 150).clamped(to: 0...1)
        let w: CGFloat = 78 - 34 * lift
        let shadow = Path(ellipseIn: CGRect(x: centreX - w / 2, y: Balloon.floor - 4, width: w, height: 9))
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            layer.fill(shadow, with: .color(.black.opacity(0.26 - 0.16 * Double(lift))))
        }

        // The weight the string is tied to.
        let body = CGRect(x: Balloon.anchor.x - 15, y: Balloon.anchor.y - 3, width: 30, height: 12)
        context.fill(Path(roundedRect: body, cornerRadius: 4), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x8A8FA3), Color(hex: 0x555A6E)]),
            startPoint: CGPoint(x: body.midX, y: body.minY),
            endPoint: CGPoint(x: body.midX, y: body.maxY)
        ))
        let loop = Path(ellipseIn: CGRect(x: Balloon.anchor.x - 4, y: Balloon.anchor.y - 8, width: 8, height: 8))
        context.stroke(loop, with: .color(Color(hex: 0x6B7086)), lineWidth: 2)
    }

    private func drawString(_ context: inout GraphicsContext) {
        let pts: [CGPoint] = model.points
        guard pts.count > 2 else { return }
        var path = Path()
        path.move(to: pts[0])
        for index in 1..<(pts.count - 1) {
            let mid: CGPoint = GestureMath.lerp(pts[index], pts[index + 1], 0.5)
            path.addQuadCurve(to: mid, control: pts[index])
        }
        path.addLine(to: pts[pts.count - 1])
        context.stroke(path, with: .color(.primary.opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }

    private func drawBalloon(_ context: inout GraphicsContext) {
        let knot: CGPoint = model.knot
        let squash: CGFloat = CGFloat(model.squash)
        let w: CGFloat = Balloon.width * (1 + squash * 0.55)
        let hgt: CGFloat = Balloon.height * (1 - squash)
        var layer = context
        layer.translateBy(x: knot.x, y: knot.y)
        layer.rotate(by: .radians(model.angle))

        // Knot.
        var tie = Path()
        tie.move(to: CGPoint(x: 0, y: -7))
        tie.addLine(to: CGPoint(x: -5.5, y: 2))
        tie.addLine(to: CGPoint(x: 5.5, y: 2))
        tie.closeSubpath()
        layer.fill(tie, with: .color(Color(hex: 0xE2455F)))

        // Body: an egg, a little wider at the top.
        let top: CGFloat = -6 - hgt
        var body = Path()
        body.move(to: CGPoint(x: 0, y: -5))
        body.addCurve(to: CGPoint(x: -w / 2, y: top + hgt * 0.42), control1: CGPoint(x: -w * 0.16, y: -8), control2: CGPoint(x: -w / 2, y: top + hgt * 0.74))
        body.addCurve(to: CGPoint(x: 0, y: top), control1: CGPoint(x: -w / 2, y: top + hgt * 0.14), control2: CGPoint(x: -w * 0.3, y: top))
        body.addCurve(to: CGPoint(x: w / 2, y: top + hgt * 0.42), control1: CGPoint(x: w * 0.3, y: top), control2: CGPoint(x: w / 2, y: top + hgt * 0.14))
        body.addCurve(to: CGPoint(x: 0, y: -5), control1: CGPoint(x: w / 2, y: top + hgt * 0.74), control2: CGPoint(x: w * 0.16, y: -8))
        body.closeSubpath()

        let lightAt = CGPoint(x: -w * 0.2, y: top + hgt * 0.28)
        layer.fill(body, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(hex: 0xFF9AA8), location: 0),
                .init(color: Color(hex: 0xFF5F7A), location: 0.45),
                .init(color: Color(hex: 0xD63A63), location: 1),
            ]),
            center: lightAt,
            startRadius: 0,
            endRadius: hgt * 0.85
        ))
        layer.stroke(body, with: .color(.white.opacity(0.22)), lineWidth: 1)

        // Soft highlight and a crisp glint.
        var soft = layer
        soft.addFilter(.blur(radius: 5))
        soft.fill(
            Path(ellipseIn: CGRect(x: -w * 0.34, y: top + hgt * 0.13, width: w * 0.3, height: hgt * 0.34)),
            with: .color(.white.opacity(0.5))
        )
        layer.fill(
            Path(ellipseIn: CGRect(x: -w * 0.27, y: top + hgt * 0.17, width: w * 0.1, height: hgt * 0.12)),
            with: .color(.white.opacity(0.85))
        )
    }
}
