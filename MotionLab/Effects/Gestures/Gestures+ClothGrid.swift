import SwiftUI

extension Effect {
    static let gesturesClothGrid = Effect(
        id: "gestures.cloth-grid",
        category: .gestures,
        interaction: .gesture,
        name: L("Hanging Cloth", "悬挂布料"),
        summary: L("A pleated curtain simulated in 3D on a rail: grab any spot, gather it, let go and watch the folds swing and settle.", "挂在横杆上的三维模拟布帘：抓住任意一点收拢再松手，看褶皱摆动并慢慢平息。"),
        prompt: L(
            "A 240×180 pt curtain hangs from five rings on a rail: a 17×13 grid of Verlet points 15 pt apart, simulated in three dimensions under 1,200 pt/s² gravity and held together by horizontal, vertical and softer diagonal distance constraints solved 6 times per 1/120 s step. The rings sit 12% closer than the fabric is wide, so the slack falls into pleats. Each cell is filled with a violet-to-coral gradient lit by its surface normal, the back of the fabric a shade darker, with a faint weave on top. Touching grabs the nearest point within 40 pt and pins it to the finger; the fabric gathers and drapes toward it, and on release the point keeps the finger's velocity, so a flick sends a wave across the cloth before it sways to rest. A gusting breeze (strength 0.35) billows it in depth. Soft, weighty, believable.",
            "240×180 pt的布帘由五个挂环挂在横杆上：17×13的Verlet质点网格，间距15 pt，在三维中模拟，受1200 pt/s²重力，由水平、竖直和较软的对角距离约束连成一体，每个1/120秒步长求解6次。挂环间距比布料窄12%，多出的布自然垂成褶皱。格子填充紫到珊瑚色渐变，按表面法线受光，背面略暗，叠一层淡织纹。触摸时抓住40 pt内最近的质点并固定在指尖，布料朝它收拢垂坠；松手时保留手指速度，一甩就有一道波横穿布面，再摆动着平息。阵风（强度0.35）让它前后鼓动。柔软可信。"
        ),
        implementation: L(
            "A reference-type Verlet grid with x, y and depth is stepped at a fixed 1/120 s inside a TimelineView: integrate with gravity and a sinusoidal wind blowing through the cloth, then relax the distance constraints several times with pinned points weighted zero. A Canvas projects the points, shades 2×2 patches per cell from interpolated normals and paints them back to front; the DragGesture pins the nearest point to the finger.",
            "带 x、y 与深度的引用类型 Verlet 网格在 TimelineView 中以固定 1/120 秒步长推进：先在重力和穿过布面的正弦风力下积分，再多次松弛距离约束，固定点权重为零。Canvas 投影各质点，每格拆成 2×2 小片并用插值法线着色，按由远及近的顺序绘制；DragGesture 把最近的质点固定在指尖。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "Verlet integration", "DragGesture.Value.velocity", "Path"],
        tags: ["cloth", "fabric", "verlet", "curtain", "simulation", "net", "布料", "布帘", "物理模拟", "网格", "褶皱"],
        params: [
            .slider("gravity", L("Gravity", "重力"), 400...2400, default: 1200, step: 50, decimals: 0, unit: "pt/s²"),
            .slider("stiffness", L("Solver passes", "求解次数"), 2...12, default: 6, step: 1, decimals: 0),
            .slider("wind", L("Breeze", "微风"), 0...1, default: 0.35),
            .choice("pins", L("Hung by", "悬挂方式"), [L("Rail", "横杆"), L("Corners", "两角")], default: 0),
        ]
    ) { ctx in
        ClothGridDemo(ctx: ctx)
    }
}

private enum Cloth {
    static let size = CGSize(width: 300, height: 280)
    static let columns = 17
    static let rows = 13
    static let spacing: CGFloat = 15
    /// A ring every `pinEvery` points along the top edge.
    static let pinEvery = 4
    static let origin = CGPoint(x: 30, y: 44)
    static let top: [(Double, Double, Double)] = [(0.64, 0.42, 1.0), (1.0, 0.37, 0.64), (1.0, 0.48, 0.36)]
}

/// A point of the cloth in stage space; +z comes toward the viewer.
private struct ClothPoint {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
}

private final class ClothModel {
    private(set) var points: [ClothPoint]
    private var previous: [ClothPoint]
    private(set) var grabbed: Int?
    private var finger: CGPoint = .zero
    private var corners = false
    private var time: Double = 0
    private var accumulator: Double = 0
    private var clock = GestureStepClock()
    private let h: Double = 1.0 / 120.0

    init() {
        var grid: [ClothPoint] = []
        for row in 0..<Cloth.rows {
            for column in 0..<Cloth.columns {
                // A little depth to start with, so the slack between rings falls into pleats.
                let depth: CGFloat = CGFloat(sin(Double(column) * .pi / 2 + 0.6)) * 7
                grid.append(ClothPoint(x: Cloth.origin.x + CGFloat(column) * Cloth.spacing, y: Cloth.origin.y + CGFloat(row) * Cloth.spacing, z: depth))
            }
        }
        points = grid
        previous = grid
        // Hang for a moment so the first frame (and the still) already shows a draped cloth.
        for _ in 0..<300 { integrate(gravity: 1200, iterations: 6, wind: 0.5) }
    }

    /// Rings sit a little closer together than the cloth is wide, so the slack hangs in pleats.
    private func pinPosition(_ column: Int) -> CGPoint {
        let middle: CGFloat = CGFloat(Cloth.columns - 1) / 2
        let pitch: CGFloat = corners ? Cloth.spacing * 0.96 : Cloth.spacing * 0.88
        return CGPoint(x: Cloth.size.width / 2 + (CGFloat(column) - middle) * pitch, y: Cloth.origin.y)
    }

    func isPinned(_ index: Int) -> Bool {
        guard index < Cloth.columns else { return false }
        return corners ? (index == 0 || index == Cloth.columns - 1) : index % Cloth.pinEvery == 0
    }

    func setCorners(_ value: Bool) {
        corners = value
    }

    /// Where a point appears on the stage (a mild perspective pushes near points outward).
    func screen(_ index: Int) -> CGPoint {
        let p = points[index]
        let k: CGFloat = 1 + p.z * 0.0014
        return CGPoint(
            x: Cloth.size.width / 2 + (p.x - Cloth.size.width / 2) * k,
            y: Cloth.size.height / 2 + (p.y - Cloth.size.height / 2) * k
        )
    }

    func isSettled(wind: Double) -> Bool {
        guard grabbed == nil, wind < 0.01 else { return false }
        for index in points.indices {
            let a = points[index]
            let b = previous[index]
            if abs(a.x - b.x) > 0.02 || abs(a.y - b.y) > 0.02 || abs(a.z - b.z) > 0.02 { return false }
        }
        return true
    }

    func nearest(to point: CGPoint, within reach: CGFloat) -> Int? {
        var best: Int?
        var bestDistance: CGFloat = reach
        for index in points.indices where !isPinned(index) {
            let d: CGFloat = GestureMath.distance(screen(index), point)
            if d < bestDistance {
                best = index
                bestDistance = d
            }
        }
        return best
    }

    func grab(_ index: Int, at point: CGPoint) {
        grabbed = index
        finger = point
    }

    func move(to point: CGPoint) {
        var target = CGPoint(x: point.x.clamped(to: 6...(Cloth.size.width - 6)), y: point.y.clamped(to: 6...(Cloth.size.height - 6)))
        // The grabbed point can only go as far from each ring as the fabric between them reaches,
        // so a hard pull drapes the cloth instead of stretching it.
        if let grabbed {
            let column: Int = grabbed % Cloth.columns
            let row: Int = grabbed / Cloth.columns
            for _ in 0..<2 {
                for pin in 0..<Cloth.columns where isPinned(pin) {
                    let anchor = pinPosition(pin)
                    let across: CGFloat = CGFloat(column - pin) * Cloth.spacing
                    let down: CGFloat = CGFloat(row) * Cloth.spacing
                    let reach: CGFloat = (across * across + down * down).squareRoot() * 1.04
                    let d: CGFloat = GestureMath.distance(target, anchor)
                    if d > reach && d > 0 {
                        target = CGPoint(x: anchor.x + (target.x - anchor.x) / d * reach, y: anchor.y + (target.y - anchor.y) / d * reach)
                    }
                }
            }
        }
        finger = target
    }

    func release(velocity: CGVector) {
        guard let index = grabbed else { return }
        grabbed = nil
        let vx: CGFloat = velocity.dx.clamped(to: -2400...2400)
        let vy: CGFloat = velocity.dy.clamped(to: -2400...2400)
        previous[index].x = points[index].x - vx * CGFloat(h)
        previous[index].y = points[index].y - vy * CGFloat(h)
    }

    func step(to date: Date, gravity: Double, iterations: Int, wind: Double) {
        let dt: Double = clock.delta(to: date)
        accumulator = min(accumulator + dt, 0.05)
        var steps = 0
        while accumulator >= h && steps < 5 {
            integrate(gravity: gravity, iterations: iterations, wind: wind)
            accumulator -= h
            steps += 1
        }
    }

    private func integrate(gravity: Double, iterations: Int, wind: Double) {
        time += h
        let g: CGFloat = CGFloat(gravity * h * h)
        // The breeze blows mostly through the cloth (in depth), in slow gusts.
        let gust: Double = wind * 900 * (0.55 + 0.45 * sin(time * 0.9)) * h * h
        for index in points.indices {
            if isPinned(index) {
                let pin = pinPosition(index % Cloth.columns)
                points[index] = ClothPoint(x: pin.x, y: pin.y, z: 0)
                previous[index] = points[index]
                continue
            }
            let p = points[index]
            let vx: CGFloat = (p.x - previous[index].x) * 0.994
            let vy: CGFloat = (p.y - previous[index].y) * 0.994
            let vz: CGFloat = (p.z - previous[index].z) * 0.99
            let phase: Double = time * 2.3 + Double(p.y) * 0.035 + Double(p.x) * 0.02
            let push: CGFloat = CGFloat(gust * sin(phase))
            previous[index] = p
            points[index] = ClothPoint(x: p.x + vx + push * 0.25, y: p.y + vy + g, z: p.z + vz + push)
        }
        if let grabbed {
            points[grabbed] = ClothPoint(x: finger.x, y: finger.y, z: 14)
        }

        let diagonal: CGFloat = Cloth.spacing * 1.41421356
        for _ in 0..<max(iterations, 1) {
            for row in 0..<Cloth.rows {
                for column in 0..<Cloth.columns {
                    let index: Int = row * Cloth.columns + column
                    if column + 1 < Cloth.columns { relax(index, index + 1, rest: Cloth.spacing, strength: 1) }
                    if row + 1 < Cloth.rows { relax(index, index + Cloth.columns, rest: Cloth.spacing, strength: 1) }
                    // Softer diagonals resist shear, so the weave keeps its shape while it drapes.
                    if column + 1 < Cloth.columns && row + 1 < Cloth.rows {
                        relax(index, index + Cloth.columns + 1, rest: diagonal, strength: 0.25)
                        relax(index + 1, index + Cloth.columns, rest: diagonal, strength: 0.25)
                    }
                }
            }
        }

        for index in points.indices where index != grabbed && !isPinned(index) {
            points[index].x = points[index].x.clamped(to: 4...(Cloth.size.width - 4))
            points[index].y = min(points[index].y, Cloth.size.height - 4)
            points[index].z = points[index].z.clamped(to: -70...70)
        }
    }

    private func relax(_ a: Int, _ b: Int, rest: CGFloat, strength: CGFloat) {
        let dx: CGFloat = points[b].x - points[a].x
        let dy: CGFloat = points[b].y - points[a].y
        let dz: CGFloat = points[b].z - points[a].z
        let d: CGFloat = max((dx * dx + dy * dy + dz * dz).squareRoot(), 0.0001)
        let diff: CGFloat = (d - rest) / d * strength
        let wa: CGFloat = isPinned(a) || a == grabbed ? 0 : 1
        let wb: CGFloat = isPinned(b) || b == grabbed ? 0 : 1
        let total: CGFloat = wa + wb
        guard total > 0 else { return }
        points[a].x += dx * diff * wa / total
        points[a].y += dy * diff * wa / total
        points[a].z += dz * diff * wa / total
        points[b].x -= dx * diff * wb / total
        points[b].y -= dy * diff * wb / total
        points[b].z -= dz * diff * wb / total
    }
}

private struct ClothGridDemo: View {
    let ctx: DemoContext
    @State private var model = ClothModel()
    @State private var held = false
    @State private var grabOffset: CGSize = .zero
    @State private var wake = 0
    @State private var script: Task<Void, Never>?
    @State private var autoStep = 0
    /// Resets on system cancellation too, so a stolen touch never leaves the cloth pinned to a ghost finger.
    @GestureState private var pressing = false

    var body: some View {
        let gravity = ctx["gravity"]
        let iterations = ctx.int("stiffness")
        let wind = ctx["wind"]
        let corners = ctx.int("pins") == 1
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled(wind: wind) }) { date in
                let _ = model.setCorners(corners)
                let _ = model.step(to: date, gravity: gravity, iterations: iterations, wind: wind)
                ClothCanvas(model: model, corners: corners, tick: date)
            }
            .frame(width: Cloth.size.width, height: Cloth.size.height)
            .background(Palette.elevated, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            .contentShape(shape)
            .gesture(drag)

            DemoHint(text: L("Grab the cloth and pull", "抓住布料拉一拉"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.5) { autoTug() }
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { letGo(velocity: .zero) }
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held {
                    guard let index = model.nearest(to: value.startLocation, within: 40) else { return }
                    script?.cancel()
                    held = true
                    let p = model.screen(index)
                    grabOffset = CGSize(width: value.startLocation.x - p.x, height: value.startLocation.y - p.y)
                    model.grab(index, at: p)
                    Haptics.tap(.light)
                }
                model.move(to: CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
                wake += 1
            }
            .onEnded { value in
                letGo(velocity: CGVector(dx: value.velocity.width, dy: value.velocity.height))
            }
    }

    private func letGo(velocity: CGVector) {
        guard model.grabbed != nil else { return }
        if held { Haptics.tap(.soft) }
        held = false
        model.release(velocity: velocity)
        wake += 1
    }

    /// A scripted finger grabs a point low on the cloth, pulls it aside and flicks it back, through
    /// the same grab / move / release the real drag calls.
    private func autoTug() {
        guard !held, model.grabbed == nil else { return }
        autoStep += 1
        let side: CGFloat = autoStep.isMultiple(of: 2) ? 1 : -1
        // Draw the curtain: gather one edge toward the middle, then let it fly back.
        let column: Int = side > 0 ? 14 : 2
        let index: Int = 8 * Cloth.columns + column
        let start = model.screen(index)
        let end = CGPoint(x: start.x - side * 96, y: start.y - 30)
        model.grab(index, at: start)
        wake += 1
        script?.cancel()
        script = Task { @MainActor in
            let finished = await GhostFinger.drag(from: start, to: end, duration: 0.6) { point in
                model.move(to: point)
                wake += 1
            }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            letGo(velocity: CGVector(dx: side * 700, dy: 200))
        }
    }
}

private struct ClothCanvas: View {
    let model: ClothModel
    let corners: Bool
    /// Changes every frame so SwiftUI redraws (the model is a reference and compares equal).
    let tick: Date

    var body: some View {
        Canvas { context, size in
            drawRail(&context, size: size)
            drawFabric(&context)
            drawPins(&context)
        }
    }

    private func drawRail(_ context: inout GraphicsContext, size: CGSize) {
        guard !corners else { return }
        let rail = CGRect(x: 18, y: Cloth.origin.y - 9, width: size.width - 36, height: 5)
        context.fill(Path(roundedRect: rail, cornerRadius: 2.5), with: .color(.primary.opacity(0.28)))
        context.fill(Path(ellipseIn: CGRect(x: rail.minX - 4, y: rail.midY - 5, width: 10, height: 10)), with: .color(.primary.opacity(0.35)))
        context.fill(Path(ellipseIn: CGRect(x: rail.maxX - 6, y: rail.midY - 5, width: 10, height: 10)), with: .color(.primary.opacity(0.35)))
    }

    private struct Patch {
        let path: Path
        /// Thread lines along the original cell edges and the hem at the bottom.
        let weave: Path?
        let hem: Path?
        let depth: CGFloat
        let color: Color
    }

    /// Smooth vertex normal from the neighbouring points.
    private func normal(_ column: Int, _ row: Int) -> (CGFloat, CGFloat, CGFloat) {
        let left = model.points[row * Cloth.columns + max(column - 1, 0)]
        let right = model.points[row * Cloth.columns + min(column + 1, Cloth.columns - 1)]
        let up = model.points[max(row - 1, 0) * Cloth.columns + column]
        let down = model.points[min(row + 1, Cloth.rows - 1) * Cloth.columns + column]
        let ux: CGFloat = right.x - left.x
        let uy: CGFloat = right.y - left.y
        let uz: CGFloat = right.z - left.z
        let vx: CGFloat = down.x - up.x
        let vy: CGFloat = down.y - up.y
        let vz: CGFloat = down.z - up.z
        let nx: CGFloat = uy * vz - uz * vy
        let ny: CGFloat = uz * vx - ux * vz
        let nz: CGFloat = ux * vy - uy * vx
        let length: CGFloat = max((nx * nx + ny * ny + nz * nz).squareRoot(), 0.0001)
        return (nx / length, ny / length, nz / length)
    }

    private func drawFabric(_ context: inout GraphicsContext) {
        let count: Int = Cloth.columns * Cloth.rows
        var screens: [CGPoint] = []
        var normals: [(CGFloat, CGFloat, CGFloat)] = []
        screens.reserveCapacity(count)
        normals.reserveCapacity(count)
        for row in 0..<Cloth.rows {
            for column in 0..<Cloth.columns {
                screens.append(model.screen(row * Cloth.columns + column))
                normals.append(normal(column, row))
            }
        }

        // Each cell is drawn as 2×2 patches shaded from interpolated normals, which reads as smooth fabric.
        let sub = 2
        let step: CGFloat = 1 / CGFloat(sub)
        // Light from the upper left, in front of the cloth.
        let light: (CGFloat, CGFloat, CGFloat) = (-0.38, -0.42, 0.82)
        var patches: [Patch] = []
        patches.reserveCapacity((Cloth.rows - 1) * (Cloth.columns - 1) * sub * sub)

        for row in 0..<(Cloth.rows - 1) {
            for column in 0..<(Cloth.columns - 1) {
                let ia: Int = row * Cloth.columns + column
                let ib: Int = ia + 1
                let ic: Int = ia + Cloth.columns + 1
                let id: Int = ia + Cloth.columns
                let za: CGFloat = model.points[ia].z
                let zb: CGFloat = model.points[ib].z
                let zc: CGFloat = model.points[ic].z
                let zd: CGFloat = model.points[id].z

                func corner(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
                    let top = GestureMath.lerp(screens[ia], screens[ib], u)
                    let bottom = GestureMath.lerp(screens[id], screens[ic], u)
                    return GestureMath.lerp(top, bottom, v)
                }

                for j in 0..<sub {
                    for i in 0..<sub {
                        let u0: CGFloat = CGFloat(i) * step
                        let v0: CGFloat = CGFloat(j) * step
                        let u: CGFloat = u0 + step / 2
                        let v: CGFloat = v0 + step / 2
                        let wa: CGFloat = (1 - u) * (1 - v)
                        let wb: CGFloat = u * (1 - v)
                        let wc: CGFloat = u * v
                        let wd: CGFloat = (1 - u) * v
                        let nx: CGFloat = normals[ia].0 * wa + normals[ib].0 * wb + normals[ic].0 * wc + normals[id].0 * wd
                        let ny: CGFloat = normals[ia].1 * wa + normals[ib].1 * wb + normals[ic].1 * wc + normals[id].1 * wd
                        let nz: CGFloat = normals[ia].2 * wa + normals[ib].2 * wb + normals[ic].2 * wc + normals[id].2 * wd
                        let length: CGFloat = max((nx * nx + ny * ny + nz * nz).squareRoot(), 0.0001)
                        let lambert: CGFloat = abs(nx * light.0 + ny * light.1 + nz * light.2) / length
                        // The back of the fabric is a shade darker than its face.
                        let shade: Double = Double(0.4 + 0.7 * lambert) * (nz >= 0 ? 1 : 0.7)

                        let p00 = corner(u0, v0)
                        let p10 = corner(u0 + step, v0)
                        let p11 = corner(u0 + step, v0 + step)
                        let p01 = corner(u0, v0 + step)
                        var quad = Path()
                        quad.move(to: p00)
                        quad.addLine(to: p10)
                        quad.addLine(to: p11)
                        quad.addLine(to: p01)
                        quad.closeSubpath()

                        var weave: Path?
                        if i == 0 || j == 0 {
                            var threads = Path()
                            if j == 0 {
                                threads.move(to: p00)
                                threads.addLine(to: p10)
                            }
                            if i == 0 {
                                threads.move(to: p00)
                                threads.addLine(to: p01)
                            }
                            weave = threads
                        }
                        var hem: Path?
                        if row == Cloth.rows - 2 && j == sub - 1 {
                            var edge = Path()
                            edge.move(to: p01)
                            edge.addLine(to: p11)
                            hem = edge
                        }
                        let t: Double = (Double(column) + Double(u)) / Double(Cloth.columns - 1)
                        patches.append(Patch(
                            path: quad,
                            weave: weave,
                            hem: hem,
                            depth: za * wa + zb * wb + zc * wc + zd * wd,
                            color: ClothCanvas.tint(t, light: shade)
                        ))
                    }
                }
            }
        }
        // Painter's order: far patches first, so pleats and folds overlap correctly.
        patches.sort { $0.depth < $1.depth }
        for patch in patches {
            context.fill(patch.path, with: .color(patch.color))
            // A hairline in the same colour closes the seams between patches.
            context.stroke(patch.path, with: .color(patch.color), lineWidth: 0.7)
            if let weave = patch.weave {
                context.stroke(weave, with: .color(.white.opacity(0.12)), lineWidth: 0.6)
            }
            if let hem = patch.hem {
                context.stroke(hem, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    private static func tint(_ t: Double, light: Double) -> Color {
        let stops = Cloth.top
        let scaled: Double = t.clamped(to: 0...1) * Double(stops.count - 1)
        let index: Int = min(Int(scaled), stops.count - 2)
        let f: Double = scaled - Double(index)
        let a = stops[index]
        let b = stops[index + 1]
        return Color(
            .sRGB,
            red: min((a.0 + (b.0 - a.0) * f) * light, 1),
            green: min((a.1 + (b.1 - a.1) * f) * light, 1),
            blue: min((a.2 + (b.2 - a.2) * f) * light, 1),
            opacity: 1
        )
    }

    private func drawPins(_ context: inout GraphicsContext) {
        for column in 0..<Cloth.columns where model.isPinned(column) {
            let p = model.screen(column)
            if corners {
                context.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(Palette.amber))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 3.5, width: 4, height: 4)), with: .color(.white.opacity(0.8)))
            } else {
                let ring = Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 11, width: 10, height: 12))
                context.stroke(ring, with: .color(.primary.opacity(0.55)), lineWidth: 2)
            }
        }
        if let grabbed = model.grabbed {
            let p = model.screen(grabbed)
            context.stroke(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.8)), lineWidth: 2)
        }
    }
}
