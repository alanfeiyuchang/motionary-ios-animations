import SwiftUI

// Replaces the planned "burn-away" transition (Burn Dissolve already burns a card away along a noise front
// with an ember edge): same family, a different material — the outgoing scene melts off like wax.

extension Effect {
    static let shaderMelt = Effect(
        id: "shader.melt",
        category: .shaders,
        interaction: .tap,
        name: L("Wax Melt", "蜡质融化"),
        summary: L(
            "The current scene melts and sags off the card in uneven drips, uncovering the next one behind it.",
            "当前画面像蜡一样融化下坠，参差的液滴滑落后，露出背后的下一幕。"
        ),
        prompt: L(
            "Tapping the poster melts it. Each column gets its own delay — broad 46 pt lobes plus drips a third as wide, and columns near the tap go first — then its top edge falls under gravity (slow start, accelerating) until it leaves the card; the whole run takes 1.6 s. The picture rides down with its edge and compresses 35% toward the bottom instead of sliding off rigidly, so it sags like warm wax. A glossy 3 pt highlight follows the melting lip, the wax darkens slightly for 16 pt beneath it, and a soft shadow falls on the next poster revealed above. When the last drip is gone the scenes swap invisibly. Gooey, heavy and oddly satisfying.",
            "点击海报，它便开始融化。每一列都有自己的延迟——宽约 46pt 的起伏，叠加宽度为其三分之一的细滴，且靠近触点的列最先开始——随后该列的上沿在重力下坠落（起步慢、越落越快），直到离开卡片；全程 1.6 秒。画面随上沿一起下滑，并向底部压缩 35%，而不是整块刚性滑走，因此像温热的蜡一样下垂。融化的边缘带着一道约 3pt 的光泽高光，其下 16pt 内的蜡略微变暗，并在上方露出的新海报上投下柔和的阴影。最后一滴落尽时，两幅画面无痕互换。黏稠、沉甸甸，有种奇妙的满足感。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader on the outgoing scene derives a per-column delay from two octaves of 1-D value noise and the distance to the tap, turns it into a falling edge, clears pixels above it, remaps the rest with a compression factor and adds lip highlight and a cast shadow; progress is Animatable and the scenes swap on completion.",
            "作用于旧画面的 [[stitchable]] layerEffect 着色器由两个倍频的一维值噪声与到触点的距离得出每列延迟，并换算成下落的上沿；上沿以上的像素被清除，其余部分按压缩系数重映射，再叠加边缘高光与投影；进度为 Animatable，完成时互换画面。"
        ),
        apis: ["layerEffect", "Animatable", "onTapGesture(coordinateSpace:)", "withAnimation(_:_:completion:)", "Metal"],
        tags: ["melt", "drip", "wax", "transition", "liquid", "融化", "滴落", "蜡", "转场"],
        params: [
            .slider("duration", L("Duration", "时长"), 0.8...3, default: 1.6, unit: "s"),
            .slider("drip", L("Drip width", "液滴宽度"), 20...90, default: 46, decimals: 0, unit: "pt"),
            .slider("goo", L("Sag", "下垂压缩"), 0...0.8, default: 0.35),
        ]
    ) { ctx in
        WaxMeltDemo(ctx: ctx)
    }
}

private struct WaxMeltDemo: View {
    let ctx: DemoContext
    @State private var current = 0
    @State private var progress: Double
    @State private var originX: CGFloat = 150
    @State private var seed: Double = 3.7
    @State private var busy = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the melt half-way, which is the picture that explains the effect.
        _progress = State(initialValue: ctx.isStill ? 0.5 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ShaderPosterScene(index: current + 1)
                ShaderPosterScene(index: current)
                    .modifier(WaxMeltModifier(progress: progress, originX: originX, drip: ctx["drip"], goo: ctx["goo"], seed: seed))
            }
            .shaderCard()
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in melt(from: location.x) }
            DemoHint(text: L("Tap to melt the poster", "点击让海报融化"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 1.0, delay: 0.4) {
            melt(from: CGFloat.random(in: 40...220))
        }
    }

    private func melt(from x: CGFloat) {
        guard !busy else { return }
        busy = true
        originX = x
        seed = Double.random(in: 0...40)
        Haptics.tap(.soft)
        // Linear: every column applies its own gravity curve to this progress.
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
        }
    }
}

private struct WaxMeltModifier: ViewModifier, Animatable {
    var progress: Double
    var originX: CGFloat
    var drip: Double
    var goo: Double
    var seed: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.mlWaxMelt(
                .float2(ShaderKit.card),
                .float(progress),
                .float(originX),
                .float(drip),
                .float(goo),
                .float(seed)
            ),
            maxSampleOffset: CGSize(width: 0, height: ShaderKit.card.height),
            isEnabled: progress > 0.0001
        )
    }
}
