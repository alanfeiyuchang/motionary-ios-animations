import SwiftUI

extension Effect {
    static let showcaseBreathFlower = Effect(
        id: "showcase.breath-flower",
        category: .showcase,
        interaction: .loop,
        name: L("Breathing Flower Guide", "呼吸引导之花"),
        summary: L(
            "Six translucent petals bloom and turn as you inhale and fold back as you exhale, with a cross-fading cue and a rolling count.",
            "六片半透明花瓣随吸气绽放旋转、随呼气收拢，提示语交叉淡化，秒数滚动倒数。"
        ),
        prompt: L(
            "A dark mindfulness widget built around a flower of six overlapping translucent circles (88 pt, lime-to-mint gradient at 50%, screen-blended so overlaps glow). Inhale takes 4 s: each petal travels outward from the centre to 46% of its diameter, grows from 42% to full size and the whole flower turns 120°, all on a sine ease-in-out, while a blurred mint halo swells behind it. Exhale takes 5 s and reverses the motion until the petals collapse into one small disc. Below, the cue word swaps between \"Inhale\" and \"Exhale\" with a 0.5 s blur-replace, the seconds left in the phase roll down, and one of five dots fills per completed breath. Tapping pauses and resumes exactly in place; once touched, a soft haptic ticks every half second of the inhale with a firmer one at the top. Slow, soft, hypnotic.",
            "深色正念小组件，核心是一朵由六个半透明圆叠成的花（直径 88pt，青柠到薄荷绿渐变、50% 不透明，滤色混合让重叠处发亮）。吸气 4 秒：每片花瓣由中心外移到自身直径的 46%，从 42% 长到原大，整朵花转过 120°，全程正弦缓入缓出，背后的薄荷色柔光随之鼓起。呼气 5 秒原路返回，直到收成一个小圆点。下方提示语在“吸气”“呼气”间以 0.5 秒模糊替换，剩余秒数向下滚动，每完成一次呼吸点亮五个圆点之一。点击可原地暂停与继续；触碰过后，吸气时每半秒一次柔和触感，到顶再重一下。缓慢、柔软。"
        ),
        implementation: L(
            "A pausable TimelineView turns accumulated time into a phase and an eased amount; every petal is a Circle whose offset, scale and the group's rotation are functions of that amount, composited with blendMode(.screen) inside a compositingGroup. The cue is an id-keyed Text with a blurReplace transition, the count uses numericText, and onChange of a half-second index fires the haptics.",
            "可暂停的 TimelineView 把累计时间换算为阶段与缓动量；每片花瓣是一个 Circle，其偏移、缩放与整组旋转都是该缓动量的函数，并在 compositingGroup 内以 blendMode(.screen) 合成。提示语是以 id 区分并带 blurReplace 过渡的 Text，秒数用 numericText，半秒序号的 onChange 触发触感。"
        ),
        apis: ["TimelineView(.animation(paused:))", "blendMode(.screen)", "compositingGroup", "transition(.blurReplace)", "contentTransition(.numericText)"],
        tags: ["breathing", "mindfulness", "meditation", "flower", "calm", "呼吸", "正念", "冥想", "花瓣", "放松"],
        params: [
            .slider("inhale", L("Inhale", "吸气时长"), 2...6, default: 4, decimals: 1, unit: "s"),
            .slider("exhale", L("Exhale", "呼气时长"), 2...8, default: 5, decimals: 1, unit: "s"),
            .slider("petals", L("Petals", "花瓣数"), 4...9, default: 6, step: 1, decimals: 0),
            .slider("spin", L("Rotation per breath", "每次呼吸旋转"), 0...180, default: 120, decimals: 0, unit: "°"),
        ]
    ) { ctx in
        BreathFlowerDemo(ctx: ctx)
    }
}

private struct BreathState: Equatable {
    var amount: Double
    var inhaling: Bool
    var secondsLeft: Int
    var breath: Int
    /// Half-second index inside the inhale (−1 while exhaling), for haptic pacing.
    var tick: Int
    /// 0…1 through the whole breath.
    var progress: Double = 0
}

private struct BreathFlowerDemo: View {
    let ctx: DemoContext
    @State private var running = true
    @State private var banked: Double = 0
    @State private var resumed = Date()
    /// Haptics pace the breath only after the user has touched the card.
    @State private var armed = false

    private var zh: Bool { ctx.language == .zh }
    private var inhale: Double { max(ctx["inhale"], 0.5) }
    private var exhale: Double { max(ctx["exhale"], 0.5) }

    private func state(at date: Date) -> BreathState {
        if ctx.isStill { return BreathState(amount: 1, inhaling: true, secondsLeft: 1, breath: 2, tick: -1, progress: 0.44) }
        let elapsed = banked + (running ? max(0, date.timeIntervalSince(resumed)) : 0)
        let cycle = inhale + exhale
        let u = elapsed.truncatingRemainder(dividingBy: cycle)
        let breath = Int(elapsed / cycle) % 5
        if u < inhale {
            let x = u / inhale
            return BreathState(amount: 0.5 - 0.5 * cos(.pi * x), inhaling: true, secondsLeft: Int((inhale - u).rounded(.up)), breath: breath, tick: Int(u / 0.5), progress: u / cycle)
        }
        let x = (u - inhale) / exhale
        return BreathState(amount: 0.5 + 0.5 * cos(.pi * x), inhaling: false, secondsLeft: Int((cycle - u).rounded(.up)), breath: breath, tick: -1, progress: u / cycle)
    }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !running || ctx.isStill)) { timeline in
                    card(state(at: timeline.date))
                }
                .sportCardTap { toggle() }
                Spacer(minLength: 0)
                DemoHint(text: L("Breathe with it · tap to pause", "跟着它呼吸 · 点击暂停"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func card(_ state: BreathState) -> some View {
        VStack(spacing: 6) {
            SportEyebrowRow(
                title: zh ? "正念 · 一分钟呼吸" : "Mindful · One minute",
                symbol: "leaf.fill",
                trailing: running ? nil : (zh ? "已暂停" : "Paused")
            )
            BreathFlower(amount: state.amount, petals: max(ctx.int("petals"), 3), spin: ctx["spin"])
                .frame(width: 248, height: 178)
            cue(state)
            dots(state)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 280)
        .signatureCard()
        .onChange(of: state.tick) { _, tick in
            guard armed, running, !ctx.isPreview, tick >= 0 else { return }
            Haptics.tap(.soft)
        }
        .onChange(of: state.inhaling) { _, inhaling in
            guard armed, running, !ctx.isPreview, !inhaling else { return }
            Haptics.tap(.medium)
        }
    }

    private func cue(_ state: BreathState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ZStack {
                Text(verbatim: state.inhaling ? (zh ? "吸气" : "Inhale") : (zh ? "呼气" : "Exhale"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .fixedSize()
                    .id(state.inhaling)
                    .transition(.blurReplace)
            }
            .animation(.easeInOut(duration: 0.5), value: state.inhaling)
            Text(state.secondsLeft, format: .number)
                .font(Signature.number(24))
                .foregroundStyle(BreathFlower.mint)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.3), value: state.secondsLeft)
        }
        .frame(height: 36)
    }

    private func dots(_ state: BreathState) -> some View {
        HStack(spacing: 7) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index < state.breath ? AnyShapeStyle(BreathFlower.mint) : AnyShapeStyle(Color.white.opacity(0.14)))
                    .frame(width: index == state.breath ? 18 : 6, height: 6)
                    .overlay(alignment: .leading) {
                        if index == state.breath {
                            Capsule()
                                .fill(BreathFlower.mint)
                                .frame(width: 6 + 12 * state.progress, height: 6)
                        }
                    }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: state.breath)
    }

    private func toggle() {
        armed = true
        Haptics.tap(.light)
        if running {
            banked += Date().timeIntervalSince(resumed)
        } else {
            resumed = Date()
        }
        withAnimation(.smooth(duration: 0.3)) { running.toggle() }
    }
}

private struct BreathFlower: View {
    let amount: Double
    let petals: Int
    let spin: Double

    static let mint = Color(hex: 0x4FE3B0)
    private let diameter: CGFloat = 88

    var body: some View {
        let p = CGFloat(amount)
        ZStack {
            Circle()
                .fill(Self.mint)
                .frame(width: 130, height: 130)
                .blur(radius: 34)
                .scaleEffect(0.5 + 0.75 * p)
                .opacity(0.16 + 0.3 * amount)
            Circle()
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: 172, height: 172)
            ZStack {
                ForEach(0..<petals, id: \.self) { index in
                    let angle = Double(index) / Double(petals) * 2 * .pi
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: 0xC8F560), Color(hex: 0x21D4A8)], startPoint: .top, endPoint: .bottom))
                        .frame(width: diameter, height: diameter)
                        .opacity(0.5)
                        .scaleEffect(0.42 + 0.58 * p)
                        .offset(x: CGFloat(cos(angle)) * diameter * 0.46 * p, y: CGFloat(sin(angle)) * diameter * 0.46 * p)
                        .blendMode(.screen)
                }
            }
            .rotationEffect(.degrees(spin * amount - 90))
            .compositingGroup()
            .shadow(color: Self.mint.opacity(0.35), radius: 14)
        }
    }
}
