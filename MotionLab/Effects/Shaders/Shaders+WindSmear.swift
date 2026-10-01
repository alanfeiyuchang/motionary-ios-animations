import SwiftUI

extension Effect {
    static let shaderWindSmear = Effect(
        id: "shader.wind-smear",
        category: .shaders,
        interaction: .gesture,
        name: L("Wind Smear", "风吹涂抹"),
        summary: L(
            "Drag and the wet paint streaks out along your finger's path in ragged strands, then springs back.",
            "拖动时未干的颜料沿手指方向被拉成参差的丝缕，松手后弹回原样。"
        ),
        prompt: L(
            "A canvas of thick brush strokes is still wet. Dragging acts like wind: every colour is pulled out along the drag direction, up to 80 pt, as if a palette knife were dragged through it. The streaks are not a uniform blur: the canvas is divided into strands about 10 pt wide whose lengths differ widely, so each hard edge combs out into long and short fibres, front-weighted so the source stays strongest. The smear follows the finger almost instantly; on release it springs back (response 0.55 s, damping 0.42), overshooting, so the paint briefly streaks the opposite way before settling perfectly sharp. A soft haptic marks the grab. Gestural, painterly and elastic.",
            "一幅厚涂的画布，颜料还没干。拖动就像起了风：所有颜色沿拖动方向被拉出，最长 80pt，仿佛刮刀从中划过。拉丝不是均匀的模糊：画面被分成约 10pt 宽的一缕缕，长度相差很大，每一道硬边都被梳成长短不一的纤维，并且越靠近原处越浓。涂抹几乎瞬间跟上手指；松手后以弹簧（响应 0.55 秒、阻尼 0.42）弹回并越过原位，颜料会短暂地朝反方向拉丝，再恢复到完全清晰。抓住画面时有一次轻柔触感。写意、有笔触感、富有弹性。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader averages 14 jittered taps upwind of each pixel with e^(−2.4t) weights; the tap distance is scaled by two octaves of value noise over the coordinate perpendicular to the wind, which makes the strands. A reference-type model stepped by TimelineView follows the drag and integrates a 2D spring after release.",
            "[[stitchable]] layerEffect 着色器在每个像素的上风方向取 14 个带抖动的采样，按 e^(−2.4t) 加权平均；采样距离由垂直于风向坐标上的两层值噪声缩放，形成一缕缕拉丝。由 TimelineView 逐帧推进的引用类型模型跟随拖动，并在松手后积分一个二维弹簧。"
        ),
        apis: ["layerEffect", "TimelineView", "DragGesture", "Metal"],
        tags: ["smear", "wind", "paint", "streak", "directional blur", "涂抹", "风", "颜料", "拉丝", "方向模糊"],
        params: [
            .slider("length", L("Max length", "最大长度"), 20...140, default: 80, decimals: 0, unit: "pt"),
            .slider("streak", L("Strand width", "丝缕宽度"), 3...30, default: 10, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.2...1.2, default: 0.55, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.2...1, default: 0.42),
        ]
    ) { ctx in
        WindSmearDemo(ctx: ctx)
    }
}

/// Follows the finger while it is down, then a damped 2D spring pulls the smear back to zero.
private final class SmearModel {
    private let clock = BackgroundClock(start: 0)
    private var smear = CGSize.zero
    private var velocity = CGSize.zero
    private var target: CGSize?
    private var start: CGPoint?
    /// A scripted gust (autoplay / intro): a simulated finger travels `vector` through `begin`/`drag`/`release`.
    private var gust: (start: Double, vector: CGSize)?

    func begin(at point: CGPoint) {
        // A real touch takes over from a scripted gust.
        gust = nil
        start = point
        target = smear
    }

    func drag(to point: CGPoint, limit: CGFloat) {
        guard let start else { return }
        var v = CGSize(width: point.x - start.x, height: point.y - start.y)
        let length = hypot(v.width, v.height)
        if length > limit {
            v.width *= limit / length
            v.height *= limit / length
        }
        target = v
    }

    func release() {
        target = nil
        start = nil
    }

    func startGust(_ vector: CGSize, now: Double) {
        begin(at: .zero)
        gust = (now, vector)
    }

    func step(now: Double, response: Double, damping: Double, limit: CGFloat) -> CGSize {
        clock.advance(to: now, speed: 1)
        let dt = clock.delta
        if let script = gust {
            let t = (now - script.start) / 0.5
            if t >= 1.25 {
                gust = nil
                release()
            } else {
                let e = min(max(t, 0), 1)
                let eased = CGFloat(e * e * (3 - 2 * e))
                drag(to: CGPoint(x: script.vector.width * eased, y: script.vector.height * eased), limit: limit)
            }
        }
        guard dt > 0 else { return smear }
        if let target {
            let k = CGFloat(1 - exp(-dt * 20))
            let dx = (target.width - smear.width) * k
            let dy = (target.height - smear.height) * k
            smear.width += dx
            smear.height += dy
            velocity = CGSize(width: dx / CGFloat(dt), height: dy / CGFloat(dt))
        } else {
            let omega = 2 * Double.pi / max(response, 0.05)
            let steps = 4
            let h = dt / Double(steps)
            for _ in 0..<steps {
                let ax = -omega * omega * Double(smear.width) - 2 * damping * omega * Double(velocity.width)
                let ay = -omega * omega * Double(smear.height) - 2 * damping * omega * Double(velocity.height)
                velocity.width += CGFloat(ax * h)
                velocity.height += CGFloat(ay * h)
                smear.width += velocity.width * CGFloat(h)
                smear.height += velocity.height * CGFloat(h)
            }
        }
        return smear
    }
}

private struct WindSmearDemo: View {
    let ctx: DemoContext
    @State private var model = SmearModel()
    @State private var turn = 0

    var body: some View {
        let limit = ctx.cg("length")
        let streak = ctx["streak"]
        let response = ctx["response"]
        let damping = ctx["damping"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let smear = ctx.isStill
                    ? CGSize(width: limit * 0.85, height: -limit * 0.3)
                    : model.step(now: timeline.date.timeIntervalSinceReferenceDate, response: response, damping: damping, limit: limit)
                ShaderPaintScene()
                    .layerEffect(
                        ShaderLibrary.mlWindSmear(.float2(ShaderKit.card), .float2(smear), .float(streak), .float(1.0), .float(3.1)),
                        maxSampleOffset: CGSize(width: limit * 1.6, height: limit * 1.6)
                    )
            }
            .shaderCard()
            .shaderTouch(
                onBegan: { point in
                    Haptics.tap(.soft)
                    model.begin(at: point)
                },
                onMoved: { point, _ in model.drag(to: point, limit: limit) },
                onEnded: { model.release() }
            )
            DemoHint(text: L("Drag in any direction, then let go", "朝任意方向拖动，再松手"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.1, delay: 0.4) { gust() }
    }

    /// Simulated drag: gusts from a rotating set of directions.
    private func gust() {
        let angles: [Double] = [-0.3, 2.6, 1.2, -2.2]
        let angle = angles[turn % angles.count]
        turn += 1
        let length = Double(ctx["length"])
        model.startGust(CGSize(width: cos(angle) * length, height: sin(angle) * length), now: Date().timeIntervalSinceReferenceDate)
    }
}
