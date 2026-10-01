import SwiftUI

extension Effect {
    static let shaderHeatHaze = Effect(
        id: "shader.heat-haze",
        category: .shaders,
        interaction: .gesture,
        name: L("Heat Haze", "热浪蒸腾"),
        summary: L(
            "Hot air shimmers up from the ground; your finger becomes a heat source with its own rising plume.",
            "热空气从地面向上抖动蒸腾；手指就是一处热源，上方升起自己的热柱。"
        ),
        prompt: L(
            "A desert road at sunset shimmers in rising heat. Two layers of fractal noise, stretched 1.9× vertically and scrolling upward, push every pixel sideways by up to 9 pt (and 45% as much vertically); the amount follows height^1.6, so the horizon and sun barely move while the road boils. A second, softer sample at 35% of the offset is blended in, smearing detail the way hot air does, and the picture washes slightly toward warm white. Touching the card adds a heat source: a Gaussian plume about 30 pt wide at the finger that widens and fades over 170 pt as it rises, easing in over ≈ 0.25 s and out over ≈ 0.6 s. Lazy, sun-baked, hypnotic.",
            "夕阳下的沙漠公路在热浪中晃动。两层分形噪声沿竖直方向拉长 1.9 倍并持续向上滚动，把每个像素横向推移最多 9pt（纵向为其 45%）；强度按高度的 1.6 次方分布，地平线与太阳几乎不动，路面却像在沸腾。再叠加一次偏移量为 35% 的柔和采样，让细节像隔着热空气一样发虚，画面略微泛出暖白。手指触碰卡片即成为热源：指尖处升起宽约 30pt 的高斯热柱，上升中逐渐变宽，并在约 170pt 内消散；出现约 0.25 秒、消退约 0.6 秒。慵懒、炙热、令人出神。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader offsets the sample by two fbm fields whose y coordinate scrolls with time, scaled by pow(y / height, falloff) plus a Gaussian plume above the touch point; a TimelineView feeds accumulated time and a small model eases the plume's position and gain toward the finger.",
            "[[stitchable]] layerEffect 着色器用两层 y 坐标随时间滚动的 fbm 噪声偏移采样点，强度为 pow(y / 高度, falloff) 加上触点上方的高斯热柱；TimelineView 提供累积时间，一个小模型把热柱的位置与强度平滑地追向手指。"
        ),
        apis: ["layerEffect", "TimelineView", "fbm noise", "DragGesture", "Metal"],
        tags: ["heat", "haze", "shimmer", "mirage", "distortion", "热浪", "蒸腾", "海市蜃楼", "扭曲"],
        params: [
            .slider("strength", L("Shimmer", "抖动幅度"), 2...16, default: 9, decimals: 0, unit: "pt"),
            .slider("scale", L("Turbulence size", "湍流尺度"), 12...60, default: 26, decimals: 0, unit: "pt"),
            .slider("falloff", L("Ground hug", "贴地程度"), 0.5...4, default: 1.6, decimals: 1),
            .slider("speed", L("Rise speed", "上升速度"), 0.3...3, default: 1, decimals: 1),
        ]
    ) { ctx in
        HeatHazeDemo(ctx: ctx)
    }
}

private struct HeatState {
    let time: Double
    let source: CGPoint
    let gain: Double
}

private final class HeatModel {
    let clock = BackgroundClock(start: 0)
    var touch: CGPoint?
    var pokeUntil: Double = 0
    private var source = CGPoint(x: 130, y: 236)
    private var gain: Double = 0

    func step(now: Double, speed: Double, auto: Bool, still: Bool) -> HeatState {
        let time = clock.advance(to: now, speed: speed)
        if still {
            return HeatState(time: 2.4, source: CGPoint(x: 150, y: 232), gain: 1)
        }
        var target: CGPoint?
        if let touch, now < pokeUntil || pokeUntil == 0 {
            target = touch
        } else if auto {
            // Simulated finger: a slow sweep along the road.
            target = CGPoint(x: 130 + 78 * sin(now * 0.55), y: 232 + 22 * sin(now * 0.9))
        }
        if let target {
            let k = CGFloat(clock.follow(rate: 9))
            source.x += (target.x - source.x) * k
            source.y += (target.y - source.y) * k
            gain += (1 - gain) * clock.follow(rate: 9)
        } else {
            gain += (0 - gain) * clock.follow(rate: 4)
        }
        return HeatState(time: time, source: source, gain: gain)
    }

    func hold(_ point: CGPoint) {
        touch = point
        pokeUntil = 0
    }

    func poke(_ point: CGPoint, now: Double) {
        touch = point
        pokeUntil = now + 0.9
    }

    func release() {
        touch = nil
        pokeUntil = 0
    }
}

private struct HeatHazeDemo: View {
    let ctx: DemoContext
    @State private var model = HeatModel()

    var body: some View {
        let strength = ctx["strength"]
        let scale = ctx["scale"]
        let falloff = ctx["falloff"]
        let speed = ctx["speed"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let state = model.step(
                    now: timeline.date.timeIntervalSinceReferenceDate,
                    speed: speed,
                    auto: ctx.isPreview,
                    still: ctx.isStill
                )
                HeatSurface(state: state, strength: strength, scale: scale, falloff: falloff)
            }
            .shaderCard(glow: Color(hex: 0xFF7A3D, opacity: 0.32))
            .shaderTouch(
                onBegan: { _ in Haptics.tap(.soft) },
                onMoved: { point, _ in model.hold(point) },
                onEnded: { model.release() },
                onTap: { point in
                    Haptics.tap(.soft)
                    model.poke(point, now: Date().timeIntervalSinceReferenceDate)
                }
            )
            DemoHint(text: L("Touch and drag to add heat", "按住拖动，添加热源"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HeatSurface: View {
    let state: HeatState
    let strength: Double
    let scale: Double
    let falloff: Double

    var body: some View {
        ShaderDesertScene()
            .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
            .layerEffect(
                ShaderLibrary.mlHeatHaze(
                    .float2(ShaderKit.card),
                    .float(state.time),
                    .float(strength),
                    .float(scale),
                    .float(falloff),
                    .float2(state.source),
                    .float(state.gain)
                ),
                maxSampleOffset: CGSize(width: strength * 2.5 + 1, height: strength * 1.2 + 1)
            )
    }
}
