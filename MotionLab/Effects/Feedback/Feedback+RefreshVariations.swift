import SwiftUI

// MARK: - Shared pull-to-refresh host

private struct RefreshVarItem {
    let symbol: String
    let tint: Color
    let title: LocalizedText
    let detail: LocalizedText
}

private enum RefreshVarData {
    static let items: [RefreshVarItem] = [
        RefreshVarItem(symbol: "airplane", tint: Palette.sky, title: L("Flight MN 88 on time", "MN 88 航班准点"), detail: L("Gate B12 · boarding 9:40", "B12 登机口 · 9:40 登机")),
        RefreshVarItem(symbol: "cart.fill", tint: Palette.coral, title: L("Order shipped", "订单已发货"), detail: L("Arrives Thursday", "预计周四送达")),
        RefreshVarItem(symbol: "heart.fill", tint: Palette.pink, title: L("Mia liked your photo", "米娅赞了你的照片"), detail: L("2 min ago", "2 分钟前")),
        RefreshVarItem(symbol: "creditcard.fill", tint: Palette.mint, title: L("Refund received", "退款已到账"), detail: L("$42.00 to card •• 4242", "¥298.00 至尾号 4242")),
        RefreshVarItem(symbol: "calendar", tint: Palette.violet, title: L("Design review moved", "设计评审已改期"), detail: L("Friday · 3:00 pm", "周五 · 下午 3:00")),
        RefreshVarItem(symbol: "sun.max.fill", tint: Palette.amber, title: L("Clear skies today", "今日晴朗"), detail: L("High 24° · Low 15°", "最高 24° · 最低 15°")),
    ]
}

/// True while the current pull comes from a real finger (not the autoplay), so indicators may buzz.
private struct RefreshUserDrivenKey: EnvironmentKey {
    static let defaultValue = false
}

/// When the current (or last) refresh started and ended. Loading loops run on the time since the start, so
/// they begin from their resting pose instead of jumping to wherever absolute time puts them.
private struct RefreshClock: Equatable {
    var start: Date = .distantPast
    var end: Date = .distantPast
}

private struct RefreshClockKey: EnvironmentKey {
    static let defaultValue = RefreshClock()
}

private extension EnvironmentValues {
    var refreshUserDriven: Bool {
        get { self[RefreshUserDrivenKey.self] }
        set { self[RefreshUserDrivenKey.self] = newValue }
    }

    var refreshClock: RefreshClock {
        get { self[RefreshClockKey.self] }
        set { self[RefreshClockKey.self] = newValue }
    }
}

/// Seconds since the refresh started, clamped at zero.
private func refreshElapsed(_ date: Date, clock: RefreshClock) -> Double {
    max(date.timeIntervalSince(clock.start), 0)
}

/// 0 → 1 over the first quarter second of a refresh, so loops fade their motion in.
private func refreshRamp(_ elapsed: Double) -> Double {
    min(elapsed / 0.25, 1)
}

/// A list with a pull area on top: the pull is a downward pan on the list, rubber-banded (see
/// `FeedbackRefreshList`); other directions scroll the page. The indicator gets the pull progress (1 = armed), the raw pull height and whether a
/// refresh is running.
private struct RefreshVarHost<Indicator: View>: View {
    let ctx: DemoContext
    let threshold: CGFloat
    let holdHeight: CGFloat
    let indicator: (CGFloat, CGFloat, Bool) -> Indicator

    /// The finger's rubber-banded pull, reported by the list's pan.
    @State private var fingerPull: CGFloat = 0
    /// Extra shift of the rows: the scripted pull of previews and the hold height while refreshing.
    @State private var shift: CGFloat = 0
    @State private var refreshing = false
    @State private var clock = RefreshClock()
    @State private var armed = false
    @State private var items: [Int] = [3, 2, 1, 0]
    @State private var nextItem = 4
    @State private var token = 0
    /// Set by a real pull, cleared by the autoplay: only a real pull plays haptics.
    @State private var userDriven = false

    init(ctx: DemoContext, threshold: CGFloat = 80, holdHeight: CGFloat = 70, @ViewBuilder indicator: @escaping (CGFloat, CGFloat, Bool) -> Indicator) {
        self.ctx = ctx
        self.threshold = threshold
        self.holdHeight = holdHeight
        self.indicator = indicator
        // Still thumbnails show the indicator mid-pull, just short of the threshold.
        _shift = State(initialValue: ctx.isStill ? threshold * 0.85 : 0)
    }

    private var pull: CGFloat { fingerPull + shift }
    private var live: Bool { !ctx.isPreview && !ctx.isStill }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                indicator(min(pull / threshold, 1.2), pull, refreshing)
                    .frame(width: 300, height: max(pull, 1))
                    .clipped()
                    .environment(\.refreshUserDriven, userDriven && live)
                    .environment(\.refreshClock, clock)
                // A downward pan on the list is the pull; other directions scroll the page.
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
        .autoplay(ctx.isPreview, every: ctx["duration"] + 2.6, delay: 0.6) { simulate() }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                RefreshVarRow(item: RefreshVarData.items[item % RefreshVarData.items.count], language: ctx.language)
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

    /// Every change of the finger's pull; `byFinger` is true while a finger is on the list.
    private func pullChanged(_ value: CGFloat, byFinger: Bool) {
        fingerPull = value
        if byFinger { userDriven = true }
        guard !refreshing else { return }
        updateArmed(pull, buzz: byFinger)
    }

    private func updateArmed(_ value: CGFloat, buzz: Bool) {
        let nowArmed = value >= threshold
        guard nowArmed != armed else { return }
        armed = nowArmed
        if nowArmed && buzz && live { Haptics.tap(.medium) }
    }

    /// Finger lifted (or the touch was cancelled), or the scripted pull ended: refresh if armed. Otherwise the
    /// list springs home (the pull in `FeedbackRefreshList`, the shift here).
    private func release() {
        guard !refreshing else { return }
        guard pull >= threshold else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shift = 0 }
            armed = false
            return
        }
        clock.start = Date()
        // The finger's pull springs back while the shift grows to the hold height.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            refreshing = true
            shift = holdHeight
        }
        let wait = ctx["duration"]
        // Only a real pull buzzes; the autoplay's simulated pull stays silent.
        let buzz: Bool = live && userDriven
        token += 1
        let current = token
        Task {
            try? await Task.sleep(for: .seconds(wait))
            guard token == current else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                items.insert(nextItem, at: 0)
                if items.count > 4 { items.removeLast() }
                shift = 0
                refreshing = false
                clock.end = Date()
            }
            armed = false
            nextItem += 1
            if buzz { Haptics.success() }
        }
    }

    private func simulate() {
        guard !refreshing else { return }
        userDriven = false
        token += 1
        let current = token
        withAnimation(.easeOut(duration: 0.6)) { shift = threshold * 0.6 }
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            guard token == current, !refreshing else { return }
            withAnimation(.easeOut(duration: 0.4)) { shift = threshold + 16 }
            updateArmed(threshold + 16, buzz: false)
            try? await Task.sleep(for: .seconds(0.45))
            guard token == current else { return }
            release()
        }
    }
}

private struct RefreshVarRow: View {
    let item: RefreshVarItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title, language)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.detail, language)
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
}

// MARK: - Gum-drop refresh

extension Effect {
    static let feedbackGooRefresh = Effect(
        id: "feedback.goo-refresh",
        category: .feedback,
        interaction: .gesture,
        name: L("Gum-Drop Refresh", "黏滴下拉刷新"),
        summary: L("Pulling stretches a sticky drop until it snaps into a spinner.", "下拉把一颗黏稠的液滴越拉越长，直到“啪”地变成加载圈。"),
        prompt: L(
            "Pulling a notification list reveals an indigo gum drop: a 32 pt head holding a refresh arrow, joined by a tapering neck to a tail that follows the finger. As the rubber-banded pull grows the head shrinks to 22 pt, the tail thins from 32 pt to 10 pt and stretches up to 44 pt below, and the arrow turns with the pull. At the 80 pt threshold the neck snaps with a medium haptic: the drop is replaced by a 26 pt spinner that pops in on a bouncy spring while the list holds at 70 pt. When the refresh ends a new row slides in from the top, the list springs home and a success haptic plays. Stretchy, tactile, nostalgic.",
            "下拉通知列表时露出一颗靛蓝色“黏滴”：32 pt 的头部里有一个刷新箭头，通过一段渐细的颈部连着跟随手指的尾巴。随着带橡皮筋阻尼的下拉加大，头部缩到 22 pt，尾巴从 32 pt 细到 10 pt 并最多向下拉长 44 pt，箭头随下拉转动。到达 80 pt 阈值时颈部“啪”地断开，伴随中等触感：液滴被一枚 26 pt 的加载圈替代，以弹跳弹簧弹出，列表停在 70 pt。刷新结束后新条目从顶部滑入，列表弹回原位并触发成功触感。有弹性、有触感，带点怀旧。"
        ),
        implementation: L(
            "A Shape unions two circles and a quad-curve neck whose radii and separation are functions of the pull progress; a shared host reads the pull from a downward-only UIPanGestureRecognizer (UIGestureRecognizerRepresentable) that the page's scroll waits for, and handles the release, threshold haptic and row insertion.",
            "Shape 将两个圆与一段二次曲线颈部合并，半径与间距都是下拉进度的函数；共享的宿主视图从只接受向下拖动的 UIPanGestureRecognizer（UIGestureRecognizerRepresentable）读取下拉距离，页面滚动会等它失败，并负责松手判定、阈值触感与新条目插入。"
        ),
        apis: ["Shape", "Path.addQuadCurve", "Path.union", "UIGestureRecognizerRepresentable", "UIPanGestureRecognizer", "spring(response:dampingFraction:)"],
        tags: ["pull to refresh", "gooey", "stretch", "drop", "下拉刷新", "黏滴", "拉伸", "液滴"],
        params: [
            .slider("duration", L("Refresh time", "刷新时长"), 0.6...3.0, default: 1.4, decimals: 1, unit: "s"),
            .slider("stretch", L("Tail stretch", "尾巴拉伸"), 20...46, default: 44, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        RefreshVarHost(ctx: ctx) { progress, _, refreshing in
            GumDropIndicator(progress: progress, refreshing: refreshing, stretch: ctx.cg("stretch"), preview: ctx.isPreview)
        }
    }
}

private struct GumDropIndicator: View {
    let progress: CGFloat
    let refreshing: Bool
    let stretch: CGFloat
    let preview: Bool

    var body: some View {
        let p: CGFloat = min(max(progress, 0), 1)
        let snapped: Bool = refreshing || progress >= 1
        ZStack(alignment: .top) {
            if snapped {
                RefreshVarSpinner(color: Palette.indigo, preview: preview)
                    .frame(width: 26, height: 26)
                    .padding(.top, 22)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                GumDropShape(progress: p, stretch: stretch)
                    .fill(Palette.primary)
                    .frame(width: 60, height: 110)
                    .overlay(alignment: .top) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(Double(p) * 270))
                            .padding(.top, 20 - 5 * p)
                    }
                    .padding(.top, 8)
                    .opacity(p > 0.05 ? 1 : 0)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: snapped)
    }
}

private struct GumDropShape: Shape {
    var progress: CGFloat
    let stretch: CGFloat

    /// Animatable so an early release retracts the drop instead of snapping it away.
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Longest tail reach that still ends inside the 80 pt gap at the threshold: the head sits 24 pt down the gap
    /// (8 pt padding + 16 pt), the tail's radius is 5 pt there, and 4 pt stay free above the list.
    static let maxReach: CGFloat = 46

    func path(in rect: CGRect) -> Path {
        let cx: CGFloat = rect.midX
        let r1: CGFloat = 16 - 5 * progress
        let r2: CGFloat = 16 - 11 * progress
        let y1: CGFloat = rect.minY + 16
        let y2: CGFloat = y1 + min(stretch, Self.maxReach) * progress
        let mid: CGFloat = (y1 + y2) / 2
        let head = Path(ellipseIn: CGRect(x: cx - r1, y: y1 - r1, width: r1 * 2, height: r1 * 2))
        let tail = Path(ellipseIn: CGRect(x: cx - r2, y: y2 - r2, width: r2 * 2, height: r2 * 2))
        var neck = Path()
        neck.move(to: CGPoint(x: cx - r1, y: y1))
        neck.addQuadCurve(to: CGPoint(x: cx - r2, y: y2), control: CGPoint(x: cx - r2 * 0.5, y: mid))
        neck.addLine(to: CGPoint(x: cx + r2, y: y2))
        neck.addQuadCurve(to: CGPoint(x: cx + r1, y: y1), control: CGPoint(x: cx + r2 * 0.5, y: mid))
        neck.closeSubpath()
        // A boolean union (iOS 17+) merges the parts into one outline, so the overlaps can never cancel out
        // under the fill rule, whichever way each subpath winds.
        return head.union(tail).union(neck)
    }
}

private struct RefreshVarSpinner: View {
    let color: Color
    let preview: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview))) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(t.truncatingRemainder(dividingBy: 0.8) / 0.8 * 360))
        }
    }
}

// MARK: - Sunrise refresh

extension Effect {
    static let feedbackSunRefresh = Effect(
        id: "feedback.sun-refresh",
        category: .feedback,
        interaction: .gesture,
        name: L("Sunrise Refresh", "日出下拉刷新"),
        summary: L("The pull area becomes a dawn sky: the sun rises and its rays unfold with the pull.", "下拉区域变成黎明的天空：太阳随下拉升起，光芒逐渐展开。"),
        prompt: L(
            "Pulling a weather feed reveals a dawn scene in the gap: a sky gradient from sky blue to amber fades in with the pull, and a 26 pt sun rises 40 pt from behind a hairline horizon. Eight rays grow from 2 pt to 10 pt and the ray ring rotates 90° over the full pull, so the gesture itself feels like turning the morning on. At the 80 pt threshold a medium haptic confirms; on release the list holds at 70 pt while the rays spin once every 2 s and pulse in length, then the sun sinks as a new row slides in and the list springs home with a success haptic. Warm, narrative, optimistic.",
            "下拉天气信息流时，空隙里浮现一幅黎明景象：从天蓝到琥珀的天空渐变随下拉淡入，一轮 26 pt 的太阳从细细的地平线后升起 40 pt。八道光芒从 2 pt 伸展到 10 pt，光环在整个下拉过程中转动 90°，仿佛手势本身在“点亮清晨”。到达 80 pt 阈值时伴随中等触感；松手后列表停在 70 pt，光芒每 2 秒旋转一圈并伸缩脉动；刷新结束时太阳落下，新条目滑入，列表弹回并触发成功触感。温暖、有叙事感、乐观。"
        ),
        implementation: L(
            "The indicator maps pull progress to the sun's offset, the rays' length and rotation and the sky's opacity; while refreshing a TimelineView spins and pulses the rays.",
            "指示器把下拉进度映射为太阳的位移、光芒的长度与旋转以及天空的不透明度；刷新时由 TimelineView 让光芒旋转并脉动。"
        ),
        apis: ["LinearGradient", "TimelineView", "rotationEffect", "UIGestureRecognizerRepresentable"],
        tags: ["pull to refresh", "sun", "weather", "sunrise", "下拉刷新", "太阳", "天气", "日出"],
        params: [
            .slider("duration", L("Refresh time", "刷新时长"), 0.6...3.0, default: 1.6, decimals: 1, unit: "s"),
            .slider("rays", L("Rays", "光芒数"), 6...14, default: 8, step: 1, decimals: 0),
        ]
    ) { ctx in
        RefreshVarHost(ctx: ctx) { progress, pull, refreshing in
            // The sun stays fully risen while the list holds, instead of sagging to the hold height's 0.875.
            SunriseIndicator(progress: refreshing ? max(progress, 1) : progress, pull: pull, refreshing: refreshing, rays: max(ctx.int("rays"), 3), preview: ctx.isPreview)
        }
    }
}

private struct SunriseIndicator: View {
    let progress: CGFloat
    let pull: CGFloat
    let refreshing: Bool
    let rays: Int
    let preview: Bool
    @Environment(\.refreshClock) private var clock

    var body: some View {
        let p: CGFloat = min(max(progress, 0), 1)
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Palette.sky.opacity(0.55), Palette.amber.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .opacity(Double(p))
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !refreshing)) { timeline in
                sun(p: p, spin: spin(at: timeline.date), pulse: pulse(at: timeline.date))
            }
            .offset(y: 30 - 40 * p)
            Rectangle()
                .fill(Palette.coral.opacity(0.5))
                .frame(height: 1)
                .padding(.bottom, 10)
            Rectangle()
                .fill(Palette.elevated)
                .frame(height: 10)
        }
    }

    /// Angle between two rays: turning the ring by a multiple of it looks identical.
    private var pitch: Double { 360 / Double(max(rays, 1)) }

    /// Spin since the refresh started (one turn per 2 s, from 0, so it never jumps). Once the refresh ends the
    /// ring rests on the next whole ray pitch ahead, which looks the same as no spin and is reached by turning
    /// forward (see the scoped animation in `sun`).
    private func spin(at date: Date) -> Double {
        if refreshing {
            return refreshElapsed(date, clock: clock) / 2 * 360
        }
        let ran: Double = max(clock.end.timeIntervalSince(clock.start), 0) / 2 * 360
        return (ran / pitch).rounded(.up) * pitch
    }

    /// Ray-length pulse, ramped in over the first 0.25 s so the rays don't snap shorter as the refresh starts.
    private func pulse(at date: Date) -> CGFloat {
        guard refreshing else { return 1 }
        let e: Double = refreshElapsed(date, clock: clock)
        return CGFloat(1 - 0.2 * refreshRamp(e) * (0.5 - 0.5 * sin(e * 5)))
    }

    private func sun(p: CGFloat, spin: Double, pulse: CGFloat) -> some View {
        let length: CGFloat = (2 + 8 * p) * pulse
        // Starting a refresh resets the spin from a whole pitch to 0 (no visible change), so it must not animate;
        // ending one turns the ring forward to the next pitch with the list's spring.
        let spinAnimation: Animation? = refreshing ? nil : .spring(response: 0.5, dampingFraction: 0.84)
        return ZStack {
            ZStack {
                ForEach(0..<rays, id: \.self) { index in
                    Capsule()
                        .fill(Palette.amber)
                        .frame(width: 3, height: length)
                        .offset(y: -(19 + length / 2))
                        .rotationEffect(.degrees(Double(index) / Double(rays) * 360))
                }
            }
            .animation(spinAnimation) { content in
                content.rotationEffect(.degrees(spin))
            }
            .rotationEffect(.degrees(Double(p) * 90))
            Circle()
                .fill(LinearGradient(colors: [Palette.amber, Palette.coral], startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 26)
                .shadow(color: Palette.amber.opacity(0.6), radius: 8)
        }
        .frame(width: 70, height: 70)
    }
}

// MARK: - Letter rise refresh

extension Effect {
    static let feedbackLetterRefresh = Effect(
        id: "feedback.letter-refresh",
        category: .feedback,
        interaction: .gesture,
        name: L("Letter Rise Refresh", "逐字升起下拉刷新"),
        summary: L("The words 'Pull to refresh' rise letter by letter as you pull, then wave while loading.", "“下拉刷新”随下拉逐字升起，加载时像波浪一样起伏。"),
        prompt: L(
            "Pulling a list reveals 'PULL TO REFRESH' set in 15 pt heavy rounded caps with 3 pt tracking. Letters are scrubbed by the pull: letter i starts rising once the progress passes i / n × 0.75 and takes the next 25% of the pull to lift 14 pt into place, fading from 0% and scaling from 60% to 100%, so the phrase assembles left to right under the finger. Past the 80 pt threshold the letters turn from secondary gray to the indigo → pink gradient with a medium haptic. While refreshing they ripple in a sine wave — 4 pt amplitude, each letter 0.45 rad behind the previous — until the new row slides in. Typographic, playful, legible.",
            "下拉列表时露出“下拉即可刷新”字样（英文为 15 pt 粗圆体大写、字距 3 pt）。每个字由下拉进度直接驱动：第 i 个字在进度超过 i / n × 0.75 时开始升起，用接下来 25% 的下拉距离上升 14 pt 落位，同时从 0% 淡入、从 60% 放大到 100%，整句话就在手指下从左到右拼出来。超过 80 pt 阈值时，文字从次级灰色变为靛蓝 → 粉色渐变，并伴随中等触感。刷新期间文字以正弦波起伏——振幅 4 pt、每个字比前一个落后 0.45 弧度——直到新条目滑入。有排版美感、俏皮、清晰。"
        ),
        implementation: L(
            "Each character is its own Text in an HStack whose offset, opacity and scale are pure functions of the pull progress; a TimelineView adds the loading wave, and the gradient is applied as a foregroundStyle over the row.",
            "每个字符都是 HStack 中独立的 Text，其位移、透明度与缩放都是下拉进度的纯函数；TimelineView 叠加加载波浪，渐变通过 foregroundStyle 应用到整行。"
        ),
        apis: ["HStack", "TimelineView", "foregroundStyle(LinearGradient)", "tracking(_:)"],
        tags: ["pull to refresh", "typography", "letters", "wave", "下拉刷新", "文字", "逐字", "波浪"],
        params: [
            .slider("duration", L("Refresh time", "刷新时长"), 0.6...3.0, default: 1.5, decimals: 1, unit: "s"),
            .slider("rise", L("Rise distance", "上升距离"), 6...24, default: 14, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        RefreshVarHost(ctx: ctx) { progress, _, refreshing in
            LetterRiseIndicator(
                text: ctx.language == .zh ? "下拉即可刷新" : "PULL TO REFRESH",
                progress: progress,
                refreshing: refreshing,
                rise: ctx.cg("rise"),
                preview: ctx.isPreview
            )
        }
    }
}

private struct LetterRiseIndicator: View {
    let text: String
    let progress: CGFloat
    let refreshing: Bool
    let rise: CGFloat
    let preview: Bool
    @Environment(\.refreshClock) private var clock

    var body: some View {
        let letters: [String] = text.map { String($0) }
        let armed: Bool = progress >= 1 || refreshing
        let style: AnyShapeStyle = armed
            ? AnyShapeStyle(LinearGradient(colors: [Palette.indigo, Palette.pink], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.secondary)
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !refreshing)) { timeline in
            let e: Double = refreshElapsed(timeline.date, clock: clock)
            HStack(spacing: 0) {
                ForEach(0..<letters.count, id: \.self) { index in
                    letter(letters[index], index: index, count: letters.count, e: e)
                }
            }
            .foregroundStyle(style)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: armed)
    }

    /// `e` is the time since the refresh started; the wave's amplitude ramps in over 0.25 s so no letter jumps.
    private func letter(_ character: String, index: Int, count: Int, e: Double) -> some View {
        let start: CGFloat = CGFloat(index) / CGFloat(max(count, 1)) * 0.75
        let local: CGFloat = refreshing ? 1 : min(max((progress - start) / 0.25, 0), 1)
        let wave: CGFloat = refreshing ? -4 * CGFloat(sin(e * 7 - Double(index) * 0.45) * refreshRamp(e)) : 0
        return Text(character)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .tracking(3)
            .scaleEffect(0.6 + 0.4 * local)
            .opacity(Double(local))
            .offset(y: (1 - local) * rise + wave)
    }
}

// MARK: - Three-dot refresh

extension Effect {
    static let feedbackDotsRefresh = Effect(
        id: "feedback.dots-refresh",
        category: .feedback,
        interaction: .gesture,
        name: L("Three-Dot Refresh", "三点下拉刷新"),
        summary: L("Three dots click into place one per third of the pull, then bounce while loading.", "下拉每走完三分之一就“咔嗒”点亮一颗圆点，加载时三点跳动。"),
        prompt: L(
            "Pulling a list reveals three 10 pt dots spaced 18 pt apart. The pull is divided into thirds: as each third is completed its dot springs from 30% to full size (response 0.3 s, damping 0.5) and fills from a gray outline to solid indigo, violet and pink respectively, with a selection haptic tick per dot — the user can feel the count. Crossing the 80 pt threshold adds a medium haptic. While refreshing the dots hop 8 pt in a staggered half-sine wave every 0.6 s (0.12 s apart); when the refresh ends they shrink away as a new row slides in from the top. Countable, rhythmic, minimal.",
            "下拉列表时露出三颗 10 pt 的圆点，间距 18 pt。下拉距离被分成三段：每走完一段，对应的圆点就以弹簧（响应 0.3 秒、阻尼 0.5）从 30% 弹到满尺寸，并从灰色描边变为实心的靛蓝、紫罗兰、粉色，每颗伴随一次选择触感——用户能“数”出进度。越过 80 pt 阈值时再加一次中等触感。刷新期间三点以 0.6 秒周期、间隔 0.12 秒的错峰半正弦各自跳起 8 pt；刷新结束时它们缩小消失，新条目从顶部滑入。可数、有节奏、极简。"
        ),
        implementation: L(
            "The number of completed thirds is derived from the pull progress; each dot animates its lit state with a spring and onChange of the count plays a selection haptic. A TimelineView drives the loading hop.",
            "由下拉进度推导已完成的段数；每颗圆点以弹簧动画切换点亮状态，onChange 监听段数变化并播放选择触感。加载时的跳动由 TimelineView 驱动。"
        ),
        apis: ["onChange(of:)", "spring(response:dampingFraction:)", "TimelineView", "UISelectionFeedbackGenerator"],
        tags: ["pull to refresh", "dots", "steps", "haptic", "下拉刷新", "圆点", "分段", "触感"],
        params: [
            .slider("duration", L("Refresh time", "刷新时长"), 0.6...3.0, default: 1.4, decimals: 1, unit: "s"),
            .slider("hop", L("Hop height", "跳跃高度"), 2...16, default: 8, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        RefreshVarHost(ctx: ctx) { progress, _, refreshing in
            DotsRefreshIndicator(progress: progress, refreshing: refreshing, hop: ctx.cg("hop"), live: !ctx.isPreview)
        }
    }
}

private struct DotsRefreshIndicator: View {
    let progress: CGFloat
    let refreshing: Bool
    let hop: CGFloat
    let live: Bool
    @Environment(\.refreshUserDriven) private var userDriven
    @Environment(\.refreshClock) private var clock

    private let colors: [Color] = [Palette.indigo, Palette.violet, Palette.pink]

    var body: some View {
        let lit: Int = refreshing ? 3 : min(Int(progress * 3 + 0.0001), 3)
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: !live), paused: !refreshing)) { timeline in
            // Cycles since the refresh started: dot 0 lifts off from sin(0) = 0, the others wait their turn.
            let t: Double = refreshElapsed(timeline.date, clock: clock) / 0.6
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    dot(index, lit: index < lit, t: t)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: lit) { old, new in
            if new > old && live && userDriven && !refreshing { Haptics.selection() }
        }
    }

    private func dot(_ index: Int, lit: Bool, t: Double) -> some View {
        let raw: Double = t - Double(index) * 0.2
        let phase: Double = raw - floor(raw)
        let lift: CGFloat = refreshing && phase < 0.5 ? CGFloat(sin(phase * 2 * .pi)) : 0
        return Circle()
            .fill(lit ? colors[index] : Color.clear)
            .overlay { Circle().strokeBorder(lit ? Color.clear : Color.secondary.opacity(0.5), lineWidth: 1.5) }
            .frame(width: 10, height: 10)
            .scaleEffect(lit ? 1 : 0.3)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: lit)
            .offset(y: -hop * lift)
    }
}
