import SwiftUI

extension Effect {
    static let shaderSuper8 = Effect(
        id: "shader.super8",
        category: .shaders,
        interaction: .tap,
        name: L("Super 8 Film", "超 8 胶片"),
        summary: L(
            "A home movie on worn film: gate weave, flicker, grain, scratches and dust; tap and the film slips with a light leak.",
            "磨损胶片上的家庭录像：片门晃动、闪烁、颗粒、划痕与灰尘；点击时胶片打滑并漏光。"
        ),
        prompt: L(
            "A beach holiday is projected from worn Super 8 film. The picture weaves in the gate, drifting a pixel or two and jumping slightly on each of 18 frames per second; exposure flickers per frame; coarse grain re-rolls every frame and is strongest in the shadows. The stock is graded warm, with lifted blacks, a gentle S-curve and a heavy vignette inside a soft, round-cornered gate. Thin vertical scratches appear for a moment each and tremble; dust specks and hairs land on single frames. Tapping makes the film slip: the picture rolls up by one full frame in 0.42 s, decelerating, with the black frame bar passing through, while an orange light leak sweeps across and fades in about a second. Nostalgic, imperfect and warm.",
            "一段海滩假日的影像，从磨损的超 8 胶片上放映出来。画面在片门里晃动，漂移一两个像素，并在每秒 18 格的每一格轻轻跳动；曝光逐格闪烁；粗颗粒每格重新生成，暗部最明显。胶片被调成暖色，黑位抬起，带柔和的 S 曲线，圆角柔边的片门内有浓重的暗角。细细的竖向划痕各自出现片刻并微微颤动；灰尘和毛发只落在单独的某一格上。点击会让胶片打滑：画面在 0.42 秒内减速向上滚过一整格，黑色格间线从中穿过，同时一片橙色漏光横扫而过，约一秒内淡去。怀旧、不完美、温暖。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader offsets the sample by noise plus a per-frame hash, blurs with four taps, grades by stock, then adds hashed grain, three scratch slots, per-frame dust cells, a rounded-rectangle gate and, after a tap, an fmod vertical roll with a Gaussian leak; a TimelineView feeds time and the tap's age.",
            "[[stitchable]] layerEffect 着色器用噪声加逐格哈希偏移采样，以四次采样柔化，再按胶片类型调色，随后叠加哈希颗粒、三道划痕、逐格灰尘单元、圆角矩形片门，并在点击后用 fmod 做纵向滚动、叠加高斯形漏光；TimelineView 提供时间与点击后的时长。"
        ),
        apis: ["layerEffect", "TimelineView", "onTapGesture", "Metal"],
        tags: ["film", "super 8", "grain", "vintage", "light leak", "胶片", "超8", "颗粒", "复古", "漏光"],
        params: [
            .slider("grain", L("Grain", "颗粒"), 0...1, default: 0.5),
            .slider("wear", L("Scratches & dust", "划痕与灰尘"), 0...1, default: 0.55),
            .slider("flicker", L("Flicker", "闪烁"), 0...1, default: 0.6),
            .choice("stock", L("Stock", "胶片"), [L("Warm reversal", "暖调反转片"), L("Black & white", "黑白"), L("Faded magenta", "褪色品红")]),
        ]
    ) { ctx in
        Super8Demo(ctx: ctx)
    }
}

private struct Super8Demo: View {
    let ctx: DemoContext
    @State private var clock = BackgroundClock(start: 3)
    @State private var slipStart = Date.distantPast

    var body: some View {
        let grain = ctx["grain"]
        let wear = ctx["wear"]
        let flicker = ctx["flicker"]
        let stock = Double(ctx.int("stock"))
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let time = ctx.isStill ? 3.3 : clock.advance(to: timeline.date.timeIntervalSinceReferenceDate, speed: 1)
                let since = timeline.date.timeIntervalSince(slipStart)
                let slip = ctx.isStill ? 0.5 : (since < 2 ? since : -1)
                ShaderHolidayScene()
                    .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                    .layerEffect(
                        ShaderLibrary.mlSuper8(
                            .float2(ShaderKit.card), .float(time), .float(grain), .float(wear), .float(flicker),
                            .float(stock), .float(slip)
                        ),
                        maxSampleOffset: CGSize(width: 4, height: ShaderKit.card.height + 24)
                    )
            }
            .shaderCard(glow: Color(hex: 0xFF8A3D, opacity: 0.25))
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap(.rigid)
                slipFilm()
            }
            DemoHint(text: L("Tap to make the film slip", "点击让胶片打滑"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.0, delay: 0.8) { slipFilm() }
    }

    private func slipFilm() {
        slipStart = Date()
    }
}
