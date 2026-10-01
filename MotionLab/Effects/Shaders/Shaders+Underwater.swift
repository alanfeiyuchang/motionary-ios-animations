import SwiftUI

extension Effect {
    static let shaderUnderwater = Effect(
        id: "shader.underwater",
        category: .shaders,
        interaction: .tap,
        name: L("Underwater", "水下视界"),
        summary: L(
            "A reef seen from below the surface: swell, light shafts, colours fading with depth, and bubbles from your tap.",
            "从水面之下看珊瑚礁：水流晃动、光柱斜射、颜色随深度褪去，点击吐出一串气泡。"
        ),
        prompt: L(
            "A coral reef card is seen from under water. The picture sways on a slow swell, about 3 pt and stronger toward the sea floor. Water takes red first: reds dim far faster than blues and everything fogs toward a teal that deepens with the depth setting. Soft light shafts fan down from a point above the frame and drift sideways, and a fine net of light dapples the sand. Small bubbles rise in their own columns; each is a tiny lens with a bright rim and a glint. Tapping exhales: eight bubbles of different sizes leave the finger within 0.3 s, accelerate upward, spread apart and fade after about 2 s. Calm, weightless and sunlit.",
            "一张珊瑚礁卡片，从水下看去。画面随缓慢的涌流晃动，幅度约 3pt，越靠近海底越明显。水最先吸收红色：红色比蓝色暗得快得多，整体蒙上一层青蓝的水雾，并随“深度”加深。柔和的光柱从画面上方一点呈扇形射下、缓缓横移，沙地上有一张细密的光网在游动。小气泡各自沿一列上升，每一颗都是带亮边和高光的小透镜。点击即吐气：八颗大小不一的气泡在 0.3 秒内离开指尖，加速上浮、彼此散开，约 2 秒后消失。宁静、失重、阳光通透。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader displaces the sample by a sine + gradient-noise swell, multiplies the colour by e^(−depth × (2.3, 0.75, 0.32)), adds angular-noise light shafts and a ridged-noise dapple, and sums small lens offsets for six ambient and eight tapped bubbles; a TimelineView feeds time and the tap's age.",
            "[[stitchable]] layerEffect 着色器用正弦加梯度噪声的涌流偏移采样，把颜色乘以 e^(−深度 × (2.3, 0.75, 0.32))，叠加按角度取噪声的光柱与脊状噪声光斑，并累加六颗环境气泡与八颗点击气泡的小透镜偏移；TimelineView 提供时间与点击后的时长。"
        ),
        apis: ["layerEffect", "TimelineView", "onTapGesture(coordinateSpace:)", "Metal"],
        tags: ["underwater", "water", "ocean", "bubbles", "god rays", "水下", "海底", "气泡", "光柱", "折射"],
        params: [
            .slider("wobble", L("Swell", "涌流幅度"), 0...8, default: 3, decimals: 1, unit: "pt"),
            .slider("rays", L("Light shafts", "光柱"), 0...1, default: 0.7),
            .slider("depth", L("Depth", "深度"), 0...1, default: 0.4),
            .slider("bubbles", L("Ambient bubbles", "环境气泡"), 0...1, default: 0.7),
        ]
    ) { ctx in
        UnderwaterDemo(ctx: ctx)
    }
}

private struct UnderwaterDemo: View {
    let ctx: DemoContext
    @State private var clock = BackgroundClock(start: 20)
    @State private var burst = CGPoint(x: 150, y: 236)
    @State private var burstStart = Date.distantPast

    var body: some View {
        let wobble = ctx["wobble"]
        let rays = ctx["rays"]
        let depth = ctx["depth"]
        let bubbles = ctx["bubbles"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let time = ctx.isStill ? 21.5 : clock.advance(to: timeline.date.timeIntervalSinceReferenceDate, speed: 1)
                let since = timeline.date.timeIntervalSince(burstStart)
                let age = ctx.isStill ? 0.9 : (since < 3 ? since : -1)
                ShaderReefScene()
                    .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                    .layerEffect(
                        ShaderLibrary.mlUnderwater(
                            .float2(ShaderKit.card), .float(time), .float(wobble), .float(rays), .float(depth),
                            .float(bubbles), .float2(burst), .float(age)
                        ),
                        maxSampleOffset: CGSize(width: wobble * 3.4 + 12, height: wobble * 3.4 + 12)
                    )
            }
            .shaderCard(glow: Color(hex: 0x1B7FC4, opacity: 0.35))
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                Haptics.tap(.soft)
                exhale(at: location)
            }
            DemoHint(text: L("Tap to breathe out bubbles", "点击吐出气泡"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.5) {
            exhale(at: CGPoint(x: CGFloat.random(in: 50...210), y: CGFloat.random(in: 190...270)))
        }
    }

    private func exhale(at point: CGPoint) {
        burst = point
        burstStart = Date()
    }
}
