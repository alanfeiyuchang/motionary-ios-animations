import SwiftUI

extension Effect {
    static let textLongShadow = Effect(
        id: "text.long-shadow",
        category: .text,
        interaction: .gesture,
        name: L("Long Shadow", "长投影"),
        summary: L("A heading throws a long extruded shadow away from a light you can drag around it.", "标题朝背光方向拖出一道长长的挤出投影，光源可以用手指拖着绕它转。"),
        prompt: L(
            "A heavy two-line heading in the text colour casts a long flat shadow, the classic extruded look: the letter shapes repeated point by point along one direction for 64 pt, shading from indigo next to the letters to pink at the tip and fading to transparent. A small glowing sun marks the light, and the shadow always points directly away from it, growing up to 20% longer as the light moves further from the heading. Left alone, the sun circles the heading on a slow ellipse, about eight seconds per lap, so the shadow sweeps around like a sundial. Dragging moves the sun under the finger; the shadow follows on a spring (response 0.45 s, damping 0.7), swinging slightly past its new direction before it settles. A solid style drops the fade for a hard retro extrusion.",
            "一个两行的特粗标题以正文色呈现，身后拖着一道长长的扁平投影，也就是经典的挤出效果：字形沿同一方向逐点重复64pt，颜色从贴近字母处的靛蓝过渡到末端的粉色，并逐渐淡到透明。一个发光的小太阳标示光源，投影始终指向正背光的方向；光源离标题越远，投影最多再变长20%。无人触碰时，太阳沿一条缓慢的椭圆绕标题运行，约八秒一圈，投影像日晷一样扫过。拖动时太阳跟着手指走，投影以弹簧（响应0.45秒、阻尼0.7）跟随，会略微甩过新的方向再停稳。切换为实心样式则去掉渐隐，得到硬朗的复古挤出效果。"
        ),
        implementation: L(
            "A Canvas redraws the resolved heading once per point of shadow length, far to near; each copy first erases its footprint with destinationOut and then draws at its own opacity, so nearer copies replace what is beneath and the fade stays exact; the offset vector is a hand-stepped spring toward the direction away from the light.",
            "Canvas 按投影长度每1pt重画一次已解析的标题，由远到近；每一层先用 destinationOut 擦掉自己的轮廓，再以自己的透明度绘制，于是较近的一层替换下面的内容，渐隐保持准确；偏移向量是一根手动步进的弹簧，目标是背离光源的方向。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.BlendMode.destinationOut", "GraphicsContext.resolve", "DragGesture"],
        tags: ["long shadow", "extrude", "flat design", "light", "3d text", "长投影", "挤出", "扁平", "光源", "立体字"],
        params: [
            .slider("length", L("Shadow length", "投影长度"), 10...120, default: 64, decimals: 0, unit: "pt"),
            .slider("response", L("Follow spring", "跟随弹簧"), 0.15...1.2, default: 0.45, unit: "s"),
            .choice("style", L("Style", "样式"), [L("Fade", "渐隐"), L("Solid", "实心")], default: 0),
        ]
    ) { ctx in
        TextLongShadowDemo(ctx: ctx)
    }
}

private struct ShadowSim {
    var last: Date?
    var phase: Double = 2.3
    var x = TextFXSpring()
    var y = TextFXSpring()
    var seeded = false
}

private struct TextLongShadowDemo: View {
    let ctx: DemoContext
    @State private var sim = TextFXBox(ShadowSim())
    @State private var finger: CGPoint? = nil

    private static let bands = 8

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                Canvas { context, size in
                    draw(&context, size: size, date: timeline.date)
                }
            }
            .frame(height: 268)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if finger == nil { Haptics.tap(.soft) }
                        finger = value.location
                    }
                    .onEnded { value in
                        // The orbit resumes from where the finger left the light.
                        let dx: Double = Double(value.location.x) - 170
                        let dy: Double = Double(value.location.y) - 134
                        sim.value.phase = atan2(dy / 100, dx / 140)
                        finger = nil
                    }
            )
            DemoHint(text: L("Drag the light around the heading", "拖着光源绕标题转"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func orbit(_ phase: Double, center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + 140 * CGFloat(cos(phase)), y: center.y + 100 * CGFloat(sin(phase)))
    }

    /// Indigo next to the letters, pink at the tip.
    private func bandColor(_ u: Double) -> Color {
        Color(
            red: (110 + (255 - 110) * u) / 255,
            green: (123 + (95 - 123) * u) / 255,
            blue: (255 + (162 - 255) * u) / 255
        )
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, date: Date) {
        let lines: [String] = ctx.language == .zh ? ["长长的", "投影"] : ["LONG", "SHADOW"]
        let fontSize: CGFloat = ctx.language == .zh ? 62 : 54
        let font: Font = .system(size: fontSize, weight: .black, design: .rounded)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let lineHeight: CGFloat = fontSize * 1.08
        let length: Double = ctx["length"]

        // Where the light is, and the shadow vector it asks for.
        var state = sim.value
        var dt: Double = 0
        if let last = state.last {
            dt = min(max(date.timeIntervalSince(last), 0), 1.0 / 20.0)
        }
        state.last = date
        if finger == nil && !ctx.isStill { state.phase += dt * 0.8 }
        let light: CGPoint = finger ?? orbit(state.phase, center: center)
        let awayX: Double = Double(center.x - light.x)
        let awayY: Double = Double(center.y - light.y)
        let distance: Double = max((awayX * awayX + awayY * awayY).squareRoot(), 1)
        let reach: Double = length * (1 + 0.2 * min(max((distance - 100) / 60, 0), 1))
        let targetX: Double = awayX / distance * reach
        let targetY: Double = awayY / distance * reach
        if !state.seeded || ctx.isStill {
            state.x.value = targetX
            state.y.value = targetY
            state.seeded = true
        } else {
            state.x.step(to: targetX, dt: dt, response: ctx["response"], damping: 0.7)
            state.y.step(to: targetY, dt: dt, response: ctx["response"], damping: 0.7)
        }
        sim.value = state
        let vector = CGPoint(x: state.x.value, y: state.y.value)
        let extent: Double = max(Double(hypot(vector.x, vector.y)), 1)
        let steps: Int = min(max(Int(extent.rounded()), 1), 150)

        // The light.
        let glowRadius: CGFloat = 34
        let glowRect = CGRect(x: light.x - glowRadius, y: light.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [Palette.amber.opacity(0.55), Palette.amber.opacity(0)]),
                center: light,
                startRadius: 2,
                endRadius: glowRadius
            )
        )
        context.fill(Path(ellipseIn: CGRect(x: light.x - 7, y: light.y - 7, width: 14, height: 14)), with: .color(Palette.amber))

        // Shadow copies, far to near. Each copy first erases its own footprint, then draws at its own
        // opacity, so a nearer copy replaces what is beneath it and the fade stays exact and smooth.
        let solid: Bool = ctx.int("style") == 1
        let shades: [[GraphicsContext.ResolvedText]] = (0..<Self.bands).map { band in
            let color = bandColor(Double(band) / Double(Self.bands - 1))
            return lines.map { context.resolve(Text(verbatim: $0).font(font).foregroundColor(color)) }
        }
        var erase = context
        erase.blendMode = .destinationOut
        var shadow = context
        for step in stride(from: steps, through: 1, by: -1) {
            let u: Double = Double(step) / Double(steps)
            let band: Int = min(Int(u * Double(Self.bands)), Self.bands - 1)
            shadow.opacity = solid ? 1 : 0.92 * pow(1 - u, 1.25)
            let dx: CGFloat = vector.x * CGFloat(u)
            let dy: CGFloat = vector.y * CGFloat(u)
            for row in lines.indices {
                let y: CGFloat = center.y + (CGFloat(row) - CGFloat(lines.count - 1) / 2) * lineHeight
                let point = CGPoint(x: center.x + dx, y: y + dy)
                if !solid { erase.draw(shades[band][row], at: point, anchor: .center) }
                shadow.draw(shades[band][row], at: point, anchor: .center)
            }
        }

        // The face.
        for (row, line) in lines.enumerated() {
            let y: CGFloat = center.y + (CGFloat(row) - CGFloat(lines.count - 1) / 2) * lineHeight
            let face = context.resolve(Text(verbatim: line).font(font).foregroundColor(.primary))
            context.draw(face, at: CGPoint(x: center.x, y: y), anchor: .center)
        }
    }
}
