import SwiftUI

extension Effect {
    static let showcaseStepsRing = Effect(
        id: "showcase.steps-ring",
        category: .showcase,
        interaction: .tap,
        name: L("Daily Steps Ring", "每日步数环"),
        summary: L(
            "A steps ring that closes with a count-up; crossing the goal flashes the ring, throws sparkles and lets the arc lap itself.",
            "随步数递增而合拢的圆环；越过目标时圆环闪亮、星屑飞散，弧线继续叠上第二圈。"
        ),
        prompt: L(
            "A dark steps widget: a 164 pt ring (16 pt stroke, orange angular gradient, rounded cap carrying a small drop shadow) around a walking glyph, a large step count and the percentage; distance, calories and active minutes sit below. Each tap adds a walk: the arc sweeps forward on a spring (response 0.9 s, damping 0.85) while the count, kilometres and calories count up in step with it, every frame. When the arc crosses 100% the whole ring pops to 107% and settles on a bouncy spring, flashes 35% brighter, a lime ring expands to 1.45× while fading over 0.7 s, 18 four-point sparkles fly out and sag, and the percentage swaps to a lime Goal reached chip with a success haptic. Past the goal the arc keeps going and overlaps itself, its shadowed head showing the second lap. Rewarding, like closing a fitness ring.",
            "深色步数组件：164pt 圆环（描边 16pt，橙色角向渐变，圆头末端带投影）围着步行图标、大号步数与进度，下方是距离、热量与时长。每点一次加一段步行：弧线以弹簧（响应 0.9 秒、阻尼 0.85）向前扫，步数与各项数据逐帧递增。弧线越过 100% 时，圆环弹到 107% 再落定，亮度闪高 35%，一圈青柠色光环在 0.7 秒内扩到 1.45 倍并淡出，18 颗四角星屑飞散下坠，进度换成青柠色“目标达成”并触发成功触感。超过目标后弧线继续前进、叠在自己上面，末端投影显出第二圈。有合上健身圆环的成就感。"
        ),
        implementation: L(
            "The whole face is an Animatable view whose animatableData is the step count, so the trim, the rotating head, the number and the derived stats are all recomputed on every frame of one spring. Crossing the goal bumps a trigger for keyframeAnimator (pop, flash, expanding ring) and stamps a date for a TimelineView + Canvas sparkle burst.",
            "整个表面是一个 Animatable 视图，animatableData 就是步数，于是 trim、旋转的末端、数字和派生数据都在同一条弹簧的每一帧重新计算。越过目标时递增 keyframeAnimator 的触发值（弹跳、闪亮、扩散光环），并记录时间戳，供 TimelineView 加 Canvas 绘制星屑迸发。"
        ),
        apis: ["Animatable", "Circle().trim", "AngularGradient", "keyframeAnimator", "TimelineView(.animation)", "Canvas"],
        tags: ["steps", "ring", "goal", "fitness", "count up", "步数", "圆环", "目标", "健身", "递增计数"],
        params: [
            .slider("goal", L("Goal", "目标步数"), 6000...12000, default: 8000, step: 1000, decimals: 0),
            .slider("chunk", L("Steps per tap", "每次增加"), 1000...4000, default: 2400, step: 200, decimals: 0),
            .slider("response", L("Sweep response", "扫动响应"), 0.4...1.4, default: 0.9, unit: "s"),
            .slider("sparkles", L("Sparkles", "星屑数量"), 0...30, default: 18, step: 1, decimals: 0),
        ]
    ) { ctx in
        StepsRingDemo(ctx: ctx)
    }
}

private struct StepsRingDemo: View {
    let ctx: DemoContext
    @State private var steps: Double
    @State private var celebrations = 0
    @State private var reached = false
    @State private var burst: Date?
    @State private var pending: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _steps = State(initialValue: ctx.isStill ? 6240 : 1200)
    }

    private var zh: Bool { ctx.language == .zh }
    private var goal: Double { max(ctx["goal"], 1000) }

    var body: some View {
        StudioScene(hint: L("Tap to add a walk", "点击，加一段步行"), ctx: ctx) {
            card
                .sportCardTap { addWalk(user: true) }
        }
        .onDisappear { pending?.cancel() }
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.7) { addWalk(user: false) }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            SportEyebrowRow(title: zh ? "今日步数" : "Steps today", symbol: "figure.walk", trailing: zh ? "目标 \(Int(goal).formatted())" : "Goal \(Int(goal).formatted())")
            StepsFace(steps: steps, goal: goal, reached: reached, zh: zh)
                .keyframeAnimator(initialValue: StepsPop(), trigger: celebrations) { content, pop in
                    content
                        .scaleEffect(pop.scale)
                        .brightness(pop.flash)
                        .background {
                            Circle()
                                .stroke(Signature.lime, lineWidth: 3)
                                .frame(width: 164, height: 164)
                                .scaleEffect(1 + 0.45 * pop.ring)
                                .opacity(pop.ring > 0 && pop.ring < 1 ? 1 - pop.ring : 0)
                                .offset(y: stepsRingOffset)
                        }
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.07, duration: 0.14)
                        SpringKeyframe(1.0, duration: 0.6, spring: .init(response: 0.35, dampingRatio: 0.45))
                    }
                    KeyframeTrack(\.flash) {
                        LinearKeyframe(0.35, duration: 0.1)
                        CubicKeyframe(0, duration: 0.5)
                    }
                    KeyframeTrack(\.ring) {
                        MoveKeyframe(0)
                        CubicKeyframe(0.75, duration: 0.35)
                        CubicKeyframe(1, duration: 0.35)
                    }
                }
                .overlay {
                    StudioBurst(start: burst, count: ctx.int("sparkles"), reach: 120, preview: ctx.isPreview)
                        .frame(width: 300, height: 300)
                        .offset(y: stepsRingOffset)
                }
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 270)
        .signatureCard()
    }

    private func addWalk(user: Bool) {
        pending?.cancel()
        if steps >= goal * 1.15 {
            // A new day: the ring unwinds.
            if user { Haptics.tap(.light) }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) {
                steps = 1200
                reached = false
            }
            return
        }
        if user { Haptics.tap(.light) }
        let before = steps
        let after = steps + ctx["chunk"]
        let response = ctx["response"]
        withAnimation(.spring(response: response, dampingFraction: 0.85)) { steps = after }
        guard before < goal, after >= goal else { return }
        // Fire when the arc actually reaches the top, part-way through the spring.
        let share = (goal - before) / max(after - before, 1)
        pending = Task { @MainActor in
            guard await studioPause(response * (0.2 + 0.4 * share)) else { return }
            celebrations += 1
            burst = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { reached = true }
            if user && !ctx.isPreview { Haptics.success() }
        }
    }
}

/// Ring centre relative to the face's centre (the stats row sits below the ring).
private let stepsRingOffset: CGFloat = -15

private struct StepsPop {
    var scale: Double = 1
    var flash: Double = 0
    var ring: Double = 0
}

private struct StepsFace: View, Animatable {
    var steps: Double
    let goal: Double
    let reached: Bool
    let zh: Bool

    var animatableData: Double {
        get { steps }
        set { steps = newValue }
    }

    private let diameter: CGFloat = 148

    var body: some View {
        let progress = max(steps / goal, 0)
        let lap = max(progress - 1, 0)
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 16)
                    .frame(width: diameter, height: diameter)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0.0001), 1))
                    .stroke(
                        AngularGradient(
                            colors: [Signature.accentHot, Signature.accent, Signature.accentSoft],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * min(max(progress, 0.08), 1))
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: diameter, height: diameter)
                    .rotationEffect(.degrees(-90 + lap * 360))
                    .shadow(color: Signature.accent.opacity(0.45), radius: 9)
                // The head: a cap with its own shadow, so the arc reads as lying on top of itself past 100%.
                Circle()
                    .fill(Signature.accentSoft)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(progress > 0.9 ? 0.55 : 0), radius: 3, x: 3)
                    .offset(y: -diameter / 2)
                    .rotationEffect(.degrees(progress * 360))
                    .opacity(progress > 0.02 ? 1 : 0)
                VStack(spacing: 0) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(reached ? Signature.lime : Signature.accent)
                    Text(verbatim: Int(steps.rounded()).formatted())
                        .font(Signature.number(34))
                        .foregroundStyle(Color.white)
                    ZStack {
                        if reached {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                Text(verbatim: zh ? "目标达成" : "Goal reached")
                            }
                            .foregroundStyle(Signature.lime)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        } else {
                            Text(verbatim: "\(Int((progress * 100).rounded()))%")
                                .foregroundStyle(Signature.textSecondary)
                                .transition(.opacity)
                        }
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(height: 16)
                }
            }
            .frame(width: 164, height: 164)
            HStack(spacing: 0) {
                stat(String(format: "%.1f", steps * 0.00072), zh ? "公里" : "km", "location.fill")
                stat("\(Int(steps * 0.042))", zh ? "千卡" : "kcal", "flame.fill")
                stat("\(Int(steps / 110))", zh ? "分钟" : "min", "clock.fill")
            }
            .frame(height: 18)
        }
    }

    private func stat(_ value: String, _ unit: String, _ symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Signature.accent)
            Text(verbatim: value)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white)
            Text(verbatim: unit)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Signature.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
