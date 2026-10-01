import SwiftUI

extension Effect {
    static let showcaseFocusTimer = Effect(
        id: "showcase.focus-timer",
        category: .showcase,
        interaction: .gesture,
        name: L("Focus Timer Dial", "专注计时拨盘"),
        summary: L(
            "Drag around the ring to set the minutes with detent ticks, then start: the ring drains under a sweeping light and a breathing glow.",
            "绕着圆环拖动设定分钟，带刻度段落感；开始后圆环在扫光与呼吸光晕中慢慢流尽。"
        ),
        prompt: L(
            "A dark focus-timer widget: a 144 pt ring (13 pt stroke, orange angular gradient) inside 60 tick marks, a large mm:ss readout in the centre and a pill button below. Dragging around the ring moves a white knob at the arc's end; the value snaps to whole minutes on an interactive spring (response 0.2 s, damping 0.8) with a selection tick per minute and a firmer tap every 5, ticks up to the knob lighting orange. Tapping Start shrinks the knob away and the arc drains anticlockwise in real time while a white highlight sweeps round the lit ticks every 1.5 s and a blurred orange halo breathes behind the ring on a 4 s sine. Pausing freezes everything in place. At zero the ring pops to 106%, flashes, and refills to the chosen minutes on a spring (response 0.7 s, damping 0.7). Calm, precise, ritual-like.",
            "深色专注计时组件：60 根刻度环绕 144pt 圆环（描边 13pt，橙色角向渐变），中央是大号 mm:ss 读数，下方是胶囊按钮。绕环拖动，弧线末端的白色旋钮跟随移动；数值以交互弹簧（响应 0.2 秒、阻尼 0.8）吸附到整分钟，每分钟一次选择触感、每 5 分钟一次重击，旋钮之前的刻度亮为橙色。点击“开始”，旋钮缩小消失，圆弧实时逆时针流尽；白色高光每 1.5 秒绕亮起的刻度扫一圈，环后的橙色柔光按 4 秒正弦呼吸。暂停即冻结。归零时圆环弹到 106% 并闪亮，再以弹簧（响应 0.7 秒、阻尼 0.7）回填。"
        ),
        implementation: L(
            "A DragGesture converts the touch to a clockwise angle, accumulates wrapped deltas into minutes and snaps them. While running, a TimelineView derives the remaining fraction from accumulated time and feeds Circle().trim, the knob's rotationEffect and a Canvas that draws the ticks and the sweeping highlight; a task(id:) fires the completion, and the refill is the same trim animated by a spring.",
            "DragGesture 把触点换算为顺时针角度，将去环绕后的增量累加为分钟并吸附。运行时由 TimelineView 根据累计时间算出剩余比例，驱动 Circle().trim、旋钮的 rotationEffect，以及绘制刻度与扫光的 Canvas；task(id:) 负责触发完成，回填则是同一个 trim 配弹簧动画。"
        ),
        apis: ["DragGesture", "TimelineView(.animation)", "Circle().trim", "Canvas", "AngularGradient", "task(id:)"],
        tags: ["timer", "focus", "pomodoro", "dial", "ring", "计时器", "专注", "番茄钟", "拨盘", "圆环"],
        params: [
            .slider("session", L("Demo session length", "演示时长"), 3...20, default: 6, decimals: 0, unit: "s"),
            .choice("detent", L("Detent", "吸附步长"), [L("1 min", "1 分钟"), L("5 min", "5 分钟")], default: 0),
            .toggle("glow", L("Breathing glow", "呼吸光晕"), default: true),
        ]
    ) { ctx in
        FocusTimerDemo(ctx: ctx)
    }
}

private struct FocusTimerDemo: View {
    let ctx: DemoContext
    @State private var minutes: Double = 25
    /// Un-snapped value the finger is dialling.
    @State private var rawMinutes: Double = 25
    @State private var running = false
    @State private var elapsed: Double = 0
    @State private var startDate = Date()
    @State private var dragging = false
    @State private var lastAngle: Double = 0
    @State private var completions = 0
    @State private var userStarted = false
    @State private var scripting = false
    @State private var script: Task<Void, Never>?
    @State private var scriptFlip = false
    @GestureState private var finger = false

    private let side: CGFloat = 202
    private let radius: CGFloat = 72

    private var zh: Bool { ctx.language == .zh }
    private var session: Double { max(ctx["session"], 1) }
    private var paused: Bool { !running && elapsed > 0 }

    private func drained(at date: Date) -> Double {
        let live = running ? max(0, date.timeIntervalSince(startDate)) : 0
        return min(1, (elapsed + live) / session)
    }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card
                Spacer(minLength: 0)
                DemoHint(text: L("Drag around the ring, then start", "绕圆环拖动设定时间，再点开始"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: "\(running)-\(session)") {
            guard running else { return }
            let left = session - elapsed - Date().timeIntervalSince(startDate)
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            guard !Task.isCancelled, running else { return }
            finish()
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: session + 3.6, delay: 0.7) { runScript() }
    }

    private var card: some View {
        VStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !running || ctx.isStill)) { timeline in
                dial(date: timeline.date)
            }
            button
        }
        .padding(16)
        .frame(width: 280)
        .signatureCard()
    }

    // MARK: Dial

    private func dial(date: Date) -> some View {
        let q = drained(at: date)
        let left = minutes * (1 - q)
        let fraction = left / 60
        let t = date.timeIntervalSinceReferenceDate
        return ZStack {
            if ctx.bool("glow") {
                Circle()
                    .fill(Signature.accent)
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                    .scaleEffect(running ? 0.96 + 0.07 * sin(t * .pi / 2) : 0.9)
                    .opacity(running ? 0.24 + 0.12 * sin(t * .pi / 2) : 0.1)
            }
            FocusTicks(fraction: fraction, sweep: running ? (t / 1.5).truncatingRemainder(dividingBy: 1) : nil)
                .frame(width: side, height: side)
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 13)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: max(fraction, 0.0001))
                .stroke(
                    AngularGradient(colors: [Signature.accentHot, Signature.accent, Signature.accentSoft], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(fraction, 0.05))),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
                .shadow(color: Signature.accent.opacity(0.5), radius: 8)
            // Knob at the arc's end.
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                .overlay(Circle().fill(Signature.accent).frame(width: 7, height: 7))
                .scaleEffect(running || paused ? 0.01 : (dragging ? 1.25 : 1))
                .offset(y: -radius)
                .rotationEffect(.degrees(fraction * 360))
            readout(left: left)
        }
        .frame(width: side, height: side)
        .keyframeAnimator(initialValue: FocusPop(), trigger: completions) { content, pop in
            content
                .scaleEffect(pop.scale)
                .brightness(pop.flash)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.06, duration: 0.14)
                SpringKeyframe(1.0, duration: 0.5, spring: .init(response: 0.35, dampingRatio: 0.5))
            }
            KeyframeTrack(\.flash) {
                LinearKeyframe(0.35, duration: 0.1)
                CubicKeyframe(0, duration: 0.5)
            }
        }
        .contentShape(Circle())
        .gesture(dialGesture)
        .onChange(of: finger) { _, down in
            if !down && !scripting { endDial() }
        }
    }

    private func readout(left: Double) -> some View {
        let seconds = Int((left * 60).rounded(.up))
        return VStack(spacing: 2) {
            Text(verbatim: String(format: "%02d:%02d", seconds / 60, seconds % 60))
                .font(Signature.number(36))
                .foregroundStyle(Color.white)
                .contentTransition(.numericText(value: Double(seconds)))
                .animation(running ? nil : .snappy(duration: 0.2), value: seconds)
            Text(verbatim: stateLabel)
                .signatureEyebrow()
                .contentTransition(.opacity)
        }
        .allowsHitTesting(false)
    }

    private var stateLabel: String {
        if running { return zh ? "深度专注中" : "Deep focus" }
        if paused { return zh ? "已暂停" : "Paused" }
        return zh ? "分钟 · 拖动设定" : "Minutes · drag to set"
    }

    private var button: some View {
        Button(action: userToggle) {
            HStack(spacing: 7) {
                Image(systemName: running ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(verbatim: running ? (zh ? "暂停" : "Pause") : (paused ? (zh ? "继续" : "Resume") : (zh ? "开始专注" : "Start focus")))
                    .contentTransition(.opacity)
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(running ? Color.white : Signature.ink)
            .frame(width: 168, height: 44)
            .background {
                Capsule().fill(running ? AnyShapeStyle(Color.white.opacity(0.1)) : AnyShapeStyle(Signature.accentGradient))
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(running ? 0.16 : 0), lineWidth: 1))
            .shadow(color: Signature.accent.opacity(running ? 0 : 0.45), radius: 10, y: 4)
        }
        .buttonStyle(SportPressStyle(scale: 0.95, dim: 0.05))
    }

    // MARK: Setting the time

    private var dialGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($finger) { _, state, _ in state = true }
            .onChanged { value in
                guard !running, !paused else { return }
                let dx = Double(value.location.x - side / 2)
                let dy = Double(value.location.y - side / 2)
                let distance = (dx * dx + dy * dy).squareRoot()
                // Clockwise from 12 o'clock, 0…2π.
                var angle = atan2(dx, -dy)
                if angle < 0 { angle += 2 * .pi }
                if !dragging {
                    guard distance > 40 else { return }
                    script?.cancel()
                    scripting = false
                    beginDial(at: angle)
                } else {
                    turnDial(to: angle)
                }
            }
            .onEnded { _ in endDial() }
    }

    private func beginDial(at angle: Double) {
        lastAngle = angle
        rawMinutes = minutes
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragging = true }
        // A touch away from the knob brings the knob to the finger.
        let knob = minutes / 60 * 2 * .pi
        var gap = angle - knob
        if gap > .pi { gap -= 2 * .pi }
        if gap < -.pi { gap += 2 * .pi }
        if abs(gap) > 0.3 { dial(by: gap) }
    }

    private func turnDial(to angle: Double) {
        var delta = angle - lastAngle
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        lastAngle = angle
        dial(by: delta)
    }

    /// Shared by the finger and the scripted drag: adds an angle, snaps, ticks.
    private func dial(by delta: Double) {
        let step: Double = ctx.int("detent") == 1 ? 5 : 1
        rawMinutes = (rawMinutes + delta / (2 * .pi) * 60).clamped(to: step...60)
        let snapped = ((rawMinutes / step).rounded() * step).clamped(to: step...60)
        guard snapped != minutes else { return }
        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) { minutes = snapped }
        guard !ctx.isPreview, !scripting else { return }
        if Int(snapped) % 5 == 0 { Haptics.tap(.rigid) } else { Haptics.selection() }
    }

    private func endDial() {
        guard dragging else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragging = false }
    }

    // MARK: Running

    private func userToggle() {
        script?.cancel()
        scripting = false
        Haptics.tap(.medium)
        userStarted = true
        toggle()
    }

    private func toggle() {
        if running {
            elapsed += Date().timeIntervalSince(startDate)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { running = false }
        } else {
            startDate = Date()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { running = true }
        }
    }

    private func finish() {
        completions += 1
        if userStarted && !ctx.isPreview { Haptics.success() }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            running = false
            elapsed = 0
        }
    }

    private func runScript() {
        guard !running, !paused, !dragging else { return }
        script?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            userStarted = false
            rawMinutes = minutes
            let target: Double = scriptFlip ? 25 : 40
            scriptFlip.toggle()
            let total = (target - minutes) / 60 * 2 * .pi
            var done = 0.0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragging = true }
            let finished = await studioScript(0.9) { t in
                let goal = total * studioEase(t)
                dial(by: goal - done)
                done = goal
            }
            endDial()
            guard finished, await studioPause(0.35), !running else { return }
            toggle()
        }
    }
}

private struct FocusPop {
    var scale: Double = 1
    var flash: Double = 0
}

/// 60 ticks: lit up to the remaining fraction, with an optional highlight sweeping round the lit part.
private struct FocusTicks: View {
    let fraction: Double
    let sweep: Double?

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.width / 2 - 3
            for index in 0..<60 {
                let position = Double(index) / 60
                let major = index % 5 == 0
                let lit = position < fraction - 0.0001
                let angle = position * 2 * .pi - .pi / 2
                let inner = outer - (major ? 9 : 5)
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner, y: center.y + CGFloat(sin(angle)) * inner))
                tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer, y: center.y + CGFloat(sin(angle)) * outer))
                var color = lit ? Signature.accent.opacity(major ? 1 : 0.75) : Color.white.opacity(major ? 0.26 : 0.13)
                if let sweep, lit {
                    // Distance behind the sweeping head, in turns.
                    var behind = sweep - position
                    if behind < 0 { behind += 1 }
                    if behind < 0.12 {
                        color = Color.white.opacity(1 - behind / 0.12 * 0.75)
                    }
                }
                context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: major ? 2 : 1.4, lineCap: .round))
            }
        }
    }
}
