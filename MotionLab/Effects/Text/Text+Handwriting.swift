import SwiftUI

extension Effect {
    static let textHandwriting = Effect(
        id: "text.handwriting",
        category: .text,
        interaction: .tap,
        name: L("Handwritten Signature", "手写签名"),
        summary: L("A cursive word is written in one continuous stroke by a pen that follows the line, lifts and underlines it.", "一支笔沿着笔迹一气呵成写出连笔字，抬笔后再划一道下划线。"),
        prompt: L(
            "A cursive “hello” is written on faint ruled guides by a visible pen. The word is one continuous stroke drawn over about 2.8 s at an almost constant hand speed, easing only as each stroke starts and ends. Line weight follows pressure like a real nib: downstrokes reach the full 4.5 pt and upstrokes thin to roughly 40%, with tapered ends. The last 34 pt behind the tip stays wet in a violet tint and dries to ink colour. The pen tip stays on the head of the line, then lifts 14 pt in an arc, hops to the left and swooshes a tapered underline before gliding away and fading. Tapping rewrites it. Calm, personal and unmistakably hand-made.",
            "一支看得见的笔在淡淡的格线上写出连笔的“hello”。整个单词是一道连续的笔画，约2.8秒写完，手速几乎恒定，只在每一笔起止处略有缓动。线条粗细像真实笔尖一样随压力变化：下行笔画达到完整的4.5pt，上行笔画收细到约40%，两端带收锋。笔尖身后最近的34pt墨迹还是湿的，带一层紫色，随后干成墨色。笔尖始终贴着线头，写完后沿弧线抬起14pt，跳到左侧，再甩出一道带收锋的下划线，最后滑开并淡出。点击可重写一遍。安静、有个人气息，一看就是手写的。"
        ),
        implementation: L(
            "The cursive is a hand-authored chain of cubic Béziers flattened once into samples with arc length and a pressure value derived from stroke direction; a TimelineView-driven Canvas strokes the samples up to the current length with per-segment widths and draws the pen symbol at the head.",
            "连笔字是手工编写的一串三次贝塞尔曲线，只展开一次为带弧长的采样点，并按笔画方向算出压力值；由 TimelineView 驱动的 Canvas 按当前长度逐段以不同线宽描出，并在线头处画出笔的符号。"
        ),
        apis: ["Canvas", "TimelineView", "Path.addCurve", "GraphicsContext.resolve", "StrokeStyle"],
        tags: ["handwriting", "signature", "cursive", "pen", "stroke", "手写", "签名", "连笔", "笔迹", "书写"],
        params: [
            .slider("duration", L("Writing time", "书写时长"), 1.2...6, default: 2.8, decimals: 1, unit: "s"),
            .slider("width", L("Stroke width", "笔画粗细"), 2...8, default: 4.5, decimals: 1, unit: "pt"),
            .slider("contrast", L("Pressure contrast", "压力对比"), 0...1, default: 0.6),
            .toggle("pen", L("Show pen", "显示笔"), default: true),
        ]
    ) { ctx in
        TextHandwritingDemo(ctx: ctx)
    }
}

// MARK: - Geometry

private struct HandSample {
    var point: CGPoint
    /// 0 = lightest upstroke, 1 = full-pressure downstroke.
    var pressure: Double
    /// Arc length from the start of the stroke, in design units.
    var length: Double
}

private struct HandStroke {
    var samples: [HandSample]
    var length: Double
}

private enum HandScript {
    /// Design box of the lettering.
    static let box = CGSize(width: 244, height: 132)

    /// Each stroke: a start point, then cubic segments (control 1, control 2, end).
    private static let word: [CGFloat] = [
        8, 92,
        22, 90, 40, 60, 46, 30,
        50, 10, 44, 2, 38, 4,
        30, 7, 28, 30, 28, 55,
        28, 70, 28, 88, 28, 100,
        28, 82, 36, 62, 48, 62,
        60, 62, 58, 80, 58, 90,
        58, 98, 64, 102, 72, 98,
        82, 93, 96, 84, 98, 74,
        100, 64, 92, 58, 86, 62,
        78, 67, 76, 84, 82, 94,
        88, 103, 100, 100, 110, 90,
        122, 78, 136, 50, 138, 28,
        140, 10, 134, 2, 128, 4,
        120, 7, 119, 30, 119, 55,
        119, 75, 118, 92, 124, 98,
        130, 103, 138, 98, 146, 90,
        158, 78, 172, 50, 174, 28,
        176, 10, 170, 2, 164, 4,
        156, 7, 155, 30, 155, 55,
        155, 75, 154, 92, 160, 98,
        166, 103, 174, 98, 180, 90,
        186, 82, 192, 66, 202, 62,
        190, 60, 182, 74, 184, 86,
        186, 100, 200, 102, 208, 92,
        216, 82, 214, 64, 202, 62,
        208, 70, 222, 70, 236, 61,
    ]

    private static let underline: [CGFloat] = [
        34, 127,
        92, 114, 168, 113, 232, 119,
    ]

    static let strokes: [HandStroke] = [flatten(word), flatten(underline)]

    private static func flatten(_ numbers: [CGFloat]) -> HandStroke {
        var points: [CGPoint] = []
        var current = CGPoint(x: numbers[0], y: numbers[1])
        points.append(current)
        var index = 2
        let steps = 14
        while index + 5 < numbers.count {
            let c1 = CGPoint(x: numbers[index], y: numbers[index + 1])
            let c2 = CGPoint(x: numbers[index + 2], y: numbers[index + 3])
            let end = CGPoint(x: numbers[index + 4], y: numbers[index + 5])
            for step in 1...steps {
                let t: CGFloat = CGFloat(step) / CGFloat(steps)
                let u: CGFloat = 1 - t
                let a: CGFloat = u * u * u
                let b: CGFloat = 3 * u * u * t
                let c: CGFloat = 3 * u * t * t
                let d: CGFloat = t * t * t
                let x: CGFloat = a * current.x + b * c1.x + c * c2.x + d * end.x
                let y: CGFloat = a * current.y + b * c1.y + c * c2.y + d * end.y
                points.append(CGPoint(x: x, y: y))
            }
            current = end
            index += 6
        }
        // Raw pressure from direction: moving down the page presses, moving up lifts.
        var raw: [Double] = []
        var lengths: [Double] = [0]
        var total: Double = 0
        for i in 1..<points.count {
            let dx = Double(points[i].x - points[i - 1].x)
            let dy = Double(points[i].y - points[i - 1].y)
            let distance: Double = max((dx * dx + dy * dy).squareRoot(), 0.0001)
            total += distance
            lengths.append(total)
            raw.append(0.5 + 0.5 * dy / distance)
        }
        raw.insert(raw.first ?? 0.5, at: 0)
        // Smooth it so the weight changes like ink, not like a switch.
        var samples: [HandSample] = []
        let radius = 5
        for i in points.indices {
            var sum: Double = 0
            var weight: Double = 0
            for j in max(0, i - radius)...min(points.count - 1, i + radius) {
                sum += raw[j]
                weight += 1
            }
            var pressure: Double = sum / weight
            // Tapered entry and exit.
            let fromStart: Double = lengths[i] / 14
            let fromEnd: Double = (total - lengths[i]) / 18
            pressure *= min(1, 0.25 + fromStart) * min(1, 0.2 + fromEnd)
            samples.append(HandSample(point: points[i], pressure: pressure, length: lengths[i]))
        }
        return HandStroke(samples: samples, length: total)
    }
}

// MARK: - Demo

private struct TextHandwritingDemo: View {
    let ctx: DemoContext
    @State private var start: Date?
    @Environment(\.colorScheme) private var colorScheme

    /// Pen-lift pause between the word and the underline, and the pen's exit, as fractions of the writing time.
    private let liftShare: Double = 0.1

    var body: some View {
        VStack(spacing: 18) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let elapsed: Double = start.map { timeline.date.timeIntervalSince($0) } ?? .infinity
                Canvas { context, size in
                    draw(&context, size: size, elapsed: elapsed)
                }
            }
            .frame(width: 320, height: 210)
            DemoHint(text: L("Tap to write it again", "点击重写一遍"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.light)
            replay()
        }
        .autoplay(ctx.isPreview, every: ctx["duration"] + 2.4) { replay() }
    }

    private func replay() {
        start = .now
    }

    // MARK: Drawing

    /// Fractions of each stroke that are written at `elapsed`, plus the pen state.
    private func progress(elapsed: Double) -> (word: Double, underline: Double, lift: Double, exit: Double) {
        let duration: Double = max(ctx["duration"], 0.2)
        let strokes = HandScript.strokes
        let total: Double = strokes[0].length + strokes[1].length
        let writing: Double = duration * (1 - liftShare)
        let wordTime: Double = writing * strokes[0].length / total
        let lineTime: Double = writing - wordTime
        let liftTime: Double = duration * liftShare
        let word: Double = hand(elapsed / wordTime)
        let lift: Double = TextFXCurve.clamp01((elapsed - wordTime) / liftTime)
        let underline: Double = TextFXCurve.easeOutCubic((elapsed - wordTime - liftTime) / lineTime)
        let exit: Double = TextFXCurve.clamp01((elapsed - duration) / 0.45)
        return (word, underline, lift, exit)
    }

    /// Mostly constant hand speed with soft starts and stops.
    private func hand(_ x: Double) -> Double {
        let u: Double = TextFXCurve.clamp01(x)
        return 0.72 * u + 0.28 * TextFXCurve.smoothstep(u)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        let box = HandScript.box
        let scale: CGFloat = min(size.width / (box.width + 16), size.height / (box.height + 30))
        let origin = CGPoint(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2 + 4)
        func place(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale) }

        // Ruled guides: x-height (dashed) and baseline.
        let guide = Color.primary.opacity(0.09)
        var baseline = Path()
        baseline.move(to: place(CGPoint(x: -4, y: 100)))
        baseline.addLine(to: place(CGPoint(x: box.width + 4, y: 100)))
        context.stroke(baseline, with: .color(guide), lineWidth: 1)
        var xHeight = Path()
        xHeight.move(to: place(CGPoint(x: -4, y: 62)))
        xHeight.addLine(to: place(CGPoint(x: box.width + 4, y: 62)))
        context.stroke(xHeight, with: .color(guide), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

        let state = progress(elapsed: elapsed)
        let strokes = HandScript.strokes
        let fractions: [Double] = [state.word, state.underline]
        let base: Double = ctx["width"]
        let contrast: Double = ctx["contrast"]
        let ink = Color.primary
        let wet = Palette.violet
        let wetLength: Double = 34 / Double(scale)
        var head: CGPoint? = nil

        for (strokeIndex, stroke) in strokes.enumerated() {
            let fraction = fractions[strokeIndex]
            guard fraction > 0 else { continue }
            let drawn: Double = stroke.length * fraction
            let writingNow = fraction < 1
            let samples = stroke.samples
            for i in 1..<samples.count {
                let a = samples[i - 1]
                var b = samples[i]
                if a.length >= drawn { break }
                if b.length > drawn {
                    let t: Double = (drawn - a.length) / max(b.length - a.length, 0.0001)
                    b.point = CGPoint(
                        x: a.point.x + (b.point.x - a.point.x) * CGFloat(t),
                        y: a.point.y + (b.point.y - a.point.y) * CGFloat(t)
                    )
                    b.pressure = a.pressure + (b.pressure - a.pressure) * t
                    b.length = drawn
                }
                let pressure: Double = (a.pressure + b.pressure) / 2
                let width: Double = base * (1 - contrast * (1 - pressure))
                var segment = Path()
                segment.move(to: place(a.point))
                segment.addLine(to: place(b.point))
                let style = StrokeStyle(lineWidth: CGFloat(max(width, 0.6)), lineCap: .round, lineJoin: .round)
                context.stroke(segment, with: .color(ink), style: style)
                if writingNow {
                    let behind: Double = drawn - b.length
                    if behind < wetLength {
                        let amount: Double = 1 - behind / wetLength
                        context.stroke(segment, with: .color(wet.opacity(amount)), style: style)
                    }
                }
                if writingNow { head = place(b.point) }
            }
        }

        guard ctx.bool("pen"), !ctx.isStill, elapsed.isFinite, state.exit < 1 else { return }
        // Where the pen is: on the head of the line, in the air between strokes, or leaving.
        let wordEnd = place(strokes[0].samples.last?.point ?? .zero)
        let lineStart = place(strokes[1].samples.first?.point ?? .zero)
        let lineEnd = place(strokes[1].samples.last?.point ?? .zero)
        var tip: CGPoint
        var lifted: CGFloat = 0
        if state.word < 1 {
            tip = head ?? place(strokes[0].samples.first?.point ?? .zero)
        } else if state.lift < 1 {
            let g = CGFloat(TextFXCurve.easeInOut(state.lift))
            tip = CGPoint(x: wordEnd.x + (lineStart.x - wordEnd.x) * g, y: wordEnd.y + (lineStart.y - wordEnd.y) * g)
            lifted = 14 * CGFloat(sin(Double.pi * state.lift))
        } else if state.underline < 1 {
            tip = head ?? lineStart
        } else {
            let g = CGFloat(TextFXCurve.easeInOut(state.exit))
            tip = CGPoint(x: lineEnd.x + 26 * g, y: lineEnd.y - 8 * g)
            lifted = 18 * g
        }
        let alpha: Double = 1 - state.exit
        // Contact shadow on the paper, then the pen itself.
        let shadowRect = CGRect(x: tip.x - 3 - lifted * 0.3, y: tip.y - 2, width: 9 + lifted * 0.6, height: 4)
        context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.22 * alpha * Double(1 - lifted / 30))))
        var pen = context.resolve(
            Text(Image(systemName: "pencil"))
                .font(.system(size: 34, weight: .semibold))
        )
        pen.shading = .color(colorScheme == .dark ? Palette.amber : Palette.coral)
        var penContext = context
        penContext.opacity = alpha
        penContext.draw(pen, at: CGPoint(x: tip.x, y: tip.y - lifted), anchor: UnitPoint(x: 0.14, y: 0.86))
    }
}
