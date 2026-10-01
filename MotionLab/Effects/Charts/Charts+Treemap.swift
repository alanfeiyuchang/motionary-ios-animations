import SwiftUI

extension Effect {
    static let chartsTreemap = Effect(
        id: "charts.treemap",
        category: .charts,
        interaction: .state,
        name: L("Treemap Re-layout", "矩形树图重排"),
        summary: L("Switch the metric and every tile springs to its new rectangle, largest first, while labels scale and fade to fit.", "切换指标后，每块矩形按面积从大到小依次弹向新位置，标签随之缩放、淡入淡出以适配。"),
        prompt: L(
            "A squarified treemap of seven business lines in fixed colours, 4 pt gaps and 10 pt continuous corners, above a three-way metric switch (Revenue · Users · Growth) with a sliding thumb. Changing the metric recomputes the layout and every tile springs to its new frame (response 0.6 s, damping 0.78), staggered 35 ms from the largest tile to the smallest, so the big blocks claim their space first and the small ones tuck in around them. Inside each tile the name and value scale with the tile from the top-left corner (55% to 125%), the value rolls with a numeric transition, and a label fades out when its tile becomes too small to hold it. Tapping a tile lifts it 4% with a shadow and dims the others to 45%. Dense, orderly and easy to follow.",
            "七条业务线的矩形树图（squarified 布局），颜色固定、间隙 4pt、10pt 连续圆角，下方是带滑块的三段指标切换（营收 · 用户 · 增长）。切换指标时重新计算布局，每块矩形以弹簧（响应 0.6 秒、阻尼 0.78）弹向新的位置与尺寸，按面积从大到小错开 35 毫秒——大块先占位，小块随后嵌入四周。块内的名称与数值以左上角为锚点随矩形缩放（55% 至 125%），数值以数字转场滚动；当矩形小到放不下时，标签自动淡出。点击某一块会将其抬起 4% 并投下阴影，其余压暗到 45%。密集而有序。"
        ),
        implementation: L(
            "A squarify pass turns the current metric into rectangles; each tile is one view placed with frame + position, so changing the metric inside withAnimation tweens size and centre, with a per-tile delay from its area rank. Label scale and opacity derive from the tile size.",
            "squarify 算法把当前指标转换成一组矩形；每块是一个用 frame + position 摆放的视图，在 withAnimation 中切换指标即可补间尺寸与中心点，延迟由面积名次决定。标签的缩放与不透明度由矩形尺寸推出。"
        ),
        apis: ["position", "frame", "Animation.delay", "matchedGeometryEffect", "contentTransition(.numericText)", "spring(response:dampingFraction:)"],
        tags: ["treemap", "layout animation", "squarify", "metric switch", "矩形树图", "布局动画", "指标切换", "占比"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1.2, default: 0.6, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.78),
            .slider("stagger", L("Stagger", "错峰间隔"), 0...0.1, default: 0.035, unit: "s"),
            .slider("gap", L("Tile gap", "块间隙"), 2...8, default: 4, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        TreemapDemo(ctx: ctx)
    }
}

private struct TreemapItem {
    let name: LocalizedText
    let color: Color
    /// Revenue ($M), users (M), growth (%).
    let values: [Double]
}

private let treemapItems: [TreemapItem] = [
    TreemapItem(name: L("Cloud", "云服务"), color: Color(hex: 0x4F6FF5), values: [34, 10, 8]),
    TreemapItem(name: L("Ads", "广告"), color: Color(hex: 0x7A5CF0), values: [22, 30, 5]),
    TreemapItem(name: L("Devices", "硬件"), color: Color(hex: 0xB04FD8), values: [16, 6, 3]),
    TreemapItem(name: L("Subs", "订阅"), color: Color(hex: 0xE0508F), values: [12, 18, 20]),
    TreemapItem(name: L("Games", "游戏"), color: Color(hex: 0xF0683C), values: [8, 24, 12]),
    TreemapItem(name: L("Pay", "支付"), color: Color(hex: 0x12A886), values: [5, 8, 30]),
    TreemapItem(name: L("Other", "其他"), color: Color(hex: 0x2A93D5), values: [3, 4, 22]),
]

private let treemapMetrics: [LocalizedText] = [L("Revenue", "营收"), L("Users", "用户"), L("Growth", "增长")]

private func treemapFormat(_ value: Double, metric: Int) -> String {
    switch metric {
    case 0: return "$\(Int(value.rounded()))M"
    case 1: return "\(Int(value.rounded()))M"
    default: return "+\(Int(value.rounded()))%"
    }
}

/// Squarified treemap (Bruls, Huizing, van Wijk): returns one rect per value, in the input order.
private func squarify(_ values: [Double], in bounds: CGRect) -> [CGRect] {
    let total = values.reduce(0, +)
    guard total > 0, bounds.width > 0, bounds.height > 0 else { return values.map { _ in .zero } }
    let scale = Double(bounds.width * bounds.height) / total
    let order = values.indices.sorted { values[$0] > values[$1] }
    var rects = [CGRect](repeating: .zero, count: values.count)
    var free = bounds
    var row: [Int] = []

    func area(_ index: Int) -> Double { values[index] * scale }

    func worst(_ row: [Int], side: Double) -> Double {
        let sum = row.reduce(0.0) { $0 + area($1) }
        guard sum > 0, side > 0 else { return .infinity }
        let largest = row.map(area).max() ?? 0
        let smallest = row.map(area).min() ?? 0
        return max(side * side * largest / (sum * sum), sum * sum / (side * side * max(smallest, 0.0001)))
    }

    func place(_ row: [Int]) {
        let sum = row.reduce(0.0) { $0 + area($1) }
        guard sum > 0 else { return }
        if free.width >= free.height {
            let width = CGFloat(sum) / free.height
            var y = free.minY
            for index in row {
                let height = CGFloat(area(index)) / width
                rects[index] = CGRect(x: free.minX, y: y, width: width, height: height)
                y += height
            }
            free = CGRect(x: free.minX + width, y: free.minY, width: max(free.width - width, 0), height: free.height)
        } else {
            let height = CGFloat(sum) / free.width
            var x = free.minX
            for index in row {
                let width = CGFloat(area(index)) / height
                rects[index] = CGRect(x: x, y: free.minY, width: width, height: height)
                x += width
            }
            free = CGRect(x: free.minX, y: free.minY + height, width: free.width, height: max(free.height - height, 0))
        }
    }

    var cursor = 0
    while cursor < order.count {
        let side = Double(min(free.width, free.height))
        let candidate = row + [order[cursor]]
        if row.isEmpty || worst(candidate, side: side) <= worst(row, side: side) {
            row = candidate
            cursor += 1
        } else {
            place(row)
            row = []
        }
    }
    place(row)
    return rects
}

private struct TreemapDemo: View {
    let ctx: DemoContext
    @State private var metric = 0
    @State private var focus: Int?
    @State private var entrance: Double = 1
    @Namespace private var ns

    private let mapSize = CGSize(width: 268, height: 164)

    var body: some View {
        let values = treemapItems.map { $0.values[metric] }
        let rects = squarify(values, in: CGRect(origin: .zero, size: mapSize))
        let order = values.indices.sorted { values[$0] > values[$1] }
        let total = values.reduce(0, +)
        ChartStage(hint: L("Switch the metric, or tap a tile", "切换指标，或点击某一块"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ctx.language == .zh ? "业务构成" : "Business mix")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(verbatim: treemapFormat(metric == 2 ? total / Double(values.count) : total, metric: metric))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: total))
                }
                ZStack(alignment: .topLeading) {
                    ForEach(treemapItems.indices, id: \.self) { index in
                        tile(index, rect: rects[index], rank: order.firstIndex(of: index) ?? 0)
                    }
                }
                .frame(width: mapSize.width, height: mapSize.height, alignment: .topLeading)
                picker
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: { entrance = 0 }, then: {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.76)) { entrance = 1 }
            })
        }
        .autoplay(ctx.isPreview, every: 1.9, delay: 1.4) { select((metric + 1) % treemapMetrics.count) }
    }

    private func tile(_ index: Int, rect: CGRect, rank: Int) -> some View {
        let item = treemapItems[index]
        let gap = ctx.cg("gap")
        let width = max(rect.width - gap, 1)
        let height = max(rect.height - gap, 1)
        let scale = min(max(min(width / 80, height / 50), 0.55), 1.25)
        let showName = width > 30 && height > 20
        let showValue = width > 40 && height > 38
        let isFocus = focus == index
        let dimmed = focus != nil && !isFocus
        // Entrance: tiles scale up from the map's centre, largest first.
        let appear = ChartKit.smoothstep(0, 1, entrance * 1.6 - Double(rank) * 0.1)
        return RoundedRectangle(cornerRadius: min(10, min(width, height) / 2), style: .continuous)
            .fill(LinearGradient(colors: [item.color, item.color.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name, ctx.language)
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(showName ? 0.92 : 0)
                    Text(verbatim: treemapFormat(item.values[metric], metric: metric))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: item.values[metric]))
                        .opacity(showValue ? 1 : 0)
                }
                .foregroundStyle(.white)
                .fixedSize()
                .scaleEffect(scale, anchor: .topLeading)
                .padding(.leading, 8 * scale)
                .padding(.top, 7 * scale)
            }
            .clipShape(RoundedRectangle(cornerRadius: min(10, min(width, height) / 2), style: .continuous))
            .shadow(color: .black.opacity(isFocus ? 0.3 : 0), radius: 10, y: 6)
            .frame(width: width, height: height)
            .scaleEffect((isFocus ? 1.04 : 1) * CGFloat(0.4 + 0.6 * appear))
            .opacity(dimmed ? 0.45 : appear)
            .position(x: rect.midX, y: rect.midY)
            .zIndex(isFocus ? 1 : 0)
            .animation(.spring(response: ctx["response"], dampingFraction: ctx["damping"]).delay(Double(rank) * ctx["stagger"]), value: metric)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: focus)
            .onTapGesture {
                Haptics.tap(.light)
                focus = isFocus ? nil : index
            }
    }

    private var picker: some View {
        HStack(spacing: 4) {
            ForEach(treemapMetrics.indices, id: \.self) { index in
                Button {
                    select(index)
                } label: {
                    Text(treemapMetrics[index], ctx.language)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(index == metric ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            if index == metric {
                                Capsule()
                                    .fill(Palette.elevated)
                                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                                    .matchedGeometryEffect(id: "thumb", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    /// The switch and autoplay share this. The thumb and total move here; each tile adds its own delay.
    private func select(_ index: Int) {
        guard index != metric else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            metric = index
            focus = nil
        }
    }
}
