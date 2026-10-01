import SwiftUI

extension Effect {
    static let showcaseTidePulse = Effect(
        id: "showcase.tide-pulse",
        category: .showcase,
        interaction: .gesture,
        name: L("Live Ticker Pulse", "实时行情脉冲"),
        summary: L(
            "A live quote card: each tick flashes the price, extends the sparkline and can flip the delta chip; hold to scrub.",
            "实时行情卡片：每次跳价都让价格闪色、走势线向前延伸，涨跌标签翻面；长按即可回看。"
        ),
        prompt: L(
            "A dark live-quote widget: ticker and pulsing live dot, a 40 pt price, a delta chip and a 250 × 96 pt sparkline over a dashed opening-price line, with open / high / low underneath. Every 0.9 s a tick arrives: the changed digits roll, the price flashes lime or coral and fades back to white over 0.7 s, and the line slides left by exactly one step on a 0.55 s ease-out while its glowing head rides the new segment at the right edge, so the chart extends instead of jumping. When the change crosses zero the chip flips on its x-axis (90° out in 0.14 s, springing back with the new colour and arrow). Holding 0.22 s freezes the tape: a hairline and dot follow the finger, the line ahead of it and the stats dim to 25%, and the price shows that moment. Alert, precise.",
            "深色实时行情组件：代码与直播点、40pt 价格、涨跌标签，和压在开盘价虚线上的 250 × 96pt 走势线，下方是开盘 / 最高 / 最低。每 0.9 秒一次跳价：变动数字滚动，价格闪青柠或珊瑚色并在 0.7 秒内褪回白色；折线以 0.55 秒 ease-out 恰好左移一格，发光端点在右缘沿新线段滑行，图线是“长出来”的，纵轴范围同步缓动。涨跌过零时，标签绕 x 轴翻面（0.14 秒转出 90°，再带新颜色与箭头弹回）。长按 0.22 秒冻结行情：细线与圆点跟随手指，其后的折线与统计暗到 25%，价格显示该时刻数值。"
        ),
        implementation: L(
            "The chart is an Animatable view over (shift, low, high): a tick appends a point, sets shift to 1 without animation and eases it to 0, so the Canvas redraws the polyline one step left per frame and interpolates the head on the newest segment. Price flash is an animated foregroundStyle; the chip flips with a keyframeAnimator on rotation3DEffect. A zero-distance DragGesture plus a 0.22 s timer implements press-and-hold scrubbing and pauses the task(id:) feed.",
            "图表是以（shift、low、high）为动画数据的 Animatable 视图：每次跳价追加一个点，把 shift 无动画置为 1 再缓动到 0，Canvas 于是逐帧把折线左移一格，并在最新线段上插值端点。价格闪色是带动画的 foregroundStyle；标签翻面用 keyframeAnimator 驱动 rotation3DEffect。零距离 DragGesture 加 0.22 秒计时实现长按回看，并暂停 task(id:) 数据流。"
        ),
        apis: ["Animatable", "Canvas", "task(id:)", "contentTransition(.numericText)", "keyframeAnimator", "rotation3DEffect", "DragGesture"],
        tags: ["stock", "crypto", "ticker", "sparkline", "live", "scrub", "股票", "行情", "走势", "实时", "涨跌"],
        params: [
            .slider("beat", L("Tick interval", "跳价间隔"), 0.4...2.0, default: 0.9, unit: "s"),
            .slider("vol", L("Volatility", "波动幅度"), 0.3...2.0, default: 1.0),
            .choice("palette", L("Up colour", "上涨颜色"), [L("Green up", "绿涨红跌"), L("Red up", "红涨绿跌")], default: 0),
        ]
    ) { ctx in
        TidePulseDemo(ctx: ctx)
    }
}

private enum TideFeed {
    static let open: Double = 184.20
    static let count = 41

    static func next(after previous: Double, tick: Int, volatility: Double) -> Double {
        let n = Double(tick)
        let target = open + (0.6 + 2.2 * sin(n * 0.13) + 1.1 * sin(n * 0.047 + 1)) * volatility
        let noise = (sportHash(n * 1.91 + 3) - 0.5) * 1.5 * volatility
        let value = previous + (target - previous) * 0.14 + noise
        return (value * 100).rounded() / 100
    }

    static func seed(volatility: Double) -> [Double] {
        var values: [Double] = []
        var last = open
        for tick in 0..<count {
            last = next(after: last, tick: tick, volatility: volatility)
            values.append(last)
        }
        return values
    }

    static func range(_ values: [Double], volatility: Double) -> (lo: Double, hi: Double) {
        let pad = 0.3 + 0.35 * volatility
        let lo = min(values.min() ?? open, open) - pad
        let hi = max(values.max() ?? open, open) + pad
        return (lo, hi)
    }
}

private struct TidePulseDemo: View {
    let ctx: DemoContext
    @State private var points: [Double]
    @State private var tick: Int
    @State private var shift: Double = 0
    @State private var lo: Double
    @State private var hi: Double
    @State private var flashOn = false
    @State private var flashUp = true
    @State private var chipUp: Bool
    @State private var flips = 0
    @State private var scrubX: CGFloat?
    @State private var touchStart: Date?
    @State private var scripting = false
    @State private var script: Task<Void, Never>?
    @State private var lastIndex = -1
    @GestureState private var touching = false

    private let plot = CGSize(width: 250, height: 96)

    init(ctx: DemoContext) {
        self.ctx = ctx
        let seeded = TideFeed.seed(volatility: ctx["vol"])
        let range = TideFeed.range(seeded, volatility: ctx["vol"])
        _points = State(initialValue: seeded)
        _tick = State(initialValue: TideFeed.count)
        _lo = State(initialValue: range.lo)
        _hi = State(initialValue: range.hi)
        _chipUp = State(initialValue: (seeded.last ?? TideFeed.open) >= TideFeed.open)
    }

    private var zh: Bool { ctx.language == .zh }
    private var upColor: Color { ctx.int("palette") == 1 ? Color(hex: 0xFF5A5F) : Signature.lime }
    private var downColor: Color { ctx.int("palette") == 1 ? Color(hex: 0x3DDC97) : Color(hex: 0xFF6B5E) }
    private var scrubbing: Bool { scrubX != nil }
    private var step: CGFloat { plot.width / CGFloat(TideFeed.count - 2) }

    /// The price under the hairline, or the live price.
    private var shown: Double {
        guard let scrubX else { return points.last ?? TideFeed.open }
        let position = Double(scrubX / step) + 1
        let lower = Int(position.rounded(.down)).clamped(to: 0...(points.count - 1))
        let upper = min(lower + 1, points.count - 1)
        let value = points[lower] + (points[upper] - points[lower]) * (position - Double(lower))
        return (value * 100).rounded() / 100
    }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card
                Spacer(minLength: 0)
                DemoHint(text: L("Press and hold the chart to scrub", "长按走势图回看"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: "\(scrubbing)-\(ctx["beat"])") {
            guard !scrubbing, !ctx.isStill else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(ctx["beat"]))
                guard !Task.isCancelled else { return }
                advance()
            }
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 7.5, delay: 3.2) { runScript() }
    }

    private var card: some View {
        let value = shown
        let up = value >= TideFeed.open
        return VStack(alignment: .leading, spacing: 10) {
            header
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: String(format: "%.2f", value))
                    .font(Signature.number(40))
                    .foregroundStyle(flashOn && !scrubbing ? (flashUp ? upColor : downColor) : Color.white)
                    .contentTransition(.numericText(value: value))
                    .animation(scrubbing ? nil : .snappy(duration: 0.3), value: value)
                chip(value: value)
                Spacer(minLength: 0)
            }
            TideChart(
                shift: shift,
                lo: lo,
                hi: hi,
                points: points,
                open: TideFeed.open,
                color: up ? upColor : downColor,
                scrub: scrubX,
                plot: plot,
                preview: ctx.isPreview
            )
            .frame(width: 264, height: plot.height, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(holdGesture)
            .onChange(of: touching) { _, isTouching in
                if !isTouching && !scripting {
                    touchStart = nil
                    endScrub()
                }
            }
            stats
                .opacity(scrubbing ? 0.25 : 1)
        }
        .padding(18)
        .frame(width: 300)
        .signatureCard()
    }

    private var header: some View {
        HStack(spacing: 6) {
            ZStack {
                if scrubbing {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(Signature.textSecondary)
                } else {
                    SportLiveDot(color: Signature.accent, preview: ctx.isPreview)
                }
            }
            .frame(width: 24, height: 24)
            Text(verbatim: "SOLR")
                .foregroundStyle(Color.white)
            Text(verbatim: scrubbing ? agoText : (zh ? "实时" : "Live"))
                .contentTransition(.numericText())
            Spacer(minLength: 0)
            Text(verbatim: "Solaris Energy")
        }
        .signatureEyebrow()
    }

    private var agoText: String {
        guard let scrubX else { return "" }
        let steps = Double((plot.width - scrubX) / step)
        let seconds = Int((steps * ctx["beat"]).rounded())
        return zh ? "\(seconds) 秒前" : "\(seconds) s ago"
    }

    private func chip(value: Double) -> some View {
        let delta = value - TideFeed.open
        let percent = abs(delta) / TideFeed.open * 100
        // While scrubbing the chip follows the hairline at once; live, it changes at the flip's midpoint.
        let up = scrubbing ? delta >= 0 : chipUp
        return HStack(spacing: 3) {
            Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 8, weight: .heavy))
            Text(verbatim: String(format: "%.2f%%", percent))
                .contentTransition(.numericText(value: percent))
        }
        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(Signature.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(up ? upColor : downColor))
        .keyframeAnimator(initialValue: 0.0, trigger: flips) { content, angle in
            content.rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(90, duration: 0.14)
                MoveKeyframe(-90)
                SpringKeyframe(0, duration: 0.42, spring: .init(response: 0.32, dampingRatio: 0.55))
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(zh ? "开盘" : "Open", TideFeed.open)
            Spacer(minLength: 0)
            stat(zh ? "最高" : "High", points.max() ?? TideFeed.open)
            Spacer(minLength: 0)
            stat(zh ? "最低" : "Low", points.min() ?? TideFeed.open)
        }
        .animation(.smooth(duration: 0.25), value: scrubbing)
    }

    private func stat(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: label)
                .signatureEyebrow()
            Text(verbatim: String(format: "%.2f", value))
                .font(Signature.number(15))
                .foregroundStyle(Color.white.opacity(0.9))
                .contentTransition(.numericText(value: value))
                .animation(.snappy(duration: 0.3), value: value)
        }
    }

    // MARK: Feed

    private func advance() {
        let previous = points.last ?? TideFeed.open
        let next = TideFeed.next(after: previous, tick: tick, volatility: ctx["vol"])
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            points.append(next)
            if points.count > TideFeed.count { points.removeFirst() }
            shift = 1
            flashUp = next >= previous
            flashOn = true
        }
        tick += 1
        let range = TideFeed.range(points, volatility: ctx["vol"])
        withAnimation(.easeOut(duration: min(0.55, ctx["beat"] * 0.8))) {
            shift = 0
            lo = range.lo
            hi = range.hi
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.12)) { flashOn = false }
        let nowUp = next >= TideFeed.open
        if nowUp != chipUp {
            flips += 1
            Task { @MainActor in
                guard await studioPause(0.14) else { return }
                chipUp = nowUp
            }
        }
    }

    // MARK: Hold to scrub

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if scripting {
                    script?.cancel()
                    scripting = false
                    endScrub()
                }
                if scrubbing {
                    scrub(to: value.location.x)
                } else if let start = touchStart {
                    if Date().timeIntervalSince(start) >= 0.22 { beginScrub(at: value.location.x) }
                } else {
                    touchStart = Date()
                    let x = value.location.x
                    Task { @MainActor in
                        guard await studioPause(0.22), touchStart != nil, !scrubbing else { return }
                        beginScrub(at: x)
                    }
                }
            }
            .onEnded { _ in
                touchStart = nil
                endScrub()
            }
    }

    private func beginScrub(at x: CGFloat) {
        buzz { Haptics.tap(.medium) }
        withAnimation(.smooth(duration: 0.2)) { scrubX = x.clamped(to: 0...plot.width) }
    }

    private func scrub(to x: CGFloat) {
        let clamped = x.clamped(to: 0...plot.width)
        scrubX = clamped
        let index = Int((clamped / step).rounded())
        if index != lastIndex {
            lastIndex = index
            buzz { Haptics.selection() }
        }
    }

    private func endScrub() {
        guard scrubbing else { return }
        withAnimation(.smooth(duration: 0.25)) { scrubX = nil }
    }

    private func buzz(_ feedback: () -> Void) {
        guard !ctx.isPreview, !scripting else { return }
        feedback()
    }

    private func runScript() {
        guard !scrubbing else { return }
        script?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            beginScrub(at: plot.width * 0.84)
            let legs: [(CGFloat, CGFloat, Double)] = [(0.84, 0.3, 1.1), (0.3, 0.62, 0.8)]
            for (from, to, duration) in legs {
                guard await studioScript(duration, { t in
                    scrub(to: plot.width * (from + (to - from) * CGFloat(studioEase(t))))
                }) else {
                    endScrub()
                    return
                }
            }
            _ = await studioPause(0.3)
            endScrub()
        }
    }
}

// MARK: - Chart

private struct TideChart: View, Animatable {
    var shift: Double
    var lo: Double
    var hi: Double
    let points: [Double]
    let open: Double
    let color: Color
    let scrub: CGFloat?
    let plot: CGSize
    let preview: Bool

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(shift, AnimatablePair(lo, hi)) }
        set {
            shift = newValue.first
            lo = newValue.second.first
            hi = newValue.second.second
        }
    }

    private var step: CGFloat { plot.width / CGFloat(max(points.count - 2, 1)) }

    private func y(_ value: Double) -> CGFloat {
        let t = (value - lo) / max(hi - lo, 0.01)
        return plot.height - 6 - CGFloat(t) * (plot.height - 12)
    }

    private func x(_ index: Int) -> CGFloat {
        (CGFloat(index) - 1 + CGFloat(shift)) * step
    }

    /// The head rides the newest segment while it slides in.
    private var headY: CGFloat {
        guard points.count >= 2 else { return plot.height / 2 }
        let a = y(points[points.count - 2])
        let b = y(points[points.count - 1])
        return a + (b - a) * CGFloat(1 - shift)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                draw(in: &context)
            }
            .frame(width: plot.width, height: plot.height)
            SportLiveDot(color: color, size: 8, period: 1.2, preview: preview)
                .position(x: plot.width, y: headY)
                .opacity(scrub == nil ? 1 : 0.3)
        }
    }

    private func draw(in context: inout GraphicsContext) {
        guard points.count >= 2 else { return }
        let bounds = CGRect(origin: .zero, size: plot)
        var line = Path()
        for index in points.indices {
            let p = CGPoint(x: x(index), y: y(points[index]))
            if index == 0 { line.move(to: p) } else { line.addLine(to: p) }
        }
        var area = line
        area.addLine(to: CGPoint(x: x(points.count - 1), y: plot.height))
        area.addLine(to: CGPoint(x: x(0), y: plot.height))
        area.closeSubpath()

        // Opening price.
        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: y(open)))
        baseline.addLine(to: CGPoint(x: plot.width, y: y(open)))
        context.stroke(baseline, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

        let stroke = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        let fill = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [color.opacity(0.32), color.opacity(0)]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: plot.height)
        )
        // Everything, dimmed (only visible ahead of the hairline while scrubbing)…
        var dim = context
        dim.clip(to: Path(bounds))
        dim.opacity = scrub == nil ? 1 : 0.25
        dim.fill(area, with: fill)
        dim.stroke(line, with: .color(color), style: stroke)
        // …and the part up to the hairline at full strength.
        if let scrub {
            var lit = context
            lit.clip(to: Path(CGRect(x: 0, y: 0, width: scrub, height: plot.height)))
            lit.fill(area, with: fill)
            lit.stroke(line, with: .color(color), style: stroke)

            var hair = Path()
            hair.move(to: CGPoint(x: scrub, y: 0))
            hair.addLine(to: CGPoint(x: scrub, y: plot.height))
            context.stroke(hair, with: .color(.white.opacity(0.7)), lineWidth: 1)
            let position = Double(scrub / step) + 1
            let lower = min(max(Int(position.rounded(.down)), 0), points.count - 1)
            let upper = min(lower + 1, points.count - 1)
            let value = points[lower] + (points[upper] - points[lower]) * (position - Double(lower))
            let dot = CGPoint(x: scrub, y: y(value))
            context.fill(Path(ellipseIn: CGRect(x: dot.x - 6.5, y: dot.y - 6.5, width: 13, height: 13)), with: .color(color.opacity(0.35)))
            context.fill(Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)), with: .color(.white))
        }
    }
}
