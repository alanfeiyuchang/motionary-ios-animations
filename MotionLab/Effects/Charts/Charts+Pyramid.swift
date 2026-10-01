import SwiftUI

extension Effect {
    static let chartsPyramid = Effect(
        id: "charts.pyramid",
        category: .charts,
        interaction: .gesture,
        name: L("Population Pyramid Scrub", "人口金字塔扫读"),
        summary: L("Two mirrored sides grow outward from the age column; scrubbing a band lights both bars and rolls both values.", "左右两侧从年龄列向外生长；拖过某个年龄段时两侧条形同时点亮，两个数值一起滚动。"),
        prompt: L(
            "A population pyramid: nine age bands as 14 pt rows with 5 pt gaps, men in sky blue growing left and women in pink growing right from a 42 pt centre column of age labels. On appear the rows spring outward from the centre, bottom band first, 50 ms apart (response 0.55 s, damping 0.74). Dragging vertically over the chart moves a soft highlight from band to band on an interactive spring (response 0.16 s): the focused row brightens and thickens by 3 pt, its two percentages pop out at the bar tips, the other rows fade to 35% and the two header figures roll to that band's values. Focus is shared between neighbouring rows while the finger is between them, so it glides instead of jumping. A selection tick marks each new band; on release everything returns to the totals. Symmetrical, calm, precise.",
            "人口金字塔：九个年龄段排成 14pt 高、间距 5pt 的行，男性天蓝向左、女性粉色向右，中间是 42pt 宽的年龄标签列。出现时各行从中间向外弹出，自底部开始，间隔 50ms（弹簧响应 0.55 秒、阻尼 0.74）。纵向拖动时，柔和的高亮以交互弹簧（响应 0.16 秒）在年龄段之间移动：聚焦行变亮并加粗 3pt，两个百分比在条形末端弹出，其余行淡到 35%，标题的两个数字滚动为该年龄段的数值。手指在两行之间时焦点由两行分担，是滑过而非跳变。每进入新年龄段有一次选择触感；松手后恢复总计。对称而精确。"
        ),
        implementation: L(
            "One Animatable Canvas takes (row growth vector, focus position, focus strength). Each row's highlight weight is 1 − |row − focus|, so a single animated Double hands the emphasis from one band to the next; the header samples both series at the same position.",
            "一个 Animatable Canvas 接收（各行生长向量、焦点位置、焦点强度）。每行的高亮权重为 1 − |行号 − 焦点|，因此一个动画 Double 就能把强调从一行交给下一行；标题在同一位置对两组数据取样。"
        ),
        apis: ["Animatable", "Canvas", "DragGesture", "interactiveSpring", "VectorArithmetic"],
        tags: ["population pyramid", "mirrored bars", "scrub", "demographics", "人口金字塔", "镜像条形", "扫读", "年龄分布"],
        params: [
            .slider("stagger", L("Row stagger", "行间错峰"), 0...0.12, default: 0.05, unit: "s"),
            .slider("follow", L("Follow response", "跟随弹簧响应"), 0.05...0.5, default: 0.16, unit: "s"),
            .slider("dim", L("Dimmed opacity", "其余行不透明度"), 0.1...0.8, default: 0.35),
        ]
    ) { ctx in
        PyramidDemo(ctx: ctx)
    }
}

/// Oldest band first (top row).
private let pyramidBands = ["80+", "70–79", "60–69", "50–59", "40–49", "30–39", "20–29", "10–19", "0–9"]
private let pyramidMen: [Double] = [1.4, 3.1, 4.9, 6.2, 7.0, 7.6, 6.8, 5.7, 5.2]
private let pyramidWomen: [Double] = [2.3, 3.8, 5.3, 6.4, 7.1, 7.4, 6.5, 5.4, 4.9]

private struct PyramidDemo: View {
    let ctx: DemoContext
    @State private var grow = ChartVector(repeating: 1, count: 9)
    @State private var focus: Double = 4
    @State private var strength: Double = 0
    @State private var engaged = false
    @State private var lastBand = -1
    @State private var autoStep = 0
    @State private var run: Task<Void, Never>?
    @GestureState private var touching = false

    private static let rowHeight: CGFloat = 14
    private static let rowGap: CGFloat = 5
    private static let stops: [Double] = [6, 3, 5, 1, 7]

    private var plotHeight: CGFloat { CGFloat(9) * Self.rowHeight + CGFloat(8) * Self.rowGap + 8 }

    var body: some View {
        ChartStage(hint: L("Drag up and down over the bands", "在年龄段上上下拖动"), ctx: ctx) {
            PyramidCard(
                grow: grow,
                focus: focus,
                strength: strength,
                dim: ctx["dim"],
                rowHeight: Self.rowHeight,
                rowGap: Self.rowGap,
                plotHeight: plotHeight,
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
                grow = ChartVector(repeating: 0, count: 9)
            }, then: { enter() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.2, delay: 1.5) { glide() }
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in scrub(value.location.y) }
            .onEnded { _ in release() }
    }

    private func enter() {
        let stagger = ctx["stagger"]
        run?.cancel()
        run = chartSequence(steps: 9, gap: stagger) { step in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.74)) { grow[8 - step] = 1 }
        }
    }

    private func scrub(_ y: CGFloat) {
        let pitch = Self.rowHeight + Self.rowGap
        let target = Double((y - 4 - Self.rowHeight / 2) / pitch).clamped(to: 0...8)
        let band = Int(target.rounded())
        if !engaged {
            engaged = true
            run?.cancel()
            Haptics.tap(.light)
            lastBand = band
        } else if band != lastBand {
            lastBand = band
            Haptics.selection()
        }
        withAnimation(.interactiveSpring(response: ctx["follow"], dampingFraction: 0.84)) {
            focus = target
            strength = 1
            grow = ChartVector(repeating: 1, count: 9)
        }
    }

    private func release() {
        guard engaged else { return }
        engaged = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { strength = 0 }
    }

    /// Autoplay and the arrival play: the highlight glides between a few bands, then rests on the totals.
    private func glide() {
        guard !engaged else { return }
        let stop = Self.stops[autoStep % Self.stops.count]
        autoStep += 1
        let rest = !ctx.isPreview && autoStep > 1
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
            focus = stop
            strength = rest ? 0 : 1
        }
        guard !ctx.isPreview else { return }
        run?.cancel()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled, !engaged else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { strength = 0 }
        }
    }
}

private struct PyramidCard: View, Animatable {
    var grow: ChartVector
    var focus: Double
    var strength: Double
    let dim: Double
    let rowHeight: CGFloat
    let rowGap: CGFloat
    let plotHeight: CGFloat
    let language: AppLanguage
    let gesture: AnyGesture<Void>

    var animatableData: AnimatablePair<ChartVector, AnimatablePair<Double, Double>> {
        get { AnimatablePair(grow, AnimatablePair(focus, strength)) }
        set {
            grow = newValue.first
            focus = newValue.second.first
            strength = newValue.second.second
        }
    }

    private static let centre: CGFloat = 42
    private static let maxValue: Double = 8.4

    private func sample(_ series: [Double]) -> Double {
        let position = min(max(focus, 0), 8)
        let index = Int(position)
        guard index < 8 else { return series[8] }
        let t = position - Double(index)
        return series[index] + (series[index + 1] - series[index]) * t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            canvas
                .frame(height: plotHeight)
                .contentShape(Rectangle())
                .highPriorityGesture(gesture)
        }
    }

    private var header: some View {
        let s = min(max(strength, 0), 1)
        let men = 47.9 + (sample(pyramidMen) - 47.9) * s
        let women = 49.1 + (sample(pyramidWomen) - 49.1) * s
        let band = pyramidBands[min(max(Int(focus.rounded()), 0), 8)]
        return HStack(alignment: .bottom) {
            figure(L("Men", "男性"), value: men, color: Palette.sky, alignment: .leading)
            Spacer()
            Text(verbatim: s > 0.5 ? band : (language == .zh ? "全部" : "All ages"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
            Spacer()
            figure(L("Women", "女性"), value: women, color: Palette.pink, alignment: .trailing)
        }
    }

    private func figure(_ name: LocalizedText, value: Double, color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(name, language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: String(format: "%.1f%%", value))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 84, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var canvas: some View {
        let grow = grow
        let focus = focus
        let strength = min(max(strength, 0), 1)
        let dim = dim
        return Canvas { context, size in
            let pitch = rowHeight + rowGap
            let side = (size.width - Self.centre) / 2
            let reach = side - 32
            for row in 0..<9 {
                let weight = max(0, 1 - abs(Double(row) - focus)) * strength
                let alpha = 1 - (1 - dim) * strength * (1 - weight)
                let g = CGFloat(max(grow[row], 0))
                let extra = CGFloat(weight) * 3
                let midY = 4 + rowHeight / 2 + CGFloat(row) * pitch
                let height = rowHeight + extra
                let menWidth = reach * CGFloat(pyramidMen[row] / Self.maxValue) * g
                let womenWidth = reach * CGFloat(pyramidWomen[row] / Self.maxValue) * g
                let menRect = CGRect(x: side - menWidth, y: midY - height / 2, width: menWidth, height: height)
                let womenRect = CGRect(x: side + Self.centre, y: midY - height / 2, width: womenWidth, height: height)

                var layer = context
                layer.opacity = alpha
                if menWidth > 0.5 {
                    layer.fill(
                        Path(roundedRect: menRect, cornerRadius: min(5, menWidth / 2), style: .continuous),
                        with: .linearGradient(Gradient(colors: [Palette.blue, Palette.sky]), startPoint: CGPoint(x: menRect.minX, y: midY), endPoint: CGPoint(x: menRect.maxX, y: midY))
                    )
                }
                if womenWidth > 0.5 {
                    layer.fill(
                        Path(roundedRect: womenRect, cornerRadius: min(5, womenWidth / 2), style: .continuous),
                        with: .linearGradient(Gradient(colors: [Palette.pink, Palette.violet]), startPoint: CGPoint(x: womenRect.minX, y: midY), endPoint: CGPoint(x: womenRect.maxX, y: midY))
                    )
                }
                layer.draw(
                    Text(verbatim: pyramidBands[row])
                        .font(.system(size: 9.5 + CGFloat(weight) * 1.5, weight: weight > 0.5 ? .bold : .medium, design: .rounded))
                        .foregroundStyle(weight > 0.5 ? Color.primary : Color.secondary),
                    at: CGPoint(x: size.width / 2, y: midY),
                    anchor: .center
                )

                guard weight > 0.02 else { continue }
                var tips = context
                tips.opacity = weight
                let slide = CGFloat(1 - weight) * 6
                tips.draw(
                    Text(verbatim: String(format: "%.1f%%", pyramidMen[row]))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.sky),
                    at: CGPoint(x: menRect.minX - 4 + slide, y: midY),
                    anchor: .trailing
                )
                tips.draw(
                    Text(verbatim: String(format: "%.1f%%", pyramidWomen[row]))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.pink),
                    at: CGPoint(x: womenRect.maxX + 4 - slide, y: midY),
                    anchor: .leading
                )
            }
        }
    }
}
