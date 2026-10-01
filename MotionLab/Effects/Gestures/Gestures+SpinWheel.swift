import SwiftUI

extension Effect {
    static let gesturesSpinWheel = Effect(
        id: "gestures.spin-wheel",
        category: .gestures,
        interaction: .gesture,
        name: L("Prize Wheel", "幸运转盘"),
        summary: L("Flick a prize wheel: it spins down under friction while a flapper clacks over the pegs, then settles in a wedge.", "甩动幸运转盘：在摩擦下逐渐减速，拨片咔嗒掠过每颗销钉，最后停在一格里。"),
        prompt: L(
            "A 232 pt prize wheel of 8 coloured wedges with white values, a peg on every divider and a 64 pt hub showing the value under the pointer; an amber flapper hangs at twelve o'clock. Dragging turns the wheel 1:1 about its centre; releasing converts the finger's tangential velocity into spin (up to 22 rad/s). Speed then decays exponentially (friction 0.8 per second) plus a small constant drag. Each peg that passes kicks the flapper sideways; it snaps back on a stiff under-damped spring with a selection tick, and the hub value rolls. Below 3 rad/s the pegs push back, so the wheel never rests on a divider: it rocks into the middle of a wedge. Then the winning wedge flashes, the hub punches to 116% and a success haptic lands. Mechanical, suspenseful, fair.",
            "232 pt的幸运转盘分成8个带数值的彩色扇区，每条分界线上有一颗销钉，中央64 pt的轮毂显示指针下的数值；十二点方向垂着琥珀色拨片。拖动时转盘绕中心1:1跟手；松手把手指的切向速度换算成转速（最高22 rad/s），此后按指数衰减（摩擦0.8/秒）并叠加少量恒定阻力。每颗销钉经过都把拨片拨向一侧，拨片由欠阻尼弹簧弹回，伴随选择触感，轮毂数值滚动。低于3 rad/s后销钉回推，转盘不会停在分界线上，而是晃进某格中央；随后中奖扇区闪亮，轮毂冲到116%，成功触感落下。机械、有悬念。"
        ),
        implementation: L(
            "A reference-type model integrates angle and angular velocity in a TimelineView (exponential friction, constant drag and a sinusoidal peg detent at low speed) and emits a tick whenever the wedge under the pointer changes, which kicks a spring-driven flapper. A Canvas draws the rotated wedges; the DragGesture turns finger position into an angle and its release velocity into r × v ∕ r².",
            "引用类型模型在 TimelineView 中积分角度与角速度（指数摩擦、恒定阻力，以及低速时的正弦销钉阻尼），每当指针下的扇区变化就发出一次 tick，并踢动由弹簧驱动的拨片。Canvas 绘制旋转后的扇区；DragGesture 把手指位置换算为角度，松手速度按 r × v ∕ r² 换算为角速度。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture.Value.velocity", "contentTransition(.numericText)", "rotationEffect"],
        tags: ["wheel", "spin", "fortune", "lottery", "friction", "detent", "转盘", "抽奖", "旋转", "惯性", "摩擦"],
        params: [
            .slider("friction", L("Friction", "摩擦"), 0.3...2.0, default: 0.8),
            .slider("segments", L("Wedges", "扇区数"), 6...12, default: 8, step: 2, decimals: 0),
            .slider("detent", L("Peg resistance", "销钉阻力"), 0...1, default: 0.5),
        ]
    ) { ctx in
        SpinWheelDemo(ctx: ctx)
    }
}

private enum WheelMetrics {
    static let outer: CGFloat = 232
    static let disc: CGFloat = 208
    static let hub: CGFloat = 64
    static let prizes: [Int] = [10, 50, 5, 100, 20, 200, 15, 75, 30, 500, 25, 150]
    static let colors: [Color] = [
        Palette.indigo, Palette.pink, Palette.amber, Palette.mint, Palette.violet, Palette.coral,
        Palette.sky, Palette.green, Palette.blue, Palette.red, Color(hex: 0x8E7CFF), Color(hex: 0xFF9F5A),
    ]
}

private enum WheelEvent {
    case tick(Int)
    case win(Int)
}

private final class SpinWheelModel {
    var angle: Double = 0.26
    var omega: Double = 0
    var isHeld = false
    private(set) var flap: Double = 0
    private var flapVelocity: Double = 0
    private(set) var winner: Int?
    private(set) var winAge: Double = 10
    private(set) var time: Double = 0
    private var spinning = false
    private var calm: Double = 0
    private var lastIndex: Int?
    private var lastAngle: Double = 0.26
    private var clock = GestureStepClock()

    var isSettled: Bool {
        !isHeld && !spinning && abs(omega) < 0.01 && abs(flap) < 0.005 && abs(flapVelocity) < 0.05 && winAge > 1.4
    }

    /// The wedge under the pointer at twelve o'clock, and how far through it (0…1) the pointer sits.
    func pointer(segments: Int) -> (index: Int, fraction: Double) {
        let slice: Double = 2 * .pi / Double(segments)
        var rel: Double = (-.pi / 2 - angle).truncatingRemainder(dividingBy: 2 * .pi)
        if rel < 0 { rel += 2 * .pi }
        let raw: Double = rel / slice
        let index: Int = min(Int(raw), segments - 1)
        return (index, raw - Double(index))
    }

    func grab() {
        isHeld = true
        omega = 0
        spinning = false
        winner = nil
    }

    func release(omega releaseOmega: Double) {
        isHeld = false
        omega = releaseOmega.clamped(to: -22...22)
        spinning = abs(omega) > 0.6
        calm = 0
        if spinning { winner = nil }
    }

    func step(to date: Date, friction: Double, segments: Int, detent: Double) -> [WheelEvent] {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return [] }
        time += dt
        winAge += dt
        var events: [WheelEvent] = []

        let substeps = 4
        let h: Double = dt / Double(substeps)
        for _ in 0..<substeps {
            if !isHeld {
                omega *= exp(-friction * h)
                let drag: Double = 0.5 * h
                omega = abs(omega) <= drag ? 0 : omega - (omega > 0 ? drag : -drag)
                // Pegs against the flapper: at low speed the wheel is pushed off the dividers.
                let slow: Double = 1 - GestureMath.smoothstep(1.5, 3.0, abs(omega))
                if slow > 0 && (spinning || abs(omega) > 0) {
                    let fraction: Double = pointer(segments: segments).fraction
                    let torque: Double = -sin(2 * .pi * fraction) * detent * 26 * slow
                    omega += torque * h
                    omega *= exp(-6 * slow * h)
                }
                angle += omega * h
            }
            flapVelocity += (-560 * flap - 13 * flapVelocity) * h
            flap = (flap + flapVelocity * h).clamped(to: -0.75...0.75)
        }

        let measured: Double = isHeld ? (angle - lastAngle) / dt : omega
        lastAngle = angle
        let index: Int = pointer(segments: segments).index
        if let last = lastIndex, last != index {
            let direction: Double = measured >= 0 ? -1 : 1
            flapVelocity = direction * min(abs(measured) * 1.7 + 4, 15)
            events.append(.tick(index))
        }
        lastIndex = index

        if spinning && !isHeld {
            calm = abs(omega) < 0.25 ? calm + dt : 0
            if calm > 0.12 {
                spinning = false
                omega = 0
                winner = index
                winAge = 0
                events.append(.win(index))
            }
        }
        return events
    }
}

private struct SpinWheelDemo: View {
    let ctx: DemoContext
    @State private var model = SpinWheelModel()
    @State private var current = 0
    @State private var won = false
    @State private var held = false
    @State private var lastTouchAngle: Double = 0
    @State private var wake = 0
    @State private var autoTurn = 0
    /// Resets on system cancellation too, so a stolen touch never leaves the wheel frozen in the hand.
    @GestureState private var pressing = false

    var body: some View {
        let friction = ctx["friction"]
        let segments = max(ctx.int("segments"), 2)
        let detent = ctx["detent"]
        VStack(spacing: 12) {
            ZStack {
                GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                    let events = model.step(to: date, friction: friction, segments: segments, detent: detent)
                    let _ = events.isEmpty ? () : handle(events)
                    WheelFace(model: model, segments: segments, tick: date)
                        .overlay(alignment: .top) {
                            WheelFlapper()
                                .rotationEffect(.radians(model.flap), anchor: UnitPoint(x: 0.5, y: 0.2))
                                .offset(y: -6)
                        }
                }
                WheelHub(value: WheelMetrics.prizes[current % WheelMetrics.prizes.count], won: won)
                    .allowsHitTesting(false)
            }
            .frame(width: WheelMetrics.outer, height: WheelMetrics.outer)
            .contentShape(Circle())
            .gesture(drag)
            .padding(.top, 8)

            DemoHint(text: L("Flick the wheel to spin", "甩动转盘"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.4, delay: 0.5) { autoSpin() }
        .onAppear { current = model.pointer(segments: segments).index }
        .onChange(of: ctx.params) {
            current = model.pointer(segments: segments).index
            wake += 1
        }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { letGo(omega: 0) }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                let centre: CGFloat = WheelMetrics.outer / 2
                let touch: Double = atan2(Double(value.location.y - centre), Double(value.location.x - centre))
                if !held {
                    held = true
                    lastTouchAngle = touch
                    model.grab()
                    if won { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { won = false } }
                    if !ctx.isPreview { Haptics.tap(.light) }
                }
                var delta: Double = touch - lastTouchAngle
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                lastTouchAngle = touch
                model.angle += delta
                wake += 1
            }
            .onEnded { value in
                let centre: CGFloat = WheelMetrics.outer / 2
                let rx: Double = Double(value.location.x - centre)
                let ry: Double = Double(value.location.y - centre)
                let r2: Double = max(rx * rx + ry * ry, 900)
                // Angular velocity of the finger about the hub: (r × v) ∕ r².
                letGo(omega: (rx * Double(value.velocity.height) - ry * Double(value.velocity.width)) / r2)
            }
    }

    private func letGo(omega: Double) {
        guard held else { return }
        held = false
        model.release(omega: omega)
        wake += 1
    }

    /// The same release a finger performs, with a scripted spin.
    private func autoSpin() {
        guard !held, !model.isHeld else { return }
        autoTurn += 1
        if won { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { won = false } }
        model.release(omega: 9.5 + Double(autoTurn % 3) * 1.7)
        wake += 1
    }

    private func handle(_ events: [WheelEvent]) {
        let silent = ctx.isPreview
        // Never mutate state while SwiftUI is evaluating the view.
        DispatchQueue.main.async {
            for event in events {
                switch event {
                case .tick(let index):
                    withAnimation(.snappy(duration: 0.16)) { current = index }
                    if !silent { Haptics.selection() }
                case .win(let index):
                    current = index
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { won = true }
                    if !silent { Haptics.success() }
                }
            }
        }
    }
}

// MARK: - Wheel

private struct WheelFace: View {
    let model: SpinWheelModel
    let segments: Int
    /// Changes every frame so SwiftUI redraws (the model is a reference and compares equal).
    let tick: Date

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            drawRim(&context, centre: centre)
            drawWedges(&context, centre: centre)
        }
        .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
    }

    private func drawRim(_ context: inout GraphicsContext, centre: CGPoint) {
        let outer: CGFloat = WheelMetrics.outer / 2
        let rim = Path(ellipseIn: CGRect(x: centre.x - outer, y: centre.y - outer, width: outer * 2, height: outer * 2))
        context.fill(
            rim,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x3A3D4A), Color(hex: 0x17181F)]),
                startPoint: CGPoint(x: centre.x, y: centre.y - outer),
                endPoint: CGPoint(x: centre.x, y: centre.y + outer)
            )
        )
        context.stroke(rim, with: .color(.white.opacity(0.14)), lineWidth: 1)
        // Chasing bulbs while it turns; all flash together on a win.
        let bulbs = 20
        let flash: Double = model.winAge < 1.2 ? (sin(model.winAge * 22) > 0 ? 1 : 0.25) : -1
        for index in 0..<bulbs {
            let a: Double = Double(index) / Double(bulbs) * 2 * .pi
            let r: CGFloat = outer - 6
            let p = CGPoint(x: centre.x + CGFloat(cos(a)) * r, y: centre.y + CGFloat(sin(a)) * r)
            let chase: Double = abs(model.omega) > 0.2 ? ((index + Int(model.time * 9)) % 3 == 0 ? 1 : 0.28) : (index % 2 == 0 ? 0.8 : 0.3)
            let lit: Double = flash >= 0 ? flash : chase
            context.fill(Path(ellipseIn: CGRect(x: p.x - 2.6, y: p.y - 2.6, width: 5.2, height: 5.2)), with: .color(Palette.amber.opacity(0.25 + 0.75 * lit)))
        }
    }

    private func drawWedges(_ context: inout GraphicsContext, centre: CGPoint) {
        let radius: CGFloat = WheelMetrics.disc / 2
        let slice: Double = 2 * .pi / Double(segments)
        var wheel = context
        wheel.translateBy(x: centre.x, y: centre.y)
        wheel.rotate(by: .radians(model.angle))

        for index in 0..<segments {
            let start: Double = Double(index) * slice
            var wedge = Path()
            wedge.move(to: .zero)
            wedge.addArc(center: .zero, radius: radius, startAngle: .radians(start), endAngle: .radians(start + slice), clockwise: false)
            wedge.closeSubpath()
            let color = WheelMetrics.colors[index % WheelMetrics.colors.count]
            wheel.fill(wedge, with: .color(color))
            if let winner = model.winner, model.winAge < 1.4 {
                if winner == index {
                    let glow: Double = 0.38 * (0.5 + 0.5 * cos(model.winAge * 16)) * exp(-model.winAge * 1.6)
                    wheel.fill(wedge, with: .color(.white.opacity(glow)))
                } else {
                    wheel.fill(wedge, with: .color(.black.opacity(0.22 * exp(-model.winAge * 1.2))))
                }
            }

            var label = wheel
            label.rotate(by: .radians(start + slice / 2))
            label.translateBy(x: radius * 0.68, y: 0)
            label.rotate(by: .degrees(90))
            let text = Text(verbatim: "\(WheelMetrics.prizes[index % WheelMetrics.prizes.count])")
                .font(.system(size: segments > 8 ? 14 : 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            label.draw(text, at: .zero, anchor: .center)
        }

        // Dividers and pegs.
        for index in 0..<segments {
            let a: Double = Double(index) * slice
            let dir = CGPoint(x: CGFloat(cos(a)), y: CGFloat(sin(a)))
            var divider = Path()
            divider.move(to: CGPoint(x: dir.x * 30, y: dir.y * 30))
            divider.addLine(to: CGPoint(x: dir.x * radius, y: dir.y * radius))
            wheel.stroke(divider, with: .color(.white.opacity(0.3)), lineWidth: 1)
            let peg = CGPoint(x: dir.x * (radius - 5), y: dir.y * (radius - 5))
            wheel.fill(Path(ellipseIn: CGRect(x: peg.x - 3.6, y: peg.y - 3.6, width: 7.2, height: 7.2)), with: .color(.white))
            wheel.stroke(Path(ellipseIn: CGRect(x: peg.x - 3.6, y: peg.y - 3.6, width: 7.2, height: 7.2)), with: .color(.black.opacity(0.2)), lineWidth: 0.8)
        }

        // Fixed lighting over the turning disc.
        let disc = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
        context.fill(
            disc,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.18)]),
                startPoint: CGPoint(x: centre.x - radius * 0.6, y: centre.y - radius),
                endPoint: CGPoint(x: centre.x + radius * 0.6, y: centre.y + radius)
            )
        )
        context.stroke(disc, with: .color(.black.opacity(0.25)), lineWidth: 1.5)
    }
}

private struct WheelFlapper: View {
    var body: some View {
        FlapperShape()
            .fill(LinearGradient(colors: [Palette.amber, Palette.coral], startPoint: .top, endPoint: .bottom))
            .overlay(FlapperShape().stroke(.white.opacity(0.6), lineWidth: 1))
            .overlay(alignment: .top) {
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 5, height: 5)
                    .padding(.top, 4)
            }
            .frame(width: 22, height: 34)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }
}

private struct FlapperShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = rect.width / 2
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + r), radius: r, startAngle: .degrees(200), endAngle: .degrees(-20), clockwise: false)
        path.addLine(to: CGPoint(x: rect.midX + 2, y: rect.maxY - 2))
        path.addQuadCurve(to: CGPoint(x: rect.midX - 2, y: rect.maxY - 2), control: CGPoint(x: rect.midX, y: rect.maxY + 1))
        path.closeSubpath()
        return path
    }
}

private struct WheelHub: View {
    let value: Int
    let won: Bool

    var body: some View {
        Circle()
            .fill(Palette.elevated)
            .overlay(Circle().strokeBorder(won ? Palette.amber : Color.primary.opacity(0.12), lineWidth: won ? 3 : 1))
            .overlay {
                Text(verbatim: "\(value)")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(value)))
                    .foregroundStyle(won ? AnyShapeStyle(Palette.sunset) : AnyShapeStyle(Color.primary))
                    .padding(.horizontal, 6)
            }
            .frame(width: WheelMetrics.hub, height: WheelMetrics.hub)
            .scaleEffect(won ? 1.16 : 1)
            .shadow(color: won ? Palette.amber.opacity(0.6) : .black.opacity(0.25), radius: won ? 14 : 8, y: won ? 0 : 4)
    }
}
