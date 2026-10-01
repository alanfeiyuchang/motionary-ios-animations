import SwiftUI

extension Effect {
    static let inputsCartStepper = Effect(
        id: "inputs.cart-stepper",
        category: .inputs,
        interaction: .tap,
        name: L("Add-to-Cart Stepper", "加购步进器"),
        summary: L("\"Add\" splits open into − 1 +, the count rolls, and taking the last one away folds it back into \"Add\" while a cart bar rises and sinks.", "「加入」裂开成「− 1 +」，数量滚动；减到零时又合拢成「加入」，底部购物车栏随之升起、沉下。"),
        prompt: L(
            "A product row with an 84 pt Add pill at its right. Tapping it widens the pill to 124 pt on a spring (response 0.4 s, damping 0.7) while its solid fill thins to a tint: the Add label blurs out and shrinks to 60%, and a minus and a plus slide out from the centre to the two ends with the count 1 popping in between. At count 1 the minus is a trash glyph, swapped by symbol replace. Each further tap rolls the digit, nudges the pill 4 pt toward the pressed side and springs it back. A cart bar rises from below with count and total, its bag icon bumping to 125% per change. Removing the last item slides both glyphs back to the centre, snaps the pill to 84 pt and sinks the cart bar. Light haptic per step, medium on add and remove.",
            "商品行右侧是一枚 84pt 的「加入」胶囊。点击后胶囊以弹簧（响应 0.4 秒、阻尼 0.7）拉宽到 124pt，实色填充褪成浅色底：「加入」二字模糊淡出并缩到 60%，减号与加号从中心滑向两端，数量「1」在中间弹出。数量为 1 时减号是垃圾桶图标，以符号替换切换。之后每次点击，数字滚动，胶囊朝被按的一侧挪 4pt 再弹回。购物车栏从下方升起，显示件数与合计，袋子图标每次变化弹到 125%。移除最后一件时，两个图标滑回中心，胶囊收回 84pt，购物车栏沉下。每一步轻触觉，加入与移除为中等触觉。"
        ),
        implementation: L(
            "One count drives everything: the pill's width, fill and the glyph offsets are functions of count > 0 inside a single spring, the digits use numericText content transitions with the count as their value, and the sideways nudge is a short keyframe animation keyed to a signed tap counter.",
            "一个数量值驱动全部：胶囊的宽度、填充与图标位移都是「数量大于零」的函数，由同一个弹簧带动；数字使用以数量为 value 的 numericText 内容过渡，侧向轻推是由带方向的点击计数触发的短关键帧动画。"
        ),
        apis: ["contentTransition(.numericText)", "contentTransition(.symbolEffect(.replace))", "keyframeAnimator", "spring(response:dampingFraction:)", "transition(.move)"],
        tags: ["stepper", "cart", "add to cart", "quantity", "morph", "步进器", "购物车", "加购", "数量", "形变"],
        params: [
            .slider("width", L("Open width", "展开宽度"), 104...150, default: 124, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.7, default: 0.4, unit: "s"),
            .slider("damping", L("Spring damping", "弹簧阻尼"), 0.5...1.0, default: 0.7),
        ]
    ) { ctx in
        InputCartStepperDemo(ctx: ctx)
    }
}

private struct InputCartStepperDemo: View {
    let ctx: DemoContext
    @State private var count: Int
    /// Signed tap counter: its change triggers the nudge, its last direction picks the side.
    @State private var nudges = 0
    @State private var direction: CGFloat = 1
    @State private var bumps = 0
    @State private var step = 0

    private let unitPrice: Double = 4.5

    init(ctx: DemoContext) {
        self.ctx = ctx
        _count = State(initialValue: ctx.isStill ? 2 : 0)
    }

    private var open: Bool { count > 0 }
    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            product
            cartBar
                .offset(y: open ? 0 : 34)
                .opacity(open ? 1 : 0)
                .scaleEffect(open ? 1 : 0.94)
                .padding(.top, 16)
                .allowsHitTesting(false)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap Add, then + and −", "点「加入」，再点 + 和 −"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.85, delay: 0.5) { autoTick() }
    }

    // MARK: Product row

    private var product: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xF3C892), Color(hex: 0xC98A4B)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.white)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Oat Latte", "燕麦拿铁"), ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(verbatim: money(unitPrice))
                    .lineLimit(1)
                    .font(.footnote.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            pill
        }
        .padding(12)
        .frame(width: 304)
        .demoCard(cornerRadius: 24)
    }

    private var pill: some View {
        let width: CGFloat = open ? ctx.cg("width") : 84
        return ZStack {
            Capsule().fill(Palette.indigo.opacity(0.14))
            Capsule().fill(Palette.primary).opacity(open ? 0 : 1)
            addLabel
            Text(verbatim: "\(max(count, 1))")
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.indigo)
                .contentTransition(.numericText(value: Double(count)))
                .scaleEffect(open ? 1 : 0.3)
                .opacity(open ? 1 : 0)
            glyph(count <= 1 ? "trash" : "minus", side: -1, width: width)
            glyph("plus", side: 1, width: width)
        }
        .frame(width: width, height: 40)
        .contentShape(Capsule())
        .overlay { hitAreas }
        .keyframeAnimator(initialValue: CGFloat(0), trigger: nudges) { view, x in
            view.offset(x: x)
        } keyframes: { _ in
            SpringKeyframe(4 * direction, duration: 0.09, spring: .snappy)
            SpringKeyframe(0, duration: 0.35, spring: .bouncy)
        }
        .frame(width: max(ctx.cg("width"), 84), alignment: .trailing)
    }

    private var addLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
            Text(L("Add", "加入"), ctx.language)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Color.white)
        .fixedSize()
        .scaleEffect(open ? 0.6 : 1)
        .opacity(open ? 0 : 1)
        .blur(radius: open ? 5 : 0)
    }

    /// Minus/trash and plus: they leave the centre for the two ends as the pill opens.
    private func glyph(_ name: String, side: CGFloat, width: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(name == "trash" ? Palette.red : Palette.indigo)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 30, height: 30)
            .offset(x: open ? side * (width / 2 - 21) : 0)
            .opacity(open ? 1 : 0)
            .scaleEffect(open ? 1 : 0.4)
    }

    private var hitAreas: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { open ? change(-1) : change(1) }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { change(1) }
        }
    }

    // MARK: Cart bar

    private var cartBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "bag.fill")
                .font(.system(size: 15, weight: .semibold))
                .keyframeAnimator(initialValue: CGFloat(1), trigger: bumps) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    SpringKeyframe(1.25, duration: 0.1, spring: .snappy)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
            Text(itemsLabel)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText(value: Double(count)))
            Spacer(minLength: 0)
            Text(verbatim: money(unitPrice * Double(max(count, 1))))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .contentTransition(.numericText(value: Double(count)))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 18)
        .frame(width: 304, height: 52)
        .background(Palette.primaryStrong, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Palette.indigo.opacity(0.35), radius: 12, y: 6)
    }

    private var itemsLabel: String {
        let shown = max(count, 1)
        if ctx.language == .zh { return "购物车 · \(shown) 件" }
        return shown == 1 ? "Cart · 1 item" : "Cart · \(shown) items"
    }

    private func money(_ amount: Double) -> String {
        (ctx.language == .zh ? "¥" : "$") + String(format: "%.2f", amount * (ctx.language == .zh ? 6 : 1))
    }

    // MARK: Actions

    /// Finger and autoplay both land here.
    private func change(_ delta: Int) {
        let next = (count + delta).clamped(to: 0...9)
        guard next != count else { return }
        let opening = count == 0
        let closing = next == 0
        Haptics.tap(opening || closing ? .medium : .light)
        if !opening && !closing {
            direction = delta > 0 ? 1 : -1
            nudges += 1
        }
        bumps += 1
        withAnimation(spring) { count = next }
    }

    private func autoTick() {
        let script = [1, 1, 1, -1, -1, -1]
        change(script[step % script.count])
        step += 1
    }
}
