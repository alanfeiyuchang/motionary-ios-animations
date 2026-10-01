import SwiftUI

extension Effect {
    static let shaderAscii = Effect(
        id: "shader.ascii",
        category: .shaders,
        interaction: .gesture,
        name: L("ASCII Decode", "ASCII 字符画"),
        summary: L(
            "Drag a divider across live artwork: one side stays a picture, the other is typed out in characters.",
            "在动态画面上拖动分割线：一侧仍是图像，另一侧被逐格“打”成字符。"
        ),
        prompt: L(
            "A moving sunset scene is split by a glowing vertical divider. Left of it is the original picture; right of it a Metal shader redraws everything as a terminal character grid: each 6 × 10 pt cell samples the luminance at its center and shows one of ten 5×7 bitmap glyphs of rising density — space . : - = + * # % @ — tinted with the source colour on near-black. Levels are dithered about six times a second, so the text keeps flickering like a live feed. Within 28 pt of the divider the cells show random glyphs re-rolled 12 times a second, a bright decoding front. Dragging moves the divider under the finger; a tap sends it there on a spring (response 0.55 s, damping 0.8). Nerdy, crisp and alive.",
            "流动的落日画面被一条发光的竖直分割线一分为二。线的左侧是原始图像；右侧由 Metal 着色器把一切重绘成终端字符网格：每个 6 × 10pt 的格子在中心采样亮度，从十个密度递增的 5×7 点阵字符（空格 . : - = + * # % @）中选出一个，用原图颜色着色，衬在近黑的底上。亮度等级每秒抖动约 6 次，文字像实时信号般不停闪动。分割线右侧 28pt 以内的格子显示随机字符，每秒重掷 12 次，形成明亮的“解码前沿”。拖动时分割线紧跟手指；点击则以弹簧（响应 0.55 秒、阻尼 0.8）滑到该处。极客、清脆、鲜活。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader quantizes position into cells, samples the cell center for luminance and looks the glyph pixel up in bitmaps packed three 5-bit rows per float (no integer ops); a hash re-rolled with time scrambles cells near the divider. The divider x is Animatable; a TimelineView animates the artwork underneath.",
            "[[stitchable]] layerEffect 着色器把坐标量化为字符格，在格心采样亮度，并从“每个浮点数打包三行、每行 5 位”的点阵中查出字形像素（不需要整数运算）；随时间重掷的哈希把分割线附近的格子打乱。分割线的 x 坐标是 Animatable，下方的画面由 TimelineView 驱动。"
        ),
        apis: ["layerEffect", "Animatable", "TimelineView", "DragGesture", "Metal"],
        tags: ["ascii", "terminal", "text art", "retro", "matrix", "字符画", "终端", "复古", "代码"],
        params: [
            .slider("cell", L("Cell height", "字符高度"), 6...18, default: 10, decimals: 0, unit: "pt"),
            .choice("mode", L("Ink", "着色"), [L("Colour", "原色"), L("Phosphor", "荧光绿"), L("Paper", "纸墨")]),
            .slider("band", L("Decode front", "解码前沿"), 0...60, default: 28, decimals: 0, unit: "pt"),
            .slider("contrast", L("Contrast", "对比度"), 0.6...2, default: 1.3, decimals: 1),
        ]
    ) { ctx in
        AsciiDemo(ctx: ctx)
    }
}

/// Moving source artwork: a sun whose highlight orbits, a moon crossing it and rolling dunes of light.
private struct AsciiLiveScene: View {
    let time: Double

    var body: some View {
        let light = UnitPoint(x: 0.5 + 0.32 * cos(time * 0.9), y: 0.5 + 0.32 * sin(time * 0.9))
        ZStack {
            LinearGradient(
                gradient: ShaderKit.gradient([0x0B1030, 0x3A1C71, 0xD76D77, 0xFFAF7B]),
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(RadialGradient(
                    colors: [.white, Color(hex: 0xFFD27A), Color(hex: 0xFF6F61), Color(hex: 0x5B2A86)],
                    center: light, startRadius: 2, endRadius: 96
                ))
                .frame(width: 150, height: 150)
                .offset(y: -34)
            Circle()
                .fill(Color.white)
                .frame(width: 26, height: 26)
                .offset(x: CGFloat(104 * cos(time * 0.7)), y: CGFloat(-34 + 46 * sin(time * 0.7)))
            Canvas { context, size in
                for band in 0..<4 {
                    let base = size.height * (0.66 + 0.09 * CGFloat(band))
                    var wave = Path()
                    wave.move(to: CGPoint(x: 0, y: size.height))
                    var x: CGFloat = 0
                    while x <= size.width + 6 {
                        let phase = Double(x) / 34 + time * (0.9 + 0.35 * Double(band)) + Double(band) * 1.7
                        wave.addLine(to: CGPoint(x: x, y: base + CGFloat(sin(phase)) * 9))
                        x += 6
                    }
                    wave.addLine(to: CGPoint(x: size.width, y: size.height))
                    wave.closeSubpath()
                    let shade = [0x2A1B5E, 0x5B2A86, 0x1B1444, 0x0B0A24][band]
                    context.fill(wave, with: .color(Color(hex: UInt32(shade))))
                    // A bright crest so the dunes read in luminance, not only in hue.
                    var crest = Path()
                    x = 0
                    while x <= size.width + 6 {
                        let phase = Double(x) / 34 + time * (0.9 + 0.35 * Double(band)) + Double(band) * 1.7
                        let point = CGPoint(x: x, y: base + CGFloat(sin(phase)) * 9)
                        if x == 0 { crest.move(to: point) } else { crest.addLine(to: point) }
                        x += 6
                    }
                    context.stroke(crest, with: .color(Color(hex: 0xFFC9A0, opacity: 0.75 - 0.15 * Double(band))), lineWidth: 2.5)
                }
            }
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

private struct AsciiDemo: View {
    let ctx: DemoContext
    @State private var divider: CGFloat = 96
    @State private var toRight = true

    var body: some View {
        let cell = ctx["cell"]
        let mode = Double(ctx.int("mode"))
        let band = ctx["band"]
        let contrast = ctx["contrast"]
        VStack(spacing: 14) {
            ShaderClock(preview: ctx.isPreview) { time in
                AsciiLiveScene(time: ctx.isStill ? 1.4 : time)
                    .modifier(AsciiModifier(
                        divider: divider, cell: cell, mode: mode, band: band, contrast: contrast,
                        time: ctx.isStill ? 1.4 : time
                    ))
            }
            .shaderCard(glow: Color(hex: 0x5B2A86, opacity: 0.4))
            .shaderTouch(
                onBegan: { _ in Haptics.selection() },
                onMoved: { point, _ in
                    withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.86)) {
                        divider = point.x.clamped(to: 8...ShaderKit.card.width - 8)
                    }
                },
                onTap: { point in
                    Haptics.selection()
                    slide(to: point.x)
                }
            )
            DemoHint(text: L("Drag the divider, or tap to send it", "拖动分割线，或点击让它滑过去"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.2, delay: 0.4) {
            slide(to: toRight ? 222 : 44)
            toRight.toggle()
        }
    }

    private func slide(to x: CGFloat) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
            divider = x.clamped(to: 8...ShaderKit.card.width - 8)
        }
    }
}

private struct AsciiModifier: ViewModifier, Animatable {
    var divider: CGFloat
    var cell: Double
    var mode: Double
    var band: Double
    var contrast: Double
    var time: Double

    var animatableData: CGFloat {
        get { divider }
        set { divider = newValue }
    }

    func body(content: Content) -> some View {
        content
            .layerEffect(
                ShaderLibrary.mlAscii(
                    .float(cell),
                    .float(divider),
                    .float(band),
                    .float(time),
                    .float(mode),
                    .color(Color(hex: 0x4DFF88)),
                    .float(contrast)
                ),
                maxSampleOffset: CGSize(width: cell, height: cell)
            )
            .overlay(alignment: .topLeading) { handle }
            .overlay(alignment: .top) { labels }
    }

    /// The grab handle rides the animated divider, so it never lags behind the shader.
    private var handle: some View {
        Capsule()
            .fill(Color.white)
            .frame(width: 26, height: 44)
            .overlay {
                Image(systemName: "chevron.left.chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x14162B))
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            .offset(x: divider - 13, y: ShaderKit.card.height / 2 - 22)
            .allowsHitTesting(false)
    }

    private var labels: some View {
        HStack {
            tag("RAW").opacity(divider > 62 ? 1 : 0)
            Spacer()
            tag("TXT").opacity(divider < ShaderKit.card.width - 62 ? 1 : 0)
        }
        .padding(14)
        .allowsHitTesting(false)
    }

    private func tag(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.45), in: Capsule())
    }
}
