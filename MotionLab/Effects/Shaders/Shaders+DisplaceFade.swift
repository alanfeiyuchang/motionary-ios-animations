import SwiftUI

extension Effect {
    static let shaderDisplaceFade = Effect(
        id: "shader.displace-fade",
        category: .shaders,
        interaction: .tap,
        name: L("Displacement Fade", "置换溶接"),
        summary: L(
            "A cross-fade where a displacement map makes each landscape push the other out of the way.",
            "一种交叉溶接：置换贴图让两幅风景互相推挤着让位。"
        ),
        prompt: L(
            "Tapping cross-fades one landscape into the next over 1.4 s (ease-in-out), but the two pictures do not simply blend: a displacement map shoves them. The outgoing image is pushed up to 60 pt along the map's vectors as it fades, while the incoming one starts displaced the opposite way and relaxes into place, so both are undistorted only when fully visible. Each pixel starts at its own moment, taken from the map's value, so the change rolls through the frame instead of happening everywhere at once; at the midpoint the mix brightens by about 16%. Three maps change the character: soft clouds, rings spreading from the tap, and vertical glass bars sliding alternately up and down. Liquid, cinematic and seamless.",
            "点击后，一幅风景在 1.4 秒内（缓入缓出）溶接为下一幅，但两张画面并不是简单地叠化：一张置换贴图在推挤它们。旧画面一边淡出，一边沿贴图的矢量被推开最多 60pt；新画面则从相反方向的偏移开始，逐渐归位，因此二者只有在完全显现时才不变形。每个像素的起始时刻取自贴图的数值，变化于是在画面里滚动推进，而不是处处同时发生；过渡中点整体提亮约 16%。三种贴图带来不同性格：柔软的云团、从触点扩散的圆环，以及交替上下滑动的竖向玻璃条。流动、电影感、天衣无缝。"
        ),
        implementation: L(
            "The same [[stitchable]] layer shader runs on both scenes with a role flag: it builds a vector map (cloud noise, radial rings or bars), derives a local progress from the map's value, displaces the outgoing scene by +v·e and the incoming one by −v·(1−e), and gives the incoming scene alpha e; progress is Animatable.",
            "同一个 [[stitchable]] layerEffect 着色器带着“角色”参数分别作用于两个画面：它生成一张矢量贴图（云噪声、径向圆环或竖条），由贴图数值得到局部进度，把旧画面偏移 +v·e、新画面偏移 −v·(1−e)，并让新画面的透明度为 e；进度为 Animatable。"
        ),
        apis: ["layerEffect", "Animatable", "easeInOut(duration:)", "onTapGesture(coordinateSpace:)", "Metal"],
        tags: ["displacement", "cross-fade", "transition", "morph", "warp", "置换", "溶接", "转场", "叠化", "扭曲"],
        params: [
            .slider("duration", L("Duration", "时长"), 0.6...3, default: 1.4, decimals: 1, unit: "s"),
            .slider("strength", L("Displacement", "置换强度"), 10...120, default: 60, decimals: 0, unit: "pt"),
            .slider("scale", L("Map scale", "贴图尺度"), 30...160, default: 80, decimals: 0, unit: "pt"),
            .choice("map", L("Map", "贴图"), [L("Clouds", "云团"), L("Rings", "圆环"), L("Glass bars", "玻璃条")]),
        ]
    ) { ctx in
        DisplaceFadeDemo(ctx: ctx)
    }
}

private struct DisplaceFadeDemo: View {
    let ctx: DemoContext
    @State private var current = 0
    @State private var progress: Double
    @State private var origin = CGPoint(x: 130, y: 150)
    @State private var busy = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the two landscapes half-way through each other.
        _progress = State(initialValue: ctx.isStill ? 0.5 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ShaderLandscapeScene(index: current)
                    .modifier(DisplaceFadeModifier(progress: progress, strength: ctx["strength"], scale: ctx["scale"], kind: ctx.int("map"), origin: origin, role: 0))
                ShaderLandscapeScene(index: current + 1)
                    .modifier(DisplaceFadeModifier(progress: progress, strength: ctx["strength"], scale: ctx["scale"], kind: ctx.int("map"), origin: origin, role: 1))
            }
            .shaderCard()
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in fade(from: location) }
            DemoHint(text: L("Tap to fade to the next view", "点击溶接到下一幅"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 1.0, delay: 0.4) {
            fade(from: CGPoint(x: CGFloat.random(in: 60...200), y: CGFloat.random(in: 80...220)))
        }
    }

    private func fade(from point: CGPoint) {
        guard !busy else { return }
        busy = true
        origin = point
        Haptics.tap(.soft)
        withAnimation(.easeInOut(duration: ctx["duration"])) {
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

private struct DisplaceFadeModifier: ViewModifier, Animatable {
    var progress: Double
    var strength: Double
    var scale: Double
    var kind: Int
    var origin: CGPoint
    var role: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.mlDisplaceFade(
                .float2(ShaderKit.card), .float(progress), .float(strength), .float(scale),
                .float(Double(kind)), .float2(origin), .float(role)
            ),
            maxSampleOffset: CGSize(width: strength * 1.3, height: strength * 1.3),
            isEnabled: progress > 0.0001
        )
        // The incoming scene is fully transparent at rest: it is simply not drawn then.
        .opacity(role > 0.5 && progress <= 0.0001 ? 0 : 1)
    }
}
