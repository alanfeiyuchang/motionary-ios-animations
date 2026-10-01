import SwiftUI

extension Effect {
    static let scrollTimelineFill = Effect(
        id: "scroll.timeline-fill",
        category: .scroll,
        interaction: .scroll,
        name: L("Filling Timeline", "滚动填充时间线"),
        summary: L("A timeline whose rail fills up to a fixed focus line; each node pops, rings and lights its card the moment the fill reaches it.", "时间线的轨道一直填充到固定的焦点线；填充到达某个节点的瞬间，节点弹出、荡开一圈光环，并点亮它的卡片。"),
        prompt: L(
            "A vertical itinerary: a 3 pt rail on the left with a 22 pt node per entry and a card (time, title, note) beside each. A focus line sits at 55% of the viewport height. The rail's gradient fill is scrubbed by the scroll: it always ends exactly at the focus line, capped by a glowing 9 pt tip. When a node crosses the line it activates in time, not by scrubbing: the hollow ring fills with the gradient and its icon scales from 30% to 100% on a spring (0.35 s, damping 0.55), a ring expands to 2.4× and fades over 0.6 s, and its card slides 8 pt into place and goes from 45% to full opacity with a light haptic. The newest active card carries an accent outline. Scrolling back reverses each node at the same line, without the ring.",
            "纵向行程时间线：左侧 3 pt 粗的轨道上每个条目有一个 22 pt 节点，旁边是卡片。焦点线位于视口高度的 55%。轨道的渐变填充由滚动直接驱动，末端始终停在焦点线上，顶着一个发光的 9 pt 光点。节点越过焦点线时按时间被激活：空心圆环被渐变填满，图标以弹簧（0.35 秒、阻尼 0.55）从 30% 弹到 100%，一圈光环在 0.6 秒内扩大到 2.4 倍并淡出，卡片滑动 8 pt 归位、不透明度从 45% 升到 100%，并有一次轻触感。最新激活的卡片带强调色描边。往回滚动时各节点在同一条线上熄灭，不再荡出光环。"
        ),
        implementation: L(
            "Rows have a fixed pitch, so each node's content y is known. onScrollGeometryChange gives the offset and viewport height; the fill's height is offset + focus − first node, and a node is active when its y is above that line. The fill is plain geometry, while each row animates its own activation with a spring keyed to the Bool.",
            "行距固定，所以每个节点在内容里的 y 是已知的。onScrollGeometryChange 给出偏移量和视口高度；填充的高度是“偏移量 + 焦点位置 − 第一个节点”，节点的 y 在这条线之上即为激活。填充只是普通的几何计算，而每一行用一个以 Bool 为键的弹簧为自己的激活过程做动画。"
        ),
        apis: ["onScrollGeometryChange", "ScrollPosition", "animation(_:value:)", "spring(response:dampingFraction:)", "onScrollPhaseChange"],
        tags: ["timeline", "progress", "steps", "scroll driven", "itinerary", "时间线", "进度", "步骤", "滚动驱动", "行程"],
        params: [
            .slider("focus", L("Focus line", "焦点线位置"), 0.3...0.8, default: 0.55),
            .slider("damping", L("Pop damping", "弹出阻尼"), 0.35...1.0, default: 0.55),
            .toggle("dim", L("Dim upcoming", "未到条目变暗"), default: true),
        ]
    ) { ctx in
        ScrollTimelineDemo(ctx: ctx)
    }
}

private let scrollTimelineEntries: [(time: String, icon: String, title: LocalizedText, note: LocalizedText)] = [
    ("07:30", "cup.and.saucer.fill", L("Coffee and checklist", "咖啡和清单"), L("Last pass over the release notes", "把发布说明再过一遍")),
    ("08:15", "tram.fill", L("Tram to the studio", "坐电车去工作室"), L("Line 28, eleven stops", "28 路，十一站")),
    ("09:00", "person.3.fill", L("Stand-up", "站会"), L("Three blockers, none serious", "三个阻塞项，都不严重")),
    ("10:30", "hammer.fill", L("Final build", "最终构建"), L("Build 42 goes to review", "第 42 版提交审核")),
    ("12:00", "fork.knife", L("Lunch on the roof", "天台午餐"), L("Nobody mentions the launch", "谁都不提发布的事")),
    ("14:00", "checkmark.seal.fill", L("Approved", "审核通过"), L("Faster than anyone expected", "比所有人预想的都快")),
    ("16:00", "paperplane.fill", L("Release", "正式发布"), L("One button, a long breath", "按一下按钮，长出一口气")),
    ("17:30", "chart.line.uptrend.xyaxis", L("First numbers", "第一批数据"), L("Crash-free 99.8%", "无崩溃率 99.8%")),
    ("19:00", "party.popper.fill", L("Dinner with the team", "团队聚餐"), L("Phones face down", "手机全部扣在桌上")),
]

private let scrollTimelinePitch: CGFloat = 78
private let scrollTimelineTop: CGFloat = 16
/// A node's centre inside its row.
private let scrollTimelineNodeY: CGFloat = 22
private let scrollTimelineRailX: CGFloat = 26

private struct ScrollTimelineDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var viewport: CGFloat = 340
    @State private var position = ScrollPosition(edge: .top)
    @State private var userDriven = false
    @State private var down = false

    private var focusY: CGFloat { viewport * ctx.cg("focus") }

    /// Content y of the fill's end.
    private var line: CGFloat { offset + focusY }

    private func nodeY(_ i: Int) -> CGFloat {
        scrollTimelineTop + CGFloat(i) * scrollTimelinePitch + scrollTimelineNodeY
    }

    private var activeCount: Int {
        scrollTimelineEntries.indices.filter { nodeY($0) <= line }.count
    }

    var body: some View {
        let active = activeCount
        let damping = ctx["damping"]
        let dim = ctx.bool("dim")
        return ScrollView {
            ZStack(alignment: .topLeading) {
                rail
                VStack(spacing: 0) {
                    ForEach(scrollTimelineEntries.indices, id: \.self) { i in
                        ScrollTimelineRow(
                            index: i,
                            isActive: i < active,
                            isCurrent: i == active - 1,
                            damping: damping,
                            dim: dim,
                            language: ctx.language
                        )
                        .frame(height: scrollTimelinePitch, alignment: .top)
                    }
                }
                .padding(.top, scrollTimelineTop)
            }
            // Room for the last node to reach the focus line.
            .padding(.bottom, max(viewport - focusY - 40, 20))
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGSize.self, of: { geometry in
            CGSize(width: geometry.contentOffset.y + geometry.contentInsets.top, height: geometry.containerSize.height)
        }, action: { _, newValue in
            offset = newValue.width
            if newValue.height > 0 { viewport = newValue.height }
        })
        .onScrollPhaseChange { _, newPhase in
            userDriven = newPhase == .interacting || newPhase == .decelerating || newPhase == .tracking
        }
        .onChange(of: active) {
            if !ctx.isPreview && userDriven { Haptics.tap(.light) }
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.8) {
            down.toggle()
            withAnimation(.easeInOut(duration: 2.3)) {
                position.scrollTo(y: down ? 430 : 0)
            }
        }
    }

    /// Track, scrubbed fill and the glowing tip that rides the focus line.
    private var rail: some View {
        let first: CGFloat = nodeY(0)
        let length: CGFloat = CGFloat(scrollTimelineEntries.count - 1) * scrollTimelinePitch
        let filled: CGFloat = (line - first).clamped(to: 0...length)
        return ZStack(alignment: .top) {
            Capsule()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 3, height: length)
            Capsule()
                .fill(LinearGradient(colors: [Palette.indigo, Palette.violet, Palette.pink], startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: length)
                .mask(alignment: .top) { Rectangle().frame(height: filled) }
            Circle()
                .fill(Color.white)
                .frame(width: 9, height: 9)
                .shadow(color: Palette.pink.opacity(0.9), radius: 6)
                .shadow(color: Palette.violet.opacity(0.7), radius: 12)
                .offset(y: filled - 4.5)
                .opacity(filled > 0 && filled < length ? 1 : 0)
        }
        .frame(width: 22)
        .offset(x: scrollTimelineRailX - 11, y: first)
    }
}

private struct ScrollTimelineRow: View {
    let index: Int
    let isActive: Bool
    let isCurrent: Bool
    let damping: Double
    let dim: Bool
    let language: AppLanguage

    /// The ring that leaves the node on activation.
    @State private var ringOut = false

    var body: some View {
        let entry = scrollTimelineEntries[index]
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(alignment: .top, spacing: 14) {
            node(icon: entry.icon)
                .frame(width: 22, height: 22)
                .padding(.top, scrollTimelineNodeY - 11)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: entry.time)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(isActive ? AnyShapeStyle(Palette.violetText) : AnyShapeStyle(.secondary))
                    if isCurrent {
                        Text(L("Now", "现在"), language)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Palette.primaryStrong, in: Capsule())
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                Text(entry.title, language)
                    .font(.subheadline.weight(.semibold))
                Text(entry.note, language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: scrollTimelinePitch - 10)
            .background(Palette.elevated, in: shape)
            .overlay(shape.strokeBorder(isCurrent ? AnyShapeStyle(Palette.primary) : AnyShapeStyle(Palette.stroke), lineWidth: isCurrent ? 1.5 : 1))
            .shadow(color: Palette.indigo.opacity(isCurrent ? 0.22 : 0), radius: 10, y: 5)
            .opacity(isActive || !dim ? 1 : 0.45)
            .offset(x: isActive ? 0 : 8)
        }
        .padding(.leading, scrollTimelineRailX - 11)
        .padding(.trailing, 14)
        .animation(.spring(response: 0.35, dampingFraction: damping), value: isActive)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCurrent)
        .onChange(of: isActive) { _, nowActive in
            guard nowActive else { return }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { ringOut = false }
            withAnimation(.easeOut(duration: 0.6)) { ringOut = true }
        }
    }

    private func node(icon: String) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Palette.violet.opacity(0.7), lineWidth: 2)
                .scaleEffect(ringOut ? 2.4 : 1)
                .opacity(ringOut ? 0 : (isActive ? 0.7 : 0))
            Circle()
                .fill(Palette.stage)
            Circle()
                .strokeBorder(Color.primary.opacity(0.22), lineWidth: 2)
                .opacity(isActive ? 0 : 1)
            Circle()
                .fill(Palette.primary)
                .scaleEffect(isActive ? 1 : 0.2)
                .opacity(isActive ? 1 : 0)
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(isActive ? 1 : 0.3)
                .opacity(isActive ? 1 : 0)
        }
    }
}
