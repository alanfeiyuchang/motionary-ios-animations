import SwiftUI

extension Effect {
    static let cardsDealHand = Effect(
        id: "cards.deal-hand",
        category: .cards,
        interaction: .tap,
        name: L("Deal a Hand", "发牌入手"),
        summary: L("Five cards fly off a deck along arcs, turn face-up in the air and land in a fan; tap one to pick it.", "五张牌沿弧线从牌堆飞出，在空中翻成正面，落成一把扇形手牌；点一张即可抽起。"),
        prompt: L(
            "A face-down deck sits at the top of the stage. Tapping it deals five 76×108 pt cards, one every 90 ms: each leaves the top of the deck along a quadratic curve that bows 55 pt sideways, swells to 114% at the apex with a deeper shadow, flips from back to face about its vertical axis between 10% and 75% of the flight, and settles into its slot on a 40° fan (pivot 250 pt below) on a spring (response 0.5 s, damping 0.8), so it slightly overshoots along the path. A light tick marks each landing. Tapping a card raises it 24 pt along its own radius and scales it 5% while its neighbours splay away by up to 6°; tapping the deck gathers the hand back in reverse order, face-down.",
            "一副背面朝上的牌堆放在舞台上方。点击后依次发出五张76×108 pt的牌，每张间隔90毫秒：每张都从牌堆顶部出发，沿一条向侧面鼓出55 pt的二次曲线飞行，在最高点放大到114%、投影加深，并在飞行的10%到75%之间绕纵轴由背面翻到正面，最后以弹簧（响应0.5秒、阻尼0.8）落入40°扇形（圆心在下方250 pt）中自己的位置，沿路径略微过冲。每张落位时有一记轻触感。点击某张牌，它沿自身半径抬起24 pt并放大5%，相邻的牌向两侧让开最多6°；再点牌堆，手牌按相反顺序扣回。"
        ),
        implementation: L(
            "Each card is an Animatable view with a flight progress: position comes from a quadratic Bézier between the deck and its fan slot, and the flip angle, scale, shadow and zIndex are derived from the same progress. One spring per card, delayed by its index, makes the stagger.",
            "每张牌是带飞行进度的 Animatable 视图：位置取自牌堆到扇形槽位之间的二次贝塞尔曲线，翻面角度、缩放、投影与 zIndex 都由同一进度推导；每张牌一条按序号延迟的弹簧形成错峰。"
        ),
        apis: ["Animatable", "rotation3DEffect", "animation(_:value:)", "zIndex", "spring(response:dampingFraction:)"],
        tags: ["deal", "playing cards", "hand", "arc", "发牌", "扑克", "手牌", "弧线"],
        params: [
            .slider("stagger", L("Deal interval", "发牌间隔"), 0.03...0.2, default: 0.09, unit: "s"),
            .slider("arc", L("Arc bend", "弧线弯度"), 0...110, default: 55, step: 1, decimals: 0, unit: "pt"),
            .slider("spread", L("Fan spread", "扇形角度"), 24...60, default: 40, step: 1, decimals: 0, unit: "°"),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.9, default: 0.5, unit: "s"),
        ]
    ) { ctx in
        CardsDealDemo(ctx: ctx)
    }
}

private struct CardsDealModel {
    let rank: String
    let suit: String
    let red: Bool

    static let hand: [CardsDealModel] = [
        CardsDealModel(rank: "10", suit: "suit.spade.fill", red: false),
        CardsDealModel(rank: "J", suit: "suit.heart.fill", red: true),
        CardsDealModel(rank: "Q", suit: "suit.spade.fill", red: false),
        CardsDealModel(rank: "K", suit: "suit.heart.fill", red: true),
        CardsDealModel(rank: "A", suit: "suit.spade.fill", red: false),
    ]
}

private enum CardsDealLayout {
    static let card = CGSize(width: 76, height: 108)
    static let deck = CGPoint(x: 0, y: -94)
    /// Rest tilt of the deck, in degrees.
    static let deckTilt: Double = -6
    /// Centre of the middle hand card, and the fan's radius below it.
    static let handY: CGFloat = 44
    static let radius: CGFloat = 250
}

private struct CardsDealDemo: View {
    let ctx: DemoContext
    @State private var dealt: Bool
    @State private var lifted: Int?
    @State private var autoStep = 0
    @State private var deckTaps = 0
    @State private var ticks: Task<Void, Never>?

    private var count: Int { CardsDealModel.hand.count }

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the dealt hand with one card picked.
        _dealt = State(initialValue: ctx.isStill)
        _lifted = State(initialValue: ctx.isStill ? 3 : nil)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                deck
                ForEach(0..<count, id: \.self) { index in
                    handCard(index)
                }
            }
            .frame(width: 320, height: 304)
            DemoHint(text: L("Tap the deck to deal, tap a card to pick it", "点击牌堆发牌，点击单张抽起"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoAdvance() }
        .onDisappear { ticks?.cancel() }
    }

    private var deck: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { layer in
                CardsDealBack()
                    .offset(y: CGFloat(3 - layer) * 1.6)
                    .brightness(-0.05 * Double(3 - layer))
            }
        }
        .shadow(color: .black.opacity(0.22), radius: 10, y: 8)
        .rotationEffect(.degrees(CardsDealLayout.deckTilt))
        .keyframeAnimator(initialValue: CardsDealKick(), trigger: deckTaps) { content, kick in
            content.scaleEffect(kick.scale)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.93, duration: 0.09)
                SpringKeyframe(1.0, duration: 0.4, spring: Spring(response: 0.3, dampingRatio: 0.5))
            }
        }
        .offset(x: CardsDealLayout.deck.x, y: CardsDealLayout.deck.y)
        .onTapGesture { tapDeck() }
    }

    private func handCard(_ index: Int) -> some View {
        // Deal left to right; gather right to left.
        let order = dealt ? index : count - 1 - index
        let flight = Animation
            .spring(response: ctx["response"], dampingFraction: 0.8)
            .delay(Double(order) * ctx["stagger"])
        return CardsDealCard(
            index: index,
            t: dealt ? 1 : 0,
            lift: lifted == index ? 1 : 0,
            shift: shift(index),
            spread: ctx["spread"],
            arc: ctx.cg("arc")
        )
        .animation(flight, value: dealt)
        .animation(.spring(response: 0.34, dampingFraction: 0.66), value: lifted)
        .onTapGesture { tapCard(index) }
        .allowsHitTesting(dealt)
    }

    /// Neighbours of the picked card splay away from it: 6° next to it, 3° one further, and so on.
    private func shift(_ index: Int) -> CGFloat {
        guard let lifted, lifted != index else { return 0 }
        let distance = CGFloat(abs(index - lifted))
        return (index < lifted ? -6 : 6) / distance
    }

    private func tapDeck() {
        Haptics.tap(.medium)
        deckTaps += 1
        setDealt(!dealt)
    }

    private func tapCard(_ index: Int) {
        guard dealt else { return }
        Haptics.selection()
        lifted = lifted == index ? nil : index
    }

    private func setDealt(_ value: Bool) {
        lifted = nil
        dealt = value
        ticks?.cancel()
        guard value, !ctx.isPreview, !Haptics.isMuted else { return }
        let stagger = ctx["stagger"]
        let landing = ctx["response"] * 0.6
        ticks = Task { @MainActor in
            // One light tick as each card reaches its slot.
            try? await Task.sleep(for: .seconds(landing))
            for _ in 0..<count {
                guard !Task.isCancelled else { return }
                Haptics.tap(.light)
                try? await Task.sleep(for: .seconds(stagger))
            }
        }
    }

    private func autoAdvance() {
        switch autoStep % 4 {
        case 0: setDealt(true)
        case 1: lifted = 3
        case 2: lifted = 1
        default: setDealt(false)
        }
        autoStep += 1
    }
}

private struct CardsDealKick {
    var scale: CGFloat = 1
}

/// One card of the hand. `t` is its flight from the deck (0) to its fan slot (1); the spring may carry it
/// slightly past 1, which extends the same curve.
private struct CardsDealCard: View, Animatable {
    let index: Int
    var t: CGFloat
    var lift: CGFloat
    /// Extra fan angle in degrees while a neighbour is picked.
    var shift: CGFloat
    let spread: Double
    let arc: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(t, AnimatablePair(lift, shift)) }
        set {
            t = newValue.first
            lift = newValue.second.first
            shift = newValue.second.second
        }
    }

    var body: some View {
        let count = CardsDealModel.hand.count
        let clamped = t.clamped(to: 0...1)
        // Slot on the fan.
        let fanAngle: Double = -spread / 2 + spread * Double(index) / Double(count - 1) + Double(shift)
        let radians = CGFloat(fanAngle * .pi / 180)
        let reach: CGFloat = CardsDealLayout.radius + lift * 24
        let slot = CGPoint(
            x: reach * sin(radians),
            y: CardsDealLayout.handY + CardsDealLayout.radius - reach * cos(radians)
        )
        // Quadratic Bézier from the deck, bowing outward.
        let deck = CardsDealLayout.deck
        let side: CGFloat = index * 2 >= count - 1 ? 1 : -1
        let control = CGPoint(x: (deck.x + slot.x) / 2 + side * arc, y: (deck.y + slot.y) / 2 - 12)
        let u = 1 - t
        let x: CGFloat = u * u * deck.x + 2 * u * t * control.x + t * t * slot.x
        let y: CGFloat = u * u * deck.y + 2 * u * t * control.y + t * t * slot.y
        // Flip between 10 % and 75 % of the flight.
        let turn = ((clamped - 0.1) / 0.65).clamped(to: 0...1)
        let eased = turn * turn * (3 - 2 * turn)
        let flip: Double = 180 * Double(1 - eased)
        let apex = sin(clamped * .pi)
        let roll: Double = fanAngle * Double(clamped) + CardsDealLayout.deckTilt * Double(1 - clamped) + Double(side * apex) * 12
        let scale: CGFloat = 1 + 0.14 * apex + 0.05 * lift
        return face(showsBack: flip > 90)
            .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(scale)
            .shadow(color: .black.opacity(0.14 + 0.1 * Double(apex)), radius: 5 + 9 * apex + 6 * lift, y: 3 + 8 * apex + 5 * lift)
            .rotationEffect(.degrees(roll))
            .offset(x: x, y: y)
            // On the deck the first card dealt is the top one; in the hand later cards overlap earlier ones.
            .zIndex(clamped < 0.35 ? Double(20 - index) : Double(30 + index))
    }

    @ViewBuilder
    private func face(showsBack: Bool) -> some View {
        if showsBack {
            CardsDealBack()
        } else {
            CardsDealFace(model: CardsDealModel.hand[index])
        }
    }
}

private struct CardsDealFace: View {
    let model: CardsDealModel

    private var ink: Color { model.red ? Color(hex: 0xE0364A) : Color(hex: 0x1B1C22) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 11, style: .continuous) }

    var body: some View {
        ZStack {
            shape.fill(LinearGradient(colors: [Color.white, Color(hex: 0xF1F1F4)], startPoint: .top, endPoint: .bottom))
            Image(systemName: model.suit)
                .font(.system(size: 30))
                .foregroundStyle(ink.gradient)
            corner
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(7)
            corner
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(7)
        }
        .frame(width: CardsDealLayout.card.width, height: CardsDealLayout.card.height)
        .overlay(shape.strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8))
    }

    private var corner: some View {
        VStack(spacing: 0) {
            Text(verbatim: model.rank)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Image(systemName: model.suit)
                .font(.system(size: 9))
        }
        .foregroundStyle(ink)
    }
}

private struct CardsDealBack: View {
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 11, style: .continuous) }

    var body: some View {
        ZStack {
            shape.fill(LinearGradient(colors: [Color(hex: 0x4B57E0), Color(hex: 0x7A45D6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                .padding(6)
            lattice
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(10)
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color(hex: 0x5A4FDB), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
        }
        .frame(width: CardsDealLayout.card.width, height: CardsDealLayout.card.height)
        .overlay(shape.strokeBorder(Color.white.opacity(0.9), lineWidth: 2.5))
        .overlay(shape.strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8))
    }

    /// Diamond lattice of the card back.
    private var lattice: some View {
        Canvas { context, size in
            let step: CGFloat = 9
            var path = Path()
            var offset: CGFloat = -size.height
            while offset < size.width {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                path.move(to: CGPoint(x: offset + size.height, y: 0))
                path.addLine(to: CGPoint(x: offset, y: size.height))
                offset += step
            }
            context.stroke(path, with: .color(.white.opacity(0.2)), lineWidth: 0.7)
        }
    }
}
