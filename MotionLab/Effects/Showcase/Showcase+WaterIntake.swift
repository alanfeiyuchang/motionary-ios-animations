import SwiftUI

extension Effect {
    static let showcaseWaterIntake = Effect(
        id: "showcase.water-intake",
        category: .showcase,
        interaction: .tap,
        name: L("Water Glass Tracker", "喝水记录水杯"),
        summary: L(
            "A glass that fills a cup per tap: a drop falls, splashes, and the waving surface rises to the goal line.",
            "每点一次添一杯水：水滴落下、溅起水花，起伏的水面一路升向目标线。"
        ),
        prompt: L(
            "A dark hydration widget: a tapered glass tumbler on the left with a dashed goal line near the top, and on the right the millilitres drunk, the goal, a row of small drop icons and an add button. The water is a blue gradient whose surface is two sine waves drifting in opposite directions, with a few bubbles rising. Tapping adds a cup: a drop falls from above the rim, accelerating for 0.3 s; where it lands six droplets arc up and fall back under gravity, the wave amplitude jumps by 7 pt and decays over about a second, and the level rises on a sloshy spring (response 0.6 s, damping 0.6) as the number rolls up and the next drop icon pops in. When the surface crosses the goal line the water turns lime, the label becomes Goal reached and a success haptic fires. Refreshing and playful.",
            "深色饮水组件：左侧是一只上宽下窄的玻璃杯，靠近杯口有一条虚线目标线；右侧是已喝毫升数、目标、一排小水滴图标和添加按钮。水是蓝色渐变，水面由两道反向漂移的正弦波叠成，杯中有几颗气泡上升。点击添一杯：水滴从杯口上方落下，0.3 秒内不断加速；落点处六颗小水珠弧线溅起、受重力落回，波幅瞬间增加 7pt 并在约一秒内衰减，水位以晃荡的弹簧（响应 0.6 秒、阻尼 0.6）上升，数字随之滚动，下一枚水滴图标弹出。水面越过目标线时，水变为青柠色，文字换成“目标达成”，并触发成功触感。清爽而俏皮。"
        ),
        implementation: L(
            "The liquid is an animatable Shape: its level is the animatableData (driven by a spring) while a TimelineView feeds the wave phase and a splash amplitude that decays exponentially from the landing time. The drop is a keyframeAnimator on offset and stretch, and a Canvas draws the droplets as ballistic arcs plus the rising bubbles, all clipped to the tumbler shape.",
            "水体是一个可动画的 Shape：水位作为 animatableData 由弹簧驱动，TimelineView 提供波相位，以及从落水时刻起按指数衰减的水花振幅。水滴是作用在位移与拉伸上的 keyframeAnimator，Canvas 把小水珠画成抛物线并绘制上升的气泡，全部裁剪在杯形之内。"
        ),
        apis: ["Shape.animatableData", "TimelineView(.animation)", "Canvas", "keyframeAnimator", "contentTransition(.numericText)", "clipShape"],
        tags: ["water", "hydration", "glass", "liquid", "wave", "喝水", "饮水", "水杯", "液体", "波浪"],
        params: [
            .slider("cup", L("Cup size", "每杯容量"), 150...500, default: 250, step: 50, decimals: 0, unit: " ml"),
            .slider("wave", L("Wave height", "波浪高度"), 0...8, default: 3.5, decimals: 1, unit: "pt"),
            .slider("response", L("Rise response", "上升响应"), 0.3...1.2, default: 0.6, unit: "s"),
        ]
    ) { ctx in
        WaterIntakeDemo(ctx: ctx)
    }
}

private enum WaterGlassMetrics {
    static let size = CGSize(width: 112, height: 172)
    static let goal: Double = 2000
    static let capacity: Double = 2400
}

private struct WaterIntakeDemo: View {
    let ctx: DemoContext
    @State private var ml: Double
    @State private var drops = 0
    @State private var splash: Date?
    @State private var splashLevel: Double = 0
    @State private var pending: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _ml = State(initialValue: ctx.isStill ? 1250 : 500)
    }

    private var zh: Bool { ctx.language == .zh }
    private var cup: Double { max(ctx["cup"], 50) }
    private var level: Double { min(ml / WaterGlassMetrics.capacity, 1) }
    private var reached: Bool { ml >= WaterGlassMetrics.goal }

    var body: some View {
        StudioScene(hint: L("Tap the glass to add a cup", "点击水杯，添一杯水"), ctx: ctx) {
            card
        }
        .onDisappear { pending?.cancel() }
        .autoplay(ctx.isPreview, every: 1.35, delay: 0.7) { addCup(user: false) }
    }

    private var card: some View {
        HStack(alignment: .center, spacing: 18) {
            Button(action: { addCup(user: true) }) {
                glass
            }
            .buttonStyle(SportPressStyle(scale: 0.97, dim: 0.02))
            info
        }
        .padding(18)
        .frame(width: 292)
        .signatureCard()
    }

    // MARK: Glass

    private var glass: some View {
        let size = WaterGlassMetrics.size
        let amplitude = ctx["wave"]
        return ZStack {
            TumblerShape()
                .fill(Color.white.opacity(0.05))
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let since = splash.map { timeline.date.timeIntervalSince($0) } ?? 99
                let kick = since >= 0 ? 7 * exp(-2.6 * since) : 0
                ZStack {
                    WaterShape(level: level, phase: -t * 1.7 + 1.3, amplitude: amplitude * 0.7 + kick * 0.6, cycles: 1.7)
                        .fill(reached ? Color(hex: 0x9BE86A).opacity(0.5) : Color(hex: 0x8FD8FF).opacity(0.45))
                    WaterShape(level: level, phase: t * 2.3, amplitude: amplitude + kick, cycles: 1.2)
                        .fill(LinearGradient(
                            colors: reached ? [Color(hex: 0xC8F560), Color(hex: 0x2FB98C)] : [Color(hex: 0x6FD3FF), Color(hex: 0x2A6FF0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    WaterSpray(level: level, splashLevel: splashLevel, since: since, time: t)
                }
            }
            .clipShape(TumblerShape(inset: 5))
            .animation(.smooth(duration: 0.5), value: reached)
            goalLine
            // Glass body: rim light, a long highlight down the left side.
            TumblerShape()
                .stroke(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.14)], startPoint: .top, endPoint: .bottom), lineWidth: 1.6)
            Capsule()
                .fill(LinearGradient(colors: [Color.white.opacity(0.34), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                .frame(width: 5, height: size.height * 0.62)
                .rotationEffect(.degrees(-4.6))
                .offset(x: -size.width * 0.33, y: -8)
            drop
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
    }

    private var goalLine: some View {
        let size = WaterGlassMetrics.size
        let y = size.height * (1 - WaterGlassMetrics.goal / WaterGlassMetrics.capacity)
        return HStack(spacing: 4) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 1.2)
                .overlay(
                    WaterDash()
                        .stroke(reached ? Signature.ink.opacity(0.55) : Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                )
            Image(systemName: reached ? "checkmark" : "flag.fill")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(reached ? Signature.ink.opacity(0.7) : Color.white.opacity(0.75))
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(.horizontal, 12)
        .position(x: size.width / 2, y: y)
    }

    private var drop: some View {
        let size = WaterGlassMetrics.size
        let landing = Double(size.height) * (1 - level) + 4
        return Image(systemName: "drop.fill")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xBDEBFF), Color(hex: 0x4FA8FF)], startPoint: .top, endPoint: .bottom))
            .keyframeAnimator(initialValue: WaterDrop(), trigger: drops) { content, value in
                content
                    .scaleEffect(x: 1 - value.stretch * 0.25, y: 1 + value.stretch, anchor: .bottom)
                    .offset(y: value.y)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    MoveKeyframe(-10)
                    CubicKeyframe(-10 + (landing + 10) * 0.26, duration: 0.16)
                    LinearKeyframe(landing, duration: 0.14)
                }
                KeyframeTrack(\.stretch) {
                    MoveKeyframe(0)
                    LinearKeyframe(0.5, duration: 0.3)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.28)
                    LinearKeyframe(0, duration: 0.03)
                }
            }
            .position(x: size.width / 2, y: 0)
            .allowsHitTesting(false)
    }

    // MARK: Info

    private var info: some View {
        let cups = min(Int((WaterGlassMetrics.goal / cup).rounded(.up)), 14)
        let done = Int(ml / cup + 0.001)
        return VStack(alignment: .leading, spacing: 8) {
            SportEyebrowRow(title: zh ? "今日饮水" : "Water today", symbol: "drop.fill")
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: Int(ml).formatted())
                    .font(Signature.number(36))
                    .foregroundStyle(reached ? Signature.lime : Color.white)
                    .contentTransition(.numericText(value: ml))
                Text(verbatim: "ml")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
            }
            Text(verbatim: reached ? (zh ? "目标达成" : "Goal reached") : (zh ? "目标 2,000 ml" : "Goal 2,000 ml"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(reached ? Signature.lime : Signature.textSecondary)
                .contentTransition(.opacity)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(12), spacing: 3), count: 8), alignment: .leading, spacing: 5) {
                ForEach(0..<cups, id: \.self) { index in
                    Image(systemName: "drop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(index < done ? (reached ? Signature.lime : Color(hex: 0x5FC4FF)) : Color.white.opacity(0.14))
                        .scaleEffect(index < done ? 1 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: done)
                }
            }
            .frame(height: 30, alignment: .top)
            Button(action: { addCup(user: true) }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                    Text(verbatim: "\(Int(cup)) ml")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Signature.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0x8FDCFF), Color(hex: 0x4FA8FF)], startPoint: .top, endPoint: .bottom)))
                .shadow(color: Color(hex: 0x4FA8FF).opacity(0.4), radius: 8, y: 4)
            }
            .buttonStyle(SportPressStyle(scale: 0.95, dim: 0.05))
        }
    }

    // MARK: Actions

    private func addCup(user: Bool) {
        pending?.cancel()
        if ml + cup > WaterGlassMetrics.capacity + 1 {
            // Full: pour it out and start a new day.
            if user { Haptics.tap(.light) }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) { ml = 0 }
            return
        }
        if user { Haptics.tap(.light) }
        drops += 1
        let wasReached = reached
        pending = Task { @MainActor in
            guard await studioPause(0.3) else { return }
            splashLevel = level
            splash = Date()
            withAnimation(.spring(response: ctx["response"], dampingFraction: 0.6)) { ml += cup }
            if user && !ctx.isPreview {
                if !wasReached && reached { Haptics.success() } else { Haptics.tap(.soft) }
            }
        }
    }
}

private struct WaterDrop {
    var y: Double = 0
    var stretch: Double = 0
    var opacity: Double = 0
}

private struct WaterDash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// A tapered tumbler: straight rim, sides leaning in, rounded base.
private struct TumblerShape: Shape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let taper = rect.width * 0.13
        let corner = max(16 - inset, 6)
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addArc(tangent1End: CGPoint(x: r.maxX - taper, y: r.maxY), tangent2End: CGPoint(x: r.minX + taper, y: r.maxY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: r.minX + taper, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: corner)
        path.closeSubpath()
        return path
    }
}

/// The water body: filled from a sine surface at `level` (0…1 of the height) down to the bottom.
private struct WaterShape: Shape {
    var level: Double
    var phase: Double
    var amplitude: Double
    var cycles: Double

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let surface = rect.maxY - rect.height * CGFloat(level)
        let steps = 28
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for index in 0...steps {
            let u = Double(index) / Double(steps)
            let y = surface + CGFloat(amplitude * sin(u * 2 * .pi * cycles + phase))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * CGFloat(u), y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Splash droplets (ballistic arcs from the landing point) and bubbles rising through the water.
private struct WaterSpray: View {
    let level: Double
    let splashLevel: Double
    let since: Double
    let time: Double

    var body: some View {
        Canvas { context, size in
            let depth = size.height * CGFloat(level)
            if depth > 14 {
                for index in 0..<7 {
                    let seed: Double = Double(index)
                    let speed: Double = 0.16 + sportHash(seed * 2.3) * 0.2
                    let phase: Double = time * speed + sportHash(seed * 7.1)
                    let rise: Double = phase.truncatingRemainder(dividingBy: 1)
                    let lane: Double = 0.22 + sportHash(seed * 4.9) * 0.56
                    let sway: Double = sin(time * 2 + seed) * 2
                    let x: CGFloat = size.width * CGFloat(lane) + CGFloat(sway)
                    let y: CGFloat = size.height - depth * CGFloat(rise)
                    let radius: CGFloat = CGFloat(1.2 + sportHash(seed * 1.3) * 1.8)
                    context.opacity = 0.4 * (1 - rise * 0.6)
                    context.stroke(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(.white), lineWidth: 0.9)
                }
            }
            guard since >= 0, since < 0.7 else { return }
            let origin = CGPoint(x: size.width / 2, y: size.height * CGFloat(1 - splashLevel))
            for index in 0..<6 {
                let seed: Double = Double(index)
                let side: Double = index % 2 == 0 ? 1 : -1
                let vx: Double = side * (16 + sportHash(seed * 3.3) * 46)
                let vy: Double = 95 + sportHash(seed * 5.7) * 70
                let fall: Double = 0.5 * 420 * since * since
                let x: CGFloat = origin.x + CGFloat(vx * since)
                let y: CGFloat = origin.y - CGFloat(vy * since - fall)
                let radius: CGFloat = CGFloat(2.6 - since * 2)
                guard radius > 0.4 else { continue }
                context.opacity = min(1, (0.7 - since) * 4)
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(Color(hex: 0xCDEFFF)))
            }
        }
    }
}
