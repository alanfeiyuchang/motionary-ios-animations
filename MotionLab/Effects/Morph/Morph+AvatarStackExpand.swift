import SwiftUI

extension Effect {
    static let morphAvatarStackExpand = Effect(
        id: "morph.avatar-stack-expand",
        category: .morph,
        interaction: .tap,
        name: L("Avatar Stack to List", "头像堆叠展开成列表"),
        summary: L(
            "An overlapping avatar stack deals itself out into a member list, each avatar swinging down an arc as its name slides in beside it.",
            "重叠的头像堆像发牌一样展开成成员列表，每个头像沿弧线落位，名字跟着从旁边滑入。"
        ),
        prompt: L(
            "A 96 pt tall card with a title on the left and five 36 pt avatars overlapping by 14 pt on the right. Tapping grows the card to 290 pt on a spring (response 0.5 s, damping 0.85) and deals the avatars into a vertical list: each one travels from its place in the stack to the left edge of its own row on its own spring (damping 0.75), delayed 50 ms after the previous, its x easing out faster than its y so the path bends into an arc. Over the last half of each flight the name and role slide in 24 pt from the right out of a 4 pt blur, a presence dot pops on the avatar, the cut-out ring fades, and hairlines appear between rows. Tapping again restacks them in reverse order. Sociable, fluid, card-dealer rhythm.",
            "一张 96pt 高的卡片，左侧是标题，右侧五个 36pt 头像彼此重叠 14pt。点一下，卡片乘弹簧（响应 0.5 秒、阻尼 0.85）长到 290pt，头像像发牌一样排成竖直列表：每个头像从堆叠中的位置飞向自己那一行的左端，各用一条弹簧（阻尼 0.75），比前一个晚 50 毫秒出发，x 方向比 y 方向更早减速，路径因此弯成弧线。每段飞行的后半程里，名字和角色从右侧 24pt 外、带 4pt 模糊滑入，头像上弹出在线圆点，镂空描边淡去，行间出现分隔细线。再点一下，头像按相反顺序叠回去。流畅，带着发牌的节奏。"
        ),
        implementation: L(
            "Each avatar is its own Animatable wrapper around a 0…1 progress with a delayed spring keyed to the expanded flag; its position is an eased lerp between the stack slot and the row slot, and the row's text, presence dot and ring are derived from the same progress.",
            "每个头像各用一个 Animatable 包装器包住 0…1 的进度，并带一条由「已展开」状态驱动的延迟弹簧；位置是堆叠槽位与列表槽位之间带缓动的插值，该行的文字、在线圆点与描边都由同一进度推导。"
        ),
        apis: ["Animatable", "animation(_:value:)", "spring(response:dampingFraction:)", "position", "zIndex"],
        tags: ["avatar", "stack", "facepile", "list", "expand", "头像", "堆叠", "成员列表", "展开"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.75),
            .slider("stagger", L("Stagger", "错峰间隔"), 0...0.15, default: 0.05, decimals: 3, unit: "s"),
            .slider("overlap", L("Stack overlap", "堆叠重叠"), 0...24, default: 14, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        AvatarStackDemo(ctx: ctx)
    }
}

private struct StackMember {
    let name: LocalizedText
    let role: LocalizedText
    let color: Color
    let online: Bool
}

private let stackMembers: [StackMember] = [
    StackMember(name: L("Ava Lin", "林艾娃"), role: L("Owner", "所有者"), color: Palette.coral, online: true),
    StackMember(name: L("Ben Ortiz", "欧本"), role: L("Can edit", "可编辑"), color: Palette.indigo, online: true),
    StackMember(name: L("Chloe Park", "朴可艾"), role: L("Can edit", "可编辑"), color: Palette.mint, online: false),
    StackMember(name: L("Dev Rao", "饶德文"), role: L("Can view", "仅查看"), color: Palette.amber, online: true),
    StackMember(name: L("Emi Sato", "佐藤惠美"), role: L("Can view", "仅查看"), color: Palette.pink, online: false),
]

private enum StackLayout {
    static let size = CGSize(width: 316, height: 306)
    static let cardX: CGFloat = 12
    static let cardWidth: CGFloat = 292
    static let collapsed: CGFloat = 96
    static let expanded: CGFloat = 290
    static let avatar: CGFloat = 36
    static let row: CGFloat = 44
    static let firstRow: CGFloat = 96

    static func stackSlot(_ index: Int, overlap: CGFloat) -> CGPoint {
        let step: CGFloat = avatar - overlap
        let right: CGFloat = cardX + cardWidth - 18 - avatar / 2
        return CGPoint(x: right - CGFloat(stackMembers.count - 1 - index) * step, y: size.height / 2)
    }

    static func rowSlot(_ index: Int) -> CGPoint {
        CGPoint(x: cardX + 18 + avatar / 2, y: firstRow + CGFloat(index) * row)
    }
}

private struct AvatarStackDemo: View {
    let ctx: DemoContext
    @State private var expanded: Bool

    init(ctx: DemoContext) {
        self.ctx = ctx
        _expanded = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 10) {
            stage
            DemoHint(
                text: expanded ? L("Tap to stack them back", "再点一下叠回去") : L("Tap the avatar stack", "点击头像堆"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7) { toggle() }
    }

    private var stage: some View {
        let card = RoundedRectangle(cornerRadius: 26, style: .continuous)
        let count: Int = stackMembers.count
        return ZStack {
            card
                .fill(Palette.elevated)
                .overlay(card.strokeBorder(Palette.stroke))
                .shadow(color: .black.opacity(expanded ? 0.16 : 0.1), radius: expanded ? 22 : 14, y: expanded ? 12 : 8)
                .frame(width: StackLayout.cardWidth, height: expanded ? StackLayout.expanded : StackLayout.collapsed)
            header
            ForEach(1..<count, id: \.self) { index in
                Rectangle()
                    .fill(Palette.stroke)
                    .frame(width: StackLayout.cardWidth - 78, height: 1)
                    .position(x: StackLayout.cardX + 66 + (StackLayout.cardWidth - 78) / 2, y: StackLayout.firstRow + (CGFloat(index) - 0.5) * StackLayout.row)
                    .opacity(expanded ? 1 : 0)
                    .animation(.easeOut(duration: 0.25).delay(expanded ? 0.2 + Double(index) * ctx["stagger"] : 0), value: expanded)
            }
            ForEach(0..<count, id: \.self) { index in
                let order: Int = expanded ? index : count - 1 - index
                MorphAnimated(expanded ? 1.0 : 0.0) { value in
                    StackMemberRow(
                        index: index,
                        progress: CGFloat(value),
                        overlap: ctx.cg("overlap"),
                        language: ctx.language
                    )
                }
                .animation(
                    .spring(response: ctx["response"], dampingFraction: ctx["damping"]).delay(Double(order) * ctx["stagger"]),
                    value: expanded
                )
                .zIndex(Double(count - index))
            }
        }
        .frame(width: StackLayout.size.width, height: StackLayout.size.height)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
    }

    private var header: some View {
        let top: CGFloat = (StackLayout.size.height - StackLayout.expanded) / 2
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ctx.language == .zh ? "周末露营计划" : "Weekend camp")
                    .font(.system(size: 17, weight: .bold))
                Text(verbatim: ctx.language == .zh ? "5 位成员 · 3 人在线" : "5 members · 3 online")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.07), in: Circle())
                .opacity(expanded ? 1 : 0)
                .scaleEffect(expanded ? 1 : 0.5)
        }
        .padding(.horizontal, 18)
        .frame(width: StackLayout.cardWidth)
        .position(x: StackLayout.size.width / 2, y: expanded ? top + 38 : StackLayout.size.height / 2)
    }

    private func toggle() {
        if !ctx.isPreview { Haptics.tap(expanded ? .light : .medium) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.85)) { expanded.toggle() }
    }
}

/// One member: the avatar on its arc plus the row text that arrives with it.
private struct StackMemberRow: View {
    let index: Int
    let progress: CGFloat
    let overlap: CGFloat
    let language: AppLanguage

    var body: some View {
        let member: StackMember = stackMembers[index]
        let from: CGPoint = StackLayout.stackSlot(index, overlap: overlap)
        let to: CGPoint = StackLayout.rowSlot(index)
        // x eases out, y stays on the spring: the avatar swings in on an arc.
        let lead: CGFloat = progress < 0 || progress > 1 ? progress : 1 - pow(1 - progress, 2.2)
        let center = CGPoint(x: MorphMath.lerp(from.x, to.x, lead), y: MorphMath.lerp(from.y, to.y, progress))
        let text: CGFloat = MorphMath.smooth(progress, 0.5, 1)
        let ring: CGFloat = 1 - MorphMath.smooth(progress, 0.2, 0.7)
        ZStack {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.name, language)
                        .font(.system(size: 15, weight: .semibold))
                    Text(verbatim: member.online ? (language == .zh ? "在线" : "Online") : (language == .zh ? "2 小时前" : "2h ago"))
                        .font(.system(size: 11))
                        .foregroundStyle(member.online ? AnyShapeStyle(Palette.green) : AnyShapeStyle(.secondary))
                }
                Spacer(minLength: 0)
                Text(member.role, language)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .frame(width: StackLayout.cardWidth - 84)
            .opacity(Double(text))
            .blur(radius: (1 - text) * 4)
            .offset(x: (1 - text) * 24)
            .position(x: StackLayout.cardX + 66 + (StackLayout.cardWidth - 84) / 2, y: to.y)
            Circle()
                .fill(LinearGradient(colors: [member.color.opacity(0.72), member.color], startPoint: .top, endPoint: .bottom))
                .overlay {
                    Text(verbatim: String(member.name(language).prefix(1)))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: StackLayout.avatar, height: StackLayout.avatar)
                .background {
                    // The cut-out ring that separates overlapping avatars in the stack.
                    Circle()
                        .fill(Palette.elevated)
                        .padding(-2.5)
                        .opacity(Double(ring))
                }
                .overlay(alignment: .bottomTrailing) {
                    if member.online {
                        Circle()
                            .fill(Palette.green)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().strokeBorder(Palette.elevated, lineWidth: 2))
                            .scaleEffect(MorphMath.smooth(progress, 0.6, 1) * (progress > 1 ? progress : 1))
                    }
                }
                .scaleEffect(1 + 0.1 * sin(.pi * MorphMath.unit(progress)))
                .position(center)
        }
        .frame(width: StackLayout.size.width, height: StackLayout.size.height)
        .allowsHitTesting(false)
    }
}
