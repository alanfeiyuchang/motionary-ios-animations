import SwiftUI

// MARK: - Card declined

extension Effect {
    static let feedbackCardDeclined = Effect(
        id: "feedback.card-declined",
        category: .feedback,
        interaction: .tap,
        name: L("Card Declined", "刷卡被拒"),
        summary: L("A card dips into a reader, is read, then gets spat back out tilted, with a red flash, a shake and a drawn-in error.", "卡片插入读卡器、读取，随后被吐出并歪向一边，红光一闪、左右抖动，错误提示逐笔画出。"),
        prompt: L(
            "A graphite card reader with a small screen and four status LEDs sits above a payment card. On tap the card slides 58 pt up into the slot on a spring (response 0.45 s, damping 0.86) and the reader nudges 3 pt as it seats; the LEDs light green one by one over 0.7 s while the screen reads 'Reading'. Then the reader rejects it: the screen and LEDs flip to red, a red glow pulses behind the body, and the card is pushed back out on a looser spring (response 0.38 s, damping 0.55), dropping 8 pt past its rest and tilting 7°. Card and reader shake against each other, 10 pt decaying over five swings in 0.4 s, with an error haptic. Below, a red cross strokes itself inside a ring in 0.35 s and 'Card declined' wipes in from the left. Blunt, mechanical, clearly a no.",
            "石墨色读卡器带一块小屏幕和四颗状态灯，下方是一张支付卡。点击后卡片以弹簧（响应 0.45 秒、阻尼 0.86）向上滑入卡槽 58 pt，到位时读卡器轻顶 3 pt；状态灯在 0.7 秒内逐颗亮绿，屏幕显示“读取中”。随后读卡器拒绝：屏幕与状态灯翻红，机身背后红光一闪，卡片被更松的弹簧（响应 0.38 秒、阻尼 0.55）推回，越过原位下落 8 pt 并倾斜 7°。卡片与读卡器相对抖动，10 pt 幅度在 0.4 秒五次摆动中衰减，伴随错误触感。下方圆环内的红叉 0.35 秒写出，“刷卡被拒”从左擦入。生硬、机械、明确。"
        ),
        implementation: L(
            "The card sits behind the reader in a ZStack, so sliding it up hides it in the slot without a mask; a phase enum drives the screen, LEDs and glow, and keyframeAnimators keyed on a rejection counter shake the card and (smaller, opposite) the reader. The error mark is two trimmed Shapes and the label is revealed by an animated mask.",
            "卡片在 ZStack 中位于读卡器之后，向上滑动就自然藏进卡槽，无需遮罩；阶段枚举驱动屏幕、状态灯与红光，以拒绝计数为触发器的 keyframeAnimator 让卡片抖动，读卡器则以更小的反向幅度跟着抖。错误标记是两个 trim 的 Shape，文字由动画遮罩揭示。"
        ),
        apis: ["keyframeAnimator(initialValue:trigger:)", "spring(response:dampingFraction:)", "trim(from:to:)", "mask(alignment:_:)", "rotationEffect(_:anchor:)"],
        tags: ["declined", "payment", "error", "card reader", "拒绝", "支付失败", "错误", "读卡器"],
        params: [
            .slider("shake", L("Shake amplitude", "抖动幅度"), 4...20, default: 10, decimals: 0, unit: "pt"),
            .slider("tilt", L("Rejected tilt", "退卡倾斜"), 0...14, default: 7, decimals: 0, unit: "°"),
            .slider("reading", L("Reading time", "读取时长"), 0.3...2.0, default: 0.7, decimals: 1, unit: "s"),
            .slider("eject", L("Eject damping", "退卡阻尼"), 0.35...0.9, default: 0.55),
        ]
    ) { ctx in
        CardDeclinedDemo(ctx: ctx)
    }
}

private enum CardDeclinedPhase {
    case idle
    case reading
    case declined
}

private struct CardDeclinedDemo: View {
    let ctx: DemoContext
    @State private var phase: CardDeclinedPhase
    @State private var inserted = false
    @State private var rejected: Bool
    @State private var leds: Int
    @State private var labelShown: Bool
    @State private var rejections = 0
    @State private var seats = 0
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the rejected card.
        _phase = State(initialValue: ctx.isStill ? .declined : .idle)
        _rejected = State(initialValue: ctx.isStill)
        _leds = State(initialValue: ctx.isStill ? 4 : 0)
        _labelShown = State(initialValue: ctx.isStill)
    }

    private static let red = Color(hex: 0xFF453A)

    var body: some View {
        let amplitude: CGFloat = ctx.cg("shake")
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    card
                        .padding(.top, 124)
                        .keyframeAnimator(initialValue: CGFloat(0), trigger: rejections) { content, x in
                            content.offset(x: x)
                        } keyframes: { _ in
                            KeyframeTrack(\.self) {
                                CubicKeyframe(-amplitude, duration: 0.06)
                                CubicKeyframe(amplitude * 0.8, duration: 0.09)
                                CubicKeyframe(-amplitude * 0.55, duration: 0.09)
                                CubicKeyframe(amplitude * 0.3, duration: 0.08)
                                CubicKeyframe(-amplitude * 0.12, duration: 0.08)
                                SpringKeyframe(0, duration: 0.25, spring: .snappy)
                            }
                        }
                    reader
                        .keyframeAnimator(initialValue: CGFloat(0), trigger: rejections) { content, x in
                            content.offset(x: x)
                        } keyframes: { _ in
                            KeyframeTrack(\.self) {
                                LinearKeyframe(0, duration: 0.03)
                                CubicKeyframe(amplitude * 0.3, duration: 0.07)
                                CubicKeyframe(-amplitude * 0.22, duration: 0.09)
                                CubicKeyframe(amplitude * 0.12, duration: 0.09)
                                SpringKeyframe(0, duration: 0.3, spring: .snappy)
                            }
                        }
                        .keyframeAnimator(initialValue: CGFloat(0), trigger: seats) { content, y in
                            content.offset(y: y)
                        } keyframes: { _ in
                            KeyframeTrack(\.self) {
                                CubicKeyframe(-3, duration: 0.08)
                                SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                            }
                        }
                }
                .frame(width: 300, height: 268, alignment: .top)
                errorLabel
                    .frame(height: 26)
                    .padding(.top, 6)
            }
            .frame(width: 300, height: 302)
            .contentShape(Rectangle())
            .onTapGesture { play() }
            DemoHint(text: L("Tap to pay again", "点击再次刷卡"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["reading"] + 4.2, delay: 0.5) { play() }
    }

    // MARK: Reader

    private var reader: some View {
        let declined: Bool = phase == .declined
        let shell = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return ZStack {
            // The red glow behind the body.
            shell
                .fill(Self.red)
                .blur(radius: 22)
                .opacity(declined ? 0.3 : 0)
                .scaleEffect(declined ? 1.08 : 0.9)
            // The flash at the moment of rejection.
            shell
                .fill(Self.red)
                .blur(radius: 26)
                .keyframeAnimator(initialValue: 0.0, trigger: rejections) { content, flash in
                    content.opacity(flash)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(0.75)
                        LinearKeyframe(0.0, duration: 0.6, timingCurve: .easeOut)
                    }
                }
            shell
                .fill(LinearGradient(colors: [Color(hex: 0x3A3A42), Color(hex: 0x1A1A1F)], startPoint: .top, endPoint: .bottom))
            shell
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            VStack(spacing: 10) {
                screen
                HStack(spacing: 9) {
                    ForEach(0..<4, id: \.self) { index in
                        let on: Bool = index < leds
                        Circle()
                            .fill(on ? (declined ? Self.red : Palette.green) : Color.white.opacity(0.12))
                            .frame(width: 6, height: 6)
                            .shadow(color: (declined ? Self.red : Palette.green).opacity(on ? 0.9 : 0), radius: 4)
                    }
                }
                // The slot the card dips into.
                Capsule()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: 108, height: 7)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            }
            .padding(.top, 2)
        }
        .frame(width: 160, height: 116)
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
    }

    private var screen: some View {
        let zh = ctx.language == .zh
        let declined: Bool = phase == .declined
        return ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(hex: 0x0A0F1A))
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Self.red)
                .opacity(declined ? 0.9 : 0)
            switch phase {
            case .idle:
                Label {
                    Text(zh ? "请插卡" : "Insert card")
                } icon: {
                    Image(systemName: "arrow.up")
                }
                .foregroundStyle(Color(hex: 0x7FD4FF))
                .transition(.opacity)
            case .reading:
                Text(zh ? "读取中" : "Reading")
                    .foregroundStyle(Color(hex: 0x7FD4FF))
                    .transition(.opacity)
            case .declined:
                Text(zh ? "交易被拒" : "DECLINED")
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 1.25).combined(with: .opacity))
            }
        }
        .font(.system(size: 13, weight: .bold, design: .monospaced))
        .frame(width: 128, height: 50)
    }

    // MARK: Card

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let tilt: Double = ctx["tilt"]
        return ZStack(alignment: .top) {
            shape.fill(LinearGradient(colors: [Color(hex: 0x5B6CFF), Color(hex: 0x9A4DFF)], startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0)], startPoint: .topLeading, endPoint: .center))
            // Chip, near the edge that enters the reader.
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFFE39A), Color(hex: 0xD9A441)], startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 20)
                .padding(.top, 20)
            VStack(spacing: 3) {
                Text(verbatim: "•••• 4821")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text(verbatim: "VALID 09/29")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 14)
            // The red wash at the moment of rejection.
            shape
                .fill(Self.red)
                .keyframeAnimator(initialValue: 0.0, trigger: rejections) { content, flash in
                    content.opacity(flash)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(0.6)
                        LinearKeyframe(0.0, duration: 0.5, timingCurve: .easeOut)
                    }
                }
        }
        .frame(width: 96, height: 132)
        .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
        .rotationEffect(.degrees(rejected ? -tilt : 0), anchor: .top)
        .offset(y: inserted ? -58 : (rejected ? 8 : 0))
    }

    // MARK: Error label

    private var errorLabel: some View {
        let zh = ctx.language == .zh
        return HStack(spacing: 7) {
            ZStack {
                Circle()
                    .trim(from: 0, to: labelShown ? 1 : 0)
                    .stroke(Self.red, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                CardDeclinedCross()
                    .trim(from: 0, to: labelShown ? 1 : 0)
                    .stroke(Self.red, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .padding(6.5)
            }
            .frame(width: 20, height: 20)
            // Round caps leave a dot at trim 0, so the mark is hidden until it draws.
            .opacity(labelShown ? 1 : 0)
            Text(zh ? "刷卡被拒 · 余额不足" : "Card declined · Insufficient funds")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Self.red)
                .fixedSize()
                .mask(alignment: .leading) {
                    Rectangle()
                        .scaleEffect(x: labelShown ? 1 : 0, anchor: .leading)
                }
                .opacity(labelShown ? 1 : 0)
        }
    }

    // MARK: Sequence

    private func play() {
        guard phase != .reading else { return }
        token += 1
        let current = token
        let reading: Double = ctx["reading"]
        let eject: Double = ctx["eject"]
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let preview: Bool = ctx.isPreview
        if buzz { Haptics.tap() }
        Task { @MainActor in
            if phase == .declined {
                // Try again: straighten the card and clear the error first.
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    phase = .idle
                    rejected = false
                    labelShown = false
                    leds = 0
                }
                try? await Task.sleep(for: .seconds(0.35))
                guard token == current else { return }
            }
            withAnimation(.easeOut(duration: 0.2)) { phase = .reading }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { inserted = true }
            try? await Task.sleep(for: .seconds(0.26))
            guard token == current else { return }
            seats += 1
            if buzz { Haptics.tap(.rigid) }
            for index in 1...4 {
                try? await Task.sleep(for: .seconds(reading / 4))
                guard token == current else { return }
                withAnimation(.easeOut(duration: 0.12)) { leds = index }
            }
            try? await Task.sleep(for: .seconds(0.12))
            guard token == current else { return }
            withAnimation(.easeOut(duration: 0.12)) { phase = .declined }
            withAnimation(.spring(response: 0.38, dampingFraction: eject)) {
                inserted = false
                rejected = true
            }
            rejections += 1
            if buzz { Haptics.error() }
            try? await Task.sleep(for: .seconds(0.3))
            guard token == current else { return }
            withAnimation(.easeOut(duration: 0.35)) { labelShown = true }
            guard preview else { return }
            try? await Task.sleep(for: .seconds(2.2))
            guard token == current else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                phase = .idle
                rejected = false
                labelShown = false
                leds = 0
            }
        }
    }
}

private struct CardDeclinedCross: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
