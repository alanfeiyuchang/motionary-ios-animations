import SwiftUI

extension Effect {
    static let inputsGlassToggle = Effect(
        id: "inputs.glass-toggle",
        category: .inputs,
        interaction: .gesture,
        name: L("Glass Lens Toggle", "玻璃透镜开关"),
        summary: L("The thumb lifts into a glass lens that magnifies the track, stretches with speed and lands on a spring.", "滑块按住即浮起成一枚玻璃透镜，放大轨道、随速度拉伸，再以弹簧落位。"),
        prompt: L(
            "A large iOS 26-style toggle: a 168 × 72 pt capsule track with a white 92 × 58 pt pill thumb. On touch-down the thumb lifts into a glass lens: it grows to 135%, its white fill fades to 12% and the track beneath shows through magnified 1.3×, with a bright rim, a top specular streak and a deeper, softer shadow (spring response 0.28 s, damping 0.7). Dragging moves the lens 1:1 with rubber-banding past the ends; horizontal speed stretches it up to 25% wider and proportionally flatter. The track blends grey to green continuously with the lens position, with a selection haptic at the midpoint. On release the lens flies to the nearer end on a spring (response 0.42 s, damping 0.62), overshoots, then 140 ms later condenses back into the solid white pill. A tap plays the same lift, travel and landing. Liquid, optical, weightless.",
            "大号 iOS 26 风格开关：168 × 72pt 胶囊轨道配白色 92 × 58pt 药丸滑块。按下时滑块浮起成玻璃透镜：放大到 135%，白色填充淡到 12%，下方轨道以 1.3 倍放大透出，边缘亮环、顶部高光，阴影更深更柔（弹簧响应 0.28 秒、阻尼 0.7）。拖动时透镜 1:1 跟手，越界有橡皮筋阻尼；横向速度让它最多拉宽 25% 并相应压扁。轨道颜色随位置在灰与绿之间连续过渡，过中点触发选择触觉。松手后透镜以弹簧（响应 0.42 秒、阻尼 0.62）飞向较近一端并略微过冲，140 毫秒后凝回实心白色药丸。"
        ),
        implementation: L(
            "The lens is drawn by hand so it works on iOS 18: a second copy of the track art is scaled around the thumb centre and masked by the thumb capsule, under a fading white fill, gradient rim and specular streak. DragGesture feeds position and a velocity-based stretch; release and tap share one spring-driven settle function.",
            "透镜为手绘实现，iOS 18 即可运行：把轨道图层再绘制一份，以滑块中心为锚点放大，并用滑块胶囊做遮罩，上面叠加渐隐的白色填充、渐变亮环与高光。DragGesture 提供位置与基于速度的拉伸量；松手与点击共用同一个弹簧落位函数。"
        ),
        apis: ["DragGesture", "mask", "scaleEffect(anchor:)", "spring(response:dampingFraction:)", "rubber band"],
        tags: ["toggle", "switch", "liquid glass", "lens", "iOS 26", "开关", "液态玻璃", "透镜", "折射"],
        params: [
            .slider("lift", L("Lens scale", "透镜放大"), 1.1...1.6, default: 1.35),
            .slider("zoom", L("Magnification", "折射倍率"), 1.0...1.6, default: 1.3),
            .slider("stretch", L("Velocity stretch", "速度拉伸"), 0...0.5, default: 0.25),
            .slider("damping", L("Landing damping", "落位阻尼"), 0.35...1.0, default: 0.62),
        ]
    ) { ctx in
        InputGlassToggleDemo(ctx: ctx)
    }
}

private struct InputGlassToggleDemo: View {
    let ctx: DemoContext
    @State private var isOn: Bool
    /// Thumb position, 0 (off) … 1 (on); runs past the ends while rubber-banding.
    @State private var position: CGFloat
    @State private var lifted = false
    @State private var stretch: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var crossedHalf = false
    @State private var landTask: Task<Void, Never>?
    /// Resets on system cancellation too, where `onEnded` never runs.
    @GestureState private var touching = false

    private let track = CGSize(width: 168, height: 72)
    private let thumb = CGSize(width: 92, height: 58)
    private let inset: CGFloat = 7
    private let canvas = CGSize(width: 260, height: 108)

    init(ctx: DemoContext) {
        self.ctx = ctx
        _isOn = State(initialValue: ctx.isStill)
        _position = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var travel: CGFloat { track.width - thumb.width - inset * 2 }
    private var thumbX: CGFloat { (position - 0.5) * travel }
    private var onAmount: Double { Double(position.clamped(to: 0...1)) }
    private var landing: Animation { .spring(response: 0.42, dampingFraction: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            caption
            toggle
                .padding(.top, 10)
            Spacer(minLength: 0)
            DemoHint(text: L("Press and drag the thumb, or tap", "按住拖动滑块，或直接点击"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7, delay: 0.5) { flip() }
        .onDisappear { landTask?.cancel() }
    }

    private var caption: some View {
        HStack(spacing: 10) {
            Image(systemName: isOn ? "moon.stars.fill" : "moon.stars")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isOn ? Palette.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
            Text(L("Focus", "专注模式"), ctx.language)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(isOn ? L("On", "已开启") : L("Off", "已关闭"), ctx.language)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .id(isOn)
                .transition(.blurReplace)
        }
        .animation(.smooth(duration: 0.3), value: isOn)
    }

    // MARK: Toggle

    private var toggle: some View {
        ZStack {
            glow
            trackArt
                .frame(width: canvas.width, height: canvas.height)
            lensShadow
            // The refraction: the same art, magnified around the thumb centre, seen only through the lens.
            trackArt
                .scaleEffect(ctx.cg("zoom"), anchor: UnitPoint(x: 0.5 + thumbX / track.width, y: 0.5))
                .frame(width: canvas.width, height: canvas.height)
                .brightness(0.06)
                .saturation(1.25)
                .mask { lens(Capsule()) }
                .opacity(lifted ? 1 : 0)
            lens(Capsule().fill(Color.white.opacity(lifted ? 0.12 : 1)))
            lens(specular)
                .opacity(lifted ? 1 : 0)
            lens(rim)
        }
        .frame(width: canvas.width, height: canvas.height)
        .contentShape(Rectangle())
        .gesture(drag)
        .onChange(of: touching) { _, down in
            if !down { endDrag(predicted: nil, moved: 100) }
        }
        .scaleEffect(ctx.isPreview ? 1.12 : 1)
    }

    private var glow: some View {
        Capsule()
            .fill(Palette.green)
            .frame(width: track.width * 0.8, height: track.height * 0.7)
            .blur(radius: 34)
            .opacity(onAmount * 0.45)
            .offset(y: 14)
    }

    /// Track with its off/on marks; drawn once as the track and once more, magnified, inside the lens.
    private var trackArt: some View {
        ZStack {
            Capsule().fill(Color.adaptive(light: 0xD4D4DC, dark: 0x3A3A40))
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0x3DDC84), Color(hex: 0x1FB866)], startPoint: .top, endPoint: .bottom))
                .opacity(onAmount)
            Capsule()
                .strokeBorder(LinearGradient(colors: [.black.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: 3, height: 18)
                .offset(x: -track.width / 2 + 34)
                .opacity(onAmount)
            Circle()
                .strokeBorder(Color.primary.opacity(0.35), lineWidth: 3)
                .frame(width: 16, height: 16)
                .offset(x: track.width / 2 - 34)
                .opacity(1 - onAmount)
        }
        .frame(width: track.width, height: track.height)
    }

    /// Places any lens layer on the thumb: lifted scale, velocity stretch, position.
    private func lens<Content: View>(_ content: Content) -> some View {
        let lift: CGFloat = lifted ? ctx.cg("lift") : 1
        return content
            .frame(width: thumb.width, height: thumb.height)
            .scaleEffect(lift)
            .scaleEffect(x: 1 + stretch, y: 1 - stretch * 0.4)
            .offset(x: thumbX)
    }

    private var lensShadow: some View {
        lens(
            Capsule()
                .fill(Color.black.opacity(lifted ? 0.3 : 0.22))
                .blur(radius: lifted ? 12 : 3)
                .offset(y: lifted ? 10 : 2)
        )
    }

    private var specular: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .top, endPoint: .center))
                .padding(3)
            Capsule()
                .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.22)], startPoint: .center, endPoint: .bottom))
                .padding(3)
            // Thickness: a soft dark band just inside the edge, where a real lens bends light away.
            Capsule()
                .stroke(Color.black.opacity(0.22), lineWidth: 4)
                .blur(radius: 3)
                .padding(1)
                .clipShape(Capsule())
        }
    }

    private var rim: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.95), .white.opacity(lifted ? 0.2 : 0.6), .white.opacity(lifted ? 0.7 : 0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: lifted ? 1.5 : 0.5
            )
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if dragStart == nil {
                    landTask?.cancel()
                    dragStart = position
                    crossedHalf = position > 0.5
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { lifted = true }
                    Haptics.tap(.soft)
                }
                let raw: CGFloat = (dragStart ?? 0) + value.translation.width / travel
                let banded: CGFloat
                if raw > 1 {
                    banded = 1 + rubberBand((raw - 1) * travel, limit: 26) / travel
                } else if raw < 0 {
                    banded = rubberBand(raw * travel, limit: 26) / travel
                } else {
                    banded = raw
                }
                let speed: CGFloat = abs(value.velocity.width)
                let pull: CGFloat = min(speed / 2400, 1) * ctx.cg("stretch")
                withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.8)) {
                    position = banded
                    stretch = pull
                }
                let half = banded > 0.5
                if half != crossedHalf {
                    crossedHalf = half
                    Haptics.selection()
                }
            }
            .onEnded { value in
                let moved: CGFloat = abs(value.translation.width)
                let predicted: CGFloat = (dragStart ?? 0) + value.predictedEndTranslation.width / travel
                endDrag(predicted: predicted, moved: moved)
            }
    }

    private func endDrag(predicted: CGFloat?, moved: CGFloat) {
        guard dragStart != nil else { return }
        dragStart = nil
        if moved < 6 {
            settle(on: !isOn)
        } else {
            settle(on: (predicted ?? position) > 0.5)
        }
    }

    /// Tap and autoplay: lift, travel, land.
    private func flip() {
        landTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { lifted = true }
        let target = !isOn
        landTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.12)) { stretch = ctx.cg("stretch") * 0.8 }
            settle(on: target)
        }
    }

    /// The single landing path for a released drag, a tap and autoplay.
    private func settle(on target: Bool) {
        if target != isOn { Haptics.tap(.medium) }
        isOn = target
        withAnimation(landing) { position = target ? 1 : 0 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) { stretch = 0 }
        landTask?.cancel()
        landTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.14))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { lifted = false }
        }
    }
}
