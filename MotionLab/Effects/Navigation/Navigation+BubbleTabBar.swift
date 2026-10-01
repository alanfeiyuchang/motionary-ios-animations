import SwiftUI

extension Effect {
    static let navigationBubbleTabBar = Effect(
        id: "navigation.bubble-tab-bar",
        category: .navigation,
        interaction: .tap,
        name: L("Bubble Label Tab Bar", "气泡标签栏"),
        summary: L(
            "The chosen tab swells into a tinted pill as its label slides out from behind the icon, while the other tabs squeeze and make room.",
            "选中的标签鼓成一枚着色胶囊，文字从图标身后滑出；其余标签被挤压着让出位置。"
        ),
        prompt: L(
            "A floating 304 × 64 pt tab bar with four icons, each tab owning a colour. The selected tab is a 44 pt-tall pill tinted at 16% of its colour, holding the icon and a semibold label. Tapping another tab runs one spring (response 0.42 s, damping 0.7) for everything: the pill slides to the new tab and re-tints, the old label is wiped away as its clip narrows to zero while the new label is uncovered from behind its icon, clearing from a 4 pt blur, and the remaining icons re-space to share the leftover width. Unselected icons dip to 84% and bounce back, each 40 ms later the farther it sits from the tap, like a ripple of pressure; the chosen icon bounces once. The bar's shadow takes the tab colour, and the page above slides in from the travel direction.",
            "一条悬浮的 304 × 64 pt 标签栏，四个图标各有代表色。选中的标签是一枚 44 pt 高的胶囊，底色为该颜色的 16%，内含图标与半粗体文字。点击另一个标签时，所有变化共用一根弹簧（响应 0.42 秒、阻尼 0.7）：胶囊滑到新标签并换色；旧文字随裁切区收窄到零而被抹去，新文字从图标身后露出，由 4 pt 模糊渐清；其余图标重新分配剩下的宽度。未选中的图标先缩到 84% 再弹回，离点击处越远越晚 40 毫秒，像一圈压力波；被选中的图标弹跳一次。标签栏阴影染上该标签的颜色，上方页面顺着移动方向滑入。"
        ),
        implementation: L(
            "Each label lives in a frame that is either its ideal width or zero, clipped, so the HStack's own layout animation does the reveal and the re-spacing; the pill is one matchedGeometryEffect shape, and a keyframeAnimator with a distance-based lead-in plays the squeeze.",
            "每个文字放在一个「理想宽度或零宽」并裁切的 frame 里，由 HStack 自身的布局动画完成显露与重新分配间距；胶囊是同一个 matchedGeometryEffect 形状，按距离延迟起步的 keyframeAnimator 播放挤压。"
        ),
        apis: ["matchedGeometryEffect", "frame(width:alignment:)", "clipped()", "keyframeAnimator", "symbolEffect(.bounce)", "spring(response:dampingFraction:)"],
        tags: ["tab bar", "bubble", "label", "pill", "标签栏", "气泡", "胶囊", "文字展开"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.8, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.7),
            .slider("squeeze", L("Neighbour squeeze", "邻居挤压"), 0.7...1.0, default: 0.84),
            .choice("style", L("Pill style", "胶囊样式"), [L("Tinted", "浅色"), L("Filled", "实色")], default: 0),
        ]
    ) { ctx in
        BubbleTabBarDemo(ctx: ctx)
    }
}

private struct BubbleTab {
    let symbol: String
    let title: LocalizedText
    let color: Color
    let headline: LocalizedText
}

private let bubbleTabs: [BubbleTab] = [
    BubbleTab(symbol: "house.fill", title: L("Home", "首页"), color: Palette.indigo, headline: L("Good morning", "早上好")),
    BubbleTab(symbol: "safari.fill", title: L("Explore", "发现"), color: Palette.pink, headline: L("Trending now", "正在流行")),
    BubbleTab(symbol: "tray.full.fill", title: L("Inbox", "收件箱"), color: Palette.coral, headline: L("3 unread", "3 条未读")),
    BubbleTab(symbol: "person.fill", title: L("Profile", "我的"), color: Palette.green, headline: L("Your space", "个人空间")),
]

private struct BubbleTabBarDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var selected = 0
    @State private var previous = 0
    @State private var moves = 0
    @State private var bounces: [Int] = [0, 0, 0, 0]

    private var filled: Bool { ctx.int("style") == 1 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            page
            Spacer(minLength: 18)
            bar
            DemoHint(text: L("Tap a tab", "点击任一标签"), ctx: ctx)
                .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.3) { select((selected + 1) % bubbleTabs.count) }
    }

    // MARK: Page

    private var page: some View {
        let direction: CGFloat = selected >= previous ? 1 : -1
        return ZStack {
            BubblePage(tab: bubbleTabs[selected], language: ctx.language)
                .id(selected)
                .transition(
                    .asymmetric(
                        insertion: .offset(x: 36 * direction).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    )
                )
        }
        .frame(width: 304, height: 176)
    }

    // MARK: Bar

    private var bar: some View {
        let tint: Color = bubbleTabs[selected].color
        return HStack(spacing: 0) {
            ForEach(0..<bubbleTabs.count, id: \.self) { index in
                BubbleItem(
                    tab: bubbleTabs[index],
                    isSelected: index == selected,
                    filled: filled,
                    language: ctx.language,
                    namespace: ns,
                    moves: moves,
                    bounce: bounces[index],
                    distance: abs(index - selected),
                    squeeze: ctx.cg("squeeze")
                )
                .onTapGesture { select(index) }
                if index < bubbleTabs.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 304, height: 64)
        .background(Palette.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.stroke))
        .shadow(color: tint.opacity(0.28), radius: 18, y: 10)
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
    }

    private func select(_ index: Int) {
        guard index != selected else { return }
        if !ctx.isPreview { Haptics.selection() }
        moves += 1
        bounces[index] += 1
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            previous = selected
            selected = index
        }
    }
}

private struct BubbleItem: View {
    let tab: BubbleTab
    let isSelected: Bool
    let filled: Bool
    let language: AppLanguage
    let namespace: Namespace.ID
    let moves: Int
    let bounce: Int
    let distance: Int
    let squeeze: CGFloat

    private var ink: Color {
        if isSelected { return filled ? Color.white : tab.color }
        return Color.secondary
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: tab.symbol)
                .font(.system(size: 18, weight: .semibold))
                .symbolEffect(.bounce, value: bounce)
                .frame(width: 24, height: 24)
            Text(tab.title, language)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, 7)
                .frame(width: isSelected ? nil : 0, alignment: .leading)
                .clipped()
                .opacity(isSelected ? 1 : 0)
                .blur(radius: isSelected ? 0 : 4)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, isSelected ? 16 : 13)
        .frame(height: 44)
        .background {
            if isSelected {
                Capsule()
                    .fill(filled ? tab.color : tab.color.opacity(0.16))
                    .matchedGeometryEffect(id: "pill", in: namespace)
            }
        }
        .contentShape(Rectangle())
        // The squeeze: unselected tabs dip and recover, later the farther they are from the new selection.
        .keyframeAnimator(initialValue: CGFloat(1), trigger: moves) { content, scale in
            content.scaleEffect(isSelected ? 1 : scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(1, duration: 0.01 + Double(max(distance - 1, 0)) * 0.04)
                CubicKeyframe(squeeze, duration: 0.12)
                SpringKeyframe(1, duration: 0.45, spring: Spring(response: 0.3, dampingRatio: 0.5))
            }
        }
    }
}

private struct BubblePage: View {
    let tab: BubbleTab
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
                    .background(tab.color.gradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tab.headline, language)
                        .font(.title3.weight(.bold))
                    Text(tab.title, language)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 9) {
                Capsule().fill(tab.color.opacity(0.28)).frame(height: 10)
                Capsule().fill(tab.color.opacity(0.2)).frame(width: 210, height: 10)
                Capsule().fill(tab.color.opacity(0.14)).frame(width: 130, height: 10)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 304, height: 176, alignment: .topLeading)
        .background(tab.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(tab.color.opacity(0.22)))
    }
}
