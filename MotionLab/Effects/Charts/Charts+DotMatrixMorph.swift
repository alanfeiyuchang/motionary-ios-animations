import SwiftUI

extension Effect {
    static let chartsDotMatrixMorph = Effect(
        id: "charts.dot-matrix-morph",
        category: .charts,
        interaction: .tap,
        name: L("Dot Matrix Regroup", "点阵重组"),
        summary: L("One hundred dots, one per customer, fly from a 10 × 10 grid into unit columns by plan, then regroup and recolour by region.", "一百个圆点各代表一位客户：从 10 × 10 方阵飞成按套餐分组的单位柱，再按地区重新分组并换色。"),
        prompt: L(
            "A unit chart of 100 dots (10 pt, one per customer) that never loses a dot. It starts as a 10 × 10 grid coloured by plan. Tapping regroups it: every dot leaves for its slot in a new layout, three bottom-anchored columns five dots wide for the plans, and on the next tap four columns four dots wide for the regions, recolouring on the way. Each dot starts at a random moment within the first 35% of a 1 s timeline, travels along a shallow arc bulging 16 pt sideways from the straight path, eases out with a slight back overshoot and blends its colour mid-flight, so the cloud looks like a flock re-forming rather than a cross-fade. Group names and counts fade out before the move and in after it; a light haptic starts it and a soft one lands it. Every person stays accounted for.",
            "由 100 个 10pt 圆点组成的单位图，每个点代表一位客户，全程一个都不丢。初始是按套餐着色的 10 × 10 方阵。点击后重组：圆点飞向新布局中自己的位置——先按套餐分成三根自底向上、五点宽的柱，再点一次按地区分成四根四点宽的柱，途中换色。每个点在 1 秒时间线的前 35% 内随机出发，沿偏离直线 16pt 的浅弧飞行，缓出并带轻微回弹，颜色在飞行中段过渡，像鸟群重新列队，而不是交叉淡化。分组名称与数量在移动前淡出、落定后淡入；开始轻触感，落定柔和触感。"
        ),
        implementation: L(
            "Each dot has a stable identity with a plan and a region; three layout functions map it to a slot. A single linear 0…1 value drives a Canvas, where every dot computes its own delayed, eased progress and lerps position (plus a sine bulge perpendicular to its path) and RGB between the two layouts.",
            "每个圆点有固定身份，带套餐与地区两个属性；三个布局函数把它映射到各自的位置。一个线性的 0…1 值驱动 Canvas，每个圆点在其中计算自己带延迟、带缓动的进度，在两个布局之间插值位置（再加上垂直于路径的正弦凸起）与 RGB。"
        ),
        apis: ["Canvas", "Animatable", "linear(duration:)", "GraphicsContext", "Task.sleep"],
        tags: ["dot matrix", "unit chart", "regroup", "isotype", "点阵图", "单位图", "重新分组", "人群分布"],
        params: [
            .slider("duration", L("Flight duration", "飞行时长"), 0.5...2.2, default: 1, unit: "s"),
            .slider("stagger", L("Departure spread", "出发分散度"), 0...0.6, default: 0.35),
            .slider("arc", L("Arc height", "弧线高度"), 0...40, default: 16, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        DotMatrixDemo(ctx: ctx)
    }
}

private struct DotGroup {
    let name: LocalizedText
    let rgb: ChartRGB
    let count: Int
}

private let dotPlans: [DotGroup] = [
    DotGroup(name: L("Free", "免费版"), rgb: .sky, count: 54),
    DotGroup(name: L("Pro", "专业版"), rgb: .indigo, count: 31),
    DotGroup(name: L("Team", "团队版"), rgb: .pink, count: 15),
]
private let dotRegions: [DotGroup] = [
    DotGroup(name: L("Americas", "美洲"), rgb: .amber, count: 38),
    DotGroup(name: L("Europe", "欧洲"), rgb: .mint, count: 29),
    DotGroup(name: L("Asia", "亚洲"), rgb: .coral, count: 24),
    DotGroup(name: L("Other", "其他"), rgb: .violet, count: 9),
]

/// Plan per dot: the grid's reading order. Region per dot: an independent shuffle.
private let dotPlanOf: [Int] = dotPlans.enumerated().flatMap { Array(repeating: $0.offset, count: $0.element.count) }
private let dotRegionOf: [Int] = {
    let shuffled = (0..<100).sorted { ChartKit.hash($0, 21) < ChartKit.hash($1, 21) }
    let flat = dotRegions.enumerated().flatMap { Array(repeating: $0.offset, count: $0.element.count) }
    var out = [Int](repeating: 0, count: 100)
    for (slot, dot) in shuffled.enumerated() { out[dot] = flat[slot] }
    return out
}()

private struct DotLayout {
    var points: [CGPoint]
    var colours: [ChartRGB]
    /// Group captions: (centre x, name, count).
    var labels: [(x: CGFloat, group: DotGroup)]

    static let size = CGSize(width: 268, height: 186)
    private static let floor: CGFloat = 150

    static func make(_ kind: Int) -> DotLayout {
        switch kind {
        case 1: return columns(groups: dotPlans, of: dotPlanOf, across: 5, gap: 34)
        case 2: return columns(groups: dotRegions, of: dotRegionOf, across: 4, gap: 28)
        default: return grid()
        }
    }

    private static func grid() -> DotLayout {
        let pitch: CGFloat = 14.6
        let left = (size.width - pitch * 9) / 2
        let top: CGFloat = 9
        let points = (0..<100).map { CGPoint(x: left + CGFloat($0 % 10) * pitch, y: top + CGFloat($0 / 10) * pitch) }
        let third = size.width / 3
        return DotLayout(
            points: points,
            colours: dotPlanOf.map { dotPlans[$0].rgb },
            labels: dotPlans.indices.map { (third * (CGFloat($0) + 0.5), dotPlans[$0]) }
        )
    }

    private static func columns(groups: [DotGroup], of membership: [Int], across: Int, gap: CGFloat) -> DotLayout {
        let pitch: CGFloat = 13
        let groupWidth = pitch * CGFloat(across - 1)
        let advance = groupWidth + gap
        let left = (size.width - (groupWidth * CGFloat(groups.count) + gap * CGFloat(groups.count - 1))) / 2
        var points = [CGPoint](repeating: .zero, count: 100)
        var filled = [Int](repeating: 0, count: groups.count)
        for dot in 0..<100 {
            let group = membership[dot]
            let slot = filled[group]
            filled[group] += 1
            points[dot] = CGPoint(
                x: left + CGFloat(group) * advance + CGFloat(slot % across) * pitch,
                y: floor - 6 - CGFloat(slot / across) * pitch
            )
        }
        return DotLayout(
            points: points,
            colours: membership.map { groups[$0].rgb },
            labels: groups.indices.map { (left + CGFloat($0) * advance + groupWidth / 2, groups[$0]) }
        )
    }
}

private let dotLayouts: [DotLayout] = (0..<3).map { DotLayout.make($0) }
private let dotTitles: [LocalizedText] = [L("All customers", "全部客户"), L("By plan", "按套餐"), L("By region", "按地区")]

private struct DotMatrixDemo: View {
    let ctx: DemoContext
    @State private var progress: Double = 1
    @State private var from = 0
    @State private var to = 0
    @State private var run: Task<Void, Never>?

    var body: some View {
        ChartStage(hint: L("Tap to regroup the dots", "点击重新分组"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 10) {
                header
                DotMatrixPlot(progress: progress, from: from, to: to, spread: ctx["stagger"], arc: ctx.cg("arc"), language: ctx.language)
                    .frame(width: DotLayout.size.width, height: DotLayout.size.height)
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { next() }
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 2.2, delay: 0.8) { next() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("1 dot = 1 customer", "1 个点 = 1 位客户"), ctx.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(dotTitles[to], ctx.language)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.opacity)
                    .id(to)
                    .transition(.asymmetric(insertion: .offset(y: 8).combined(with: .opacity), removal: .offset(y: -8).combined(with: .opacity)))
            }
            Spacer()
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == to ? Palette.indigo : Color.primary.opacity(0.14))
                        .frame(width: index == to ? 16 : 6, height: 6)
                }
            }
        }
    }

    private func next() {
        Haptics.tap(.light)
        let duration = ctx["duration"]
        run?.cancel()
        chartInstant {
            from = to
            progress = 0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { to = (to + 1) % 3 }
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.03))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: duration)) { progress = 1 }
            try? await Task.sleep(for: .seconds(duration * 0.9))
            guard !Task.isCancelled, !ctx.isPreview else { return }
            Haptics.tap(.soft)
        }
    }
}

private struct DotMatrixPlot: View, Animatable {
    var progress: Double
    let from: Int
    let to: Int
    let spread: Double
    let arc: CGFloat
    let language: AppLanguage

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            let a = dotLayouts[from]
            let b = dotLayouts[to]
            let t = min(max(progress, 0), 1)
            let span = 1 - spread
            for dot in 0..<100 {
                let local = ChartKit.stagger(t, delay: ChartKit.hash(dot, 31) * spread, span: span)
                let eased = ChartKit.backOut(local, overshoot: 0.9)
                let start = a.points[dot]
                let end = b.points[dot]
                var centre = ChartKit.lerp(start, end, eased)
                let dx = end.x - start.x
                let dy = end.y - start.y
                let length = sqrt(dx * dx + dy * dy)
                if length > 1 {
                    // Bulge sideways, alternating direction, more for longer trips.
                    let side: CGFloat = dot % 2 == 0 ? 1 : -1
                    let bulge = arc * side * CGFloat(sin(Double.pi * local)) * min(length / 90, 1)
                    centre.x += -dy / length * bulge
                    centre.y += dx / length * bulge
                }
                let colour = a.colours[dot].mixed(b.colours[dot], ChartKit.smoothstep(0.25, 0.75, local))
                let radius: CGFloat = 5 * (1 + 0.18 * CGFloat(sin(Double.pi * local)))
                context.fill(
                    Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(colour.color())
                )
            }
            if from != to {
                captions(context, a, alpha: 1 - ChartKit.smoothstep(0, 0.25, t), shift: 0)
            }
            let landed = from == to ? 1 : ChartKit.smoothstep(0.7, 1, t)
            captions(context, b, alpha: landed, shift: CGFloat(1 - landed) * 6)
        }
    }

    private func captions(_ context: GraphicsContext, _ layout: DotLayout, alpha: Double, shift: CGFloat) {
        guard alpha > 0.01 else { return }
        var layer = context
        layer.opacity = alpha
        for label in layout.labels {
            layer.draw(
                Text(verbatim: "\(label.group.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(label.group.rgb.mixed(ChartRGB(0x000000), 0.12).color()),
                at: CGPoint(x: label.x, y: DotLayout.size.height - 30 + shift),
                anchor: .top
            )
            layer.draw(
                Text(verbatim: label.group.name(language))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondary),
                at: CGPoint(x: label.x, y: DotLayout.size.height - 14 + shift),
                anchor: .top
            )
        }
    }
}
