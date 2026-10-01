import SwiftUI

extension Effect {
    static let cardsStampCard = Effect(
        id: "cards.stamp-card",
        category: .cards,
        interaction: .tap,
        name: L("Stamp Card", "集章卡"),
        summary: L("Each tap slams an ink stamp onto a loyalty card with a splatter and a jolt; the eighth one flips the card to its reward.", "每点一下，就有一枚印章砸在积分卡上，溅出墨点、卡片一震；盖满第八枚，卡片翻面亮出奖励。"),
        prompt: L(
            "A cream 264×166 pt loyalty card with eight dashed 36 pt slots in two rows. Each tap stamps the next slot: an ink ring with a cup glyph drops from 240% scale and zero opacity to 100% in 0.16 s on a steep ease-in, landing at a random tilt of up to ±12°. At impact the card jolts (scale 97.5%, a 0.8° twist, spring back), seven ink droplets shoot 3 to 11 pt past the ring in 0.22 s and stay as specks, and a rigid haptic fires. When the eighth stamp lands the card waits 350 ms, then flips about its vertical axis on a spring (response 0.62 s, damping 0.7), lifting 8% at mid-turn, to a gold reward side: a highlight sweeps across it in 0.8 s, six sparkles pop outward, and a success haptic plays. The next tap flips it back and clears the stamps.",
            "264×166 pt的米色积分卡上有两排共八个36 pt的虚线圆位。每点一下盖一枚：带杯子图案的墨环从240%、完全透明落到100%，用时0.16秒、陡峭缓入，带最多±12°的随机倾斜。落印瞬间卡片一震（缩到97.5%、拧0.8°），七滴墨点在0.22秒内溅出墨环3到11 pt并留在纸上，伴随清脆触感。第八枚落下后，停顿350毫秒，再以弹簧（响应0.62秒、阻尼0.7）绕纵轴翻面，中途抬高8%，亮出金色奖励面：高光用0.8秒扫过，六颗星芒迸出，并有成功触感。再点一下，翻回并清空。"
        ),
        implementation: L(
            "Stamps are inserted with a scale-and-opacity transition under a steep ease-in animation; a task waits for the impact, then bumps a keyframeAnimator for the jolt and animates that slot's splatter progress. The flip is an Animatable angle that swaps faces at 90°.",
            "印章以缩放加透明度的转场插入，配合陡峭的缓入动画；一个 task 等到落印时刻，再触发 keyframeAnimator 的震动，并推进该圆位的墨点飞溅进度。翻面是一个 Animatable 角度，在90°处切换正反面。"
        ),
        apis: ["transition", "keyframeAnimator", "Animatable", "rotation3DEffect", "Canvas", "spring(response:dampingFraction:)"],
        tags: ["stamp", "loyalty", "ink", "reward", "集章", "积分卡", "印章", "奖励"],
        params: [
            .slider("start", L("Stamps to begin with", "初始印章数"), 0...7, default: 5, step: 1, decimals: 0),
            .slider("slam", L("Slam duration", "落印时长"), 0.1...0.35, default: 0.16, unit: "s"),
            .slider("jitter", L("Stamp tilt", "印章倾斜"), 0...20, default: 12, step: 1, decimals: 0, unit: "°"),
            .slider("flip", L("Flip response", "翻面响应"), 0.4...1.0, default: 0.62, unit: "s"),
        ]
    ) { ctx in
        CardsStampDemo(ctx: ctx)
    }
}

private enum CardsStampLayout {
    static let size = CGSize(width: 264, height: 166)
    static let slots = 8
    static let slot: CGFloat = 36
    static let ink = Color(hex: 0xB23A2B)
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }

    static func noise(_ a: Int, _ b: Int) -> CGFloat {
        var x = UInt64(truncatingIfNeeded: a &* 48271 &+ b &* 16807 &+ 977)
        x ^= x >> 30
        x = x &* 0xBF58476D1CE4E5B9
        x ^= x >> 27
        x = x &* 0x94D049BB133111EB
        x ^= x >> 31
        return CGFloat(x % 10_000) / 10_000
    }
}

private struct CardsStampDemo: View {
    let ctx: DemoContext
    @State private var count: Int
    /// Splatter progress per slot: 0 nothing, 1 droplets landed.
    @State private var splats: [CGFloat]
    @State private var angle: Double = 0
    @State private var flipped = false
    @State private var busy = false
    @State private var jolts = 0
    @State private var sweeps = 0
    @State private var round = 0
    @State private var rest = 0
    @State private var script: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows a nearly full card.
        let filled = ctx.isStill ? 7 : ctx.int("start").clamped(to: 0...7)
        _count = State(initialValue: filled)
        _splats = State(initialValue: (0..<CardsStampLayout.slots).map { $0 < filled ? 1 : 0 })
    }

    var body: some View {
        VStack(spacing: 22) {
            CardsStampFlip(angle: angle) {
                CardsStampFront(count: count, splats: splats, round: round, jitter: ctx["jitter"], language: ctx.language)
            } back: {
                CardsStampReward(sweeps: sweeps, language: ctx.language)
            }
            .keyframeAnimator(initialValue: CardsStampJolt(), trigger: jolts) { content, jolt in
                content
                    .scaleEffect(jolt.scale)
                    .rotationEffect(.degrees(jolt.twist))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.975, duration: 0.05)
                    SpringKeyframe(1, duration: 0.4, spring: Spring(response: 0.24, dampingRatio: 0.45))
                }
                KeyframeTrack(\.twist) {
                    CubicKeyframe(jolts % 2 == 0 ? 0.8 : -0.8, duration: 0.05)
                    SpringKeyframe(0, duration: 0.4, spring: Spring(response: 0.26, dampingRatio: 0.4))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { tap(haptic: true) }
            DemoHint(text: L("Tap to stamp", "点击盖章"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.75) { autoTap() }
        .onChange(of: ctx.int("start")) { _, _ in
            guard !flipped, !busy else { return }
            clear()
        }
        .onDisappear { script?.cancel() }
    }

    /// Preview: stamp to the end, hold on the reward for a few beats, then start over.
    private func autoTap() {
        if flipped {
            rest += 1
            guard rest >= 3 else { return }
            rest = 0
        }
        tap(haptic: false)
    }

    private func tap(haptic: Bool) {
        guard !busy else { return }
        let buzz = haptic && !ctx.isPreview
        if flipped {
            flipBack(buzz: buzz)
            return
        }
        guard count < CardsStampLayout.slots else { return }
        busy = true
        let slot = count
        let slam = ctx["slam"]
        withAnimation(.timingCurve(0.7, 0, 1, 0.5, duration: slam)) { count = slot + 1 }
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(slam))
            guard !Task.isCancelled else { return }
            jolts += 1
            if buzz { Haptics.tap(.rigid) }
            withAnimation(.easeOut(duration: 0.22)) { splats[slot] = 1 }
            guard slot + 1 == CardsStampLayout.slots else {
                busy = false
                return
            }
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            let response = ctx["flip"]
            withAnimation(.spring(response: response, dampingFraction: 0.7)) { angle += 180 }
            flipped = true
            try? await Task.sleep(for: .seconds(response * 0.55))
            guard !Task.isCancelled else { return }
            sweeps += 1
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(0.3))
            busy = false
        }
    }

    private func flipBack(buzz: Bool) {
        busy = true
        if buzz { Haptics.tap(.medium) }
        let response = ctx["flip"]
        withAnimation(.spring(response: response, dampingFraction: 0.78)) { angle += 180 }
        flipped = false
        script?.cancel()
        script = Task { @MainActor in
            // Wipe the card while it is edge-on.
            try? await Task.sleep(for: .seconds(response * 0.25))
            guard !Task.isCancelled else { return }
            clear()
            try? await Task.sleep(for: .seconds(response * 0.5))
            busy = false
        }
    }

    private func clear() {
        let filled = ctx.int("start").clamped(to: 0...7)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            round += 1
            count = filled
            splats = (0..<CardsStampLayout.slots).map { $0 < filled ? 1 : 0 }
        }
    }
}

private struct CardsStampJolt {
    var scale: CGFloat = 1
    var twist: Double = 0
}

/// Two-sided card: swaps faces as the turn passes 90° and lifts mid-flip.
private struct CardsStampFlip<Front: View, Back: View>: View, Animatable {
    var angle: Double
    @ViewBuilder let front: () -> Front
    @ViewBuilder let back: () -> Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let remainder = angle.truncatingRemainder(dividingBy: 360)
        let normalized = remainder < 0 ? remainder + 360 : remainder
        let showBack = normalized > 90 && normalized < 270
        let rise = CGFloat(abs(sin(angle * .pi / 180)))
        ZStack {
            front()
                .opacity(showBack ? 0 : 1)
            back()
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showBack ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .scaleEffect(1 + 0.08 * rise)
        .shadow(color: .black.opacity(0.18 + 0.1 * Double(rise)), radius: 14 + 12 * rise, y: 10 + 12 * rise)
    }
}

private struct CardsStampFront: View {
    let count: Int
    let splats: [CGFloat]
    let round: Int
    let jitter: Double
    let language: AppLanguage

    private let ink = Color(hex: 0x4A3424)

    var body: some View {
        let size = CardsStampLayout.size
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Corner Café", "街角咖啡"), language)
                    .font(.system(size: 17, weight: .heavy, design: .serif))
                Spacer(minLength: 0)
                Text(verbatim: "\(min(count, CardsStampLayout.slots)) / \(CardsStampLayout.slots)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .opacity(0.6)
            }
            Text(L("Collect 8 stamps for a free coffee", "集满 8 枚印章，免费换一杯咖啡"), language)
                .font(.system(size: 10, weight: .medium))
                .opacity(0.55)
                .padding(.top, 2)
            Spacer(minLength: 0)
            VStack(spacing: 9) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { column in
                            slot(row * 4 + column)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: size.width, height: size.height)
        .background {
            LinearGradient(colors: [Color(hex: 0xFCF6E8), Color(hex: 0xF0E4CC)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(CardsStampLayout.shape)
        .overlay(CardsStampLayout.shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
    }

    private func slot(_ index: Int) -> some View {
        let side = CardsStampLayout.slot
        let tilt = Double(CardsStampLayout.noise(index, round * 7 + 3) * 2 - 1) * jitter
        return ZStack {
            Circle()
                .strokeBorder(ink.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                .frame(width: side, height: side)
            if index == CardsStampLayout.slots - 1 && index >= count {
                Image(systemName: "gift.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.3))
            }
            CardsStampSplat(progress: splats[index], seed: index + round * 31)
                .frame(width: side * 1.7, height: side * 1.7)
            if index < count {
                CardsStampMark()
                    .rotationEffect(.degrees(tilt))
                    .transition(.asymmetric(insertion: .scale(scale: 2.4).combined(with: .opacity), removal: .opacity))
                    .id("stamp-\(round)-\(index)")
            }
        }
        .frame(width: side, height: side)
    }
}

/// The ink impression: a ring, a cup and a second thin ring, slightly uneven like real ink.
private struct CardsStampMark: View {
    var body: some View {
        let ink = CardsStampLayout.ink
        ZStack {
            Circle()
                .fill(ink.opacity(0.1))
            Circle()
                .strokeBorder(ink, lineWidth: 2.4)
            Circle()
                .strokeBorder(ink.opacity(0.75), style: StrokeStyle(lineWidth: 0.9, dash: [9, 2, 5, 2]))
                .padding(4.5)
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ink)
        }
        .frame(width: CardsStampLayout.slot, height: CardsStampLayout.slot)
        .opacity(0.9)
    }
}

/// Ink droplets thrown out by the impact. They fly out with `progress` and stay where they land.
private struct CardsStampSplat: View, Animatable {
    var progress: CGFloat
    let seed: Int

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = progress
        Canvas { context, size in
            guard p > 0.01 else { return }
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let rim = CardsStampLayout.slot / 2
            for drop in 0..<7 {
                let angle = 2 * CGFloat.pi * (CGFloat(drop) + CardsStampLayout.noise(seed, drop) * 0.8) / 7
                let reach = rim - 2 + (5 + 8 * CardsStampLayout.noise(seed, drop + 20)) * p
                let radius = (0.5 + 1.1 * CardsStampLayout.noise(seed, drop + 40)) * (1.25 - 0.25 * p)
                let point = CGPoint(x: centre.x + cos(angle) * reach, y: centre.y + sin(angle) * reach)
                let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(CardsStampLayout.ink.opacity(0.78)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CardsStampReward: View {
    let sweeps: Int
    let language: AppLanguage

    private struct Shine {
        var travel: CGFloat = -1
        var pop: CGFloat = 0
        var fade: Double = 0
    }

    var body: some View {
        let size = CardsStampLayout.size
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF6D98A), Color(hex: 0xD9A441), Color(hex: 0x9C6A1E)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 34, weight: .bold))
                Text(L("Free coffee", "免费咖啡一杯"), language)
                    .font(.system(size: 22, weight: .heavy, design: .serif))
                Text(L("Show this card at the counter", "到店出示此卡即可兑换"), language)
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.7)
            }
            .foregroundStyle(Color(hex: 0x3D2608))
        }
        .frame(width: size.width, height: size.height)
        .keyframeAnimator(initialValue: Shine(), trigger: sweeps) { content, shine in
            content
                .overlay {
                    // The highlight that sweeps the foil.
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0), location: 0.35),
                            .init(color: .white.opacity(0.7), location: 0.5),
                            .init(color: .white.opacity(0), location: 0.65),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .offset(x: shine.travel * size.width)
                    .blendMode(.plusLighter)
                }
                .overlay { CardsStampSparkles(pop: shine.pop, fade: shine.fade) }
        } keyframes: { _ in
            KeyframeTrack(\.travel) {
                MoveKeyframe(-1)
                CubicKeyframe(1, duration: 0.8)
            }
            KeyframeTrack(\.pop) {
                MoveKeyframe(0)
                SpringKeyframe(1, duration: 0.6, spring: Spring(response: 0.4, dampingRatio: 0.7))
            }
            KeyframeTrack(\.fade) {
                MoveKeyframe(1)
                LinearKeyframe(1, duration: 0.35)
                LinearKeyframe(0, duration: 0.45)
            }
        }
        .clipShape(CardsStampLayout.shape)
        .overlay(CardsStampLayout.shape.strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
    }
}

private struct CardsStampSparkles: View {
    let pop: CGFloat
    let fade: Double

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) * .pi / 3 + 0.4
                Image(systemName: "sparkle")
                    .font(.system(size: index % 2 == 0 ? 15 : 10, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(0.3 + 0.7 * pop)
                    .offset(x: CGFloat(cos(angle)) * (30 + 74 * pop), y: CGFloat(sin(angle)) * (20 + 40 * pop))
            }
        }
        .opacity(fade)
    }
}
