import SwiftUI

extension Effect {
    static let backgroundsBubbles = Effect(
        id: "backgrounds.bubbles",
        category: .backgrounds,
        interaction: .tap,
        name: L("Rising Bubbles", "上浮气泡"),
        summary: L(
            "Glassy bubbles wobble up through sunlit water and burst at the surface — or under your finger.",
            "透亮的气泡在透光的水中摇晃上浮，到水面破裂，也可以被手指戳破。"
        ),
        prompt: L(
            "Underwater, looking up: turquoise near the rippling surface, deep navy below, with faint light shafts. 16 bubbles of 9–30 pt radius rise at 18 + 9·√r pt/s, so big ones overtake small ones, swaying sideways on a slow sine. Each is a real soap-film sphere: a clear centre, a tinted rim that thickens toward the edge, an iridescent white-to-cyan-to-pink outline, a tilted specular oval top-left and a thin reflected crescent bottom-right; its outline squashes and stretches by 6% at about 5 rad/s. A bubble bursts when it reaches the surface or is tapped: within 0.45 s a ring expands to 1.5× and fades while nine droplets fly out and fall, and a ripple spreads on the surface. Tapping open water blows a new bubble that springs in with overshoot. Light haptic on every pop. Fresh, buoyant, playful.",
            "从水下仰望：靠近波动水面处是青绿色，往下沉入深蓝。16 个半径 9–30pt 的气泡以 18 + 9·√r pt/s 上浮，大泡会追过小泡，并沿缓慢正弦左右摇摆。每个气泡都像皂膜球：中心通透，边缘色调加厚，轮廓是由白到青再到粉的虹彩描边，左上有一枚倾斜的高光，右下有一道反光弧；轮廓以约 5 rad/s 做 6% 的挤压拉伸。气泡升到水面或被点中就破裂：0.45 秒内一圈环扩大到 1.5 倍并淡出，九颗水珠飞散后下坠，水面荡开涟漪。点击空白水域会吹出一个带过冲弹入的新气泡。每次破裂伴随轻触感。清爽、俏皮。"
        ),
        implementation: L(
            "A reference model integrates the bubbles each frame; a Canvas draws every bubble as a radial-gradient ellipse, a gradient-stroked rim and two highlight Paths, and bursts as analytic rings and droplets from their age.",
            "引用类型模型逐帧积分气泡位置；Canvas 把每个气泡画成径向渐变椭圆、渐变描边的轮廓和两条高光 Path，破裂效果则按存活时间解析地画出扩散环与水珠。"
        ),
        apis: ["Canvas", "GraphicsContext.Shading.radialGradient", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "Haptics"],
        tags: ["bubbles", "water", "pop", "underwater", "气泡", "水下", "破裂", "上浮"],
        params: [
            .slider("count", L("Bubbles", "气泡数量"), 6...36, default: 16, step: 1, decimals: 0),
            .slider("speed", L("Rise speed", "上浮速度"), 0.3...2.5, default: 1.0, unit: "×"),
            .slider("size", L("Size", "大小"), 0.6...1.6, default: 1.0, unit: "×"),
            .slider("wobble", L("Wobble", "晃动"), 0...2.5, default: 1.0, unit: "×"),
        ]
    ) { ctx in
        BubblesDemo(ctx: ctx)
    }
}

private struct Bubble {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var phase: Double
    var born: Double
    /// Blown by a tap: it is not replaced when it bursts.
    var extra: Bool
}

private struct BubbleBurst {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let born: Double
    let atSurface: Bool
}

private final class BubbleModel {
    let clock = BackgroundClock()
    private(set) var bubbles: [Bubble] = []
    private(set) var bursts: [BubbleBurst] = []
    private var size: CGSize = .zero
    private var rng = BackgroundRNG(seed: 7)
    private var lastScale: CGFloat = 0
    static let surface: CGFloat = 20

    private func fresh(scale: CGFloat, spread: Bool) -> Bubble {
        let radius = CGFloat(rng.range(9...30)) * scale
        let y = spread
            ? CGFloat(rng.range(0.16...1.0)) * size.height
            : size.height + radius + CGFloat(rng.range(0...0.35)) * size.height
        return Bubble(
            x: CGFloat(rng.range(0.08...0.92)) * size.width, y: y, radius: radius,
            phase: rng.range(0...BackgroundMath.tau), born: -10, extra: false
        )
    }

    func step(now: Double, size newSize: CGSize, count: Int, speed: Double, scale: CGFloat, frozen: Bool) -> Double {
        if newSize != size {
            size = newSize
            rng = BackgroundRNG(seed: 7)
            bubbles = (0..<count).map { _ in fresh(scale: scale, spread: true) }
            bursts = []
        }
        if scale != lastScale, lastScale > 0 {
            // The size slider rescales the bubbles already in the water.
            for i in bubbles.indices { bubbles[i].radius *= scale / lastScale }
        }
        lastScale = scale
        let t = clock.advance(to: now, speed: 1)
        guard !frozen else { return t }
        let regular = bubbles.filter { !$0.extra }.count
        if regular < count {
            for _ in 0..<(count - regular) { bubbles.append(fresh(scale: scale, spread: false)) }
        } else if regular > count, let index = bubbles.lastIndex(where: { !$0.extra }) {
            bubbles.remove(at: index)
        }
        let dt = CGFloat(clock.delta * speed)
        var popped: [Int] = []
        for i in bubbles.indices {
            let rise = 18 + 9 * bubbles[i].radius.squareRoot()
            bubbles[i].y -= rise * dt
            if bubbles[i].y < Self.surface + bubbles[i].radius * 0.7 { popped.append(i) }
        }
        for i in popped.reversed() { burst(at: i, time: t, atSurface: true, scale: scale) }
        bursts.removeAll { t - $0.born > 0.9 }
        return t
    }

    private func burst(at index: Int, time: Double, atSurface: Bool, scale: CGFloat) {
        let b = bubbles[index]
        bursts.append(BubbleBurst(x: position(of: b, time: time).x, y: b.y, radius: b.radius, born: time, atSurface: atSurface))
        if b.extra {
            bubbles.remove(at: index)
        } else {
            bubbles[index] = fresh(scale: scale, spread: false)
        }
    }

    func position(of b: Bubble, time: Double) -> CGPoint {
        let sway = (5 + b.radius * 0.3) * CGFloat(sin(time * 0.9 + b.phase))
        return CGPoint(x: b.x + sway, y: b.y)
    }

    /// Pops the bubble under `point`, or blows a new one there. Returns `true` for a pop.
    func tap(at point: CGPoint, scale: CGFloat) -> Bool {
        let t = clock.phase
        var best: (index: Int, distance: CGFloat)?
        for i in bubbles.indices {
            let c = position(of: bubbles[i], time: t)
            let d = hypot(c.x - point.x, c.y - point.y)
            if d < bubbles[i].radius + 10, d < (best?.distance ?? .infinity) { best = (i, d) }
        }
        if let best {
            burst(at: best.index, time: t, atSurface: false, scale: scale)
            return true
        }
        let radius = CGFloat(rng.range(15...26)) * scale
        bubbles.append(Bubble(x: point.x, y: point.y, radius: radius, phase: 0, born: t, extra: true))
        return false
    }

    /// Autoplay: burst the bubble nearest the middle of the stage.
    func popOne(scale: CGFloat) {
        let t = clock.phase
        let middle = CGPoint(x: size.width / 2, y: size.height * 0.5)
        var best: (index: Int, distance: CGFloat)?
        for i in bubbles.indices where bubbles[i].y < size.height - 20 {
            let c = position(of: bubbles[i], time: t)
            let d = hypot(c.x - middle.x, c.y - middle.y)
            if d < (best?.distance ?? .infinity) { best = (i, d) }
        }
        if let best { burst(at: best.index, time: t, atSurface: false, scale: scale) }
    }
}

private struct BubblesDemo: View {
    let ctx: DemoContext
    @State private var model = BubbleModel()

    var body: some View {
        let scale = ctx.cg("size")
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x4FC3D9), Color(hex: 0x1C7FA8), Color(hex: 0x0B3F74), Color(hex: 0x061633)],
                startPoint: .top, endPoint: .bottom
            )
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.step(now: now, size: size, count: ctx.int("count"), speed: ctx["speed"], scale: scale, frozen: ctx.isStill)
                    BubblePainter.drawWater(&context, size: size, t: t)
                    for b in model.bubbles {
                        BubblePainter.drawBubble(&context, bubble: b, centre: model.position(of: b, time: t), t: t, wobble: ctx["wobble"])
                    }
                    for burst in model.bursts {
                        BubblePainter.drawBurst(&context, burst: burst, age: t - burst.born)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            if model.tap(at: location, scale: scale) {
                Haptics.tap(.light)
            } else {
                Haptics.tap(.soft)
            }
        }
        .autoplay(ctx.isPreview, every: 1.3, delay: 0.6) { model.popOne(scale: scale) }
        .backgroundsChipHint(L("Tap a bubble to pop it · tap water to blow one", "点气泡戳破 · 点水面吹一个"), ctx)
    }
}

private enum BubblePainter {
    static func drawWater(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        // Light shafts from the surface.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 14))
            layer.blendMode = .plusLighter
            for i in 0..<4 {
                let x = size.width * (0.12 + 0.26 * CGFloat(i)) + 14 * CGFloat(sin(t * 0.25 + Double(i) * 1.9))
                let w = size.width * (0.05 + 0.03 * BackgroundMath.unit(i, 401))
                var shaft = Path()
                shaft.move(to: CGPoint(x: x - w, y: -10))
                shaft.addLine(to: CGPoint(x: x + w, y: -10))
                shaft.addLine(to: CGPoint(x: x + w * 2.6 - 50, y: size.height * 0.85))
                shaft.addLine(to: CGPoint(x: x - w * 2.6 - 50, y: size.height * 0.85))
                shaft.closeSubpath()
                let alpha = 0.1 + 0.05 * sin(t * 0.4 + Double(i))
                layer.fill(shaft, with: .linearGradient(
                    Gradient(colors: [.white.opacity(alpha), .white.opacity(0)]),
                    startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x - 50, y: size.height * 0.85)
                ))
            }
        }
        // The rippling surface seen from below.
        var surface = Path()
        surface.move(to: CGPoint(x: 0, y: 0))
        var x: CGFloat = 0
        while x <= size.width + 6 {
            let y = BubbleModel.surface - 6 + 3 * CGFloat(sin(Double(x) * 0.045 + t * 1.3)) + 2 * CGFloat(sin(Double(x) * 0.11 - t * 0.9))
            surface.addLine(to: CGPoint(x: x, y: y))
            x += 6
        }
        surface.addLine(to: CGPoint(x: size.width, y: 0))
        surface.closeSubpath()
        context.fill(surface, with: .color(Color(hex: 0xC8F4FF).opacity(0.5)))
        // Streams of tiny bubbles.
        var micro = Path()
        for i in 0..<36 {
            let column = i % 3
            let u = BackgroundMath.fract(BackgroundMath.rand(i, 411) + t * (0.1 + 0.08 * BackgroundMath.rand(i, 412)))
            let baseX = size.width * (0.2 + 0.3 * CGFloat(column))
            let px = baseX + 7 * CGFloat(sin(u * 14 + Double(i)))
            let py = size.height - CGFloat(u) * (size.height - BubbleModel.surface)
            let r = 0.7 + 1.1 * BackgroundMath.unit(i, 413)
            micro.addEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
        }
        context.fill(micro, with: .color(.white.opacity(0.35)))
    }

    static func drawBubble(_ context: inout GraphicsContext, bubble: Bubble, centre: CGPoint, t: Double, wobble: Double) {
        let age = t - bubble.born
        // Blown bubbles spring in with overshoot.
        let entry = age < 1.2 ? CGFloat(1 - exp(-7 * age) * cos(13 * age)) : 1
        let squash = CGFloat(0.06 * wobble * sin(t * 5 + bubble.phase * 3)) * min(bubble.radius / 20, 1.3)
        let rx = bubble.radius * entry * (1 + squash)
        let ry = bubble.radius * entry * (1 - squash)
        guard rx > 0.5, ry > 0.5 else { return }
        let rect = CGRect(x: centre.x - rx, y: centre.y - ry, width: rx * 2, height: ry * 2)
        let outline = Path(ellipseIn: rect)

        let film = Gradient(stops: [
            .init(color: .white.opacity(0.02), location: 0),
            .init(color: Color(hex: 0xB8F0FF).opacity(0.05), location: 0.6),
            .init(color: Color(hex: 0xB8F0FF).opacity(0.22), location: 0.88),
            .init(color: .white.opacity(0.5), location: 1),
        ])
        let focus = CGPoint(x: centre.x + rx * 0.12, y: centre.y + ry * 0.14)
        context.fill(outline, with: .radialGradient(film, center: focus, startRadius: 0, endRadius: max(rx, ry) * 1.12))

        let rim = Gradient(colors: [.white.opacity(0.95), Color(hex: 0x8FE9FF).opacity(0.45), Color(hex: 0xFF9BD6).opacity(0.6)])
        context.stroke(
            outline,
            with: .linearGradient(rim, startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)),
            lineWidth: max(0.8, bubble.radius * 0.05)
        )

        // Specular oval, top-left.
        let hw = rx * 0.3
        let hh = ry * 0.16
        let spot = Path(ellipseIn: CGRect(x: -hw, y: -hh, width: hw * 2, height: hh * 2))
            .applying(CGAffineTransform(translationX: centre.x - rx * 0.4, y: centre.y - ry * 0.44).rotated(by: -0.7))
        context.fill(spot, with: .color(.white.opacity(0.85)))
        // Reflected crescent, bottom-right.
        var crescent = Path()
        crescent.addArc(center: centre, radius: min(rx, ry) * 0.74, startAngle: .degrees(18), endAngle: .degrees(72), clockwise: false)
        context.stroke(crescent, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: max(0.8, bubble.radius * 0.07), lineCap: .round))
    }

    static func drawBurst(_ context: inout GraphicsContext, burst: BubbleBurst, age: Double) {
        let p = min(max(age / 0.45, 0), 1)
        let centre = CGPoint(x: burst.x, y: burst.y)
        if p < 1 {
            let ease = CGFloat(1 - pow(1 - p, 3))
            let r = burst.radius * (1 + 0.5 * ease)
            context.stroke(
                Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity((1 - p) * 0.8)),
                lineWidth: CGFloat(1.6 * (1 - p) + 0.3)
            )
            var drops = Path()
            for k in 0..<9 {
                let angle = Double(k) / 9 * BackgroundMath.tau + Double(burst.radius)
                let distance = burst.radius * (1 + 1.1 * ease)
                let x = centre.x + distance * CGFloat(cos(angle))
                let y = centre.y + distance * CGFloat(sin(angle)) + 34 * CGFloat(p * p)
                let s = burst.radius * 0.09 * CGFloat(1 - p) + 0.6
                drops.addEllipse(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2))
            }
            context.fill(drops, with: .color(.white.opacity(0.9 * (1 - p * p))))
        }
        // A bubble that reaches the surface leaves a ripple there.
        if burst.atSurface {
            let q = min(max(age / 0.9, 0), 1)
            let rx = burst.radius * CGFloat(0.8 + 2.2 * q)
            let ry = rx * 0.18
            let rect = CGRect(x: centre.x - rx, y: BubbleModel.surface - 4 - ry, width: rx * 2, height: ry * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity((1 - q) * 0.7)), lineWidth: 1.2)
        }
    }
}
