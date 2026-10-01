import SwiftUI

extension Effect {
    static let gesturesDoublePendulum = Effect(
        id: "gestures.double-pendulum",
        category: .gestures,
        interaction: .gesture,
        name: L("Double Pendulum", "双摆"),
        summary: L("Two rods hinged end to end: lift either bob, let go, and watch chaos draw a glowing trail that never repeats.", "两根杆首尾铰接：提起任意一颗摆球再松手，看混沌画出一条永不重复的发光轨迹。"),
        prompt: L(
            "A double pendulum hangs from a pivot plate: a 62 pt rod to a sky-blue bob and a 58 pt rod to a larger pink bob. Grabbing the outer bob poses both rods by inverse kinematics so the bob stays under the finger; grabbing the inner bob swings the first rod while the second dangles. Releasing hands over the finger's angular velocity and the exact equations of motion take over (gravity 1,400 pt/s², RK4 at 240 Hz, damping 0.12/s): smooth arcs, sudden whips and full loops of the outer bob that never repeat. The outer bob draws a 1.8 s trail that tapers from 3.5 pt to a hair and shifts from pink to violet as it fades; the bobs glow slightly brighter the faster they move. A light haptic on grab. Hypnotic, scientific, unpredictable.",
            "双摆挂在枢轴板下：62 pt的杆连着天蓝色摆球，再接58 pt的杆连着更大的粉色摆球。抓住外侧摆球时，两根杆通过逆运动学摆出姿态，让球始终在指下；抓住内侧摆球则带动第一根杆，第二根自然垂荡。松手时继承手指的角速度，随后交给精确的运动方程（重力1400 pt/s²、240 Hz的RK4积分、阻尼0.12/s）：平滑的弧线、突然的甩动、整圈翻转，永不重复。外侧摆球拖出1.8秒的轨迹，线宽从3.5 pt收成细丝，由粉渐变到紫并淡出；摆球越快，辉光越亮。催眠而不可预测。"
        ),
        implementation: L(
            "The two angles and angular velocities are integrated with fourth-order Runge–Kutta from the Lagrangian equations of the double pendulum inside a TimelineView. While a bob is held, two-link inverse kinematics (law of cosines, keeping the elbow on its current side) sets the angles and finite differences estimate the release velocity. A Canvas strokes the timestamped trail segment by segment, then rods and bobs.",
            "两个角度与角速度在 TimelineView 中按双摆的拉格朗日方程用四阶龙格–库塔法积分。按住摆球时，由两连杆逆运动学（余弦定理，并保持肘部在当前一侧）设定角度，再用有限差分估计松手速度。Canvas 逐段描出带时间戳的轨迹，然后绘制摆杆与摆球。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture", "Runge–Kutta 4", "GraphicsContext.addFilter(.shadow)"],
        tags: ["double pendulum", "chaos", "physics", "trail", "swing", "simulation", "双摆", "混沌", "物理", "轨迹", "摆动", "模拟"],
        params: [
            .slider("gravity", L("Gravity", "重力"), 400...3000, default: 1400, step: 50, decimals: 0, unit: "pt/s²"),
            .slider("damping", L("Damping", "阻尼"), 0...1.5, default: 0.12, unit: "/s"),
            .slider("trail", L("Trail length", "轨迹时长"), 0.4...4, default: 1.8, decimals: 1, unit: "s"),
            .slider("mass", L("Outer mass ratio", "外球质量比"), 0.3...3, default: 1, decimals: 1),
        ]
    ) { ctx in
        DoublePendulumDemo(ctx: ctx)
    }
}

private enum Pendulum {
    static let size = CGSize(width: 300, height: 262)
    static let pivot = CGPoint(x: 150, y: 124)
    static let l1: Double = 62
    static let l2: Double = 58
}

private struct PendulumState {
    var a1: Double
    var a2: Double
    var w1: Double
    var w2: Double
}

private final class DoublePendulumModel {
    private(set) var state = PendulumState(a1: 2.25, a2: 2.9, w1: 0, w2: 0)
    private(set) var trail: [(point: CGPoint, time: Double)] = []
    private(set) var time: Double = 0
    /// 0 = free, 1 = inner bob held, 2 = outer bob held.
    private(set) var held = 0
    private var target: CGPoint = .zero
    private var clock = GestureStepClock()
    private let h: Double = 1.0 / 240.0
    private var substep = 0

    var inner: CGPoint {
        CGPoint(x: Pendulum.pivot.x + CGFloat(Pendulum.l1 * sin(state.a1)), y: Pendulum.pivot.y + CGFloat(Pendulum.l1 * cos(state.a1)))
    }

    var outer: CGPoint {
        let p: CGPoint = inner
        return CGPoint(x: p.x + CGFloat(Pendulum.l2 * sin(state.a2)), y: p.y + CGFloat(Pendulum.l2 * cos(state.a2)))
    }

    var speed: Double { abs(state.w1) + abs(state.w2) }

    var isSettled: Bool {
        held == 0 && speed < 0.03 && abs(sin(state.a1)) < 0.02 && abs(sin(state.a2)) < 0.02 && cos(state.a1) > 0 && cos(state.a2) > 0
            && (trail.first.map { time - $0.time > 0.3 } ?? true)
    }

    func bob(at point: CGPoint) -> Int {
        let d2: CGFloat = GestureMath.distance(point, outer)
        let d1: CGFloat = GestureMath.distance(point, inner)
        if d2 < 44 && d2 <= d1 + 8 { return 2 }
        if d1 < 40 { return 1 }
        return d2 < 70 ? 2 : 0
    }

    func grab(_ bob: Int) {
        held = bob
        target = bob == 1 ? inner : outer
    }

    func move(to point: CGPoint) {
        target = point
    }

    func release() {
        held = 0
        state.w1 = state.w1.clamped(to: -14...14)
        state.w2 = state.w2.clamped(to: -16...16)
    }

    func step(to date: Date, gravity: Double, damping: Double, ratio: Double, trailLength: Double) {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return }
        let steps: Int = min(max(Int((dt / h).rounded()), 1), 10)
        for _ in 0..<steps { advance(gravity: gravity, damping: damping, ratio: ratio) }
        trail.removeAll { time - $0.time > trailLength }
    }

    func advance(gravity: Double, damping: Double, ratio: Double) {
        time += h
        switch held {
        case 2: poseOuter()
        case 1: poseInner(gravity: gravity)
        default: integrate(gravity: gravity, damping: damping, ratio: ratio)
        }
        substep += 1
        if substep % 2 == 0 { trail.append((outer, time)) }
    }

    private static func wrapped(_ angle: Double) -> Double {
        var a: Double = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a < -.pi { a += 2 * .pi }
        return a
    }

    /// Two-link inverse kinematics: the outer bob sits on the finger.
    private func poseOuter() {
        let dx: Double = Double(target.x - Pendulum.pivot.x)
        let dy: Double = Double(target.y - Pendulum.pivot.y)
        let reach: Double = (dx * dx + dy * dy).squareRoot()
        let d: Double = reach.clamped(to: (abs(Pendulum.l1 - Pendulum.l2) + 1)...(Pendulum.l1 + Pendulum.l2 - 0.5))
        let toward: Double = atan2(dx, dy)
        let cosine: Double = ((Pendulum.l1 * Pendulum.l1 + d * d - Pendulum.l2 * Pendulum.l2) / (2 * Pendulum.l1 * d)).clamped(to: -1...1)
        let bend: Double = acos(cosine)
        // Keep the elbow on the side it is already on.
        let plus: Double = toward + bend
        let minus: Double = toward - bend
        let pick: Double = abs(Self.wrapped(plus - state.a1)) < abs(Self.wrapped(minus - state.a1)) ? plus : minus
        let a1: Double = state.a1 + Self.wrapped(pick - state.a1) * 0.5
        let ex: Double = Pendulum.l1 * sin(a1)
        let ey: Double = Pendulum.l1 * cos(a1)
        let tx: Double = d * sin(toward)
        let ty: Double = d * cos(toward)
        let a2: Double = state.a2 + Self.wrapped(atan2(tx - ex, ty - ey) - state.a2) * 0.5
        state.w1 = state.w1 * 0.9 + (a1 - state.a1) / h * 0.1
        state.w2 = state.w2 * 0.9 + (a2 - state.a2) / h * 0.1
        state.a1 = a1
        state.a2 = a2
    }

    /// The inner bob follows the finger; the outer rod hangs from it as a damped pendulum.
    private func poseInner(gravity: Double) {
        let goal: Double = atan2(Double(target.x - Pendulum.pivot.x), Double(target.y - Pendulum.pivot.y))
        let a1: Double = state.a1 + Self.wrapped(goal - state.a1) * 0.4
        let w1: Double = (a1 - state.a1) / h
        let swing: Double = -(gravity / Pendulum.l2) * sin(state.a2) - 2.5 * state.w2
            - (w1 - state.w1) / h * (Pendulum.l1 / Pendulum.l2) * cos(a1 - state.a2) * 0.15
        state.w1 = state.w1 * 0.9 + w1 * 0.1
        state.a1 = a1
        state.w2 += swing * h
        state.a2 += state.w2 * h
    }

    private func derivative(_ s: PendulumState, gravity g: Double, damping: Double, ratio: Double) -> PendulumState {
        let m1: Double = 1
        let m2: Double = ratio
        let l1: Double = Pendulum.l1
        let l2: Double = Pendulum.l2
        let delta: Double = s.a1 - s.a2
        let den: Double = 2 * m1 + m2 - m2 * cos(2 * delta)
        let n1: Double = -g * (2 * m1 + m2) * sin(s.a1) - m2 * g * sin(s.a1 - 2 * s.a2)
            - 2 * sin(delta) * m2 * (s.w2 * s.w2 * l2 + s.w1 * s.w1 * l1 * cos(delta))
        let n2: Double = 2 * sin(delta) * (s.w1 * s.w1 * l1 * (m1 + m2) + g * (m1 + m2) * cos(s.a1) + s.w2 * s.w2 * l2 * m2 * cos(delta))
        return PendulumState(a1: s.w1, a2: s.w2, w1: n1 / (l1 * den) - damping * s.w1, w2: n2 / (l2 * den) - damping * s.w2)
    }

    private func integrate(gravity: Double, damping: Double, ratio: Double) {
        func add(_ s: PendulumState, _ d: PendulumState, _ k: Double) -> PendulumState {
            PendulumState(a1: s.a1 + d.a1 * k, a2: s.a2 + d.a2 * k, w1: s.w1 + d.w1 * k, w2: s.w2 + d.w2 * k)
        }
        let k1: PendulumState = derivative(state, gravity: gravity, damping: damping, ratio: ratio)
        let k2: PendulumState = derivative(add(state, k1, h / 2), gravity: gravity, damping: damping, ratio: ratio)
        let k3: PendulumState = derivative(add(state, k2, h / 2), gravity: gravity, damping: damping, ratio: ratio)
        let k4: PendulumState = derivative(add(state, k3, h), gravity: gravity, damping: damping, ratio: ratio)
        state.a1 += (k1.a1 + 2 * k2.a1 + 2 * k3.a1 + k4.a1) * h / 6
        state.a2 += (k1.a2 + 2 * k2.a2 + 2 * k3.a2 + k4.a2) * h / 6
        state.w1 = ((state.w1 + (k1.w1 + 2 * k2.w1 + 2 * k3.w1 + k4.w1) * h / 6)).clamped(to: -40...40)
        state.w2 = ((state.w2 + (k1.w2 + 2 * k2.w2 + 2 * k3.w2 + k4.w2) * h / 6)).clamped(to: -40...40)
    }
}

private struct DoublePendulumDemo: View {
    let ctx: DemoContext
    @State private var model: DoublePendulumModel
    @State private var touching = false
    @State private var grabOffset: CGSize = .zero
    @State private var wake = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = DoublePendulumModel()
        if ctx.isStill {
            // A still shows the swing in full flight with its trail drawn.
            for _ in 0..<400 { model.advance(gravity: 1400, damping: 0.12, ratio: 1) }
        }
        _model = State(initialValue: model)
    }

    var body: some View {
        let gravity = ctx["gravity"]
        let damping = ctx["damping"]
        let ratio = ctx["mass"]
        let trail = ctx["trail"]
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let _ = ctx.isStill ? () : model.step(to: date, gravity: gravity, damping: damping, ratio: ratio, trailLength: trail)
                DoublePendulumCanvas(model: model, trailLength: trail, ratio: ratio, tick: date)
            }
            .frame(width: Pendulum.size.width, height: Pendulum.size.height)
            .gestureTray()
            .gesture(drag)

            DemoHint(text: L("Lift a bob and let it go", "提起一颗摆球再松手"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The pendulum starts raised and swings on its own, so there is no separate intro play.
        .autoplay(ctx.isPreview, every: 6.0, delay: 5.0, intro: false) { autoLift() }
        .onChange(of: ctx.params) { wake += 1 }
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
                    script?.cancel()
                    if model.held != 0 { model.release() }
                    let bob: Int = model.bob(at: value.startLocation)
                    if bob != 0 {
                        let centre: CGPoint = bob == 1 ? model.inner : model.outer
                        grabOffset = CGSize(width: value.startLocation.x - centre.x, height: value.startLocation.y - centre.y)
                        model.grab(bob)
                        Haptics.tap(.light)
                    }
                }
                touchMoved(to: CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
            }
            .onEnded { _ in touchEnded() }
    }

    private func touchMoved(to point: CGPoint) {
        guard model.held != 0 else { return }
        model.move(to: point)
        wake += 1
    }

    private func touchEnded() {
        touching = false
        guard model.held != 0 else { return }
        model.release()
        wake += 1
    }

    /// A scripted finger takes the outer bob, lifts it high to one side and lets go.
    private func autoLift() {
        guard !touching, model.held == 0 else { return }
        autoStep += 1
        let side: CGFloat = autoStep % 2 == 0 ? 1 : -1
        let from: CGPoint = model.outer
        let to = CGPoint(x: Pendulum.pivot.x + side * 92, y: Pendulum.pivot.y - 62)
        script?.cancel()
        script = Task { @MainActor in
            model.grab(2)
            let finished = await GhostFinger.drag(from: from, to: to, duration: 0.8) { point in
                touchMoved(to: point)
            }
            guard finished else {
                if !touching { touchEnded() }
                return
            }
            try? await Task.sleep(for: .seconds(0.2))
            if !touching { touchEnded() }
        }
    }
}

private struct DoublePendulumCanvas: View {
    let model: DoublePendulumModel
    let trailLength: Double
    let ratio: Double
    let tick: Date

    var body: some View {
        Canvas { context, _ in
            drawTrail(&context)
            drawRig(&context)
        }
    }

    private func drawTrail(_ context: inout GraphicsContext) {
        let trail = model.trail
        guard trail.count > 2 else { return }
        // Short runs of four samples, each one stroke: no doubled alpha where segments meet.
        var index = 1
        while index < trail.count {
            let last: Int = min(index + 3, trail.count - 1)
            let age: Double = (model.time - trail[index].time) / max(trailLength, 0.1)
            let fresh: Double = max(1 - age, 0)
            var run = Path()
            run.move(to: trail[index - 1].point)
            for k in index...last { run.addLine(to: trail[k].point) }
            let rgb: GestureRGB = GestureRGB(hex: 0xFF5FA2).mixed(GestureRGB(hex: 0x7B61FF), min(age * 1.2, 1))
            context.stroke(
                run,
                with: .color(rgb.color(0.9 * fresh * fresh + 0.08 * fresh)),
                style: StrokeStyle(lineWidth: 0.6 + 2.9 * CGFloat(fresh), lineCap: .butt, lineJoin: .round)
            )
            index = last + 1
        }
    }

    private func drawRig(_ context: inout GraphicsContext) {
        let pivot: CGPoint = Pendulum.pivot
        let inner: CGPoint = model.inner
        let outer: CGPoint = model.outer
        let glow: Double = min(model.speed / 18, 1)

        // Mount.
        let plate = CGRect(x: pivot.x - 22, y: pivot.y - 5, width: 44, height: 10)
        context.fill(Path(roundedRect: plate, cornerRadius: 5), with: .color(.primary.opacity(0.14)))

        var rods = Path()
        rods.move(to: pivot)
        rods.addLine(to: inner)
        rods.addLine(to: outer)
        context.stroke(rods, with: .color(.primary.opacity(0.62)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
        context.fill(Path(ellipseIn: CGRect(x: pivot.x - 4.5, y: pivot.y - 4.5, width: 9, height: 9)), with: .color(.primary.opacity(0.85)))

        drawBob(&context, at: inner, radius: 11, colors: [Color(hex: 0x8ADFFF), Color(hex: 0x3A9BFF)], glow: Palette.sky, amount: glow, held: model.held == 1)
        let r2: CGFloat = 11 + 3.5 * CGFloat(min(max(ratio, 0.3), 3).squareRoot())
        drawBob(&context, at: outer, radius: r2, colors: [Color(hex: 0xFF9CC4), Color(hex: 0xF0428F)], glow: Palette.pink, amount: glow, held: model.held == 2)
    }

    private func drawBob(_ context: inout GraphicsContext, at p: CGPoint, radius: CGFloat, colors: [Color], glow: Color, amount: Double, held: Bool) {
        let r: CGFloat = radius * (held ? 1.12 : 1)
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        var layer = context
        layer.addFilter(.shadow(color: glow.opacity(0.35 + 0.5 * amount), radius: 5 + 9 * CGFloat(amount)))
        layer.fill(Path(ellipseIn: rect), with: .color(colors[1]))
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [colors[0], colors[1]]),
            center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.4),
            startRadius: 0,
            endRadius: r * 1.4
        ))
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - r * 0.5, y: p.y - r * 0.58, width: r * 0.42, height: r * 0.3)),
            with: .color(.white.opacity(0.7))
        )
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(held ? 0.8 : 0.3)), lineWidth: 1)
    }
}
