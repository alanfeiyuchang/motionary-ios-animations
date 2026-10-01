import SwiftUI

extension Effect {
    static let shaderZoomBlur = Effect(
        id: "shader.zoom-blur",
        category: .shaders,
        interaction: .tap,
        name: L("Zoom Blur Cut", "变焦模糊转场"),
        summary: L(
            "The scene rushes toward your tap in radial streaks, flashes, and the next one lands sharp out of the blur.",
            "画面朝触点化作放射状光轨猛冲过去，一闪之后，下一幕从模糊中稳稳落定。"
        ),
        prompt: L(
            "Tapping a poster flies the camera through it. For the first 60% of the 0.9 s run the outgoing scene accelerates toward the tapped point: it magnifies up to 1.54× while a 16-tap radial blur stretches every detail into streaks covering up to 60% of its distance to that point. From 40% to 60% it cross-fades into the next scene, which starts 21% smaller and fully streaked, then decelerates to sharp and full size. The streaks are spectrally split — red at the near end, blue at the far end — and exposure lifts about 45% at the middle of the cut like a lens flare, so the swap itself is never seen. A soft tap marks the landing. Fast, cinematic, propulsive.",
            "点击海报，镜头便从中穿过。在 0.9 秒全程的前 60%，旧画面朝触点加速冲去：最多放大到 1.54 倍，同时 16 次采样的径向模糊把所有细节拉成光轨，最长可达该点距离的 60%。在 40% 到 60% 之间交叉淡化为下一幕；新画面起始时缩小 21% 且完全拉丝，随后减速恢复到清晰的原始大小。光轨带有光谱分离——近端偏红、远端偏蓝——在转场正中曝光提升约 45%，像一次镜头眩光，因此画面切换本身完全不可见。落定时有一次轻微的触感。迅疾、电影感、充满推进力。"
        ),
        implementation: L(
            "One [[stitchable]] layer shader runs on both scenes: it scales the picture about the center, averages 16 jittered samples along the ray to the center with red/blue weights that lean along the streak, and adds exposure. An Animatable stage view maps one linear progress to each scene's amount, zoom and opacity with its own ease-in and ease-out.",
            "同一个 [[stitchable]] layerEffect 着色器同时作用于两幅画面：先围绕中心缩放，再沿指向中心的射线平均 16 个带抖动的采样，红、蓝权重沿光轨方向倾斜，并叠加曝光。一个 Animatable 舞台视图把同一个线性进度分别映射为两幅画面的模糊量、缩放与不透明度，各自带有缓入与缓出。"
        ),
        apis: ["layerEffect", "Animatable", "onTapGesture(coordinateSpace:)", "withAnimation(_:_:completion:)", "Metal"],
        tags: ["zoom", "radial blur", "transition", "warp", "speed", "变焦", "径向模糊", "转场", "穿越"],
        params: [
            .slider("duration", L("Duration", "时长"), 0.5...2, default: 0.9, unit: "s"),
            .slider("strength", L("Streak length", "光轨长度"), 0.2...0.9, default: 0.6),
            .slider("chroma", L("Spectral split", "光谱分离"), 0...1, default: 0.5),
        ]
    ) { ctx in
        ZoomBlurDemo(ctx: ctx)
    }
}

private struct ZoomBlurDemo: View {
    let ctx: DemoContext
    /// Starts two posters in, so this stage never opens on the same poster as Wax Melt.
    @State private var current = 2
    @State private var progress: Double
    @State private var center = CGPoint(x: 130, y: 150)
    @State private var busy = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the outgoing scene mid-rush.
        _progress = State(initialValue: ctx.isStill ? 0.34 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZoomBlurStage(progress: progress, current: current, center: center, strength: ctx["strength"], chroma: ctx["chroma"])
                .shaderCard()
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in cut(toward: location) }
            DemoHint(text: L("Tap where the camera should fly", "点击镜头要冲向的位置"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 1.0, delay: 0.4) {
            cut(toward: CGPoint(x: CGFloat.random(in: 70...190), y: CGFloat.random(in: 90...210)))
        }
    }

    private func cut(toward point: CGPoint) {
        guard !busy else { return }
        busy = true
        center = point
        Haptics.tap(.rigid)
        let duration = ctx["duration"]
        // Linear: each scene applies its own easing to this progress.
        withAnimation(.linear(duration: duration)) {
            progress = 1
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                current += 1
                progress = 0
            }
            busy = false
            if !ctx.isPreview { Haptics.tap(.soft) }
        }
    }
}

/// Animatable so the per-scene curves are evaluated every frame from one progress value.
private struct ZoomBlurStage: View, Animatable {
    var progress: Double
    let current: Int
    let center: CGPoint
    let strength: Double
    let chroma: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = min(max(progress, 0), 1)
        // Outgoing: accelerates over 0…60%. Incoming: decelerates over 40…100%.
        let outT = min(p / 0.6, 1)
        let rush = outT * outT
        let inT = max((p - 0.4) / 0.6, 0)
        let land = 1 - (1 - inT) * (1 - inT) * (1 - inT)
        let mix = min(max((p - 0.4) / 0.2, 0), 1)
        let fade = mix * mix * (3 - 2 * mix)
        let flash = pow(sin(.pi * p), 2) * 0.45
        ZStack {
            ShaderPosterScene(index: current + 1)
                .modifier(ZoomBlurLayer(
                    center: center, amount: strength * (1 - land), zoom: 1 - 0.35 * strength * (1 - land),
                    chroma: chroma, exposure: flash, enabled: p > 0.0001
                ))
            ShaderPosterScene(index: current)
                .modifier(ZoomBlurLayer(
                    center: center, amount: strength * rush, zoom: 1 + 0.9 * strength * rush,
                    chroma: chroma, exposure: flash, enabled: p > 0.0001
                ))
                .opacity(1 - fade)
        }
    }
}

private struct ZoomBlurLayer: ViewModifier {
    let center: CGPoint
    let amount: Double
    let zoom: Double
    let chroma: Double
    let exposure: Double
    let enabled: Bool

    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.mlZoomBlur(
                .float2(ShaderKit.card),
                .float2(center),
                .float(amount),
                .float(zoom),
                .float(chroma),
                .float(exposure)
            ),
            maxSampleOffset: ShaderKit.card,
            isEnabled: enabled
        )
    }
}
