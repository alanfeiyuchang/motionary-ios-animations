import SwiftUI

extension Effect {
    static let buttonsEmojiFountain = Effect(
        id: "buttons.emoji-fountain",
        category: .buttons,
        interaction: .tap,
        name: L("Emoji Fountain", "表情喷泉"),
        summary: L(
            "Each tap shoots emoji up like a fountain; they spin, arc over and fall, and rapid taps build the stream.",
            "每次点击都像喷泉一样把表情喷上去，旋转、越过顶点再落下；连点会让水柱越喷越猛。"
        ),
        prompt: L(
            "A round 72 pt gradient button with a party emoji. Each tap launches 3 emoji from its centre: they leave at about 460 pt/s inside a ±20° cone around straight up, pop from 30% to full size in 90 ms, tumble at up to ±320°/s, decelerate under 950 pt/s² gravity, arc over the top and fall back, fading out over the last 30% of a 1.25 s life. The button squashes to 88% and springs back (response 0.3 s, damping 0.5) and a counter beside it rolls up. Taps less than 0.5 s apart build heat: every tap adds 20%, and at full heat each one launches 4 more emoji 25% faster, while a ring around the button swells and glows; heat drains 0.7 s after the last tap. Light haptic per tap. Exuberant and generous.",
            "直径 72pt 的圆形渐变按钮，上面是庆祝表情。每次点击从中心喷出 3 个表情：以约 460pt/s 的初速在正上方 ±20° 的锥形内射出，90 毫秒内从 30% 弹到原大，以最高 ±320°/s 翻滚，在 950pt/s² 的重力下越过顶点回落，并在 1.25 秒寿命的最后 30% 淡出。按钮压到 88% 再弹回（响应 0.3 秒、阻尼 0.5），旁边的计数滚动增加。间隔小于 0.5 秒的连点累积热度：每次加 20%，满热度时每次多喷 4 个、快 25%，按钮外的光环涨大发亮；停手 0.7 秒后热度消退。每次点击伴随轻触感。"
        ),
        implementation: L(
            "Particles are plain values (birth time, launch angle, speed, spin, emoji index); a TimelineView Canvas evaluates the ballistic position x = v·t, y = v·t − ½g·t² for each and draws a resolved emoji Text through a translated, rotated and scaled copy of the context. Taps append particles and prune dead ones.",
            "粒子只是普通数值（出生时间、发射角、初速、自旋、表情序号）；TimelineView 中的 Canvas 为每个粒子计算弹道位置 x = v·t、y = v·t − ½g·t²，并在平移、旋转、缩放后的上下文副本里绘制已解析的表情 Text。点击时追加粒子并清理已消失的粒子。"
        ),
        apis: ["TimelineView", "Canvas", "GraphicsContext.resolve(_:)", "contentTransition(.numericText())", "keyframeAnimator"],
        tags: ["emoji", "fountain", "particles", "gravity", "combo", "表情", "喷泉", "粒子", "重力", "连击"],
        params: [
            .slider("count", L("Emoji per tap", "每次数量"), 1...8, default: 3, step: 1, decimals: 0),
            .slider("power", L("Launch speed", "喷射速度"), 300...700, default: 460, decimals: 0, unit: "pt/s"),
            .slider("gravity", L("Gravity", "重力"), 500...1600, default: 950, decimals: 0, unit: "pt/s²"),
            .slider("spread", L("Spread", "扩散角"), 5...45, default: 20, decimals: 0, unit: "°"),
        ]
    ) { ctx in
        ButtonFountainDemo(ctx: ctx)
    }
}

private struct ButtonFountainParticle {
    let birth: Date
    let angle: Double
    let speed: Double
    let spin: Double
    let tilt: Double
    let size: CGFloat
    let symbol: Int
}

private struct ButtonFountainDemo: View {
    let ctx: DemoContext
    @State private var particles: [ButtonFountainParticle]
    @State private var total: Int
    @State private var heat: Double = 0
    @State private var taps = 0
    @State private var seed = 0
    @State private var lastTap = Date.distantPast
    @State private var live = false
    @State private var coolTask: Task<Void, Never>?
    @State private var idleTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    private static let stage = CGSize(width: 320, height: 272)
    private static let life = 1.25
    private static let stillDate = Date(timeIntervalSinceReferenceDate: 1000)
    /// Where the fountain starts, in stage coordinates: the centre of the button.
    private static let origin = CGPoint(x: stage.width / 2, y: stage.height - 44)

    init(ctx: DemoContext) {
        self.ctx = ctx
        var seeded: [ButtonFountainParticle] = []
        if ctx.isStill {
            // A frozen stream: particles at staggered ages along the arc.
            for index in 0..<11 {
                seeded.append(
                    Self.makeParticle(
                        seed: index * 3 + 5,
                        birth: Self.stillDate.addingTimeInterval(-0.06 - Double(index) * 0.075),
                        power: 460,
                        spread: 20
                    )
                )
            }
        }
        _particles = State(initialValue: seeded)
        _total = State(initialValue: ctx.isStill ? 128 : 124)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !live || ctx.isStill)) { timeline in
                    ButtonFountainCanvas(
                        particles: particles,
                        date: ctx.isStill ? Self.stillDate : timeline.date,
                        origin: Self.origin,
                        gravity: ctx["gravity"],
                        life: Self.life
                    )
                }
                .allowsHitTesting(false)
                button
                    .position(Self.origin)
                counter
                    .position(x: Self.origin.x + 84, y: Self.origin.y)
            }
            .frame(width: Self.stage.width, height: Self.stage.height)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap, then tap faster", "点一下，再越点越快"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.7, delay: 0.4) { playScript() }
        .onDisappear {
            coolTask?.cancel()
            idleTask?.cancel()
            scriptTask?.cancel()
        }
    }

    private var button: some View {
        Button {
            scriptTask?.cancel()
            fire()
        } label: {
            ZStack {
                // The heat ring: swells and glows as the combo builds.
                Circle()
                    .strokeBorder(Palette.amber.opacity(0.25 + 0.6 * heat), lineWidth: 2 + 3 * heat)
                    .frame(width: 84 + 22 * heat, height: 84 + 22 * heat)
                    .blur(radius: 1.5 * heat)
                    .opacity(heat > 0.01 ? 1 : 0)
                Circle()
                    .fill(Palette.sunset)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(colors: [Color.white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.2
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: Palette.coral.opacity(0.35 + 0.3 * heat), radius: 12 + 8 * heat, y: 7)
                Text("🎉")
                    .font(.system(size: 32))
            }
            .frame(width: 110, height: 110)
            .contentShape(Circle())
            .keyframeAnimator(initialValue: CGSize(width: 1, height: 1), trigger: taps) { content, scale in
                content.scaleEffect(x: scale.width, y: scale.height)
            } keyframes: { _ in
                KeyframeTrack(\.height) {
                    CubicKeyframe(0.88, duration: 0.07)
                    SpringKeyframe(1, duration: 0.45, spring: Spring(response: 0.3, dampingRatio: 0.5))
                }
                KeyframeTrack(\.width) {
                    CubicKeyframe(1.06, duration: 0.07)
                    SpringKeyframe(1, duration: 0.45, spring: Spring(response: 0.3, dampingRatio: 0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var counter: some View {
        Text("\(total)")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(heat > 0.5 ? AnyShapeStyle(Palette.coral) : AnyShapeStyle(Color.secondary))
            .contentTransition(.numericText(value: Double(total)))
            .frame(width: 70, alignment: .leading)
    }

    // MARK: Behaviour

    private func fire() {
        let now = Date()
        let chained = now.timeIntervalSince(lastTap) < 0.5
        lastTap = now
        let newHeat = chained ? min(heat + 0.2, 1) : 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { heat = newHeat }
        let amount = min(max(ctx.int("count"), 1), 8) + Int((newHeat * 4).rounded())
        let power = ctx["power"] * (1 + 0.25 * newHeat)
        var next = particles.filter { now.timeIntervalSince($0.birth) < Self.life }
        for index in 0..<amount {
            seed += 1
            // A few milliseconds apart so one tap reads as a short jet, not a single clump.
            next.append(Self.makeParticle(seed: seed, birth: now.addingTimeInterval(Double(index) * 0.022), power: power, spread: ctx["spread"]))
        }
        particles = next
        taps += 1
        withAnimation(.snappy(duration: 0.25)) { total += 1 }
        Haptics.tap(newHeat > 0.7 ? .medium : .light)
        live = true

        coolTask?.cancel()
        coolTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) { heat = 0 }
        }
        idleTask?.cancel()
        idleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.life + 0.4))
            guard !Task.isCancelled else { return }
            live = false
            particles = []
        }
    }

    /// Preview loop and detail intro: one lone tap, then a quick run that builds the stream.
    private func playScript() {
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            fire()
            try? await Task.sleep(for: .seconds(0.75))
            for _ in 0..<5 {
                guard !Task.isCancelled else { return }
                fire()
                try? await Task.sleep(for: .seconds(0.15))
            }
        }
    }

    private static func makeParticle(seed: Int, birth: Date, power: Double, spread: Double) -> ButtonFountainParticle {
        let cone = spread * .pi / 180
        return ButtonFountainParticle(
            birth: birth,
            angle: (hash(seed, 1) * 2 - 1) * cone,
            speed: power * (0.78 + 0.3 * hash(seed, 2)),
            spin: (hash(seed, 3) * 2 - 1) * 320 * .pi / 180,
            tilt: (hash(seed, 4) * 2 - 1) * 0.5,
            size: 0.8 + 0.45 * CGFloat(hash(seed, 5)),
            symbol: seed
        )
    }

    private static func hash(_ value: Int, _ channel: Int) -> Double {
        let x = sin(Double(value) * 12.9898 + Double(channel) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }
}

private struct ButtonFountainCanvas: View {
    let particles: [ButtonFountainParticle]
    let date: Date
    let origin: CGPoint
    let gravity: Double
    let life: Double

    private static let emoji = ["😍", "🔥", "👏", "🎉", "💜", "✨"]

    var body: some View {
        Canvas { context, _ in
            let glyphs = Self.emoji.map { context.resolve(Text($0).font(.system(size: 26))) }
            for particle in particles {
                let age = date.timeIntervalSince(particle.birth)
                guard age >= 0, age < life else { continue }
                let x = sin(particle.angle) * particle.speed * age
                let y = -cos(particle.angle) * particle.speed * age + 0.5 * gravity * age * age
                // Never draw below the launch point: falling emoji disappear behind the button.
                guard y < 20 else { continue }
                let pop = min(age / 0.09, 1)
                let scale = particle.size * CGFloat(0.3 + 0.7 * pop)
                let fade = min((life - age) / (life * 0.3), 1)
                var glyph = context
                glyph.translateBy(x: origin.x + x, y: origin.y + y)
                glyph.rotate(by: .radians(particle.tilt + particle.spin * age))
                glyph.scaleBy(x: scale, y: scale)
                glyph.opacity = fade
                glyph.draw(glyphs[abs(particle.symbol) % glyphs.count], at: .zero)
            }
        }
    }
}
