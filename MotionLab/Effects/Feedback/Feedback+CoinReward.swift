import SwiftUI

// MARK: - Coin reward

extension Effect {
    static let feedbackCoinReward = Effect(
        id: "feedback.coin-reward",
        category: .feedback,
        interaction: .tap,
        name: L("Coin Reward", "金币奖励"),
        summary: L("Coins burst from a gift, hang for a beat, then arc one by one into a counter that ticks and bumps on each arrival.", "金币从礼物里迸出，悬停一拍，再逐枚划弧飞入计数器，每到一枚就跳数、弹一下。"),
        prompt: L(
            "A reward card with a gift tile and a coin counter in its top-right corner. On tap the tile squashes to 86% and rebounds, and ten gold coins burst upward into a loose cloud reaching up to 78 pt, 20 ms apart, each overshooting its spot on an ease-out-back over 0.42 s while spinning about its vertical axis. They hover and bob for a moment, then leave in order, 60 ms apart: each one flies a curved path to the counter in 0.5 s, accelerating, shrinking to 55% and spinning faster, with a faint trail. Every arrival adds 10 with rolling digits, bumps the counter to 114% on a spring (response 0.3 s, damping 0.45), flashes a gold ring and ticks a light haptic; the last one lands with a success haptic. Greedy, juicy, game-like.",
            "奖励卡片上有一枚礼物方块，右上角是金币计数器。点击后方块压到 86% 再回弹，十枚金币向上迸成一团，最远 78 pt，彼此间隔 20 毫秒，各自在 0.42 秒内以回弹缓出越过落点再回位，同时绕竖轴旋转。悬停起伏片刻后依次出发，间隔 60 毫秒：每枚沿弧线在 0.5 秒内加速飞向计数器，缩小到 55%，越转越快，带一道淡淡拖尾。每到一枚，数字滚动加 10，计数器以弹簧（响应 0.3 秒、阻尼 0.45）鼓到 114%，闪过金环并伴随轻触感；最后一枚落定时触发成功触感。贪心、多汁、像游戏。"
        ),
        implementation: L(
            "Coins are value records with a birth time, scatter point and departure time; a TimelineView-driven Canvas places each one from its age (burst, hover, then a quadratic Bézier flight) and fakes the spin by scaling the coin's width with a cosine. One task per coin fires at its arrival time to add to the counter and trigger the bump keyframes.",
            "金币是带出生时间、散开落点与出发时间的值记录；由 TimelineView 驱动的 Canvas 按“年龄”摆放每一枚（迸出、悬停，再沿二次贝塞尔飞行），并用余弦缩放宽度来模拟旋转。每枚金币各有一个任务在到达时刻触发，给计数器加数并启动弹跳关键帧。"
        ),
        apis: ["Canvas", "TimelineView(.animation(minimumInterval:paused:))", "keyframeAnimator(initialValue:trigger:)", "contentTransition(.numericText)", "Path.addQuadCurve"],
        tags: ["coins", "reward", "collect", "counter", "金币", "奖励", "收集", "计数"],
        params: [
            .slider("coins", L("Coins", "金币数"), 4...16, default: 10, step: 1, decimals: 0),
            .slider("spread", L("Burst spread", "迸发范围"), 40...110, default: 78, decimals: 0, unit: "pt"),
            .slider("stagger", L("Collect stagger", "收集间隔"), 0.02...0.12, default: 0.06, unit: "s"),
            .slider("flight", L("Flight time", "飞行时长"), 0.3...0.9, default: 0.5, unit: "s"),
        ]
    ) { ctx in
        CoinRewardDemo(ctx: ctx)
    }
}

private struct RewardCoin: Identifiable {
    let id: Int
    /// When the coin leaves the gift.
    let born: Double
    /// When it starts flying to the counter.
    let depart: Double
    let flight: Double
    let scatter: CGPoint
    let phase: Double
    let size: CGFloat
}

private struct CoinRewardDemo: View {
    let ctx: DemoContext
    @State private var coins: [RewardCoin]
    @State private var total: Int
    @State private var bumps = 0
    @State private var presses = 0
    @State private var nextID = 0

    private static let origin = CGPoint(x: 150, y: 176)
    private static let target = CGPoint(x: 199, y: 37)
    private static let burst: Double = 0.42
    private static let stillNow: Double = 100

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the coins hanging in the air.
        var seeded: [RewardCoin] = []
        if ctx.isStill {
            for index in 0..<10 {
                seeded.append(Self.makeCoin(id: -1 - index, index: index, count: 10, now: Self.stillNow - 0.6, spread: 78, stagger: 0.06, flight: 0.5))
            }
        }
        _coins = State(initialValue: seeded)
        _total = State(initialValue: 1240)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                card
                coinLayer
            }
            .frame(width: 300, height: 300)
            DemoHint(text: L("Tap the gift", "点击礼物"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.4) { claim() }
    }

    // MARK: Scene

    private var card: some View {
        let zh = ctx.language == .zh
        return ZStack {
            counter
                .position(x: 232, y: 37)
            Button(action: claim) {
                giftTile
            }
            .buttonStyle(.plain)
            .position(x: Self.origin.x, y: Self.origin.y)
            VStack(spacing: 2) {
                Text(zh ? "每日奖励" : "Daily reward")
                    .font(.subheadline.weight(.semibold))
                Text(zh ? "点击领取金币" : "Tap to collect coins")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .position(x: 150, y: 256)
        }
        .frame(width: 300, height: 300)
        .demoCard(cornerRadius: 26)
    }

    private var giftTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFF9A5C), Color(hex: 0xFF4D7A)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)], startPoint: .top, endPoint: .center))
            Image(systemName: "gift.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: Color(hex: 0xB3243F).opacity(0.5), radius: 3, y: 2)
        }
        .frame(width: 88, height: 88)
        .shadow(color: Color(hex: 0xFF4D7A).opacity(0.4), radius: 16, y: 8)
        .keyframeAnimator(initialValue: CoinGiftPose(), trigger: presses) { content, pose in
            content
                .scaleEffect(x: pose.scale + (1 - pose.scale) * 0.5, y: pose.scale, anchor: .bottom)
                .offset(y: pose.lift)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.86, duration: 0.09)
                CubicKeyframe(1.08, duration: 0.14)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
            KeyframeTrack(\.lift) {
                LinearKeyframe(0, duration: 0.09)
                CubicKeyframe(-9, duration: 0.14)
                SpringKeyframe(0, duration: 0.4, spring: .bouncy)
            }
        }
    }

    private var counter: some View {
        HStack(spacing: 7) {
            CoinFace()
                .frame(width: 22, height: 22)
            Text(verbatim: total.formatted(.number.grouping(.automatic)))
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(value: Double(total)))
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .frame(width: 104, height: 36)
        .background(Color.primary.opacity(0.07), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color(hex: 0xFFC247), lineWidth: 2)
                .keyframeAnimator(initialValue: 0.0, trigger: bumps) { content, flash in
                    content.opacity(flash)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(0.9)
                        LinearKeyframe(0.0, duration: 0.35, timingCurve: .easeOut)
                    }
                }
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: bumps) { content, bump in
            content.scaleEffect(bump)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.14, duration: 0.07)
                SpringKeyframe(1, duration: 0.4, spring: Spring(response: 0.3, dampingRatio: 0.45))
            }
        }
    }

    private var coinLayer: some View {
        let still: Bool = ctx.isStill
        return TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: coins.isEmpty || still)) { timeline in
            let now: Double = still ? Self.stillNow : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                for coin in coins {
                    CoinPainter.draw(coin, now: now, origin: Self.origin, target: Self.target, burst: Self.burst, in: &context)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Sequence

    private static func makeCoin(id: Int, index: Int, count: Int, now: Double, spread: Double, stagger: Double, flight: Double) -> RewardCoin {
        let noise: Double = abs(sin(Double(id) * 12.9898 + 2.3))
        let noise2: Double = abs(sin(Double(id) * 78.233 + 0.7))
        let fan: Double = count > 1 ? Double(index) / Double(count - 1) - 0.5 : 0
        let angle: Double = -Double.pi / 2 + fan * 2.7 + (noise - 0.5) * 0.5
        // Alternate near and far so the burst is a cloud, not a single arc.
        let radius: Double = spread * ((index % 2 == 0 ? 0.72 : 0.36) + 0.28 * noise2)
        let born: Double = now + Double(index) * 0.02
        return RewardCoin(
            id: id,
            born: born,
            depart: now + burst + 0.2 + Double(index) * stagger,
            flight: flight,
            scatter: CGPoint(x: cos(angle) * radius * 1.25, y: sin(angle) * radius - 34),
            phase: noise * 6.28,
            size: 21 + CGFloat(noise2) * 5
        )
    }

    private func claim() {
        let count: Int = max(ctx.int("coins"), 1)
        let now: Double = Date().timeIntervalSinceReferenceDate
        let flight: Double = ctx["flight"]
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        if buzz { Haptics.tap(.medium) }
        presses += 1
        for index in 0..<count {
            let coin = Self.makeCoin(id: nextID, index: index, count: count, now: now, spread: ctx["spread"], stagger: ctx["stagger"], flight: flight)
            nextID += 1
            coins.append(coin)
            let isLast: Bool = index == count - 1
            let wait: Double = coin.depart + coin.flight - now
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(wait))
                coins.removeAll { $0.id == coin.id }
                withAnimation(.snappy(duration: 0.18)) { total += 10 }
                bumps += 1
                guard buzz else { return }
                if isLast { Haptics.success() } else { Haptics.tap(.light) }
            }
        }
    }
}

private struct CoinGiftPose {
    var scale: CGFloat = 1
    var lift: CGFloat = 0
}

/// The static coin in the counter.
private struct CoinFace: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xF5A623)], startPoint: .top, endPoint: .bottom))
            Circle()
                .strokeBorder(Color(hex: 0xC77D0A).opacity(0.7), lineWidth: 1)
            Circle()
                .strokeBorder(Color(hex: 0xFFF3C4).opacity(0.8), lineWidth: 1)
                .padding(3.5)
            Image(systemName: "star.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color(hex: 0xC77D0A))
        }
    }
}

private enum CoinPainter {
    static func draw(_ coin: RewardCoin, now: Double, origin: CGPoint, target: CGPoint, burst: Double, in context: inout GraphicsContext) {
        let age: Double = now - coin.born
        guard age >= 0 else { return }
        let rest = CGPoint(x: origin.x + coin.scatter.x, y: origin.y + coin.scatter.y)
        let point: CGPoint
        let scale: CGFloat
        var spin: Double = coin.phase + age * 7
        var flying: Double = 0

        if now < coin.depart {
            // Burst with an ease-out-back overshoot, then hover with a slow bob.
            let u: Double = min(age / burst, 1)
            let c: Double = 1.9
            let back: Double = 1 + (c + 1) * pow(u - 1, 3) + c * pow(u - 1, 2)
            let bob: Double = sin(age * 5 + coin.phase) * 2.5 * min(max(age - burst, 0) / 0.2, 1)
            point = CGPoint(x: origin.x + coin.scatter.x * CGFloat(back), y: origin.y + coin.scatter.y * CGFloat(back) + CGFloat(bob))
            scale = CGFloat(0.35 + 0.65 * min(u * 2.2, 1))
        } else {
            let u: Double = min((now - coin.depart) / coin.flight, 1)
            let eased: Double = pow(u, 2.2)
            flying = u
            point = bezier(from: rest, to: target, t: eased)
            scale = CGFloat(1 - 0.45 * eased)
            spin += pow(now - coin.depart, 2) * 22
            // A faint trail behind the flying coin.
            for step in 1...4 {
                let past: Double = max(eased - Double(step) * 0.05, 0)
                let trail: CGPoint = bezier(from: rest, to: target, t: past)
                let r: CGFloat = coin.size * scale * 0.5 * CGFloat(1 - Double(step) * 0.18)
                context.fill(
                    Path(ellipseIn: CGRect(x: trail.x - r, y: trail.y - r, width: r * 2, height: r * 2)),
                    with: .color(Color(hex: 0xFFC247).opacity(0.16 * u * (1 - Double(step) * 0.2)))
                )
            }
        }

        let h: CGFloat = coin.size * scale
        let turn: Double = cos(spin)
        let w: CGFloat = max(h * CGFloat(abs(turn)), h * 0.16)
        let rect = CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h)

        // Contact shadow that shrinks as the coin flies off.
        let shadow = CGRect(x: point.x - w * 0.42, y: point.y + h * 0.5 + 3, width: w * 0.84, height: 4)
        context.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.16 * (1 - flying))))

        // The edge, seen when the coin is turned.
        let edge = rect.offsetBy(dx: turn > 0 ? 1.4 : -1.4, dy: 0)
        context.fill(Path(ellipseIn: edge), with: .color(Color(hex: 0xC77D0A)))
        context.fill(
            Path(ellipseIn: rect),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFEFA0), Color(hex: 0xF5A623)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
        context.stroke(Path(ellipseIn: rect.insetBy(dx: w * 0.17, dy: h * 0.17)), with: .color(Color(hex: 0xFFF7D6).opacity(0.85)), lineWidth: 1)
        // A glint when the face passes the light.
        let glint: Double = max(turn, 0)
        context.fill(
            Path(ellipseIn: CGRect(x: rect.midX - w * 0.26, y: rect.minY + h * 0.12, width: w * 0.3, height: h * 0.22)),
            with: .color(.white.opacity(0.55 * glint * glint))
        )
    }

    /// A path that first swings outward and up, then drops into the counter.
    private static func bezier(from start: CGPoint, to end: CGPoint, t: Double) -> CGPoint {
        let control = CGPoint(x: start.x + (end.x - start.x) * 0.15 - 26, y: min(start.y, end.y) - 34)
        let u: CGFloat = CGFloat(t)
        let a: CGFloat = (1 - u) * (1 - u)
        let b: CGFloat = 2 * (1 - u) * u
        let c: CGFloat = u * u
        return CGPoint(x: a * start.x + b * control.x + c * end.x, y: a * start.y + b * control.y + c * end.y)
    }
}
