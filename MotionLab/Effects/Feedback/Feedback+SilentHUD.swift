import SwiftUI

// MARK: - Silent HUD

extension Effect {
    static let feedbackSilentHUD = Effect(
        id: "feedback.silent-hud",
        category: .feedback,
        interaction: .tap,
        name: L("Ringer HUD", "静音提示 HUD"),
        summary: L("Flipping the ringer drops a black pill from the top: the bell swings, gets struck through, and the level bar drains.", "拨动静音键，顶部落下黑色胶囊：铃铛摆动、被一道斜线划掉，音量条随之排空。"),
        prompt: L(
            "A phone screen with a hardware switch on its left edge. Flipping the switch drops a black 50 pt pill from the top on a spring (response 0.45 s, damping 0.7), scaling from 60% out of a 6 pt blur. Inside, a bell hung from its top swings like a pendulum: 28° one way, then −20°, 12°, −6°, settling in about 1 s. Going silent, a slash strokes across the bell in 0.28 s with a knocked-out outline, bell and label turn red, the label rolls from 'Ring' to 'Silent', and the 72 pt level bar drains to empty on a spring (response 0.5 s, damping 0.8). Going back to ring, the slash retracts, the bar refills to 70% and two sound arcs pulse outward from the bell. The pill shrinks back up after 1.6 s. A rigid haptic marks the switch. Terse, system-grade, legible at a glance.",
            "手机屏幕左缘有一枚实体拨键。拨动后，50 pt 高的黑色胶囊从顶部落下：弹簧（响应 0.45 秒、阻尼 0.7），由 60% 放大并从 6 pt 模糊中清晰。铃铛以顶端为轴像钟摆摆动：28°、−20°、12°、−6°，约 1 秒停稳。切到静音时，一道带镂空描边的斜线 0.28 秒划过铃铛，铃铛与文字变红，文字从“响铃”滚动为“静音”，72 pt 音量条以弹簧（响应 0.5 秒、阻尼 0.8）排空。切回响铃时斜线收回，音量条回填到 70%，两道声波弧向外脉冲。1.6 秒后缩回顶部，拨键瞬间有硬朗触感。简洁、系统级。"
        ),
        implementation: L(
            "The pill is a Capsule sized by its content; a keyframeAnimator keyed on a swing counter rotates the bell around its top anchor through decaying angles, the slash is a trimmed line drawn twice (a thick pill-coloured stroke under a thin tinted one), and a cancellable task re-arms the auto-dismiss on every flip.",
            "胶囊是由内容决定尺寸的 Capsule；以摆动计数为触发器的 keyframeAnimator 让铃铛绕顶部锚点按衰减角度旋转，斜线是画两遍的 trim 线段（底下一道与胶囊同色的粗线，上面一道着色细线），可取消的任务在每次拨动时重新计时自动收起。"
        ),
        apis: ["keyframeAnimator(initialValue:trigger:)", "rotationEffect(_:anchor:)", "trim(from:to:)", "contentTransition(.numericText)", "spring(response:dampingFraction:)"],
        tags: ["hud", "silent", "ringer", "mute", "静音", "响铃", "系统提示", "音量"],
        params: [
            .slider("swing", L("Swing angle", "摆动角度"), 10...45, default: 28, decimals: 0, unit: "°"),
            .slider("dismiss", L("Stay time", "停留时长"), 0.8...3.0, default: 1.6, decimals: 1, unit: "s"),
            .slider("damping", L("Drop damping", "落下阻尼"), 0.5...1.0, default: 0.7),
            .slider("level", L("Ring volume", "响铃音量"), 0.2...1.0, default: 0.7),
        ]
    ) { ctx in
        SilentHUDDemo(ctx: ctx)
    }
}

private struct SilentHUDDemo: View {
    let ctx: DemoContext
    @State private var silent: Bool
    @State private var shown: Bool
    @State private var swings = 0
    @State private var waveAt = Date.distantPast
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the HUD in silent mode.
        _silent = State(initialValue: ctx.isStill)
        _shown = State(initialValue: ctx.isStill)
    }

    private static let red = Color(hex: 0xFF453A)

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                wallpaper
                hud
                    .padding(.top, 14)
            }
            .frame(width: 280, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color.primary.opacity(0.22), lineWidth: 3))
            .overlay(alignment: .topLeading) { hardwareSwitch }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
            .contentShape(Rectangle())
            .onTapGesture { flip() }
            DemoHint(text: L("Tap to flip the ringer switch", "点击拨动静音键"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["dismiss"] + 0.8, delay: 0.5) { flip() }
    }

    // MARK: Scene

    private var wallpaper: some View {
        let zh = ctx.language == .zh
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x1B1F4B), Color(hex: 0x5B3A8C), Color(hex: 0xE0708A), Color(hex: 0xFFB36B)], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Color(hex: 0xFFD9A0).opacity(0.5))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(y: 110)
            VStack(spacing: 0) {
                Text(zh ? "9月30日 星期三" : "Wednesday, September 30")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(verbatim: "9:41")
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .offset(y: -20)
        }
    }

    /// The side switch: up for ring, down (showing orange) for silent.
    private var hardwareSwitch: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(Color(hex: 0xFF9500))
                .frame(width: 5, height: 26)
            Capsule()
                .fill(Color.adaptive(light: 0x8E8E93, dark: 0xAEAEB2))
                .frame(width: 5, height: 17)
                .offset(y: silent ? 9 : 0)
        }
        .offset(x: -5, y: 62)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: silent)
    }

    // MARK: HUD

    private var hud: some View {
        let zh = ctx.language == .zh
        let tint: Color = silent ? Self.red : .white
        return HStack(spacing: 8) {
            bell(tint: tint)
            Text(silent ? (zh ? "静音" : "Silent") : (zh ? "响铃" : "Ring"))
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .fixedSize()
            levelBar
        }
        .padding(.leading, 14)
        .padding(.trailing, 20)
        .frame(height: 50)
        .background(Color.black, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
        .scaleEffect(shown ? 1 : 0.6)
        .blur(radius: shown ? 0 : 6)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : -70)
    }

    private func bell(tint: Color) -> some View {
        let angle: Double = ctx["swing"]
        return ZStack {
            SilentHUDBurstClock(start: waveAt, duration: 0.7, preview: ctx.isPreview) { clock in
                SilentHUDWaves(clock: clock)
            }
            Image(systemName: "bell.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
            // Knock-out under the slash, then the slash itself.
            SilentHUDSlash()
                .trim(from: 0, to: silent ? 1 : 0)
                .stroke(Color.black, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                .frame(width: 28, height: 28)
                .animation(.easeOut(duration: 0.28), value: silent)
            SilentHUDSlash()
                .trim(from: 0, to: silent ? 1 : 0)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 28, height: 28)
                .animation(.easeOut(duration: 0.28), value: silent)
        }
        .frame(width: 36, height: 28)
        .keyframeAnimator(initialValue: 0.0, trigger: swings) { content, swing in
            content.rotationEffect(.degrees(swing), anchor: .top)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(angle, duration: 0.14)
                CubicKeyframe(-angle * 0.71, duration: 0.2)
                CubicKeyframe(angle * 0.43, duration: 0.2)
                CubicKeyframe(-angle * 0.21, duration: 0.2)
                SpringKeyframe(0.0, duration: 0.3, spring: .smooth)
            }
        }
    }

    private var levelBar: some View {
        let level: CGFloat = silent ? 0 : ctx.cg("level")
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.22))
            Capsule()
                .fill(Color.white)
                .frame(width: max(72 * level, 0))
        }
        .frame(width: 72, height: 6)
        .clipShape(Capsule())
    }

    // MARK: Sequence

    private func flip() {
        token += 1
        let current = token
        let dismiss: Double = ctx["dismiss"]
        let wasShown: Bool = shown
        let goingSilent: Bool = !silent
        if !ctx.isPreview { Haptics.tap(.rigid) }
        withAnimation(.spring(response: 0.45, dampingFraction: ctx["damping"])) { shown = true }
        Task { @MainActor in
            // A fresh pill lands first; one that is already down reacts at once.
            if !wasShown {
                try? await Task.sleep(for: .seconds(0.12))
                guard token == current else { return }
            }
            swings += 1
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { silent = goingSilent }
            if !goingSilent { waveAt = Date() }
            try? await Task.sleep(for: .seconds(dismiss))
            guard token == current else { return }
            withAnimation(.easeIn(duration: 0.25)) { shown = false }
        }
    }
}

// MARK: - Pieces

private struct SilentHUDSlash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 3, y: rect.minY + 3))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.maxY - 3))
        return path
    }
}

/// Feeds a 0 → 1 clock to `content` for `duration` seconds after `start` changes; the timeline is paused
/// the rest of the time, and `content` then gets 1 (finished).
private struct SilentHUDBurstClock<Content: View>: View {
    let start: Date
    let duration: Double
    let preview: Bool
    @ViewBuilder let content: (Double) -> Content
    @State private var running = false

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !running)) { timeline in
            let t: Double = timeline.date.timeIntervalSince(start) / duration
            content(running ? min(max(t, 0), 1) : 1)
        }
        .task(id: start) {
            guard start != .distantPast else { return }
            running = true
            try? await Task.sleep(for: .seconds(duration + 0.05))
            guard !Task.isCancelled else { return }
            running = false
        }
    }
}

/// Two arcs on each side of the bell that pulse outward when the ringer comes back on.
private struct SilentHUDWaves: View {
    /// 0 → 1 over the 0.7 s pulse.
    let clock: Double

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let u: Double = min(max(clock * 1.4 - Double(index) * 0.4, 0), 1)
                let radius: CGFloat = 12 + CGFloat(index) * 2.5 + 3 * CGFloat(u)
                ZStack {
                    // Right-hand arc (split across the trim seam) and left-hand arc.
                    Circle().trim(from: 0.92, to: 1).stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    Circle().trim(from: 0, to: 0.08).stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    Circle().trim(from: 0.42, to: 0.58).stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                .frame(width: radius * 2, height: radius * 2)
                .opacity(u > 0 && u < 1 ? sin(u * .pi) : 0)
            }
        }
        .allowsHitTesting(false)
    }
}
