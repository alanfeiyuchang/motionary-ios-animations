import SwiftUI

extension Effect {
    static let buttonsHoldLiquid = Effect(
        id: "buttons.hold-liquid",
        category: .buttons,
        interaction: .gesture,
        name: L("Liquid Fill Hold", "注液长按"),
        summary: L(
            "Holding fills the button with sloshing liquid that inverts the label as it rises.",
            "按住时液体晃动着注满按钮，水面升到哪里，文字就反色到哪里。"
        ),
        prompt: L(
            "A 236 × 64 pt capsule with a quiet surface and the label “Hold to send”. While held, liquid rises from the bottom over 1.5 s: a blue gradient body with a lighter second wave behind it, both surfaces travelling sine waves 5 pt high in opposite phase, with small bubbles climbing inside. The label is drawn twice and the inverted copy is masked by the liquid, so each letter flips colour exactly at the waterline. Starting or stopping the hold kicks the surface into a slosh: it tilts up to 8 pt end to end and rocks back as a damped 1.4 Hz oscillation. Releasing early drains at 2× speed. When full, the waves calm within half a second, the label rolls to “Sent” with a check through a blur, and the capsule pops to 104% with a success haptic; 1.6 s later it drains itself. Fluid, patient, satisfying.",
            "236×64pt 的胶囊按钮，底色安静，写着“按住发送”。按住期间，液体在 1.5 秒内从底部升起：蓝色渐变主体后面还有一层更浅的波，两层水面都是 5pt 高、相位相反的行进正弦波，内部有小气泡上浮。文字绘制两份，反色的那份由液体遮罩，因此每个字恰好在水线处反色。开始或停止按压都会让水面晃动：两端最多倾斜 8pt，再以 1.4 Hz 的阻尼振荡摆回。提前松手，液体以 2 倍速度排空。注满后波浪在半秒内平息，文字带模糊滚动成带对勾的“已发送”，胶囊弹到 104% 并触发成功触感；1.6 秒后自行排空。"
        ),
        implementation: L(
            "The fill level is a pure function of time whose rate flips on press and release; a TimelineView evaluates it each frame and feeds a wave Shape (level, phase, amplitude, tilt). The same Shape masks an inverted copy of the label and clips a Canvas of bubbles, while the tilt is a damped cosine measured from the last press or release.",
            "液位是时间的纯函数，按下与松开只是切换其速率；TimelineView 每帧求值并传给波浪 Shape（液位、相位、振幅、倾斜）。同一个 Shape 既遮罩反色的文字副本，也裁剪气泡 Canvas；倾斜量则是从最近一次按下或松开算起的阻尼余弦。"
        ),
        apis: ["TimelineView", "Shape", "mask", "onLongPressGesture(minimumDuration:maximumDistance:perform:onPressingChanged:)", "Canvas"],
        tags: ["hold", "liquid", "wave", "fill", "长按", "液体", "波浪", "注满"],
        params: [
            .slider("duration", L("Fill time", "注满时长"), 0.8...3.0, default: 1.5, unit: "s"),
            .slider("wave", L("Wave height", "波浪高度"), 0...10, default: 5, decimals: 1, unit: "pt"),
            .slider("slosh", L("Slosh tilt", "晃动倾斜"), 0...16, default: 8, decimals: 0, unit: "pt"),
            .slider("drain", L("Drain speed", "排空速度"), 1...4, default: 2, decimals: 1, unit: "×"),
        ]
    ) { ctx in
        ButtonLiquidDemo(ctx: ctx)
    }
}

/// Fill level as a pure function of time.
private struct ButtonLiquidClock {
    var base: Double = 0
    var rate: Double = 0
    var since = Date.distantPast

    func value(at date: Date) -> Double {
        (base + rate * date.timeIntervalSince(since)).clamped(to: 0...1)
    }
}

private enum ButtonLiquidPhase {
    case idle, filling, draining, done
}

private struct ButtonLiquidDemo: View {
    let ctx: DemoContext
    @State private var clock = ButtonLiquidClock()
    @State private var phase = ButtonLiquidPhase.idle
    /// When the surface was last kicked, and which way.
    @State private var kickAt = Date.distantPast
    @State private var kickSign: Double = 1
    @State private var pops = 0
    @State private var finishTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    private static let size = CGSize(width: 236, height: 64)
    private var duration: Double { max(ctx["duration"], 0.2) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            control
            Spacer()
            DemoHint(text: L("Hold until the button is full", "一直按住，直到注满"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: duration * 1.8 + 3.6, delay: 0.4) { playScript() }
        .onDisappear {
            scriptTask?.cancel()
            finishTask?.cancel()
        }
    }

    private var control: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: phase == .idle || ctx.isStill)) { timeline in
            let now = timeline.date
            let since = ctx.isStill ? 0.25 : now.timeIntervalSince(kickAt)
            ButtonLiquidFace(
                level: ctx.isStill ? 0.56 : clock.value(at: now),
                time: ctx.isStill ? 0 : now.timeIntervalSinceReferenceDate,
                // Damped rocking after every press or release.
                tilt: ctx.cg("slosh") * CGFloat(kickSign * exp(-2.6 * since) * cos(since * 2 * .pi * 1.4)),
                // Waves run high while the level moves and die down once it rests.
                amplitude: ctx.cg("wave") * CGFloat(moving ? 1 : max(exp(-6 * since), 0)),
                done: phase == .done,
                language: ctx.language
            )
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .scaleEffect(phase == .filling ? 0.97 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: phase == .filling)
        .keyframeAnimator(initialValue: 1.0, trigger: pops) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.04, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
            }
        }
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: 600, maximumDistance: 60) {
        } onPressingChanged: { isPressing in
            scriptTask?.cancel()
            if isPressing { begin(haptics: true) } else { cancel() }
        }
        .accessibilityAddTraits(.isButton)
    }

    private var moving: Bool { phase == .filling || phase == .draining || ctx.isStill }

    // MARK: Behaviour

    private func kick(_ sign: Double, at date: Date) {
        kickAt = date
        kickSign = sign
    }

    private func begin(haptics: Bool) {
        guard phase != .done else { return }
        let now = Date()
        let current = clock.value(at: now)
        clock = ButtonLiquidClock(base: current, rate: 1 / duration, since: now)
        kick(1, at: now)
        phase = .filling
        if haptics { Haptics.tap(.soft) }
        finishTask?.cancel()
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds((1 - current) * duration))
            guard !Task.isCancelled else { return }
            finish(haptics: haptics)
        }
    }

    private func cancel() {
        guard phase == .filling else { return }
        drain(speed: max(ctx["drain"], 0.5), sign: -1)
    }

    private func drain(speed: Double, sign: Double) {
        finishTask?.cancel()
        let now = Date()
        let current = clock.value(at: now)
        clock = ButtonLiquidClock(base: current, rate: -speed / duration, since: now)
        kick(sign, at: now)
        withAnimation(.smooth(duration: 0.3)) { phase = .draining }
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(current * duration / speed + 0.05))
            guard !Task.isCancelled else { return }
            if phase == .draining { phase = .idle }
        }
    }

    private func finish(haptics: Bool) {
        let now = Date()
        clock = ButtonLiquidClock(base: 1, rate: 0, since: now)
        kick(-0.6, at: now)
        pops += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .done }
        if haptics { Haptics.success() }
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            drain(speed: 2.4, sign: 1)
        }
    }

    /// Preview loop and detail intro: a full fill, then a short hold that is let go and drains.
    private func playScript() {
        guard phase == .idle else { return }
        scriptTask?.cancel()
        let fill = duration
        scriptTask = Task { @MainActor in
            begin(haptics: false)
            try? await Task.sleep(for: .seconds(fill + 1.6 + fill / 2.4 + 0.5))
            guard !Task.isCancelled, ctx.isPreview else { return }
            begin(haptics: false)
            try? await Task.sleep(for: .seconds(fill * 0.55))
            guard !Task.isCancelled else { return }
            cancel()
        }
    }
}

private struct ButtonLiquidFace: View {
    let level: Double
    let time: Double
    let tilt: CGFloat
    let amplitude: CGFloat
    let done: Bool
    let language: AppLanguage
    @Environment(\.colorScheme) private var colorScheme

    /// The label's colour inside the liquid: the opposite of its colour on the empty surface.
    private var submerged: Color { colorScheme == .dark ? Color(hex: 0x04193A) : .white }

    var body: some View {
        let front = ButtonLiquidShape(level: level, phase: time * 4.2, amplitude: amplitude, tilt: tilt, wavelength: 132)
        let back = ButtonLiquidShape(level: level, phase: -time * 3.1 + 2.1, amplitude: amplitude * 1.25, tilt: -tilt * 0.6, wavelength: 96)
        ZStack {
            Capsule().fill(Palette.elevated)
            label(color: .primary)
            back
                .fill(Palette.sky.opacity(0.5))
                .offset(y: -3)
            front.fill(LinearGradient(colors: [Palette.sky, Palette.blue], startPoint: .top, endPoint: .bottom))
            ButtonLiquidBubbles(time: time, active: level > 0.02 && !done)
                .mask(front)
            // Light on the surface: a thin bright line riding the front wave.
            front.stroke(Color.white.opacity(0.55), lineWidth: 1.2)
            label(color: submerged)
                .mask(front)
        }
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
        .shadow(color: Palette.blue.opacity(0.12 + 0.24 * level), radius: 16, y: 9)
    }

    /// Drawn twice with identical layout: once dark on the surface, once white inside the liquid.
    private func label(color: Color) -> some View {
        ZStack {
            if done {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L("Sent", "已发送"), language)
                }
                .transition(ButtonLiquidRoll(distance: 16))
            } else {
                HStack(spacing: 7) {
                    Image(systemName: "paperplane.fill")
                    Text(L("Hold to send", "按住发送"), language)
                }
                .transition(ButtonLiquidRoll(distance: 16))
            }
        }
        .font(.headline)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ButtonLiquidRoll: Transition {
    let distance: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .offset(y: phase == .willAppear ? distance : (phase == .didDisappear ? -distance : 0))
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 5)
    }
}

/// Everything below a tilted, travelling sine surface.
private struct ButtonLiquidShape: Shape {
    let level: Double
    let phase: Double
    let amplitude: CGFloat
    let tilt: CGFloat
    let wavelength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard level > 0.0005 else { return path }
        // Slack above and below, so an empty button hides the crests and a full one covers them.
        let slack = amplitude * 1.3 + abs(tilt) + 2
        let waterline = rect.maxY + slack - (rect.height + slack * 2) * CGFloat(level)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY + 2))
        var x = rect.minX
        while x <= rect.maxX + 3 {
            let wave = amplitude * CGFloat(sin(Double(x / wavelength) * 2 * .pi + phase))
            let lean = tilt * (x - rect.midX) / (rect.width / 2)
            path.addLine(to: CGPoint(x: x, y: waterline + wave + lean))
            x += 3
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY + 2))
        path.closeSubpath()
        return path
    }
}

private struct ButtonLiquidBubbles: View {
    let time: Double
    let active: Bool

    var body: some View {
        Canvas { context, size in
            guard active else { return }
            for index in 0..<9 {
                let seed: Double = Double(index) * 0.618
                let speed: Double = 0.5 + 0.35 * (seed - seed.rounded(.down))
                let cycle: Double = time * speed + seed * 3
                let rise: Double = cycle - cycle.rounded(.down)
                let column: Double = seed * 7.3
                let columnFraction: Double = column - column.rounded(.down)
                let sway: Double = sin(time * 3 + seed * 9) * 3
                let x: CGFloat = size.width * CGFloat(0.08 + 0.84 * columnFraction) + CGFloat(sway)
                let y: CGFloat = size.height * CGFloat(1.05 - rise * 1.1)
                let grain: Double = seed * 3.7
                let radius: CGFloat = CGFloat(1.4 + 1.8 * (grain - grain.rounded(.down)))
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(Color.white.opacity(0.32 * (1 - rise * 0.5)))
                )
            }
        }
    }
}
