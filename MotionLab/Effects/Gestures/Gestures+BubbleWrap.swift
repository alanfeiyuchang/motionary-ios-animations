import SwiftUI

extension Effect {
    static let gesturesBubbleWrap = Effect(
        id: "gestures.bubble-wrap",
        category: .gestures,
        interaction: .gesture,
        name: L("Bubble Wrap", "捏泡泡纸"),
        summary: L("A sheet of glossy air bubbles: tap one and it squishes flat with a ring and a click, or drag across to pop a whole streak.", "一张亮晶晶的气泡膜：点一下，气泡“啪”地瘪掉并荡出一圈光环；手指划过，一路连着爆开。"),
        prompt: L(
            "A translucent sheet holds staggered rows of domed bubbles, six per row, each with a soft radial shade, a crisp specular glint and a rim light. Touching a bubble pops it at once: the dome bulges 12% wider for 40 ms, then collapses flat within 0.12 s, a thin ring expands to 1.8× the bubble's radius and fades over 0.35 s, five tiny specks of air fly outward, and a rigid haptic clicks. What remains is a flat, dull disc with three random creases. Dragging pops every bubble the finger crosses, one click each. When the last bubble is gone, after 0.9 s the sheet re-inflates in a diagonal wave, each dome springing up with an overshoot, 4 ms later per point of distance from the corner. Compulsive, crisp, satisfying.",
            "半透明薄膜上交错排列着鼓起的气泡，每行六颗，各有柔和的径向明暗、清晰的高光点和一道边缘光。手指一碰，气泡立刻爆开：圆顶先在40毫秒内鼓出12%，再在0.12秒内塌平；一圈细环扩散到气泡半径的1.8倍并在0.35秒内淡出，五颗细小气粒向外飞散，同时“咔”地一下硬朗触感。留下的是扁平暗淡、带三道随机折痕的圆片。手指划过会依次爆掉沿途每一颗。全部爆完0.9秒后，整张膜沿对角线波浪式重新鼓起，每颗圆顶带着过冲弹起，离角落每远1 pt晚4毫秒。清脆、解压。"
        ),
        implementation: L(
            "A reference-type model stores each bubble's centre, popped flag and the timestamps of its last pop and re-inflation; hit-testing samples the segment between successive touch points. Inside a TimelineView a Canvas derives every bubble's look from the time since those stamps: dome scale, ring radius and opacity, specks, creases. The timeline sleeps when nothing is animating.",
            "引用类型模型保存每颗气泡的圆心、是否已爆以及最近一次爆开和重新鼓起的时间戳；命中检测沿相邻触点之间的线段取样。在 TimelineView 中，Canvas 根据距离这些时间戳的时长推导每颗气泡的外观：圆顶缩放、光环半径与透明度、气粒、折痕。没有动画时时间线休眠。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture", "GraphicsContext.Shading.radialGradient", "UIImpactFeedbackGenerator"],
        tags: ["bubble wrap", "pop", "fidget", "squish", "haptic", "ring", "泡泡纸", "气泡膜", "解压", "爆破", "触感", "光环"],
        params: [
            .slider("cols", L("Bubbles per row", "每行气泡数"), 4...8, default: 6, step: 1, decimals: 0),
            .slider("ring", L("Ring size", "光环大小"), 1.2...2.8, default: 1.8, decimals: 1, unit: "×"),
            .slider("refill", L("Refill delay", "重新鼓起延迟"), 0.3...3, default: 0.9, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        BubbleWrapDemo(ctx: ctx)
    }
}

private enum Wrap {
    static let size = CGSize(width: 300, height: 262)
}

private struct WrapBubble {
    var centre: CGPoint
    var popped = false
    var poppedAt: Double = -100
    var inflatedAt: Double = -100
    var seed: Int
}

private final class BubbleWrapModel {
    private(set) var bubbles: [WrapBubble] = []
    private(set) var radius: CGFloat = 18
    private(set) var time: Double = 0
    private var refillAt: Double?
    private var lastEvent: Double = 0
    private var cols = 0
    private var clock = GestureStepClock()

    init(cols: Int) {
        layout(cols: cols)
    }

    var isSettled: Bool { refillAt == nil && time - lastEvent > 1.2 }

    func layout(cols newCols: Int) {
        guard newCols != cols else { return }
        cols = newCols
        let pitch: CGFloat = (Wrap.size.width - 16) / (CGFloat(cols) + 0.5)
        let rowPitch: CGFloat = pitch * 0.866
        radius = pitch * 0.42
        let rows: Int = max(Int((Wrap.size.height - 16 - pitch) / rowPitch) + 1, 1)
        let top: CGFloat = (Wrap.size.height - (CGFloat(rows - 1) * rowPitch + pitch)) / 2 + pitch / 2
        var result: [WrapBubble] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let x: CGFloat = 8 + pitch * (CGFloat(col) + 0.5 + (row % 2 == 1 ? 0.5 : 0))
                let y: CGFloat = top + rowPitch * CGFloat(row)
                result.append(WrapBubble(centre: CGPoint(x: x, y: y), seed: row * 31 + col * 7 + 3))
            }
        }
        bubbles = result
        refillAt = nil
    }

    /// Pops the unpopped bubble under `point`, if any.
    func touch(at point: CGPoint) -> Bool {
        for index in bubbles.indices where !bubbles[index].popped {
            if GestureMath.distance(bubbles[index].centre, point) <= radius * 1.02 {
                bubbles[index].popped = true
                bubbles[index].poppedAt = time
                lastEvent = time
                return true
            }
        }
        return false
    }

    func step(to date: Date, refill: Double) {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return }
        time += dt
        if refillAt == nil && !bubbles.isEmpty && bubbles.allSatisfy({ $0.popped }) {
            refillAt = time + refill
            lastEvent = time + refill
        }
        if let at = refillAt, time >= at {
            refillAt = nil
            var latest: Double = time
            for index in bubbles.indices {
                let c: CGPoint = bubbles[index].centre
                // A diagonal wave from the top-left corner.
                let start: Double = time + Double(c.x + c.y) * 0.004
                bubbles[index].popped = false
                bubbles[index].inflatedAt = start
                latest = max(latest, start)
            }
            lastEvent = latest
        }
    }

    /// For the still thumbnail: a swath already popped.
    func poseStill() {
        for index in bubbles.indices {
            let c: CGPoint = bubbles[index].centre
            if abs((c.y - 60) - (c.x - 40) * 0.62) < 30 && c.x < 240 {
                bubbles[index].popped = true
            }
        }
    }
}

private struct BubbleWrapDemo: View {
    let ctx: DemoContext
    @State private var model: BubbleWrapModel
    @State private var touching = false
    @State private var lastPoint: CGPoint = .zero
    @State private var wake = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = BubbleWrapModel(cols: ctx.int("cols"))
        if ctx.isStill { model.poseStill() }
        _model = State(initialValue: model)
    }

    var body: some View {
        let refill = ctx["refill"]
        let ring = ctx.cg("ring")
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let _ = ctx.isStill ? () : model.step(to: date, refill: refill)
                BubbleWrapCanvas(model: model, ring: ring, tick: date)
            }
            .frame(width: Wrap.size.width, height: Wrap.size.height)
            .background(Palette.sky.opacity(0.1))
            .gestureTray(cornerRadius: 26)
            .gesture(drag)

            DemoHint(text: L("Tap a bubble, or drag across the sheet", "点一颗气泡，或在膜上划过"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.2, delay: 0.5) { autoSweep() }
        .onChange(of: ctx.params) {
            model.layout(cols: ctx.int("cols"))
            wake += 1
        }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touching = false }
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    touching = true
                    script?.cancel()
                    lastPoint = value.startLocation
                }
                press(at: value.location)
            }
            .onEnded { _ in touching = false }
    }

    /// The finger (or the scripted one) is at `point`: pop whatever lies between here and its last position.
    private func press(at point: CGPoint) {
        let distance: CGFloat = GestureMath.distance(lastPoint, point)
        let samples: Int = max(Int(distance / 6), 1)
        for step in 1...samples {
            let p: CGPoint = GestureMath.lerp(lastPoint, point, CGFloat(step) / CGFloat(samples))
            if model.touch(at: p) && !ctx.isPreview { Haptics.tap(.rigid) }
        }
        lastPoint = point
        wake += 1
    }

    /// A scripted finger drags a bowed line across the sheet.
    private func autoSweep() {
        guard !touching else { return }
        autoStep += 1
        let paths: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: 30, y: 46), CGPoint(x: 270, y: 120), CGPoint(x: 150, y: 20)),
            (CGPoint(x: 268, y: 210), CGPoint(x: 34, y: 150), CGPoint(x: 150, y: 250)),
            (CGPoint(x: 40, y: 228), CGPoint(x: 262, y: 44), CGPoint(x: 90, y: 90)),
            (CGPoint(x: 150, y: 30), CGPoint(x: 150, y: 236), CGPoint(x: 260, y: 130)),
            (CGPoint(x: 30, y: 110), CGPoint(x: 270, y: 196), CGPoint(x: 150, y: 190)),
            (CGPoint(x: 270, y: 34), CGPoint(x: 40, y: 80), CGPoint(x: 60, y: 10)),
        ]
        let path = paths[autoStep % paths.count]
        script?.cancel()
        script = Task { @MainActor in
            lastPoint = path.0
            _ = await GhostFinger.drag(from: path.0, to: path.1, control: path.2, duration: 1.1) { point in
                press(at: point)
            }
        }
    }
}

private struct BubbleWrapCanvas: View {
    let model: BubbleWrapModel
    let ring: CGFloat
    let tick: Date

    var body: some View {
        Canvas { context, _ in
            let r: CGFloat = model.radius
            for bubble in model.bubbles {
                let since: Double = model.time - bubble.poppedAt
                let grown: Double = model.time - bubble.inflatedAt
                // 1 = full dome, 0 = flat.
                var dome: CGFloat = bubble.popped ? 0 : 1
                var bulge: CGFloat = 1
                if bubble.popped && since < 0.16 {
                    if since < 0.04 {
                        dome = 1
                        bulge = 1 + 0.12 * CGFloat(since / 0.04)
                    } else {
                        let t: CGFloat = CGFloat((since - 0.04) / 0.12)
                        dome = (1 - t) * (1 - t)
                        bulge = 1.12 - 0.12 * t
                    }
                } else if !bubble.popped && grown < 0 {
                    // Waiting for its turn in the refill wave.
                    dome = 0
                } else if !bubble.popped && grown < 0.7 {
                    dome = CGFloat(1 - exp(-7 * grown) * cos(15 * grown))
                }
                drawFlat(&context, bubble, radius: r, amount: 1 - min(dome, 1))
                if dome > 0.01 { drawDome(&context, bubble.centre, radius: r * bulge, dome: dome) }
                if bubble.popped && since < 0.35 { drawBurst(&context, bubble, radius: r, since: since) }
            }
        }
    }

    private func drawFlat(_ context: inout GraphicsContext, _ bubble: WrapBubble, radius r: CGFloat, amount: CGFloat) {
        let c: CGPoint = bubble.centre
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: .color(Palette.sky.opacity(0.07)))
        context.stroke(Path(ellipseIn: rect), with: .color(.primary.opacity(0.13)), lineWidth: 1)
        guard amount > 0.05 else { return }
        // Creases of the deflated film.
        var creases = Path()
        for n in 0..<3 {
            let a: Double = GestureMath.hash(bubble.seed * 5 + n) * 2 * .pi
            let inner: CGFloat = r * CGFloat(0.1 + 0.2 * GestureMath.hash(bubble.seed + n * 3))
            let outer: CGFloat = r * CGFloat(0.6 + 0.3 * GestureMath.hash(bubble.seed * 3 + n))
            creases.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner))
            creases.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + 0.35)) * outer, y: c.y + CGFloat(sin(a + 0.35)) * outer))
        }
        context.stroke(creases, with: .color(.primary.opacity(0.28 * Double(amount))), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        let dimple = rect.insetBy(dx: r * 0.45, dy: r * 0.45)
        context.stroke(Path(ellipseIn: dimple), with: .color(.primary.opacity(0.1 * Double(amount))), lineWidth: 1)
    }

    private func drawDome(_ context: inout GraphicsContext, _ c: CGPoint, radius: CGFloat, dome: CGFloat) {
        let k: Double = Double(min(dome, 1))
        let r: CGFloat = radius * (0.84 + 0.16 * min(dome, 1.15))
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        // Contact shadow, then the dome itself.
        context.fill(Path(ellipseIn: rect.offsetBy(dx: 1.5, dy: 2.5)), with: .color(.black.opacity(0.12 * k)))
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(hex: 0xFFFFFF).opacity(0.85 * k), location: 0),
                .init(color: Color(hex: 0xBFE9FF).opacity(0.62 * k), location: 0.35),
                .init(color: Color(hex: 0x6FB6F2).opacity(0.6 * k), location: 0.8),
                .init(color: Color(hex: 0x3E7FD1).opacity(0.66 * k), location: 1),
            ]),
            center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35),
            startRadius: 0,
            endRadius: r * 1.45
        ))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.55 * k)), lineWidth: 1)
        // Rim light on the lower right, glint on the upper left.
        var rim = Path()
        rim.addArc(center: c, radius: r * 0.74, startAngle: .degrees(10), endAngle: .degrees(80), clockwise: false)
        context.stroke(rim, with: .color(.white.opacity(0.4 * k)), style: StrokeStyle(lineWidth: r * 0.1, lineCap: .round))
        let glint = CGRect(x: c.x - r * 0.52, y: c.y - r * 0.56, width: r * 0.34, height: r * 0.24)
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.95 * k)))
    }

    private func drawBurst(_ context: inout GraphicsContext, _ bubble: WrapBubble, radius r: CGFloat, since: Double) {
        let c: CGPoint = bubble.centre
        let p: CGFloat = CGFloat(since / 0.35)
        let eased: CGFloat = 1 - (1 - p) * (1 - p) * (1 - p)
        let ringRadius: CGFloat = r * (1 + (ring - 1) * eased)
        let rect = CGRect(x: c.x - ringRadius, y: c.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(Palette.sky.opacity(0.85 * Double(1 - p))), lineWidth: 2.2 * (1 - p) + 0.4)
        for n in 0..<5 {
            let a: Double = GestureMath.hash(bubble.seed * 11 + n) * 2 * .pi
            let reach: CGFloat = r * (0.5 + 1.3 * eased)
            let dot: CGFloat = 2.4 * (1 - p) + 0.4
            let at = CGPoint(x: c.x + CGFloat(cos(a)) * reach, y: c.y + CGFloat(sin(a)) * reach)
            context.fill(
                Path(ellipseIn: CGRect(x: at.x - dot, y: at.y - dot, width: dot * 2, height: dot * 2)),
                with: .color(.white.opacity(0.9 * Double(1 - p)))
            )
        }
    }
}
