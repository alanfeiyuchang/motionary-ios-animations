import SwiftUI

extension Effect {
    static let buttonsSpecularGlass = Effect(
        id: "buttons.specular-glass",
        category: .buttons,
        interaction: .gesture,
        name: L("Specular Glass", "高光玻璃"),
        summary: L(
            "A glass pill whose highlight, rim light and refraction follow the finger; pressing deepens the glass.",
            "玻璃胶囊的高光、轮廓光与折射都跟随手指，按下时玻璃变得更深。"
        ),
        prompt: L(
            "A 232 × 76 pt clear glass capsule lies on a colourful wallpaper card with a fine dot grid. The glass shows a magnified copy of the wallpaper (118%) that slides against the finger, so its dots visibly refract; a flattened specular streak about 96 pt wide sits toward the upper left, with a thin crescent of light on the far wall opposite and a rim stroke that is brightest on the lit side. Dragging near the button moves the light: highlight, rim gradient and refraction offset chase the finger on one spring (response 0.22 s, damping 0.75), and the label drifts 3 pt the other way. Touching the glass presses it to 95.5%: the tint darkens, the inner shadow thickens, the highlight narrows to 60% and brightens, and the shadow tightens. Lifting on it fires a medium haptic and a quick sheen; the light then eases back to rest.",
            "232×76pt 的透明玻璃胶囊压在带细点网格的彩色壁纸卡片上。玻璃内是放大到 118% 的壁纸副本，会逆着手指方向滑动，里面的小点因此明显折射；左上方有一道宽约 96pt 的扁平高光，对面的内壁上有一弯细细的反光，描边在受光一侧最亮。在附近拖动即可移动光源：高光、描边渐变与折射偏移由同一弹簧（响应 0.22 秒、阻尼 0.75）追随手指，文字反向漂移 3pt。按在玻璃上会压到 95.5%：色调变深、内阴影加厚、高光收窄到 60% 并更亮，投影收紧。在其上抬手触发中等触感与一道光泽，随后光源归位。"
        ),
        implementation: L(
            "No material is involved: the capsule masks a scaled, counter-offset copy of the backdrop, then stacks a tint, a blurred inner stroke, two radial-gradient ellipses in plusLighter and a strokeBorder whose LinearGradient start point is the light direction. A zero-distance DragGesture maps the finger to a unit light vector animated by a spring.",
            "完全不用系统材质：胶囊遮罩一份放大并反向偏移的背景副本，再叠上色调层、模糊内描边、两枚 plusLighter 混合的径向渐变椭圆，以及一条以光源方向为起点的 LinearGradient 描边。零距离 DragGesture 把手指映射成单位光源向量，并由弹簧驱动。"
        ),
        apis: ["DragGesture", "RadialGradient", "blendMode(.plusLighter)", "mask", "spring(response:dampingFraction:)"],
        tags: ["glass", "specular", "refraction", "highlight", "玻璃", "高光", "折射", "跟随"],
        params: [
            .slider("size", L("Highlight size", "高光大小"), 50...150, default: 96, decimals: 0, unit: "pt"),
            .slider("intensity", L("Highlight intensity", "高光强度"), 0.3...1.0, default: 0.8),
            .slider("refraction", L("Refraction", "折射强度"), 0...0.5, default: 0.25),
            .slider("lag", L("Follow response", "跟随响应"), 0.08...0.5, default: 0.22, unit: "s"),
        ]
    ) { ctx in
        ButtonSpecularDemo(ctx: ctx)
    }
}

private struct ButtonSpecularDemo: View {
    let ctx: DemoContext
    /// Unit light vector relative to the button centre (−1…1 on each axis).
    @State private var light = ButtonSpecularDemo.restLight
    @State private var pressed = false
    @State private var sheens = 0
    @State private var step = 0
    @State private var introTask: Task<Void, Never>?
    @GestureState private var touching = false

    private static let restLight = CGSize(width: -0.55, height: -0.7)
    private static let card = CGSize(width: 304, height: 220)
    private static let glass = CGSize(width: 232, height: 76)
    private static let path: [CGSize] = [
        CGSize(width: 0.8, height: -0.6),
        CGSize(width: 0.5, height: 0.7),
        CGSize(width: -0.2, height: 0.1),
        CGSize(width: -0.85, height: 0.6),
        CGSize(width: -0.4, height: -0.8),
    ]

    private var follow: Animation { .spring(response: ctx["lag"], dampingFraction: 0.75) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                ButtonSpecularBackdrop()
                    .frame(width: Self.card.width, height: Self.card.height)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                ButtonSpecularGlass(
                    title: ctx.language == .zh ? "继续" : "Continue",
                    light: light,
                    pressed: pressed,
                    sheens: sheens,
                    highlight: ctx.cg("size"),
                    intensity: ctx["intensity"],
                    refraction: ctx.cg("refraction"),
                    card: Self.card,
                    glass: Self.glass
                )
            }
            .frame(width: Self.card.width, height: Self.card.height)
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
            .onChange(of: touching) { _, isTouching in
                if !isTouching { release() }
            }
            .accessibilityAddTraits(.isButton)
            Spacer()
            DemoHint(text: L("Drag across the glass, then tap it", "在玻璃上拖动，再点一下"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.95, delay: 0.3) {
            if ctx.isPreview { stepPreview() } else { playIntro() }
        }
        .onDisappear { stopIntro() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                stopIntro()
                let inside = isOnGlass(value.location)
                if inside != pressed {
                    if inside { Haptics.tap(.soft) }
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.7)) { pressed = inside }
                }
                withAnimation(follow) { light = lightVector(for: value.location) }
            }
            .onEnded { value in
                if isOnGlass(value.location) {
                    Haptics.tap(.medium)
                    sheens += 1
                }
                release()
            }
    }

    private func lightVector(for point: CGPoint) -> CGSize {
        let x = (point.x - Self.card.width / 2) / (Self.glass.width / 2)
        let y = (point.y - Self.card.height / 2) / (Self.glass.height / 2)
        return CGSize(width: x.clamped(to: -1...1), height: y.clamped(to: -1...1))
    }

    private func isOnGlass(_ point: CGPoint) -> Bool {
        abs(point.x - Self.card.width / 2) < Self.glass.width / 2
            && abs(point.y - Self.card.height / 2) < Self.glass.height / 2
    }

    private func release() {
        guard pressed || light != Self.restLight else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { pressed = false }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { light = Self.restLight }
    }

    private func stepPreview() {
        let next = Self.path[step % Self.path.count]
        step += 1
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { light = next }
        // Every third stop presses the glass and lets go.
        guard step % 3 == 0 else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.7)) { pressed = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            sheens += 1
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { pressed = false }
        }
    }

    private func playIntro() {
        stopIntro()
        introTask = Task { @MainActor in
            for _ in 0..<3 {
                stepPreview()
                try? await Task.sleep(for: .seconds(0.9))
                guard !Task.isCancelled else { return }
            }
            release()
            introTask = nil
        }
    }

    private func stopIntro() {
        introTask?.cancel()
        introTask = nil
    }
}

/// The wallpaper under the glass: soft colour fields plus a crisp dot grid, so refraction has detail to bend.
private struct ButtonSpecularBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B1D3A), Color(hex: 0x3A1D4F)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Group {
                Circle().fill(Palette.pink).frame(width: 150, height: 150).offset(x: -96, y: -52)
                Circle().fill(Palette.amber).frame(width: 120, height: 120).offset(x: 104, y: 46)
                Circle().fill(Palette.sky).frame(width: 170, height: 170).offset(x: 6, y: 86)
                Circle().fill(Palette.mint).frame(width: 96, height: 96).offset(x: 70, y: -84)
            }
            .blur(radius: 34)
            Canvas { context, size in
                let gap: CGFloat = 19
                var y: CGFloat = gap / 2
                while y < size.height {
                    var x: CGFloat = gap / 2
                    while x < size.width {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)),
                            with: .color(Color.white.opacity(0.42))
                        )
                        x += gap
                    }
                    y += gap
                }
            }
        }
    }
}

private struct ButtonSpecularGlass: View {
    let title: String
    let light: CGSize
    let pressed: Bool
    let sheens: Int
    let highlight: CGFloat
    let intensity: Double
    let refraction: CGFloat
    let card: CGSize
    let glass: CGSize

    /// Where the light lands on the glass, kept inside the capsule.
    private var spot: CGSize {
        CGSize(width: light.width * (glass.width / 2 - 26), height: light.height * (glass.height / 2 - 14))
    }

    var body: some View {
        ZStack {
            refracted
            Capsule().fill(pressed ? Color.black.opacity(0.16) : Color.white.opacity(0.1))
            innerShadow
            highlights
            farRim
            label
        }
        .frame(width: glass.width, height: glass.height)
        .clipShape(Capsule())
        .overlay(rim)
        .keyframeAnimator(initialValue: -1.0, trigger: sheens) { content, travel in
            content.overlay { ButtonSpecularSheen(travel: travel, glass: glass) }
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                MoveKeyframe(-1)
                CubicKeyframe(1, duration: 0.5)
            }
        }
        .shadow(color: .black.opacity(pressed ? 0.3 : 0.38), radius: pressed ? 7 : 18, y: pressed ? 4 : 12)
        .scaleEffect(pressed ? 0.955 : 1)
    }

    /// A magnified copy of the wallpaper that slides against the light: the lens effect.
    private var refracted: some View {
        ButtonSpecularBackdrop()
            .frame(width: card.width, height: card.height)
            .scaleEffect(1.18 + (pressed ? 0.06 : 0))
            .offset(x: -light.width * refraction * 44, y: -light.height * refraction * 26)
            .blur(radius: pressed ? 1.6 : 0.5)
            .saturation(1.25)
            .frame(width: glass.width, height: glass.height)
    }

    private var innerShadow: some View {
        Capsule()
            .strokeBorder(Color.black.opacity(pressed ? 0.5 : 0.28), lineWidth: pressed ? 12 : 7)
            .blur(radius: pressed ? 8 : 6)
            .offset(y: pressed ? 3 : 1)
    }

    private var highlights: some View {
        let width = highlight * (pressed ? 0.6 : 1)
        let peak = intensity * (pressed ? 1 : 0.8)
        // The specular hit: a hot core with a quick falloff, flattened into a streak.
        return Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: Color.white.opacity(peak), location: 0),
                        .init(color: Color.white.opacity(peak * 0.45), location: 0.3),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width / 2
                )
            )
            .frame(width: width, height: width)
            .scaleEffect(x: 1, y: pressed ? 0.32 : 0.4)
            .offset(spot)
            .blendMode(.plusLighter)
    }

    /// Light that crossed the glass and catches the far wall: a crescent hugging the edge opposite the highlight.
    private var farRim: some View {
        let rimOpacity: Double = Double(intensity) * 0.75
        let rimX: CGFloat = -light.width * glass.width / 2
        let rimY: CGFloat = -light.height * glass.height / 2
        return Capsule()
            .strokeBorder(Color.white.opacity(rimOpacity), lineWidth: 3.5)
            .blur(radius: 2.5)
            .mask {
                Circle()
                    .fill(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 160, height: 160)
                    .offset(x: rimX, y: rimY)
            }
            .blendMode(.plusLighter)
    }

    private var label: some View {
        HStack(spacing: 8) {
            Text(title)
            Image(systemName: "arrow.right")
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        .offset(x: -light.width * 3, y: -light.height * 2)
    }

    /// The rim is brightest where the light enters and picks up again where it leaves.
    private var rim: some View {
        let start = UnitPoint(x: 0.5 + light.width * 0.5, y: 0.5 + light.height * 0.5)
        let end = UnitPoint(x: 0.5 - light.width * 0.5, y: 0.5 - light.height * 0.5)
        return Capsule()
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.95), location: 0),
                        .init(color: Color.white.opacity(0.12), location: 0.55),
                        .init(color: Color.white.opacity(0.5), location: 1),
                    ],
                    startPoint: start,
                    endPoint: end
                ),
                lineWidth: 1.4
            )
    }

}

/// The quick diagonal sheen that crosses the glass after a tap.
private struct ButtonSpecularSheen: View {
    let travel: Double
    let glass: CGSize

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(width: 70, height: glass.height * 2)
            .rotationEffect(.degrees(20))
            .offset(x: CGFloat(travel) * (glass.width / 2 + 60))
            .opacity(1 - abs(travel) * 0.6)
            .blendMode(.plusLighter)
            .mask(Capsule().frame(width: glass.width, height: glass.height))
            .allowsHitTesting(false)
    }
}
