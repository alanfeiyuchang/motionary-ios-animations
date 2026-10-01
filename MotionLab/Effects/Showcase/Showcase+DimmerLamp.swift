import SwiftUI

extension Effect {
    static let showcaseDimmerLamp = Effect(
        id: "showcase.dimmer-lamp",
        category: .showcase,
        interaction: .gesture,
        name: L("Dim-to-Warm Lamp Tile", "暖光调光灯卡片"),
        summary: L(
            "Drag up and down to dim a pendant lamp: the bulb, the light cone, the colour temperature and the room wash follow your finger.",
            "上下拖动调节吊灯亮度：灯泡、光锥、色温与整间屋子的光都跟着手指变化。"
        ),
        prompt: L(
            "A 224 × 280 pt smart-home tile that is a dark room: a pendant lamp hangs from the top, a light cone falls to a pool on the floor, and the brightness percentage with its colour temperature sits bottom-left beside a slim level bar. A vertical drag anywhere changes brightness 1:1 (200 pt for the full range). Everything is derived from that one value: the bulb glow, the cone and floor pool opacity, a radial wash on the wall, the tile's outer glow, and the colour, which runs from amber 2200 K when dim to soft white 4000 K at full. Past 0% or 100% the tile rubber-bands, stretching up to 5% in the drag direction with a rigid tick, and springs back on release. A double tap toggles the lamp with a spring (response 0.5 s, damping 0.62), a bloom expanding from the bulb and a pendant swing. Cosy.",
            "224 × 280pt 的智能家居卡片，是一间暗着的小屋：吊灯从顶部垂下，光锥落到地面成一汪光斑，左下角是亮度百分比与色温，旁有细长亮度条。上下拖动即可 1:1 调光（200pt 走完全程）。一切由这一数值推导：灯泡辉光、光锥与地面光斑的不透明度、墙面径向光晕、卡片外发光，以及颜色——暗时 2200K 琥珀，全亮时 4000K 柔白。拖过 0% 或 100% 时卡片橡皮筋式拉伸，最多 5%，并给一次硬触感，松手弹回。双击开关灯：弹簧（响应 0.5 秒、阻尼 0.62）过渡，灯泡处泛起柔光，吊灯轻轻摆动。温馨。"
        ),
        implementation: L(
            "One level value drives opacity, shadow radius and interpolated colours of layered gradients (cone, floor pool, wall wash in plusLighter). A zero-distance DragGesture maps translation to the level, rubber-bands the overshoot into an anchored scaleEffect, and detects double taps by timing. The toggle animates the level with a spring while keyframeAnimator plays the bloom and the pendant swing.",
            "单一亮度值驱动多层渐变（光锥、地面光斑、plusLighter 的墙面光晕）的不透明度、阴影半径与插值颜色。零距离 DragGesture 把位移映射为亮度，把越界部分经橡皮筋函数转成带锚点的 scaleEffect，并通过计时识别双击。开关时用弹簧为亮度做动画，同时由 keyframeAnimator 播放柔光与吊灯摆动。"
        ),
        apis: ["DragGesture", "RadialGradient", "blendMode(.plusLighter)", "scaleEffect(x:y:anchor:)", "keyframeAnimator", "contentTransition(.numericText)"],
        tags: ["smart home", "lamp", "dimmer", "brightness", "light", "智能家居", "灯", "调光", "亮度", "色温"],
        params: [
            .slider("travel", L("Drag travel for 100%", "全程拖动距离"), 120...320, default: 200, decimals: 0, unit: "pt"),
            .toggle("warm", L("Dim to warm", "越暗越暖"), default: true),
            .slider("bloom", L("Toggle bloom", "开灯柔光"), 0...1.5, default: 1.0),
        ]
    ) { ctx in
        DimmerLampDemo(ctx: ctx)
    }
}

private struct DimmerLampDemo: View {
    let ctx: DemoContext
    @State private var level: Double = 0.68
    @State private var isOn = true
    @State private var stretch: CGFloat = 0
    @State private var dragging = false
    @State private var startLevel: Double = 0
    @State private var touchStart = Date()
    @State private var lastTap = Date.distantPast
    @State private var atLimit = false
    @State private var blooms = 0
    @State private var swings = 0
    @State private var scripting = false
    @State private var script: Task<Void, Never>?
    @GestureState private var finger = false

    private let size = CGSize(width: 224, height: 280)
    private let bulb = CGPoint(x: 112, y: 96)

    private var zh: Bool { ctx.language == .zh }
    private var lit: Double { isOn ? level : 0 }
    private var tone: Color {
        ctx.bool("warm") ? studioMix(0xFF8F33, 0xFFF0DA, lit) : Color(hex: 0xFFD9A3)
    }
    private var kelvin: Int {
        ctx.bool("warm") ? Int((2200 + 1800 * lit) / 50) * 50 : 3000
    }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                tile
                Spacer(minLength: 0)
                DemoHint(text: L("Drag up or down · double-tap to toggle", "上下拖动调光 · 双击开关"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 7.2, delay: 0.7) { runScript() }
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack {
            room
            lamp
            readout
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.18 + 0.2 * lit), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
        .shadow(color: tone.opacity(0.32 * lit), radius: 34)
        .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
        .scaleEffect(x: 1 - abs(stretch) / 900, y: 1 + abs(stretch) / 300, anchor: stretch > 0 ? .bottom : .top)
        .scaleEffect(dragging ? 0.985 : 1)
        .contentShape(shape)
        .gesture(dimGesture)
        .onChange(of: finger) { _, down in
            if !down && !scripting { endDrag() }
        }
    }

    // MARK: Room

    private var room: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1C1C21), Color(hex: 0x0D0D10)], startPoint: .top, endPoint: .bottom)
            // Wall wash.
            RadialGradient(colors: [tone.opacity(0.5), tone.opacity(0.12), .clear], center: UnitPoint(x: 0.5, y: 0.36), startRadius: 0, endRadius: 215)
                .opacity(lit)
                .blendMode(.plusLighter)
            // Floor.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color.white.opacity(0.07 + 0.1 * lit))
                    .frame(height: 1)
                LinearGradient(colors: [Color.black.opacity(0.22), Color.black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 58)
            }
            LampCone()
                .fill(LinearGradient(colors: [tone.opacity(0.42), tone.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                .frame(width: 204, height: 154)
                .position(x: bulb.x, y: bulb.y + 77)
                .blur(radius: 7)
                .opacity(lit)
                .blendMode(.plusLighter)
            Ellipse()
                .fill(tone)
                .frame(width: 166, height: 28)
                .blur(radius: 10)
                .opacity(0.55 * lit)
                .position(x: bulb.x, y: size.height - 30)
                .blendMode(.plusLighter)
        }
    }

    private var lamp: some View {
        ZStack {
            // Bloom on switch-on.
            Circle()
                .fill(RadialGradient(colors: [tone, tone.opacity(0)], center: .center, startRadius: 0, endRadius: 60))
                .frame(width: 120, height: 120)
                .keyframeAnimator(initialValue: 0.0, trigger: blooms) { content, p in
                    content
                        .scaleEffect(0.3 + 3.2 * p)
                        .opacity(p > 0 && p < 1 ? (1 - p) * 0.6 * ctx["bloom"] : 0)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(0.0)
                        CubicKeyframe(0.6, duration: 0.22)
                        CubicKeyframe(1.0, duration: 0.5)
                    }
                }
                .position(bulb)
                .blendMode(.plusLighter)
            pendant
                .keyframeAnimator(initialValue: 0.0, trigger: swings) { content, angle in
                    content.rotationEffect(.degrees(angle), anchor: .top)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(3.6, duration: 0.22)
                        CubicKeyframe(-2.2, duration: 0.42)
                        CubicKeyframe(1.1, duration: 0.42)
                        CubicKeyframe(0, duration: 0.45)
                    }
                }
        }
        .allowsHitTesting(false)
    }

    /// Cord, shade and bulb, laid out from the top edge of the tile.
    private var pendant: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 1.5, height: 54)
            // Bulb with its halo, half hidden by the shade.
            Circle()
                .fill(RadialGradient(colors: [.white, tone], center: .center, startRadius: 0, endRadius: 11))
                .frame(width: 20, height: 20)
                .opacity(0.25 + 0.75 * lit)
                .shadow(color: tone.opacity(lit), radius: 6 + 18 * lit)
                .shadow(color: tone.opacity(0.7 * lit), radius: 30 * lit)
                .offset(y: 86)
            LampShade()
                .fill(LinearGradient(colors: [Color(hex: 0x4A4A52), Color(hex: 0x202024)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(LampShade().stroke(Color.white.opacity(0.14), lineWidth: 1))
                .frame(width: 86, height: 42)
                .offset(y: 52)
            // Lit inner rim.
            Capsule()
                .fill(tone)
                .frame(width: 80, height: 4)
                .opacity(0.15 + 0.85 * lit)
                .shadow(color: tone.opacity(lit), radius: 6)
                .offset(y: 92)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    // MARK: Readout

    private var readout: some View {
        let percent = Int((lit * 100).rounded())
        return HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Image(systemName: isOn && percent > 0 ? "lightbulb.fill" : "lightbulb")
                        .foregroundStyle(isOn && percent > 0 ? tone : Signature.textSecondary)
                        .contentTransition(.symbolEffect(.replace))
                    Text(verbatim: zh ? "客厅吊灯" : "Living room")
                }
                .signatureEyebrow()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(percent, format: .number)
                        .font(Signature.number(40))
                        .contentTransition(.numericText(value: Double(percent)))
                        .animation(.snappy(duration: 0.2), value: percent)
                    Text(verbatim: "%")
                        .font(Signature.number(18))
                        .foregroundStyle(Signature.textSecondary)
                }
                .foregroundStyle(Color.white)
                Text(verbatim: isOn && percent > 0 ? "\(kelvin) K" : (zh ? "已关闭" : "Off"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Signature.textSecondary)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
            levelBar
        }
        .padding(16)
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private var levelBar: some View {
        let height: CGFloat = 88
        return ZStack(alignment: .bottom) {
            Capsule()
                .fill(Color.white.opacity(0.1))
            Capsule()
                .fill(tone)
                .frame(height: max(8, height * CGFloat(lit)))
                .shadow(color: tone.opacity(0.7 * lit), radius: 6)
        }
        .frame(width: 8, height: height)
        .scaleEffect(x: dragging ? 1.5 : 1, anchor: .trailing)
    }

    // MARK: Gesture

    private var dimGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($finger) { _, state, _ in state = true }
            .onChanged { value in
                if !dragging {
                    script?.cancel()
                    scripting = false
                    beginDrag()
                }
                guard abs(value.translation.height) > 3 || abs(stretch) > 0 || lit != startLevel else { return }
                setLevel(raw: startLevel - Double(value.translation.height) / ctx["travel"])
            }
            .onEnded { value in
                let moved = abs(value.translation.height) + abs(value.translation.width)
                let wasTap = moved < 8 && Date().timeIntervalSince(touchStart) < 0.3
                endDrag()
                if wasTap { registerTap() }
            }
    }

    private func beginDrag() {
        startLevel = lit
        touchStart = Date()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dragging = true }
    }

    /// Shared by the finger and the scripted drag. `raw` may leave 0…1; the excess rubber-bands the tile.
    private func setLevel(raw: Double) {
        let clamped = raw.clamped(to: 0...1)
        level = clamped
        isOn = clamped > 0.004
        let over = raw > 1 ? raw - 1 : (raw < 0 ? raw : 0)
        stretch = rubberBand(CGFloat(over * ctx["travel"]), limit: 15)
        let limit = over != 0
        if limit != atLimit {
            atLimit = limit
            if limit && !ctx.isPreview && !scripting { Haptics.tap(.rigid) }
        }
    }

    private func endDrag() {
        guard dragging else { return }
        atLimit = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            stretch = 0
            dragging = false
        }
    }

    /// Two taps within 0.45 s toggle the lamp.
    private func registerTap() {
        let now = Date()
        if now.timeIntervalSince(lastTap) < 0.45 {
            lastTap = .distantPast
            Haptics.tap(.medium)
            toggle()
        } else {
            lastTap = now
        }
    }

    private func toggle() {
        let turningOn = !(isOn && level > 0.004)
        if turningOn && level < 0.08 { level = 0.6 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { isOn = turningOn }
        if turningOn { blooms += 1 }
        swings += 1
    }

    private func runScript() {
        script?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            if !isOn { toggle() }
            let legs: [(Double, Double)] = [(1.08, 1.0), (0.2, 1.2)]
            var from = lit
            for (target, duration) in legs {
                let origin = from
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dragging = true }
                guard await studioScript(duration, { t in setLevel(raw: origin + (target - origin) * studioEase(t)) }) else {
                    endDrag()
                    return
                }
                endDrag()
                from = target.clamped(to: 0...1)
                guard await studioPause(0.3) else { return }
            }
            toggle()
            guard await studioPause(0.9) else { return }
            level = 0.68
            toggle()
        }
    }
}

// MARK: - Shapes

private struct LampShade: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.5 - 9, y: rect.minY),
            control1: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.35),
            control2: CGPoint(x: rect.minX + w * 0.24, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + w * 0.5 + 9, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.minX + w * 0.76, y: rect.minY),
            control2: CGPoint(x: rect.minX + w * 0.98, y: rect.minY + h * 0.35)
        )
        path.closeSubpath()
        return path
    }
}

/// The light cone: narrow under the shade, wide at the floor.
private struct LampCone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 38, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + 38, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
