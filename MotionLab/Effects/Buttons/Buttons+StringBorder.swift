import SwiftUI

extension Effect {
    static let buttonsStringBorder = Effect(
        id: "buttons.string-border",
        category: .buttons,
        interaction: .gesture,
        name: L("Plucked String Border", "拨弦边框"),
        summary: L(
            "The outline is a taut string: a press dents it at the finger, letting go makes it ring out.",
            "边框像一根绷紧的弦：按下时在指尖处凹进去，松手后振动着荡开。"
        ),
        prompt: L(
            "A 236 × 64 pt rounded button whose outline is a taut, glowing string and whose face follows it. Touching it pulls the nearest stretch of border 14 pt inward as a smooth bell-shaped dent about 60 pt wide, reaching full depth in roughly 0.15 s; sliding the finger drags the dent along the perimeter and the label leans 30% of the depth into it. On release the string is let go: the dent swings out past rest and rings at 8 Hz, its amplitude decaying exponentially with a 0.55 s time constant, while two smaller wave packets run away in both directions around the border at 260 pt/s. The string's glow brightens with the vibration energy and fades as it settles. Soft haptic on touch, a light one on the twang. Springy, musical, physical.",
            "236×64pt 的圆角按钮，描边是一根绷紧发光的弦，按钮表面跟着弦一起形变。手指按下时，最近的一段边框被向内拉进 14pt，形成宽约 60pt 的钟形凹陷，约 0.15 秒到位；手指滑动时凹陷沿周长跟着走，文字向凹陷方向偏移深度的 30%。松手即放弦：凹陷反向荡过原位，以 8Hz 振动，振幅按 0.55 秒的时间常数指数衰减，同时两个较小的波包以 260pt/s 沿边框向两侧跑开。弦的辉光随振动能量变亮，静止后淡去。按下有柔和触感，放弦时一记轻触感，弹性十足，像拨动琴弦。"
        ),
        implementation: L(
            "The border is sampled at 180 arc-length positions with outward normals; a TimelineView Canvas offsets every sample by a displacement that is a pure function of time: a Gaussian dent while pressed, then a decaying cosine standing wave plus two travelling Gaussian packets after release. A zero-distance DragGesture finds the nearest sample to place the pluck.",
            "把边框按弧长采样 180 个点并求出外法线；TimelineView 中的 Canvas 让每个采样点沿法线偏移，偏移量是时间的纯函数：按住时是高斯凹陷，松手后是衰减的余弦驻波加两个行进的高斯波包。零距离 DragGesture 找到离手指最近的采样点来确定拨弦位置。"
        ),
        apis: ["TimelineView", "Canvas", "DragGesture", "GraphicsContext.drawLayer", "Path"],
        tags: ["string", "pluck", "border", "vibrate", "elastic", "拨弦", "边框", "振动", "弹性"],
        params: [
            .slider("depth", L("Dent depth", "凹陷深度"), 6...22, default: 14, decimals: 0, unit: "pt"),
            .slider("width", L("Dent width", "凹陷宽度"), 30...110, default: 60, decimals: 0, unit: "pt"),
            .slider("frequency", L("Ring frequency", "振动频率"), 3...14, default: 8, decimals: 1, unit: "Hz"),
            .slider("decay", L("Decay time", "衰减时间"), 0.2...1.2, default: 0.55, unit: "s"),
        ]
    ) { ctx in
        ButtonStringDemo(ctx: ctx)
    }
}

/// Where and when the string was plucked. The displacement of every border point follows from it.
private struct ButtonStringPluck {
    var position: Double = 0
    var pressedAt: Date?
    var releasedAt = Date.distantPast
    var releaseDepth: Double = 0

    /// 0…1 ease-in of the dent while the finger is down.
    func pressAmount(at date: Date) -> Double {
        guard let pressedAt else { return 0 }
        return 1 - exp(-max(date.timeIntervalSince(pressedAt), 0) / 0.05)
    }

    /// Remaining vibration energy, 1 while held.
    func energy(at date: Date, decay: Double) -> Double {
        if pressedAt != nil { return pressAmount(at: date) }
        guard releaseDepth > 0 else { return 0 }
        return exp(-max(date.timeIntervalSince(releasedAt), 0) / decay)
    }

    /// Signed offset along the outward normal at arc position `s` (negative = pushed into the button).
    func displacement(at s: Double, length: Double, date: Date, depth: Double, width: Double, frequency: Double, decay: Double) -> Double {
        var delta = (s - position).truncatingRemainder(dividingBy: length)
        if delta > length / 2 { delta -= length }
        if delta < -length / 2 { delta += length }
        func bell(_ x: Double) -> Double { exp(-(x * x) / (width * width)) }
        if pressedAt != nil {
            return -depth * pressAmount(at: date) * bell(delta)
        }
        guard releaseDepth > 0.01 else { return 0 }
        let age = max(date.timeIntervalSince(releasedAt), 0)
        let amplitude = releaseDepth * exp(-age / decay)
        guard amplitude > 0.05 else { return 0 }
        let swing = cos(2 * .pi * frequency * age)
        let travel = 260 * age
        let standing = 0.6 * bell(delta)
        let packets = 0.2 * (bell(delta - travel) + bell(delta + travel))
        return -amplitude * swing * (standing + packets)
    }
}

/// Arc-length parametrisation of a rounded rectangle, starting at the top-left straight and running clockwise.
private struct ButtonStringGeometry {
    let size: CGSize
    let radius: CGFloat

    private var top: Double { Double(size.width - 2 * radius) }
    private var side: Double { Double(size.height - 2 * radius) }
    private var corner: Double { Double(radius) * .pi / 2 }
    var length: Double { 2 * top + 2 * side + 4 * corner }

    func sample(_ s: Double) -> (point: CGPoint, normal: CGVector) {
        var t = s.truncatingRemainder(dividingBy: length)
        if t < 0 { t += length }
        let r = Double(radius)
        let w = Double(size.width)
        let h = Double(size.height)
        func arc(_ cx: Double, _ cy: Double, _ start: Double, _ t: Double) -> (CGPoint, CGVector) {
            let angle = start + t / r
            return (CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)), CGVector(dx: cos(angle), dy: sin(angle)))
        }
        if t < top { return (CGPoint(x: r + t, y: 0), CGVector(dx: 0, dy: -1)) }
        t -= top
        if t < corner { return arc(w - r, r, -.pi / 2, t) }
        t -= corner
        if t < side { return (CGPoint(x: w, y: r + t), CGVector(dx: 1, dy: 0)) }
        t -= side
        if t < corner { return arc(w - r, h - r, 0, t) }
        t -= corner
        if t < top { return (CGPoint(x: w - r - t, y: h), CGVector(dx: 0, dy: 1)) }
        t -= top
        if t < corner { return arc(r, h - r, .pi / 2, t) }
        t -= corner
        if t < side { return (CGPoint(x: 0, y: h - r - t), CGVector(dx: -1, dy: 0)) }
        t -= side
        return arc(r, r, .pi, t)
    }

    /// Arc position of the border point closest to `point` (in the face's own coordinates).
    func nearest(to point: CGPoint) -> Double {
        var best = 0.0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        let count = 180
        for index in 0..<count {
            let s = length * Double(index) / Double(count)
            let candidate = sample(s).point
            let distance = hypot(candidate.x - point.x, candidate.y - point.y)
            if distance < bestDistance {
                bestDistance = distance
                best = s
            }
        }
        return best
    }
}

private struct ButtonStringDemo: View {
    let ctx: DemoContext
    @State private var pluck: ButtonStringPluck
    @State private var live = false
    @State private var step = 0
    @State private var idleTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    private static let stage = CGSize(width: 320, height: 170)
    private static let face = CGSize(width: 236, height: 64)
    private static let geometry = ButtonStringGeometry(size: face, radius: 22)
    /// Scripted pluck positions as fractions of the perimeter, alternating between the top and bottom straights.
    private static let script: [Double] = [0.17, 0.67, 0.07, 0.58, 0.27, 0.76]

    init(ctx: DemoContext) {
        self.ctx = ctx
        let still = ButtonStringPluck(position: Self.geometry.length * 0.2, pressedAt: .distantPast)
        _pluck = State(initialValue: ctx.isStill ? still : ButtonStringPluck())
    }

    private var depth: Double { ctx["depth"] }
    private var decay: Double { max(ctx["decay"], 0.05) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            control
            Spacer()
            DemoHint(text: L("Press the edge, slide, then let go", "按住边缘滑动，再松手"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.4) { playScript() }
        .onDisappear {
            idleTask?.cancel()
            scriptTask?.cancel()
        }
    }

    private var control: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !live || ctx.isStill)) { timeline in
            let lean = labelLean(at: timeline.date)
            ZStack {
                ButtonStringCanvas(
                    pluck: pluck,
                    date: timeline.date,
                    face: Self.face,
                    geometry: Self.geometry,
                    depth: depth,
                    width: ctx["width"],
                    frequency: ctx["frequency"],
                    decay: decay
                )
                HStack(spacing: 8) {
                    Image(systemName: "guitars.fill")
                    Text(ctx.language == .zh ? "拨一下" : "Pluck me")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .offset(lean)
            }
            .frame(width: Self.stage.width, height: Self.stage.height)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .accessibilityAddTraits(.isButton)
    }

    /// The label is pushed the same way the border moves, by 30% of the current offset.
    private func labelLean(at date: Date) -> CGSize {
        let geometry = Self.geometry
        let offset = pluck.displacement(
            at: pluck.position,
            length: geometry.length,
            date: date,
            depth: depth,
            width: ctx["width"],
            frequency: ctx["frequency"],
            decay: decay
        )
        let normal = geometry.sample(pluck.position).normal
        return CGSize(width: normal.dx * offset * 0.3, height: normal.dy * offset * 0.3)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                scriptTask?.cancel()
                let local = CGPoint(
                    x: value.location.x - (Self.stage.width - Self.face.width) / 2,
                    y: value.location.y - (Self.stage.height - Self.face.height) / 2
                )
                let position = Self.geometry.nearest(to: local)
                if pluck.pressedAt == nil {
                    press(at: position)
                    Haptics.tap(.soft)
                } else {
                    pluck.position = position
                }
            }
            .onEnded { _ in
                release()
                Haptics.tap(.light)
            }
    }

    // MARK: Behaviour

    private func press(at position: Double) {
        idleTask?.cancel()
        live = true
        pluck = ButtonStringPluck(position: position, pressedAt: Date())
    }

    private func release() {
        guard pluck.pressedAt != nil else { return }
        let now = Date()
        let reached = depth * pluck.pressAmount(at: now)
        pluck = ButtonStringPluck(position: pluck.position, pressedAt: nil, releasedAt: now, releaseDepth: reached)
        idleTask?.cancel()
        let rest = decay * 5 + 0.3
        idleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(rest))
            guard !Task.isCancelled else { return }
            live = false
        }
    }

    private func playScript() {
        guard pluck.pressedAt == nil else { return }
        let fraction = Self.script[step % Self.script.count]
        step += 1
        press(at: Self.geometry.length * fraction)
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.32))
            guard !Task.isCancelled else { return }
            release()
        }
    }
}

private struct ButtonStringCanvas: View {
    let pluck: ButtonStringPluck
    let date: Date
    let face: CGSize
    let geometry: ButtonStringGeometry
    let depth: Double
    let width: Double
    let frequency: Double
    let decay: Double

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: (size.width - face.width) / 2, y: (size.height - face.height) / 2)
            let outline = outline(origin: origin)
            let energy = pluck.energy(at: date, decay: decay)

            context.drawLayer { layer in
                layer.addFilter(.shadow(color: Palette.indigo.opacity(0.35), radius: 14, x: 0, y: 9))
                layer.fill(
                    outline,
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x4B57E0), Color(hex: 0x7A45D6)]),
                        startPoint: origin,
                        endPoint: CGPoint(x: origin.x + face.width, y: origin.y + face.height)
                    )
                )
            }
            // Soft top light on the face.
            context.drawLayer { layer in
                layer.clip(to: outline)
                layer.fill(
                    Path(CGRect(x: origin.x, y: origin.y - 20, width: face.width, height: face.height * 0.75)),
                    with: .linearGradient(
                        Gradient(colors: [Color.white.opacity(0.22), .clear]),
                        startPoint: CGPoint(x: origin.x, y: origin.y),
                        endPoint: CGPoint(x: origin.x, y: origin.y + face.height * 0.55)
                    )
                )
            }
            // The string: a glow that follows the vibration energy, then the crisp line.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                layer.stroke(outline, with: .color(Palette.sky.opacity(0.25 + 0.75 * energy)), lineWidth: 4 + 3 * energy)
            }
            context.stroke(
                outline,
                with: .color(Color.white.opacity(0.75 + 0.25 * energy)),
                style: StrokeStyle(lineWidth: 2, lineJoin: .round)
            )
        }
    }

    private func outline(origin: CGPoint) -> Path {
        var path = Path()
        let count = 180
        for index in 0..<count {
            let s = geometry.length * Double(index) / Double(count)
            let sample = geometry.sample(s)
            let offset = pluck.displacement(
                at: s,
                length: geometry.length,
                date: date,
                depth: depth,
                width: width,
                frequency: frequency,
                decay: decay
            )
            let point = CGPoint(
                x: origin.x + sample.point.x + sample.normal.dx * offset,
                y: origin.y + sample.point.y + sample.normal.dy * offset
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
