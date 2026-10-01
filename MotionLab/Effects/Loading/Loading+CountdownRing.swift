import SwiftUI

extension Effect {
    static let loadingCountdownRing = Effect(
        id: "loading.countdown-ring",
        category: .loading,
        interaction: .state,
        name: L("Countdown Ring", "倒计时圆环"),
        summary: L("3 · 2 · 1: each number punches in while the ring unwinds one turn, then GO bursts.", "3、2、1：每个数字砸入画面，圆环随之走完一圈，最后“GO”迸发。"),
        prompt: L(
            "A 170 pt ring with a 10 pt round-capped stroke counts down 3 · 2 · 1. On each 0.9 s beat the arc snaps back to full in 0.16 s, then unwinds clockwise at constant speed with a glowing dot on its moving end. The numeral punches in at the same instant: from 1.9× scale and a 14 pt blur to sharp on a spring (response 0.34 s, damping 0.62), while the previous one shrinks to 0.6× and blurs away in 0.18 s; the ring kicks to 106% and a hairline shock ring expands and fades. Colours step sky → violet → pink. After 1, the ring closes green, 'GO' slams in and 14 rays shoot outward 40 pt over 0.6 s. Rigid ticks, then a success haptic. Punchy, rhythmic, energising.",
            "一枚 170 pt、10 pt 圆头描边的圆环倒数 3、2、1。每拍 0.9 秒：圆弧先在 0.16 秒内弹回满圈，再匀速顺时针走完，移动端带一颗发光圆点。数字同时砸入：从 1.9 倍、14 pt 模糊以弹簧（响应 0.34 秒、阻尼 0.62）落定，上一个数字在 0.18 秒内缩到 0.6 倍并模糊消失；圆环顶到 106%，一道细线冲击环向外扩散淡去。颜色依次为天蓝 → 紫罗兰 → 粉。数完 1，圆环以绿色闭合，“GO”猛然砸入，14 道光芒在 0.6 秒内向外射出 40 pt。每拍一次硬朗触感，最后是成功触感。有冲击力、有节奏。"
        ),
        implementation: L(
            "An async task steps the count; the numeral is re-identified per step and swapped with a scale + blur modifier transition, the arc is a trimmed circle animated linearly per beat, and the rays are an animatable Shape.",
            "异步任务逐拍推进计数；数字每拍更换 id，用缩放加模糊的 modifier 转场切换，圆弧是按拍线性动画的 trim 圆，光芒由一个可动画的 Shape 绘制。"
        ),
        apis: ["AnyTransition.modifier(active:identity:)", "trim(from:to:)", "Shape.animatableData", "keyframeAnimator", "task(id:)"],
        tags: ["countdown", "timer", "3 2 1", "go", "倒计时", "倒数", "开始", "计时"],
        params: [
            .slider("beat", L("Beat", "每拍时长"), 0.5...1.5, default: 0.9, decimals: 1, unit: "s"),
            .slider("from", L("Count from", "起始数字"), 3...5, default: 3, step: 1, decimals: 0),
            .slider("punch", L("Punch scale", "砸入倍数"), 1.2...2.6, default: 1.9, decimals: 1, unit: "×"),
        ]
    ) { ctx in
        CountdownRingDemo(ctx: ctx)
    }
}

private struct CountdownPunch: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

/// Short rays that fly outward and thin out as `progress` goes 0 → 1.
private struct CountdownRays: Shape {
    var progress: Double
    let count: Int
    let inner: CGFloat
    let travel: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let eased: CGFloat = CGFloat(1 - pow(1 - progress, 3))
        let length: CGFloat = 16 * CGFloat(1 - progress) + 2
        for index in 0..<count {
            let angle: Double = 2 * .pi * Double(index) / Double(count)
            let near: CGFloat = inner + travel * eased
            let far: CGFloat = near + length * (index % 2 == 0 ? 1 : 0.6)
            path.move(to: CGPoint(x: center.x + near * CGFloat(cos(angle)), y: center.y + near * CGFloat(sin(angle))))
            path.addLine(to: CGPoint(x: center.x + far * CGFloat(cos(angle)), y: center.y + far * CGFloat(sin(angle))))
        }
        return path
    }
}

private struct CountdownRingDemo: View {
    let ctx: DemoContext
    /// The number on screen; 0 means GO and -1 nothing yet.
    @State private var count: Int
    /// How much of the turn has unwound (0 = full ring).
    @State private var sweep: Double
    @State private var kicks = 0
    @State private var shock = false
    @State private var burst = false
    @State private var run = 0

    private let diameter: CGFloat = 170

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills never run `task`: show "2" with the ring part-way round.
        _count = State(initialValue: ctx.isStill ? 2 : -1)
        _sweep = State(initialValue: ctx.isStill ? 0.38 : 0)
    }

    private func color(for number: Int) -> Color {
        switch number {
        case 0: return Palette.green
        case 1: return Palette.pink
        case 2: return Palette.violet
        case 3: return Palette.sky
        case 4: return Palette.mint
        default: return Palette.amber
        }
    }

    var body: some View {
        let zh = ctx.language == .zh
        let tint: Color = color(for: count < 0 ? max(ctx.int("from"), 1) : count)
        VStack(spacing: 14) {
            ZStack {
                CountdownRays(progress: burst ? 1 : 0, count: 14, inner: diameter / 2 + 10, travel: 40)
                    .stroke(Palette.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .opacity(burst ? 0 : (count == 0 ? 1 : 0))
                Circle()
                    .stroke(tint, lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(shock ? 1.28 : 1)
                    .opacity(shock ? 0 : 0.55)
                ring(tint: tint)
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: kicks) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.self) {
                            CubicKeyframe(count == 0 ? 1.12 : 1.06, duration: 0.09)
                            SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                        }
                    }
                numeral(tint: tint)
            }
            .frame(width: 270, height: 232)
            Text(count == 0 ? (zh ? "训练已开始" : "Workout started") : (zh ? "训练即将开始" : "Workout starts in"))
                .font(.subheadline.weight(.semibold))
                .contentTransition(.interpolate)
            DemoHint(text: L("Tap to restart", "点击重新开始"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { run += 1 }
        .task(id: run) { await play() }
        .onChange(of: ctx.int("from")) { run += 1 }
    }

    private func ring(tint: Color) -> some View {
        let end: Double = min(max(sweep, 0), 1)
        return ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: end, to: 1)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.5), radius: 8)
            // The glowing dot riding the moving end.
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
                .shadow(color: tint, radius: 6)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(360 * end))
                .opacity(count == 0 || end > 0.985 ? 0 : 1)
        }
        .frame(width: diameter, height: diameter)
    }

    private func numeral(tint: Color) -> some View {
        let punch: CGFloat = ctx.cg("punch")
        let transition = AnyTransition.asymmetric(
            insertion: .modifier(
                active: CountdownPunch(scale: count == 0 ? punch * 1.15 : punch, blur: 14, opacity: 0),
                identity: CountdownPunch(scale: 1, blur: 0, opacity: 1)
            ),
            removal: .modifier(
                active: CountdownPunch(scale: 0.6, blur: 8, opacity: 0),
                identity: CountdownPunch(scale: 1, blur: 0, opacity: 1)
            ).animation(.easeIn(duration: 0.18))
        )
        return ZStack {
            Text(count == 0 ? "GO" : (count < 0 ? "" : "\(count)"))
                .font(.system(size: count == 0 ? 60 : 86, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.35), radius: 12, y: 4)
                .id(count)
                .transition(transition)
        }
        .frame(width: 150, height: 110)
    }

    private func play() async {
        // Only a run the user restarted buzzes; the automatic first run stays silent.
        let live: Bool = !ctx.isPreview && run > 0
        let first: Int = max(ctx.int("from"), 1)
        var instant = Transaction()
        instant.disablesAnimations = true
        // Clear the stage first, so the first numeral punches in like the others.
        withTransaction(instant) {
            burst = false
            count = -1
        }
        var number: Int = first
        while number >= 1 {
            if Task.isCancelled { return }
            let beat: Double = max(ctx["beat"], 0.3)
            withTransaction(instant) { shock = false }
            withAnimation(.easeOut(duration: 0.16)) { sweep = 0 }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) { count = number }
            withAnimation(.easeOut(duration: 0.5)) { shock = true }
            kicks += 1
            if live { Haptics.tap(.rigid) }
            try? await Task.sleep(for: .seconds(0.16))
            if Task.isCancelled { return }
            withAnimation(.linear(duration: beat - 0.16)) { sweep = 1 }
            try? await Task.sleep(for: .seconds(beat - 0.16))
            number -= 1
        }
        guard !Task.isCancelled else { return }
        withTransaction(instant) { shock = false }
        withAnimation(.easeOut(duration: 0.2)) { sweep = 0 }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { count = 0 }
        withAnimation(.easeOut(duration: 0.5)) { shock = true }
        withAnimation(.easeOut(duration: 0.6)) { burst = true }
        kicks += 1
        if live { Haptics.success() }
        guard ctx.isPreview else { return }
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        run += 1
    }
}
