import SwiftUI

extension Effect {
    static let backgroundsSunsetHorizon = Effect(
        id: "backgrounds.sunset-horizon",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Sunset Horizon", "海上落日"),
        summary: L(
            "A sun sinks into the sea through banded sky colours, laying a shimmering path of light across the water; drag it to scrub the dusk.",
            "太阳穿过层层色带沉入海面，在水上铺出一条粼粼光路；拖动太阳即可拨动暮色。"
        ),
        prompt: L(
            "A seascape with the horizon at 62% of the height. The sky is painted in 8 flat horizontal bands with softly blended edges, sampled from a ramp that travels with the sun's elevation: blue over pale gold while it is high, violet through coral to amber as it touches the horizon, deep indigo and wine once it has set, when stars fade in. The sun is a gradient disc with a wide additive halo; it sinks and rises on a 24 s cosine cycle, flattens by 12% near the horizon and is clipped by the waterline. Below, 26 reflection glints stack toward the viewer with growing spacing and thickness; each one's width flickers and its centre wobbles sideways on its own phase, so the path of light shimmers. Dragging moves the sun on a spring (stiffness 40, damping 0.8) and every colour follows. Warm, calm, cinematic.",
            "海平线位于画面高度 62% 处的海景。天空由 8 条边缘柔和过渡的水平色带组成，取色随太阳高度变化：太阳高时上蓝下淡金，触及海平线时由紫经珊瑚到琥珀，落下之后是深靛与酒红，星星随之浮现。太阳是带大范围叠加光晕的渐变圆盘，按 24 秒的余弦周期沉落与升起，接近海平线时压扁 12%，并被水线裁切。水面上 26 道反光由远及近排列，间距与厚度逐渐加大；每道的宽度各自闪烁，中心按各自相位左右轻晃，光路因此粼粼波动。拖动可用弹簧（刚度 40、阻尼 0.8）移动太阳，所有颜色随之变化。温暖、宁静、有电影感。"
        ),
        implementation: L(
            "One Canvas: the sky is a linear gradient with two stops per band (flat core, soft seam) sampled from three blended palettes; the sun is drawn in a context clipped to the sky, and the reflection is a set of capsules batched into three Paths and filled with plusLighter.",
            "单个 Canvas：天空是每条色带两个色标（平色带芯、柔和接缝）的线性渐变，取自三套按太阳高度混合的色板；太阳绘制在裁剪到天空区域的上下文里，倒影是合并进三条 Path 的胶囊形，以 plusLighter 填充。"
        ),
        apis: ["Canvas", "GraphicsContext.clip(to:)", "GraphicsContext.Shading.linearGradient", "TimelineView(.animation)", "DragGesture"],
        tags: ["sunset", "horizon", "sea", "reflection", "日落", "海平线", "夕阳", "倒影"],
        params: [
            .slider("bands", L("Sky bands", "天空色带"), 3...14, default: 8, step: 1, decimals: 0),
            .slider("shimmer", L("Shimmer", "波光"), 0...1, default: 0.7),
            .slider("cycle", L("Day length", "一日时长"), 8...60, default: 24, decimals: 0, unit: "s"),
        ]
    ) { ctx in
        SunsetHorizonDemo(ctx: ctx)
    }
}

private final class SunsetModel {
    let clock = BackgroundClock()
    let pointer = BackgroundPointer()
}

private struct SunsetHorizonDemo: View {
    let ctx: DemoContext
    @State private var model = SunsetModel()

    var body: some View {
        ZStack {
            Color(hex: 0x1B1340)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.clock.advance(to: now, speed: 1)
                    let horizon = size.height * 0.62
                    let travel = size.height * 0.5
                    // A still shows the sun half set.
                    let phase = ctx.isStill ? 2.05 : (t - 100) * BackgroundMath.tau / max(ctx["cycle"], 1) + 1.1
                    let auto = CGPoint(
                        x: size.width * CGFloat(0.5 + 0.1 * sin(phase * 0.5)),
                        y: horizon - travel * CGFloat(0.36 + 0.56 * cos(phase))
                    )
                    let sun = model.pointer.step(now: now, idle: auto, stiffness: 40, damping: 0.8, frozen: ctx.isStill)
                    let elevation = Double(((horizon - sun.y) / travel).clamped(to: -0.3...1.1))
                    SunsetPainter.draw(
                        &context, size: size, t: t, sun: CGPoint(x: sun.x, y: horizon - CGFloat(elevation) * travel),
                        elevation: elevation, bands: max(ctx.int("bands"), 2), shimmer: ctx["shimmer"]
                    )
                }
            }
        }
        .backgroundsTouch { location in
            if !model.pointer.userTouched { Haptics.tap(.soft) }
            model.pointer.userTouched = true
            model.pointer.touch = location
        } onEnded: {
            model.pointer.touch = nil
        }
        .backgroundsChipHint(L("Swipe sideways, then drag the sun", "先横向滑动，再拖动太阳"), ctx)
    }
}

private enum SunsetPainter {
    // Top → horizon, for a high sun, a sun on the horizon and after sunset.
    static let day: [BackgroundRGB] = [.init(hex: 0x2E5C9E), .init(hex: 0x5E8FC4), .init(hex: 0xF2C48D), .init(hex: 0xFFE2A8)]
    static let dusk: [BackgroundRGB] = [.init(hex: 0x2A1B5E), .init(hex: 0x8A2E7A), .init(hex: 0xF0594A), .init(hex: 0xFFB347)]
    static let night: [BackgroundRGB] = [.init(hex: 0x070A24), .init(hex: 0x1F1147), .init(hex: 0x5A1E5C), .init(hex: 0xC2456A)]

    static func sky(_ f: Double, dusk d: Double) -> BackgroundRGB {
        let a = BackgroundRGB.ramp(day, f)
        let b = BackgroundRGB.ramp(dusk, f)
        let c = BackgroundRGB.ramp(night, f)
        return d < 0.5 ? a.mix(b, d * 2) : b.mix(c, d * 2 - 1)
    }

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, sun: CGPoint, elevation: Double, bands: Int, shimmer: Double
    ) {
        let horizon = size.height * 0.62
        let d = 1 - BackgroundMath.smoothstep(-0.2, 0.8, elevation)
        let radius = size.width * 0.13
        let low = 1 - BackgroundMath.smoothstep(-0.1, 0.4, elevation)

        // Banded sky: a flat core per band with a soft seam between bands.
        var stops: [Gradient.Stop] = []
        for i in 0..<bands {
            let color = sky((Double(i) + 0.5) / Double(bands), dusk: d).color()
            stops.append(.init(color: color, location: (CGFloat(i) + 0.2) / CGFloat(bands)))
            stops.append(.init(color: color, location: (CGFloat(i) + 0.8) / CGFloat(bands)))
        }
        let skyRect = CGRect(x: 0, y: 0, width: size.width, height: horizon)
        context.fill(Path(skyRect), with: .linearGradient(Gradient(stops: stops), startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))

        // Stars come out once the sun is down.
        let night = BackgroundMath.smoothstep(0.6, 1, d)
        if night > 0.01 {
            var stars = Path()
            for i in 0..<46 {
                let twinkle = 0.6 + 0.4 * sin(t * (1.2 + 2 * BackgroundMath.rand(i, 2203)) + Double(i))
                let r = (0.5 + 0.9 * BackgroundMath.unit(i, 2201)) * CGFloat(twinkle)
                let x = size.width * BackgroundMath.unit(i, 2204)
                let y = horizon * 0.8 * BackgroundMath.unit(i, 2205)
                stars.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            context.fill(stars, with: .color(.white.opacity(night * 0.85)))
        }

        let top = BackgroundRGB(hex: 0xFFF3B0).mix(BackgroundRGB(hex: 0xFFC25A), low)
        let bottom = BackgroundRGB(hex: 0xFF9A3D).mix(BackgroundRGB(hex: 0xFF3D54), low)
        let glowColor = top.mix(bottom, 0.5)
        let above = BackgroundMath.smoothstep(-0.3, 0.05, elevation)

        // Sun, halo and horizon glow, cut by the waterline.
        var skyContext = context
        skyContext.clip(to: Path(skyRect))
        skyContext.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.backgroundsGlow(at: CGPoint(x: sun.x, y: horizon), radius: size.width * 0.85, color: glowColor.color(0.32 + 0.22 * low), squash: 0.34)
            layer.backgroundsGlow(at: sun, radius: radius * 3.4, color: glowColor.color(0.55))
        }
        let squash = 1 - 0.12 * CGFloat(low)
        let disc = CGRect(x: sun.x - radius, y: sun.y - radius * squash, width: radius * 2, height: radius * 2 * squash)
        skyContext.fill(
            Path(ellipseIn: disc),
            with: .linearGradient(
                Gradient(colors: [top.color(), bottom.color()]),
                startPoint: CGPoint(x: sun.x, y: disc.minY), endPoint: CGPoint(x: sun.x, y: disc.maxY)
            )
        )

        // Water: a darkened mirror of the sky.
        let waterRect = CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)
        let water = Gradient(colors: [
            sky(1, dusk: d).scaled(0.6).mix(BackgroundRGB(hex: 0x14366A), 0.3).color(),
            sky(0.55, dusk: d).scaled(0.4).mix(BackgroundRGB(hex: 0x0C2450), 0.3).color(),
            sky(0, dusk: d).scaled(0.34).color(),
        ])
        context.fill(Path(waterRect), with: .linearGradient(water, startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)))

        // Dark swell lines drifting toward the viewer.
        var swell = Path()
        for i in 0..<12 {
            let f = BackgroundMath.fract(Double(i) / 12 + t * 0.012)
            let y = horizon + (size.height - horizon) * CGFloat(pow(f, 1.8))
            let x = size.width * (BackgroundMath.unit(i, 2211) * 1.2 - 0.1)
            let w = size.width * CGFloat(0.12 + 0.3 * f)
            swell.addRoundedRect(in: CGRect(x: x - w / 2, y: y, width: w, height: 0.8 + 1.6 * CGFloat(f)), cornerSize: CGSize(width: 1, height: 1))
        }
        context.fill(swell, with: .color(.black.opacity(0.14)))

        drawReflection(&context, size: size, t: t, sun: sun, radius: radius, shimmer: shimmer, color: top.mix(bottom, 0.35), strength: above)

        // Bright seam along the horizon.
        context.fill(
            Path(CGRect(x: 0, y: horizon - 0.5, width: size.width, height: 1)),
            with: .color(sky(1, dusk: d).mix(BackgroundRGB(1, 1, 1), 0.4).color(0.5))
        )
    }

    private static func drawReflection(
        _ context: inout GraphicsContext, size: CGSize, t: Double, sun: CGPoint, radius: CGFloat, shimmer: Double,
        color: BackgroundRGB, strength: Double
    ) {
        guard strength > 0.01 else { return }
        let horizon = size.height * 0.62
        let depth = size.height - horizon
        let rows = 26
        var bins = [Path](repeating: Path(), count: 3)
        for k in 0..<rows {
            let f = Double(k + 1) / Double(rows)
            let y = horizon + depth * CGFloat(pow(f, 1.6))
            let thickness = 0.9 + 3.6 * CGFloat(f)
            let flicker = 0.5 + 0.5 * sin(t * (1.6 + 1.3 * BackgroundMath.rand(k, 2221)) + Double(k) * 1.7)
            let width = radius * 2 * CGFloat(0.5 + 1.25 * f) * CGFloat(1 - shimmer * 0.6 * flicker)
            let wobble = CGFloat(sin(t * 1.3 + Double(k) * 0.9)) * 7 * CGFloat(shimmer) * CGFloat(0.25 + f)
            let level = min(Int((1 - f * 0.75) * 3), 2)
            let corner = CGSize(width: thickness / 2, height: thickness / 2)
            // A solid core, two flanking dashes that blink, and loose glints further out.
            let core = width * 0.56
            bins[level].addRoundedRect(in: CGRect(x: sun.x + wobble - core / 2, y: y, width: core, height: thickness), cornerSize: corner)
            for side in 0..<2 {
                let seed = k * 2 + side
                let sign: CGFloat = side == 0 ? -1 : 1
                let blink = sin(t * (2.1 + 1.7 * BackgroundMath.rand(seed, 2222)) + Double(seed) * 2.3)
                let w = width * CGFloat(0.13 + 0.15 * BackgroundMath.rand(seed, 2223))
                let gap = 3 + 6 * CGFloat(f)
                if blink > -0.5 {
                    bins[level].addRoundedRect(
                        in: CGRect(x: sun.x + wobble + sign * (core / 2 + gap + w / 2) - w / 2, y: y, width: w, height: thickness),
                        cornerSize: corner
                    )
                }
                guard blink > 1 - shimmer * 0.9 else { continue }
                let far = core / 2 + gap * 2 + w + width * CGFloat(0.12 + 0.3 * BackgroundMath.rand(seed, 2224))
                bins[max(level - 1, 0)].addRoundedRect(
                    in: CGRect(x: sun.x + wobble + sign * far - w * 0.4, y: y, width: w * 0.8, height: thickness * 0.8), cornerSize: corner
                )
            }
        }
        var water = context
        water.clip(to: Path(CGRect(x: 0, y: horizon, width: size.width, height: depth)))
        water.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.backgroundsGlow(
                at: CGPoint(x: sun.x, y: horizon + depth * 0.3), radius: depth * 0.9, color: color.color(0.3 * strength), squash: 1
            )
            for level in 0..<3 {
                layer.fill(bins[level], with: .color(color.mix(BackgroundRGB(1, 1, 1), 0.25).color((0.3 + 0.27 * Double(level)) * strength)))
            }
        }
    }
}
