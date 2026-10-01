import SwiftUI

extension Effect {
    static let inputsPasteCode = Effect(
        id: "inputs.paste-code",
        category: .inputs,
        interaction: .tap,
        name: L("Paste Code Cascade", "验证码粘贴飞入"),
        summary: L("Tap the keyboard's code suggestion: six digits fly out of it into their boxes in a cascade, then the row verifies with a green wave.", "点一下键盘上的验证码建议：六位数字依次飞出、落进各自的格子，随后整行以绿色波浪完成验证。"),
        prompt: L(
            "Six empty 38 × 48 pt code boxes sit above a keyboard whose suggestion bar offers the code from a message. Tapping the suggestion launches its digits out of the chip one by one, 60 ms apart: each travels to its box on a spring (response 0.5 s, damping 0.74), lifted along an arc 26 pt above the straight line and scaling from the chip's 15 pt text up to 26 pt. On landing each box pops to 112% and its border tints indigo, with a light haptic tick. 280 ms after the last digit lands the row verifies: boxes and digits hop 9 pt in a left-to-right wave, 50 ms per box, turning green as they rise, and a check with the word Verified blurs in below with a success haptic. The chip then offers Clear, which drops the digits out and brings the suggestion back.",
            "六个 38 × 48pt 的空验证码格子，下方键盘的建议栏里是短信里的验证码。点击后，数字一个接一个从胶囊里飞出，间隔 60 毫秒：每个数字以弹簧（响应 0.5 秒、阻尼 0.74）飞向自己的格子，沿高出直线 26pt 的弧线，字号从胶囊里的 15pt 放大到 26pt。落下时对应格子弹到 112%，边框染成靛蓝，伴随轻触觉。最后一位落定 280 毫秒后整行通过验证：格子与数字自左向右依次跳起 9pt，每格相隔 50 毫秒并变绿；下方「验证成功」连同勾号模糊淡入，伴随成功触觉。此后胶囊变为「清除」，点击即复位。"
        ),
        implementation: L(
            "Chip and boxes are laid out on fixed coordinates, so each digit is one view with an animatable flight modifier: progress 0→1 interpolates position and scale and adds a sine arc. The cascade is the same spring with a per-digit delay; the box pop and the verify wave are keyframe animators triggered by counters.",
            "胶囊与格子都按固定坐标排布，每个数字是同一个视图加一个可动画的飞行修饰器：进度 0→1 插值位置与缩放，并叠加一段正弦弧线。逐个飞出靠同一个弹簧加逐位延迟；格子的弹跳与验证波浪是由计数器触发的关键帧动画。"
        ),
        apis: ["Animatable", "ViewModifier", "keyframeAnimator", "spring(response:dampingFraction:)", "transition(.blurReplace)"],
        tags: ["otp", "code", "paste", "autofill", "verify", "cascade", "验证码", "粘贴", "自动填充", "飞入", "验证"],
        params: [
            .slider("stagger", L("Digit stagger", "逐位间隔"), 0.02...0.15, default: 0.06, unit: "s"),
            .slider("lift", L("Arc height", "弧线高度"), 0...60, default: 26, decimals: 0, unit: "pt"),
            .slider("response", L("Flight response", "飞行响应"), 0.3...0.8, default: 0.5, unit: "s"),
        ]
    ) { ctx in
        InputPasteCodeDemo(ctx: ctx)
    }
}

private enum InputCodeLayout {
    static let size = CGSize(width: 300, height: 262)
    static let digits: [String] = ["3", "8", "4", "9", "2", "1"]
    static let boxY: CGFloat = 72
    static let chipY: CGFloat = 186
    static let chipWidth: CGFloat = 166

    static func box(_ index: Int) -> CGPoint {
        CGPoint(x: 11 + 19 + CGFloat(index) * 46 + (index >= 3 ? 10 : 0), y: boxY)
    }

    /// Centre of a digit while it sits inside the suggestion chip.
    static func chip(_ index: Int) -> CGPoint {
        let digitsWidth: CGFloat = 6 * 11 + 5
        let start = size.width / 2 + chipWidth / 2 - 14 - digitsWidth
        return CGPoint(x: start + 5.5 + CGFloat(index) * 11 + (index >= 3 ? 5 : 0), y: chipY)
    }
}

private struct InputPasteCodeDemo: View {
    private enum Phase { case empty, filling, verified }

    let ctx: DemoContext
    @State private var phase: Phase
    @State private var flight: [CGFloat]
    @State private var landed: [Bool]
    @State private var pops: [Int] = Array(repeating: 0, count: 6)
    @State private var gone = false
    @State private var clearing = false
    @State private var wave = 0
    @State private var chipTaps = 0
    @State private var task: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        let done = ctx.isStill
        _phase = State(initialValue: done ? .verified : .empty)
        _flight = State(initialValue: Array(repeating: done ? 1 : 0, count: 6))
        _landed = State(initialValue: Array(repeating: done, count: 6))
    }

    private var verified: Bool { phase == .verified }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                header
                ForEach(0..<6, id: \.self) { index in
                    InputCodeBox(landed: landed[index], verified: verified, pop: pops[index])
                        .modifier(InputCodeHop(index: index, wave: wave))
                        .position(InputCodeLayout.box(index))
                }
                status
                keyboard
                ForEach(0..<6, id: \.self) { index in
                    digit(index)
                }
            }
            .frame(width: InputCodeLayout.size.width, height: InputCodeLayout.size.height)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap the suggestion above the keys", "点击键盘上方的验证码建议"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.1, delay: 0.5) { chipTapped() }
        .onDisappear { task?.cancel() }
    }

    // MARK: Pieces

    private var header: some View {
        Text(L("Enter the 6-digit code", "输入 6 位验证码"), ctx.language)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .position(x: InputCodeLayout.size.width / 2, y: 20)
    }

    private var status: some View {
        HStack(spacing: 6) {
            Image(systemName: verified ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(verified ? Palette.green : Color.secondary)
            Text(verified ? L("Verified", "验证成功") : L("Sent to your phone", "已发送到你的手机"), ctx.language)
                .foregroundStyle(verified ? Palette.green : Color.secondary)
        }
        .font(.footnote.weight(.semibold))
        .id(verified)
        .transition(.blurReplace)
        .animation(.smooth(duration: 0.35), value: verified)
        .position(x: InputCodeLayout.size.width / 2, y: 122)
    }

    private func digit(_ index: Int) -> some View {
        Text(verbatim: InputCodeLayout.digits[index])
            .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(verified ? Palette.green : Color.primary)
            .animation(.easeOut(duration: 0.2).delay(Double(index) * 0.05), value: verified)
            .modifier(InputCodeHop(index: index, wave: wave))
            .modifier(
                InputCodeFlight(
                    progress: flight[index],
                    from: InputCodeLayout.chip(index),
                    to: InputCodeLayout.box(index),
                    lift: ctx.cg("lift")
                )
            )
            .opacity(phase == .empty || gone ? 0 : 1)
            .offset(y: gone ? 16 : 0)
            .blur(radius: gone ? 4 : 0)
            .allowsHitTesting(false)
    }

    private var keyboard: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 26, bottomTrailingRadius: 26, topTrailingRadius: 20, style: .continuous)
        return ZStack {
            shape
                .fill(Color.primary.opacity(0.07))
            HStack(spacing: 4) {
                ForEach(Array("QWERTYUIOP").map(String.init), id: \.self) { letter in
                    Text(verbatim: letter)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .frame(width: 24.6, height: 34)
                        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
                }
            }
            .offset(y: 24)
            Button(action: chipTapped) { chip }
                .buttonStyle(InputCodeChipStyle(taps: chipTaps))
                .offset(y: -22)
        }
        .frame(width: InputCodeLayout.size.width, height: 100)
        .position(x: InputCodeLayout.size.width / 2, y: InputCodeLayout.chipY + 22)
    }

    private var chip: some View {
        ZStack {
            HStack(spacing: 0) {
                Text(L("Messages", "来自信息"), ctx.language)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 67, alignment: .leading)
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { index in
                        Text(verbatim: InputCodeLayout.digits[index])
                            .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                            .frame(width: 11)
                            .padding(.leading, index == 3 ? 5 : 0)
                    }
                }
                .foregroundStyle(.primary)
                .opacity(phase == .empty ? 1 : 0)
            }
            .opacity(phase == .verified ? 0 : (phase == .empty ? 1 : 0.35))
            .blur(radius: phase == .verified ? 5 : 0)
            HStack(spacing: 5) {
                Image(systemName: "arrow.counterclockwise")
                Text(L("Clear", "清除"), ctx.language)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .opacity(phase == .verified ? 1 : 0)
            .blur(radius: phase == .verified ? 0 : 5)
        }
        .padding(.horizontal, 14)
        .frame(width: InputCodeLayout.chipWidth, height: 34)
        .background(Palette.elevated, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        .animation(.smooth(duration: 0.3), value: phase)
    }

    // MARK: Actions

    private func chipTapped() {
        guard !clearing else { return }
        chipTaps += 1
        switch phase {
        case .empty: paste()
        case .filling: break
        case .verified: clear()
        }
    }

    private func paste() {
        let stagger = ctx["stagger"]
        let response = ctx["response"]
        Haptics.tap(.light)
        phase = .filling
        for index in 0..<6 {
            withAnimation(.spring(response: response, dampingFraction: 0.74).delay(Double(index) * stagger)) {
                flight[index] = 1
            }
        }
        task?.cancel()
        task = Task { @MainActor in
            // A digit reaches its box a little before its spring settles.
            try? await Task.sleep(for: .seconds(response * 0.62))
            for index in 0..<6 {
                guard !Task.isCancelled else { return }
                landed[index] = true
                pops[index] += 1
                if !ctx.isPreview { Haptics.tap(.light) }
                try? await Task.sleep(for: .seconds(stagger))
            }
            try? await Task.sleep(for: .seconds(0.28))
            guard !Task.isCancelled else { return }
            phase = .verified
            wave += 1
            if !ctx.isPreview { Haptics.success() }
        }
    }

    private func clear() {
        Haptics.tap(.light)
        task?.cancel()
        clearing = true
        withAnimation(.easeIn(duration: 0.22)) { gone = true }
        withAnimation(.smooth(duration: 0.3)) {
            landed = Array(repeating: false, count: 6)
            phase = .empty
        }
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.34))
            guard !Task.isCancelled else { return }
            // The digits are invisible now: send them home without animation.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                flight = Array(repeating: 0, count: 6)
                gone = false
            }
            clearing = false
        }
    }
}

private struct InputCodeBox: View {
    let landed: Bool
    let verified: Bool
    let pop: Int

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let border: Color = verified ? Palette.green : (landed ? Palette.indigo : Color.primary.opacity(0.14))
        return shape
            .fill(verified ? Palette.green.opacity(0.12) : Palette.elevated)
            .overlay(shape.strokeBorder(border, lineWidth: landed ? 1.8 : 1.2))
            .frame(width: 38, height: 48)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .animation(.easeOut(duration: 0.2), value: landed)
            .animation(.easeOut(duration: 0.25), value: verified)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: pop) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.12, duration: 0.1, spring: .snappy)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            }
    }
}

/// The verify wave: each box (and its digit) hops a moment after the one before it.
private struct InputCodeHop: ViewModifier {
    let index: Int
    let wave: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(0), trigger: wave) { view, lift in
            view.offset(y: lift)
        } keyframes: { _ in
            LinearKeyframe(0, duration: 0.01 + Double(index) * 0.05)
            SpringKeyframe(-9, duration: 0.14, spring: .snappy)
            SpringKeyframe(0, duration: 0.45, spring: .bouncy)
        }
    }
}

/// Flies a digit from the chip to its box along an arc, growing on the way.
private struct InputCodeFlight: ViewModifier, Animatable {
    var progress: CGFloat
    let from: CGPoint
    let to: CGPoint
    let lift: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let arc = sin(.pi * min(max(progress, 0), 1)) * lift
        let x = from.x + (to.x - from.x) * progress
        let y = from.y + (to.y - from.y) * progress - arc
        let scale = 15.0 / 26.0 + (1 - 15.0 / 26.0) * progress
        return content
            .scaleEffect(scale)
            .position(x: x, y: y)
    }
}

private struct InputCodeChipStyle: ButtonStyle {
    let taps: Int

    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(isPressed: configuration.isPressed, taps: taps) { pressed in
            configuration.label
                .scaleEffect(pressed ? 0.94 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
    }
}
