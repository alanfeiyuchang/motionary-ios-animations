import SwiftUI

extension Effect {
    static let shaderLightningArcs = Effect(
        id: "shader.lightning-arcs",
        category: .shaders,
        interaction: .gesture,
        name: L("Plasma Globe Arcs", "等离子球电弧"),
        summary: L(
            "Electric arcs crawl from an electrode to the glass of a plasma globe; touch it and they gather at your finger.",
            "电弧从电极爬向等离子球的玻璃壁；手指一碰，它们就向指尖聚拢。"
        ),
        prompt: L(
            "A plasma globe sits on a dark stage: a glass sphere with a small electrode at its centre and five thin arcs reaching out to the glass. Each arc is a jagged filament with a white core and a violet halo; its kinks crawl along its length while both ends stay pinned, its far end wanders slowly round the glass, and its brightness flickers 24 times a second. Touching the glass draws the arcs to the finger: within about 0.2 s three of them bend over and meet there, thicker and brighter, a glow blooms at the contact and the rest dim; on release they drift apart again over half a second. A tap fires one fat bolt to that point with a flash that decays in a quarter of a second. Electric, alive and irresistible to touch.",
            "暗色舞台上放着一只等离子球：玻璃球体中心有一个小电极，五道纤细的电弧伸向玻璃壁。每道电弧都是一根曲折的细丝，白色的芯、紫色的光晕；它的折点沿弧身不断爬行，两端却始终固定，远端缓缓绕着玻璃游走，亮度每秒闪烁 24 次。触摸玻璃会把电弧引向指尖：约 0.2 秒内其中三道弯折过来汇聚于此，变得更粗更亮，接触点绽开一团辉光，其余的随之变暗；松手后它们在半秒内重新散开。点击则向该点打出一道粗壮的闪电，伴随一次白光，在四分之一秒内衰减。带电、鲜活，让人忍不住想摸。"
        ),
        implementation: L(
            "A [[stitchable]] color shader sums, for up to six arcs, a glow of 1/distance to a segment whose points are displaced sideways by three octaves of value noise under a sin(π·t) envelope; end points blend from wandering rim positions to the finger by a pull value. A model stepped by TimelineView smooths the pull and times the strike.",
            "[[stitchable]] colorEffect 着色器对最多六道电弧求和：每道是“到线段距离的倒数”辉光，线段上的点在 sin(π·t) 包络下被三层值噪声横向偏移；端点按“牵引”值从玻璃壁上游走的位置过渡到手指。由 TimelineView 逐帧推进的模型平滑牵引值，并为闪击计时。"
        ),
        apis: ["colorEffect", "visualEffect", "TimelineView", "DragGesture", "Metal"],
        tags: ["lightning", "plasma globe", "arc", "electric", "tesla", "闪电", "等离子球", "电弧", "电", "特斯拉"],
        params: [
            .slider("arcs", L("Arcs", "电弧数量"), 1...6, default: 5, decimals: 0),
            .slider("jag", L("Jaggedness", "曲折程度"), 0...1, default: 0.7),
            .slider("speed", L("Crawl speed", "爬行速度"), 0.3...2.5, default: 1, decimals: 1),
            .choice("color", L("Gas", "气体"), [L("Violet", "紫"), L("Cyan", "青"), L("Amber", "琥珀")]),
        ]
    ) { ctx in
        LightningDemo(ctx: ctx)
    }
}

private struct LightningState {
    let time: Double
    let touch: CGPoint
    let pull: Double
    let strike: Double
}

private final class LightningModel {
    private let clock = BackgroundClock(start: 40)
    private var touch = CGPoint(x: 240, y: 120)
    private var held = false
    private var pull: Double = 0
    private var strikeStart: Double = -100
    private var everTouched = false

    func hold(at point: CGPoint, scripted: Bool = false) {
        if !scripted { everTouched = true }
        touch = point
        held = true
    }

    func release() {
        held = false
    }

    func strike(at point: CGPoint, now: Double) {
        if !held { touch = point }
        strikeStart = now
    }

    func step(now: Double, speed: Double, size: CGSize, auto: Bool) -> LightningState {
        let time = clock.advance(to: now, speed: speed)
        if auto && !everTouched {
            // Simulated finger: rests on the glass and slides round it for 2.6 s of every 4.6 s.
            let cycle = now.truncatingRemainder(dividingBy: 4.6)
            if cycle < 2.6 {
                let a = now * 0.9
                let r = Double(min(size.width, size.height)) * 0.36
                hold(at: CGPoint(x: Double(size.width) * 0.5 + cos(a) * r, y: Double(size.height) * 0.41 + sin(a) * r), scripted: true)
            } else if held {
                release()
            }
        }
        pull += ((held ? 1 : 0) - pull) * (held ? clock.follow(rate: 14) : clock.follow(rate: 5))
        let age = now - strikeStart
        return LightningState(time: time, touch: touch, pull: pull, strike: age < 1 ? age : -1)
    }
}

private struct LightningDemo: View {
    let ctx: DemoContext
    @State private var model = LightningModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        let arcs = ctx["arcs"]
        let jag = ctx["jag"]
        let speed = ctx["speed"]
        let color = ctx.int("color")
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let state = ctx.isStill
                ? LightningState(time: 41.3, touch: CGPoint(x: size.width * 0.8, y: size.height * 0.24), pull: 1, strike: -1)
                : model.step(now: timeline.date.timeIntervalSinceReferenceDate, speed: speed, size: size, auto: ctx.isPreview)
            LightningSurface(state: state, arcs: arcs, jag: jag, color: color)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .shaderTouch(
            onBegan: { point in
                Haptics.tap(.soft)
                model.hold(at: point)
            },
            onMoved: { point, _ in model.hold(at: point) },
            onEnded: { model.release() },
            onTap: { point in
                Haptics.tap(.rigid)
                model.strike(at: point, now: Date().timeIntervalSinceReferenceDate)
            }
        )
        .autoplay(ctx.isPreview, every: 2.3, delay: 1.0) {
            let angle = Double.random(in: 0...(2 * Double.pi))
            let r = Double(min(size.width, size.height)) * 0.36
            model.strike(
                at: CGPoint(x: Double(size.width) * 0.5 + cos(angle) * r, y: Double(size.height) * 0.41 + sin(angle) * r),
                now: Date().timeIntervalSinceReferenceDate
            )
        }
        .shaderStageHint(L("Touch the glass · tap to strike", "触摸玻璃球 · 点击放电"), ctx)
    }
}

private struct LightningSurface: View {
    let state: LightningState
    let arcs: Double
    let jag: Double
    let color: Int

    private var glow: Color {
        switch color {
        case 1: return Color(hex: 0x2BD9FE)
        case 2: return Color(hex: 0xFF9A2E)
        default: return Color(hex: 0xA24BFF)
        }
    }

    var body: some View {
        let s = state
        let count = arcs.rounded()
        let j = jag
        let tint = glow
        Rectangle()
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.mlPlasmaGlobe(
                        .float2(proxy.size), .float(s.time), .float(count), .float(j), .color(tint),
                        .float2(s.touch), .float(s.pull), .float(s.strike)
                    )
                )
            }
    }
}
