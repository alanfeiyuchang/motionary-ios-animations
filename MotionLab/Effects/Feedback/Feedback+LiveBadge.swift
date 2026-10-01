import SwiftUI

// MARK: - Live badge

extension Effect {
    static let feedbackLiveBadge = Effect(
        id: "feedback.live-badge",
        category: .feedback,
        interaction: .loop,
        name: L("Live Badge", "直播中角标"),
        summary: L("A LIVE badge whose dot beats like a heart and sends out rings while the viewer count ticks up and down beside it.", "“直播中”角标里的圆点像心跳一样搏动、向外扩散光环，旁边的观看人数上下跳动。"),
        prompt: L(
            "A red LIVE capsule sits in the corner of a stream thumbnail. Its white dot beats on a 1.2 s heartbeat: a 22% swell that decays, then a softer 12% echo 28% into the cycle. Each beat releases a white ring that grows to 2.8× the dot while fading over the cycle. Beside it a dark chip shows the viewer count; every 0.9 s it changes by a small random amount with rolling digits, and a green '+12' or coral '−5' floats up 12 pt and fades in 0.7 s. Tapping ends the stream: the badge turns grey, the picture desaturates and dims, the count chip tucks away behind the badge. Tapping again goes live with a spring pop (response 0.4 s, damping 0.55), a ring sweeping across the picture and the count rolling up from zero.",
            "直播封面角落有一枚红色“直播中”胶囊。白色圆点按 1.2 秒的心跳搏动：先鼓起 22% 再衰减，周期 28% 处再来一次 12% 的回声。每次搏动放出一圈白环，一个周期内扩大到圆点的 2.8 倍并淡出。旁边的深色标签显示观看人数，每 0.9 秒随机小幅变化、数字滚动，一个绿色“+12”或珊瑚色“−5”上浮 12 pt，0.7 秒内淡出。点击结束直播：角标变灰，画面褪色变暗，人数标签收到角标后面。再点开播：角标以弹簧（响应 0.4 秒、阻尼 0.55）弹出，一圈光环扫过画面，人数从零滚上来。"
        ),
        implementation: L(
            "A TimelineView turns the time modulo the pulse period into the dot's scale (two exponential decays) and the rings' radius and opacity. A looping task changes the count inside an animation so numericText rolls it, and a keyframeAnimator keyed on a change counter floats the delta label.",
            "TimelineView 把时间对搏动周期取模，换算成圆点的缩放（两段指数衰减）以及光环的半径与透明度。循环任务在动画中修改人数，由 numericText 负责滚动；以变化计数为触发器的 keyframeAnimator 让增量标签上浮。"
        ),
        apis: ["TimelineView(.animation(minimumInterval:paused:))", "contentTransition(.numericText)", "keyframeAnimator(initialValue:trigger:)", "saturation", "spring(response:dampingFraction:)"],
        tags: ["live", "badge", "pulse", "viewers", "streaming", "直播", "角标", "脉冲", "观看人数", "心跳"],
        params: [
            .slider("period", L("Pulse period", "搏动周期"), 0.6...2.4, default: 1.2, decimals: 1, unit: "s"),
            .slider("reach", L("Ring reach", "光环范围"), 1.5...4.0, default: 2.8, decimals: 1, unit: "×"),
            .slider("tick", L("Count interval", "人数刷新间隔"), 0.4...2.0, default: 0.9, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        LiveBadgeDemo(ctx: ctx)
    }
}

private struct LiveBadgeDelta {
    var lift: CGFloat = 4
    var opacity: Double = 0
}

private struct LiveBadgeDemo: View {
    let ctx: DemoContext
    @State private var live = true
    @State private var viewers = 1284
    @State private var delta = 12
    @State private var changes = 0
    /// The ring that sweeps the picture when going live; `true` is its spread, invisible end state.
    @State private var sweep = true
    @State private var wentLive = Date.distantPast

    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                LiveBadgeVideo(preview: ctx.isPreview)
                    .saturation(live ? 1 : 0.15)
                    .overlay(Color.black.opacity(live ? 0 : 0.4))
                Circle()
                    .stroke(Color.white.opacity(sweep ? 0 : 0.7), lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .scaleEffect(sweep ? 22 : 1)
                    .offset(x: 14, y: 14)
                    .allowsHitTesting(false)
                HStack(spacing: 8) {
                    badge
                    viewerChip
                        .offset(x: live ? 0 : -46)
                        .opacity(live ? 1 : 0)
                        .scaleEffect(live ? 1 : 0.7, anchor: .leading)
                }
                .padding(14)
                footer
                    .frame(width: 300, height: 270, alignment: .bottomLeading)
            }
            .frame(width: 300, height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            DemoHint(text: L("Tap to end or start the stream", "点击结束或开始直播"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: LiveBadgeTicker(live: live, interval: ctx["tick"])) {
            guard live, !ctx.isStill else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(ctx["tick"]))
                guard !Task.isCancelled else { return }
                tickViewers()
            }
        }
    }

    // MARK: Badge

    private var badge: some View {
        HStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !live || ctx.isStill)) { timeline in
                let elapsed: Double = ctx.isStill ? ctx["period"] * 0.3 : timeline.date.timeIntervalSince(wentLive)
                LiveBadgeDot(elapsed: elapsed, period: ctx["period"], reach: ctx.cg("reach"), live: live)
            }
            .frame(width: 10, height: 10)
            Text(live ? (zh ? "直播中" : "LIVE") : (zh ? "未开播" : "OFFLINE"))
                .font(.caption.weight(.heavy))
                .kerning(zh ? 0 : 0.6)
                .contentTransition(.opacity)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background {
            ZStack {
                Capsule().fill(Color(white: 0.32))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0xFF5A6E), Color(hex: 0xE5213F)], startPoint: .top, endPoint: .bottom))
                    .opacity(live ? 1 : 0)
            }
        }
        .shadow(color: Color(hex: 0xFF2D4B).opacity(live ? 0.55 : 0), radius: 10, y: 2)
    }

    private var viewerChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "eye.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(verbatim: viewers.formatted(.number.grouping(.automatic)))
                .font(.caption.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText(value: Double(viewers)))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.black.opacity(0.42), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
        .overlay(alignment: .topTrailing) {
            Text(verbatim: delta >= 0 ? "+\(delta)" : "−\(-delta)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(delta >= 0 ? Color(hex: 0x6DF0A6) : Palette.coral)
                .fixedSize()
                .keyframeAnimator(initialValue: LiveBadgeDelta(), trigger: changes) { content, value in
                    content.offset(y: value.lift).opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.lift) {
                        MoveKeyframe(4)
                        CubicKeyframe(-8, duration: 0.7)
                        MoveKeyframe(4)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.12)
                        LinearKeyframe(1, duration: 0.28)
                        LinearKeyframe(0, duration: 0.3)
                    }
                }
                .offset(x: 26, y: 6)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Palette.sunset)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(zh ? "屋顶不插电现场" : "Rooftop acoustic set")
                    .font(.subheadline.weight(.semibold))
                Text(zh ? "夏树 · 第 3 首" : "Natsuki · song 3")
                    .font(.caption)
                    .opacity(0.75)
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: Actions

    private func tickViewers() {
        let change: Int = Int.random(in: -9...24)
        guard change != 0 else { return }
        delta = change
        changes += 1
        withAnimation(.snappy(duration: 0.35)) { viewers = max(viewers + change, 1) }
    }

    private func toggle() {
        Haptics.tap(.medium)
        if live {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { live = false }
            return
        }
        wentLive = Date()
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            sweep = false
            viewers = 0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { live = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.03))
            withAnimation(.easeOut(duration: 0.8)) { sweep = true }
            try? await Task.sleep(for: .seconds(0.25))
            // The audience pours in: the count climbs in eased steps so the digits keep rolling.
            let steps = 9
            for step in 1...steps {
                guard live else { return }
                let progress: Double = 1 - pow(1 - Double(step) / Double(steps), 2.4)
                withAnimation(.snappy(duration: 0.25)) { viewers = Int((1284 * progress).rounded()) }
                try? await Task.sleep(for: .seconds(0.09))
            }
        }
    }
}

private struct LiveBadgeTicker: Hashable {
    let live: Bool
    let interval: Double
}

/// The dot: a two-beat heartbeat and the rings each beat releases.
private struct LiveBadgeDot: View {
    let elapsed: Double
    let period: Double
    let reach: CGFloat
    let live: Bool

    var body: some View {
        let cycle: Double = max(period, 0.2)
        let p: Double = (elapsed / cycle).truncatingRemainder(dividingBy: 1)
        let phase: Double = p < 0 ? p + 1 : p
        let echo: Double = phase - 0.28
        let beat: Double = 0.22 * exp(-phase * 9) + (echo >= 0 ? 0.12 * exp(-echo * 12) : 0)
        ZStack {
            ring(phase)
            ring(echo >= 0 ? echo / 0.72 : 1)
                .opacity(0.6)
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .scaleEffect(live ? 1 + CGFloat(beat) : 0.8)
                .opacity(live ? 1 : 0.6)
        }
    }

    /// A ring released at a beat: `progress` 0 (at the dot) … 1 (fully spread and gone).
    private func ring(_ progress: Double) -> some View {
        let eased: Double = 1 - pow(1 - min(max(progress, 0), 1), 2.2)
        let scale: CGFloat = 1 + (reach - 1) * CGFloat(eased)
        return Circle()
            .stroke(Color.white.opacity(live ? 0.75 * (1 - eased) : 0), lineWidth: 1.4 / scale)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
    }
}

/// A warm stage: slow spotlights over a dark gradient, so the thumbnail feels like video.
private struct LiveBadgeVideo: View {
    let preview: Bool
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        TimelineView(.animation(minimumInterval: preview ? 1.0 / 20.0 : 1.0 / 30.0, paused: isStill)) { timeline in
            let t: Double = isStill ? 2 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(colors: [Color(hex: 0x1A1033), Color(hex: 0x3A1650), Color(hex: 0x7A2A4A)], startPoint: .top, endPoint: .bottom)
                spot(Color(hex: 0xFF8A3D), x: 70 * sin(t * 0.5), y: -30 + 16 * cos(t * 0.4), size: 190)
                spot(Color(hex: 0xB04BFF), x: -80 * cos(t * 0.37), y: 40 + 20 * sin(t * 0.6), size: 210)
                spot(Color(hex: 0xFFD27A), x: 20 + 30 * sin(t * 0.8), y: 70, size: 120)
                // The performer, as a simple silhouette.
                VStack(spacing: -6) {
                    Circle().frame(width: 44, height: 44)
                    Capsule().frame(width: 84, height: 120)
                }
                .foregroundStyle(Color.black.opacity(0.55))
                .offset(x: CGFloat(3 * sin(t * 1.3)), y: 78)
            }
        }
        .frame(width: 300, height: 270)
        .clipped()
    }

    private func spot(_ colour: Color, x: Double, y: Double, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [colour.opacity(0.75), colour.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .offset(x: CGFloat(x), y: CGFloat(y))
            .blendMode(.screen)
    }
}
