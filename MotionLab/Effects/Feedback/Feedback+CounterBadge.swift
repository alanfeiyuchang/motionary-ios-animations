import SwiftUI

// MARK: - Counter badge

extension Effect {
    static let feedbackCounterBadge = Effect(
        id: "feedback.counter-badge",
        category: .feedback,
        interaction: .tap,
        name: L("Elastic Counter Badge", "弹性计数角标"),
        summary: L("A badge that stretches to fit its digits, squashes and pops on every increment, and clears with a poof.", "角标随位数伸展，每次加数都压扁弹起，清零时“噗”地散开。"),
        prompt: L(
            "A red notification badge, 34 pt tall, sits on the corner of a 124 pt app icon. Each increment rolls the digits upward and plays a squash-and-stretch pop: the badge widens and flattens, peaks at 128% in 0.1 s, dips to 94% and settles on a bouncy spring while hopping 6 pt, and the icon rocks 5° in sympathy. When the count gains a digit (9 to 10, 99 to 99+) the capsule stretches sideways to its new width on a loose spring (response 0.35 s, damping 0.55), growing away from the icon's corner. Clearing swells the badge to 135% and dissolves it in 0.14 s while eight red puffs fly 26 to 42 pt outward, shrinking over 0.45 s inside an expanding ring, with a soft haptic. The next count springs back from zero. Elastic, cheeky, alive.",
            "红色通知角标高 34 pt，停在 124 pt 应用图标的一角。每次加数，数字向上滚动并做一次挤压拉伸的弹跳：角标先变宽变扁，0.1 秒内鼓到 128%，回落到 94%，再以弹跳弹簧停稳，同时跳起 6 pt，图标跟着晃 5°。位数增加时（9 到 10、99 到 99+），胶囊以较松的弹簧（响应 0.35 秒、阻尼 0.55）横向伸展，朝远离图标角的方向生长。清零时角标鼓到 135%，在 0.14 秒内消散，八团红色烟团向外飞出 26 到 42 pt，在扩散的圆环里用 0.45 秒缩小消失，伴随柔和触感。有弹性、俏皮、鲜活。"
        ),
        implementation: L(
            "The badge is a Capsule sized by its Text, so changing the count inside a spring stretches it; contentTransition(.numericText) rolls the digits, a keyframeAnimator keyed on a pop counter adds the squash, and a TimelineView feeds a 0 → 1 clock to the poof's puffs and ring.",
            "角标是由 Text 决定尺寸的 Capsule，在弹簧动画里改变数字就会被拉伸；contentTransition(.numericText) 负责滚动数字，以弹跳计数为触发器的 keyframeAnimator 叠加挤压，TimelineView 向“噗”的烟团与圆环输出 0 → 1 的时钟。"
        ),
        apis: ["contentTransition(.numericText(value:))", "keyframeAnimator(initialValue:trigger:)", "TimelineView(.animation)", "Capsule", "spring(response:dampingFraction:)", "fixedSize()"],
        tags: ["badge", "counter", "notification", "unread", "角标", "计数", "通知", "未读"],
        params: [
            .slider("pop", L("Pop scale", "弹跳缩放"), 1.0...1.6, default: 1.28),
            .slider("damping", L("Stretch damping", "伸展阻尼"), 0.3...1.0, default: 0.55),
            .slider("puffs", L("Poof puffs", "烟团数"), 4...14, default: 8, step: 1, decimals: 0),
            .choice("cap", L("Cap", "上限"), [L("9+", "9+"), L("99+", "99+"), L("999+", "999+")], default: 1),
        ]
    ) { ctx in
        CounterBadgeDemo(ctx: ctx)
    }
}

private struct CounterBadgePop {
    var scale: CGFloat = 1
    var squash: CGFloat = 0
    var hop: CGFloat = 0
}

private struct CounterBadgeDemo: View {
    let ctx: DemoContext
    @State private var count: Int
    @State private var poofing = false
    @State private var pops = 0
    @State private var poofAt = Date.distantPast
    @State private var autoStepIndex = 0
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Previews start empty and build up; the detail page and stills start with a count.
        _count = State(initialValue: ctx.isStill ? 12 : (ctx.isPreview ? 0 : 3))
    }

    private var cap: Int {
        switch ctx.int("cap") {
        case 0: return 9
        case 2: return 999
        default: return 99
        }
    }

    private var label: String {
        count > cap ? "\(cap)+" : "\(count)"
    }

    var body: some View {
        VStack(spacing: 30) {
            Button {
                add(1)
            } label: {
                icon
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            controls
            DemoHint(text: L("Tap the icon or the buttons", "点击图标或下方按钮"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.95, delay: 0.5) { autoStep() }
    }

    // MARK: Icon and badge

    private var icon: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x5AC8FA), Color(hex: 0x0A7AFF)], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0)], startPoint: .top, endPoint: .center))
                Image(systemName: "envelope.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 124, height: 124)
            .shadow(color: Color(hex: 0x0A7AFF).opacity(0.35), radius: 16, y: 9)
            .keyframeAnimator(initialValue: 0.0, trigger: pops) { content, rock in
                content.rotationEffect(.degrees(rock), anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(5.0, duration: 0.09)
                    CubicKeyframe(-2.5, duration: 0.12)
                    SpringKeyframe(0.0, duration: 0.35, spring: .bouncy)
                }
            }
            badge
                // Trailing edge anchored 14 pt outside the icon's corner, so the badge grows leftward.
                .offset(x: 16, y: -14)
        }
    }

    private var badge: some View {
        let pop: CGFloat = ctx.cg("pop")
        let visible: Bool = count > 0 && !poofing
        return ZStack {
            CounterBadgeBurstClock(start: poofAt, duration: 0.45, preview: ctx.isPreview) { clock in
                CounterBadgePoof(count: max(ctx.int("puffs"), 1), clock: clock)
            }
            .frame(width: 34, height: 34)
            Text(verbatim: label)
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(count)))
                .fixedSize()
                .padding(.horizontal, 9)
                .frame(minWidth: 34)
                .frame(height: 34)
                .background {
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: 0xFF6259), Color(hex: 0xFF2D55)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color(hex: 0xFF2D55).opacity(0.45), radius: 6, y: 3)
                }
                .keyframeAnimator(initialValue: CounterBadgePop(), trigger: pops) { content, value in
                    content
                        .scaleEffect(x: value.scale * (1 + value.squash), y: value.scale * (1 - value.squash))
                        .offset(y: value.hop)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(pop, duration: 0.1)
                        CubicKeyframe(0.94, duration: 0.12)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    }
                    KeyframeTrack(\.squash) {
                        CubicKeyframe(0.12, duration: 0.06)
                        CubicKeyframe(-0.08, duration: 0.1)
                        SpringKeyframe(0, duration: 0.4, spring: .bouncy)
                    }
                    KeyframeTrack(\.hop) {
                        CubicKeyframe(-6, duration: 0.1)
                        SpringKeyframe(0, duration: 0.45, spring: .bouncy)
                    }
                }
                .scaleEffect(poofing ? 1.35 : (count > 0 ? 1 : 0.01))
                .blur(radius: poofing ? 4 : 0)
                .opacity(visible ? 1 : 0)
        }
        .fixedSize()
    }

    // MARK: Controls

    private var controls: some View {
        let zh = ctx.language == .zh
        return HStack(spacing: 10) {
            chip(title: "+1") { add(1) }
            chip(title: "+10") { add(10) }
            chip(title: zh ? "全部已读" : "Mark read") { clear() }
        }
    }

    private func chip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(Palette.elevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.stroke))
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    /// The preview's script: 1, 2, 9, 10 (stretch), 99, 99+ (stretch), poof.
    private func autoStep() {
        guard ctx.isPreview else {
            // The detail page's arrival play: a single increment.
            add(1)
            return
        }
        let script: [Int] = [1, 1, 7, 1, 89, 1, 0]
        let step: Int = script[autoStepIndex % script.count]
        autoStepIndex += 1
        if step == 0 { clear() } else { add(step) }
    }

    private func add(_ amount: Int) {
        token += 1
        let appearing: Bool = count == 0 || poofing
        poofing = false
        let stretch = Animation.spring(response: 0.35, dampingFraction: appearing ? 0.5 : ctx["damping"])
        withAnimation(stretch) { count = min(count + amount, 9999) }
        // A badge that springs in from zero already bounces; the pop is for increments.
        if !appearing { pops += 1 }
        if !ctx.isPreview { Haptics.tap(.light) }
    }

    private func clear() {
        guard count > 0, !poofing else { return }
        token += 1
        let current = token
        withAnimation(.easeOut(duration: 0.14)) { poofing = true }
        poofAt = Date()
        if !ctx.isPreview { Haptics.tap(.soft) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard token == current else { return }
            // The badge is invisible now: drop the count without animating it.
            count = 0
            poofing = false
        }
    }
}

// MARK: - Poof

/// Feeds a 0 → 1 clock to `content` for `duration` seconds after `start` changes; the timeline is paused
/// the rest of the time, and `content` then gets 1 (finished).
private struct CounterBadgeBurstClock<Content: View>: View {
    let start: Date
    let duration: Double
    let preview: Bool
    @ViewBuilder let content: (Double) -> Content
    @State private var running = false

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !running)) { timeline in
            let t: Double = timeline.date.timeIntervalSince(start) / duration
            content(running ? min(max(t, 0), 1) : 1)
        }
        .task(id: start) {
            guard start != .distantPast else { return }
            running = true
            try? await Task.sleep(for: .seconds(duration + 0.05))
            guard !Task.isCancelled else { return }
            running = false
        }
    }
}

private struct CounterBadgePoof: View {
    let count: Int
    /// 0 → 1 over the 0.45 s poof.
    let clock: Double

    var body: some View {
        let live: Bool = clock > 0.001 && clock < 0.999
        let eased: Double = 1 - pow(1 - clock, 3)
        ZStack {
            Circle()
                .stroke(Color(hex: 0xFF2D55).opacity(0.7 * (1 - clock)), lineWidth: 3 * (1 - clock) + 0.5)
                .frame(width: 34 + 38 * eased, height: 34 + 38 * eased)
            ForEach(0..<count, id: \.self) { index in
                puff(index, eased: eased)
            }
        }
        .opacity(live ? 1 : 0)
        .allowsHitTesting(false)
    }

    private func puff(_ index: Int, eased: Double) -> some View {
        let noise: Double = abs(sin(Double(index) * 12.9898 + 1.1))
        let angle: Double = Double(index) / Double(count) * 2 * .pi + noise * 0.6
        let reach: Double = 26 + 16 * noise
        let size: CGFloat = CGFloat(10 + 8 * noise) * CGFloat(1 - clock * 0.8)
        return Circle()
            .fill(index % 2 == 0 ? Color(hex: 0xFF2D55) : Color(hex: 0xFF6B6B))
            .frame(width: size, height: size)
            .offset(x: CGFloat(cos(angle) * reach * eased), y: CGFloat(sin(angle) * reach * eased))
            .opacity(1 - clock * clock)
    }
}
