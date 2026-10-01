import SwiftUI

// MARK: - Fireworks

extension Effect {
    static let feedbackFireworks = Effect(
        id: "feedback.fireworks",
        category: .feedback,
        interaction: .tap,
        name: L("Fireworks", "烟花"),
        summary: L("Tap the night sky: a rocket climbs with a trail and bursts into sparks that sag, cool and twinkle out.", "点击夜空：火箭拖着尾迹升空，炸成下坠、冷却、闪烁着熄灭的火花。"),
        prompt: L(
            "A night-sky card over a dark skyline. Tapping launches a rocket from the bottom edge toward the finger: it climbs for 0.65 s on a quadratic ease-out with a slight sideways wobble, leaving a tapering warm trail. At the apex it bursts into 48 sparks with a white flash that fades in 0.22 s and lights the rooftops in the burst's colour. Sparks leave at up to 230 pt/s, slowed by air drag (2.2 per second) and pulled down by gravity (180 pt/s²), each drawn as a short streak along its own path. They start white-hot, cool to the rocket's hue within 15% of their 1.6 s life, then fade and twinkle through the final 40%. A rigid haptic marks every burst. Peony, ring and willow shells differ only in launch speeds, drag and life. Festive, physical, generous.",
            "深色天际线上方是一片夜空。点击后火箭从底边射向手指位置：以二次缓出爬升 0.65 秒，略带摆动，拖着渐细的暖色尾迹。到顶点炸成 48 颗火花，白色闪光在 0.22 秒内消退，并把屋顶映成这一发的颜色。火花以最高 230 pt/s 射出，受空气阻力（每秒 2.2）减速、被重力（180 pt/s²）下拉，各自沿轨迹画成一小段拖尾；起初白热，在 1.6 秒寿命的前 15% 内冷却为火箭的色相，最后 40% 边淡出边闪烁。每次炸开都有一记硬朗触感。牡丹、环形与垂柳只在初速、阻力和寿命上不同。喜庆、有物理感。"
        ),
        implementation: L(
            "Rockets are value records with a birth time, target and hue; a TimelineView-driven Canvas evaluates every spark in closed form (velocity with linear drag plus gravity), so there is no per-frame simulation state, and draws streaks with additive blending. The timeline pauses when no rocket is alive.",
            "火箭是带出生时间、目标与色相的值记录；由 TimelineView 驱动的 Canvas 以闭式公式（带线性阻力的速度加重力）求出每颗火花的位置，无需逐帧模拟状态，并用加色混合绘制拖尾。没有存活的火箭时时间线暂停。"
        ),
        apis: ["Canvas", "TimelineView(.animation(minimumInterval:paused:))", "GraphicsContext.blendMode", "SpatialTapGesture", "Path"],
        tags: ["fireworks", "celebration", "particles", "burst", "烟花", "庆祝", "粒子", "礼花"],
        params: [
            .slider("sparks", L("Sparks", "火花数"), 20...90, default: 48, step: 2, decimals: 0),
            .slider("gravity", L("Gravity", "重力"), 60...400, default: 180, decimals: 0, unit: "pt/s²"),
            .slider("trail", L("Trail length", "拖尾长度"), 0...1, default: 0.6),
            .choice("shell", L("Shell", "礼花样式"), [L("Peony", "牡丹"), L("Ring", "环形"), L("Willow", "垂柳")], default: 0),
        ]
    ) { ctx in
        FireworksDemo(ctx: ctx)
    }
}

private struct FireworkRocket: Identifiable {
    let id: Int
    let born: Double
    let from: CGPoint
    let to: CGPoint
    let hue: Double
    let seed: Double
}

private struct FireworkShell {
    let speed: Double
    let drag: Double
    let life: Double
    let gravityScale: Double

    static func make(_ index: Int) -> FireworkShell {
        switch index {
        case 1: return FireworkShell(speed: 200, drag: 2.6, life: 1.4, gravityScale: 0.7)
        case 2: return FireworkShell(speed: 175, drag: 1.5, life: 2.3, gravityScale: 1.25)
        default: return FireworkShell(speed: 230, drag: 2.2, life: 1.6, gravityScale: 1)
        }
    }
}

private func fireworkHash(_ value: Double) -> Double {
    let s: Double = sin(value * 12.9898) * 43758.5453
    return s - s.rounded(.down)
}

private struct FireworksDemo: View {
    let ctx: DemoContext
    @State private var rockets: [FireworkRocket]
    @State private var nextID = 0
    @State private var autoIndex = 0

    private static let size = CGSize(width: 300, height: 300)
    private static let rise: Double = 0.65
    /// The fixed clock of still thumbnails.
    private static let stillNow: Double = 100

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show three bursts at different ages.
        let seeded: [FireworkRocket] = ctx.isStill
            ? [
                FireworkRocket(id: -1, born: Self.stillNow - 1.2, from: CGPoint(x: 130, y: 300), to: CGPoint(x: 96, y: 92), hue: 0.93, seed: 1.7),
                FireworkRocket(id: -2, born: Self.stillNow - 0.95, from: CGPoint(x: 170, y: 300), to: CGPoint(x: 214, y: 124), hue: 0.12, seed: 4.2),
                FireworkRocket(id: -3, born: Self.stillNow - 0.4, from: CGPoint(x: 150, y: 300), to: CGPoint(x: 160, y: 60), hue: 0.55, seed: 8.9),
            ]
            : []
        _rockets = State(initialValue: seeded)
    }

    private static let autoTargets: [CGPoint] = [
        CGPoint(x: 92, y: 96), CGPoint(x: 214, y: 78), CGPoint(x: 150, y: 132), CGPoint(x: 70, y: 150),
        CGPoint(x: 232, y: 146), CGPoint(x: 132, y: 64), CGPoint(x: 188, y: 110),
    ]
    private static let hues: [Double] = [0.93, 0.12, 0.55, 0.78, 0.04, 0.42, 0.62]

    var body: some View {
        VStack(spacing: 14) {
            sky
                .frame(width: Self.size.width, height: Self.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
                .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        launch(to: value.location)
                    }
                )
            DemoHint(text: L("Tap anywhere in the sky", "点击夜空任意位置"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.85, delay: 0.3) { autoLaunch() }
    }

    private var sky: some View {
        let shell = FireworkShell.make(ctx.int("shell"))
        let painter = FireworkPainter(
            shell: shell,
            sparks: max(ctx.int("sparks"), 4),
            gravity: ctx["gravity"] * shell.gravityScale,
            trail: ctx["trail"],
            ring: ctx.int("shell") == 1,
            willow: ctx.int("shell") == 2,
            rise: Self.rise
        )
        let still: Bool = ctx.isStill
        return TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: rockets.isEmpty || still)) { timeline in
            let now: Double = still ? Self.stillNow : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                painter.draw(rockets, now: now, in: &context, size: size)
            }
        }
        .background(
            LinearGradient(colors: [Color(hex: 0x05061A), Color(hex: 0x141238), Color(hex: 0x2A1B4A)], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: Launching

    private func autoLaunch() {
        // On the detail page this runs once (the arrival play): a single rocket to the middle of the sky.
        let target: CGPoint = Self.autoTargets[autoIndex % Self.autoTargets.count]
        autoIndex += 1
        launch(to: target)
    }

    private func launch(to point: CGPoint) {
        let shell = FireworkShell.make(ctx.int("shell"))
        let now: Double = Date().timeIntervalSinceReferenceDate
        let lifetime: Double = Self.rise + shell.life
        rockets.removeAll { now - $0.born > lifetime }
        let target = CGPoint(x: point.x.clamped(to: 30...270), y: point.y.clamped(to: 40...210))
        let seed: Double = Double(nextID) * 3.17 + 0.61
        let start = CGPoint(x: 150 + (target.x - 150) * 0.35 + CGFloat(fireworkHash(seed) - 0.5) * 30, y: Self.size.height + 4)
        rockets.append(
            FireworkRocket(id: nextID, born: now, from: start, to: target, hue: Self.hues[nextID % Self.hues.count], seed: seed)
        )
        nextID += 1
        // Captured now: false inside the silent intro/autoplay, so the burst's haptic stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        if buzz { Haptics.tap(.light) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.rise))
            if buzz { Haptics.tap(.rigid) }
            // Prune after the last spark has died so the timeline pauses instead of ticking forever.
            try? await Task.sleep(for: .seconds(shell.life + 0.1))
            let later: Double = Date().timeIntervalSinceReferenceDate
            rockets.removeAll { later - $0.born > lifetime }
        }
    }
}

// MARK: - Drawing

private struct FireworkPainter {
    let shell: FireworkShell
    let sparks: Int
    let gravity: Double
    let trail: Double
    let ring: Bool
    let willow: Bool
    let rise: Double

    func draw(_ rockets: [FireworkRocket], now: Double, in context: inout GraphicsContext, size: CGSize) {
        drawStars(in: &context, size: size, now: now)
        var glow = context
        glow.blendMode = .plusLighter
        for rocket in rockets {
            let age: Double = now - rocket.born
            if age < 0 { continue }
            if age < rise {
                drawRocket(rocket, age: age, in: &glow)
            } else if age - rise < shell.life {
                drawBurst(rocket, t: age - rise, in: &glow)
            }
        }
        drawSkyline(rockets, now: now, in: &context, size: size)
    }

    // MARK: Sky

    private func drawStars(in context: inout GraphicsContext, size: CGSize, now: Double) {
        for index in 0..<26 {
            let i = Double(index)
            let x: CGFloat = CGFloat(fireworkHash(i * 1.37 + 0.2)) * size.width
            let y: CGFloat = CGFloat(fireworkHash(i * 2.91 + 5.1)) * size.height * 0.7
            let twinkle: Double = 0.25 + 0.2 * sin(now * (0.8 + fireworkHash(i) * 1.4) + i)
            let r: CGFloat = index % 5 == 0 ? 1.1 : 0.7
            context.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(twinkle))
            )
        }
    }

    private func skyline(size: CGSize) -> Path {
        let heights: [CGFloat] = [26, 40, 30, 54, 36, 22, 46, 62, 34, 28, 48, 38, 24, 42]
        let width: CGFloat = size.width / CGFloat(heights.count)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for (index, height) in heights.enumerated() {
            let x: CGFloat = CGFloat(index) * width
            path.addLine(to: CGPoint(x: x, y: size.height - height))
            path.addLine(to: CGPoint(x: x + width, y: size.height - height))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }

    /// The rooftops, lit from above by every burst that is still bright.
    private func drawSkyline(_ rockets: [FireworkRocket], now: Double, in context: inout GraphicsContext, size: CGSize) {
        let path: Path = skyline(size: size)
        context.fill(path, with: .color(Color(hex: 0x07071A)))
        var lit = context
        lit.clip(to: path)
        lit.blendMode = .plusLighter
        for rocket in rockets {
            let t: Double = now - rocket.born - rise
            guard t >= 0, t < shell.life else { continue }
            let strength: Double = pow(1 - t / shell.life, 2) * 0.55
            let center = CGPoint(x: rocket.to.x, y: size.height - 64)
            let colour = Color(hue: rocket.hue, saturation: 0.7, brightness: 1)
            lit.fill(
                Path(ellipseIn: CGRect(x: center.x - 130, y: center.y - 20, width: 260, height: 90)),
                with: .radialGradient(
                    Gradient(colors: [colour.opacity(strength), colour.opacity(0)]),
                    center: center,
                    startRadius: 0,
                    endRadius: 120
                )
            )
        }
    }

    // MARK: Rocket

    private func rocketPoint(_ rocket: FireworkRocket, u: Double) -> CGPoint {
        let eased: Double = 1 - (1 - u) * (1 - u)
        let wobble: Double = sin(u * 9 + rocket.seed) * 3 * (1 - u)
        return CGPoint(
            x: rocket.from.x + (rocket.to.x - rocket.from.x) * CGFloat(eased) + CGFloat(wobble),
            y: rocket.from.y + (rocket.to.y - rocket.from.y) * CGFloat(eased)
        )
    }

    private func drawRocket(_ rocket: FireworkRocket, age: Double, in context: inout GraphicsContext) {
        let u: Double = age / rise
        let steps = 12
        for step in 0..<steps {
            let back: Double = Double(step) / Double(steps)
            let pastU: Double = u - back * 0.22
            guard pastU > 0 else { continue }
            let point: CGPoint = rocketPoint(rocket, u: pastU)
            let fade: Double = (1 - back) * (1 - back)
            let r: CGFloat = CGFloat(2.2 * (1 - back) + 0.5)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                with: .color(Color(hue: 0.1, saturation: 0.55 * back, brightness: 1).opacity(fade * 0.9))
            )
        }
    }

    // MARK: Burst

    private func sparkOffset(angle: Double, speed: Double, t: Double) -> CGPoint {
        let k: Double = shell.drag
        let decay: Double = (1 - exp(-k * t)) / k
        let x: Double = cos(angle) * speed * decay
        let y: Double = sin(angle) * speed * decay + gravity * (t / k - decay / k)
        return CGPoint(x: x, y: y)
    }

    private func drawBurst(_ rocket: FireworkRocket, t: Double, in context: inout GraphicsContext) {
        let life: Double = shell.life
        let f: Double = t / life
        let origin: CGPoint = rocket.to

        // The flash at the moment of the burst.
        if t < 0.22 {
            let flash: Double = 1 - t / 0.22
            let radius: CGFloat = 46 + 50 * CGFloat(t / 0.22)
            let colour = Color(hue: rocket.hue, saturation: 0.35, brightness: 1)
            context.fill(
                Path(ellipseIn: CGRect(x: origin.x - radius, y: origin.y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.75 * flash), colour.opacity(0.3 * flash), colour.opacity(0)]),
                    center: origin,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }

        let lag: Double = 0.02 + 0.12 * trail
        for index in 0..<sparks {
            let i: Double = Double(index) + rocket.seed * 10
            let angle: Double
            let speed: Double
            if ring {
                angle = Double(index) / Double(sparks) * 2 * .pi + rocket.seed
                speed = shell.speed * (index % 2 == 0 ? 1 : 0.52)
            } else {
                angle = fireworkHash(i * 1.13) * 2 * .pi
                speed = shell.speed * (0.3 + 0.7 * sqrt(fireworkHash(i * 2.71 + 1.3)))
            }
            let head: CGPoint = sparkOffset(angle: angle, speed: speed, t: t)
            let tail: CGPoint = sparkOffset(angle: angle, speed: speed, t: max(t - lag, 0))

            // White-hot for the first 15% of life, then the shell's colour; twinkle through the last 40%.
            let heat: Double = max(1 - f / 0.15, 0)
            let hueShift: Double = willow ? 0 : (index % 3 == 0 ? 0.07 : 0)
            let hue: Double = willow ? 0.11 : (rocket.hue + hueShift).truncatingRemainder(dividingBy: 1)
            let colour = Color(hue: hue, saturation: (willow ? 0.6 : 0.8) * (1 - heat), brightness: 1)
            var alpha: Double = 1 - f
            if f > 0.6 {
                alpha *= 0.55 + 0.45 * sin(t * 38 + i * 2.3)
            }
            guard alpha > 0.01 else { continue }

            var streak = Path()
            streak.move(to: CGPoint(x: origin.x + tail.x, y: origin.y + tail.y))
            streak.addLine(to: CGPoint(x: origin.x + head.x, y: origin.y + head.y))
            let width: CGFloat = CGFloat(2.4 - 1.2 * f)
            context.stroke(streak, with: .color(colour.opacity(alpha * 0.8)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            let r: CGFloat = width * 0.75
            // A soft halo around the head.
            let halo: CGFloat = r * 3.2
            context.fill(
                Path(ellipseIn: CGRect(x: origin.x + head.x - halo, y: origin.y + head.y - halo, width: halo * 2, height: halo * 2)),
                with: .color(colour.opacity(alpha * 0.14))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: origin.x + head.x - r, y: origin.y + head.y - r, width: r * 2, height: r * 2)),
                with: .color(colour.opacity(alpha))
            )
        }
    }
}
