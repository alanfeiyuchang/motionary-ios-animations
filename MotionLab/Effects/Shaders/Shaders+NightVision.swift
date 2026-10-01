import SwiftUI

extension Effect {
    static let shaderNightVision = Effect(
        id: "shader.night-vision",
        category: .shaders,
        interaction: .gesture,
        name: L("Night Vision", "夜视仪"),
        summary: L(
            "A pitch-dark forest through an image intensifier; drag the infrared beam to find what hides there, tap to overload the tube.",
            "透过微光夜视仪看漆黑的森林；拖动红外光束找出藏着的东西，点击让像管过曝。"
        ),
        prompt: L(
            "A forest clearing is almost black to the eye. Through the intensifier its faint luminance is amplified 3.2× and mapped onto green phosphor, from near-black through emerald to a pale, almost white green. An infrared beam of 80 pt radius multiplies the gain again where it points, so the deer, the owl and the tent only read clearly inside it; eyes and the moon bloom into soft halos. Dragging aims the beam, which trails the finger with a smooth lag of about 0.15 s, and a reticle rides with it. Noise re-rolls 30 times a second with rare bright sparks, fine scan lines cross the image, and it sits in a round tube with barrel distortion and dark corners. Tapping overloads the tube: a white-out fades in 0.2 s while the gain dips and recovers within a second. Tense, tactical and grainy.",
            "一片林间空地，肉眼看去几乎全黑。夜视仪把微弱的亮度放大 3.2 倍，映射到绿色荧光屏上：从近黑、翠绿到近白的浅绿。一束半径 80pt 的红外光在所指之处把增益再放大一轮，鹿、猫头鹰和帐篷只有在光束里才看得清；眼睛与月亮晕出柔和的光环。拖动即可瞄准光束，它带着约 0.15 秒的平滑滞后跟随手指，准星随之移动。噪点每秒重新生成 30 次，偶有亮斑闪现，细密的扫描线横过画面，画面嵌在带桶形畸变和暗角的圆形像管里。点击让像管过曝：白光在 0.2 秒内退去，增益随之下沉，一秒内恢复。紧张、战术感、粗粝。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader samples with barrel distortion, multiplies luminance by gain and a Gaussian beam term, adds an 8-tap bloom of bright pixels, hashed noise at 30 Hz and scan lines, tone-maps with 1 − e^(−1.6v) into a green ramp and masks a round port. A model stepped by TimelineView smooths the beam toward the finger.",
            "[[stitchable]] layerEffect 着色器带桶形畸变采样，把亮度乘以增益和高斯形光束项，加上对亮像素的 8 次采样辉光、30Hz 的哈希噪点与扫描线，用 1 − e^(−1.6v) 做色调映射后套上绿色色阶，并遮出圆形视窗。由 TimelineView 逐帧推进的模型让光束平滑地追向手指。"
        ),
        apis: ["layerEffect", "TimelineView", "DragGesture", "Canvas", "Metal"],
        tags: ["night vision", "infrared", "green", "phosphor", "noise", "夜视", "红外", "绿色", "荧光", "噪点"],
        params: [
            .slider("gain", L("Gain", "增益"), 1...6, default: 3.2, decimals: 1, unit: "×"),
            .slider("noise", L("Noise", "噪点"), 0...1, default: 0.45),
            .slider("radius", L("Beam radius", "光束半径"), 40...140, default: 80, decimals: 0, unit: "pt"),
            .slider("bloom", L("Bloom", "辉光"), 0...1, default: 0.6),
        ]
    ) { ctx in
        NightVisionDemo(ctx: ctx)
    }
}

private struct NightVisionState {
    let time: Double
    let beam: CGPoint
    let flash: Double
}

private final class NightVisionModel {
    private let clock = BackgroundClock(start: 2)
    private var beam = CGPoint(x: 150, y: 200)
    private var target = CGPoint(x: 150, y: 200)
    private var flashStart: Double = -100

    func aim(at point: CGPoint) {
        target = CGPoint(x: min(max(point.x, 10), ShaderKit.card.width - 10), y: min(max(point.y, 10), ShaderKit.card.height - 10))
    }

    func overload(now: Double) {
        flashStart = now
    }

    func step(now: Double) -> NightVisionState {
        let time = clock.advance(to: now, speed: 1)
        let k = CGFloat(clock.follow(rate: 7))
        beam.x += (target.x - beam.x) * k
        beam.y += (target.y - beam.y) * k
        let age = now - flashStart
        return NightVisionState(time: time, beam: beam, flash: age < 3 ? age : -1)
    }

    static let still = NightVisionState(time: 2.4, beam: CGPoint(x: 172, y: 204), flash: -1)
}

private struct NightVisionDemo: View {
    let ctx: DemoContext
    @State private var model = NightVisionModel()
    @State private var turn = 0

    /// Where the simulated operator looks: deer, owl, tent, moon, undergrowth.
    private static let sweep: [CGPoint] = [
        CGPoint(x: 176, y: 204), CGPoint(x: 168, y: 82), CGPoint(x: 64, y: 232), CGPoint(x: 198, y: 50), CGPoint(x: 120, y: 262),
    ]

    var body: some View {
        let gain = ctx["gain"]
        let noise = ctx["noise"]
        let radius = ctx["radius"]
        let bloom = ctx["bloom"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let state = ctx.isStill ? NightVisionModel.still : model.step(now: timeline.date.timeIntervalSinceReferenceDate)
                ShaderForestScene()
                    .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                    .layerEffect(
                        ShaderLibrary.mlNightVision(
                            .float2(ShaderKit.card), .float(state.time), .float(gain), .float(noise),
                            .float2(state.beam), .float(radius), .float(bloom), .float(state.flash)
                        ),
                        maxSampleOffset: CGSize(width: 24, height: 24)
                    )
                    .overlay { NightVisionHUD(beam: state.beam, gain: gain, time: state.time) }
            }
            .shaderCard(glow: Color(hex: 0x21D45A, opacity: 0.22))
            .shaderTouch(
                onBegan: { point in
                    Haptics.tap(.soft)
                    model.aim(at: point)
                },
                onMoved: { point, _ in model.aim(at: point) },
                onTap: { point in
                    Haptics.tap(.rigid)
                    model.aim(at: point)
                    model.overload(now: Date().timeIntervalSinceReferenceDate)
                }
            )
            DemoHint(text: L("Drag the beam · tap to overload", "拖动光束 · 点击过曝"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.4) { look() }
    }

    /// Simulated operator: aims at the next subject, and overloads the tube on every fourth look.
    private func look() {
        model.aim(at: Self.sweep[turn % Self.sweep.count])
        if turn % 4 == 3 { model.overload(now: Date().timeIntervalSinceReferenceDate) }
        turn += 1
    }
}

/// Reticle and read-outs in phosphor green, drawn over the tube.
private struct NightVisionHUD: View {
    let beam: CGPoint
    let gain: Double
    let time: Double

    var body: some View {
        Canvas { context, size in
            let green = Color(hex: 0xB8FFC4, opacity: 0.85)
            var reticle = Path()
            reticle.addEllipse(in: CGRect(x: beam.x - 16, y: beam.y - 16, width: 32, height: 32))
            for k in 0..<4 {
                let a = CGFloat(k) * .pi / 2
                reticle.move(to: CGPoint(x: beam.x + cos(a) * 22, y: beam.y + sin(a) * 22))
                reticle.addLine(to: CGPoint(x: beam.x + cos(a) * 34, y: beam.y + sin(a) * 34))
            }
            context.stroke(reticle, with: .color(green), lineWidth: 1.2)
            context.fill(Path(ellipseIn: CGRect(x: beam.x - 1.5, y: beam.y - 1.5, width: 3, height: 3)), with: .color(green))
            let blink = time.truncatingRemainder(dividingBy: 1) < 0.5
            context.draw(
                Text(verbatim: "IR 850 nm").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(green),
                at: CGPoint(x: 44, y: 46), anchor: .leading
            )
            context.draw(
                Text(verbatim: String(format: "GAIN ×%.1f", gain)).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(green),
                at: CGPoint(x: size.width - 44, y: 46), anchor: .trailing
            )
            if blink {
                context.fill(Path(ellipseIn: CGRect(x: 44, y: size.height - 50, width: 6, height: 6)), with: .color(green))
            }
            context.draw(
                Text(verbatim: "REC").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(green),
                at: CGPoint(x: 55, y: size.height - 47), anchor: .leading
            )
        }
        .allowsHitTesting(false)
    }
}
