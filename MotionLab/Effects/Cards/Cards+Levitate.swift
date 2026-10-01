import SwiftUI

extension Effect {
    static let cardsLevitate = Effect(
        id: "cards.levitate",
        category: .cards,
        interaction: .gesture,
        name: L("Levitate", "悬浮"),
        summary: L("A card hovers above the surface with a slow bob and a breathing shadow; press it down and it springs back up.", "卡片悬在表面上方缓缓起伏，影子随之呼吸；按下去，松手后它又弹回空中。"),
        prompt: L(
            "A glossy card hovers 38 pt above a surface. It bobs ±7 pt on a 3.6 s sine while swaying about 3° on two slower, unrelated periods, so the motion never visibly repeats. Its shadow is a separate soft copy of the card: the higher the card, the further down the shadow sits, the wider its blur (6 to 26 pt) and the fainter it gets, and a coloured glow from the card spills around it. Pressing pushes the card onto the surface on a stiff spring: it shrinks to 93%, tips 7° toward the finger, and the shadow tightens into a dark rim; a ring of light spreads out on contact with a soft haptic. Releasing lets a looser spring (damping 0.45) throw it back up past its hover height, and it settles after two or three bounces.",
            "一张有光泽的卡片悬在表面上方38 pt处。它以3.6秒的正弦周期上下起伏±7 pt，同时按另外两个更慢、互不相关的周期摆动约3°，所以看不出重复。影子是卡片的一份独立的柔化副本：卡片越高，影子越靠下、模糊越大（6到26 pt）、颜色越淡，卡片的色光还会洒在影子周围。按下时，卡片被一条较硬的弹簧压到表面：缩到93%，朝手指倾斜7°，影子收紧成一圈深色轮廓；触底瞬间一圈光向外扩散，并有一记柔和触感。松手后，较松的弹簧（阻尼0.45）把它抛回空中，冲过悬浮高度，弹两三下后停稳。"
        ),
        implementation: L(
            "A TimelineView steps a small spring integrator for the card's height (target: hover height, or 0 while pressed) and adds the sine bob scaled by that height. Scale, tilt and the shadow's offset, blur and opacity are all derived from the one height value.",
            "TimelineView 逐帧推进一个小型弹簧积分器来计算卡片高度（目标是悬浮高度，按下时为0），并叠加按高度缩放的正弦起伏。缩放、倾斜以及影子的偏移、模糊和透明度全部由这一个高度值推导。"
        ),
        apis: ["TimelineView", "rotation3DEffect", "blur", "DragGesture", "GestureState"],
        tags: ["levitate", "float", "hover", "shadow", "悬浮", "漂浮", "影子", "呼吸"],
        params: [
            .slider("height", L("Hover height", "悬浮高度"), 16...60, default: 38, step: 1, decimals: 0, unit: "pt"),
            .slider("bob", L("Bob amplitude", "起伏幅度"), 0...14, default: 7, step: 0.5, decimals: 1, unit: "pt"),
            .slider("period", L("Bob period", "起伏周期"), 1.6...6, default: 3.6, unit: "s"),
            .slider("damping", L("Rebound damping", "回弹阻尼"), 0.2...1.0, default: 0.45),
        ]
    ) { ctx in
        CardsLevitateDemo(ctx: ctx)
    }
}

/// Spring state stepped once per frame (kept out of `@State` values so stepping never invalidates the view).
private final class CardsLevitateBody {
    var height: CGFloat
    var velocity: CGFloat = 0
    var last: Date?
    var touchedGround = false

    init(height: CGFloat) {
        self.height = height
    }

    /// Semi-implicit Euler toward `target`. Returns `true` on the frame the card first reaches the surface.
    func step(to now: Date, target: CGFloat, stiffness: CGFloat, damping: CGFloat) -> Bool {
        defer { last = now }
        guard let last else { return false }
        var remaining = CGFloat(min(now.timeIntervalSince(last), 1.0 / 20.0))
        var landed = false
        while remaining > 0.0001 {
            let dt = min(remaining, 1.0 / 240.0)
            remaining -= dt
            let force = -stiffness * (height - target) - damping * velocity
            velocity += force * dt
            height += velocity * dt
            if height < 0 {
                // The surface is solid: the card stops dead on it.
                height = 0
                velocity = max(velocity, 0) * 0.2
                if !touchedGround { landed = true }
                touchedGround = true
            }
        }
        if height > 6 { touchedGround = false }
        return landed
    }
}

private struct CardsLevitateDemo: View {
    let ctx: DemoContext
    @State private var physics: CardsLevitateBody
    @State private var pressed = false
    @State private var touch: CGPoint = .zero
    @State private var ripples = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    private let cardSize = CGSize(width: 230, height: 230 * 158 / 250)

    init(ctx: DemoContext) {
        self.ctx = ctx
        _physics = State(initialValue: CardsLevitateBody(height: ctx.cg("height")))
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                stage(at: timeline.date)
            }
            .frame(width: 300, height: 286)
            DemoHint(text: L("Press and hold the card", "按住卡片"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.4, delay: 1.4) { autoPress() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release() }
        }
        .onDisappear { script?.cancel() }
    }

    private func stage(at date: Date) -> some View {
        let hover = ctx.cg("height")
        let landed = advance(to: date)
        let t = date.timeIntervalSinceReferenceDate
        let base = physics.height
        // The bob fades out as the card is pushed down, so a grounded card lies still.
        let afloat = (base / max(hover, 1)).clamped(to: 0...1.4)
        let bob: CGFloat = ctx.isStill ? 0 : ctx.cg("bob") * afloat * CGFloat(sin(t * 2 * .pi / ctx["period"]))
        let height = max(base + bob, 0)
        let lift = (height / 60).clamped(to: 0...1.2)
        let swayX: Double = ctx.isStill ? 2.5 : 3.2 * sin(t * 2 * .pi / 5.3) * Double(afloat)
        let swayY: Double = ctx.isStill ? -3 : 3.6 * sin(t * 2 * .pi / 7.1 + 1.3) * Double(afloat)
        let lean = 1 - afloat.clamped(to: 0...1)
        let tiltX: Double = swayX - Double(touch.y / (cardSize.height / 2)) * 7 * Double(lean)
        let tiltY: Double = swayY + Double(touch.x / (cardSize.width / 2)) * 7 * Double(lean)
        return ZStack {
            CardsLevitateShadow(size: cardSize, height: height, lift: lift)
            CardsLevitateRipple(trigger: ripples, size: cardSize)
            CardsCreditCard(theme: 0, width: cardSize.width, last4: "2048")
                .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .scaleEffect(0.93 + 0.07 * (height / max(hover, 1)).clamped(to: 0...1.5))
                .offset(y: -height * 0.72)
                .gesture(press)
        }
        .offset(y: 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: landed) { _, didLand in
            if didLand { touchDown() }
        }
    }

    /// Steps the spring and reports the frame the card hits the surface.
    private func advance(to date: Date) -> Bool {
        guard !ctx.isStill else { return false }
        // Pressing uses a stiff, well damped spring; the release spring is looser and bouncier.
        let stiffness: CGFloat = pressed ? 520 : 150
        let ratio: CGFloat = pressed ? 0.9 : ctx.cg("damping")
        let damping: CGFloat = 2 * ratio * sqrt(stiffness)
        return physics.step(to: date, target: pressed ? -8 : ctx.cg("height"), stiffness: stiffness, damping: damping)
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !pressed {
                    script?.cancel()
                    script = nil
                    pressed = true
                }
                touch = CGPoint(
                    x: (value.location.x - cardSize.width / 2).clamped(to: -cardSize.width / 2...cardSize.width / 2),
                    y: (value.location.y - cardSize.height / 2).clamped(to: -cardSize.height / 2...cardSize.height / 2)
                )
            }
            .onEnded { _ in release() }
    }

    private func release() {
        guard pressed, script == nil else { return }
        pressed = false
        Haptics.tap(.light)
    }

    private func touchDown() {
        ripples += 1
        if !ctx.isPreview { Haptics.tap(.soft) }
    }

    private func autoPress() {
        guard !pressed else { return }
        touch = CGPoint(x: 54, y: 18)
        pressed = true
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.75))
            guard !Task.isCancelled else { return }
            script = nil
            pressed = false
        }
    }
}

/// The card's shadow on the surface: lower, softer and fainter as the card rises, with the card's own
/// colours bleeding around it.
private struct CardsLevitateShadow: View {
    let size: CGSize
    let height: CGFloat
    let lift: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        ZStack {
            shape
                .fill(LinearGradient(colors: CardsArt.colors(0), startPoint: .leading, endPoint: .trailing))
                .frame(width: size.width * 0.9, height: size.height * 0.8)
                .blur(radius: 26)
                .opacity(0.16 + 0.26 * Double(lift))
                .offset(y: height * 0.5 + 6)
            shape
                .fill(Color.black)
                .frame(width: size.width * (0.96 - 0.1 * lift), height: size.height * (0.94 - 0.14 * lift))
                .blur(radius: 6 + 20 * lift)
                .opacity(0.5 - 0.27 * Double(lift.clamped(to: 0...1)))
                .offset(y: 4 + height * 0.62)
        }
    }
}

/// A ring of light that spreads over the surface when the card lands on it.
private struct CardsLevitateRipple: View {
    let trigger: Int
    let size: CGSize

    private struct Wave {
        var grow: CGFloat = 0
        var fade: Double = 0
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.9), lineWidth: 2)
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Wave(), trigger: trigger) { content, wave in
                content
                    .scaleEffect(1 + 0.24 * wave.grow)
                    .opacity(wave.fade)
                    .blur(radius: 1 + 5 * wave.grow)
            } keyframes: { _ in
                KeyframeTrack(\.grow) {
                    MoveKeyframe(0)
                    CubicKeyframe(1, duration: 0.6)
                }
                KeyframeTrack(\.fade) {
                    MoveKeyframe(0.55)
                    LinearKeyframe(0, duration: 0.6)
                }
            }
            .offset(y: 4)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
}
