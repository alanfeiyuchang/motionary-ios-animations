import SwiftUI

extension Effect {
    static let chartsRangeBrush = Effect(
        id: "charts.range-brush",
        category: .charts,
        interaction: .gesture,
        name: L("Histogram Range Brush", "直方图区间刷选"),
        summary: L("Drag two handles across a histogram: bars light up as the edge passes them and the count rolls.", "拖动直方图上的两个手柄：边缘扫过时柱子逐根点亮，数量随之滚动。"),
        prompt: L(
            "A price filter card: a 26-bin histogram of muted grey bars with a brush on top, made of a tinted band between two white 22 × 34 pt grip handles. Bars inside the brush are painted with an indigo → violet → pink gradient and stand 8% taller; a bar under an edge is lit by exactly the fraction the brush covers, so colour and height sweep through it continuously instead of switching. Dragging a handle (it swells to 112%) or the band itself moves the range under the finger with a selection tick at every bin crossed; on release the edges snap to the nearest bin on a spring (response 0.5 s, damping 0.72). The header rolls the price range and the number of matching stays every frame, from the same interpolated edges. Direct, precise and satisfying.",
            "价格筛选卡片：26 档的灰色直方图上叠着一把「刷子」——两个 22 × 34pt 白色带纹手柄之间是一条着色区间带。区间内的柱子涂上靛蓝 → 紫 → 粉的渐变并长高 8%；压在边缘下的柱子按被覆盖的比例点亮，颜色与高度连续扫过，而不是生硬切换。拖动手柄（放大到 112%）或直接拖动整条区间带，范围紧跟手指，每越过一档有一次选择触感；松手后两端以弹簧（响应 0.5 秒、阻尼 0.72）吸附到最近的档位。标题中的价格区间与符合条件的房源数，由同一组插值边界逐帧算出并滚动。直接、精准、令人满足。"
        ),
        implementation: L(
            "The card body is an Animatable view over (low, high, grow): a Canvas paints each bar with its covered fraction and the header derives count and prices from the same interpolated edges. One horizontal-first DragGesture picks the nearest handle or the band and updates the edges; release snaps them with a spring.",
            "卡片主体是一个以（下界、上界、生长进度）为动画数据的 Animatable 视图：Canvas 按被覆盖比例绘制每根柱子，标题用同一组插值边界计算数量与价格。一个横向优先的 DragGesture 选中最近的手柄或区间带并更新边界，松手时用弹簧吸附。"
        ),
        apis: ["Animatable", "AnimatablePair", "Canvas", "DragGesture", "interactiveSpring", "spring(response:dampingFraction:)"],
        tags: ["histogram", "range slider", "brush", "filter", "直方图", "区间选择", "刷选", "价格筛选"],
        params: [
            .toggle("snap", L("Snap to bins", "吸附到档位"), default: true),
            .slider("pop", L("Lit bar lift", "点亮柱增高"), 0...0.2, default: 0.08),
            .slider("response", L("Snap response", "吸附弹簧响应"), 0.3...1.0, default: 0.5, unit: "s"),
        ]
    ) { ctx in
        RangeBrushDemo(ctx: ctx)
    }
}

/// Stays per $20 bin, $40 … $560: a right-skewed distribution.
private let brushBins: [Double] = (0..<26).map { index in
    let x = Double(index)
    let main = 62 * exp(-pow((x - 7.5) / 4.2, 2))
    let tail = 20 * exp(-pow((x - 16) / 5.5, 2))
    let wiggle = 5 * sin(x * 1.9) + 3 * cos(x * 0.7)
    return max((main + tail + wiggle + 6).rounded(), 3)
}

private enum BrushGrab {
    case low, high, band
}

private struct RangeBrushDemo: View {
    let ctx: DemoContext
    @State private var low: Double = 5
    @State private var high: Double = 14
    @State private var grow: Double = 1
    @State private var grab: BrushGrab?
    @State private var grabOffset: Double = 0
    @State private var autoStep = 0
    @GestureState private var touching = false

    private let plotWidth: CGFloat = 268
    private let plotHeight: CGFloat = 132
    private static let presets: [(Double, Double)] = [(9, 20), (3, 10), (12, 23), (5, 14)]

    var body: some View {
        ChartStage(hint: L("Drag a handle or the band", "拖动手柄或整条区间带"), ctx: ctx) {
            RangeBrushCard(
                low: low,
                high: high,
                grow: grow,
                pop: ctx["pop"],
                grab: grab,
                plotWidth: plotWidth,
                plotHeight: plotHeight,
                language: ctx.language,
                gesture: AnyGesture(brushGesture.map { _ in () })
            )
            .padding(16)
            .frame(width: 300)
            .demoCard()
        }
        .onChange(of: touching) { _, isTouching in
            if !isTouching { release() }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: { grow = 0 }, then: {
                withAnimation(.easeOut(duration: 0.9)) { grow = 1 }
            })
        }
        .autoplay(ctx.isPreview, every: 1.9, delay: 1.3) { glide() }
    }

    private var brushGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in drag(value) }
            .onEnded { _ in release() }
    }

    private func bin(at x: CGFloat) -> Double {
        Double(x / plotWidth) * Double(brushBins.count)
    }

    /// Horizontal-first: a mostly vertical swipe is left to the page's scroll view.
    private func drag(_ value: DragGesture.Value) {
        let position = bin(at: value.location.x)
        if grab == nil {
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            let start = bin(at: value.startLocation.x)
            let reach = 26.0 / Double(plotWidth) * Double(brushBins.count)
            let toLow = abs(start - low)
            let toHigh = abs(start - high)
            let picked: BrushGrab
            if min(toLow, toHigh) <= reach || start < low || start > high {
                picked = toLow <= toHigh ? .low : .high
            } else {
                picked = .band
            }
            grabOffset = start - low
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { grab = picked }
            Haptics.tap(.light)
        }
        guard let grab else { return }
        let count = Double(brushBins.count)
        var newLow = low
        var newHigh = high
        switch grab {
        case .low:
            newLow = min(max(position, 0), high - 2)
        case .high:
            newHigh = max(min(position, count), low + 2)
        case .band:
            let width = high - low
            newLow = min(max(position - grabOffset, 0), count - width)
            newHigh = newLow + width
        }
        if Int(newLow.rounded()) != Int(low.rounded()) || Int(newHigh.rounded()) != Int(high.rounded()) {
            Haptics.selection()
        }
        withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.86)) {
            low = newLow
            high = newHigh
        }
    }

    private func release() {
        guard grab != nil else { return }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.72)) {
            grab = nil
            if ctx.bool("snap") {
                low = low.rounded()
                high = max(high.rounded(), low + 2)
            }
        }
        Haptics.tap(.rigid)
    }

    /// Autoplay and the arrival play: both edges glide to the next preset, lighting bars as they pass.
    private func glide() {
        let preset = Self.presets[autoStep % Self.presets.count]
        autoStep += 1
        withAnimation(.spring(response: ctx["response"] * 1.5, dampingFraction: 0.82)) {
            low = preset.0
            high = preset.1
        }
    }
}

private struct RangeBrushCard: View, Animatable {
    var low: Double
    var high: Double
    var grow: Double
    let pop: Double
    let grab: BrushGrab?
    let plotWidth: CGFloat
    let plotHeight: CGFloat
    let language: AppLanguage
    let gesture: AnyGesture<Void>

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(low, AnimatablePair(high, grow)) }
        set {
            low = newValue.first
            high = newValue.second.first
            grow = newValue.second.second
        }
    }

    private func coverage(_ index: Int) -> Double {
        min(max(min(high, Double(index + 1)) - max(low, Double(index)), 0), 1)
    }

    private var matching: Int {
        Int(brushBins.indices.reduce(0.0) { $0 + brushBins[$1] * coverage($1) }.rounded())
    }

    private func price(_ edge: Double) -> Int { Int((40 + edge * 20).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            ZStack(alignment: .topLeading) {
                bars
                band
                handle(at: low, active: grab == .low || grab == .band)
                handle(at: high, active: grab == .high || grab == .band)
            }
            .frame(width: plotWidth, height: plotHeight + 18, alignment: .topLeading)
            .contentShape(Rectangle())
            .simultaneousGesture(gesture)
            axis
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(language == .zh ? "每晚价格" : "Price per night")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verbatim: "$\(price(low)) – $\(price(high))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: "\(matching)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.violet)
                Text(language == .zh ? "套房源" : "stays")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bars: some View {
        let count = brushBins.count
        let peak = brushBins.max() ?? 1
        let lift = pop
        let entrance = grow
        let covered = brushBins.indices.map { coverage($0) }
        return Canvas { context, size in
            let slot = size.width / CGFloat(count)
            let barWidth = slot - 3
            let room = size.height / CGFloat(1 + 0.2)
            for index in 0..<count {
                let stagger = ChartKit.smoothstep(0, 1, entrance * 1.7 - Double(index) / Double(count) * 0.7)
                let lit = covered[index]
                let height = room * CGFloat(brushBins[index] / peak) * CGFloat(1 + lift * lit) * CGFloat(stagger)
                guard height > 0.5 else { continue }
                let rect = CGRect(x: slot * CGFloat(index) + 1.5, y: size.height - height, width: barWidth, height: height)
                let path = Path(roundedRect: rect, cornerRadius: min(3, height / 2), style: .continuous)
                context.fill(path, with: .color(.primary.opacity(0.13)))
                guard lit > 0.004 else { continue }
                let t = Double(index) / Double(count - 1)
                let tint = t < 0.5
                    ? ChartRGB.indigo.mixed(ChartRGB.violet, t * 2)
                    : ChartRGB.violet.mixed(ChartRGB.pink, (t - 0.5) * 2)
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [tint.color(lit), tint.color(lit * 0.72)]),
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                    )
                )
            }
        }
        .frame(width: plotWidth, height: plotHeight)
    }

    private func x(_ edge: Double) -> CGFloat {
        plotWidth * CGFloat(edge / Double(brushBins.count))
    }

    private var band: some View {
        let from = x(low)
        let width = max(x(high) - from, 0)
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Palette.violet.opacity(grab == .band ? 0.16 : 0.09))
            .overlay(alignment: .bottom) {
                Capsule().fill(Palette.violet).frame(height: 3)
            }
            .frame(width: width, height: plotHeight + 1.5)
            .offset(x: from)
    }

    private func handle(at edge: Double, active: Bool) -> some View {
        ZStack {
            Rectangle()
                .fill(Palette.violet.opacity(0.55))
                .frame(width: 1.5, height: plotHeight)
                .offset(y: -9)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                .frame(width: 22, height: 34)
                .shadow(color: .black.opacity(active ? 0.28 : 0.18), radius: active ? 9 : 5, y: active ? 5 : 3)
                .overlay {
                    HStack(spacing: 3) {
                        ForEach(0..<2, id: \.self) { _ in
                            Capsule().fill(Palette.violet.opacity(0.8)).frame(width: 2, height: 12)
                        }
                    }
                }
                .scaleEffect(active ? 1.12 : 1)
                .offset(y: plotHeight / 2 - 9)
        }
        .frame(width: 22, height: plotHeight + 18)
        .offset(x: x(edge) - 11)
    }

    private var axis: some View {
        HStack {
            ForEach([40, 170, 300, 430, 560], id: \.self) { value in
                Text(verbatim: "$\(value)")
                if value != 560 { Spacer() }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: plotWidth)
    }
}
