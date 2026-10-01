import SwiftUI

extension Effect {
    static let backgroundsShootingStars = Effect(
        id: "backgrounds.shooting-stars",
        category: .backgrounds,
        interaction: .tap,
        name: L("Shooting Stars", "流星夜空"),
        summary: L(
            "A slowly wheeling night sky of twinkling stars; meteors streak across with glowing tails — tap to wish for one.",
            "缓缓转动的夜空里群星闪烁，流星拖着发光的尾巴划过；点击即可许愿召来一颗。"
        ),
        prompt: L(
            "A clear night above a pine ridge: the sky deepens from twilight violet at the horizon to near-black overhead, crossed by a faint, blurred Milky Way band. About 180 stars in white, blue-white and warm tones rotate together around an off-screen pole at 0.012 rad/s, each scintillating on its own sine; the brightest carry four-point diffraction spikes that pulse gently. Every 1.8 s on average a meteor crosses at 460 pt/s on a shallow downward diagonal: its head fades in and out along a sine arc, its 130 pt tail is a gradient from white to transparent blue with a blurred glow, and six sparks shed from the tail drift and die behind it. Tapping sends a meteor straight through the touched point with a light haptic. Still, vast, quietly magical.",
            "松林山脊之上的晴朗夜空：天色从地平线处的暮紫加深到头顶的近乎纯黑，一条朦胧的银河斜贯其间。约 180 颗白色、蓝白色与暖色的星星绕着画面外的天极以 0.012 rad/s 一同旋转，各自按自己的正弦闪烁；最亮的几颗带有四角星芒，轻轻脉动。平均每 1.8 秒有一颗流星以 460pt/s 沿平缓的斜线向下划过：头部亮度沿正弦弧线淡入淡出，130pt 长的尾迹由白色渐变为透明的蓝，并带一层模糊辉光，尾部洒落的六粒火花在身后飘散熄灭。点击会让一颗流星正好穿过触点，伴随轻触感。静谧、辽阔、带着一点魔法。"
        ),
        implementation: L(
            "Stars are analytic: polar coordinates around a pole plus time, bucketed into nine Paths by colour and brightness. Meteors live in a small reference model; a Canvas strokes each tail with a linear gradient twice (blurred glow, then core) and derives sparks from the meteor's age.",
            "星星是解析的：绕天极的极坐标加上时间，按颜色与亮度分入九条 Path。流星保存在一个小型引用类型模型中；Canvas 用线性渐变把每条尾迹描两遍（先模糊辉光，再亮芯），火花则由流星的存活时间推算。"
        ),
        apis: ["Canvas", "GraphicsContext.Shading.linearGradient", "GraphicsContext.drawLayer", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)"],
        tags: ["shooting star", "meteor", "night sky", "stars", "流星", "夜空", "星空", "许愿"],
        params: [
            .slider("stars", L("Stars", "星星数量"), 60...360, default: 180, step: 10, decimals: 0),
            .slider("interval", L("Meteor interval", "流星间隔"), 0.5...6, default: 1.8, decimals: 1, unit: "s"),
            .slider("tail", L("Tail length", "尾迹长度"), 60...240, default: 130, decimals: 0, unit: "pt"),
            .slider("speed", L("Meteor speed", "流星速度"), 220...900, default: 460, decimals: 0, unit: "pt/s"),
        ]
    ) { ctx in
        ShootingStarsDemo(ctx: ctx)
    }
}

private struct Meteor {
    let start: CGPoint
    let direction: CGVector
    let speed: CGFloat
    let life: Double
    let born: Double
    let seed: Int
}

private final class MeteorModel {
    let clock = BackgroundClock()
    private(set) var meteors: [Meteor] = []
    private var rng = BackgroundRNG(seed: 5)
    private var next: Double = 100.7
    private var size: CGSize = .zero
    private var seed = 0

    func step(now: Double, size newSize: CGSize, interval: Double, speed: CGFloat, frozen: Bool) -> Double {
        let t = clock.advance(to: now, speed: 1)
        if newSize != size {
            size = newSize
            meteors = []
            if frozen {
                // A still catches one meteor at mid-flight.
                let direction = CGVector(dx: cos(2.6), dy: sin(2.6))
                let travel: CGFloat = 320
                let middle = CGPoint(x: newSize.width * 0.42, y: newSize.height * 0.36)
                meteors = [Meteor(
                    start: CGPoint(x: middle.x - direction.dx * travel / 2, y: middle.y - direction.dy * travel / 2),
                    direction: direction, speed: speed, life: Double(travel / speed), born: t - Double(travel / speed) * 0.5, seed: 1
                )]
            }
        }
        guard !frozen else { return t }
        meteors.removeAll { t - $0.born > $0.life + 1.0 }
        if t >= next {
            spawn(through: nil, speed: speed, born: t)
            next = t + interval * rng.range(0.5...1.5)
        } else if next - t > interval * 1.6 {
            next = t + interval
        }
        return t
    }

    func wish(at point: CGPoint, speed: CGFloat) {
        spawn(through: point, speed: speed, born: clock.phase)
    }

    private func spawn(through point: CGPoint?, speed: CGFloat, born: Double) {
        guard size.width > 0 else { return }
        // Mostly down-left, sometimes down-right; always shallow.
        let leftward = rng.unit() > 0.25
        let angle = leftward ? rng.range(2.3...2.85) : rng.range(0.3...0.85)
        let direction = CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
        let travel = CGFloat(rng.range(230...380))
        let middle = point ?? CGPoint(
            x: size.width * CGFloat(rng.range(0.2...0.8)),
            y: size.height * CGFloat(rng.range(0.12...0.5))
        )
        seed += 1
        meteors.append(Meteor(
            start: CGPoint(x: middle.x - direction.dx * travel / 2, y: middle.y - direction.dy * travel / 2),
            direction: direction, speed: speed, life: Double(travel / max(speed, 1)), born: born, seed: seed
        ))
        if meteors.count > 8 { meteors.removeFirst(meteors.count - 8) }
    }
}

private struct ShootingStarsDemo: View {
    let ctx: DemoContext
    @State private var model = MeteorModel()

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x03040F), location: 0),
                    .init(color: Color(hex: 0x0A1038), location: 0.45),
                    .init(color: Color(hex: 0x232C60), location: 0.78),
                    .init(color: Color(hex: 0x4B4478), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.step(now: now, size: size, interval: max(ctx["interval"], 0.2), speed: max(ctx.cg("speed"), 50), frozen: ctx.isStill)
                    NightSkyPainter.drawMilkyWay(&context, size: size)
                    NightSkyPainter.drawStars(&context, size: size, t: t, count: ctx.int("stars"))
                    for meteor in model.meteors {
                        NightSkyPainter.drawMeteor(&context, meteor: meteor, age: t - meteor.born, tail: ctx.cg("tail"))
                    }
                    NightSkyPainter.drawRidge(&context, size: size)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.light)
            model.wish(at: location, speed: max(ctx.cg("speed"), 50))
        }
        .backgroundsHint(L("Tap the sky to make a wish", "点击夜空许个愿"), ctx)
    }
}

private enum NightSkyPainter {
    private static let starColors: [Color] = [.white, Color(hex: 0xBBD2FF), Color(hex: 0xFFE2B8)]

    static func drawMilkyWay(_ context: inout GraphicsContext, size: CGSize) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 20))
            layer.blendMode = .plusLighter
            let tints: [Color] = [Color(hex: 0x6E7BFF), Color(hex: 0xA46BFF), Color(hex: 0xFF8FB8), Color(hex: 0x7CC8FF)]
            for i in 0..<26 {
                let u = CGFloat(i) / 25
                let across = (BackgroundMath.unit(i, 1101) - 0.5) * size.width * 0.14
                let x = size.width * (0.14 + 0.74 * u) + across * 0.4
                let y = size.height * (0.6 - 0.52 * u) + across
                let r = size.width * (0.05 + 0.06 * BackgroundMath.unit(i, 1102))
                // The band thins out toward both ends.
                let density = 0.012 + 0.03 * sin(.pi * Double(u))
                layer.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(tints[i % tints.count].opacity(density))
                )
            }
        }
    }

    static func drawStars(_ context: inout GraphicsContext, size: CGSize, t: Double, count: Int) {
        // Everything turns around a pole above the top-right corner.
        let pole = CGPoint(x: size.width * 0.82, y: -size.height * 0.3)
        let inner = Double(size.height) * 0.3
        let outer = Double(hypot(pole.x, size.height - pole.y))
        // Only part of the ring is on stage, so more stars are generated than are seen.
        let ring = Double.pi * (outer * outer - inner * inner)
        let total = Int(Double(max(count, 0)) * ring / Double(max(size.width * size.height, 1)))
        let spin = t * 0.012
        var bins = [Path](repeating: Path(), count: 9)
        var spikes = Path()
        for i in 0..<total {
            let rho = (inner * inner + (outer * outer - inner * inner) * BackgroundMath.rand(i, 1111)).squareRoot()
            let angle = BackgroundMath.rand(i, 1112) * BackgroundMath.tau + spin
            let x = pole.x + CGFloat(rho * cos(angle))
            let y = pole.y + CGFloat(rho * sin(angle))
            guard x > -3, y > -3, x < size.width + 3, y < size.height * 0.95 else { continue }
            let magnitude = pow(BackgroundMath.rand(i, 1113), 3)
            let twinkle = 0.62 + 0.38 * sin(t * (0.8 + 3.2 * BackgroundMath.rand(i, 1114)) + Double(i))
            // Stars fade into the haze near the horizon.
            let haze = 1 - 0.6 * BackgroundMath.smoothstep(0.55, 0.95, Double(y / size.height))
            let brightness = (0.35 + 0.65 * magnitude) * twinkle * haze
            let level = min(Int(brightness * 3), 2)
            let tone = i % 7 == 0 ? 2 : (i % 3 == 0 ? 1 : 0)
            let r = CGFloat(0.45 + 1.25 * magnitude)
            bins[tone * 3 + level].addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            if magnitude > 0.88 {
                let arm = CGFloat(3 + 5 * magnitude) * CGFloat(0.7 + 0.3 * twinkle)
                spikes.move(to: CGPoint(x: x - arm, y: y))
                spikes.addLine(to: CGPoint(x: x + arm, y: y))
                spikes.move(to: CGPoint(x: x, y: y - arm))
                spikes.addLine(to: CGPoint(x: x, y: y + arm))
            }
        }
        for tone in 0..<3 {
            for level in 0..<3 {
                let alpha = 0.3 + 0.35 * Double(level)
                context.fill(bins[tone * 3 + level], with: .color(starColors[tone].opacity(alpha)))
            }
        }
        context.stroke(spikes, with: .color(.white.opacity(0.38)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 2.5))
            layer.blendMode = .plusLighter
            for tone in 0..<3 {
                layer.fill(bins[tone * 3 + 2], with: .color(starColors[tone].opacity(0.8)))
            }
        }
    }

    static func drawMeteor(_ context: inout GraphicsContext, meteor: Meteor, age: Double, tail: CGFloat) {
        guard age >= 0 else { return }
        let p = min(age / meteor.life, 1)
        let travelled = meteor.speed * CGFloat(min(age, meteor.life))
        let head = CGPoint(x: meteor.start.x + meteor.direction.dx * travelled, y: meteor.start.y + meteor.direction.dy * travelled)
        let brightness = age < meteor.life ? pow(sin(.pi * p), 0.6) : 0

        // Sparks shed along the path keep glowing for a moment after the head is gone.
        var sparks = Path()
        var sparkAlpha = 0.0
        for k in 0..<6 {
            let shedAt = meteor.life * (0.25 + 0.11 * Double(k))
            let sparkAge = age - shedAt
            guard sparkAge > 0, sparkAge < 0.9 else { continue }
            let along = meteor.speed * CGFloat(shedAt)
            let side = CGFloat(BackgroundMath.rand(meteor.seed * 13 + k, 1121) - 0.5) * 2
            let drift = CGFloat(sparkAge) * 16
            let x = meteor.start.x + meteor.direction.dx * along - meteor.direction.dy * side * drift + meteor.direction.dx * drift
            let y = meteor.start.y + meteor.direction.dy * along + meteor.direction.dx * side * drift + CGFloat(sparkAge * sparkAge) * 22
            let r = CGFloat(1.3 * (1 - sparkAge / 0.9)) + 0.3
            sparks.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            sparkAlpha = max(sparkAlpha, 1 - sparkAge / 0.9)
        }
        if sparkAlpha > 0 {
            context.fill(sparks, with: .color(Color(hex: 0xFFE9C4).opacity(0.85 * sparkAlpha)))
        }

        guard brightness > 0.01 else { return }
        let length = min(tail, travelled)
        let end = CGPoint(x: head.x - meteor.direction.dx * length, y: head.y - meteor.direction.dy * length)
        var streak = Path()
        streak.move(to: end)
        streak.addLine(to: head)
        let glow = Gradient(stops: [
            .init(color: Color(hex: 0x7CB8FF).opacity(0), location: 0),
            .init(color: Color(hex: 0x9FD0FF).opacity(0.55 * brightness), location: 0.7),
            .init(color: Color.white.opacity(brightness), location: 1),
        ])
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            layer.blendMode = .plusLighter
            layer.stroke(streak, with: .linearGradient(glow, startPoint: end, endPoint: head), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            let r: CGFloat = 9
            layer.fill(Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xCFE4FF).opacity(0.9 * brightness)))
        }
        let core = Gradient(stops: [
            .init(color: .white.opacity(0), location: 0),
            .init(color: .white.opacity(0.5 * brightness), location: 0.6),
            .init(color: .white.opacity(brightness), location: 1),
        ])
        context.stroke(streak, with: .linearGradient(core, startPoint: end, endPoint: head), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        let r = CGFloat(1.6 + 1.2 * brightness)
        context.fill(Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(brightness)))
    }

    static func drawRidge(_ context: inout GraphicsContext, size: CGSize) {
        // Horizon glow, then a hill line bristling with pines.
        let glow = Gradient(colors: [Color(hex: 0x6A5A9A).opacity(0), Color(hex: 0x6A5A9A).opacity(0.35)])
        context.fill(
            Path(CGRect(x: 0, y: size.height * 0.7, width: size.width, height: size.height * 0.3)),
            with: .linearGradient(glow, startPoint: CGPoint(x: 0, y: size.height * 0.7), endPoint: CGPoint(x: 0, y: size.height))
        )
        var ridge = Path()
        ridge.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = -6
        var i = 0
        while x < size.width + 12 {
            let u = Double(x / max(size.width, 1))
            let ground = size.height * CGFloat(0.93 - 0.035 * sin(u * 4.1 + 0.8) - 0.015 * sin(u * 9.3))
            let w = 7 + 7 * BackgroundMath.unit(i, 1131)
            let h = 12 + 22 * BackgroundMath.unit(i, 1132)
            ridge.addLine(to: CGPoint(x: x, y: ground))
            ridge.addLine(to: CGPoint(x: x + w * 0.5, y: ground - h))
            ridge.addLine(to: CGPoint(x: x + w, y: ground))
            x += w * 0.78
            i += 1
        }
        ridge.addLine(to: CGPoint(x: size.width, y: size.height))
        ridge.closeSubpath()
        context.fill(ridge, with: .color(Color(hex: 0x03040B)))
    }
}
