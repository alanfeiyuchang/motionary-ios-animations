import SwiftUI

extension Effect {
    static let shaderTouchTrail = Effect(
        id: "shader.touch-trail",
        category: .shaders,
        interaction: .gesture,
        name: L("Touch Trail", "指尖折射轨迹"),
        summary: L(
            "Your finger leaves a ridge of clear gel that bends the picture with a rainbow fringe, then heals away.",
            "手指划过留下一道透明凝胶般的隆起，带着彩色色边弯折画面，随后自行愈合。"
        ),
        prompt: L(
            "Dragging across the poster leaves a trail that looks like a bead of clear gel squeezed along the finger's path. The trail is a rounded ridge 22 pt in half-width; its flanks act as a lens and bend the grid and type underneath by up to 14 pt, red and blue slightly more and less than green, so a thin spectral fringe outlines it. A specular line runs along the lit side and a soft shade along the other. The ridge is continuous however fast the finger moves, and thins toward its tail. It heals from the oldest end: over 1.6 s each part narrows and flattens until the picture is untouched. Fluid, glassy and immediate.",
            "在海报上拖动，会留下一道轨迹，像沿着手指路径挤出的一条透明凝胶。轨迹是一条半宽 22pt 的圆润隆起，两侧坡面如同透镜，把下方的网格与文字弯折最多 14pt，红、蓝通道比绿色偏移得略多和略少，于是一圈细细的光谱色边勾出它的轮廓。受光一侧有一道高光线，另一侧是柔和的暗部。无论手指多快，隆起始终连贯，并向尾端渐细。它从最早的一端开始愈合：每一段在 1.6 秒内变窄、变平，直到画面恢复如初。流动、通透、即时响应。"
        ),
        implementation: L(
            "The finger path is kept as twelve points (position, life, link) spaced 22 pt apart. A [[stitchable]] layer shader joins them into capsules, takes the maximum of their dome profiles as a height field, refracts R/G/B by its finite-difference gradient and lights it with a specular term; a TimelineView ages the points.",
            "手指路径保存为间隔 22pt 的十二个点（位置、寿命、是否相连）。[[stitchable]] layerEffect 着色器把它们连成胶囊形，取各自圆顶剖面的最大值作为高度场，用有限差分梯度分别折射 R/G/B，并加上高光项；TimelineView 负责让这些点逐渐老化。"
        ),
        apis: ["layerEffect", "TimelineView", "DragGesture", "Metal"],
        tags: ["trail", "refraction", "touch", "gel", "liquid", "轨迹", "折射", "触摸", "凝胶", "拖尾"],
        params: [
            .slider("width", L("Trail width", "轨迹宽度"), 10...40, default: 22, decimals: 0, unit: "pt"),
            .slider("strength", L("Refraction", "折射强度"), 4...30, default: 14, decimals: 0, unit: "pt"),
            .slider("heal", L("Heal time", "愈合时间"), 0.5...4, default: 1.6, decimals: 1, unit: "s"),
            .slider("fringe", L("Chromatic fringe", "色边"), 0...0.6, default: 0.18),
        ]
    ) { ctx in
        TouchTrailDemo(ctx: ctx)
    }
}

private struct TrailPoint {
    var position: CGPoint
    var time: Double
    /// Continues the stroke of the previous point.
    var linked: Bool
}

private final class TrailModel {
    static let capacity = 12
    static let spacing: CGFloat = 22

    private var points: [TrailPoint] = []
    private var anchor = CGPoint.zero
    private var fresh = true
    /// A scripted stroke (autoplay / intro): the simulated finger goes through `add` like a real one.
    private var script: (start: Double, variant: Int)?

    func lift() {
        fresh = true
    }

    func add(_ point: CGPoint, now: Double) {
        // The newest point is the head under the finger; once it is `spacing` away from where it was dropped
        // it stays behind and a new head starts, so a stroke spends one slot per 22 pt.
        if !fresh, let last = points.indices.last, hypot(anchor.x - point.x, anchor.y - point.y) < Self.spacing {
            points[last].position = point
            points[last].time = now
            return
        }
        if !fresh, let last = points.indices.last {
            anchor = points[last].position
        } else {
            anchor = point
        }
        points.append(TrailPoint(position: point, time: now, linked: !fresh))
        fresh = false
        if points.count > Self.capacity { points.removeFirst(points.count - Self.capacity) }
    }

    func startStroke(variant: Int, now: Double) {
        lift()
        script = (now, variant)
    }

    func step(now: Double, heal: Double) -> [(Float, Float, Float, Float)] {
        if let script {
            let t = (now - script.start) / 1.5
            if t >= 1 {
                self.script = nil
                lift()
            } else if t >= 0 {
                add(Self.path(t, variant: script.variant), now: now)
            }
        }
        points.removeAll { now - $0.time > heal }
        return packed(now: now, heal: heal)
    }

    /// Simulated finger paths: an S-curve, a loop and a diagonal swoop.
    private static func path(_ t: Double, variant: Int) -> CGPoint {
        let e = t * t * (3 - 2 * t)
        switch variant % 3 {
        case 1:
            let a = e * 2 * Double.pi - 1.2
            return CGPoint(x: 130 + cos(a) * 78, y: 160 + sin(a) * 86)
        case 2:
            return CGPoint(x: 226 - e * 190, y: 60 + e * 190 + sin(e * Double.pi * 2) * 34)
        default:
            return CGPoint(x: 32 + e * 196, y: 150 + sin(e * Double.pi * 2) * 92)
        }
    }

    /// A settled picture for stills: one S-shaped stroke, fresh at its head.
    func still() -> [(Float, Float, Float, Float)] {
        (0..<Self.capacity).map { index in
            let t = 0.12 + 0.8 * Double(index) / Double(Self.capacity - 1)
            let p = Self.path(t, variant: 0)
            return (Float(p.x), Float(p.y), Float(0.3 + 0.7 * Double(index) / Double(Self.capacity - 1)), index == 0 ? 0 : 1)
        }
    }

    private func packed(now: Double, heal: Double) -> [(Float, Float, Float, Float)] {
        // Besides ageing, the tail tapers over the last 70 pt of the length the twelve slots can hold, so a
        // fast stroke never loses its oldest point with a visible jump.
        let reach = Self.spacing * CGFloat(Self.capacity - 2)
        var fromHead: CGFloat = 0
        var entries: [(Float, Float, Float, Float)] = []
        for index in points.indices.reversed() {
            let point = points[index]
            if index < points.count - 1 {
                let next = points[index + 1]
                fromHead += next.linked ? hypot(next.position.x - point.position.x, next.position.y - point.position.y) : Self.spacing
            }
            let age = max(0, 1 - (now - point.time) / max(heal, 0.1))
            let taper = min(max((reach - fromHead) / 70, 0), 1)
            entries.append((Float(point.position.x), Float(point.position.y), Float(age * Double(taper)), point.linked ? 1 : 0))
        }
        entries.reverse()
        if !entries.isEmpty { entries[0].3 = 0 }
        let padding = [(Float, Float, Float, Float)](repeating: (0, 0, 0, 0), count: Self.capacity - entries.count)
        return padding + entries
    }
}

private struct TouchTrailDemo: View {
    let ctx: DemoContext
    @State private var model = TrailModel()
    @State private var turn = 0

    var body: some View {
        let width = ctx["width"]
        let strength = ctx["strength"]
        let heal = ctx["heal"]
        let fringe = ctx["fringe"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let points = ctx.isStill ? model.still() : model.step(now: timeline.date.timeIntervalSinceReferenceDate, heal: heal)
                TrailSurface(points: points, width: width, strength: strength, fringe: fringe)
            }
            .shaderCard(glow: Color(hex: 0x5B2AD0, opacity: 0.32))
            .shaderTouch(
                onBegan: { point in
                    Haptics.tap(.soft)
                    model.lift()
                    model.add(point, now: Date().timeIntervalSinceReferenceDate)
                },
                onMoved: { point, _ in model.add(point, now: Date().timeIntervalSinceReferenceDate) },
                onEnded: { model.lift() },
                onTap: { point in
                    model.lift()
                    model.add(point, now: Date().timeIntervalSinceReferenceDate)
                    model.lift()
                }
            )
            DemoHint(text: L("Draw on the poster with a finger", "用手指在海报上划动"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.3, delay: 0.3) {
            model.startStroke(variant: turn, now: Date().timeIntervalSinceReferenceDate)
            turn += 1
        }
    }
}

private struct TrailSurface: View {
    let points: [(Float, Float, Float, Float)]
    let width: Double
    let strength: Double
    let fringe: Double

    private func arg(_ index: Int) -> Shader.Argument {
        let p = points[index]
        return .float4(p.0, p.1, p.2, p.3)
    }

    var body: some View {
        ShaderFlowScene()
            .layerEffect(
                ShaderLibrary.mlTouchTrail(
                    .float2(ShaderKit.card),
                    arg(0), arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7), arg(8), arg(9), arg(10), arg(11),
                    .float(width), .float(strength), .float(fringe), .float(0.85)
                ),
                maxSampleOffset: CGSize(width: strength * (1 + fringe) + 2, height: strength * (1 + fringe) + 2)
            )
    }
}
