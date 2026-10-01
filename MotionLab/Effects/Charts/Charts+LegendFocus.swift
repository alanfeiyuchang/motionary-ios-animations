import SwiftUI

extension Effect {
    static let chartsLegendFocus = Effect(
        id: "charts.legend-focus",
        category: .charts,
        interaction: .tap,
        name: L("Legend Focus", "图例聚焦"),
        summary: L("Tap a legend chip: its line thickens, glows and gains an area fill and an end label while the others step back.", "点击图例：对应折线加粗发光，出现面积填充与末端数值，其余折线退到背景。"),
        prompt: L(
            "A multi-series card: three smooth 2 pt lines (indigo, pink, mint) over a week, with a row of legend chips above. The lines draw on left to right one after another, 120 ms apart, 0.8 s each. Tapping a chip focuses its series: the chip fills with the series colour and its text turns white, the line thickens to 3.5 pt on a spring (response 0.4 s, damping 0.7), a soft 6 pt glow of its own colour blooms under it, a gradient area fades in beneath, and its end dot grows with the latest value beside it. The other lines thin to 1.5 pt and fade to 22% on the same spring, and the header figure rolls from the total to the focused series. Tapping the same chip again releases the focus. Selection haptic on each change. Calm, legible, a spotlight rather than a filter.",
            "多系列卡片：一周内三条 2pt 平滑折线（靛蓝、粉、薄荷绿），上方一排图例胶囊。折线自左向右依次画出，间隔 120ms，每条 0.8 秒。点击图例即聚焦该系列：胶囊填充为系列色、文字变白，折线以弹簧（响应 0.4 秒、阻尼 0.7）加粗到 3.5pt，下方晕开 6pt 的同色柔光，渐变面积随之淡入，末端圆点放大并在旁边显示最新数值。其余折线以同一弹簧变细到 1.5pt、淡到 22%，标题数字从合计滚动为该系列的数值。再次点击同一图例取消聚焦。每次切换有选择触感。沉稳、清晰，是聚光灯而不是筛选器。"
        ),
        implementation: L(
            "An Animatable Canvas takes one emphasis value per series (a ChartVector) plus a draw-on vector. Width, glow (a blurred copy of the stroke), area opacity and dot size are all functions of the emphasis, and the dimming of a line is the largest emphasis among the others; lines are painted in emphasis order so the focused one is on top.",
            "Animatable Canvas 为每个系列接收一个强调值（ChartVector）与一个绘制进度向量。线宽、发光（描边的模糊副本）、面积不透明度与圆点大小都是强调值的函数，某条线的变暗程度取其他系列中最大的强调值；按强调值排序绘制，使聚焦的线位于最上层。"
        ),
        apis: ["Animatable", "VectorArithmetic", "Canvas", "GraphicsContext.addFilter(.blur)", "spring(response:dampingFraction:)"],
        tags: ["legend", "focus", "highlight series", "multi line", "图例", "聚焦", "高亮系列", "多折线"],
        params: [
            .slider("dim", L("Dimmed opacity", "其余线不透明度"), 0.05...0.7, default: 0.22),
            .slider("glow", L("Glow radius", "发光半径"), 0...14, default: 6, decimals: 1, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.9, default: 0.4, unit: "s"),
        ]
    ) { ctx in
        LegendFocusDemo(ctx: ctx)
    }
}

private struct LegendSeries {
    let name: LocalizedText
    let rgb: ChartRGB
    let values: [Double]
    let latest: Double
}

private let legendSeries: [LegendSeries] = [
    LegendSeries(name: L("Search", "搜索"), rgb: .indigo, values: ChartKit.resample([32, 41, 38, 52, 61, 58, 72], perSegment: 8), latest: 72),
    LegendSeries(name: L("Social", "社交"), rgb: .pink, values: ChartKit.resample([48, 44, 55, 47, 41, 54, 49], perSegment: 8), latest: 49),
    LegendSeries(name: L("Direct", "直接"), rgb: .mint, values: ChartKit.resample([18, 22, 29, 26, 35, 31, 38], perSegment: 8), latest: 38),
]
private let legendRange: ClosedRange<Double> = 8...82

private struct LegendFocusDemo: View {
    let ctx: DemoContext
    @State private var emphasis = ChartVector(repeating: 0, count: 3)
    @State private var draw = ChartVector(repeating: 1, count: 3)
    @State private var focused: Int?
    @State private var shown: Double = 159
    @State private var autoStep = 0
    @State private var run: Task<Void, Never>?

    var body: some View {
        ChartStage(hint: L("Tap a legend chip to focus a line", "点击图例聚焦一条折线"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 10) {
                header
                legend
                LegendFocusPlot(emphasis: emphasis, draw: draw, dim: ctx["dim"], glow: ctx.cg("glow"))
                    .frame(width: 268, height: 136)
                    .contentShape(Rectangle())
                    .onTapGesture { cycle() }
                axis
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                draw = ChartVector(repeating: 0, count: 3)
            }, then: { enter() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.5, delay: 1.5) { cycle() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(focused.map { legendSeries[$0].name } ?? L("All sessions", "全部会话"), ctx.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                ChartRollText(value: shown) { "\(Int($0.rounded()))k" }
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer()
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                let series = legendSeries[index]
                let on = focused == index
                Button {
                    focus(on ? nil : index)
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(on ? Color.white : series.rgb.color())
                            .frame(width: 7, height: 7)
                        Text(series.name, ctx.language)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(on ? Color.white : Color.primary.opacity(focused == nil ? 0.8 : 0.45))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        Capsule().fill(on ? AnyShapeStyle(series.rgb.mixed(ChartRGB(0x000000), 0.08).color()) : AnyShapeStyle(Color.primary.opacity(0.06)))
                    )
                    .scaleEffect(on ? 1.05 : 1)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var axis: some View {
        let labels = ctx.language == .zh ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                Text(verbatim: labels[index])
                if index < labels.count - 1 { Spacer(minLength: 0) }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 268 - LegendFocusPlot.trailing)
    }

    private func enter() {
        run?.cancel()
        run = chartSequence(steps: 3, gap: 0.12) { step in
            withAnimation(.easeInOut(duration: 0.8)) { draw[step] = 1 }
        }
    }

    /// The plot and autoplay step through the three series and back to all.
    private func cycle() {
        let order: [Int?] = [0, 1, 2, nil]
        if ctx.isPreview {
            focus(order[autoStep % order.count])
            autoStep += 1
        } else {
            let next: Int? = focused.map { $0 + 1 < 3 ? $0 + 1 : nil } ?? 0
            focus(next)
        }
    }

    private func focus(_ index: Int?) {
        Haptics.selection()
        run?.cancel()
        let response = ctx["response"]
        withAnimation(.spring(response: response, dampingFraction: 0.7)) {
            focused = index
            draw = ChartVector(repeating: 1, count: 3)
        }
        var target = ChartVector(repeating: 0, count: 3)
        if let index { target[index] = 1 }
        withAnimation(.spring(response: response, dampingFraction: 0.7)) { emphasis = target }
        withAnimation(.easeInOut(duration: 0.45)) {
            shown = index.map { legendSeries[$0].latest } ?? 159
        }
    }
}

private struct LegendFocusPlot: View, Animatable {
    var emphasis: ChartVector
    var draw: ChartVector
    let dim: Double
    let glow: CGFloat

    static let trailing: CGFloat = 30

    var animatableData: AnimatablePair<ChartVector, ChartVector> {
        get { AnimatablePair(emphasis, draw) }
        set {
            emphasis = newValue.first
            draw = newValue.second
        }
    }

    var body: some View {
        Canvas { context, size in
            let width = size.width - Self.trailing
            func y(_ value: Double) -> CGFloat {
                let t = (value - legendRange.lowerBound) / (legendRange.upperBound - legendRange.lowerBound)
                return size.height - 4 - (size.height - 8) * CGFloat(t)
            }
            for line in 0...2 {
                let lineY = 4 + (size.height - 8) * CGFloat(line) / 2
                var rule = Path()
                rule.move(to: CGPoint(x: 0, y: lineY))
                rule.addLine(to: CGPoint(x: width, y: lineY))
                context.stroke(rule, with: .color(.primary.opacity(0.06)), lineWidth: 1)
            }

            let order = (0..<3).sorted { emphasis[$0] < emphasis[$1] }
            for index in order {
                let series = legendSeries[index]
                let e = min(max(emphasis[index], 0), 1.2)
                let others = (0..<3).filter { $0 != index }.map { min(max(emphasis[$0], 0), 1) }.max() ?? 0
                let alpha = 1 - (1 - dim) * others * (1 - min(e, 1))
                let progress = CGFloat(min(max(draw[index], 0), 1))
                guard progress > 0.001 else { continue }
                let step = width / CGFloat(series.values.count - 1)
                let points: [CGPoint] = series.values.indices.map { CGPoint(x: CGFloat($0) * step, y: y(series.values[$0])) }
                var path = Path()
                path.addLines(points)

                var layer = context
                layer.opacity = alpha
                layer.clip(to: Path(CGRect(x: -4, y: -12, width: (width + 4) * progress + 4, height: size.height + 24)))

                if e > 0.01 {
                    var area = path
                    area.addLine(to: CGPoint(x: width, y: size.height))
                    area.addLine(to: CGPoint(x: 0, y: size.height))
                    area.closeSubpath()
                    layer.fill(area, with: .linearGradient(
                        Gradient(colors: [series.rgb.color(0.26 * min(e, 1)), series.rgb.color(0)]),
                        startPoint: CGPoint(x: 0, y: 10),
                        endPoint: CGPoint(x: 0, y: size.height)
                    ))
                    if glow > 0.2 {
                        var halo = layer
                        halo.addFilter(.blur(radius: glow))
                        var lowered = path
                        lowered = lowered.offsetBy(dx: 0, dy: 3)
                        halo.stroke(lowered, with: .color(series.rgb.color(0.75 * min(e, 1))), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                }

                let lineWidth = 2 + 1.5 * CGFloat(e) - 0.5 * CGFloat(others * (1 - min(e, 1)))
                layer.stroke(path, with: .color(series.rgb.color()), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                // End dot and value.
                guard progress > 0.98, let end = points.last else { continue }
                var marks = context
                marks.opacity = alpha
                let radius = 3 + 2.5 * CGFloat(e)
                let ring = CGRect(x: end.x - radius, y: end.y - radius, width: radius * 2, height: radius * 2)
                if e > 0.3 {
                    marks.fill(Path(ellipseIn: ring.insetBy(dx: -1.5, dy: -1.5)), with: .color(.white))
                }
                marks.fill(Path(ellipseIn: ring), with: .color(series.rgb.color()))
                if e > 0.02 {
                    var text = context
                    text.opacity = min(e, 1)
                    text.draw(
                        Text(verbatim: "\(Int(series.latest))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(series.rgb.color()),
                        at: CGPoint(x: end.x + 9 + CGFloat(1 - min(e, 1)) * 6, y: end.y),
                        anchor: .leading
                    )
                }
            }
        }
    }
}
