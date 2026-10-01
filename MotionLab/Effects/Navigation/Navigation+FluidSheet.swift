import SwiftUI

extension Effect {
    static let navigationFluidSheet = Effect(
        id: "navigation.fluid-sheet",
        category: .navigation,
        interaction: .tap,
        name: L("Fluid Step Sheet", "流体分步面板"),
        summary: L(
            "One floating tray carries a whole flow: it springs to each step's height while the content dissolves and re-forms inside, and the button becomes the success mark.",
            "一块悬浮托盘承载整个流程：它弹到每一步所需的高度，内容在其中消散又重组，按钮最后化为成功标记。"
        ),
        prompt: L(
            "A floating tray with 30 pt continuous corners sits 8 pt above the bottom of a dimmed wallet screen and hosts four steps: pick an action (214 pt tall), enter an amount (254 pt), confirm (194 pt), success (156 pt). It never dismisses; its height springs to each size (response 0.42 s, damping 0.82), anchored at the bottom. Content does not slide: the outgoing step fades out in 0.16 s while blurring 6 pt and shrinking to 97%, and the incoming one rises 10 pt out of blur, 80 ms later. Persistent pieces only change in place: the title blur-replaces, a back chevron grows in beside it, the amount rolls digit by digit, and the 46 pt button keeps its position while its label swaps. On confirm the button itself contracts into a 56 pt green disc and a check strokes in over 0.35 s, with a success haptic.",
            "一块 30 pt 圆角的悬浮托盘停在钱包页面底部上方 8 pt 处，承载四步流程：选择操作（高 214 pt）、输入金额（254 pt）、确认（194 pt）、成功（156 pt）。托盘从不收起，而是以底边为锚点，用弹簧（响应 0.42 秒、阻尼 0.82）弹到每步的高度。离场内容在 0.16 秒内淡出，模糊 6 pt、缩到 97%；入场内容晚 80 毫秒，从模糊中上移 10 pt 淡入。常驻元素只在原位变化：标题模糊替换，金额逐位滚动，46 pt 的按钮只换文字。确认时按钮收缩成 56 pt 的绿色圆片，对勾在 0.35 秒内描出。"
        ),
        implementation: L(
            "The tray's frame height is looked up per step and animated by one spring; the step body is swapped by id with an asymmetric custom Transition (fast blur-out, delayed blur-in), and the button and the success disc share a matchedGeometryEffect id so one morphs into the other.",
            "托盘的 frame 高度按步骤查表，由一根弹簧驱动；步骤内容按 id 替换，使用不对称的自定义 Transition（快速模糊淡出、延迟模糊淡入）；按钮与成功圆片共享一个 matchedGeometryEffect ID，因此前者会变形为后者。"
        ),
        apis: ["Transition", "matchedGeometryEffect", "contentTransition(.numericText(value:))", "transition(.blurReplace)", "trim(from:to:)", "spring(response:dampingFraction:)"],
        tags: ["sheet", "tray", "multi-step", "flow", "面板", "托盘", "分步流程", "高度变化"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.8, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.55...1.0, default: 0.82),
            .slider("delay", L("Content delay", "内容延迟"), 0...0.25, default: 0.08, unit: "s"),
            .slider("blur", L("Content blur", "内容模糊"), 0...12, default: 6, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        FluidSheetDemo(ctx: ctx)
    }
}

private struct FluidAction {
    let symbol: String
    let title: LocalizedText
    let caption: LocalizedText
    let color: Color
}

private let fluidActions: [FluidAction] = [
    FluidAction(symbol: "arrow.up.right", title: L("Send", "转账"), caption: L("To a contact or address", "给联系人或地址"), color: Palette.indigo),
    FluidAction(symbol: "arrow.down.left", title: L("Receive", "收款"), caption: L("Show your code", "出示收款码"), color: Palette.green),
    FluidAction(symbol: "arrow.left.arrow.right", title: L("Swap", "兑换"), caption: L("Between currencies", "在币种之间"), color: Palette.coral),
]

private let fluidTitles: [LocalizedText] = [
    L("Move money", "资金操作"),
    L("Amount", "输入金额"),
    L("Review", "确认信息"),
    L("", ""),
]

private let fluidHeights: [CGFloat] = [214, 254, 194, 156]

/// Fast blur-out, blur-in from slightly below. The timing lives on the transition (see `stepTransition`).
private struct FluidStepTransition: Transition {
    let blur: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : blur)
            .scaleEffect(phase == .didDisappear ? 0.97 : 1)
            .offset(y: phase == .willAppear ? 10 : 0)
    }
}

private struct FluidSheetDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var step: Int
    @State private var amount = 120
    @State private var autoStep = 0

    private let frameSize = CGSize(width: 260, height: 290)
    private let trayWidth: CGFloat = 244

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the richest step.
        _step = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    private var stepTransition: AnyTransition {
        let base = AnyTransition(FluidStepTransition(blur: ctx.cg("blur")))
        return .asymmetric(
            insertion: base.animation(.easeOut(duration: 0.3).delay(ctx["delay"])),
            removal: base.animation(.easeIn(duration: 0.16))
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottom) {
                FluidWalletBackdrop(language: ctx.language)
                Color.black.opacity(0.22)
                tray
                    .padding(.bottom, 8)
            }
            .frame(width: frameSize.width, height: frameSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
            DemoHint(text: L("Tap through the flow", "依次点击完成流程"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.35) { autoplayStep() }
    }

    // MARK: Tray

    private var tray: some View {
        ZStack(alignment: .top) {
            header
                .opacity(step == 3 ? 0 : 1)
            stepBody
                .id(step)
                .transition(stepTransition)
        }
        .frame(width: trayWidth, height: fluidHeights[step], alignment: .top)
        .overlay(alignment: .bottom) { button }
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Color.black.opacity(0.22), radius: 22, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            if step == 3 { go(to: 0) }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if step == 1 || step == 2 {
                Button { go(to: step - 1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
            Text(fluidTitles[step], ctx.language)
                .font(.headline)
                .id(step)
                .transition(.blurReplace)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 32)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case 0: actionList
        case 1: amountEntry
        case 2: review
        default: success
        }
    }

    // MARK: Steps

    private var actionList: some View {
        VStack(spacing: 4) {
            ForEach(0..<fluidActions.count, id: \.self) { index in
                let action = fluidActions[index]
                Button { go(to: 1) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: action.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 32, height: 32)
                            .background(action.color.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(action.title, ctx.language)
                                .font(.subheadline.weight(.semibold))
                            Text(action.caption, ctx.language)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 46)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 54)
    }

    private var amountEntry: some View {
        VStack(spacing: 7) {
            recipient
            Text("$\(amount)")
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(amount)))
                .frame(height: 48)
            HStack(spacing: 8) {
                ForEach([10, 50, 100], id: \.self) { delta in
                    Button { add(delta) } label: {
                        Text(verbatim: "+\(delta)")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .frame(width: 58, height: 30)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 54)
    }

    private var recipient: some View {
        HStack(spacing: 10) {
            Text(verbatim: "M")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .background(Palette.sunset, in: Circle())
            Text(L("To Mia Chen", "转给 陈米娅"), ctx.language)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var review: some View {
        VStack(spacing: 0) {
            reviewRow(L("To", "收款人"), value: ctx.language == .zh ? "陈米娅" : "Mia Chen")
            Divider().opacity(0.6)
            reviewRow(L("Amount", "金额"), value: "$\(amount).00")
        }
        .padding(.horizontal, 18)
        .padding(.top, 54)
    }

    private func reviewRow(_ label: LocalizedText, value: String) -> some View {
        HStack {
            Text(label, ctx.language)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(verbatim: value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
        .frame(height: 33)
    }

    private var success: some View {
        VStack(spacing: 10) {
            ZStack {
                Capsule()
                    .fill(Palette.green.gradient)
                    .matchedGeometryEffect(id: "cta", in: ns)
                    .frame(width: 56, height: 56)
                FluidCheck(still: ctx.isStill)
                    .frame(width: 24, height: 18)
            }
            VStack(spacing: 2) {
                Text(L("Sent", "已发送"), ctx.language)
                    .font(.headline)
                Text(ctx.language == .zh ? "$\(amount) 已转给 陈米娅" : "$\(amount) to Mia Chen")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(width: trayWidth, height: fluidHeights[3])
    }

    /// The call to action stays in place across the amount and review steps; only its label changes.
    @ViewBuilder
    private var button: some View {
        if step == 1 || step == 2 {
            Button { go(to: step + 1) } label: {
                Text(step == 1 ? L("Continue", "继续") : L("Confirm & send", "确认并发送"), ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .id(step)
                    .transition(.blurReplace)
                    .frame(width: trayWidth - 28, height: 46)
                    .background {
                        Capsule()
                            .fill(Palette.primaryStrong)
                            .matchedGeometryEffect(id: "cta", in: ns)
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)
            .transition(.opacity.combined(with: .offset(y: 14)))
        }
    }

    // MARK: Actions

    private func go(to target: Int) {
        guard target != step, target >= 0, target < fluidHeights.count else { return }
        if !ctx.isPreview {
            if target == 3 { Haptics.success() } else { Haptics.tap(.light) }
        }
        withAnimation(spring) { step = target }
    }

    private func add(_ delta: Int) {
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.snappy(duration: 0.3)) { amount = min(amount + delta, 9_990) }
    }

    /// Preview loop: action → amount (+50) → review → success → back to the start.
    private func autoplayStep() {
        let phase = autoStep % 5
        autoStep += 1
        switch phase {
        case 0: go(to: 1)
        case 1: add(50)
        case 2: go(to: 2)
        case 3: go(to: 3)
        default:
            amount = 120
            go(to: 0)
        }
    }
}

/// A check mark that strokes itself in after the disc has formed (drawn complete in a still).
private struct FluidCheck: View {
    @State private var drawn: Bool

    init(still: Bool) {
        _drawn = State(initialValue: still)
    }

    var body: some View {
        FluidCheckShape()
            .trim(from: 0, to: drawn ? 1 : 0)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(0.28)) { drawn = true }
            }
    }
}

private struct FluidCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct FluidWalletBackdrop: View {
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Total balance", "总资产"), language)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(verbatim: "$4,820.50")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.primary)
                    .frame(height: 74)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.sunset)
                    .frame(height: 74)
            }
            PlaceholderLines(count: 3, color: Color.primary.opacity(0.1))
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.elevated)
    }
}
