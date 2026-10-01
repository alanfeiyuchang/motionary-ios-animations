import SwiftUI

extension Effect {
    static let buttonsKeycap = Effect(
        id: "buttons.keycap",
        category: .buttons,
        interaction: .tap,
        name: L("Mechanical Keycap", "机械键帽"),
        summary: L(
            "Sculpted keycaps travel down along their side walls, click at the bottom and wobble back up.",
            "立体键帽沿侧壁下沉，触底“咔哒”一声，再带着轻晃弹回。"
        ),
        prompt: L(
            "Three sculpted keycaps sit in a recessed keyboard plate, seen from slightly above: each has a dished top face, tapered side walls 16 pt tall with a taller front wall, a backlit legend and a soft shadow thrown onto the plate. Pressing a key drives the cap 9 pt straight down on a stiff spring (response 0.13 s, damping 0.85): the walls slide into the plate so less of them shows, the cast shadow shortens from 13 to 4 pt, and the coloured underglow around the skirt and the legend brighten. A rigid click haptic lands at the bottom, 50 ms after touch-down. On release the cap returns on a loose spring (response 0.32 s, damping 0.42), overshooting above rest and rocking about 1.5° on its stem before settling, with a softer upstroke tick. Tactile and mechanical.",
            "三枚立体键帽嵌在下沉的键盘定位板里，视角略高：每枚都有微凹的顶面、16pt 高的斜侧壁（正面更高）、透光字符，并在板面上投下柔和阴影。按下时键帽由硬弹簧（响应 0.13 秒、阻尼 0.85）垂直下压 9pt：侧壁滑入板内而露出更少，投影从 13pt 缩短到 4pt，裙边一圈彩色底光和字符同时变亮。触底时（按下后 50 毫秒）给出一次清脆的刚性触感。松手后键帽以松弹簧（响应 0.32 秒、阻尼 0.42）回升，越过静止高度，并在轴心上摇晃约 1.5° 后落定，伴随更轻的回弹触感。机械、真实、有段落感。"
        ),
        implementation: L(
            "Each cap is an Animatable view whose depth (0…1) is spring-animated by a LatchedPress button style; a Canvas stacks 26 interpolated rounded rects from skirt to face, drops the layers that sink below the plate, and offsets the face, legend, shadow and underglow from the same depth. The wobble is the spring's own overshoot mapped to a rotation.",
            "每枚键帽都是 Animatable 视图，按压深度（0…1）由带 LatchedPress 的按钮样式以弹簧驱动；Canvas 从裙边到顶面叠出 26 层插值圆角矩形，丢弃沉到板面以下的层，并用同一深度推算顶面、字符、投影与底光的位置。回弹的晃动就是弹簧自身的过冲映射成的旋转。"
        ),
        apis: ["Animatable", "Canvas", "ButtonStyle", "spring(response:dampingFraction:)", "rotationEffect"],
        tags: ["keycap", "mechanical", "3D", "click", "键帽", "机械键盘", "立体", "按键"],
        params: [
            .slider("travel", L("Key travel", "键程"), 4...14, default: 9, decimals: 0, unit: "pt"),
            .slider("height", L("Cap height", "键帽高度"), 12...22, default: 16, decimals: 0, unit: "pt"),
            .slider("glow", L("Underglow", "底光强度"), 0...1, default: 0.6),
            .slider("wobble", L("Rebound wobble", "回弹晃动"), 0...4, default: 1.5, decimals: 1, unit: "°"),
        ]
    ) { ctx in
        ButtonKeycapDemo(ctx: ctx)
    }
}

private struct ButtonKeycapSpec {
    let symbol: String
    let tint: Color
    let accent: Bool
}

private struct ButtonKeycapDemo: View {
    let ctx: DemoContext
    @Environment(\.colorScheme) private var colorScheme
    /// The key the script is holding down (preview loop, detail intro).
    @State private var forced: Int?
    @State private var step = 0
    @State private var scriptTask: Task<Void, Never>?

    private let keys: [ButtonKeycapSpec] = [
        ButtonKeycapSpec(symbol: "command", tint: Palette.sky, accent: false),
        ButtonKeycapSpec(symbol: "shift", tint: Palette.violet, accent: false),
        ButtonKeycapSpec(symbol: "return", tint: Palette.coral, accent: true),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            plate
            Spacer()
            DemoHint(text: L("Press the keys", "按下这些按键"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.62, delay: 0.4) {
            if ctx.isPreview { strike(step) } else { playIntro() }
        }
        .onDisappear {
            scriptTask?.cancel()
            scriptTask = nil
            forced = nil
        }
    }

    private var plate: some View {
        let dark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return HStack(spacing: 8) {
            ForEach(keys.indices, id: \.self) { index in
                ButtonKeycapKey(
                    spec: keys[index],
                    forced: forced == index,
                    travel: min(ctx.cg("travel"), ctx.cg("height") - 2),
                    height: ctx.cg("height"),
                    glow: ctx["glow"],
                    wobble: ctx["wobble"]
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background {
            shape.fill(
                LinearGradient(
                    colors: dark
                        ? [Color(hex: 0x0C0C10), Color(hex: 0x17171D)]
                        : [Color(hex: 0xC9CCD6), Color(hex: 0xDDDFE7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .overlay {
            // Rim: dark lip at the top, light catch at the bottom, so the plate reads as recessed.
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.black.opacity(dark ? 0.6 : 0.16), Color.white.opacity(dark ? 0.1 : 0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1.5
            )
        }
    }

    /// One scripted keystroke: down for 0.2 s, then up.
    private func strike(_ index: Int) {
        step = index + 1
        forced = index % keys.count
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            forced = nil
        }
    }

    private func playIntro() {
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            for index in keys.indices {
                forced = index
                try? await Task.sleep(for: .seconds(0.2))
                guard !Task.isCancelled else { return }
                forced = nil
                try? await Task.sleep(for: .seconds(0.28))
                guard !Task.isCancelled else { return }
            }
        }
    }
}

private struct ButtonKeycapKey: View {
    let spec: ButtonKeycapSpec
    let forced: Bool
    let travel: CGFloat
    let height: CGFloat
    let glow: Double
    let wobble: Double
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
        } label: {
            Color.clear.frame(width: ButtonKeycapMetrics.size.width, height: ButtonKeycapMetrics.size.height)
        }
        .buttonStyle(
            ButtonKeycapStyle(spec: spec, forced: forced, taps: taps, travel: travel, height: height, glow: glow, wobble: wobble)
        )
    }
}

private struct ButtonKeycapStyle: ButtonStyle {
    let spec: ButtonKeycapSpec
    let forced: Bool
    let taps: Int
    let travel: CGFloat
    let height: CGFloat
    let glow: Double
    let wobble: Double

    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(
            isPressed: configuration.isPressed,
            taps: taps,
            forced: forced,
            minimumHold: 0.12,
            pressDelay: 0.05,
            onPress: { Haptics.tap(.rigid) },
            onRelease: { Haptics.tap(.soft) }
        ) { pressed in
            ButtonKeycapBody(depth: pressed ? 1 : 0, spec: spec, travel: travel, height: height, glow: glow, wobble: wobble)
                .animation(
                    pressed
                        ? .spring(response: 0.13, dampingFraction: 0.85)
                        : .spring(response: 0.32, dampingFraction: 0.42),
                    value: pressed
                )
                .contentShape(Rectangle())
        }
    }
}

private enum ButtonKeycapMetrics {
    static let size = CGSize(width: 88, height: 110)
    /// Footprint of the skirt on the plate.
    static let base = CGRect(x: 4, y: 24, width: 80, height: 80)
    static let baseRadius: CGFloat = 17
    /// How far the walls taper in from skirt to face.
    static let taper: CGFloat = 10
    static let layers = 26
}

/// One keycap at a given press depth. Animatable, so the spring's overshoot reaches the Canvas.
private struct ButtonKeycapBody: View, Animatable {
    var depth: CGFloat
    let spec: ButtonKeycapSpec
    let travel: CGFloat
    let height: CGFloat
    let glow: Double
    let wobble: Double
    @Environment(\.colorScheme) private var colorScheme

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    /// Height of the face above the plate right now.
    private var lift: CGFloat { height - travel * depth }
    private var pressure: Double { Double(depth.clamped(to: 0...1)) }

    var body: some View {
        let base = ButtonKeycapMetrics.base
        let faceCenterY = base.midY - lift
        ZStack {
            shadow(base: base)
            underglow(base: base)
            Canvas { context, _ in
                drawWell(&context, base: base)
                drawCap(&context, base: base)
            }
            Image(systemName: spec.symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(legendColor)
                .shadow(color: spec.tint.opacity(spec.accent ? 0 : glow * (0.35 + 0.65 * pressure)), radius: 5)
                .position(x: base.midX, y: faceCenterY)
        }
        .frame(width: ButtonKeycapMetrics.size.width, height: ButtonKeycapMetrics.size.height)
        // Off-axis stem wobble: largest mid-travel, and it flips sign while the release spring overshoots.
        .rotationEffect(.degrees(wobble * sin(Double(depth) * .pi)), anchor: .bottom)
    }

    private var legendColor: Color {
        if spec.accent { return .white }
        let dark = colorScheme == .dark
        return dark
            ? spec.tint.opacity(0.75 + 0.25 * pressure)
            : Color(hex: 0x3C3F4D).opacity(0.85)
    }

    /// Shadow cast onto the plate: long while the cap stands tall, short at the bottom of the stroke.
    private func shadow(base: CGRect) -> some View {
        let reach = 4 + 9 * (1 - depth.clamped(to: -0.3...1))
        return RoundedRectangle(cornerRadius: ButtonKeycapMetrics.baseRadius, style: .continuous)
            .fill(Color.black.opacity(colorScheme == .dark ? 0.55 : 0.26))
            .frame(width: base.width - 6, height: base.height - 8)
            .blur(radius: 5)
            .position(x: base.midX, y: base.midY + reach)
    }

    /// The LED under the switch leaks out around the skirt, and more of it when the cap is down.
    private func underglow(base: CGRect) -> some View {
        RoundedRectangle(cornerRadius: ButtonKeycapMetrics.baseRadius + 2, style: .continuous)
            .stroke(spec.tint, lineWidth: 5)
            .frame(width: base.width, height: base.height)
            .blur(radius: 6)
            .opacity(glow * (0.3 + 0.7 * pressure))
            .position(x: base.midX, y: base.midY)
    }

    private func drawWell(_ context: inout GraphicsContext, base: CGRect) {
        let well = Path(roundedRect: base.insetBy(dx: 1, dy: 1), cornerRadius: ButtonKeycapMetrics.baseRadius, style: .continuous)
        context.fill(well, with: .color(Color.black.opacity(colorScheme == .dark ? 0.7 : 0.3)))
    }

    private func drawCap(_ context: inout GraphicsContext, base: CGRect) {
        let dark = colorScheme == .dark
        let count = ButtonKeycapMetrics.layers
        let taper = ButtonKeycapMetrics.taper
        let sink = travel * depth
        let wallLow = wallColor(dark: dark, top: false)
        let wallHigh = wallColor(dark: dark, top: true)
        for index in 0...count {
            let t = CGFloat(index) / CGFloat(count)
            let z = height * t - sink
            // Layers that have sunk below the plate are hidden inside the well.
            guard z >= -0.5 else { continue }
            let rect = base.insetBy(dx: taper * t, dy: taper * t).offsetBy(dx: 0, dy: -z)
            let radius = ButtonKeycapMetrics.baseRadius - 4 * t
            let path = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
            if index < count {
                context.fill(path, with: .color(wallLow.mix(with: wallHigh, by: Double(t))))
            } else {
                drawFace(&context, path: path, rect: rect, dark: dark)
            }
        }
    }

    private func drawFace(_ context: inout GraphicsContext, path: Path, rect: CGRect, dark: Bool) {
        let top: Color
        let bottom: Color
        if spec.accent {
            top = Color(hex: 0xFF8A66)
            bottom = Color(hex: 0xF0603F)
        } else {
            top = dark ? Color(hex: 0x4A4C58) : Color(hex: 0xFFFFFF)
            bottom = dark ? Color(hex: 0x363842) : Color(hex: 0xECEDF2)
        }
        // Dished face: slightly darker toward the top, where the scoop turns away from the light.
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [bottom, top]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [Color.white.opacity(dark ? 0.28 : 0.9), Color.white.opacity(0.02)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ),
            lineWidth: 1
        )
    }

    private func wallColor(dark: Bool, top: Bool) -> Color {
        if spec.accent {
            return top ? Color(hex: 0xE2553A) : Color(hex: 0xA5361F)
        }
        if dark {
            return top ? Color(hex: 0x2E3039) : Color(hex: 0x17181D)
        }
        return top ? Color(hex: 0xDADCE4) : Color(hex: 0xA9ACB9)
    }
}
