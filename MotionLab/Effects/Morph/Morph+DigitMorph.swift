import SwiftUI

extension Effect {
    static let morphDigitMorph = Effect(
        id: "morph.digit-morph",
        category: .morph,
        interaction: .loop,
        name: L("Digit Morph", "数字笔画形变"),
        summary: L(
            "A counter whose numerals never swap: each digit is one continuous stroke that bends itself into the next.",
            "一个从不“换字”的计数器：每个数字都是一笔连续的线条，自己弯成下一个数字。"
        ),
        prompt: L(
            "Two large numerals, each drawn as one continuous 16 pt round-capped stroke in a pink-to-indigo gradient with a soft glow beneath and a thin highlight along its spine. Every 1.2 s the count advances and the stroke reshapes itself into the next digit instead of cross-fading: all ten digits are single paths resampled to 96 points of equal arc length, and matching points are interpolated. The change travels along the line like a whip, the start of the stroke leading the end by 45% of the morph, on a spring (0.7 s, bounce 0.3) that swings slightly past the new numeral before settling. The tens digit follows 80 ms after the ones on a rollover and the hue sways within ±40° as it counts. Tapping skips ahead. Fluid, calligraphic, hypnotic.",
            "两个大号数字，各由一笔连续的 16pt 圆头线条写成，粉到靛蓝的渐变，下方一层柔和辉光，笔画中线带一道细高光。每 1.2 秒计数加一，线条自己重塑成下一个数字，而不是交叉淡变：十个数字都是单条路径，按弧长等距重采样为 96 个点，对应点逐一插值。变化像甩鞭一样沿笔画传递，起笔比收笔领先形变全程的 45%，整体乘弹簧（0.7 秒、回弹 0.3），略微甩过新数字再回稳。进位时十位比个位晚 80 毫秒，色相随计数在 ±40° 内缓缓摆动。点一下可立即跳到下一个。流动、有书写感、令人着迷。"
        ),
        implementation: L(
            "Each digit is authored as arcs and segments in one stroke order, then resampled by arc length into a shared point count. A Shape exposes the running count as animatableData, picks the two neighbouring digits, and offsets each point's local progress by its position along the stroke; past the target it extrapolates, which is what makes the spring overshoot.",
            "每个数字先用圆弧和线段按一笔的顺序写出，再按弧长重采样到统一点数。Shape 把连续的计数值作为 animatableData，取相邻两个数字，并按每个点在笔画上的位置错开其局部进度；超过目标值时做外推，弹簧的过冲由此而来。"
        ),
        apis: ["Shape", "animatableData", "Path", "StrokeStyle", "spring(duration:bounce:)", "hueRotation"],
        tags: ["digits", "numbers", "counter", "path morph", "数字", "计数", "路径形变", "笔画"],
        params: [
            .slider("duration", L("Morph duration", "形变时长"), 0.3...1.5, default: 0.7, unit: "s"),
            .slider("bounce", L("Bounce", "回弹"), 0...0.5, default: 0.3),
            .slider("stagger", L("Whip along the stroke", "沿笔画甩动"), 0...1, default: 0.45),
            .slider("interval", L("Count interval", "计数间隔"), 0.6...3, default: 1.2, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        DigitMorphDemo(ctx: ctx)
    }
}

private struct DigitMorphDemo: View {
    let ctx: DemoContext
    @State private var count: Int
    @State private var ones: Double
    @State private var tens: Double
    @State private var ticks = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        let start: Int = ctx.isStill ? 42 : 27
        _count = State(initialValue: start)
        _ones = State(initialValue: Double(start))
        _tens = State(initialValue: Double(start / 10))
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                DigitGlyph(value: tens, target: count / 10, stagger: ctx["stagger"])
                DigitGlyph(value: ones, target: count, stagger: ctx["stagger"])
            }
            .hueRotation(.degrees(40 * sin(Double(ticks) * 0.45)))
            .animation(.easeInOut(duration: 0.6), value: ticks)
            Text(verbatim: ctx.language == .zh ? "一笔 · 十个数字" : "ONE STROKE · TEN DIGITS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(ctx.language == .zh ? 3 : 2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if !ctx.isPreview { Haptics.tap(.soft) }
            advance()
        }
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Tap to skip ahead", "点击立即加一"), ctx: ctx)
                .padding(.bottom, 14)
        }
        // It counts by itself everywhere (it is a loop), so the detail page needs no separate intro play.
        .autoplay(true, every: ctx["interval"], delay: 0.7, intro: false) { advance() }
    }

    private func advance() {
        count += 1
        ticks += 1
        let spring: Animation = .spring(duration: ctx["duration"], bounce: ctx["bounce"])
        withAnimation(spring) { ones = Double(count) }
        if count % 10 == 0 {
            withAnimation(spring.delay(0.08)) { tens = Double(count / 10) }
        }
    }
}

private struct DigitGlyph: View {
    let value: Double
    let target: Int
    let stagger: Double

    var body: some View {
        let stroke = DigitStroke(value: value, target: target, stagger: stagger)
        let ink = LinearGradient(colors: [Palette.pink, Palette.violet, Palette.indigo], startPoint: .top, endPoint: .bottom)
        ZStack {
            stroke
                .stroke(ink, style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                .blur(radius: 14)
                .opacity(0.55)
                .offset(y: 6)
            stroke
                .stroke(ink, style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
            stroke
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .blur(radius: 0.6)
        }
        .frame(width: 108, height: 172)
    }
}

/// One stroke that is digit `floor(value)` bending into the next one; `value` is the animated running count.
private struct DigitStroke: Shape {
    var value: Double
    /// The count the animation is heading for. Past it, the stroke extrapolates (spring overshoot).
    var target: Int
    var stagger: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let from: Int
        let to: Int
        let t: Double
        if value >= Double(target) {
            from = target - 1
            to = target
            t = 1 + (value - Double(target))
        } else {
            let base: Double = max(value, 0).rounded(.down)
            from = Int(base)
            to = from + 1
            t = value - base
        }
        let a: [CGPoint] = DigitGlyphs.table[((from % 10) + 10) % 10]
        let b: [CGPoint] = DigitGlyphs.table[((to % 10) + 10) % 10]
        let count: Int = DigitGlyphs.samples
        let sx: CGFloat = rect.width / DigitGlyphs.box.width
        let sy: CGFloat = rect.height / DigitGlyphs.box.height
        var points: [CGPoint] = []
        points.reserveCapacity(count)
        for index in 0..<count {
            let along: Double = Double(index) / Double(count - 1)
            // Below 1 the start of the stroke leads the end; at and past 1 every point moves together.
            let local: Double = t >= 1 ? t : min(max(t * (1 + stagger) - stagger * along, 0), 1)
            let k = CGFloat(local)
            let x: CGFloat = a[index].x + (b[index].x - a[index].x) * k
            let y: CGFloat = a[index].y + (b[index].y - a[index].y) * k
            points.append(CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy))
        }
        var path = Path()
        path.move(to: points[0])
        for index in 1..<(count - 1) {
            let mid = CGPoint(x: (points[index].x + points[index + 1].x) / 2, y: (points[index].y + points[index + 1].y) / 2)
            path.addQuadCurve(to: mid, control: points[index])
        }
        path.addLine(to: points[count - 1])
        return path
    }
}

/// Ten single-stroke numerals in a 100 × 160 box, resampled to the same number of equally spaced points.
private enum DigitGlyphs {
    static let samples = 96
    static let box = CGSize(width: 100, height: 160)
    static let table: [[CGPoint]] = (0...9).map { resample(outline($0), count: samples) }

    /// Elliptical arc in screen coordinates (y down); angles in degrees, either direction.
    private static func arc(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, from: CGFloat, to: CGFloat) -> [CGPoint] {
        let steps: Int = max(Int(abs(to - from) / 6), 4)
        return (0...steps).map { step in
            let angle: CGFloat = (from + (to - from) * CGFloat(step) / CGFloat(steps)) * .pi / 180
            return CGPoint(x: cx + rx * cos(angle), y: cy + ry * sin(angle))
        }
    }

    private static func outline(_ digit: Int) -> [CGPoint] {
        switch digit {
        case 0:
            return arc(50, 80, 40, 72, from: -90, to: 270)
        case 1:
            return [CGPoint(x: 26, y: 40), CGPoint(x: 58, y: 8), CGPoint(x: 58, y: 152)]
        case 2:
            return arc(50, 48, 38, 40, from: -170, to: 55) + [CGPoint(x: 12, y: 152), CGPoint(x: 90, y: 152)]
        case 3:
            return arc(48, 44, 36, 36, from: -150, to: 90) + arc(48, 118, 38, 38, from: -90, to: 150)
        case 4:
            return [CGPoint(x: 72, y: 152), CGPoint(x: 72, y: 8), CGPoint(x: 8, y: 108), CGPoint(x: 96, y: 108)]
        case 5:
            return [CGPoint(x: 86, y: 8), CGPoint(x: 24, y: 8)] + arc(46, 104, 46, 46, from: -135, to: 150)
        case 6:
            return arc(84, 108, 76, 100, from: -96, to: -180) + arc(50, 108, 42, 42, from: 180, to: -180)
        case 7:
            return [CGPoint(x: 8, y: 8), CGPoint(x: 92, y: 8), CGPoint(x: 38, y: 152)]
        case 8:
            return arc(50, 42, 34, 34, from: 90, to: -270) + arc(50, 118, 42, 42, from: -90, to: 270)
        default:
            return arc(50, 52, 42, 42, from: 0, to: 360) + arc(16, 52, 76, 100, from: 0, to: 84)
        }
    }

    private static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        var lengths: [CGFloat] = [0]
        for index in 1..<points.count {
            let dx: CGFloat = points[index].x - points[index - 1].x
            let dy: CGFloat = points[index].y - points[index - 1].y
            lengths.append(lengths[index - 1] + (dx * dx + dy * dy).squareRoot())
        }
        let total: CGFloat = lengths[lengths.count - 1]
        var result: [CGPoint] = []
        var segment = 1
        for index in 0..<count {
            let wanted: CGFloat = total * CGFloat(index) / CGFloat(count - 1)
            while segment < points.count - 1 && lengths[segment] < wanted { segment += 1 }
            let span: CGFloat = lengths[segment] - lengths[segment - 1]
            let k: CGFloat = span > 0 ? (wanted - lengths[segment - 1]) / span : 0
            result.append(CGPoint(
                x: points[segment - 1].x + (points[segment].x - points[segment - 1].x) * k,
                y: points[segment - 1].y + (points[segment].y - points[segment - 1].y) * k
            ))
        }
        return result
    }
}
