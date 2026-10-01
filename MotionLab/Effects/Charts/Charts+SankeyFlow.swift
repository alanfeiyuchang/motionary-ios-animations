import SwiftUI

extension Effect {
    static let chartsSankeyFlow = Effect(
        id: "charts.sankey-flow",
        category: .charts,
        interaction: .tap,
        name: L("Sankey Ribbon Flow", "桑基流带"),
        summary: L("Ribbons pour from three sources into three outcomes, each as thick as its share, with particles riding inside; tap a node to isolate its flows.", "流带从三个来源涌向三个结果，粗细对应占比，粒子在其中流动；点击节点可单独查看它的流向。"),
        prompt: L(
            "A two-column Sankey: three source bars on the left (Organic, Paid, Referral) and three outcome bars on the right, 10 pt wide with labels and values outside, joined by nine curved ribbons, each as thick as its value, filled with a 40% gradient from source colour to outcome colour. On appear the source bars grow from their centres, then the ribbons pour left to right one after another, 70 ms apart, each revealed in 0.55 s on an ease-out, and every outcome bar grows as its inflows arrive. Small dots travel along each ribbon in parallel lanes at 0.35 passes per second, their count proportional to the flow, fading in and out at the ends. Tapping a node isolates it: unrelated ribbons and their particles fade to 18% on a spring (response 0.4 s, damping 0.8) and the header rolls to that node's total. Flowing, proportional, easy to trace.",
            "两列桑基图：左侧三根来源柱，右侧三根结果柱，柱宽 10pt，名称与数值标在外侧；九条曲线流带连接两侧，粗细与数值成正比，填充为来源色到结果色的 40% 渐变。出现时来源柱从中心生长，流带随后自左向右依次涌出，间隔 70ms，每条用 0.55 秒缓出展开，结果柱随流入到达而长高。小圆点沿每条流带的平行通道持续流动，每秒 0.35 程，数量与流量成正比，两端淡入淡出。点击节点将其单独突出：无关的流带与粒子以弹簧（响应 0.4 秒、阻尼 0.8）淡到 18%，标题数字滚动为该节点合计。流动而易于追踪。"
        ),
        implementation: L(
            "Node and ribbon rectangles come from a small layout pass (stacked offsets per node). An Animatable view holds one reveal value per ribbon and a focus amount; inside it a TimelineView Canvas fills each ribbon (two cubic edges) through a clip that follows the reveal, and places particles on the same cubic by a time-based parameter.",
            "节点与流带的位置由一次简单的布局计算得到（每个节点内按顺序堆叠偏移）。Animatable 视图保存每条流带的展开进度与聚焦程度；其中的 TimelineView Canvas 通过跟随展开进度的裁剪区域填充流带（两条三次曲线边），并按时间参数把粒子放在同一条三次曲线上。"
        ),
        apis: ["TimelineView", "Canvas", "Animatable", "VectorArithmetic", "Path.addCurve", "SpatialTapGesture"],
        tags: ["sankey", "flow", "ribbons", "particles", "桑基图", "流向", "流带", "粒子流"],
        params: [
            .slider("speed", L("Flow speed", "流动速度"), 0...1, default: 0.35, unit: "/s"),
            .slider("density", L("Particle density", "粒子密度"), 0...6, default: 3, decimals: 1),
            .slider("curve", L("Curvature", "曲率"), 0.2...0.7, default: 0.5),
        ]
    ) { ctx in
        SankeyDemo(ctx: ctx)
    }
}

private struct SankeyNode {
    let name: LocalizedText
    let rgb: ChartRGB
}

private let sankeySources: [SankeyNode] = [
    SankeyNode(name: L("Organic", "自然流量"), rgb: .indigo),
    SankeyNode(name: L("Paid", "付费"), rgb: .pink),
    SankeyNode(name: L("Referral", "推荐"), rgb: .amber),
]
private let sankeyTargets: [SankeyNode] = [
    SankeyNode(name: L("Purchased", "已购买"), rgb: .green),
    SankeyNode(name: L("Browsed", "仅浏览"), rgb: .sky),
    SankeyNode(name: L("Bounced", "跳出"), rgb: .red),
]
/// value[source][target]
private let sankeyValues: [[Double]] = [[22, 18, 6], [9, 13, 10], [7, 10, 5]]

private func sankeySourceTotal(_ index: Int) -> Double { sankeyValues[index].reduce(0, +) }
private func sankeyTargetTotal(_ index: Int) -> Double { sankeyValues.reduce(0) { $0 + $1[index] } }

private struct SankeyDemo: View {
    let ctx: DemoContext
    @State private var links = ChartVector(repeating: 1, count: 9)
    @State private var nodes: Double = 1
    @State private var focus: Int?
    @State private var focusAmount: Double = 0
    @State private var shown: Double = 100
    @State private var autoStep = 0
    @State private var run: Task<Void, Never>?

    private static let plotSize = CGSize(width: 268, height: 184)

    var body: some View {
        ChartStage(hint: L("Tap a node to isolate its flows", "点击节点查看它的流向"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 10) {
                header
                SankeyPlot(
                    links: links,
                    nodes: nodes,
                    focusAmount: focusAmount,
                    focus: focus,
                    speed: ctx["speed"],
                    density: ctx["density"],
                    curve: ctx.cg("curve"),
                    isPreview: ctx.isPreview,
                    isStill: ctx.isStill,
                    language: ctx.language
                )
                .frame(width: Self.plotSize.width, height: Self.plotSize.height)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { value in tap(at: value.location) })
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                links = ChartVector(repeating: 0, count: 9)
                nodes = 0
                shown = 0
            }, then: { pour() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.7, delay: 2.4, intro: false) { auto() }
    }

    private var header: some View {
        let node: SankeyNode? = focus.map { $0 < 3 ? sankeySources[$0] : sankeyTargets[$0 - 3] }
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(node?.name ?? L("Visits to outcome", "访问去向"), ctx.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(node.map { $0.rgb.mixed(ChartRGB(0x000000), 0.12).color() } ?? Color.secondary)
                    .contentTransition(.opacity)
                ChartRollText(value: shown) { "\(Int($0.rounded()))k" }
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10, weight: .bold))
                Text(L("9 flows", "9 条流向"), ctx.language)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    private func pour() {
        run?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { nodes = 1 }
        withAnimation(.easeOut(duration: 1.1)) { shown = focus == nil ? 100 : shown }
        run = chartSequence(steps: 9, gap: 0.07, first: 0.2) { step in
            withAnimation(.easeOut(duration: 0.55)) { links[step] = 1 }
        }
    }

    private func tap(at location: CGPoint) {
        let layout = SankeyLayout(size: Self.plotSize)
        if location.x < layout.leftX + 24 {
            select(layout.sourceRects.firstIndex { location.y >= $0.minY - 5 && location.y <= $0.maxY + 5 })
        } else if location.x > layout.rightX - 14 {
            select(layout.targetRects.firstIndex { location.y >= $0.minY - 5 && location.y <= $0.maxY + 5 }.map { $0 + 3 })
        } else if focus != nil {
            select(nil)
        } else {
            replay()
        }
    }

    private func select(_ node: Int?) {
        let next: Int? = node == focus ? nil : node
        Haptics.selection()
        run?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let next { focus = next }
            focusAmount = next == nil ? 0 : 1
            links = ChartVector(repeating: 1, count: 9)
            nodes = 1
        }
        withAnimation(.easeInOut(duration: 0.45)) {
            shown = next.map { $0 < 3 ? sankeySourceTotal($0) : sankeyTargetTotal($0 - 3) } ?? 100
        }
        if next == nil {
            run = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }
                focus = nil
            }
        }
    }

    private func replay() {
        Haptics.tap(.light)
        run?.cancel()
        withAnimation(.easeIn(duration: 0.2)) {
            links = ChartVector(repeating: 0, count: 9)
        }
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            pour()
        }
    }

    /// Autoplay: isolate a source, an outcome, show everything, then pour again.
    private func auto() {
        let step = autoStep % 5
        autoStep += 1
        switch step {
        case 0: select(0)
        case 1: select(3)
        case 2: select(5)
        case 3: select(nil)
        default: replay()
        }
    }
}

private struct SankeyLayout {
    let leftX: CGFloat
    let rightX: CGFloat
    let barWidth: CGFloat = 10
    let sourceRects: [CGRect]
    let targetRects: [CGRect]
    /// (top at the source, top at the target, thickness), indexed source * 3 + target.
    let ribbons: [(from: CGFloat, to: CGFloat, thickness: CGFloat)]

    init(size: CGSize) {
        let gap: CGFloat = 12
        let unit = (size.height - gap * 2 - 4) / 100
        leftX = 58
        rightX = size.width - 58 - 10
        var sources: [CGRect] = []
        var y: CGFloat = 2
        for index in 0..<3 {
            let height = CGFloat(sankeySourceTotal(index)) * unit
            sources.append(CGRect(x: leftX, y: y, width: 10, height: height))
            y += height + gap
        }
        var targets: [CGRect] = []
        y = 2
        for index in 0..<3 {
            let height = CGFloat(sankeyTargetTotal(index)) * unit
            targets.append(CGRect(x: rightX, y: y, width: 10, height: height))
            y += height + gap
        }
        var out: [(from: CGFloat, to: CGFloat, thickness: CGFloat)] = []
        var targetFill = [CGFloat](repeating: 0, count: 3)
        for source in 0..<3 {
            var sourceFill: CGFloat = 0
            for target in 0..<3 {
                let thickness = CGFloat(sankeyValues[source][target]) * unit
                out.append((sources[source].minY + sourceFill, targets[target].minY + targetFill[target], thickness))
                sourceFill += thickness
                targetFill[target] += thickness
            }
        }
        sourceRects = sources
        targetRects = targets
        ribbons = out
    }
}

private struct SankeyPlot: View, Animatable {
    var links: ChartVector
    var nodes: Double
    var focusAmount: Double
    let focus: Int?
    let speed: Double
    let density: Double
    let curve: CGFloat
    let isPreview: Bool
    let isStill: Bool
    let language: AppLanguage

    var animatableData: AnimatablePair<ChartVector, AnimatablePair<Double, Double>> {
        get { AnimatablePair(links, AnimatablePair(nodes, focusAmount)) }
        set {
            links = newValue.first
            nodes = newValue.second.first
            focusAmount = newValue.second.second
        }
    }

    private static let dimmed = 0.18

    private func emphasis(source: Int, target: Int) -> Double {
        guard let focus else { return 1 }
        let related = focus < 3 ? focus == source : focus - 3 == target
        return related ? 1 : 1 - (1 - Self.dimmed) * min(max(focusAmount, 0), 1)
    }

    private func nodeEmphasis(_ node: Int) -> Double {
        guard let focus, focus != node else { return 1 }
        // Nodes on the other side stay lit: they receive part of the focused flow.
        let sameSide = (focus < 3) == (node < 3)
        return sameSide ? 1 - 0.6 * min(max(focusAmount, 0), 1) : 1
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: isPreview), paused: isStill)) { timeline in
            Canvas { context, size in
                draw(context, size: size, time: isStill ? 0.37 : timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func bezier(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat, _ t: CGFloat) -> CGFloat {
        let u = 1 - t
        return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
    }

    private func draw(_ context: GraphicsContext, size: CGSize, time: Double) {
        let layout = SankeyLayout(size: size)
        let x0 = layout.leftX + layout.barWidth
        let x1 = layout.rightX
        let dx = x1 - x0
        var arrived = [Double](repeating: 0, count: 3)

        for source in 0..<3 {
            for target in 0..<3 {
                let index = source * 3 + target
                let ribbon = layout.ribbons[index]
                let reveal = CGFloat(min(max(links[index], 0), 1))
                arrived[target] += sankeyValues[source][target] * ChartKit.smoothstep(0.75, 1, Double(reveal))
                guard reveal > 0.002 else { continue }
                let alpha = emphasis(source: source, target: target)
                var path = Path()
                path.move(to: CGPoint(x: x0, y: ribbon.from))
                path.addCurve(
                    to: CGPoint(x: x1, y: ribbon.to),
                    control1: CGPoint(x: x0 + dx * curve, y: ribbon.from),
                    control2: CGPoint(x: x1 - dx * curve, y: ribbon.to)
                )
                path.addLine(to: CGPoint(x: x1, y: ribbon.to + ribbon.thickness))
                path.addCurve(
                    to: CGPoint(x: x0, y: ribbon.from + ribbon.thickness),
                    control1: CGPoint(x: x1 - dx * curve, y: ribbon.to + ribbon.thickness),
                    control2: CGPoint(x: x0 + dx * curve, y: ribbon.from + ribbon.thickness)
                )
                path.closeSubpath()

                let from = sankeySources[source].rgb
                let to = sankeyTargets[target].rgb
                let edge = x0 + dx * reveal
                var layer = context
                layer.opacity = alpha
                layer.clip(to: Path(CGRect(x: x0, y: 0, width: edge - x0, height: size.height)))
                layer.fill(path, with: .linearGradient(
                    Gradient(colors: [from.color(0.4), to.color(0.4)]),
                    startPoint: CGPoint(x: x0, y: 0),
                    endPoint: CGPoint(x: x1, y: 0)
                ))

                // Particles in parallel lanes on the same cubic.
                let count = Int((sankeyValues[source][target] / 10 * density).rounded())
                guard count > 0 else { continue }
                for particle in 0..<count {
                    let seed = index * 31 + particle
                    let pace = speed * (0.8 + 0.4 * ChartKit.hash(seed, 41))
                    let raw = time * pace + ChartKit.hash(seed, 43)
                    let u = CGFloat(raw - floor(raw))
                    let lane = (CGFloat(particle) + 0.5) / CGFloat(count)
                    let wobble = CGFloat(ChartKit.hash(seed, 47) - 0.5) * 0.3 / CGFloat(count)
                    let offset = ribbon.thickness * min(max(lane + wobble, 0.12), 0.88)
                    let px = bezier(x0, x0 + dx * curve, x1 - dx * curve, x1, u)
                    guard px <= edge else { continue }
                    let py = bezier(ribbon.from, ribbon.from, ribbon.to, ribbon.to, u) + offset
                    let fade = min(Double(u) / 0.12, Double(1 - u) / 0.12, 1)
                    let tint = from.mixed(to, Double(u)).mixed(ChartRGB(0xFFFFFF), 0.15)
                    let r: CGFloat = 1.7
                    layer.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)), with: .color(tint.color(0.95 * fade)))
                }
            }
        }

        // Node bars and their labels.
        let grown = CGFloat(max(nodes, 0))
        for index in 0..<3 {
            let source = layout.sourceRects[index]
            let node = sankeySources[index]
            let alpha = nodeEmphasis(index)
            let height = source.height * grown
            let bar = CGRect(x: source.minX, y: source.midY - height / 2, width: source.width, height: height)
            var layer = context
            layer.opacity = alpha
            layer.fill(Path(roundedRect: bar, cornerRadius: min(3, height / 2), style: .continuous), with: .color(node.rgb.color()))
            label(layer, name: node.name(language), value: sankeySourceTotal(index), at: CGPoint(x: source.minX - 7, y: source.midY), leading: false, alpha: Double(min(grown, 1)))

            let target = layout.targetRects[index]
            let outcome = sankeyTargets[index]
            let share = CGFloat(arrived[index] / sankeyTargetTotal(index))
            let targetHeight = target.height * share
            var right = context
            right.opacity = nodeEmphasis(index + 3)
            right.fill(Path(roundedRect: target, cornerRadius: 3, style: .continuous), with: .color(.primary.opacity(0.07)))
            if targetHeight > 0.5 {
                right.fill(
                    Path(roundedRect: CGRect(x: target.minX, y: target.minY, width: target.width, height: targetHeight), cornerRadius: min(3, targetHeight / 2), style: .continuous),
                    with: .color(outcome.rgb.color())
                )
            }
            label(right, name: outcome.name(language), value: arrived[index], at: CGPoint(x: target.maxX + 7, y: target.midY), leading: true, alpha: 1)
        }
    }

    private func label(_ context: GraphicsContext, name: String, value: Double, at point: CGPoint, leading: Bool, alpha: Double) {
        var layer = context
        layer.opacity = context.opacity * alpha
        layer.draw(
            Text(verbatim: "\(Int(value.rounded()))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary),
            at: CGPoint(x: point.x, y: point.y - 1),
            anchor: leading ? .bottomLeading : .bottomTrailing
        )
        layer.draw(
            Text(verbatim: name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.secondary),
            at: CGPoint(x: point.x, y: point.y + 1),
            anchor: leading ? .topLeading : .topTrailing
        )
    }
}
