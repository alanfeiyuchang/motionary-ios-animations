import SwiftUI

extension Effect {
    static let navigationSplitPane = Effect(
        id: "navigation.split-pane",
        category: .navigation,
        interaction: .gesture,
        name: L("Snapping Split Pane", "吸附式分栏"),
        summary: L(
            "Drag the divider between sidebar and detail: it snaps to three sizes, and both panes re-compose for the room they get instead of merely being squeezed.",
            "拖动侧栏与详情之间的分隔条：它会吸附到三种宽度，两侧内容按得到的空间重新编排，而不是单纯被挤压。"
        ),
        prompt: L(
            "A two-pane window with a draggable divider. The sidebar follows the finger 1:1 between 52 and 176 pt, rubber-banding beyond, and its content adapts continuously: below about 90 pt it is an icon rail; labels fade in between 72 and 104 pt; past 140 pt each row grows from 34 to 42 pt and reveals a subtitle and a count badge. The detail pane re-flows its six tiles by available width, three columns, then two, then a single-column list, each tile springing to its new slot as a threshold is crossed. While held, the divider's grip lengthens from 34 to 50 pt and takes the accent colour. On release the sidebar springs (response 0.45 s, damping 0.78) to the nearest of 52, 118 or 176 pt, biased by the flick, with a light haptic; tapping the grip steps to the next size.",
            "带可拖动分隔条的双栏窗口。侧栏在 52 到 176 pt 之间 1:1 跟手，超出进入橡皮筋，内容连续适应：约 90 pt 以下是纯图标栏；72 到 104 pt 之间文字渐显；超过 140 pt 后每行由 34 pt 长到 42 pt，并露出副标题与角标。详情栏六个色块按宽度重排，三列、两列、单列，每过一个阈值，色块以弹簧就位。按住时，把手从 34 pt 拉长到 50 pt 并染上强调色。松手后侧栏以弹簧（响应 0.45 秒、阻尼 0.78）吸附到 52、118、176 pt 中最近的一档，并受甩动影响，伴随轻触感；点击把手切到下一档。"
        ),
        implementation: L(
            "The sidebar width is the only state. Label and subtitle opacities and row height are smoothstep functions of it; tile frames are computed from a column count derived from the detail width, and animation(_:value:) on that count turns each threshold crossing into a sprung re-flow.",
            "侧栏宽度是唯一的状态。文字、副标题的透明度与行高都是它的 smoothstep 函数；色块的 frame 由「根据详情栏宽度得出的列数」计算，对该列数使用 animation(_:value:)，使每次越过阈值都成为一次弹簧重排。"
        ),
        apis: ["DragGesture", "predictedEndTranslation", "animation(_:value:)", "rubberBand", "spring(response:dampingFraction:)"],
        tags: ["split view", "divider", "resizable", "sidebar", "分栏", "分隔条", "可调整宽度", "侧栏"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.45, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.78),
            .slider("band", L("Rubber band", "橡皮筋范围"), 0...60, default: 30, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        SplitPaneDemo(ctx: ctx)
    }
}

private struct SplitSection {
    let symbol: String
    let title: LocalizedText
    let subtitle: LocalizedText
    let count: Int
    let color: Color
}

private let splitSections: [SplitSection] = [
    SplitSection(symbol: "tray.full.fill", title: L("All", "全部"), subtitle: L("Everything", "所有项目"), count: 24, color: Palette.indigo),
    SplitSection(symbol: "photo.fill", title: L("Images", "图片"), subtitle: L("Shots & art", "截图与插画"), count: 12, color: Palette.pink),
    SplitSection(symbol: "doc.text.fill", title: L("Docs", "文档"), subtitle: L("Notes & specs", "笔记与规格"), count: 7, color: Palette.mint),
    SplitSection(symbol: "film.fill", title: L("Clips", "视频"), subtitle: L("Recordings", "录屏片段"), count: 5, color: Palette.amber),
]

private enum SplitMetrics {
    static let frame = CGSize(width: 300, height: 252)
    static let snaps: [CGFloat] = [52, 118, 176]
    static let divider: CGFloat = 14
    static let tiles = 6

    static func smooth(_ value: CGFloat, _ from: CGFloat, _ to: CGFloat) -> CGFloat {
        let t: CGFloat = min(max((value - from) / (to - from), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

private struct SplitPaneDemo: View {
    let ctx: DemoContext
    @State private var sidebar: CGFloat = SplitMetrics.snaps[1]
    @State private var dragStart: CGFloat?
    /// Set when a drag began away from the divider, so the rest of that drag is ignored.
    @State private var dragRejected = false
    @State private var selection = 0
    @State private var autoStep = 0

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var detailWidth: CGFloat { SplitMetrics.frame.width - sidebar - SplitMetrics.divider }
    private var columns: Int { detailWidth > 200 ? 3 : (detailWidth > 130 ? 2 : 1) }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                sidebarPane
                    .frame(width: max(sidebar, 30))
                divider
                detailPane
                    .frame(width: max(detailWidth, 40))
            }
            .frame(width: SplitMetrics.frame.width, height: SplitMetrics.frame.height, alignment: .leading)
            // The drag lives on the window, which does not move, and only engages when it starts on the divider.
            .contentShape(Rectangle())
            .pageSafeHorizontalDrag(minimumDistance: 4, onChanged: dragChanged, onEnded: dragEnded)
            .background(Palette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.stroke))
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
            DemoHint(text: L("Drag the divider, or tap its grip", "拖动分隔条，或点击把手"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.4) { autoplayStep() }
    }

    // MARK: Sidebar

    private var sidebarPane: some View {
        let labels: CGFloat = SplitMetrics.smooth(sidebar, 72, 104)
        let wide: CGFloat = SplitMetrics.smooth(sidebar, 140, 172)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<splitSections.count, id: \.self) { index in
                sidebarRow(index, labels: labels, wide: wide)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 2)
        .padding(.top, 12)
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.035))
        .clipped()
    }

    private func sidebarRow(_ index: Int, labels: CGFloat, wide: CGFloat) -> some View {
        let section: SplitSection = splitSections[index]
        let active: Bool = selection == index
        return HStack(spacing: 9) {
            Image(systemName: section.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(active ? Color.white : section.color)
                .frame(width: 28, height: 28)
                .background(section.color.opacity(active ? 1 : 0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(section.title, ctx.language)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primary)
                if wide > 0.01 {
                    Text(section.subtitle, ctx.language)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .opacity(Double(wide))
                        .frame(height: 12 * wide, alignment: .top)
                }
            }
            .lineLimit(1)
            .fixedSize()
            .opacity(Double(labels))
            Spacer(minLength: 0)
            Text(verbatim: "\(section.count)")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .frame(height: 18)
                .background(Color.primary.opacity(0.08), in: Capsule())
                .fixedSize()
                .opacity(Double(wide))
                .scaleEffect(0.6 + 0.4 * wide)
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(height: 34 + 8 * wide)
        // minWidth 0 lets the row be narrower than its fixed-size labels, which then clip at the trailing edge.
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(active ? 0.07 * Double(labels) : 0), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if !ctx.isPreview { Haptics.selection() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = index }
        }
    }

    // MARK: Divider

    private var divider: some View {
        let held: Bool = dragStart != nil
        return ZStack {
            Rectangle()
                .fill(held ? Palette.indigo.opacity(0.5) : Color.primary.opacity(0.1))
                .frame(width: held ? 2 : 1)
            Capsule()
                .fill(held ? Palette.indigo : Color.primary.opacity(0.3))
                .frame(width: held ? 6 : 5, height: held ? 50 : 34)
                .shadow(color: Palette.indigo.opacity(held ? 0.5 : 0), radius: 6)
        }
        .frame(width: SplitMetrics.divider)
        .frame(maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: held)
        // A wider invisible strip makes the divider easy to grab.
        .overlay {
            Color.clear
                .frame(width: 34)
                .contentShape(Rectangle())
                .onTapGesture { step() }
        }
        .zIndex(1)
    }

    // MARK: Detail

    private var detailPane: some View {
        let section: SplitSection = splitSections[selection]
        let width: CGFloat = max(detailWidth, 40) - 20
        let height: CGFloat = SplitMetrics.frame.height - 58
        let count: Int = columns
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(section.title, ctx.language)
                    .font(.headline)
                    .fixedSize()
                    .id(selection)
                    .transition(.blurReplace)
                Spacer(minLength: 0)
                Image(systemName: count == 1 ? "list.bullet" : (count == 2 ? "square.grid.2x2.fill" : "square.grid.3x2.fill"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(height: 22)
            ZStack(alignment: .topLeading) {
                ForEach(0..<SplitMetrics.tiles, id: \.self) { index in
                    let rect: CGRect = tileRect(index, columns: count, width: width, height: height)
                    tile(index, color: section.color, list: count == 1)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .animation(spring, value: count)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.top, 14)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func tileRect(_ index: Int, columns: Int, width: CGFloat, height: CGFloat) -> CGRect {
        let gap: CGFloat = 7
        let rows: Int = Int((Double(SplitMetrics.tiles) / Double(columns)).rounded(.up))
        let w: CGFloat = (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let h: CGFloat = (height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        let column: Int = index % columns
        let row: Int = index / columns
        return CGRect(x: CGFloat(column) * (w + gap), y: CGFloat(row) * (h + gap), width: max(w, 10), height: max(h, 10))
    }

    private func tile(_ index: Int, color: Color, list: Bool) -> some View {
        RoundedRectangle(cornerRadius: list ? 9 : 13, style: .continuous)
            .fill(color.opacity(0.9 - Double(index) * 0.11).gradient)
            .overlay(alignment: list ? .leading : .bottomLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: list ? 44 : 26, height: 5)
                    .padding(list ? 10 : 8)
            }
    }

    // MARK: Actions

    private func dragChanged(_ value: DragGesture.Value) {
        guard !dragRejected else { return }
        let start: CGFloat = dragStart ?? sidebar
        if dragStart == nil {
            guard abs(value.startLocation.x - (sidebar + SplitMetrics.divider / 2)) < 24 else {
                dragRejected = true
                return
            }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { dragStart = sidebar }
        }
        let low: CGFloat = SplitMetrics.snaps[0]
        let high: CGFloat = SplitMetrics.snaps[SplitMetrics.snaps.count - 1]
        var width: CGFloat = start + value.translation.width
        let band: CGFloat = max(ctx.cg("band"), 1)
        if width < low { width = low - rubberBand(low - width, limit: band * 0.6) }
        if width > high { width = high + rubberBand(width - high, limit: band) }
        sidebar = width
    }

    private func dragEnded(_ value: DragGesture.Value?) {
        dragRejected = false
        guard let start = dragStart else { return }
        let projected: CGFloat = value.map { start + $0.predictedEndTranslation.width } ?? sidebar
        let target: CGFloat = SplitMetrics.snaps.min(by: { abs($0 - projected) < abs($1 - projected) }) ?? sidebar
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(spring) {
            dragStart = nil
            sidebar = target
        }
    }

    /// Tap on the grip: go to the next snap size (wrapping round).
    private func step() {
        guard dragStart == nil else { return }
        let current: Int = nearestSnap()
        settle((current + 1) % SplitMetrics.snaps.count)
    }

    private func nearestSnap() -> Int {
        var best: Int = 0
        for index in SplitMetrics.snaps.indices where abs(SplitMetrics.snaps[index] - sidebar) < abs(SplitMetrics.snaps[best] - sidebar) {
            best = index
        }
        return best
    }

    private func settle(_ index: Int) {
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(spring) { sidebar = SplitMetrics.snaps[index] }
    }

    private func autoplayStep() {
        let tour: [Int] = [2, 1, 0, 1]
        settle(tour[autoStep % tour.count])
        autoStep += 1
    }
}
