import SwiftUI

extension Effect {
    static let cardsNumberReveal = Effect(
        id: "cards.number-reveal",
        category: .cards,
        interaction: .tap,
        name: L("Card Number Reveal", "卡号揭示"),
        summary: L("A bank card's masked digits scramble into the real number under a light sweep, then roll back into dots.", "银行卡上被遮住的数字在一道扫光下乱码跳动、依次定格为真实卡号，随后又滚回圆点。"),
        prompt: L(
            "A dark 286×180 pt bank card shows twelve dots, its last four digits and a masked CVV. Tapping 'Show' unmasks it left to right: each character starts 50 ms after the previous one, flickers through random digits every 45 ms for 0.4 s at 70% opacity, then locks onto its real digit with a pop from 130% that settles in 180 ms. Meanwhile the card nods 9° on its vertical axis and back while a soft diagonal band of light sweeps across it in 0.9 s. A success haptic marks the last digit; a ring around the eye icon then drains for 4 s and the number hides itself. Hiding runs right to left: each digit rolls up 12 pt and fades as its dot rolls in from below. Secure, crisp and a little theatrical.",
            "一张286×180 pt的深色银行卡，显示十二个圆点、末四位数字和被遮住的CVV。点击「显示」后从左到右解除遮挡：每个字符比前一个晚50毫秒开始，以70%不透明度每45毫秒跳一个随机数字、持续0.4秒，随后定格为真实数字，并从130%回落、在180毫秒内稳住。与此同时，卡片绕纵轴点头9°再回正，一道柔和的斜向光带用0.9秒扫过卡面。最后一位定格时给出成功触感；接着眼睛图标外的圆环用4秒走完，卡号自动隐藏。隐藏时从右到左：每个数字上滚12 pt并淡出，圆点从下方滚入。安全而利落。"
        ),
        implementation: L(
            "A TimelineView (paused when idle) gives the time since the last toggle; every character cell derives its glyph, opacity, offset and scale from that time and its index. A keyframeAnimator drives the card's nod and the light band together.",
            "TimelineView（空闲时暂停）提供距上次切换的时间，每个字符格根据该时间与自身序号推导字形、透明度、位移与缩放；卡片的点头与光带由同一个 keyframeAnimator 驱动。"
        ),
        apis: ["TimelineView", "keyframeAnimator", "rotation3DEffect", "blendMode(.plusLighter)", "contentTransition(.symbolEffect(.replace))"],
        tags: ["card number", "reveal", "scramble", "mask", "卡号", "显示隐藏", "乱码", "扫光"],
        params: [
            .slider("stagger", L("Per-digit delay", "逐位延迟"), 0.02...0.12, default: 0.05, unit: "s"),
            .slider("scramble", L("Scramble time", "乱码时长"), 0.15...1.0, default: 0.4, unit: "s"),
            .slider("autoHide", L("Auto-hide after", "自动隐藏"), 0...8, default: 4, step: 1, decimals: 0, unit: "s"),
            .toggle("sweep", L("Light sweep", "扫光"), default: true),
        ]
    ) { ctx in
        CardsNumberRevealDemo(ctx: ctx)
    }
}

private struct CardsNumberRevealDemo: View {
    let ctx: DemoContext
    @State private var revealed: Bool
    /// When the last show / hide began; every character cell is timed from it.
    @State private var changedAt = Date.distantPast
    @State private var animating = false
    @State private var shows = 0
    @State private var ring: CGFloat = 0
    @State private var taps = 0
    @State private var script: Task<Void, Never>?

    /// 12 masked number characters + 3 CVV characters.
    private let maskedCount = 15

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the revealed number.
        _revealed = State(initialValue: ctx.isStill)
    }

    var body: some View {
        let sweeps = ctx.bool("sweep")
        VStack(spacing: 22) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !animating)) { timeline in
                CardsRevealCard(
                    revealed: revealed,
                    elapsed: timeline.date.timeIntervalSince(changedAt),
                    stagger: ctx["stagger"],
                    scramble: ctx["scramble"]
                )
            }
            .keyframeAnimator(initialValue: CardsRevealFX(), trigger: shows) { content, fx in
                content
                    .overlay { CardsRevealBand(sweep: fx.sweep, isOn: sweeps) }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .rotation3DEffect(.degrees(fx.tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 14)
            } keyframes: { _ in
                KeyframeTrack(\.tilt) {
                    CubicKeyframe(-9, duration: 0.3)
                    CubicKeyframe(4, duration: 0.35)
                    SpringKeyframe(0, duration: 0.45, spring: Spring(response: 0.35, dampingRatio: 0.7))
                }
                KeyframeTrack(\.sweep) {
                    MoveKeyframe(-1.3)
                    CubicKeyframe(1.3, duration: 0.9)
                }
            }
            eyeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.3) { toggle() }
        .onDisappear { script?.cancel() }
    }

    private var eyeButton: some View {
        Button {
            taps += 1
            Haptics.tap(.light)
            toggle()
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: ring)
                        .stroke(Palette.indigo, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 26, height: 26)
                Text(revealed ? L("Hide number", "隐藏卡号") : L("Show number", "显示卡号"), ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(.primary)
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .frame(height: 44)
            .background(Palette.elevated, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.stroke))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(CardsRevealButtonStyle(taps: taps))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: revealed)
    }

    private func toggle() {
        setRevealed(!revealed)
    }

    private func setRevealed(_ value: Bool) {
        let muted = Haptics.isMuted || ctx.isPreview
        let stagger = ctx["stagger"]
        let autoHide = ctx["autoHide"]
        revealed = value
        changedAt = .now
        animating = true
        script?.cancel()
        var instant = Transaction()
        instant.disablesAnimations = true
        if value {
            shows += 1
            withTransaction(instant) { ring = 1 }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { ring = 0 }
        }
        // Until the last cell has settled (plus its pop / roll).
        let total: Double = value
            ? Double(maskedCount - 1) * stagger + ctx["scramble"] + 0.2
            : Double(maskedCount - 1) * stagger * 0.6 + 0.3
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(total))
            guard !Task.isCancelled else { return }
            animating = false
            guard value else { return }
            if !muted { Haptics.success() }
            // The preview loop hides it on its own beat; on the detail page the ring counts down.
            guard autoHide > 0, !ctx.isPreview else {
                withAnimation(.easeOut(duration: 0.3)) { ring = 0 }
                return
            }
            withAnimation(.linear(duration: autoHide)) { ring = 0 }
            try? await Task.sleep(for: .seconds(autoHide))
            guard !Task.isCancelled else { return }
            setRevealed(false)
        }
    }
}

/// A soft diagonal band of light that crosses the card once per reveal.
private struct CardsRevealBand: View {
    let sweep: Double
    let isOn: Bool

    var body: some View {
        LinearGradient(colors: [.clear, Color.white.opacity(0.34), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(width: 96, height: 380)
            .rotationEffect(.degrees(22))
            .offset(x: CGFloat(sweep) * 230)
            .blendMode(.plusLighter)
            .opacity(isOn ? 1 : 0)
            .allowsHitTesting(false)
    }
}

private struct CardsRevealFX {
    var tilt: Double = 0
    /// −1.3 … 1.3 across the card; parked off the right edge at rest.
    var sweep: Double = 1.3
}

private struct CardsRevealButtonStyle: ButtonStyle {
    let taps: Int

    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(isPressed: configuration.isPressed, taps: taps) { pressed in
            configuration.label
                .scaleEffect(pressed ? 0.95 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
    }
}

/// The card face. Each masked character is a function of `elapsed` (time since the last toggle) and its index.
private struct CardsRevealCard: View {
    let revealed: Bool
    let elapsed: Double
    let stagger: Double
    let scramble: Double

    private static let number = Array("541275349021")
    private static let cvv = Array("372")

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .bold))
                    Text(verbatim: "Aurora")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer(minLength: 0)
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 15, weight: .semibold))
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
                chip
                numberRow
                    .padding(.top, 14)
                footer
                    .padding(.top, 12)
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .frame(width: 286, height: 180)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x262A44), Color(hex: 0x10111A)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color(hex: 0x6E7BFF).opacity(0.55))
                .frame(width: 210, height: 210)
                .blur(radius: 46)
                .offset(x: 120, y: -90)
            Circle()
                .fill(Color(hex: 0xFF5FA2).opacity(0.3))
                .frame(width: 170, height: 170)
                .blur(radius: 50)
                .offset(x: -130, y: 100)
        }
    }

    private var chip: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0xF7E3A1), Color(hex: 0xC9A24B)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 36, height: 26)
            .overlay {
                VStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(0.18))
                            .frame(height: 0.8)
                    }
                }
                .padding(.horizontal, 4)
            }
    }

    private var numberRow: some View {
        HStack(spacing: 11) {
            ForEach(0..<3, id: \.self) { group in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { k in
                        cell(group * 4 + k, character: Self.number[group * 4 + k], size: 19, width: 12)
                    }
                }
            }
            Text(verbatim: "4821")
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .kerning(0.5)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: 24)
    }

    private var footer: some View {
        HStack(alignment: .bottom, spacing: 0) {
            label("CARD HOLDER", value: Text(verbatim: "ALEX MORGAN"))
            Spacer(minLength: 0)
            label("EXP", value: Text(verbatim: "09/29"))
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 3) {
                caption("CVV")
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { k in
                        cell(12 + k, character: Self.cvv[k], size: 11.5, width: 9)
                    }
                }
                .frame(height: 14)
            }
        }
    }

    private func label(_ title: String, value: Text) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            caption(title)
            value
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .frame(height: 14)
        }
    }

    private func caption(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.system(size: 7.5, weight: .semibold))
            .tracking(1)
            .opacity(0.6)
    }

    /// One masked character: a dot, a flickering random digit, or the real digit.
    private func cell(_ index: Int, character: Character, size: CGFloat, width: CGFloat) -> some View {
        let state = cellState(index)
        let glyph: Character = state.scrambling ? randomDigit(index) : character
        return ZStack {
            Text(verbatim: String(glyph))
                .font(.system(size: size, weight: .semibold, design: .monospaced))
                .opacity(state.digitOpacity)
                .scaleEffect(state.digitScale)
                .offset(y: state.digitOffset)
            Circle()
                .frame(width: size * 0.3, height: size * 0.3)
                .opacity(state.dotOpacity)
                .offset(y: state.dotOffset)
        }
        .frame(width: width)
    }

    private struct CellState {
        var scrambling = false
        var digitOpacity: Double = 0
        var digitScale: CGFloat = 1
        var digitOffset: CGFloat = 0
        var dotOpacity: Double = 1
        var dotOffset: CGFloat = 0
    }

    private func cellState(_ index: Int) -> CellState {
        var state = CellState()
        if revealed {
            // Left to right: dot → flicker → locked digit with a pop.
            let start = Double(index) * stagger
            let lock = start + scramble
            guard elapsed >= start else { return state }
            state.dotOpacity = 0
            if elapsed < lock {
                state.scrambling = true
                state.digitOpacity = 0.7
            } else {
                state.digitOpacity = 1
                let pop = max(0, 1 - (elapsed - lock) / 0.18)
                state.digitScale = 1 + 0.3 * CGFloat(pop * pop)
            }
        } else {
            // Right to left: the digit rolls up and out, the dot rolls in from below.
            let start = Double(14 - index) * stagger * 0.6
            let p = ((elapsed - start) / 0.22).clamped(to: 0...1)
            let eased = CGFloat(p * p * (3 - 2 * p))
            state.digitOpacity = Double(1 - eased)
            state.digitOffset = -12 * eased
            state.dotOpacity = Double(eased)
            state.dotOffset = 12 * (1 - eased)
        }
        return state
    }

    /// A new pseudo-random digit every 45 ms, different for every cell.
    private func randomDigit(_ index: Int) -> Character {
        let tick = Int(elapsed / 0.045)
        let hash = abs((index &* 7919) &+ (tick &* 104_729) &+ (index &* tick &* 31))
        return Character(String(hash % 10))
    }
}
