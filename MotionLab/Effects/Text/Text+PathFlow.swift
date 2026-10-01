import SwiftUI

extension Effect {
    static let textPathFlow = Effect(
        id: "text.path-flow",
        category: .text,
        interaction: .gesture,
        name: L("Text on a Flowing Path", "沿曲线流动的文字"),
        summary: L("A sentence streams along a living wave, every letter turning with the curve; drag to bend the path.", "一句话沿着起伏的波浪流过，每个字随曲线转向；拖动可以把路径拉弯。"),
        prompt: L(
            "A sentence in 24 pt heavy rounded type travels along a wavy path that never holds still. The path is the sum of two sine waves (34 pt amplitude) drifting in opposite directions, drawn as a soft translucent ribbon that fades out at both edges. Glyphs are spaced by arc length, sit centred on the ribbon and rotate to the local tangent, flowing leftward at 46 pt per second and fading over the last 50 pt of each edge. A smaller, fainter ribbon runs the other way behind it for depth. Touching the stage pulls the path toward the finger in a 90 pt wide bulge on a spring (response 0.35 s); letting go releases it with a loose wobble (damping 0.35).",
            "一句24pt粗圆体的话沿着一条从不静止的波浪路径行进。路径由两道相向漂移的正弦波叠加而成（振幅34pt），画成一条柔和的半透明丝带，两端渐隐。字形按弧长排布，居中骑在丝带上，并转到所在位置的切线方向，以每秒46pt的速度向左流动，在两侧最后50pt内淡出。后面还有一条更小、更淡的丝带反向流动，增加纵深。手指按住舞台时，路径会以弹簧（响应0.35秒）向指尖鼓出一个约90pt宽的弧；松手后带着松弛的晃动（阻尼0.35）弹回原位。文字像被水流托着走。"
        ),
        implementation: L(
            "Each frame a Canvas samples the curve into points with cumulative arc length, measures every resolved glyph, walks the samples to find each glyph's position and tangent, and draws it in a translated, rotated context; the finger bulge is a hand-stepped spring.",
            "Canvas 每帧把曲线采样为带累计弧长的点，测量每个已解析的字形，沿采样点找到字形的位置与切线，在平移并旋转后的上下文中绘制；手指造成的鼓包是一个手动步进的弹簧。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.resolve", "GraphicsContext.rotate(by:)", "DragGesture"],
        tags: ["text on path", "curve", "wave", "ribbon", "kinetic", "路径文字", "曲线", "波浪", "丝带", "动态排版"],
        params: [
            .slider("amplitude", L("Wave amplitude", "波浪振幅"), 0...60, default: 34, decimals: 0, unit: "pt"),
            .slider("speed", L("Text speed", "文字速度"), 0...140, default: 46, decimals: 0, unit: "pt/s"),
            .slider("drift", L("Wave drift", "波浪漂移"), 0...2, default: 0.6),
            .slider("size", L("Font size", "字号"), 16...34, default: 24, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        TextPathFlowDemo(ctx: ctx)
    }
}

private struct PathFlowSim {
    var last: Date?
    var scroll: Double = 0
    var wave: Double = 0
    var pull = TextFXSpring()
}

private struct PathFlowFrame {
    var scroll: Double
    var wave: Double
    var pull: Double
}

private struct PathFlowLane {
    var centre: CGFloat
    var amplitudeScale: CGFloat
    var fontScale: CGFloat
    var direction: Double
    var phase: Double
    var opacity: Double
    var bulge: CGFloat
}

private struct TextPathFlowDemo: View {
    let ctx: DemoContext
    @State private var sim = TextFXBox(PathFlowSim())
    @State private var finger = CGPoint(x: 170, y: 60)
    @State private var held = false
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    private var phrase: String {
        ctx.language == .zh ? "文字沿着曲线流动 ✦ 让排版活起来 ✦ " : "TYPE THAT FOLLOWS THE CURVE ✦ MOTION IN EVERY LETTER ✦ "
    }
    private var backPhrase: String {
        ctx.language == .zh ? "动效词典 · 文字与数字 · " : "MOTIONARY · TEXT & NUMBERS · "
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let frame = advance(to: timeline.date)
            Canvas { context, size in
                let back = PathFlowLane(centre: size.height * 0.30, amplitudeScale: 0.6, fontScale: 0.62, direction: -0.7, phase: 2.4, opacity: 0.42, bulge: 0.5)
                let front = PathFlowLane(centre: size.height * 0.56, amplitudeScale: 1, fontScale: 1, direction: 1, phase: 0, opacity: 1, bulge: 1)
                draw(&context, size: size, frame: frame, lane: back, text: backPhrase)
                draw(&context, size: size, frame: frame, lane: front, text: phrase)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Touch and drag to bend the path", "按住并拖动，把路径拉弯"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
        .gesture(drag)
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release() }
        }
        .autoplay(ctx.isPreview, every: 3.4, delay: 1.2) { simulate() }
        .onDisappear { script?.cancel() }
    }

    // MARK: Touch

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held {
                    script?.cancel()
                    Haptics.tap(.soft)
                }
                touch(at: value.location)
            }
            .onEnded { _ in
                if held { Haptics.tap(.light) }
                release()
            }
    }

    private func touch(at point: CGPoint) {
        held = true
        finger = point
    }

    private func release() {
        held = false
    }

    /// Preview / intro: a scripted finger pulls the path up or down, slides and lets go.
    private func simulate() {
        guard !held else { return }
        let upward = Bool.random()
        let x: CGFloat = CGFloat.random(in: 110...230)
        touch(at: CGPoint(x: x, y: upward ? 70 : 290))
        script?.cancel()
        script = Task { @MainActor in
            for step in 1...10 {
                try? await Task.sleep(for: .seconds(0.08))
                guard !Task.isCancelled else { return }
                touch(at: CGPoint(x: x + CGFloat(step) * 5, y: upward ? 70 : 290))
            }
            release()
        }
    }

    // MARK: Simulation

    private func advance(to date: Date) -> PathFlowFrame {
        if ctx.isStill { return PathFlowFrame(scroll: 40, wave: 0.9, pull: 0) }
        var state = sim.value
        if let last = state.last {
            let dt: Double = min(max(date.timeIntervalSince(last), 0), 0.1)
            if dt > 0 {
                state.scroll += ctx["speed"] * dt
                state.wave += ctx["drift"] * dt
                state.pull.step(to: held ? 1 : 0, dt: dt, response: held ? 0.35 : 0.5, damping: held ? 0.8 : 0.35)
                state.last = date
            }
        } else {
            state.last = date
        }
        sim.value = state
        return PathFlowFrame(scroll: state.scroll, wave: state.wave, pull: state.pull.value)
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, size: CGSize, frame: PathFlowFrame, lane: PathFlowLane, text: String) {
        let amplitude: CGFloat = ctx.cg("amplitude") * lane.amplitudeScale
        let fontSize: CGFloat = ctx.cg("size") * lane.fontScale
        let margin: CGFloat = 44
        let wavePhase: Double = frame.wave * 2 + lane.phase

        func height(_ x: CGFloat) -> CGFloat {
            let a: Double = sin(Double(x) / 300 * 2 * Double.pi + wavePhase)
            let b: Double = sin(Double(x) / 170 * 2 * Double.pi - wavePhase * 0.7 + 1.3)
            var y: CGFloat = lane.centre + amplitude * CGFloat(0.74 * a + 0.34 * b)
            let distance: Double = Double(x - finger.x) / 90
            let reach: CGFloat = (finger.y - lane.centre) * lane.bulge
            y += CGFloat(frame.pull * exp(-distance * distance)) * reach * 0.8
            return y
        }

        // Sample the curve once per frame: points and cumulative arc length.
        var points: [CGPoint] = []
        var lengths: [CGFloat] = []
        var total: CGFloat = 0
        var x: CGFloat = -margin
        while x <= size.width + margin {
            let point = CGPoint(x: x, y: height(x))
            if let previous = points.last {
                total += hypot(point.x - previous.x, point.y - previous.y)
            }
            points.append(point)
            lengths.append(total)
            x += 4
        }
        guard points.count > 2 else { return }

        // The ribbon the text rides on.
        var ribbon = Path()
        ribbon.addLines(points)
        let tint = Gradient(stops: [
            .init(color: Palette.mint.opacity(0), location: 0.04),
            .init(color: Palette.mint.opacity(0.20), location: 0.2),
            .init(color: Palette.sky.opacity(0.22), location: 0.5),
            .init(color: Palette.violet.opacity(0.20), location: 0.8),
            .init(color: Palette.violet.opacity(0), location: 0.96),
        ])
        var ribbonContext = context
        ribbonContext.opacity = lane.opacity
        ribbonContext.stroke(
            ribbon,
            with: .linearGradient(tint, startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
            style: StrokeStyle(lineWidth: fontSize * 1.75, lineCap: .round, lineJoin: .round)
        )

        // Resolve and measure every distinct glyph once.
        let glyphs: [Character] = Array(text)
        var resolved: [Character: (text: GraphicsContext.ResolvedText, width: CGFloat)] = [:]
        for glyph in glyphs where resolved[glyph] == nil {
            let isMark = glyph == "✦" || glyph == "·"
            let label = Text(verbatim: String(glyph))
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundColor(isMark ? Palette.coral : Color.primary)
            let item = context.resolve(label)
            let width: CGFloat = glyph == " " ? fontSize * 0.3 : item.measure(in: CGSize(width: 200, height: 200)).width
            resolved[glyph] = (item, width)
        }
        let tracking: CGFloat = fontSize * 0.04
        let phraseWidth: CGFloat = glyphs.reduce(0) { $0 + (resolved[$1]?.width ?? 0) + tracking }
        guard phraseWidth > 1 else { return }

        let travel: Double = frame.scroll * lane.direction
        var shift: CGFloat = CGFloat(travel.truncatingRemainder(dividingBy: Double(phraseWidth)))
        if shift < 0 { shift += phraseWidth }
        var cursor: CGFloat = -shift
        var segment = 1
        while cursor < total {
            for glyph in glyphs {
                guard let item = resolved[glyph] else { continue }
                let centre: CGFloat = cursor + item.width / 2
                cursor += item.width + tracking
                guard centre > 0, centre < total, glyph != " " else { continue }
                while segment < lengths.count - 1 && lengths[segment] < centre { segment += 1 }
                let a = points[segment - 1]
                let b = points[segment]
                let span: CGFloat = max(lengths[segment] - lengths[segment - 1], 0.001)
                let t: CGFloat = (centre - lengths[segment - 1]) / span
                let position = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                let angle: CGFloat = atan2(b.y - a.y, b.x - a.x)
                let fadeIn: Double = TextFXCurve.smoothstep(Double(position.x) / 50)
                let fadeOut: Double = TextFXCurve.smoothstep(Double(size.width - position.x) / 50)
                let alpha: Double = fadeIn * fadeOut * lane.opacity
                guard alpha > 0.01 else { continue }
                var glyphContext = context
                glyphContext.opacity = alpha
                glyphContext.translateBy(x: position.x, y: position.y)
                glyphContext.rotate(by: .radians(Double(angle)))
                glyphContext.draw(item.text, at: .zero, anchor: .center)
            }
        }
    }
}
