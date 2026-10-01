import SwiftUI

extension Effect {
    static let inputsRadioCards = Effect(
        id: "inputs.radio-cards",
        category: .inputs,
        interaction: .tap,
        name: L("Radio Plan Cards", "单选方案卡片"),
        summary: L("Plan cards as radio options: the chosen one lifts and unfolds its details while its ring draws itself, and the others step back.", "把方案卡片当作单选项：选中的那张抬起、展开详情，圆环同时画出；其余卡片后退一步。"),
        prompt: L(
            "Three stacked plan cards, 292 pt wide and 58 pt tall, each with a radio ring, a name and a price. Tapping a card selects it with one spring (response 0.45 s, damping 0.78): the card grows to 112 pt tall to reveal two feature lines, scales to 102%, gains a 2 pt tinted border and a deeper tinted shadow, while the others shrink to 96%, fade to 70% and slide to make room. On the chosen card the radio ring draws clockwise from 12 o'clock in 350 ms and its centre dot pops in 200 ms later with a bounce (response 0.3 s, damping 0.55); the feature lines rise 8 pt out of a 5 pt blur, 70 ms apart. On the card that was selected the ring un-draws, the dot shrinks away and the details blur out as it folds shut.",
            "三张叠放的方案卡片，宽 292pt、高 58pt，各有单选圆环、名称与价格。点击卡片，由同一个弹簧（响应 0.45 秒、阻尼 0.78）完成选中：它长高到 112pt，露出两行权益，放大到 102%，加上 2pt 主题色描边和更深的彩色阴影；其余卡片缩到 96%、淡到 70%，并滑开让位。其圆环用 350 毫秒从 12 点方向顺时针画满，200 毫秒后中心圆点带弹跳弹出（响应 0.3 秒、阻尼 0.55）；权益文字相隔 70 毫秒，从 5pt 模糊中上移 8pt 出现。原先选中的那张，圆环擦回、圆点缩没、详情淡出合拢。"
        ),
        implementation: L(
            "Each card is a fixed-height frame that clips its details; height, scale and opacity depend on whether it is the selection and animate inside one withAnimation spring. The ring is a trimmed inset circle with its own ease-out animation, and the dot and feature lines use delayed springs keyed to the same flag.",
            "每张卡片是一个裁切详情的定高容器；高度、缩放与透明度取决于它是否被选中，都在同一个 withAnimation 弹簧里变化。圆环是 trim 过的内缩圆，带自己的 ease-out 动画；圆点与权益文字使用绑定同一标记、带延迟的弹簧。"
        ),
        apis: ["trim(from:to:)", "spring(response:dampingFraction:)", "clipped", "scaleEffect", "Animation.delay"],
        tags: ["radio", "plan", "pricing", "cards", "selection", "expand", "单选", "方案", "定价", "卡片", "展开"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.8, default: 0.45, unit: "s"),
            .slider("damping", L("Spring damping", "弹簧阻尼"), 0.5...1.0, default: 0.78),
            .slider("recede", L("Unselected scale", "未选缩放"), 0.9...1.0, default: 0.96),
            .slider("lift", L("Selected scale", "选中放大"), 1.0...1.06, default: 1.02),
        ]
    ) { ctx in
        InputRadioCardsDemo(ctx: ctx)
    }
}

private struct InputPlan {
    let name: LocalizedText
    let price: LocalizedText
    let badge: LocalizedText?
    let tint: Color
    let features: [LocalizedText]

    static let all: [InputPlan] = [
        InputPlan(
            name: L("Starter", "入门版"),
            price: L("Free", "免费"),
            badge: nil,
            tint: Palette.mint,
            features: [L("3 projects, 1 GB storage", "3 个项目，1 GB 存储"), L("Community support", "社区支持")]
        ),
        InputPlan(
            name: L("Plus", "进阶版"),
            price: L("$8", "¥58"),
            badge: L("Popular", "热门"),
            tint: Palette.indigo,
            features: [L("Unlimited projects, 50 GB", "项目不限，50 GB 存储"), L("Version history for 90 days", "90 天版本历史")]
        ),
        InputPlan(
            name: L("Studio", "工作室版"),
            price: L("$16", "¥118"),
            badge: nil,
            tint: Palette.pink,
            features: [L("Everything in Plus, 1 TB", "包含进阶版全部，1 TB"), L("Shared team library", "团队共享素材库")]
        ),
    ]
}

private struct InputRadioCardsDemo: View {
    let ctx: DemoContext
    @State private var selected = 1

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                ForEach(0..<InputPlan.all.count, id: \.self) { index in
                    InputPlanCard(
                        plan: InputPlan.all[index],
                        selected: index == selected,
                        recede: ctx.cg("recede"),
                        lift: ctx.cg("lift"),
                        language: ctx.language
                    )
                    .onTapGesture { select(index) }
                }
            }
            .frame(height: 58 * 2 + 112 + 20)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap another plan", "点选另一个方案"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.5) {
            select((selected + 1) % InputPlan.all.count)
        }
    }

    /// Finger and autoplay both land here.
    private func select(_ index: Int) {
        guard index != selected else { return }
        Haptics.selection()
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            selected = index
        }
    }
}

private struct InputPlanCard: View {
    let plan: InputPlan
    let selected: Bool
    let recede: CGFloat
    let lift: CGFloat
    let language: AppLanguage

    private let collapsed: CGFloat = 58
    private let expanded: CGFloat = 112

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: collapsed)
            details
        }
        .padding(.horizontal, 16)
        .frame(width: 292, height: selected ? expanded : collapsed, alignment: .top)
        .clipped()
        .background(Palette.elevated, in: shape)
        .overlay(shape.strokeBorder(selected ? plan.tint : Color.primary.opacity(0.1), lineWidth: selected ? 2 : 1))
        .shadow(color: selected ? plan.tint.opacity(0.28) : Color.black.opacity(0.06), radius: selected ? 16 : 6, y: selected ? 10 : 3)
        .scaleEffect(selected ? lift : recede)
        .opacity(selected ? 1 : 0.7)
        .contentShape(shape)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ring
            Text(plan.name, language)
                .font(.headline)
                .foregroundStyle(.primary)
            if let badge = plan.badge {
                Text(badge, language)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(plan.tint)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(plan.tint.opacity(0.16), in: Capsule())
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(plan.price, language)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? plan.tint : Color.primary)
                Text(L("/mo", "/月"), language)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.primary.opacity(0.22), lineWidth: 2)
            Circle()
                .inset(by: 1.25)
                .trim(from: 0, to: selected ? 1 : 0)
                .stroke(plan.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: selected)
            Circle()
                .fill(plan.tint)
                .frame(width: 11, height: 11)
                .scaleEffect(selected ? 1 : 0.01)
                .animation(.spring(response: 0.3, dampingFraction: 0.55).delay(selected ? 0.2 : 0), value: selected)
        }
        .frame(width: 24, height: 24)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(plan.features.enumerated()), id: \.offset) { index, feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(plan.tint)
                    Text(feature, language)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .opacity(selected ? 1 : 0)
                .offset(y: selected ? 0 : 8)
                .blur(radius: selected ? 0 : 5)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(selected ? 0.08 + Double(index) * 0.07 : 0), value: selected)
            }
        }
        .padding(.leading, 36)
        .frame(height: expanded - collapsed - 12, alignment: .top)
    }
}
