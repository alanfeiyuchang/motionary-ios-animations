import SwiftUI

// MARK: - Achievement banner

extension Effect {
    static let feedbackAchievementBanner = Effect(
        id: "feedback.achievement-banner",
        category: .feedback,
        interaction: .tap,
        name: L("Achievement Banner", "成就横幅"),
        summary: L("A medal drops onto a dark banner and bounces, a shine sweeps across and the title lands letter by letter.", "奖牌落到深色横幅上弹跳两下，高光扫过，标题逐字落定。"),
        prompt: L(
            "Checking in on day 7 fills the last streak dot, then a 296 × 84 pt midnight banner with a gold hairline springs down from the top (response 0.5 s, damping 0.78). 150 ms later a 54 pt gold medal falls into its left slot under gravity (0.28 s ease-in), squashes to 80%, rebounds 22 pt, then 7 pt, and rests; the banner dips 5 pt on the first impact. At that instant eight four-point sparkles pop around the medal, each swelling and fading over 0.5 s while turning 90°, a medium haptic fires, and a soft white band sweeps the banner in 0.7 s. The title rises letter by letter from 12 pt below out of a blur, 35 ms apart, on a spring (response 0.4 s, damping 0.7). It leaves upward after 2.2 s. Proud and polished, like a console trophy.",
            "第 7 天签到点亮最后一颗圆点，随后 296 × 84 pt、带金色细描边的午夜色横幅从顶部弹入（响应 0.5 秒、阻尼 0.78）。150 毫秒后，54 pt 金色奖牌在重力下落入左侧槽位（0.28 秒缓入），压扁到 80%，先反弹 22 pt、再 7 pt 后停稳；首次撞击时横幅下沉 5 pt，八颗四角星芒在奖牌周围绽放，各在 0.5 秒内放大淡出并旋转 90°，触发中等触感，一道白光 0.7 秒扫过横幅。标题逐字从下方 12 pt 带模糊升起，间隔 35 毫秒（响应 0.4 秒、阻尼 0.7）。2.2 秒后向上离场。精致，像主机奖杯。"
        ),
        implementation: L(
            "One keyframeAnimator plays the medal's fall and two rebounds with linear keyframes on ease-in/ease-out timing curves (a real floor bounce, not a spring) plus a squash track; a second one sweeps the shine, and a TimelineView feeds a 0 → 1 clock to the sparkles; letters are separate Texts animated with a per-index delay.",
            "一个 keyframeAnimator 用带缓入/缓出时间曲线的线性关键帧播放奖牌下落与两次反弹（真正的触地弹跳，而非弹簧），外加一条压扁轨道；另一个驱动高光扫过，TimelineView 向星芒输出 0 → 1 的时钟；标题拆成逐字的 Text，按序号延迟动画。"
        ),
        apis: ["keyframeAnimator(initialValue:trigger:)", "LinearKeyframe(_:duration:timingCurve:)", "AngularGradient", "Shape", "animation(_:value:)"],
        tags: ["achievement", "banner", "medal", "trophy", "成就", "横幅", "奖牌", "解锁"],
        params: [
            .slider("bounce", L("Bounce height", "反弹高度"), 0...40, default: 22, decimals: 0, unit: "pt"),
            .slider("stagger", L("Letter stagger", "逐字间隔"), 0.01...0.08, default: 0.035, decimals: 3, unit: "s"),
            .slider("sparkles", L("Sparkles", "星芒数"), 4...14, default: 8, step: 1, decimals: 0),
            .slider("hold", L("Stay time", "停留时长"), 1.0...4.0, default: 2.2, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        AchievementBannerDemo(ctx: ctx)
    }
}

private struct AchievementMedalPose {
    var y: CGFloat = 0
    var turn: Double = 0
    var squash: CGFloat = 1
}

private struct AchievementBannerDemo: View {
    let ctx: DemoContext
    @State private var shown: Bool
    @State private var medalShown: Bool
    @State private var lettersIn: Bool
    @State private var checkedIn: Bool
    @State private var drops = 0
    @State private var impacts = 0
    @State private var impactAt = Date.distantPast
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the banner settled.
        _shown = State(initialValue: ctx.isStill)
        _medalShown = State(initialValue: ctx.isStill)
        _lettersIn = State(initialValue: ctx.isStill)
        _checkedIn = State(initialValue: ctx.isStill)
    }

    private static let gold = Color(hex: 0xFFD66B)

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                streakCard
                banner
                    .padding(.top, 14)
            }
            .frame(width: 320, height: 300)
            DemoHint(text: L("Tap Check in", "点击“签到”"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["hold"] + 3.2, delay: 0.4) { play() }
    }

    // MARK: Scene

    private var streakCard: some View {
        let zh = ctx.language == .zh
        let days: [String] = zh ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"]
        return VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(zh ? "本周打卡" : "This week")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text(verbatim: "\(checkedIn ? 7 : 6)/7")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Palette.coral)
                    .contentTransition(.numericText(value: checkedIn ? 7 : 6))
            }
            .frame(width: 236)
            HStack(spacing: 9) {
                ForEach(0..<7, id: \.self) { index in
                    let filled: Bool = index < 6 || checkedIn
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                            Circle()
                                .fill(Palette.sunset)
                                .scaleEffect(filled ? 1 : 0.01)
                                .opacity(filled ? 1 : 0)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .scaleEffect(filled ? 1 : 0.2)
                                .opacity(filled ? 1 : 0)
                        }
                        .frame(width: 26, height: 26)
                        Text(verbatim: days[index])
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button(action: play) {
                Text(zh ? "签到" : "Check in")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 236, height: 40)
                    .background(Palette.primaryStrong, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 18)
        .frame(width: 280)
        .demoCard(cornerRadius: 26)
        .padding(.top, 116)
    }

    // MARK: Banner

    private var banner: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return HStack(spacing: 14) {
            medalSlot
            bannerText
            Spacer(minLength: 0)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(width: 296, height: 84)
        .background {
            shape.fill(LinearGradient(colors: [Color(hex: 0x2A2B45), Color(hex: 0x12121C)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            Color.clear
                .overlay { AchievementShine() }
                .keyframeAnimator(initialValue: -1.0, trigger: impacts) { content, sweep in
                    content.environment(\.achievementClock, sweep)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(-1.0)
                        CubicKeyframe(1.0, duration: 0.7)
                    }
                }
                .clipShape(shape)
                .allowsHitTesting(false)
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(colors: [Self.gold.opacity(0.7), Self.gold.opacity(0.12), Self.gold.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
        .keyframeAnimator(initialValue: CGFloat(0), trigger: impacts) { content, dip in
            content.offset(y: dip)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(5, duration: 0.07)
                SpringKeyframe(0, duration: 0.45, spring: .bouncy)
            }
        }
        .scaleEffect(shown ? 1 : 0.86)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : -130)
    }

    private var medalSlot: some View {
        let bounce: CGFloat = ctx.cg("bounce")
        let count: Int = max(ctx.int("sparkles"), 1)
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.28))
                .frame(width: 58, height: 58)
            AchievementBurstClock(start: impactAt, duration: 0.9, preview: ctx.isPreview) { clock in
                AchievementSparkles(count: count, clock: clock)
            }
            AchievementMedal()
                .frame(width: 54, height: 54)
                .keyframeAnimator(initialValue: AchievementMedalPose(), trigger: drops) { content, pose in
                    content
                        .scaleEffect(x: 2 - pose.squash, y: pose.squash, anchor: .bottom)
                        .rotationEffect(.degrees(pose.turn))
                        .offset(y: pose.y)
                } keyframes: { _ in
                    KeyframeTrack(\.y) {
                        MoveKeyframe(-150)
                        LinearKeyframe(0, duration: 0.28, timingCurve: .easeIn)
                        LinearKeyframe(-bounce, duration: 0.14, timingCurve: .easeOut)
                        LinearKeyframe(0, duration: 0.14, timingCurve: .easeIn)
                        LinearKeyframe(-bounce * 0.32, duration: 0.09, timingCurve: .easeOut)
                        LinearKeyframe(0, duration: 0.09, timingCurve: .easeIn)
                    }
                    KeyframeTrack(\.turn) {
                        MoveKeyframe(-70)
                        LinearKeyframe(0, duration: 0.28, timingCurve: .easeOut)
                    }
                    KeyframeTrack(\.squash) {
                        MoveKeyframe(1.08)
                        LinearKeyframe(1.08, duration: 0.25)
                        CubicKeyframe(0.8, duration: 0.05)
                        CubicKeyframe(1.05, duration: 0.12)
                        CubicKeyframe(1.0, duration: 0.11)
                        CubicKeyframe(0.92, duration: 0.05)
                        SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                    }
                }
                .opacity(medalShown ? 1 : 0)
        }
        .frame(width: 58, height: 58)
    }

    private var bannerText: some View {
        let zh = ctx.language == .zh
        let title: String = zh ? "连续打卡 7 天" : "7-Day Streak"
        let stagger: Double = ctx["stagger"]
        return VStack(alignment: .leading, spacing: 3) {
            Text(zh ? "成就已解锁" : "ACHIEVEMENT UNLOCKED")
                .font(.system(size: 10, weight: .heavy))
                .tracking(zh ? 2 : 1.1)
                .foregroundStyle(Self.gold)
                .opacity(lettersIn ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: lettersIn)
            HStack(spacing: 0) {
                ForEach(Array(title.enumerated()), id: \.offset) { index, letter in
                    Text(verbatim: String(letter))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: lettersIn ? 0 : 12)
                        .opacity(lettersIn ? 1 : 0)
                        .blur(radius: lettersIn ? 0 : 5)
                        .animation(
                            lettersIn
                                ? Animation.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * stagger)
                                : Animation.linear(duration: 0.01),
                            value: lettersIn
                        )
                }
            }
            Text(zh ? "+250 经验" : "+250 XP")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
                .opacity(lettersIn ? 1 : 0)
                .animation(lettersIn ? Animation.easeOut(duration: 0.3).delay(0.35) : Animation.linear(duration: 0.01), value: lettersIn)
        }
    }

    // MARK: Sequence

    private func play() {
        token += 1
        let current = token
        let hold: Double = ctx["hold"]
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let preview: Bool = ctx.isPreview
        if buzz { Haptics.tap() }
        Task { @MainActor in
            if shown || checkedIn {
                // Replay: clear the previous run first.
                withAnimation(.easeIn(duration: 0.2)) {
                    shown = false
                    checkedIn = false
                }
                try? await Task.sleep(for: .seconds(0.3))
                guard token == current else { return }
                medalShown = false
                lettersIn = false
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { checkedIn = true }
            try? await Task.sleep(for: .seconds(0.35))
            guard token == current else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { shown = true }
            try? await Task.sleep(for: .seconds(0.15))
            guard token == current else { return }
            medalShown = true
            drops += 1
            lettersIn = true
            // The medal touches down 0.28 s into its fall.
            try? await Task.sleep(for: .seconds(0.28))
            guard token == current else { return }
            impacts += 1
            impactAt = Date()
            if buzz { Haptics.tap(.medium) }
            try? await Task.sleep(for: .seconds(hold))
            guard token == current else { return }
            withAnimation(.easeIn(duration: 0.3)) { shown = false }
            try? await Task.sleep(for: .seconds(0.35))
            guard token == current else { return }
            medalShown = false
            lettersIn = false
            guard preview else { return }
            withAnimation(.smooth(duration: 0.3)) { checkedIn = false }
        }
    }
}

// MARK: - Pieces

private struct AchievementClockKey: EnvironmentKey {
    static let defaultValue: Double = 1
}

private extension EnvironmentValues {
    /// −1 → 1 position of the shine sweep.
    var achievementClock: Double {
        get { self[AchievementClockKey.self] }
        set { self[AchievementClockKey.self] = newValue }
    }
}

/// Feeds a 0 → 1 clock to `content` for `duration` seconds after `start` changes; the timeline is paused
/// the rest of the time, and `content` then gets 1 (finished).
private struct AchievementBurstClock<Content: View>: View {
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

private struct AchievementMedal: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [Color(hex: 0xFFE9A6), Color(hex: 0xF2A93B), Color(hex: 0xFFF3C4), Color(hex: 0xD98B1F), Color(hex: 0xFFE9A6)],
                        center: .center
                    )
                )
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFFD66B), Color(hex: 0xF0A030)], startPoint: .top, endPoint: .bottom))
                .padding(5)
            Circle()
                .strokeBorder(Color(hex: 0xB86E0E).opacity(0.55), lineWidth: 1)
                .padding(5)
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF6D8), Color(hex: 0xFFE08A)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(hex: 0x9A5A00).opacity(0.6), radius: 0.5, y: 1)
            // Fixed specular highlight.
            Ellipse()
                .fill(Color.white.opacity(0.5))
                .frame(width: 22, height: 9)
                .blur(radius: 4)
                .offset(x: -8, y: -15)
        }
        .shadow(color: Color(hex: 0xF2A93B).opacity(0.5), radius: 10, y: 3)
    }
}

/// A soft diagonal band that crosses the banner once per impact.
private struct AchievementShine: View {
    @Environment(\.achievementClock) private var sweep

    var body: some View {
        LinearGradient(
            colors: [.white.opacity(0), .white.opacity(0.32), .white.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 90, height: 160)
        .rotationEffect(.degrees(20))
        .offset(x: CGFloat(sweep) * 220)
        .blendMode(.plusLighter)
    }
}

private struct AchievementSparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r: CGFloat = min(rect.width, rect.height) / 2
        let inner: CGFloat = r * 0.26
        var path = Path()
        for step in 0..<8 {
            let angle: Double = Double(step) * .pi / 4 - .pi / 2
            let radius: CGFloat = step % 2 == 0 ? r : inner
            let point = CGPoint(x: c.x + CGFloat(cos(angle)) * radius, y: c.y + CGFloat(sin(angle)) * radius)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct AchievementSparkles: View {
    let count: Int
    /// 0 → 1 over the 0.9 s burst.
    let clock: Double

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                sparkle(index)
            }
        }
        .allowsHitTesting(false)
    }

    private func sparkle(_ index: Int) -> some View {
        let noise: Double = abs(sin(Double(index) * 12.9898 + 4.1))
        let delay: Double = noise * 0.36
        // Each sparkle lives 0.5 s inside the 0.9 s clock.
        let u: Double = min(max((clock * 0.9 - delay) / 0.5, 0), 1)
        let angle: Double = Double(index) / Double(count) * 2 * .pi + noise * 0.5
        let radius: Double = 30 + 14 * abs(sin(Double(index) * 7.31)) + 10 * u
        let size: CGFloat = index % 3 == 0 ? 20 : 13
        return AchievementSparkShape()
            .fill(index % 2 == 0 ? Color.white : Color(hex: 0xFFD66B))
            .frame(width: size, height: size)
            .scaleEffect(CGFloat(sin(u * .pi)))
            .rotationEffect(.degrees(u * 90))
            .offset(x: CGFloat(cos(angle) * radius), y: CGFloat(sin(angle) * radius))
            .opacity(u > 0 && u < 1 ? 1 : 0)
    }
}
