import SwiftUI

extension Effect {
    static let shaderFire = Effect(
        id: "shader.fire",
        category: .shaders,
        interaction: .gesture,
        name: L("Procedural Fire", "程序化火焰"),
        summary: L(
            "A bed of flames with rising tongues and embers; your finger is a torch that leans in the wind of its own motion.",
            "一片翻卷的火焰，火舌与火星不断升腾；手指就是一支火把，会随自身移动带起的风而倾斜。"
        ),
        prompt: L(
            "Flames fill the lower half of a dark stage. A solid bed burns along the bottom edge and breaks into separate tongues that lick upward, twist and tear off, scrolling at a steady rate while a slower turbulence bends their paths. Colour follows heat: deep red at the fringes, orange in the body, yellow near the base and white in the hottest cores. Embers rise above the flames on two depths, wobbling sideways, flickering and dying out with height. Touching lights a torch at the finger: a narrow flame about a third of the stage tall, which leans away from the direction of travel as it moves and straightens when it rests, then fades over 0.5 s on release. A tap makes the whole bed flare up by 90% for about a second. Hot, alive and hypnotic.",
            "火焰占据暗色舞台的下半部分。底边是一层连成片的火床，向上裂成一条条独立的火舌，舔舐、扭转、撕离，以稳定的速度向上滚动，同时被更缓慢的湍流弯折路径。颜色跟随温度：边缘是深红，火身是橙色，靠近底部转黄，最热的焰心发白。火星在火焰上方分两层升起，左右摇摆、明灭闪烁，越高越暗直至熄灭。触摸会在指尖点燃一支火把：一束约为舞台三分之一高的窄焰，移动时向运动的反方向倾斜，停下后重新直立，松手后在 0.5 秒内熄灭。点击则让整片火床在约一秒内蹿高 90%。炽热、鲜活、令人入神。"
        ),
        implementation: L(
            "A [[stitchable]] color shader scrolls domain-warped gradient-noise clouds upward, subtracts a height falloff to get heat, repeats the field in a Gaussian column above the finger, maps heat through a four-stop ramp and adds two hashed ember grids. A model stepped by TimelineView smooths the torch strength and the wind from finger velocity.",
            "[[stitchable]] colorEffect 着色器让经过域扭曲的梯度噪声云向上滚动，减去随高度增加的衰减得到温度，并在手指上方的高斯柱内重复这一场，再把温度映射到四级色阶，叠加两层哈希火星网格。由 TimelineView 逐帧推进的模型平滑火把强度，以及由手指速度得到的风。"
        ),
        apis: ["colorEffect", "visualEffect", "TimelineView", "DragGesture", "Metal"],
        tags: ["fire", "flame", "embers", "torch", "fbm", "generative", "火焰", "火", "火星", "火把", "生成"],
        params: [
            .slider("height", L("Flame height", "火焰高度"), 0.2...0.9, default: 0.5),
            .slider("speed", L("Speed", "速度"), 0.3...2.5, default: 1, decimals: 1),
            .slider("turbulence", L("Turbulence", "湍流"), 0...1, default: 0.6),
            .choice("palette", L("Fuel", "燃料"), [L("Wood fire", "柴火"), L("Gas blue", "燃气蓝焰"), L("Spirit green", "幽绿鬼火")]),
        ]
    ) { ctx in
        FireDemo(ctx: ctx)
    }
}

private struct FireState {
    let time: Double
    let touch: CGPoint
    let press: Double
    let wind: Double
    let flare: Double
}

private final class FireModel {
    private let clock = BackgroundClock(start: 30)
    private var touch = CGPoint(x: 170, y: 190)
    private var last: (point: CGPoint, time: Double)?
    private var held = false
    private var press: Double = 0
    private var wind: Double = 0
    private var gust: Double = 0
    private var flareStart: Double = -100
    private var everTouched = false

    func hold(at point: CGPoint, now: Double, scripted: Bool = false) {
        if !scripted { everTouched = true }
        if let last, now > last.time {
            // The flame lags behind the hand: wind blows against the direction of travel.
            let vx = Double(point.x - last.point.x) / max(now - last.time, 1.0 / 120)
            gust = min(max(-vx / 500, -1), 1)
        }
        last = (point, now)
        touch = point
        held = true
    }

    func release() {
        held = false
        last = nil
    }

    func flare(now: Double) {
        flareStart = now
    }

    func step(now: Double, speed: Double, size: CGSize, auto: Bool) -> FireState {
        let time = clock.advance(to: now, speed: speed)
        if auto && !everTouched {
            // Simulated finger: carries the torch across for 3.2 s of every 5 s, then lets go.
            let cycle = now.truncatingRemainder(dividingBy: 5)
            if cycle < 3.2 {
                let t = cycle / 3.2
                hold(at: CGPoint(x: size.width * (0.5 - 0.3 * cos(t * 2 * Double.pi)), y: size.height * (0.5 + 0.1 * sin(t * 4 * Double.pi))), now: now, scripted: true)
            } else if held {
                release()
            }
        }
        press += ((held ? 1 : 0) - press) * (held ? clock.follow(rate: 12) : clock.follow(rate: 5))
        gust *= exp(-clock.delta * 5)
        wind += (gust - wind) * clock.follow(rate: 8)
        let age = now - flareStart
        return FireState(time: time, touch: touch, press: press, wind: wind, flare: age < 2 ? age : -1)
    }
}

private struct FireDemo: View {
    let ctx: DemoContext
    @State private var model = FireModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        let height = ctx["height"]
        let speed = ctx["speed"]
        let turbulence = ctx["turbulence"]
        let palette = ctx.int("palette")
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let state = ctx.isStill
                ? FireState(time: 31.7, touch: CGPoint(x: size.width * 0.62, y: size.height * 0.5), press: 1, wind: 0.25, flare: -1)
                : model.step(now: timeline.date.timeIntervalSinceReferenceDate, speed: speed, size: size, auto: ctx.isPreview)
            FireSurface(state: state, height: height, turbulence: turbulence, palette: palette)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .shaderTouch(
            onBegan: { point in
                Haptics.tap(.soft)
                model.hold(at: point, now: Date().timeIntervalSinceReferenceDate)
            },
            onMoved: { point, _ in model.hold(at: point, now: Date().timeIntervalSinceReferenceDate) },
            onEnded: { model.release() },
            onTap: { _ in
                Haptics.tap(.rigid)
                model.flare(now: Date().timeIntervalSinceReferenceDate)
            }
        )
        .autoplay(ctx.isPreview, every: 3.7, delay: 1.2) {
            model.flare(now: Date().timeIntervalSinceReferenceDate)
        }
        .shaderStageHint(L("Hold and move a torch · tap to flare", "按住移动火把 · 点击蹿火"), ctx)
    }
}

private struct FireSurface: View {
    let state: FireState
    let height: Double
    let turbulence: Double
    let palette: Int

    private var colors: [Color] {
        switch palette {
        case 1: return [Color(hex: 0x0A1E8C), Color(hex: 0x1E7BFF), Color(hex: 0x9AE8FF)]
        case 2: return [Color(hex: 0x064D2A), Color(hex: 0x1FBF5A), Color(hex: 0xD6FF7A)]
        default: return [Color(hex: 0x8C0D00), Color(hex: 0xFF5A0A), Color(hex: 0xFFD23F)]
        }
    }

    var body: some View {
        let s = state
        let h = height
        let tb = turbulence
        let c = colors
        Rectangle()
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.mlFire(
                        .float2(proxy.size), .float(s.time), .float(h), .float(tb),
                        .color(c[0]), .color(c[1]), .color(c[2]),
                        .float2(s.touch), .float(s.press), .float(s.wind), .float(s.flare)
                    )
                )
            }
    }
}
