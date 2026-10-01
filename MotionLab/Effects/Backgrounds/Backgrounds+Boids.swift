import SwiftUI

extension Effect {
    static let backgroundsBoids = Effect(
        id: "backgrounds.boids",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Murmuration", "椋鸟群飞"),
        summary: L(
            "A flock of birds swirls as one body against a dusk sky and splits around your finger like around a hawk.",
            "鸟群在黄昏的天空中如同一个整体般盘旋，遇到手指就像遇到鹰一样分开绕行。"
        ),
        prompt: L(
            "A dusk sky fading from indigo through mauve to amber above dark hills, with a low sun glow. 90 small bird silhouettes fly as a murmuration driven by three local rules: each bird matches the average heading of neighbours within 46 pt, drifts toward their centre, and pushes away from any closer than 18 pt. A slowly wandering roost point keeps the flock circling in sweeping figure-eights instead of leaving, and soft walls turn it back 36 pt from the edges. Speeds stay between 55 and 120 pt/s, every bird points along its velocity, and wings flap at about 14 rad/s with each bird out of phase; distant birds are smaller and paler. Touching the sky acts as a hawk: birds within 95 pt veer away hard, the flock splits around the finger and re-forms behind it. Organic, emergent, hypnotic.",
            "黄昏的天空自靛蓝经淡紫过渡到琥珀色，下方是深色山丘与一团落日余晖。90 只小鸟的剪影组成椋鸟群，由三条局部规则驱动：向 46pt 内邻居的平均航向对齐，朝它们的中心靠拢，并躲开 18pt 以内的同伴。一个缓慢游走的栖息点让鸟群以舒展的 8 字盘旋，距边缘 36pt 的柔性边界会把它们推回。速度保持在 55 到 120pt/s，鸟身始终沿速度方向，翅膀以约 14 rad/s 错相扇动；远处的鸟更小更淡。触摸天空就像一只鹰：95pt 内的鸟急速避让，鸟群绕开手指分成两股，再在后方合拢。自然、涌现、令人出神。"
        ),
        implementation: L(
            "A reference model integrates the classic boids rules (alignment, cohesion, separation) plus a roost attractor, soft walls and a predator force with an O(n²) neighbour pass; a Canvas appends one transformed bird Path per boid into three depth buckets.",
            "引用类型模型用 O(n²) 邻居遍历积分经典 boids 规则（对齐、聚合、分离），外加栖息点吸引、柔性边界与天敌斥力；Canvas 把每只鸟的 Path 经变换后合并进三个景深分组。"
        ),
        apis: ["Canvas", "Path.addPath(_:transform:)", "CGAffineTransform", "TimelineView(.animation)", "DragGesture"],
        tags: ["boids", "flock", "birds", "swarm", "鸟群", "集群", "群飞", "涌现"],
        params: [
            .slider("count", L("Birds", "鸟的数量"), 30...160, default: 90, step: 5, decimals: 0),
            .slider("cohesion", L("Cohesion", "聚合"), 0...2.5, default: 1.0, unit: "×"),
            .slider("separation", L("Separation", "分离"), 0.2...2.5, default: 1.0, unit: "×"),
            .slider("speed", L("Speed", "速度"), 0.4...2.0, default: 1.0, unit: "×"),
        ]
    ) { ctx in
        BoidsDemo(ctx: ctx)
    }
}

private struct BoidSettings {
    let count: Int
    let cohesion: CGFloat
    let separation: CGFloat
    let speed: CGFloat
}

private final class FlockModel {
    private var last: Double?
    private var size: CGSize = .zero
    private(set) var position: [CGPoint] = []
    private(set) var velocity: [CGVector] = []
    var touch: CGPoint?
    var userTouched = false
    private(set) var predator: CGPoint?

    private func spawn(_ i: Int) -> (CGPoint, CGVector) {
        // Start as a vortex around the middle so the first frame (and the still) already reads as a flock.
        let angle = BackgroundMath.rand(i, 701) * BackgroundMath.tau
        let rho = (0.12 + 0.88 * BackgroundMath.rand(i, 702).squareRoot()) * Double(min(size.width, size.height)) * 0.3
        let p = CGPoint(x: size.width * 0.5 + CGFloat(rho * cos(angle)), y: size.height * 0.42 + CGFloat(rho * sin(angle) * 0.7))
        let v = CGVector(dx: CGFloat(-sin(angle)) * 85, dy: CGFloat(cos(angle)) * 60)
        return (p, v)
    }

    func step(now: Double, size newSize: CGSize, settings: BoidSettings, simulate: Bool, frozen: Bool) {
        if newSize != size {
            size = newSize
            position = []
            velocity = []
        }
        while position.count < settings.count {
            let (p, v) = spawn(position.count)
            position.append(p)
            velocity.append(v)
        }
        if position.count > settings.count {
            position.removeLast(position.count - settings.count)
            velocity.removeLast(velocity.count - settings.count)
        }
        guard !frozen else { return }
        var dt = 0.0
        if let last = last { dt = min(max(now - last, 0), 1.0 / 30.0) }
        last = now
        let h = CGFloat(dt)
        guard h > 0 else { return }

        if let touch {
            predator = touch
        } else if simulate {
            // A ghost hawk crosses the sky so previews show the flock splitting.
            predator = CGPoint(
                x: size.width * CGFloat(0.5 + 0.42 * sin(now * 0.63)),
                y: size.height * CGFloat(0.42 + 0.3 * sin(now * 0.94 + 1))
            )
        } else {
            predator = nil
        }
        let roost = CGPoint(
            x: size.width * CGFloat(0.5 + 0.27 * sin(now * 0.31)),
            y: size.height * CGFloat(0.42 + 0.2 * sin(now * 0.62))
        )

        let n = position.count
        let perception: CGFloat = 46
        let personal: CGFloat = 18
        let margin: CGFloat = 36
        let floor = size.height * 0.84
        var acceleration = [CGVector](repeating: .zero, count: n)
        for i in 0..<n {
            let p = position[i]
            var heading = CGVector.zero
            var centre = CGPoint.zero
            var neighbours: CGFloat = 0
            var ax: CGFloat = 0
            var ay: CGFloat = 0
            for j in 0..<n where j != i {
                let dx = position[j].x - p.x
                let dy = position[j].y - p.y
                guard abs(dx) < perception, abs(dy) < perception else { continue }
                let d = max((dx * dx + dy * dy).squareRoot(), 0.01)
                guard d < perception else { continue }
                heading.dx += velocity[j].dx
                heading.dy += velocity[j].dy
                centre.x += position[j].x
                centre.y += position[j].y
                neighbours += 1
                if d < personal {
                    let push = (1 - d / personal) * 520 * settings.separation
                    ax -= dx / d * push
                    ay -= dy / d * push
                }
            }
            if neighbours > 0 {
                ax += (heading.dx / neighbours - velocity[i].dx) * 1.3
                ay += (heading.dy / neighbours - velocity[i].dy) * 1.3
                ax += (centre.x / neighbours - p.x) * 1.1 * settings.cohesion
                ay += (centre.y / neighbours - p.y) * 1.1 * settings.cohesion
            }
            ax += (roost.x - p.x) * 0.55
            ay += (roost.y - p.y) * 0.55
            if p.x < margin { ax += (margin - p.x) * 9 }
            if p.x > size.width - margin { ax -= (p.x - (size.width - margin)) * 9 }
            if p.y < margin { ay += (margin - p.y) * 9 }
            if p.y > floor { ay -= (p.y - floor) * 9 }
            if let hawk = predator {
                let dx = p.x - hawk.x
                let dy = p.y - hawk.y
                let d = max((dx * dx + dy * dy).squareRoot(), 0.01)
                if d < 95 {
                    let push = (1 - d / 95) * 1500
                    ax += dx / d * push
                    ay += dy / d * push
                }
            }
            // A little individual restlessness.
            let wander = CGFloat(sin(now * 1.7 + Double(i) * 3.1)) * 26
            let speed = max(hypot(velocity[i].dx, velocity[i].dy), 0.01)
            ax += -velocity[i].dy / speed * wander
            ay += velocity[i].dx / speed * wander
            acceleration[i] = CGVector(dx: ax, dy: ay)
        }
        let slow = 55 * settings.speed
        let fast = 120 * settings.speed
        for i in 0..<n {
            var v = velocity[i]
            v.dx += acceleration[i].dx * h
            v.dy += acceleration[i].dy * h
            let speed = max(hypot(v.dx, v.dy), 0.01)
            let wanted = min(max(speed, slow), fast)
            v.dx *= wanted / speed
            v.dy *= wanted / speed
            velocity[i] = v
            position[i].x += v.dx * h
            position[i].y += v.dy * h
        }
    }
}

private struct BoidsDemo: View {
    let ctx: DemoContext
    @State private var model = FlockModel()

    var body: some View {
        let settings = BoidSettings(
            count: max(ctx.int("count"), 1), cohesion: ctx.cg("cohesion"), separation: ctx.cg("separation"), speed: ctx.cg("speed")
        )
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x1E2456), location: 0),
                    .init(color: Color(hex: 0x5A4486), location: 0.38),
                    .init(color: Color(hex: 0xD9806F), location: 0.68),
                    .init(color: Color(hex: 0xF8C98E), location: 0.86),
                ],
                startPoint: .top, endPoint: .bottom
            )
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    model.step(now: now, size: size, settings: settings, simulate: ctx.isPreview || !model.userTouched, frozen: ctx.isStill)
                    BoidsPainter.draw(&context, size: size, now: now, model: model)
                }
            }
        }
        .backgroundsTouch { location in
            if model.touch == nil { Haptics.tap(.light) }
            model.userTouched = true
            model.touch = location
        } onEnded: {
            model.touch = nil
        }
        .backgroundsHint(L("Tap or swipe sideways to scatter the flock", "点击或横向滑动驱散鸟群"), ctx)
    }
}

private enum BoidsPainter {
    static func draw(_ context: inout GraphicsContext, size: CGSize, now: Double, model: FlockModel) {
        // Low sun glow.
        let sun = CGPoint(x: size.width * 0.68, y: size.height * 0.83)
        let glow = Gradient(colors: [Color(hex: 0xFFE6B0).opacity(0.75), Color(hex: 0xFFB37A).opacity(0)])
        let reach = size.width * 0.6
        context.fill(
            Path(ellipseIn: CGRect(x: sun.x - reach, y: sun.y - reach, width: reach * 2, height: reach * 2)),
            with: .radialGradient(glow, center: sun, startRadius: 0, endRadius: reach)
        )

        // Birds, in three depth buckets (far ones smaller and paler).
        var buckets = [Path](repeating: Path(), count: 3)
        let t = now.truncatingRemainder(dividingBy: 1000)
        for i in model.position.indices {
            let depth = BackgroundMath.rand(i, 711)
            let bucket = min(Int(depth * 3), 2)
            let scale = CGFloat(0.6 + 0.55 * depth)
            let v = model.velocity[i]
            let angle = atan2(v.dy, v.dx)
            let flap = abs(sin(t * 14 * (0.85 + 0.3 * BackgroundMath.rand(i, 712)) + Double(i) * 1.9))
            let span = CGFloat(0.3 + 0.7 * flap)
            let length: CGFloat = 9 * scale
            var bird = Path()
            bird.move(to: CGPoint(x: length * 0.62, y: 0))
            bird.addQuadCurve(to: CGPoint(x: -length * 0.2, y: length * 0.8 * span), control: CGPoint(x: length * 0.2, y: length * 0.22))
            bird.addLine(to: CGPoint(x: -length * 0.08, y: length * 0.1))
            bird.addLine(to: CGPoint(x: -length * 0.55, y: 0))
            bird.addLine(to: CGPoint(x: -length * 0.08, y: -length * 0.1))
            bird.addLine(to: CGPoint(x: -length * 0.2, y: -length * 0.8 * span))
            bird.addQuadCurve(to: CGPoint(x: length * 0.62, y: 0), control: CGPoint(x: length * 0.2, y: -length * 0.22))
            bird.closeSubpath()
            let transform = CGAffineTransform(translationX: model.position[i].x, y: model.position[i].y).rotated(by: angle)
            buckets[bucket].addPath(bird, transform: transform)
        }
        let ink = Color(hex: 0x130E28)
        context.fill(buckets[0], with: .color(ink.opacity(0.42)))
        context.fill(buckets[1], with: .color(ink.opacity(0.68)))
        context.fill(buckets[2], with: .color(ink.opacity(0.92)))

        // Hills.
        var far = Path()
        var near = Path()
        far.move(to: CGPoint(x: 0, y: size.height))
        near.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = 0
        while x <= size.width + 8 {
            let u = Double(x / max(size.width, 1))
            far.addLine(to: CGPoint(x: x, y: size.height * CGFloat(0.87 - 0.035 * sin(u * 5.2 + 0.6) - 0.02 * sin(u * 11 + 2))))
            near.addLine(to: CGPoint(x: x, y: size.height * CGFloat(0.93 - 0.03 * sin(u * 3.4 + 2.2) - 0.012 * sin(u * 17))))
            x += 8
        }
        far.addLine(to: CGPoint(x: size.width, y: size.height))
        near.addLine(to: CGPoint(x: size.width, y: size.height))
        far.closeSubpath()
        near.closeSubpath()
        context.fill(far, with: .color(Color(hex: 0x3A2A52)))
        context.fill(near, with: .color(Color(hex: 0x17112B)))
    }
}
