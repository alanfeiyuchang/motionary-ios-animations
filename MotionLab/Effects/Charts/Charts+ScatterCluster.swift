import SwiftUI

extension Effect {
    static let chartsScatterCluster = Effect(
        id: "charts.scatter-cluster",
        category: .charts,
        interaction: .tap,
        name: L("Scatter to Clusters", "散点聚类"),
        summary: L("Grey scatter points take on colour and pull together into three clusters, then soft hulls inflate around them; tap to disperse.", "灰色散点染上颜色并聚成三簇，柔和的包络随后在它们周围鼓起；再次点击散开。"),
        prompt: L(
            "A scatter plot of 48 grey 7 pt dots on faint axes. Tapping runs the clustering: each dot blends from grey to its cluster colour (indigo, pink, mint) and travels toward its centroid on a spring (response 0.6 s, damping 0.72), starting up to 150 ms late at random so the cloud condenses organically and overshoots inward a little before settling. 250 ms later a rounded hull inflates from each centroid on a bouncier spring (response 0.45 s, damping 0.62): a smooth closed curve through the convex hull of the cluster padded by 10 pt, filled at 14% with a 1.5 pt outline, plus a centroid cross and a count label. The header's separation score rolls from 0 to 71%. Tapping again deflates the hulls first, then releases the dots back to their scattered positions as the colour drains. Analytical with a satisfying snap into order.",
            "散点图：48 个 7pt 灰色圆点。点击开始聚类：每个点从灰色过渡到所属簇的颜色（靛蓝、粉、薄荷绿），以弹簧（响应 0.6 秒、阻尼 0.72）移向质心；各点随机延迟最多 150ms 出发，点云自然凝聚并轻微过冲。250ms 后，圆润的包络以更有弹性的弹簧（响应 0.45 秒、阻尼 0.62）从质心鼓起：它是穿过该簇凸包并外扩 10pt 的平滑闭合曲线，14% 填充加 1.5pt 描边，带质心十字与数量标签。标题的分离度从 0 滚到 71%。再次点击，包络先收起，圆点回到散开的位置，颜色褪去。有“归位”的爽感。"
        ),
        implementation: L(
            "An Animatable Canvas over (gather, hull). Every dot derives a local progress from the gather value minus its own random delay, used for both position and colour; hulls are recomputed each frame from the interpolated dot positions with a monotone-chain convex hull, padded away from the centroid and smoothed with a closed Catmull-Rom.",
            "以（聚合度、包络度）为动画数据的 Animatable Canvas。每个圆点用聚合度减去自己的随机延迟得到局部进度，同时用于位置与颜色；包络每帧根据插值后的点位重新计算：单调链凸包、沿质心方向外扩，再用闭合 Catmull-Rom 平滑。"
        ),
        apis: ["Animatable", "AnimatablePair", "Canvas", "convex hull", "spring(response:dampingFraction:)"],
        tags: ["scatter", "cluster", "k-means", "hull", "散点图", "聚类", "分群", "包络"],
        params: [
            .slider("tight", L("Cluster spread", "簇半径"), 0.5...1.6, default: 1),
            .slider("pad", L("Hull padding", "包络外扩"), 3...18, default: 10, step: 1, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1.1, default: 0.6, unit: "s"),
        ]
    ) { ctx in
        ScatterClusterDemo(ctx: ctx)
    }
}

private struct ClusterPoint {
    let cluster: Int
    let scattered: CGPoint
    /// Offset from the centroid in the clustered state (unit space).
    let offset: CGPoint
    let delay: Double
}

private let clusterCentres: [CGPoint] = [CGPoint(x: 0.25, y: 0.34), CGPoint(x: 0.74, y: 0.3), CGPoint(x: 0.5, y: 0.76)]
private let clusterColours: [ChartRGB] = [.indigo, .pink, .mint]
private let clusterNames = ["A", "B", "C"]

private let clusterPoints: [ClusterPoint] = (0..<48).map { index in
    let cluster = index % 3
    let centre = clusterCentres[cluster]
    let sx = (centre.x + CGFloat(ChartKit.hash(index, 1) - 0.5) * 0.92).clamped(to: 0.04...0.96)
    let sy = (centre.y + CGFloat(ChartKit.hash(index, 2) - 0.5) * 0.98).clamped(to: 0.05...0.95)
    let radius = 0.035 + sqrt(ChartKit.hash(index, 3)) * 0.105
    let theta = ChartKit.hash(index, 4) * 2 * Double.pi
    return ClusterPoint(
        cluster: cluster,
        scattered: CGPoint(x: sx, y: sy),
        offset: CGPoint(x: radius * cos(theta), y: radius * sin(theta) * 1.25),
        delay: ChartKit.hash(index, 5) * 0.25
    )
}

private struct ScatterClusterDemo: View {
    let ctx: DemoContext
    @State private var gather: Double = 1
    @State private var hull: Double = 1
    @State private var appear: Double = 1
    @State private var clustered = true
    @State private var score: Double = 71
    @State private var run: Task<Void, Never>?

    var body: some View {
        ChartStage(hint: L("Tap to cluster and disperse", "点击聚类 / 散开"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 10) {
                header
                ScatterClusterPlot(gather: gather, hull: hull, appear: appear, tight: ctx["tight"], pad: ctx.cg("pad"))
                    .frame(width: 268, height: 190)
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                gather = 0
                hull = 0
                appear = 0
                clustered = false
                score = 0
            }, then: {
                withAnimation(.easeOut(duration: 0.7)) { appear = 1 }
            })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 2.1, delay: 1.0) { toggle() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Separation", "分离度"), ctx.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChartRollText(value: score) { "\(Int($0.rounded()))%" }
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: clustered ? "circle.hexagongrid.fill" : "circle.dotted")
                    .font(.system(size: 11, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                Text(clustered ? L("3 clusters", "3 个分群") : L("48 points", "48 个点"), ctx.language)
                    .font(.system(size: 12, weight: .semibold))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(clustered ? Palette.indigo : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((clustered ? Palette.indigo : Color.primary).opacity(clustered ? 0.14 : 0.06), in: Capsule())
        }
    }

    private func toggle() {
        Haptics.tap(.light)
        run?.cancel()
        let response = ctx["response"]
        let target = !clustered
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { clustered = target }
        withAnimation(.easeOut(duration: 0.25)) { appear = 1 }
        if target {
            withAnimation(.spring(response: response, dampingFraction: 0.72)) { gather = 1 }
            withAnimation(.easeInOut(duration: 0.8)) { score = 71 }
            run = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.25))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { hull = 1 }
                if !ctx.isPreview { Haptics.tap(.soft) }
            }
        } else {
            withAnimation(.easeIn(duration: 0.2)) { hull = 0 }
            withAnimation(.easeInOut(duration: 0.6)) { score = 0 }
            run = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.14))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: response * 1.1, dampingFraction: 0.8)) { gather = 0 }
            }
        }
    }
}

private struct ScatterClusterPlot: View, Animatable {
    var gather: Double
    var hull: Double
    var appear: Double
    let tight: Double
    let pad: CGFloat

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(gather, AnimatablePair(hull, appear)) }
        set {
            gather = newValue.first
            hull = newValue.second.first
            appear = newValue.second.second
        }
    }

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 14, y: 4, width: size.width - 18, height: size.height - 20)
            func place(_ unit: CGPoint) -> CGPoint {
                CGPoint(x: plot.minX + plot.width * unit.x, y: plot.minY + plot.height * unit.y)
            }

            // Axes and a light grid.
            for line in 1...3 {
                var rule = Path()
                let lineY = plot.minY + plot.height * CGFloat(line) / 4
                rule.move(to: CGPoint(x: plot.minX, y: lineY))
                rule.addLine(to: CGPoint(x: plot.maxX, y: lineY))
                let lineX = plot.minX + plot.width * CGFloat(line) / 4
                rule.move(to: CGPoint(x: lineX, y: plot.minY))
                rule.addLine(to: CGPoint(x: lineX, y: plot.maxY))
                context.stroke(rule, with: .color(.primary.opacity(0.05)), lineWidth: 1)
            }
            var axes = Path()
            axes.move(to: CGPoint(x: plot.minX, y: plot.minY))
            axes.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
            axes.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            context.stroke(axes, with: .color(.primary.opacity(0.18)), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

            // Current dot positions.
            var positions: [CGPoint] = []
            var locals: [Double] = []
            for point in clusterPoints {
                let local = min(max(gather * 1.25 - point.delay, 0), 1.2)
                let centre = clusterCentres[point.cluster]
                let home = CGPoint(x: centre.x + point.offset.x * tight, y: centre.y + point.offset.y * tight)
                positions.append(place(ChartKit.lerp(point.scattered, home, local)))
                locals.append(local)
            }

            // Hulls, inflating from each centroid.
            let inflate = max(hull, 0)
            if inflate > 0.01 {
                for cluster in 0..<3 {
                    let members = clusterPoints.indices.filter { clusterPoints[$0].cluster == cluster }.map { positions[$0] }
                    guard members.count > 2 else { continue }
                    let centroid = CGPoint(
                        x: members.reduce(0) { $0 + $1.x } / CGFloat(members.count),
                        y: members.reduce(0) { $0 + $1.y } / CGFloat(members.count)
                    )
                    let padded: [CGPoint] = ChartKit.convexHull(members).map { vertex in
                        let dx = vertex.x - centroid.x
                        let dy = vertex.y - centroid.y
                        let length = max(sqrt(dx * dx + dy * dy), 0.001)
                        let reach = (length + pad) * CGFloat(inflate)
                        return CGPoint(x: centroid.x + dx / length * reach, y: centroid.y + dy / length * reach)
                    }
                    let shape = ChartKit.smoothLoop(padded)
                    let colour = clusterColours[cluster]
                    let alpha = min(inflate, 1)
                    context.fill(shape, with: .color(colour.color(0.14 * alpha)))
                    context.stroke(shape, with: .color(colour.color(0.55 * alpha)), lineWidth: 1.5)

                    var cross = Path()
                    cross.move(to: CGPoint(x: centroid.x - 4, y: centroid.y))
                    cross.addLine(to: CGPoint(x: centroid.x + 4, y: centroid.y))
                    cross.move(to: CGPoint(x: centroid.x, y: centroid.y - 4))
                    cross.addLine(to: CGPoint(x: centroid.x, y: centroid.y + 4))
                    context.stroke(cross, with: .color(colour.mixed(ChartRGB(0x000000), 0.25).color(alpha)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                    let top = padded.map(\.y).min() ?? centroid.y
                    var label = context
                    label.opacity = alpha
                    label.draw(
                        Text(verbatim: "\(clusterNames[cluster]) · \(members.count)")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(colour.mixed(ChartRGB(0x000000), 0.15).color()),
                        at: CGPoint(x: centroid.x, y: max(top - 3, 9)),
                        anchor: .bottom
                    )
                }
            }

            // Dots.
            for index in clusterPoints.indices {
                let point = clusterPoints[index]
                let born = ChartKit.backOut(ChartKit.stagger(appear, delay: ChartKit.hash(index, 6) * 0.6, span: 0.4), overshoot: 2)
                guard born > 0.01 else { continue }
                let tint = ChartKit.smoothstep(0.1, 0.7, locals[index])
                let colour = ChartRGB.grey.mixed(clusterColours[point.cluster], tint)
                let radius = 3.5 * CGFloat(born)
                let centre = positions[index]
                let rect = CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(colour.color(0.55 + 0.4 * tint)))
                context.stroke(Path(ellipseIn: rect), with: .color(colour.mixed(ChartRGB(0x000000), 0.2).color(0.5)), lineWidth: 0.5)
            }
        }
    }
}
