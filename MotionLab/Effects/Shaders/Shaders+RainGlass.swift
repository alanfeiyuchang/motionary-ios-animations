import SwiftUI

extension Effect {
    static let shaderRainGlass = Effect(
        id: "shader.rain-glass",
        category: .shaders,
        interaction: .tap,
        name: L("Rain on Glass", "雨打玻璃"),
        summary: L(
            "Drops run down a fogged window in fits and starts, each one a tiny upside-down lens; tap to send a heavy drop down.",
            "雨滴在起雾的窗上走走停停地滑落，每一颗都是一枚倒映街景的小透镜；点击让一颗大水滴滑下。"
        ),
        prompt: L(
            "A night street is seen through a fogged window in the rain. The dry glass blurs the lights into soft discs under a grey mist. Small still droplets sit everywhere, slowly swelling and vanishing. Larger drops run down in their own lanes with stick-slip motion: they hang, slide a little, hang again, then fall away, meandering sideways as they go. Each drags a tapering film that wipes the fog clear and leaves a string of beads that shrink along it. Every drop is a lens: the street inside it is sharp, upside-down and bright, with a white glint at top-left and a dark lower rim. Tapping drops a heavy 10 pt bead at the finger, which accelerates down the pane and clears a wide track. Quiet, melancholic and cinematic.",
            "隔着一扇起雾的窗，看雨夜的街道。干燥的玻璃把灯光糊成柔和的光斑，蒙着一层灰雾。到处停着细小的静止水珠，慢慢胀大又消失。较大的雨滴沿各自的路线走走停停地下滑：悬住，滑一小段，再悬住，然后一路坠下，途中还左右蜿蜒。每一滴都拖着一道渐细的水膜，把雾气擦出清晰的痕迹，并留下一串沿途变小的水珠。每颗水滴都是一枚透镜：其中的街景清晰、倒置而明亮，左上有一点白色高光，下缘是一圈暗边。点击会在指尖落下一颗 10pt 的大水滴，它加速滑下窗面，清出一条宽宽的轨迹。安静、带点忧郁、电影感。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader builds a water height field (hashed still droplets, two column-based layers of stick-slip drops with films and beads, three tapped drops), refracts the scene by its finite-difference gradient, and mixes that with an 8-tap fogged blur wherever the glass is dry; a TimelineView feeds time and tap ages.",
            "[[stitchable]] layerEffect 着色器构建水的高度场（哈希生成的静止水珠、两层按列分布且带水膜与水珠串的“粘滑”雨滴、三颗点击水滴），用有限差分梯度折射画面，并在玻璃干燥处混入 8 次采样的起雾模糊；TimelineView 提供时间与各次点击的时长。"
        ),
        apis: ["layerEffect", "TimelineView", "onTapGesture(coordinateSpace:)", "Metal"],
        tags: ["rain", "glass", "droplets", "refraction", "window", "fog", "雨", "玻璃", "水滴", "折射", "窗户", "起雾"],
        params: [
            .slider("amount", L("Rain", "雨量"), 0...1, default: 0.6),
            .slider("refraction", L("Refraction", "折射强度"), 0.2...1.5, default: 0.8),
            .slider("fog", L("Fog", "雾气"), 0...1, default: 0.6),
            .slider("speed", L("Speed", "速度"), 0.3...2, default: 1, decimals: 1),
        ]
    ) { ctx in
        RainGlassDemo(ctx: ctx)
    }
}

private struct RainTap {
    var origin = CGPoint.zero
    var start = Date.distantPast
}

private struct RainGlassDemo: View {
    let ctx: DemoContext
    @State private var clock = BackgroundClock(start: 14)
    @State private var taps = [RainTap(), RainTap(), RainTap()]
    @State private var next = 0

    var body: some View {
        let amount = ctx["amount"]
        let refraction = ctx["refraction"]
        let fog = ctx["fog"]
        let speed = ctx["speed"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let time = ctx.isStill ? 15.2 : clock.advance(to: timeline.date.timeIntervalSinceReferenceDate, speed: speed)
                let drops = ctx.isStill ? [(Float(170), Float(70), Float(0.9)), (0, 0, -1), (0, 0, -1)] : packed(at: timeline.date)
                ShaderStreetScene()
                    .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                    .layerEffect(
                        ShaderLibrary.mlRainGlass(
                            .float2(ShaderKit.card), .float(time), .float(amount), .float(refraction), .float(fog),
                            .float3(drops[0].0, drops[0].1, drops[0].2),
                            .float3(drops[1].0, drops[1].1, drops[1].2),
                            .float3(drops[2].0, drops[2].1, drops[2].2)
                        ),
                        maxSampleOffset: CGSize(width: refraction * 46 + 10, height: refraction * 46 + 10)
                    )
            }
            .shaderCard(glow: Color(hex: 0x3A1E55, opacity: 0.5))
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                Haptics.tap(.soft)
                drop(at: location)
            }
            DemoHint(text: L("Tap the glass to send a drop down", "点击玻璃，让一颗水滴滑下"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.8, delay: 0.6) {
            drop(at: CGPoint(x: CGFloat.random(in: 40...220), y: CGFloat.random(in: 30...130)))
        }
    }

    private func packed(at date: Date) -> [(Float, Float, Float)] {
        taps.map { tap in
            let age = date.timeIntervalSince(tap.start)
            return (Float(tap.origin.x), Float(tap.origin.y), Float(age >= 0 && age < 3.2 ? age : -1))
        }
    }

    private func drop(at point: CGPoint) {
        taps[next] = RainTap(origin: point, start: Date())
        next = (next + 1) % taps.count
    }
}
