import SwiftUI

extension Effect {
    static let inputsClockPicker = Effect(
        id: "inputs.clock-picker",
        category: .inputs,
        interaction: .gesture,
        name: L("Clock Face Time Picker", "表盘时间选择器"),
        summary: L("Drag the hand round the dial: numbers swell near it, then the hand sweeps and the ring morphs from hours to minutes.", "拖动指针绕表盘转动：靠近的数字放大；选完小时，指针扫向分钟，数字环随之变形。"),
        prompt: L(
            "An analog time picker: a two-segment digital readout above a 224 pt dial with twelve numerals, a thin hand and a 40 pt indigo selector disc that turns the numeral under it white. Dragging on the dial swings the hand to the finger, pulled 65% of the way to the nearest hour; numerals within 60° of the hand swell up to 145%, and each new value ticks a selection haptic. On release the hand springs onto the number (response 0.3 s, damping 0.6); 350 ms later the picker advances to minutes: the hand sweeps the short way to the minute angle (response 0.6 s, damping 0.78) while the ring morphs. Hour numerals shrink to 60% and sink 22 pt inward as they fade, the 00–55 labels arrive from 22 pt outside, the change rippling outward from the hand, and minute dots fade in. Tapping a readout segment switches back.",
            "模拟表盘时间选择器：两段式数字读数下方是 224pt 表盘，十二个数字、细指针和 40pt 靛蓝选择圆片，圆片下的数字反白。拖动时指针摆向手指，并被最近的小时吸过去 65%；指针 60° 内的数字最多放大到 145%，每换一个值一次选择触觉。松手后指针以弹簧（响应 0.3 秒、阻尼 0.6）落到数字上；350 毫秒后进入分钟：指针沿近路扫到分钟角度（响应 0.6 秒、阻尼 0.78），数字环同时变形——小时数字缩到 60%、内沉 22pt 淡出，00–55 从外侧 22pt 到位，变化自指针向两侧扩散。"
        ),
        implementation: L(
            "The dial is an Animatable view over (hand angle, morph): every frame it recomputes each numeral's scale from its angular distance to the hand and a per-numeral morph delayed by that distance. The numerals are drawn twice, once in the primary colour and once in white masked by the selector disc; atan2 maps the touch to an angle and the angle is kept unbounded so springs take the short way round.",
            "表盘是以（指针角度、变形进度）为动画数据的 Animatable 视图：每帧根据各数字与指针的角距离重新计算缩放，并按该距离延迟各自的变形进度。数字绘制两遍，一遍用主色，一遍用白色并以选择圆片为遮罩；atan2 把触点映射为角度，角度保持无界，使弹簧总走近路。"
        ),
        apis: ["Animatable", "AnimatablePair", "atan2", "mask", "contentTransition(.numericText)"],
        tags: ["time picker", "clock", "dial", "hour", "minute", "时间选择", "表盘", "时钟", "小时", "分钟"],
        params: [
            .slider("magnify", L("Numeral magnify", "数字放大"), 0...0.8, default: 0.45),
            .slider("sweep", L("Sweep response", "扫动响应"), 0.3...1.0, default: 0.6, unit: "s"),
            .slider("stagger", L("Morph ripple", "变形扩散"), 0...1, default: 0.6),
            .toggle("auto", L("Auto-advance to minutes", "自动进入分钟"), default: true),
        ]
    ) { ctx in
        InputClockPickerDemo(ctx: ctx)
    }
}

private enum InputClockMode {
    case hour, minute
}

private struct InputClockPickerDemo: View {
    let ctx: DemoContext
    @State private var mode = InputClockMode.hour
    @State private var hour = 10
    @State private var minute = 30
    /// Hand angle in degrees, clockwise from 12. Unbounded, so animations take the short way round.
    @State private var angle: Double = 300
    @State private var morph: Double = 0
    @State private var dragging = false
    @State private var step = 0
    @State private var advanceTask: Task<Void, Never>?
    @GestureState private var touching = false

    private let dial: CGFloat = 224

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                readout
                face
            }
            .scaleEffect(ctx.isPreview ? 1.04 : 1)
            Spacer(minLength: 0)
            DemoHint(text: L("Drag the hand; tap the hour or minutes to switch", "拖动指针；点击小时或分钟切换"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.4) { previewTick() }
        .onDisappear { advanceTask?.cancel() }
    }

    // MARK: Readout

    private var readout: some View {
        HStack(spacing: 6) {
            segment(String(format: "%d", hour), active: mode == .hour, value: Double(hour)) { setMode(.hour) }
            Text(verbatim: ":")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .offset(y: -2)
            segment(String(format: "%02d", minute), active: mode == .minute, value: Double(minute)) { setMode(.minute) }
        }
    }

    private func segment(_ text: String, active: Bool, value: Double, action: @escaping () -> Void) -> some View {
        Button {
            advanceTask?.cancel()
            action()
        } label: {
            Text(verbatim: text)
                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(value: value))
                .foregroundStyle(active ? Palette.indigo : Color.primary.opacity(0.55))
                .frame(width: 78, height: 52)
                .background(
                    active ? Palette.indigo.opacity(0.16) : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
                .scaleEffect(active ? 1 : 0.94)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.25), value: value)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: active)
    }

    // MARK: Dial

    private var face: some View {
        InputClockFace(
            angle: angle,
            morph: morph,
            magnify: ctx["magnify"],
            spread: ctx["stagger"],
            lifted: dragging
        )
        .frame(width: dial, height: dial)
        .contentShape(Circle())
        .gesture(drag)
        .onChange(of: touching) { _, down in
            if !down { release() }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                let dx = Double(value.location.x - dial / 2)
                let dy = Double(value.location.y - dial / 2)
                guard hypot(dx, dy) > 14 else { return }
                advanceTask?.cancel()
                if !dragging {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { dragging = true }
                }
                var theta = atan2(dx, -dy) * 180 / .pi
                if theta < 0 { theta += 360 }
                point(at: theta, animation: .interactiveSpring(response: 0.14, dampingFraction: 0.85))
            }
            .onEnded { _ in release() }
    }

    /// Finger or script: read the value at `theta` and swing the hand there, pulled toward the nearest detent.
    private func point(at theta: Double, animation: Animation) {
        let unit: Double = mode == .hour ? 30 : 6
        let pull: Double = mode == .hour ? 0.65 : 0.5
        let snapped = (theta / unit).rounded() * unit
        let shown = theta + (snapped - theta) * pull
        if mode == .hour {
            let index = Int((snapped / 30).rounded()) % 12
            let value = index == 0 ? 12 : index
            if value != hour {
                hour = value
                Haptics.selection()
            }
        } else {
            let value = Int((snapped / 6).rounded()) % 60
            if value != minute {
                minute = value
                Haptics.selection()
            }
        }
        withAnimation(animation) { angle += shortest(from: angle, to: shown) }
    }

    private func shortest(from current: Double, to target: Double) -> Double {
        var delta = (target - current).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    private var restAngle: Double {
        mode == .hour ? Double(hour % 12) * 30 : Double(minute) * 6
    }

    /// Finger lifted, gesture cancelled, or the script letting go.
    private func release() {
        guard dragging else { return }
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            dragging = false
            angle += shortest(from: angle, to: restAngle)
        }
        guard mode == .hour, ctx.bool("auto") else { return }
        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            setMode(.minute)
        }
    }

    private func setMode(_ target: InputClockMode) {
        guard target != mode else { return }
        mode = target
        withAnimation(.spring(response: ctx["sweep"], dampingFraction: 0.78)) {
            angle += shortest(from: angle, to: restAngle)
            morph = target == .minute ? 1 : 0
        }
    }

    // MARK: Autoplay

    private func previewTick() {
        let phase = step % 3
        let round = step / 3
        step += 1
        switch phase {
        case 0:
            if mode != .hour { setMode(.hour) }
            scriptDrag(to: [210, 60, 330][round % 3])
        case 1:
            if mode != .minute { setMode(.minute) }
            scriptDrag(to: [270, 48, 162][round % 3])
        default:
            // The detail intro only plays the first drag; previews go back to hours for the next round.
            setMode(.hour)
        }
    }

    private func scriptDrag(to theta: Double) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { dragging = true }
        point(at: theta, animation: .smooth(duration: 0.6))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            guard !touching else { return }
            release()
        }
    }
}

/// Dial, numerals, hand. Animatable over (angle, morph) so magnification and the ring morph track every frame.
private struct InputClockFace: View, Animatable {
    var angle: Double
    var morph: Double
    let magnify: Double
    let spread: Double
    let lifted: Bool

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(angle, morph) }
        set {
            angle = newValue.first
            morph = newValue.second
        }
    }

    private let radius: CGFloat = 85
    private let disc: CGFloat = 40

    private func distance(to position: Double) -> Double {
        var delta = (angle - position).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        return delta > 180 ? 360 - delta : delta
    }

    var body: some View {
        let clamped = min(max(morph, 0), 1)
        // How far the hand is from a five-minute mark (0 on a numeral, 1 half-way between two).
        let offGrid: Double = abs((angle / 30).rounded() * 30 - angle) / 15
        let dot: Double = clamped * min(max((offGrid - 0.25) * 2.5, 0), 1)
        return ZStack {
            Circle().fill(Color.primary.opacity(0.06))
            Circle().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            ticks.opacity(clamped)
            numerals(color: .primary)
            hand
            numerals(color: .white)
                .mask { selector }
                .opacity(1 - dot)
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .offset(y: -radius)
                .rotationEffect(.degrees(angle))
                .opacity(dot)
            Circle()
                .fill(Palette.indigo)
                .frame(width: 8, height: 8)
        }
    }

    private var ticks: some View {
        ForEach(0..<60, id: \.self) { index in
            Circle()
                .fill(Color.primary.opacity(index % 5 == 0 ? 0.0 : 0.22))
                .frame(width: 2.5, height: 2.5)
                .offset(y: -radius)
                .rotationEffect(.degrees(Double(index) * 6))
        }
    }

    private var selector: some View {
        Circle()
            .frame(width: disc, height: disc)
            .scaleEffect(lifted ? 1.12 : 1)
            .offset(y: -radius)
            .rotationEffect(.degrees(angle))
    }

    private var hand: some View {
        ZStack {
            Capsule()
                .fill(Palette.indigo)
                .frame(width: 2.5, height: radius - disc / 2 + 2)
                .offset(y: -(radius - disc / 2 + 2) / 2)
                .rotationEffect(.degrees(angle))
            selector
                .foregroundStyle(LinearGradient(colors: [Palette.indigo, Palette.violet], startPoint: .top, endPoint: .bottom))
                .shadow(color: Palette.indigo.opacity(lifted ? 0.55 : 0.3), radius: lifted ? 12 : 6, y: 4)
        }
    }

    private func numerals(color: Color) -> some View {
        let clamped = min(max(morph, 0), 1)
        return ZStack {
            ForEach(0..<12, id: \.self) { index in
                let position = Double(index) * 30
                let apart = distance(to: position)
                let near: Double = max(0, 1 - apart / 60)
                let grow: CGFloat = 1 + CGFloat(magnify * near * near * (3 - 2 * near))
                // The morph starts at the hand and reaches the far side last.
                let local: Double = min(max(clamped * (1 + spread) - spread * apart / 180, 0), 1)
                let radians: Double = position * .pi / 180
                let hourRadius: CGFloat = radius - 22 * CGFloat(local)
                let minuteRadius: CGFloat = radius + 22 * CGFloat(1 - local)
                Text(verbatim: index == 0 ? "12" : "\(index)")
                    .fixedSize()
                    .scaleEffect(grow * CGFloat(1 - 0.4 * local))
                    .opacity(1 - local)
                    .offset(x: hourRadius * CGFloat(sin(radians)), y: -hourRadius * CGFloat(cos(radians)))
                Text(verbatim: String(format: "%02d", index * 5))
                    .fixedSize()
                    .scaleEffect(grow * CGFloat(0.6 + 0.4 * local))
                    .opacity(local)
                    .offset(x: minuteRadius * CGFloat(sin(radians)), y: -minuteRadius * CGFloat(cos(radians)))
            }
        }
        .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
        .foregroundStyle(color)
    }
}
