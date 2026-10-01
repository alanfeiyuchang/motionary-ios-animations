import SwiftUI

extension Effect {
    static let gesturesAnswerCall = Effect(
        id: "gestures.answer-call",
        category: .gestures,
        interaction: .gesture,
        name: L("Slide to Answer or Decline", "滑动接听或拒接"),
        summary: L("An incoming call with one handle and two outcomes: slide right to answer in green, left to decline in red, while the receiver icon turns.", "来电界面上一个滑块、两种结果：向右滑变绿接听，向左滑变红拒接，听筒图标随之转动。"),
        prompt: L(
            "A dark call card: an avatar with three rings pulsing outward every 1.6 s, the caller's name and \"Incoming call\". Below, a 238×62 pt capsule track holds a white 54 pt handle at its centre, its phone icon shivering in short ringing bursts, with chevrons streaming outward on both sides. Dragging right floods the track green from the centre to the handle and turns the handle green; dragging left floods it red and rotates the receiver up to 135° into the hang-up pose. Past 72% of the 88 pt travel the target glyph swells to 1.25× with a light haptic. Releasing there, or with a flick, springs the handle to that end (response 0.4 s, damping 0.7): answering settles the rings into a steady green halo and starts a rolling call timer; declining shakes the card and dims it. Releasing early springs back to centre. Clear, decisive, reassuring.",
            "深色来电卡片：头像外三圈光环每1.6秒脉动一次，下方是名字与“来电”。238×62 pt的胶囊滑轨正中有一颗54 pt的白色滑块，听筒图标以短促的振铃节奏抖动，两侧箭头向外流动。向右拖，绿色从中心漫到滑块，滑块变绿；向左拖则漫出红色，听筒最多旋转135°成挂断姿态。越过88 pt行程的72%时，目标图标放大到1.25倍并伴随轻触感。在此松手或快速一甩，滑块以弹簧（响应0.4秒、阻尼0.7）弹到那一端：接听后光环收成绿色光晕，通话计时开始滚动；拒接则卡片抖动变暗。提前松手弹回中央。"
        ),
        implementation: L(
            "A DragGesture on the handle maps its horizontal translation to a signed progress in −1…1 with rubber-banding at the ends; the fill width, colours, icon rotation and target scale are all functions of that progress. Release picks commit or cancel from progress and velocity and animates with a spring. A TimelineView drives the ring pulses, the ringing shiver and the call timer.",
            "滑块上的 DragGesture 把水平位移映射为 −1…1 的带符号进度，两端带橡皮筋；填充宽度、颜色、图标旋转与目标图标缩放全是该进度的函数。松手时依据进度与速度决定提交或取消，并以弹簧动画过渡。TimelineView 驱动光环脉动、振铃抖动与通话计时。"
        ),
        apis: ["DragGesture", "TimelineView", "rotationEffect", "spring(response:dampingFraction:)", "contentTransition(.numericText)", "keyframeAnimator"],
        tags: ["answer", "decline", "incoming call", "slide", "two-way", "phone", "接听", "拒接", "来电", "滑动", "双向", "电话"],
        params: [
            .slider("threshold", L("Commit threshold", "触发阈值"), 0.5...0.95, default: 0.72),
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.8, default: 0.4, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.7),
            .slider("pulse", L("Ring pulse period", "光环脉动周期"), 0.8...2.4, default: 1.6, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        AnswerCallDemo(ctx: ctx)
    }
}

private enum CallUI {
    static let card = CGSize(width: 270, height: 288)
    static let track = CGSize(width: 238, height: 62)
    static let handle: CGFloat = 54
    static let travel: CGFloat = 88
    static let green = Color(hex: 0x30D158)
    static let red = Color(hex: 0xFF453A)
}

private enum CallState {
    case ringing, answered, declined
}

private struct AnswerCallDemo: View {
    let ctx: DemoContext
    /// −1 = fully at decline, +1 = fully at answer.
    @State private var progress: CGFloat
    @State private var state: CallState = .ringing
    @State private var armed = 0
    @State private var held = false
    @State private var answeredAt = Date()
    @State private var shake = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @State private var reset: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 0.58 : 0)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                CallHeader(
                    state: state,
                    answeredAt: answeredAt,
                    period: ctx["pulse"],
                    animated: !ctx.isStill,
                    language: ctx.language
                )
                Spacer(minLength: 0)
                slider
                    .padding(.bottom, 18)
            }
            .frame(width: CallUI.card.width, height: CallUI.card.height)
            .background {
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x1D2B3A), Color(hex: 0x0E1220)], startPoint: .top, endPoint: .bottom)
                    Circle()
                        .fill((state == .declined ? CallUI.red : CallUI.green).opacity(state == .ringing ? 0.14 : 0.24))
                        .frame(width: 240, height: 240)
                        .blur(radius: 60)
                        .offset(y: -70)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .brightness(state == .declined ? -0.06 : 0)
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            .keyframeAnimator(initialValue: CGFloat(0), trigger: shake) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-9, duration: 0.07)
                    CubicKeyframe(8, duration: 0.09)
                    CubicKeyframe(-5, duration: 0.08)
                    CubicKeyframe(3, duration: 0.07)
                    CubicKeyframe(0, duration: 0.08)
                }
            }

            DemoHint(text: state == .answered ? L("Tap the red handle to hang up", "点击红色滑块挂断") : L("Slide right to answer, left to decline", "右滑接听，左滑拒接"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.4, delay: 0.7) { autoSlide() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing && held { release(velocity: 0) }
        }
        .onDisappear {
            script?.cancel()
            reset?.cancel()
        }
    }

    private var slider: some View {
        CallSlider(progress: progress, armed: armed, state: state, held: held, animated: !ctx.isStill)
            .frame(width: CallUI.track.width, height: CallUI.track.height)
            .overlay {
                // The touch target rides with the handle.
                Circle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: CallUI.handle + 16, height: CallUI.handle + 16)
                    .offset(x: progress * CallUI.travel)
                    .gesture(drag)
                    .onTapGesture {
                        if state == .answered { hangUp() }
                    }
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                guard state == .ringing else { return }
                if !held {
                    held = true
                    script?.cancel()
                }
                dragChanged(value.translation.width)
            }
            .onEnded { value in
                guard held else { return }
                release(velocity: value.velocity.width)
            }
    }

    /// The finger (or the scripted one) is `translation` points from where it took the handle.
    private func dragChanged(_ translation: CGFloat) {
        let raw: CGFloat = translation / CallUI.travel
        let sign: CGFloat = raw < 0 ? -1 : 1
        progress = abs(raw) <= 1 ? raw : sign * (1 + rubberBand(abs(raw) - 1, limit: 0.12))
        let threshold: CGFloat = ctx.cg("threshold")
        let nowArmed: Int = progress >= threshold ? 1 : (progress <= -threshold ? -1 : 0)
        if nowArmed != armed {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { armed = nowArmed }
            if !ctx.isPreview { Haptics.tap(.light) }
        }
    }

    private func release(velocity: CGFloat) {
        held = false
        guard state == .ringing else { return }
        let flick: Int = velocity > 650 && progress > 0.2 ? 1 : (velocity < -650 && progress < -0.2 ? -1 : 0)
        let outcome: Int = armed != 0 ? armed : flick
        let spring: Animation = .spring(response: ctx["response"], dampingFraction: ctx["damping"])
        if outcome > 0 {
            answeredAt = Date()
            withAnimation(spring) {
                progress = 1
                state = .answered
                armed = 0
            }
            if !ctx.isPreview { Haptics.success() }
        } else if outcome < 0 {
            withAnimation(spring) {
                progress = -1
                state = .declined
                armed = 0
            }
            shake += 1
            if !ctx.isPreview { Haptics.error() }
            ringAgain(after: 1.5)
        } else {
            withAnimation(spring) {
                progress = 0
                armed = 0
            }
        }
    }

    private func hangUp() {
        guard state == .answered else { return }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.85)) { state = .declined }
        if !ctx.isPreview { Haptics.tap(.rigid) }
        ringAgain(after: 0.9)
    }

    /// A new call comes in: the handle returns to the centre.
    private func ringAgain(after delay: Double) {
        reset?.cancel()
        reset = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                progress = 0
                state = .ringing
            }
        }
    }

    /// A scripted finger slides the handle: to answer one time, to decline the next.
    private func autoSlide() {
        guard !held else { return }
        if state == .answered {
            hangUp()
            return
        }
        guard state == .ringing else { return }
        autoStep += 1
        let direction: CGFloat = autoStep % 2 == 1 ? 1 : -1
        script?.cancel()
        script = Task { @MainActor in
            let finished = await GhostFinger.drag(from: .zero, to: CGPoint(x: direction * CallUI.travel * 0.94, y: 0), duration: 0.7) { point in
                dragChanged(point.x)
            }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.1))
            guard !Task.isCancelled else { return }
            release(velocity: 0)
        }
    }
}

// MARK: - Pieces

private struct CallHeader: View {
    let state: CallState
    let answeredAt: Date
    let period: Double
    let animated: Bool
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated || state != .ringing)) { timeline in
                    let t: Double = timeline.date.timeIntervalSinceReferenceDate / max(period, 0.2)
                    ZStack {
                        ForEach(0..<3, id: \.self) { index in
                            let raw: Double = t + Double(index) / 3
                            let phase: Double = state == .ringing ? (animated ? raw - floor(raw) : 0.25 + Double(index) * 0.25) : 0
                            Circle()
                                .stroke(Color.white.opacity(state == .ringing ? 0.34 * (1 - phase) : 0), lineWidth: 1.5)
                                .frame(width: 74, height: 74)
                                .scaleEffect(1 + 0.95 * phase)
                        }
                    }
                }
                Circle()
                    .stroke(CallUI.green.opacity(state == .answered ? 0.9 : 0), lineWidth: 3)
                    .frame(width: 84, height: 84)
                    .shadow(color: CallUI.green.opacity(state == .answered ? 0.8 : 0), radius: 8)
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFB36B), Color(hex: 0xFF6B8B)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .saturation(state == .declined ? 0.2 : 1)
            }
            .frame(height: 112)
            .padding(.top, 14)

            Text(L("Mina Park", "林小敏"), language)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 2)
            status
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.top, 3)
                .frame(height: 20)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch state {
        case .ringing:
            Text(L("Incoming call", "来电"), language)
                .transition(.opacity)
        case .declined:
            Text(L("Call ended", "通话已结束"), language)
                .foregroundStyle(CallUI.red)
                .transition(.opacity)
        case .answered:
            TimelineView(.periodic(from: answeredAt, by: 1)) { timeline in
                let seconds: Int = animated ? max(Int(timeline.date.timeIntervalSince(answeredAt)), 0) : 7
                Text(verbatim: String(format: "%02d:%02d", seconds / 60, seconds % 60))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(seconds)))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: seconds)
                    .foregroundStyle(CallUI.green)
            }
            .transition(.opacity)
        }
    }
}

private struct CallSlider: View {
    let progress: CGFloat
    let armed: Int
    let state: CallState
    let held: Bool
    let animated: Bool

    var body: some View {
        let amount: CGFloat = min(abs(progress), 1)
        let positive: Bool = progress >= 0
        // After the call is answered the handle becomes the hang-up button.
        let hangUp: Bool = state != .ringing
        let tint: Color = hangUp ? CallUI.red : (positive ? CallUI.green : CallUI.red)
        let fillAmount: CGFloat = hangUp ? 0 : amount
        ZStack {
            Capsule().fill(.white.opacity(0.1))
            Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)

            // Colour floods from the centre to the handle.
            Capsule()
                .fill(tint.opacity(0.28 + 0.5 * Double(fillAmount)))
                .frame(width: CallUI.handle + 8 + fillAmount * CallUI.travel, height: CallUI.handle + 8)
                .offset(x: (positive ? 1 : -1) * fillAmount * CallUI.travel / 2)
                .opacity(Double(min(fillAmount * 4, 1)))

            CallChevrons(animated: animated && state == .ringing && !held)
                .opacity(state == .ringing ? Double(1 - amount) : 0)

            CallWave(animated: animated && state == .answered)
                .opacity(state == .answered ? 1 : 0)
                .offset(x: -26)

            HStack {
                Image(systemName: "phone.down.fill")
                    .foregroundStyle(CallUI.red)
                    .scaleEffect(armed < 0 ? 1.25 : 1)
                    .opacity(state == .ringing ? 1 : 0)
                Spacer()
                Image(systemName: "phone.fill")
                    .foregroundStyle(CallUI.green)
                    .scaleEffect(armed > 0 ? 1.25 : 1)
                    .opacity(state == .ringing ? 1 : 0)
            }
            .font(.system(size: 19, weight: .semibold))
            .padding(.horizontal, 20)

            handle(amount: hangUp ? 1 : amount, tint: tint, hangUp: hangUp || !positive)
                .offset(x: progress * CallUI.travel)
        }
    }

    private func handle(amount: CGFloat, tint: Color, hangUp: Bool) -> some View {
        ZStack {
            Circle().fill(.white)
            Circle().fill(tint).opacity(Double(amount))
            CallRinger(animated: animated && state == .ringing && !held && amount < 0.05) {
                ZStack {
                    Image(systemName: "phone.fill").foregroundStyle(Color(hex: 0x1D2B3A)).opacity(Double(1 - amount))
                    Image(systemName: "phone.fill").foregroundStyle(.white).opacity(Double(amount))
                }
                .font(.system(size: 22, weight: .semibold))
                .rotationEffect(.degrees(hangUp ? 135 * Double(amount) : 0))
            }
        }
        .frame(width: CallUI.handle, height: CallUI.handle)
        .scaleEffect(held ? 1.06 : 1)
        .shadow(color: tint.opacity(0.55 * Double(amount)), radius: 10)
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: held)
    }
}

/// Shivers its content in short bursts, like a ringing phone.
private struct CallRinger<Content: View>: View {
    let animated: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate
            let cycle: Double = (t / 1.4) - floor(t / 1.4)
            // Ring for the first 45% of every cycle.
            let envelope: Double = animated && cycle < 0.45 ? sin(cycle / 0.45 * .pi) : 0
            content()
                .rotationEffect(.degrees(sin(t * 46) * 13 * envelope))
        }
    }
}

/// Chevrons streaming away from the centre on both sides.
private struct CallChevrons: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate / 1.3
            let cycle: Double = t - floor(t)
            HStack(spacing: CallUI.handle + 22) {
                side(cycle: cycle, symbol: "chevron.left", reversed: true)
                side(cycle: cycle, symbol: "chevron.right", reversed: false)
            }
        }
    }

    private func side(cycle: Double, symbol: String, reversed: Bool) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                // The wave leaves the handle: the chevron nearest to it lights first.
                let order: Int = reversed ? 2 - index : index
                let phase: Double = cycle - Double(order) * 0.16
                let wave: Double = animated ? max(0, 1 - abs(phase - 0.3) / 0.3) : 0.4
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.18 + 0.6 * wave))
            }
        }
    }
}

/// The voice level shown in the track while the call is connected.
private struct CallWave: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<18, id: \.self) { index in
                    let x: Double = Double(index)
                    // Two beating sines per bar give an uneven, speech-like level.
                    let level: Double = animated
                        ? 0.5 + 0.5 * sin(t * 6.3 + x * 0.9) * sin(t * 2.1 + x * 0.37)
                        : 0.35 + 0.3 * GestureMath.hash(index * 3 + 1)
                    Capsule()
                        .fill(CallUI.green.opacity(0.85))
                        .frame(width: 3, height: 5 + 22 * CGFloat(max(level, 0.05)))
                }
            }
        }
        .frame(height: 30)
    }
}
