import SwiftUI

extension Effect {
    static let buttonsUndoCountdown = Effect(
        id: "buttons.undo-countdown",
        category: .buttons,
        interaction: .tap,
        name: L("Undo Countdown", "撤销倒计时"),
        summary: L(
            "After the action the button becomes Undo with a border that drains like a timer; when it runs out, the action commits.",
            "执行操作后按钮变成“撤销”，描边像计时器一样流尽；时间一到，操作正式生效。"
        ),
        prompt: L(
            "A message row sits above a 216 × 58 pt “Archive” pill. Tapping it slides the row 46 pt left as it fades and shrinks, and the pill becomes “Undo”: the icon swaps to a U-turn arrow, a small digit shows the seconds left, and an amber border appears full, then drains linearly over 3 s, its end retreating counter-clockwise toward the top centre under a soft glow; the digit rolls down each second. Tapping Undo spins the arrow one turn backwards, refills the border on a spring (response 0.45 s, damping 0.75), brings the row back with a bounce and restores “Archive”. If the border empties, the action commits: the pill dips to 94%, springs back at 180 pt wide in a quiet green with a check and “Archived”, and a success haptic fires. Forgiving, clear, calm.",
            "一行邮件条目下方是 216×58pt 的“归档”胶囊按钮。点击后条目向左滑出 46pt 并淡出缩小，按钮变为“撤销”：图标换成回转箭头，小数字显示剩余秒数，琥珀色描边先完整出现，再在 3 秒内匀速流尽，末端带着柔光逆时针退回顶部中点；数字每秒向下滚动。点击“撤销”时，箭头反向转一圈，描边以弹簧（响应 0.45 秒、阻尼 0.75）回满，条目带回弹归位，按钮恢复为“归档”。若描边流尽，操作生效：按钮下沉到 94%，再弹回并收窄到 180pt，变成安静的绿色，显示对勾与“已归档”，触发成功触感。"
        ),
        implementation: L(
            "`remaining` is a single state value: a linear withAnimation drains it and a spring refills it from wherever it was. It trims a capsule path that starts at the top centre. A Task rolls the seconds digit (numericText) and commits on expiry; the phase drives the pill's width, fill and label.",
            "`remaining` 是唯一的状态值：线性 withAnimation 让它流尽，弹簧则从当前位置把它回满；它用来裁剪一条从顶部中点出发的胶囊路径。一个 Task 负责滚动秒数（numericText）并在到期时提交；阶段值驱动按钮的宽度、填充与文字。"
        ),
        apis: ["withAnimation(.linear)", "Shape.trim(from:to:)", "contentTransition(.numericText())", "contentTransition(.symbolEffect(.replace))", "keyframeAnimator"],
        tags: ["undo", "countdown", "timer", "border", "commit", "撤销", "倒计时", "描边", "计时", "归档"],
        params: [
            .slider("duration", L("Undo window", "可撤销时长"), 2...8, default: 3, step: 1, decimals: 0, unit: "s"),
            .slider("width", L("Border width", "描边粗细"), 2...6, default: 3.5, decimals: 1, unit: "pt"),
            .slider("rewind", L("Refill response", "回满响应"), 0.2...0.8, default: 0.45, unit: "s"),
        ]
    ) { ctx in
        ButtonUndoDemo(ctx: ctx)
    }
}

private enum ButtonUndoPhase {
    case idle, counting, committed
}

private struct ButtonUndoDemo: View {
    let ctx: DemoContext
    @State private var phase: ButtonUndoPhase
    @State private var remaining: Double
    @State private var seconds: Int
    @State private var rewinds = 0
    @State private var settles = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? .counting : .idle)
        _remaining = State(initialValue: ctx.isStill ? 0.62 : 1)
        _seconds = State(initialValue: ctx.isStill ? 2 : 3)
    }

    private var duration: Double { max(ctx["duration"].rounded(), 1) }
    private var archived: Bool { phase != .idle }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 26) {
                ButtonUndoRow(language: ctx.language)
                    .offset(x: archived ? -46 : 0)
                    .scaleEffect(archived ? 0.92 : 1)
                    .opacity(archived ? 0 : 1)
                Button {
                    scriptTask?.cancel()
                    tapped(haptics: true)
                } label: {
                    pill
                }
                .buttonStyle(.plain)
            }
            Spacer()
            DemoHint(text: L("Tap Archive, then Undo before the border runs out", "点“归档”，再在描边流尽前点“撤销”"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: duration + 5.4, delay: 0.5) { playScript() }
        .onDisappear {
            timerTask?.cancel()
            scriptTask?.cancel()
        }
    }

    private var pill: some View {
        let counting = phase == .counting
        let committed = phase == .committed
        return HStack(spacing: 9) {
            Image(systemName: committed ? "checkmark" : (counting ? "arrow.uturn.backward" : "archivebox.fill"))
                .font(.system(size: 17, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .keyframeAnimator(initialValue: 0.0, trigger: rewinds) { content, turn in
                    content.rotationEffect(.degrees(turn))
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(0)
                        SpringKeyframe(-360, duration: 0.6, spring: Spring(response: 0.4, dampingRatio: 0.7))
                        MoveKeyframe(0)
                    }
                }
                .frame(width: 22)
            Text(title, ctx.language)
                .font(.headline)
                .contentTransition(.opacity)
            if counting {
                Text("\(seconds)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .frame(width: 24, height: 24)
                    .background(Palette.amber.opacity(0.22), in: Circle())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .foregroundStyle(committed ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
        .frame(width: committed ? 180 : 216, height: 58)
        .background {
            ZStack {
                Capsule().fill(Palette.elevated)
                Capsule().fill(Palette.successStrong).opacity(committed ? 1 : 0)
            }
        }
        .overlay(Capsule().strokeBorder(Color.primary.opacity(counting ? 0.1 : 0.14), lineWidth: counting ? ctx.cg("width") : 1))
        .overlay { timerBorder(shown: counting) }
        .shadow(color: (committed ? Palette.green : Color.black).opacity(committed ? 0.3 : 0.12), radius: 14, y: 8)
        .contentShape(Capsule())
        .keyframeAnimator(initialValue: CGFloat(1), trigger: settles) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(0.94, duration: 0.12)
                SpringKeyframe(1, duration: 0.55, spring: Spring(response: 0.36, dampingRatio: 0.55))
            }
        }
    }

    private func timerBorder(shown: Bool) -> some View {
        let width = ctx.cg("width")
        let line = ButtonUndoLoop()
            .trim(from: 0, to: remaining)
            .stroke(
                LinearGradient(colors: [Palette.amber, Palette.coral], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        return ZStack {
            line.blur(radius: 5).opacity(0.7)
            line
        }
        .padding(width / 2)
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(false)
    }

    private var title: LocalizedText {
        switch phase {
        case .idle: return L("Archive", "归档")
        case .counting: return L("Undo", "撤销")
        case .committed: return L("Archived", "已归档")
        }
    }

    // MARK: Behaviour

    private func tapped(haptics: Bool) {
        switch phase {
        case .idle: act(haptics: haptics)
        case .counting: undo(haptics: haptics)
        case .committed: reset()
        }
    }

    private func act(haptics: Bool) {
        guard phase == .idle else { return }
        if haptics { Haptics.tap(.medium) }
        let window = duration
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            remaining = 1
            seconds = Int(window)
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { phase = .counting }
        withAnimation(.linear(duration: window)) { remaining = 0 }
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            for left in stride(from: Int(window) - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if left > 0 {
                    withAnimation(.snappy(duration: 0.3)) { seconds = left }
                    if haptics { Haptics.tap(.soft) }
                }
            }
            commit(haptics: haptics)
        }
    }

    private func undo(haptics: Bool) {
        guard phase == .counting else { return }
        timerTask?.cancel()
        if haptics { Haptics.tap(.rigid) }
        rewinds += 1
        withAnimation(.spring(response: ctx["rewind"], dampingFraction: 0.75)) { remaining = 1 }
        timerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { phase = .idle }
        }
    }

    private func commit(haptics: Bool) {
        settles += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) { phase = .committed }
        if haptics { Haptics.success() }
        timerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    private func reset() {
        timerTask?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { phase = .idle }
    }

    /// Preview loop and detail intro: archive and undo in time, then archive again and let it run out.
    private func playScript() {
        guard phase == .idle else { return }
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            act(haptics: false)
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled else { return }
            undo(haptics: false)
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled else { return }
            act(haptics: false)
        }
    }
}

/// The capsule outline as one path that starts at the top centre and runs clockwise, so a trim reads like a clock.
private struct ButtonUndoLoop: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.height / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.midY), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.midY), radius: radius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

private struct ButtonUndoRow: View {
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Palette.ocean, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Weekly report", "本周周报"), language)
                    .font(.subheadline.weight(.semibold))
                Text(L("Numbers are up 12% this week", "本周数据上涨 12%"), language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("9:41")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(width: 284, height: 64)
        .demoCard(cornerRadius: 20)
    }
}
