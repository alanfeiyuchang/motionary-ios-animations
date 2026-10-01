import SwiftUI

extension Effect {
    static let navigationFolderTabs = Effect(
        id: "navigation.folder-tabs",
        category: .navigation,
        interaction: .tap,
        name: L("Fluid Folder Tabs", "流体文件夹标签"),
        summary: L(
            "The active tab and the panel below are one surface joined by concave fillets; the tab slides and stretches as a single silhouette.",
            "当前标签与下方面板是同一块表面，以内凹圆角相连；切换时标签作为同一个轮廓滑动并拉伸。"
        ),
        prompt: L(
            "Three browser-style tabs sit on a recessed 300 pt track above a 190 pt content panel. The active tab is not a separate pill: tab and panel are one filled outline, the tab's 14 pt top corners flowing into the panel through two concave 12 pt fillets, with a single hairline and shadow wrapping the whole silhouette. Tapping another tab sends the tab part across: the edge facing the target moves on a spring (response 0.4 s, damping 0.74), the far edge on one 1.4× slower, so the tab stretches wide in transit and snaps back to 100 pt. At either end the outer fillet shrinks to nothing and the tab's side becomes the panel's side. Labels turn bold, the icon bounces, and panel rows slide in 28 pt from the travel direction, 45 ms apart, clearing from a 6 pt blur.",
            "三个浏览器式标签排在 300 pt 的内凹轨道上，下方是 190 pt 高的面板。当前标签与面板是同一个填充轮廓：标签顶部 14 pt 的圆角经两段 12 pt 的内凹圆角流入面板，细线与阴影包住整个外形。切换时标签部分滑过去：朝向目标的一侧以弹簧（响应 0.4 秒、阻尼 0.74）先行，另一侧慢 1.4 倍，标签在途中被拉宽，再弹回 100 pt。到两端时，外侧内凹圆角收缩到零，标签侧边与面板侧边连成一线。文字变为加粗主色，图标弹跳；面板各行从移动方向滑入 28 pt，相隔 45 毫秒，由 6 pt 模糊渐清。"
        ),
        implementation: L(
            "One Shape draws tab and panel as a single path, clamping the fillet radii to the distance from the panel's edge; two nested Animatable views interpolate the tab's leading and trailing x separately so each edge keeps its own spring.",
            "一个 Shape 把标签与面板画成同一条路径，并把内凹圆角半径钳制在到面板边缘的距离以内；两层嵌套的 Animatable 视图分别插值标签的前缘与后缘，使两条边各用各的弹簧。"
        ),
        apis: ["Shape", "Animatable", "addQuadCurve(to:control:)", "symbolEffect(.bounce)", "transition(.asymmetric)", "spring(response:dampingFraction:)"],
        tags: ["tabs", "folder", "browser tab", "concave corner", "标签页", "文件夹", "内凹圆角", "浏览器标签"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.8, default: 0.4, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.74),
            .slider("ear", L("Fillet radius", "内凹圆角"), 0...18, default: 12, decimals: 0, unit: "pt"),
            .slider("stretch", L("Far-edge lag", "后缘滞后"), 1.0...2.0, default: 1.4, unit: "×"),
        ]
    ) { ctx in
        FolderTabsDemo(ctx: ctx)
    }
}

private struct FolderTabRow {
    let symbol: String
    let title: LocalizedText
    let detail: LocalizedText
}

private struct FolderTab {
    let symbol: String
    let title: LocalizedText
    let color: Color
    let rows: [FolderTabRow]
}

private let folderTabs: [FolderTab] = [
    FolderTab(symbol: "note.text", title: L("Notes", "笔记"), color: Palette.amber, rows: [
        FolderTabRow(symbol: "text.alignleft", title: L("Launch checklist", "发布清单"), detail: L("9:41", "9:41")),
        FolderTabRow(symbol: "lightbulb.fill", title: L("Spring tuning ideas", "弹簧调参灵感"), detail: L("Mon", "周一")),
        FolderTabRow(symbol: "quote.opening", title: L("Interview quotes", "访谈摘录"), detail: L("Sep 12", "9月12日")),
    ]),
    FolderTab(symbol: "checklist", title: L("Tasks", "任务"), color: Palette.indigo, rows: [
        FolderTabRow(symbol: "checkmark.circle.fill", title: L("Record the trailer", "录制预告片"), detail: L("Done", "完成")),
        FolderTabRow(symbol: "circle", title: L("Polish tab motion", "打磨标签动效"), detail: L("Today", "今天")),
        FolderTabRow(symbol: "circle", title: L("Ship the web port", "上线网页版"), detail: L("Fri", "周五")),
    ]),
    FolderTab(symbol: "folder.fill", title: L("Files", "文件"), color: Palette.mint, rows: [
        FolderTabRow(symbol: "doc.richtext.fill", title: L("Prompt guide.pdf", "提示词指南.pdf"), detail: L("2.4 MB", "2.4 MB")),
        FolderTabRow(symbol: "photo.fill", title: L("Cover-final.png", "封面-终版.png"), detail: L("860 KB", "860 KB")),
        FolderTabRow(symbol: "film.fill", title: L("Trailer.mov", "预告片.mov"), detail: L("48 MB", "48 MB")),
    ]),
]

private enum FolderTabMetrics {
    static let width: CGFloat = 300
    static let stripHeight: CGFloat = 46
    static let panelHeight: CGFloat = 190
    static var slot: CGFloat { width / CGFloat(folderTabs.count) }
    static var height: CGFloat { stripHeight + panelHeight }
}

private struct FolderTabsDemo: View {
    let ctx: DemoContext
    @State private var selected = 0
    @State private var previous = 0
    @State private var lead: CGFloat = 0
    @State private var trail: CGFloat = FolderTabMetrics.slot
    @State private var bounces: [Int] = [0, 0, 0]
    @State private var autoForward = true

    var body: some View {
        VStack(spacing: 18) {
            card
            DemoHint(text: L("Tap a tab", "点击任一标签"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.3) { autoplayStep() }
    }

    private var card: some View {
        ZStack(alignment: .top) {
            // The recessed track the inactive tabs rest on; it shows through the fillets.
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .frame(height: FolderTabMetrics.stripHeight + 30)
            FolderLeadLayer(lead: lead, trail: trail, ear: ctx.cg("ear"))
            dividers
            labels
            panel
                .padding(.top, FolderTabMetrics.stripHeight)
        }
        .frame(width: FolderTabMetrics.width, height: FolderTabMetrics.height, alignment: .top)
    }

    private var labels: some View {
        HStack(spacing: 0) {
            ForEach(0..<folderTabs.count, id: \.self) { index in
                let isSelected: Bool = index == selected
                HStack(spacing: 6) {
                    Image(systemName: folderTabs[index].symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? folderTabs[index].color : Color.secondary)
                        .symbolEffect(.bounce, value: bounces[index])
                    Text(folderTabs[index].title, ctx.language)
                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                }
                .frame(width: FolderTabMetrics.slot, height: FolderTabMetrics.stripHeight)
                .contentShape(Rectangle())
                .onTapGesture { select(index) }
            }
        }
    }

    /// Hairlines between two inactive tabs only: the active tab's own outline separates it.
    private var dividers: some View {
        HStack(spacing: 0) {
            ForEach(1..<folderTabs.count, id: \.self) { index in
                let nextToActive: Bool = index == selected || index - 1 == selected
                Rectangle()
                    .fill(Color.primary.opacity(0.14))
                    .frame(width: 1, height: 18)
                    .opacity(nextToActive ? 0 : 1)
                    .frame(width: FolderTabMetrics.slot, height: FolderTabMetrics.stripHeight, alignment: .leading)
            }
        }
        .frame(width: FolderTabMetrics.width, height: FolderTabMetrics.stripHeight, alignment: .trailing)
        .allowsHitTesting(false)
    }

    private var panel: some View {
        let direction: CGFloat = selected >= previous ? 1 : -1
        return ZStack {
            FolderPanelRows(tab: folderTabs[selected], language: ctx.language, direction: direction, still: ctx.isStill)
                .id(selected)
                .transition(
                    .asymmetric(
                        insertion: .identity,
                        removal: .opacity
                    )
                )
        }
        .frame(width: FolderTabMetrics.width, height: FolderTabMetrics.panelHeight)
        .clipped()
    }

    private func autoplayStep() {
        var next = selected + (autoForward ? 1 : -1)
        if next >= folderTabs.count {
            autoForward = false
            next = selected - 1
        } else if next < 0 {
            autoForward = true
            next = selected + 1
        }
        select(next)
    }

    private func select(_ index: Int) {
        guard index != selected else { return }
        if !ctx.isPreview { Haptics.selection() }
        let goingRight: Bool = index > selected
        let response: Double = ctx["response"]
        let fast: Animation = .spring(response: response, dampingFraction: ctx["damping"])
        let slow: Animation = .spring(response: response * ctx["stretch"], dampingFraction: min(ctx["damping"] + 0.08, 1))
        let targetLead: CGFloat = CGFloat(index) * FolderTabMetrics.slot
        bounces[index] += 1
        withAnimation(.easeOut(duration: 0.22)) {
            previous = selected
            selected = index
        }
        withAnimation(goingRight ? fast : slow) { trail = targetLead + FolderTabMetrics.slot }
        withAnimation(goingRight ? slow : fast) { lead = targetLead }
    }
}

// MARK: - Silhouette

/// Interpolates only the tab's leading x, so its spring stays independent of the trailing edge's.
private struct FolderLeadLayer: View, Animatable {
    var lead: CGFloat
    let trail: CGFloat
    let ear: CGFloat

    var animatableData: CGFloat {
        get { lead }
        set { lead = newValue }
    }

    var body: some View {
        FolderTrailLayer(lead: lead, trail: trail, ear: ear)
    }
}

/// Interpolates the trailing x and draws tab + panel as one surface.
private struct FolderTrailLayer: View, Animatable {
    let lead: CGFloat
    var trail: CGFloat
    let ear: CGFloat

    var animatableData: CGFloat {
        get { trail }
        set { trail = newValue }
    }

    var body: some View {
        let shape = FolderSilhouette(lead: lead, trail: trail, ear: ear, stripHeight: FolderTabMetrics.stripHeight)
        shape
            .fill(Palette.elevated)
            .overlay(shape.stroke(Palette.stroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.12), radius: 16, y: 9)
            .frame(width: FolderTabMetrics.width, height: FolderTabMetrics.height)
    }
}

private struct FolderSilhouette: Shape {
    let lead: CGFloat
    let trail: CGFloat
    let ear: CGFloat
    let stripHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let tabCorner: CGFloat = 14
        let panelCorner: CGFloat = 22
        let join: CGFloat = rect.minY + stripHeight
        // A spring overshoot may push an edge past the panel: the silhouette never leaves the card.
        let left: CGFloat = min(max(lead, rect.minX), rect.maxX - tabCorner * 2)
        let right: CGFloat = max(min(trail, rect.maxX), left + tabCorner * 2)
        let leftEar: CGFloat = min(ear, max(left - rect.minX, 0))
        let rightEar: CGFloat = min(ear, max(rect.maxX - right, 0))
        let panelLeft: CGFloat = min(panelCorner, max(left - leftEar - rect.minX, 0))
        let panelRight: CGFloat = min(panelCorner, max(rect.maxX - right - rightEar, 0))

        var path = Path()
        path.move(to: CGPoint(x: left, y: join - leftEar))
        path.addLine(to: CGPoint(x: left, y: rect.minY + tabCorner))
        path.addQuadCurve(to: CGPoint(x: left + tabCorner, y: rect.minY), control: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: right - tabCorner, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: right, y: rect.minY + tabCorner), control: CGPoint(x: right, y: rect.minY))
        path.addLine(to: CGPoint(x: right, y: join - rightEar))
        path.addQuadCurve(to: CGPoint(x: right + rightEar, y: join), control: CGPoint(x: right, y: join))
        path.addLine(to: CGPoint(x: rect.maxX - panelRight, y: join))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: join + panelRight), control: CGPoint(x: rect.maxX, y: join))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - panelCorner))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - panelCorner, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + panelCorner, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - panelCorner), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: join + panelLeft))
        path.addQuadCurve(to: CGPoint(x: rect.minX + panelLeft, y: join), control: CGPoint(x: rect.minX, y: join))
        path.addLine(to: CGPoint(x: left - leftEar, y: join))
        path.addQuadCurve(to: CGPoint(x: left, y: join - leftEar), control: CGPoint(x: left, y: join))
        path.closeSubpath()
        return path
    }
}

// MARK: - Panel

private struct FolderPanelRows: View {
    let tab: FolderTab
    let language: AppLanguage
    let direction: CGFloat
    @State private var appeared: Bool

    init(tab: FolderTab, language: AppLanguage, direction: CGFloat, still: Bool) {
        self.tab = tab
        self.language = language
        self.direction = direction
        _appeared = State(initialValue: still)
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<tab.rows.count, id: \.self) { index in
                row(tab.rows[index])
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 28 * direction)
                    .blur(radius: appeared ? 0 : 6)
                    .animation(.spring(response: 0.42, dampingFraction: 0.8).delay(0.04 + Double(index) * 0.045), value: appeared)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: FolderTabMetrics.width, height: FolderTabMetrics.panelHeight)
        .onAppear { appeared = true }
    }

    private func row(_ item: FolderTabRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tab.color)
                .frame(width: 34, height: 34)
                .background(tab.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.title, language)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(item.detail, language)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 50)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
