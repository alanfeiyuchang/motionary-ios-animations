import SwiftUI

extension Effect {
    static let shaderInkBleed = Effect(
        id: "shader.ink-bleed",
        category: .shaders,
        interaction: .tap,
        name: L("Ink Bleed", "墨迹晕染"),
        summary: L(
            "The next scene soaks in from your tap like ink into paper, wicking along fibres with a dark wet edge.",
            "下一幕从触点像墨水渗入宣纸般晕开，沿纸纤维蔓延，边缘带一圈深色湿痕。"
        ),
        prompt: L(
            "Tapping the sheet drops ink on it, and the next scene bleeds in from that point over 2.2 s — fast at first, then slowing like real diffusion. The front is not a circle: blotchy fractal absorbency pushes it out in lobes, long thin fibres running both ways wick the ink ahead in hair-fine streaks, and two smaller satellite blots land nearby 28% and 42% later and merge into the main stain. Pigment collects at the wet front, so a darker line rides the edge and the freshly soaked area stays about 14% darker until it dries during the last fifth of the run. The edge is feathered and grainy, never a hard mask. Organic, calm and handmade.",
            "点击纸面，墨便落在那里，下一幕在 2.2 秒内从触点晕染开来——起初很快，随后像真实的扩散一样渐渐放慢。晕染的前沿并不是正圆：斑驳的分形吸水性把它推成一瓣一瓣，纵横两个方向的细长纸纤维把墨汁提前吸出发丝般的细线，另有两滴较小的卫星墨点晚 28% 与 42% 落在附近，最终并入主墨迹。颜料在湿润的前沿聚集，边缘因此带着一道更深的线，刚浸湿的区域也暗约 14%，直到全程最后五分之一才逐渐干透。边缘是带颗粒的羽化过渡，绝不是生硬的遮罩。有机、沉静、带着手工的温度。"
        ),
        implementation: L(
            "A [[stitchable]] color shader on the incoming scene builds an arrival field (distance to the tap and two satellites, warped by fbm and by two anisotropic fibre noises), compares it with the animated progress for a feathered alpha and tints a band behind the front with the pigment colour; progress is Animatable with a decelerating timing curve.",
            "作用于新画面的 [[stitchable]] colorEffect 着色器构建“到达场”（到触点及两个卫星点的距离，再经 fbm 与两组各向异性的纤维噪声扭曲），与动画进度比较得到羽化的透明度，并把前沿后方的一条带染上颜料色；进度为 Animatable，采用减速的时间曲线。"
        ),
        apis: ["colorEffect", "Animatable", "timingCurve", "onTapGesture(coordinateSpace:)", "Metal"],
        tags: ["ink", "bleed", "watercolor", "paper", "transition", "墨迹", "晕染", "水墨", "宣纸", "转场"],
        params: [
            .slider("duration", L("Duration", "时长"), 1...4, default: 2.2, decimals: 1, unit: "s"),
            .slider("rough", L("Blotchiness", "斑驳程度"), 0...1, default: 0.6),
            .slider("fibre", L("Fibre wicking", "纤维渗吸"), 0...1, default: 0.55),
            .slider("edge", L("Wet edge", "湿边深度"), 0...1, default: 0.6),
        ]
    ) { ctx in
        InkBleedDemo(ctx: ctx)
    }
}

private struct InkSheet {
    let paper: UInt32
    let ink: UInt32
    let pigment: UInt32
    let glyph: String
    let caption: String
    let offset: CGSize

    static let all: [InkSheet] = [
        InkSheet(paper: 0xF2EADB, ink: 0x1A1A20, pigment: 0x6B5A3E, glyph: "墨", caption: "INK · 01", offset: CGSize(width: -8, height: -12)),
        InkSheet(paper: 0x1D3461, ink: 0xF2EADB, pigment: 0x0A1530, glyph: "水", caption: "WATER · 02", offset: CGSize(width: 10, height: 6)),
        InkSheet(paper: 0xB5362A, ink: 0xFBEFD9, pigment: 0x5A100B, glyph: "山", caption: "MOUNTAIN · 03", offset: CGSize(width: -4, height: 10)),
        InkSheet(paper: 0x15151A, ink: 0xE5B769, pigment: 0x000000, glyph: "風", caption: "WIND · 04", offset: CGSize(width: 8, height: -8)),
    ]

    static func at(_ index: Int) -> InkSheet {
        all[((index % all.count) + all.count) % all.count]
    }
}

/// A sheet of dyed paper with one brushed character, a wash behind it, fibres and a seal.
private struct InkPaperScene: View {
    let sheet: InkSheet

    var body: some View {
        ZStack {
            Color(hex: sheet.paper)
            Canvas { context, size in
                let ink = Color(hex: sheet.ink)
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 18))
                    layer.fill(
                        Path(ellipseIn: CGRect(x: size.width * 0.5 - 86 + sheet.offset.width, y: size.height * 0.46 - 86 + sheet.offset.height, width: 172, height: 172)),
                        with: .color(ink.opacity(0.14))
                    )
                }
                // Paper fibres.
                for i in 0..<120 {
                    let p = CGPoint(x: ShaderKit.rand(i, 51) * size.width, y: ShaderKit.rand(i, 52) * size.height)
                    let angle = ShaderKit.rand(i, 53) * .pi
                    let length = 5 + ShaderKit.rand(i, 54) * 13
                    var fibre = Path()
                    fibre.move(to: p)
                    fibre.addLine(to: CGPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length))
                    context.stroke(fibre, with: .color(ink.opacity(0.07)), lineWidth: 0.7)
                }
            }
            Text(verbatim: sheet.glyph)
                .font(.system(size: 158, weight: .black, design: .serif))
                .foregroundStyle(Color(hex: sheet.ink))
                .offset(sheet.offset)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Text(verbatim: sheet.caption)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Color(hex: sheet.ink).opacity(0.75))
                    Spacer()
                    Text(verbatim: "印")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: 0xFBEFD9))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: 0xC8372D), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color(hex: 0xFBEFD9, opacity: 0.5), lineWidth: 1))
                }
            }
            .padding(20)
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }
}

private struct InkBleedDemo: View {
    let ctx: DemoContext
    @State private var current = 0
    @State private var progress: Double
    @State private var origin = CGPoint(x: 150, y: 130)
    @State private var seed: Double = 2.3
    @State private var busy = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the stain half-spread.
        _progress = State(initialValue: ctx.isStill ? 0.5 : 0)
    }

    var body: some View {
        let next = InkSheet.at(current + 1)
        VStack(spacing: 14) {
            ZStack {
                InkPaperScene(sheet: InkSheet.at(current))
                InkPaperScene(sheet: next)
                    .modifier(InkBleedModifier(
                        progress: progress, origin: origin, rough: ctx["rough"], fibre: ctx["fibre"],
                        edge: ctx["edge"], pigment: Color(hex: next.pigment), seed: seed
                    ))
            }
            .shaderCard()
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in bleed(from: location) }
            DemoHint(text: L("Tap to drop ink", "点击落墨"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 0.9, delay: 0.4) {
            bleed(from: CGPoint(x: CGFloat.random(in: 60...200), y: CGFloat.random(in: 70...230)))
        }
    }

    private func bleed(from point: CGPoint) {
        guard !busy else { return }
        busy = true
        origin = point
        seed = Double.random(in: 0...30)
        Haptics.tap(.soft)
        // Fast at first, then slowing, like diffusion.
        withAnimation(.timingCurve(0.25, 0.5, 0.45, 1, duration: ctx["duration"])) {
            progress = 1
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                current += 1
                progress = 0
            }
            busy = false
        }
    }
}

private struct InkBleedModifier: ViewModifier, Animatable {
    var progress: Double
    var origin: CGPoint
    var rough: Double
    var fibre: Double
    var edge: Double
    var pigment: Color
    var seed: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        // The shader hides the incoming scene; at rest it is simply not drawn.
        content
            .colorEffect(
                ShaderLibrary.mlInkBleed(
                    .float2(ShaderKit.card),
                    .float2(origin),
                    .float(progress),
                    .float(rough),
                    .float(fibre),
                    .float(edge),
                    .color(pigment),
                    .float(seed)
                )
            )
            .opacity(progress > 0.0001 ? 1 : 0)
    }
}
