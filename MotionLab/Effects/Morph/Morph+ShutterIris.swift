import SwiftUI

extension Effect {
    static let morphShutterIris = Effect(
        id: "morph.shutter-iris",
        category: .morph,
        interaction: .tap,
        name: L("Shutter Iris", "光圈快门切换"),
        summary: L(
            "Overlapping aperture blades swirl shut over the picture, swap it in the dark, and spring open again.",
            "层叠的光圈叶片旋转着合拢遮住画面，在黑暗中换图，再弹开。"
        ),
        prompt: L(
            "A round lens in a dark metal barrel shows a picture through a seven-blade iris; at rest the blades peek in from the rim, leaving a heptagonal opening at 82% of the lens radius. Tapping fires the shutter: the blades close to a point in 0.26 s on an ease-in while the whole iris twists 35°, each blade a graphite wedge with a bright leading edge and a shadow where the next blade overlaps it. At full black a rigid haptic clicks and the picture is swapped; 90 ms later the iris springs open (response 0.5 s, damping 0.7), overshooting wider before settling, and the picture, pushed in to 112% as the blades closed, eases back to 100%. The f-number under the lens rolls from ƒ/1.7 to ƒ/22 and back. Mechanical, precise, satisfying.",
            "深色金属镜筒里的圆形镜头，透过七片光圈叶片露出画面；静止时叶片从边缘探入，留出一个开口为镜头半径 82% 的七边形。点一下触发快门：叶片用 0.26 秒缓入收拢到一点，整个光圈同时扭转 35°；每片叶片是石墨色楔形，前缘一道亮边，被下一片压住处落着阴影。全黑的瞬间有一次硬朗的触感，画面在此刻替换；90 毫秒后光圈乘弹簧弹开（响应 0.5 秒、阻尼 0.7），先开得更大再回稳，合拢时被推近到 112% 的画面缓缓退回 100%。镜头下方的光圈值从 ƒ/1.7 滚到 ƒ/22 再滚回来。机械、精确、令人满足。"
        ),
        implementation: L(
            "The opening is a regular polygon; each blade is the half-plane beyond one of its edges. A Canvas draws blade i as that half-plane clipped to the lens and to the inside of blade i+1's edge, which gives a consistent cyclic overlap with no seam, then adds its edge highlight and the neighbour's shadow. An Animatable wrapper feeds the aperture value, so the close ease and the opening spring both drive the geometry.",
            "开口是一个正多边形，每片叶片是其一条边之外的半平面。Canvas 把第 i 片画成该半平面与镜头圆、以及第 i+1 片边线内侧的交集，由此得到首尾一致、没有接缝的循环层叠，再叠加前缘高光与相邻叶片的投影。Animatable 包装器提供光圈数值，合拢的缓动与弹开的弹簧都直接驱动几何。"
        ),
        apis: ["Canvas", "GraphicsContext.clip(to:)", "Animatable", "withAnimation(_:completionCriteria:_:completion:)", "contentTransition(.numericText)"],
        tags: ["iris", "aperture", "shutter", "camera", "光圈", "快门", "相机", "叶片"],
        params: [
            .slider("blades", L("Blades", "叶片数"), 5...10, default: 7, step: 1, decimals: 0),
            .slider("close", L("Close duration", "合拢时长"), 0.12...0.8, default: 0.26, unit: "s"),
            .slider("twist", L("Twist", "扭转角度"), 0...90, default: 35, decimals: 0, unit: "°"),
            .slider("rest", L("Resting aperture", "静止开口"), 0.5...1.1, default: 0.82),
        ]
    ) { ctx in
        ShutterIrisDemo(ctx: ctx)
    }
}

private struct IrisScene {
    let symbol: String
    let colors: [Color]
    let name: LocalizedText
}

private let irisScenes: [IrisScene] = [
    IrisScene(symbol: "sun.horizon.fill", colors: [Color(hex: 0xFFB45A), Color(hex: 0xE5407A), Color(hex: 0x4B2A78)], name: L("Dusk", "黄昏")),
    IrisScene(symbol: "mountain.2.fill", colors: [Color(hex: 0x8FE3FF), Color(hex: 0x3A8BE8), Color(hex: 0x1B2F6B)], name: L("Summit", "山巅")),
    IrisScene(symbol: "leaf.fill", colors: [Color(hex: 0xC8F27A), Color(hex: 0x2FB37A), Color(hex: 0x0E4A46)], name: L("Canopy", "林间")),
    IrisScene(symbol: "moon.stars.fill", colors: [Color(hex: 0x9A8BFF), Color(hex: 0x4A3AA8), Color(hex: 0x130F3A)], name: L("Night", "夜空")),
]

private struct ShutterIrisDemo: View {
    let ctx: DemoContext
    /// 0 = closed to a point, `rest` = the idle opening, above it = wider.
    @State private var aperture: Double
    @State private var scene = 0
    @State private var zoom: CGFloat = 1
    @State private var busy = false
    @State private var token = 0
    @State private var shots = 41

    private static let lens: CGFloat = 228

    init(ctx: DemoContext) {
        self.ctx = ctx
        _aperture = State(initialValue: ctx["rest"])
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                barrel
                picture
                MorphAnimated(aperture) { value in
                    IrisBlades(aperture: CGFloat(value), blades: ctx.int("blades"), twist: ctx["twist"], rest: ctx.cg("rest"))
                }
                .frame(width: Self.lens, height: Self.lens)
                glass
            }
            .frame(width: 264, height: 264)
            .contentShape(Circle())
            .onTapGesture { fire() }
            readout
            DemoHint(text: L("Tap the lens", "点击镜头"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { fire() }
        .onChange(of: ctx["rest"]) { _, rest in
            guard !busy else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { aperture = rest }
        }
    }

    private var barrel: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x3A3D45), Color(hex: 0x121317)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            Circle()
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            Circle()
                .strokeBorder(Color.black.opacity(0.6), lineWidth: 2)
                .padding(15)
            ForEach(0..<48, id: \.self) { tick in
                Capsule()
                    .fill(Color.white.opacity(tick % 4 == 0 ? 0.5 : 0.18))
                    .frame(width: 1.2, height: tick % 4 == 0 ? 6 : 3.5)
                    .offset(y: -123)
                    .rotationEffect(.degrees(Double(tick) * 7.5))
            }
        }
    }

    private var picture: some View {
        let item: IrisScene = irisScenes[scene % irisScenes.count]
        return ZStack {
            LinearGradient(colors: item.colors, startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.4), .clear], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 120)
            Image(systemName: item.symbol)
                .font(.system(size: 84, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
        .scaleEffect(zoom)
        .frame(width: Self.lens, height: Self.lens)
        .clipShape(Circle())
    }

    /// Front element: a reflection arc and an inner vignette, above the blades.
    private var glass: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.clear, .clear, Color.black.opacity(0.35)], center: .center, startRadius: 0, endRadius: Self.lens / 2))
            Ellipse()
                .fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 150, height: 74)
                .rotationEffect(.degrees(-28))
                .offset(x: -34, y: -58)
                .blur(radius: 4)
            Circle()
                .strokeBorder(Color.black.opacity(0.7), lineWidth: 3)
        }
        .frame(width: Self.lens, height: Self.lens)
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    private var readout: some View {
        HStack(spacing: 14) {
            MorphAnimated(aperture) { value in
                Text(verbatim: "ƒ/" + ShutterIrisDemo.stop(value))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 58, alignment: .leading)
            }
            Text(irisScenes[scene % irisScenes.count].name, ctx.language)
                .font(.system(size: 15, weight: .semibold))
                .id(scene)
                .transition(.blurReplace)
                .frame(maxWidth: .infinity)
            Text(verbatim: "IMG_00\(shots)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(shots)))
        }
        .frame(width: 264)
    }

    /// f-number for an aperture value: wide open reads ƒ/1.4, nearly closed ƒ/22.
    private static func stop(_ aperture: Double) -> String {
        let number: Double = min(1.4 / max(aperture, 0.064), 22)
        return number >= 10 ? String(format: "%.0f", number) : String(format: "%.1f", number)
    }

    /// Close, swap the picture in the dark, spring open.
    private func fire() {
        guard !busy else { return }
        busy = true
        token += 1
        let current: Int = token
        let preview: Bool = ctx.isPreview
        let rest: Double = ctx["rest"]
        if !preview { Haptics.tap(.light) }
        withAnimation(.easeIn(duration: ctx["close"]), completionCriteria: .logicallyComplete) {
            aperture = 0
            zoom = 1.12
        } completion: {
            guard current == token else { return }
            if !preview { Haptics.tap(.rigid) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                scene += 1
                shots += 1
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.09)) { aperture = rest }
            withAnimation(.easeOut(duration: 0.9).delay(0.09)) { zoom = 1 }
            busy = false
        }
    }
}

/// The iris at one aperture value. `aperture` is the distance from the centre to each blade's edge as a fraction
/// of the lens radius, so 1 clears the lens entirely for any blade count.
private struct IrisBlades: View {
    let aperture: CGFloat
    let blades: Int
    let twist: Double
    let rest: CGFloat

    var body: some View {
        Canvas { context, size in
            let count: Int = min(max(blades, 3), 12)
            let radius: CGFloat = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Distance from the centre to each blade's edge. At aperture 1 the edges sit just outside the lens.
            let inset: CGFloat = max(aperture, 0) * radius * 1.03
            let closing: CGFloat = rest > 0 ? 1 - min(max(aperture / rest, 0), 1.3) : 0
            let rotation: Double = Double(closing) * twist * .pi / 180
            let step: Double = 2 * .pi / Double(count)
            let far: CGFloat = radius * 2.4
            let lens = Path(ellipseIn: CGRect(x: 0, y: 0, width: size.width, height: size.height))

            for index in 0..<count {
                let angle: Double = rotation + Double(index) * step
                let next: Double = angle + step
                let own = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: CGFloat(angle))
                let neighbour = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: CGFloat(next))
                // Beyond this blade's edge…
                let outside = Path(CGRect(x: inset, y: -far, width: far, height: far * 2)).applying(own)
                // …but only where the next blade is not lying on top of it.
                let uncovered = Path(CGRect(x: inset - far, y: -far, width: far, height: far * 2)).applying(neighbour)

                context.drawLayer { layer in
                    layer.clip(to: lens)
                    layer.clip(to: outside)
                    layer.clip(to: uncovered)
                    let tangent = CGPoint(x: -CGFloat(sin(angle)), y: CGFloat(cos(angle)))
                    let edge = CGPoint(x: center.x + CGFloat(cos(angle)) * inset, y: center.y + CGFloat(sin(angle)) * inset)
                    layer.fill(
                        lens,
                        with: .linearGradient(
                            Gradient(colors: [Color(hex: 0x17181C), Color(hex: 0x34373F), Color(hex: 0x1E2025)]),
                            startPoint: CGPoint(x: edge.x - tangent.x * radius, y: edge.y - tangent.y * radius),
                            endPoint: CGPoint(x: edge.x + tangent.x * radius, y: edge.y + tangent.y * radius)
                        )
                    )
                    // Shadow cast by the next blade, falling inward from its edge.
                    let band = Path(CGRect(x: inset - 18, y: -far, width: 18, height: far * 2)).applying(neighbour)
                    let from = CGPoint(x: center.x + CGFloat(cos(next)) * inset, y: center.y + CGFloat(sin(next)) * inset)
                    let to = CGPoint(x: center.x + CGFloat(cos(next)) * (inset - 18), y: center.y + CGFloat(sin(next)) * (inset - 18))
                    layer.fill(
                        band,
                        with: .linearGradient(Gradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0)]), startPoint: from, endPoint: to)
                    )
                    // Bright leading edge.
                    var line = Path()
                    line.move(to: CGPoint(x: inset + 0.6, y: -far))
                    line.addLine(to: CGPoint(x: inset + 0.6, y: far))
                    layer.stroke(line.applying(own), with: .color(Color.white.opacity(0.3)), lineWidth: 1.2)
                }
            }
        }
    }
}
