import SwiftUI

extension Effect {
    static let showcaseZoomDial = Effect(
        id: "showcase.zoom-dial",
        category: .showcase,
        interaction: .gesture,
        name: L("Camera Zoom Dial", "相机变焦拨盘"),
        summary: L(
            "Hold the zoom pill and an arc dial unfolds; drag it to zoom with ticks and detents, then it folds back into the pill.",
            "按住变焦胶囊，弧形拨盘随即展开；拖动拨盘变焦，带刻度与段落感，松手后收回胶囊。"
        ),
        prompt: L(
            "A dark camera widget: a viewfinder above three zoom chips (.5, the live value, 3), the centre one orange. Holding the row for 0.16 s, or starting to drag, unfolds an arc dial from the chips: it scales up from 70% and rises 26 pt on a spring (response 0.4 s, damping 0.72) while the side chips fade away. The dial is a wheel of ticks on a logarithmic scale, 22° per doubling, with labelled stops at .5, 1, 2, 3, 5 and 8× that fade toward the edges under a fixed orange pointer. Dragging turns the wheel; the scene scales with the zoom, each minor tick gives a selection haptic, and stops attract the value and click with a rigid tap. 0.7 s after release the dial folds back (response 0.45 s, damping 0.85). Tapping a chip springs to that zoom. Precise, optical.",
            "深色相机组件：取景框下方是三个变焦标签（.5、当前倍率、3），中间为橙色。按住 0.16 秒或直接拖动，弧形拨盘从标签处展开：以弹簧（响应 0.4 秒、阻尼 0.72）从 70% 放大并上升 26pt，两侧标签淡出。拨盘是一圈按对数分布的刻度，每翻一倍占 22°，在 .5、1、2、3、5、8 倍处有数字档位，越靠边越淡，上方是橙色指针。拖动转动拨盘；画面随倍率缩放，每格细刻度一次选择触感，档位吸住数值并硬质咔哒一下。松手 0.7 秒后拨盘收回（响应 0.45 秒、阻尼 0.85）。点击标签弹到对应倍率。"
        ),
        implementation: L(
            "Zoom is stored as log2, so a drag adds a linear offset and the dial angle is a simple difference. An Animatable view takes the zoom level and the open amount as an AnimatablePair and redraws the scene scale, the readout and a Canvas wheel each frame. A DragGesture with zero minimum distance starts a short hold task that opens the dial, and a second task folds it after release.",
            "倍率以 log2 存储，拖动只需加上线性偏移，拨盘角度就是简单的差值。一个 Animatable 视图以 AnimatablePair 接收倍率与展开程度，逐帧重绘画面缩放、读数和 Canvas 拨盘。最小距离为零的 DragGesture 启动一个短暂的按住 task 来展开拨盘，另一个 task 在松手后把它收回。"
        ),
        apis: ["DragGesture", "AnimatablePair", "Canvas", "scaleEffect", "Task.sleep", "spring(response:dampingFraction:)"],
        tags: ["camera", "zoom", "dial", "arc", "detent", "相机", "变焦", "拨盘", "弧形", "段落感"],
        params: [
            .slider("spacing", L("Degrees per doubling", "每翻倍的角度"), 14...34, default: 22, decimals: 0, unit: "°"),
            .slider("fold", L("Fold delay", "收回延迟"), 0.3...2.0, default: 0.7, unit: "s"),
            .slider("max", L("Maximum zoom", "最大倍率"), 5...10, default: 8, step: 1, decimals: 0, unit: "×"),
        ]
    ) { ctx in
        ZoomDialDemo(ctx: ctx)
    }
}

private enum ZoomMetrics {
    static let width: CGFloat = 248
    static let dialHeight: CGFloat = 86
    static let radius: CGFloat = 190
    static let stops: [Double] = [0.5, 1, 2, 3, 5, 8, 10]

    static func label(_ zoom: Double) -> String {
        if zoom < 0.95 { return String(format: "%.1f", zoom).replacingOccurrences(of: "0.", with: ".") }
        if abs(zoom - zoom.rounded()) < 0.05 { return "\(Int(zoom.rounded()))" }
        return String(format: "%.1f", zoom)
    }
}

private struct ZoomDialDemo: View {
    let ctx: DemoContext
    /// log2 of the zoom factor.
    @State private var level: Double
    @State private var open: Bool
    @State private var dragStart: Double?
    @State private var hold: Task<Void, Never>?
    @State private var foldTask: Task<Void, Never>?
    @State private var script: Task<Void, Never>?
    @State private var scripting = false
    @State private var scriptFlip = false
    @GestureState private var finger = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _level = State(initialValue: ctx.isStill ? log2(2.4) : 0)
        _open = State(initialValue: ctx.isStill)
    }

    private var maxLevel: Double { log2(max(ctx["max"], 2)) }
    private var pointsPerDoubling: Double { Double(ZoomMetrics.radius) * ctx["spacing"] * .pi / 180 }

    var body: some View {
        StudioScene(hint: L("Hold the zoom pill, then drag", "按住变焦胶囊，再左右拖动"), ctx: ctx) {
            ZoomFace(level: level, open: open ? 1 : 0, spacing: ctx["spacing"], maxLevel: maxLevel, gesture: gesture)
                .padding(16)
                .signatureCard()
                .onChange(of: finger) { _, down in
                    if !down && !scripting && dragStart != nil { finishDrag(tapAt: nil) }
                }
        }
        .onDisappear {
            hold?.cancel()
            foldTask?.cancel()
            script?.cancel()
        }
        .autoplay(ctx.isPreview, every: 4.0, delay: 0.7) { runScript() }
    }

    private var gesture: AnyGesture<Void> {
        AnyGesture(
            DragGesture(minimumDistance: 0)
                .updating($finger) { _, state, _ in state = true }
                .onChanged { value in
                    if dragStart == nil {
                        script?.cancel()
                        scripting = false
                        foldTask?.cancel()
                        dragStart = level
                        if !open {
                            hold = Task { @MainActor in
                                guard await studioPause(0.16) else { return }
                                openDial(user: true)
                            }
                        }
                    }
                    if !open && abs(value.translation.width) > 6 {
                        hold?.cancel()
                        openDial(user: true)
                    }
                    if open, let start = dragStart {
                        setLevel(start - Double(value.translation.width) / pointsPerDoubling, user: true)
                    }
                }
                .onEnded { value in
                    guard dragStart != nil else { return }
                    let moved = abs(value.translation.width) > 6
                    finishDrag(tapAt: open || moved ? nil : value.location.x)
                }
                .map { _ in () }
        )
    }

    private func finishDrag(tapAt x: CGFloat?) {
        hold?.cancel()
        dragStart = nil
        if let x {
            // A quick tap: the chips are presets.
            let target: Double = x < ZoomMetrics.width / 2 - 28 ? 0.5 : (x > ZoomMetrics.width / 2 + 28 ? 3 : (abs(level) < 0.05 ? 2 : 1))
            Haptics.tap(.light)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { level = min(log2(target), maxLevel) }
        } else {
            scheduleFold()
        }
    }

    private func openDial(user: Bool) {
        guard !open else { return }
        if user { Haptics.tap(.light) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { open = true }
    }

    private func scheduleFold() {
        foldTask?.cancel()
        foldTask = Task { @MainActor in
            guard await studioPause(ctx["fold"]) else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { open = false }
        }
    }

    /// Shared by the finger and the scripted drag: clamp, pull toward stops, tick.
    private func setLevel(_ raw: Double, user: Bool) {
        var value = raw.clamped(to: -1...maxLevel)
        var onStop = false
        for stop in ZoomMetrics.stops.map({ log2($0) }) where stop <= maxLevel + 0.001 && abs(value - stop) < 0.045 {
            value = stop
            onStop = true
        }
        let before = level
        guard value != before else { return }
        level = value
        guard user, !ctx.isPreview else { return }
        if onStop {
            Haptics.tap(.rigid)
        } else if Int((value * 8).rounded(.down)) != Int((before * 8).rounded(.down)) {
            Haptics.selection()
        }
    }

    private func runScript() {
        guard dragStart == nil else { return }
        script?.cancel()
        foldTask?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            openDial(user: false)
            guard await studioPause(0.45) else { return }
            let from = level
            let target = scriptFlip ? 0 : min(log2(3), maxLevel)
            scriptFlip.toggle()
            let finished = await studioScript(1.3) { t in
                setLevel(from + (target - from) * studioEase(t), user: false)
            }
            guard finished else { return }
            scheduleFold()
        }
    }
}

private struct ZoomFace: View, Animatable {
    var level: Double
    var open: Double
    let spacing: Double
    let maxLevel: Double
    let gesture: AnyGesture<Void>

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, open) }
        set {
            level = newValue.first
            open = newValue.second
        }
    }

    var body: some View {
        let zoom = pow(2, level)
        let shown = open.clamped(to: 0...1)
        VStack(spacing: 10) {
            finder(zoom: zoom)
            ZStack(alignment: .bottom) {
                ZoomWheel(level: level, spacing: spacing, maxLevel: maxLevel)
                    .frame(width: ZoomMetrics.width, height: ZoomMetrics.dialHeight)
                    .scaleEffect(0.7 + 0.3 * open, anchor: .bottom)
                    .offset(y: (1 - open) * 26)
                    .opacity(shown)
                HStack(spacing: 10) {
                    sideChip(".5")
                        .opacity(1 - shown)
                        .scaleEffect(1 - 0.3 * shown)
                    Text(verbatim: ZoomMetrics.label(zoom) + "×")
                        .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Signature.accent)
                        .frame(width: 46, height: 34)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .overlay(Capsule().strokeBorder(Signature.accent.opacity(0.35 + 0.4 * shown), lineWidth: 1))
                    sideChip("3")
                        .opacity(1 - shown)
                        .scaleEffect(1 - 0.3 * shown)
                }
                .padding(5)
                .background(Capsule().fill(Color.white.opacity(0.07 * (1 - shown))))
                .padding(.bottom, 2)
            }
            .frame(width: ZoomMetrics.width, height: ZoomMetrics.dialHeight)
            .contentShape(Rectangle())
            .gesture(gesture)
        }
    }

    private func sideChip(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.85))
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.black.opacity(0.45)))
    }

    private func finder(zoom: Double) -> some View {
        ZStack {
            LandscapeArt(seed: 1)
                .scaleEffect(pow(zoom / 0.5, 0.62), anchor: UnitPoint(x: 0.47, y: 0.46))
            ZoomReticle()
                .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .frame(width: 62, height: 62)
                .shadow(color: .black.opacity(0.5), radius: 1.5)
                .scaleEffect(1 + 0.12 * open)
        }
        .frame(width: ZoomMetrics.width, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

/// Four corner brackets.
private struct ZoomReticle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arm = rect.width * 0.24
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1), (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1), (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x + arm * dx, y: corner.y))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + arm * dy))
        }
        return path
    }
}

/// The arc wheel: ticks on a log scale turning under a fixed pointer at the top centre.
private struct ZoomWheel: View {
    let level: Double
    let spacing: Double
    let maxLevel: Double

    var body: some View {
        Canvas { context, size in
            let radius = ZoomMetrics.radius
            let top: CGFloat = 16
            let center = CGPoint(x: size.width / 2, y: top + radius)
            // Wheel body.
            var band = Path()
            band.addArc(center: center, radius: radius - 15, startAngle: .degrees(-140), endAngle: .degrees(-40), clockwise: false)
            context.stroke(band, with: .color(Color.black.opacity(0.5)), style: StrokeStyle(lineWidth: 46))
            context.stroke(band, with: .color(Color.white.opacity(0.06)), style: StrokeStyle(lineWidth: 46))

            func point(_ degrees: Double, _ r: CGFloat) -> CGPoint {
                let a = degrees * .pi / 180
                return CGPoint(x: center.x + r * CGFloat(sin(a)), y: center.y - r * CGFloat(cos(a)))
            }
            let count = Int((maxLevel + 1) * 8 + 0.5)
            for index in 0...max(count, 1) {
                let tickLevel = -1 + Double(index) / 8
                let degrees = (tickLevel - level) * spacing
                guard abs(degrees) < 44 else { continue }
                let fade = 1 - pow(abs(degrees) / 44, 2)
                var tick = Path()
                tick.move(to: point(degrees, radius))
                tick.addLine(to: point(degrees, radius - 6))
                context.stroke(tick, with: .color(Color.white.opacity(0.4 * fade)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
            for stop in ZoomMetrics.stops where log2(stop) <= maxLevel + 0.001 {
                let degrees = (log2(stop) - level) * spacing
                guard abs(degrees) < 44 else { continue }
                let fade = 1 - pow(abs(degrees) / 44, 2)
                let near = max(0, 1 - abs(degrees) / 5)
                var tick = Path()
                tick.move(to: point(degrees, radius + 1))
                tick.addLine(to: point(degrees, radius - 11))
                context.stroke(tick, with: .color(Color.white.opacity(fade)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                let label = Text(verbatim: ZoomMetrics.label(stop))
                    .font(.system(size: 11 + 2 * near, weight: .bold, design: .rounded))
                    .foregroundColor(near > 0.5 ? Signature.accent : Color.white.opacity(0.85 * fade))
                context.draw(label, at: point(degrees, radius - 24))
            }
            // Fixed pointer.
            var pointer = Path()
            pointer.move(to: CGPoint(x: center.x - 5, y: 2))
            pointer.addLine(to: CGPoint(x: center.x + 5, y: 2))
            pointer.addLine(to: CGPoint(x: center.x, y: 11))
            pointer.closeSubpath()
            context.fill(pointer, with: .color(Signature.accent))
        }
    }
}
