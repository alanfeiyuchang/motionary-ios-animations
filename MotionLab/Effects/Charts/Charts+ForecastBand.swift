import SwiftUI

extension Effect {
    static let chartsForecastBand = Effect(
        id: "charts.forecast-band",
        category: .charts,
        interaction: .tap,
        name: L("Forecast Fan", "预测扇形带"),
        summary: L("A solid line of actuals runs into a dashed forecast whose confidence band fans open; tapping swaps the scenario and the fan re-bends.", "实线的实际值接上虚线预测，置信区间像扇面一样张开；点击切换情景，扇面随之弯向新的走势。"),
        prompt: L(
            "A forecast card: nine months of actuals as a 2.5 pt solid indigo line with a soft area fill, a dashed “today” divider, then four forecast months as a dashed line inside a translucent confidence band that starts at zero width on the last real point and widens to the right. On appear the actual line draws left to right in 0.9 s; the moment it reaches today a ringed dot pops and the forecast extends in 0.6 s while the band fans open on a spring (response 0.6 s, damping 0.62), overshooting once before it settles. A range whisker lands at the far end. Tapping switches scenario (base, optimistic, cautious): line and band bend to the new path on the same spring, their colour blends indigo → green → amber, and the header figure and range roll. Confident about the past, honest about uncertainty.",
            "预测卡片：九个月实际值是 2.5pt 靛蓝实线加柔和面积填充，“今天”处一条虚线分隔；其后四个月的预测是虚线，外包半透明置信带，带宽从最后一个真实数据点的零开始向右变宽。出现时实际线用 0.9 秒自左向右画出，到达今天的瞬间弹出白环圆点，预测线用 0.6 秒延伸，置信带以弹簧（响应 0.6 秒、阻尼 0.62）张开，宽度过冲一次后回稳，区间须线落在最右端。点击切换情景（基准、乐观、谨慎）：线与带以同一弹簧弯向新路径，颜色在靛蓝 → 绿 → 琥珀间渐变，标题数字与区间随之滚动。对过去笃定，对不确定坦诚。"
        ),
        implementation: L(
            "An Animatable card over (draw progress, forecast reach, fan width, scenario vector). The scenario vector holds the four forecast values, the spread and an RGB tint, so one spring bends the line, resizes the band and blends the colour; a Canvas builds the band polygon from the interpolated values.",
            "卡片是以（绘制进度、预测延伸、扇面宽度、情景向量）为动画数据的 Animatable 视图。情景向量包含四个预测值、区间宽度与 RGB 色值，因此一个弹簧同时弯曲线条、改变带宽并混合颜色；Canvas 根据插值结果构造置信带多边形。"
        ),
        apis: ["Animatable", "VectorArithmetic", "Canvas", "trimmedPath(from:to:)", "spring(response:dampingFraction:)"],
        tags: ["forecast", "confidence band", "projection", "uncertainty", "预测", "置信区间", "趋势外推", "扇形图"],
        params: [
            .slider("band", L("Band width", "置信带宽度"), 0.3...1.8, default: 1),
            .slider("draw", L("Draw duration", "绘制时长"), 0.4...2, default: 0.9, unit: "s"),
            .slider("response", L("Fan response", "扇面弹簧响应"), 0.3...1.2, default: 0.6, unit: "s"),
        ]
    ) { ctx in
        ForecastDemo(ctx: ctx)
    }
}

private struct ForecastScenario {
    let name: LocalizedText
    let values: [Double]
    let spread: Double
    let tint: ChartRGB

    /// Four values, the spread at the far end, then the tint.
    var vector: ChartVector { ChartVector(values + [spread, tint.r, tint.g, tint.b]) }
}

private let forecastActual: [Double] = [62, 68, 65, 74, 81, 78, 88, 95, 101]
private let forecastScenarios: [ForecastScenario] = [
    ForecastScenario(name: L("Base", "基准"), values: [106, 112, 117, 123], spread: 17, tint: .indigo),
    ForecastScenario(name: L("Optimistic", "乐观"), values: [111, 122, 134, 147], spread: 23, tint: .green),
    ForecastScenario(name: L("Cautious", "谨慎"), values: [100, 99, 96, 94], spread: 14, tint: .amber),
]

private struct ForecastDemo: View {
    let ctx: DemoContext
    @State private var draw: Double = 1
    @State private var reach: Double = 1
    @State private var fan: Double = 1
    @State private var scenario = forecastScenarios[0].vector
    @State private var index = 0
    @State private var run: Task<Void, Never>?

    var body: some View {
        ChartStage(hint: L("Tap to switch scenario", "点击切换预测情景"), ctx: ctx) {
            ForecastCard(
                draw: draw,
                reach: reach,
                fan: fan,
                scenario: scenario,
                band: ctx["band"],
                name: forecastScenarios[index].name(ctx.language),
                language: ctx.language
            )
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { next() }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                draw = 0
                reach = 0
                fan = 0
            }, then: { enter() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.9, delay: 2.6, intro: false) { next() }
    }

    private func enter() {
        let duration = ctx["draw"]
        let response = ctx["response"]
        withAnimation(.easeInOut(duration: duration)) { draw = 1 }
        run?.cancel()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration * 0.94))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.6)) { reach = 1 }
            withAnimation(.spring(response: response, dampingFraction: 0.62)) { fan = 1 }
        }
    }

    private func next() {
        Haptics.tap(.light)
        run?.cancel()
        index = (index + 1) % forecastScenarios.count
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.62)) {
            scenario = forecastScenarios[index].vector
            fan = 1
        }
        withAnimation(.easeOut(duration: 0.3)) {
            draw = 1
            reach = 1
        }
    }
}

private struct ForecastCard: View, Animatable {
    var draw: Double
    var reach: Double
    var fan: Double
    var scenario: ChartVector
    let band: Double
    let name: String
    let language: AppLanguage

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, ChartVector>> {
        get { AnimatablePair(AnimatablePair(draw, reach), AnimatablePair(fan, scenario)) }
        set {
            draw = newValue.first.first
            reach = newValue.first.second
            fan = newValue.second.first
            scenario = newValue.second.second
        }
    }

    private static let range: ClosedRange<Double> = 52...176
    private static let plotHeight: CGFloat = 156

    private var tint: ChartRGB {
        ChartRGB(r: min(max(scenario[5], 0), 1), g: min(max(scenario[6], 0), 1), b: min(max(scenario[7], 0), 1))
    }

    private var spread: Double { max(scenario[4], 0) * band * max(fan, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            canvas.frame(height: Self.plotHeight)
            axis
        }
    }

    private var header: some View {
        let end = scenario[3]
        let visible = min(max(reach, 0), 1)
        let value = forecastActual[8] + (end - forecastActual[8]) * visible
        let low = Int((end - spread).rounded())
        let high = Int((end + spread).rounded())
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Projected MRR · Jan", "预计月经常性收入 · 1月"), language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "$\(Int(value.rounded()))k")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(verbatim: "\(low)–\(high)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .opacity(visible)
                }
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(tint.color()).frame(width: 7, height: 7)
                Text(verbatim: name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint.mixed(ChartRGB(0x000000), 0.1).color())
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.color(0.14), in: Capsule())
        }
    }

    private var axis: some View {
        let labels = language == .zh ? ["1月", "5月", "今天", "次年1月"] : ["Jan", "May", "Today", "Jan"]
        return ZStack(alignment: .leading) {
            ForEach(Array([0, 4, 8, 12].enumerated()), id: \.offset) { item in
                Text(verbatim: labels[item.offset])
                    .font(.system(size: 10, weight: item.element == 8 ? .semibold : .medium))
                    .foregroundStyle(item.element == 8 ? Color.primary.opacity(0.7) : Color.secondary)
                    .fixedSize()
                    .frame(width: 60, alignment: item.element == 0 ? .leading : (item.element == 12 ? .trailing : .center))
                    .offset(x: 260 * CGFloat(item.element) / 12 - (item.element == 0 ? 0 : (item.element == 12 ? 60 : 30)))
            }
        }
        .frame(width: 268, height: 12, alignment: .leading)
    }

    private var canvas: some View {
        let draw = min(max(draw, 0), 1)
        let reach = min(max(reach, 0), 1)
        let values = (0..<4).map { scenario[$0] }
        let spread = spread
        let tint = tint
        return Canvas { context, size in
            let step = (size.width - 8) / 12
            func y(_ value: Double) -> CGFloat {
                let t = (value - Self.range.lowerBound) / (Self.range.upperBound - Self.range.lowerBound)
                return size.height - 6 - (size.height - 12) * CGFloat(t)
            }
            for line in 0...2 {
                let lineY = 6 + (size.height - 12) * CGFloat(line) / 2
                var rule = Path()
                rule.move(to: CGPoint(x: 0, y: lineY))
                rule.addLine(to: CGPoint(x: size.width, y: lineY))
                context.stroke(rule, with: .color(.primary.opacity(0.06)), lineWidth: 1)
            }

            // Actuals: area + line, revealed by the draw progress.
            let actual: [CGPoint] = forecastActual.indices.map { CGPoint(x: CGFloat($0) * step, y: y(forecastActual[$0])) }
            let todayX = step * 8
            let line = ChartKit.smoothPath(actual)
            var area = line
            area.addLine(to: CGPoint(x: todayX, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()
            var clipped = context
            clipped.clip(to: Path(CGRect(x: 0, y: 0, width: todayX * CGFloat(draw), height: size.height)))
            clipped.fill(area, with: .linearGradient(
                Gradient(colors: [Palette.indigo.opacity(0.34), Palette.indigo.opacity(0.03)]),
                startPoint: CGPoint(x: 0, y: 20),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
            clipped.stroke(line, with: .color(Palette.indigo), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            // Today divider.
            let dividerAlpha = ChartKit.smoothstep(0.7, 1, draw)
            if dividerAlpha > 0.01 {
                var divider = Path()
                divider.move(to: CGPoint(x: todayX, y: 0))
                divider.addLine(to: CGPoint(x: todayX, y: size.height))
                context.stroke(divider, with: .color(.primary.opacity(0.2 * dividerAlpha)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }

            // Forecast: band polygon and dashed centre line, both cut at the reach.
            if reach > 0.001 {
                let origin = actual[8]
                var centre: [CGPoint] = [origin]
                var upper: [CGPoint] = [origin]
                var lower: [CGPoint] = [origin]
                for index in 0..<4 {
                    let x = todayX + step * CGFloat(index + 1)
                    let widen = pow(Double(index + 1) / 4, 0.85)
                    centre.append(CGPoint(x: x, y: y(values[index])))
                    upper.append(CGPoint(x: x, y: y(values[index] + spread * widen)))
                    lower.append(CGPoint(x: x, y: y(values[index] - spread * widen)))
                }
                var bandPath = Path()
                ChartKit.addSmooth(&bandPath, upper)
                ChartKit.addSmooth(&bandPath, Array(lower.reversed()), move: false)
                bandPath.closeSubpath()
                let endX = todayX + (size.width - todayX) * CGFloat(reach) + 0.5
                var future = context
                future.clip(to: Path(CGRect(x: todayX, y: -10, width: endX - todayX, height: size.height + 20)))
                future.fill(bandPath, with: .linearGradient(
                    Gradient(colors: [tint.color(0.14), tint.color(0.34)]),
                    startPoint: CGPoint(x: todayX, y: 0),
                    endPoint: CGPoint(x: size.width, y: 0)
                ))
                var edges = Path()
                ChartKit.addSmooth(&edges, upper)
                ChartKit.addSmooth(&edges, lower)
                future.stroke(edges, with: .color(tint.color(0.35)), lineWidth: 1)
                future.stroke(ChartKit.smoothPath(centre), with: .color(tint.color()), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 6]))

                // Range whisker and value at the far end.
                let landed = ChartKit.smoothstep(0.8, 1, reach)
                if landed > 0.01, let last = centre.last, let top = upper.last, let bottom = lower.last {
                    var marks = context
                    marks.opacity = landed
                    var whisker = Path()
                    whisker.move(to: CGPoint(x: last.x - 1.5, y: top.y))
                    whisker.addLine(to: CGPoint(x: last.x - 1.5, y: bottom.y))
                    marks.stroke(whisker, with: .color(tint.color(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    let dot = CGRect(x: last.x - 6.5, y: last.y - 5, width: 10, height: 10)
                    marks.fill(Path(ellipseIn: dot), with: .color(.white))
                    marks.fill(Path(ellipseIn: dot.insetBy(dx: 2.2, dy: 2.2)), with: .color(tint.color()))
                }
            }

            // The last real point.
            let pop = ChartKit.backOut(ChartKit.stagger(draw, delay: 0.9, span: 0.1), overshoot: 2.2)
            if draw > 0.9 {
                let radius = 5.5 * CGFloat(pop)
                let ring = CGRect(x: todayX - radius, y: actual[8].y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: ring), with: .color(.white))
                context.fill(Path(ellipseIn: ring.insetBy(dx: 2.2, dy: 2.2)), with: .color(Palette.indigo))
            }
        }
    }
}
