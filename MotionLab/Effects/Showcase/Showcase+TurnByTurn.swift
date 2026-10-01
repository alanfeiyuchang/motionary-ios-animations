import SwiftUI

extension Effect {
    static let showcaseTurnByTurn = Effect(
        id: "showcase.turn-by-turn",
        category: .showcase,
        interaction: .tap,
        name: L("Turn-by-Turn Card", "逐向导航卡片"),
        summary: L(
            "A navigation card whose manoeuvre arrow bends into the next turn while the distance counts down and the next instruction slides up.",
            "导航卡片：转向箭头弯成下一个动作，距离倒数归零，下一条指引向上滑入。"
        ),
        prompt: L(
            "A dark navigation widget: an orange tile holding a thick white manoeuvre arrow, a large distance, the street name, a draining progress bar, a row of lane arrows and a Then row previewing the following step. The distance counts down in 10 m steps with rolling digits over 2.4 s while the bar empties. At zero the readout becomes Now and the tile pulses to 108%. Tapping advances: the arrow does not swap but morphs, its bend angle animating on a spring (response 0.5 s, damping 0.62) so a right turn swings through straight into a left turn or curls into a U-turn with a slight wobble; the old distance and street leave upward with a blur as the new ones rise 26 pt from below, the lane row re-lights its recommended lanes 40 ms apart, and the Then row pushes up to the next preview. Clear, glanceable.",
            "深色导航组件：橙色方块里是一枚粗白的转向箭头，旁边是大号距离、道路名称、排空中的进度条、一排车道箭头，以及预告再下一步的“然后”行。距离以 10 米为步长在 2.4 秒内倒数，数字滚动。归零时读数变成“现在”，方块脉动到 108%。点击进入下一步：箭头不替换而是形变，弯折角度以弹簧（响应 0.5 秒、阻尼 0.62）变化，右转摆过直行变成左转，或卷成掉头，略带摆动；旧的距离与路名带模糊上移离开，新的从下方 26pt 升起，车道行以 40 毫秒间隔点亮推荐车道，“然后”行向上推入下一条预告。一眼可读。"
        ),
        implementation: L(
            "The arrow is a Shape whose animatableData is the bend angle: a stem, an arc sampled by that angle, a tail and a head, re-centred on its bounding box every frame. The instruction block is keyed by the step id with an asymmetric offset + blurReplace transition, a Task steps the distance with numericText, and the Then row uses a push transition.",
            "箭头是以弯折角度为 animatableData 的 Shape：由直杆、按角度采样的圆弧、尾段与箭头组成，每帧按包围盒重新居中。指引文字块以步骤 id 为键，使用位移加 blurReplace 的非对称转场；一个 Task 用 numericText 逐步递减距离，“然后”行使用 push 转场。"
        ),
        apis: ["Shape.animatableData", "transition(.blurReplace)", "contentTransition(.numericText)", "keyframeAnimator", "transition(.push)", "Task.sleep"],
        tags: ["navigation", "turn", "arrow", "directions", "maps", "导航", "转向", "箭头", "路线指引", "车道"],
        params: [
            .slider("leg", L("Countdown duration", "倒数时长"), 1.0...5.0, default: 2.4, decimals: 1, unit: "s"),
            .slider("response", L("Morph response", "形变响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Morph damping", "形变阻尼"), 0.4...1.0, default: 0.62),
        ]
    ) { ctx in
        TurnByTurnDemo(ctx: ctx)
    }
}

private struct TurnStep {
    /// Degrees, positive = right.
    let bend: Double
    let distance: Int
    let action: LocalizedText
    let street: LocalizedText
    /// Lane arrows (bend per lane) and which of them to take.
    let lanes: [Double]
    let take: Set<Int>

    static let all: [TurnStep] = [
        TurnStep(bend: 90, distance: 300, action: L("Turn right", "右转"), street: L("Maple Street", "枫林路"), lanes: [-90, 0, 0, 90], take: [3]),
        TurnStep(bend: -90, distance: 450, action: L("Turn left", "左转"), street: L("Harbor Avenue", "海港大道"), lanes: [-90, -90, 0, 0], take: [0, 1]),
        TurnStep(bend: 0, distance: 800, action: L("Continue", "直行"), street: L("Ring Road East", "东环路"), lanes: [-90, 0, 0, 90], take: [1, 2]),
        TurnStep(bend: 45, distance: 200, action: L("Keep right", "靠右"), street: L("Exit 12 · Airport", "12 号出口 · 机场"), lanes: [0, 0, 45, 45], take: [2, 3]),
        TurnStep(bend: -180, distance: 150, action: L("Make a U-turn", "掉头"), street: L("Station Road", "车站路"), lanes: [-180, 0, 0, 0], take: [0]),
    ]
}

private struct TurnByTurnDemo: View {
    let ctx: DemoContext
    @State private var step: Int
    @State private var distance: Int
    @State private var pulses = 0
    @State private var run: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _step = State(initialValue: 0)
        _distance = State(initialValue: ctx.isStill ? 180 : TurnStep.all[0].distance)
    }

    private var zh: Bool { ctx.language == .zh }
    private var current: TurnStep { TurnStep.all[step % TurnStep.all.count] }
    private var next: TurnStep { TurnStep.all[(step + 1) % TurnStep.all.count] }
    private var morph: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        StudioScene(hint: L("Tap for the next manoeuvre", "点击，进入下一个转向"), ctx: ctx) {
            card
                .sportCardTap { advance(user: true) }
        }
        .onAppear {
            guard !ctx.isStill else { return }
            countDown(user: false)
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: ctx["leg"] + 1.3, delay: ctx["leg"] + 1.0, intro: false) { advance(user: false) }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                tile
                instruction
            }
            progress
            lanes
            thenRow
        }
        .padding(16)
        .frame(width: 292)
        .signatureCard()
    }

    private var tile: some View {
        ManeuverArrow(bend: current.bend)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            .frame(width: 48, height: 48)
            .frame(width: 78, height: 78)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Signature.accentGradient))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: Signature.accent.opacity(0.45), radius: 12, y: 6)
            .keyframeAnimator(initialValue: 1.0, trigger: pulses) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(1.08, duration: 0.14)
                    SpringKeyframe(1.0, duration: 0.5, spring: .init(response: 0.3, dampingRatio: 0.5))
                }
            }
    }

    private var instruction: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if distance > 0 {
                        Text(distance, format: .number.grouping(.never))
                            .font(Signature.number(42))
                            .contentTransition(.numericText(countsDown: true))
                        Text(verbatim: zh ? "米" : "m")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Signature.textSecondary)
                    } else {
                        Text(verbatim: zh ? "现在" : "Now")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Signature.accentSoft)
                            .transition(.scale(scale: 0.7, anchor: .leading).combined(with: .opacity))
                    }
                }
                .foregroundStyle(Color.white)
                .frame(height: 48, alignment: .bottomLeading)
                Text(verbatim: current.action(ctx.language) + (zh ? " · " : " onto ") + current.street(ctx.language))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .id(step)
            .transition(AsymmetricTransition(
                insertion: OffsetTransition(CGSize(width: 0, height: 26)).combined(with: BlurReplaceTransition(configuration: .downUp)),
                removal: OffsetTransition(CGSize(width: 0, height: -22)).combined(with: BlurReplaceTransition(configuration: .downUp))
            ))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progress: some View {
        let share = Double(distance) / Double(max(current.distance, 1))
        return GeometryReader { proxy in
            Capsule()
                .fill(Color.white.opacity(0.1))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Signature.accentGradient)
                        .frame(width: max(proxy.size.width * CGFloat(share), 4))
                }
        }
        .frame(height: 4)
    }

    private var lanes: some View {
        HStack(spacing: 8) {
            Text(verbatim: zh ? "车道" : "Lanes")
                .signatureEyebrow()
            Spacer(minLength: 0)
            ForEach(0..<4, id: \.self) { index in
                let take = current.take.contains(index)
                ManeuverArrow(bend: current.lanes[index])
                    .stroke(take ? Color.white : Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 15, height: 15)
                    .frame(width: 34, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(take ? Signature.accent.opacity(0.9) : Color.white.opacity(0.06)))
                    .scaleEffect(take ? 1 : 0.94)
                    .animation(morph.delay(Double(index) * 0.04), value: step)
            }
        }
    }

    private var thenRow: some View {
        HStack(spacing: 10) {
            ManeuverArrow(bend: next.bend)
                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 16)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.1)))
            ZStack(alignment: .leading) {
                Text(verbatim: (zh ? "然后 " : "Then ") + next.action(ctx.language) + " · " + next.street(ctx.language))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .id(step)
                    .transition(.push(from: .bottom))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.28)))
    }

    // MARK: Actions

    private func advance(user: Bool) {
        if user { Haptics.tap(.medium) }
        withAnimation(morph) {
            step += 1
            distance = TurnStep.all[step % TurnStep.all.count].distance
        }
        countDown(user: user)
    }

    private func countDown(user: Bool) {
        run?.cancel()
        let from = distance
        let ticks = max(from / 10, 1)
        let leg = ctx["leg"]
        run = Task { @MainActor in
            guard await studioPause(0.5) else { return }
            let finished = await studioScript(leg) { t in
                let left = from - Int(Double(ticks) * t) * 10
                if left != distance, left > 0 {
                    withAnimation(.linear(duration: 0.08)) { distance = left }
                }
            }
            guard finished else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { distance = 0 }
            pulses += 1
            if user && !ctx.isPreview { Haptics.tap(.rigid) }
        }
    }
}

/// A manoeuvre arrow: a stem going up, then a bend of `bend` degrees (positive = right), a tail and a head.
/// The bend is animatable, so turns morph into each other.
private struct ManeuverArrow: Shape {
    var bend: Double

    var animatableData: Double {
        get { bend }
        set { bend = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let unit = Double(min(rect.width, rect.height))
        let amount = min(abs(bend) / 90, 1)
        let stem = unit * (0.92 - 0.42 * amount)
        let radius = unit * 0.24
        let tail = unit * (0.08 + 0.3 * amount)
        let head = unit * 0.3
        let sign: Double = bend >= 0 ? 1 : -1

        var points: [CGPoint] = [CGPoint(x: 0, y: 0)]
        var position = CGPoint(x: 0, y: -stem)
        points.append(position)
        let startHeading = -Double.pi / 2
        let sweep = bend * .pi / 180
        // Arc: centre sits to the side the turn goes to.
        let normal = startHeading + .pi / 2
        let center = CGPoint(x: position.x + CGFloat(sign * radius * cos(normal)), y: position.y + CGFloat(sign * radius * sin(normal)))
        let steps = 16
        for index in 1...steps {
            let heading = startHeading + sweep * Double(index) / Double(steps)
            let n = heading + .pi / 2
            position = CGPoint(x: center.x - CGFloat(sign * radius * cos(n)), y: center.y - CGFloat(sign * radius * sin(n)))
            points.append(position)
        }
        let heading = startHeading + sweep
        let tip = CGPoint(x: position.x + CGFloat(tail * cos(heading)), y: position.y + CGFloat(tail * sin(heading)))
        points.append(tip)
        let left = CGPoint(x: tip.x + CGFloat(head * cos(heading + 2.45)), y: tip.y + CGFloat(head * sin(heading + 2.45)))
        let right = CGPoint(x: tip.x + CGFloat(head * cos(heading - 2.45)), y: tip.y + CGFloat(head * sin(heading - 2.45)))

        // Re-centre on the bounding box.
        let all = points + [left, right]
        let minX = all.map(\.x).min() ?? 0
        let maxX = all.map(\.x).max() ?? 0
        let minY = all.map(\.y).min() ?? 0
        let maxY = all.map(\.y).max() ?? 0
        let shift = CGPoint(x: rect.midX - (minX + maxX) / 2, y: rect.midY - (minY + maxY) / 2)
        func placed(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + shift.x, y: p.y + shift.y) }

        var path = Path()
        path.move(to: placed(points[0]))
        for point in points.dropFirst() { path.addLine(to: placed(point)) }
        path.move(to: placed(left))
        path.addLine(to: placed(tip))
        path.addLine(to: placed(right))
        return path
    }
}
