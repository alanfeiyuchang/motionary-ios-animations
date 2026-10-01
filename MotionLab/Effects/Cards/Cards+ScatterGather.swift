import SwiftUI

extension Effect {
    static let cardsScatterGather = Effect(
        id: "cards.scatter-gather",
        category: .cards,
        interaction: .tap,
        name: L("Scatter & Gather", "散开与收拢"),
        summary: L("Tap a pile of instant photos and they burst outward across the table, each with its own spin; tap again and they slide back into a squared-up stack.", "点一下一叠拍立得，照片各自带着旋转向四周散开铺满桌面；再点一下，它们滑回去叠得整整齐齐。"),
        prompt: L(
            "Six 80×96 pt instant photos lie in a near-square pile, each rotated a few degrees. A tap bursts them outward from the pile: targets are spread evenly around a ring about 110 pt out, pushed away from the tap point, with a fresh random rotation of up to 22° each time. They leave from the top of the pile down, 40 ms apart, on springs of slightly different response (0.5 s ±15%, damping 0.74): each photo lifts to 110% with a deeper shadow mid-flight, twists a further 16° on the way, slides a little past its spot and settles. Scattered photos can be dragged and flicked around the table. A second tap gathers them in the same order; each landing is a light tick, and the finished pile closes with a small squeeze to 96%.",
            "六张80×96 pt的拍立得叠成一摞，几乎对齐，各带几度的随意旋转。点击后它们从纸堆向外迸开：目标均匀分布在约110 pt外的一圈上，并被推离点击位置，每次重新随机一个最多22°的旋转。照片从最上面一张起依次出发，间隔40毫秒，弹簧响应各不相同（0.5秒±15%，阻尼0.74）：途中放大到110%、投影加深，再多拧16°，滑过目标一点后停稳。散开的照片可以在桌面上拖动、甩动。再次点击，它们按同样的顺序收拢；每张落位一记轻触感，最后整摞轻轻一缩到96%收尾。"
        ),
        implementation: L(
            "Each photo is an Animatable view with a flight progress and a target: position and rotation interpolate between its pile slot and the target, while scale, shadow and an extra twist come from sin(π·progress). A per-photo animation(_:value:) with its own delay and response makes the burst uneven.",
            "每张照片是带飞行进度和目标点的 Animatable 视图：位置和旋转在纸堆槽位与目标之间插值，缩放、投影和额外的扭转取自 sin(π·进度)。逐张设置延迟和响应不同的 animation(_:value:)，让迸散显得不整齐。"
        ),
        apis: ["Animatable", "animation(_:value:)", "DragGesture", "zIndex", "keyframeAnimator", "spring(response:dampingFraction:)"],
        tags: ["scatter", "gather", "photos", "pile", "散开", "收拢", "照片", "拍立得"],
        params: [
            .slider("spread", L("Spread", "散开范围"), 0.6...1.15, default: 1.0),
            .slider("rotation", L("Random rotation", "随机旋转"), 0...40, default: 22, step: 1, decimals: 0, unit: "°"),
            .slider("stagger", L("Stagger", "错峰间隔"), 0...0.12, default: 0.04, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.9, default: 0.5, unit: "s"),
        ]
    ) { ctx in
        CardsScatterDemo(ctx: ctx)
    }
}

private enum CardsScatterLayout {
    static let photo = CGSize(width: 80, height: 96)
    static let area = CGSize(width: 330, height: 290)
    static let count = 6
    static let pile = CGPoint(x: 0, y: -4)

    /// Rest tilt of each photo in the pile.
    static let pileTilt: [Double] = [-4, 3, -2, 5, -3, 1.5]
    static let pileShift: [CGSize] = [
        CGSize(width: -2, height: 2), CGSize(width: 2, height: 1), CGSize(width: -1, height: -1),
        CGSize(width: 1, height: -2), CGSize(width: -2, height: 0), CGSize(width: 0, height: 0),
    ]

    static func clamp(_ point: CGPoint) -> CGPoint {
        let x = (area.width - photo.width) / 2 - 14
        let y = (area.height - photo.height) / 2 - 10
        return CGPoint(x: point.x.clamped(to: -x...x), y: point.y.clamped(to: -y...y))
    }
}

private struct CardsScatterDemo: View {
    let ctx: DemoContext
    @State private var scattered: Bool
    @State private var targets: [CGPoint]
    @State private var turns: [Double]
    /// Stacking order, back to front.
    @State private var order: [Int] = Array(0..<CardsScatterLayout.count)
    @State private var dragging: Int?
    @State private var dragOrigin: CGPoint = .zero
    @State private var round = 0
    @State private var squeezes = 0
    @State private var ticks: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        let plan = Self.plan(round: 0, tap: CGPoint(x: 0, y: 0), spread: ctx.cg("spread"), rotation: ctx["rotation"])
        _targets = State(initialValue: plan.points)
        _turns = State(initialValue: plan.turns)
        _scattered = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        toggle(at: location, haptic: true)
                    }
                ForEach(0..<CardsScatterLayout.count, id: \.self) { index in
                    photo(index)
                }
            }
            .frame(width: CardsScatterLayout.area.width, height: CardsScatterLayout.area.height)
            .coordinateSpace(.named("cardsScatter"))
            .keyframeAnimator(initialValue: CGFloat(1), trigger: squeezes) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(0.96, duration: 0.09)
                SpringKeyframe(1, duration: 0.4, spring: Spring(response: 0.28, dampingRatio: 0.5))
            }
            DemoHint(text: L("Tap to scatter or gather, drag a photo", "点击散开或收拢，可拖动照片"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) {
            let spots: [CGPoint] = [CGPoint(x: 150, y: 150), CGPoint(x: 190, y: 120), CGPoint(x: 140, y: 170)]
            toggle(at: spots[round % spots.count], haptic: false)
        }
        .onDisappear { ticks?.cancel() }
    }

    private func photo(_ index: Int) -> some View {
        // The top of the pile leaves first.
        let rank = CardsScatterLayout.count - 1 - index
        let personal = 0.85 + 0.3 * Double(CardsScatterNoise.value(index, 7))
        let spring = Animation
            .spring(response: ctx["response"] * personal, dampingFraction: 0.74)
            .delay(Double(rank) * ctx["stagger"])
        return CardsScatterPhoto(
            index: index,
            t: scattered ? 1 : 0,
            target: targets[index],
            turn: turns[index],
            language: ctx.language
        )
        .animation(spring, value: scattered)
        .zIndex(Double(order.firstIndex(of: index) ?? index) + (dragging == index ? 10 : 0))
        .gesture(drag(index))
    }

    private func drag(_ index: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("cardsScatter"))
            .onChanged { value in
                guard scattered else { return }
                if dragging != index {
                    dragging = index
                    dragOrigin = targets[index]
                    order.removeAll { $0 == index }
                    order.append(index)
                }
                guard hypot(value.translation.width, value.translation.height) > 3 else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    targets[index] = CGPoint(x: dragOrigin.x + value.translation.width, y: dragOrigin.y + value.translation.height)
                }
            }
            .onEnded { value in
                let moved = hypot(value.translation.width, value.translation.height)
                let wasDragging = dragging == index
                dragging = nil
                if moved < 8 || !wasDragging {
                    // A tap on a photo counts like a tap on the table.
                    toggle(at: value.startLocation, haptic: true)
                    return
                }
                let landing = CGPoint(
                    x: dragOrigin.x + value.predictedEndTranslation.width,
                    y: dragOrigin.y + value.predictedEndTranslation.height
                )
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    targets[index] = CardsScatterLayout.clamp(landing)
                    turns[index] += Double(value.predictedEndTranslation.width - value.translation.width) / 14
                }
            }
    }

    /// Where each photo lands: evenly around a ring, pushed away from the tap, with fresh rotations.
    private static func plan(round: Int, tap: CGPoint, spread: CGFloat, rotation: Double) -> (points: [CGPoint], turns: [Double]) {
        let count = CardsScatterLayout.count
        let start = Double(CardsScatterNoise.value(round, 1)) * 2 * .pi
        // Tapping one side of the pile throws the photos toward the other.
        let push = CGPoint(x: (-tap.x * 0.5).clamped(to: -24...24), y: (-tap.y * 0.5).clamped(to: -18...18))
        var points: [CGPoint] = []
        var turns: [Double] = []
        for index in 0..<count {
            let angle = start + 2 * .pi * Double(index) / Double(count) + Double(CardsScatterNoise.value(round * 31 + index, 2) - 0.5) * 0.4
            let distance = spread * (96 + 18 * CardsScatterNoise.value(round * 17 + index, 3))
            let raw = CGPoint(
                x: CardsScatterLayout.pile.x + push.x + CGFloat(cos(angle)) * distance * 1.14,
                y: CardsScatterLayout.pile.y + push.y + CGFloat(sin(angle)) * distance * 0.9
            )
            points.append(CardsScatterLayout.clamp(raw))
            turns.append(Double(CardsScatterNoise.value(round * 13 + index, 4) * 2 - 1) * rotation)
        }
        return (points, turns)
    }

    private func toggle(at location: CGPoint, haptic: Bool) {
        let buzz = haptic && !ctx.isPreview
        ticks?.cancel()
        if scattered {
            scattered = false
            let stagger = ctx["stagger"]
            let landing = ctx["response"] * 0.6
            ticks = Task { @MainActor in
                try? await Task.sleep(for: .seconds(landing))
                for _ in 0..<CardsScatterLayout.count {
                    guard !Task.isCancelled else { return }
                    if buzz { Haptics.tap(.light) }
                    try? await Task.sleep(for: .seconds(max(stagger, 0.02)))
                }
                guard !Task.isCancelled else { return }
                squeezes += 1
            }
        } else {
            round += 1
            let tap = CGPoint(
                x: location.x - CardsScatterLayout.area.width / 2 - CardsScatterLayout.pile.x,
                y: location.y - CardsScatterLayout.area.height / 2 - CardsScatterLayout.pile.y
            )
            let plan = Self.plan(round: round, tap: tap, spread: ctx.cg("spread"), rotation: ctx["rotation"])
            targets = plan.points
            turns = plan.turns
            order = Array(0..<CardsScatterLayout.count)
            scattered = true
            if buzz { Haptics.tap(.medium) }
        }
    }
}

private enum CardsScatterNoise {
    /// Deterministic 0…1 value.
    static func value(_ a: Int, _ b: Int) -> CGFloat {
        var x = UInt64(truncatingIfNeeded: a &* 92821 &+ b &* 689287 &+ 4099)
        x ^= x >> 31
        x = x &* 0x7FB5D329728EA185
        x ^= x >> 27
        x = x &* 0x81DADEF4BC2DD44D
        x ^= x >> 33
        return CGFloat(x % 10_000) / 10_000
    }
}

/// One photo. `t` is its flight from the pile (0) to its place on the table (1).
private struct CardsScatterPhoto: View, Animatable {
    let index: Int
    var t: CGFloat
    var target: CGPoint
    var turn: Double
    let language: AppLanguage

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGPoint.AnimatableData, Double>> {
        get { AnimatablePair(t, AnimatablePair(target.animatableData, turn)) }
        set {
            t = newValue.first
            target.animatableData = newValue.second.first
            turn = newValue.second.second
        }
    }

    var body: some View {
        let shift = CardsScatterLayout.pileShift[index % CardsScatterLayout.count]
        let home = CGPoint(x: CardsScatterLayout.pile.x + shift.width, y: CardsScatterLayout.pile.y + shift.height)
        let x = home.x + (target.x - home.x) * t
        let y = home.y + (target.y - home.y) * t
        let air = sin(.pi * t.clamped(to: 0...1))
        let side: Double = index % 2 == 0 ? 1 : -1
        let pileTilt = CardsScatterLayout.pileTilt[index % CardsScatterLayout.count]
        let angle = pileTilt + (turn - pileTilt) * Double(t) + side * 16 * Double(air)
        CardsScatterFace(index: index, language: language)
            .scaleEffect(1 + 0.1 * air)
            .shadow(color: .black.opacity(0.16 + 0.1 * Double(air)), radius: 4 + 9 * air, y: 2 + 7 * air)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: y)
    }
}

private struct CardsScatterFace: View {
    let index: Int
    let language: AppLanguage

    var body: some View {
        let item = CardsDeck.item(index)
        let size = CardsScatterLayout.photo
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 60, height: 60)
                    .offset(x: 22, y: -22)
                Image(systemName: item.symbol)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.95))
            }
            .frame(width: size.width - 12, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .padding(.top, 6)
            Text(item.title, language)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: 0x4A4A52))
                .lineLimit(1)
                .frame(maxHeight: .infinity)
        }
        .frame(width: size.width, height: size.height)
        .background(
            LinearGradient(colors: [Color.white, Color(hex: 0xF0EEE9)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.6))
    }
}
