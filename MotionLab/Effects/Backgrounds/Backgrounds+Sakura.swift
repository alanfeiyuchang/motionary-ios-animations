import SwiftUI

extension Effect {
    static let backgroundsSakura = Effect(
        id: "backgrounds.sakura",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Sakura Drift", "樱吹雪"),
        summary: L(
            "Cherry petals shed from a blossoming branch, tumble in three dimensions on passing gusts and spiral around your finger.",
            "花瓣从盛开的枝头飘落，乘着一阵阵风做三维翻转，并绕着你的手指打旋。"
        ),
        prompt: L(
            "A pale spring sky, blue fading to blush, with a dark blossoming branch reaching in from the top right and swaying a degree or two. 80 notched petals fall in three depths: far ones small and softly blurred, near ones large and out of focus. Each petal is a simulated body that chases the local wind with a 1.8/s lag: a steady breeze, slow turbulence from a noise field, and a gust front that sweeps right to left every few seconds, tripling the wind as it passes and lifting the petals, so they surge in a visible wave. Petals spin in-plane and flip about their long axis faster the quicker they move; the flip squashes their width through zero and shows a deeper pink underside. The finger is a small whirlwind: petals within about 70 pt orbit it at up to 160 pt/s and drift inward. Gentle, fleeting, poetic.",
            "春日天空由蓝渐变为绯粉，一根开满花的深色枝条从右上角探入，轻摆一两度。80 片带缺口的花瓣分三层景深飘落：远处的小而略模糊，近处的大而虚焦。每片花瓣是被模拟的物体，以 1.8/s 的滞后追随当地的风：稳定的微风、噪声场带来的缓慢湍流，以及每隔几秒自右向左扫过的阵风锋面，经过时风力增至三倍并把花瓣托起，花瓣成片涌动。花瓣在平面内旋转，同时绕长轴翻转，越快翻得越快；翻转时宽度被压过零点，露出更深的粉色背面。手指是一小股旋风：约 70pt 内的花瓣以最高每秒 160pt 绕它旋转并被轻轻吸入。"
        ),
        implementation: L(
            "Petal state (position, velocity, spin, flip) lives in a reference model stepped once per frame; a Canvas appends one petal Path per body with addPath(_:transform:), where the transform's x-scale is cos(flip), into colour and depth bins, and draws the far and near bins inside blurred layers.",
            "花瓣状态（位置、速度、旋转、翻转）保存在引用类型模型中，每帧步进一次；Canvas 用 addPath(_:transform:) 为每片花瓣追加一条花瓣 Path（变换的 x 向缩放为 cos(翻转角)），按颜色与景深分组，并在模糊图层中绘制远景与近景两组。"
        ),
        apis: ["Canvas", "Path.addPath(_:transform:)", "CGAffineTransform", "GraphicsContext.drawLayer", "TimelineView(.animation)", "DragGesture"],
        tags: ["sakura", "cherry blossom", "petals", "spring", "樱花", "花瓣", "春天", "樱吹雪"],
        params: [
            .slider("count", L("Petals", "花瓣数量"), 30...160, default: 80, step: 5, decimals: 0),
            .slider("wind", L("Wind", "风力"), 0...2.5, default: 1.0, unit: "×"),
            .slider("tumble", L("Tumble", "翻转"), 0.2...3.0, default: 1.0, unit: "×"),
            .toggle("branch", L("Blossom branch", "花枝"), default: true),
        ]
    ) { ctx in
        SakuraDemo(ctx: ctx)
    }
}

private struct SakuraPetal {
    var position: CGPoint
    var velocity: CGVector
    var angle: Double
    var flip: Double
    let depth: Double
    let size: CGFloat
    let spin: Double
    let flipRate: Double
    let shade: Int
}

private final class SakuraModel {
    let clock = BackgroundClock()
    let pointer = BackgroundPointer()
    private(set) var petals: [SakuraPetal] = []
    private var rng = BackgroundRNG(seed: 71)
    private var size: CGSize = .zero

    /// Strength of the gust front at x (0...1); it sweeps right to left, away from the branch.
    static func gust(x: Double, t: Double) -> Double {
        pow(max(0, sin(x * 0.008 + t * 1.3 + 2 * sin(t * 0.37))), 3)
    }

    func step(now: Double, size newSize: CGSize, count: Int, wind: Double, tumble: Double, finger: CGPoint, swirl: Double, frozen: Bool) -> Double {
        let t = clock.advance(to: now, speed: 1)
        if newSize != size || petals.count != count {
            size = newSize
            rng = BackgroundRNG(seed: 71)
            petals = (0..<count).map { _ in
                make(at: CGPoint(x: size.width * CGFloat(rng.range(-0.1...1.1)), y: size.height * CGFloat(rng.range(-0.05...1.05))))
            }
        }
        guard !frozen else { return t }
        let dt = clock.delta
        guard dt > 0 else { return t }
        for i in petals.indices {
            var p = petals[i]
            let x = Double(p.position.x)
            let y = Double(p.position.y)
            let near = 0.6 + p.depth
            let g = SakuraModel.gust(x: x, t: t)
            let noise = BackgroundMath.valueNoise(x * 0.01 + t * 0.12, y * 0.01 - t * 0.2) * BackgroundMath.tau * 2
            var ux = -(38 + 76 * g) * wind * near + cos(noise) * 18 + 22 * sin(p.flip)
            var uy = (26 + 30 * p.depth) * (1 - 0.4 * abs(cos(p.flip))) - 16 * g * wind + sin(noise) * 18
            // The finger is a small whirlwind.
            if swirl > 0.01 {
                let dx = x - Double(finger.x)
                let dy = y - Double(finger.y)
                let d = max((dx * dx + dy * dy).squareRoot(), 1)
                let spin = 160 * swirl * exp(-d / 70)
                let pull = 34 * swirl * exp(-d / 90)
                ux += -dy / d * spin - dx / d * pull
                uy += dx / d * spin - dy / d * pull
            }
            let rate = min(1.8 * dt, 1)
            p.velocity.dx += (CGFloat(ux) - p.velocity.dx) * CGFloat(rate)
            p.velocity.dy += (CGFloat(uy) - p.velocity.dy) * CGFloat(rate)
            p.position.x += p.velocity.dx * CGFloat(dt)
            p.position.y += p.velocity.dy * CGFloat(dt)
            let speed = Double(hypot(p.velocity.dx, p.velocity.dy))
            p.angle += p.spin * dt * (0.5 + speed / 80)
            p.flip += p.flipRate * tumble * dt * (0.5 + speed / 70)

            if p.position.y > size.height + 24 {
                if rng.unit() < 0.35 {
                    // Shed from the blossoming branch.
                    p = make(at: CGPoint(x: size.width * CGFloat(rng.range(0.42...1.0)), y: size.height * CGFloat(rng.range(0.06...0.24))))
                } else {
                    p = make(at: CGPoint(x: size.width * CGFloat(rng.range(0.0...1.35)), y: -20))
                }
            } else if p.position.x < -30 {
                p = make(at: CGPoint(x: size.width + 24, y: size.height * CGFloat(rng.range(-0.1...0.8))))
            } else if p.position.x > size.width + 40 {
                p.position.x = size.width + 40
            } else if p.position.y < -60 {
                p.position.y = -20
            }
            petals[i] = p
        }
        return t
    }

    private func make(at point: CGPoint) -> SakuraPetal {
        let depth = rng.unit()
        return SakuraPetal(
            position: point,
            velocity: CGVector(dx: -30, dy: 30),
            angle: rng.range(0...6.28),
            flip: rng.range(0...6.28),
            depth: depth,
            size: CGFloat(6 + 8 * depth * depth + rng.range(0...2.5)),
            spin: rng.range(-1.6...1.6),
            flipRate: rng.range(1.2...3.2),
            shade: Int(rng.range(0...2.99))
        )
    }
}

private struct SakuraDemo: View {
    let ctx: DemoContext
    @State private var model = SakuraModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x9CC6EE), Color(hex: 0xD6E6F8), Color(hex: 0xFBDDE8)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let phase = model.clock.phase
                    let idle = CGPoint(
                        x: size.width * CGFloat(0.5 + 0.3 * sin(phase * 0.4)),
                        y: size.height * CGFloat(0.55 + 0.22 * sin(phase * 0.63 + 1))
                    )
                    let finger = model.pointer.step(now: now, idle: idle, stiffness: 60, damping: 0.8, frozen: ctx.isStill)
                    let t = model.step(
                        now: now, size: size, count: max(ctx.int("count"), 1), wind: ctx["wind"], tumble: ctx["tumble"],
                        finger: finger, swirl: model.pointer.strength(idle: 0.4), frozen: ctx.isStill
                    )
                    SakuraPainter.draw(&context, size: size, t: t, petals: model.petals, wind: ctx["wind"], branch: ctx.bool("branch"))
                }
            }
        }
        .backgroundsTouch { location in
            if !model.pointer.userTouched { Haptics.tap(.soft) }
            model.pointer.userTouched = true
            model.pointer.touch = location
        } onEnded: {
            model.pointer.touch = nil
        }
        .backgroundsLightChipHint(L("Swipe sideways to stir a whirlwind", "横向滑动搅起一阵旋风"), ctx)
    }
}

private enum SakuraPainter {
    static let fronts: [UInt32] = [0xFFE3EC, 0xFFD0DF, 0xFFC2D6]
    static let backs: [UInt32] = [0xFFB5CC, 0xF99FBD, 0xF48FB1]

    /// A notched petal pointing up, about 1 unit tall.
    static let petal: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.55))
        p.addCurve(to: CGPoint(x: 0.22, y: -0.55), control1: CGPoint(x: 0.62, y: 0.25), control2: CGPoint(x: 0.58, y: -0.4))
        p.addLine(to: CGPoint(x: 0, y: -0.36))
        p.addLine(to: CGPoint(x: -0.22, y: -0.55))
        p.addCurve(to: CGPoint(x: 0, y: 0.55), control1: CGPoint(x: -0.58, y: -0.4), control2: CGPoint(x: -0.62, y: 0.25))
        p.closeSubpath()
        return p
    }()

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, petals: [SakuraPetal], wind: Double, branch: Bool) {
        // Hazy sun and distant blossom.
        context.backgroundsGlow(at: CGPoint(x: size.width * 0.16, y: size.height * 0.1), radius: size.width * 0.6, color: .white.opacity(0.55))
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 28))
            for i in 0..<7 {
                let r = size.width * (0.1 + 0.12 * BackgroundMath.unit(i, 2801))
                let x = size.width * (0.45 + 0.6 * BackgroundMath.unit(i, 2802))
                let y = size.height * (0.02 + 0.22 * BackgroundMath.unit(i, 2803))
                layer.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xFFB8D0).opacity(0.24)))
            }
        }

        // Bins: 3 depth groups × front/back × 3 shades.
        var bins = [Path](repeating: Path(), count: 18)
        for p in petals {
            let group = p.depth < 0.3 ? 0 : (p.depth < 0.86 ? 1 : 2)
            let c = cos(p.flip)
            let width = max(abs(c), 0.14)
            let scale = p.size * (group == 2 ? 1.5 : 1)
            let transform = CGAffineTransform(translationX: p.position.x, y: p.position.y)
                .rotated(by: CGFloat(p.angle))
                .scaledBy(x: scale * CGFloat(width), y: scale)
            bins[group * 6 + (c >= 0 ? 0 : 3) + p.shade].addPath(petal, transform: transform)
        }
        func fill(_ layer: inout GraphicsContext, group: Int, opacity: Double) {
            for shade in 0..<3 {
                layer.fill(bins[group * 6 + shade], with: .color(Color(hex: fronts[shade]).opacity(opacity)))
                layer.fill(bins[group * 6 + 3 + shade], with: .color(Color(hex: backs[shade]).opacity(opacity)))
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.4))
            fill(&layer, group: 0, opacity: 0.8)
        }
        if branch {
            drawBranch(&context, size: size, t: t, wind: wind)
        }
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color(hex: 0xB04A78).opacity(0.25), radius: 2, x: 0, y: 1.5))
            fill(&layer, group: 1, opacity: 0.96)
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 3.5))
            fill(&layer, group: 2, opacity: 0.85)
        }
    }

    private static func drawBranch(_ context: inout GraphicsContext, size: CGSize, t: Double, wind: Double) {
        let root = CGPoint(x: size.width + 14, y: size.height * 0.07)
        let gust = SakuraModel.gust(x: Double(size.width) * 0.8, t: t)
        let sway = (1.1 * sin(t * 0.8) + 2.2 * gust * wind) * .pi / 180
        var ctx = context
        ctx.translateBy(x: root.x, y: root.y)
        ctx.rotate(by: .radians(sway))
        ctx.translateBy(x: -root.x, y: -root.y)

        let w = size.width
        let h = size.height
        let tip = CGPoint(x: w * 0.4, y: h * 0.2)
        let c1 = CGPoint(x: w * 0.82, y: h * 0.16)
        let c2 = CGPoint(x: w * 0.6, y: h * 0.1)
        var limb = Path()
        limb.move(to: root)
        limb.addCurve(to: tip, control1: c1, control2: c2)
        let wood = Color(hex: 0x4A2E2C)
        ctx.stroke(limb, with: .color(wood), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        func onLimb(_ u: CGFloat) -> CGPoint {
            let m = 1 - u
            return CGPoint(
                x: m * m * m * root.x + 3 * m * m * u * c1.x + 3 * m * u * u * c2.x + u * u * u * tip.x,
                y: m * m * m * root.y + 3 * m * m * u * c1.y + 3 * m * u * u * c2.y + u * u * u * tip.y
            )
        }
        // Twigs.
        var twigs = Path()
        let twigEnds: [(CGFloat, CGFloat, CGFloat)] = [(0.3, -0.02, 0.13), (0.52, 0.02, 0.12), (0.72, -0.05, 0.1), (0.86, 0.03, 0.09)]
        var blossomPoints: [CGPoint] = []
        for (k, twig) in twigEnds.enumerated() {
            let start = onLimb(twig.0)
            let end = CGPoint(x: start.x - w * 0.1 + w * twig.1, y: start.y + h * twig.2 * (k % 2 == 0 ? 1 : -0.45))
            twigs.move(to: start)
            twigs.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2 + 8, y: (start.y + end.y) / 2 - 4))
            blossomPoints.append(end)
            blossomPoints.append(CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2))
        }
        ctx.stroke(twigs, with: .color(wood), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        for i in 0..<11 {
            let p = onLimb(0.12 + 0.86 * CGFloat(i) / 10)
            blossomPoints.append(CGPoint(
                x: p.x + (BackgroundMath.unit(i, 2811) - 0.5) * 16, y: p.y + (BackgroundMath.unit(i, 2812) - 0.5) * 16
            ))
        }

        // Five-petal blossoms.
        var petals = Path()
        var hearts = Path()
        for (i, p) in blossomPoints.enumerated() {
            let r = 6 + 4 * BackgroundMath.unit(i, 2813)
            let turn = Double(BackgroundMath.unit(i, 2814)) * BackgroundMath.tau + sin(t * 1.1 + Double(i)) * 0.12
            for k in 0..<5 {
                let angle = turn + Double(k) * BackgroundMath.tau / 5
                let transform = CGAffineTransform(translationX: p.x + CGFloat(cos(angle)) * r * 0.55, y: p.y + CGFloat(sin(angle)) * r * 0.55)
                    .rotated(by: CGFloat(angle) + .pi / 2)
                    .scaledBy(x: r * 1.05, y: r * 1.2)
                petals.addPath(petal, transform: transform)
            }
            hearts.addEllipse(in: CGRect(x: p.x - r * 0.24, y: p.y - r * 0.24, width: r * 0.48, height: r * 0.48))
        }
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color(hex: 0xB04A78).opacity(0.3), radius: 2.5, x: 0, y: 1.5))
            layer.fill(petals, with: .color(Color(hex: 0xFFDDE8)))
        }
        ctx.fill(hearts, with: .color(Color(hex: 0xE8648F)))
    }
}
