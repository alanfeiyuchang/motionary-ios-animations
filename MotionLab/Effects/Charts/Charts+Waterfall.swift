import SwiftUI

extension Effect {
    static let chartsWaterfall = Effect(
        id: "charts.waterfall",
        category: .charts,
        interaction: .tap,
        name: L("Waterfall Build", "瀑布图搭建"),
        summary: L("Floating bars build step by step, dashed connectors hand the level on, and the total drops in with a bounce.", "悬浮柱逐级搭建，虚线连接线传递水位，合计柱带着弹跳落下。"),
        prompt: L(
            "A cash-flow waterfall card: an opening total bar, five floating delta bars (green up, red down) and a closing total, 22 pt wide with 5 pt corners over three hairline grid lines. On appear the bars build left to right, 0.32 s apart: each delta grows away from the previous level on a spring (response 0.45 s, damping 0.78) while its signed value fades in beside it, then a 1 pt dashed connector draws across the gap to the next bar in 0.14 s. The closing total does not grow: it drops from 54 pt above and lands with three decaying bounces (restitution 0.45, 0.75 s) and a slight squash. The header figure rolls through every running subtotal and a net-change pill pops in at the end. Soft haptic per step, success on landing. Feels like a ledger adding itself up.",
            "现金流瀑布图卡片：期初合计柱、五根悬浮增减柱（增绿减红）与期末合计柱，柱宽 22pt、圆角 5pt，背后三条网格线。出现时自左向右搭建，间隔 0.32 秒：每根增减柱从上一级水位以弹簧（响应 0.45 秒、阻尼 0.78）生长，带符号的数值随之淡入；随后 1pt 虚线用 0.14 秒划过间隙，把水位交给下一根。期末合计柱不是生长，而是从上方 54pt 处落下，以恢复系数 0.45 弹跳三次（共 0.75 秒）并轻微压扁。标题数字滚过每个累计值，最后净变化胶囊弹出。每步轻触感，落地成功触感，像账本自己算清了账。"
        ),
        implementation: L(
            "One Animatable Canvas draws everything from two ChartVectors (bar growth, connector progress); a cancellable Task steps through the bars so each element gets its own spring, and the last bar maps a linear 0…1 through a parabolic bounce function.",
            "整张图由一个 Animatable Canvas 根据两个 ChartVector（柱体生长、连接线进度）绘制；可取消的 Task 逐根推进，让每个元素拥有自己的弹簧，最后一根柱把线性 0…1 映射到抛物线弹跳函数。"
        ),
        apis: ["Animatable", "VectorArithmetic", "Canvas", "Task.sleep", "spring(response:dampingFraction:)"],
        tags: ["waterfall", "bridge chart", "cash flow", "sequence", "瀑布图", "桥图", "现金流", "逐级搭建"],
        params: [
            .slider("stagger", L("Step interval", "步进间隔"), 0.15...0.6, default: 0.32, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.8, default: 0.45, unit: "s"),
            .slider("bounce", L("Landing restitution", "落地恢复系数"), 0...0.7, default: 0.45),
            .toggle("links", L("Connectors", "连接线"), default: true),
        ]
    ) { ctx in
        WaterfallDemo(ctx: ctx)
    }
}

private struct WaterfallStep {
    let label: LocalizedText
    /// The total for `isTotal` bars, otherwise the signed change.
    let amount: Double
    let isTotal: Bool
}

private struct WaterfallSet {
    let title: LocalizedText
    let steps: [WaterfallStep]

    /// Level before and after each step.
    var levels: [(before: Double, after: Double)] {
        var running = 0.0
        return steps.map { step in
            if step.isTotal {
                let before = running
                if before == 0 { running = step.amount }
                return (0, running)
            }
            let before = running
            running += step.amount
            return (before, running)
        }
    }

    var top: Double { (levels.map { max($0.before, $0.after) }.max() ?? 1) * 1.16 }
    var opening: Double { levels.first?.after ?? 0 }
    var closing: Double { levels.last?.after ?? 0 }
}

private let waterfallSets: [WaterfallSet] = [
    WaterfallSet(title: L("Net cash · Q3", "净现金流 · Q3"), steps: [
        WaterfallStep(label: L("Open", "期初"), amount: 420, isTotal: true),
        WaterfallStep(label: L("Sales", "销售"), amount: 180, isTotal: false),
        WaterfallStep(label: L("Service", "服务"), amount: 90, isTotal: false),
        WaterfallStep(label: L("Costs", "成本"), amount: -150, isTotal: false),
        WaterfallStep(label: L("Tax", "税费"), amount: -60, isTotal: false),
        WaterfallStep(label: L("Other", "其他"), amount: 40, isTotal: false),
        WaterfallStep(label: L("Close", "期末"), amount: 0, isTotal: true),
    ]),
    WaterfallSet(title: L("Net cash · Q4", "净现金流 · Q4"), steps: [
        WaterfallStep(label: L("Open", "期初"), amount: 520, isTotal: true),
        WaterfallStep(label: L("Sales", "销售"), amount: 130, isTotal: false),
        WaterfallStep(label: L("Refund", "退款"), amount: -80, isTotal: false),
        WaterfallStep(label: L("Costs", "成本"), amount: -190, isTotal: false),
        WaterfallStep(label: L("Grants", "补贴"), amount: 110, isTotal: false),
        WaterfallStep(label: L("Tax", "税费"), amount: -50, isTotal: false),
        WaterfallStep(label: L("Close", "期末"), amount: 0, isTotal: true),
    ]),
]

private struct WaterfallDemo: View {
    let ctx: DemoContext
    /// Seeded built so a still shows the finished chart; `onAppear` empties it and replays the build.
    @State private var grow = ChartVector(repeating: 1, count: 7)
    @State private var link = ChartVector(repeating: 1, count: 6)
    @State private var setIndex = 0
    @State private var shown: Double = waterfallSets[0].closing
    @State private var finished = true
    @State private var run: Task<Void, Never>?

    private var data: WaterfallSet { waterfallSets[setIndex] }

    var body: some View {
        ChartStage(hint: L("Tap to rebuild with new figures", "点击用新数据重新搭建"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 10) {
                header
                WaterfallPlot(
                    data: data,
                    grow: grow,
                    link: link,
                    restitution: ctx["bounce"],
                    showLinks: ctx.bool("links"),
                    language: ctx.language
                )
                .frame(height: 178)
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { rebuild() }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: { clear() }, then: { build() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 4.4, delay: 3.6, intro: false) { rebuild() }
    }

    private var header: some View {
        let net = data.closing - data.opening
        let tint = net >= 0 ? Palette.green : Palette.red
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.title, ctx.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChartRollText(value: shown) { "$\(Int($0.rounded()))k" }
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: net >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(verbatim: String(format: "%+.0f", net))
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .scaleEffect(finished ? 1 : 0.4)
            .opacity(finished ? 1 : 0)
        }
    }

    private func clear() {
        grow = ChartVector(repeating: 0, count: 7)
        link = ChartVector(repeating: 0, count: 6)
        shown = 0
        finished = false
    }

    /// Tap and autoplay: fold the chart away, switch dataset, build again.
    private func rebuild() {
        Haptics.tap(.light)
        run?.cancel()
        withAnimation(.easeIn(duration: 0.2)) {
            grow = ChartVector(repeating: 0, count: 7)
            link = ChartVector(repeating: 0, count: 6)
            finished = false
        }
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.26))
            guard !Task.isCancelled else { return }
            chartInstant {
                setIndex = (setIndex + 1) % waterfallSets.count
                shown = 0
            }
            try? await Task.sleep(for: .seconds(0.05))
            guard !Task.isCancelled else { return }
            await steps()
        }
    }

    private func build() {
        run?.cancel()
        run = Task { @MainActor in await steps() }
    }

    @MainActor
    private func steps() async {
        let stagger = ctx["stagger"]
        let response = ctx["response"]
        let levels = data.levels
        let last = levels.count - 1
        for index in levels.indices {
            guard !Task.isCancelled else { return }
            if index == last {
                // The closing total falls and bounces: linear time, the plot maps it through the bounce curve.
                withAnimation(.linear(duration: 0.75)) { grow[index] = 1 }
                let impact = 0.75 * ChartKit.firstImpact(restitution: ctx["bounce"])
                try? await Task.sleep(for: .seconds(impact))
                guard !Task.isCancelled else { return }
                if !ctx.isPreview { Haptics.success() }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { finished = true }
            } else {
                withAnimation(.spring(response: response, dampingFraction: 0.78)) { grow[index] = 1 }
                withAnimation(.easeOut(duration: max(response, 0.2))) { shown = levels[index].after }
                if !ctx.isPreview { Haptics.tap(.soft) }
                try? await Task.sleep(for: .seconds(stagger * 0.56))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.14)) { link[index] = 1 }
                try? await Task.sleep(for: .seconds(stagger * 0.44))
            }
        }
    }
}

private struct WaterfallPlot: View, Animatable {
    let data: WaterfallSet
    var grow: ChartVector
    var link: ChartVector
    let restitution: Double
    let showLinks: Bool
    let language: AppLanguage

    var animatableData: AnimatablePair<ChartVector, ChartVector> {
        get { AnimatablePair(grow, link) }
        set {
            grow = newValue.first
            link = newValue.second
        }
    }

    private static let barWidth: CGFloat = 22
    private static let dropHeight: CGFloat = 54

    var body: some View {
        Canvas { context, size in
            draw(in: context, size: size)
        }
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let steps = data.steps
        let levels = data.levels
        let top = data.top
        let plot = CGRect(x: 0, y: 16, width: size.width, height: size.height - 16 - 20)
        let slot = plot.width / CGFloat(steps.count)
        func y(_ value: Double) -> CGFloat { plot.maxY - plot.height * CGFloat(value / top) }

        for line in 0...2 {
            let lineY = plot.maxY - plot.height * CGFloat(line) / 2.4
            var rule = Path()
            rule.move(to: CGPoint(x: 0, y: lineY))
            rule.addLine(to: CGPoint(x: plot.maxX, y: lineY))
            context.stroke(rule, with: .color(.primary.opacity(line == 0 ? 0.16 : 0.06)), lineWidth: 1)
        }

        for index in steps.indices {
            let step = steps[index]
            let level = levels[index]
            let g = grow[index]
            let centerX = slot * (CGFloat(index) + 0.5)
            let left = centerX - Self.barWidth / 2
            var rect: CGRect
            var alpha = 1.0
            let isLast = index == steps.count - 1

            if step.isTotal && isLast {
                let fall = CGFloat(ChartKit.bounceHeight(g, restitution: restitution)) * Self.dropHeight
                let squash = CGFloat(ChartKit.bounceSquash(g, restitution: restitution))
                let height = (plot.maxY - y(level.after)) * (1 - squash)
                rect = CGRect(x: left - Self.barWidth * squash / 2, y: plot.maxY - height - fall, width: Self.barWidth * (1 + squash), height: height)
                alpha = min(max(g * 8, 0), 1)
            } else if step.isTotal {
                let height = (plot.maxY - y(level.after)) * CGFloat(max(g, 0))
                rect = CGRect(x: left, y: plot.maxY - height, width: Self.barWidth, height: height)
            } else {
                let from = y(level.before)
                let to = from + (y(level.after) - from) * CGFloat(g)
                rect = CGRect(x: left, y: min(from, to), width: Self.barWidth, height: abs(to - from))
            }

            if rect.height > 0.5, alpha > 0.01 {
                var layer = context
                layer.opacity = alpha
                let radius = min(5, rect.height / 2)
                let colors: [Color] = step.isTotal
                    ? [Palette.violet, Palette.indigo]
                    : (step.amount >= 0 ? [Palette.mint, Palette.green] : [Palette.coral, Palette.red])
                layer.fill(
                    Path(roundedRect: rect, cornerRadius: radius, style: .continuous),
                    with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY))
                )
            }

            // Value: totals above the bar, deltas on the far side of their travel.
            let labelAlpha = ChartKit.smoothstep(0.45, 0.95, g) * alpha
            if labelAlpha > 0.01 {
                var layer = context
                layer.opacity = labelAlpha
                let text: Text
                let anchorY: CGFloat
                let anchor: UnitPoint
                if step.isTotal {
                    text = Text(verbatim: "\(Int(level.after.rounded()))").foregroundStyle(Color.primary)
                    anchorY = rect.minY - 3
                    anchor = .bottom
                } else if step.amount >= 0 {
                    text = Text(verbatim: String(format: "%+.0f", step.amount)).foregroundStyle(Palette.green)
                    anchorY = rect.minY - 3
                    anchor = .bottom
                } else {
                    text = Text(verbatim: String(format: "%+.0f", step.amount).replacingOccurrences(of: "-", with: "−")).foregroundStyle(Palette.red)
                    anchorY = rect.maxY + 3
                    anchor = .top
                }
                layer.draw(text.font(.system(size: 10, weight: .bold, design: .rounded)), at: CGPoint(x: centerX, y: anchorY), anchor: anchor)
            }

            context.draw(
                Text(step.label(language)).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondary),
                at: CGPoint(x: centerX, y: plot.maxY + 6),
                anchor: .top
            )

            if showLinks, index < steps.count - 1 {
                let progress = CGFloat(min(max(link[index], 0), 1))
                if progress > 0.01 {
                    let lineY = y(level.after)
                    let startX = centerX + Self.barWidth / 2 + 1
                    let endX = centerX + slot - Self.barWidth / 2 - 1
                    var dash = Path()
                    dash.move(to: CGPoint(x: startX, y: lineY))
                    dash.addLine(to: CGPoint(x: startX + (endX - startX) * progress, y: lineY))
                    context.stroke(dash, with: .color(.primary.opacity(0.42)), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2.5, 2.5]))
                }
            }
        }
    }
}
