import SwiftUI

extension Effect {
    static let shaderPrism = Effect(
        id: "shader.prism",
        category: .shaders,
        interaction: .gesture,
        name: L("Prism Dispersion", "棱镜色散"),
        summary: L(
            "Slide a glass prism over white type: it splits the picture at its ridge and fringes every edge with a spectrum.",
            "把一根玻璃棱镜滑过白色大字：画面在棱脊处错开，每条边缘都镶上光谱色边。"
        ),
        prompt: L(
            "A 64 pt wide bar of glass with a triangular profile lies at 72° across a black poster set in heavy white type. Its two facets refract in opposite directions, so the letters behind it break at the ridge and shift up to 18 pt sideways. Seven wavelengths are sampled with offsets spread 60% around that shift and recombined, leaving red-to-violet fringes on every stroke, while a soft rainbow is cast on the poster beside the exit face. Facet shading, a bright ridge line and bevels draw the glass. Dragging carries the bar with the finger and leans it up to 14° with the drag speed; on release it swings upright with a wobble (response 0.5 s, damping 0.4). Optical, crisp and jewel-like.",
            "一根宽 64pt、截面为三角形的玻璃棱镜，以 72° 斜放在一张白色粗体大字的黑色海报上。它的两个棱面朝相反方向折射，身后的字母因此在棱脊处断开，向两侧错位最多 18pt。着色器对七个波长分别采样，偏移量围绕该错位展开 60%，再重新合成，于是每一笔画都镶上从红到紫的色边；出射面旁的海报上还投着一道柔和的彩虹。棱面明暗、明亮的棱脊线与两侧的倒角勾勒出玻璃的体积。拖动时棱镜跟随手指，并随拖动速度倾斜最多 14°；松手后带着摆动回正（响应 0.5 秒、阻尼 0.4）。光学感、锐利，像一件珠宝。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader measures each pixel's position across the bar, picks the facet's constant slope and averages seven samples displaced along the bar's normal with triangular R/G/B response weights; facet shading, ridge and bevel highlights and the cast rainbow are added analytically. Position and lean are Animatable.",
            "[[stitchable]] layerEffect 着色器计算像素在棱镜横截方向上的位置，取所在棱面的恒定斜率，沿棱镜法线对七个偏移采样并以三角形的 R/G/B 响应权重平均；棱面明暗、棱脊与倒角高光以及投射的彩虹都以解析方式叠加。位置与倾角为 Animatable。"
        ),
        apis: ["layerEffect", "Animatable", "DragGesture.Value.velocity", "spring(response:dampingFraction:)", "Metal"],
        tags: ["prism", "dispersion", "spectrum", "rainbow", "refraction", "棱镜", "色散", "光谱", "彩虹", "折射"],
        params: [
            .slider("angle", L("Bar angle", "棱镜角度"), 45...135, default: 72, decimals: 0, unit: "°"),
            .slider("width", L("Bar width", "棱镜宽度"), 30...110, default: 64, decimals: 0, unit: "pt"),
            .slider("bend", L("Refraction", "折射位移"), 4...40, default: 18, decimals: 0, unit: "pt"),
            .slider("dispersion", L("Dispersion", "色散"), 0...1, default: 0.6),
        ]
    ) { ctx in
        PrismDemo(ctx: ctx)
    }
}

private struct PrismDemo: View {
    let ctx: DemoContext
    @State private var x: CGFloat
    @State private var lean: Double = 0
    @State private var grab: CGFloat = 0
    @State private var toRight = true
    @State private var settle = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _x = State(initialValue: ctx.isStill ? 118 : 92)
    }

    var body: some View {
        let angle = ctx["angle"] * .pi / 180
        VStack(spacing: 14) {
            ShaderTypeScene()
                .modifier(PrismModifier(
                    x: x, lean: lean, angle: angle, width: ctx["width"], bend: ctx["bend"], dispersion: ctx["dispersion"]
                ))
                .shaderCard(glow: Color(hex: 0x7A5CFF, opacity: 0.3))
                .shaderTouch(
                    onBegan: { point in
                        settle += 1
                        grab = x - point.x
                        if abs(grab) > 60 { grab = 0 }
                        Haptics.tap(.soft)
                    },
                    onMoved: { point, velocity in
                        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.82)) {
                            x = (point.x + grab).clamped(to: 20...ShaderKit.card.width - 20)
                            lean = Double(velocity.width * 0.0005).clamped(to: -0.25...0.25)
                        }
                    },
                    onEnded: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) { lean = 0 }
                    },
                    onTap: { point in
                        Haptics.tap(.soft)
                        glide(to: point.x)
                    }
                )
            DemoHint(text: L("Drag the prism across the type", "拖动棱镜划过文字"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.3, delay: 0.4) {
            glide(to: toRight ? 186 : 78)
            toRight.toggle()
        }
    }

    /// Tap (and the autoplay): the bar glides to `target`, leaning into the move, then swings upright.
    private func glide(to target: CGFloat) {
        settle += 1
        let token = settle
        let direction: Double = target > x ? 1 : -1
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
            x = target.clamped(to: 20...ShaderKit.card.width - 20)
        }
        withAnimation(.easeOut(duration: 0.18)) { lean = 0.2 * direction }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            guard token == settle else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) { lean = 0 }
        }
    }
}

private struct PrismModifier: ViewModifier, Animatable {
    var x: CGFloat
    var lean: Double
    var angle: Double
    var width: Double
    var bend: Double
    var dispersion: Double

    var animatableData: AnimatablePair<CGFloat, Double> {
        get { AnimatablePair(x, lean) }
        set {
            x = newValue.first
            lean = newValue.second
        }
    }

    func body(content: Content) -> some View {
        let reach = 1.25 * bend * (1 + dispersion) + 2
        content.layerEffect(
            ShaderLibrary.mlPrism(
                .float2(x, ShaderKit.card.height / 2),
                .float(angle + lean),
                .float(width),
                .float(bend),
                .float(dispersion)
            ),
            maxSampleOffset: CGSize(width: reach, height: reach)
        )
    }
}
