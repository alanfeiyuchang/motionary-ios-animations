import SwiftUI

extension Effect {
    static let textCountdown = Effect(
        id: "text.countdown",
        category: .text,
        interaction: .loop,
        name: L("Launch Countdown", "发售倒计时"),
        summary: L("Days, hours, minutes and seconds roll in pairs; the last five seconds pulse red, then zero flips to live.", "天、时、分、秒成对滚动；最后五秒红色脉冲，归零后切换为已开始。"),
        prompt: L(
            "A launch countdown of four tiles (days, hours, minutes, seconds), each holding a pair of 34 pt rounded digits over a small unit label, separated by colons that dim to 25% and return once per tick. Every second only the digits that change roll: the old one drops out of its clipped slot with a 3 pt blur while the new one falls in from above on a spring (response 0.45 s, damping 0.8); when a unit wraps, the roll cascades right to left 50 ms apart. In the last five seconds the digits turn red and the seconds tile pulses to 112% with an expanding red ring on each tick. At zero the tiles pop in turn, switch to mint and the caption rolls to “Live now”.",
            "四块数字牌组成的发售倒计时（天、时、分、秒），每块是一对34pt圆体数字加一行小单位，中间的冒号每跳一次暗到25%再亮回。每秒只有变化的数位滚动：旧数字带3pt模糊从裁剪槽口向下落出，新数字从上方以弹簧（响应0.45秒、阻尼0.8）落入；发生借位时，滚动从右到左依次传递，间隔50毫秒。最后五秒数字变红，秒牌每跳一次放大到112%，并向外扩散一圈红环。归零时四块牌依次弹起、换成薄荷绿，下方说明滚动为“已开始”。紧张感一点点收紧，最后一下释放。"
        ),
        implementation: L(
            "A task decrements the remaining seconds; each digit is an Animatable two-face roll slot with a per-place delay, and the final-seconds pulse is a scale spring plus a ring whose scale and opacity animate on every tick.",
            "一个任务每跳递减剩余秒数；每个数位是带位次延迟的 Animatable 双面滚动槽，最后几秒的脉冲由缩放弹簧加一圈随每跳放大淡出的圆环组成。"
        ),
        apis: ["Animatable", "Task.sleep", "spring(response:dampingFraction:)", "contentTransition(.numericText)", "clipped()"],
        tags: ["countdown", "timer", "launch", "digits", "roll", "倒计时", "计时器", "发售", "数字滚动", "秒杀"],
        params: [
            .slider("tick", L("Tick interval", "每跳间隔"), 0.4...1.5, default: 1.0, unit: "s"),
            .slider("response", L("Roll spring", "滚动弹簧"), 0.25...0.9, default: 0.45, unit: "s"),
            .slider("pulse", L("Final pulse scale", "末段脉冲缩放"), 1.0...1.3, default: 1.12),
        ]
    ) { ctx in
        TextCountdownDemo(ctx: ctx)
    }
}

private struct TextCountdownDemo: View {
    let ctx: DemoContext

    /// 3 days and 3 seconds: the fourth tick wraps every unit at once.
    private static let start = 3 * 86_400 + 3
    private static let finalWindow = 5

    @State private var remaining = TextCountdownDemo.start
    @State private var colonDim = false
    @State private var pulse = false
    @State private var ring = false
    @State private var celebrate = 0
    /// Bumped by a tap: restarts the script at the last seconds.
    @State private var jumps = 0
    /// Tick haptics only after a tap, never for the unattended loop.
    @State private var armed = false

    private var isFinal: Bool { remaining <= Self.finalWindow && remaining > 0 }
    private var isLive: Bool { remaining == 0 }

    var body: some View {
        VStack(spacing: 22) {
            caption
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { unit in
                    tile(unit)
                    if unit < 3 { colon }
                }
            }
            DemoHint(text: L("Tap to jump to the last seconds", "点击跳到最后几秒"), ctx: ctx)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !ctx.isPreview else { return }
            armed = true
            Haptics.tap(.medium)
            jumps += 1
        }
        .task(id: jumps) { await run(jumped: jumps > 0) }
    }

    // MARK: Pieces

    private var caption: some View {
        HStack(spacing: 8) {
            Image(systemName: isLive ? "dot.radiowaves.left.and.right" : "clock.fill")
                .font(.system(size: 13, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
            Text(isLive ? L("Live now", "已开始") : L("Drop starts in", "距离发售还有"), ctx.language)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(isLive ? Palette.mint : (isFinal ? Palette.red : Color.secondary))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isLive)
        .animation(.easeOut(duration: 0.3), value: isFinal)
    }

    private var units: [Int] {
        [remaining / 86_400, (remaining / 3_600) % 24, (remaining / 60) % 60, remaining % 60]
    }

    private func label(_ unit: Int) -> LocalizedText {
        switch unit {
        case 0: return L("DAYS", "天")
        case 1: return L("HRS", "时")
        case 2: return L("MIN", "分")
        default: return L("SEC", "秒")
        }
    }

    private func tile(_ unit: Int) -> some View {
        let value = units[unit]
        let digits: [String] = [String(value / 10), String(value % 10)]
        let digitColor: Color = isLive ? Palette.mint : (isFinal ? Palette.red : Color.primary)
        let isSeconds = unit == 3
        let font: Font = .system(size: 34, weight: .heavy, design: .rounded).monospacedDigit()
        return VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(0..<2, id: \.self) { place in
                    // Places counted from the right across the whole clock: seconds' ones roll first.
                    let order = (3 - unit) * 2 + (1 - place)
                    TextFXRollGlyph(
                        glyph: digits[place],
                        direction: -1,
                        font: font,
                        slot: CGSize(width: 23, height: 44),
                        color: digitColor,
                        response: ctx["response"],
                        damping: 0.8,
                        delay: Double(order) * 0.05,
                        blur: 3
                    )
                }
            }
            Text(label(unit), ctx.language)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(.secondary)
        }
        .frame(width: 64, height: 78)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tileEdge, lineWidth: 1)
        }
        .background {
            if isSeconds {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.red, lineWidth: 2)
                    .scaleEffect(ring ? 1.34 : 1)
                    .opacity(ring ? 0 : (isFinal ? 0.7 : 0))
            }
        }
        .shadow(color: .black.opacity(0.10), radius: 10, y: 6)
        .scaleEffect(isSeconds && pulse ? ctx.cg("pulse") : 1)
        .offset(y: celebrate == unit + 1 ? -10 : 0)
        .animation(.easeOut(duration: 0.3), value: isFinal)
        .animation(.easeOut(duration: 0.3), value: isLive)
    }

    private var tileEdge: Color {
        if isLive { return Palette.mint.opacity(0.55) }
        if isFinal { return Palette.red.opacity(0.4) }
        return Palette.stroke
    }

    private var colon: some View {
        VStack(spacing: 8) {
            Circle().frame(width: 5, height: 5)
            Circle().frame(width: 5, height: 5)
        }
        .foregroundStyle(isLive ? Palette.mint : (isFinal ? Palette.red : Color.secondary))
        .opacity(colonDim ? 0.25 : 1)
        .padding(.bottom, 14)
    }

    // MARK: Script

    private func run(jumped: Bool) async {
        if jumped {
            setRemaining(Self.finalWindow)
        } else if !ctx.isStill {
            setRemaining(Self.start)
        }
        guard !ctx.isStill else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(ctx["tick"]))
            if Task.isCancelled { return }
            if remaining == 0 {
                setRemaining(Self.start)
                continue
            }
            // After the big wrap has played, skip ahead to the last seconds.
            if remaining == Self.start - 6 {
                setRemaining(Self.finalWindow)
                continue
            }
            tick()
            if remaining == 0 {
                await finish()
            }
        }
    }

    private func setRemaining(_ value: Int) {
        withAnimation(.easeOut(duration: 0.3)) {
            remaining = value
            celebrate = 0
        }
    }

    private func tick() {
        remaining -= 1
        // Colons: dim at once, come back before the next tick.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            colonDim = true
            ring = false
        }
        withAnimation(.easeInOut(duration: min(ctx["tick"] * 0.6, 0.6)).delay(0.08)) { colonDim = false }
        guard remaining <= Self.finalWindow, remaining > 0 else { return }
        if armed && !ctx.isPreview { Haptics.tap(.rigid) }
        withAnimation(.easeOut(duration: 0.1)) { pulse = true }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.45).delay(0.1)) { pulse = false }
        withAnimation(.easeOut(duration: 0.55).delay(0.02)) { ring = true }
    }

    /// Zero: the tiles hop one after another and settle in mint.
    private func finish() async {
        if armed && !ctx.isPreview { Haptics.success() }
        for unit in 0..<5 {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { celebrate = unit + 1 }
            try? await Task.sleep(for: .seconds(0.07))
            if Task.isCancelled { return }
        }
        try? await Task.sleep(for: .seconds(1.6))
    }
}
