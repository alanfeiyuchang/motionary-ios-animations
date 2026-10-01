import SwiftUI

extension Effect {
    static let chartsBarDrilldown = Effect(
        id: "charts.bar-drilldown",
        category: .charts,
        interaction: .tap,
        name: L("Bar Drill-Down", "柱状图下钻"),
        summary: L("Tap a quarter: its stacked bar splits into three month bars that spread across the plot while the scale re-fits.", "点击某个季度：堆叠柱拆成三根月份柱并铺满图表，坐标刻度随之重新适配。"),
        prompt: L(
            "A yearly sales card with four quarter bars, each 34 pt wide and built from three stacked month segments in indigo-to-violet shades. Tapping a quarter drills into it: the other three bars slide 26 pt outward and fade in 0.3 s, then the tapped bar comes apart, its segments leaving one after another, 70 ms apart, each dropping to the baseline, widening to 44 pt and travelling to its own third of the plot on a spring (response 0.55 s, damping 0.76). The value scale re-fits too: the 100 / 200 grid lines rise out of the frame as 25 / 50 / 75 lines flow in from below. The header figure rolls to the quarter total and the breadcrumb gains a chevron and the quarter name. Tapping again re-stacks the months in reverse and brings the neighbours back. Feels like zooming into the data, not swapping charts.",
            "年度销售卡片：四根 34pt 宽的季度柱，各由三段月份堆叠而成，靛蓝到紫色渐变。点击某季度即下钻：其余三柱用 0.3 秒向外滑开 26pt 并淡出，被点的柱随后拆开，三段间隔 70ms 依次离开，落到基线、加宽到 44pt，并以弹簧（响应 0.55 秒、阻尼 0.76）移到图表的三分之一处。刻度同时重新适配：100 / 200 网格线向上移出，25 / 50 / 75 网格线从下方流入。标题数字滚动为季度合计，面包屑多出箭头与季度名。再次点击，月份按相反顺序叠回，邻柱归位。像推近数据，而不是换一张图。"
        ),
        implementation: L(
            "One Animatable Canvas draws every segment by interpolating between its stacked rectangle and its drilled rectangle with a per-month progress (a ChartVector stepped by a cancellable Task); a second value moves the neighbours away and blends the two grid scales.",
            "一个 Animatable Canvas 按每个月份的进度，在“堆叠矩形”和“下钻矩形”之间插值绘制每一段（ChartVector 由可取消的 Task 逐段推进）；另一个值负责把邻柱推开，并混合两套网格刻度。"
        ),
        apis: ["Animatable", "Canvas", "VectorArithmetic", "SpatialTapGesture", "spring(response:dampingFraction:)"],
        tags: ["drill down", "expand", "zoom", "hierarchy", "下钻", "展开", "层级", "季度月份"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.9, default: 0.55, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1, default: 0.76),
            .slider("stagger", L("Segment stagger", "分段错峰"), 0...0.2, default: 0.07, unit: "s"),
        ]
    ) { ctx in
        BarDrilldownDemo(ctx: ctx)
    }
}

private let drillMonths: [[Double]] = [[42, 38, 51], [55, 61, 48], [66, 72, 59], [58, 80, 91]]
private let drillMonthNamesEN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

private func drillTotal(_ quarter: Int) -> Double { drillMonths[quarter].reduce(0, +) }
private let drillYearTotal: Double = (0..<4).reduce(0) { $0 + drillTotal($1) }

private struct BarDrilldownDemo: View {
    let ctx: DemoContext
    @State private var grow = ChartVector(repeating: 1, count: 4)
    @State private var open = ChartVector(repeating: 0, count: 3)
    @State private var away: Double = 0
    @State private var selected = 2
    @State private var drilled = false
    @State private var shown: Double = drillYearTotal
    @State private var autoStep = 0
    @State private var run: Task<Void, Never>?

    private let plotWidth: CGFloat = 268

    var body: some View {
        ChartStage(hint: L("Tap a bar to drill in, tap again to go back", "点击柱子下钻，再点一次返回"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 10) {
                header
                BarDrilldownPlot(grow: grow, open: open, away: away, selected: selected, language: ctx.language)
                    .frame(width: plotWidth, height: 178)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in tap(at: value.location.x) })
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                grow = ChartVector(repeating: 0, count: 4)
                shown = 0
            }, then: { enter() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 2.0, delay: 1.6) { auto() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(L("Sales 2025", "2025 销售额"), ctx.language)
                    if drilled {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .transition(.opacity.combined(with: .offset(x: -6)))
                        Text(verbatim: "Q\(selected + 1)")
                            .foregroundStyle(Palette.indigo)
                            .transition(.opacity.combined(with: .offset(x: -8)))
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                ChartRollText(value: shown) { "$\(Int($0.rounded()))k" }
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: drilled ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                Text(drilled ? L("Months", "月份") : L("Quarters", "季度"), ctx.language)
                    .contentTransition(.opacity)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(drilled ? Palette.indigo : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((drilled ? Palette.indigo : Color.primary).opacity(drilled ? 0.14 : 0.06), in: Capsule())
        }
    }

    private func enter() {
        withAnimation(.easeOut(duration: 0.8)) { shown = drillYearTotal }
        run?.cancel()
        run = chartSequence(steps: 4, gap: 0.08) { step in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { grow[step] = 1 }
        }
    }

    private func tap(at x: CGFloat) {
        if drilled {
            collapse()
        } else {
            drill(min(max(Int((x - BarDrilldownPlot.inset) / ((plotWidth - BarDrilldownPlot.inset) / 4)), 0), 3))
        }
    }

    private func auto() {
        if drilled {
            collapse()
        } else {
            drill([2, 0, 3, 1][autoStep % 4])
            autoStep += 1
        }
    }

    private func drill(_ quarter: Int) {
        Haptics.tap(.light)
        let response = ctx["response"]
        let damping = ctx["damping"]
        let stagger = ctx["stagger"]
        run?.cancel()
        chartInstant {
            selected = quarter
            grow = ChartVector(repeating: 1, count: 4)
            open = ChartVector(repeating: 0, count: 3)
        }
        withAnimation(.easeOut(duration: 0.3)) { away = 1 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { drilled = true }
        withAnimation(.easeInOut(duration: 0.5)) { shown = drillTotal(quarter) }
        run = chartSequence(steps: 3, gap: stagger, first: 0.12) { step in
            // The top segment leaves first.
            withAnimation(.spring(response: response, dampingFraction: damping)) { open[2 - step] = 1 }
            if !ctx.isPreview { Haptics.tap(.soft) }
        }
    }

    private func collapse() {
        Haptics.tap(.light)
        let response = ctx["response"]
        let stagger = ctx["stagger"]
        run?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { drilled = false }
        withAnimation(.easeInOut(duration: 0.5)) { shown = drillYearTotal }
        run = Task { @MainActor in
            for step in 0..<3 {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: response * 0.9, dampingFraction: 0.86)) { open[step] = 0 }
                if stagger > 0 { try? await Task.sleep(for: .seconds(stagger)) }
            }
            try? await Task.sleep(for: .seconds(0.1))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { away = 0 }
        }
    }
}

private struct BarDrilldownPlot: View, Animatable {
    var grow: ChartVector
    var open: ChartVector
    var away: Double
    let selected: Int
    let language: AppLanguage

    var animatableData: AnimatablePair<ChartVector, AnimatablePair<ChartVector, Double>> {
        get { AnimatablePair(grow, AnimatablePair(open, away)) }
        set {
            grow = newValue.first
            open = newValue.second.first
            away = newValue.second.second
        }
    }

    private static let quarterWidth: CGFloat = 34
    private static let monthWidth: CGFloat = 44
    private static let overviewTop: Double = 260
    private static let slide: CGFloat = 26
    /// Room on the left for the grid values.
    static let inset: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            draw(in: context, size: size)
        }
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let plot = CGRect(x: 0, y: 18, width: size.width, height: size.height - 18 - 20)
        let months = drillMonths[selected]
        let detailTop = (months.max() ?? 1) * 1.22
        let mix = min(max(away, 0), 1)
        let zoom = (open[0] + open[1] + open[2]) / 3
        let top = Self.overviewTop + (detailTop - Self.overviewTop) * min(max(zoom, 0), 1)

        // Two grid scales share the interpolated top, so the lines travel as the scale re-fits.
        func rule(_ value: Double, alpha: Double) {
            let lineY = plot.maxY - plot.height * CGFloat(value / top)
            guard lineY > plot.minY - 12, alpha > 0.01 else { return }
            var line = Path()
            line.move(to: CGPoint(x: 0, y: lineY))
            line.addLine(to: CGPoint(x: plot.maxX, y: lineY))
            context.stroke(line, with: .color(.primary.opacity(0.07 * alpha)), lineWidth: 1)
            var layer = context
            layer.opacity = alpha
            layer.draw(
                Text(verbatim: "\(Int(value))").font(.system(size: 9, weight: .medium)).foregroundStyle(Color.secondary.opacity(0.8)),
                at: CGPoint(x: 0, y: lineY - 2),
                anchor: .bottomLeading
            )
        }
        let detailAlpha = min(max(zoom, 0), 1)
        for value in [100.0, 200.0] { rule(value, alpha: 1 - detailAlpha) }
        for value in [25.0, 50.0, 75.0] { rule(value, alpha: detailAlpha) }
        var base = Path()
        base.move(to: CGPoint(x: 0, y: plot.maxY))
        base.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(base, with: .color(.primary.opacity(0.16)), lineWidth: 1)

        let slot = (plot.width - Self.inset) / 4
        let shades: [ChartRGB] = [ChartRGB.indigo, ChartRGB.indigo.mixed(.violet, 0.5), ChartRGB.violet]

        for quarter in 0..<4 {
            let centerX = Self.inset + slot * (CGFloat(quarter) + 0.5)
            let g = CGFloat(max(grow[quarter], 0))
            if quarter != selected {
                let direction: CGFloat = quarter < selected ? -1 : 1
                var layer = context
                layer.opacity = 1 - mix
                layer.translateBy(x: direction * Self.slide * CGFloat(mix), y: 0)
                var bottom = plot.maxY
                for month in 0..<3 {
                    let height = plot.height * CGFloat(drillMonths[quarter][month] / Self.overviewTop) * g
                    let rect = CGRect(x: centerX - Self.quarterWidth / 2, y: bottom - height + 1, width: Self.quarterWidth, height: max(height - 1, 0))
                    fill(layer, rect, radius: min(3, rect.height / 2), tone: shades[month])
                    bottom -= height
                }
                label(layer, "\(Int(drillTotal(quarter)))", x: centerX, y: bottom - 3, alpha: Double(min(g, 1)), bold: true)
                label(layer, "Q\(quarter + 1)", x: centerX, y: plot.maxY + 6, alpha: 1, bold: false, top: true)
                continue
            }

            var stacked = 0.0
            for month in 0..<3 {
                let value = months[month]
                let p = open[month]
                let fromHeight = plot.height * CGFloat(value / Self.overviewTop) * g
                let fromBottom = plot.maxY - plot.height * CGFloat(stacked / Self.overviewTop) * g
                let toHeight = plot.height * CGFloat(value / detailTop)
                let toCenter = Self.inset + (plot.width - Self.inset) / 3 * (CGFloat(month) + 0.5)
                let width = ChartKit.lerp(Self.quarterWidth, Self.monthWidth, p)
                let midX = ChartKit.lerp(centerX, toCenter, p)
                let height = max(ChartKit.lerp(fromHeight - 1, toHeight, p), 0)
                let bottom = ChartKit.lerp(fromBottom, plot.maxY, p)
                let rect = CGRect(x: midX - width / 2, y: bottom - height, width: width, height: height)
                let radius = min(ChartKit.lerp(3, 6, min(max(p, 0), 1)), rect.height / 2)
                fill(context, rect, radius: radius, tone: shades[month])
                let shownAlpha = ChartKit.smoothstep(0.55, 1, p)
                label(context, "\(Int(value))", x: midX, y: rect.minY - 3, alpha: shownAlpha, bold: true)
                let name = language == .zh ? "\(selected * 3 + month + 1)月" : drillMonthNamesEN[selected * 3 + month]
                label(context, name, x: midX, y: plot.maxY + 6, alpha: shownAlpha, bold: false, top: true)
                stacked += value
            }
            let closed = 1 - ChartKit.smoothstep(0, 0.35, max(open[0], max(open[1], open[2])))
            let topY = plot.maxY - plot.height * CGFloat(stacked / Self.overviewTop) * g
            label(context, "\(Int(stacked))", x: centerX, y: topY - 3, alpha: closed * Double(min(g, 1)), bold: true)
            label(context, "Q\(quarter + 1)", x: centerX, y: plot.maxY + 6, alpha: closed, bold: false, top: true)
        }
    }

    private func fill(_ context: GraphicsContext, _ rect: CGRect, radius: CGFloat, tone: ChartRGB) {
        guard rect.height > 0.5 else { return }
        context.fill(
            Path(roundedRect: rect, cornerRadius: radius, style: .continuous),
            with: .linearGradient(
                Gradient(colors: [tone.mixed(ChartRGB(0xFFFFFF), 0.18).color(), tone.color()]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
    }

    private func label(_ context: GraphicsContext, _ text: String, x: CGFloat, y: CGFloat, alpha: Double, bold: Bool, top: Bool = false) {
        guard alpha > 0.01 else { return }
        var layer = context
        layer.opacity = context.opacity * alpha
        layer.draw(
            Text(verbatim: text)
                .font(.system(size: 10, weight: bold ? .bold : .medium, design: bold ? .rounded : .default))
                .foregroundStyle(bold ? Color.primary : Color.secondary),
            at: CGPoint(x: x, y: y),
            anchor: top ? .top : .bottom
        )
    }
}
