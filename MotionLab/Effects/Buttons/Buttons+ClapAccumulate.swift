import SwiftUI

extension Effect {
    static let buttonsClapAccumulate = Effect(
        id: "buttons.clap-accumulate",
        category: .buttons,
        interaction: .gesture,
        name: L("Clap & Hold", "连击鼓掌"),
        summary: L(
            "Each tap pops a +N bubble; holding claps faster and faster with escalating sparks.",
            "每次点击都弹出 +N 气泡；按住则越拍越快，火花逐级升级。"
        ),
        prompt: L(
            "A 76 pt round clap button with a running total beneath it. Each tap adds one clap: the button pops to 116% and settles on a bouncy spring while the hands tilt 10°, a ring of small coloured sparks (dots and triangles) flies 20–46 pt outward and fades in 0.55 s, and a green 48 pt “+N” bubble springs 80 pt above the button (response 0.35 s, damping 0.6), bumping on every further clap as its number rolls. Holding claps automatically after 0.38 s: the interval starts at 0.3 s and shrinks by 14% per clap down to 50 ms, haptics step from light to medium to heavy, and bursts gain sparks and reach with the streak. 0.9 s after the last clap the bubble drifts up 34 pt and fades. At the 50-clap cap the bubble turns gold with a success haptic. Generous, rhythmic, rewarding.",
            "76pt 的圆形鼓掌按钮，下方是累计数。每点一次加一次掌声：按钮弹到 116% 后弹性落定，手掌图标倾斜 10°；一圈彩色小火花（圆点与三角）向外飞出 20–46pt，0.55 秒内淡出；48pt 的绿色“+N”气泡弹到按钮上方 80pt（响应 0.35 秒、阻尼 0.6），此后每次鼓掌都顶一下并滚动数字。按住 0.38 秒后自动连拍：间隔从 0.3 秒起每次缩短 14%，最快 50 毫秒，触感由轻到重，火花随连击变多变远。停手 0.9 秒后气泡再上浮 34pt 淡出；达到 50 次上限时气泡变金并触发成功触感。"
        ),
        implementation: L(
            "A zero-distance DragGesture claps on touch-down and starts a Task that keeps clapping with a geometrically shrinking sleep; every clap bumps a keyframeAnimator trigger, appends a batch of sparks drawn by a TimelineView Canvas from their birth time, and re-arms the bubble's dismissal Task.",
            "零距离 DragGesture 在按下瞬间鼓掌，并启动一个 Task，以按等比缩短的间隔持续鼓掌；每次鼓掌都会触发 keyframeAnimator、追加一批由 TimelineView Canvas 依出生时间绘制的火花，并重新计时气泡的消失任务。"
        ),
        apis: ["DragGesture", "Task.sleep", "keyframeAnimator", "TimelineView", "Canvas", "contentTransition(.numericText)"],
        tags: ["clap", "like", "hold", "accumulate", "鼓掌", "点赞", "连击", "长按"],
        params: [
            .slider("accel", L("Interval multiplier", "间隔倍率"), 0.7...0.98, default: 0.86),
            .slider("sparks", L("Sparks per clap", "每次火花数"), 3...12, default: 6, step: 1, decimals: 0),
            .slider("rise", L("Bubble height", "气泡高度"), 50...110, default: 80, decimals: 0, unit: "pt"),
            .slider("cap", L("Clap limit", "鼓掌上限"), 10...99, default: 50, step: 1, decimals: 0),
        ]
    ) { ctx in
        ButtonClapDemo(ctx: ctx)
    }
}

private struct ButtonClapSpark: Identifiable {
    let id = UUID()
    let birth: Date
    let angle: Double
    let reach: CGFloat
    let color: Color
    let triangle: Bool
    let spin: Double
}

private enum ButtonClapBubblePhase {
    case hidden, shown, leaving
}

private struct ButtonClapDemo: View {
    let ctx: DemoContext
    @State private var count: Int
    @State private var streak = 0
    @State private var bubble: ButtonClapBubblePhase
    @State private var sparks: [ButtonClapSpark] = []
    @State private var sparksLive = false
    @State private var holdTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?
    @State private var holding = false
    @GestureState private var touching = false

    private static let baseTotal = 1284

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still thumbnail shows the button mid-streak: clapped, with its bubble up.
        _count = State(initialValue: ctx.isStill ? 12 : 0)
        _bubble = State(initialValue: ctx.isStill ? .shown : .hidden)
    }
    private var cap: Int { max(ctx.int("cap"), 1) }
    private var capped: Bool { count >= cap }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    sparkLayer
                    bubbleView
                    button
                }
                .frame(width: 220, height: 96)
                .padding(.top, 64)
                totals
            }
            Spacer()
            DemoHint(text: L("Tap to clap, or hold to keep clapping", "点击鼓掌，或按住连续鼓掌"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.6, delay: 0.4) { playScript() }
        .onDisappear {
            scriptTask?.cancel()
            holdTask?.cancel()
            dismissTask?.cancel()
        }
    }

    // MARK: Pieces

    private var button: some View {
        let active = count > 0
        let tint = capped ? Palette.amber : Palette.green
        return ZStack {
            Circle()
                .fill(active ? AnyShapeStyle(tint.opacity(0.16)) : AnyShapeStyle(Palette.elevated))
            Circle()
                .strokeBorder(active ? tint.opacity(0.9) : Color.primary.opacity(0.18), lineWidth: 1.5)
            Image(systemName: active ? "hands.clap.fill" : "hands.clap")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(active ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(0.75)))
                .keyframeAnimator(initialValue: 0.0, trigger: count) { content, tilt in
                    content.rotationEffect(.degrees(tilt))
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(-10, duration: 0.07)
                        SpringKeyframe(0, duration: 0.4, spring: .bouncy)
                    }
                }
        }
        .frame(width: 76, height: 76)
        .shadow(color: (active ? tint : Color.black).opacity(active ? 0.28 : 0.1), radius: 14, y: 8)
        .scaleEffect(holding ? 0.94 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: holding)
        .keyframeAnimator(initialValue: 1.0, trigger: count) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.16, duration: 0.07)
                SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
            }
        }
        .contentShape(Circle().inset(by: -10))
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($touching) { _, state, _ in state = true }
        )
        .onChange(of: touching) { _, isTouching in
            if isTouching {
                scriptTask?.cancel()
                beginHold(haptics: true)
            } else {
                endHold()
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    private var bubbleView: some View {
        let rise = ctx.cg("rise")
        let offset: CGFloat = bubble == .hidden ? 0 : (bubble == .shown ? -rise : -rise - 34)
        return Text(verbatim: "+\(count)")
            .font(.system(size: count > 9 ? 16 : 18, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(count)))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background {
                Circle().fill(
                    capped
                        ? LinearGradient(colors: [Palette.amber, Palette.coral], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Palette.mint, Palette.green], startPoint: .top, endPoint: .bottom)
                )
            }
            .shadow(color: (capped ? Palette.coral : Palette.green).opacity(0.4), radius: 10, y: 5)
            .keyframeAnimator(initialValue: 1.0, trigger: count) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(1.22, duration: 0.08)
                    SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                }
            }
            .scaleEffect(bubble == .hidden ? 0.3 : (bubble == .shown ? 1 : 0.9))
            .opacity(bubble == .shown ? 1 : 0)
            .offset(y: offset)
            .allowsHitTesting(false)
    }

    private var sparkLayer: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !sparksLive)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for spark in sparks {
                    let age = timeline.date.timeIntervalSince(spark.birth) / 0.55
                    guard age >= 0, age < 1 else { continue }
                    let eased = 1 - pow(1 - age, 3)
                    let distance = 44 + spark.reach * CGFloat(eased)
                    let point = CGPoint(
                        x: center.x + CGFloat(cos(spark.angle)) * distance,
                        y: center.y + CGFloat(sin(spark.angle)) * distance
                    )
                    let dot = 3.4 * CGFloat(1 - age * 0.6)
                    context.opacity = 1 - age * age
                    if spark.triangle {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: -dot * 1.4))
                        path.addLine(to: CGPoint(x: dot * 1.2, y: dot))
                        path.addLine(to: CGPoint(x: -dot * 1.2, y: dot))
                        path.closeSubpath()
                        let transform = CGAffineTransform(translationX: point.x, y: point.y)
                            .rotated(by: spark.angle + spark.spin * age)
                        context.fill(path.applying(transform), with: .color(spark.color))
                    } else {
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)),
                            with: .color(spark.color)
                        )
                    }
                }
            }
        }
        .frame(width: 220, height: 220)
        .allowsHitTesting(false)
    }

    private var totals: some View {
        VStack(spacing: 2) {
            Text(verbatim: (Self.baseTotal + count).formatted(.number.grouping(.automatic)))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
                .foregroundStyle(.primary)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: count)
            Text(L("claps", "次鼓掌"), ctx.language)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Behaviour

    private func clap(haptics: Bool) {
        guard !capped else {
            if haptics { Haptics.tap(.rigid) }
            return
        }
        streak += 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { count += 1 }
        if haptics {
            if count >= cap {
                Haptics.success()
            } else {
                Haptics.tap(streak < 5 ? .light : (streak < 12 ? .medium : .heavy))
            }
        }
        emitSparks()
        if bubble != .shown {
            // Start from the button again, without animating the jump back.
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { bubble = .hidden }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { bubble = .shown }
        }
        scheduleDismiss()
    }

    private func emitSparks() {
        let now = Date()
        sparks.removeAll { now.timeIntervalSince($0.birth) > 0.6 }
        let amount = ctx.int("sparks") + min(streak / 2, 8)
        let reach = 20 + min(CGFloat(streak) * 1.6, 26)
        let start = Double.random(in: 0..<(2 * .pi))
        for index in 0..<amount {
            let angle = start + Double(index) / Double(amount) * 2 * .pi + Double.random(in: -0.16...0.16)
            sparks.append(
                ButtonClapSpark(
                    birth: now,
                    angle: angle,
                    reach: reach * CGFloat.random(in: 0.75...1),
                    color: Palette.spectrum[(index + streak) % Palette.spectrum.count],
                    triangle: index % 2 == 0,
                    spin: Double.random(in: -3...3)
                )
            )
        }
        sparksLive = true
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.45)) { bubble = .leaving }
            streak = 0
            sparksLive = false
        }
    }

    private func beginHold(haptics: Bool) {
        holdTask?.cancel()
        holding = true
        clap(haptics: haptics)
        let multiplier = ctx["accel"]
        holdTask = Task { @MainActor in
            var interval = 0.3
            try? await Task.sleep(for: .seconds(0.38))
            while !Task.isCancelled {
                clap(haptics: haptics)
                interval = max(0.05, interval * multiplier)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func endHold() {
        holdTask?.cancel()
        holdTask = nil
        holding = false
    }

    /// Preview loop and detail intro: two taps, then a hold. Never buzzes.
    private func playScript() {
        scriptTask?.cancel()
        if capped {
            withAnimation(.smooth(duration: 0.3)) { count = 0 }
        }
        scriptTask = Task { @MainActor in
            clap(haptics: false)
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            clap(haptics: false)
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            beginHold(haptics: false)
            try? await Task.sleep(for: .seconds(1.5))
            // A real finger took over: its own hold must keep running.
            guard !Task.isCancelled else { return }
            endHold()
        }
    }
}
