import SwiftUI

extension Effect {
    static let backgroundsGalaxy = Effect(
        id: "backgrounds.galaxy",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Spiral Galaxy", "旋涡星系"),
        summary: L(
            "A tilted spiral galaxy of 900 stars turns around a glowing core; drag to tip the disc in 3D.",
            "由 900 颗星组成的倾斜旋涡星系绕着发光的星核旋转，拖动即可在三维中倾斜星盘。"
        ),
        prompt: L(
            "Deep space with a faint field of distant stars. A spiral galaxy of 900 particles fills the stage: two logarithmic arms wind one full turn outward from a warm, blurred core, with stars scattered within ±0.4 rad of each arm and densest on its spine, a fifth of them spread between the arms, and a round bulge of golden stars in the middle. The disc is seen in true 3D at a 62° inclination, rolled −20°, and slowly precesses. Arms rotate at 0.12 rad/s while bulge stars run 1.8× faster and inter-arm stars 0.7× slower, so layers shear past each other. Arm stars are blue-white with occasional pink and cyan clusters; a third of all stars twinkle on their own sine, and soft violet haze follows the arms. Dragging tips and rolls the disc with a smooth 5/s follow. Vast, silent, slowly turning.",
            "深空中散落着远星。一座由 900 个粒子组成的旋涡星系铺满舞台：两条对数旋臂从温暖朦胧的星核向外盘绕一整圈，恒星散布在旋臂两侧 ±0.4 rad 内、越靠近臂脊越密，五分之一散落在旋臂之间，中央是金色的核球。星盘以真实三维呈现，倾角 62°、滚转 −20°，并缓慢进动。旋臂以 0.12 rad/s 转动，核球恒星快 1.8 倍，臂间恒星慢到 0.7 倍。旋臂恒星呈蓝白色，间有粉色与青色星团；三分之一的恒星各自明灭，淡紫色星云沿旋臂铺开。拖动可让星盘倾斜与滚转，以 5/s 平滑跟随。辽阔、寂静。"
        ),
        implementation: L(
            "Every star's disc position is analytic from its index (radius, arm, scatter, rotation rate); positions are projected with an inclination and roll, then batched into 15 Paths by colour and brightness. Core and haze are drawn in blurred plusLighter layers.",
            "每颗星在星盘上的位置都由序号解析得出（半径、旋臂、散布、转速），经倾角与滚转投影后按颜色和亮度合并为 15 条 Path；星核与星云雾气绘制在模糊的 plusLighter 图层中。"
        ),
        apis: ["Canvas", "GraphicsContext.drawLayer", "blendMode(.plusLighter)", "TimelineView(.animation)", "DragGesture"],
        tags: ["galaxy", "spiral", "stars", "space", "星系", "旋涡", "星空", "宇宙"],
        params: [
            .slider("stars", L("Stars", "恒星数量"), 300...1600, default: 900, step: 50, decimals: 0),
            .slider("arms", L("Arms", "旋臂数"), 2...6, default: 2, step: 1, decimals: 0),
            .slider("twist", L("Arm winding", "旋臂圈数"), 0.3...2.0, default: 1.0, unit: " turns"),
            .slider("speed", L("Rotation", "转速"), 0...4, default: 1.0, unit: "×"),
        ]
    ) { ctx in
        GalaxyDemo(ctx: ctx)
    }
}

private final class GalaxyModel {
    let clock = BackgroundClock()
    /// Normalised touch position (0...1 on both axes), `nil` when idle.
    var touch: CGPoint?
    private(set) var inclination: Double = 62 * .pi / 180
    private(set) var roll: Double = -20 * .pi / 180
    private var wall = BackgroundClock()

    func step(now: Double, speed: Double, frozen: Bool) -> Double {
        let t = clock.advance(to: now, speed: speed)
        guard !frozen else { return t }
        let real = wall.advance(to: now, speed: 1)
        var wantedInclination = (62 + 8 * sin(real * 0.13)) * .pi / 180
        var wantedRoll = (-20 + 9 * sin(real * 0.09)) * .pi / 180
        if let touch {
            wantedInclination = (30 + 52 * Double(touch.y)) * .pi / 180
            wantedRoll = (Double(touch.x) - 0.5) * 1.5
        }
        let k = wall.follow(rate: 5)
        inclination += (wantedInclination - inclination) * k
        roll += (wantedRoll - roll) * k
        return t
    }
}

private struct GalaxyDemo: View {
    let ctx: DemoContext
    @State private var model = GalaxyModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x141033), Color(hex: 0x070716), Color(hex: 0x020207)], center: .center, startRadius: 0, endRadius: 300)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let t = model.step(now: timeline.date.timeIntervalSinceReferenceDate, speed: ctx["speed"], frozen: ctx.isStill)
                GalaxyCanvas(
                    t: t, inclination: model.inclination, roll: model.roll,
                    stars: ctx.int("stars"), arms: max(ctx.int("arms"), 1), twist: ctx["twist"]
                )
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .backgroundsTouch { location in
            model.touch = CGPoint(
                x: (location.x / max(size.width, 1)).clamped(to: 0...1),
                y: (location.y / max(size.height, 1)).clamped(to: 0...1)
            )
        } onEnded: {
            model.touch = nil
        }
        .backgroundsHint(L("Swipe sideways, then move to tilt the galaxy", "横向滑动后移动手指倾斜星系"), ctx)
    }
}

private struct GalaxyCanvas: View {
    let t: Double
    let inclination: Double
    let roll: Double
    let stars: Int
    let arms: Int
    let twist: Double

    private static let colors: [Color] = [
        Color(hex: 0xFFDFA8), // bulge
        Color(hex: 0xFFF6E6), // inner disc
        Color(hex: 0xBCD2FF), // arms
        Color(hex: 0xFF8FC4), // star-forming knots
        Color(hex: 0x8FE9FF), // young clusters
    ]
    private static let levels = 3

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let reach = Double(min(size.width, size.height)) * 0.74
            GalaxyCanvas.drawBackdrop(&context, size: size, t: t)

            let cosI = cos(inclination)
            let sinI = sin(inclination)
            let cosR = cos(roll)
            let sinR = sin(roll)
            func project(_ x: Double, _ y: Double, _ z: Double) -> (CGPoint, Double) {
                let py = y * cosI - z * sinI
                let depth = y * sinI + z * cosI
                return (CGPoint(x: centre.x + CGFloat(x * cosR - py * sinR), y: centre.y + CGFloat(x * sinR + py * cosR)), depth)
            }

            // Haze along the arms.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 11))
                layer.blendMode = .plusLighter
                var violet = Path()
                var blue = Path()
                for i in 0..<120 {
                    let star = GalaxyCanvas.star(index: i * 7 + 3, t: t, arms: arms, twist: twist, hazy: true)
                    let (p, _) = project(star.x * reach, star.y * reach, 0)
                    let r = CGFloat(7 + 9 * BackgroundMath.rand(i, 611))
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    if i % 2 == 0 { violet.addEllipse(in: rect) } else { blue.addEllipse(in: rect) }
                }
                layer.fill(violet, with: .color(Color(hex: 0x8A5CFF).opacity(0.17)))
                layer.fill(blue, with: .color(Color(hex: 0x4F8BFF).opacity(0.15)))
            }

            // Stars.
            var bins = [Path](repeating: Path(), count: GalaxyCanvas.colors.count * GalaxyCanvas.levels)
            for i in 0..<max(stars, 0) {
                let star = GalaxyCanvas.star(index: i, t: t, arms: arms, twist: twist, hazy: false)
                let (p, depth) = project(star.x * reach, star.y * reach, star.z * reach)
                guard p.x > -4, p.y > -4, p.x < size.width + 4, p.y < size.height + 4 else { continue }
                var brightness = star.brightness * (0.85 + 0.25 * depth / reach)
                if i % 3 == 0 {
                    brightness *= 0.6 + 0.4 * sin(t * (1.5 + 4 * BackgroundMath.rand(i, 621)) + Double(i))
                }
                let level = min(max(Int(brightness * Double(GalaxyCanvas.levels)), 0), GalaxyCanvas.levels - 1)
                let r = CGFloat(star.size) * CGFloat(1 + 0.2 * depth / reach)
                bins[star.color * GalaxyCanvas.levels + level].addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            }
            for c in 0..<GalaxyCanvas.colors.count {
                for level in 0..<GalaxyCanvas.levels {
                    let alpha = 0.3 + 0.7 * Double(level) / Double(GalaxyCanvas.levels - 1)
                    context.fill(bins[c * GalaxyCanvas.levels + level], with: .color(GalaxyCanvas.colors[c].opacity(alpha)))
                }
            }
            // Bloom on the brightest stars.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 2.5))
                layer.blendMode = .plusLighter
                for c in 2..<GalaxyCanvas.colors.count {
                    layer.fill(bins[c * GalaxyCanvas.levels + GalaxyCanvas.levels - 1], with: .color(GalaxyCanvas.colors[c].opacity(0.8)))
                }
            }

            // The core: an ellipse flattened by the inclination.
            context.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.translateBy(x: centre.x, y: centre.y)
                layer.rotate(by: .radians(roll))
                layer.scaleBy(x: 1, y: CGFloat(0.45 + 0.55 * abs(cosI)))
                let r = CGFloat(reach) * 0.36
                let core = Gradient(stops: [
                    .init(color: Color(hex: 0xFFF3D6).opacity(0.95), location: 0),
                    .init(color: Color(hex: 0xFFC98A).opacity(0.45), location: 0.18),
                    .init(color: Color(hex: 0xB07CFF).opacity(0.12), location: 0.55),
                    .init(color: Color(hex: 0xB07CFF).opacity(0), location: 1),
                ])
                layer.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .radialGradient(core, center: .zero, startRadius: 0, endRadius: r))
            }
        }
    }

    private struct Star {
        let x: Double
        let y: Double
        let z: Double
        let size: Double
        let brightness: Double
        let color: Int
    }

    /// Position on the unit disc (z is the height above it), fully determined by the index and time.
    private static func star(index i: Int, t: Double, arms: Int, twist: Double, hazy: Bool) -> Star {
        let kind = BackgroundMath.rand(i, 601)
        let u = BackgroundMath.rand(i, 602)
        let spin = t * 0.12
        if kind < 0.14 && !hazy {
            // Bulge: a small, round swarm.
            let rho = 0.2 * pow(u, 0.8)
            let angle = BackgroundMath.rand(i, 603) * BackgroundMath.tau + spin * 1.8
            let lift = (BackgroundMath.rand(i, 604) - 0.5) * 0.24 * (1 - rho / 0.2 * 0.6)
            return Star(x: rho * cos(angle), y: rho * sin(angle), z: lift, size: 0.6 + 0.9 * BackgroundMath.rand(i, 605), brightness: 0.55 + 0.45 * u, color: 0)
        }
        let rho = 0.07 + 0.93 * pow(u, 0.7)
        let between = kind > 0.8 && !hazy
        var angle: Double
        if between {
            angle = BackgroundMath.rand(i, 603) * BackgroundMath.tau + spin * 0.7
        } else {
            let arm = Double(i % arms) / Double(arms) * BackgroundMath.tau
            let scatter = (BackgroundMath.rand(i, 603) + BackgroundMath.rand(i, 606) - 1) * 0.4
            // Logarithmic spiral: `twist` turns between the core and the rim.
            angle = arm + twist * BackgroundMath.tau * log(1 + rho * 3) / log(4) + scatter + spin
        }
        angle = -angle
        let lift = (BackgroundMath.rand(i, 604) - 0.5) * 0.035
        let tint = BackgroundMath.rand(i, 607)
        var color = rho < 0.3 ? 1 : 2
        if !between {
            if tint > 0.93 { color = 3 } else if tint > 0.86 { color = 4 }
        }
        let size = (between ? 0.45 : 0.55) + 1.0 * pow(BackgroundMath.rand(i, 605), 3)
        let brightness = (between ? 0.3 : 0.5) + 0.5 * BackgroundMath.rand(i, 608) * (1.1 - 0.5 * rho)
        return Star(x: rho * cos(angle), y: rho * sin(angle), z: lift, size: size, brightness: brightness, color: color)
    }

    private static func drawBackdrop(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        var dim = Path()
        var bright = Path()
        for i in 0..<70 {
            let x = BackgroundMath.unit(i, 631) * size.width
            let y = BackgroundMath.unit(i, 632) * size.height
            let r = 0.4 + 0.7 * BackgroundMath.unit(i, 633)
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            if sin(t * 0.6 + Double(i) * 2.4) > 0.3 { bright.addEllipse(in: rect) } else { dim.addEllipse(in: rect) }
        }
        context.fill(dim, with: .color(.white.opacity(0.22)))
        context.fill(bright, with: .color(.white.opacity(0.5)))
    }
}
