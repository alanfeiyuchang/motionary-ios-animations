import SwiftUI

extension Effect {
    static let shaderGlassBlocks = Effect(
        id: "shader.glass-blocks",
        category: .shaders,
        interaction: .gesture,
        name: L("Glass Block Wall", "玻璃砖墙"),
        summary: L(
            "A wall of glass blocks, each one a pillow lens with its own view; drag the lights behind it and watch them multiply.",
            "一面玻璃砖墙，每块砖都是一枚自带视角的枕形透镜；拖动墙后的灯光，看它们被一块块复制。"
        ),
        prompt: L(
            "Glowing shapes drift behind a wall of 52 pt glass blocks. Each block is a pillow lens: it shows a minified view of the scene around its own centre, bending harder toward its edges, so one light appears in several neighbouring blocks at once and jumps from block to block as it moves. Every block is tilted slightly differently and carries a wavy cast relief that ripples what is behind it, softened by a light frost. Dark mortar joints separate the blocks; bevels are bright on the top and left edges, dark on the others, and a diagonal sheen crosses each face. Dragging moves the lights behind the wall; they follow with a soft lag and glide on with the throw of the release. Architectural, cool and tactile.",
            "发光的图形在一面由 52pt 玻璃砖砌成的墙后游移。每块砖都是一枚枕形透镜：它呈现以自身中心为准、被缩小的景象，越靠近边缘弯折越强，于是一盏灯会同时出现在相邻的好几块砖里，移动时又从一块跳到另一块。每块砖的倾角略有不同，表面还带着浇铸出的波浪纹，把后方景物搅出涟漪，再蒙上一层薄薄的磨砂。深色砖缝把它们隔开；倒角在上、左两侧发亮，另两侧发暗，每块砖面上斜着掠过一道光泽。拖动可移动墙后的灯光，它们带着柔和的滞后跟随，松手后顺着甩出的力道继续滑行。建筑感、清冷、有触感。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader divides the layer into whole blocks, offsets the sample by the in-block coordinate scaled with a term growing in r², a hashed tilt and gradient-noise relief, blurs with five taps, then draws bevels, sheen and joints from the distance to the block edge. A model stepped by TimelineView moves the lights with lag and inertia.",
            "[[stitchable]] layerEffect 着色器把图层划分为整数块砖，用砖内坐标（乘以随 r² 增长的系数）、哈希倾角与梯度噪声浮雕偏移采样，以五次采样做磨砂，再根据到砖边的距离画出倒角、光泽与砖缝。由 TimelineView 逐帧推进的模型让灯光带着滞后与惯性移动。"
        ),
        apis: ["layerEffect", "TimelineView", "DragGesture", "Canvas", "Metal"],
        tags: ["glass block", "refraction", "lens", "grid", "architecture", "玻璃砖", "折射", "透镜", "网格", "建筑"],
        params: [
            .slider("block", L("Block size", "砖块大小"), 30...90, default: 52, decimals: 0, unit: "pt"),
            .slider("refraction", L("Refraction", "折射强度"), 0...1, default: 0.8),
            .slider("relief", L("Wavy relief", "波浪纹"), 0...1, default: 0.35),
            .slider("frost", L("Frost", "磨砂"), 0...6, default: 1.5, decimals: 1, unit: "pt"),
        ]
    ) { ctx in
        GlassBlocksDemo(ctx: ctx)
    }
}

/// The lights behind the wall: they chase a target with a soft lag; a release throws the target on.
private final class GlassSubjectModel {
    private let clock = BackgroundClock(start: 0)
    private var position = CGPoint(x: 130, y: 150)
    private var target = CGPoint(x: 130, y: 150)
    private var offset = CGSize.zero
    /// Until a finger takes over, a simulated one wanders (previews, and the detail stage on arrival).
    private var everTouched = false

    func grab(at point: CGPoint) {
        everTouched = true
        offset = CGSize(width: target.x - point.x, height: target.y - point.y)
    }

    func drag(to point: CGPoint) {
        target = clamped(CGPoint(x: point.x + offset.width, y: point.y + offset.height))
    }

    func release(velocity: CGSize) {
        target = clamped(CGPoint(x: target.x + velocity.width * 0.22, y: target.y + velocity.height * 0.22))
    }

    func step(now: Double) -> (CGPoint, Double) {
        let time = clock.advance(to: now, speed: 1)
        if !everTouched {
            // Simulated drag on a slow figure-eight, through the same `drag(to:)` as the finger.
            drag(to: CGPoint(x: 130 + 78 * sin(time * 0.8), y: 150 + 84 * sin(time * 0.53 + 1)))
        }
        let k = CGFloat(clock.follow(rate: 6))
        position.x += (target.x - position.x) * k
        position.y += (target.y - position.y) * k
        return (position, time)
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 20), ShaderKit.card.width - 20), y: min(max(point.y, 20), ShaderKit.card.height - 20))
    }
}

private struct GlassBlocksDemo: View {
    let ctx: DemoContext
    @State private var model = GlassSubjectModel()
    @State private var lastVelocity = CGSize.zero

    var body: some View {
        let block = ctx["block"]
        let refraction = ctx["refraction"]
        let relief = ctx["relief"]
        let frost = ctx["frost"]
        let reach = block * refraction * 1.2 + 10 * refraction + 12 * relief + frost + 4
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let state = ctx.isStill
                    ? (CGPoint(x: 150, y: 138), 2.0)
                    : model.step(now: timeline.date.timeIntervalSinceReferenceDate)
                GlassBackdrop(subject: state.0, time: state.1)
                    .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                    .layerEffect(
                        ShaderLibrary.mlGlassBlocks(.float2(ShaderKit.card), .float(block), .float(refraction), .float(relief), .float(frost)),
                        maxSampleOffset: CGSize(width: reach, height: reach)
                    )
            }
            .shaderCard(glow: Color(hex: 0x1F6F8B, opacity: 0.3))
            .shaderTouch(
                onBegan: { point in
                    Haptics.tap(.soft)
                    model.grab(at: point)
                },
                onMoved: { point, velocity in
                    lastVelocity = velocity
                    model.drag(to: point)
                },
                onEnded: { model.release(velocity: lastVelocity) }
            )
            DemoHint(text: L("Drag the lights behind the wall", "拖动墙后的灯光"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// What stands behind the wall: a dusk-coloured room with stripes and a cluster of lights that can be moved.
private struct GlassBackdrop: View {
    let subject: CGPoint
    let time: Double

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(ShaderKit.gradient([0x0E2A47, 0x1F6F8B, 0xF2A65A, 0xE4572E]), startPoint: .zero, endPoint: CGPoint(x: w * 0.3, y: h))
            )
            var x: CGFloat = -h
            while x < w {
                var stripe = Path()
                stripe.move(to: CGPoint(x: x, y: h))
                stripe.addLine(to: CGPoint(x: x + h * 0.6, y: 0))
                context.stroke(stripe, with: .color(.white.opacity(0.12)), lineWidth: 7)
                x += 34
            }
            context.fill(Path(CGRect(x: 0, y: h * 0.78, width: w, height: h * 0.22)), with: .color(Color(hex: 0x0B1B2E, opacity: 0.75)))
            // The movable cluster: a big sun, a moon in orbit and a ring.
            let s = subject
            context.fill(Path(ellipseIn: CGRect(x: s.x - 58, y: s.y - 58, width: 116, height: 116)), with: .color(Color(hex: 0xFFE9A8, opacity: 0.3)))
            context.fill(
                Path(ellipseIn: CGRect(x: s.x - 40, y: s.y - 40, width: 80, height: 80)),
                with: .linearGradient(ShaderKit.gradient([0xFFF6C8, 0xFFB03A]), startPoint: CGPoint(x: s.x, y: s.y - 40), endPoint: CGPoint(x: s.x, y: s.y + 40))
            )
            let moon = CGPoint(x: s.x + CGFloat(cos(time * 1.1)) * 70, y: s.y + CGFloat(sin(time * 1.1)) * 46)
            context.fill(Path(ellipseIn: CGRect(x: moon.x - 13, y: moon.y - 13, width: 26, height: 26)), with: .color(Color(hex: 0xFF3D8B)))
            context.stroke(
                Path(ellipseIn: CGRect(x: s.x - 78, y: s.y - 78, width: 156, height: 156)),
                with: .color(Color(hex: 0x7FF0FF, opacity: 0.85)), lineWidth: 4
            )
        }
    }
}
