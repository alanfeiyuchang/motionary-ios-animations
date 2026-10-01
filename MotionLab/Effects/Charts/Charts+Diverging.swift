import SwiftUI

extension Effect {
    static let chartsDiverging = Effect(
        id: "charts.diverging",
        category: .charts,
        interaction: .tap,
        name: L("Diverging Sort", "发散条形排序"),
        summary: L("Bars grow left and right from a centre axis, then re-sort from best to worst with rows gliding past each other.", "条形从中轴向左右生长，随后按从高到低重排，各行相互滑过。"),
        prompt: L(
            "A year-over-year card: seven regions as 16 pt rows around a vertical centre axis, gains growing right in mint-green, losses growing left in coral-red, each with 5 pt outer corners and a square edge on the axis. The row label sits on the empty side of the axis and the signed percentage rides the bar tip. On appear the axis draws top to bottom in 0.3 s, then bars spring out from it one row at a time, 60 ms apart (response 0.5 s, damping 0.7, a visible overshoot). Tapping the sort chip re-orders the rows from best to worst: each row glides to its new slot on a spring delayed 40 ms per rank, so the stack fans into a clean staircase; tapping again restores the original order. Light haptic on sort. Clear, balanced and decisive.",
            "同比卡片：七个地区排成 16pt 高的行，围绕一条竖直中轴；增长向右生长为薄荷绿，下滑向左生长为珊瑚红，外端 5pt 圆角、贴轴一端平直。行标签放在中轴空着的一侧，带符号的百分比跟在条形末端。出现时中轴用 0.3 秒自上而下画出，随后条形逐行从轴上弹出，间隔 60ms（弹簧响应 0.5 秒、阻尼 0.7，有明显过冲）。点击排序按钮，各行按从高到低重排：每行以弹簧滑向新位置，并按名次延迟 40ms，整体展开成整齐的阶梯；再次点击恢复原始顺序。排序时轻触感。清晰、均衡、果断。"
        ),
        implementation: L(
            "Rows live in a ZStack and are placed with an offset from their rank, so a sort is just a new rank per row animated with a rank-delayed spring. Each bar is an UnevenRoundedRectangle whose width follows an Animatable growth value; the tip label reads the same interpolated value.",
            "各行放在 ZStack 中，按名次用 offset 定位，排序只是给每行一个新名次，并用按名次延迟的弹簧做动画。条形是 UnevenRoundedRectangle，宽度跟随 Animatable 的生长值，末端标签读取同一个插值。"
        ),
        apis: ["UnevenRoundedRectangle", "Animatable", "offset", "spring(response:dampingFraction:)", "ZStack"],
        tags: ["diverging", "centre axis", "sort", "positive negative", "发散条形", "中轴", "排序", "正负对比"],
        params: [
            .slider("stagger", L("Row stagger", "行间错峰"), 0...0.15, default: 0.06, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.45...1, default: 0.7),
        ]
    ) { ctx in
        DivergingDemo(ctx: ctx)
    }
}

private struct DivergingRow: Identifiable {
    let id: Int
    let label: LocalizedText
    let value: Double
}

private let divergingRows: [DivergingRow] = [
    DivergingRow(id: 0, label: L("Nordics", "北欧"), value: 12),
    DivergingRow(id: 1, label: L("Iberia", "伊比利亚"), value: -18),
    DivergingRow(id: 2, label: L("DACH", "德语区"), value: 24),
    DivergingRow(id: 3, label: L("Benelux", "比荷卢"), value: -7),
    DivergingRow(id: 4, label: L("France", "法国"), value: 31),
    DivergingRow(id: 5, label: L("Italy", "意大利"), value: -26),
    DivergingRow(id: 6, label: L("UK", "英国"), value: 5),
]

private struct DivergingDemo: View {
    let ctx: DemoContext
    @State private var grown = true
    @State private var axis: CGFloat = 1
    @State private var sorted = false
    @State private var run: Task<Void, Never>?

    private static let rowHeight: CGFloat = 16
    private static let rowGap: CGFloat = 9
    private static let half: CGFloat = 134

    private var ranks: [Int: Int] {
        let order = sorted ? divergingRows.sorted { $0.value > $1.value } : divergingRows
        var out: [Int: Int] = [:]
        for (rank, row) in order.enumerated() { out[row.id] = rank }
        return out
    }

    var body: some View {
        ChartStage(hint: L("Tap to sort and unsort", "点击切换排序"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 12) {
                header
                plot
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { toggleSort() }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                grown = false
                axis = 0
            }, then: { enter() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 2.2, delay: 2.0) { toggleSort() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Revenue vs last year", "营收同比"), ctx.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verbatim: "+3.0%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(sorted ? 180 : 0))
                Text(sorted ? L("Sorted", "已排序") : L("By region", "按地区"), ctx.language)
                    .font(.system(size: 12, weight: .semibold))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(sorted ? Color.white : Color.primary.opacity(0.75))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(sorted ? AnyShapeStyle(Palette.indigo) : AnyShapeStyle(Color.primary.opacity(0.07)), in: Capsule())
        }
    }

    private var plot: some View {
        let ranks = ranks
        let count = divergingRows.count
        let height = CGFloat(count) * Self.rowHeight + CGFloat(count - 1) * Self.rowGap
        return ZStack(alignment: .top) {
            Capsule()
                .fill(Color.primary.opacity(0.22))
                .frame(width: 1.5, height: (height + 12) * axis)
                .frame(height: height + 12, alignment: .top)
                .offset(y: -6)
            ForEach(divergingRows) { row in
                let rank = ranks[row.id] ?? row.id
                DivergingBar(
                    value: row.value,
                    grow: grown ? 1 : 0,
                    label: row.label(ctx.language),
                    half: Self.half,
                    height: Self.rowHeight
                )
                .offset(y: CGFloat(rank) * (Self.rowHeight + Self.rowGap))
                .animation(
                    .spring(response: ctx["response"], dampingFraction: ctx["damping"]).delay(Double(row.id) * ctx["stagger"]),
                    value: grown
                )
                .animation(
                    .spring(response: ctx["response"] * 1.1, dampingFraction: 0.78).delay(Double(rank) * 0.04),
                    value: sorted
                )
            }
        }
        .frame(width: Self.half * 2, height: height, alignment: .top)
    }

    private func enter() {
        withAnimation(.easeOut(duration: 0.3)) { axis = 1 }
        run?.cancel()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            grown = true
        }
    }

    private func toggleSort() {
        Haptics.tap(.light)
        grown = true
        withAnimation(.easeOut(duration: 0.2)) { axis = 1 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { sorted.toggle() }
    }
}

private struct DivergingBar: View, Animatable {
    let value: Double
    var grow: Double
    let label: String
    let half: CGFloat
    let height: CGFloat

    var animatableData: Double {
        get { grow }
        set { grow = newValue }
    }

    private static let scale: Double = 36

    var body: some View {
        let positive = value >= 0
        let full = half * 0.74 * CGFloat(abs(value) / Self.scale)
        let width = max(full * CGFloat(max(grow, 0)), 0)
        let colors: [Color] = positive ? [Palette.green, Palette.mint] : [Palette.coral, Palette.red]
        let shown = value * min(max(grow, 0), 1)
        let text = String(format: "%+.0f%%", shown).replacingOccurrences(of: "-", with: "−")
        let fade = ChartKit.smoothstep(0.25, 0.8, grow)
        return ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: positive ? 0 : 5,
                bottomLeadingRadius: positive ? 0 : 5,
                bottomTrailingRadius: positive ? 5 : 0,
                topTrailingRadius: positive ? 5 : 0,
                style: .continuous
            )
            .fill(LinearGradient(colors: colors, startPoint: positive ? .leading : .trailing, endPoint: positive ? .trailing : .leading))
            .frame(width: width, height: height)
            .offset(x: (positive ? 1 : -1) * (width / 2 + 0.75))

            Text(verbatim: text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(positive ? Palette.green : Palette.red)
                .fixedSize()
                .frame(width: 44, alignment: positive ? .leading : .trailing)
                .offset(x: (positive ? 1 : -1) * (width + 6 + 22))
                .opacity(fade)

            Text(verbatim: label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize()
                .frame(width: half - 10, alignment: positive ? .trailing : .leading)
                .offset(x: (positive ? -1 : 1) * (half - 10) / 2 + (positive ? -8 : 8))
        }
        .frame(width: half * 2, height: height)
    }
}
