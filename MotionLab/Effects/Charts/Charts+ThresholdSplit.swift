import SwiftUI

extension Effect {
    static let chartsThresholdSplit = Effect(
        id: "charts.threshold-split",
        category: .charts,
        interaction: .gesture,
        name: L("Threshold Split", "阈值分色折线"),
        summary: L("Drag a threshold up and down: the line and its fill turn coral above it and blue below, and the time-above figure rolls.", "上下拖动阈值线：折线与填充在线上变珊瑚色、线下变蓝色，超出时长的数字随之滚动。"),
        prompt: L(
            "A glucose-style card: one smooth 2.5 pt line over 24 hours crossed by a horizontal dashed threshold with a value handle on the right edge. The line is drawn twice through two clip regions, coral above the threshold and sky blue below, and the space between line and threshold is filled the same way (20% opacity), so peaks read as warm islands and dips as cool pools. On appear the line draws on in 0.9 s and the fills fade up. Dragging vertically moves the threshold with the finger on an interactive spring (response 0.14 s); colours re-split continuously, the handle swells to 1.12× and the “time above” percentage rolls. On release the threshold snaps to the nearest 5 on a bouncy spring (response 0.4 s, damping 0.6) with a light tick. Diagnostic, tactile and instantly readable.",
            "血糖卡片：一条 2.5pt 平滑折线覆盖 24 小时，被一条水平虚线阈值穿过，阈值右端带数值手柄。折线通过两个裁剪区域绘制两遍，阈值以上珊瑚色、以下天蓝色；折线与阈值之间的区域同样分色填充（不透明度 20%），高峰像暖色小岛，低谷像冷色水洼。出现时折线用 0.9 秒画出，填充随后淡入。纵向拖动时阈值以交互弹簧（响应 0.14 秒）跟手，颜色连续重新分割，手柄放大到 1.12 倍，“超出时长”百分比同步滚动。松手后阈值以弹簧（响应 0.4 秒、阻尼 0.6）吸附到最近的 5，并有一次轻触感。一眼读懂。"
        ),
        implementation: L(
            "The card is Animatable over (threshold, draw, fill). A Canvas builds the line once, closes it against the threshold line for the fill, and paints both through two clip rectangles split at the threshold's y; the share of samples above the interpolated threshold drives the header.",
            "卡片是以（阈值、绘制进度、填充度）为动画数据的 Animatable 视图。Canvas 只构造一次折线，并与阈值线闭合成填充区域，再通过以阈值高度分割的两个裁剪矩形分别上色；高于插值阈值的采样占比驱动标题数字。"
        ),
        apis: ["Animatable", "Canvas", "GraphicsContext.clip(to:)", "DragGesture", "interactiveSpring"],
        tags: ["threshold", "split colour", "above below", "limit line", "阈值", "分色", "上下区间", "警戒线"],
        params: [
            .slider("follow", L("Follow response", "跟随弹簧响应"), 0.05...0.5, default: 0.14, unit: "s"),
            .slider("fill", L("Fill opacity", "填充不透明度"), 0...0.45, default: 0.2),
            .toggle("snap", L("Snap to 5", "吸附到 5 的倍数"), default: true),
        ]
    ) { ctx in
        ThresholdDemo(ctx: ctx)
    }
}

private let thresholdSeries: [Double] = ChartKit.resample(
    [96, 88, 84, 91, 112, 149, 133, 106, 95, 102, 127, 138, 124, 99, 89, 96, 131, 163, 150, 118, 100],
    perSegment: 6
)
private let thresholdRange: ClosedRange<Double> = 70...175

private struct ThresholdDemo: View {
    let ctx: DemoContext
    @State private var threshold: Double = 120
    @State private var draw: Double = 1
    @State private var fill: Double = 1
    @State private var grab: Double = 0
    @State private var engaged = false
    @State private var startValue: Double = 120
    @State private var autoStep = 0
    @State private var run: Task<Void, Never>?
    @GestureState private var touching = false

    private static let stops: [Double] = [145, 100, 130, 90, 120]

    var body: some View {
        ChartStage(hint: L("Drag the threshold up and down", "上下拖动阈值线"), ctx: ctx) {
            ThresholdCard(
                threshold: threshold,
                draw: draw,
                fill: fill,
                grab: grab,
                fillOpacity: ctx["fill"],
                language: ctx.language,
                gesture: AnyGesture(dragGesture.map { _ in () })
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
                fill = 0
            }, then: { enter() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.4, delay: 1.6) { glide() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in drag(value) }
            .onEnded { _ in release() }
    }

    private func enter() {
        withAnimation(.easeInOut(duration: 0.9)) { draw = 1 }
        run?.cancel()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) { fill = 1 }
        }
    }

    private func drag(_ value: DragGesture.Value) {
        if !engaged {
            engaged = true
            run?.cancel()
            startValue = threshold
            Haptics.tap(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { grab = 1 }
        }
        let span = thresholdRange.upperBound - thresholdRange.lowerBound
        let delta = Double(-value.translation.height / ThresholdCard.plotHeight) * span
        let target = (startValue + delta).clamped(to: 80...165)
        withAnimation(.interactiveSpring(response: ctx["follow"], dampingFraction: 0.86)) {
            threshold = target
            draw = 1
            fill = 1
        }
    }

    private func release() {
        guard engaged else { return }
        engaged = false
        let target = ctx.bool("snap") ? (threshold / 5).rounded() * 5 : threshold
        Haptics.tap(.rigid)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            threshold = target
            grab = 0
        }
    }

    /// Autoplay and the arrival play: the threshold travels between a few levels.
    private func glide() {
        guard !engaged else { return }
        let target = Self.stops[autoStep % Self.stops.count]
        autoStep += 1
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
            threshold = target
            fill = 1
        }
    }
}

private struct ThresholdCard: View, Animatable {
    var threshold: Double
    var draw: Double
    var fill: Double
    var grab: Double
    let fillOpacity: Double
    let language: AppLanguage
    let gesture: AnyGesture<Void>

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(threshold, draw), AnimatablePair(fill, grab)) }
        set {
            threshold = newValue.first.first
            draw = newValue.first.second
            fill = newValue.second.first
            grab = newValue.second.second
        }
    }

    static let plotHeight: CGFloat = 158
    private static let plotWidth: CGFloat = 268
    private static let handleWidth: CGFloat = 38

    private func y(_ value: Double) -> CGFloat {
        let t = (value - thresholdRange.lowerBound) / (thresholdRange.upperBound - thresholdRange.lowerBound)
        return Self.plotHeight - Self.plotHeight * CGFloat(t)
    }

    private var above: Double {
        let count = thresholdSeries.filter { $0 > threshold }.count
        // Blend in the samples closest to the line so the figure moves smoothly, not in steps.
        let near = thresholdSeries.reduce(0.0) { $0 + ChartKit.smoothstep(-3, 3, $1 - threshold) }
        return (Double(count) * 0.2 + near * 0.8) / Double(thresholdSeries.count) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ZStack(alignment: .topLeading) {
                canvas
                handle
            }
            .frame(width: Self.plotWidth, height: Self.plotHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .highPriorityGesture(gesture)
            axis
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Time above limit", "高于阈值的时间"), language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: "\(Int(above.rounded()))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(verbatim: "%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                key(L("Above", "以上"), color: Palette.coral)
                key(L("Below", "以下"), color: Palette.sky)
            }
        }
    }

    private func key(_ name: LocalizedText, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(name, language)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var axis: some View {
        HStack(spacing: 0) {
            ForEach(["00", "06", "12", "18", "24"], id: \.self) { label in
                Text(verbatim: label)
                if label != "24" { Spacer(minLength: 0) }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(width: Self.plotWidth - Self.handleWidth - 4)
    }

    private var handle: some View {
        Text(verbatim: "\(Int(threshold.rounded()))")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: Self.handleWidth, height: 22)
            .background(Color(hex: 0x3A3A44), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
            .scaleEffect(1 + 0.12 * grab)
            .position(x: Self.plotWidth - Self.handleWidth / 2, y: y(threshold))
            .allowsHitTesting(false)
    }

    private var canvas: some View {
        let limitY = y(threshold)
        let draw = min(max(draw, 0), 1)
        let fill = min(max(fill, 0), 1)
        let amount = fillOpacity
        let grab = grab
        return Canvas { context, size in
            let width = size.width - Self.handleWidth - 4
            let step = width / CGFloat(thresholdSeries.count - 1)
            let points: [CGPoint] = thresholdSeries.indices.map { CGPoint(x: CGFloat($0) * step, y: y(thresholdSeries[$0])) }
            var line = Path()
            line.addLines(points)
            var region = line
            region.addLine(to: CGPoint(x: width, y: limitY))
            region.addLine(to: CGPoint(x: 0, y: limitY))
            region.closeSubpath()

            let reveal = CGRect(x: 0, y: -10, width: width * CGFloat(draw) + 0.5, height: size.height + 20)
            let upper = CGRect(x: 0, y: -10, width: size.width, height: limitY + 10).intersection(reveal)
            let lower = CGRect(x: 0, y: limitY, width: size.width, height: size.height + 10 - limitY).intersection(reveal)
            let style = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

            if !upper.isNull, upper.width > 0 {
                var warm = context
                warm.clip(to: Path(upper))
                warm.fill(region, with: .linearGradient(
                    Gradient(colors: [Palette.coral.opacity(amount * 1.5 * fill), Palette.coral.opacity(amount * 0.5 * fill)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: limitY)
                ))
                warm.stroke(line, with: .color(Palette.coral), style: style)
            }
            if !lower.isNull, lower.width > 0 {
                var cool = context
                cool.clip(to: Path(lower))
                cool.fill(region, with: .linearGradient(
                    Gradient(colors: [Palette.sky.opacity(amount * 0.5 * fill), Palette.sky.opacity(amount * 1.5 * fill)]),
                    startPoint: CGPoint(x: 0, y: limitY),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                cool.stroke(line, with: .color(Palette.sky), style: style)
            }

            var limit = Path()
            limit.move(to: CGPoint(x: 0, y: limitY))
            limit.addLine(to: CGPoint(x: size.width - Self.handleWidth, y: limitY))
            context.stroke(
                limit,
                with: .color(.primary.opacity(0.4 + 0.3 * grab)),
                style: StrokeStyle(lineWidth: 1 + 0.5 * CGFloat(grab), lineCap: .round, dash: [4, 4])
            )
        }
        .frame(width: Self.plotWidth, height: Self.plotHeight)
    }
}
