import SwiftUI

extension Effect {
    static let shaderShockwave = Effect(
        id: "shader.shockwave",
        category: .shaders,
        interaction: .tap,
        name: L("Shockwave", "冲击波"),
        summary: L(
            "A tap detonates a single refractive ring that races outward, lensing the picture with a chromatic fringe.",
            "点击引爆一道折射圆环，向外疾驰，像透镜一样弯折画面并带出彩色色边。"
        ),
        prompt: L(
            "Tapping the skyline detonates a shockwave at the finger. One ring, not a train of ripples: its front leaves the tap at 320 pt/s, and within a 26 pt band around it the picture is refracted by a one-cycle wavelet — pushed outward up to 14 pt just ahead of the front, pulled inward just behind — so the ring reads as a travelling glass lens. Red and blue are displaced 30% more and less than green, leaving a thin spectral fringe, and the crest carries a faint highlight. At the tap a white flash blooms and fades while the card punches down to 97.5% and springs back (response 0.32 s, damping 0.42). Up to three rings overlap; each dies out before 420 pt. Punchy, physical, cinematic.",
            "点击城市天际线，在指尖引爆一道冲击波。它是单独的一圈，而不是一串涟漪：波前以 320pt/s 离开触点，在其前后 26pt 的环带内，画面被单周期子波折射——波前外侧最多被向外推 14pt，内侧则被向内拉——整圈读起来像一枚移动的玻璃透镜。红、蓝通道比绿色多偏移和少偏移 30%，留下一道细细的光谱色边，波峰带一抹微弱高光。触点处绽开一团白光后淡去，同时卡片下沉到 97.5% 再以弹簧（响应 0.32 秒、阻尼 0.42）弹回。最多三圈可以叠加，每一圈在 420pt 之内消散。干脆、有力、电影感十足。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader sums three rings, each a wavelet x·e^(−1.6x²) of the distance to its front, and samples R, G and B at slightly different displacements; a TimelineView feeds each ring's age while one is alive, and an Animatable value drives the flash and the card's punch.",
            "[[stitchable]] layerEffect 着色器叠加三道圆环，每道都是关于“到波前距离”的子波 x·e^(−1.6x²)，并以略有差别的位移分别采样 R、G、B；圆环存活期间由 TimelineView 提供各自的时间，白光与卡片的冲击缩放由一个 Animatable 数值驱动。"
        ),
        apis: ["layerEffect", "TimelineView", "onTapGesture(coordinateSpace:)", "spring(response:dampingFraction:)", "Metal"],
        tags: ["shockwave", "blast", "refraction", "ring", "chromatic", "冲击波", "爆炸", "折射", "色散"],
        params: [
            .slider("speed", L("Front speed", "波前速度"), 200...900, default: 320, decimals: 0, unit: "pt/s"),
            .slider("width", L("Band width", "环带宽度"), 14...60, default: 26, decimals: 0, unit: "pt"),
            .slider("strength", L("Refraction", "折射强度"), 4...30, default: 14, decimals: 0, unit: "pt"),
            .slider("fringe", L("Chromatic fringe", "色边"), 0...0.6, default: 0.3),
        ]
    ) { ctx in
        ShockwaveDemo(ctx: ctx)
    }
}

private struct ShockRing {
    var origin = CGPoint(x: 130, y: 150)
    var start = Date.distantPast
}

private struct ShockwaveDemo: View {
    let ctx: DemoContext
    @State private var rings = [ShockRing(), ShockRing(), ShockRing()]
    @State private var next = 0
    @State private var active = false
    @State private var token = 0
    @State private var punch: Double = 0
    @State private var flashAt = CGPoint(x: 130, y: 150)

    /// Rings fade out completely by this radius (the card's diagonal is ≈ 397 pt).
    private static let reach: Double = 420

    var body: some View {
        let speed = ctx["speed"]
        let width = ctx["width"]
        let strength = ctx["strength"]
        let fringe = ctx["fringe"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !active)) { timeline in
                let ages = ages(at: timeline.date)
                ShaderCityScene()
                    .modifier(ShockFlash(punch: punch, at: flashAt))
                    .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                    .layerEffect(
                        ShaderLibrary.mlShockwave(
                            .float2(ShaderKit.card),
                            .float2(rings[0].origin), .float(ages[0]),
                            .float2(rings[1].origin), .float(ages[1]),
                            .float2(rings[2].origin), .float(ages[2]),
                            .float(speed), .float(width), .float(strength), .float(fringe), .float(Self.reach)
                        ),
                        maxSampleOffset: CGSize(width: strength * 3 * (1 + fringe), height: strength * 3 * (1 + fringe)),
                        isEnabled: active || ctx.isStill
                    )
            }
            .shaderCard(glow: Color(hex: 0x7A5CFF, opacity: 0.35))
            .modifier(ShockPunch(punch: punch))
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                Haptics.tap(.rigid)
                detonate(at: location)
            }
            DemoHint(text: L("Tap anywhere, tap again before it fades", "点击任意位置，可在消散前连点"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7, delay: 0.3) {
            detonate(at: CGPoint(x: CGFloat.random(in: 50...210), y: CGFloat.random(in: 70...230)))
        }
    }

    private func ages(at date: Date) -> [Double] {
        if ctx.isStill {
            // A still shows one ring frozen mid-flight.
            return [0.36, -1, -1]
        }
        let life = Self.reach / max(ctx["speed"], 1)
        return rings.map { ring in
            let age = date.timeIntervalSince(ring.start)
            return age >= 0 && age < life ? age : -1
        }
    }

    private func detonate(at point: CGPoint) {
        rings[next] = ShockRing(origin: point, start: Date())
        next = (next + 1) % rings.count
        active = true
        flashAt = point
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { punch = 1 }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) { punch = 0 }
        token += 1
        let current = token
        let life = Self.reach / max(ctx["speed"], 1)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(life + 0.1))
            // Stop the clock once the last ring is gone, so the shader costs nothing at rest.
            if current == token { active = false }
        }
    }
}

/// White bloom at the blast point; it is part of the layer, so the ring refracts it too.
private struct ShockFlash: ViewModifier, Animatable {
    var punch: Double
    var at: CGPoint

    var animatableData: Double {
        get { punch }
        set { punch = newValue }
    }

    func body(content: Content) -> some View {
        let p = min(max(punch, 0), 1)
        content.overlay {
            Circle()
                .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: 40))
                .frame(width: 80, height: 80)
                .scaleEffect(0.4 + (1 - p) * 1.4)
                .position(at)
                .opacity(p * 0.85)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }
}

/// The card recoils: 97.5% at the blast, then the spring overshoots slightly past 100%.
private struct ShockPunch: ViewModifier, Animatable {
    var punch: Double

    var animatableData: Double {
        get { punch }
        set { punch = newValue }
    }

    func body(content: Content) -> some View {
        content.scaleEffect(1 - 0.025 * punch)
    }
}
