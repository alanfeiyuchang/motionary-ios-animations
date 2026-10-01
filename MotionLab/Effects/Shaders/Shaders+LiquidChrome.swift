import SwiftUI

extension Effect {
    static let shaderLiquidChrome = Effect(
        id: "shader.liquid-chrome",
        category: .shaders,
        interaction: .gesture,
        name: L("Liquid Chrome", "液态铬金属"),
        summary: L(
            "Molten mirror metal that flows on its own; press a dent into it and let go to send a ring through.",
            "自行流淌的镜面熔融金属；按下去压出一个凹坑，松手时荡开一圈波纹。"
        ),
        prompt: L(
            "The whole stage is a pool of liquid metal. A height field of two soft noise octaves, warped by two more noise fields and a long swell, drifts slowly; its slope becomes a surface normal, and the mirror reflection of the view looks up a procedural photo studio — a bright sky, a hard black horizon line, a pale floor and softbox stripes. That sharp horizon wrapping through the folds is what reads as polished chrome, topped with pin-sharp specular glints. Pressing sinks a 64 pt dent that follows the finger (easing in over ≈ 0.2 s) and bends every reflection around it; letting go sends one ring outward at 230 pt/s that decays within about 2 s. Finishes: chrome, gold or an iridescent oil film. Heavy, expensive and mesmerising.",
            "舞台是一池液态金属。两个柔和倍频的噪声构成高度场，被另外两层噪声和一道长涌浪扭曲后缓缓漂移；它的斜率换算成表面法线，视线的镜面反射再去查询一座程序化的摄影棚——明亮的天幕、一条生硬的黑色地平线、浅色地面与柔光箱条纹。正是这条锐利的地平线在褶皱间弯绕，才让表面读起来像抛光的铬，再点缀针尖般的镜面高光。按下会压出一个 64pt 的凹坑，跟随手指（约 0.2 秒缓入），周围所有反射都绕着它弯曲；松手时一圈波纹以 230pt/s 向外荡开，约 2 秒内消失。可选铬、金或虹彩油膜。沉重、昂贵、迷人。"
        ),
        implementation: L(
            "A [[stitchable]] color shader evaluates the warped noise height three times for a finite-difference normal, reflects the view vector and shades it with an analytic studio environment, a tint and an optional cosine thin-film; a small model eases the dent toward the finger and timestamps the release ring.",
            "[[stitchable]] colorEffect 着色器对扭曲后的噪声高度场求值三次，以有限差分得到法线，反射视线后用解析的摄影棚环境、金属色与可选的余弦薄膜干涉着色；一个小模型让凹坑平滑追随手指，并为松手的波纹记录时间。"
        ),
        apis: ["colorEffect", "visualEffect", "TimelineView", "DragGesture", "Metal"],
        tags: ["chrome", "liquid metal", "mercury", "reflection", "generative", "液态金属", "铬", "水银", "反射", "生成"],
        params: [
            .slider("speed", L("Flow speed", "流动速度"), 0.2...2.5, default: 1, decimals: 1),
            .slider("scale", L("Ripple density", "波纹密度"), 0.8...4, default: 2, decimals: 1),
            .slider("relief", L("Relief", "起伏深度"), 0.2...1.2, default: 0.6),
            .choice("finish", L("Finish", "表面"), [L("Chrome", "铬"), L("Gold", "金"), L("Oil film", "油膜")]),
        ]
    ) { ctx in
        LiquidChromeDemo(ctx: ctx)
    }
}

private struct ChromeState {
    let time: Double
    let touch: CGPoint
    let press: Double
    let ripple: CGPoint
    let rippleAge: Double
}

private final class ChromeModel {
    let clock = BackgroundClock(start: 40)
    var finger: CGPoint?
    private var touch = CGPoint(x: 170, y: 170)
    private var press: Double = 0
    private var ripple = CGPoint(x: 170, y: 170)
    private var rippleStart: Double = -100

    func drop(at point: CGPoint, now: Double) {
        ripple = point
        rippleStart = now
    }

    func step(now: Double, speed: Double, size: CGSize, auto: Bool) -> ChromeState {
        let time = clock.advance(to: now, speed: speed)
        var target: CGPoint?
        if let finger {
            target = finger
        } else if auto {
            // Simulated finger: a slow orbit that keeps a dent travelling through the metal.
            target = CGPoint(
                x: size.width / 2 + size.width * 0.26 * CGFloat(cos(now * 0.6)),
                y: size.height / 2 + size.height * 0.22 * CGFloat(sin(now * 0.85))
            )
        }
        if let target {
            let k = CGFloat(clock.follow(rate: 12))
            touch.x += (target.x - touch.x) * k
            touch.y += (target.y - touch.y) * k
            press += ((auto && finger == nil ? 0.7 : 1) - press) * clock.follow(rate: 11)
        } else {
            press += (0 - press) * clock.follow(rate: 6)
        }
        let age = now - rippleStart
        return ChromeState(time: time, touch: touch, press: press, ripple: ripple, rippleAge: age < 3 ? age : -1)
    }
}

private struct LiquidChromeDemo: View {
    let ctx: DemoContext
    @State private var model = ChromeModel()
    @State private var size = CGSize(width: 340, height: 340)
    @State private var last = CGPoint(x: 170, y: 170)

    var body: some View {
        let speed = ctx["speed"]
        let scale = ctx["scale"]
        let relief = ctx["relief"]
        let finish = ctx.int("finish")
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let state = model.step(
                now: timeline.date.timeIntervalSinceReferenceDate,
                speed: speed,
                size: size,
                auto: ctx.isPreview && !ctx.isStill
            )
            ChromeSurface(state: state, scale: scale, relief: relief, finish: finish)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .shaderTouch(
            onBegan: { point in
                last = point
                Haptics.tap(.soft)
            },
            onMoved: { point, _ in
                last = point
                model.finger = point
            },
            onEnded: {
                model.finger = nil
                drop(at: last)
            },
            onTap: { point in
                Haptics.tap(.soft)
                drop(at: point)
            }
        )
        .autoplay(ctx.isPreview, every: 3.2, delay: 0.8) {
            drop(at: CGPoint(x: CGFloat.random(in: 0.25...0.75) * size.width, y: CGFloat.random(in: 0.25...0.75) * size.height))
        }
        .shaderStageHint(L("Press and drag the metal, let go for a ripple", "按住拖动金属，松手荡开波纹"), ctx)
    }

    private func drop(at point: CGPoint) {
        model.drop(at: point, now: Date().timeIntervalSinceReferenceDate)
    }
}

private struct ChromeSurface: View {
    let state: ChromeState
    let scale: Double
    let relief: Double
    let finish: Int

    var body: some View {
        let s = state
        let sc = scale
        let rl = relief
        let tint: Color = finish == 1 ? Color(hex: 0xFFC861) : Color(hex: 0xF4F7FF)
        let film: Double = finish == 2 ? 0.75 : 0
        Rectangle()
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.mlLiquidChrome(
                        .float2(proxy.size),
                        .float(s.time),
                        .float(sc),
                        .float(rl),
                        .color(tint),
                        .float(film),
                        .float2(s.touch),
                        .float(s.press),
                        .float2(s.ripple),
                        .float(s.rippleAge)
                    )
                )
            }
    }
}
