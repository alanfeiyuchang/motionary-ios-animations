import SwiftUI

extension Effect {
    static let chartsStackedArea = Effect(
        id: "charts.stacked-area",
        category: .charts,
        interaction: .tap,
        name: L("Stacked Area Re-stack", "堆叠面积重排"),
        summary: L("Four area streams swell in from the bottom up and re-stack on one spring when a series is toggled.", "四条面积带自下而上涨起；开关某个系列时，其余在同一个弹簧里重新堆叠。"),
        prompt: L(
            "A traffic card with four smooth stacked areas (indigo, sky, mint, amber), each with a brighter 1.5 pt top edge, over a 24-point week. On appear a wipe reveals the plot left to right in 0.9 s while the layers swell from zero thickness one after another, bottom first, 110 ms apart. Tapping a legend chip removes its series: that layer's thickness springs to zero (response 0.6 s, damping 0.82) and every layer above settles down onto the one below in the same spring, tops and bottoms computed from the same interpolated weights so no gap ever opens; tapping again swells it back. The chip dims and its dot hollows; the total figure rolls. A Stream layout re-centres the stack around the middle with the same spring. Calm, liquid and honest.",
            "流量卡片：四条平滑堆叠的面积带（靛蓝、天蓝、薄荷、琥珀），每条顶部有 1.5pt 亮边，横轴为一周 24 个采样点。出现时图表自左向右在 0.9 秒内擦出，同时各层从零厚度自下而上依次涨起，间隔 110 毫秒。点击图例标签可移除该系列：这一层的厚度以弹簧（响应 0.6 秒、阻尼 0.82）收为零，上方各层在同一个弹簧中落到下一层上——上下边界都由同一组插值权重算出，绝不露缝；再点一次重新涨回。标签变暗、圆点变空心，总量数字滚动。「流图」布局用同样的弹簧把整叠围绕中线居中。从容如液体，且忠于数据。"
        ),
        implementation: L(
            "An Animatable Canvas interpolates a ChartVector of per-series weights plus a centring factor and a reveal fraction; each frame it accumulates the weighted series into running baselines and fills Catmull-Rom bands between them.",
            "Animatable Canvas 插值每个系列的权重（ChartVector）、居中系数与擦出比例；每帧把加权后的系列累加成逐层基线，并在基线之间填充 Catmull-Rom 平滑面积带。"
        ),
        apis: ["Animatable", "VectorArithmetic", "Canvas", "Path.addCurve", "spring(response:dampingFraction:)"],
        tags: ["stacked area", "streamgraph", "toggle series", "legend", "堆叠面积图", "流图", "系列开关", "图例"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1.2, default: 0.6, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .choice("layout", L("Layout", "布局"), [L("Stacked", "堆叠"), L("Stream", "流图")]),
        ]
    ) { ctx in
        StackedAreaDemo(ctx: ctx)
    }
}

private struct AreaSeries {
    let name: LocalizedText
    let color: Color
    let values: [Double]
}

private func areaValues(base: Double, swing: Double, seed: Double) -> [Double] {
    (0..<24).map { index in
        let x = Double(index) / 23
        let wave = sin(x * 5.2 + seed) * 0.55 + sin(x * 11 + seed * 1.7) * 0.25 + cos(x * 2.3 + seed * 0.6) * 0.3
        return max(base + swing * wave + base * 0.5 * x, base * 0.25)
    }
}

private let areaSeries: [AreaSeries] = [
    AreaSeries(name: L("Organic", "自然"), color: Palette.indigo, values: areaValues(base: 9, swing: 3.2, seed: 0.4)),
    AreaSeries(name: L("Paid", "付费"), color: Palette.sky, values: areaValues(base: 6, swing: 2.6, seed: 2.1)),
    AreaSeries(name: L("Social", "社交"), color: Palette.mint, values: areaValues(base: 5, swing: 2.8, seed: 4.4)),
    AreaSeries(name: L("Referral", "引荐"), color: Palette.amber, values: areaValues(base: 3.5, swing: 1.8, seed: 5.7)),
]

private let areaPeak: Double = (0..<24).map { index in areaSeries.reduce(0) { $0 + $1.values[index] } }.max() ?? 1

private struct StackedAreaDemo: View {
    let ctx: DemoContext
    @State private var enabled: [Bool] = Array(repeating: true, count: areaSeries.count)
    @State private var weights = ChartVector(repeating: 1, count: areaSeries.count)
    @State private var reveal: Double = 1
    @State private var autoStep = 0
    @State private var run: Task<Void, Never>?

    private static let script = [1, 3, 1, 0, 3, 0]

    private var total: Double {
        areaSeries.indices.reduce(0) { $0 + (enabled[$1] ? (areaSeries[$1].values.last ?? 0) : 0) }
    }

    var body: some View {
        ChartStage(hint: L("Tap a legend chip to toggle a series", "点击图例开关某个系列"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 12) {
                header
                StackedAreaPlot(weights: weights, center: ctx.int("layout") == 1 ? 1 : 0, reveal: reveal)
                    .frame(height: 150)
                    .animation(.spring(response: ctx["response"], dampingFraction: ctx["damping"]), value: ctx.int("layout"))
                legend
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                weights = ChartVector(repeating: 0, count: areaSeries.count)
                reveal = 0
            }, then: { swellIn() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.5, delay: 2.0, intro: false) {
            toggle(Self.script[autoStep % Self.script.count])
            autoStep += 1
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ctx.language == .zh ? "访问来源 · 本周" : "Traffic sources · this week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChartRollText(value: total) { String(format: "%.1fk", $0) }
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer()
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            ForEach(areaSeries.indices, id: \.self) { index in
                let on = enabled[index]
                Button {
                    toggle(index)
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .strokeBorder(areaSeries[index].color, lineWidth: on ? 4 : 1.5)
                            .frame(width: 8, height: 8)
                        Text(areaSeries[index].name, ctx.language)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(on ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(Color.primary.opacity(on ? 0.07 : 0.03), in: Capsule())
                    .opacity(on ? 1 : 0.6)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Legend chips and autoplay share this. The last visible series cannot be removed.
    private func toggle(_ index: Int) {
        let turningOff = enabled[index]
        if turningOff && enabled.filter({ $0 }).count <= 1 {
            Haptics.error()
            return
        }
        Haptics.selection()
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            enabled[index].toggle()
            weights[index] = turningOff ? 0 : 1
        }
    }

    private func swellIn() {
        withAnimation(.easeOut(duration: 0.9)) { reveal = 1 }
        run?.cancel()
        let response = ctx["response"]
        let damping = ctx["damping"]
        run = chartSequence(steps: areaSeries.count, gap: 0.11) { index in
            withAnimation(.spring(response: response * 1.2, dampingFraction: damping)) {
                weights[index] = enabled[index] ? 1 : 0
            }
        }
    }
}

private struct StackedAreaPlot: View, Animatable {
    var weights: ChartVector
    var center: Double
    var reveal: Double

    var animatableData: AnimatablePair<ChartVector, AnimatablePair<Double, Double>> {
        get { AnimatablePair(weights, AnimatablePair(center, reveal)) }
        set {
            weights = newValue.first
            center = newValue.second.first
            reveal = newValue.second.second
        }
    }

    var body: some View {
        let w = weights
        let centring = center
        let shown = reveal
        Canvas { context, size in
            let count = 24
            let plot = CGRect(x: 0, y: 4, width: size.width, height: size.height - 22)
            let step = plot.width / CGFloat(count - 1)
            let unit = plot.height / CGFloat(areaPeak)

            for line in 0...3 {
                let y = plot.maxY - plot.height * CGFloat(line) / 3
                var rule = Path()
                rule.move(to: CGPoint(x: 0, y: y))
                rule.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(rule, with: .color(.primary.opacity(line == 0 ? 0.14 : 0.05)), lineWidth: 1)
            }

            var clipped = context
            clipped.clip(to: Path(CGRect(x: 0, y: 0, width: size.width * CGFloat(shown), height: size.height)))

            // Running baseline per x: starts at the (optionally centred) floor and climbs with each layer.
            var base: [CGFloat] = (0..<count).map { index in
                let total = areaSeries.indices.reduce(0.0) { $0 + areaSeries[$1].values[index] * max(w[$1], 0) }
                let slack = plot.height - CGFloat(total) * unit
                return plot.maxY - slack / 2 * CGFloat(centring)
            }

            for series in areaSeries.indices {
                let weight = max(w[series], 0)
                let bottom: [CGPoint] = (0..<count).map { CGPoint(x: CGFloat($0) * step, y: base[$0]) }
                let top: [CGPoint] = (0..<count).map { index in
                    CGPoint(x: CGFloat(index) * step, y: base[index] - CGFloat(areaSeries[series].values[index] * weight) * unit)
                }
                base = top.map(\.y)
                guard weight > 0.003 else { continue }

                var band = Path()
                ChartKit.addSmooth(&band, top)
                ChartKit.addSmooth(&band, bottom.reversed(), move: false)
                band.closeSubpath()
                let color = areaSeries[series].color
                clipped.fill(
                    band,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.92), color.opacity(0.62)]),
                        startPoint: CGPoint(x: 0, y: plot.minY),
                        endPoint: CGPoint(x: 0, y: plot.maxY)
                    )
                )
                var edge = clipped
                edge.opacity = min(weight * 5, 1)
                edge.stroke(ChartKit.smoothPath(top), with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }

            let days = ["M", "T", "W", "T", "F", "S", "S"]
            for (index, day) in days.enumerated() {
                let x = plot.width * (CGFloat(index) + 0.5) / CGFloat(days.count)
                context.draw(
                    Text(verbatim: day).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary),
                    at: CGPoint(x: x, y: plot.maxY + 5),
                    anchor: .top
                )
            }
        }
    }
}
