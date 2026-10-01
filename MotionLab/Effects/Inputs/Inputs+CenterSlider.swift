import SwiftUI

extension Effect {
    static let inputsCenterSlider = Effect(
        id: "inputs.center-slider",
        category: .inputs,
        interaction: .gesture,
        name: L("Balance Slider", "居中平衡滑块"),
        summary: L("A balance slider that fills outward from the centre, snaps into a magnetic centre detent and carries a value bubble that leans with speed.", "从中点向两侧填充的平衡滑块：中点有磁吸定位，头顶的数值气泡会随速度倾斜。"),
        prompt: L(
            "A left/right balance slider: a 264 × 8 pt grey track with a centre notch, a 28 pt white thumb, and a fill that grows from the centre to the thumb, indigo to the right and pink to the left. Touching the thumb swells it to 115% and a value bubble springs up above it from 40% scale (response 0.3 s, damping 0.62), reading L 42, 0 or R 30 with rolling digits. While dragging, the bubble leans against the motion by up to 16° around its tail and swings back upright when the finger slows. Within 10% of the centre the thumb is captured: it jumps to zero on a spring (response 0.28 s), the notch pulses to 180% and a rigid haptic fires; it only pops out again once the finger leaves the zone. On release the bubble drops back into the thumb.",
            "左右声道平衡滑块：264 × 8pt 灰色轨道，中点一道刻痕，28pt 白色滑块；填充从中点长到滑块，向右为靛蓝，向左为粉色。按住滑块时它鼓到 115%，头顶的数值气泡从 40% 弹出（响应 0.3 秒、阻尼 0.62），以滚动数字显示「L 42」「0」或「R 30」。拖动时气泡绕尾尖逆着运动方向倾斜，最多 16°，手指放慢后摆回竖直。进入中点两侧 10% 范围时滑块被吸住：以弹簧（响应 0.28 秒）跳到零位，刻痕脉冲放大到 180%，一次硬朗触觉；手指离开该范围它才弹出来。松手后气泡落回滑块。"
        ),
        implementation: L(
            "The finger value and a `snapped` flag are stored separately; the shown value is zero while snapped, and only the flag change is animated, which makes the capture and the pop-out. The fill is a capsule whose width and offset derive from the shown value, and the bubble's lean comes from the drag velocity through an interactive spring.",
            "手指数值与 snapped 标记分开存储；吸附时显示值为零，只有标记变化带动画，于是产生吸入与弹出。填充是一枚宽度和偏移都由显示值推出的胶囊，气泡的倾斜来自拖动速度，经交互式弹簧平滑。"
        ),
        apis: ["DragGesture", "rotationEffect(_:anchor:)", "keyframeAnimator", "contentTransition(.numericText)", "interactiveSpring"],
        tags: ["slider", "balance", "center", "detent", "magnetic", "bubble", "滑块", "平衡", "居中", "磁吸", "气泡"],
        params: [
            .slider("detent", L("Detent width", "吸附范围"), 0...0.25, default: 0.1),
            .slider("lean", L("Bubble lean", "气泡倾斜"), 0...30, default: 16, decimals: 0, unit: "°"),
            .slider("damping", L("Spring damping", "弹簧阻尼"), 0.4...1.0, default: 0.62),
        ]
    ) { ctx in
        InputCenterSliderDemo(ctx: ctx)
    }
}

private struct InputCenterSliderDemo: View {
    let ctx: DemoContext
    /// Where the finger is, -1...1.
    @State private var raw: CGFloat = 0.42
    @State private var snapped = false
    @State private var pressing: Bool
    @State private var lean: Double = 0
    @State private var startRaw: CGFloat = 0
    @State private var pulse = 0
    @State private var step = 0
    @State private var playTask: Task<Void, Never>?
    @GestureState private var touching = false

    private let width: CGFloat = 264

    init(ctx: DemoContext) {
        self.ctx = ctx
        _pressing = State(initialValue: ctx.isStill)
    }

    private var shown: CGFloat { snapped ? 0 : raw }
    private var tint: Color { shown < 0 ? Palette.pink : Palette.indigo }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            meters
                .padding(.bottom, 62)
            slider
                .frame(width: width, height: 44)
                .contentShape(Rectangle().inset(by: -12))
                .gesture(drag)
            Spacer(minLength: 0)
            DemoHint(text: L("Drag across the centre", "拖过中点试试"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: touching) { _, down in
            if !down { release() }
        }
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.5) { play() }
        .onDisappear { playTask?.cancel() }
    }

    // MARK: Pieces

    private var meters: some View {
        HStack(spacing: 14) {
            InputBalanceMeter(letter: "L", level: 1 - max(shown, 0), tint: Palette.pink, mirrored: true)
            Image(systemName: "headphones")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
            InputBalanceMeter(letter: "R", level: 1 - max(-shown, 0), tint: Palette.indigo, mirrored: false)
        }
    }

    private var slider: some View {
        let half = width / 2
        return ZStack {
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 8)
            Capsule()
                .fill(tint)
                .frame(width: max(abs(shown) * half, 0.01), height: 8)
                .offset(x: shown * half / 2)
            Capsule()
                .fill(snapped ? Color.primary : Color.primary.opacity(0.35))
                .frame(width: 3, height: 18)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: pulse) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    SpringKeyframe(1.8, duration: 0.12, spring: .snappy)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                }
            thumb
                .offset(x: shown * half)
        }
    }

    private var thumb: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 28, height: 28)
            .shadow(color: .black.opacity(pressing ? 0.3 : 0.2), radius: pressing ? 9 : 4, y: pressing ? 5 : 2)
            .scaleEffect(pressing ? 1.15 : 1)
            .overlay(alignment: .top) { bubble }
    }

    private var bubble: some View {
        let amount = Int((abs(shown) * 100).rounded())
        let label: String = amount == 0 ? "0" : (shown < 0 ? "L \(amount)" : "R \(amount)")
        return VStack(spacing: -1) {
            Text(verbatim: label)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(shown)))
                .animation(.snappy(duration: 0.2), value: label)
                .padding(.horizontal, 11)
                .frame(minWidth: 46)
                .frame(height: 30)
                .background(tint, in: Capsule())
            InputBubbleTail()
                .fill(tint)
                .frame(width: 12, height: 7)
        }
        .fixedSize()
        .rotationEffect(.degrees(lean), anchor: .bottom)
        .scaleEffect(pressing ? 1 : 0.4, anchor: .bottom)
        .opacity(pressing ? 1 : 0)
        .offset(y: -46)
        .animation(.easeOut(duration: 0.2), value: shown < 0)
    }

    // MARK: Gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { gesture in
                if !pressing {
                    playTask?.cancel()
                    startRaw = shown
                    Haptics.tap(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: ctx["damping"])) { pressing = true }
                }
                let target = (startRaw + gesture.translation.width / (width / 2)).clamped(to: -1...1)
                move(to: target, velocity: gesture.velocity.width)
            }
            .onEnded { _ in release() }
    }

    /// Finger and autoplay both land here.
    private func move(to target: CGFloat, velocity: CGFloat) {
        raw = target
        let inside = abs(target) < ctx.cg("detent")
        if inside != snapped {
            if inside {
                Haptics.tap(.rigid)
                pulse += 1
            } else {
                Haptics.tap(.light)
            }
            withAnimation(.spring(response: 0.28, dampingFraction: ctx["damping"])) { snapped = inside }
        }
        let maxLean = ctx["lean"]
        let wanted = (-Double(velocity) / 45).clamped(to: -maxLean...maxLean)
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) { lean = wanted }
    }

    private func release() {
        guard pressing else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: ctx["damping"])) {
            pressing = false
            lean = 0
        }
    }

    private func play() {
        guard !touching else { return }
        let script: [CGFloat] = [0.62, 0, -0.74, 0, 0.42]
        let target = script[step % script.count]
        step += 1
        playTask?.cancel()
        playTask = Task { @MainActor in
            let direction: Double = target > shown ? -1 : 1
            withAnimation(.spring(response: 0.3, dampingFraction: ctx["damping"])) {
                pressing = true
                lean = direction * ctx["lean"]
            }
            let inside = abs(target) < ctx.cg("detent")
            withAnimation(.smooth(duration: 0.5)) {
                raw = target
                snapped = inside
            }
            try? await Task.sleep(for: .seconds(0.38))
            guard !Task.isCancelled else { return }
            if inside { pulse += 1 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { lean = 0 }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            release()
        }
    }
}

private struct InputBalanceMeter: View {
    let letter: String
    let level: CGFloat
    let tint: Color
    let mirrored: Bool

    var body: some View {
        let lit = Int((level * 5).rounded())
        let bars = HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                // The bar nearest the headphones is index 0.
                Capsule()
                    .fill(index < lit ? tint : Color.primary.opacity(0.12))
                    .frame(width: 5, height: 10 + CGFloat(index) * 4)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: lit)
            }
        }
        return HStack(spacing: 10) {
            if mirrored {
                letterView
                bars.scaleEffect(x: -1)
            } else {
                bars
                letterView
            }
        }
    }

    private var letterView: some View {
        Text(verbatim: letter)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(level > 0.5 ? Color.primary : Color.secondary)
            .scaleEffect(0.85 + 0.25 * level)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: level)
            .frame(width: 18)
    }
}

private struct InputBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        path.closeSubpath()
        return path
    }
}
