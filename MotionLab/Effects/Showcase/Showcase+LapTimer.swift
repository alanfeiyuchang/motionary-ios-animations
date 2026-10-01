import SwiftUI

extension Effect {
    static let showcaseLapTimer = Effect(
        id: "showcase.lap-timer",
        category: .showcase,
        interaction: .tap,
        name: L("Lap Stopwatch", "计圈秒表"),
        summary: L(
            "A stopwatch whose hand sweeps while the digits roll; every lap springs a new row in and tints the fastest and slowest.",
            "指针扫动、数字滚动的秒表；每记一圈弹入一行，最快与最慢的一圈各自着色。"
        ),
        prompt: L(
            "A dark stopwatch widget: a small dial with 50 ticks, an orange lap hand (one turn per 10 s) and a faint white total hand (one turn per minute), a large m:ss.cc readout whose seconds roll, three lap rows and two pill buttons. Tapping Start runs the clock at display rate. Tapping Lap makes the orange hand spring back to twelve (response 0.5 s, damping 0.62) while a new row drops in from under the top edge, scaling from 86% and pushing the older rows down on a spring (response 0.42 s, damping 0.68); the oldest fades out. Each row carries a bar proportional to its time; the fastest lap turns lime with a Best tag and the slowest turns red, re-evaluated on every lap. Stop freezes the hands; Reset swings both back to zero. Crisp, sporty, mechanical.",
            "深色秒表组件：小表盘有 50 根刻度，橙色计圈指针每 10 秒一圈，淡白色总时指针每分钟一圈；旁边是秒位会滚动的大号 m:ss.cc 读数，下方三行圈速和两个胶囊按钮。点“计圈”，橙色指针以弹簧（响应 0.5 秒、阻尼 0.62）甩回十二点，新的一行从上沿落入，由 86% 放大，并用弹簧（响应 0.42 秒、阻尼 0.68）把旧行往下推，最旧一行淡出。每行带一条与用时成比例的细条；最快一圈变青柠色并挂“最快”标签，最慢一圈变红，每次计圈重新评定。“复位”让两根指针摆回零位。干脆、机械感。"
        ),
        implementation: L(
            "A TimelineView derives the elapsed time from a start date plus banked seconds and feeds the readout and both hands. A lap moves the lap mark and adds the lost angle to an un-animated offset while the same amount is added to a spring-animated counter-offset, so the hand swings home. Rows live in a clipped VStack with a move + scale insertion transition under withAnimation(.spring).",
            "TimelineView 由起始时间加已累计秒数算出用时，驱动读数与两根指针。计圈时移动圈起点，把损失的角度加到一个不带动画的偏移上，同时把同样的量加到带弹簧动画的反向偏移上，于是指针摆回原位。圈速行放在裁剪的 VStack 里，用 withAnimation(.spring) 配合位移加缩放的插入转场。"
        ),
        apis: ["TimelineView(.animation)", "rotationEffect", "contentTransition(.numericText)", "AnyTransition.asymmetric", "withAnimation(.spring)", "Canvas"],
        tags: ["stopwatch", "lap", "timer", "sport", "split", "秒表", "计圈", "计时", "运动", "圈速"],
        params: [
            .slider("response", L("Row spring response", "行弹簧响应"), 0.2...0.8, default: 0.42, unit: "s"),
            .slider("damping", L("Row damping", "行阻尼"), 0.4...1.0, default: 0.68),
            .slider("rows", L("Visible laps", "显示圈数"), 2...3, default: 3, step: 1, decimals: 0),
            .toggle("tint", L("Tint best / worst", "标出最快 / 最慢"), default: true),
        ]
    ) { ctx in
        LapTimerDemo(ctx: ctx)
    }
}

private struct LapEntry: Identifiable, Equatable {
    let id: Int
    let time: Double
}

private func lapClock(_ time: Double) -> (main: String, cents: String) {
    let total = max(0, time)
    let whole = Int(total)
    let cents = Int((total - Double(whole)) * 100)
    return (String(format: "%d:%02d", whole / 60, whole % 60), String(format: ".%02d", cents))
}

private struct LapTimerDemo: View {
    let ctx: DemoContext
    @State private var running = false
    @State private var startDate = Date()
    /// Seconds accumulated before the current run.
    @State private var banked: Double
    /// Elapsed time at the last lap.
    @State private var lapMark: Double
    @State private var laps: [LapEntry]
    // Hand offsets: `jump` is applied instantly, `settle` follows it on a spring (shown angle = live + jump − settle).
    @State private var lapJump: Double = 0
    @State private var lapSettle: Double = 0
    @State private var totalJump: Double = 0
    @State private var totalSettle: Double = 0
    @State private var script: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        if ctx.isStill {
            _banked = State(initialValue: 42.18)
            _lapMark = State(initialValue: 38.6)
            _laps = State(initialValue: [LapEntry(id: 3, time: 11.42), LapEntry(id: 2, time: 14.86), LapEntry(id: 1, time: 12.32)])
        } else {
            _banked = State(initialValue: 0)
            _lapMark = State(initialValue: 0)
            _laps = State(initialValue: [])
        }
    }

    private var zh: Bool { ctx.language == .zh }
    private var rowSpring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    private func elapsed(at date: Date) -> Double {
        banked + (running ? max(0, date.timeIntervalSince(startDate)) : 0)
    }

    var body: some View {
        StudioScene(hint: L("Start, then tap Lap", "点开始，再点计圈"), ctx: ctx) {
            card
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 9.2, delay: 0.6) { runScript() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            SportEyebrowRow(
                title: zh ? "秒表 · 400 米间歇" : "Stopwatch · 400 m repeats",
                symbol: "stopwatch.fill",
                trailing: laps.isEmpty ? nil : (zh ? "第 \(laps.count + 1) 圈" : "Lap \(laps.count + 1)")
            )
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !running || ctx.isStill)) { timeline in
                face(total: elapsed(at: timeline.date))
            }
            lapList
            buttons
        }
        .padding(16)
        .frame(width: 290)
        .signatureCard()
    }

    // MARK: Dial + readout

    private func face(total: Double) -> some View {
        let lap = total - lapMark
        let clock = lapClock(total)
        let lapText = lapClock(lap)
        return HStack(spacing: 14) {
            ZStack {
                LapDialFace()
                LapHand(length: 22, width: 1.6, color: Color.white.opacity(0.45))
                    .rotationEffect(.degrees(total / 60 * 360 + totalJump))
                    .animation(nil, value: totalJump)
                    .rotationEffect(.degrees(-totalSettle))
                LapHand(length: 29, width: 2.4, color: Signature.accent)
                    .shadow(color: Signature.accent.opacity(0.7), radius: 4)
                    .rotationEffect(.degrees(lap / 10 * 360 + lapJump))
                    .animation(nil, value: lapJump)
                    .rotationEffect(.degrees(-lapSettle))
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().fill(Signature.ink).frame(width: 2.5, height: 2.5))
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(verbatim: clock.main)
                        .font(Signature.number(40))
                        .contentTransition(.numericText(value: Double(Int(total))))
                        .animation(.snappy(duration: 0.22), value: Int(total))
                    Text(verbatim: clock.cents)
                        .font(Signature.number(24))
                        .foregroundStyle(Signature.accentSoft)
                }
                .foregroundStyle(Color.white)
                Text(verbatim: (zh ? "本圈 " : "This lap ") + lapText.main + lapText.cents)
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Signature.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Laps

    private var lapList: some View {
        let rows = max(ctx.int("rows"), 2)
        let shown = Array(laps.prefix(rows))
        let times = laps.map(\.time)
        let tint = ctx.bool("tint")
        let best = tint && laps.count >= 2 ? times.min() : nil
        let worst = tint && laps.count >= 3 ? times.max() : nil
        let longest = max(times.max() ?? 1, 0.1)
        return VStack(spacing: 5) {
            ForEach(shown) { lap in
                LapRow(
                    lap: lap,
                    share: lap.time / longest,
                    mark: lap.time == best ? .best : (lap.time == worst ? .worst : .none),
                    zh: zh
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.86, anchor: .top)),
                    removal: .opacity
                ))
            }
            if shown.count < rows {
                ForEach(shown.count..<rows, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(height: 26)
                        .id("empty-\(index)")
                        .transition(.opacity)
                }
            }
        }
        .frame(height: CGFloat(rows) * 31 - 5, alignment: .top)
        .clipped()
    }

    private var buttons: some View {
        let canReset = !running && (banked > 0 || !laps.isEmpty)
        return HStack(spacing: 10) {
            Button(action: { userSecondary() }) {
                Text(verbatim: canReset ? (zh ? "复位" : "Reset") : (zh ? "计圈" : "Lap"))
                    .contentTransition(.opacity)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(running || canReset ? 1 : 0.35))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            }
            Button(action: { userPrimary() }) {
                HStack(spacing: 6) {
                    Image(systemName: running ? "stop.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                    Text(verbatim: running ? (zh ? "停止" : "Stop") : (zh ? "开始" : "Start"))
                        .contentTransition(.opacity)
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(running ? Color.white : Signature.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    Capsule().fill(running ? AnyShapeStyle(Color(hex: 0xFF4D3D).opacity(0.85)) : AnyShapeStyle(Signature.accentGradient))
                }
                .shadow(color: (running ? Color(hex: 0xFF4D3D) : Signature.accent).opacity(0.4), radius: 9, y: 4)
            }
        }
        .buttonStyle(SportPressStyle(scale: 0.95, dim: 0.05))
    }

    // MARK: Actions

    private func userPrimary() {
        script?.cancel()
        Haptics.tap(.medium)
        toggleRun()
    }

    private func userSecondary() {
        script?.cancel()
        if running {
            Haptics.tap(.rigid)
            lap()
        } else if banked > 0 || !laps.isEmpty {
            Haptics.tap(.light)
            reset()
        }
    }

    private func toggleRun() {
        if running {
            banked += Date().timeIntervalSince(startDate)
            withAnimation(.snappy(duration: 0.25)) { running = false }
        } else {
            startDate = Date()
            withAnimation(.snappy(duration: 0.25)) { running = true }
        }
    }

    /// Signed shortest way home for a hand showing `degrees`.
    private func homeward(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped > 180 ? wrapped - 360 : wrapped
    }

    private func lap() {
        guard running else { return }
        let total = elapsed(at: Date())
        let time = total - lapMark
        guard time > 0.05 else { return }
        let swing = homeward(time / 10 * 360)
        // The live angle drops to zero with the mark: keep the hand where it is, then let it swing home.
        lapMark = total
        lapJump += swing
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { lapSettle += swing }
        withAnimation(rowSpring) {
            laps.insert(LapEntry(id: (laps.first?.id ?? 0) + 1, time: time), at: 0)
        }
    }

    private func reset() {
        guard !running else { return }
        let lapSwing = homeward((banked - lapMark) / 10 * 360)
        let totalSwing = homeward(banked / 60 * 360)
        banked = 0
        lapMark = 0
        lapJump += lapSwing
        totalJump += totalSwing
        withAnimation(.spring(response: 0.55, dampingFraction: 0.66)) {
            lapSettle += lapSwing
            totalSettle += totalSwing
        }
        withAnimation(.smooth(duration: 0.3)) { laps = [] }
    }

    private func runScript() {
        script?.cancel()
        script = Task { @MainActor in
            if running { toggleRun() }
            reset()
            guard await studioPause(0.5) else { return }
            toggleRun()
            for gap in [1.25, 1.9, 0.95, 1.5] {
                guard await studioPause(gap) else { return }
                lap()
            }
            guard await studioPause(0.9), running else { return }
            toggleRun()
        }
    }
}

// MARK: - Pieces

private enum LapMark {
    case none, best, worst
}

private struct LapRow: View {
    let lap: LapEntry
    let share: Double
    let mark: LapMark
    let zh: Bool

    private var tint: Color {
        switch mark {
        case .best: return Signature.lime
        case .worst: return Color(hex: 0xFF6B5E)
        case .none: return Color.white
        }
    }

    var body: some View {
        let clock = lapClock(lap.time)
        HStack(spacing: 8) {
            Text(verbatim: zh ? "第 \(lap.id) 圈" : "Lap \(lap.id)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 50, alignment: .leading)
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(mark == .none ? AnyShapeStyle(Color.white.opacity(0.35)) : AnyShapeStyle(tint))
                            .frame(width: max(4, proxy.size.width * share))
                    }
            }
            .frame(height: 4)
            if mark != .none {
                Text(verbatim: mark == .best ? (zh ? "最快" : "Best") : (zh ? "最慢" : "Slow"))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(Signature.ink)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(tint))
                    .transition(.scale.combined(with: .opacity))
            }
            Text(verbatim: clock.main + clock.cents)
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.06)))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: mark)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: share)
    }
}

private struct LapHand: View {
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length + 7)
            .offset(y: -(length - 7) / 2)
    }
}

/// 50 ticks, one per 0.2 s of the lap hand's 10 s turn.
private struct LapDialFace: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.width / 2 - 1
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.05)))
            for index in 0..<50 {
                let major = index % 5 == 0
                let angle = Double(index) / 50 * 2 * .pi - .pi / 2
                let inner = outer - (major ? 7 : 3.5)
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner, y: center.y + CGFloat(sin(angle)) * inner))
                tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer, y: center.y + CGFloat(sin(angle)) * outer))
                context.stroke(tick, with: .color(Color.white.opacity(major ? 0.7 : 0.25)), style: StrokeStyle(lineWidth: major ? 1.6 : 1, lineCap: .round))
            }
        }
    }
}
