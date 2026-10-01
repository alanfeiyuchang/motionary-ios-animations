import SwiftUI

extension Effect {
    static let gesturesBallPit = Effect(
        id: "gestures.ball-pit",
        category: .gestures,
        interaction: .gesture,
        name: L("Ball Pit", "海洋球池"),
        summary: L("A tray of glossy balls with gravity and real collisions: grab one and throw it, or tap to blast them apart.", "一盘带重力和真实碰撞的亮面小球：抓起一颗甩出去，或点一下把它们炸开。"),
        prompt: L(
            "Eighteen glossy balls (13–22 pt radius, palette colours, a radial highlight and a spot that shows their spin) lie piled in a 300×280 pt rounded tray. Gravity is 1,600 pt/s²; balls collide with each other, the walls and the rounded corners with 0.55 restitution, exchanging momentum by mass (radius squared), integrated in 1/240 s substeps so stacks stay stable. Grabbing a ball makes it follow the finger as an immovable body that shoulders the others aside; releasing hands over the finger's velocity as a throw. Tapping empty space fires a radial impulse of up to 1,100 pt/s that falls off over 150 pt, with a ring that expands to 150 pt and fades in 0.45 s. Hard impacts give soft haptics, and the simulation sleeps once everything rests. Tactile, chaotic, satisfying.",
            "18颗亮面小球（半径13–22 pt，带高光和显示自转的圆斑）堆在300×280 pt的圆角托盘里。重力1600 pt/s²；小球之间、与四壁及圆角都会碰撞，恢复系数0.55，按质量（半径平方）交换动量，以1/240秒子步长积分，堆叠保持稳定。抓住一颗球，它作为不可推动的物体跟随手指，把其他球挤开；松手时继承手指速度被甩出。点击空白处释放一次径向冲量，最高1100 pt/s、在150 pt内衰减，同时一圈光环扩散到150 pt并在0.45秒内淡出。重击带来柔和触感，全部静止后模拟休眠。"
        ),
        implementation: L(
            "A reference-type model steps gravity, pairwise circle collisions (positional correction plus a restitution impulse weighted by inverse mass) and wall and corner constraints in fixed substeps inside a TimelineView; a Canvas draws every ball with a radial gradient. The DragGesture either pins the touched ball as a kinematic body or, on a tap, applies a radial impulse.",
            "引用类型模型在 TimelineView 中以固定子步长推进重力、两两圆碰撞（位置修正加上按逆质量加权的恢复冲量）以及墙壁和圆角约束；Canvas 用径向渐变绘制每颗球。DragGesture 要么把被触摸的球固定为运动学物体，要么在点击时施加径向冲量。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture.Value.velocity", "GraphicsContext.Shading.radialGradient", "drawingGroup"],
        tags: ["physics", "collision", "balls", "gravity", "throw", "impulse", "物理", "碰撞", "小球", "重力", "抛掷"],
        params: [
            .slider("count", L("Balls", "小球数量"), 6...24, default: 18, step: 1, decimals: 0),
            .slider("gravity", L("Gravity", "重力"), 0...3000, default: 1600, step: 50, decimals: 0, unit: "pt/s²"),
            .slider("bounce", L("Restitution", "恢复系数"), 0.2...0.9, default: 0.55),
        ]
    ) { ctx in
        BallPitDemo(ctx: ctx)
    }
}

private enum Pit {
    static let size = CGSize(width: 300, height: 280)
    static let corner: CGFloat = 30
    static let colors: [Color] = [
        Palette.indigo, Palette.pink, Palette.amber, Palette.mint, Palette.sky,
        Palette.coral, Palette.violet, Palette.green, Palette.blue,
    ]
}

private struct PitBall {
    var position: CGPoint
    var velocity: CGVector = .zero
    let radius: CGFloat
    let color: Int
    var spin: Double = 0
}

private final class BallPitModel {
    private(set) var balls: [PitBall] = []
    private(set) var heldIndex: Int?
    private var finger: CGPoint = .zero
    private(set) var blastAt: CGPoint?
    private(set) var blastAge: Double = 10
    private var hitCooldown: Double = 0
    private var seed = 0
    private var clock = GestureStepClock()
    private let h: CGFloat = 1.0 / 240.0

    init(count: Int) {
        setCount(count, settle: true)
    }

    var isSettled: Bool {
        heldIndex == nil && blastAge > 0.5 && balls.allSatisfy { GestureMath.length($0.velocity) < 12 }
    }

    func setCount(_ count: Int, settle: Bool = false) {
        while balls.count > count { balls.removeLast() }
        while balls.count < count {
            seed += 1
            let radius: CGFloat = 13 + CGFloat(GestureMath.hash(seed * 3 + 1)) * 9
            let x: CGFloat = 36 + CGFloat(GestureMath.hash(seed * 7 + 2)) * (Pit.size.width - 72)
            let y: CGFloat = settle ? 30 + CGFloat(GestureMath.hash(seed * 11 + 5)) * 200 : radius + 4
            balls.append(PitBall(position: CGPoint(x: x, y: y), radius: radius, color: seed % Pit.colors.count))
        }
        if let held = heldIndex, held >= balls.count { heldIndex = nil }
        guard settle else { return }
        // Let the pile fall into place before the first frame (and for the still thumbnail).
        for _ in 0..<1400 { _ = integrate(gravity: 1600, restitution: 0.3) }
        for index in balls.indices { balls[index].velocity = .zero }
    }

    func ball(at point: CGPoint) -> Int? {
        var best: Int?
        var bestDistance: CGFloat = .greatestFiniteMagnitude
        for (index, ball) in balls.enumerated() {
            let d: CGFloat = GestureMath.distance(ball.position, point)
            if d < ball.radius + 10 && d < bestDistance {
                best = index
                bestDistance = d
            }
        }
        return best
    }

    func grab(_ index: Int, at point: CGPoint) {
        heldIndex = index
        finger = point
    }

    func move(to point: CGPoint) {
        finger = point
    }

    func release(velocity: CGVector) {
        guard let index = heldIndex, balls.indices.contains(index) else {
            heldIndex = nil
            return
        }
        balls[index].velocity = CGVector(dx: velocity.dx.clamped(to: -2600...2600), dy: velocity.dy.clamped(to: -2600...2600))
        heldIndex = nil
    }

    /// Radial kick away from `point`.
    func impulse(at point: CGPoint, strength: CGFloat = 1100) {
        blastAt = point
        blastAge = 0
        for index in balls.indices where index != heldIndex {
            let dx: CGFloat = balls[index].position.x - point.x
            let dy: CGFloat = balls[index].position.y - point.y
            let d: CGFloat = max((dx * dx + dy * dy).squareRoot(), 1)
            let falloff: CGFloat = max(1 - d / 150, 0)
            guard falloff > 0 else { continue }
            balls[index].velocity.dx += dx / d * strength * falloff
            balls[index].velocity.dy += dy / d * strength * falloff - 160 * falloff
        }
    }

    /// Returns the hardest impact speed of this frame (for haptics).
    func step(to date: Date, gravity: CGFloat, restitution: CGFloat) -> CGFloat {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return 0 }
        blastAge += dt
        hitCooldown -= dt
        let steps: Int = max(Int((dt / Double(h)).rounded()), 1)
        var hardest: CGFloat = 0
        for _ in 0..<min(steps, 10) {
            hardest = max(hardest, integrate(gravity: gravity, restitution: restitution))
        }
        if hardest > 420 && hitCooldown <= 0 {
            hitCooldown = 0.07
            return hardest
        }
        return 0
    }

    private func integrate(gravity: CGFloat, restitution: CGFloat) -> CGFloat {
        var hardest: CGFloat = 0
        let drag: CGFloat = CGFloat(exp(-Double(h) * 0.35))
        for index in balls.indices {
            if index == heldIndex {
                // Kinematic: chase the finger, carrying a velocity the others can feel.
                let vx: CGFloat = ((finger.x - balls[index].position.x) * 28).clamped(to: -2600...2600)
                let vy: CGFloat = ((finger.y - balls[index].position.y) * 28).clamped(to: -2600...2600)
                balls[index].velocity = CGVector(dx: vx, dy: vy)
            } else {
                balls[index].velocity.dy += gravity * h
                balls[index].velocity.dx *= drag
                balls[index].velocity.dy *= drag
            }
            balls[index].position.x += balls[index].velocity.dx * h
            balls[index].position.y += balls[index].velocity.dy * h
            balls[index].spin += Double(balls[index].velocity.dx / balls[index].radius) * Double(h) * 0.7
        }

        let count: Int = balls.count
        if count > 1 {
            for a in 0..<(count - 1) {
                for b in (a + 1)..<count {
                    hardest = max(hardest, collide(a, b, restitution: restitution))
                }
            }
        }
        for index in balls.indices {
            hardest = max(hardest, contain(index, restitution: restitution))
        }
        return hardest
    }

    private func collide(_ a: Int, _ b: Int, restitution: CGFloat) -> CGFloat {
        let dx: CGFloat = balls[b].position.x - balls[a].position.x
        let dy: CGFloat = balls[b].position.y - balls[a].position.y
        let reach: CGFloat = balls[a].radius + balls[b].radius
        let d2: CGFloat = dx * dx + dy * dy
        guard d2 < reach * reach, d2 > 0.0001 else { return 0 }
        let d: CGFloat = d2.squareRoot()
        let nx: CGFloat = dx / d
        let ny: CGFloat = dy / d
        let wa: CGFloat = a == heldIndex ? 0 : 1 / (balls[a].radius * balls[a].radius)
        let wb: CGFloat = b == heldIndex ? 0 : 1 / (balls[b].radius * balls[b].radius)
        let total: CGFloat = wa + wb
        guard total > 0 else { return 0 }
        let overlap: CGFloat = reach - d
        balls[a].position.x -= nx * overlap * wa / total
        balls[a].position.y -= ny * overlap * wa / total
        balls[b].position.x += nx * overlap * wb / total
        balls[b].position.y += ny * overlap * wb / total

        let approach: CGFloat = (balls[b].velocity.dx - balls[a].velocity.dx) * nx + (balls[b].velocity.dy - balls[a].velocity.dy) * ny
        guard approach < 0 else { return 0 }
        // Slow contacts do not bounce, which keeps a resting pile quiet.
        let e: CGFloat = approach > -40 ? 0 : restitution
        let j: CGFloat = -(1 + e) * approach / total
        balls[a].velocity.dx -= j * wa * nx
        balls[a].velocity.dy -= j * wa * ny
        balls[b].velocity.dx += j * wb * nx
        balls[b].velocity.dy += j * wb * ny
        return -approach
    }

    private func contain(_ index: Int, restitution: CGFloat) -> CGFloat {
        guard index != heldIndex else {
            let r: CGFloat = balls[index].radius
            balls[index].position.x = balls[index].position.x.clamped(to: r...(Pit.size.width - r))
            balls[index].position.y = balls[index].position.y.clamped(to: r...(Pit.size.height - r))
            return 0
        }
        var hardest: CGFloat = 0
        let r: CGFloat = balls[index].radius
        var p: CGPoint = balls[index].position
        var v: CGVector = balls[index].velocity
        let w: CGFloat = Pit.size.width
        let hgt: CGFloat = Pit.size.height
        let c: CGFloat = Pit.corner

        // Rounded corners: keep the centre inside a circle of radius (corner − r) around the corner centre.
        let cx: CGFloat = p.x < c ? c : (p.x > w - c ? w - c : p.x)
        let cy: CGFloat = p.y < c ? c : (p.y > hgt - c ? hgt - c : p.y)
        if cx != p.x && cy != p.y {
            let dx: CGFloat = p.x - cx
            let dy: CGFloat = p.y - cy
            let d: CGFloat = (dx * dx + dy * dy).squareRoot()
            let limit: CGFloat = max(c - r, 0)
            if d > limit && d > 0.001 {
                let nx: CGFloat = dx / d
                let ny: CGFloat = dy / d
                p.x = cx + nx * limit
                p.y = cy + ny * limit
                let vn: CGFloat = v.dx * nx + v.dy * ny
                if vn > 0 {
                    hardest = max(hardest, vn)
                    let e: CGFloat = vn < 40 ? 0 : restitution
                    v.dx -= (1 + e) * vn * nx
                    v.dy -= (1 + e) * vn * ny
                }
            }
        } else {
            if p.x < r {
                p.x = r
                if v.dx < 0 {
                    hardest = max(hardest, -v.dx)
                    v.dx = -v.dx * restitution
                }
            } else if p.x > w - r {
                p.x = w - r
                if v.dx > 0 {
                    hardest = max(hardest, v.dx)
                    v.dx = -v.dx * restitution
                }
            }
            if p.y < r {
                p.y = r
                if v.dy < 0 { v.dy = -v.dy * restitution }
            } else if p.y > hgt - r {
                p.y = hgt - r
                if v.dy > 0 {
                    hardest = max(hardest, v.dy)
                    v.dy = v.dy < 40 ? 0 : -v.dy * restitution
                }
                // Rolling friction on the floor.
                v.dx *= CGFloat(exp(-Double(h) * 1.6))
            }
        }
        balls[index].position = p
        balls[index].velocity = v
        return hardest
    }
}

private struct BallPitDemo: View {
    let ctx: DemoContext
    @State private var model: BallPitModel
    @State private var touching = false
    @State private var grabOffset: CGSize = .zero
    @State private var userTouched = false
    @State private var wake = 0
    @State private var autoStep = 0
    /// Resets on system cancellation too, so a stolen touch never leaves a ball pinned to a ghost finger.
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _model = State(initialValue: BallPitModel(count: ctx.int("count")))
    }

    var body: some View {
        let gravity = ctx.cg("gravity")
        let restitution = ctx.cg("bounce")
        let haptics = !ctx.isPreview && userTouched
        let shape = RoundedRectangle(cornerRadius: Pit.corner, style: .continuous)
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let impact = model.step(to: date, gravity: gravity, restitution: restitution)
                let _ = impact > 0 && haptics ? buzz() : ()
                BallPitCanvas(model: model, tick: date)
            }
            .frame(width: Pit.size.width, height: Pit.size.height)
            .background(Palette.elevated, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            .contentShape(shape)
            .gesture(drag)

            DemoHint(text: L("Throw a ball, or tap an empty spot", "抓球甩出去，或点击空白处"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.4, delay: 0.5) { autoBlast() }
        .onChange(of: ctx.params) {
            model.setCount(ctx.int("count"))
            wake += 1
        }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { letGo(velocity: .zero, tapAt: nil) }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    touching = true
                    userTouched = true
                    if let index = model.ball(at: value.startLocation) {
                        let centre = model.balls[index].position
                        grabOffset = CGSize(width: value.startLocation.x - centre.x, height: value.startLocation.y - centre.y)
                        model.grab(index, at: centre)
                        Haptics.tap(.light)
                    }
                }
                if model.heldIndex != nil {
                    model.move(to: CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
                }
                wake += 1
            }
            .onEnded { value in
                let moved: CGFloat = abs(value.translation.width) + abs(value.translation.height)
                letGo(
                    velocity: CGVector(dx: value.velocity.width, dy: value.velocity.height),
                    tapAt: model.heldIndex == nil && moved < 12 ? value.location : nil
                )
            }
    }

    private func letGo(velocity: CGVector, tapAt: CGPoint?) {
        guard touching else { return }
        touching = false
        if model.heldIndex != nil {
            model.release(velocity: velocity)
        } else if let tapAt {
            blast(at: tapAt)
            Haptics.tap(.medium)
        }
        wake += 1
    }

    private func blast(at point: CGPoint) {
        model.impulse(at: point)
        wake += 1
    }

    /// The same impulse a tap fires, from a spot low in the pile.
    private func autoBlast() {
        guard !touching else { return }
        autoStep += 1
        let x: CGFloat = 70 + CGFloat(GestureMath.hash(autoStep * 5 + 3)) * (Pit.size.width - 140)
        blast(at: CGPoint(x: x, y: Pit.size.height - 34))
    }

    private func buzz() {
        // Never fire side effects while SwiftUI is evaluating the view.
        DispatchQueue.main.async { Haptics.tap(.soft) }
    }
}

private struct BallPitCanvas: View {
    let model: BallPitModel
    /// Changes every frame so SwiftUI redraws (the model is a reference and compares equal).
    let tick: Date

    var body: some View {
        Canvas { context, _ in
            drawBlast(&context)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.22), radius: 5, y: 3))
                for (index, ball) in model.balls.enumerated() {
                    drawBall(&layer, ball, held: index == model.heldIndex)
                }
            }
        }
    }

    private func drawBlast(_ context: inout GraphicsContext) {
        guard let at = model.blastAt, model.blastAge < 0.45 else { return }
        let p: CGFloat = CGFloat(model.blastAge / 0.45)
        let eased: CGFloat = 1 - (1 - p) * (1 - p) * (1 - p)
        let r: CGFloat = 14 + 136 * eased
        context.stroke(
            Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: r * 2, height: r * 2)),
            with: .color(.primary.opacity(0.28 * Double(1 - p))),
            lineWidth: 2 + 6 * (1 - p)
        )
    }

    private func drawBall(_ context: inout GraphicsContext, _ ball: PitBall, held: Bool) {
        let r: CGFloat = ball.radius * (held ? 1.08 : 1)
        let p = ball.position
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        let color = Pit.colors[ball.color % Pit.colors.count]
        let disc = Path(ellipseIn: rect)
        context.fill(disc, with: .color(color))
        // A lighter spot that turns with the ball shows its spin.
        let spot = CGPoint(x: p.x + CGFloat(cos(ball.spin)) * r * 0.42, y: p.y + CGFloat(sin(ball.spin)) * r * 0.42)
        context.fill(
            Path(ellipseIn: CGRect(x: spot.x - r * 0.26, y: spot.y - r * 0.26, width: r * 0.52, height: r * 0.52)),
            with: .color(.white.opacity(0.28))
        )
        context.fill(
            disc,
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.55), location: 0),
                    .init(color: .white.opacity(0), location: 0.45),
                    .init(color: .black.opacity(0), location: 0.7),
                    .init(color: .black.opacity(0.28), location: 1),
                ]),
                center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.4),
                startRadius: 0,
                endRadius: r * 1.5
            )
        )
        context.stroke(disc, with: .color(.white.opacity(held ? 0.7 : 0.25)), lineWidth: 1)
    }
}
