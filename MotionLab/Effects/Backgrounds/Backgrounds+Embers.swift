import SwiftUI

extension Effect {
    static let backgroundsEmbers = Effect(
        id: "backgrounds.embers",
        category: .backgrounds,
        interaction: .tap,
        name: L("Rising Embers", "升腾余烬"),
        summary: L(
            "Sparks lift off an unseen fire, weave on the hot air and cool from white-gold to deep red; tap to stir up a burst.",
            "火星从看不见的火堆升起，在热气流中摇曳，由白金色冷却为暗红；点击可拨起一簇火花。"
        ),
        prompt: L(
            "A charcoal-black night above an unseen fire: a wide orange glow breathes along the bottom edge and soft smoke drifts up. 120 embers rise from below on buoyant paths that start fast and ease, each weaving sideways on two layered sines (22 pt and 10 pt) that widen with height, leaning with a light draught. Every ember is a short streak along its own velocity; it flickers at 9–16 Hz, shrinks, and cools as it climbs, from white-gold through orange to deep red before fading out. A few large, blurred embers pass close to the lens for depth. Tapping stirs the fire: 26 sparks burst upward from the finger in a ±63° fan at 120–380 pt/s, slow under drag 2.2/s, curl upward on the heat and die within 1.1–2 s, with a flare of light and a medium haptic. Warm, hypnotic, primal.",
            "炭黑的夜色，下方是看不见的火堆：橙色辉光沿底边呼吸，淡烟上飘。120 粒余烬自下方升起，上浮先快后缓，各自按两层正弦（22pt 与 10pt）左右摇曳，越高摆幅越大。每粒余烬是一小段沿速度方向的拖影，以 9–16Hz 闪烁，边升边缩小、冷却，从白金经橙色变为暗红后消散；几粒虚化的大余烬从镜头近处掠过。点击拨动火堆：26 粒火花从手指处以 ±63° 扇形、每秒 120–380pt 向上迸发，在 2.2/s 的阻力下减速，被热气托着上卷，1.1–2 秒内熄灭，同时亮起一团火光，伴随中等触感。温暖、催眠。"
        ),
        implementation: L(
            "Every ember is analytic in its index and the clock (position, flicker and temperature), evaluated at t and t − 0.05 s to draw a velocity streak; streaks are batched into ten Paths by temperature and size and re-drawn in a blurred plusLighter layer for the bloom. Tap bursts use closed-form drag: p = p₀ + v·(1 − e^(−k·a))/k.",
            "每粒余烬的位置、闪烁与温度都是其序号和时钟的解析函数；在 t 与 t − 0.05 秒各求一次位置以画出速度拖影，再按温度与粗细合并为十条 Path，并在模糊的 plusLighter 图层中重绘一次形成辉光。点击迸发的火花用阻力的闭式解：p = p₀ + v·(1 − e^(−k·a))/k。"
        ),
        apis: ["Canvas", "GraphicsContext.drawLayer", "GraphicsContext.addFilter(.blur)", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "Haptics"],
        tags: ["embers", "sparks", "fire", "campfire", "余烬", "火星", "火花", "篝火"],
        params: [
            .slider("count", L("Embers", "余烬数量"), 40...220, default: 120, step: 10, decimals: 0),
            .slider("speed", L("Rise speed", "上升速度"), 0.3...2.5, default: 1.0, unit: "×"),
            .slider("turbulence", L("Turbulence", "扰动"), 0...2, default: 1.0, unit: "×"),
            .slider("glow", L("Fire glow", "火光"), 0...1, default: 0.7),
        ]
    ) { ctx in
        EmbersDemo(ctx: ctx)
    }
}

private struct EmberBurst {
    let origin: CGPoint
    let born: Double
    let seed: Int
}

private final class EmbersModel {
    let clock = BackgroundClock()
    private(set) var bursts: [EmberBurst] = []
    private var counter = 0
    private var seededStill = false

    func step(now: Double, size: CGSize, speed: Double, frozen: Bool) -> Double {
        let t = clock.advance(to: now, speed: speed)
        if frozen {
            if !seededStill {
                seededStill = true
                bursts = [EmberBurst(origin: CGPoint(x: size.width * 0.58, y: size.height * 0.72), born: t - 0.3, seed: 3)]
            }
            return t
        }
        bursts.removeAll { t - $0.born > 2.4 }
        return t
    }

    func stir(at location: CGPoint) {
        counter += 1
        bursts.append(EmberBurst(origin: location, born: clock.phase, seed: counter))
        if bursts.count > 6 { bursts.removeFirst(bursts.count - 6) }
    }
}

private struct EmbersDemo: View {
    let ctx: DemoContext
    @State private var model = EmbersModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x060405), Color(hex: 0x120907), Color(hex: 0x2A0F08)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.step(now: now, size: size, speed: ctx["speed"], frozen: ctx.isStill)
                    EmbersPainter.draw(
                        &context, size: size, t: t, bursts: model.bursts, count: ctx.int("count"),
                        turbulence: ctx["turbulence"], glow: ctx["glow"]
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.medium)
            model.stir(at: location)
        }
        .autoplay(ctx.isPreview, every: 3.2, delay: 0.8) {
            model.stir(at: CGPoint(x: size.width * CGFloat.random(in: 0.25...0.75), y: size.height * CGFloat.random(in: 0.6...0.85)))
        }
        .backgroundsHint(L("Tap to stir up sparks", "点击拨起火花"), ctx)
    }
}

private enum EmbersPainter {
    // Cold → hot.
    static let heat: [BackgroundRGB] = [
        .init(hex: 0x7A1A0A), .init(hex: 0xE8451E), .init(hex: 0xFF8A2A), .init(hex: 0xFFD27A), .init(hex: 0xFFF6DC),
    ]
    static let levels = 5

    /// Position and rise progress (0 at the fire, 1 at the top) of ember `i` at time `t`.
    static func ember(_ i: Int, t: Double, size: CGSize, turbulence: Double, salt: Int) -> (CGPoint, Double, Int) {
        let life = 4 + 5 * BackgroundMath.rand(i, salt)
        let cycle = BackgroundMath.rand(i, salt + 1) + t / life
        let p = BackgroundMath.fract(cycle)
        let seed = i * 31 + Int(cycle.rounded(.down)) * 7
        let x0 = Double(size.width) * (BackgroundMath.rand(seed, salt + 2) * 1.2 - 0.1)
        let weave = 22 * sin(t * 0.9 + BackgroundMath.rand(seed, salt + 3) * 6.28 + p * 4)
            + 10 * sin(t * 2.3 + BackgroundMath.rand(seed, salt + 4) * 6.28)
        let x = x0 + turbulence * weave * (0.3 + p) + 18 * p
        let y = Double(size.height) + 12 - Double(size.height) * 1.15 * pow(p, 0.85)
        return (CGPoint(x: x, y: y), p, seed)
    }

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, bursts: [EmberBurst], count: Int, turbulence: Double, glow: Double
    ) {
        // Fire glow breathing along the bottom edge, flaring with every burst.
        var flare = 0.0
        for burst in bursts { flare = max(flare, exp(-max(t - burst.born, 0) * 4)) }
        let breath = 0.82 + 0.1 * sin(t * 2.7) + 0.08 * sin(t * 6.1 + 1.3)
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            let base = CGPoint(x: size.width / 2, y: size.height + 24)
            layer.backgroundsGlow(at: base, radius: size.width * 0.95, color: Color(hex: 0xFF5A1F).opacity(glow * (0.5 * breath + 0.25 * flare)), squash: 0.62)
            layer.backgroundsGlow(at: base, radius: size.width * 0.5, color: Color(hex: 0xFFB04A).opacity(glow * 0.5 * breath), squash: 0.5)
        }

        // Smoke.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 26))
            for i in 0..<5 {
                let p = BackgroundMath.fract(BackgroundMath.rand(i, 2501) + t * 0.035)
                let w = size.width * (0.35 + 0.3 * BackgroundMath.unit(i, 2502))
                let x = size.width * BackgroundMath.unit(i, 2503) + CGFloat(sin(t * 0.2 + Double(i))) * 20
                let y = size.height * CGFloat(1.05 - p * 1.2)
                layer.fill(
                    Path(ellipseIn: CGRect(x: x - w / 2, y: y - w * 0.3, width: w, height: w * 0.6)),
                    with: .color(Color(hex: 0x5A4038).opacity(0.2 * sin(p * .pi)))
                )
            }
        }

        // Rising embers as velocity streaks, binned by temperature and thickness.
        var bins = [Path](repeating: Path(), count: levels * 2)
        for i in 0..<max(count, 0) {
            let (now, p, seed) = ember(i, t: t, size: size, turbulence: turbulence, salt: 2510)
            let (before, _, _) = ember(i, t: t - 0.05, size: size, turbulence: turbulence, salt: 2510)
            let flicker = 0.62 + 0.38 * sin(t * (56 + 44 * BackgroundMath.rand(seed, 2516)) + Double(seed))
            let cooling = 0.7 + 0.3 * BackgroundMath.rand(seed, 2517)
            let fade = min(p / 0.05, 1) * (1 - BackgroundMath.smoothstep(0.6, 0.97, p))
            let temperature = (1 - p * cooling) * flicker * fade
            guard temperature > 0.04, hypot(now.x - before.x, now.y - before.y) < 60 else { continue }
            let level = min(Int(temperature * Double(levels)), levels - 1)
            let big = BackgroundMath.rand(i, 2518) > 0.62
            bins[level * 2 + (big ? 1 : 0)].move(to: before)
            bins[level * 2 + (big ? 1 : 0)].addLine(to: now)
        }
        drawBursts(&bins, t: t, bursts: bursts)

        let thin = StrokeStyle(lineWidth: 1.3, lineCap: .round)
        let thick = StrokeStyle(lineWidth: 2.4, lineCap: .round)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.blendMode = .plusLighter
            for level in 1..<levels {
                let color = heat[min(level, 3)].color(0.5 * Double(level) / Double(levels - 1))
                layer.stroke(bins[level * 2], with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                layer.stroke(bins[level * 2 + 1], with: .color(color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
        }
        for level in 0..<levels {
            let color = heat[level].color(0.45 + 0.55 * Double(level) / Double(levels - 1))
            context.stroke(bins[level * 2], with: .color(color), style: thin)
            context.stroke(bins[level * 2 + 1], with: .color(color), style: thick)
        }

        // A few out-of-focus embers close to the lens.
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            for i in 0..<7 {
                let (p0, p, seed) = ember(i, t: t * 1.5, size: size, turbulence: turbulence * 1.6, salt: 2530)
                let r = 7 + 9 * BackgroundMath.unit(seed, 2536)
                let alpha = sin(p * .pi) * 0.34
                layer.backgroundsGlow(at: p0, radius: r, color: heat[2].color(alpha))
            }
        }

        for burst in bursts {
            let age = t - burst.born
            guard age >= 0, age < 0.7 else { continue }
            context.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.backgroundsGlow(at: burst.origin, radius: 60 + 90 * CGFloat(age), color: Color(hex: 0xFFC27A).opacity(exp(-age * 4) * 0.85))
            }
        }
    }

    private static func spark(_ burst: EmberBurst, _ i: Int, age: Double) -> CGPoint {
        let key = burst.seed * 97 + i
        let angle = -Double.pi / 2 + (BackgroundMath.rand(key, 2541) * 2 - 1) * 1.1
        let v = 120 + 260 * BackgroundMath.rand(key, 2542)
        let k = 2.2
        let travel = v * (1 - exp(-k * age)) / k
        let curl = 9 * sin(age * 7 + BackgroundMath.rand(key, 2543) * 6.28) * age
        return CGPoint(
            x: burst.origin.x + CGFloat(cos(angle) * travel + curl),
            y: burst.origin.y + CGFloat(sin(angle) * travel - 34 * age * age)
        )
    }

    private static func drawBursts(_ bins: inout [Path], t: Double, bursts: [EmberBurst]) {
        for burst in bursts {
            let age = t - burst.born
            guard age > 0 else { continue }
            for i in 0..<26 {
                let key = burst.seed * 97 + i
                let life = 1.1 + 0.9 * BackgroundMath.rand(key, 2544)
                guard age < life else { continue }
                let heatNow = pow(1 - age / life, 0.5) * (0.82 + 0.18 * sin(t * 60 + Double(key)))
                let level = min(Int(heatNow * Double(levels)), levels - 1)
                let big = BackgroundMath.rand(key, 2545) > 0.3
                bins[level * 2 + (big ? 1 : 0)].move(to: spark(burst, i, age: max(age - 0.05, 0)))
                bins[level * 2 + (big ? 1 : 0)].addLine(to: spark(burst, i, age: age))
            }
        }
    }
}
