import SwiftUI

extension Effect {
    static let shaderCurlFlip = Effect(
        id: "shader.curl-flip",
        category: .shaders,
        interaction: .gesture,
        name: L("Page Curl", "卷页翻页"),
        summary: L(
            "Peel the page from its corner: it rolls over a cylinder, shows its paper back and casts a shadow on the next page.",
            "从页角揭起书页：纸张绕着圆柱卷起，露出纸背，并在下一页上投下阴影。"
        ),
        prompt: L(
            "A book page lies on top of the next one. Dragging left peels it from the bottom-right corner: the sheet rolls around an invisible cylinder of 28 pt radius whose axis starts tilted 22° and straightens as the peel advances. On the roll the print compresses and darkens as it turns away; over the top comes the back of the page, cream paper with a faint mirror image of the print and a specular streak along the curve, and the part that has turned fully lies flat as a flap. A soft shadow falls on the flat page under the roll and on the page revealed beyond it. Releasing past 45% or with a flick finishes the turn in about 0.4 s; otherwise the page springs back (response 0.5 s, damping 0.8). Physical, papery and precise.",
            "一页书压在下一页上。向左拖动，书页从右下角被揭起：纸张绕着一根半径 28pt 的隐形圆柱卷起，卷轴起初倾斜 22°，随着翻动逐渐摆正。卷起的部分上，印刷内容被压缩，并在转离视线时变暗；越过顶端露出的是纸背——米白的纸面透出淡淡的镜像图文，沿弧面带一道高光；完全翻过去的部分则平铺成一片翻折的纸。卷轴下方的平整页面和露出的下一页上，都落着柔和的阴影。松手时若超过 45% 或带有甩动，就在约 0.4 秒内翻完；否则书页以弹簧（响应 0.5 秒、阻尼 0.8）弹回。真实、有纸感、精确。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader on the top page maps each pixel back along the curl direction by the arc length on a cylinder (r·asin(d/r) for the front, r·(π − asin(d/r)) for the back, π·r − d for the flat flap), shades by the roll angle and returns translucent black for the cast shadow. One Animatable progress drives the fold line; the drag sets it directly.",
            "作用于上层书页的 [[stitchable]] layerEffect 着色器按圆柱上的弧长把每个像素沿卷曲方向映射回原位（正面为 r·asin(d/r)，背面为 r·(π − asin(d/r))，平铺的翻折部分为 π·r − d），按卷曲角度着色，并以半透明黑色返回投影。一个 Animatable 进度驱动折线位置，拖动时直接设置它。"
        ),
        apis: ["layerEffect", "Animatable", "DragGesture", "spring(response:dampingFraction:)", "Metal"],
        tags: ["page curl", "peel", "flip", "book", "transition", "卷页", "翻页", "书页", "揭开", "转场"],
        params: [
            .slider("radius", L("Roll radius", "卷曲半径"), 14...50, default: 28, decimals: 0, unit: "pt"),
            .slider("angle", L("Corner angle", "页角倾斜"), 0...40, default: 22, decimals: 0, unit: "°"),
            .slider("shadow", L("Shadow", "阴影"), 0...1, default: 0.7),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1, default: 0.5, unit: "s"),
        ]
    ) { ctx in
        CurlFlipDemo(ctx: ctx)
    }
}

private struct CurlFlipDemo: View {
    let ctx: DemoContext
    @State private var current = 0
    @State private var progress: Double
    @State private var lean: Double = 0
    @State private var startPoint = CGPoint.zero
    @State private var startProgress: Double = 0
    @State private var lastVelocity = CGSize.zero
    @State private var dragging = false
    @State private var token = 0
    @State private var finishing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the page half peeled.
        _progress = State(initialValue: ctx.isStill ? 0.42 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ShaderPageScene(index: current + 1)
                ShaderPageScene(index: current)
                    .modifier(PageCurlModifier(progress: progress, lean: lean, radius: ctx["radius"], angle: ctx["angle"], shadow: ctx["shadow"]))
            }
            .shaderCard()
            .shaderTouch(
                onBegan: { point in
                    guard !finishing else { return }
                    Haptics.tap(.soft)
                    grab(at: point)
                },
                onMoved: { point, velocity in
                    lastVelocity = velocity
                    peel(to: point)
                },
                onEnded: { settle(velocity: lastVelocity.width) },
                onTap: { _ in
                    guard !finishing, !dragging else { return }
                    token += 1
                    finish(turn: true)
                }
            )
            DemoHint(text: L("Drag left to peel the page", "向左拖动揭开书页"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.5) { simulateDrag() }
    }

    private func grab(at point: CGPoint) {
        token += 1
        dragging = true
        startPoint = point
        startProgress = progress
        lastVelocity = .zero
    }

    /// The finger's leftward travel is the peel; its vertical travel leans the fold line.
    private func peel(to point: CGPoint) {
        guard dragging else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            progress = min(max(startProgress + Double(startPoint.x - point.x) / Double(ShaderKit.card.width * 0.9), 0), 1)
            lean = min(max(Double(startPoint.y - point.y) / 240, -0.25), 0.25)
        }
    }

    private func settle(velocity: CGFloat) {
        guard dragging else { return }
        dragging = false
        finish(turn: progress > 0.45 || velocity < -500)
    }

    private func finish(turn: Bool) {
        if turn {
            finishing = true
            let current = token
            let remaining = 0.18 + 0.3 * (1 - progress)
            withAnimation(.easeOut(duration: remaining)) {
                progress = 1
                lean = 0
            } completion: {
                finishing = false
                guard current == token else { return }
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) {
                    self.current += 1
                    progress = 0
                }
                if !ctx.isPreview { Haptics.tap(.light) }
            }
        } else {
            withAnimation(.spring(response: ctx["response"], dampingFraction: 0.8)) {
                progress = 0
                lean = 0
            }
        }
    }

    /// Simulated finger: grabs the right edge, drags 62% of the way across with a slight lift, lets go.
    private func simulateDrag() {
        guard !dragging, !finishing, progress < 0.001 else { return }
        grab(at: CGPoint(x: 236, y: 250))
        let current = token
        Task { @MainActor in
            let frames = 42
            for frame in 1...frames {
                try? await Task.sleep(for: .milliseconds(16))
                guard current == token else { return }
                let t = Double(frame) / Double(frames)
                let e = t * t * (3 - 2 * t)
                lastVelocity = CGSize(width: -260, height: 0)
                peel(to: CGPoint(x: 236 - 145 * e, y: 250 - 34 * e))
            }
            settle(velocity: lastVelocity.width)
        }
    }
}

private struct PageCurlModifier: ViewModifier, Animatable {
    var progress: Double
    var lean: Double
    var radius: Double
    var angle: Double
    var shadow: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, lean) }
        set {
            progress = newValue.first
            lean = newValue.second
        }
    }

    func body(content: Content) -> some View {
        let p = min(max(progress, 0), 1)
        let size = ShaderKit.card
        // The fold line pivots on the bottom edge: it starts just outside the bottom-right corner, tilted,
        // and ends upright just past the left edge, where the whole page has been lifted away.
        let tilt = (angle * Double.pi / 180 + lean) * pow(1 - p, 0.8)
        let foldX = Double(size.width) + 1 - p * (Double(size.width) + radius + 4)
        let reach = Double(size.width + size.height)
        content.layerEffect(
            ShaderLibrary.mlPageCurl(
                .float2(size),
                .float2(CGPoint(x: foldX, y: Double(size.height))),
                .float2(CGPoint(x: cos(tilt), y: sin(tilt))),
                .float(radius),
                .float(shadow * min(p * 8, 1)),
                .color(Color(hex: 0xF4EEDF))
            ),
            maxSampleOffset: CGSize(width: reach, height: reach),
            isEnabled: p > 0.0005
        )
    }
}
