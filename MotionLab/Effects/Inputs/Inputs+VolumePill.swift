import SwiftUI

extension Effect {
    static let inputsVolumePill = Effect(
        id: "inputs.volume-pill",
        category: .inputs,
        interaction: .gesture,
        name: L("Control Centre Pills", "控制中心药丸滑块"),
        summary: L("Fat vertical sliders: the fill tracks your finger, the pill stretches like rubber at the limits, the icon steps through levels.", "粗壮的竖向滑块：填充紧跟手指，到头后药丸像橡皮一样被拉长，图标逐级切换。"),
        prompt: L(
            "Two Control Centre style sliders, brightness and volume, on a blurred wallpaper tile: 80 × 196 pt pills with 30 pt continuous corners, dark translucent glass with a near-white fill rising from the bottom and a glyph near the base. Touching a pill swells it to 105% on a spring (response 0.3 s, damping 0.7) and a percentage fades in above; dragging anywhere changes the level relative to the touch, 1:1. Past either limit the pill rubber-bands: it stretches up to 44 pt along the drag, anchored at the opposite end, and narrows to conserve volume, with a medium haptic on contact. Release snaps it back on an underdamped spring (response 0.35 s, damping 0.55) with a visible wobble. The glyph steps through its levels with a symbol replace and flips from white to dark once the fill covers it; the brightness pill dims the wallpaper live. Chunky, elastic, system-grade.",
            "模糊壁纸卡片上的两枚控制中心风格滑块：80 × 196pt、30pt 连续圆角的药丸，深色半透明玻璃底，近白色填充自底部升起，底部一枚图标。按下时药丸以弹簧（响应 0.3 秒、阻尼 0.7）鼓到 105%，上方淡入百分比；在药丸任意位置拖动，数值相对落点 1:1 变化。越过任一极限出现橡皮筋效果：以另一端为锚点沿拖动方向最多拉长 44pt，同时变窄，触边瞬间一次中等触觉。松手后以欠阻尼弹簧（响应 0.35 秒、阻尼 0.55）弹回。图标通过符号替换逐级变化，被填充盖住后由白转深；亮度药丸压暗壁纸。"
        ),
        implementation: L(
            "Each pill keeps a start level and maps DragGesture translation to the value; overflow goes through a rubber-band curve into an anisotropic scaleEffect anchored at the far end. A stored edge flag keeps the anchor fixed while the release spring wobbles, and the glyph is an SF Symbol chosen from the level with contentTransition(.symbolEffect(.replace)).",
            "每个药丸记录起始数值，把 DragGesture 位移映射为取值；溢出量经橡皮筋曲线转成以远端为锚点的非等比 scaleEffect。用一个存储的边缘标记让回弹晃动时锚点保持不变，图标按数值选取 SF Symbol 并使用 contentTransition(.symbolEffect(.replace))。"
        ),
        apis: ["DragGesture", "scaleEffect(x:y:anchor:)", "spring(response:dampingFraction:)", "contentTransition(.symbolEffect(.replace))", "@GestureState"],
        tags: ["slider", "volume", "brightness", "control center", "rubber band", "滑块", "音量", "亮度", "控制中心", "橡皮筋"],
        params: [
            .slider("limit", L("Stretch limit", "拉伸上限"), 16...80, default: 44, decimals: 0, unit: "pt"),
            .slider("damping", L("Snap-back damping", "回弹阻尼"), 0.3...1.0, default: 0.55),
            .slider("press", L("Press scale", "按下放大"), 1.0...1.12, default: 1.05),
        ]
    ) { ctx in
        InputVolumePillDemo(ctx: ctx)
    }
}

private struct InputVolumePillDemo: View {
    let ctx: DemoContext
    @State private var brightness: Double = 0.72
    @State private var volume: Double = 0.46
    @State private var tick = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                wallpaper
                HStack(spacing: 24) {
                    InputCCPill(kind: .brightness, level: $brightness, tick: tick, ctx: ctx)
                    InputCCPill(kind: .volume, level: $volume, tick: tick, ctx: ctx)
                }
                .offset(y: 10)
            }
            .frame(width: 276, height: 280)
            Spacer(minLength: 0)
            DemoHint(text: L("Drag a pill past its top or bottom", "把药丸拖过顶端或底端"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.0, delay: 0.4) { tick += 1 }
    }

    private var wallpaper: some View {
        let shape = RoundedRectangle(cornerRadius: 38, style: .continuous)
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x3B2A8C), Color(hex: 0xB0407F), Color(hex: 0xF39A4A)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color(hex: 0x39D0D8)).frame(width: 200).blur(radius: 60).offset(x: -90, y: 90)
            Circle().fill(Color(hex: 0xFF5FA2)).frame(width: 160).blur(radius: 55).offset(x: 100, y: -90)
            Color.black.opacity((1 - brightness) * 0.5)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
    }
}

private enum InputCCPillKind {
    case brightness, volume

    func symbol(_ level: Double) -> String {
        switch self {
        case .brightness:
            if level <= 0.001 { return "sun.min" }
            return level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            if level <= 0.001 { return "speaker.slash.fill" }
            if level < 0.34 { return "speaker.wave.1.fill" }
            return level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        }
    }

    /// Autoplay script, one entry per tick (nil = rest).
    var script: [Double?] {
        switch self {
        case .brightness: return [nil, 0.9, nil, nil, -1, 0.72]
        case .volume: return [2, nil, nil, 0.3, nil, nil]
        }
    }
}

private struct InputCCPill: View {
    let kind: InputCCPillKind
    @Binding var level: Double
    let tick: Int
    let ctx: DemoContext

    @State private var stretch: CGFloat = 0
    @State private var pressing = false
    @State private var startLevel: Double = 0
    @State private var atEdge = false
    /// Which end is being pulled. Stored so the wobbling release keeps its anchor.
    @State private var pullingUp = true
    @GestureState private var touching = false

    private let size = CGSize(width: 80, height: 196)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        // Positive = stretched, negative = the spring's compression overshoot.
        let amount: CGFloat = pullingUp ? stretch : -stretch
        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.34)
            Color.white.opacity(0.1)
            Color.white.opacity(0.94)
                .frame(height: size.height * CGFloat(level))
            Image(systemName: kind.symbol(level))
                .font(.system(size: 24, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(level > 0.17 ? Color(hex: 0x2B2B30) : Color.white)
                .animation(.easeOut(duration: 0.2), value: level > 0.17)
                .frame(height: 30)
                .padding(.bottom, 20)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        .scaleEffect(
            x: 1 - amount / size.width * 0.28,
            y: 1 + amount / size.height,
            anchor: pullingUp ? .bottom : .top
        )
        .scaleEffect(pressing ? ctx.cg("press") : 1)
        .shadow(color: .black.opacity(pressing ? 0.35 : 0.2), radius: pressing ? 18 : 10, y: pressing ? 12 : 6)
        .overlay(alignment: .top) { readout }
        .contentShape(shape)
        .gesture(drag)
        .onChange(of: touching) { _, down in
            if !down { release() }
        }
        .onChange(of: tick) { _, value in play(value) }
    }

    private var readout: some View {
        Text(verbatim: "\(Int((level * 100).rounded()))%")
            .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .contentTransition(.numericText(value: level))
            .opacity(pressing ? 1 : 0)
            .offset(y: pressing ? -34 - max(pullingUp ? stretch : 0, 0) : -22)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if !pressing {
                    startLevel = level
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressing = true }
                }
                let raw: Double = startLevel - Double(value.translation.height / size.height)
                apply(raw: raw)
            }
            .onEnded { _ in release() }
    }

    /// Finger and autoplay both land here: clamp the value, send the overflow into the rubber band.
    private func apply(raw: Double) {
        let limit = ctx.cg("limit")
        withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.9)) {
            level = raw.clamped(to: 0...1)
        }
        if raw > 1 {
            pullingUp = true
            stretch = rubberBand(CGFloat(raw - 1) * size.height, limit: limit)
        } else if raw < 0 {
            pullingUp = false
            stretch = rubberBand(CGFloat(raw) * size.height, limit: limit)
        } else {
            stretch = 0
        }
        let edge = raw >= 1 || raw <= 0
        if edge && !atEdge { Haptics.tap(.medium) }
        atEdge = edge
    }

    /// Single cleanup for a lifted or cancelled finger and for autoplay.
    private func release() {
        guard pressing || stretch != 0 else { return }
        atEdge = false
        withAnimation(.spring(response: 0.35, dampingFraction: ctx["damping"])) {
            stretch = 0
            pressing = false
        }
    }

    // MARK: Autoplay

    private func play(_ tick: Int) {
        guard !touching else { return }
        let script = kind.script
        guard let target = script[(tick - 1 + script.count) % script.count] else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressing = true }
        let overflow = target > 1 || target < 0
        withAnimation(.smooth(duration: overflow ? 0.3 : 0.5)) { level = target.clamped(to: 0...1) }
        Task { @MainActor in
            if overflow {
                try? await Task.sleep(for: .seconds(0.26))
                pullingUp = target > 1
                let pull: CGFloat = ctx.cg("limit") * 0.85
                withAnimation(.easeOut(duration: 0.2)) { stretch = target > 1 ? pull : -pull }
                try? await Task.sleep(for: .seconds(0.3))
            } else {
                try? await Task.sleep(for: .seconds(0.6))
            }
            release()
        }
    }
}
