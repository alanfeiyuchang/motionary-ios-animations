import SwiftUI

extension Effect {
    static let gesturesSqueezeCrumple = Effect(
        id: "gestures.squeeze-crumple",
        category: .gestures,
        interaction: .gesture,
        name: L("Pinch to Crumple", "捏合揉成纸团"),
        summary: L("Pinch a sheet of paper and it crumples into a faceted ball under your fingers; spread to smooth it out, creases and all.", "捏合一张纸，它在指间揉成带棱面的纸团；张开手指再把它抹平，只是折痕还在。"),
        prompt: L(
            "A 180×220 pt sheet of off-white paper with a coloured header and grey text lines lies flat with a soft shadow. It is a 9×11 vertex mesh; pinching in drives a crumple progress from 0 to 1 that follows the fingers. Corners start first and the centre last (staggered by up to 0.35 of the progress): each vertex travels to a random spot inside a 48 pt ball while the sheet twists 50°, every triangle is shaded by where it faces a top-left light so facets appear, fold lines show, and the printed lines buckle with the mesh. Releasing past half way springs to a tight ball (response 0.45 s, damping 0.62) that squeezes a little too small and relaxes; otherwise, or when spreading, it springs back flat. A smoothed sheet keeps faint creases. Haptics tick as it crunches. Tactile, papery, a little destructive.",
            "一张180×220 pt的米白色纸，带彩色页眉和灰色文字行，平放并投下柔影。它是9×11顶点的网格；向内捏合驱动“揉皱进度”从0到1并始终跟手。四角先动、中心最后（最多错开0.35的进度）：每个顶点移向48 pt纸团内的随机位置，整张纸扭转50°，每个三角面按朝向左上方光源的角度着色而出现棱面，折痕显现，印刷的文字行随网格皱折。过半松手会以弹簧（响应0.45秒、阻尼0.62）收成紧实的纸团，先略微捏得过小再放松；否则或张开手指时弹回平整，但仍留有淡淡折痕。揉皱时伴随咔嚓的触感。"
        ),
        implementation: L(
            "MagnifyGesture maps its magnification to a progress value; an Animatable view interpolates every mesh vertex between its flat position and a hashed position inside a disc, each with its own delay, and a Canvas fills the triangles with per-facet shades inside a shadowed layer, then strokes creases and the warped text lines. Release animates the progress with a spring.",
            "MagnifyGesture 把缩放倍率映射为进度值；一个 Animatable 视图让每个网格顶点在平整位置与圆盘内的哈希随机位置之间插值（各有延迟），Canvas 在带阴影的图层里以逐面灰度填充三角形，再描出折痕与随网格变形的文字行。松手时用弹簧动画驱动进度。"
        ),
        apis: ["MagnifyGesture", "Animatable", "Canvas", "GraphicsContext.drawLayer", "spring(response:dampingFraction:)"],
        tags: ["crumple", "paper", "pinch", "squeeze", "mesh", "delete", "揉皱", "纸团", "捏合", "挤压", "网格", "丢弃"],
        params: [
            .slider("ball", L("Ball radius", "纸团半径"), 30...64, default: 48, step: 1, decimals: 0, unit: "pt"),
            .slider("contrast", L("Facet contrast", "棱面对比"), 0.2...1.0, default: 0.6),
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.9, default: 0.45, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.35...1.0, default: 0.62),
        ]
    ) { ctx in
        SqueezeCrumpleDemo(ctx: ctx)
    }
}

private enum Sheet {
    static let stage = CGSize(width: 300, height: 268)
    static let size = CGSize(width: 180, height: 220)
    static let cols = 9
    static let rows = 11
    static let twist: Double = 50 * .pi / 180
}

private struct SqueezeCrumpleDemo: View {
    let ctx: DemoContext
    /// 0 = flat sheet, 1 = paper ball.
    @State private var progress: CGFloat
    @State private var base: CGFloat = 0
    /// The deepest crumple so far: what is left as creases when the sheet is flat again.
    @State private var creased: CGFloat
    @State private var held = false
    @State private var crunch = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pinching = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 0.56 : 0)
        _creased = State(initialValue: ctx.isStill ? 0.56 : 0)
    }

    var body: some View {
        VStack(spacing: 10) {
            CrumpleSheet(
                progress: progress,
                creased: creased,
                ball: ctx.cg("ball"),
                contrast: ctx["contrast"]
            )
            .frame(width: Sheet.stage.width, height: Sheet.stage.height)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            .gesture(pinch)

            DemoHint(text: L("Pinch to crumple, spread to smooth (or tap)", "捏合揉皱，张开抹平（也可点击）"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.3, delay: 0.5) { autoPinch() }
        .onChange(of: pinching) { _, isPinching in
            if !isPinching { pinchEnded() }
        }
        .onDisappear { script?.cancel() }
    }

    private var pinch: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.02)
            .updating($pinching) { _, state, _ in state = true }
            .onChanged { value in
                if !held { script?.cancel() }
                pinchChanged(value.magnification)
            }
            .onEnded { _ in pinchEnded() }
    }

    /// Fingers (or the scripted pinch) are at `magnification` relative to where they started.
    private func pinchChanged(_ magnification: CGFloat) {
        if !held {
            held = true
            base = progress.clamped(to: 0...1)
        }
        let raw: CGFloat = magnification < 1 ? base + (1 - magnification) * 1.7 : base - (magnification - 1) * 1.15
        let next: CGFloat = raw > 1 ? 1 + rubberBand(raw - 1, limit: 0.1) : (raw < 0 ? -rubberBand(-raw, limit: 0.05) : raw)
        progress = next
        creased = max(creased, min(next, 1))
        // A crunch every eighth of the way.
        let step: Int = Int((next * 8).rounded(.down))
        if step != crunch {
            crunch = step
            if !ctx.isPreview { Haptics.tap(.rigid) }
        }
    }

    private func pinchEnded() {
        guard held else { return }
        held = false
        settle(crumpled: progress > 0.5)
    }

    private func toggle() {
        guard !held else { return }
        script?.cancel()
        settle(crumpled: progress < 0.5)
    }

    private func settle(crumpled: Bool) {
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            progress = crumpled ? 1 : 0
        }
        if crumpled { creased = 1 }
        if !ctx.isPreview { Haptics.tap(crumpled ? .medium : .soft) }
    }

    /// A scripted pinch: squeeze in to crumple, and the next time spread out to smooth.
    private func autoPinch() {
        guard !held, !pinching else { return }
        autoStep += 1
        let closing: Bool = progress < 0.5
        let end: CGFloat = closing ? 0.52 : 1.75
        script?.cancel()
        script = Task { @MainActor in
            let finished = await GhostFinger.drag(from: CGPoint(x: 1, y: 0), to: CGPoint(x: end, y: 0), duration: 0.8) { point in
                pinchChanged(point.x)
            }
            guard finished else { return }
            pinchEnded()
        }
    }
}

/// The paper mesh. `progress` animates, so springs drive the whole crumple.
private struct CrumpleSheet: View, Animatable {
    var progress: CGFloat
    let creased: CGFloat
    let ball: CGFloat
    let contrast: Double

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var amount: CGFloat { min(max(progress, 0), 1) }

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let count: Int = Sheet.cols * Sheet.rows
            let flats: [CGPoint] = (0..<count).map { flat($0) }
            let shifts: [CGPoint] = (0..<count).map { shift($0, flat: flats[$0]) }
            let points: [CGPoint] = (0..<count).map {
                CGPoint(x: centre.x + flats[$0].x + shifts[$0].x, y: centre.y + flats[$0].y + shifts[$0].y)
            }
            let amounts: [CGFloat] = (0..<count).map { local($0) }
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.22 + 0.14 * Double(amount)), radius: 9 - 3 * amount, y: 6 + 5 * amount))
                drawFacets(&layer, points: points, amounts: amounts, centre: centre)
            }
            drawCreases(&context, points: points)
            drawPrint(&context, shifts: shifts, centre: centre)
        }
    }

    /// How far vertex `index` is along its own crumple: corners lead, the centre trails.
    private func local(_ index: Int) -> CGFloat {
        let col: CGFloat = CGFloat(index % Sheet.cols) / CGFloat(Sheet.cols - 1) - 0.5
        let row: CGFloat = CGFloat(index / Sheet.cols) / CGFloat(Sheet.rows - 1) - 0.5
        let edge: CGFloat = min((col * col + row * row).squareRoot() / 0.7071, 1)
        let delay: CGFloat = 0.35 * (1 - edge)
        let t: CGFloat = (progress - delay) / (1 - delay)
        if t <= 0 { return max(t, -0.1) * 0.3 }
        if t >= 1 { return t }
        return t * t * (3 - 2 * t)
    }

    /// Where vertex `index` lies on the flat sheet, relative to its centre. Interior vertices are
    /// nudged off the regular grid (invisible while flat) so the folds come out irregular.
    private func flat(_ index: Int) -> CGPoint {
        let col: Int = index % Sheet.cols
        let row: Int = index / Sheet.cols
        var u: CGFloat = CGFloat(col) / CGFloat(Sheet.cols - 1)
        var v: CGFloat = CGFloat(row) / CGFloat(Sheet.rows - 1)
        if col > 0 && col < Sheet.cols - 1 {
            u += CGFloat(GestureMath.hash(index * 3 + 17) - 0.5) * 0.62 / CGFloat(Sheet.cols - 1)
        }
        if row > 0 && row < Sheet.rows - 1 {
            v += CGFloat(GestureMath.hash(index * 5 + 29) - 0.5) * 0.62 / CGFloat(Sheet.rows - 1)
        }
        return CGPoint(x: (u - 0.5) * Sheet.size.width, y: (v - 0.5) * Sheet.size.height)
    }

    /// How far vertex `index` has moved from its flat position.
    private func shift(_ index: Int, flat: CGPoint) -> CGPoint {
        let col: Int = index % Sheet.cols
        let row: Int = index / Sheet.cols
        let border: Bool = col == 0 || row == 0 || col == Sheet.cols - 1 || row == Sheet.rows - 1
        // Destination inside the ball: border vertices stay near the rim so the silhouette is round.
        let h1: Double = GestureMath.hash(index * 7 + 3)
        let h2: Double = GestureMath.hash(index * 13 + 11)
        let radius: CGFloat = ball * CGFloat(border ? 0.8 + 0.2 * h1 : 0.1 + 0.7 * h1)
        let angle: Double = atan2(Double(flat.y), Double(flat.x)) + (h2 - 0.5) * (border ? 0.5 : 2.4) + Sheet.twist
        let crushed = CGPoint(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
        let t: CGFloat = local(index)
        // A smoothed sheet never gets perfectly flat again.
        let memory: CGFloat = border ? 0 : creased * 2.2 * (1 - amount)
        return CGPoint(
            x: (crushed.x - flat.x) * t + CGFloat(h1 - 0.5) * memory,
            y: (crushed.y - flat.y) * t + CGFloat(h2 - 0.5) * memory
        )
    }

    private func drawFacets(_ context: inout GraphicsContext, points: [CGPoint], amounts: [CGFloat], centre: CGPoint) {
        let paper = GestureRGB(0.972, 0.962, 0.934)
        let shadow = GestureRGB(0.3, 0.29, 0.36)
        for row in 0..<(Sheet.rows - 1) {
            for col in 0..<(Sheet.cols - 1) {
                let i: Int = row * Sheet.cols + col
                let quad: [Int] = [i, i + 1, i + Sheet.cols + 1, i + Sheet.cols]
                // Alternate the diagonal so the facets do not line up.
                let flip: Bool = (row + col) % 2 == 0
                let triangles: [[Int]] = flip
                    ? [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]
                    : [[quad[0], quad[1], quad[3]], [quad[1], quad[2], quad[3]]]
                for (n, tri) in triangles.enumerated() {
                    let a: CGPoint = points[tri[0]]
                    let b: CGPoint = points[tri[1]]
                    let c: CGPoint = points[tri[2]]
                    var path = Path()
                    path.move(to: a)
                    path.addLine(to: b)
                    path.addLine(to: c)
                    path.closeSubpath()
                    let folded: Double = Double(min(max((amounts[tri[0]] + amounts[tri[1]] + amounts[tri[2]]) / 3, 0), 1))
                    let noise: Double = GestureMath.hash(i * 2 + n + 31)
                    // On the ball a facet is lit by where it sits relative to a top-left light.
                    let mx: Double = Double((a.x + b.x + c.x) / 3 - centre.x) / Double(max(ball, 1))
                    let my: Double = Double((a.y + b.y + c.y) / 3 - centre.y) / Double(max(ball, 1))
                    let facing: Double = min(max((mx * 0.6 + my * 0.8) * 0.5 + 0.5, 0), 1)
                    let lit: Double = (0.12 + 0.5 * facing) * 0.55 + noise * 0.45 * (0.3 + contrast)
                    // A smoothed sheet keeps a few faintly shaded facets.
                    let residue: Double = noise > 0.62 ? Double(creased) * 0.07 * (noise - 0.62) / 0.38 : 0
                    let dim: Double = min(max(folded * lit * (0.5 + contrast), residue), 0.85)
                    let color: Color = paper.mixed(shadow, dim).color()
                    context.fill(path, with: .color(color))
                    context.stroke(path, with: .color(color), lineWidth: 0.7)
                }
            }
        }
    }

    private func drawCreases(_ context: inout GraphicsContext, points: [CGPoint]) {
        // Fold lines read on the sheet; on the ball the facets take over.
        let strength: Double = max(Double(amount) * (1 - 0.75 * Double(amount)) * 2, Double(creased) * 0.3)
        guard strength > 0.01 else { return }
        var folds = Path()
        for row in 0..<Sheet.rows {
            for col in 0..<Sheet.cols {
                let i: Int = row * Sheet.cols + col
                // Only some edges crease, picked by hash, so the pattern looks irregular.
                if col < Sheet.cols - 1 && row > 0 && row < Sheet.rows - 1 && GestureMath.hash(i * 5 + 1) > 0.5 {
                    folds.move(to: points[i])
                    folds.addLine(to: points[i + 1])
                }
                if row < Sheet.rows - 1 && col > 0 && col < Sheet.cols - 1 && GestureMath.hash(i * 5 + 2) > 0.5 {
                    folds.move(to: points[i])
                    folds.addLine(to: points[i + Sheet.cols])
                }
                if col < Sheet.cols - 1 && row < Sheet.rows - 1 && GestureMath.hash(i * 5 + 3) > 0.55 {
                    let flip: Bool = (row + col) % 2 == 0
                    folds.move(to: points[flip ? i : i + 1])
                    folds.addLine(to: points[flip ? i + Sheet.cols + 1 : i + Sheet.cols])
                }
            }
        }
        context.stroke(folds, with: .color(Color(hex: 0x3A3840).opacity(0.26 * min(strength, 1))), lineWidth: 0.6)
    }

    /// A point of the sheet in its own 0…1 coordinates, carried along by the mesh: its flat position
    /// plus the vertex shifts around it, blended bilinearly.
    private func mapped(_ u: CGFloat, _ v: CGFloat, shifts: [CGPoint], centre: CGPoint) -> CGPoint {
        let x: CGFloat = u * CGFloat(Sheet.cols - 1)
        let y: CGFloat = v * CGFloat(Sheet.rows - 1)
        let col: Int = min(Int(x), Sheet.cols - 2)
        let row: Int = min(Int(y), Sheet.rows - 2)
        let fx: CGFloat = x - CGFloat(col)
        let fy: CGFloat = y - CGFloat(row)
        let i: Int = row * Sheet.cols + col
        let top: CGPoint = GestureMath.lerp(shifts[i], shifts[i + 1], fx)
        let bottom: CGPoint = GestureMath.lerp(shifts[i + Sheet.cols], shifts[i + Sheet.cols + 1], fx)
        let moved: CGPoint = GestureMath.lerp(top, bottom, fy)
        return CGPoint(
            x: centre.x + (u - 0.5) * Sheet.size.width + moved.x,
            y: centre.y + (v - 0.5) * Sheet.size.height + moved.y
        )
    }

    private func drawPrint(_ context: inout GraphicsContext, shifts: [CGPoint], centre: CGPoint) {
        let fade: Double = 1 - 0.6 * Double(amount)
        let thin: CGFloat = 1 - 0.45 * amount
        // Header bar, then text lines of different lengths.
        let rows: [(v: CGFloat, from: CGFloat, to: CGFloat, header: Bool)] = [
            (0.12, 0.12, 0.52, true),
            (0.27, 0.12, 0.88, false), (0.35, 0.12, 0.82, false), (0.43, 0.12, 0.88, false), (0.51, 0.12, 0.6, false),
            (0.64, 0.12, 0.88, false), (0.72, 0.12, 0.76, false), (0.80, 0.12, 0.86, false), (0.88, 0.12, 0.44, false),
        ]
        for row in rows {
            var line = Path()
            let segments: Int = 18
            for step in 0...segments {
                let u: CGFloat = row.from + (row.to - row.from) * CGFloat(step) / CGFloat(segments)
                let p: CGPoint = mapped(u, row.v, shifts: shifts, centre: centre)
                if step == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            context.stroke(
                line,
                with: .color(row.header ? Palette.indigo.opacity(0.9 * fade) : Color(hex: 0x8C8A93).opacity(0.55 * fade)),
                style: StrokeStyle(lineWidth: (row.header ? 7 : 3) * thin, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
