import SwiftUI

extension Effect {
    static let loadingSquashBall = Effect(
        id: "loading.squash-ball",
        category: .loading,
        interaction: .loop,
        name: L("Squash & Stretch Ball", "挤压拉伸弹球"),
        summary: L("A rubber ball that stretches as it falls, flattens on the floor and pulls its shadow tight on every impact.", "一颗橡胶球：下落时拉长，触地时压扁，每次撞击都把影子收得又小又深。"),
        prompt: L(
            "A 56 pt glossy ball bounces in place on a hairline floor, one bounce every 0.85 s. In the air it follows a true parabola 110 pt high and stretches along its travel by up to 20% in proportion to its speed, returning to a perfect circle at the apex. Contact takes 18% of the cycle: the ball flattens to 66% of its height and widens to 127%, bottom edge pinned to the floor, then springs back out. The shadow tells the same story from below: wide, blurred and 10% opaque at the apex, it contracts to a tight, sharp 32% ellipse at impact. Each landing sends a thin ring skating outward along the floor, kicks four dust specks to the sides and shifts the ball to the next palette colour. Elastic, weighty, cartoon-true.",
            "一颗 56 pt 的亮面小球在细线地面上原地弹跳，每 0.85 秒一次。腾空时沿真实抛物线升到 110 pt，并按速度沿运动方向拉长最多 20%，到最高点恢复正圆。触地占周期的 18%：球被压到原高度的 66%、加宽到 127%，底边始终贴着地面，随后弹起复原。影子在下方讲着同一个故事：球在最高点时它又宽又虚、不透明度只有 10%，撞击瞬间收成一个又小又实、32% 的椭圆。每次落地都会在地面上滑出一圈细环、向两侧踢出四粒尘点，并让小球换成调色板里的下一个颜色。有弹性、有重量、卡通动画般准确。"
        ),
        implementation: L(
            "A TimelineView feeds the cycle phase to a Canvas. The phase splits into a contact window (sine squash, bottom pinned) and a flight (parabola, stretch = speed × edge fade); the shadow's width, blur and opacity are functions of the height.",
            "TimelineView 把周期相位交给 Canvas。相位分成触地窗口（正弦压扁、底边固定）与腾空段（抛物线，拉伸 = 速度 × 两端淡入）；影子的宽度、模糊与不透明度都是高度的函数。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.scaleBy", "GraphicsContext.addFilter(.blur)", "radialGradient"],
        tags: ["bounce", "squash", "stretch", "ball", "弹跳", "挤压", "拉伸", "小球"],
        params: [
            .slider("period", L("Bounce period", "弹跳周期"), 0.5...1.6, default: 0.85, unit: "s"),
            .slider("height", L("Bounce height", "弹跳高度"), 50...140, default: 110, decimals: 0, unit: "pt"),
            .slider("squash", L("Squash", "压扁程度"), 0...0.55, default: 0.34),
            .toggle("recolor", L("Recolour on impact", "落地换色"), default: true),
        ]
    ) { ctx in
        SquashBallDemo(ctx: ctx)
    }
}

private struct SquashBallDemo: View {
    let ctx: DemoContext
    @State private var clock = LoadingPhaseClock()

    var body: some View {
        let period: Double = max(ctx["period"], 0.2)
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            // Stills catch the ball on its way down, stretched, with the last impact's ring still visible.
            let phase: Double = ctx.isStill ? 2.8 : clock.phase(at: timeline.date, rate: 1 / period) + 0.18
            SquashBallCanvas(
                phase: phase,
                height: ctx.cg("height"),
                squash: ctx.cg("squash"),
                recolor: ctx.bool("recolor")
            )
            .frame(width: 260, height: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx["period"]) { old, _ in
            clock.rebase(at: .now, oldRate: 1 / max(old, 0.2))
        }
    }
}

private struct SquashBallCanvas: View {
    /// Whole part = bounce number, fraction = position in the bounce (0 = first contact).
    let phase: Double
    let height: CGFloat
    let squash: CGFloat
    let recolor: Bool

    private static let contact: Double = 0.18
    private static let radius: CGFloat = 28
    private static let tints: [Color] = [Palette.coral, Palette.amber, Palette.mint, Palette.sky, Palette.violet, Palette.pink]

    private func tint(_ bounce: Int, mix: Double) -> Color {
        let colors = SquashBallCanvas.tints
        guard recolor else { return colors[0] }
        let count: Int = colors.count
        let previous: Color = colors[((bounce - 1) % count + count) % count]
        let current: Color = colors[(bounce % count + count) % count]
        return previous.mix(with: current, by: mix)
    }

    var body: some View {
        Canvas { context, size in
            let p: Double = phase - floor(phase)
            let bounce: Int = Int(floor(phase))
            let c: Double = SquashBallCanvas.contact
            let r: CGFloat = SquashBallCanvas.radius
            let ground: CGFloat = size.height - 44
            let centreX: CGFloat = size.width / 2

            var scaleX: CGFloat = 1
            var scaleY: CGFloat = 1
            var lift: CGFloat = 0
            if p < c {
                let s: CGFloat = CGFloat(sin(.pi * p / c))
                scaleY = 1 - squash * s
                scaleX = 1 + squash * 0.8 * s
            } else {
                let u: Double = (p - c) / (1 - c)
                lift = height * CGFloat(4 * u * (1 - u))
                let speed: Double = abs(1 - 2 * u)
                let edge: Double = LoadingCurve.smoothstep(u / 0.14) * LoadingCurve.smoothstep((1 - u) / 0.14)
                let stretch: CGFloat = squash * 0.6 * CGFloat(speed * edge)
                scaleY = 1 + stretch
                scaleX = 1 / (1 + stretch * 0.75)
            }
            let airborne: CGFloat = min(lift / max(height, 1), 1)
            let centreY: CGFloat = ground - r * scaleY - lift

            // Floor line, fading toward its ends.
            var floor = Path()
            floor.move(to: CGPoint(x: 26, y: ground + 0.5))
            floor.addLine(to: CGPoint(x: size.width - 26, y: ground + 0.5))
            context.stroke(
                floor,
                with: .linearGradient(
                    Gradient(colors: [Color.primary.opacity(0), Color.primary.opacity(0.24), Color.primary.opacity(0)]),
                    startPoint: CGPoint(x: 26, y: ground),
                    endPoint: CGPoint(x: size.width - 26, y: ground)
                ),
                lineWidth: 1
            )

            // Impact ring skating out along the floor.
            let ringLife: Double = 0.5
            if p < ringLife {
                let u: Double = p / ringLife
                let eased: CGFloat = CGFloat(LoadingCurve.easeOutCubic(u))
                let rx: CGFloat = 22 + 62 * eased
                let ring = CGRect(x: centreX - rx, y: ground - rx * 0.13, width: rx * 2, height: rx * 0.26)
                context.stroke(
                    Path(ellipseIn: ring),
                    with: .color(tint(bounce, mix: 1).opacity(0.5 * (1 - u))),
                    lineWidth: 2.2 * CGFloat(1 - u) + 0.4
                )
                // Dust specks kicked sideways.
                for index in 0..<4 {
                    let side: CGFloat = index % 2 == 0 ? 1 : -1
                    let reach: CGFloat = (index < 2 ? 46 : 30) * eased
                    let hop: CGFloat = (index < 2 ? 16 : 24) * CGFloat(4 * u * (1 - u))
                    let dot: CGFloat = 2.4 * CGFloat(1 - u) + 0.3
                    let point = CGPoint(x: centreX + side * (20 + reach), y: ground - 3 - hop)
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)),
                        with: .color(Color.primary.opacity(0.3 * (1 - u)))
                    )
                }
            }

            // Shadow: tight and dark at impact, wide and faint at the apex.
            let shadowHalf: CGFloat = r * (0.95 + 0.75 * airborne) * (p < c ? scaleX : 1)
            let shadowRect = CGRect(x: centreX - shadowHalf, y: ground - 3.5, width: shadowHalf * 2, height: 9)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 2 + 6 * airborne))
                layer.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.32 - 0.22 * Double(airborne))))
            }

            let mix: Double = min(p / 0.12, 1)
            let colour: Color = tint(bounce, mix: mix)

            // The ball's own colour bounced off the floor: bright when it is close, gone at the apex.
            let glowHalf: CGFloat = r * (1.5 + 0.9 * airborne)
            let glow = CGRect(x: centreX - glowHalf, y: ground - 5, width: glowHalf * 2, height: 12)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 7))
                layer.fill(Path(ellipseIn: glow), with: .color(colour.opacity(0.5 * Double(1 - airborne) * Double(1 - airborne))))
            }

            // The ball.
            context.translateBy(x: centreX, y: centreY)
            context.scaleBy(x: scaleX, y: scaleY)
            let ball = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
            context.fill(
                Path(ellipseIn: ball),
                with: .radialGradient(
                    Gradient(colors: [colour.mix(with: .white, by: 0.6), colour, colour.mix(with: .black, by: 0.3)]),
                    center: CGPoint(x: -r * 0.32, y: -r * 0.38),
                    startRadius: 0,
                    endRadius: r * 1.55
                )
            )
            let gloss = CGRect(x: -r * 0.62, y: -r * 0.7, width: r * 0.56, height: r * 0.36)
            context.fill(Path(ellipseIn: gloss), with: .color(.white.opacity(0.55)))
        }
    }
}
