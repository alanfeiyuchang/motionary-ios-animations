import SwiftUI

// MARK: - Retry countdown

extension Effect {
    static let feedbackRetryCountdown = Effect(
        id: "feedback.retry-countdown",
        category: .feedback,
        interaction: .state,
        name: L("Retry Countdown Ring", "重试倒计时环"),
        summary: L("A lost connection counts down to its next attempt on a draining ring, spins while it retries, and closes green when it is back.", "断网后圆环一点点耗尽，倒数到下一次重试；重试时旋转，恢复后闭合成绿色。"),
        prompt: L(
            "A 112 pt ring surrounds a round retry button under a struck-through Wi-Fi glyph. While offline the coral-to-amber arc, 7 pt wide with round caps, drains clockwise at constant speed over the wait; the caption 'Retrying in 3 s' rolls its digit down each second and the button pulses 3.5% on every tick. At zero, or on tap, the arc becomes a 30% indigo segment circling once every 0.9 s while the arrow spins with it and the caption reads 'Reconnecting'. A failed attempt flashes the ring red, shakes it 9 pt three times and doubles the wait. On success the arc closes to a full green ring on a spring (response 0.5 s, damping 0.7), the arrow is replaced by a check, a soft ring blooms outward to 150% and fades, and the glyph turns to full Wi-Fi with a success haptic.",
            "划掉的 Wi-Fi 图标下方，112 pt 的圆环围着圆形重试按钮。离线时，7 pt 宽、圆头的琥珀到珊瑚色弧线在等待时间内匀速耗尽；“3 秒后重试”每秒向下滚动一位，按钮随每次跳秒鼓起 3.5%。归零或被点击时，弧线变成 30% 长的靛蓝弧段，每 0.9 秒转一圈，箭头同步旋转，文字换成“正在重新连接”。若失败，圆环闪红、左右抖动 9 pt，等待时间翻倍。成功时弧线以弹簧（响应 0.5 秒、阻尼 0.7）闭合成完整绿环，箭头替换为对勾，一圈柔光绽到 150% 后淡出，图标变回 Wi-Fi，并触发成功触感。"
        ),
        implementation: L(
            "A TimelineView reads a deadline date: the arc's trim is the remaining fraction, the caption is the rounded-up remainder with a numericText transition, and the per-second pulse is an exponential decay of the fractional second. One tokenized Task moves the phase enum through counting, retrying, failed and online.",
            "TimelineView 读取截止时间：弧线的 trim 是剩余比例，说明文字是向上取整的剩余秒数并使用 numericText 转场，每秒的鼓动是小数秒部分的指数衰减。一个带令牌的 Task 让状态枚举依次经过倒数、重试、失败与恢复。"
        ),
        apis: ["TimelineView(.animation(minimumInterval:paused:))", "trim(from:to:)", "contentTransition(.numericText(countsDown:))", "contentTransition(.symbolEffect(.replace))", "keyframeAnimator(initialValue:trigger:)"],
        tags: ["retry", "offline", "countdown", "reconnect", "error", "重试", "离线", "倒计时", "重新连接", "错误"],
        params: [
            .slider("seconds", L("Wait", "等待时间"), 2...8, default: 3, step: 1, decimals: 0, unit: "s"),
            .slider("retry", L("Attempt time", "重试耗时"), 0.6...3.0, default: 1.2, decimals: 1, unit: "s"),
            .toggle("fail", L("First attempt fails", "首次重试失败"), default: false),
        ]
    ) { ctx in
        RetryCountdownDemo(ctx: ctx)
    }
}

private enum RetryPhase: Equatable {
    case counting
    case retrying
    case failed
    case online
}

private struct RetryCountdownDemo: View {
    let ctx: DemoContext
    @State private var phase: RetryPhase = .counting
    @State private var deadline: Date
    @State private var wait: Double
    @State private var attempt = 0
    @State private var shakes = 0
    @State private var bloom = false
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        let seconds: Double = max(ctx["seconds"], 1)
        _wait = State(initialValue: seconds)
        _deadline = State(initialValue: Date().addingTimeInterval(seconds))
    }

    private var zh: Bool { ctx.language == .zh }
    private var ticking: Bool { phase == .counting || phase == .retrying }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                glyph
                TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !ticking || ctx.isStill)) { timeline in
                    let left: Double = ctx.isStill ? wait * 0.62 : max(deadline.timeIntervalSince(timeline.date), 0)
                    let now: Double = timeline.date.timeIntervalSinceReferenceDate
                    VStack(spacing: 14) {
                        ring(left: left, now: now)
                        captions(seconds: Int(left.rounded(.up)))
                    }
                }
            }
            .frame(width: 272, height: 262)
            .demoCard(cornerRadius: 26)
            DemoHint(text: L("Tap the ring to retry now", "点击圆环立即重试"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !ctx.isStill else { return }
            startCountdown(Double(max(ctx.int("seconds"), 1)), fresh: true)
        }
        .onChange(of: ctx.int("seconds")) { _, seconds in
            guard phase == .counting else { return }
            startCountdown(Double(max(seconds, 1)), fresh: true)
        }
    }

    // MARK: Pieces

    private var glyph: some View {
        let online: Bool = phase == .online
        return Image(systemName: online ? "wifi" : "wifi.slash")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(online ? Palette.green : Color.secondary)
            .contentTransition(.symbolEffect(.replace))
            .frame(height: 24)
    }

    private func ring(left: Double, now: Double) -> some View {
        let fraction: CGFloat = CGFloat(min(max(left / max(wait, 0.1), 0), 1))
        // A short swell right after each whole second passes.
        let sinceTick: Double = left.rounded(.up) - left
        let pulse: CGFloat = phase == .counting && !ctx.isStill ? 0.035 * CGFloat(exp(-sinceTick * 9)) : 0
        let spin: Double = (now / 0.9).truncatingRemainder(dividingBy: 1) * 360
        let counting: Bool = phase == .counting
        let retrying: Bool = phase == .retrying
        let online: Bool = phase == .online
        let failed: Bool = phase == .failed
        return ZStack {
            Circle()
                .stroke(Palette.green.opacity(bloom ? 0 : 0.5), lineWidth: 3)
                .scaleEffect(bloom ? 1.5 : 1)
                .opacity(online ? 1 : 0)
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(colors: [Palette.amber, Palette.coral, Palette.coral], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(counting ? 1 : 0)
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Palette.indigo, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(spin - 90))
                .opacity(retrying ? 1 : 0)
            Circle()
                .stroke(Palette.red, lineWidth: 7)
                .opacity(failed ? 1 : 0)
            Circle()
                .trim(from: 0, to: online ? 1 : 0)
                .stroke(
                    LinearGradient(colors: [Color(hex: 0x4BE08F), Palette.green], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Button(action: retryNow) {
                ZStack {
                    Circle()
                        .fill(Palette.surface)
                        .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                    Image(systemName: online ? "checkmark" : (failed ? "xmark" : "arrow.clockwise"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(online ? Palette.green : (failed ? Palette.red : (retrying ? Palette.indigo : Color.primary)))
                        .contentTransition(.symbolEffect(.replace))
                        .rotationEffect(.degrees(retrying ? spin : 0))
                }
                .frame(width: 78, height: 78)
                .scaleEffect(1 + pulse)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 112, height: 112)
        .keyframeAnimator(initialValue: CGFloat(0), trigger: shakes) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(9, duration: 0.06)
                CubicKeyframe(-9, duration: 0.1)
                CubicKeyframe(7, duration: 0.1)
                CubicKeyframe(-5, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
            }
        }
    }

    private func captions(seconds: Int) -> some View {
        let title: String
        let detail: String
        switch phase {
        case .counting:
            title = zh ? "连接已断开" : "Connection lost"
            detail = zh ? "\(seconds) 秒后重试" : "Retrying in \(seconds) s"
        case .retrying:
            title = zh ? "连接已断开" : "Connection lost"
            detail = zh ? "正在重新连接…" : "Reconnecting…"
        case .failed:
            title = zh ? "仍然无法连接" : "Still offline"
            detail = zh ? "稍后再试一次" : "Trying again shortly"
        case .online:
            title = zh ? "已恢复连接" : "Back online"
            detail = zh ? "刚刚已同步" : "Synced just now"
        }
        return VStack(spacing: 3) {
            Text(verbatim: title)
                .font(.headline)
                .contentTransition(.opacity)
            Text(verbatim: detail)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(phase == .counting ? .numericText(countsDown: true) : .opacity)
                .animation(.snappy(duration: 0.3), value: seconds)
        }
        .frame(height: 46)
    }

    // MARK: Sequence

    private func startCountdown(_ seconds: Double, fresh: Bool) {
        token += 1
        let current = token
        if fresh { attempt = 0 }
        wait = seconds
        deadline = Date().addingTimeInterval(seconds)
        bloom = false
        withAnimation(.smooth(duration: 0.3)) { phase = .counting }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard token == current else { return }
            retry(buzz: false)
        }
    }

    private func retryNow() {
        guard phase == .counting else { return }
        Haptics.tap()
        retry(buzz: !ctx.isPreview && !Haptics.isMuted)
    }

    private func retry(buzz: Bool) {
        token += 1
        let current = token
        withAnimation(.smooth(duration: 0.25)) { phase = .retrying }
        let duration: Double = ctx["retry"]
        let fails: Bool = ctx.bool("fail") && attempt == 0
        attempt += 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard token == current else { return }
            if fails {
                withAnimation(.easeOut(duration: 0.15)) { phase = .failed }
                shakes += 1
                if buzz { Haptics.error() }
                try? await Task.sleep(for: .seconds(0.9))
                guard token == current else { return }
                // Back off: wait twice as long before the next attempt.
                startCountdown(min(wait * 2, 16), fresh: false)
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = .online }
            withAnimation(.easeOut(duration: 0.7).delay(0.1)) { bloom = true }
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(2.2))
            guard token == current else { return }
            // The demo drops the connection again so the countdown can be watched once more.
            startCountdown(Double(max(ctx.int("seconds"), 1)), fresh: true)
        }
    }
}
