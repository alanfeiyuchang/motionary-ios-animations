import SwiftUI

extension Effect {
    static let morphWaveCircle = Effect(
        id: "morph.wave-circle",
        category: .morph,
        interaction: .gesture,
        name: L("Wave Ring", "波动圆环"),
        summary: L(
            "Pull a ring's outline and let go: the bump splits into two waves that race around the circle, pass through each other and die away.",
            "把圆环的轮廓拉出一个鼓包再松手：鼓包分成两道波沿圆周相向奔跑、彼此穿过，最后平息回正圆。"
        ),
        prompt: L(
            "A 184 pt ring drawn with a 5 pt conic-gradient stroke over a soft glow. Its outline is a closed string of 128 nodes obeying the wave equation with a weak pull back to the circle. Dragging grabs the rim under the finger: the outline follows it radially inside a Gaussian window about 0.22 rad wide, up to 60 pt outward or 46 pt inward, so the amplitude is exactly how far you pull. On release the bump splits into two crests travelling in opposite directions at 0.8 laps per second; they cross on the far side, keep circling and decay (damping 1.6 per second) until the ring is round again. Three inner echo rings replay the outline a few frames late at reduced amplitude, and a centre readout tracks the peak. Taut, resonant, like a plucked drum skin.",
            "一个直径 184pt 的圆环，5pt 锥形渐变描边叠在柔和辉光上。轮廓是由 128 个节点组成的闭合弦，遵循波动方程，并带一点拉回正圆的弱恢复力。拖动时手指抓住所在位置的边缘：轮廓在约 0.22 弧度宽的高斯窗口内沿径向跟随手指，最多外拉 60pt、内压 46pt，振幅就是你拉出的距离。松手后鼓包分成两道波峰，以每秒 0.8 圈的速度反向传播，在对侧相遇穿过、继续绕行并逐渐衰减（阻尼每秒 1.6），直到圆环重新变圆。三圈内层回声环以更小的振幅延迟数帧重放轮廓，中央读数显示峰值。像拨了一下鼓面。"
        ),
        implementation: L(
            "A reference-type ring of 128 nodes integrates the damped 1-D wave equation with at least six sub-steps per frame inside a TimelineView; the finger pins a Gaussian patch of nodes to its radial distance. A Canvas strokes the displaced outline and three echoes read from a short history buffer.",
            "引用类型的 128 节点圆环在 TimelineView 中以每帧至少六个子步积分带阻尼的一维波动方程；手指把一段高斯窗口内的节点钉在它的径向距离上。Canvas 描出位移后的轮廓，以及从一小段历史缓冲中读取的三圈回声。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "GraphicsContext.Shading.conicGradient", "UIGestureRecognizerRepresentable", "Path"],
        tags: ["wave", "ring", "circle", "pluck", "string physics", "波动", "圆环", "拨弦", "波动方程"],
        params: [
            .slider("speed", L("Wave speed", "波速"), 0.2...2.0, default: 0.8, unit: "/s"),
            .slider("damping", L("Damping", "阻尼"), 0.3...6, default: 1.6, decimals: 1),
            .slider("width", L("Grab width", "抓取宽度"), 0.08...0.6, default: 0.22, unit: "rad"),
            .slider("echoes", L("Echo rings", "回声环数"), 0...3, default: 3, step: 1, decimals: 0),
        ]
    ) { ctx in
        WaveCircleDemo(ctx: ctx)
    }
}

private final class WaveRing {
    static let count = 128
    static let radius: Double = 92
    var u = [Double](repeating: 0, count: WaveRing.count)
    var v = [Double](repeating: 0, count: WaveRing.count)
    /// Recent outlines, newest first, for the echo rings.
    var history: [[Double]] = []
    /// Finger in polar coordinates around the ring centre: angle and radial offset from the rim.
    var grab: (angle: Double, offset: Double)?
    private var last: TimeInterval?
    private var autoClock: Double = 0
    private var autoIndex = 0

    init(settled: Bool) {
        if settled {
            for index in 0..<WaveRing.count {
                let theta = Double(index) / Double(WaveRing.count) * 2 * Double.pi
                let a = WaveRing.wrap(theta - 5.2)
                let b = WaveRing.wrap(theta - 0.9)
                let c = WaveRing.wrap(theta - 2.9)
                u[index] = 24 * exp(-a * a / 0.05) + 17 * exp(-b * b / 0.07) - 9 * exp(-c * c / 0.12)
            }
        }
        history = [[Double]](repeating: u, count: 16)
    }

    static func wrap(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * Double.pi)
        if a > Double.pi { a -= 2 * Double.pi }
        if a < -Double.pi { a += 2 * Double.pi }
        return a
    }

    var peak: Double {
        u.reduce(0) { max($0, abs($1)) }
    }

    /// Displace the rim around `angle` and let it go.
    func pluck(angle: Double, amount: Double, width: Double) {
        for index in 0..<WaveRing.count {
            let theta = Double(index) / Double(WaveRing.count) * 2 * Double.pi
            let d = WaveRing.wrap(theta - angle)
            u[index] += amount * exp(-d * d / (2 * width * width))
        }
    }

    func step(to date: Date, speed: Double, damping: Double, width: Double, auto: Bool) {
        let now: TimeInterval = date.timeIntervalSinceReferenceDate
        let elapsed: Double = min(max(now - (last ?? now), 0), 1.0 / 30.0)
        last = now
        guard elapsed > 0 else { return }
        if auto {
            autoClock += elapsed
            if autoClock > 1.7 {
                autoClock = 0
                let angles: [Double] = [5.3, 2.2, 0.6, 3.8]
                let amounts: [Double] = [34, -26, 30, 38]
                pluck(angle: angles[autoIndex % 4], amount: amounts[autoIndex % 4], width: width)
                autoIndex += 1
            }
        }
        let n: Int = WaveRing.count
        let tension: Double = pow(speed * Double(n), 2)
        // Enough sub-steps to keep the explicit integration stable at any wave speed.
        let steps: Int = max(6, Int((elapsed * (4 * tension + 26).squareRoot() / 1.1).rounded(.up)))
        let dt: Double = elapsed / Double(steps)
        for _ in 0..<steps {
            if let grab {
                for index in 0..<n {
                    let theta = Double(index) / Double(n) * 2 * Double.pi
                    let d = WaveRing.wrap(theta - grab.angle)
                    let weight = exp(-d * d / (2 * width * width))
                    guard weight > 0.02 else { continue }
                    // Held nodes chase the finger hard and lose their own momentum.
                    let pull: Double = min(weight * 360 * dt, 1)
                    u[index] += (grab.offset * weight - u[index]) * pull
                    v[index] *= 1 - min(weight, 1) * 0.5
                }
            }
            var acceleration = [Double](repeating: 0, count: n)
            for index in 0..<n {
                let left: Double = u[(index + n - 1) % n]
                let right: Double = u[(index + 1) % n]
                acceleration[index] = tension * (left + right - 2 * u[index]) - 26 * u[index] - damping * v[index]
            }
            for index in 0..<n {
                v[index] += acceleration[index] * dt
                u[index] += v[index] * dt
            }
        }
        history.insert(u, at: 0)
        if history.count > 16 { history.removeLast() }
    }
}

private struct WaveCircleDemo: View {
    let ctx: DemoContext
    @State private var ring: WaveRing
    @State private var touchStart: CGPoint = .zero
    @State private var introDone = false

    private static let canvas = CGSize(width: 316, height: 292)

    init(ctx: DemoContext) {
        self.ctx = ctx
        _ring = State(initialValue: WaveRing(settled: ctx.isStill))
    }

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                let _ = advance(to: timeline.date)
                ZStack {
                    WaveRingCanvas(ring: ring, echoes: ctx.int("echoes"), tick: timeline.date)
                    readout
                }
            }
            .frame(width: WaveCircleDemo.canvas.width, height: WaveCircleDemo.canvas.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                if !ctx.isPreview { Haptics.tap(.soft) }
                let polar = WaveCircleDemo.polar(location)
                ring.pluck(angle: polar.angle, amount: polar.offset >= 0 ? 32 : -26, width: ctx["width"])
            }
            .gesture(PageSafePan(
                directions: [.up, .down, .left, .right],
                onChanged: { translation in
                    let point = CGPoint(x: touchStart.x + translation.width, y: touchStart.y + translation.height)
                    let polar = WaveCircleDemo.polar(point)
                    ring.grab = (polar.angle, min(max(polar.offset, -46), 60))
                },
                onEnded: { _ in
                    if ring.grab != nil, !ctx.isPreview { Haptics.tap(.light) }
                    ring.grab = nil
                },
                onBegan: { touchStart = $0 }
            ))
            DemoHint(text: L("Pull the ring and let go", "拉动圆环再松手"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The detail page plucks once on arrival; previews pluck on a loop inside the simulation.
        .autoplay(false, every: 1.7) {
            ring.pluck(angle: 5.3, amount: 34, width: ctx["width"])
        }
    }

    private var readout: some View {
        let peak = Int(ring.peak.rounded())
        return VStack(spacing: 0) {
            Text(verbatim: "\(peak)")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(verbatim: ctx.language == .zh ? "振幅 pt" : "amplitude pt")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .allowsHitTesting(false)
    }

    private static func polar(_ point: CGPoint) -> (angle: Double, offset: Double) {
        let dx = Double(point.x - canvas.width / 2)
        let dy = Double(point.y - canvas.height / 2)
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * Double.pi }
        return (angle, (dx * dx + dy * dy).squareRoot() - WaveRing.radius)
    }

    private func advance(to date: Date) {
        guard !ctx.isStill else { return }
        ring.step(to: date, speed: ctx["speed"], damping: ctx["damping"], width: ctx["width"], auto: ctx.isPreview)
    }
}

private struct WaveRingCanvas: View {
    let ring: WaveRing
    let echoes: Int
    /// The ring is a reference, so the view needs a value that changes every frame to be redrawn.
    let tick: Date

    private static func outline(_ values: [Double], center: CGPoint, scale: Double, gain: Double) -> Path {
        let n: Int = values.count
        var points: [CGPoint] = []
        points.reserveCapacity(n)
        for index in 0..<n {
            let theta = Double(index) / Double(n) * 2 * Double.pi
            let radius: Double = WaveRing.radius * scale + values[index] * gain
            points.append(CGPoint(x: center.x + CGFloat(cos(theta) * radius), y: center.y + CGFloat(sin(theta) * radius)))
        }
        // Quadratic segments through the midpoints keep the outline smooth at any amplitude.
        var path = Path()
        let first = CGPoint(x: (points[n - 1].x + points[0].x) / 2, y: (points[n - 1].y + points[0].y) / 2)
        path.move(to: first)
        for index in 0..<n {
            let next: CGPoint = points[(index + 1) % n]
            let mid = CGPoint(x: (points[index].x + next.x) / 2, y: (points[index].y + next.y) / 2)
            path.addQuadCurve(to: mid, control: points[index])
        }
        path.closeSubpath()
        return path
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let colors: [Color] = [Palette.sky, Palette.indigo, Palette.violet, Palette.pink, Palette.amber, Palette.sky]
            let conic = GraphicsContext.Shading.conicGradient(Gradient(colors: colors), center: center)
            let main: Path = WaveRingCanvas.outline(ring.u, center: center, scale: 1, gain: 1)

            context.fill(
                main,
                with: .radialGradient(
                    Gradient(colors: [Palette.violet.opacity(0.0), Palette.violet.opacity(0.16)]),
                    center: center, startRadius: 20, endRadius: CGFloat(WaveRing.radius) + 20
                )
            )
            let scales: [Double] = [0.8, 0.62, 0.46]
            let gains: [Double] = [0.6, 0.36, 0.18]
            for echo in 0..<min(max(echoes, 0), 3) {
                let frame: Int = min((echo + 1) * 5, ring.history.count - 1)
                let path: Path = WaveRingCanvas.outline(ring.history[frame], center: center, scale: scales[echo], gain: gains[echo])
                context.opacity = 0.42 - 0.11 * Double(echo)
                context.stroke(path, with: conic, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
            context.opacity = 1
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 10))
                layer.opacity = 0.6
                layer.stroke(main, with: conic, style: StrokeStyle(lineWidth: 11, lineJoin: .round))
            }
            context.stroke(main, with: conic, style: StrokeStyle(lineWidth: 5, lineJoin: .round))
            if let grab = ring.grab {
                let radius: Double = WaveRing.radius + grab.offset
                let point = CGPoint(x: center.x + CGFloat(cos(grab.angle) * radius), y: center.y + CGFloat(sin(grab.angle) * radius))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: .color(.white))
                context.stroke(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: conic, lineWidth: 3)
            }
        }
        .allowsHitTesting(false)
    }
}
