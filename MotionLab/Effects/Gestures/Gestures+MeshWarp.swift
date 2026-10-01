import SwiftUI

extension Effect {
    static let gesturesMeshWarp = Effect(
        id: "gestures.mesh-warp",
        category: .gestures,
        interaction: .gesture,
        name: L("Elastic Mesh Warp", "弹性网格拉扯"),
        summary: L("A coloured rubber sheet on a grid: pinch a spot and pull, the neighbourhood stretches with it, then ripples back.", "铺在网格上的彩色橡胶膜：捏住一处往外拉，周围跟着被扯开，松手后荡着涟漪弹回。"),
        prompt: L(
            "A 300×264 pt sheet is a 13×12 lattice of points filled with a four-corner gradient (indigo, pink, sky, amber) and overlaid with faint white grid lines; its border points are pinned. Touching it grabs every point within 70 pt with a Gaussian falloff, so the pull has a soft shoulder: the spot under the finger follows exactly, neighbours follow less. Stretched cells brighten and compressed ones darken, like rubber thinning. On release each point is driven by neighbour springs (stiffness 520) and a weak home spring (38) with damping 2.4, integrated at 240 Hz, so the dent snaps back, overshoots, and sends concentric ripples that reflect off the pinned edge for about 1.5 s. A light haptic on grab, a soft one on release. Elastic, liquid, slightly hypnotic.",
            "300×264 pt的薄膜由13×12的质点网格构成，以四角渐变（靛、粉、天蓝、琥珀）填充，叠着淡白网格线，边缘质点固定。触摸时，70 pt内的质点按高斯衰减被一同抓住：指下那一点完全跟手，越远跟得越少，拉扯带着柔和的肩部。被拉开的格子变亮、被挤压的变暗，像橡胶被拉薄。松手后每个质点受邻点弹簧（劲度520）和较弱的归位弹簧（38）驱动，阻尼2.4，以240 Hz积分：凹陷弹回并过冲，激起同心涟漪，在固定边缘反射，约1.5秒平息。抓取时轻触感，松手时柔和触感。"
        ),
        implementation: L(
            "A reference-type lattice stores a displacement and velocity per point; each 1/240 s substep adds the discrete Laplacian of the displacement (neighbour springs), a home spring, damping and, while held, a Gaussian-weighted pull toward the finger. A Canvas fills every warped quad with a bilinear corner colour shaded by its area ratio and strokes the grid lines.",
            "引用类型的网格为每个质点保存位移与速度；每个1/240秒子步叠加位移的离散拉普拉斯（邻点弹簧）、归位弹簧、阻尼，以及按住时按高斯权重拉向手指的力。Canvas 用双线性插值的四角颜色填充每个变形四边形，并按面积比调整明暗，再描出网格线。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture", "Path", "GraphicsContext.fill"],
        tags: ["mesh", "warp", "elastic", "lattice", "ripple", "rubber sheet", "网格", "扭曲", "弹性", "涟漪", "橡胶膜"],
        params: [
            .slider("stiffness", L("Neighbour stiffness", "邻点劲度"), 150...1200, default: 520, step: 10, decimals: 0),
            .slider("damping", L("Damping", "阻尼"), 0.6...8, default: 2.4, decimals: 1),
            .slider("radius", L("Grab radius", "抓取半径"), 30...130, default: 70, step: 5, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        MeshWarpDemo(ctx: ctx)
    }
}

private enum WarpMesh {
    static let size = CGSize(width: 300, height: 264)
    static let cols = 13
    static let rows = 12
    static let home: CGFloat = 38
    static let corners: [GestureRGB] = [
        GestureRGB(hex: 0x6E7BFF), GestureRGB(hex: 0xFF5FA2),
        GestureRGB(hex: 0x3AC4FF), GestureRGB(hex: 0xFFC247),
    ]
}

private final class MeshWarpModel {
    let rest: [CGPoint]
    private(set) var offset: [CGVector]
    private var velocity: [CGVector]
    private var weight: [CGFloat]
    private var grabOffset: [CGVector]
    private var pull: CGSize = .zero
    private(set) var held = false
    private(set) var grabPoint: CGPoint = .zero
    private var clock = GestureStepClock()
    private let h: CGFloat = 1.0 / 240.0

    init() {
        var points: [CGPoint] = []
        for row in 0..<WarpMesh.rows {
            for col in 0..<WarpMesh.cols {
                let x: CGFloat = WarpMesh.size.width * CGFloat(col) / CGFloat(WarpMesh.cols - 1)
                let y: CGFloat = WarpMesh.size.height * CGFloat(row) / CGFloat(WarpMesh.rows - 1)
                points.append(CGPoint(x: x, y: y))
            }
        }
        rest = points
        offset = Array(repeating: .zero, count: points.count)
        velocity = Array(repeating: .zero, count: points.count)
        weight = Array(repeating: 0, count: points.count)
        grabOffset = Array(repeating: .zero, count: points.count)
    }

    var isSettled: Bool {
        guard !held else { return false }
        for index in offset.indices {
            if abs(velocity[index].dx) + abs(velocity[index].dy) > 1.5 { return false }
            if abs(offset[index].dx) + abs(offset[index].dy) > 0.3 { return false }
        }
        return true
    }

    func position(_ index: Int) -> CGPoint {
        CGPoint(x: rest[index].x + offset[index].dx, y: rest[index].y + offset[index].dy)
    }

    func grab(at point: CGPoint, radius: CGFloat) {
        held = true
        grabPoint = point
        pull = .zero
        let sigma: CGFloat = max(radius, 10) / 2
        for index in rest.indices {
            let d: CGFloat = GestureMath.distance(position(index), point)
            let w: CGFloat = CGFloat(exp(-Double(d * d) / Double(2 * sigma * sigma)))
            weight[index] = w < 0.02 ? 0 : w
            grabOffset[index] = offset[index]
        }
    }

    func move(by translation: CGSize) {
        // Soft limit so the sheet cannot be dragged far outside the tray.
        pull = CGSize(width: MeshWarpModel.soft(translation.width), height: MeshWarpModel.soft(translation.height))
    }

    /// One to one for the first 80 pt, rubber-banded beyond.
    private static func soft(_ x: CGFloat) -> CGFloat {
        let free: CGFloat = 80
        guard abs(x) > free else { return x }
        let sign: CGFloat = x < 0 ? -1 : 1
        return sign * (free + rubberBand(abs(x) - free, limit: 70))
    }

    var fingerPoint: CGPoint {
        CGPoint(x: grabPoint.x + pull.width, y: grabPoint.y + pull.height)
    }

    func release() {
        held = false
    }

    func step(to date: Date, stiffness: CGFloat, damping: CGFloat) {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return }
        let steps: Int = min(max(Int((dt / Double(h)).rounded()), 1), 10)
        for _ in 0..<steps { integrate(stiffness: stiffness, damping: damping) }
    }

    func integrate(stiffness: CGFloat, damping: CGFloat) {
        let cols: Int = WarpMesh.cols
        let rows: Int = WarpMesh.rows
        let decay: CGFloat = CGFloat(exp(-Double(damping * h)))
        for row in 1..<(rows - 1) {
            for col in 1..<(cols - 1) {
                let i: Int = row * cols + col
                let o: CGVector = offset[i]
                let lapX: CGFloat = offset[i - 1].dx + offset[i + 1].dx + offset[i - cols].dx + offset[i + cols].dx - 4 * o.dx
                let lapY: CGFloat = offset[i - 1].dy + offset[i + 1].dy + offset[i - cols].dy + offset[i + cols].dy - 4 * o.dy
                var ax: CGFloat = stiffness * lapX - WarpMesh.home * o.dx
                var ay: CGFloat = stiffness * lapY - WarpMesh.home * o.dy
                if held && weight[i] > 0 {
                    let w: CGFloat = weight[i]
                    let k: CGFloat = 9000 * w * w
                    ax += k * (grabOffset[i].dx + pull.width * w - o.dx)
                    ay += k * (grabOffset[i].dy + pull.height * w - o.dy)
                    // Extra drag where the finger holds, so the grabbed patch does not buzz.
                    velocity[i].dx *= 1 - 0.12 * w
                    velocity[i].dy *= 1 - 0.12 * w
                }
                velocity[i].dx = (velocity[i].dx + ax * h) * decay
                velocity[i].dy = (velocity[i].dy + ay * h) * decay
            }
        }
        for row in 1..<(rows - 1) {
            for col in 1..<(cols - 1) {
                let i: Int = row * cols + col
                offset[i].dx += velocity[i].dx * h
                offset[i].dy += velocity[i].dy * h
            }
        }
    }
}

private struct MeshWarpDemo: View {
    let ctx: DemoContext
    @State private var model: MeshWarpModel
    @State private var touching = false
    @State private var wake = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = MeshWarpModel()
        if ctx.isStill {
            // A still shows the sheet mid-pull.
            model.grab(at: CGPoint(x: 150, y: 140), radius: 80)
            model.move(by: CGSize(width: 78, height: -64))
            for _ in 0..<500 { model.integrate(stiffness: 520, damping: 2.4) }
        }
        _model = State(initialValue: model)
    }

    var body: some View {
        let stiffness = ctx.cg("stiffness")
        let damping = ctx.cg("damping")
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let _ = ctx.isStill ? () : model.step(to: date, stiffness: stiffness, damping: damping)
                MeshWarpCanvas(model: model, tick: date)
            }
            .frame(width: WarpMesh.size.width, height: WarpMesh.size.height)
            .gestureTray(cornerRadius: 26)
            .gesture(drag)

            DemoHint(text: L("Pinch a spot and pull, then let go", "捏住一处拉开，再松手"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.5) { autoPull() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touchEnded() }
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    touching = true
                    script?.cancel()
                    touchBegan(at: value.startLocation)
                    Haptics.tap(.light)
                }
                touchMoved(by: value.translation)
            }
            .onEnded { _ in touchEnded() }
    }

    private func touchBegan(at point: CGPoint) {
        model.grab(at: point, radius: ctx.cg("radius"))
        wake += 1
    }

    private func touchMoved(by translation: CGSize) {
        model.move(by: translation)
        wake += 1
    }

    private func touchEnded() {
        guard model.held else { return }
        touching = false
        model.release()
        if !ctx.isPreview { Haptics.tap(.soft) }
        wake += 1
    }

    /// A scripted finger grabs a spot, pulls it out and lets go, through the touch handlers.
    private func autoPull() {
        guard !touching else { return }
        autoStep += 1
        let spots: [CGPoint] = [CGPoint(x: 110, y: 150), CGPoint(x: 190, y: 110), CGPoint(x: 150, y: 170)]
        let pulls: [CGPoint] = [CGPoint(x: 80, y: -70), CGPoint(x: -90, y: 70), CGPoint(x: 30, y: -100)]
        let start: CGPoint = spots[autoStep % spots.count]
        let pull: CGPoint = pulls[autoStep % pulls.count]
        script?.cancel()
        script = Task { @MainActor in
            touchBegan(at: start)
            let finished = await GhostFinger.drag(from: .zero, to: pull, duration: 0.55) { point in
                touchMoved(by: CGSize(width: point.x, height: point.y))
            }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            touchEnded()
        }
    }
}

private struct MeshWarpCanvas: View {
    let model: MeshWarpModel
    let tick: Date

    var body: some View {
        Canvas { context, _ in
            let cols: Int = WarpMesh.cols
            let rows: Int = WarpMesh.rows
            let restArea: CGFloat = (WarpMesh.size.width / CGFloat(cols - 1)) * (WarpMesh.size.height / CGFloat(rows - 1))
            for row in 0..<(rows - 1) {
                for col in 0..<(cols - 1) {
                    let i: Int = row * cols + col
                    let a: CGPoint = model.position(i)
                    let b: CGPoint = model.position(i + 1)
                    let c: CGPoint = model.position(i + cols + 1)
                    let d: CGPoint = model.position(i + cols)
                    var path = Path()
                    path.move(to: a)
                    path.addLine(to: b)
                    path.addLine(to: c)
                    path.addLine(to: d)
                    path.closeSubpath()
                    // Shoelace area: stretched cells thin out and brighten, squeezed ones darken.
                    let area: CGFloat = abs((a.x * b.y - b.x * a.y) + (b.x * c.y - c.x * b.y) + (c.x * d.y - d.x * c.y) + (d.x * a.y - a.x * d.y)) / 2
                    let ratio: Double = Double(area / restArea)
                    let u: Double = (Double(col) + 0.5) / Double(cols - 1)
                    let v: Double = (Double(row) + 0.5) / Double(rows - 1)
                    let top: GestureRGB = WarpMesh.corners[0].mixed(WarpMesh.corners[1], u)
                    let bottom: GestureRGB = WarpMesh.corners[2].mixed(WarpMesh.corners[3], u)
                    var rgb: GestureRGB = top.mixed(bottom, v)
                    if ratio > 1 {
                        rgb = rgb.mixed(GestureRGB(1, 1, 1), min((ratio - 1) * 0.42, 0.6))
                    } else {
                        rgb = rgb.mixed(GestureRGB(0.05, 0.03, 0.2), min((1 - ratio) * 0.9, 0.55))
                    }
                    let color: Color = rgb.color()
                    context.fill(path, with: .color(color))
                    context.stroke(path, with: .color(color), lineWidth: 0.8)
                }
            }

            var lines = Path()
            for row in 1..<(rows - 1) {
                lines.move(to: model.position(row * cols))
                for col in 1..<cols { lines.addLine(to: model.position(row * cols + col)) }
            }
            for col in 1..<(cols - 1) {
                lines.move(to: model.position(col))
                for row in 1..<rows { lines.addLine(to: model.position(row * cols + col)) }
            }
            context.stroke(lines, with: .color(.white.opacity(0.3)), lineWidth: 0.7)

            if model.held {
                let p: CGPoint = model.fingerPoint
                let ring = Path(ellipseIn: CGRect(x: p.x - 15, y: p.y - 15, width: 30, height: 30))
                context.fill(ring, with: .color(.white.opacity(0.22)))
                context.stroke(ring, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
            }
        }
    }
}
