import SwiftUI

extension Effect {
    static let loadingHourglass = Effect(
        id: "loading.hourglass",
        category: .loading,
        interaction: .loop,
        name: L("Sand Hourglass", "流沙沙漏"),
        summary: L("Sand funnels through the neck, a mound grows below, and the glass flips itself with a spring.", "细沙穿过瓶颈落下，下方沙堆渐高，流尽后沙漏自己弹性翻转。"),
        prompt: L(
            "A 124 pt glass hourglass between two rounded caps. Over 2.8 s the amber sand in the top bulb sinks at a steady rate while a funnel dimple deepens at its centre; a 2 pt stream falls through the neck with loose grains tumbling in it, and below a rounded mound rises, widening against the glass until it fills the bulb, with grains skipping off its peak. When the last grain lands the glass waits 0.25 s, then flips 180° in 0.8 s on a spring that overshoots about 8% and rings once, lifting to 106% while its ground shadow narrows. The full bulb is now on top and the loop restarts seamlessly. Patient, physical, satisfying.",
            "一只 124 pt 高的玻璃沙漏，上下各有一块圆角盖板。上半球里的琥珀色细沙在 2.8 秒内匀速下沉，沙面中央的漏斗凹陷逐渐加深；一道 2 pt 的沙流穿过瓶颈落下，其间夹着零散翻滚的沙粒；下半球里圆顶沙堆不断升高、贴着玻璃向两侧铺开，直到填满整个球体，沙粒从堆顶弹跳滚落。最后一粒沙落定后停顿 0.25 秒，沙漏以弹簧在 0.8 秒内翻转 180°，过冲约 8% 并回摆一次，同时抬升到 106%，地面投影随之收窄。装满的一端回到上方，循环无缝重新开始。耐心、真实、解压。"
        ),
        implementation: L(
            "A TimelineView drives one Canvas: the bulb outline is a width function, sand levels come from a cumulative-area table so volume is conserved, both sand bodies are polygons clipped to the bulbs, and the flip is a rotation of the whole drawing along a damped-cosine settle.",
            "TimelineView 驱动一张 Canvas：球体轮廓由“高度 → 半宽”函数生成，沙面高度查累积面积表以保持体积守恒，上下两团沙都是裁切在球体内的多边形，翻转则是整幅图沿阻尼余弦落定曲线旋转。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.clip(to:)", "GraphicsContext.rotate(by:)", "Path"],
        tags: ["hourglass", "sand", "timer", "flip", "沙漏", "流沙", "计时", "翻转"],
        params: [
            .slider("drain", L("Drain time", "流尽时间"), 1.5...8, default: 2.8, decimals: 1, unit: "s"),
            .slider("overshoot", L("Flip overshoot", "翻转过冲"), 0...0.25, default: 0.08),
            .toggle("grains", L("Loose grains", "散落沙粒"), default: true),
        ]
    ) { ctx in
        HourglassDemo(ctx: ctx)
    }
}

private struct SandClock {
    var anchorDate = Date()
    var anchorPhase: Double = 0

    func phase(at date: Date, rate: Double) -> Double {
        anchorPhase + date.timeIntervalSince(anchorDate) * rate
    }

    mutating func rebase(at date: Date, oldRate: Double) {
        anchorPhase = phase(at: date, rate: oldRate)
        anchorDate = date
    }
}

/// Geometry of one bulb: `t` runs from the neck (0) to the cap (1).
private enum SandBulb {
    static let height: CGFloat = 54
    static let maxHalf: CGFloat = 40
    static let neckHalf: CGFloat = 3
    static let steps = 48

    static func half(_ t: Double) -> CGFloat {
        let u: Double = min(max(t, 0), 1)
        return neckHalf + (maxHalf - neckHalf) * CGFloat(pow(sin(u * .pi / 2), 0.72))
    }

    /// Cumulative area share from the neck up to each step (0…1).
    static let cumulative: [Double] = {
        var sums: [Double] = [0]
        var total: Double = 0
        for index in 0..<steps {
            let mid: Double = (Double(index) + 0.5) / Double(steps)
            total += Double(half(mid))
            sums.append(total)
        }
        return sums.map { $0 / total }
    }()

    /// The `t` below which `share` of the bulb's area lies (measured from the neck).
    static func level(forShare share: Double) -> Double {
        let target: Double = min(max(share, 0), 1)
        for index in 1...steps where cumulative[index] >= target {
            let low: Double = cumulative[index - 1]
            let span: Double = max(cumulative[index] - low, 1e-9)
            return (Double(index - 1) + (target - low) / span) / Double(steps)
        }
        return 1
    }

    /// Outline of a bulb. `direction` is -1 for the upper bulb (cap above the neck) and +1 for the lower one.
    static func path(direction: CGFloat, inset: CGFloat = 0) -> Path {
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for index in 0...steps {
            let t: Double = Double(index) / Double(steps)
            let w: CGFloat = max(half(t) - inset, 0.5)
            let y: CGFloat = direction * height * CGFloat(t)
            left.append(CGPoint(x: -w, y: y))
            right.append(CGPoint(x: w, y: y))
        }
        var path = Path()
        path.addLines(left + right.reversed())
        path.closeSubpath()
        return path
    }
}

private struct SandFrame {
    /// Share of the sand that has fallen (0…1).
    var fallen: Double
    /// Seconds since the drain started (drives the stream's head and tail).
    var elapsed: Double
    var drain: Double
    /// Flip progress along the settle curve (0…1, may overshoot).
    var turn: Double
    /// 0…1…0 across the flip, for the lift and the shadow.
    var lift: Double

    static let wait: Double = 0.25
    static let flip: Double = 0.8
    static let rest: Double = 0.2

    static func cycle(drain: Double) -> Double { drain + wait + flip + rest }

    static func settle(_ u: Double, overshoot: Double) -> Double {
        let x: Double = min(max(u, 0), 1)
        let decay: Double = -3 * log(max(overshoot, 0.005))
        let wobble: Double = exp(-decay * x) * cos(3 * .pi * x)
        return 1 - wobble * (1 - x * x * x)
    }

    static func at(seconds: Double, drain: Double, overshoot: Double) -> SandFrame {
        let fallen: Double = min(seconds / drain, 1)
        let flipStart: Double = drain + wait
        let u: Double = min(max((seconds - flipStart) / flip, 0), 1)
        return SandFrame(
            fallen: fallen,
            elapsed: seconds,
            drain: drain,
            turn: u > 0 ? settle(u, overshoot: overshoot) : 0,
            lift: sin(.pi * min(u * 1.5, 1))
        )
    }
}

private struct HourglassDemo: View {
    let ctx: DemoContext
    @State private var clock = SandClock()

    var body: some View {
        let zh = ctx.language == .zh
        let drain: Double = max(ctx["drain"], 0.5)
        let total: Double = SandFrame.cycle(drain: drain)
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let phase: Double = clock.phase(at: timeline.date, rate: 1 / total)
            // Stills show the glass half-run, with the stream and both sand bodies visible.
            let seconds: Double = ctx.isStill ? drain * 0.52 : (phase - floor(phase)) * total
            let frame = SandFrame.at(seconds: seconds, drain: drain, overshoot: ctx["overshoot"])
            let left: Int = max(Int((drain - seconds).rounded(.up)), 0)
            VStack(spacing: 10) {
                HourglassCanvas(frame: frame, grains: ctx.bool("grains"))
                    .frame(width: 180, height: 192)
                VStack(spacing: 4) {
                    Text(zh ? "正在整理你的资料库" : "Tidying your library")
                        .font(.subheadline.weight(.semibold))
                    Text(left > 0
                         ? (zh ? "大约还需 \(left) 秒" : "About \(left) s left")
                         : (zh ? "马上就好" : "Almost there"))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx["drain"]) { old, _ in
            clock.rebase(at: .now, oldRate: 1 / SandFrame.cycle(drain: max(old, 0.5)))
        }
    }
}

private struct HourglassCanvas: View {
    let frame: SandFrame
    let grains: Bool

    private static let capColor = Color.adaptive(light: 0x3C3C48, dark: 0xD9D9E2)

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2 - 6)
            let lift: CGFloat = CGFloat(frame.lift)

            // Ground shadow (not rotated).
            let shadowWidth: CGFloat = 96 - 34 * lift
            let shadowRect = CGRect(x: center.x - shadowWidth / 2, y: center.y + 76, width: shadowWidth, height: 9)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 4))
                layer.fill(Path(ellipseIn: shadowRect), with: .color(Color.primary.opacity(0.16 - 0.08 * frame.lift)))
            }

            context.translateBy(x: center.x, y: center.y - 8 * lift)
            context.scaleBy(x: 1 + 0.06 * lift, y: 1 + 0.06 * lift)
            context.rotate(by: .degrees(180 * frame.turn))
            HourglassCanvas.drawGlassBack(&context)
            HourglassCanvas.drawSand(&context, frame: frame, grains: grains)
            HourglassCanvas.drawGlassFront(&context)
        }
    }

    private static func sandShading() -> GraphicsContext.Shading {
        // Point-symmetric about the centre, so the picture is identical after a half turn.
        .radialGradient(
            Gradient(colors: [Color(hex: 0xFFD56B), Palette.amber, Color(hex: 0xF29A3C)]),
            center: .zero,
            startRadius: 0,
            endRadius: 62
        )
    }

    private static func drawGlassBack(_ context: inout GraphicsContext) {
        for direction: CGFloat in [-1, 1] {
            let bulb = SandBulb.path(direction: direction)
            context.fill(bulb, with: .color(Palette.sky.opacity(0.10)))
            context.fill(bulb, with: .color(Color.primary.opacity(0.03)))
        }
    }

    private static func drawSand(_ context: inout GraphicsContext, frame: SandFrame, grains: Bool) {
        let f: Double = frame.fallen
        let h: CGFloat = SandBulb.height
        let shading = sandShading()

        // Upper body: what is left sits against the neck, with a funnel dimple in the middle.
        if f < 0.999 {
            let level: Double = SandBulb.level(forShare: 1 - f)
            let surfaceY: CGFloat = -h * CGFloat(level)
            let halfWidth: CGFloat = SandBulb.half(level)
            let dimple: CGFloat = min(h * CGFloat(level) * 0.55, 13) * CGFloat(min(f / 0.12, 1))
            var points: [CGPoint] = []
            let samples: Int = 24
            for index in 0...samples {
                let s: Double = Double(index) / Double(samples) * 2 - 1
                let fall: Double = pow(1 - abs(s), 1.6)
                points.append(CGPoint(x: halfWidth * CGFloat(s), y: surfaceY + dimple * CGFloat(fall)))
            }
            points.append(CGPoint(x: halfWidth, y: 0))
            points.append(CGPoint(x: -halfWidth, y: 0))
            var body = Path()
            body.addLines(points)
            body.closeSubpath()
            var upper = context
            upper.clip(to: SandBulb.path(direction: -1, inset: 2.5))
            upper.fill(body, with: shading)
        }

        // Lower body: a rounded mound that flattens out as the bulb fills.
        var peakY: CGFloat = h - 2.5
        if f > 0.001 {
            // Sand lies between the cap (t = 1) and `fillT`; the area between them is the fallen share.
            let fillT: Double = SandBulb.level(forShare: 1 - f)
            let surfaceY: CGFloat = h * CGFloat(fillT)
            let mound: CGFloat = 15 * CGFloat(pow(sin(.pi * min(f, 1)), 0.7)) * CGFloat(1 - f * 0.55)
            var points: [CGPoint] = []
            let samples: Int = 24
            let reach: CGFloat = SandBulb.maxHalf
            for index in 0...samples {
                let s: Double = Double(index) / Double(samples) * 2 - 1
                let bell: Double = 0.5 + 0.5 * cos(.pi * s)
                // The mound takes from the edges what it piles in the middle.
                points.append(CGPoint(x: reach * CGFloat(s), y: surfaceY - mound * CGFloat(bell - 0.42)))
            }
            points.append(CGPoint(x: reach, y: h))
            points.append(CGPoint(x: -reach, y: h))
            var body = Path()
            body.addLines(points)
            body.closeSubpath()
            var lower = context
            lower.clip(to: SandBulb.path(direction: 1, inset: 2.5))
            lower.fill(body, with: shading)
            peakY = max(surfaceY - mound * 0.58, 3)
        }

        // The stream: its head drops in at the start, its tail drops out at the end.
        let gravity: Double = 1500
        let head: CGFloat = min(CGFloat(0.5 * gravity * frame.elapsed * frame.elapsed), peakY)
        let sinceEmpty: Double = frame.elapsed - frame.drain
        let tail: CGFloat = sinceEmpty > 0 ? min(CGFloat(0.5 * gravity * sinceEmpty * sinceEmpty), peakY) : -3
        if head > tail + 0.5 {
            var stream = Path()
            stream.move(to: CGPoint(x: 0, y: tail))
            stream.addLine(to: CGPoint(x: 0, y: head))
            context.stroke(stream, with: .color(Palette.amber), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            if grains {
                // Loose grains tumbling in the stream.
                for index in 0..<7 {
                    let seed: Double = Double(index) * 0.618
                    let travel: Double = (frame.elapsed * 1.9 + seed).truncatingRemainder(dividingBy: 1)
                    let y: CGFloat = tail + (head - tail) * CGFloat(travel * travel)
                    let x: CGFloat = CGFloat(sin(seed * 40 + frame.elapsed * 9)) * 2.2
                    let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xFFE39A)))
                }
                // Grains skipping off the peak, only while sand is landing.
                if head >= peakY - 0.5 {
                    for index in 0..<6 {
                        let seed: Double = Double(index) / 6
                        let hop: Double = (frame.elapsed * 2.6 + seed).truncatingRemainder(dividingBy: 1)
                        let side: CGFloat = index % 2 == 0 ? 1 : -1
                        let x: CGFloat = side * CGFloat(3 + 15 * hop)
                        let y: CGFloat = peakY - CGFloat(22 * hop * (1 - hop)) + CGFloat(7 * hop)
                        let rect = CGRect(x: x - 1.1, y: y - 1.1, width: 2.2, height: 2.2)
                        context.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xFFD56B).opacity(1 - hop)))
                    }
                }
            }
        }
    }

    private static func drawGlassFront(_ context: inout GraphicsContext) {
        let h: CGFloat = SandBulb.height
        let glass = GraphicsContext.Shading.color(Color.primary.opacity(0.42))
        for direction: CGFloat in [-1, 1] {
            context.stroke(SandBulb.path(direction: direction), with: glass, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            // A specular streak: upper-left on the top bulb, lower-right on the bottom one (point-symmetric).
            var streak = Path()
            let x: CGFloat = direction * 27
            streak.move(to: CGPoint(x: x, y: direction * (h - 12)))
            streak.addQuadCurve(to: CGPoint(x: direction * 15, y: direction * 20), control: CGPoint(x: direction * 26, y: direction * 30))
            context.stroke(streak, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        // Caps and the two posts.
        for direction: CGFloat in [-1, 1] {
            let cap = CGRect(x: -50, y: direction * (h + 4) - 4, width: 100, height: 8)
            context.fill(Path(roundedRect: cap, cornerRadius: 4, style: .continuous), with: .color(capColor))
            var post = Path()
            post.move(to: CGPoint(x: direction * 46, y: -h))
            post.addLine(to: CGPoint(x: direction * 46, y: h))
            context.stroke(post, with: .color(capColor.opacity(0.55)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
}
