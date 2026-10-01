import SwiftUI

// MARK: - Thread refresh

extension Effect {
    static let feedbackThreadRefresh = Effect(
        id: "feedback.thread-refresh",
        category: .feedback,
        interaction: .gesture,
        name: L("Plucked Thread Refresh", "拨弦下拉刷新"),
        summary: L("The pull stretches a thread by a bead until it slips free: the thread twangs like a plucked string and the bead becomes the spinner.", "下拉用一颗珠子把细线越拉越紧，直到滑脱：细线像拨动的琴弦一样震颤，珠子变成加载圈。"),
        prompt: L(
            "A thread is strung across the top of a list between two pins, with an 18 pt ring bead at its middle. Pulling the list drags the bead down and bends the thread into a taut V; as tension builds the thread thins from 3.2 pt to 1.8 pt and shifts from indigo to pink. At the 80 pt threshold the bead slips off with a rigid haptic and the thread is let go from 56 pt of deflection: it vibrates as a real plucked string, its first three odd harmonics ringing at 7, 21 and 35 Hz and dying away at 5 per second, higher ones faster. The freed bead pops to 135% and opens into a spinning arc while the list holds at 70 pt. When loading ends a new row slides in, the list springs home and a success haptic plays. Tense, musical, physical.",
            "列表顶部两枚小钉之间绷着一根细线，中点穿着一颗 18 pt 的环形珠子。下拉时珠子被向下带动，把细线拉成紧绷的 V 形；张力越大线越细（3.2 pt 到 1.8 pt），颜色从靛蓝渐变为粉色。到达 80 pt 阈值，珠子滑脱并伴随硬朗触感，细线从 56 pt 的偏移处被放开：像真实的拨弦一样振动，前三个奇次谐波以 7、21、35 Hz 鸣响，以每秒 5 的速率衰减，高次更快。脱开的珠子鼓到 135%，张开成旋转的弧线，列表停在 70 pt。加载结束后新条目滑入，列表弹回并触发成功触感。紧绷、有乐感、有物理质感。"
        ),
        implementation: L(
            "The thread is a Shape whose three animatable amplitudes weight the first odd sine harmonics of a triangle; while pulling they all equal the deflection (a V), and after the snap a TimelineView sets each to a damped cosine at its own frequency. The pull comes from a downward-only UIPanGestureRecognizer that the page's scroll waits for.",
            "细线是一个 Shape，三个可动画的振幅分别加权三角波的前几个奇次正弦谐波；下拉时它们都等于偏移量（呈 V 形），滑脱后由 TimelineView 把每个振幅设为各自频率的阻尼余弦。下拉距离来自只接受向下拖动的 UIPanGestureRecognizer，页面滚动会等它失败。"
        ),
        apis: ["Shape", "AnimatablePair", "TimelineView(.animation(minimumInterval:paused:))", "UIGestureRecognizerRepresentable", "UIPanGestureRecognizer", "keyframeAnimator(initialValue:trigger:)"],
        tags: ["pull to refresh", "string", "elastic", "twang", "下拉刷新", "琴弦", "弹性", "震颤"],
        params: [
            .slider("duration", L("Refresh time", "刷新时长"), 0.6...3.0, default: 1.4, decimals: 1, unit: "s"),
            .slider("pitch", L("Twang pitch", "震颤频率"), 3...12, default: 7, decimals: 0, unit: "Hz"),
            .slider("decay", L("Twang decay", "震颤衰减"), 2...10, default: 5, decimals: 1, unit: "/s"),
        ]
    ) { ctx in
        ThreadRefreshHost(ctx: ctx)
    }
}

// MARK: - Host

private struct ThreadRefreshItem {
    let symbol: String
    let tint: Color
    let title: LocalizedText
    let detail: LocalizedText
}

private enum ThreadRefreshData {
    static let items: [ThreadRefreshItem] = [
        ThreadRefreshItem(symbol: "music.note", tint: Palette.pink, title: L("New release from Khruangbin", "Khruangbin 发布新专辑"), detail: L("12 tracks · out now", "12 首 · 现已上线")),
        ThreadRefreshItem(symbol: "guitars.fill", tint: Palette.indigo, title: L("Lesson 8: fingerpicking", "第 8 课：指弹"), detail: L("14 min · intermediate", "14 分钟 · 中级")),
        ThreadRefreshItem(symbol: "tuningfork", tint: Palette.mint, title: L("Tuner calibrated", "调音器已校准"), detail: L("A4 = 440 Hz", "A4 = 440 Hz")),
        ThreadRefreshItem(symbol: "waveform", tint: Palette.coral, title: L("Take 3 saved", "第 3 次录音已保存"), detail: L("0:48 · just now", "0:48 · 刚刚")),
        ThreadRefreshItem(symbol: "person.2.fill", tint: Palette.sky, title: L("Jam session on Friday", "周五合奏"), detail: L("Studio B · 7:30 pm", "B 号排练室 · 晚 7:30")),
        ThreadRefreshItem(symbol: "metronome.fill", tint: Palette.amber, title: L("Practice streak: 9 days", "已连续练习 9 天"), detail: L("Keep it going", "继续保持")),
    ]
}

/// A list with a pull area on top. The pull is a downward pan on the list, rubber-banded (see
/// `FeedbackRefreshList`); other directions scroll the page.
private struct ThreadRefreshHost: View {
    let ctx: DemoContext

    /// The finger's rubber-banded pull, reported by the list's pan.
    @State private var fingerPull: CGFloat = 0
    /// Extra shift of the rows: the scripted pull of previews and the hold height while refreshing.
    @State private var shift: CGFloat
    @State private var refreshing = false
    @State private var items: [Int] = [3, 2, 1, 0]
    @State private var nextItem = 4
    @State private var token = 0
    /// Set by a real pull, cleared by the autoplay: only a real pull plays haptics.
    @State private var userDriven = false

    private static let threshold: CGFloat = 80
    private static let holdHeight: CGFloat = 70

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the thread stretched, just short of the threshold.
        _shift = State(initialValue: ctx.isStill ? Self.threshold * 0.88 : 0)
    }

    private var pull: CGFloat { fingerPull + shift }
    private var live: Bool { !ctx.isPreview && !ctx.isStill }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                ThreadIndicator(
                    pull: pull,
                    threshold: Self.threshold,
                    refreshing: refreshing,
                    pitch: ctx["pitch"],
                    decay: ctx["decay"],
                    preview: ctx.isPreview,
                    buzz: userDriven && live
                )
                .frame(width: 300, height: max(pull, 1), alignment: .top)
                .clipped()
                FeedbackRefreshList(live: live, hold: shift, onPull: pullChanged, onRelease: release) {
                    list
                }
            }
            .frame(width: 300, height: 260, alignment: .top)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .demoCard(cornerRadius: 22)
            DemoHint(text: L("Pull the list down", "向下拖动列表"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 3.6, delay: 0.6) { simulate() }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                row(ThreadRefreshData.items[item % ThreadRefreshData.items.count])
                    .transition(
                        AnyTransition.asymmetric(
                            insertion: AnyTransition.move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
            Spacer(minLength: 0)
        }
        .frame(width: 300, height: 260, alignment: .top)
        .background(Palette.elevated)
    }

    private func row(_ item: ThreadRefreshItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title, ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.detail, ctx.language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 62)
        }
    }

    /// Every change of the finger's pull; `byFinger` is true while a finger is on the list.
    private func pullChanged(_ value: CGFloat, byFinger: Bool) {
        fingerPull = value
        if byFinger { userDriven = true }
    }

    /// Finger lifted (or the touch was cancelled), or the scripted pull ended: refresh if past the threshold.
    private func release() {
        guard !refreshing else { return }
        guard pull >= Self.threshold else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shift = 0 }
            return
        }
        // The finger's pull springs back while the shift grows to the hold height.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            refreshing = true
            shift = Self.holdHeight
        }
        let wait: Double = ctx["duration"]
        // Only a real pull buzzes; the autoplay's simulated pull stays silent.
        let buzz: Bool = live && userDriven
        token += 1
        let current = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            guard token == current else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                items.insert(nextItem, at: 0)
                if items.count > 4 { items.removeLast() }
                shift = 0
                refreshing = false
            }
            nextItem += 1
            if buzz { Haptics.success() }
        }
    }

    private func simulate() {
        guard !refreshing else { return }
        userDriven = false
        token += 1
        let current = token
        withAnimation(.easeOut(duration: 0.6)) { shift = Self.threshold * 0.62 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            guard token == current, !refreshing else { return }
            // Linger just under the threshold so the taut V reads, then pull through.
            withAnimation(.easeOut(duration: 0.5)) { shift = Self.threshold - 5 }
            try? await Task.sleep(for: .seconds(0.75))
            guard token == current, !refreshing else { return }
            withAnimation(.easeOut(duration: 0.25)) { shift = Self.threshold + 14 }
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            release()
        }
    }
}

// MARK: - Indicator

private struct ThreadIndicator: View {
    let pull: CGFloat
    let threshold: CGFloat
    let refreshing: Bool
    let pitch: Double
    let decay: Double
    let preview: Bool
    let buzz: Bool

    /// When the bead slipped off, and how far the thread was deflected at that instant.
    @State private var snapTime = Date.distantPast
    @State private var snapSag: CGFloat = 0
    @State private var ringing = false
    /// The bead has slipped off and stays free until the list is back home.
    @State private var slipped = false
    @State private var snaps = 0
    @State private var ringToken = 0

    /// Height of the pins the thread is strung between.
    private static let anchorY: CGFloat = 12
    /// How far above the list's top edge the bead rides.
    private static let beadGap: CGFloat = 12

    private var snapped: Bool { refreshing || pull >= threshold }
    private var beadY: CGFloat { max(pull - Self.beadGap, Self.anchorY) }
    private var sag: CGFloat { beadY - Self.anchorY }

    var body: some View {
        let tension: CGFloat = min(max(sag / (threshold - Self.beadGap - Self.anchorY), 0), 1)
        let held: Bool = !snapped && !slipped
        ZStack(alignment: .top) {
            thread(held: held, tension: tension)
            pins
            ThreadBead(spinning: !held, colour: held ? threadColour(tension) : Palette.indigo, preview: preview)
                .frame(width: 18, height: 18)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: snaps) { content, pop in
                    content.scaleEffect(pop)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(1.35, duration: 0.09)
                        SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                    }
                }
                .offset(y: beadY - 9)
        }
        .frame(width: 300, height: 90, alignment: .top)
        .opacity(pull > 6 ? 1 : 0)
        .onChange(of: snapped) { _, now in
            guard now, !slipped else { return }
            snap()
        }
        .onChange(of: pull < 8) { _, home in
            if home { slipped = false }
        }
    }

    private var pins: some View {
        HStack {
            Circle().frame(width: 5, height: 5)
            Spacer()
            Circle().frame(width: 5, height: 5)
        }
        .foregroundStyle(Color.primary.opacity(0.35))
        .frame(width: 249)
        .offset(y: Self.anchorY - 2.5)
    }

    @ViewBuilder
    private func thread(held: Bool, tension: CGFloat) -> some View {
        if held {
            // Bent by the bead: all three harmonics carry the same deflection, which sums to a V.
            ThreadShape(first: sag, third: sag, fifth: sag, anchorY: Self.anchorY)
                .stroke(threadColour(tension), style: StrokeStyle(lineWidth: 3.2 - 1.4 * tension, lineCap: .round, lineJoin: .round))
        } else {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !ringing)) { timeline in
                let t: Double = max(timeline.date.timeIntervalSince(snapTime), 0)
                ThreadShape(
                    first: mode(1, t: t),
                    third: mode(3, t: t),
                    fifth: mode(5, t: t),
                    anchorY: Self.anchorY
                )
                .stroke(Palette.indigo, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// Deflection carried by harmonic `n` at `t` seconds after the snap: a damped cosine at n × the pitch.
    private func mode(_ n: Double, t: Double) -> CGFloat {
        guard ringing else { return 0 }
        let damping: Double = exp(-decay * pow(n, 1.3) * t)
        let swing: Double = cos(2 * .pi * pitch * n * t)
        return snapSag * CGFloat(damping * swing)
    }

    private func threadColour(_ tension: CGFloat) -> Color {
        let t = Double(tension)
        // Indigo (0x6E7BFF) to pink (0xFF5FA2).
        return Color(
            .sRGB,
            red: (110 + (255 - 110) * t) / 255,
            green: (123 + (95 - 123) * t) / 255,
            blue: (255 + (162 - 255) * t) / 255,
            opacity: 1
        )
    }

    private func snap() {
        snapSag = max(sag, 40)
        snapTime = Date()
        ringing = true
        slipped = true
        snaps += 1
        if buzz { Haptics.tap(.rigid) }
        ringToken += 1
        let current = ringToken
        Task { @MainActor in
            // Pause the timeline once the string has died away.
            try? await Task.sleep(for: .seconds(1.6))
            guard ringToken == current else { return }
            ringing = false
        }
    }
}

/// A string between two pins, deflected by the first three odd harmonics of a triangle wave. With equal
/// amplitudes they sum to a V with its apex at `anchorY + amplitude`.
private struct ThreadShape: Shape {
    var first: CGFloat
    var third: CGFloat
    var fifth: CGFloat
    let anchorY: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(first, AnimatablePair(third, fifth)) }
        set {
            first = newValue.first
            third = newValue.second.first
            fifth = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 28
        let span: CGFloat = rect.width - inset * 2
        // Fourier weights of a triangle wave (1, −1/9, 1/25), normalised so the apex equals the amplitude.
        let norm: CGFloat = 1 + 1.0 / 9 + 1.0 / 25
        var path = Path()
        let steps = 56
        for step in 0...steps {
            let u: CGFloat = CGFloat(step) / CGFloat(steps)
            let a: CGFloat = sin(.pi * u)
            let b: CGFloat = -sin(3 * .pi * u) / 9
            let c: CGFloat = sin(5 * .pi * u) / 25
            var deflection: CGFloat = (first * a + third * b + fifth * c) / norm
            // The pins sit near the top edge, so the upward swing is kept short to stay inside the pull area.
            if deflection < 0 { deflection *= 0.3 }
            let point = CGPoint(x: rect.minX + inset + span * u, y: rect.minY + anchorY + deflection)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// The bead: a closed ring on the thread, an open spinning arc once it has slipped off.
private struct ThreadBead: View {
    let spinning: Bool
    let colour: Color
    let preview: Bool
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !spinning || isStill)) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate
            let turn: Double = spinning ? (t / 0.75 - (t / 0.75).rounded(.down)) * 360 : 0
            ZStack {
                Circle()
                    .fill(Palette.surface)
                Circle()
                    .trim(from: 0, to: spinning ? 0.72 : 1)
                    .stroke(colour, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(turn - 90))
            }
        }
        .animation(.easeOut(duration: 0.2), value: spinning)
    }
}
