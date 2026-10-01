import SwiftUI

extension Effect {
    static let textLiquidFill = Effect(
        id: "text.liquid-fill",
        category: .text,
        interaction: .loop,
        name: L("Liquid-Filled Letters", "液体灌注文字"),
        summary: L("Hollow letters fill with rising water whose surface sloshes while it pours and calms when full.", "空心的字被上涨的水灌满，水面在灌注时晃动、灌满后平静。"),
        prompt: L(
            "A heavy 92 pt word stands as a faint hollow shape and fills with liquid from the bottom, the letters acting as the glass. The level rises over 3.2 s on a smooth ease-in-out while a percentage beneath counts along. The surface is two layered sine waves, a pale one behind and a blue gradient one in front with a thin white meniscus line, 7 pt high while pouring; the faster the level moves, the rougher the surface, and once full it calms to a third of that. Small bubbles drift upward inside the liquid. At 100% a diagonal shine sweeps across in 0.7 s and the word swells 4% and settles. Then it drains quickly and repeats; dragging vertically sets the level by hand.",
            "一个92pt的粗重单词起初只是一个淡淡的空心形状，随后像玻璃容器一样从底部被液体灌满。液面在3.2秒内以平滑的缓入缓出上升，下方的百分比同步计数。水面由两层正弦波叠成：后面一层颜色浅，前面一层是蓝色渐变并带一道细细的白色液面线，灌注时浪高7pt；液面移动越快水面越乱，灌满后平息到三分之一。细小的气泡在液体里向上漂。到100%时，一道斜向高光在0.7秒内扫过，单词鼓起4%再回落。随后迅速排空并循环；上下拖动可以亲手控制液面高度。"
        ),
        implementation: L(
            "A TimelineView-driven Canvas draws two wave polygons, bubbles and the shine, and is masked by the Text itself; the level comes from a time function (or the drag), and an agitation value fed by the level's speed and decaying over time scales the wave height.",
            "由 TimelineView 驱动的 Canvas 画出两层波浪多边形、气泡和高光，并用 Text 本身作为蒙版；液面由时间函数（或拖动）决定，一个由液面速度累加、随时间衰减的扰动量控制浪高。"
        ),
        apis: ["Canvas", "TimelineView", "mask(alignment:_:)", "GraphicsContext.Shading.linearGradient", "DragGesture"],
        tags: ["liquid", "fill", "wave", "water", "mask", "液体", "灌注", "波浪", "水位", "文字蒙版"],
        params: [
            .slider("duration", L("Fill time", "灌注时长"), 1.2...7, default: 3.2, decimals: 1, unit: "s"),
            .slider("wave", L("Wave height", "浪高"), 2...16, default: 7, decimals: 0, unit: "pt"),
            .slider("speed", L("Wave speed", "波速"), 0.2...2.5, default: 1.0),
            .toggle("bubbles", L("Bubbles", "气泡"), default: true),
        ]
    ) { ctx in
        TextLiquidFillDemo(ctx: ctx)
    }
}

private struct LiquidSim {
    var last: Date?
    var level: Double = 0
    var agitation: Double = 0.7
}

private struct LiquidFrame {
    var level: Double
    var agitation: Double
    /// Seconds since the word became full in the automatic cycle (negative otherwise).
    var fullFor: Double
    var time: Double
}

private struct TextLiquidFillDemo: View {
    let ctx: DemoContext
    @State private var cycleStart = Date()
    @State private var manual: Double?
    @State private var sim = TextFXBox(LiquidSim())

    private let holdTime: Double = 1.7
    private let drainTime: Double = 0.7
    private let restTime: Double = 0.35

    private var word: String { ctx.language == .zh ? "流动" : "FLOW" }
    private var fontSize: CGFloat { ctx.language == .zh ? 120 : 92 }
    /// Where the ink of the glyphs sits inside the text frame (fractions of its height).
    private var inkTop: CGFloat { ctx.language == .zh ? 0.10 : 0.18 }
    private var inkBottom: CGFloat { ctx.language == .zh ? 0.92 : 0.84 }

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let frame = advance(to: timeline.date)
            VStack(spacing: 10) {
                letters(frame)
                readout(frame)
                DemoHint(text: L("Drag up or down to set the level · tap to refill", "上下拖动控制液面 · 点击重新灌注"), ctx: ctx)
                    .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var label: some View {
        Text(verbatim: word)
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .fixedSize()
    }

    private func letters(_ frame: LiquidFrame) -> some View {
        let swell: Double = frame.fullFor >= 0 && frame.fullFor < 0.5
            ? 0.04 * sin(Double.pi * frame.fullFor / 0.5)
            : 0
        return label
            .foregroundStyle(Color.primary.opacity(0.10))
            .overlay {
                Canvas { context, size in
                    drawLiquid(&context, size: size, frame: frame)
                }
                .mask { label }
            }
            .scaleEffect(1 + swell)
            .contentShape(Rectangle())
            .gesture(drag)
    }

    private func readout(_ frame: LiquidFrame) -> some View {
        HStack(spacing: 6) {
            Image(systemName: frame.level > 0.995 ? "checkmark.circle.fill" : "drop.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.sky)
            Text(verbatim: "\(Int((frame.level * 100).rounded()))%")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Level

    private var period: Double { ctx["duration"] + holdTime + drainTime + restTime }

    /// The automatic cycle: fill, hold, drain, rest.
    private func cycleLevel(_ t: Double) -> (level: Double, fullFor: Double) {
        let fill: Double = max(ctx["duration"], 0.2)
        if t < fill { return (TextFXCurve.smoothstep(t / fill), -1) }
        if t < fill + holdTime { return (1, t - fill) }
        if t < fill + holdTime + drainTime {
            let p: Double = (t - fill - holdTime) / drainTime
            return (1 - p * p, -1)
        }
        return (0, -1)
    }

    private func advance(to date: Date) -> LiquidFrame {
        let time: Double = date.timeIntervalSinceReferenceDate
        if ctx.isStill {
            return LiquidFrame(level: 0.68, agitation: 0.7, fullFor: -1, time: 0.4)
        }
        var level: Double
        var fullFor: Double = -1
        if let manual {
            level = manual
        } else {
            let elapsed: Double = max(date.timeIntervalSince(cycleStart), 0)
            let t: Double = elapsed.truncatingRemainder(dividingBy: period)
            let state = cycleLevel(t)
            level = state.level
            fullFor = state.fullFor
        }
        var state = sim.value
        if let last = state.last {
            let dt: Double = min(max(date.timeIntervalSince(last), 0), 0.1)
            if dt > 0 {
                state.agitation += abs(level - state.level) * 7
                state.agitation *= exp(-dt * 2.2)
                state.agitation = min(state.agitation, 1.3)
                state.level = level
                state.last = date
            }
        } else {
            state.last = date
            state.level = level
        }
        sim.value = state
        return LiquidFrame(level: level, agitation: state.agitation, fullFor: fullFor, time: time)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard abs(value.translation.height) > 4 || manual != nil else { return }
                if manual == nil { Haptics.tap(.soft) }
                // The label's frame height is about 1.19 × the font size.
                let height: CGFloat = fontSize * 1.19
                let top: CGFloat = height * inkTop
                let bottom: CGFloat = height * inkBottom
                let level: CGFloat = 1 - (value.location.y - top) / (bottom - top)
                manual = Double(min(max(level, 0), 1))
            }
            .onEnded { _ in
                if let level = manual {
                    // Carry on with the automatic cycle from this level.
                    cycleStart = Date().addingTimeInterval(-fillTime(for: level))
                    manual = nil
                    Haptics.tap(.light)
                } else {
                    cycleStart = Date()
                    Haptics.tap(.light)
                }
            }
    }

    /// Inverse of the fill curve: how far into the fill the cycle reaches `level`.
    private func fillTime(for level: Double) -> Double {
        var low: Double = 0
        var high: Double = 1
        for _ in 0..<24 {
            let mid: Double = (low + high) / 2
            if TextFXCurve.smoothstep(mid) < level { low = mid } else { high = mid }
        }
        return low * max(ctx["duration"], 0.2)
    }

    // MARK: Drawing

    private func drawLiquid(_ context: inout GraphicsContext, size: CGSize, frame: LiquidFrame) {
        guard frame.level > 0.001 else { return }
        let amplitude: CGFloat = ctx.cg("wave") * CGFloat(0.33 + min(frame.agitation, 1.0) * 0.67)
        let top: CGFloat = size.height * inkTop - ctx.cg("wave") - 2
        let bottom: CGFloat = size.height * inkBottom + ctx.cg("wave") + 2
        let surface: CGFloat = bottom - (bottom - top) * CGFloat(frame.level)
        let phase: Double = frame.time * ctx["speed"] * 2.4

        func wave(_ x: CGFloat, shift: Double, scale: CGFloat) -> CGFloat {
            let u: Double = Double(x / size.width)
            let primary: Double = sin(u * Double.pi * 2 * 1.6 + phase + shift)
            let ripple: Double = sin(u * Double.pi * 2 * 2.9 - phase * 1.4 + shift * 2)
            return surface + amplitude * scale * CGFloat(primary * 0.72 + ripple * 0.28)
        }

        func body(shift: Double, scale: CGFloat) -> (fill: Path, edge: Path) {
            var fill = Path()
            var edge = Path()
            let steps = 48
            for step in 0...steps {
                let x: CGFloat = size.width * CGFloat(step) / CGFloat(steps)
                let point = CGPoint(x: x, y: wave(x, shift: shift, scale: scale))
                if step == 0 {
                    fill.move(to: point)
                    edge.move(to: point)
                } else {
                    fill.addLine(to: point)
                    edge.addLine(to: point)
                }
            }
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            return (fill, edge)
        }

        let back = body(shift: 2.1, scale: 1.25)
        context.fill(back.fill, with: .color(Palette.mint.opacity(0.55)))

        let front = body(shift: 0, scale: 1)
        let gradient = Gradient(colors: [Palette.sky, Palette.blue, Palette.indigo])
        context.fill(
            front.fill,
            with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: surface), endPoint: CGPoint(x: 0, y: size.height))
        )
        context.stroke(front.edge, with: .color(.white.opacity(0.75)), lineWidth: 1.5)

        if ctx.bool("bubbles") {
            for index in 0..<14 {
                let seed: Double = Double(index) * 0.618_034
                let column: Double = (seed * 7.3).truncatingRemainder(dividingBy: 1)
                let rise: Double = (frame.time * (0.10 + 0.07 * column) + seed).truncatingRemainder(dividingBy: 1)
                let sway: Double = sin(frame.time * 1.7 + seed * 9) * 4
                let x: CGFloat = size.width * CGFloat(0.04 + 0.92 * column) + CGFloat(sway)
                let y: CGFloat = size.height - (size.height - top) * CGFloat(rise)
                guard y > wave(x, shift: 0, scale: 1) + 6 else { continue }
                let radius: CGFloat = 1.6 + 2.6 * CGFloat((seed * 3.1).truncatingRemainder(dividingBy: 1))
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.32)))
            }
        }

        // The shine that crosses the word when it becomes full.
        if frame.fullFor >= 0 && frame.fullFor < 0.7 {
            let p: CGFloat = CGFloat(frame.fullFor / 0.7)
            let x: CGFloat = -size.width * 0.3 + size.width * 1.6 * p
            var band = Path()
            band.move(to: CGPoint(x: x, y: size.height))
            band.addLine(to: CGPoint(x: x + 46, y: size.height))
            band.addLine(to: CGPoint(x: x + 46 + size.height * 0.5, y: 0))
            band.addLine(to: CGPoint(x: x + size.height * 0.5, y: 0))
            band.closeSubpath()
            var shine = context
            shine.addFilter(.blur(radius: 8))
            shine.fill(band, with: .color(.white.opacity(0.7)))
        }
    }
}
