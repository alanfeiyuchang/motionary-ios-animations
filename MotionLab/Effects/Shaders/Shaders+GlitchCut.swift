import SwiftUI

extension Effect {
    static let shaderGlitchCut = Effect(
        id: "shader.glitch-cut",
        category: .shaders,
        interaction: .tap,
        name: L("Glitch Cut", "故障切换"),
        summary: L(
            "A hard cut that breaks up for a few frames: slices jump sideways, colours split and blocks of static flash.",
            "一次硬切在几帧之内碎裂开来：横条左右错位、色彩分离、成块的雪花一闪而过。"
        ),
        prompt: L(
            "Tapping cuts from one poster to the next in 0.45 s, and the cut misfires on the way. Time is stepped, twelve frames in all, with no easing. The frame is sliced into about 16 horizontal bands of two heights; each band flips to the new poster at its own frame between 20% and 80% of the run, so both images are on screen at once. While the cut is in flight about half of the bands jump sideways by a new offset every frame, up to a quarter of the width, wrapping around; red and blue separate by up to 10 pt; a thin bright tear line edges the moving bands; and small blocks flash to television static. The damage peaks mid-cut, then the new poster lands perfectly clean with a rigid haptic. Abrupt, digital and punchy.",
            "点击后，画面在 0.45 秒内从一张海报切到下一张，而这次切换在途中“出了故障”。时间是分步的，一共十二帧，没有任何缓动。画面被切成约 16 条两种高度的横带；每条在全程 20% 到 80% 之间各自的某一帧翻到新海报，于是两张图同时出现在屏幕上。切换进行中，约一半横带每帧向左右跳到新的偏移，最多四分之一宽度，并从另一侧绕回；红、蓝通道最多分离 10pt；错位横带的边缘带一道细亮的撕裂线；小方块闪成电视雪花。破坏在中点最强，随后新海报干干净净地落定，伴随一次硬朗触感。突兀、数字感、有冲击力。"
        ),
        implementation: L(
            "One [[stitchable]] layer shader runs on both posters with a role flag. It quantises progress to twelve steps, hashes each band for its switch time and a per-step sideways jump (wrapped with fmod), samples R/G/B at split offsets and replaces hashed 26 × 9 pt blocks with static, all scaled by sin(π·progress); progress is animated linearly.",
            "同一个 [[stitchable]] layerEffect 着色器带着“角色”参数作用于两张海报。它把进度量化为十二步，对每条横带做哈希得到切换时刻和每步的横向跳动（用 fmod 绕回），以分离的偏移采样 R/G/B，并把哈希选中的 26 × 9pt 方块换成雪花，全部乘以 sin(π·进度)；进度以线性动画推进。"
        ),
        apis: ["layerEffect", "Animatable", "linear(duration:)", "onTapGesture", "Metal"],
        tags: ["glitch", "cut", "transition", "rgb split", "static", "故障", "切换", "转场", "色彩分离", "雪花"],
        params: [
            .slider("duration", L("Duration", "时长"), 0.2...1.2, default: 0.45, decimals: 2, unit: "s"),
            .slider("slices", L("Slices", "横带数量"), 6...40, default: 16, decimals: 0),
            .slider("split", L("RGB split", "色彩分离"), 0...24, default: 10, decimals: 0, unit: "pt"),
            .slider("noise", L("Static", "雪花"), 0...1, default: 0.5),
        ]
    ) { ctx in
        GlitchCutDemo(ctx: ctx)
    }
}

private struct GlitchCutDemo: View {
    let ctx: DemoContext
    @State private var current = 2
    @State private var progress: Double
    @State private var seed: Double = 5.3
    @State private var busy = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the cut at its most broken.
        _progress = State(initialValue: ctx.isStill ? 0.5 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ShaderPosterScene(index: current)
                    .modifier(GlitchCutModifier(progress: progress, slices: ctx["slices"], split: ctx["split"], noise: ctx["noise"], seed: seed, role: 0))
                ShaderPosterScene(index: current + 1)
                    .modifier(GlitchCutModifier(progress: progress, slices: ctx["slices"], split: ctx["split"], noise: ctx["noise"], seed: seed, role: 1))
            }
            .shaderCard()
            .contentShape(Rectangle())
            .onTapGesture { cut() }
            DemoHint(text: L("Tap to cut", "点击切换"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 1.2, delay: 0.5) { cut() }
    }

    private func cut() {
        guard !busy else { return }
        busy = true
        seed = Double.random(in: 1...40)
        Haptics.tap(.light)
        // Linear: the shader quantises this progress into twelve frames itself.
        withAnimation(.linear(duration: ctx["duration"])) {
            progress = 1
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                current += 1
                progress = 0
            }
            busy = false
            if !ctx.isPreview { Haptics.tap(.rigid) }
        }
    }
}

private struct GlitchCutModifier: ViewModifier, Animatable {
    var progress: Double
    var slices: Double
    var split: Double
    var noise: Double
    var seed: Double
    var role: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.mlGlitchCut(
                .float2(ShaderKit.card), .float(progress), .float(slices.rounded()), .float(split),
                .float(noise), .float(seed), .float(role)
            ),
            maxSampleOffset: CGSize(width: ShaderKit.card.width, height: 0),
            isEnabled: progress > 0.0001
        )
        // The incoming scene is fully transparent at rest: it is simply not drawn then.
        .opacity(role > 0.5 && progress <= 0.0001 ? 0 : 1)
    }
}
