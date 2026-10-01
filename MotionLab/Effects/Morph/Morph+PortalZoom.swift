import SwiftUI

extension Effect {
    static let morphPortalZoom = Effect(
        id: "morph.portal-zoom",
        category: .morph,
        interaction: .tap,
        name: L("Portal Zoom-Through", "穿越传送门"),
        summary: L(
            "The camera dives through a round portal: the current scene rushes past and blurs while the world inside the portal grows to fill the frame.",
            "镜头一头扎进圆形传送门：当前场景向四周飞掠、模糊，门里的世界长大到铺满画面。"
        ),
        prompt: L(
            "A scene with a glowing 68 pt round portal that shows the next scene in miniature at 34% scale, its rim breathing and sending out a faint ring every 1.6 s. Tapping dives through it in 0.95 s on an ease-in-out curve: the whole current scene scales up exponentially around the portal's centre (about 8×) and blurs up to 6 pt as it flies past the edges, the portal's circular mask grows with it until it covers the frame, and the scene inside grows with the opening from 34% until it is life-size, drifting from the portal's centre to the frame's centre, so depth reads as parallax rather than a cross-fade. The white rim thickens, then fades by 80%. When the dive lands, the next portal pops in on a spring (response 0.45 s, damping 0.6). Cinematic, continuous, endlessly loopable.",
            "场景中有一个直径 68pt 的发光圆形传送门，门内以 34% 的比例显示下一个场景的缩影，门框缓缓呼吸，每 1.6 秒荡出一圈淡淡的光环。点一下，镜头用 0.95 秒、缓入缓出地穿过它：当前场景以门心为锚点按指数放大（约 8 倍），飞掠出画时最多模糊 6pt；圆形遮罩同步变大直到盖满画面；门内场景随门洞一起从 34% 长到原大，并从门心漂移到画面中心，纵深靠视差而不是交叉淡变来表达。白色门框先变粗，在进度 80% 前淡出。穿越落定后，下一个传送门乘弹簧（响应 0.45 秒、阻尼 0.6）弹出。可以无限循环。"
        ),
        implementation: L(
            "An Animatable wrapper interpolates one progress; the outgoing scene gets scaleEffect(pow(S, p)) anchored at the portal, the incoming one is masked by a circle of radius r·pow(S, p) and scaled with it until it reaches full size. The animation's completion swaps the scene index and resets the progress without animation.",
            "Animatable 包装器对单一进度插值；旧场景以传送门为锚点做 scaleEffect(pow(S, p))，新场景被半径 r·pow(S, p) 的圆形遮罩裁切，并随之放大直到原大。动画完成回调切换场景序号，并无动画地把进度归零。"
        ),
        apis: ["Animatable", "scaleEffect(_:anchor:)", "mask", "Canvas", "withAnimation(_:completion:)", "phaseAnimator"],
        tags: ["portal", "zoom", "transition", "scene", "parallax", "传送门", "缩放穿越", "场景转场", "视差"],
        params: [
            .slider("duration", L("Duration", "时长"), 0.5...2.0, default: 0.95, unit: "s"),
            .slider("radius", L("Portal radius", "传送门半径"), 22...44, default: 34, decimals: 0, unit: "pt"),
            .slider("depth", L("Inner scale", "门内初始比例"), 0.3...0.7, default: 0.34),
            .slider("blur", L("Fly-past blur", "飞掠模糊"), 0...14, default: 6, decimals: 1, unit: "pt"),
        ]
    ) { ctx in
        PortalZoomDemo(ctx: ctx)
    }
}

private enum PortalLayout {
    static let size = CGSize(width: 316, height: 306)
    static let portals: [CGPoint] = [CGPoint(x: 216, y: 112), CGPoint(x: 104, y: 122), CGPoint(x: 178, y: 150)]
    static let titles: [LocalizedText] = [L("Dusk", "黄昏"), L("Meadow", "草甸"), L("Night", "夜空")]
    static let captions: [LocalizedText] = [
        L("Ridge trail, 18:42", "山脊步道 18:42"), L("Valley floor, 10:15", "谷底草场 10:15"), L("Summit camp, 23:30", "山顶营地 23:30"),
    ]
}

private struct PortalZoomDemo: View {
    let ctx: DemoContext
    @State private var index = 0
    @State private var progress: Double
    @State private var portalIn: CGFloat = 1
    @State private var diving = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 0.42 : 0)
    }

    var body: some View {
        VStack(spacing: 10) {
            MorphAnimated(progress) { value in
                PortalStage(
                    index: index,
                    progress: CGFloat(value),
                    radius: ctx.cg("radius"),
                    depth: ctx.cg("depth"),
                    blur: ctx.cg("blur"),
                    portalIn: portalIn,
                    language: ctx.language
                )
            }
            .contentShape(Rectangle())
            .onTapGesture { dive() }
            .morphScreen()
            DemoHint(text: L("Tap the portal", "点击传送门"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { dive() }
    }

    private func dive() {
        guard !diving else { return }
        diving = true
        let preview: Bool = ctx.isPreview
        if !preview { Haptics.tap(.medium) }
        withAnimation(.timingCurve(0.65, 0, 0.3, 1, duration: ctx["duration"])) {
            progress = 1
        } completion: {
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) {
                index = (index + 1) % 3
                progress = 0
                portalIn = 0
            }
            diving = false
            if !preview { Haptics.tap(.soft) }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.08)) { portalIn = 1 }
        }
    }
}

private struct PortalStage: View {
    let index: Int
    let progress: CGFloat
    let radius: CGFloat
    let depth: CGFloat
    let blur: CGFloat
    let portalIn: CGFloat
    let language: AppLanguage

    var body: some View {
        let p: CGFloat = MorphMath.unit(progress)
        let size: CGSize = PortalLayout.size
        let portal: CGPoint = PortalLayout.portals[index]
        let next: Int = (index + 1) % 3
        // Scale that makes the portal's circle reach the farthest corner.
        let reach: CGFloat = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            .map { hypot($0.x - portal.x, $0.y - portal.y) }
            .max() ?? 300
        let full: CGFloat = (reach + 8) / max(radius, 1)
        let zoom: CGFloat = pow(full, p)
        // The inner scene grows with the opening until it is life-size, drifting to the frame's centre as it does.
        let nominal: CGFloat = min(depth * zoom, 1)
        let travel: CGFloat = MorphMath.unit((nominal - depth) / max(1 - depth, 0.01))
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let innerCenter: CGPoint = MorphMath.lerp(portal, center, travel)
        // Never smaller than what the opening shows, so the scene's own edges stay out of sight.
        let drift: CGFloat = hypot(innerCenter.x - portal.x, innerCenter.y - portal.y)
        let cover: CGFloat = (radius * zoom + drift + 6) / (min(size.width, size.height) / 2)
        let inner: CGFloat = min(max(nominal, cover), 1)
        let hole: CGFloat = radius * zoom * portalIn
        let anchor = UnitPoint(x: portal.x / size.width, y: portal.y / size.height)
        ZStack {
            PortalSceneView(index: index, language: language)
                .scaleEffect(zoom, anchor: anchor)
                .blur(radius: blur * p)
            PortalSceneView(index: next, language: language)
                .scaleEffect(inner)
                .position(innerCenter)
                .frame(width: size.width, height: size.height)
                .overlay {
                    // Depth: the opening is darker toward its edge until you are through it.
                    Circle()
                        .fill(RadialGradient(colors: [.clear, .black.opacity(0.4)], center: .center, startRadius: hole * 0.55, endRadius: hole))
                        .frame(width: hole * 2, height: hole * 2)
                        .position(portal)
                        .opacity(Double(1 - MorphMath.smooth(p, 0.1, 0.7)))
                }
                .mask {
                    Circle()
                        .frame(width: hole * 2, height: hole * 2)
                        .position(portal)
                }
            PortalRim(idle: p == 0, lineWidth: 3 + 7 * p)
                .frame(width: hole * 2, height: hole * 2)
                .opacity(Double(1 - MorphMath.smooth(p, 0.35, 0.8)))
                .position(portal)
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct PortalRim: View {
    let idle: Bool
    let lineWidth: CGFloat
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        ZStack {
            // Always in the tree (hidden while diving), so it never animates in from elsewhere.
            Circle()
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5)
                .phaseAnimator([false, true]) { content, out in
                    content
                        .scaleEffect(out ? 1.7 : 1)
                        .opacity(out ? 0 : 0.8)
                } animation: { out in
                    out ? .easeOut(duration: 1.4) : .linear(duration: 0.2)
                }
                .opacity(idle && !isStill ? 1 : 0)
            Circle()
                .strokeBorder(Color.white, lineWidth: lineWidth)
                .shadow(color: .white.opacity(0.8), radius: 8)
                .phaseAnimator([false, true]) { content, inhale in
                    content.scaleEffect(inhale && idle ? 1.05 : 1)
                } animation: { _ in
                    .easeInOut(duration: 1.2)
                }
        }
        .allowsHitTesting(false)
    }
}

private struct PortalSceneView: View {
    let index: Int
    let language: AppLanguage

    var body: some View {
        Canvas { context, size in
            switch index {
            case 0: PortalSceneView.dusk(&context, size)
            case 1: PortalSceneView.meadow(&context, size)
            default: PortalSceneView.night(&context, size)
            }
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PortalLayout.titles[index], language)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(PortalLayout.captions[index], language)
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            .padding(18)
        }
        .frame(width: PortalLayout.size.width, height: PortalLayout.size.height)
    }

    private static func ridge(_ size: CGSize, base: CGFloat, height: CGFloat, phase: Double, frequency: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        let steps = 48
        for step in 0...steps {
            let u = Double(step) / Double(steps)
            let wave: Double = sin(u * frequency + phase) * 0.6 + sin(u * frequency * 2.3 + phase * 1.7) * 0.4
            path.addLine(to: CGPoint(x: size.width * CGFloat(u), y: size.height * (base - height * CGFloat(wave))))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }

    private static func sky(_ context: inout GraphicsContext, _ size: CGSize, _ colors: [Color]) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: size.width * 0.4, y: 0), endPoint: CGPoint(x: size.width * 0.6, y: size.height))
        )
    }

    private static func disc(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, glow: CGFloat) {
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * glow, y: center.y - radius * glow, width: radius * glow * 2, height: radius * glow * 2)),
            with: .radialGradient(Gradient(colors: [color.opacity(0.5), color.opacity(0)]), center: center, startRadius: 0, endRadius: radius * glow)
        )
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }

    private static func dusk(_ context: inout GraphicsContext, _ size: CGSize) {
        sky(&context, size, [Color(hex: 0x2A2F86), Color(hex: 0xB04A9A), Color(hex: 0xFF8660), Color(hex: 0xFFD08A)])
        disc(&context, center: CGPoint(x: size.width * 0.3, y: size.height * 0.56), radius: 30, color: Color(hex: 0xFFF0C4), glow: 3)
        context.fill(ridge(size, base: 0.66, height: 0.07, phase: 0.4, frequency: 5), with: .color(Color(hex: 0x8A3C86).opacity(0.85)))
        context.fill(ridge(size, base: 0.78, height: 0.06, phase: 2.1, frequency: 6.5), with: .color(Color(hex: 0x532468)))
        context.fill(ridge(size, base: 0.9, height: 0.05, phase: 4.0, frequency: 8), with: .color(Color(hex: 0x24123C)))
    }

    private static func meadow(_ context: inout GraphicsContext, _ size: CGSize) {
        sky(&context, size, [Color(hex: 0x3FA9F5), Color(hex: 0x8EDBFF), Color(hex: 0xDDF7E6)])
        disc(&context, center: CGPoint(x: size.width * 0.76, y: size.height * 0.2), radius: 22, color: .white, glow: 3.2)
        let clouds: [CGRect] = [
            CGRect(x: 150, y: 196, width: 84, height: 22), CGRect(x: 176, y: 184, width: 50, height: 24),
            CGRect(x: 30, y: 56, width: 70, height: 18), CGRect(x: 52, y: 46, width: 40, height: 20),
        ]
        for cloud in clouds {
            context.fill(Path(roundedRect: cloud, cornerRadius: cloud.height / 2), with: .color(.white.opacity(0.85)))
        }
        context.fill(ridge(size, base: 0.7, height: 0.08, phase: 1.2, frequency: 4), with: .color(Color(hex: 0x7ED69A)))
        context.fill(ridge(size, base: 0.8, height: 0.06, phase: 3.0, frequency: 5.5), with: .color(Color(hex: 0x43B27A)))
        context.fill(ridge(size, base: 0.9, height: 0.04, phase: 5.2, frequency: 7), with: .color(Color(hex: 0x1F8058)))
    }

    private static func night(_ context: inout GraphicsContext, _ size: CGSize) {
        sky(&context, size, [Color(hex: 0x060920), Color(hex: 0x18205A), Color(hex: 0x43307E)])
        for star in 0..<70 {
            let x: CGFloat = CGFloat((star * 73 + 11) % 316)
            let y: CGFloat = CGFloat((star * 137 + 29) % 210)
            let radius: CGFloat = star % 7 == 0 ? 1.5 : (star % 3 == 0 ? 1.0 : 0.7)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                with: .color(.white.opacity(star % 4 == 0 ? 0.95 : 0.6))
            )
        }
        let moon = CGPoint(x: size.width * 0.24, y: size.height * 0.22)
        disc(&context, center: moon, radius: 20, color: Color(hex: 0xF4F1FF), glow: 2.8)
        context.fill(
            Path(ellipseIn: CGRect(x: moon.x - 10, y: moon.y - 24, width: 38, height: 38)),
            with: .color(Color(hex: 0x0D1238))
        )
        context.fill(ridge(size, base: 0.76, height: 0.09, phase: 0.9, frequency: 6), with: .color(Color(hex: 0x1C2258)))
        context.fill(ridge(size, base: 0.88, height: 0.06, phase: 2.8, frequency: 8), with: .color(Color(hex: 0x0B0E2C)))
    }
}
