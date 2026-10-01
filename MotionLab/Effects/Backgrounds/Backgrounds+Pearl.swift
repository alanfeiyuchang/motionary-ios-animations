import SwiftUI

extension Effect {
    static let backgroundsPearl = Effect(
        id: "backgrounds.pearl",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Mother of Pearl", "珍珠母贝"),
        summary: L(
            "A nacre surface: creamy lustre, faint growth lines and soft bands of thin-film colour that slide and trade places as the light follows your finger.",
            "一片珠母表面：奶油般的光泽、若隐若现的生长纹，还有随光源跟着手指移动而滑动、互换位置的柔和薄膜虹彩。"
        ),
        prompt: L(
            "A full-bleed mother-of-pearl surface in creamy white. Its colour is thin-film iridescence: a pastel spectrum (pink, mint, lavender, peach, aqua, lemon) indexed by a smooth two-octave noise field plus the distance to the light, one full cycle per 240 pt, so large soft bands of colour lie across the surface like the layers of a shell, and slide and exchange places as the light moves; colour is strongest away from the light and washes out to white lustre beneath it. Twenty-two faint wavy growth lines catch the light on one side and shade on the other. The light is a broad white sheen with a small hot core and a dim counter-glow opposite; it follows the finger on a spring (stiffness 50, damping 0.7) and drifts in a slow figure-eight when untouched. A Tahitian variant swaps in peacock green, violet and teal on charcoal. Soft, precious, serene.",
            "铺满画面的奶白色珍珠母贝。它的颜色是薄膜干涉的虹彩：一条粉彩光谱（粉、薄荷、淡紫、蜜桃、水蓝、柠檬）由平滑的两倍频噪声场加上到光源的距离来取色，每 240pt 循环一轮，大片柔和的色带像贝壳层理一样铺在表面，并随光源移动而滑动、互换位置；离光源越远色彩越浓，光源下方则洗成白色珠光。22 条若隐若现的波浪形生长纹一侧受光、一侧落影。光源是一片宽阔白光加小光芯，对侧有一抹微弱反光；它以弹簧（刚度 50、阻尼 0.7）跟随手指，无触摸时缓慢走 8 字。黑珍珠变体换成炭灰底上的孔雀绿、紫与青。"
        ),
        implementation: L(
            "A 9 × 9 MeshGradient is recoloured every frame: each vertex samples a cyclic pastel ramp at noise(x, y) + distance-to-light / spread and is mixed into the base by its distance from the light; a Canvas on top strokes sine growth lines with light-centred radial shading and adds the specular glows.",
            "9 × 9 的 MeshGradient 每帧重新着色：每个顶点在“噪声(x, y) + 到光源距离 / 间距”处对循环粉彩色带取样，并按离光源的远近混入底色；上层 Canvas 以光源为中心的径向着色描出正弦生长纹，并叠加高光。"
        ),
        apis: ["MeshGradient", "Canvas", "GraphicsContext.Shading.radialGradient", "TimelineView(.animation)", "DragGesture"],
        tags: ["pearl", "nacre", "iridescent", "lustre", "珍珠", "珠光", "母贝", "虹彩"],
        params: [
            .slider("iridescence", L("Iridescence", "虹彩强度"), 0...1, default: 0.6),
            .slider("spread", L("Colour spread", "色带间距"), 120...400, default: 240, decimals: 0, unit: "pt"),
            .slider("lustre", L("Lustre", "珠光"), 0...1, default: 0.75),
            .choice("pearl", L("Pearl", "珍珠"), [L("White", "白珍珠"), L("Tahitian", "黑珍珠")]),
        ]
    ) { ctx in
        PearlDemo(ctx: ctx)
    }
}

private final class PearlModel {
    let pointer = BackgroundPointer()
}

private struct PearlDemo: View {
    let ctx: DemoContext
    @State private var model = PearlModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        let dark = ctx.int("pearl") == 1
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let idle = ctx.isStill
                ? CGPoint(x: size.width * 0.36, y: size.height * 0.34)
                : CGPoint(
                    x: size.width * CGFloat(0.5 + 0.32 * sin(now * 0.5)),
                    y: size.height * CGFloat(0.46 + 0.26 * sin(now * 1.0))
                )
            let light = model.pointer.step(now: now, idle: idle, stiffness: 50, damping: 0.7, frozen: ctx.isStill)
            ZStack {
                MeshGradient(
                    width: PearlPainter.grid, height: PearlPainter.grid, points: PearlPainter.points,
                    colors: PearlPainter.colors(
                        size: size, light: light, dark: dark, iridescence: ctx["iridescence"], spread: max(ctx["spread"], 40),
                        drift: ctx.isStill ? 0 : now * 0.02
                    )
                )
                Canvas { context, size in
                    PearlPainter.draw(&context, size: size, light: light, dark: dark, lustre: ctx["lustre"])
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .backgroundsTouch { location in
            if !model.pointer.userTouched { Haptics.tap(.soft) }
            model.pointer.userTouched = true
            model.pointer.touch = location
        } onEnded: {
            model.pointer.touch = nil
        }
        .modifier(PearlHint(ctx: ctx, dark: dark))
    }
}

private struct PearlHint: ViewModifier {
    let ctx: DemoContext
    let dark: Bool
    private let text = L("Swipe sideways to move the light", "横向滑动移动光源")

    func body(content: Content) -> some View {
        if dark {
            content.backgroundsChipHint(text, ctx)
        } else {
            content.backgroundsLightChipHint(text, ctx)
        }
    }
}

private enum PearlPainter {
    static let grid = 9
    static let pastel: [BackgroundRGB] = [
        .init(hex: 0xFF9CCB), .init(hex: 0x9CF0D4), .init(hex: 0xB9A0FF), .init(hex: 0xFFCB96), .init(hex: 0x96D8FF), .init(hex: 0xF2EC9A),
    ]
    static let peacock: [BackgroundRGB] = [
        .init(hex: 0x1FD6A4), .init(hex: 0x8A4CFF), .init(hex: 0x12A8C4), .init(hex: 0xD84CB0), .init(hex: 0x3F7BFF), .init(hex: 0x7FE05A),
    ]

    /// A regular lattice; interior vertices are nudged so the bands never look gridded.
    static let points: [SIMD2<Float>] = {
        var result: [SIMD2<Float>] = []
        for row in 0..<grid {
            for col in 0..<grid {
                var x = Float(col) / Float(grid - 1)
                var y = Float(row) / Float(grid - 1)
                if col > 0, col < grid - 1 { x += Float(BackgroundMath.rand(row * grid + col, 2321) - 0.5) * 0.05 }
                if row > 0, row < grid - 1 { y += Float(BackgroundMath.rand(row * grid + col, 2322) - 0.5) * 0.05 }
                result.append(SIMD2(x, y))
            }
        }
        return result
    }()

    static func cyclic(_ colors: [BackgroundRGB], _ x: Double) -> BackgroundRGB {
        let f = BackgroundMath.fract(x) * Double(colors.count)
        let i = Int(f) % colors.count
        return colors[i].mix(colors[(i + 1) % colors.count], f - f.rounded(.down))
    }

    static func colors(size: CGSize, light: CGPoint, dark: Bool, iridescence: Double, spread: Double, drift: Double) -> [Color] {
        let palette = dark ? peacock : pastel
        let base = dark ? BackgroundRGB(hex: 0x23262F) : BackgroundRGB(hex: 0xF4EEE8)
        let lit = dark ? BackgroundRGB(hex: 0x8E94A6) : BackgroundRGB(hex: 0xFFFFFF)
        let reach = Double(size.width) * 0.5
        return points.map { point in
            let u = Double(point.x)
            let v = Double(point.y)
            let dx = u * Double(size.width) - Double(light.x)
            let dy = v * Double(size.height) - Double(light.y)
            let distance = (dx * dx + dy * dy).squareRoot()
            let noise = 1.3 * BackgroundMath.valueNoise(u * 2.2 + 7, v * 2.2 + 3) + 0.5 * BackgroundMath.valueNoise(u * 5 + 1, v * 5 + 9)
            let film = cyclic(palette, noise + distance / spread + drift)
            // Lustre washes the colour out under the light.
            let near = exp(-distance * distance / (2 * reach * reach))
            let body = base.mix(lit, 0.55 * near)
            return body.mix(film, iridescence * (dark ? 0.7 : 0.62) * (1 - 0.55 * near)).color()
        }
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, light: CGPoint, dark: Bool, lustre: Double) {
        let rect = Path(CGRect(origin: .zero, size: size))
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let diagonal = hypot(size.width, size.height)

        drawGrowthLines(&context, size: size, light: light, dark: dark)

        // Lustre: a broad sheen with a hot core, and a dim counter-light across the centre.
        let glow = lustre * (dark ? 0.6 : 0.95)
        context.drawLayer { layer in
            layer.blendMode = dark ? .plusLighter : .normal
            layer.backgroundsGlow(at: light, radius: size.width * 0.46, color: .white.opacity(glow * 0.6))
            layer.backgroundsGlow(at: light, radius: size.width * 0.15, color: .white.opacity(glow))
            let counter = CGPoint(x: centre.x * 2 - light.x, y: centre.y * 2 - light.y)
            layer.backgroundsGlow(at: counter, radius: size.width * 0.3, color: .white.opacity(glow * 0.28))
        }

        // The shell curves away at the rim.
        let rim = Gradient(stops: [
            .init(color: .clear, location: 0.5),
            .init(color: (dark ? Color.black : Color(hex: 0x6E5F86)).opacity(dark ? 0.55 : 0.3), location: 1),
        ])
        context.fill(rect, with: .radialGradient(rim, center: centre, startRadius: 0, endRadius: diagonal * 0.6))
    }

    private static func drawGrowthLines(_ context: inout GraphicsContext, size: CGSize, light: CGPoint, dark: Bool) {
        var lines = Path()
        let count = 22
        for i in 0..<count {
            let base = size.height * (CGFloat(i) + 0.5) / CGFloat(count)
            let phase = Double(i) * 1.37
            let amp = 4 + 5 * BackgroundMath.rand(i, 2311)
            var x: CGFloat = -4
            var first = true
            while x <= size.width + 4 {
                let xn = Double(x) / 340
                let y = base + CGFloat(amp * sin(xn * 4.3 + phase) + amp * 0.4 * sin(xn * 11 + phase * 2.1) + 14 * sin(xn * 1.6 + Double(i) * 0.21))
                if first {
                    lines.move(to: CGPoint(x: x, y: y))
                    first = false
                } else {
                    lines.addLine(to: CGPoint(x: x, y: y))
                }
                x += 8
            }
        }
        // Lit side of each ridge, then its shadow one point below; both strongest near the light.
        let reach = size.width * 0.8
        let lit = Gradient(colors: [.white.opacity(dark ? 0.24 : 0.6), .white.opacity(dark ? 0.03 : 0.12)])
        context.stroke(lines, with: .radialGradient(lit, center: light, startRadius: 0, endRadius: reach), lineWidth: 0.8)
        var shadow = context
        shadow.translateBy(x: 0, y: 1.1)
        let shade = Gradient(colors: [Color(hex: 0x5A4A78).opacity(dark ? 0.3 : 0.18), Color(hex: 0x5A4A78).opacity(0.04)])
        shadow.stroke(lines, with: .radialGradient(shade, center: light, startRadius: 0, endRadius: reach), lineWidth: 0.8)
    }
}
