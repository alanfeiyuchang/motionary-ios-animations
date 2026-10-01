import SwiftUI

extension Effect {
    static let inputsHueSlider = Effect(
        id: "inputs.hue-slider",
        category: .inputs,
        interaction: .gesture,
        name: L("Hue Slider with Loupe", "色相滑块与放大镜"),
        summary: L("A drop-shaped loupe pops out of the thumb with the picked colour, sways as you drag, and the card above tints live.", "水滴形放大镜从滑块里弹出显示所选颜色，拖动时随之摇摆，上方卡片实时染色。"),
        prompt: L(
            "A 280 × 26 pt rainbow hue track with a white 32 pt ring thumb, under a preview card whose tile, button, progress bar, hex code and glow take the picked colour live. On touch-down a teardrop loupe, a 58 pt disc with a pointed tail and a 3 pt white rim, springs out of the thumb, scaling from 20% around its tip (response 0.32 s, damping 0.6), filled with the colour and labelled with the hue in degrees. While dragging, the loupe sways like a balloon on a string: it leans up to 22° against the direction of travel in proportion to speed, then swings upright on a loose spring (response 0.3 s, damping 0.45) when the finger pauses. A selection haptic ticks every 30° of hue. On release the loupe drops back into the thumb (damping 0.8), which swells to 128% and settles as it absorbs it.",
            "280 × 26pt 的彩虹色相轨道配白色 32pt 环形滑块，上方预览卡片的色块、按钮、进度条、色值与光晕实时跟随所选颜色。按下时，水滴形放大镜（58pt 圆盘带尖尾、3pt 白边）以尖端为锚点从 20% 弹出（弹簧响应 0.32 秒、阻尼 0.6），填充所选颜色并标注色相角度。拖动时放大镜像拴在线上的气球一样摇摆：按速度向运动反方向倾斜最多 22°，手指停顿后以松弛弹簧（响应 0.3 秒、阻尼 0.45）摆正；色相每变化 30° 一次选择触觉。松手后放大镜落回滑块（阻尼 0.8），滑块鼓到 128% 再回落。"
        ),
        implementation: L(
            "The whole stage is an Animatable view keyed on hue, so scripted glides interpolate in hue space rather than RGB. The loupe is a custom teardrop Shape scaled and rotated around its tip; drag velocity sets the lean and a debounced task releases it, and a keyframeAnimator pulses the thumb on each drop.",
            "整个舞台是一个以色相为动画数据的 Animatable 视图，因此脚本滑动在色相空间而非 RGB 中插值。放大镜是自定义水滴 Shape，以尖端为锚点缩放与旋转；拖动速度决定倾角并由去抖任务释放，keyframeAnimator 在每次落下时让滑块鼓起。"
        ),
        apis: ["Animatable", "Shape", "DragGesture", "keyframeAnimator", "Color(hue:saturation:brightness:)"],
        tags: ["slider", "hue", "color picker", "loupe", "tint", "滑块", "色相", "取色", "放大镜", "染色"],
        params: [
            .slider("size", L("Loupe size", "放大镜大小"), 44...76, default: 58, decimals: 0, unit: "pt"),
            .slider("pop", L("Pop damping", "弹出阻尼"), 0.35...1.0, default: 0.6),
            .slider("sway", L("Sway", "摇摆幅度"), 0...1.5, default: 1),
            .slider("sat", L("Saturation", "饱和度"), 0.3...1.0, default: 0.85),
        ]
    ) { ctx in
        InputHueSliderDemo(ctx: ctx)
    }
}

private struct InputHueSliderDemo: View {
    let ctx: DemoContext
    @State private var hue: Double = 0.58
    @State private var pressing: Bool
    @State private var lean: Double = 0
    @State private var drops = 0
    @State private var step = 0
    @State private var settleTask: Task<Void, Never>?
    @GestureState private var touching = false

    private let width: CGFloat = 280
    private static let previewHues: [Double] = [0.92, 0.08, 0.36, 0.58]

    init(ctx: DemoContext) {
        self.ctx = ctx
        _pressing = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            InputHueStage(
                hue: hue,
                saturation: ctx["sat"],
                pressing: pressing,
                lean: lean,
                drops: drops,
                loupe: ctx.cg("size"),
                popDamping: ctx["pop"],
                language: ctx.language
            )
            .overlay(alignment: .bottom) {
                Color.clear
                    .frame(width: width + 32, height: 64)
                    .contentShape(Rectangle())
                    .gesture(drag)
                    .offset(y: 19)
            }
            Spacer(minLength: 0)
            DemoHint(text: L("Press and drag along the track", "按住并沿轨道拖动"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: touching) { _, down in
            if !down { drop() }
        }
        .autoplay(ctx.isPreview, every: 1.0, delay: 0.4) { previewTick() }
        .onDisappear { settleTask?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if !pressing { press() }
                let newHue = Double((value.location.x - 16) / width).clamped(to: 0...1)
                if Int(newHue * 12) != Int(hue * 12) { Haptics.selection() }
                hue = newHue
                let target = (-Double(value.velocity.width) / 45).clamped(to: -22...22) * ctx["sway"]
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { lean = target }
                settleTask?.cancel()
                settleTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(90))
                    guard !Task.isCancelled else { return }
                    upright()
                }
            }
            .onEnded { _ in drop() }
    }

    private func press() {
        withAnimation(.spring(response: 0.32, dampingFraction: ctx["pop"])) { pressing = true }
        Haptics.tap(.soft)
    }

    private func upright() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { lean = 0 }
    }

    /// Finger lifted, gesture cancelled or autoplay: the loupe falls back into the thumb.
    private func drop() {
        guard pressing else { return }
        settleTask?.cancel()
        upright()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { pressing = false }
        drops += 1
        Haptics.tap(.light)
    }

    private func previewTick() {
        let phase = step % 3
        step += 1
        if phase == 2 {
            drop()
            return
        }
        if !pressing { press() }
        let target = Self.previewHues[(step / 3 * 2 + phase) % Self.previewHues.count]
        let direction: Double = target > hue ? -1 : 1
        withAnimation(.smooth(duration: 0.75)) { hue = target }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { lean = 18 * direction * ctx["sway"] }
        settleTask?.cancel()
        settleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))
            guard !Task.isCancelled else { return }
            upright()
            // The detail intro plays one glide; it must not leave the loupe out.
            guard !ctx.isPreview else { return }
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled, !touching else { return }
            drop()
        }
    }
}

private func inputHueRGB(_ hue: Double, _ saturation: Double, _ brightness: Double) -> (r: Double, g: Double, b: Double) {
    let h = (hue - floor(hue)) * 6
    let sector = Int(h) % 6
    let f = h - floor(h)
    let p = brightness * (1 - saturation)
    let q = brightness * (1 - saturation * f)
    let t = brightness * (1 - saturation * (1 - f))
    switch sector {
    case 0: return (brightness, t, p)
    case 1: return (q, brightness, p)
    case 2: return (p, brightness, t)
    case 3: return (p, q, brightness)
    case 4: return (t, p, brightness)
    default: return (brightness, p, q)
    }
}

/// Card, track and loupe. Animatable on hue, so every frame of a glide shows a true hue, not an RGB blend.
private struct InputHueStage: View, Animatable {
    var hue: Double
    let saturation: Double
    let pressing: Bool
    let lean: Double
    let drops: Int
    let loupe: CGFloat
    let popDamping: Double
    let language: AppLanguage

    var animatableData: Double {
        get { hue }
        set { hue = newValue }
    }

    private let width: CGFloat = 280
    private let trackHeight: CGFloat = 26

    private var clampedHue: Double { hue.clamped(to: 0...1) }
    private var color: Color { Color(hue: clampedHue * 0.999, saturation: saturation, brightness: 0.96) }
    private var rgb: (r: Double, g: Double, b: Double) { inputHueRGB(clampedHue * 0.999, saturation, 0.96) }
    private var ink: Color {
        let c = rgb
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b > 0.66 ? Color(hex: 0x16161A) : .white
    }

    private var hex: String {
        let c = rgb
        return String(format: "#%02X%02X%02X", Int((c.r * 255).rounded()), Int((c.g * 255).rounded()), Int((c.b * 255).rounded()))
    }

    var body: some View {
        VStack(spacing: 0) {
            card
            Color.clear.frame(height: 94)
            track
        }
    }

    // MARK: Tinted card

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(
                        colors: [color, Color(hue: (clampedHue + 0.09).truncatingRemainder(dividingBy: 1), saturation: saturation, brightness: 0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "paintpalette.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(ink))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Accent", "强调色"), language)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(verbatim: hex)
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(L("Apply", "应用"), language)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(color, in: Capsule())
            }
            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color).frame(width: 110)
                }
                .frame(height: 8)
                ForEach(0..<3, id: \.self) { index in
                    let shifted = (clampedHue + Double(index + 1) * 0.07).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .fill(Color(hue: shifted, saturation: saturation * 0.9, brightness: 0.96))
                        .frame(width: 16, height: 16)
                }
            }
        }
        .padding(16)
        .frame(width: width)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(color.opacity(0.35), lineWidth: 1))
        .shadow(color: color.opacity(0.35), radius: 22, y: 12)
    }

    // MARK: Track, thumb, loupe

    private var track: some View {
        let x: CGFloat = width * CGFloat(clampedHue)
        let stops: [Color] = (0...12).map { Color(hue: Double($0) / 12 * 0.999, saturation: saturation, brightness: 0.96) }
        return ZStack {
            Capsule()
                .fill(LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing))
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                .frame(width: width + trackHeight, height: trackHeight)
            thumb
                .position(x: x, y: trackHeight / 2)
            loupeView
                .position(x: x, y: 0)
        }
        .frame(width: width, height: trackHeight)
    }

    private var thumb: some View {
        ZStack {
            Circle().fill(Color.white)
            Circle().fill(color).padding(5)
        }
        .frame(width: 32, height: 32)
        .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
        .scaleEffect(pressing ? 0.86 : 1)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: drops) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(1, duration: 0.14)
                CubicKeyframe(1.28, duration: 0.1)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
            }
        }
    }

    /// Zero-size anchor at the loupe's tip; the teardrop grows upward from it.
    private var loupeView: some View {
        let tail: CGFloat = loupe * 0.3
        return ZStack {
            InputHueTeardrop(tail: tail)
                .fill(color)
            InputHueTeardrop(tail: tail)
                .stroke(Color.white, lineWidth: 3)
            Text(verbatim: "\(Int((clampedHue * 360).rounded()))°")
                .font(.system(size: loupe * 0.27, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(ink)
                .offset(y: -tail / 2)
        }
        .frame(width: loupe, height: loupe + tail)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
        .scaleEffect(pressing ? 1 : 0.2, anchor: .bottom)
        .rotationEffect(.degrees(lean), anchor: .bottom)
        .opacity(pressing ? 1 : 0)
        .offset(y: -(loupe + tail) / 2 - (pressing ? 10 : -14))
        .allowsHitTesting(false)
    }
}

/// A disc with a pointed tail at the bottom centre.
private struct InputHueTeardrop: Shape {
    let tail: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = min(rect.width, rect.height - tail) / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + radius)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        var path = Path()
        // In SwiftUI's flipped space 90° points down: leave a 70° gap at the bottom for the tail.
        path.addArc(center: center, radius: radius, startAngle: .degrees(125), endAngle: .degrees(415), clockwise: false)
        path.addQuadCurve(to: tip, control: CGPoint(x: rect.midX + radius * 0.2, y: center.y + radius * 1.05))
        let start = CGPoint(x: center.x + radius * CGFloat(cos(125 * Double.pi / 180)), y: center.y + radius * CGFloat(sin(125 * Double.pi / 180)))
        path.addQuadCurve(to: start, control: CGPoint(x: rect.midX - radius * 0.2, y: center.y + radius * 1.05))
        path.closeSubpath()
        return path
    }
}
