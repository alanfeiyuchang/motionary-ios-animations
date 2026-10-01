import SwiftUI

extension Effect {
    static let scrollStickyTabsSync = Effect(
        id: "scroll.sticky-tabs-sync",
        category: .scroll,
        interaction: .scroll,
        name: L("Scroll-synced Section Tabs", "滚动联动分区标签"),
        summary: L("A sticky tab strip whose indicator is scrubbed by the list: it stretches across to the next tab as that section arrives, and tapping a tab scrolls there.", "吸顶的标签条，指示器由列表直接驱动：下一个分区到来时它拉伸着滑向下一个标签，点击标签则滚动到对应分区。"),
        prompt: L(
            "A menu screen: a sticky, frosted tab strip of six section names above a long list grouped under matching headers. The indicator pill is not animated on a timer; the scroll position scrubs it. It rests on the current tab until the next header is within 80 pt of the bar, then hands off continuously: its leading edge moves on an ease-out curve and its trailing edge on an ease-in, so the pill stretches across the gap and closes on the next tab exactly as the header docks. Label colours cross-fade with the same progress and the strip scrolls itself to keep the active tab centred (0.35 s). Tapping a tab locks the pill onto it with a spring (0.4 s, damping 0.78) and scrolls the list there in 0.5 s ease-in-out, without flickering through the tabs in between. A selection haptic marks each change.",
            "吸顶的磨砂标签条列出六个分区，下方是按同名标题分组的长列表。指示胶囊由滚动位置直接驱动：它停在当前标签上，直到下一个分区标题进入距标签条 80 pt 的范围，随后连续交接——前缘走缓出、后缘走缓入，胶囊横跨两个标签被拉长，并在标题贴上标签条的那一刻收拢到下一个标签。文字颜色按同一进度交叉淡化，标签条自己滚动（0.35 秒）让当前标签居中。点击标签时，胶囊以弹簧（0.4 秒、阻尼 0.78）锁定到它上面，列表用 0.5 秒缓入缓出滚过去，途中不在经过的标签上闪烁。每次切换有一次选择触感。"
        ),
        implementation: L(
            "Section start offsets are known from fixed row heights; onScrollGeometryChange turns the offset into an active index plus a 0…1 hand-off progress. Tab frames are measured with onGeometryChange and the pill's two edges are interpolated between neighbouring frames with different easings. A tap sets a lock that pins the pill to the target until the timed ScrollPosition.scrollTo finishes.",
            "各分区的起始偏移由固定行高直接算出；onScrollGeometryChange 把偏移量换算成当前分区索引和 0…1 的交接进度。标签的位置用 onGeometryChange 测量，胶囊的两条边分别以不同缓动在相邻标签的位置之间插值。点击会设置一个锁，把胶囊钉在目标标签上，直到定时的 ScrollPosition.scrollTo 结束。"
        ),
        apis: ["onScrollGeometryChange", "ScrollPosition", "onGeometryChange", "scrollPosition(id:anchor:)", "spring(response:dampingFraction:)"],
        tags: ["tabs", "scroll spy", "sticky", "section", "indicator", "标签", "滚动监听", "吸顶", "分区", "指示器"],
        params: [
            .slider("lead", L("Hand-off distance", "交接距离"), 30...160, default: 80, step: 5, decimals: 0, unit: "pt"),
            .choice("style", L("Indicator", "指示器"), [L("Pill", "胶囊"), L("Underline", "下划线")], default: 0),
            .slider("duration", L("Tap scroll time", "点击滚动时长"), 0.25...1.0, default: 0.5, unit: "s"),
        ]
    ) { ctx in
        ScrollTabsSyncDemo(ctx: ctx)
    }
}

// MARK: - Menu data

private struct ScrollTabsSection {
    let title: LocalizedText
    let items: [(name: LocalizedText, note: LocalizedText, price: String)]
}

private let scrollTabsSections: [ScrollTabsSection] = [
    ScrollTabsSection(title: L("Popular", "人气"), items: [
        (L("Charred leek toast", "炭烤韭葱吐司"), L("Whipped ricotta, lemon", "打发乳清奶酪、柠檬"), "9"),
        (L("Miso butter noodles", "味噌黄油拌面"), L("Scallion, sesame", "葱花、芝麻"), "14"),
        (L("Burnt honey flan", "焦蜜布丁"), L("Sea salt", "海盐"), "8"),
    ]),
    ScrollTabsSection(title: L("Starters", "前菜"), items: [
        (L("Citrus cured trout", "柑橘腌鳟鱼"), L("Fennel, dill oil", "茴香、莳萝油"), "12"),
        (L("Roasted beet salad", "烤甜菜沙拉"), L("Goat cheese, walnut", "山羊奶酪、核桃"), "10"),
        (L("Crispy rice cakes", "脆米饼"), L("Chili crisp", "香辣脆"), "8"),
    ]),
    ScrollTabsSection(title: L("Mains", "主菜"), items: [
        (L("Braised short rib", "红酒炖牛小排"), L("Parsnip purée", "欧防风泥"), "26"),
        (L("Grilled sea bream", "炭烤鲷鱼"), L("Salsa verde", "青酱"), "24"),
        (L("Wild mushroom risotto", "野菌烩饭"), L("Aged parmesan", "陈年帕玛森"), "19"),
        (L("Harissa chicken", "哈里萨烤鸡"), L("Yogurt, mint", "酸奶、薄荷"), "21"),
    ]),
    ScrollTabsSection(title: L("Sides", "配菜"), items: [
        (L("Smashed potatoes", "压碎烤土豆"), L("Garlic, rosemary", "蒜、迷迭香"), "7"),
        (L("Blistered greens", "炝炒时蔬"), L("Brown butter", "焦化黄油"), "7"),
        (L("Sourdough basket", "酸种面包篮"), L("Cultured butter", "发酵黄油"), "5"),
    ]),
    ScrollTabsSection(title: L("Desserts", "甜点"), items: [
        (L("Dark chocolate tart", "黑巧克力挞"), L("Crème fraîche", "法式酸奶油"), "9"),
        (L("Poached pear", "炖梨"), L("Vanilla, almond", "香草、杏仁"), "8"),
        (L("Olive oil gelato", "橄榄油冰淇淋"), L("Two scoops", "两球"), "6"),
    ]),
    ScrollTabsSection(title: L("Drinks", "饮品"), items: [
        (L("Yuzu spritz", "柚子气泡酒"), L("Low alcohol", "低酒精"), "9"),
        (L("Cold brew tonic", "冷萃汤力"), L("Orange peel", "橙皮"), "6"),
        (L("Jasmine pearl tea", "茉莉龙珠"), L("Pot for two", "两人份一壶"), "7"),
        (L("Sparkling water", "气泡水"), L("750 ml", "750 毫升"), "4"),
    ]),
]

private let scrollTabsHeader: CGFloat = 40
private let scrollTabsRow: CGFloat = 62
private let scrollTabsBar: CGFloat = 48

/// Scroll offset at which each section's header docks under the bar.
private let scrollTabsStarts: [CGFloat] = {
    var y: CGFloat = 0
    var starts: [CGFloat] = []
    for section in scrollTabsSections {
        starts.append(y)
        y += scrollTabsHeader + CGFloat(section.items.count) * scrollTabsRow
    }
    return starts
}()

// MARK: - Demo

private struct ScrollTabsSyncDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var tabPosition = ScrollPosition(edge: .leading)
    /// Tab frames inside the strip's content.
    @State private var frames: [Int: CGRect] = [:]
    /// Set by a tap: the pill stays on this tab while the list travels there.
    @State private var locked: Int?
    @State private var lockToken = 0
    @State private var highlighted = 0
    @State private var step = 0

    private var lead: CGFloat { max(ctx.cg("lead"), 1) }

    /// The section under the bar and how far the hand-off to the next one has progressed.
    private var reading: (index: Int, handoff: CGFloat) {
        var index = 0
        for (i, start) in scrollTabsStarts.enumerated() where start <= offset + 0.5 { index = i }
        guard index + 1 < scrollTabsStarts.count else { return (index, 0) }
        let next = scrollTabsStarts[index + 1]
        return (index, ScrollMath.unit(offset, next - lead, next))
    }

    var body: some View {
        list
            .overlay(alignment: .top) { bar }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: nearest) { _, newValue in
                guard newValue != highlighted else { return }
                highlighted = newValue
                if !ctx.isPreview && locked == nil { Haptics.selection() }
                withAnimation(.smooth(duration: 0.35)) {
                    tabPosition.scrollTo(id: newValue, anchor: .center)
                }
            }
            .autoplay(ctx.isPreview, every: 1.9) { autoStep() }
    }

    /// The tab that counts as current (for centring the strip and the haptic).
    private var nearest: Int {
        if let locked { return locked }
        let now = reading
        return now.handoff > 0.5 ? now.index + 1 : now.index
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(scrollTabsSections.indices, id: \.self) { s in
                    ScrollTabsSectionHeader(section: scrollTabsSections[s], language: ctx.language)
                    ForEach(scrollTabsSections[s].items.indices, id: \.self) { r in
                        ScrollTabsDish(section: s, row: r, language: ctx.language)
                    }
                }
            }
            .padding(.top, scrollTabsBar)
            // Room for the last section's header to reach the bar.
            .padding(.bottom, 70)
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        }, action: { _, newValue in
            offset = newValue
        })
        .onScrollPhaseChange { _, newPhase in
            // A finger on the list takes over from a tap's scroll.
            if newPhase == .interacting { locked = nil }
        }
    }

    // MARK: Bar

    private var bar: some View {
        let now = reading
        let underline = ctx.int("style") == 1
        return ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(scrollTabsSections.indices, id: \.self) { i in
                    ScrollTabsLabel(
                        title: scrollTabsSections[i].title,
                        weight: weight(i, now),
                        underline: underline,
                        language: ctx.language
                    )
                    .onGeometryChange(for: CGRect.self, of: { proxy in proxy.frame(in: .named("scrollTabsStrip")) }, action: { frame in
                        frames[i] = frame
                    })
                    .contentShape(Rectangle())
                    .onTapGesture { select(i, haptic: true) }
                    .id(i)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 12)
            .background(alignment: .topLeading) { indicator(now, underline: underline) }
            .coordinateSpace(.named("scrollTabsStrip"))
            .frame(height: scrollTabsBar)
            // The detail stage keeps its Reset button in the top-trailing corner.
            .padding(.trailing, ctx.isPreview ? 0 : 40)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($tabPosition)
        .frame(height: scrollTabsBar)
        .demoGlass(Rectangle(), material: .regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 0.5)
        }
        .shadow(color: .black.opacity(0.12 * Double(ScrollMath.unit(offset, 0, 24))), radius: 8, y: 4)
    }

    private func weight(_ i: Int, _ now: (index: Int, handoff: CGFloat)) -> CGFloat {
        if let locked { return i == locked ? 1 : 0 }
        if i == now.index { return 1 - now.handoff }
        if i == now.index + 1 { return now.handoff }
        return 0
    }

    @ViewBuilder
    private func indicator(_ now: (index: Int, handoff: CGFloat), underline: Bool) -> some View {
        if let rect = indicatorRect(now) {
            if underline {
                Capsule()
                    .fill(Palette.primary)
                    .frame(width: max(rect.width - 20, 8), height: 3)
                    .offset(x: rect.minX + 10, y: scrollTabsBar - 6)
            } else {
                Capsule()
                    .fill(Palette.primaryStrong)
                    .shadow(color: Palette.indigo.opacity(0.35), radius: 6, y: 3)
                    .frame(width: rect.width, height: 32)
                    .offset(x: rect.minX, y: (scrollTabsBar - 32) / 2)
            }
        }
    }

    /// Leading and trailing edges travel on different curves, so the pill stretches across the gap.
    private func indicatorRect(_ now: (index: Int, handoff: CGFloat)) -> CGRect? {
        if let locked { return frames[locked] }
        guard let from = frames[now.index] else { return nil }
        guard now.handoff > 0, let to = frames[now.index + 1] else { return from }
        let t = now.handoff
        let trailing: CGFloat = ScrollMath.lerp(from.maxX, to.maxX, 1 - (1 - t) * (1 - t))
        let leading: CGFloat = ScrollMath.lerp(from.minX, to.minX, t * t)
        return CGRect(x: leading, y: 0, width: max(trailing - leading, 8), height: from.height)
    }

    // MARK: Actions

    /// A tab tap (and the autoplay's simulated tap): lock the pill onto the tab and travel there.
    private func select(_ index: Int, haptic: Bool) {
        if haptic { Haptics.selection() }
        let duration = ctx["duration"]
        lockToken += 1
        let token = lockToken
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { locked = index }
        withAnimation(.easeInOut(duration: duration)) {
            position.scrollTo(y: scrollTabsStarts[index])
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.12))
            // The list now rests on the section, so the scrubbed pill is where the locked one was.
            if token == lockToken { locked = nil }
        }
    }

    private func autoStep() {
        switch step % 4 {
        case 0:
            // A plain scroll: the pill is scrubbed through three hand-offs.
            locked = nil
            withAnimation(.easeInOut(duration: 1.6)) { position.scrollTo(y: scrollTabsStarts[3] + 30) }
        case 1: select(5, haptic: false)
        case 2: select(1, haptic: false)
        default: select(0, haptic: false)
        }
        step += 1
    }
}

// MARK: - Pieces

private struct ScrollTabsLabel: View {
    let title: LocalizedText
    /// 0 idle … 1 under the indicator.
    let weight: CGFloat
    let underline: Bool
    let language: AppLanguage

    var body: some View {
        let text = Text(title, language).font(.subheadline.weight(.semibold))
        return ZStack {
            text.foregroundStyle(.secondary).opacity(Double(1 - weight))
            text.foregroundStyle(underline ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.white)).opacity(Double(weight))
        }
        .fixedSize()
        .padding(.horizontal, 13)
        .frame(height: 32)
    }
}

private struct ScrollTabsSectionHeader: View {
    let section: ScrollTabsSection
    let language: AppLanguage

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(section.title, language)
                .font(.system(size: 19, weight: .bold))
            Text(verbatim: String(section.items.count))
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .frame(height: scrollTabsHeader)
    }
}

private struct ScrollTabsDish: View {
    let section: Int
    let row: Int
    let language: AppLanguage

    var body: some View {
        let item = scrollTabsSections[section].items[row]
        return HStack(spacing: 12) {
            ScrollKitIcon(index: section * 3 + row, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name, language)
                    .font(.subheadline.weight(.semibold))
                Text(item.note, language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Text(verbatim: "$" + item.price)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: scrollTabsRow - 6)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.stroke))
        .frame(height: scrollTabsRow, alignment: .top)
    }
}
