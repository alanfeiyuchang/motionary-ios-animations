import SwiftUI

extension Effect {
    static let shaderCrumple = Effect(
        id: "shader.crumple",
        category: .shaders,
        interaction: .gesture,
        name: L("Paper Crumple", "揉皱纸张"),
        summary: L(
            "Press and hold to crush the flyer into faceted paper from your fingertip; let go and it snaps flat, creases fading.",
            "按住即可从指尖把传单揉成满是折面的纸团；松手后弹平，折痕慢慢淡去。"
        ),
        prompt: L(
            "A printed flyer lies flat. Pressing and holding crushes it like paper in a fist: the crush starts under the finger and spreads across the sheet on a spring (response 0.5 s, damping 0.7). The sheet breaks into flat facets about 54 pt wide with finer wrinkles inside; each facet tilts its own way, shifting and foreshortening its piece of the print by up to 14 pt, catching light or falling into shade, with a dark crease along every border. The whole sheet contracts toward the finger by roughly a fifth, so its outline turns jagged. Releasing snaps it flat with a springy overshoot (response 0.6 s, damping 0.55); the creases linger and fade over 2.4 s. Tactile, crisp and satisfying.",
            "一张印刷传单平放着。按住它，就像把纸攥进拳头：褶皱从指下开始，以弹簧（响应 0.5 秒、阻尼 0.7）向整张纸蔓延。纸面碎成约 54pt 宽的平整折面，里面还有更细的皱纹；每个折面朝各自的方向倾斜，把那一块图案挪动并压缩最多 14pt，有的迎光、有的落入阴影，每条边界都留下一道深色折痕。整张纸向指尖收缩约五分之一，轮廓因此变得参差。松手后带着弹性过冲弹平（响应 0.6 秒、阻尼 0.55），折痕停留片刻，在 2.4 秒内淡去。有触感、干脆、解压。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader runs two Voronoi levels; the nearest cell's hashed tilt offsets the sample, scales brightness, and the F2−F1 border distance draws creases, while the sample position is scaled about the press point. Two Animatable values (crush and leftover creases) are driven by springs from a hold gesture.",
            "[[stitchable]] layerEffect 着色器计算两层 Voronoi；最近单元的哈希倾斜量用来偏移采样并缩放亮度，F2−F1 边界距离画出折痕，同时采样位置绕按压点缩放。两个 Animatable 数值（揉皱程度与残留折痕）由按住手势触发的弹簧驱动。"
        ),
        apis: ["layerEffect", "Animatable", "spring(response:dampingFraction:)", "DragGesture", "Metal"],
        tags: ["crumple", "paper", "wrinkle", "voronoi", "fold", "揉皱", "纸张", "褶皱", "折痕", "纸团"],
        params: [
            .slider("cell", L("Facet size", "折面大小"), 30...90, default: 54, decimals: 0, unit: "pt"),
            .slider("depth", L("Depth", "褶皱深度"), 4...30, default: 14, decimals: 0, unit: "pt"),
            .slider("shade", L("Shading", "明暗"), 0...1, default: 0.7),
            .slider("damping", L("Unfold damping", "展开阻尼"), 0.3...1, default: 0.55),
        ]
    ) { ctx in
        CrumpleDemo(ctx: ctx)
    }
}

private struct CrumpleDemo: View {
    let ctx: DemoContext
    @State private var amount: Double
    @State private var crease: Double
    @State private var centre = CGPoint(x: 150, y: 170)
    @State private var seed: Double = 4.2
    @State private var pressing = false
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the sheet mostly crushed.
        _amount = State(initialValue: ctx.isStill ? 0.8 : 0)
        _crease = State(initialValue: ctx.isStill ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            ShaderFlyerScene()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .modifier(CrumpleModifier(
                    amount: amount, crease: crease, centre: centre,
                    cell: ctx["cell"], depth: ctx["depth"], shade: ctx["shade"], seed: seed
                ))
                .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                .shaderTouch(
                    onBegan: { point in
                        Haptics.tap(.rigid)
                        pressing = true
                        crush(at: point)
                    },
                    onMoved: { _, _ in },
                    onEnded: {
                        pressing = false
                        unfold()
                    },
                    onTap: { point in squeeze(at: point) }
                )
            DemoHint(text: L("Press and hold to crumple", "按住揉皱"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.2, delay: 0.4) {
            squeeze(at: CGPoint(x: CGFloat.random(in: 70...190), y: CGFloat.random(in: 90...210)))
        }
    }

    /// A quick tap (and the autoplay): crush, hold for a moment, let go.
    private func squeeze(at point: CGPoint) {
        crush(at: point)
        let current = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard current == token, !pressing else { return }
            unfold()
        }
    }

    private func crush(at point: CGPoint) {
        token += 1
        // Keep the fold pattern while old creases are still visible, so they never jump.
        if crease < 0.02 { seed = Double.random(in: 0...40) }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { centre = point }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            amount = 1
            crease = 1
        }
    }

    private func unfold() {
        token += 1
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.6, dampingFraction: ctx["damping"])) { amount = 0 }
        withAnimation(.easeOut(duration: 2.4).delay(0.4)) { crease = 0 }
    }
}

private struct CrumpleModifier: ViewModifier, Animatable {
    var amount: Double
    var crease: Double
    var centre: CGPoint
    var cell: Double
    var depth: Double
    var shade: Double
    var seed: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(amount, crease) }
        set {
            amount = newValue.first
            crease = newValue.second
        }
    }

    func body(content: Content) -> some View {
        let reach = depth * 2.6 + 100
        content
            .layerEffect(
                ShaderLibrary.mlCrumple(
                    .float2(ShaderKit.card), .float2(centre), .float(amount), .float(crease),
                    .float(cell), .float(depth), .float(shade), .float(seed)
                ),
                maxSampleOffset: CGSize(width: reach, height: reach),
                isEnabled: abs(amount) > 0.0005 || crease > 0.0005
            )
            .shadow(color: .black.opacity(0.22 + 0.12 * min(max(amount, 0), 1)), radius: 16 - 6 * min(max(amount, 0), 1), y: 10)
    }
}
