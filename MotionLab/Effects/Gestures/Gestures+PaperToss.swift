import SwiftUI

extension Effect {
    static let gesturesPaperToss = Effect(
        id: "gestures.paper-toss",
        category: .gestures,
        interaction: .gesture,
        name: L("Paper Toss", "投纸团"),
        summary: L("Flick a crumpled paper ball in an arc at a wire bin: it can rattle off the rim, drop in and score.", "把纸团沿抛物线甩向铁丝纸篓：可能磕到篓沿弹跳，落进去就得分。"),
        prompt: L(
            "A 15 pt-radius crumpled paper ball rests on the floor of a 300×280 pt rounded room, with a 92 pt-tall wire-mesh bin (78 pt opening, tapered sides) to the right and a huge faint score numeral on the back wall. Grab the ball and flick: the release velocity launches it under 1,500 pt/s² gravity, leaving a dotted trace that fades in 0.7 s. The bin's two side walls are real colliders, so the ball can clip a rim, bounce with 0.45 restitution, spin and rattle down inside behind the mesh. Crossing the mouth scores: the numeral rolls and punches to 118%, a \"+1\" floats up 34 pt, the bin gulps with a damped wobble and a success haptic fires; a miss rolls to rest and resets the streak. A fresh ball pops in with a spring. Playful and fair.",
            "半径15 pt的皱纸团停在300×280 pt圆角房间的地面上，右侧是92 pt高的铁丝网纸篓（开口78 pt、两侧内收），背景墙上印着巨大而浅淡的得分数字。抓起纸团一甩：离手速度即初速度，在1500 pt/s²重力下飞出，身后的虚线轨迹0.7秒内淡去。纸篓两侧篓壁是真实碰撞体，纸团可能磕到篓沿，以0.45的恢复系数弹起、旋转，再在网后落底。越过篓口即得分：数字冲到118%，“+1”向上飘34 pt，纸篓带阻尼地晃一下，成功触感响起；没进则滚停并清空连中。新纸团以弹簧弹出。有趣而公平。"
        ),
        implementation: L(
            "A reference-type model integrates the ball in 1/240 s substeps with gravity and circle-versus-segment collisions against the bin's side walls; a TimelineView feeds a Canvas that draws the bin's back, the ball and then the mesh front so the ball sinks behind it. The DragGesture hands its release velocity to the same launch function the autoplay solves a ballistic shot for.",
            "引用类型模型以 1/240 秒子步长积分纸团，包含重力以及圆与线段（纸篓两侧篓壁）的碰撞；TimelineView 驱动 Canvas 依次绘制纸篓背面、纸团、铁丝网正面，让纸团沉到网后。DragGesture 把松手速度交给发射函数，自动演示则解出一条弹道后调用同一函数。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture.Value.velocity", "GraphicsContext.clip", "Path"],
        tags: ["toss", "throw", "ballistic", "basket", "score", "game", "投掷", "抛物线", "纸篓", "得分", "小游戏"],
        params: [
            .slider("gravity", L("Gravity", "重力"), 800...2600, default: 1500, step: 50, decimals: 0, unit: "pt/s²"),
            .slider("bounce", L("Restitution", "恢复系数"), 0.2...0.75, default: 0.45),
            .slider("mouth", L("Bin opening", "篓口宽度"), 56...110, default: 78, step: 2, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        PaperTossDemo(ctx: ctx)
    }
}

private enum TossRoom {
    static let size = CGSize(width: 300, height: 280)
    static let floorY: CGFloat = 258
    static let radius: CGFloat = 15
    static let start = CGPoint(x: 54, y: floorY - radius)
    static let binX: CGFloat = 224
    static let binHeight: CGFloat = 92
    static let rimY: CGFloat = floorY - binHeight
    static let wall: CGFloat = 2
}

private enum TossEvent {
    case bump
    case score
    case miss
}

private final class PaperTossModel {
    enum Phase {
        case ready
        case held
        case flying
        case ending
    }

    var position = TossRoom.start
    var velocity: CGVector = .zero
    var phase: Phase = .ready
    var spin: Double = 0.3
    private var spinVelocity: Double = 0
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var scored = false
    private(set) var scoreAge: Double = 10
    private(set) var endingAge: Double = 0
    private(set) var spawnAge: Double = 10
    private(set) var flightAge: Double = 0
    private var restAge: Double = 0
    private(set) var trace: [(point: CGPoint, age: Double)] = []
    private var traceTimer: Double = 0
    private var lastBump: Double = 10
    private var clock = GestureStepClock()

    var isSettled: Bool {
        phase == .ready && scoreAge > 1.2 && spawnAge > 0.6 && trace.isEmpty
    }

    func hold(at point: CGPoint) {
        let r: CGFloat = TossRoom.radius
        position = CGPoint(
            x: point.x.clamped(to: r...(TossRoom.size.width - r)),
            y: point.y.clamped(to: r...(TossRoom.floorY - r))
        )
        velocity = .zero
        phase = .held
    }

    func launch(velocity launchVelocity: CGVector) {
        velocity = launchVelocity
        phase = .flying
        scored = false
        flightAge = 0
        restAge = 0
        spinVelocity = Double(launchVelocity.dx) / 40
    }

    /// The launch velocity that carries the ball from its current spot to `target` in `time` seconds.
    func solve(target: CGPoint, time: CGFloat, gravity: CGFloat) -> CGVector {
        CGVector(
            dx: (target.x - position.x) / time,
            dy: (target.y - position.y) / time - gravity * time / 2
        )
    }

    func step(to date: Date, gravity: CGFloat, restitution: CGFloat, mouth: CGFloat) -> [TossEvent] {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return [] }
        var events: [TossEvent] = []
        scoreAge += dt
        spawnAge += dt
        lastBump += dt
        trace = trace.compactMap { $0.age + dt < 0.7 ? (point: $0.point, age: $0.age + dt) : nil }

        switch phase {
        case .ready, .held:
            break
        case .ending:
            endingAge += dt
            simulate(dt: dt, gravity: gravity, restitution: restitution, mouth: mouth, events: &events)
            if endingAge > 0.75 {
                position = TossRoom.start
                velocity = .zero
                spin = 0.3
                phase = .ready
                spawnAge = 0
            }
        case .flying:
            flightAge += dt
            traceTimer += dt
            if traceTimer > 0.035 {
                traceTimer = 0
                trace.append((point: position, age: 0))
            }
            simulate(dt: dt, gravity: gravity, restitution: restitution, mouth: mouth, events: &events)
            let half: CGFloat = mouth / 2
            let inside: Bool = abs(position.x - TossRoom.binX) < half - 3 && position.y > TossRoom.rimY + TossRoom.radius * 0.6
            if inside && !scored {
                scored = true
                score += 1
                streak += 1
                scoreAge = 0
                events.append(.score)
            }
            let slow: Bool = GestureMath.length(velocity) < 14 && position.y > TossRoom.floorY - TossRoom.radius - 1.5
            restAge = slow || (scored && GestureMath.length(velocity) < 40) ? restAge + dt : 0
            if restAge > (scored ? 0.45 : 0.3) || flightAge > 5 {
                if !scored {
                    streak = 0
                    events.append(.miss)
                }
                phase = .ending
                endingAge = 0
            }
        }
        return events
    }

    private func simulate(dt: Double, gravity: CGFloat, restitution: CGFloat, mouth: CGFloat, events: inout [TossEvent]) {
        let substeps: Int = max(Int((dt * 240).rounded(.up)), 1)
        let h: CGFloat = CGFloat(dt) / CGFloat(substeps)
        let r: CGFloat = TossRoom.radius
        let half: CGFloat = mouth / 2
        let foot: CGFloat = mouth * 0.37
        let leftTop = CGPoint(x: TossRoom.binX - half, y: TossRoom.rimY)
        let leftBottom = CGPoint(x: TossRoom.binX - foot, y: TossRoom.floorY)
        let rightTop = CGPoint(x: TossRoom.binX + half, y: TossRoom.rimY)
        let rightBottom = CGPoint(x: TossRoom.binX + foot, y: TossRoom.floorY)
        var hardest: CGFloat = 0

        for _ in 0..<substeps {
            velocity.dy += gravity * h
            position.x += velocity.dx * h
            position.y += velocity.dy * h

            hardest = max(hardest, collide(leftTop, leftBottom, restitution: restitution))
            hardest = max(hardest, collide(rightTop, rightBottom, restitution: restitution))

            if position.y > TossRoom.floorY - r {
                position.y = TossRoom.floorY - r
                if velocity.dy > 0 {
                    hardest = max(hardest, velocity.dy)
                    velocity.dy = -velocity.dy * restitution
                    if abs(velocity.dy) < 50 { velocity.dy = 0 }
                    velocity.dx *= 0.9
                }
                velocity.dx *= CGFloat(exp(-Double(h) * 2.2))
                spinVelocity = Double(velocity.dx / r)
            }
            if position.x < r {
                position.x = r
                velocity.dx = abs(velocity.dx) * restitution
            }
            if position.x > TossRoom.size.width - r {
                position.x = TossRoom.size.width - r
                velocity.dx = -abs(velocity.dx) * restitution
            }
            spin += spinVelocity * Double(h)
        }
        if hardest > 260 && lastBump > 0.08 {
            lastBump = 0
            events.append(.bump)
        }
    }

    /// Circle against a thick segment. Returns the impact speed along the contact normal.
    private func collide(_ a: CGPoint, _ b: CGPoint, restitution: CGFloat) -> CGFloat {
        let abx: CGFloat = b.x - a.x
        let aby: CGFloat = b.y - a.y
        let lengthSquared: CGFloat = abx * abx + aby * aby
        guard lengthSquared > 0 else { return 0 }
        let t: CGFloat = (((position.x - a.x) * abx + (position.y - a.y) * aby) / lengthSquared).clamped(to: 0...1)
        let cx: CGFloat = a.x + abx * t
        let cy: CGFloat = a.y + aby * t
        let dx: CGFloat = position.x - cx
        let dy: CGFloat = position.y - cy
        let distance: CGFloat = (dx * dx + dy * dy).squareRoot()
        let reach: CGFloat = TossRoom.radius + TossRoom.wall
        guard distance < reach, distance > 0.001 else { return 0 }
        let nx: CGFloat = dx / distance
        let ny: CGFloat = dy / distance
        position.x = cx + nx * reach
        position.y = cy + ny * reach
        let vn: CGFloat = velocity.dx * nx + velocity.dy * ny
        guard vn < 0 else { return 0 }
        let tx: CGFloat = -ny
        let ty: CGFloat = nx
        let vt: CGFloat = (velocity.dx * tx + velocity.dy * ty) * 0.92
        let bounced: CGFloat = -vn * restitution
        velocity.dx = nx * bounced + tx * vt
        velocity.dy = ny * bounced + ty * vt
        spinVelocity = Double(vt / TossRoom.radius)
        return -vn
    }
}

private struct PaperTossDemo: View {
    let ctx: DemoContext
    @State private var model = PaperTossModel()
    @State private var held = false
    @State private var grabOffset: CGSize = .zero
    @State private var wake = 0
    @State private var autoShot = 0
    /// Resets on system cancellation too, so a stolen touch never leaves the ball hanging in the air.
    @GestureState private var pressing = false

    var body: some View {
        let gravity = ctx.cg("gravity")
        let restitution = ctx.cg("bounce")
        let mouth = ctx.cg("mouth")
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let events = model.step(to: date, gravity: gravity, restitution: restitution, mouth: mouth)
                let _ = events.isEmpty ? () : buzz(events)
                PaperTossScene(model: model, mouth: mouth, held: held, tick: date)
                    // Only a disc around the ball takes touches, so swipes elsewhere still scroll the page.
                    .contentShape(TossGrabArea(center: model.position, radius: TossRoom.radius + 26))
                    .gesture(drag)
            }
            .frame(width: TossRoom.size.width, height: TossRoom.size.height)

            DemoHint(text: L("Flick the paper ball into the bin", "把纸团甩进纸篓"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.8, delay: 0.5) { autoThrow() }
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { letGo(velocity: .zero) }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held {
                    guard model.phase == .ready || model.phase == .flying else { return }
                    held = true
                    grabOffset = CGSize(width: value.startLocation.x - model.position.x, height: value.startLocation.y - model.position.y)
                    if !ctx.isPreview { Haptics.tap(.light) }
                }
                model.hold(at: CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
                wake += 1
            }
            .onEnded { value in
                letGo(velocity: CGVector(
                    dx: value.velocity.width.clamped(to: -2400...2400),
                    dy: value.velocity.height.clamped(to: -2400...2400)
                ))
            }
    }

    private func letGo(velocity: CGVector) {
        guard held else { return }
        held = false
        model.launch(velocity: velocity)
        wake += 1
    }

    /// Solves a ballistic shot (clean, then one that clips the far rim) and launches it through the
    /// same function a finger release calls.
    private func autoThrow() {
        guard !held, model.phase == .ready else { return }
        autoShot += 1
        let mouth = ctx.cg("mouth")
        let offsets: [CGFloat] = [0, mouth / 2 - 5, -4, -(mouth / 2) + 3]
        let target = CGPoint(x: TossRoom.binX + offsets[autoShot % offsets.count], y: TossRoom.rimY - 6)
        model.launch(velocity: model.solve(target: target, time: 0.82, gravity: ctx.cg("gravity")))
        wake += 1
    }

    private func buzz(_ events: [TossEvent]) {
        guard !ctx.isPreview else { return }
        // Never fire side effects while SwiftUI is evaluating the view.
        DispatchQueue.main.async {
            for event in events {
                switch event {
                case .bump: Haptics.tap(.soft)
                case .score: Haptics.success()
                case .miss: Haptics.tap(.light)
                }
            }
        }
    }
}

private struct TossGrabArea: Shape {
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

// MARK: - Scene

private struct PaperTossScene: View {
    let model: PaperTossModel
    let mouth: CGFloat
    let held: Bool
    /// Changes every frame so SwiftUI redraws (the model is a reference and compares equal).
    let tick: Date

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        Canvas { context, size in
            drawScore(&context, size: size)
            drawFloor(&context, size: size)
            drawBin(&context, front: false)
            drawTrace(&context)
            drawBall(&context)
            drawBin(&context, front: true)
            drawPop(&context)
        }
        .background(Palette.elevated, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    /// Damped wobble of the bin after a score.
    private var gulp: CGFloat {
        let t: Double = model.scoreAge
        guard t < 1 else { return 0 }
        return CGFloat(sin(t * 20) * exp(-t * 6.5)) * 0.07
    }

    private func drawScore(_ context: inout GraphicsContext, size: CGSize) {
        let t: Double = model.scoreAge
        let punch: CGFloat = t < 0.6 ? 1 + 0.18 * CGFloat(exp(-t * 7) * cos(t * 13)) : 1
        let label = Text(verbatim: "\(model.score)")
            .font(.system(size: 96, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.primary.opacity(t < 0.6 ? 0.07 + 0.1 * exp(-t * 6) : 0.07))
        var layer = context
        layer.translateBy(x: size.width / 2 - 34, y: 96)
        layer.scaleBy(x: punch, y: punch)
        layer.draw(label, at: .zero, anchor: .center)
    }

    private func drawFloor(_ context: inout GraphicsContext, size: CGSize) {
        var line = Path()
        line.move(to: CGPoint(x: 18, y: TossRoom.floorY + 1))
        line.addLine(to: CGPoint(x: size.width - 18, y: TossRoom.floorY + 1))
        context.stroke(line, with: .color(.primary.opacity(0.1)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private func binOutline() -> Path {
        let half: CGFloat = mouth / 2
        let foot: CGFloat = mouth * 0.37
        var path = Path()
        path.move(to: CGPoint(x: TossRoom.binX - half, y: TossRoom.rimY))
        path.addLine(to: CGPoint(x: TossRoom.binX - foot, y: TossRoom.floorY))
        path.addLine(to: CGPoint(x: TossRoom.binX + foot, y: TossRoom.floorY))
        path.addLine(to: CGPoint(x: TossRoom.binX + half, y: TossRoom.rimY))
        return path
    }

    private func drawBin(_ context: inout GraphicsContext, front: Bool) {
        let half: CGFloat = mouth / 2
        var layer = context
        // Wobble about the bin's foot.
        layer.translateBy(x: TossRoom.binX, y: TossRoom.floorY)
        layer.scaleBy(x: 1 + gulp, y: 1 - gulp)
        layer.translateBy(x: -TossRoom.binX, y: -TossRoom.floorY)

        let rimRect = CGRect(x: TossRoom.binX - half, y: TossRoom.rimY - 6, width: mouth, height: 12)
        var body = binOutline()
        body.closeSubpath()

        if !front {
            layer.fill(body, with: .color(.primary.opacity(0.05)))
            layer.fill(Path(ellipseIn: rimRect), with: .color(.primary.opacity(0.1)))
            var back = Path()
            back.addArc(center: .zero, radius: 1, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            let placed = back.applying(CGAffineTransform(translationX: rimRect.midX, y: rimRect.midY).scaledBy(x: half, y: 6))
            layer.stroke(placed, with: .color(.primary.opacity(0.3)), lineWidth: 1.5)
            return
        }

        // Diagonal wire mesh, clipped to the bin's face.
        var meshLayer = layer
        meshLayer.clip(to: body)
        var mesh = Path()
        var offset: CGFloat = -TossRoom.binHeight
        while offset < mouth + TossRoom.binHeight {
            let x: CGFloat = TossRoom.binX - half + offset
            mesh.move(to: CGPoint(x: x, y: TossRoom.rimY))
            mesh.addLine(to: CGPoint(x: x + TossRoom.binHeight, y: TossRoom.floorY))
            mesh.move(to: CGPoint(x: x + TossRoom.binHeight, y: TossRoom.rimY))
            mesh.addLine(to: CGPoint(x: x, y: TossRoom.floorY))
            offset += 11
        }
        meshLayer.stroke(mesh, with: .color(.primary.opacity(0.2)), lineWidth: 1)

        layer.stroke(binOutline(), with: .color(.primary.opacity(0.5)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        var frontArc = Path()
        frontArc.addArc(center: .zero, radius: 1, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        let placed = frontArc.applying(CGAffineTransform(translationX: rimRect.midX, y: rimRect.midY).scaledBy(x: half, y: 6))
        layer.stroke(placed, with: .color(.primary.opacity(0.55)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        if model.scoreAge < 0.7 {
            let glow: Double = exp(-model.scoreAge * 5)
            layer.stroke(Path(ellipseIn: rimRect), with: .color(Palette.green.opacity(glow)), lineWidth: 3)
        }
    }

    private func drawTrace(_ context: inout GraphicsContext) {
        for dot in model.trace {
            let fade: Double = 1 - dot.age / 0.7
            let r: CGFloat = 2.2
            context.fill(
                Path(ellipseIn: CGRect(x: dot.point.x - r, y: dot.point.y - r, width: r * 2, height: r * 2)),
                with: .color(.primary.opacity(0.28 * fade))
            )
        }
    }

    private func drawBall(_ context: inout GraphicsContext) {
        let r: CGFloat = TossRoom.radius
        let p = model.position
        var alpha: Double = 1
        var scale: CGFloat = held ? 1.1 : 1
        if model.phase == .ending {
            alpha = 1 - GestureMath.smoothstep(0.45, 0.72, model.endingAge)
        }
        if model.spawnAge < 0.6 {
            let t: Double = model.spawnAge
            scale = CGFloat(1 - exp(-t * 11) * cos(t * 17))
        }

        // Contact shadow on the floor.
        let height: CGFloat = max(TossRoom.floorY - r - p.y, 0)
        let near: CGFloat = max(1 - height / 200, 0.2)
        var shadow = context
        shadow.addFilter(.blur(radius: 3))
        shadow.fill(
            Path(ellipseIn: CGRect(x: p.x - r * near, y: TossRoom.floorY - 3, width: r * 2 * near, height: 6)),
            with: .color(.black.opacity(0.2 * Double(near) * alpha))
        )

        var layer = context
        layer.opacity = alpha
        layer.translateBy(x: p.x, y: p.y)
        layer.scaleBy(x: scale, y: scale)
        layer.rotate(by: .radians(model.spin))

        // A jagged outline and a few creases read as crumpled paper and make the spin visible.
        var outline = Path()
        let vertices = 11
        for index in 0..<vertices {
            let angle: Double = Double(index) / Double(vertices) * 2 * .pi
            let jitter: CGFloat = 0.88 + 0.12 * CGFloat(GestureMath.hash(index * 3 + 2))
            let point = CGPoint(x: CGFloat(cos(angle)) * r * jitter, y: CGFloat(sin(angle)) * r * jitter)
            if index == 0 { outline.move(to: point) } else { outline.addLine(to: point) }
        }
        outline.closeSubpath()
        layer.drawLayer { inner in
            inner.addFilter(.shadow(color: .black.opacity(0.22), radius: 4, y: 2))
            inner.fill(
                outline,
                with: .linearGradient(
                    Gradient(colors: [Color(white: 1), Color(white: 0.84)]),
                    startPoint: CGPoint(x: -r, y: -r),
                    endPoint: CGPoint(x: r, y: r)
                )
            )
        }
        var creases = Path()
        for index in 0..<5 {
            let a: Double = GestureMath.hash(index * 11 + 1) * 2 * .pi
            let b: Double = a + 1.6 + GestureMath.hash(index * 5 + 9) * 1.4
            let ra: CGFloat = r * (0.5 + 0.4 * CGFloat(GestureMath.hash(index + 40)))
            let rb: CGFloat = r * (0.3 + 0.5 * CGFloat(GestureMath.hash(index + 70)))
            creases.move(to: CGPoint(x: CGFloat(cos(a)) * ra, y: CGFloat(sin(a)) * ra))
            creases.addLine(to: CGPoint(x: CGFloat(cos(b)) * rb, y: CGFloat(sin(b)) * rb))
        }
        layer.stroke(creases, with: .color(.black.opacity(0.16)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        layer.stroke(outline, with: .color(.black.opacity(0.14)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
    }

    private func drawPop(_ context: inout GraphicsContext) {
        let t: Double = model.scoreAge
        guard t < 0.9 else { return }
        let rise: CGFloat = 34 * CGFloat(1 - pow(1 - min(t / 0.9, 1), 3))
        let fade: Double = 1 - GestureMath.smoothstep(0.5, 0.9, t)
        let scale: CGFloat = CGFloat(1 - exp(-t * 14) * cos(t * 20))
        let text: String = model.streak > 1 ? "+1  ×\(model.streak)" : "+1"
        let label = Text(verbatim: text)
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .foregroundStyle(Palette.green)
        var layer = context
        layer.opacity = fade
        layer.translateBy(x: TossRoom.binX, y: TossRoom.rimY - 22 - rise)
        layer.scaleBy(x: scale, y: scale)
        layer.draw(label, at: .zero, anchor: .center)
    }
}
