import SwiftUI

private struct SuccessCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.maxY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.03, y: rect.minY + rect.height * 0.06))
        return path
    }
}

// MARK: - Spark burst

extension Effect {
    static let feedbackSparkBurst = Effect(
        id: "feedback.spark-burst",
        category: .feedback,
        interaction: .tap,
        name: L("Spark Burst Check", "火花迸发对勾"),
        summary: L("The Pay pill itself curls into a green disc and fountains gravity-bound sparks.", "“支付”胶囊自身蜷缩成绿色圆盘，并喷出受重力下落的火花。"),
        prompt: L(
            "A 200 × 50 pt 'Pay' pill sits under a '$24.00 to Mia' card. On tap the pill itself becomes the success mark: it contracts to a 50 pt spinning circle for 0.7 s, then turns green and swells to an 88 pt disc on a bouncy spring (response 0.45 s, damping 0.5) while gliding up into the card's place as the card shrinks away. Sixteen green, mint and amber sparks fountain from its rim in an upward fan, arc under gravity and fall back, shrinking and fading over 0.9 s. 200 ms later a 6 pt white check writes itself on a 0.3 s ease-out with a success haptic. One continuous object from button to badge; lively, not noisy.",
            "“向 Mia 支付 ¥168.00”卡片下方是一枚 200 × 50 pt 的“支付”胶囊。点击后，胶囊本身化作成功标记：先收缩成 50 pt 的旋转圆，0.7 秒后转绿，以弹跳弹簧（响应 0.45 秒、阻尼 0.5）膨胀为 88 pt 圆盘，同时上移接替缩小退场的卡片。十六颗绿、薄荷、琥珀色火花从圆盘边缘呈扇形向上喷出，在重力下划出抛物线回落，0.9 秒内边落边缩小淡出。200 毫秒后，6 pt 白色对勾以 0.3 秒缓出写出，伴随成功触感。从按钮到徽章始终是同一个物体，热闹而不吵。"
        ),
        implementation: L(
            "One Capsule's frame animates 200 × 50 → 50 × 50 → 88 × 88 and its offset lifts it into the card's slot, so the button morphs rather than being replaced; a TimelineView clock measures the time since the burst and places each particle with projectile motion (v·t + ½·g·t²).",
            "同一个 Capsule 的尺寸按 200 × 50 → 50 × 50 → 88 × 88 动画，并通过 offset 上移到卡片位置，因此按钮是在形变而非被替换；TimelineView 时钟计算迸发后经过的时间，粒子按抛体公式（v·t + ½·g·t²）定位。"
        ),
        apis: ["TimelineView(.animation(minimumInterval:paused:))", "Capsule", "trim(from:to:)", "spring(response:dampingFraction:)"],
        tags: ["success", "sparks", "burst", "payment", "morph", "成功", "火花", "支付"],
        params: [
            .slider("damping", L("Pop damping", "弹出阻尼"), 0.3...1.0, default: 0.5),
            .slider("reach", L("Spark power", "火花力度"), 10...60, default: 30, decimals: 0, unit: "pt"),
            .slider("count", L("Sparks", "火花数"), 10...24, default: 16, step: 2, decimals: 0),
        ]
    ) { ctx in
        SparkBurstDemo(ctx: ctx)
    }
}

private enum SparkPhase: Equatable {
    case idle
    case paying
    case paid
}

private struct SparkBurstDemo: View {
    let ctx: DemoContext
    @State private var phase: SparkPhase = .idle
    /// When the sparks were launched; `nil` while none are in the air (the fountain's clock is paused then).
    @State private var burstStart: Date?
    @State private var token = 0

    var body: some View {
        let zh = ctx.language == .zh
        let paid = phase == .paid
        VStack(spacing: 14) {
            ZStack {
                amountCard(zh: zh)
                    .scaleEffect(paid ? 0.6 : 1)
                    .opacity(paid ? 0 : 1)
                    .offset(y: -56)
                    .animation(.smooth(duration: 0.35), value: paid)
                morphButton(zh: zh)
                    .offset(y: paid ? -40 : 88)
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: paid)
            }
            .frame(width: 260, height: 260)
            Text(zh ? "付款成功" : "Payment sent")
                .font(.headline)
                .opacity(paid ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(paid ? 0.3 : 0), value: paid)
            DemoHint(text: L("Tap Pay", "点击支付"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.2, delay: 0.5) { pay() }
    }

    private func amountCard(zh: Bool) -> some View {
        VStack(spacing: 6) {
            Text(zh ? "向 Mia 支付" : "Pay Mia")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(zh ? "¥168.00" : "$24.00")
                .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
        }
        .frame(width: 220, height: 120)
        .demoCard()
    }

    private func morphButton(zh: Bool) -> some View {
        Button(action: pay) {
            ZStack {
                SparkFountain(count: max(ctx.int("count"), 6), power: ctx.cg("reach"), start: burstStart, preview: ctx.isPreview)
                SparkMorphShape(phase: phase)
                buttonContent(zh: zh)
                SuccessCheckShape()
                    .trim(from: 0, to: phase == .paid ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .frame(width: 36, height: 28)
                    .animation(phase == .paid ? Animation.easeOut(duration: 0.3).delay(0.2) : Animation.easeIn(duration: 0.1), value: phase)
            }
            .frame(width: 200, height: 88)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func buttonContent(zh: Bool) -> some View {
        switch phase {
        case .idle:
            Text(zh ? "支付" : "Pay")
                .font(.headline)
                .foregroundStyle(.white)
                .transition(.opacity)
        case .paying:
            ProgressView()
                .tint(.white)
                .transition(.opacity)
        case .paid:
            EmptyView()
        }
    }

    private func pay() {
        switch phase {
        case .paying:
            return
        case .paid:
            token += 1
            withAnimation(.smooth(duration: 0.35)) { phase = .idle }
            return
        case .idle:
            break
        }
        token += 1
        let current = token
        let live = !ctx.isPreview
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = live && !Haptics.isMuted
        if buzz { Haptics.tap(.medium) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .paying }
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            guard token == current else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: ctx["damping"])) { phase = .paid }
            let launched = Date()
            burstStart = launched
            try? await Task.sleep(for: .seconds(0.2))
            guard token == current else { return }
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(SparkFountain.life))
            // Park the fountain's clock once this burst has faded (a newer burst keeps its own start).
            if burstStart == launched { burstStart = nil }
            guard token == current, !live else { return }
            try? await Task.sleep(for: .seconds(2.4 - SparkFountain.life))
            guard token == current else { return }
            withAnimation(.smooth(duration: 0.35)) { phase = .idle }
        }
    }
}

/// The single capsule that is the button, the spinner well and the success disc.
private struct SparkMorphShape: View {
    let phase: SparkPhase

    private var size: CGSize {
        switch phase {
        case .idle: return CGSize(width: 200, height: 50)
        case .paying: return CGSize(width: 50, height: 50)
        case .paid: return CGSize(width: 88, height: 88)
        }
    }

    var body: some View {
        let size: CGSize = self.size
        let paid = phase == .paid
        ZStack {
            Capsule().fill(Palette.primary)
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0x4BE08F), Palette.green], startPoint: .top, endPoint: .bottom))
                .opacity(paid ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: (paid ? Palette.green : Palette.indigo).opacity(0.35), radius: 14, y: 6)
    }
}

/// Particles launched in an upward fan from the disc's rim, then pulled down by gravity.
/// A `TimelineView` clock measures the time since `start`; a value pushed through the environment by a
/// `keyframeAnimator` never reached the particles, so the fountain rendered nothing.
private struct SparkFountain: View {
    let count: Int
    let power: CGFloat
    let start: Date?
    let preview: Bool

    /// Seconds a burst stays in the air.
    static let life: Double = 0.9

    private let colors: [Color] = [Palette.green, Palette.mint, Palette.amber]

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: start == nil)) { timeline in
            let elapsed: Double = start.map { timeline.date.timeIntervalSince($0) } ?? -1
            let t: Double = elapsed / Self.life
            let live: Bool = t > 0 && t < 1
            ZStack {
                if live {
                    ForEach(0..<count, id: \.self) { index in
                        particle(index, t: t)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func particle(_ index: Int, t: Double) -> some View {
        let fan: Double = count > 1 ? Double(index) / Double(count - 1) - 0.5 : 0
        let angle: Double = -Double.pi / 2 + fan * 2.3
        let jitter: Double = 0.72 + 0.28 * abs(sin(Double(index) * 12.9898))
        let speed: Double = (150 + Double(power) * 2) * jitter
        let x: Double = cos(angle) * (30 + speed * t)
        let y: Double = sin(angle) * (30 + speed * t) + 0.5 * 380 * t * t
        let size: CGFloat = (index % 2 == 0 ? 7 : 5) * CGFloat(1 - 0.6 * t)
        return RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(colors[index % colors.count])
            .frame(width: size, height: size)
            .rotationEffect(.degrees(t * 360 * (index % 2 == 0 ? 1 : -1)))
            .offset(x: x, y: y)
            .opacity(1 - t * t)
    }
}

// MARK: - Level up

extension Effect {
    static let feedbackLevelUp = Effect(
        id: "feedback.level-up",
        category: .feedback,
        interaction: .tap,
        name: L("Level-Up Flip", "升级翻牌"),
        summary: L("XP overflows the bar, the level badge flips to the next number and a gleam sweeps it.", "经验值溢出进度条，等级徽章翻面到下一个数字，一道高光扫过。"),
        prompt: L(
            "A lesson card holds a 56 pt gradient level badge, a 180 × 10 pt XP bar with a '70 / 100 XP' readout, and a 'Complete lesson' pill. Each tap earns 50 XP: a '+50 XP' label floats 40 pt up from the button and fades over 0.9 s while the bar fills on a 0.5 s ease-in-out. When it overflows, the full bar flashes white, the badge flips 180° around its vertical axis in 0.8-perspective 3D on a spring (response 0.6 s, damping 0.6) and its number switches exactly when it is edge-on, then a diagonal gleam sweeps across it in 0.5 s; the bar empties and refills to the 20 XP carried over, and a success haptic plays. Rewarding, game-like, crisp.",
            "课程卡片上是 56 pt 渐变等级徽章、180 × 10 pt 经验条（“70 / 100 XP”）和“完成课程”按钮。每点一次得 50 XP：“+50 XP”从按钮上浮 40 pt、0.9 秒内淡出，经验条以 0.5 秒缓入缓出增长。一旦溢出，满格闪白，徽章以 0.8 透视绕竖轴按弹簧（响应 0.6 秒、阻尼 0.6）翻转 180°，数字恰在侧对镜头时切换，随后斜向高光 0.5 秒扫过；经验条清空再涨到结转的 20 XP，伴随成功触感。奖励感十足，干脆利落。"
        ),
        implementation: L(
            "An Animatable badge interpolates a 'turns' value so rotation3DEffect and the displayed number stay in sync (the face is mirrored on odd turns); keyframeAnimators keyed on counters run the floating XP label and the gleam.",
            "Animatable 徽章插值“翻转圈数”，让 rotation3DEffect 与显示的数字保持同步（奇数次翻转时镜像内容）；以计数器为触发器的 keyframeAnimator 驱动上浮的经验标签与高光。"
        ),
        apis: ["Animatable", "rotation3DEffect(_:axis:perspective:)", "keyframeAnimator(initialValue:trigger:)", "contentTransition(.numericText)"],
        tags: ["level up", "xp", "gamification", "flip", "升级", "经验值", "游戏化", "翻牌"],
        params: [
            .slider("gain", L("XP per lesson", "每课经验"), 10...100, default: 50, step: 10, decimals: 0, unit: " XP"),
            .slider("response", L("Flip response", "翻转响应"), 0.3...1.0, default: 0.6, unit: "s"),
            .slider("damping", L("Flip damping", "翻转阻尼"), 0.3...1.0, default: 0.6),
        ]
    ) { ctx in
        LevelUpDemo(ctx: ctx)
    }
}

private struct FloatXP {
    var y: CGFloat = 0
    var opacity: Double = 0
}

private struct LevelUpDemo: View {
    let ctx: DemoContext
    @State private var xp: Double = 0.7
    @State private var turns: Double = 0
    @State private var gains = 0
    @State private var gleams = 0
    @State private var flash = false
    @State private var busy = false
    @State private var token = 0

    private let startLevel = 4

    var body: some View {
        let zh = ctx.language == .zh
        let gain: Int = max(ctx.int("gain"), 10)
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    LevelBadge(turns: turns, startLevel: startLevel, gleams: gleams)
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(zh ? "西班牙语 · 第 12 课" : "Spanish · Lesson 12")
                            .font(.subheadline.weight(.semibold))
                        xpBar
                        Text("\(Int((xp * 100).rounded())) / 100 XP")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText(value: xp))
                    }
                }
                Button(action: { complete(gain: gain) }) {
                    Text(zh ? "完成课程" : "Complete lesson")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Palette.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { floatingGain(gain) }
            }
            .frame(width: 262)
            .padding(18)
            .demoCard()
            DemoHint(text: L("Tap Complete lesson", "点击“完成课程”"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.5) { complete(gain: gain) }
    }

    private var xpBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.primary.opacity(0.08))
            Capsule()
                .fill(LinearGradient(colors: [Palette.amber, Palette.coral], startPoint: .leading, endPoint: .trailing))
                .frame(width: max(10, 180 * CGFloat(min(xp, 1))))
            Capsule()
                .fill(.white)
                .opacity(flash ? 0.8 : 0)
        }
        .frame(width: 180, height: 10)
    }

    private func floatingGain(_ gain: Int) -> some View {
        Text("+\(gain) XP")
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(Palette.coral)
            .allowsHitTesting(false)
            .keyframeAnimator(initialValue: FloatXP(), trigger: gains) { content, value in
                content
                    .offset(y: value.y)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    MoveKeyframe(0)
                    CubicKeyframe(-40, duration: 0.9)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.4)
                    CubicKeyframe(0, duration: 0.5)
                }
            }
    }

    private func complete(gain: Int) {
        guard !busy else { return }
        busy = true
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let step: Double = Double(gain) / 100
        let total: Double = xp + step
        let flipSpring = Animation.spring(response: ctx["response"], dampingFraction: ctx["damping"])
        gains += 1
        token += 1
        let current = token
        if buzz { Haptics.tap() }
        withAnimation(.easeInOut(duration: 0.5)) { xp = min(total, 1) }
        Task {
            try? await Task.sleep(for: .seconds(0.55))
            guard token == current else { return }
            guard total >= 1 else {
                busy = false
                return
            }
            withAnimation(.easeOut(duration: 0.12)) { flash = true }
            withAnimation(flipSpring) { turns += 1 }
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(0.2))
            guard token == current else { return }
            withAnimation(.easeIn(duration: 0.25)) { flash = false }
            // Snap empty without animation, let that frame render, then refill to the carried-over XP.
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) { xp = 0 }
            try? await Task.sleep(for: .milliseconds(20))
            guard token == current else { return }
            withAnimation(.easeOut(duration: 0.45)) { xp = total - 1 }
            try? await Task.sleep(for: .seconds(0.25))
            guard token == current else { return }
            gleams += 1
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            busy = false
        }
    }
}

/// The level badge. `turns` is animatable so the number flips exactly at 90°.
private struct LevelBadge: View, Animatable {
    var turns: Double
    let startLevel: Int
    let gleams: Int

    var animatableData: Double {
        get { turns }
        set { turns = newValue }
    }

    var body: some View {
        let passed: Int = Int((turns + 0.5).rounded(.down))
        let mirrored: Bool = passed % 2 == 1
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Palette.violet, Palette.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: 2)
            VStack(spacing: -2) {
                Text(verbatim: "LV")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .opacity(0.8)
                Text("\(startLevel + passed)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
            }
            .foregroundStyle(.white)
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            LevelGleam(trigger: gleams)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        }
        .rotation3DEffect(.degrees(turns * 180), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
        .shadow(color: Palette.violet.opacity(0.4), radius: 10, y: 5)
    }
}

private struct LevelGleam: View {
    let trigger: Int

    var body: some View {
        LinearGradient(
            colors: [.white.opacity(0), .white.opacity(0.7), .white.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 24, height: 90)
        .rotationEffect(.degrees(25))
        .keyframeAnimator(initialValue: CGFloat(-70), trigger: trigger) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                MoveKeyframe(-60)
                CubicKeyframe(60, duration: 0.5)
                MoveKeyframe(-70)
            }
        }
        .allowsHitTesting(false)
    }
}
