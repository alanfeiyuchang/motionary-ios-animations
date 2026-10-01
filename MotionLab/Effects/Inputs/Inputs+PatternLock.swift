import SwiftUI

extension Effect {
    static let inputsPatternLock = Effect(
        id: "inputs.pattern-lock",
        category: .inputs,
        interaction: .gesture,
        name: L("Elastic Pattern Lock", "弹性图案锁"),
        summary: L("A rubbery line stretches from dot to finger and twangs when it catches; wrong shakes red and reels in, right traces green.", "橡皮筋般的线从圆点拉向手指，接上时“嘣”地一颤；画错变红抖动并收线，画对则绿光描过。"),
        prompt: L(
            "A 3 × 3 pattern lock: nine 14 pt dots on a 72 pt grid. Dragging from a dot pulls out a 6 pt indigo line like elastic: the live strand tapers toward the finger and thins as it lengthens. Within 26 pt of a free dot it snaps on; the finished segment twangs, bowing 7 pt sideways and ringing out on a very underdamped spring (response 0.22 s, damping 0.16), while the dot swells to 130% and a ring ripples from 50% to 170% over 450 ms with a selection haptic. A wrong pattern turns red, shakes the grid 10 pt for 400 ms with an error haptic, then reels the line in segment by segment, 50 ms apart. The correct Z turns green: a white highlight runs the path in 0.7 s, the dots pop in order 60 ms apart, the lock opens and a success haptic fires.",
            "3 × 3 图案锁：九个 14pt 圆点按 72pt 间距排列。从圆点拖出一条 6pt 靛蓝线，像橡皮筋：朝手指渐细、越长越细。靠近空闲圆点 26pt 内即吸附；刚完成的线段向侧面弓起 7pt，以强欠阻尼弹簧（响应 0.22 秒、阻尼 0.16）余振衰减，圆点放大到 130%，涟漪在 450 毫秒内从 50% 扩到 170%。图案错误时变红，网格抖动 10pt 持续 400 毫秒并触发错误触觉，随后线段逐段收回，间隔 50 毫秒。画出正确的 Z 则变绿：白色高光在 0.7 秒内描过路径，圆点依次间隔 60 毫秒弹起，锁打开并触发成功触觉。"
        ),
        implementation: L(
            "Each joined segment is its own view holding a bend value that springs from the twang amplitude to zero inside an animatable quad-curve Shape; the live strand is a second animatable Shape that tapers with length. The same join and finish functions serve the DragGesture and the scripted finger, and trim drives both the reel-in and the success highlight.",
            "每条已连接的线段都是独立视图，持有一个从拨动幅度弹回零的弯曲值，由可动画的二次曲线 Shape 绘制；活动线段是另一个随长度变细的可动画 Shape。DragGesture 与脚本手指共用同一套连接与结束函数，trim 同时驱动收线与成功高光。"
        ),
        apis: ["Shape", "animatableData", "DragGesture", "trim(from:to:)", "keyframeAnimator", "spring(response:dampingFraction:)"],
        tags: ["pattern lock", "unlock", "elastic", "line", "android", "图案锁", "解锁", "弹性", "连线", "九宫格"],
        params: [
            .slider("twang", L("Twang amplitude", "拨动幅度"), 0...14, default: 7, decimals: 0, unit: "pt"),
            .slider("capture", L("Capture radius", "吸附半径"), 16...36, default: 26, decimals: 0, unit: "pt"),
            .slider("width", L("Line width", "线宽"), 3...10, default: 6, decimals: 0, unit: "pt"),
            .slider("shake", L("Error shake", "错误抖动"), 4...20, default: 10, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        InputPatternLockDemo(ctx: ctx)
    }
}

private enum InputPatternStatus {
    case idle, error, success
}

private struct InputPatternLockDemo: View {
    let ctx: DemoContext
    @State private var path: [Int]
    @State private var finger: CGPoint?
    @State private var status: InputPatternStatus
    @State private var pulses = Array(repeating: 0, count: 9)
    @State private var shakes = 0
    @State private var retracting = false
    @State private var trace: CGFloat = 0
    @State private var busy = false
    @State private var step = 0
    @State private var scriptTask: Task<Void, Never>?
    @State private var resultTask: Task<Void, Never>?
    @GestureState private var touching = false

    private static let secret = [0, 1, 2, 4, 6, 7, 8]
    private static let wrong = [0, 3, 6, 7, 5]
    private let spacing: CGFloat = 72
    private let side: CGFloat = 216

    init(ctx: DemoContext) {
        self.ctx = ctx
        _path = State(initialValue: ctx.isStill ? Self.secret : [])
        _status = State(initialValue: ctx.isStill ? .success : .idle)
    }

    private var tint: Color {
        switch status {
        case .idle: return Palette.indigo
        case .error: return Palette.red
        case .success: return Palette.green
        }
    }

    private func point(_ index: Int) -> CGPoint {
        CGPoint(x: 36 + CGFloat(index % 3) * spacing, y: 36 + CGFloat(index / 3) * spacing)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            header
                .padding(.bottom, 10)
            grid
            Spacer(minLength: 0)
            DemoHint(text: L("Draw a Z from the top-left dot", "从左上角的点开始画一个 Z"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.6, delay: 0.4) { previewTick() }
        .onDisappear {
            scriptTask?.cancel()
            resultTask?.cancel()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: status == .success ? "lock.open.fill" : "lock.fill")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(status == .idle ? Color.primary : tint)
            Text(title, ctx.language)
                .contentTransition(.opacity)
        }
        .font(.headline)
        .foregroundStyle(.primary)
        .animation(.smooth(duration: 0.25), value: status)
    }

    private var title: LocalizedText {
        switch status {
        case .idle: return L("Draw your pattern", "绘制解锁图案")
        case .error: return L("Wrong pattern", "图案错误")
        case .success: return L("Unlocked", "已解锁")
        }
    }

    // MARK: Grid

    private var grid: some View {
        let width = ctx.cg("width")
        return ZStack {
            segments(width: width)
            liveStrand(width: width)
            highlight(width: width)
            ForEach(0..<9, id: \.self) { index in
                InputPatternDot(joined: path.contains(index), tint: tint, pulse: pulses[index])
                    .position(point(index))
            }
        }
        .frame(width: side, height: side)
        .keyframeAnimator(initialValue: CGFloat(0), trigger: shakes) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            let distance = ctx.cg("shake")
            KeyframeTrack(\.self) {
                CubicKeyframe(distance, duration: 0.07)
                CubicKeyframe(-distance * 0.8, duration: 0.09)
                CubicKeyframe(distance * 0.5, duration: 0.09)
                CubicKeyframe(-distance * 0.25, duration: 0.08)
                CubicKeyframe(0, duration: 0.07)
            }
        }
        .contentShape(Rectangle())
        .gesture(drag)
        .onChange(of: touching) { _, down in
            if !down { finish() }
        }
    }

    private func segments(width: CGFloat) -> some View {
        let count = max(path.count - 1, 0)
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                InputPatternSegment(
                    from: point(path[index]),
                    to: point(path[index + 1]),
                    tint: tint,
                    width: width,
                    amplitude: ctx.isStill ? 0 : ctx.cg("twang") * (index % 2 == 0 ? 1 : -1),
                    retracting: retracting,
                    delay: Double(count - 1 - index) * 0.05
                )
            }
        }
    }

    @ViewBuilder
    private func liveStrand(width: CGFloat) -> some View {
        if let finger, let last = path.last, status == .idle {
            InputPatternStrand(from: point(last), to: finger, width: width)
                .fill(tint.opacity(0.8))
        }
    }

    private func highlight(width: CGFloat) -> some View {
        InputPatternPolyline(points: path.map(point))
            .trim(from: max(trace - 0.22, 0), to: min(trace, 1))
            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: width * 0.55, lineCap: .round, lineJoin: .round))
            .shadow(color: .white.opacity(0.9), radius: 6)
            .opacity(status == .success ? 1 : 0)
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if scriptTask != nil { stopScript() }
                guard !busy else { return }
                finger = value.location
                capture(at: value.location)
            }
            .onEnded { _ in finish() }
    }

    private func capture(at location: CGPoint) {
        let radius = ctx.cg("capture")
        for index in 0..<9 where !path.contains(index) {
            let dot = point(index)
            guard hypot(dot.x - location.x, dot.y - location.y) < radius else { continue }
            // Jumping over a free dot in a straight line picks it up on the way, like the real lock.
            if let last = path.last {
                let rowSum = last / 3 + index / 3
                let columnSum = last % 3 + index % 3
                if rowSum % 2 == 0, columnSum % 2 == 0 {
                    let middle = rowSum / 2 * 3 + columnSum / 2
                    if middle != last, middle != index, !path.contains(middle) { join(middle) }
                }
            }
            join(index)
            return
        }
    }

    /// A dot is caught, by the finger or the script.
    private func join(_ index: Int) {
        guard !path.contains(index) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { path.append(index) }
        pulses[index] += 1
        if scriptTask == nil { Haptics.selection() }
    }

    /// The finger (or the script) lets go: judge the pattern.
    private func finish(scripted: Bool = false) {
        guard !busy, finger != nil || !path.isEmpty else { return }
        finger = nil
        guard path.count > 1 else {
            withAnimation(.easeOut(duration: 0.2)) { path = [] }
            return
        }
        busy = true
        let correct = path == Self.secret
        let order = path
        let quiet = ctx.isPreview || scripted
        resultTask?.cancel()
        resultTask = Task { @MainActor in
            if correct {
                withAnimation(.easeOut(duration: 0.2)) { status = .success }
                if !quiet { Haptics.success() }
                trace = 0
                withAnimation(.linear(duration: 0.7)) { trace = 1.22 }
                for index in order {
                    pulses[index] += 1
                    try? await Task.sleep(for: .milliseconds(60))
                }
                try? await Task.sleep(for: .seconds(1.5))
            } else {
                withAnimation(.easeOut(duration: 0.12)) { status = .error }
                shakes += 1
                if !quiet { Haptics.error() }
                try? await Task.sleep(for: .seconds(0.6))
                retracting = true
                try? await Task.sleep(for: .seconds(0.16 + Double(order.count) * 0.05))
            }
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    private func reset() {
        var plain = Transaction()
        plain.disablesAnimations = true
        // After a reel-in the segments are already gone: drop them without animation, or they would
        // flash back at full length while fading.
        let reeled = retracting
        withTransaction(plain) {
            if reeled { path = [] }
            retracting = false
            trace = 0
        }
        withAnimation(.easeOut(duration: 0.25)) {
            path = []
            status = .idle
        }
        busy = false
    }

    // MARK: Autoplay

    private func previewTick() {
        let pattern = step % 2 == 0 ? Self.secret : Self.wrong
        step += 1
        play(pattern)
    }

    /// A scripted finger: glides dot to dot and goes through the same join / finish as a real drag.
    private func play(_ pattern: [Int]) {
        guard !busy, let first = pattern.first else { return }
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            finger = point(first)
            join(first)
            for index in pattern.dropFirst() {
                withAnimation(.easeInOut(duration: 0.2)) { finger = point(index) }
                try? await Task.sleep(for: .seconds(0.21))
                guard !Task.isCancelled else { return }
                join(index)
            }
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            scriptTask = nil
            finish(scripted: true)
        }
    }

    /// The first real touch takes over from the script.
    private func stopScript() {
        scriptTask?.cancel()
        scriptTask = nil
        guard !busy else { return }
        path = []
        finger = nil
    }
}

// MARK: - Pieces

private struct InputPatternDot: View {
    let joined: Bool
    let tint: Color
    let pulse: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint, lineWidth: 2)
                .frame(width: 38, height: 38)
                .keyframeAnimator(initialValue: InputPatternRipple(), trigger: pulse) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(0.5)
                        LinearKeyframe(1.7, duration: 0.45, timingCurve: .easeOut)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0.7)
                        LinearKeyframe(0, duration: 0.45, timingCurve: .easeOut)
                    }
                }
            Circle()
                .fill(tint.opacity(joined ? 0.18 : 0))
                .frame(width: 38, height: 38)
            Circle()
                .fill(joined ? tint : Color.primary.opacity(0.3))
                .frame(width: 14, height: 14)
                .scaleEffect(joined ? 1.3 : 1)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: pulse) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(1.45, duration: 0.09)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    }
                }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: joined)
        .animation(.easeOut(duration: 0.15), value: tint)
    }
}

private struct InputPatternRipple {
    var scale: CGFloat = 1.7
    var opacity: Double = 0
}

/// One joined segment. It appears bowed sideways and rings out to a straight line.
private struct InputPatternSegment: View {
    let from: CGPoint
    let to: CGPoint
    let tint: Color
    let width: CGFloat
    let amplitude: CGFloat
    let retracting: Bool
    let delay: Double
    @State private var bend: CGFloat

    init(from: CGPoint, to: CGPoint, tint: Color, width: CGFloat, amplitude: CGFloat, retracting: Bool, delay: Double) {
        self.from = from
        self.to = to
        self.tint = tint
        self.width = width
        self.amplitude = amplitude
        self.retracting = retracting
        self.delay = delay
        _bend = State(initialValue: amplitude)
    }

    var body: some View {
        InputPatternBow(from: from, to: to, bend: bend)
            .trim(from: 0, to: retracting ? 0 : 1)
            .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
            .opacity(retracting ? 0 : 1)
            .animation(.easeIn(duration: 0.14).delay(delay), value: retracting)
            .animation(.easeOut(duration: 0.15), value: tint)
            .onAppear {
                guard amplitude != 0 else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.16)) { bend = 0 }
            }
    }
}

private struct InputPatternBow: Shape {
    let from: CGPoint
    let to: CGPoint
    var bend: CGFloat

    var animatableData: CGFloat {
        get { bend }
        set { bend = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(hypot(dx, dy), 0.001)
        let middle = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        // A quad curve peaks at half its control offset, hence the factor 2.
        let control = CGPoint(x: middle.x - dy / length * bend * 2, y: middle.y + dx / length * bend * 2)
        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: control)
        return path
    }
}

/// The live strand from the last dot to the finger: tapered, and thinner the further it is pulled.
private struct InputPatternStrand: Shape {
    let from: CGPoint
    var to: CGPoint
    let width: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(to.x, to.y) }
        set { to = CGPoint(x: newValue.first, y: newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = hypot(dx, dy)
        guard length > 0.5 else { return Path() }
        let thin: CGFloat = 1 / (1 + length / 160)
        let near: CGFloat = width / 2 * (0.55 + 0.45 * thin)
        let far: CGFloat = width / 2 * max(thin, 0.3)
        let nx = -dy / length
        let ny = dx / length
        var path = Path()
        path.move(to: CGPoint(x: from.x + nx * near, y: from.y + ny * near))
        path.addLine(to: CGPoint(x: to.x + nx * far, y: to.y + ny * far))
        path.addLine(to: CGPoint(x: to.x - nx * far, y: to.y - ny * far))
        path.addLine(to: CGPoint(x: from.x - nx * near, y: from.y - ny * near))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: to.x - far, y: to.y - far, width: far * 2, height: far * 2))
        return path
    }
}

private struct InputPatternPolyline: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }
}
