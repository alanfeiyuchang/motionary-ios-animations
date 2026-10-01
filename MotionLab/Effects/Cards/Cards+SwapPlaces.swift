import SwiftUI

extension Effect {
    static let cardsSwapPlaces = Effect(
        id: "cards.swap-places",
        category: .cards,
        interaction: .tap,
        name: L("Swap Places", "卡片换位"),
        summary: L("Two currency cards trade slots along opposite arcs: one lifts and passes over, the other ducks under.", "两张货币卡片沿相反的弧线互换位置：一张抬起从上方越过，另一张压低从下方穿过。"),
        prompt: L(
            "Two 244×92 pt currency cards are stacked 12 pt apart with a round swap button on the seam. Tapping it sends the upper card down and the lower card up along mirrored arcs: the travelling-over card bows 34 pt to the right, scales up 6%, rolls 2.5° and deepens its shadow from 10 to 26 pt blur, while the other bows left, shrinks 6%, dims and flattens its shadow, so depth reads clearly as they cross. Both ride one spring (response 0.55 s, damping 0.78) whose slight overshoot makes them settle into the slots; the button's arrows spin 180° and the 'You send / You get' tags cross-fade. A medium haptic starts the swap and a light one lands it. Dragging either card scrubs the same path.",
            "两张244×92 pt的货币卡片上下排列、间隔12 pt，接缝处有一个圆形交换按钮。点击后，上方卡片下行、下方卡片上行，沿镜像弧线交换：从上方越过的那张向右鼓出34 pt、放大6%、侧倾2.5°，投影从10 pt加深到26 pt模糊；另一张向左鼓出、缩小6%、变暗、投影收平，交错时层次分明。两者由同一条弹簧（响应0.55秒、阻尼0.78）驱动，轻微过冲后落入槽位；按钮箭头旋转180°，「付款 / 收款」标签交叉淡化。开始时一记中等触感，落位时一记轻触感。拖动任意一张卡片也能沿同一路径搓动。"
        ),
        implementation: L(
            "Each card is an Animatable view with one slot progress: y is linear, while the sideways bow, scale, roll and shadow all follow sin(π·progress), signed by whether the card passes over or under; zIndex follows the same sign. A UIKit pan scrubs the progress.",
            "每张卡片是带一个槽位进度的 Animatable 视图：纵向线性移动，横向鼓出、缩放、侧倾与投影都按 sin(π·进度) 变化，并根据「从上越过」或「从下穿过」取正负号，zIndex 同理；UIKit 平移手势可直接搓动该进度。"
        ),
        apis: ["Animatable", "zIndex", "rotationEffect", "UIGestureRecognizerRepresentable", "spring(response:dampingFraction:)", "contentTransition"],
        tags: ["swap", "exchange", "reorder", "arc", "互换", "交换", "换位", "弧线"],
        params: [
            .slider("arc", L("Arc width", "弧线宽度"), 0...48, default: 34, step: 1, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1.0, default: 0.55, unit: "s"),
            .slider("lift", L("Lift scale", "抬起缩放"), 0...0.14, default: 0.06),
        ]
    ) { ctx in
        CardsSwapDemo(ctx: ctx)
    }
}

private struct CardsSwapDemo: View {
    let ctx: DemoContext
    /// 0: card 0 sits in the top slot. 1: card 0 sits in the bottom slot.
    @State private var t: CGFloat = 0
    @State private var target = 0
    /// The card that travels above the other during the current swap.
    @State private var over = 0
    @State private var dragStart: CGFloat?
    @State private var dragDecided = false
    @State private var landing: Task<Void, Never>?

    /// Distance between the two slots (92 pt card + 12 pt gap).
    private let slot: CGFloat = 104

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                card(0)
                card(1)
                swapButton
                    .zIndex(3)
            }
            .frame(width: 300, height: 216)
            .contentShape(Rectangle())
            .gesture(PageSafePan(directions: [.up, .down], onChanged: dragChanged, onEnded: dragEnded))
            DemoHint(text: L("Tap the button, or drag a card onto the other", "点击按钮，或把一张卡片拖向另一张"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7) { swap() }
        .onDisappear { landing?.cancel() }
    }

    private func card(_ index: Int) -> some View {
        CardsSwapCard(
            index: index,
            progress: index == 0 ? t : 1 - t,
            sign: over == index ? 1 : -1,
            slot: slot,
            arc: ctx.cg("arc"),
            lift: ctx.cg("lift"),
            sends: target == index,
            language: ctx.language
        )
    }

    private var swapButton: some View {
        Button(action: swap) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(Double(t) * 180))
                .frame(width: 40, height: 40)
                .background(Palette.primaryStrong, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stage, lineWidth: 4))
        }
        .buttonStyle(CardsSwapButtonStyle())
    }

    private func swap() {
        guard dragStart == nil else { return }
        Haptics.tap(.medium)
        // The card now in the top slot is the one that passes over.
        over = target
        settle(to: 1 - target)
    }

    private func settle(to next: Int) {
        let changed = next != target
        target = next
        let response = ctx["response"]
        let muted = Haptics.isMuted || ctx.isPreview
        withAnimation(.spring(response: response, dampingFraction: 0.78)) {
            t = CGFloat(next)
        }
        landing?.cancel()
        guard changed, !muted else { return }
        landing = Task { @MainActor in
            try? await Task.sleep(for: .seconds(response * 0.8))
            guard !Task.isCancelled else { return }
            Haptics.tap(.light)
        }
    }

    // MARK: Drag (scrubs the same path)

    private func dragChanged(_ translation: CGSize) {
        if dragStart == nil {
            dragStart = CGFloat(target)
            dragDecided = false
            landing?.cancel()
        }
        let dy = translation.height
        if !dragDecided {
            guard abs(dy) > 0.5 else { return }
            dragDecided = true
            // Pulling down grabs the top card, pulling up grabs the bottom one; the grabbed card goes over.
            over = dy > 0 ? target : 1 - target
            Haptics.tap(.soft)
        }
        let grabbedTop = over == target
        let travel: CGFloat = max(grabbedTop ? dy : -dy, 0) / slot
        let amount: CGFloat = travel > 1 ? 1 + rubberBand(travel - 1, limit: 0.3) : travel
        t = target == 0 ? amount : 1 - amount
    }

    private func dragEnded(_ end: PageSafePanEnd?) {
        guard dragStart != nil else { return }
        dragStart = nil
        guard dragDecided, let end else {
            settle(to: target)
            return
        }
        let grabbedTop = over == target
        let predicted: CGFloat = (grabbedTop ? end.predictedEndTranslation.height : -end.predictedEndTranslation.height) / slot
        settle(to: predicted > 0.5 ? 1 - target : target)
    }
}

private struct CardsSwapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(isPressed: configuration.isPressed) { pressed in
            configuration.label
                .scaleEffect(pressed ? 0.86 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
    }
}

private struct CardsSwapCurrency {
    let code: String
    let name: LocalizedText
    let symbol: String
    let amount: String
    let colors: [Color]

    static let all: [CardsSwapCurrency] = [
        CardsSwapCurrency(code: "USD", name: L("US Dollar", "美元"), symbol: "dollarsign", amount: "1,000.00", colors: [Color(hex: 0x21D4A8), Color(hex: 0x1A9E9A)]),
        CardsSwapCurrency(code: "EUR", name: L("Euro", "欧元"), symbol: "eurosign", amount: "921.40", colors: [Color(hex: 0x4F7CFF), Color(hex: 0x7A45D6)]),
    ]
}

/// One currency card. `progress` is its slot (0 top, 1 bottom); everything else is derived from it,
/// so the arc, lift and shadow follow the spring exactly, overshoot included.
private struct CardsSwapCard: View, Animatable {
    let index: Int
    var progress: CGFloat
    /// +1 passes over (bows right, grows), −1 passes under (bows left, shrinks).
    let sign: CGFloat
    let slot: CGFloat
    let arc: CGFloat
    let lift: CGFloat
    let sends: Bool
    let language: AppLanguage

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }

    var body: some View {
        // sin(π·p) is 0 in both slots and 1 mid-way; past the ends it turns slightly negative, a tiny counter-sway.
        let bow = sin(progress * .pi)
        let mid = max(bow, 0)
        let overAmount = sign > 0 ? Double(mid) : 0
        let underAmount = sign > 0 ? 0 : Double(mid)
        let shadowRadius: CGFloat = 10 + 16 * CGFloat(overAmount) - 6 * CGFloat(underAmount)
        let shadowY: CGFloat = 6 + 12 * CGFloat(overAmount) - 4 * CGFloat(underAmount)
        face
            .brightness(-0.07 * underAmount)
            .scaleEffect(1 + sign * lift * bow)
            .rotationEffect(.degrees(Double(sign * bow) * 2.5))
            .shadow(color: .black.opacity(0.13 + 0.1 * overAmount), radius: shadowRadius, y: shadowY)
            .offset(x: sign * arc * bow, y: -slot / 2 + slot * progress)
            .zIndex(sign > 0 ? 2 : 1)
    }

    private var face: some View {
        let currency = CardsSwapCurrency.all[index]
        return HStack(spacing: 12) {
            Image(systemName: currency.symbol)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: currency.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: currency.code)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(currency.name, language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                Text(sends ? L("You send", "付款") : L("You get", "收款"), language)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(sends ? Color.secondary : Palette.green)
                    .contentTransition(.opacity)
                Text(verbatim: currency.amount)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 244, height: 92)
        .background(Palette.elevated, in: shape)
        .overlay(shape.strokeBorder(Palette.stroke))
    }
}
