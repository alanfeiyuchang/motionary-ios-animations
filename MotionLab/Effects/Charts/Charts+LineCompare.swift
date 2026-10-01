import SwiftUI

extension Effect {
    static let chartsLineCompare = Effect(
        id: "charts.line-compare",
        category: .charts,
        interaction: .gesture,
        name: L("Compare Crosshair", "双线对比十字线"),
        summary: L("Scrub two lines at once: the gap between them is shaded and a delta pill rides the crosshair, flipping colour with the lead.", "同时扫过两条折线：两线之间的差距被着色，差值胶囊跟随十字线，并随领先方变色。"),
        prompt: L(
            "A comparison card: this week (2.5 pt indigo line) against last week (2 pt grey line) over seven days, with the region between them tinted green where this week leads and red where it trails (16% opacity). The lines draw on left to right in 1 s, then a crosshair appears at today. Dragging horizontally moves a dashed hairline with a white-ringed dot on each line; a 4 pt rounded bar spans the gap between the dots and a delta pill floats beside it, its arrow and colour blending red → amber → green as the lead changes, and sliding to the other side near the right edge. The crosshair follows the finger on an interactive spring (response 0.18 s) and both legend values are read from the same interpolated position. On release it glides back to today. Analytical, immediate and legible.",
            "对比卡片：七天内的本周（2.5pt 靛蓝线）与上周（2pt 灰线），两线之间的区域在本周领先处染绿、落后处染红（不透明度 16%）。两条线用 1 秒自左向右绘出，随后十字线出现在「今天」。横向拖动时，一条虚线细线移动，两条线上各有一个白环圆点；两点之间由一根 4pt 圆头短柱连接差距，旁边浮着差值胶囊——箭头与颜色随领先关系在红 → 琥珀 → 绿之间渐变，靠近右缘时滑到另一侧。十字线以交互弹簧（响应 0.18 秒）跟随手指，两个图例数值取自同一个插值位置；松手后滑回今天。理性、即时、清晰易读。"
        ),
        implementation: L(
            "The whole card is an Animatable view over (crosshair x, draw-on, focus). Both series are Catmull-Rom resampled once; a Canvas splits the between-lines polygon at every crossing to colour it by sign, and the legend values, gap bar and pill are all sampled at the interpolated x.",
            "整张卡片是以（十字线位置、绘制进度、聚焦度）为动画数据的 Animatable 视图。两组数据预先用 Catmull-Rom 重采样；Canvas 在每个交点处切分两线之间的多边形并按正负着色，图例数值、差距短柱与胶囊都在插值后的位置上取样。"
        ),
        apis: ["Animatable", "AnimatablePair", "Canvas", "DragGesture", "interactiveSpring", "GestureState"],
        tags: ["compare", "crosshair", "two lines", "delta", "对比", "十字线", "双折线", "差值"],
        params: [
            .toggle("snap", L("Snap to days", "吸附到每天"), default: false),
            .slider("shade", L("Gap shading", "差距着色"), 0...0.4, default: 0.16),
            .slider("follow", L("Follow response", "跟随弹簧响应"), 0.05...0.5, default: 0.18, unit: "s"),
        ]
    ) { ctx in
        LineCompareDemo(ctx: ctx)
    }
}

private let compareThis: [Double] = ChartKit.resample([118, 134, 126, 152, 141, 168, 176], perSegment: 10)
private let compareLast: [Double] = ChartKit.resample([126, 122, 139, 137, 150, 144, 158], perSegment: 10)
private let compareRange: ClosedRange<Double> = 105...185

private struct LineCompareDemo: View {
    let ctx: DemoContext
    @State private var position: Double = 1
    @State private var draw: Double = 1
    @State private var focus: Double = 1
    @State private var engaged = false
    @State private var autoStep = 0
    @State private var run: Task<Void, Never>?
    @GestureState private var touching = false

    private let plotWidth: CGFloat = 268
    private static let stops: [Double] = [0.24, 0.7, 0.45, 0.93, 0.1]

    var body: some View {
        ChartStage(hint: L("Drag across the chart to compare", "在图表上左右滑动对比"), ctx: ctx) {
            LineCompareCard(
                position: position,
                draw: draw,
                focus: focus,
                shade: ctx["shade"],
                plotWidth: plotWidth,
                language: ctx.language,
                gesture: AnyGesture(scrubGesture.map { _ in () })
            )
            .padding(16)
            .frame(width: 300)
            .demoCard()
        }
        .onChange(of: touching) { _, isTouching in
            if !isTouching { release() }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                draw = 0
                focus = 0
            }, then: { drawOn() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.3, delay: 1.7) { glide() }
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in scrub(value) }
            .onEnded { _ in release() }
    }

    private func drawOn() {
        withAnimation(.easeInOut(duration: 1)) { draw = 1 }
        run?.cancel()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.85))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { focus = 1 }
        }
    }

    /// Horizontal-first, so a vertical swipe on the chart still scrolls the page.
    private func scrub(_ value: DragGesture.Value) {
        if !engaged {
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            engaged = true
            Haptics.tap(.light)
        }
        var target = Double(value.location.x / plotWidth).clamped(to: 0...1)
        if ctx.bool("snap") {
            target = (target * 6).rounded() / 6
            if abs(target - position) > 0.01 { Haptics.selection() }
        }
        withAnimation(.interactiveSpring(response: ctx["follow"], dampingFraction: 0.82)) {
            position = target
            focus = 1
            draw = 1
        }
    }

    private func release() {
        guard engaged else { return }
        engaged = false
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { position = 1 }
    }

    /// Autoplay and the arrival play: the crosshair glides between a few days.
    private func glide() {
        guard !engaged else { return }
        let target = Self.stops[autoStep % Self.stops.count]
        autoStep += 1
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
            position = target
            focus = 1
        }
    }
}

private struct LineCompareCard: View, Animatable {
    var position: Double
    var draw: Double
    var focus: Double
    let shade: Double
    let plotWidth: CGFloat
    let language: AppLanguage
    let gesture: AnyGesture<Void>

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(position, AnimatablePair(draw, focus)) }
        set {
            position = newValue.first
            draw = newValue.second.first
            focus = newValue.second.second
        }
    }

    private static let plotHeight: CGFloat = 150
    private static let inset: CGFloat = 10

    private var x: Double { min(max(position, 0), 1) }
    private var current: Double { ChartKit.sample(compareThis, at: x) }
    private var previous: Double { ChartKit.sample(compareLast, at: x) }

    private func y(_ value: Double) -> CGFloat {
        let span = compareRange.upperBound - compareRange.lowerBound
        let usable = Self.plotHeight - Self.inset * 2
        return Self.inset + usable * CGFloat(1 - (value - compareRange.lowerBound) / span)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ZStack(alignment: .topLeading) {
                canvas
                pill
            }
            .frame(width: plotWidth, height: Self.plotHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .simultaneousGesture(gesture)
            axis
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            legend(L("This week", "本周"), value: current, color: Palette.indigo, dashed: false)
            legend(L("Last week", "上周"), value: previous, color: Color.secondary, dashed: true)
            Spacer()
            Text(dayLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    private var dayLabel: String {
        let index = min(max(Int((x * 6).rounded()), 0), 6)
        let en = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Today"]
        let zh = ["周一", "周二", "周三", "周四", "周五", "周六", "今天"]
        return language == .zh ? zh[index] : en[index]
    }

    private func legend(_ name: LocalizedText, value: Double, color: Color, dashed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Capsule().fill(color).frame(width: 12, height: 3)
                Text(name, language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: "\(Int(value.rounded()))")
                .font(.system(size: dashed ? 20 : 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(dashed ? Color.secondary : Color.primary)
                .frame(height: 28, alignment: .bottom)
        }
    }

    private var canvas: some View {
        let cross = x
        let shown = draw
        let visible = focus
        let tintAmount = shade
        let yThis = y(current)
        let yLast = y(previous)
        let tone = ChartRGB.trend((current - previous) / 8)
        return Canvas { context, size in
            let count = compareThis.count
            let step = size.width / CGFloat(count - 1)
            let top: [CGPoint] = compareThis.indices.map { CGPoint(x: CGFloat($0) * step, y: y(compareThis[$0])) }
            let bottom: [CGPoint] = compareLast.indices.map { CGPoint(x: CGFloat($0) * step, y: y(compareLast[$0])) }

            for line in 0...2 {
                let lineY = Self.inset + (size.height - Self.inset * 2) * CGFloat(line) / 2
                var rule = Path()
                rule.move(to: CGPoint(x: 0, y: lineY))
                rule.addLine(to: CGPoint(x: size.width, y: lineY))
                context.stroke(rule, with: .color(.primary.opacity(0.06)), lineWidth: 1)
            }

            var clipped = context
            clipped.clip(to: Path(CGRect(x: 0, y: 0, width: size.width * CGFloat(shown) + 0.5, height: size.height)))

            // Shade between the lines, split at each crossing so every piece has one sign.
            var lead = Path()
            var trail = Path()
            for index in 0..<(count - 1) {
                let a0 = top[index], a1 = top[index + 1]
                let b0 = bottom[index], b1 = bottom[index + 1]
                let d0 = b0.y - a0.y
                let d1 = b1.y - a1.y
                func quad(_ path: inout Path, _ p: [CGPoint]) {
                    path.move(to: p[0])
                    for point in p.dropFirst() { path.addLine(to: point) }
                    path.closeSubpath()
                }
                if d0 * d1 < 0 {
                    let t = d0 / (d0 - d1)
                    let crossPoint = CGPoint(x: a0.x + (a1.x - a0.x) * t, y: a0.y + (a1.y - a0.y) * t)
                    if d0 > 0 {
                        quad(&lead, [a0, crossPoint, b0])
                        quad(&trail, [crossPoint, a1, b1])
                    } else {
                        quad(&trail, [a0, crossPoint, b0])
                        quad(&lead, [crossPoint, a1, b1])
                    }
                } else if d0 + d1 >= 0 {
                    quad(&lead, [a0, a1, b1, b0])
                } else {
                    quad(&trail, [a0, a1, b1, b0])
                }
            }
            clipped.fill(lead, with: .color(Palette.green.opacity(tintAmount)))
            clipped.fill(trail, with: .color(Palette.red.opacity(tintAmount)))

            var lastLine = Path()
            lastLine.addLines(bottom)
            clipped.stroke(lastLine, with: .color(.secondary.opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            var thisLine = Path()
            thisLine.addLines(top)
            clipped.stroke(thisLine, with: .color(Palette.indigo), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            guard visible > 0.01 else { return }
            var marks = context
            marks.opacity = min(visible, 1)
            let crossX = size.width * CGFloat(cross)
            var hair = Path()
            hair.move(to: CGPoint(x: crossX, y: 0))
            hair.addLine(to: CGPoint(x: crossX, y: size.height))
            marks.stroke(hair, with: .color(.primary.opacity(0.28)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            var gap = Path()
            gap.move(to: CGPoint(x: crossX, y: yThis))
            gap.addLine(to: CGPoint(x: crossX, y: yLast))
            marks.stroke(gap, with: .color(tone.color()), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            let radius: CGFloat = 5.5 * CGFloat(min(visible, 1.2))
            for (pointY, color) in [(yLast, Color.secondary), (yThis, Palette.indigo)] {
                let ring = CGRect(x: crossX - radius, y: pointY - radius, width: radius * 2, height: radius * 2)
                marks.fill(Path(ellipseIn: ring), with: .color(.white))
                marks.fill(Path(ellipseIn: ring.insetBy(dx: 2.2, dy: 2.2)), with: .color(color))
            }
        }
        .frame(width: plotWidth, height: Self.plotHeight)
    }

    private var pill: some View {
        let delta = current - previous
        let tone = ChartRGB.trend(delta / 8)
        let side = ChartKit.smoothstep(0.66, 0.8, x)
        let offset = 40 - 80 * CGFloat(side)
        let centerY = min(max((y(current) + y(previous)) / 2, 14), Self.plotHeight - 14)
        let centerX = min(max(plotWidth * CGFloat(x) + offset, 28), plotWidth - 28)
        return HStack(spacing: 3) {
            Image(systemName: "arrow.up")
                .font(.system(size: 9, weight: .heavy))
                .rotationEffect(.degrees(90 - 90 * min(max(delta / 8, -1), 1)))
            Text(verbatim: "\(abs(Int(delta.rounded())))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(tone.mixed(ChartRGB(0x000000), 0.12).color(), in: Capsule())
        .shadow(color: tone.color(0.4), radius: 6, y: 3)
        .scaleEffect(0.6 + 0.4 * min(focus, 1.15))
        .opacity(min(focus, 1))
        .position(x: centerX, y: centerY)
        .allowsHitTesting(false)
    }

    private var axis: some View {
        let labels = language == .zh ? ["一", "二", "三", "四", "五", "六", "今"] : ["M", "T", "W", "T", "F", "S", "T"]
        return HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                Text(verbatim: labels[index])
                if index < labels.count - 1 { Spacer(minLength: 0) }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: plotWidth)
    }
}
