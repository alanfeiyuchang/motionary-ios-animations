import SwiftUI

extension Effect {
    static let gesturesRotateKnob = Effect(
        id: "gestures.rotate-knob",
        category: .gestures,
        interaction: .gesture,
        name: L("Detent Rotary Knob", "带档位的旋钮"),
        summary: L("A machined knob you turn with one finger around its rim or with a two-finger twist: it clicks through detents while a value arc fills.", "可用单指绕边缘拨动、也可双指拧转的金属旋钮：咔嗒越过一个个档位，数值弧随之填充。"),
        prompt: L(
            "A 150 pt brushed-metal knob with a knurled rim and a glowing indicator dot sits inside a 270° track with 13 ticks. Dragging a finger around it, or twisting with two fingers, turns it by the angle swept, not by distance. Twelve detents pull the rotation magnetically: the knob lingers in each notch and jumps between them (snap strength 0.7), with a selection haptic and the passed tick stretching to 1.6× for an instant. The metal's highlights stay fixed to the light while the knurling and dot rotate; a gradient arc from mint to pink fills up to the dot, glowing brighter with the value, and the number in the centre rolls. Past either end the knob rubber-bands up to 18°. On release it springs to the nearest detent (response 0.3 s, damping 0.55) with a small overshoot. Precise, mechanical, satisfying.",
            "150 pt的拉丝金属旋钮带滚花边缘和发光指示点，外围是270°的轨道与13个刻度。单指绕着它拖动或双指拧转，旋钮按扫过的角度转动。12个档位以磁吸方式牵引旋转：旋钮在每个卡口略作停留、在档位之间跳过（吸附强度0.7），触发选择触感，被越过的刻度拉长到1.6倍。金属高光固定于光源方向，滚花与指示点随之转动；薄荷绿到粉色的渐变弧填充到指示点处，数值越大辉光越亮，中央数字滚动。转过两端时以橡皮筋方式最多多转18°。松手后以弹簧（响应0.3秒、阻尼0.55）落到最近档位并轻微过冲。"
        ),
        implementation: L(
            "A DragGesture converts the finger's position to a polar angle around the knob's centre and accumulates the unwrapped delta; a simultaneous RotateGesture adds two-finger twist. The shown angle is the raw angle minus a sinusoidal detent term, so the mapping flattens at each notch. rotationEffect turns the knurling and indicator, a trimmed circle with an AngularGradient draws the value arc, and release animates the raw angle to the nearest detent with a spring.",
            "DragGesture 把手指位置换算成绕旋钮中心的极角并累加展开后的角度差；同时识别的 RotateGesture 叠加双指拧转。显示角度等于原始角度减去一个正弦档位项，于是映射在每个卡口处变平。rotationEffect 转动滚花与指示点，带 AngularGradient 的裁剪圆环绘制数值弧，松手时用弹簧把原始角度送到最近档位。"
        ),
        apis: ["DragGesture", "RotateGesture", "rotationEffect", "Circle().trim", "AngularGradient", "contentTransition(.numericText)"],
        tags: ["knob", "dial", "rotate", "detent", "twist", "volume", "旋钮", "拨盘", "旋转", "档位", "拧转", "音量"],
        params: [
            .slider("detents", L("Detents", "档位数"), 6...24, default: 12, step: 1, decimals: 0),
            .slider("snap", L("Snap strength", "吸附强度"), 0...1, default: 0.7),
            .slider("response", L("Spring response", "弹簧响应"), 0.15...0.8, default: 0.3, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.3...1.0, default: 0.55),
        ]
    ) { ctx in
        RotateKnobDemo(ctx: ctx)
    }
}

private enum Knob {
    static let stage: CGFloat = 252
    static let size: CGFloat = 150
    static let sweep: Double = 270
    static let trackRadius: CGFloat = 104
}

private struct RotateKnobDemo: View {
    let ctx: DemoContext
    /// Raw rotation in degrees from the minimum, before the detent pull. 0…270.
    @State private var raw: Double
    @State private var lastTouchAngle: Double?
    @State private var lastTwist: Double = 0
    @State private var twisting = false
    @State private var held = false
    @State private var notch: Int
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false
    @GestureState private var twistingNow = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let detents: Int = max(ctx.int("detents"), 1)
        let start: Int = Int((Double(detents) * 0.42).rounded())
        _raw = State(initialValue: Double(start) * Knob.sweep / Double(detents))
        _notch = State(initialValue: start)
    }

    private var detents: Int { max(ctx.int("detents"), 1) }
    private var spacing: Double { Knob.sweep / Double(detents) }

    /// The angle the knob shows: raw, rubber-banded past the ends and pulled into the detents.
    private func shown(_ raw: Double) -> Double {
        if raw < 0 { return -Double(rubberBand(CGFloat(-raw), limit: 18)) }
        if raw > Knob.sweep { return Knob.sweep + Double(rubberBand(CGFloat(raw - Knob.sweep), limit: 18)) }
        let pull: Double = ctx["snap"] * spacing / (2 * .pi) * sin(2 * .pi * raw / spacing)
        return raw - pull
    }

    var body: some View {
        let angle: Double = shown(raw)
        let fraction: Double = (angle / Knob.sweep).clamped(to: 0...1)
        VStack(spacing: 10) {
            ZStack {
                KnobTrack(fraction: fraction, detents: detents, notch: notch)
                KnobBody(angle: angle - 135, fraction: fraction, held: held)
                Text(verbatim: "\(notch)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: Double(notch)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: notch)
                    .foregroundStyle(.primary.opacity(0.85))
                    .allowsHitTesting(false)
                KnobEndIcons()
            }
            .frame(width: Knob.stage, height: Knob.stage)
            .contentShape(Circle())
            .gesture(drag)
            .simultaneousGesture(twist)

            DemoHint(text: L("Drag around the knob, or twist with two fingers", "绕着旋钮拖动，或双指拧转"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9, delay: 0.5) { autoTurn() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing && !twistingNow { release() }
        }
        .onChange(of: twistingNow) { _, isTwisting in
            if !isTwisting {
                twisting = false
                if !pressing { release() }
            }
        }
        .onChange(of: ctx.int("detents")) {
            raw = (raw / spacing).rounded() * spacing
            notch = Int((raw / spacing).rounded())
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held { script?.cancel() }
                beginHold()
                guard !twisting else {
                    lastTouchAngle = nil
                    return
                }
                let dx: Double = Double(value.location.x - Knob.stage / 2)
                let dy: Double = Double(value.location.y - Knob.stage / 2)
                // Too close to the centre the angle is noise.
                guard dx * dx + dy * dy > 18 * 18 else {
                    lastTouchAngle = nil
                    return
                }
                let touch: Double = atan2(dy, dx) * 180 / .pi
                if let last = lastTouchAngle {
                    var delta: Double = touch - last
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    turn(to: raw + delta)
                }
                lastTouchAngle = touch
            }
            .onEnded { _ in
                lastTouchAngle = nil
            }
    }

    private var twist: some Gesture {
        RotateGesture(minimumAngleDelta: .degrees(2))
            .updating($twistingNow) { _, state, _ in state = true }
            .onChanged { value in
                if !held { script?.cancel() }
                beginHold()
                if !twisting {
                    twisting = true
                    lastTwist = value.rotation.degrees
                }
                turn(to: raw + value.rotation.degrees - lastTwist)
                lastTwist = value.rotation.degrees
            }
    }

    private func beginHold() {
        guard !held else { return }
        withAnimation(.easeOut(duration: 0.15)) { held = true }
    }

    /// Finger and ghost finger both land here.
    private func turn(to newRaw: Double) {
        raw = newRaw.clamped(to: -90...(Knob.sweep + 90))
        let nearest: Int = Int((shown(raw) / spacing).rounded()).clamped(to: 0...detents)
        if nearest != notch {
            notch = nearest
            if !ctx.isPreview { Haptics.selection() }
        }
    }

    private func release() {
        guard held else { return }
        lastTouchAngle = nil
        let target: Double = Double(Int((raw / spacing).rounded()).clamped(to: 0...detents)) * spacing
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            raw = target
            held = false
        }
        notch = Int((target / spacing).rounded())
        if !ctx.isPreview { Haptics.tap(.soft) }
    }

    /// A scripted finger sweeps the knob to another detent and lets go.
    private func autoTurn() {
        guard !pressing, !twistingNow else { return }
        autoStep += 1
        let stops: [Double] = [0.83, 0.25, 0.58, 1.0, 0.08, 0.5]
        let goal: Double = (stops[autoStep % stops.count] * Double(detents)).rounded() * spacing
        // Stop a little short or long, so the release visibly snaps.
        let end: Double = goal + spacing * (autoStep % 2 == 0 ? 0.32 : -0.32)
        let start: Double = raw
        script?.cancel()
        script = Task { @MainActor in
            beginHold()
            let finished = await GhostFinger.drag(from: CGPoint(x: start, y: 0), to: CGPoint(x: end, y: 0), duration: 0.75) { point in
                turn(to: Double(point.x))
            }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.1))
            guard !Task.isCancelled else { return }
            release()
        }
    }
}

// MARK: - Pieces

private struct KnobTrack: View {
    let fraction: Double
    let detents: Int
    let notch: Int

    private static let colors: [Color] = [Palette.mint, Palette.sky, Palette.indigo, Palette.violet, Palette.pink]

    var body: some View {
        let d: CGFloat = Knob.trackRadius * 2
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.primary.opacity(0.09), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: d, height: d)
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(
                    AngularGradient(colors: KnobTrack.colors, center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: d, height: d)
                .rotationEffect(.degrees(135))
                .shadow(color: Palette.violet.opacity(0.15 + 0.45 * fraction), radius: 4 + 8 * fraction)
            ForEach(0...detents, id: \.self) { index in
                let lit: Bool = index <= notch
                Capsule()
                    .fill(lit ? Color.primary.opacity(0.75) : Color.primary.opacity(0.2))
                    .frame(width: 2.5, height: 7)
                    .scaleEffect(y: index == notch ? 1.6 : 1, anchor: .bottom)
                    .offset(y: -(Knob.trackRadius + 14))
                    .rotationEffect(.degrees(-135 + Knob.sweep * Double(index) / Double(detents)))
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: notch)
            }
        }
    }
}

private struct KnobBody: View {
    /// Rotation of the indicator in degrees; 0 points up.
    let angle: Double
    let fraction: Double
    let held: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark: Bool = colorScheme == .dark
        let hi: Double = dark ? 0.42 : 1.0
        let lo: Double = dark ? 0.15 : 0.7
        let metal: [Color] = [
            Color(white: hi), Color(white: lo), Color(white: hi * 0.92), Color(white: lo * 0.9),
            Color(white: hi), Color(white: lo), Color(white: hi * 0.92), Color(white: lo * 0.9), Color(white: hi),
        ]
        ZStack {
            // Knurled rim: turns with the knob.
            Circle()
                .fill(AngularGradient(colors: metal, center: .center))
                .frame(width: Knob.size, height: Knob.size)
            KnobKnurl(dark: dark)
                .frame(width: Knob.size, height: Knob.size)
                .rotationEffect(.degrees(angle))
            // Face: its highlights stay with the light.
            Circle()
                .fill(AngularGradient(colors: metal, center: .center, angle: .degrees(24)))
                .frame(width: Knob.size - 28, height: Knob.size - 28)
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(dark ? 0.35 : 0.95), .black.opacity(dark ? 0.5 : 0.18)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.5
                    )
                )
                .overlay(Circle().fill(dark ? Color.black.opacity(0.25) : Color.white.opacity(0.35)))
            // Indicator dot.
            Circle()
                .fill(Palette.mint)
                .frame(width: 9, height: 9)
                .shadow(color: Palette.mint.opacity(0.9), radius: 3 + 5 * fraction)
                .offset(y: -(Knob.size / 2 - 26))
                .rotationEffect(.degrees(angle))
        }
        .scaleEffect(held ? 1.03 : 1)
        .shadow(color: .black.opacity(dark ? 0.5 : 0.22), radius: held ? 20 : 14, y: held ? 14 : 9)
    }
}

/// 60 fine grooves around the rim.
private struct KnobKnurl: View {
    let dark: Bool

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer: CGFloat = size.width / 2 - 1
            let inner: CGFloat = outer - 11
            var grooves = Path()
            for index in 0..<60 {
                let a: Double = Double(index) / 60 * 2 * .pi
                let c: CGFloat = CGFloat(cos(a))
                let s: CGFloat = CGFloat(sin(a))
                grooves.move(to: CGPoint(x: centre.x + c * inner, y: centre.y + s * inner))
                grooves.addLine(to: CGPoint(x: centre.x + c * outer, y: centre.y + s * outer))
            }
            context.stroke(grooves, with: .color(.black.opacity(dark ? 0.55 : 0.22)), lineWidth: 1.6)
        }
    }
}

private struct KnobEndIcons: View {
    var body: some View {
        HStack {
            Image(systemName: "speaker.fill")
            Spacer()
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 150)
        .offset(y: Knob.trackRadius + 4)
        .allowsHitTesting(false)
    }
}
