import SwiftUI

extension Effect {
    static let chartsPanZoom = Effect(
        id: "charts.pan-zoom",
        category: .charts,
        interaction: .gesture,
        name: L("Pan & Pinch Timeline", "平移捏合时间轴"),
        summary: L("Drag a time series with inertia and pinch to zoom; axis ticks fade between months, 5-day and daily steps and the value scale re-fits.", "带惯性地拖动时间序列，捏合缩放；坐标刻度在月、5 日与单日之间淡入淡出，数值范围自动适配。"),
        prompt: L(
            "A six-month time series in a card, showing a 60-day window as a 2 pt indigo line with a gradient area. Dragging pans the window 1:1; on release it keeps gliding with the finger's velocity and decelerates on a critically damped spring (response 0.9 s), rubber-banding at both ends of the data. Pinching zooms around the pinch centre between 10 and 180 days; double-tap (or the zoom chip) toggles 60 ↔ 20 days at the tapped point on a spring (response 0.5 s, damping 0.82). Axis ticks belong to three levels (months, every 5 days, every day): each level's labels and grid lines fade in only once their spacing passes about 24 pt, so the axis re-flows instead of popping. The vertical scale re-fits the visible data every frame, a minimap window tracks the viewport, and the header rolls the date range and change. Fluid, map-like, in control.",
            "半年时间序列，默认显示 60 天窗口：2pt 靛蓝折线加渐变面积。拖动时窗口 1:1 跟手；松手后带着手指速度继续滑行，以临界阻尼弹簧（响应 0.9 秒）减速，两端橡皮筋回弹。捏合以捏合中心为锚点缩放，范围 10 到 180 天；双击或点缩放胶囊以弹簧（响应 0.5 秒、阻尼 0.82）在 60 ↔ 20 天间切换。刻度分三级（月、每 5 天、每天）：每一级的标签与网格线在间距超过约 24pt 后才淡入，坐标轴平滑重排。纵向范围每帧适配可见数据，小地图窗口跟随视口，标题滚动显示日期范围与涨跌。像地图一样流畅。"
        ),
        implementation: L(
            "The viewport is two animatable Doubles (start day, span). A Canvas maps days to x from the interpolated viewport, fits the y range to the visible samples plus the interpolated edge values so it stays continuous, and gives each tick the opacity of its own level's pixel spacing. Drag and MagnifyGesture run simultaneously; release animates to the velocity-projected, clamped target.",
            "视口是两个可动画的 Double（起始日、跨度）。Canvas 根据插值后的视口把日期映射到 x，纵向范围取可见采样加上两端的插值，从而保持连续；每个刻度的不透明度由它所属层级的像素间距决定。DragGesture 与 MagnifyGesture 同时识别，松手时动画到按速度投射并夹紧后的目标。"
        ),
        apis: ["Animatable", "Canvas", "DragGesture", "MagnifyGesture", "SpatialTapGesture", "predictedEndTranslation"],
        tags: ["pan", "pinch zoom", "inertia", "time series", "平移", "捏合缩放", "惯性", "时间序列"],
        params: [
            .slider("glide", L("Inertia", "惯性"), 0...1.5, default: 1),
            .slider("zoom", L("Double-tap span", "双击后的跨度"), 10...40, default: 20, step: 1, decimals: 0, unit: "d"),
            .toggle("minimap", L("Minimap", "小地图"), default: true),
        ]
    ) { ctx in
        PanZoomDemo(ctx: ctx)
    }
}

private let panZoomDays = 180
private let panZoomSeries: [Double] = (0...panZoomDays).map { day in
    let d = Double(day)
    let trend = 96 + d * 0.22
    let waves = sin(d / 9.5) * 9 + sin(d / 3.7 + 1.2) * 3.2 + sin(d / 27 + 0.6) * 14
    let noise = (ChartKit.hash(day, 7) - 0.5) * 3.4
    return trend + waves + noise
}

private func panZoomValue(_ day: Double) -> Double {
    ChartKit.sample(panZoomSeries, at: day / Double(panZoomDays))
}

private func panZoomDate(_ day: Double, _ language: AppLanguage) -> String {
    let d = Int(day.rounded()).clamped(to: 0...panZoomDays)
    let month = min(d / 30, 6)
    let dayOfMonth = max(d - month * 30, 1)
    let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"]
    return language == .zh ? "\(month + 1)月\(dayOfMonth)日" : "\(names[month]) \(dayOfMonth)"
}

private struct PanZoomDemo: View {
    let ctx: DemoContext
    @State private var start: Double = 112
    @State private var span: Double = 60
    @State private var draw: Double = 1
    @State private var dragStart: Double?
    @State private var pinch: (span: Double, anchorDay: Double, anchorUnit: Double)?
    @State private var autoStep = 0

    private let plotWidth: CGFloat = 268
    private static let total = Double(panZoomDays)

    var body: some View {
        ChartStage(hint: L("Drag to pan · pinch or double-tap to zoom", "拖动平移 · 捏合或双击缩放"), ctx: ctx) {
            PanZoomCard(start: start, span: span, draw: draw, minimap: ctx.bool("minimap"), plotWidth: plotWidth, language: ctx.language, gesture: AnyGesture(gesture.map { _ in () }), onZoom: { toggleZoom(at: plotWidth / 2) })
                .padding(16)
                .frame(width: 300)
                .demoCard()
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: { draw = 0 }, then: {
                withAnimation(.easeInOut(duration: 0.8)) { draw = 1 }
            })
        }
        .autoplay(ctx.isPreview, every: 1.5, delay: 1.2) { auto() }
    }

    private var gesture: some Gesture {
        let drag = DragGesture(minimumDistance: 2)
            .onChanged { value in pan(value) }
            .onEnded { value in fling(value) }
        let magnify = MagnifyGesture()
            .onChanged { value in zoom(value) }
            .onEnded { _ in settle() }
        let doubleTap = SpatialTapGesture(count: 2)
            .onEnded { value in toggleZoom(at: value.location.x) }
        return doubleTap.simultaneously(with: drag.simultaneously(with: magnify))
    }

    private func limit(_ value: Double, span: Double) -> Double {
        value.clamped(to: 0...max(Self.total - span, 0))
    }

    private func pan(_ value: DragGesture.Value) {
        guard pinch == nil else { return }
        if dragStart == nil {
            dragStart = start
            Haptics.tap(.soft)
        }
        let origin = dragStart ?? start
        let raw = origin - Double(value.translation.width / plotWidth) * span
        let maxStart = max(Self.total - span, 0)
        // Rubber band past either end of the data.
        var target = raw
        if raw < 0 {
            target = -Double(rubberBand(CGFloat(-raw), limit: CGFloat(span * 0.3)))
        } else if raw > maxStart {
            target = maxStart + Double(rubberBand(CGFloat(raw - maxStart), limit: CGFloat(span * 0.3)))
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            start = target
            draw = 1
        }
    }

    private func fling(_ value: DragGesture.Value) {
        guard dragStart != nil else { return }
        dragStart = nil
        guard pinch == nil else { return }
        let extra = Double((value.predictedEndTranslation.width - value.translation.width) / plotWidth) * span * ctx["glide"]
        let target = limit(start - extra, span: span)
        let hitEnd = target != start - extra
        withAnimation(.spring(response: hitEnd ? 0.55 : 0.9, dampingFraction: hitEnd ? 0.78 : 1)) { start = target }
    }

    private func zoom(_ value: MagnifyGesture.Value) {
        if pinch == nil {
            let unit = Double(value.startAnchor.x).clamped(to: 0...1)
            pinch = (span, start + span * unit, unit)
            Haptics.tap(.soft)
        }
        guard let pinch else { return }
        let newSpan = (pinch.span / Double(max(value.magnification, 0.05))).clamped(to: 8...Self.total * 1.15)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            span = newSpan
            start = pinch.anchorDay - newSpan * pinch.anchorUnit
            draw = 1
        }
    }

    private func settle() {
        pinch = nil
        dragStart = nil
        let target = span.clamped(to: 10...Self.total)
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            span = target
            start = limit(start, span: target)
        }
    }

    private func toggleZoom(at x: CGFloat) {
        let unit = Double(x / plotWidth).clamped(to: 0...1)
        let anchor = start + span * unit
        let zoomed = ctx["zoom"]
        let target: Double = span > zoomed * 1.5 ? zoomed : 60
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            span = target
            start = limit(anchor - target * unit, span: target)
            draw = 1
        }
    }

    /// Autoplay and the arrival play: pan with a glide, zoom in, pan, zoom out, come back.
    private func auto() {
        guard dragStart == nil, pinch == nil else { return }
        let step = autoStep % 5
        autoStep += 1
        let zoomed = ctx["zoom"]
        switch step {
        case 0:
            withAnimation(.spring(response: 0.9, dampingFraction: 1)) { start = 58 }
        case 1:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                span = zoomed
                start = limit(88 - zoomed / 2, span: zoomed)
            }
        case 2:
            withAnimation(.spring(response: 0.9, dampingFraction: 1)) { start = limit(start + zoomed * 1.6, span: span) }
        case 3:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                span = 150
                start = 20
            }
        default:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                span = 60
                start = 112
            }
        }
    }
}

private struct PanZoomCard: View, Animatable {
    var start: Double
    var span: Double
    var draw: Double
    let minimap: Bool
    let plotWidth: CGFloat
    let language: AppLanguage
    let gesture: AnyGesture<Void>
    let onZoom: () -> Void

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(start, AnimatablePair(span, draw)) }
        set {
            start = newValue.first
            span = newValue.second.first
            draw = newValue.second.second
        }
    }

    private static let plotHeight: CGFloat = 132
    private static let total = Double(panZoomDays)

    private var visible: (from: Double, to: Double) {
        (max(start, 0), min(start + max(span, 1), Self.total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            canvas
                .frame(width: plotWidth, height: Self.plotHeight + 16)
                .contentShape(Rectangle())
                .gesture(gesture)
            if minimap {
                map.frame(width: plotWidth, height: 20)
            }
        }
    }

    private var header: some View {
        let range = visible
        let first = panZoomValue(range.from)
        let last = panZoomValue(range.to)
        let change = (last - first) / max(first, 1) * 100
        let tone = ChartRGB.trend(change / 6)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(panZoomDate(range.from, language)) – \(panZoomDate(range.to, language))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(verbatim: String(format: "%.1f", last))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(verbatim: String(format: "%+.1f%%", change).replacingOccurrences(of: "-", with: "−"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tone.mixed(ChartRGB(0x000000), 0.12).color())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(tone.color(0.16), in: Capsule())
                Button(action: onZoom) {
                    HStack(spacing: 3) {
                        Image(systemName: span > 40 ? "plus.magnifyingglass" : "minus.magnifyingglass")
                            .font(.system(size: 10, weight: .bold))
                        Text(verbatim: language == .zh ? "\(Int(span.rounded())) 天" : "\(Int(span.rounded())) days")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canvas: some View {
        let start = start
        let span = max(span, 1)
        let draw = min(max(draw, 0), 1)
        let language = language
        return Canvas { context, size in
            let height = Self.plotHeight
            let from = max(start, 0)
            let to = min(start + span, Self.total)
            func x(_ day: Double) -> CGFloat { size.width * CGFloat((day - start) / span) }

            // Fit the value range to what is visible (edges interpolated, so it never jumps).
            var low = min(panZoomValue(from), panZoomValue(to))
            var high = max(panZoomValue(from), panZoomValue(to))
            let firstDay = Int(from.rounded(.up))
            let lastDay = Int(to.rounded(.down))
            if firstDay <= lastDay {
                for day in firstDay...lastDay {
                    low = min(low, panZoomSeries[day])
                    high = max(high, panZoomSeries[day])
                }
            }
            let pad = max((high - low) * 0.16, 2)
            low -= pad
            high += pad
            func y(_ value: Double) -> CGFloat { height - height * CGFloat((value - low) / (high - low)) }

            // Ticks: each day belongs to the coarsest level that divides it and fades with that level's spacing.
            let levels: [(every: Int, alpha: Double)] = [(1, 16.0), (5, 22.0), (30, 22.0)].map { every, threshold in
                let spacing = Double(size.width) * Double(every) / span
                return (every, ChartKit.smoothstep(threshold, threshold + 10, spacing))
            }
            let tickFrom = max(Int((start - span * 0.05).rounded(.down)), 0)
            let tickTo = min(Int((start + span * 1.05).rounded(.up)), panZoomDays)
            if tickFrom <= tickTo {
                for day in tickFrom...tickTo {
                    let level = day % 30 == 0 ? 2 : (day % 5 == 0 ? 1 : 0)
                    let alpha = levels[level].alpha
                    guard alpha > 0.01 else { continue }
                    let tickX = x(Double(day))
                    var rule = Path()
                    rule.move(to: CGPoint(x: tickX, y: 0))
                    rule.addLine(to: CGPoint(x: tickX, y: height))
                    context.stroke(rule, with: .color(.primary.opacity((level == 2 ? 0.14 : 0.06) * alpha)), lineWidth: 1)
                    let text: String
                    if level == 2 {
                        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"]
                        text = language == .zh ? "\(day / 30 + 1)月" : names[min(day / 30, 6)]
                    } else {
                        text = "\(day % 30)"
                    }
                    var label = context
                    // Labels dissolve at the plot's edges instead of being cut off.
                    let edge = ChartKit.smoothstep(2, 16, Double(tickX)) * ChartKit.smoothstep(2, 16, Double(size.width - tickX))
                    label.opacity = alpha * edge
                    label.draw(
                        Text(verbatim: text)
                            .font(.system(size: 10, weight: level == 2 ? .semibold : .medium))
                            .foregroundStyle(level == 2 ? Color.primary.opacity(0.7) : Color.secondary),
                        at: CGPoint(x: tickX, y: height + 4),
                        anchor: .top
                    )
                }
            }

            // Series, one sample per day plus the two interpolated edges.
            var points: [CGPoint] = [CGPoint(x: x(from), y: y(panZoomValue(from)))]
            if firstDay <= lastDay {
                for day in firstDay...lastDay { points.append(CGPoint(x: x(Double(day)), y: y(panZoomSeries[day]))) }
            }
            points.append(CGPoint(x: x(to), y: y(panZoomValue(to))))
            var line = Path()
            line.addLines(points)
            var area = line
            area.addLine(to: CGPoint(x: x(to), y: height))
            area.addLine(to: CGPoint(x: x(from), y: height))
            area.closeSubpath()

            var plot = context
            plot.clip(to: Path(CGRect(x: 0, y: -6, width: size.width * CGFloat(draw), height: height + 6)))
            plot.fill(area, with: .linearGradient(
                Gradient(colors: [Palette.indigo.opacity(0.28), Palette.indigo.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: height)
            ))
            plot.stroke(line, with: .color(Palette.indigo), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Daily dots appear once days are far enough apart.
            let dotAlpha = levels[0].alpha
            if dotAlpha > 0.01, firstDay <= lastDay {
                for day in firstDay...lastDay {
                    let centre = CGPoint(x: x(Double(day)), y: y(panZoomSeries[day]))
                    let ring = CGRect(x: centre.x - 3.5, y: centre.y - 3.5, width: 7, height: 7)
                    plot.fill(Path(ellipseIn: ring), with: .color(.white.opacity(dotAlpha)))
                    plot.fill(Path(ellipseIn: ring.insetBy(dx: 1.6, dy: 1.6)), with: .color(Palette.indigo.opacity(dotAlpha)))
                }
            }

            var floor = Path()
            floor.move(to: CGPoint(x: 0, y: height))
            floor.addLine(to: CGPoint(x: size.width, y: height))
            context.stroke(floor, with: .color(.primary.opacity(0.16)), lineWidth: 1)
        }
    }

    private var map: some View {
        let start = start
        let span = span
        return Canvas { context, size in
            let low = panZoomSeries.min() ?? 0
            let high = panZoomSeries.max() ?? 1
            var line = Path()
            for day in stride(from: 0, through: panZoomDays, by: 2) {
                let point = CGPoint(
                    x: size.width * CGFloat(day) / CGFloat(panZoomDays),
                    y: size.height - 3 - (size.height - 6) * CGFloat((panZoomSeries[day] - low) / (high - low))
                )
                if day == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6, style: .continuous), with: .color(.primary.opacity(0.05)))
            context.stroke(line, with: .color(.secondary.opacity(0.7)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            let from = min(max(start / Self.total, 0), 1)
            let to = min(max((start + span) / Self.total, 0), 1)
            let window = CGRect(x: size.width * CGFloat(from), y: 0, width: max(size.width * CGFloat(to - from), 6), height: size.height)
            let shape = Path(roundedRect: window, cornerRadius: 6, style: .continuous)
            context.fill(shape, with: .color(Palette.indigo.opacity(0.2)))
            context.stroke(shape, with: .color(Palette.indigo), lineWidth: 1.5)
        }
    }
}
