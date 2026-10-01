import SwiftUI

extension Effect {
    static let backgroundsMatrixRain = Effect(
        id: "backgrounds.matrix-rain",
        category: .backgrounds,
        interaction: .tap,
        name: L("Digital Rain", "数字雨"),
        summary: L(
            "Columns of glyphs fall with white-hot heads and fading trails; a tap sends a decoding pulse through the code.",
            "字符成列坠落，头部白热、尾迹渐隐；点击会有一圈解码脉冲扫过整片代码。"
        ),
        prompt: L(
            "A black-green terminal filled with a monospaced grid of half-width katakana and digits, 15 pt glyphs. Each column carries two independent streams that fall in whole-row steps at 5–14 rows/s. The head glyph is white with a soft bloom; behind it a trail about 16 rows long fades with a (1 − d/L)^1.4 curve from bright green to nothing. Glyphs in the trail keep mutating: every cell re-rolls its character at its own rate of 0.3–2.3 changes/s, and columns sit at different depths, the far ones at 45% brightness. Tapping sends a circular pulse outward at 420 pt/s: a 26 pt wide ring that flashes every cell it crosses to white, even dark ones, revealing the hidden grid before fading over about a second. A rigid haptic marks the tap. Cold, cryptic, cinematic.",
            "黑绿色的终端铺满等宽字符网格：半角片假名与数字，字号 15pt。每一列带着两股独立的字符流，以每秒 5–14 行的速度整行跳落。头部字符为白色并带柔和辉光；身后约 16 行的尾迹按 (1 − d/L)^1.4 由亮绿渐隐至无。尾迹里的字符不断变异：每个格子以各自 0.3–2.3 次/秒的频率重掷字符；各列处于不同景深，远处的列只有 45% 亮度。点击会发出一圈以 420pt/s 扩散的脉冲：宽 26pt 的环把经过的每个格子（包括熄灭的）闪成白色，显露隐藏的网格，约一秒内淡去。并伴随清脆触感。冷峻而神秘。"
        ),
        implementation: L(
            "Glyphs are Canvas symbols (Text views resolved once per frame in tint and in white); each cell's brightness is analytic from its column's stream phases, so the renderer just sets context.opacity and draws the cached symbol. Head blooms go into one blurred plusLighter layer.",
            "字符是 Canvas 的 symbols（每帧只解析一次的着色与白色 Text）；每个格子的亮度由所在列字符流的相位解析得出，渲染时只需设置 context.opacity 并绘制缓存好的符号。头部辉光统一画在一个模糊的 plusLighter 图层里。"
        ),
        apis: ["Canvas(symbols:)", "GraphicsContext.resolveSymbol(id:)", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "Haptics"],
        tags: ["matrix", "digital rain", "glyphs", "code", "数字雨", "黑客帝国", "字符", "代码"],
        params: [
            .slider("glyph", L("Glyph size", "字符大小"), 10...22, default: 15, step: 1, decimals: 0, unit: "pt"),
            .slider("speed", L("Fall speed", "下落速度"), 0.3...2.5, default: 1.0, unit: "×"),
            .slider("trail", L("Trail length", "尾迹长度"), 5...30, default: 16, step: 1, decimals: 0),
            .choice("tint", L("Phosphor", "荧光色"), [L("Green", "绿"), L("Amber", "琥珀"), L("Ice", "冰蓝")]),
        ]
    ) { ctx in
        MatrixRainDemo(ctx: ctx)
    }
}

private struct MatrixPulse {
    let origin: CGPoint
    let born: Double
}

private final class MatrixModel {
    let clock = BackgroundClock()
    private(set) var pulses: [MatrixPulse] = []

    func pulse(at point: CGPoint) {
        pulses.append(MatrixPulse(origin: point, born: clock.phase))
        if pulses.count > 4 { pulses.removeFirst(pulses.count - 4) }
    }

    func step(now: Double) -> Double {
        let t = clock.advance(to: now, speed: 1)
        pulses.removeAll { t - $0.born > 2.2 }
        return t
    }
}

private struct MatrixRainDemo: View {
    let ctx: DemoContext
    @State private var model = MatrixModel()
    @State private var flow = BackgroundClock()
    @State private var size = CGSize(width: 340, height: 340)

    private static let glyphs: [String] = Array("ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎ0123456789").map(String.init)
    private static let tints: [Color] = [Color(hex: 0x3DFF8A), Color(hex: 0xFFB63D), Color(hex: 0x7CD8FF)]
    private static let grounds: [[Color]] = [
        [Color(hex: 0x010604), Color(hex: 0x04150D)],
        [Color(hex: 0x070401), Color(hex: 0x170E04)],
        [Color(hex: 0x01040A), Color(hex: 0x051222)],
    ]

    var body: some View {
        let index = min(max(ctx.int("tint"), 0), Self.tints.count - 1)
        let tint = Self.tints[index]
        let glyphSize = max(ctx.cg("glyph"), 6)
        ZStack {
            LinearGradient(colors: Self.grounds[index], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let wall = model.step(now: now)
                let t = flow.advance(to: now, speed: ctx["speed"])
                Canvas { context, size in
                    MatrixPainter.draw(
                        &context, size: size, t: t, wall: wall, pulses: model.pulses,
                        glyph: glyphSize, trail: max(ctx["trail"], 2), count: Self.glyphs.count, tint: tint
                    )
                } symbols: {
                    // One ForEach: every symbol needs its own identity (tags 0..<n tinted, n..<2n white heads).
                    ForEach(0..<(Self.glyphs.count * 2), id: \.self) { k in
                        let head = k >= Self.glyphs.count
                        Text(Self.glyphs[k % Self.glyphs.count])
                            .font(.system(size: glyphSize, weight: head ? .semibold : .medium, design: .monospaced))
                            .foregroundStyle(head ? Color.white : tint)
                            .tag(k)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.rigid)
            model.pulse(at: location)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .autoplay(ctx.isPreview, every: 3.2, delay: 1.0) {
            model.pulse(at: CGPoint(x: size.width * CGFloat.random(in: 0.25...0.75), y: size.height * CGFloat.random(in: 0.25...0.75)))
        }
        .backgroundsChipHint(L("Tap to send a pulse through the code", "点击向代码中发出一圈脉冲"), ctx)
    }
}

private enum MatrixPainter {
    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, wall: Double, pulses: [MatrixPulse],
        glyph: CGFloat, trail: Double, count: Int, tint: Color
    ) {
        var green: [GraphicsContext.ResolvedSymbol?] = []
        var white: [GraphicsContext.ResolvedSymbol?] = []
        for i in 0..<count {
            green.append(context.resolveSymbol(id: i))
            white.append(context.resolveSymbol(id: count + i))
        }
        let cellW = glyph * 0.95
        let cellH = glyph * 1.18
        let cols = Int((size.width / cellW).rounded(.up))
        let rows = Int((size.height / cellH).rounded(.up)) + 1
        let offsetX = (size.width - CGFloat(cols) * cellW) / 2 + cellW / 2
        var blooms = Path()

        for c in 0..<cols {
            let depth = 0.45 + 0.55 * BackgroundMath.rand(c, 801)
            // Two streams per column: (head row, trail length).
            var heads: [(row: Int, length: Double)] = []
            for s in 0..<2 {
                let key = c * 2 + s
                let length = trail * (0.6 + 0.8 * BackgroundMath.rand(key, 802))
                let speed = 5 + 9 * BackgroundMath.rand(key, 803)
                let cycle = Double(rows) + length + Double(rows) * 0.9 * BackgroundMath.rand(key, 804)
                let head = BackgroundMath.fract(BackgroundMath.rand(key, 805) + t * speed / cycle) * cycle
                heads.append((Int(head.rounded(.down)), length))
            }
            let x = offsetX + CGFloat(c) * cellW
            for r in 0..<rows {
                var brightness = 0.0
                var isHead = false
                for head in heads {
                    let d = head.row - r
                    guard d >= 0, Double(d) <= head.length else { continue }
                    if d == 0 { isHead = true }
                    brightness = max(brightness, pow(1 - Double(d) / head.length, 1.4))
                }
                let y = (CGFloat(r) + 0.5) * cellH
                var flash = 0.0
                for pulse in pulses {
                    let age = wall - pulse.born
                    let distance = Double(hypot(x - pulse.origin.x, y - pulse.origin.y))
                    let offset = (distance - age * 420) / 26
                    flash = max(flash, exp(-offset * offset) * exp(-age * 1.2))
                }
                let lit = max(brightness * depth, flash)
                guard lit > 0.035 else { continue }
                let cell = c * 977 + r * 131
                let roll = Int((t * (0.3 + 2 * BackgroundMath.rand(cell, 806))).rounded(.down))
                let which = min(Int(BackgroundMath.rand(cell + roll * 7, 807) * Double(count)), count - 1)
                let point = CGPoint(x: x, y: y)
                let bright = isHead || flash > 0.35
                if let symbol = bright ? white[which] : green[which] {
                    context.opacity = bright ? max(lit, 0.9 * depth + 0.1) : lit
                    context.draw(symbol, at: point)
                }
                if isHead {
                    let radius = glyph * 0.62
                    blooms.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                }
            }
        }
        context.opacity = 1
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: glyph * 0.5))
            layer.blendMode = .plusLighter
            layer.fill(blooms, with: .color(tint.opacity(0.3)))
        }
        // Tube vignette.
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let shade = Gradient(stops: [.init(color: .clear, location: 0.5), .init(color: .black.opacity(0.6), location: 1)])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(shade, center: centre, startRadius: 0, endRadius: hypot(size.width, size.height) * 0.6)
        )
    }
}
