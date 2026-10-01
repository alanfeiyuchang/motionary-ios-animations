import SwiftUI

extension Effect {
    static let chartsSunburst = Effect(
        id: "charts.sunburst",
        category: .charts,
        interaction: .tap,
        name: L("Sunburst Drill-In", "旭日图下钻"),
        summary: L("Tap a segment to zoom into it: its arc opens to the full circle, the rings step inward and the centre label rolls.", "点击扇区即可钻入：它的弧展开成整圆，各环向内递进，中心标签随之滚动。"),
        prompt: L(
            "A storage sunburst: a centre disc (radius 38 pt) showing the total, an inner ring of four categories and an outer ring of their sub-items in lighter tints, separated by 1.2 pt gaps. Tapping a category drills in: every arc tweens its start angle, end angle and both radii on one spring (response 0.65 s, damping 0.82), so the chosen wedge fans open to 360° while its siblings are squeezed to zero width at the seam, its children step inward to become the inner ring and a hidden third level slides in from the rim as the new outer ring. Arc labels cross-fade, the disc tints to the category colour and its value rolls with a back glyph. Tapping the disc reverses the whole tween. Tapping an inner arc while zoomed spotlights it. Hierarchical, spatial and reversible.",
            "存储空间旭日图：中心圆盘（半径 38pt）显示总量，内环是四个类别，外环是它们的子项（颜色更浅），彼此以 1.2pt 间隙分隔。点击某个类别即可钻入：每段弧的起始角、终止角与内外半径在同一个弹簧（响应 0.65 秒、阻尼 0.82）中补间——被选中的扇区展开成 360°，兄弟扇区在接缝处被挤压为零宽，它的子项向内递进成为内环，隐藏的第三层则从外缘滑入成为新的外环。弧上标签交叉淡入淡出，圆盘染上类别色，数值滚动并出现返回图标。点击圆盘整体反向播放。层级清晰、可逆。"
        ),
        implementation: L(
            "Every node keeps its angular extent in the root layout; the displayed arc is that extent remapped to the focused node's range and its depth offset mapped to a ring. Each arc is an Animatable Shape over (start, end, inner, outer), so SwiftUI tweens real arcs rather than cross-fading.",
            "每个节点保存其在根布局中的角度范围；显示用的弧由该范围重映射到聚焦节点的区间得到，深度差决定所在的环。每段弧是以（起始角、终止角、内半径、外半径）为动画数据的 Animatable Shape，因此 SwiftUI 补间的是真实的弧，而非交叉淡化。"
        ),
        apis: ["Shape", "AnimatablePair", "Path.addArc", "spring(response:dampingFraction:)", "contentTransition(.numericText)", "atan2"],
        tags: ["sunburst", "drill down", "hierarchy", "zoomable", "旭日图", "下钻", "层级", "存储空间"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1.2, default: 0.65, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .slider("gap", L("Arc gap", "弧间隙"), 0...3, default: 1.2, unit: "pt"),
        ]
    ) { ctx in
        SunburstDemo(ctx: ctx)
    }
}

// MARK: - Hierarchy

private struct SunNode: Identifiable {
    let id: Int
    let name: LocalizedText
    let value: Double
    let depth: Int
    let parent: Int?
    /// Angular extent in the root layout, as fractions of the full circle.
    let start: Double
    let end: Double
    let category: Int
    let sibling: Int
    /// Index into the category's colour ramp (the sub-item this node is, or belongs to).
    var tone: Int = 0
}

private let sunColors: [ChartRGB] = [ChartRGB(0x6E7BFF), ChartRGB(0xFF5FA2), ChartRGB(0xF5A623), ChartRGB(0x21C4A0)]

/// One hue per sub-item, close to its category colour, so a zoomed ring is not a single flat tint.
private let sunRamps: [[ChartRGB]] = [
    [ChartRGB(0x6E7BFF), ChartRGB(0x9A6BFF), ChartRGB(0x4FA8FF)],
    [ChartRGB(0xFF5FA2), ChartRGB(0xFF7C7C), ChartRGB(0xD867E6)],
    [ChartRGB(0xF5A623), ChartRGB(0xFF8648), ChartRGB(0xEFC62C)],
    [ChartRGB(0x21C4A0), ChartRGB(0x35B8E8), ChartRGB(0x6FD36A)],
]

private let sunNodes: [SunNode] = {
    typealias Child = (LocalizedText, Double)
    let tree: [(LocalizedText, [Child])] = [
        (L("Photos", "照片"), [(L("Library", "图库"), 26), (L("Videos", "视频"), 14), (L("Shared", "共享"), 6)]),
        (L("Apps", "应用"), [(L("Games", "游戏"), 16), (L("Social", "社交"), 10), (L("Tools", "工具"), 8)]),
        (L("Media", "媒体"), [(L("Music", "音乐"), 12), (L("Podcasts", "播客"), 8), (L("Books", "图书"), 6)]),
        (L("System", "系统"), [(L("iOS", "iOS"), 11), (L("Cache", "缓存"), 7)]),
    ]
    let leafSplit: [Double] = [0.5, 0.3, 0.2]
    let total = tree.reduce(0.0) { $0 + $1.1.reduce(0.0) { $0 + $1.1 } }
    var nodes: [SunNode] = [SunNode(id: 0, name: L("Storage", "存储空间"), value: total, depth: 0, parent: nil, start: 0, end: 1, category: -1, sibling: 0)]
    var cursor = 0.0
    for (categoryIndex, category) in tree.enumerated() {
        let categoryValue = category.1.reduce(0.0) { $0 + $1.1 }
        let categoryID = nodes.count
        nodes.append(SunNode(id: categoryID, name: category.0, value: categoryValue, depth: 1, parent: 0, start: cursor, end: cursor + categoryValue / total, category: categoryIndex, sibling: categoryIndex))
        var childCursor = cursor
        for (childIndex, child) in category.1.enumerated() {
            let childID = nodes.count
            let childEnd = childCursor + child.1 / total
            nodes.append(SunNode(id: childID, name: child.0, value: child.1, depth: 2, parent: categoryID, start: childCursor, end: childEnd, category: categoryIndex, sibling: childIndex, tone: childIndex))
            var leafCursor = childCursor
            for (leafIndex, share) in leafSplit.enumerated() {
                let leafEnd = leafCursor + (childEnd - childCursor) * share
                nodes.append(SunNode(id: nodes.count, name: child.0, value: child.1 * share, depth: 3, parent: childID, start: leafCursor, end: leafEnd, category: categoryIndex, sibling: leafIndex, tone: childIndex))
                leafCursor = leafEnd
            }
            childCursor = childEnd
        }
        cursor += categoryValue / total
    }
    return nodes
}()

// MARK: - Arc

private struct SunArc: Shape {
    var start: Double
    var end: Double
    var inner: CGFloat
    var outer: CGFloat
    let gap: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(start, end), AnimatablePair(inner, outer)) }
        set {
            start = newValue.first.first
            end = newValue.first.second
            inner = newValue.second.first
            outer = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sweep = (end - start) * 2 * Double.pi
        guard sweep > 0.004, outer - inner > 0.5, outer > 1 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let from = start * 2 * Double.pi - Double.pi / 2
        let padOuter = min(Double(gap / 2 / outer), sweep * 0.45)
        let padInner = min(Double(gap / 2 / max(inner, 1)), sweep * 0.45)
        path.addArc(center: center, radius: outer, startAngle: .radians(from + padOuter), endAngle: .radians(from + sweep - padOuter), clockwise: false)
        path.addArc(center: center, radius: max(inner, 0.5), startAngle: .radians(from + sweep - padInner), endAngle: .radians(from + padInner), clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Demo

private struct SunburstDemo: View {
    let ctx: DemoContext
    @State private var focus = 0
    @State private var spotlight: Int?
    @State private var entrance: Double = 1
    @State private var autoStep = 0

    private let side: CGFloat = 250
    private static let core: CGFloat = 38
    private static let ringA: ClosedRange<CGFloat> = 42...80
    private static let ringB: ClosedRange<CGFloat> = 83...114

    private struct Placement {
        var start: Double
        var end: Double
        var inner: CGFloat
        var outer: CGFloat
        var visible: Bool
    }

    private func placement(_ node: SunNode) -> Placement {
        let target = sunNodes[focus]
        let span = max(target.end - target.start, 0.0001)
        let start = ((node.start - target.start) / span).clamped(to: 0...1)
        let end = ((node.end - target.start) / span).clamped(to: 0...1)
        switch node.depth - target.depth {
        case 1:
            return Placement(start: start, end: end, inner: Self.ringA.lowerBound, outer: Self.ringA.upperBound, visible: true)
        case 2:
            return Placement(start: start, end: end, inner: Self.ringB.lowerBound, outer: Self.ringB.upperBound, visible: true)
        case let offset where offset > 2:
            return Placement(start: start, end: end, inner: Self.ringB.upperBound + 2, outer: Self.ringB.upperBound + 2.5, visible: false)
        default:
            return Placement(start: start, end: end, inner: Self.core - 6, outer: Self.core, visible: false)
        }
    }

    var body: some View {
        ChartStage(hint: L("Tap a segment to drill in, the centre to go back", "点击扇区钻入，点击中心返回"), ctx: ctx) {
            ZStack {
                ForEach(sunNodes.dropFirst()) { node in
                    arc(node)
                }
                labels
                    .id(focus)
                    .transition(.opacity)
                centerDisc
            }
            .frame(width: side, height: side)
            .scaleEffect(0.82 + 0.18 * entrance)
            .rotationEffect(.degrees(-50 * (1 - entrance)))
            .opacity(entrance)
            .contentShape(Rectangle())
            .onTapGesture { location in tap(location) }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: { entrance = 0 }, then: {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.78)) { entrance = 1 }
            })
        }
        // The entrance already plays on arrival; the intro would leave the chart zoomed in.
        .autoplay(ctx.isPreview, every: 1.7, delay: 1.5, intro: false) { autoAdvance() }
    }

    private func color(_ node: SunNode) -> Color {
        let category = max(node.category, 0)
        switch node.depth {
        case 1:
            return sunColors[category].color()
        case 2:
            let ramp = sunRamps[category]
            return ramp[node.tone % ramp.count].mixed(ChartRGB(0xFFFFFF), 0.16).color()
        default:
            let ramp = sunRamps[category]
            return ramp[node.tone % ramp.count].mixed(ChartRGB(0xFFFFFF), 0.34 + 0.1 * Double(node.sibling)).color()
        }
    }

    private func arc(_ node: SunNode) -> some View {
        let place = placement(node)
        let dimmed = spotlight != nil && spotlight != node.id && sunNodes[node.id].parent != spotlight
        return SunArc(start: place.start, end: place.end, inner: place.inner, outer: place.outer, gap: ctx.cg("gap"))
            .fill(color(node))
            .opacity(place.visible ? (dimmed ? 0.3 : 1) : 0)
    }

    /// Names on the inner ring, only where the arc is wide enough to carry one.
    private var labels: some View {
        let target = sunNodes[focus]
        return ZStack {
            ForEach(sunNodes.filter { $0.depth == target.depth + 1 }) { node in
                let place = placement(node)
                if place.end - place.start > 0.1 {
                    let mid = (place.start + place.end) / 2 * 2 * Double.pi - Double.pi / 2
                    let radius = (Self.ringA.lowerBound + Self.ringA.upperBound) / 2
                    Text(node.name, ctx.language)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .fixedSize()
                        .offset(x: CGFloat(cos(mid)) * radius, y: CGFloat(sin(mid)) * radius)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var centerDisc: some View {
        let shown = sunNodes[spotlight ?? focus]
        let zoomed = focus != 0
        let tint = zoomed ? sunColors[max(sunNodes[focus].category, 0)].color() : Color.clear
        return ZStack {
            Circle()
                .fill(Palette.elevated)
                .overlay(Circle().fill(tint.opacity(0.16)))
                .overlay(Circle().strokeBorder(Palette.stroke))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            VStack(spacing: 0) {
                if zoomed {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.secondary)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(verbatim: "\(Int(shown.value.rounded()))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: shown.value))
                Text(verbatim: shown.name(ctx.language) + " · GB")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.opacity)
            }
            .frame(width: Self.core * 2 - 10)
        }
        .frame(width: Self.core * 2, height: Self.core * 2)
        .allowsHitTesting(false)
    }

    private func tap(_ location: CGPoint) {
        let dx = location.x - side / 2
        let dy = location.y - side / 2
        let radius = (dx * dx + dy * dy).squareRoot()
        if radius <= Self.core + 2 {
            if spotlight != nil { highlight(nil) } else { zoom(to: sunNodes[focus].parent ?? 0) }
            return
        }
        let ring: Int
        if radius <= Self.ringA.upperBound + 1.5 { ring = 1 } else if radius <= Self.ringB.upperBound + 10 { ring = 2 } else {
            highlight(nil)
            return
        }
        var fraction = (Double(atan2(dy, dx)) + Double.pi / 2) / (2 * Double.pi)
        if fraction < 0 { fraction += 1 }
        let depth = sunNodes[focus].depth + ring
        guard let hit = sunNodes.first(where: { node in
            guard node.depth == depth else { return false }
            let place = placement(node)
            return fraction >= place.start && fraction < place.end
        }) else { return }

        if focus == 0 {
            // At the root, either ring drills into the category that owns the tapped arc.
            zoom(to: ring == 1 ? hit.id : (hit.parent ?? 0))
        } else {
            let item = ring == 1 ? hit.id : (hit.parent ?? hit.id)
            highlight(spotlight == item ? nil : item)
        }
    }

    /// Taps and autoplay share this: every arc re-targets in one spring.
    private func zoom(to node: Int) {
        guard node != focus else { return }
        Haptics.tap(node == 0 ? .light : .medium)
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            focus = node
            spotlight = nil
        }
    }

    private func highlight(_ node: Int?) {
        guard node != spotlight else { return }
        Haptics.selection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { spotlight = node }
    }

    private func autoAdvance() {
        let categories = sunNodes.filter { $0.depth == 1 }.map(\.id)
        let step = autoStep % 6
        autoStep += 1
        switch step {
        case 0: zoom(to: categories[0])
        case 1: highlight(sunNodes.first { $0.parent == categories[0] }?.id)
        case 2: zoom(to: 0)
        case 3: zoom(to: categories[2])
        case 4: highlight(sunNodes.last { $0.parent == categories[2] }?.id)
        default: zoom(to: 0)
        }
    }
}
