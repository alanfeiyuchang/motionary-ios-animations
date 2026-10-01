import SwiftUI

extension Effect {
    static let textEchoTrail = Effect(
        id: "text.echo-trail",
        category: .text,
        interaction: .gesture,
        name: L("Echo Trail", "残影拖尾"),
        summary: L("A word glides around leaving a stack of fading, colour-shifting copies of where it has just been.", "一个词四处滑行，身后拖着一串逐渐淡去、渐次变色的残影，记录它刚刚经过的位置。"),
        prompt: L(
            "A heavy italic word travels along a smooth figure-eight about 190 pt wide and leans into its direction of travel. Behind it trail nine echoes: each is the same word drawn exactly where the head was a moment earlier, 45 ms further back per copy, so the trail stretches on fast stretches and bunches up in the turns. Echoes shrink 3% each, fade from about 60% toward nothing and shift colour from pink through violet to sky blue, while the head stays in the text colour on top. Touching the stage takes over: the head chases the finger on a spring (response 0.3 s, damping 0.7) and the echoes replay the finger's path; on release it glides back onto its orbit. The result feels like long-exposure photography of moving type.",
            "一个特粗的斜体词沿着约190pt宽的平滑8字轨迹滑行，并朝行进方向倾斜。它身后拖着九个残影：每个残影都是同一个词，画在词头片刻之前所在的位置，每往后一个再早45毫秒，所以在直道上拖尾被拉长，在弯道里又挤在一起。残影逐个缩小3%，透明度从约60%渐渐淡到没有，颜色从粉色经紫色过渡到天蓝，词头本身保持正文色并压在最上层。手指按上舞台后由你接管：词头以弹簧（响应0.3秒、阻尼0.7）追着指尖，残影重放指尖走过的路径；松手后它再滑回自己的轨道。整体像对运动中的文字做了一次长曝光。"
        ),
        implementation: L(
            "The head position is integrated by hand toward a target (the orbit or the finger) and every frame is appended to a short timestamped history; a Canvas draws the word at interpolated history samples k × gap seconds in the past, back to front, with per-echo scale, opacity and colour.",
            "词头的位置朝目标（轨道或指尖）手动积分，每帧追加到一段带时间戳的短历史里；Canvas 在历史中按 k × 间隔秒之前的位置插值取样，从后往前逐个画出这个词，并给每个残影不同的缩放、透明度和颜色。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.resolve", "DragGesture", "GraphicsContext.translateBy"],
        tags: ["echo", "trail", "ghost", "afterimage", "motion blur", "残影", "拖尾", "重影", "长曝光", "运动"],
        params: [
            .slider("count", L("Echoes", "残影数量"), 3...16, default: 9, step: 1, decimals: 0),
            .slider("gap", L("Echo delay", "残影间隔"), 0.02...0.12, default: 0.045, decimals: 3, unit: "s"),
            .slider("speed", L("Orbit speed", "轨道速度"), 0.3...2, default: 1, unit: "×"),
        ]
    ) { ctx in
        TextEchoTrailDemo(ctx: ctx)
    }
}

private struct EchoSample {
    var time: Double
    var point: CGPoint
    var lean: Double
}

private struct EchoSim {
    var last: Date?
    var now: Double = 0
    var orbit: Double = 0
    var position: CGPoint? = nil
    var velocity: CGPoint = .zero
    var history: [EchoSample] = []
}

private struct TextEchoTrailDemo: View {
    let ctx: DemoContext
    @State private var sim = TextFXBox(EchoSim())
    @State private var finger: CGPoint? = nil

    private let tints: [Color] = [Palette.pink, Palette.violet, Palette.indigo, Palette.sky]

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                Canvas { context, size in
                    draw(&context, size: size, date: timeline.date)
                }
            }
            .frame(height: 268)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if finger == nil { Haptics.tap(.soft) }
                        finger = value.location
                    }
                    .onEnded { _ in finger = nil }
            )
            DemoHint(text: L("Drag the word around", "拖着这个词到处走"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The figure-eight the word follows when nobody is touching it.
    private func orbit(_ clock: Double, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + 95 * CGFloat(sin(clock * 1.5)),
            y: size.height / 2 + 62 * CGFloat(sin(clock * 3.0 + 0.4))
        )
    }

    private func lean(forVelocity vx: Double) -> Double {
        min(max(vx * 0.0011, -0.38), 0.38)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, date: Date) {
        let count: Int = max(ctx.int("count"), 1)
        let gap: Double = ctx["gap"]
        let word: String = ctx.language == .zh ? "残影" : "ECHO"
        let font: Font = .system(size: ctx.language == .zh ? 70 : 64, weight: .black, design: .rounded).italic()

        var samples: [EchoSample] = []
        if ctx.isStill {
            for index in 0...count {
                let clock: Double = 2.35 - Double(index) * gap * ctx["speed"]
                let ahead = orbit(clock + 0.01, in: size)
                let here = orbit(clock, in: size)
                samples.append(EchoSample(time: 0, point: here, lean: lean(forVelocity: Double(ahead.x - here.x) * 100)))
            }
        } else {
            advance(size: size, date: date, keep: Double(count) * gap + 0.3)
            let state = sim.value
            for index in 0...count {
                samples.append(sample(state.history, at: state.now - Double(index) * gap))
            }
        }

        for index in stride(from: count, through: 0, by: -1) {
            let entry = samples[index]
            let isHead: Bool = index == 0
            let color: Color = isHead ? Color.primary : tints[min((index - 1) * tints.count / count, tints.count - 1)]
            let resolved = context.resolve(Text(verbatim: word).font(font).foregroundColor(color))
            let fade: Double = 1 - Double(index) / Double(count + 1)
            var layer = context
            layer.translateBy(x: entry.point.x, y: entry.point.y)
            layer.rotate(by: .radians(entry.lean))
            let scale: CGFloat = isHead ? 1 : max(1 - 0.03 * CGFloat(index), 0.3)
            layer.scaleBy(x: scale, y: scale)
            layer.opacity = isHead ? 1 : 0.62 * pow(fade, 1.4)
            layer.draw(resolved, at: .zero, anchor: .center)
        }
    }

    /// History lookup with linear interpolation.
    private func sample(_ history: [EchoSample], at time: Double) -> EchoSample {
        guard var newer = history.last else { return EchoSample(time: time, point: .zero, lean: 0) }
        for older in history.reversed() {
            if older.time <= time {
                let span: Double = newer.time - older.time
                let u: CGFloat = span > 0 ? CGFloat((time - older.time) / span) : 0
                return EchoSample(
                    time: time,
                    point: CGPoint(
                        x: older.point.x + (newer.point.x - older.point.x) * u,
                        y: older.point.y + (newer.point.y - older.point.y) * u
                    ),
                    lean: older.lean + (newer.lean - older.lean) * Double(u)
                )
            }
            newer = older
        }
        return newer
    }

    private func advance(size: CGSize, date: Date, keep: Double) {
        var state = sim.value
        defer { sim.value = state }
        guard let last = state.last, let position = state.position else {
            state.last = date
            let home = orbit(state.orbit, in: size)
            state.position = home
            state.history = [EchoSample(time: state.now, point: home, lean: 0)]
            return
        }
        let dt: Double = min(max(date.timeIntervalSince(last), 0), 1.0 / 20.0)
        guard dt > 0 else { return }
        state.last = date
        state.now += dt

        let held: Bool = finger != nil
        if !held { state.orbit += dt * ctx["speed"] }
        let target: CGPoint = finger ?? orbit(state.orbit, in: size)

        // Spring toward the target: tight on the finger, looser when gliding back onto the orbit.
        let response: Double = held ? 0.3 : 0.22
        let damping: Double = held ? 0.7 : 0.9
        let omega: Double = 2 * Double.pi / response
        var px: Double = Double(position.x)
        var py: Double = Double(position.y)
        var vx: Double = Double(state.velocity.x)
        var vy: Double = Double(state.velocity.y)
        let steps = 4
        let h: Double = dt / Double(steps)
        for _ in 0..<steps {
            vx += (-omega * omega * (px - Double(target.x)) - 2 * damping * omega * vx) * h
            vy += (-omega * omega * (py - Double(target.y)) - 2 * damping * omega * vy) * h
            px += vx * h
            py += vy * h
        }
        state.position = CGPoint(x: px, y: py)
        state.velocity = CGPoint(x: vx, y: vy)
        state.history.append(EchoSample(time: state.now, point: CGPoint(x: px, y: py), lean: lean(forVelocity: vx)))
        let cutoff: Double = state.now - keep
        if let firstKept = state.history.firstIndex(where: { $0.time >= cutoff }), firstKept > 1 {
            state.history.removeFirst(firstKept - 1)
        }
    }
}
