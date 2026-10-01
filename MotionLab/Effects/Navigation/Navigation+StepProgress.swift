import SwiftUI

extension Effect {
    static let navigationStepProgress = Effect(
        id: "navigation.step-progress",
        category: .navigation,
        interaction: .tap,
        name: L("Step Progress Navigator", "分步进度导航"),
        summary: L(
            "A checkout stepper whose connectors fill, checkmarks draw and pages push in the right direction.",
            "结账步骤条：连接线填充、对勾描绘，页面按方向推入。"
        ),
        prompt: L(
            "A four-step checkout indicator (Cart → Address → Payment → Done): numbered 28 pt circles joined by 3 pt connector tracks, with the active step wrapped in a softly pulsing halo. Advancing fills the connector left-to-right with the brand gradient over ~350 ms; at about 60% of that fill the completed step's number fades out and a white checkmark draws itself with a 0.3 s stroke trim, while the next circle takes on the gradient and its halo starts breathing. The step content below pushes in from the trailing edge with a fade while the old page exits to the leading edge; going back reverses both the fill and the push direction. Precise, reassuring and clearly directional.",
            "一个四步结账进度条（购物车 → 地址 → 支付 → 完成）：28pt 的数字圆点由 3pt 连接轨道相连，当前步骤外圈有柔和呼吸的光晕。前进时，连接线在约 350 毫秒内以品牌渐变从左向右填满；填充进行到约 60% 时，已完成步骤的数字淡出，白色对勾以 0.3 秒的描边裁剪动画「画」出来，同时下一个圆点换上渐变填充，光晕开始呼吸。下方的步骤内容从右侧淡入推入，旧页面向左侧退出；后退时连接线回收、推入方向同样反转。精确、令人安心，并具有清晰的方向感。"
        ),
        implementation: L(
            "Connectors are capsules whose gradient fill scales on x from a leading anchor; the checkmark is a custom Shape animated with trim(from:to:), the halo uses phaseAnimator, and page content uses a direction-aware .push(from:) transition keyed with .id.",
            "连接线是以左侧为锚点在 x 方向缩放的渐变胶囊；对勾是自定义 Shape，用 trim(from:to:) 动画描绘；光晕使用 phaseAnimator；页面内容以 .id 标识，并使用感知方向的 .push(from:) 转场。"
        ),
        apis: ["trim(from:to:)", "Shape", "phaseAnimator", "transition(.push(from:))", "scaleEffect(x:y:anchor:)"],
        tags: ["stepper", "progress", "wizard", "checkout", "步骤条", "进度", "向导", "结账"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...1.0, default: 0.45, unit: "s"),
            .slider("fill", L("Connector fill", "连线填充时长"), 0.1...1.0, default: 0.35, unit: "s"),
            .toggle("pulse", L("Pulse active step", "当前步骤呼吸"), default: true),
        ]
    ) { ctx in
        StepProgressDemo(ctx: ctx)
    }
}

private let checkoutSteps: [(String, LocalizedText)] = [
    ("cart.fill", L("Cart", "购物车")),
    ("house.fill", L("Address", "地址")),
    ("creditcard.fill", L("Payment", "支付")),
    ("checkmark.seal.fill", L("Done", "完成")),
]

private struct StepProgressDemo: View {
    let ctx: DemoContext
    @State private var step = 0
    @State private var forward = true

    private var lastStep: Int { checkoutSteps.count - 1 }

    var body: some View {
        VStack(spacing: 24) {
            StepIndicator(step: step, fillDuration: ctx["fill"], pulse: ctx.bool("pulse"), language: ctx.language)
            ZStack {
                StepPage(index: step, language: ctx.language)
                    .id(step)
                    .transition(
                        .push(from: forward ? .trailing : .leading)
                            .combined(with: .opacity)
                    )
            }
            // No inner clip: a tight clip rectangle cut the card's shadow into a visible gray box.
            // The stage itself clips pages as they push in/out.
            .frame(maxWidth: .infinity)
            .frame(height: 136)
            controls
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.4) {
            go(to: step == lastStep ? 0 : step + 1)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { go(to: step - 1) } label: {
                Text(ctx.language == .zh ? "上一步" : "Back")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 96, height: 42)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(step == 0)
            .opacity(step == 0 ? 0.4 : 1)

            Button { go(to: step == lastStep ? 0 : step + 1) } label: {
                Text(step == lastStep ? (ctx.language == .zh ? "重新开始" : "Restart") : (ctx.language == .zh ? "继续" : "Continue"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 128, height: 42)
                    .background(Palette.primary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func go(to target: Int) {
        let clamped = target.clamped(to: 0...lastStep)
        guard clamped != step else { return }
        if !ctx.isPreview {
            if clamped == lastStep { Haptics.success() } else { Haptics.tap() }
        }
        // Update the direction first so the outgoing page picks up the matching removal edge.
        forward = clamped > step
        DispatchQueue.main.async {
            withAnimation(.spring(response: ctx["response"], dampingFraction: 0.86)) {
                step = clamped
            }
        }
    }
}

private struct StepIndicator: View {
    let step: Int
    let fillDuration: Double
    let pulse: Bool
    let language: AppLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(0..<checkoutSteps.count, id: \.self) { index in
                node(index)
                if index < checkoutSteps.count - 1 {
                    connector(filled: index < step)
                }
            }
        }
    }

    private func node(_ index: Int) -> some View {
        let done = index < step
        let current = index == step
        return VStack(spacing: 6) {
            ZStack {
                if current && pulse {
                    Circle()
                        .fill(Palette.indigo.opacity(0.25))
                        .frame(width: 28, height: 28)
                        .phaseAnimator([1.0, 1.45]) { content, scale in
                            content.scaleEffect(scale).opacity(2 - scale * 1.2)
                        } animation: { _ in
                            .easeInOut(duration: 0.9)
                        }
                }
                Circle()
                    .fill(done || current ? AnyShapeStyle(Palette.primary) : AnyShapeStyle(Color.primary.opacity(0.08)))
                    .frame(width: 28, height: 28)
                    .animation(.easeOut(duration: 0.25).delay(done ? fillDuration * 0.6 : 0), value: done)
                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(current ? Color.white : Color.secondary)
                    .opacity(done ? 0 : 1)
                    .animation(.easeOut(duration: 0.15).delay(done ? fillDuration * 0.6 : 0), value: done)
                StepCheck()
                    .trim(from: 0, to: done ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 10)
                    .animation(done ? .easeOut(duration: 0.3).delay(fillDuration * 0.6 + 0.1) : .easeOut(duration: 0.12), value: done)
            }
            .frame(width: 28, height: 28)
            Text(checkoutSteps[index].1, language)
                .font(.caption2.weight(current ? .bold : .medium))
                .foregroundStyle(current || done ? Color.primary : Color.secondary)
                .fixedSize()
        }
        .frame(width: 48)
    }

    private func connector(filled: Bool) -> some View {
        Capsule()
            .fill(Color.primary.opacity(0.1))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Palette.primary)
                    .scaleEffect(x: filled ? 1 : 0, y: 1, anchor: .leading)
                    .animation(.easeInOut(duration: fillDuration), value: filled)
            }
            .frame(height: 3)
            .frame(maxWidth: .infinity)
            .padding(.top, 12.5)
    }
}

private struct StepCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct StepPage: View {
    let index: Int
    let language: AppLanguage

    private static let details: [LocalizedText] = [
        L("2 items · $64.00", "2 件商品 · ¥468"),
        L("Home · 88 Bund Rd", "家 · 外滩路 88 号"),
        L("Nova •••• 4242", "Nova •••• 4242"),
        L("Order confirmed", "订单已确认"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: checkoutSteps[index].0)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Palette.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(checkoutSteps[index].1, language)
                    .font(.headline)
                Text(Self.details[index], language)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 280, height: 96)
        .demoCard(cornerRadius: 22)
    }
}
