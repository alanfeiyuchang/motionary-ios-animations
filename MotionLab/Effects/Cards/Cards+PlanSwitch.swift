import SwiftUI

extension Effect {
    static let cardsPlanSwitch = Effect(
        id: "cards.plan-switch",
        category: .cards,
        interaction: .state,
        name: L("Plan Switch", "套餐切换"),
        summary: L("Flip a monthly / yearly toggle: prices roll across three plan cards, save badges pop and the recommended plan lifts.", "拨动月付 / 年付开关：三张套餐卡的价格依次滚动，省钱角标弹出，推荐套餐随之抬起。"),
        prompt: L(
            "Three 100×184 pt plan cards sit under a pill toggle; the middle, recommended one is filled with an indigo gradient. Switching to yearly slides the toggle's thumb on a spring (response 0.35 s, damping 0.75) and sweeps a wave across the cards, each starting 60 ms after its neighbour: the price digits roll down to the yearly figure, the old price fades in beside it as a line strikes through it left to right, and a green save badge pops from zero scale with a 28° twist on a bouncy spring (damping 0.5). The recommended card rises 10 pt, grows 4% and gains a coloured glow. Tapping a card selects it: its radio dot springs in, it lifts 4 pt and the total below rolls to the new amount. Clear, persuasive and lively.",
            "胶囊开关下方并排三张100×184 pt的套餐卡，中间的推荐套餐以靛蓝渐变填充。切到年付时，开关滑块以弹簧（响应0.35秒、阻尼0.75）滑过去，卡片上随即掠过一道波：每张比相邻一张晚60毫秒开始，价格数字向下滚动到年付价，原价在一旁淡入并被一条删除线从左到右划过，绿色的省钱角标从零缩放、带着28°的扭转以活泼的弹簧（阻尼0.5）弹出。推荐卡片上升10 pt、放大4%，并泛起彩色光晕。点击任意卡片即可选中：单选圆点弹入，卡片抬起4 pt，底部总价滚动到新的金额。清晰而灵动。"
        ),
        implementation: L(
            "One Bool drives everything; each card applies its own delayed spring with animation(_:value:), so prices (contentTransition numericText), strike lines, badges and the lift form a staggered wave without any timers.",
            "所有变化由一个 Bool 驱动；每张卡片通过 animation(_:value:) 使用各自带延迟的弹簧，于是价格（contentTransition numericText）、删除线、角标与抬升自然形成错峰的波，无需任何定时器。"
        ),
        apis: ["contentTransition(.numericText(value:))", "animation(_:value:)", "spring(response:dampingFraction:)", "scaleEffect", "rotationEffect"],
        tags: ["pricing", "plans", "toggle", "subscription", "定价", "套餐", "订阅", "年付月付"],
        params: [
            .slider("stagger", L("Card stagger", "卡片错峰"), 0...0.15, default: 0.06, unit: "s"),
            .slider("lift", L("Recommended lift", "推荐抬升"), 0...20, default: 10, step: 1, decimals: 0, unit: "pt"),
            .slider("bounce", L("Badge damping", "角标阻尼"), 0.3...0.9, default: 0.5),
        ]
    ) { ctx in
        CardsPlanSwitchDemo(ctx: ctx)
    }
}

private struct CardsPlan {
    let name: LocalizedText
    let monthly: Int
    let yearly: Int
    let saving: String
    let features: [LocalizedText]

    static let all: [CardsPlan] = [
        CardsPlan(name: L("Basic", "基础版"), monthly: 6, yearly: 4, saving: "33%", features: [L("3 projects", "3 个项目"), L("1 GB", "1 GB 空间")]),
        CardsPlan(name: L("Pro", "专业版"), monthly: 12, yearly: 9, saving: "25%", features: [L("Unlimited", "项目不限"), L("50 GB", "50 GB 空间")]),
        CardsPlan(name: L("Team", "团队版"), monthly: 29, yearly: 23, saving: "21%", features: [L("10 seats", "10 个席位"), L("SSO", "单点登录")]),
    ]
}

private struct CardsPlanSwitchDemo: View {
    let ctx: DemoContext
    @State private var yearly: Bool
    @State private var selected = 1
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the yearly state: badges out, recommended card lifted.
        _yearly = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            toggle
            HStack(spacing: 8) {
                ForEach(0..<CardsPlan.all.count, id: \.self) { index in
                    CardsPlanCard(
                        index: index,
                        yearly: yearly,
                        isSelected: selected == index,
                        lift: ctx.cg("lift"),
                        stagger: ctx["stagger"],
                        bounce: ctx["bounce"],
                        language: ctx.language
                    )
                    .onTapGesture { select(index) }
                }
            }
            .padding(.top, 34)
            summary
                .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoAdvance() }
    }

    // MARK: Toggle

    private var toggle: some View {
        HStack(spacing: 0) {
            segment(L("Monthly", "月付"), value: false)
            segment(L("Yearly", "年付"), value: true)
        }
        .background(alignment: .leading) {
            Capsule()
                .fill(Palette.elevated)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .frame(width: 104)
                .offset(x: yearly ? 104 : 0)
        }
        .padding(3)
        .background(Color.primary.opacity(0.08), in: Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: yearly)
    }

    private func segment(_ title: LocalizedText, value: Bool) -> some View {
        Text(title, ctx.language)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(yearly == value ? Color.primary : Color.secondary)
            .frame(width: 104, height: 34)
            .contentShape(Rectangle())
            .onTapGesture { setYearly(value) }
    }

    // MARK: Total

    private var summary: some View {
        let plan = CardsPlan.all[selected]
        let total = yearly ? plan.yearly * 12 : plan.monthly
        return HStack(spacing: 4) {
            Text(plan.name, ctx.language)
                .contentTransition(.opacity)
            Text(verbatim: "·")
            Text(verbatim: "$\(total)")
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(total)))
            Text(yearly ? L("per year", "每年") : L("per month", "每月"), ctx.language)
                .contentTransition(.opacity)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .frame(height: 44)
        .background(Palette.primaryStrong, in: Capsule())
        .shadow(color: Palette.indigo.opacity(0.35), radius: 12, y: 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: total)
    }

    private func setYearly(_ value: Bool) {
        guard value != yearly else { return }
        Haptics.tap(.light)
        yearly = value
    }

    private func select(_ index: Int) {
        guard index != selected else { return }
        Haptics.selection()
        selected = index
    }

    private func autoAdvance() {
        switch autoStep % 4 {
        case 0: yearly = true
        case 1: selected = 2
        case 2: yearly = false
        default: selected = 1
        }
        autoStep += 1
    }
}

private struct CardsPlanCard: View {
    let index: Int
    let yearly: Bool
    let isSelected: Bool
    let lift: CGFloat
    let stagger: Double
    let bounce: Double
    let language: AppLanguage

    private var plan: CardsPlan { CardsPlan.all[index] }
    private var recommended: Bool { index == 1 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }
    private var ink: Color { recommended ? .white : .primary }

    var body: some View {
        let raised = recommended && yearly
        let rise: CGFloat = (raised ? lift : 0) + (isSelected ? 4 : 0)
        let wave = Animation.spring(response: 0.45, dampingFraction: 0.72).delay(Double(index) * stagger)
        content
            .padding(12)
            .frame(width: 100, height: 184, alignment: .topLeading)
            .background { background }
            .overlay { shape.strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1) }
            .overlay(alignment: .topTrailing) { badge }
            .scaleEffect(raised ? 1.04 : 1)
            .offset(y: -rise)
            .shadow(
                color: recommended ? Palette.indigo.opacity(raised ? 0.45 : 0.22) : Color.black.opacity(0.1),
                radius: raised ? 20 : 10,
                y: raised ? 14 : 6
            )
            .animation(wave, value: yearly)
            .animation(.spring(response: 0.35, dampingFraction: 0.68), value: isSelected)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var background: some View {
        if recommended {
            shape.fill(Palette.primaryStrong)
        } else {
            shape.fill(Palette.elevated)
        }
    }

    private var borderColor: Color {
        if isSelected { return recommended ? Color.white.opacity(0.9) : Palette.indigo }
        return recommended ? Color.white.opacity(0.2) : Color.primary.opacity(0.08)
    }

    private var content: some View {
        let price = yearly ? plan.yearly : plan.monthly
        return VStack(alignment: .leading, spacing: 0) {
            Text(plan.name, language)
                .font(.system(size: 12, weight: .bold))
                .opacity(0.75)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: "$")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(verbatim: "\(price)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(price)))
            }
            .padding(.top, 6)
            wasPrice
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<plan.features.count, id: \.self) { k in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7.5, weight: .heavy))
                            .foregroundStyle(recommended ? Color.white : Palette.green)
                        Text(plan.features[k], language)
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(.top, 10)
            Spacer(minLength: 0)
            radio
        }
        .foregroundStyle(ink)
    }

    /// "/mo" always; in yearly mode the old monthly price fades in and a line strikes through it.
    private var wasPrice: some View {
        HStack(spacing: 4) {
            Text(L("/mo", "/月"), language)
                .opacity(0.6)
            Text(verbatim: "$\(plan.monthly)")
                .opacity(yearly ? 0.6 : 0)
                .overlay(alignment: .leading) {
                    Capsule()
                        .frame(height: 1.2)
                        .scaleEffect(x: yearly ? 1 : 0, anchor: .leading)
                        .opacity(0.8)
                }
        }
        .font(.system(size: 10.5, weight: .semibold))
        .frame(height: 14)
    }

    private var radio: some View {
        ZStack {
            Circle()
                .strokeBorder(ink.opacity(isSelected ? 0.9 : 0.25), lineWidth: 1.5)
            Circle()
                .fill(recommended ? Color.white : Palette.indigo)
                .padding(4)
                .scaleEffect(isSelected ? 1 : 0.01)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: 18, height: 18)
        .frame(maxWidth: .infinity)
    }

    private var badge: some View {
        Text(verbatim: "−\(plan.saving)")
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Palette.successStrong, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            .scaleEffect(yearly ? 1 : 0.01)
            .rotationEffect(.degrees(yearly ? 8 : -20))
            .opacity(yearly ? 1 : 0)
            .offset(x: 8, y: -11)
            // The badge pops a beat after its card's price starts rolling.
            .animation(.spring(response: 0.4, dampingFraction: bounce).delay(0.16 + Double(index) * stagger), value: yearly)
    }
}
