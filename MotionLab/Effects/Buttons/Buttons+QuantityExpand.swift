import SwiftUI

extension Effect {
    static let buttonsQuantityExpand = Effect(
        id: "buttons.quantity-expand",
        category: .buttons,
        interaction: .tap,
        name: L("Add to Stepper", "加购展开步进器"),
        summary: L(
            "A round plus on a product card unfolds into a − 1 + stepper, then folds into a count badge when left alone.",
            "商品卡片上的圆形加号展开成“− 1 +”步进器，闲置片刻后收拢成数量角标。"
        ),
        prompt: L(
            "A product card with a round 42 pt plus button on the corner of its image. The first tap adds one item and unfolds the button leftward into a 128 pt stepper pill on a spring (response 0.38 s, damping 0.68): the minus and the count slide out from under the plus with a 40 ms stagger. Each + or − rolls the count digit in its direction, bulges the pill 7% toward the tapped side before it springs back, and rolls the total price below. At a count of one the minus becomes a bin; tapping it folds the pill back into the plain plus. After 2.2 s without input the stepper folds by itself into a filled accent badge showing the count, which pops slightly as it lands; tapping the badge unfolds the stepper again. Light haptic per step, a rigid one on removal. Compact, quick, thumb-friendly.",
            "商品卡片的图片一角有一枚 42pt 的圆形加号按钮。第一次点击加入一件商品，并以弹簧（响应 0.38 秒、阻尼 0.68）向左展开成 128pt 宽的步进器胶囊：减号与数量以 40 毫秒的错峰从加号下方滑出。每次点 + 或 −，数字朝对应方向滚动，胶囊向被点的一侧鼓出 7% 再弹回，下方总价同步滚动。数量为 1 时减号变成垃圾桶，点击它会把胶囊收回成加号。2.2 秒没有操作后，步进器自动收拢成显示数量的实心强调色角标，落位时轻轻一弹；点击角标可再次展开。每一步伴随轻触感，移除时为硬朗触感。"
        ),
        implementation: L(
            "A single trailing-anchored capsule animates its width between 42 pt and the stepper width from two pieces of state (`count`, `expanded`); stepper content and the plus/count face cross-fade inside it. The side bulge is a keyframeAnimator scaleEffect anchored on the opposite edge, and a cancellable Task schedules the auto-collapse.",
            "一个右侧锚定的胶囊，根据两份状态（`count`、`expanded`）在 42pt 与步进器宽度之间做宽度动画；步进器内容与“加号 / 数量”面在其中交叉淡入淡出。侧向鼓出由锚定在对侧边缘的 keyframeAnimator scaleEffect 实现，自动收拢由一个可取消的 Task 调度。"
        ),
        apis: ["spring(response:dampingFraction:)", "contentTransition(.numericText(value:))", "keyframeAnimator", "contentTransition(.symbolEffect(.replace))", "Task.sleep"],
        tags: ["add", "quantity", "stepper", "expand", "cart", "加购", "数量", "步进器", "展开", "购物车"],
        params: [
            .slider("width", L("Stepper width", "步进器宽度"), 104...160, default: 128, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.6, default: 0.38, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.68),
            .slider("idle", L("Auto-collapse delay", "自动收拢延迟"), 1...5, default: 2.2, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        ButtonQuantityDemo(ctx: ctx)
    }
}

private struct ButtonQuantityBulge {
    var plus: CGFloat = 1
    var minus: CGFloat = 1
}

private struct ButtonQuantityDemo: View {
    let ctx: DemoContext
    @State private var count: Int
    @State private var expanded: Bool
    @State private var plusBumps = 0
    @State private var minusBumps = 0
    @State private var badgePops = 0
    @State private var collapseTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    private static let unitPrice = 28

    init(ctx: DemoContext) {
        self.ctx = ctx
        _count = State(initialValue: ctx.isStill ? 2 : 0)
        _expanded = State(initialValue: ctx.isStill)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var accent: Color { Palette.coral }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            card
            Spacer()
            DemoHint(text: L("Tap +, then wait for it to fold", "点 +，再等它自动收拢"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 5.6, delay: 0.5) { playScript() }
        .onDisappear {
            collapseTask?.cancel()
            scriptTask?.cancel()
        }
    }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(colors: [Color(hex: 0xFFD9A8), Color(hex: 0xFF9D7A)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: Color(hex: 0xC8552B).opacity(0.35), radius: 8, y: 5)
                    }
                control
                    .padding(10)
            }
            .frame(width: 226, height: 138)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ctx.language == .zh ? "澳白咖啡" : "Flat White")
                        .font(.subheadline.weight(.semibold))
                    Text(ctx.language == .zh ? "中杯 · 热" : "Medium · Hot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(priceText)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(count > 0 ? AnyShapeStyle(accent) : AnyShapeStyle(Color.primary))
                    .contentTransition(.numericText(value: Double(count)))
            }
            .padding(.horizontal, 6)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
        .frame(width: 226)
        .padding(10)
        .demoCard(cornerRadius: 26)
    }

    private var priceText: String {
        let amount = Self.unitPrice * max(count, 1)
        return ctx.language == .zh ? "¥\(amount)" : "$\(amount)"
    }

    // MARK: Control

    private var control: some View {
        let open = expanded && count > 0
        let badge = !expanded && count > 0
        let width: CGFloat = open ? ctx.cg("width") : 42
        return ZStack {
            Capsule()
                .fill(badge ? AnyShapeStyle(accent) : AnyShapeStyle(Color.white))
            // Stepper content: −, count, +.
            HStack(spacing: 0) {
                stepButton(symbol: count <= 1 ? "trash.fill" : "minus", tint: count <= 1 ? Palette.red : Color(hex: 0x2B2B33)) { decrement(haptics: true) }
                    .opacity(open ? 1 : 0)
                    .offset(x: open ? 0 : 30)
                    .animation(spring.delay(open ? 0.04 : 0), value: open)
                    .allowsHitTesting(open)
                Spacer(minLength: 0)
                Text("\(max(count, 1))")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: 0x2B2B33))
                    .contentTransition(.numericText(value: Double(count)))
                    .opacity(open ? 1 : 0)
                    .offset(x: open ? 0 : 16)
                Spacer(minLength: 0)
                stepButton(symbol: "plus", tint: accent) { increment(haptics: true) }
                    .opacity(open || count == 0 ? 1 : 0)
                    .allowsHitTesting(open)
            }
            // The row keeps its full width and is revealed from the trailing edge as the pill widens.
            .frame(width: ctx.cg("width"))
            .frame(width: width, alignment: .trailing)
            // Collapsed badge face: the count on the accent fill.
            Text("\(max(count, 1))")
                .font(.system(.body, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(count)))
                .opacity(badge ? 1 : 0)
                .scaleEffect(badge ? 1 : 0.5)
                .frame(width: 42, height: 42)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: 42)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        .contentShape(Capsule())
        .onTapGesture {
            scriptTask?.cancel()
            tapFace(haptics: true)
        }
        .keyframeAnimator(initialValue: ButtonQuantityBulge(), trigger: plusBumps) { content, bulge in
            content.scaleEffect(x: bulge.plus, anchor: .leading)
        } keyframes: { _ in
            KeyframeTrack(\.plus) {
                CubicKeyframe(1.07, duration: 0.08)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
        }
        .keyframeAnimator(initialValue: ButtonQuantityBulge(), trigger: minusBumps) { content, bulge in
            content.scaleEffect(x: bulge.minus, anchor: .trailing)
        } keyframes: { _ in
            KeyframeTrack(\.minus) {
                CubicKeyframe(1.07, duration: 0.08)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: badgePops) { content, scale in
            content.scaleEffect(scale, anchor: .trailing)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(1, duration: 0.16)
                CubicKeyframe(1.14, duration: 0.1)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    private func stepButton(symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            scriptTask?.cancel()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 42, height: 42)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Behaviour

    /// A tap on the collapsed face: the plain plus adds the first item, the badge just re-opens the stepper.
    private func tapFace(haptics: Bool) {
        guard !expanded || count == 0 else { return }
        if count == 0 {
            increment(haptics: haptics)
        } else {
            if haptics { Haptics.tap(.light) }
            withAnimation(spring) { expanded = true }
            scheduleCollapse()
        }
    }

    private func increment(haptics: Bool) {
        if haptics { Haptics.tap(.light) }
        let wasOpen = expanded && count > 0
        withAnimation(spring) {
            count = min(count + 1, 99)
            expanded = true
        }
        if wasOpen { plusBumps += 1 }
        scheduleCollapse()
    }

    private func decrement(haptics: Bool) {
        guard count > 0 else { return }
        if count == 1 {
            if haptics { Haptics.tap(.rigid) }
            collapseTask?.cancel()
            withAnimation(spring) {
                count = 0
                expanded = false
            }
            return
        }
        if haptics { Haptics.tap(.light) }
        withAnimation(spring) { count -= 1 }
        minusBumps += 1
        scheduleCollapse()
    }

    private func collapse() {
        guard expanded, count > 0 else { return }
        withAnimation(spring) { expanded = false }
        badgePops += 1
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        let delay = max(ctx["idle"], 0.3)
        collapseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            collapse()
        }
    }

    /// Preview loop and detail intro: add three, fold to the badge, re-open, remove them all.
    private func playScript() {
        guard count == 0 else { return }
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            func pause(_ seconds: Double) async -> Bool {
                try? await Task.sleep(for: .seconds(seconds))
                return !Task.isCancelled
            }
            tapFace(haptics: false)
            guard await pause(0.55) else { return }
            increment(haptics: false)
            guard await pause(0.42) else { return }
            increment(haptics: false)
            guard await pause(0.75) else { return }
            collapseTask?.cancel()
            collapse()
            guard await pause(0.95) else { return }
            tapFace(haptics: false)
            guard await pause(0.5) else { return }
            decrement(haptics: false)
            guard await pause(0.4) else { return }
            decrement(haptics: false)
            guard await pause(0.45) else { return }
            decrement(haptics: false)
        }
    }
}
