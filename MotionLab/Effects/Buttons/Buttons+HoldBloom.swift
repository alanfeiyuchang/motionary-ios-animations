import SwiftUI

extension Effect {
    static let buttonsHoldBloom = Effect(
        id: "buttons.hold-bloom",
        category: .buttons,
        interaction: .gesture,
        name: L("Hold to Bloom", "长按绽染"),
        summary: L(
            "Holding grows a bloom of colour out of the button until it floods the card and flips its theme.",
            "按住时，一团色彩从按钮里绽开，直到漫过整张卡片并翻转它的主题。"
        ),
        prompt: L(
            "A 300 × 212 pt settings card in a light “Day” theme with a hold button near its bottom edge. Holding the button grows an organic blob from the button's centre: its radius follows progress^1.5 over 1.2 s, so it creeps at first and then rushes to the far corners, and its edge wobbles by 3 pt on two slow sine waves. The blob is two layers: an 18 pt band of accent colour leads, and inside it the same card is redrawn in the other theme, so title, icon, text lines and the button itself invert exactly where the bloom has passed. The button sinks to 95% and soft haptics tick while held. Releasing early pulls the bloom back at 2.5× speed. Reaching the corners commits the new theme with a success haptic and a 103% pop of the card; the next hold blooms back.",
            "300×212pt 的设置卡片，初始为浅色“日间”主题，底边附近有一枚长按按钮。按住后，一团有机形状从按钮中心长出：半径按进度的 1.5 次方在 1.2 秒内增长，先缓慢蔓延再冲向最远的角落；边缘由两道慢速正弦波带来 3pt 起伏。色团分两层：最前面是 18pt 宽的强调色带，其内部用另一套主题重绘同一张卡片，标题、图标、文字和按钮恰好在色团经过处反转。按住时按钮下沉到 95%，伴随连续轻触感。提前松手，色团以 2.5 倍速收回。漫到四角即提交新主题：成功触感，卡片弹到 103% 再回落。"
        ),
        implementation: L(
            "The card is drawn twice, once per theme; the second copy and a flat accent layer are masked by the same animatable blob Shape at two radii. Progress is a pure function of time (base + rate × elapsed) read inside a TimelineView, and onLongPressGesture's pressing callback flips the rate between growing and retracting.",
            "卡片按两套主题各画一次；第二份卡片和一层纯强调色，用同一个有机形状 Shape 以两个不同半径做遮罩。进度是时间的纯函数（基准值 + 速率 × 经过时间），在 TimelineView 中读取；onLongPressGesture 的按压回调把速率在生长与收回之间切换。"
        ),
        apis: ["TimelineView", "mask", "Shape", "onLongPressGesture(minimumDuration:maximumDistance:perform:onPressingChanged:)", "keyframeAnimator"],
        tags: ["hold", "bloom", "theme", "reveal", "flood", "长按", "绽放", "主题", "揭示", "漫染"],
        params: [
            .slider("duration", L("Hold time", "按住时长"), 0.6...2.5, default: 1.2, unit: "s"),
            .slider("band", L("Colour band", "色带宽度"), 0...40, default: 18, decimals: 0, unit: "pt"),
            .slider("wobble", L("Edge wobble", "边缘起伏"), 0...8, default: 3, decimals: 1, unit: "pt"),
            .slider("retract", L("Retract speed", "收回速度"), 1...5, default: 2.5, decimals: 1, unit: "×"),
        ]
    ) { ctx in
        ButtonBloomDemo(ctx: ctx)
    }
}

private struct ButtonBloomClock {
    var base: Double = 0
    var rate: Double = 0
    var since = Date.distantPast

    func value(at date: Date) -> Double {
        (base + rate * date.timeIntervalSince(since)).clamped(to: 0...1)
    }
}

private struct ButtonBloomTheme {
    let background: [Color]
    let text: Color
    let secondary: Color
    let accent: Color
    let icon: String
    let title: LocalizedText
    let subtitle: LocalizedText

    static let day = ButtonBloomTheme(
        background: [Color(hex: 0xFFFDF8), Color(hex: 0xF1EADD)],
        text: Color(hex: 0x1F1B2D),
        secondary: Color(hex: 0x1F1B2D, opacity: 0.14),
        accent: Palette.amber,
        icon: "sun.max.fill",
        title: L("Day", "日间"),
        subtitle: L("Bright and warm", "明亮温暖")
    )
    static let night = ButtonBloomTheme(
        background: [Color(hex: 0x1A1740), Color(hex: 0x0E0C24)],
        text: Color(hex: 0xF4F2FF),
        secondary: Color(hex: 0xF4F2FF, opacity: 0.16),
        accent: Palette.violet,
        icon: "moon.stars.fill",
        title: L("Night", "夜间"),
        subtitle: L("Calm and dim", "沉静柔和")
    )
}

private enum ButtonBloomPhase {
    case idle, growing, retracting
}

private struct ButtonBloomDemo: View {
    let ctx: DemoContext
    @State private var clock = ButtonBloomClock()
    @State private var phase = ButtonBloomPhase.idle
    @State private var isNight = false
    @State private var pops = 0
    @State private var finishTask: Task<Void, Never>?
    @State private var tickTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    private static let card = CGSize(width: 300, height: 212)
    /// Centre of the hold button inside the card: the bloom's origin.
    private static let origin = CGPoint(x: card.width / 2, y: card.height - 40)

    private var duration: Double { max(ctx["duration"], 0.2) }
    private var band: CGFloat { ctx.cg("band") }
    private var wobble: CGFloat { ctx.cg("wobble") }
    /// Radius at which the inner (theme) layer has passed the farthest corner.
    private var fullRadius: CGFloat {
        hypot(Self.card.width / 2, Self.origin.y) + band + wobble * 1.5 + 2
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            card
            Spacer()
            DemoHint(text: L("Hold the button until the colour fills the card", "按住按钮，直到色彩漫满卡片"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: duration * 1.7 + 2.6, delay: 0.4) { playScript() }
        .onDisappear {
            finishTask?.cancel()
            tickTask?.cancel()
            scriptTask?.cancel()
        }
    }

    private var card: some View {
        let current = isNight ? ButtonBloomTheme.night : ButtonBloomTheme.day
        let next = isNight ? ButtonBloomTheme.day : ButtonBloomTheme.night
        let holding = phase == .growing
        return TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: phase == .idle || ctx.isStill)) { timeline in
            let progress = ctx.isStill ? 0.66 : clock.value(at: timeline.date)
            let radius = fullRadius * CGFloat(pow(progress, 1.5))
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ButtonBloomCard(theme: current, language: ctx.language, holding: holding)
                if progress > 0.001 {
                    Rectangle()
                        .fill(next.accent)
                        .mask(ButtonBloomBlob(center: Self.origin, radius: radius, wobble: wobble, time: time))
                    ButtonBloomCard(theme: next, language: ctx.language, holding: holding)
                        .mask(ButtonBloomBlob(center: Self.origin, radius: max(radius - band, 0), wobble: wobble, time: time + 1.3))
                }
            }
            .frame(width: Self.card.width, height: Self.card.height)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 12)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.03, duration: 0.1)
                SpringKeyframe(1, duration: 0.5, spring: .bouncy)
            }
        }
        .overlay {
            // The hit target is the hold button only.
            Color.clear
                .frame(width: 190, height: 60)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 600, maximumDistance: 60) {
                } onPressingChanged: { isPressing in
                    scriptTask?.cancel()
                    if isPressing { begin(haptics: true) } else { cancel() }
                }
                .position(Self.origin)
        }
        .frame(width: Self.card.width, height: Self.card.height)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Behaviour

    private func begin(haptics: Bool) {
        let now = Date()
        let current = clock.value(at: now)
        clock = ButtonBloomClock(base: current, rate: 1 / duration, since: now)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { phase = .growing }
        if haptics { Haptics.tap(.soft) }
        finishTask?.cancel()
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds((1 - current) * duration))
            guard !Task.isCancelled else { return }
            commit(haptics: haptics)
        }
        tickTask?.cancel()
        guard haptics else { return }
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.16))
                guard !Task.isCancelled else { return }
                Haptics.tap(.soft)
            }
        }
    }

    private func cancel() {
        guard phase == .growing else { return }
        finishTask?.cancel()
        tickTask?.cancel()
        let now = Date()
        let current = clock.value(at: now)
        let speed = max(ctx["retract"], 0.5)
        clock = ButtonBloomClock(base: current, rate: -speed / duration, since: now)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { phase = .retracting }
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(current * duration / speed + 0.05))
            guard !Task.isCancelled else { return }
            if phase == .retracting { phase = .idle }
        }
    }

    /// The bloom has covered the card: the flooded theme becomes the card's theme and the mask starts over.
    private func commit(haptics: Bool) {
        tickTask?.cancel()
        isNight.toggle()
        clock = ButtonBloomClock()
        pops += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { phase = .idle }
        if haptics { Haptics.success() }
    }

    /// Preview loop and detail intro: a full bloom, then (previews only) a half hold that is let go.
    private func playScript() {
        guard phase == .idle else { return }
        scriptTask?.cancel()
        let hold = duration
        scriptTask = Task { @MainActor in
            begin(haptics: false)
            try? await Task.sleep(for: .seconds(hold + 1.2))
            guard !Task.isCancelled, ctx.isPreview else { return }
            begin(haptics: false)
            try? await Task.sleep(for: .seconds(hold * 0.62))
            guard !Task.isCancelled else { return }
            cancel()
        }
    }
}

private struct ButtonBloomCard: View {
    let theme: ButtonBloomTheme
    let language: AppLanguage
    let holding: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.background, startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .background(theme.accent.opacity(0.18), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.title, language)
                            .font(.headline)
                            .foregroundStyle(theme.text)
                        Text(theme.subtitle, language)
                            .font(.caption)
                            .foregroundStyle(theme.text.opacity(0.6))
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Capsule().fill(theme.secondary).frame(height: 9)
                    Capsule().fill(theme.secondary).frame(width: 170, height: 9)
                }
                .padding(.top, 18)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                    Text(L("Hold to switch", "按住切换"), language)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.background[0])
                .frame(width: 176, height: 46)
                .background(theme.text, in: Capsule())
                .scaleEffect(holding ? 0.95 : 1)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 17)
        }
    }
}

/// A circle whose edge breathes on two sine waves, so the bloom reads as liquid rather than a compass-drawn disc.
private struct ButtonBloomBlob: Shape {
    let center: CGPoint
    let radius: CGFloat
    let wobble: CGFloat
    let time: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard radius > 0.5 else { return path }
        let count = 72
        // Small blooms wobble less, so the shape never folds over itself near the button.
        let amount = min(wobble, radius * 0.07)
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
            let ripple = sin(angle * 5 + time * 3) + 0.5 * sin(angle * 3 - time * 2.1)
            let r = radius + amount * CGFloat(ripple)
            let point = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
