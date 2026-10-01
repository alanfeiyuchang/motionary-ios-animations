import SwiftUI

extension Effect {
    static let backgroundsGodrays = Effect(
        id: "backgrounds.godrays",
        category: .backgrounds,
        interaction: .gesture,
        name: L("God Rays", "丁达尔光束"),
        summary: L(
            "Volumetric shafts of light fan out of a corner; dust motes only sparkle while they cross a beam.",
            "体积光束从角落呈扇形洒下，尘埃只有飘进光束时才被点亮。"
        ),
        prompt: L(
            "A dim, hazy interior lit by one off-screen light in the top-left corner. 9 soft wedge-shaped beams fan out across a 66° arc, each an additive gradient that is brightest at the source and gone after 1.25× the stage diagonal. Every beam breathes on its own: its angle sways ±3.5° on a 27 s sine, its width swells by 30% and its brightness drifts between 35% and 100%, so the fan never repeats. 80 dust motes drift slowly upward with a sideways wobble; a mote is almost invisible in shadow and flares to a warm pinpoint only while it is inside a beam, with Gaussian falloff from the beam axis. Dragging sideways slides the light along the top edge and the whole fan re-aims with an exponential follow of 3.5/s. Still, reverent, cinematic.",
            "昏暗而带薄雾的室内，光源藏在左上角画面之外。9 道柔和的楔形光束在 66° 的扇面内铺开，每道都是叠加混合的渐变：靠近光源最亮，延伸到舞台对角线的 1.25 倍处完全消失。每道光各自呼吸：角度以 27 秒的正弦摆动 ±3.5°，宽度涨落 30%，亮度在 35% 到 100% 之间漂移，整片光扇永不重复。80 粒尘埃缓缓上浮并左右轻晃；在阴影里几乎看不见，只有飘进光束时才亮成一个暖色光点，亮度按到光束轴线的高斯距离衰减。横向拖动可让光源沿顶边滑动，光扇以 3.5/s 的指数跟随重新对准。静谧、庄重、有电影感。"
        ),
        implementation: L(
            "One Canvas: beams are triangles filled with a radial gradient centred on the light and composited with plusLighter inside a blurred layer; each mote's brightness is the analytic sum of Gaussian beam contributions at its polar angle, bucketed into five Paths.",
            "单个 Canvas：光束是以光源为圆心的径向渐变三角形，在模糊图层中以 plusLighter 叠加；每粒尘埃的亮度是它所在极角处各光束高斯贡献的解析求和，再分入五条 Path 批量绘制。"
        ),
        apis: ["Canvas", "GraphicsContext.drawLayer", "blendMode(.plusLighter)", "TimelineView(.animation)", "DragGesture"],
        tags: ["god rays", "light beams", "volumetric", "dust", "丁达尔", "光束", "体积光", "尘埃"],
        params: [
            .slider("beams", L("Beams", "光束数量"), 4...16, default: 9, step: 1, decimals: 0),
            .slider("intensity", L("Intensity", "强度"), 0.3...1.6, default: 1.0, unit: "×"),
            .slider("speed", L("Drift speed", "漂移速度"), 0.2...3.0, default: 1.0, unit: "×"),
            .choice("light", L("Light", "光线"), [L("Golden", "金色"), L("Moonlit", "月光"), L("Deep sea", "深海")]),
        ]
    ) { ctx in
        GodraysDemo(ctx: ctx)
    }
}

private struct GodrayTheme {
    let sky: [Color]
    let beam: Color
    let mote: Color

    static let all: [GodrayTheme] = [
        GodrayTheme(sky: [Color(hex: 0x3B2A20), Color(hex: 0x1B1418), Color(hex: 0x08070C)], beam: Color(hex: 0xFFD79A), mote: Color(hex: 0xFFF1D2)),
        GodrayTheme(sky: [Color(hex: 0x1E2A4A), Color(hex: 0x0E1428), Color(hex: 0x05060E)], beam: Color(hex: 0xB8CCFF), mote: Color(hex: 0xEAF1FF)),
        GodrayTheme(sky: [Color(hex: 0x0E4A5A), Color(hex: 0x06283C), Color(hex: 0x020C18)], beam: Color(hex: 0x8FF2E4), mote: Color(hex: 0xDDFFF8)),
    ]
}

private final class GodrayModel {
    let clock = BackgroundClock()
    /// Normalised x of the light along the top edge; `nil` while nobody is touching.
    var touchX: CGFloat?
    private(set) var sourceX: CGFloat = 0.06

    func step(now: Double, speed: Double) -> Double {
        let t = clock.advance(to: now, speed: speed)
        // Without a finger the light sways slowly by itself, so the fan always moves.
        let idle = CGFloat(0.1 + 0.1 * sin(t * 0.21))
        let target = touchX ?? idle
        sourceX += (target - sourceX) * CGFloat(clock.follow(rate: 3.5))
        return t
    }
}

private struct GodraysDemo: View {
    let ctx: DemoContext
    @State private var model = GodrayModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        let theme = GodrayTheme.all[min(max(ctx.int("light"), 0), GodrayTheme.all.count - 1)]
        ZStack {
            LinearGradient(colors: theme.sky, startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let t = model.step(now: timeline.date.timeIntervalSinceReferenceDate, speed: ctx["speed"])
                GodrayCanvas(t: t, sourceX: model.sourceX, beams: max(ctx.int("beams"), 1), intensity: ctx["intensity"], theme: theme)
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .backgroundsTouch { location in
            model.touchX = (location.x / max(size.width, 1)).clamped(to: 0...1)
        } onEnded: {
            model.touchX = nil
        }
        .backgroundsHint(L("Swipe sideways to move the light", "横向滑动移动光源"), ctx)
    }
}

private struct GodrayBeam {
    let angle: Double
    let halfWidth: Double
    let alpha: Double
}

private struct GodrayCanvas: View {
    let t: Double
    let sourceX: CGFloat
    let beams: Int
    let intensity: Double
    let theme: GodrayTheme

    var body: some View {
        Canvas { context, size in
            let source = CGPoint(x: size.width * sourceX, y: -size.height * 0.06)
            let reach = hypot(size.width, size.height) * 1.25
            let list = GodrayCanvas.beamList(t: t, count: beams, source: source, size: size)

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 7))
                layer.blendMode = .plusLighter
                for beam in list {
                    let a = CGPoint(x: source.x + reach * CGFloat(cos(beam.angle - beam.halfWidth)), y: source.y + reach * CGFloat(sin(beam.angle - beam.halfWidth)))
                    let b = CGPoint(x: source.x + reach * CGFloat(cos(beam.angle + beam.halfWidth)), y: source.y + reach * CGFloat(sin(beam.angle + beam.halfWidth)))
                    var wedge = Path()
                    wedge.move(to: source)
                    wedge.addLine(to: a)
                    wedge.addLine(to: b)
                    wedge.closeSubpath()
                    let peak = min(0.5 * beam.alpha * intensity, 1)
                    let gradient = Gradient(stops: [
                        .init(color: theme.beam.opacity(peak), location: 0),
                        .init(color: theme.beam.opacity(peak * 0.45), location: 0.4),
                        .init(color: theme.beam.opacity(0), location: 1),
                    ])
                    layer.fill(wedge, with: .radialGradient(gradient, center: source, startRadius: 0, endRadius: reach))
                }
                // The glowing window itself.
                let r = size.width * 0.5
                let halo = Gradient(colors: [theme.beam.opacity(min(0.55 * intensity, 1)), theme.beam.opacity(0)])
                layer.fill(
                    Path(ellipseIn: CGRect(x: source.x - r, y: source.y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(halo, center: source, startRadius: 0, endRadius: r)
                )
            }

            GodrayCanvas.drawMotes(&context, size: size, t: t, source: source, reach: reach, beams: list, intensity: intensity, color: theme.mote)

            // A soft vignette keeps the far corner in shadow.
            let far = CGPoint(x: size.width, y: size.height)
            let shade = Gradient(colors: [.black.opacity(0.45), .black.opacity(0)])
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(shade, center: far, startRadius: 0, endRadius: size.width * 0.9))
        }
    }

    private static func beamList(t: Double, count: Int, source: CGPoint, size: CGSize) -> [GodrayBeam] {
        // The fan is centred on the direction from the light to the lower middle of the stage.
        let centre = atan2(Double(size.height * 0.95 - source.y), Double(size.width * 0.55 - source.x))
        let span = 1.15
        return (0..<count).map { i in
            let u = count == 1 ? 0.5 : Double(i) / Double(count - 1)
            let sway = 0.061 * sin(t * BackgroundMath.tau / 27 + Double(i) * 1.7)
            let angle = centre + (u - 0.5) * span + sway
            let base = 0.022 + 0.034 * BackgroundMath.rand(i, 201)
            let halfWidth = base * (1 + 0.3 * sin(t * 0.31 + Double(i) * 2.3))
            let alpha = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 0.4 + Double(i) * 2.1))
            return GodrayBeam(angle: angle, halfWidth: halfWidth, alpha: alpha)
        }
    }

    private static func drawMotes(
        _ context: inout GraphicsContext, size: CGSize, t: Double, source: CGPoint, reach: CGFloat,
        beams: [GodrayBeam], intensity: Double, color: Color
    ) {
        let levels = 5
        var bins = [Path](repeating: Path(), count: levels)
        for i in 0..<80 {
            let depth = BackgroundMath.rand(i, 211)
            let rise = 0.012 + 0.022 * depth
            let x = BackgroundMath.fract(BackgroundMath.rand(i, 212) + 0.02 * sin(t * (0.3 + 0.4 * depth) + Double(i))) * Double(size.width)
            let y = (1 - BackgroundMath.fract(BackgroundMath.rand(i, 213) + t * rise)) * Double(size.height + 20) - 10
            let dx = x - Double(source.x)
            let dy = y - Double(source.y)
            let phi = atan2(dy, dx)
            let distance = (dx * dx + dy * dy).squareRoot()
            var lit = 0.0
            for beam in beams {
                let d = (phi - beam.angle) / beam.halfWidth
                lit += beam.alpha * exp(-d * d * 0.9)
            }
            lit = min(lit, 1) * max(0, 1 - distance / Double(reach) * 0.9)
            let twinkle = 0.7 + 0.3 * sin(t * (1.2 + 2 * BackgroundMath.rand(i, 214)) + Double(i) * 3.1)
            let brightness = min(0.07 + lit * twinkle * intensity, 1)
            let level = min(Int(brightness * Double(levels)), levels - 1)
            let r = CGFloat(0.5 + 1.3 * depth) * CGFloat(0.8 + 0.5 * lit)
            bins[level].addEllipse(in: CGRect(x: CGFloat(x) - r, y: CGFloat(y) - r, width: r * 2, height: r * 2))
        }
        for level in 0..<levels {
            let alpha = (Double(level) + 0.6) / Double(levels)
            context.fill(bins[level], with: .color(color.opacity(alpha * alpha)))
        }
        // The brightest motes get a halo.
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: 3))
            glow.blendMode = .plusLighter
            glow.fill(bins[levels - 1], with: .color(color.opacity(0.9)))
            glow.fill(bins[levels - 2], with: .color(color.opacity(0.45)))
        }
    }
}
