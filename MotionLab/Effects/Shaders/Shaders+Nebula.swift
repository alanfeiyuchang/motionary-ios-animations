import SwiftUI

extension Effect {
    static let shaderNebula = Effect(
        id: "shader.nebula",
        category: .shaders,
        interaction: .gesture,
        name: L("Deep-Space Nebula", "深空星云"),
        summary: L(
            "Layered clouds of glowing gas drift behind twinkling stars; drag to fly through, tap to ignite a star.",
            "层层发光的气体云在闪烁的星星后缓缓漂移；拖动即可穿行其间，点击点燃一颗新星。"
        ),
        prompt: L(
            "A procedural nebula fills the stage. Two cloud layers of fractal noise on a shared warped domain — far gas and nearer gas — glow in two colours, and where they overlap a hot core in a third shows through; a nearer noise layer cuts dark dust lanes across them. Two star fields twinkle at their own rates and dim behind dense gas. Everything drifts very slowly. Dragging pans the camera with parallax: stars and each cloud layer move by different amounts, so the scene has real depth, and a release keeps gliding and decays over about a second. Tapping ignites a star: a core with four diffraction spikes flares in 0.12 s, lights the gas around it and fades over ≈ 2.5 s. Vast, quiet and luminous.",
            "程序生成的星云铺满舞台。两层分形噪声云共用一个被扭曲的坐标域——远处的气体与较近的气体——各自发出一种颜色的光，二者重叠之处透出第三种颜色的炽热核心；更近的一层噪声在其上切出暗色的尘埃带。两层星场以各自的节奏闪烁，并在浓密气体后方变暗。一切都在极缓慢地漂移。拖动会带着视差平移镜头：星星与每层云移动的幅度各不相同，画面因此有真实的纵深；松手后继续滑行，约一秒内停下。点击可点燃一颗星：带四道衍射星芒的核心在 0.12 秒内亮起，照亮周围的气体，并在约 2.5 秒内淡去。浩瀚、静谧、通透。"
        ),
        implementation: L(
            "A [[stitchable]] color shader sums three fbm layers sampled at offsets scaled per depth by a pan vector, two hashed star grids and an optional flare, then tone-maps with 1 − e^(−1.5c). A small model integrates the drag into the pan with inertia; a TimelineView feeds accumulated time.",
            "[[stitchable]] colorEffect 着色器叠加三层 fbm（按深度以不同比例受平移向量偏移）、两层哈希星点网格与可选的星芒，最后以 1 − e^(−1.5c) 做色调映射。一个小模型把拖动带惯性地积分为平移量；TimelineView 提供累积时间。"
        ),
        apis: ["colorEffect", "visualEffect", "TimelineView", "DragGesture", "Metal"],
        tags: ["nebula", "space", "galaxy", "stars", "fbm", "generative", "星云", "太空", "银河", "星空", "生成"],
        params: [
            .slider("speed", L("Drift speed", "漂移速度"), 0...3, default: 1, decimals: 1),
            .slider("density", L("Gas density", "气体浓度"), 0.2...1, default: 0.5),
            .slider("stars", L("Stars", "星星数量"), 0...1, default: 0.6),
            .choice("palette", L("Palette", "配色"), [L("Orion", "猎户座"), L("Carina", "船底座"), L("Ember", "余烬")]),
        ]
    ) { ctx in
        NebulaDemo(ctx: ctx)
    }
}

private struct NebulaState {
    let time: Double
    let pan: CGPoint
    let flare: CGPoint
    let flareAge: Double
}

private final class NebulaModel {
    let clock = BackgroundClock(start: 60)
    /// Pan in view heights; `velocity` in view heights per second (inertia after release).
    private var pan = CGPoint.zero
    private var velocity = CGPoint.zero
    private var lastTouch: CGPoint?
    private var flare = CGPoint(x: 170, y: 170)
    private var flareStart: Double = -100

    func drag(to point: CGPoint, height: CGFloat) {
        if let last = lastTouch {
            pan.x -= (point.x - last.x) / max(height, 1)
            pan.y -= (point.y - last.y) / max(height, 1)
        }
        lastTouch = point
        velocity = .zero
    }

    func release(velocity gesture: CGSize, height: CGFloat) {
        lastTouch = nil
        velocity = CGPoint(x: -gesture.width / max(height, 1), y: -gesture.height / max(height, 1))
    }

    func ignite(at point: CGPoint, now: Double) {
        flare = point
        flareStart = now
    }

    func step(now: Double, speed: Double, auto: Bool) -> NebulaState {
        let time = clock.advance(to: now, speed: speed)
        if lastTouch == nil {
            pan.x += velocity.x * CGFloat(clock.delta)
            pan.y += velocity.y * CGFloat(clock.delta)
            let keep = CGFloat(exp(-clock.delta * 3.5))
            velocity.x *= keep
            velocity.y *= keep
        }
        var shown = pan
        if auto {
            // Simulated drag: a slow figure-eight pan that shows the parallax between the layers.
            shown.x += CGFloat(0.42 * sin(now * 0.42))
            shown.y += CGFloat(0.24 * sin(now * 0.84))
        }
        let age = now - flareStart
        return NebulaState(time: time, pan: shown, flare: flare, flareAge: age < 3 ? age : -1)
    }
}

private struct NebulaDemo: View {
    let ctx: DemoContext
    @State private var model = NebulaModel()
    @State private var size = CGSize(width: 340, height: 340)
    @State private var lastVelocity = CGSize.zero

    var body: some View {
        let speed = ctx["speed"]
        let density = ctx["density"]
        let stars = ctx["stars"]
        let palette = ctx.int("palette")
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let state = model.step(
                now: timeline.date.timeIntervalSinceReferenceDate,
                speed: speed,
                auto: ctx.isPreview && !ctx.isStill
            )
            NebulaSurface(state: state, density: density, stars: stars, palette: palette)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .shaderTouch(
            onBegan: { point in model.drag(to: point, height: size.height) },
            onMoved: { point, velocity in
                lastVelocity = velocity
                model.drag(to: point, height: size.height)
            },
            onEnded: { model.release(velocity: lastVelocity, height: size.height) },
            onTap: { point in
                Haptics.tap(.soft)
                ignite(at: point)
            }
        )
        .autoplay(ctx.isPreview, every: 3.4, delay: 0.9) {
            ignite(at: CGPoint(x: CGFloat.random(in: 0.2...0.8) * size.width, y: CGFloat.random(in: 0.2...0.8) * size.height))
        }
        .shaderStageHint(L("Drag to fly through · tap to ignite a star", "拖动穿行 · 点击点燃一颗星"), ctx)
    }

    private func ignite(at point: CGPoint) {
        model.ignite(at: point, now: Date().timeIntervalSinceReferenceDate)
    }
}

private struct NebulaSurface: View {
    let state: NebulaState
    let density: Double
    let stars: Double
    let palette: Int

    private var colors: [Color] {
        switch palette {
        case 1: return [Color(hex: 0x2B6BFF), Color(hex: 0x9B4DFF), Color(hex: 0xFF8AD8)]
        case 2: return [Color(hex: 0xC2261C), Color(hex: 0xFF7A1A), Color(hex: 0xFFE08A)]
        default: return [Color(hex: 0xC42BB8), Color(hex: 0x1FB8C9), Color(hex: 0xFFC46B)]
        }
    }

    var body: some View {
        let s = state
        let dn = density
        let st = stars
        let c = colors
        Rectangle()
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.mlNebula(
                        .float2(proxy.size),
                        .float(s.time),
                        .float2(s.pan),
                        .float(dn),
                        .float(st),
                        .color(c[0]),
                        .color(c[1]),
                        .color(c[2]),
                        .float2(s.flare),
                        .float(s.flareAge)
                    )
                )
            }
    }
}
