import SwiftUI

extension Effect {
    static let gesturesJoystick = Effect(
        id: "gestures.joystick",
        category: .gestures,
        interaction: .gesture,
        name: L("Thumb Stick", "虚拟摇杆"),
        summary: L("A thumb-stick held inside its ring steers a little ship by velocity, then springs back to centre.", "被圆环限位的摇杆以速度操控小飞船，松手后弹回中心。"),
        prompt: L(
            "A 124 pt recessed stick base with four faint chevrons holds a 56 pt glossy knob; above it a 300×150 pt arena shows a small arrow-shaped ship and a glowing orb. Touching the base moves the knob to the finger, clamped to a 34 pt circle with a rigid haptic when it reaches the rim; the base tilts up to 12° toward the push and the chevron on that side lights up. Deflection sets the ship's target velocity (full tilt = 240 pt/s) and the ship eases into it over about 0.18 s, turns its nose along its heading and leaves a tapering trail; reaching the orb pops a ring and moves the orb. On release the knob springs home (response 0.3 s, damping 0.55, one small overshoot) while the ship coasts to rest. Game-like and precise.",
            "124 pt的下凹摇杆底座带四个方向箭头，中间是56 pt的光泽摇杆帽；上方300×150 pt的场地里有一艘箭头形小飞船和一颗发光能量球。触摸底座，摇杆帽移到指下，被限制在34 pt的圆内，顶到边缘时有一次硬朗触感；底座朝推动方向倾斜最多12°，该侧箭头亮起。偏移量决定飞船的目标速度（推满240 pt/s），飞船约0.18秒缓入，船头转向航向并拖出渐细的尾迹；碰到能量球迸出光环，能量球换位。松手后摇杆帽以弹簧（响应0.3秒、阻尼0.55）回中并轻微过冲，飞船滑行停下。精准如手柄。"
        ),
        implementation: L(
            "A DragGesture on the base clamps the knob offset to a circle and writes the normalised deflection into a reference-type model; a TimelineView steps the ship (velocity eased toward deflection × speed) and a Canvas draws the trail, ship and orb. Release animates the knob home with a spring.",
            "底座上的 DragGesture 把摇杆帽偏移限制在圆内，并把归一化偏移写入引用类型模型；TimelineView 逐帧推进飞船（速度向“偏移 × 速度”缓动），Canvas 绘制尾迹、飞船与能量球。松手时用弹簧把摇杆帽送回中心。"
        ),
        apis: ["DragGesture", "TimelineView(.animation)", "Canvas", "rotation3DEffect", "spring(response:dampingFraction:)"],
        tags: ["joystick", "thumb stick", "game controller", "velocity", "摇杆", "手柄", "游戏", "速度控制"],
        params: [
            .slider("speed", L("Ship speed", "飞船速度"), 100...420, default: 240, step: 10, decimals: 0, unit: "pt/s"),
            .slider("inertia", L("Ship inertia", "飞船惯性"), 0.04...0.6, default: 0.18, unit: "s"),
            .slider("response", L("Return response", "回中响应"), 0.15...0.7, default: 0.3, unit: "s"),
            .slider("damping", L("Return damping", "回中阻尼"), 0.25...1.0, default: 0.55),
        ]
    ) { ctx in
        JoystickDemo(ctx: ctx)
    }
}

private enum StickMetrics {
    static let arena = CGSize(width: 300, height: 150)
    static let base: CGFloat = 124
    static let knob: CGFloat = 56
    static let travel: CGFloat = 34
    static let margin: CGFloat = 22
}

private final class JoystickModel {
    /// Normalised stick deflection, each axis in −1…1.
    var input: CGVector = .zero
    var position = CGPoint(x: 96, y: 86)
    var velocity: CGVector = .zero
    var heading: Double = -0.5
    var trail: [CGPoint] = []
    var orb = CGPoint(x: 214, y: 56)
    var score = 0
    var burstAt: CGPoint?
    var burstAge: Double = 1
    private var orbSeed = 0
    private var clock = GestureStepClock()

    var isSettled: Bool {
        input == .zero && GestureMath.length(velocity) < 1.5 && burstAge >= 0.5 && trail.count <= 1
    }

    /// Returns `true` on the frame the ship collects the orb.
    func step(to date: Date, speed: CGFloat, inertia: Double) -> Bool {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return false }
        let blend: CGFloat = CGFloat(1 - exp(-dt / max(inertia, 0.01)))
        velocity.dx += (input.dx * speed - velocity.dx) * blend
        velocity.dy += (input.dy * speed - velocity.dy) * blend
        position.x += velocity.dx * CGFloat(dt)
        position.y += velocity.dy * CGFloat(dt)
        let m: CGFloat = StickMetrics.margin
        if position.x < m || position.x > StickMetrics.arena.width - m {
            position.x = position.x.clamped(to: m...(StickMetrics.arena.width - m))
            velocity.dx = 0
        }
        if position.y < m || position.y > StickMetrics.arena.height - m {
            position.y = position.y.clamped(to: m...(StickMetrics.arena.height - m))
            velocity.dy = 0
        }

        let v: CGFloat = GestureMath.length(velocity)
        if v > 10 {
            let target: Double = atan2(Double(velocity.dy), Double(velocity.dx))
            var delta: Double = (target - heading).truncatingRemainder(dividingBy: 2 * .pi)
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            heading += delta * (1 - exp(-dt * 14))
        }

        trail.append(position)
        let keep: Int = v > 10 ? 20 : 0
        if trail.count > keep { trail.removeFirst(min(trail.count - keep, v > 10 ? 1 : 2)) }

        burstAge += dt
        if GestureMath.distance(position, orb) < 19 {
            burstAt = orb
            burstAge = 0
            score += 1
            moveOrb()
            return true
        }
        return false
    }

    private func moveOrb() {
        for _ in 0..<12 {
            orbSeed += 1
            let x: CGFloat = 28 + CGFloat(GestureMath.hash(orbSeed * 7 + 1)) * (StickMetrics.arena.width - 56)
            let y: CGFloat = 26 + CGFloat(GestureMath.hash(orbSeed * 13 + 5)) * (StickMetrics.arena.height - 52)
            let candidate = CGPoint(x: x, y: y)
            if GestureMath.distance(candidate, position) > 90 {
                orb = candidate
                return
            }
        }
        orb = CGPoint(x: StickMetrics.arena.width - position.x, y: StickMetrics.arena.height - position.y)
    }
}

private struct JoystickDemo: View {
    let ctx: DemoContext
    @State private var model = JoystickModel()
    @State private var stick: CGSize = .zero
    @State private var held = false
    @State private var atRim = false
    @State private var wake = 0
    @State private var script: Task<Void, Never>?
    /// Resets on system cancellation too, so a stolen touch never leaves the stick deflected.
    @GestureState private var pressing = false

    var body: some View {
        let speed = ctx.cg("speed")
        let inertia = ctx["inertia"]
        VStack(spacing: 14) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let collected = model.step(to: date, speed: speed, inertia: inertia)
                let _ = collected ? buzzCollect() : ()
                JoystickArena(model: model, tick: date)
            }
            .frame(width: StickMetrics.arena.width, height: StickMetrics.arena.height)

            StickBase(stick: stick, held: held)
                .contentShape(Circle())
                .gesture(drag)

            DemoHint(text: L("Push the stick to steer", "推动摇杆操控飞船"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.5) { autoPush() }
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release(haptic: false) }
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                script?.cancel()
                let centre: CGFloat = StickMetrics.base / 2
                let raw = CGSize(width: value.location.x - centre, height: value.location.y - centre)
                if !held {
                    held = true
                    if !ctx.isPreview { Haptics.tap(.light) }
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.8)) { push(raw) }
                } else {
                    push(raw)
                }
            }
            .onEnded { _ in release(haptic: true) }
    }

    /// Clamps the knob to its ring and hands the normalised deflection to the ship.
    private func push(_ raw: CGSize) {
        let length: CGFloat = (raw.width * raw.width + raw.height * raw.height).squareRoot()
        let limit: CGFloat = StickMetrics.travel
        let scale: CGFloat = length > limit ? limit / length : 1
        stick = CGSize(width: raw.width * scale, height: raw.height * scale)
        model.input = CGVector(dx: stick.width / limit, dy: stick.height / limit)
        let rim: Bool = length >= limit
        if rim != atRim {
            atRim = rim
            if rim && held && !ctx.isPreview { Haptics.tap(.rigid) }
        }
        wake += 1
    }

    private func release(haptic: Bool) {
        guard held || stick != .zero else { return }
        let wasHeld = held
        held = false
        atRim = false
        model.input = .zero
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) { stick = .zero }
        if wasHeld && haptic && !ctx.isPreview { Haptics.tap(.soft) }
        wake += 1
    }

    /// Scripted push toward the orb, through the same `push` / `release` the finger uses.
    private func autoPush() {
        guard !held else { return }
        let dx: CGFloat = model.orb.x - model.position.x
        let dy: CGFloat = model.orb.y - model.position.y
        let d: CGFloat = max((dx * dx + dy * dy).squareRoot(), 1)
        let reach: CGFloat = StickMetrics.travel * 1.2
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
            push(CGSize(width: dx / d * reach, height: dy / d * reach))
        }
        let hold: Double = min(max(Double(d / max(ctx.cg("speed"), 1)) + 0.1, 0.35), 1.0)
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            release(haptic: false)
        }
    }

    private func buzzCollect() {
        guard !ctx.isPreview else { return }
        // Never fire side effects while SwiftUI is evaluating the view.
        DispatchQueue.main.async { Haptics.tap(.medium) }
    }
}

// MARK: - Arena

private struct JoystickArena: View {
    let model: JoystickModel
    /// Changes every frame so SwiftUI redraws (the model is a reference and compares equal).
    let tick: Date

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        Canvas { context, size in
            drawGrid(&context, size: size)
            drawOrb(&context)
            drawTrail(&context)
            drawShip(&context)
            drawScore(&context)
        }
        .background(Palette.elevated, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }

    private func drawGrid(_ context: inout GraphicsContext, size: CGSize) {
        var dots = Path()
        var y: CGFloat = 15
        while y < size.height {
            var x: CGFloat = 15
            while x < size.width {
                dots.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                x += 18
            }
            y += 18
        }
        context.fill(dots, with: .color(.primary.opacity(0.09)))
    }

    private func drawOrb(_ context: inout GraphicsContext) {
        let orb = model.orb
        let halo = CGRect(x: orb.x - 16, y: orb.y - 16, width: 32, height: 32)
        context.fill(
            Path(ellipseIn: halo),
            with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.45), Palette.amber.opacity(0)]), center: orb, startRadius: 2, endRadius: 16)
        )
        context.fill(Path(ellipseIn: CGRect(x: orb.x - 6, y: orb.y - 6, width: 12, height: 12)), with: .color(Palette.amber))
        context.fill(Path(ellipseIn: CGRect(x: orb.x - 3.5, y: orb.y - 4.5, width: 4, height: 4)), with: .color(.white.opacity(0.85)))

        if let at = model.burstAt, model.burstAge < 0.5 {
            let p: CGFloat = CGFloat(model.burstAge / 0.5)
            let eased: CGFloat = 1 - (1 - p) * (1 - p)
            let r: CGFloat = 8 + 26 * eased
            context.stroke(
                Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: r * 2, height: r * 2)),
                with: .color(Palette.amber.opacity(Double(1 - p))),
                lineWidth: 3 * (1 - p) + 0.5
            )
            for spoke in 0..<6 {
                let a: Double = Double(spoke) / 6 * 2 * .pi + 0.4
                let inner: CGFloat = r + 3
                let outer: CGFloat = r + 3 + 7 * (1 - p)
                var ray = Path()
                ray.move(to: CGPoint(x: at.x + CGFloat(cos(a)) * inner, y: at.y + CGFloat(sin(a)) * inner))
                ray.addLine(to: CGPoint(x: at.x + CGFloat(cos(a)) * outer, y: at.y + CGFloat(sin(a)) * outer))
                context.stroke(ray, with: .color(Palette.amber.opacity(Double(1 - p))), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    private func drawTrail(_ context: inout GraphicsContext) {
        let points = model.trail
        guard points.count > 1 else { return }
        for index in 1..<points.count {
            let t: CGFloat = CGFloat(index) / CGFloat(points.count)
            var segment = Path()
            segment.move(to: points[index - 1])
            segment.addLine(to: points[index])
            context.stroke(
                segment,
                with: .color(Palette.mint.opacity(Double(t) * 0.55)),
                style: StrokeStyle(lineWidth: 1 + 6 * t, lineCap: .round)
            )
        }
    }

    private func drawShip(_ context: inout GraphicsContext) {
        var ship = Path()
        ship.move(to: CGPoint(x: 13, y: 0))
        ship.addLine(to: CGPoint(x: -9, y: -9))
        ship.addQuadCurve(to: CGPoint(x: -9, y: 9), control: CGPoint(x: -3, y: 0))
        ship.closeSubpath()
        let transform = CGAffineTransform(translationX: model.position.x, y: model.position.y).rotated(by: CGFloat(model.heading))
        let placed = ship.applying(transform)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Palette.mint.opacity(0.6), radius: 7))
            layer.fill(
                placed,
                with: .linearGradient(
                    Gradient(colors: [Palette.mint, Palette.sky]),
                    startPoint: CGPoint(x: model.position.x - 12, y: model.position.y - 12),
                    endPoint: CGPoint(x: model.position.x + 12, y: model.position.y + 12)
                )
            )
        }
        context.stroke(placed, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
    }

    private func drawScore(_ context: inout GraphicsContext) {
        let label = Text(verbatim: "\(model.score)")
            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.primary.opacity(0.7))
        let pill = CGRect(x: 12, y: 10, width: 44, height: 22)
        context.fill(Path(roundedRect: pill, cornerRadius: 11, style: .continuous), with: .color(.primary.opacity(0.07)))
        context.fill(Path(ellipseIn: CGRect(x: pill.minX + 8, y: pill.midY - 4, width: 8, height: 8)), with: .color(Palette.amber))
        context.draw(label, at: CGPoint(x: pill.minX + 30, y: pill.midY), anchor: .center)
    }
}

// MARK: - Stick

private struct StickBase: View {
    let stick: CGSize
    let held: Bool

    var body: some View {
        let nx: CGFloat = stick.width / StickMetrics.travel
        let ny: CGFloat = stick.height / StickMetrics.travel
        let amount: CGFloat = min((nx * nx + ny * ny).squareRoot(), 1)
        ZStack {
            Circle()
                .fill(Palette.elevated)
                .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
            // Recessed well.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.primary.opacity(0.14), Color.primary.opacity(0.04)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 52
                    )
                )
                .padding(10)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1).padding(10))
            StickChevrons(nx: nx, ny: ny)
        }
        .frame(width: StickMetrics.base, height: StickMetrics.base)
        .rotation3DEffect(.degrees(Double(amount) * 12), axis: (x: -ny, y: nx, z: 0.0001), perspective: 0.5)
        .overlay {
            StickKnob(held: held)
                .offset(stick)
        }
    }
}

private struct StickChevrons: View {
    let nx: CGFloat
    let ny: CGFloat

    var body: some View {
        ZStack {
            chevron("chevron.up", glow: -ny).offset(y: -47)
            chevron("chevron.down", glow: ny).offset(y: 47)
            chevron("chevron.left", glow: -nx).offset(x: -47)
            chevron("chevron.right", glow: nx).offset(x: 47)
        }
    }

    private func chevron(_ name: String, glow: CGFloat) -> some View {
        let lit: Double = Double(max(glow, 0))
        return Image(systemName: name)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Palette.mint.opacity(lit))
            .background {
                Image(systemName: name)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.primary.opacity(0.22))
            }
            .shadow(color: Palette.mint.opacity(lit * 0.8), radius: 5)
    }
}

private struct StickKnob: View {
    let held: Bool

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [Palette.mint, Palette.sky], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Circle()
                    .fill(RadialGradient(colors: [.black.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 20))
                    .padding(9)
            }
            .overlay {
                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center))
                    .padding(3)
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1))
            .frame(width: StickMetrics.knob, height: StickMetrics.knob)
            .scaleEffect(held ? 0.94 : 1)
            .shadow(color: Palette.mint.opacity(held ? 0.5 : 0.3), radius: held ? 14 : 9, y: held ? 4 : 7)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: held)
    }
}
