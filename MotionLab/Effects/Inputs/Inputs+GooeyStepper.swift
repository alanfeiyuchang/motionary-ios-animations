import SwiftUI

extension Effect {
    static let inputsGooeyStepper = Effect(
        id: "inputs.gooey-stepper",
        category: .inputs,
        interaction: .tap,
        name: L("Gooey Momentum Stepper", "黏液动量步进器"),
        summary: L("The value blob shoots a sticky arm at the side you tap and snaps back; rapid taps build momentum and it reaches further.", "数值黏团朝你点的一侧甩出一条黏丝再弹回；连续快点会积累动量，甩得更远、晃得更狠。"),
        prompt: L(
            "A stepper built from goo: a 232 × 64 pt capsule track with minus and plus glyphs and, in the middle, an 80 pt indigo-to-violet blob that bulges past the track carrying a bold number. Tapping a side throws a 46 pt satellite drop out of the blob toward that glyph in 130 ms ease-out; a metaball filter keeps the two joined by a sticky neck. The blob then pulls it back on an underdamped spring (response 0.42 s, damping 0.45), overshooting to the far side, while the number rolls with a light haptic. Each tap within 0.7 s adds 22% momentum: the arm starts at 55% of the way and reaches the glyph at full momentum, the wobble loosens, the blob swells up to 10%, a violet glow grows and five dots light up; the tapped glyph kicks to 135%. After 0.7 s idle, momentum drains over 0.6 s.",
            "用黏液做的步进器：232 × 64pt 胶囊轨道两端是减号与加号，中间一团 80pt 靛紫渐变黏团鼓出轨道，上有数字。点击某一侧，黏团在 130 毫秒内朝该符号甩出一颗 46pt 液滴，metaball 滤镜让两者连着黏颈；随后以欠阻尼弹簧（响应 0.42 秒、阻尼 0.45）把它拉回，冲过头再停稳，数字滚动。0.7 秒内每次点击累加 22% 动量：黏臂起初只伸到 55% 处，满动量时够到符号；晃动更松，黏团最多胀大 10%，五个小点逐个点亮，被点的符号弹到 135%。停手 0.7 秒后，动量在 0.6 秒内泄掉。"
        ),
        implementation: L(
            "An Animatable view takes the interpolated pull and momentum and redraws a Canvas whose layer applies alphaThreshold over blur (metaballs); that Canvas masks a gradient. A tap animates pull out with ease-out and back with a spring whose damping drops as momentum rises; a debounced task drains momentum.",
            "Animatable 视图接收插值后的拉伸量与动量，重绘一个在图层上叠加 alphaThreshold 与 blur 的 Canvas（metaball），并以它作为渐变的遮罩。点击先以缓出把拉伸量推出去，再用阻尼随动量降低的弹簧拉回；去抖任务负责泄掉动量。"
        ),
        apis: ["Canvas", "GraphicsContext.Filter.alphaThreshold", "Animatable", "contentTransition(.numericText)", "spring(response:dampingFraction:)"],
        tags: ["stepper", "gooey", "metaball", "momentum", "counter", "步进器", "黏液", "融球", "动量", "计数"],
        params: [
            .slider("reach", L("Arm reach", "黏臂长度"), 0.5...1.2, default: 1.0),
            .slider("wobble", L("Wobble damping", "晃动阻尼"), 0.25...0.9, default: 0.45),
            .slider("goo", L("Gooeyness", "黏度"), 6...16, default: 10, decimals: 0, unit: "pt"),
            .slider("gain", L("Momentum per tap", "每次动量"), 0.05...0.5, default: 0.22),
        ]
    ) { ctx in
        InputGooeyStepperDemo(ctx: ctx)
    }
}

private struct InputGooeyStepperDemo: View {
    let ctx: DemoContext
    @State private var value = 3
    /// −1…1: how far the satellite drop is thrown, toward minus or plus.
    @State private var pull: CGFloat = 0
    @State private var momentum: CGFloat
    @State private var kicks = [0, 0]
    @State private var step = 0
    @State private var recoil: Task<Void, Never>?
    @State private var drain: Task<Void, Never>?
    @State private var burst: Task<Void, Never>?

    private let track = CGSize(width: 232, height: 64)
    private static let script: [Int] = [1, 1, 1, 1, 1, 1, 0, 0, 0, 0, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0]

    init(ctx: DemoContext) {
        self.ctx = ctx
        _momentum = State(initialValue: ctx.isStill ? 0.6 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            stepper
            meter
                .padding(.top, 26)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap + or − quickly, several times", "快速连续点击 + 或 −"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.3, delay: 0.5) {
            if ctx.isPreview { previewTick() } else { introBurst() }
        }
        .onDisappear {
            recoil?.cancel()
            drain?.cancel()
            burst?.cancel()
        }
    }

    private var stepper: some View {
        ZStack {
            Circle()
                .fill(Palette.violet)
                .frame(width: 90, height: 90)
                .blur(radius: 24)
                .opacity(Double(momentum) * 0.45)
                .scaleEffect(1 + momentum * 0.35)
                .offset(y: 12)
            Capsule()
                .fill(Color.primary.opacity(0.07))
                .overlay(Capsule().strokeBorder(Palette.stroke))
                .frame(width: track.width, height: track.height)
            glyph("minus", side: 0)
                .offset(x: -track.width / 2 + 34)
            glyph("plus", side: 1)
                .offset(x: track.width / 2 - 34)
            InputGooBlob(pull: pull, momentum: momentum, reach: (track.width / 2 - 34) * ctx.cg("reach"), goo: ctx.cg("goo"))
                .frame(width: 300, height: 130)
                .shadow(color: Palette.indigo.opacity(0.35), radius: 10, y: 6)
                .allowsHitTesting(false)
            // Wet highlight riding on the blob.
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 44, height: 22)
                .blur(radius: 3)
                .offset(x: pull * 9 - 4, y: -22)
                .scaleEffect(1 + momentum * 0.1)
                .allowsHitTesting(false)
            Text(verbatim: "\(value)")
                .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(value)))
                .animation(.snappy(duration: 0.28), value: value)
                .offset(x: pull * 9)
                .allowsHitTesting(false)
        }
        .frame(width: 300, height: 130)
        .overlay {
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { press(-1) }
                Color.clear.contentShape(Rectangle()).onTapGesture { press(1) }
            }
            .frame(width: track.width + 24, height: 96)
        }
    }

    private func glyph(_ name: String, side: Int) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: kicks[side]) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(0.8, duration: 0.08)
                    CubicKeyframe(1.35, duration: 0.1)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
            }
    }

    private var meter: some View {
        let lit = Int((momentum * 5).rounded())
        return HStack(spacing: 7) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < lit ? Palette.violet : Color.primary.opacity(0.12))
                    .frame(width: 7, height: 7)
                    .scaleEffect(index < lit ? 1.25 : 1)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: lit)
    }

    // MARK: Press

    /// One tap, real or simulated: throw the drop, change the value, feed momentum.
    private func press(_ direction: Int) {
        let next = value + direction
        let blocked = next < 0 || next > 99
        let gained: CGFloat = blocked ? momentum : min(momentum + ctx.cg("gain"), 1)
        // The throw uses the momentum built up before this tap: 55% of the way from rest, all the way at full.
        let amplitude: CGFloat = blocked ? 0.3 : 0.55 + 0.45 * momentum
        kicks[direction < 0 ? 0 : 1] += 1
        if blocked {
            Haptics.tap(.rigid)
        } else {
            value = next
            Haptics.tap(gained >= 1 ? .medium : .light)
        }
        withAnimation(.easeOut(duration: 0.13)) { pull = CGFloat(direction) * amplitude }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { momentum = gained }
        recoil?.cancel()
        recoil = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            let damping = max(ctx["wobble"] - 0.15 * Double(gained), 0.2)
            withAnimation(.spring(response: 0.42, dampingFraction: damping)) { pull = 0 }
        }
        drain?.cancel()
        drain = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.6)) { momentum = 0 }
        }
    }

    private func previewTick() {
        let direction = Self.script[step % Self.script.count]
        step += 1
        if direction != 0 { press(direction) }
    }

    /// Detail arrival: a quick run of four taps, so the momentum is visible straight away.
    private func introBurst() {
        burst?.cancel()
        burst = Task { @MainActor in
            for _ in 0..<4 {
                guard !Task.isCancelled else { return }
                Haptics.isMuted = true
                press(1)
                Haptics.isMuted = false
                try? await Task.sleep(for: .seconds(0.26))
            }
        }
    }
}

/// The metaball layer. Animatable so the spring's every frame redraws the Canvas.
private struct InputGooBlob: View, Animatable {
    var pull: CGFloat
    var momentum: CGFloat
    let reach: CGFloat
    let goo: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(pull, momentum) }
        set {
            pull = newValue.first
            momentum = newValue.second
        }
    }

    var body: some View {
        let pull = self.pull
        let swell: CGFloat = 1 + 0.1 * min(max(momentum, 0), 1)
        let reach = self.reach
        return LinearGradient(colors: [Palette.indigo, Palette.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
            .mask {
                Canvas { context, size in
                    let mid = CGPoint(x: size.width / 2, y: size.height / 2)
                    context.addFilter(.alphaThreshold(min: 0.5, color: .white))
                    context.addFilter(.blur(radius: goo))
                    context.drawLayer { layer in
                        // The blob leans into the throw and flattens a little, then the drop leaves it.
                        let width: CGFloat = 80 * swell * (1 + 0.1 * abs(pull))
                        let height: CGFloat = 80 * swell * (1 - 0.07 * abs(pull))
                        let body = CGRect(x: mid.x - width / 2 + pull * 8, y: mid.y - height / 2, width: width, height: height)
                        layer.fill(Path(ellipseIn: body), with: .color(.white))
                        let drop: CGFloat = 46
                        let centre = mid.x + pull * reach
                        layer.fill(
                            Path(ellipseIn: CGRect(x: centre - drop / 2, y: mid.y - drop / 2, width: drop, height: drop)),
                            with: .color(.white)
                        )
                        // A bead half-way keeps the neck from pinching off too early.
                        let bead: CGFloat = 30
                        let half = mid.x + pull * reach * 0.55
                        layer.fill(
                            Path(ellipseIn: CGRect(x: half - bead / 2, y: mid.y - bead / 2, width: bead, height: bead)),
                            with: .color(.white)
                        )
                    }
                }
                .blur(radius: 0.7)
            }
    }
}
