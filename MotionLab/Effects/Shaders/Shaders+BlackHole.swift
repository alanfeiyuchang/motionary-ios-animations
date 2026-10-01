import SwiftUI

// Replaces the planned "bulge" lens (Jelly Press and Refracting Sphere already cover a drag-controlled bulge):
// same family, a different optical idea — gravitational lensing.

extension Effect {
    static let shaderBlackHole = Effect(
        id: "shader.black-hole",
        category: .shaders,
        interaction: .gesture,
        name: L("Black Hole Lens", "黑洞引力透镜"),
        summary: L(
            "Drag a black hole across a star field: space wraps around it into an Einstein ring with a burning rim.",
            "在星空里拖动一颗黑洞：空间绕着它弯成爱因斯坦环，边缘燃着一圈吸积光。"
        ),
        prompt: L(
            "A black hole with a 30 pt event horizon floats over a star field crossed by a coordinate grid. Every pixel's sample is pulled toward the hole by 1.1 · r² / d, so grid lines bow around it and, next to the horizon, the far side of the sky wraps into a mirrored Einstein ring; the pull fades to nothing at five radii. Inside the horizon is pure black, hugged by a hairline photon ring and a swirling accretion glow that is brighter on one side. Grabbing it makes it feed, swelling 25% (spring 0.35 s, damping 0.6), and it follows the finger with an interactive spring; released, it falls home with a loose overshoot (response 0.7 s, damping 0.55). Vast, eerie, precise.",
            "一颗事件视界半径 30pt 的黑洞悬在布着坐标网格的星空之上。每个像素的采样点都被拉向黑洞，位移为 1.1 · r² / d：网格线绕着它弯曲，紧贴视界处，背面的星空被折成一圈镜像的爱因斯坦环；引力在 5 倍半径处衰减为零。视界之内是纯黑，外缘贴着一道极细的光子环，以及一圈旋转流动、一侧更亮的吸积辉光。按住它，它便“进食”膨胀 25%（弹簧 0.35 秒、阻尼 0.6），并以交互弹簧跟随手指；松手后带着松弛的过冲落回原位（响应 0.7 秒、阻尼 0.55）。浩瀚、诡谲而精确。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader moves each sample toward the center by bend · rs² / d (faded out by 5 rs), blacks out d < rs and adds a Gaussian photon ring plus an fbm accretion glow rotated with time; center and radius live in an Animatable modifier so springs carry the hole.",
            "[[stitchable]] layerEffect 着色器把每个采样点沿径向拉向中心 bend · rs² / d（在 5 rs 处淡出），将 d < rs 涂黑，并叠加高斯光子环与随时间旋转的 fbm 吸积辉光；中心与半径放在 Animatable 修饰器中，由弹簧带动黑洞。"
        ),
        apis: ["layerEffect", "Animatable", "DragGesture", "spring(response:dampingFraction:)", "Metal"],
        tags: ["black hole", "gravity", "lens", "einstein ring", "space", "黑洞", "引力透镜", "爱因斯坦环", "扭曲"],
        params: [
            .slider("radius", L("Horizon radius", "视界半径"), 16...48, default: 30, decimals: 0, unit: "pt"),
            .slider("bend", L("Lensing", "引力弯折"), 0.4...2, default: 1.1, decimals: 1),
            .slider("glow", L("Accretion glow", "吸积辉光"), 0...1.5, default: 1, decimals: 1),
        ]
    ) { ctx in
        BlackHoleDemo(ctx: ctx)
    }
}

private struct BlackHoleDemo: View {
    let ctx: DemoContext
    @State private var center: CGPoint
    @State private var mass: Double = 1
    @State private var grab = CGSize.zero
    @State private var holding = false
    @State private var visit = 0

    private static let home = CGPoint(x: 130, y: 150)

    init(ctx: DemoContext) {
        self.ctx = ctx
        _center = State(initialValue: ctx.isStill ? CGPoint(x: 112, y: 168) : Self.home)
    }

    var body: some View {
        let radius = ctx["radius"]
        let bend = ctx["bend"]
        let glow = ctx["glow"]
        VStack(spacing: 14) {
            ShaderClock(preview: ctx.isPreview) { time in
                ShaderSpaceScene()
                    .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                    .modifier(BlackHoleModifier(
                        center: center, radius: radius * mass, bend: bend, glow: glow,
                        time: ctx.isStill ? 3 : time
                    ))
            }
            .shaderCard(glow: Color(hex: 0xFF8A3D, opacity: 0.25))
            .shaderTouch(
                onBegan: { point in
                    holding = true
                    grab = CGSize(width: center.x - point.x, height: center.y - point.y)
                    // Grabbing from far away pulls the hole to the finger instead of keeping a long offset.
                    if hypot(grab.width, grab.height) > 70 { grab = .zero }
                    Haptics.tap(.soft)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { mass = 1.25 }
                },
                onMoved: { point, _ in
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                        center = clamp(CGPoint(x: point.x + grab.width, y: point.y + grab.height))
                    }
                },
                onEnded: {
                    holding = false
                    visit += 1
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) {
                        center = Self.home
                        mass = 1
                    }
                },
                onTap: { point in
                    Haptics.tap(.soft)
                    travel(to: point)
                }
            )
            DemoHint(text: L("Drag the black hole, or tap to send it", "拖动黑洞，或点击让它飞过去"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.3) {
            travel(to: CGPoint(x: CGFloat.random(in: 50...210), y: CGFloat.random(in: 60...240)))
        }
    }

    private func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x.clamped(to: 10...ShaderKit.card.width - 10), y: point.y.clamped(to: 10...ShaderKit.card.height - 10))
    }

    /// Tap (and the autoplay): the hole swells, flies to the point, then falls back home.
    private func travel(to point: CGPoint) {
        guard !holding else { return }
        visit += 1
        let token = visit
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            center = clamp(point)
            mass = 1.25
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard token == visit, !holding else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) {
                center = Self.home
                mass = 1
            }
        }
    }
}

/// Animatable so springs carry the hole's position and size into the shader.
private struct BlackHoleModifier: ViewModifier, Animatable {
    var center: CGPoint
    var radius: Double
    var bend: Double
    var glow: Double
    var time: Double

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, Double> {
        get { AnimatablePair(AnimatablePair(center.x, center.y), radius) }
        set {
            center = CGPoint(x: newValue.first.first, y: newValue.first.second)
            radius = newValue.second
        }
    }

    func body(content: Content) -> some View {
        // A slow idle drift, so the lensing is alive even when nobody touches it.
        let drift = CGPoint(x: center.x + CGFloat(5 * sin(time * 0.7)), y: center.y + CGFloat(4 * cos(time * 0.9)))
        let reach = bend * radius + 2
        content.layerEffect(
            ShaderLibrary.mlBlackHole(
                .float2(ShaderKit.card),
                .float2(drift),
                .float(radius),
                .float(bend),
                .float(glow),
                .float(time)
            ),
            maxSampleOffset: CGSize(width: reach, height: reach)
        )
    }
}
