import SwiftUI

extension Effect {
    static let buttonsHoldRecord = Effect(
        id: "buttons.hold-record",
        category: .buttons,
        interaction: .gesture,
        name: L("Hold to Record", "按住录制"),
        summary: L(
            "Hold and the red dot becomes a rounded square inside a growing ring while a timer rolls; let go to save with a pop.",
            "按住后红点变成圆角方块，外环随时间生长，计时滚动；松手即保存并弹出反馈。"
        ),
        prompt: L(
            "A camera-style record control: a 60 pt red disc inside an 84 pt outlined ring. Holding it starts recording: the disc morphs into a 30 pt rounded square (corner radius 30 → 9) on a spring (response 0.32 s, damping 0.7), the outer ring swells to 118%, and a red progress arc starts at 12 o'clock and sweeps clockwise at constant speed, completing in 4 s. Above, a timer capsule fades in: a blinking red dot, digits ticking in tenths with a numeric roll, and five level bars dancing; a soft halo breathes behind the control once per second with a soft haptic tick. Releasing (or reaching the limit) saves: the square springs back to a disc, the control pops to 114% and settles, the arc fades, and the timer flips to a green “Saved” chip with a check for 1.5 s. A hold shorter than 0.35 s just recoils.",
            "相机式录制控件：84pt 的描边圆环里是 60pt 的红色圆点。按住即开始录制：圆点以弹簧（响应 0.32 秒、阻尼 0.7）变形为 30pt 的圆角方块（圆角 30 → 9），外环放大到 118%，红色进度弧从 12 点方向匀速顺时针扫过，4 秒走完一圈。上方淡入计时胶囊：闪烁的红点、按十分之一秒滚动的读数和五根跳动的电平条；背后的柔光每秒呼吸一次并带轻触感。松手或到达上限即保存：方块弹回圆点，控件弹到 114% 再回落，计时变成带对勾的绿色“已保存”标签，停留 1.5 秒。按住不足 0.35 秒只回弹，不保存。"
        ),
        implementation: L(
            "onLongPressGesture's pressing callback starts and stops the take. While recording, a TimelineView derives everything from the start date: the trimmed progress arc, the tenths readout (numericText), the halo's sine pulse and the level bars. The shape morph is one RoundedRectangle whose size and corner radius are animated by a spring.",
            "onLongPressGesture 的按压回调负责开始与结束。录制期间，TimelineView 由开始时间推导出一切：裁剪的进度弧、十分位读数（numericText）、柔光的正弦脉动和电平条。形状变形只是一个 RoundedRectangle，由弹簧同时驱动尺寸与圆角。"
        ),
        apis: ["onLongPressGesture(minimumDuration:maximumDistance:perform:onPressingChanged:)", "TimelineView", "Shape.trim(from:to:)", "contentTransition(.numericText())", "keyframeAnimator"],
        tags: ["hold", "record", "timer", "ring", "camera", "长按", "录制", "计时", "圆环", "相机"],
        params: [
            .slider("limit", L("Maximum length", "最长时长"), 2...8, default: 4, decimals: 1, unit: "s"),
            .slider("ring", L("Ring growth", "外环放大"), 1...1.4, default: 1.18),
            .slider("response", L("Morph response", "变形响应"), 0.2...0.6, default: 0.32, unit: "s"),
        ]
    ) { ctx in
        ButtonRecordDemo(ctx: ctx)
    }
}

private enum ButtonRecordPhase {
    case idle, recording, saved
}

private struct ButtonRecordDemo: View {
    let ctx: DemoContext
    @State private var phase: ButtonRecordPhase
    @State private var startedAt = Date()
    @State private var savedLength: Double = 0
    @State private var pops = 0
    @State private var limitTask: Task<Void, Never>?
    @State private var tickTask: Task<Void, Never>?
    @State private var resetTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? .recording : .idle)
    }

    private var limit: Double { max(ctx["limit"], 0.5) }
    private var recording: Bool { phase == .recording }
    private var morph: Animation { .spring(response: ctx["response"], dampingFraction: 0.7) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !recording || ctx.isStill)) { timeline in
                let elapsed = ctx.isStill ? 1.8 : (recording ? min(timeline.date.timeIntervalSince(startedAt), limit) : 0)
                VStack(spacing: 26) {
                    readout(elapsed: elapsed)
                    control(elapsed: elapsed)
                }
            }
            Spacer()
            DemoHint(text: L("Hold to record, release to save", "按住录制，松手保存"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.6, delay: 0.4) { playScript() }
        .onDisappear {
            limitTask?.cancel()
            tickTask?.cancel()
            resetTask?.cancel()
            scriptTask?.cancel()
        }
    }

    // MARK: Pieces

    private func readout(elapsed: Double) -> some View {
        ZStack {
            if phase == .saved {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(ctx.language == .zh ? "已保存" : "Saved")
                    Text(Self.clock(savedLength))
                        .monospacedDigit()
                        .opacity(0.8)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Palette.successStrong, in: Capsule())
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Palette.red)
                        .frame(width: 8, height: 8)
                        .opacity(elapsed.truncatingRemainder(dividingBy: 1) < 0.6 ? 1 : 0.25)
                    Text(Self.clock(elapsed))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: elapsed))
                        .animation(.snappy(duration: 0.18), value: Int(elapsed * 10))
                    ButtonRecordLevels(time: elapsed)
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Palette.red.opacity(0.14), in: Capsule())
                .opacity(recording ? 1 : 0)
                .scaleEffect(recording ? 1 : 0.85)
                .transition(.opacity)
            }
        }
        .frame(height: 34)
    }

    private func control(elapsed: Double) -> some View {
        let pulse = recording ? 0.5 + 0.5 * sin(elapsed * 2 * .pi - .pi / 2) : 0
        let grow = recording ? ctx.cg("ring") : 1
        return ZStack {
            Circle()
                .fill(Palette.red.opacity(0.16))
                .frame(width: 84, height: 84)
                .scaleEffect(grow * (1.12 + 0.14 * pulse))
                .opacity(recording ? 1 : 0)
            Circle()
                .strokeBorder(Color.primary.opacity(recording ? 0.14 : 0.85), lineWidth: 4)
                .frame(width: 84, height: 84)
                .scaleEffect(grow)
            Circle()
                .trim(from: 0, to: recording ? elapsed / limit : 0)
                .stroke(Palette.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 80, height: 80)
                .scaleEffect(grow)
                .opacity(recording ? 1 : 0)
            RoundedRectangle(cornerRadius: recording ? 9 : 30, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFF6A6F), Palette.red], startPoint: .top, endPoint: .bottom))
                .frame(width: recording ? 30 : 60, height: recording ? 30 : 60)
                .shadow(color: Palette.red.opacity(0.4), radius: 8, y: 4)
        }
        .frame(width: 130, height: 130)
        .contentShape(Circle())
        .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.14, duration: 0.1)
                SpringKeyframe(1, duration: 0.5, spring: .bouncy)
            }
        }
        .onLongPressGesture(minimumDuration: 600, maximumDistance: 80) {
        } onPressingChanged: { isPressing in
            scriptTask?.cancel()
            if isPressing { begin(haptics: true) } else { finish(haptics: true) }
        }
        .accessibilityAddTraits(.isButton)
    }

    private static func clock(_ seconds: Double) -> String {
        let tenths = Int((seconds * 10).rounded(.down))
        return String(format: "0:%02d.%d", tenths / 10, tenths % 10)
    }

    // MARK: Behaviour

    private func begin(haptics: Bool) {
        guard phase != .recording else { return }
        resetTask?.cancel()
        startedAt = Date()
        withAnimation(morph) { phase = .recording }
        if haptics { Haptics.tap(.medium) }
        limitTask?.cancel()
        limitTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(limit))
            guard !Task.isCancelled else { return }
            finish(haptics: haptics)
        }
        tickTask?.cancel()
        guard haptics else { return }
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                Haptics.tap(.soft)
            }
        }
    }

    private func finish(haptics: Bool) {
        guard phase == .recording else { return }
        limitTask?.cancel()
        tickTask?.cancel()
        let length = min(Date().timeIntervalSince(startedAt), limit)
        guard length >= 0.35 else {
            // Too short to be a take: recoil without saving.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { phase = .idle }
            return
        }
        savedLength = length
        pops += 1
        withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) { phase = .saved }
        if haptics { Haptics.success() }
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.3)) { phase = .idle }
        }
    }

    private func playScript() {
        guard phase == .idle else { return }
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            begin(haptics: false)
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            finish(haptics: false)
        }
    }
}

/// Five level bars driven by cheap layered sines, so the meter looks alive without any audio.
private struct ButtonRecordLevels: View {
    let time: Double

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<5, id: \.self) { index in
                let phase = Double(index) * 1.9
                let level = 0.5 + 0.3 * sin(time * 9 + phase) + 0.2 * sin(time * 15.3 + phase * 2.1)
                Capsule()
                    .fill(Palette.red)
                    .frame(width: 2.5, height: 4 + 12 * max(level, 0.05))
            }
        }
        .frame(height: 18)
    }
}
