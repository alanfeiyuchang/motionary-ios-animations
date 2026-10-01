import SwiftUI

extension Effect {
    static let chartsTrendPill = Effect(
        id: "charts.trend-pill",
        category: .charts,
        interaction: .tap,
        name: L("Trend Pill KPI", "趋势胶囊指标卡"),
        summary: L("Each update rolls the value, swings the delta pill's arrow through the turn and re-draws the sparkline over a fading ghost.", "每次更新：数值滚动，涨跌胶囊的箭头转过半圈，迷你折线在渐隐的旧线上重新绘出。"),
        prompt: L(
            "Two KPI tiles (Revenue, Churn), each with a glyph badge, a large rounded value, a delta pill and a 46 pt sparkline. Tapping loads the next week, the second tile 0.12 s after the first. The value rolls with a numeric transition. The pill's delta is animated as a number on a spring (response 0.5 s, damping 0.55): its figure counts through zero, its arrow rotates continuously from up (0°) to down (180°) and wobbles as the spring overshoots, its tint blends green → amber → red (inverted for Churn, where down is good), and the pill pops to 112% and settles. Meanwhile the old sparkline stays as a 30% ghost that fades while the new line is drawn left to right in 0.7 s behind a glowing head dot, its area fill following. A selection haptic marks each update. Crisp and newsy.",
            "两张指标卡（营收、流失率），各含图标、大号数值、涨跌胶囊与 46pt 高的迷你折线。点击载入下一周，第二张比第一张晚 0.12 秒。数值以数字转场滚动；胶囊里的涨跌幅作为数值由弹簧（响应 0.5 秒、阻尼 0.55）驱动：数字穿过零点计数，箭头从向上（0°）连续转到向下（180°）并随弹簧过冲而摆动，底色在绿 → 琥珀 → 红之间渐变（流失率相反，下降为好），胶囊弹到 112% 再回稳。同时旧折线以 30% 的残影淡出，新折线跟在发光笔头后用 0.7 秒自左向右绘出。每次更新有一次选择触感。干脆利落。"
        ),
        implementation: L(
            "The pill is an Animatable view over the delta itself, so text, arrow angle and colour all derive from one interpolated number; a keyframeAnimator adds the pop. The sparkline is an Animatable Canvas over a draw fraction that clips the new line, positions the head dot and fades the previous series.",
            "胶囊是以涨跌幅本身为动画数据的 Animatable 视图，文字、箭头角度与颜色都由同一个插值数值推出；keyframeAnimator 叠加弹出动作。迷你折线是以绘制比例为动画数据的 Animatable Canvas：裁剪新折线、定位笔头圆点，并淡出上一组数据。"
        ),
        apis: ["Animatable", "keyframeAnimator", "contentTransition(.numericText)", "Canvas", "spring(response:dampingFraction:)"],
        tags: ["kpi", "delta", "trend", "sparkline", "指标卡", "涨跌", "趋势", "迷你折线"],
        params: [
            .slider("draw", L("Redraw duration", "重绘时长"), 0.3...1.5, default: 0.7, unit: "s"),
            .slider("response", L("Pill response", "胶囊弹簧响应"), 0.3...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Pill damping", "胶囊阻尼"), 0.3...1.0, default: 0.55),
            .slider("stagger", L("Tile stagger", "卡片错峰"), 0...0.4, default: 0.12, unit: "s"),
        ]
    ) { ctx in
        TrendPillDemo(ctx: ctx)
    }
}

private struct TrendSnapshot {
    let value: Double
    let delta: Double
    let series: [Double]
}

private struct TrendMetric {
    let title: LocalizedText
    let symbol: String
    let tint: Color
    /// Churn: a falling number is the good direction.
    let lowerIsBetter: Bool
    let format: (Double) -> String
    let snapshots: [TrendSnapshot]
}

private func trendSeries(seed: Double, drift: Double) -> [Double] {
    let raw: [Double] = (0..<14).map { index in
        let x = Double(index) / 13
        return drift * x * x + 0.35 * sin(x * 7 + seed) + 0.18 * sin(x * 15 + seed * 2.3)
    }
    let low = raw.min() ?? 0
    let span = max((raw.max() ?? 1) - low, 0.001)
    return raw.map { 0.1 + 0.8 * ($0 - low) / span }
}

private let trendMetrics: [TrendMetric] = [
    TrendMetric(
        title: L("Revenue", "营收"), symbol: "dollarsign", tint: Palette.indigo, lowerIsBetter: false,
        format: { String(format: "$%.1fk", $0) },
        snapshots: [
            TrendSnapshot(value: 48.2, delta: 12.4, series: trendSeries(seed: 0.6, drift: 1.1)),
            TrendSnapshot(value: 44.9, delta: -6.8, series: trendSeries(seed: 2.4, drift: -0.9)),
            TrendSnapshot(value: 51.6, delta: 14.9, series: trendSeries(seed: 4.0, drift: 1.4)),
            TrendSnapshot(value: 50.1, delta: -2.9, series: trendSeries(seed: 5.3, drift: -0.5)),
        ]
    ),
    TrendMetric(
        title: L("Churn", "流失率"), symbol: "person.fill.xmark", tint: Palette.sky, lowerIsBetter: true,
        format: { String(format: "%.1f%%", $0) },
        snapshots: [
            TrendSnapshot(value: 2.4, delta: -18.0, series: trendSeries(seed: 1.2, drift: -1.0)),
            TrendSnapshot(value: 3.1, delta: 29.2, series: trendSeries(seed: 3.1, drift: 1.3)),
            TrendSnapshot(value: 2.2, delta: -29.0, series: trendSeries(seed: 0.2, drift: -1.2)),
            TrendSnapshot(value: 2.6, delta: 18.2, series: trendSeries(seed: 4.7, drift: 0.8)),
        ]
    ),
]

private struct TrendPillDemo: View {
    let ctx: DemoContext
    @State private var step: [Int] = [0, 0]
    @State private var previous: [Int] = [0, 0]
    @State private var draw: [Double] = [1, 1]
    @State private var pops: [Int] = [0, 0]
    @State private var week = 32
    @State private var run: Task<Void, Never>?

    var body: some View {
        ChartStage(hint: L("Tap a tile to load the next week", "点击卡片载入下一周"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(ctx.language == .zh ? "每周概览" : "Weekly snapshot")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(verbatim: ctx.language == .zh ? "第 \(week) 周" : "Week \(week)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(week)))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                HStack(spacing: 12) {
                    ForEach(trendMetrics.indices, id: \.self) { index in
                        tile(index)
                    }
                }
            }
            .frame(width: 300)
            .contentShape(Rectangle())
            .onTapGesture { advance() }
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 2.0, delay: 0.8) { advance() }
    }

    private func tile(_ index: Int) -> some View {
        let metric = trendMetrics[index]
        let snapshot = metric.snapshots[step[index]]
        let ghost = metric.snapshots[previous[index]]
        let good = (snapshot.delta >= 0) != metric.lowerIsBetter
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: metric.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(metric.tint)
                    .frame(width: 26, height: 26)
                    .background(metric.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(metric.title, ctx.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: metric.format(snapshot.value))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: snapshot.value))
            TrendPill(delta: snapshot.delta, invert: metric.lowerIsBetter)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: pops[index]) { content, scale in
                    content.scaleEffect(scale, anchor: .leading)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(CGFloat(1.12), duration: 0.16, spring: .snappy)
                        SpringKeyframe(CGFloat(1), duration: 0.5, spring: .bouncy)
                    }
                }
            TrendSpark(
                series: snapshot.series,
                ghost: ghost.series,
                draw: draw[index],
                color: good ? Palette.green : Palette.red
            )
            .frame(height: 46)
        }
        .padding(14)
        .frame(width: 144, alignment: .leading)
        .demoCard(cornerRadius: 20)
    }

    /// Tap and autoplay share this: every tile moves to its next snapshot, one after another.
    private func advance() {
        Haptics.selection()
        run?.cancel()
        let stagger = ctx["stagger"]
        let response = ctx["response"]
        let damping = ctx["damping"]
        let duration = ctx["draw"]
        withAnimation(.snappy(duration: 0.3)) { week += 1 }
        run = Task { @MainActor in
            for index in trendMetrics.indices {
                guard !Task.isCancelled else { return }
                chartInstant {
                    previous[index] = step[index]
                    draw[index] = 0
                }
                // A frame apart, so the reset and the animated redraw never coalesce.
                try? await Task.sleep(for: .seconds(0.04))
                guard !Task.isCancelled else {
                    draw[index] = 1
                    return
                }
                withAnimation(.spring(response: response, dampingFraction: damping)) {
                    step[index] = (step[index] + 1) % trendMetrics[index].snapshots.count
                }
                withAnimation(.easeInOut(duration: duration)) { draw[index] = 1 }
                pops[index] += 1
                if stagger > 0.04 { try? await Task.sleep(for: .seconds(stagger - 0.04)) }
            }
        }
    }
}

/// The delta is the animated value: figure, arrow angle and tint are all read from it.
private struct TrendPill: View, Animatable {
    var delta: Double
    let invert: Bool

    var animatableData: Double {
        get { delta }
        set { delta = newValue }
    }

    var body: some View {
        let direction = min(max(delta / 6, -1), 1)
        let tone = ChartRGB.trend(invert ? -direction : direction)
        HStack(spacing: 3) {
            Image(systemName: "arrow.up")
                .font(.system(size: 10, weight: .heavy))
                .rotationEffect(.degrees(90 - 90 * direction))
            Text(verbatim: String(format: "%.1f%%", abs(delta)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(tone.mixed(ChartRGB(0x000000), 0.18).color())
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(tone.color(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(tone.color(0.35), lineWidth: 0.5))
    }
}

private struct TrendSpark: View, Animatable {
    let series: [Double]
    let ghost: [Double]
    var draw: Double
    let color: Color

    var animatableData: Double {
        get { draw }
        set { draw = newValue }
    }

    var body: some View {
        let progress = min(max(draw, 0), 1)
        Canvas { context, size in
            let inset: CGFloat = 6
            let plot = CGRect(x: 0, y: inset, width: size.width - inset, height: size.height - inset * 2)
            func points(_ values: [Double]) -> [CGPoint] {
                values.enumerated().map { index, value in
                    CGPoint(x: plot.minX + plot.width * CGFloat(index) / CGFloat(max(values.count - 1, 1)), y: plot.maxY - plot.height * CGFloat(value))
                }
            }

            if progress < 0.995 {
                var old = context
                old.opacity = 0.3 * (1 - progress)
                old.stroke(ChartKit.smoothPath(points(ChartKit.resample(ghost, perSegment: 6))), with: .color(.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

            // Densely resampled, so the head dot (sampled from the same array) sits exactly on the line.
            let dense = ChartKit.resample(series, perSegment: 6)
            var line = Path()
            line.addLines(points(dense))
            let headX = plot.minX + plot.width * CGFloat(progress)
            var clipped = context
            clipped.clip(to: Path(CGRect(x: 0, y: 0, width: headX + 0.5, height: size.height)))
            var area = line
            area.addLine(to: CGPoint(x: plot.maxX, y: size.height))
            area.addLine(to: CGPoint(x: plot.minX, y: size.height))
            area.closeSubpath()
            clipped.fill(
                area,
                with: .linearGradient(Gradient(colors: [color.opacity(0.26), color.opacity(0)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )
            clipped.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            guard progress > 0.01 else { return }
            let headY = plot.maxY - plot.height * CGFloat(ChartKit.sample(dense, at: progress))
            let halo: CGFloat = 6
            context.fill(Path(ellipseIn: CGRect(x: headX - halo, y: headY - halo, width: halo * 2, height: halo * 2)), with: .color(color.opacity(0.25)))
            context.fill(Path(ellipseIn: CGRect(x: headX - 3, y: headY - 3, width: 6, height: 6)), with: .color(color))
        }
    }
}
