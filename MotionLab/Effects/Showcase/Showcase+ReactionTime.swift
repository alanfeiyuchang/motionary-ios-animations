import SwiftUI

extension Effect {
    static let showcaseReactionTime = Effect(
        id: "showcase.reaction-time",
        category: .showcase,
        interaction: .tap,
        name: L("Reaction Time Tile", "反应速度测试卡片"),
        summary: L(
            "Wait, the pad flashes TAP, hit it: your milliseconds slam in and a marker slides along the rank bar against your best.",
            "静候，面板闪出“点！”，立刻拍下：毫秒数砸进画面，标记沿排名条滑到你与最佳成绩的位置。"
        ),
        prompt: L(
            "A dark reaction-game tile: a 244 × 112 pt pad, a rank bar and three small stats (best, average, tries). Tapping arms it: the pad turns deep red with \"Wait…\" and three dots pulsing in sequence for a random 1–3 s. Then it snaps to solid lime with a 6% brightness pop and \"TAP!\" punches in from 60% scale on a bouncy spring. The tap is timed against that instant; the result slams in from 2.4× scale and 14 pt blur to sharp on a spring (response 0.35 s, damping 0.5) as the pad returns to dark. Below, a white knob slides along a lime-to-coral track (150–450 ms) on a softer spring 0.15 s later, a lime tick marks the best run, and the stats roll. A new record turns the number lime with a success haptic; tapping too early shakes the pad coral. Playful, punchy.",
            "深色反应力游戏卡片：244 × 112pt 面板、排名条和三项数据（最佳、平均、次数）。点击开始：面板变深红，显示“等待…”，三点依次脉动，随机 1–3 秒。随后瞬间变纯青柠色，亮度一闪 6%，“点！”以弹性弹簧从 60% 砸入。此刻起计时；成绩从 2.4 倍、14pt 模糊以弹簧（响应 0.35 秒、阻尼 0.5）砸到清晰。白色圆钮延迟 0.15 秒，以更柔的弹簧沿青柠到珊瑚色轨道（150–450 毫秒）滑到位，青柠小标记标出最佳，数据滚动。破纪录时数字变青柠并有成功触感；抢跑则面板变珊瑚色并摇晃。带劲。"
        ),
        implementation: L(
            "A small state machine (idle, waiting, go, result, early) lives in @State; a Task sleeps the random delay, stores the flash Date and the tap handler measures against it. Each state is a view in a ZStack with its own transition: the result uses a custom scale + blur modifier transition driven by the spring, the flash and shake are keyframeAnimators, and the rank knob is an offset animated by a delayed spring.",
            "一个小状态机（空闲、等待、出击、成绩、抢跑）保存在 @State 中；Task 休眠随机时长后记录闪现时刻的 Date，点击处理函数据此计时。每个状态是 ZStack 里带各自过渡的视图：成绩使用由弹簧驱动的“缩放 + 模糊”自定义 modifier 过渡，闪光与摇晃由 keyframeAnimator 完成，排名圆钮则是延迟弹簧驱动的 offset。"
        ),
        apis: ["Task.sleep", "AnyTransition.modifier(active:identity:)", "keyframeAnimator", "phaseAnimator", "contentTransition(.numericText)", "spring(response:dampingFraction:)"],
        tags: ["reaction", "game", "reflex", "timer", "score", "反应", "游戏", "测试", "毫秒", "成绩"],
        params: [
            .slider("maxWait", L("Longest wait", "最长等待"), 1.5...5, default: 3.0, decimals: 1, unit: "s"),
            .slider("damping", L("Slam damping", "砸入阻尼"), 0.3...1.0, default: 0.5),
            .slider("slam", L("Slam scale", "砸入倍数"), 1.5...3.5, default: 2.4, decimals: 1, unit: "×"),
        ]
    ) { ctx in
        ReactionTimeDemo(ctx: ctx)
    }
}

private enum ReactionPhase: Equatable {
    case idle
    case waiting
    case go
    case result(Int)
    case early
}

private struct ReactionTimeDemo: View {
    let ctx: DemoContext
    @State private var phase: ReactionPhase
    @State private var best: Int = 213
    @State private var total: Int = 738
    @State private var tries: Int = 3
    @State private var marker: Double
    @State private var isRecord = false
    @State private var goDate = Date()
    @State private var flashes = 0
    @State private var shakes = 0
    @State private var round = 0
    @State private var pending: Task<Void, Never>?

    private let pad = CGSize(width: 244, height: 112)
    private static let coral = Color(hex: 0xFF6B5E)

    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? .result(231) : .idle)
        _marker = State(initialValue: Self.position(ctx.isStill ? 231 : 252))
    }

    private var zh: Bool { ctx.language == .zh }
    private var average: Int { tries > 0 ? total / tries : 0 }

    /// 150 ms (left) … 450 ms (right).
    private static func position(_ ms: Int) -> Double {
        (Double(ms - 150) / 300).clamped(to: 0...1)
    }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card
                    .sportCardTap { tap(user: true) }
                Spacer(minLength: 0)
                DemoHint(text: L("Tap to arm, then tap the instant it turns green", "点击开始，变绿的瞬间立刻再点"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear { pending?.cancel() }
        // The detail page waits for the player; only previews play themselves.
        .autoplay(ctx.isPreview, every: 3.8, delay: 0.6, intro: false) {
            switch phase {
            case .idle, .result, .early: tap(user: false)
            case .waiting, .go: break
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            SportEyebrowRow(
                title: zh ? "反应速度" : "Reaction time",
                symbol: "bolt.fill",
                trailing: zh ? "第 \(tries + 1) 次" : "Try \(tries + 1)"
            )
            padView
            rank
            stats
        }
        .padding(16)
        .frame(width: pad.width + 32)
        .signatureCard()
    }

    // MARK: Pad

    private var padColor: Color {
        switch phase {
        case .idle, .result: return Color.white.opacity(0.06)
        case .waiting: return Color(hex: 0x3A1512)
        case .go: return Signature.lime
        case .early: return Self.coral.opacity(0.35)
        }
    }

    private var padView: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return ZStack {
            // Colour never rides the bouncy springs (they would overshoot into odd hues); the cue is near-instant.
            shape.fill(padColor)
                .animation(.easeOut(duration: phase == .go ? 0.05 : 0.22), value: phase)
            shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            padContent
        }
        .frame(width: pad.width, height: pad.height)
        .clipShape(shape)
        .shadow(color: Signature.lime.opacity(phase == .go ? 0.55 : 0), radius: 22)
        .keyframeAnimator(initialValue: 0.0, trigger: flashes) { content, flash in
            content
                .brightness(flash * 0.06)
                .scaleEffect(1 + flash * 0.035)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(1.0, duration: 0.05)
                SpringKeyframe(0.0, duration: 0.4, spring: .init(response: 0.28, dampingRatio: 0.55))
            }
        }
        .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(-11, duration: 0.07)
                CubicKeyframe(9, duration: 0.09)
                CubicKeyframe(-6, duration: 0.09)
                CubicKeyframe(3, duration: 0.09)
                CubicKeyframe(0, duration: 0.1)
            }
        }
    }

    @ViewBuilder
    private var padContent: some View {
        switch phase {
        case .idle:
            VStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Signature.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: !ctx.isStill)
                Text(verbatim: zh ? "点击开始" : "Tap to start")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            .transition(.opacity)
        case .waiting:
            VStack(spacing: 12) {
                Text(verbatim: zh ? "等待…" : "Wait…")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.9))
                ReactionDots()
            }
            .transition(.opacity)
        case .go:
            Text(verbatim: zh ? "点！" : "TAP!")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(Signature.ink)
                .fixedSize()
                .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
        case .result(let ms):
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(verbatim: "\(ms)")
                    .font(Signature.number(56))
                    .foregroundStyle(isRecord ? Signature.lime : Color.white)
                    .fixedSize()
                Text(verbatim: "ms")
                    .font(Signature.number(22))
                    .foregroundStyle(Signature.textSecondary)
            }
            .overlay(alignment: .top) {
                if isRecord {
                    Label {
                        Text(verbatim: zh ? "新纪录" : "New best")
                    } icon: {
                        Image(systemName: "crown.fill")
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Signature.lime)
                    .offset(y: -10)
                }
            }
            .id(round)
            .transition(
                .asymmetric(
                    insertion: .modifier(
                        active: ReactionSlam(scale: ctx.cg("slam"), blur: 14, opacity: 0),
                        identity: ReactionSlam(scale: 1, blur: 0, opacity: 1)
                    ),
                    removal: .opacity
                )
            )
        case .early:
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .semibold))
                Text(verbatim: zh ? "太早了" : "Too soon")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Self.coral)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    // MARK: Rank + stats

    private var rank: some View {
        let width = pad.width
        let percent = { () -> Int in
            if case .result(let ms) = phase { return ((430 - ms) * 10 / 26).clamped(to: 1...99) }
            return 0
        }()
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(verbatim: zh ? "排名" : "Rank")
                Spacer(minLength: 0)
                Text(verbatim: percent > 0 ? (zh ? "超过 \(percent)% 的人" : "Faster than \(percent)%") : (zh ? "150 – 450 毫秒" : "150 – 450 ms"))
                    .contentTransition(.numericText())
                    .foregroundStyle(percent > 0 ? Color.white.opacity(0.9) : Signature.textSecondary)
            }
            .signatureEyebrow()
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [Signature.lime, Color(hex: 0xFFD24A), Self.coral], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width, height: 8)
                    .opacity(0.85)
                // Best run.
                Capsule()
                    .fill(Signature.lime)
                    .frame(width: 3, height: 18)
                    .shadow(color: Signature.lime.opacity(0.8), radius: 4)
                    .offset(x: (width - 3) * CGFloat(Self.position(best)))
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .overlay(Circle().fill(Signature.ink).frame(width: 6, height: 6))
                    .offset(x: (width - 18) * CGFloat(marker))
            }
            .frame(width: width, height: 18)
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(zh ? "最佳" : "Best", best, "ms")
            Spacer(minLength: 0)
            stat(zh ? "平均" : "Average", average, "ms")
            Spacer(minLength: 0)
            stat(zh ? "次数" : "Tries", tries, "")
        }
    }

    private func stat(_ label: String, _ value: Int, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: label)
                .signatureEyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value, format: .number)
                    .font(Signature.number(17))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText(value: Double(value)))
                Text(verbatim: unit)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
            }
        }
    }

    // MARK: Game

    private func tap(user: Bool) {
        switch phase {
        case .idle, .result, .early:
            if user { Haptics.tap(.light) }
            arm(user: user)
        case .waiting:
            pending?.cancel()
            shakes += 1
            if user { Haptics.error() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { phase = .early }
        case .go:
            pending?.cancel()
            let ms = Int((Date().timeIntervalSince(goDate) * 1000).rounded()).clamped(to: 1...999)
            record(ms, user: user)
        }
    }

    private func arm(user: Bool) {
        pending?.cancel()
        round += 1
        withAnimation(.smooth(duration: 0.25)) {
            phase = .waiting
            isRecord = false
        }
        let seed = sportHash(Double(round) * 3.17 + Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 7))
        let wait = ctx.isPreview ? 1.0 + seed * 0.5 : 1.0 + seed * max(ctx["maxWait"] - 1, 0.2)
        pending = Task { @MainActor in
            guard await studioPause(wait), phase == .waiting else { return }
            goDate = Date()
            flashes += 1
            // The cue itself must be instant; only the label gets a spring.
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { phase = .go }
            if user {
                // Nobody tapped: stand down after a while.
                guard await studioPause(2.5), phase == .go else { return }
                withAnimation(.smooth(duration: 0.3)) { phase = .idle }
            } else {
                // Previews answer for the player with a plausible reflex.
                guard await studioPause(0.19 + sportHash(Double(round) * 1.7) * 0.13), phase == .go else { return }
                tap(user: false)
            }
        }
    }

    private func record(_ ms: Int, user: Bool) {
        let record = ms < best
        if user {
            if record { Haptics.success() } else { Haptics.tap(.heavy) }
        }
        withAnimation(.spring(response: 0.35, dampingFraction: ctx["damping"])) {
            isRecord = record
            phase = .result(ms)
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.68).delay(0.15)) {
            marker = Self.position(ms)
        }
        withAnimation(.snappy(duration: 0.35).delay(0.15)) {
            tries += 1
            total += ms
            if record { best = ms }
        }
    }
}

/// Scale + blur + fade used as the "slam" insertion.
private struct ReactionSlam: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .blur(radius: max(blur, 0))
            .opacity(opacity)
    }
}

private struct ReactionDots: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .phaseAnimator([0, 1, 2]) { content, phase in
                        content
                            .opacity(phase == index ? 1 : 0.25)
                            .scaleEffect(phase == index ? 1.25 : 1)
                    } animation: { _ in
                        .easeInOut(duration: 0.28)
                    }
            }
        }
    }
}
