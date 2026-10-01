import SwiftUI

extension Effect {
    static let gesturesSoftBody = Effect(
        id: "gestures.soft-body",
        category: .gestures,
        interaction: .gesture,
        name: L("Soft-Body Jelly", "软体果冻"),
        summary: L("A pudding built from spring-linked points: poke it and it dents, bulges elsewhere to keep its volume, then jiggles back.", "由弹簧相连的质点构成的布丁：戳一下会凹陷，别处鼓起以保持体积，然后抖动着复原。"),
        prompt: L(
            "A raspberry jelly about 172 pt wide sits on a plate, its outline 28 point masses joined by springs to their neighbours, pulled toward their rest positions (stiffness 120, the base held eight times harder) and pushed outward by an area-preserving pressure. Tapping pokes it: points near the tap get a 420 pt/s kick toward the centre with a Gaussian falloff (σ 46 pt), so the surface dents, the far side swells and a wave runs around the skin before damping 4 calms it in about a second. Dragging grabs the nearest patch and stretches it up to 90 pt with rubber-band resistance; release snaps it back with a wobble and a soft haptic. A glossy highlight and two eyes ride the deformation, the eyes squinting as it squashes. Squishy, elastic, alive.",
            "一块约172 pt宽的树莓果冻坐在盘子上，轮廓由28个质点组成：相邻质点以弹簧相连，同时被拉向各自的静止位置（刚度120，底部为8倍），并受保持面积的内压向外推。点击即戳一下：落点附近的质点获得朝向中心的420 pt/s冲量，按高斯衰减（σ 46 pt），表面凹陷、另一侧鼓起，一道波沿表皮传开，阻尼4让它约一秒后平静。拖动会抓住最近的一片表皮，最多拉出90 pt并带橡皮筋阻尼；松手后弹回并晃动，伴随柔和触感。高光和一双眼睛随形变移动，压扁时眼睛眯起。软、弹、有生命感。"
        ),
        implementation: L(
            "A reference-type model integrates 28 perimeter masses in 1/240 s substeps: structural and two ranks of bending springs, a rest-shape spring, viscous damping and a pressure force of (rest area − area) along each edge normal. A TimelineView feeds a Canvas that fills a closed Catmull-Rom curve through the points; DragGesture adds a Gaussian-weighted pull.",
            "引用类型模型以 1/240 秒子步长积分 28 个轮廓质点：结构弹簧与抗弯弹簧、指向静止形状的弹簧、粘性阻尼，以及沿每条边法线、正比于（静止面积 − 当前面积）的压力。TimelineView 驱动 Canvas 填充经过各质点的闭合 Catmull-Rom 曲线；DragGesture 施加按高斯加权的拉力。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "Path.addCurve", "DragGesture", "mass-spring system"],
        tags: ["soft body", "jelly", "mass-spring", "squish", "wobble", "pressure", "软体", "果冻", "质点弹簧", "形变", "抖动"],
        params: [
            .slider("stiffness", L("Stiffness", "刚度"), 40...300, default: 120, step: 5, decimals: 0),
            .slider("damping", L("Damping", "阻尼"), 1...12, default: 4, decimals: 1),
            .slider("pressure", L("Internal pressure", "内压"), 0...2, default: 1),
        ]
    ) { ctx in
        SoftBodyDemo(ctx: ctx)
    }
}

private enum Jelly {
    static let size = CGSize(width: 300, height: 280)
    static let centre = CGPoint(x: 150, y: 160)
    static let count = 28
    static let plateY: CGFloat = 230
}

private final class SoftBodyModel {
    let rest: [CGPoint]
    private let anchor: [CGFloat]
    private let restLength1: [CGFloat]
    private let restLength2: [CGFloat]
    private let restLength3: [CGFloat]
    private let restArea: CGFloat
    private(set) var points: [CGPoint]
    private var velocities: [CGVector]
    private var grabWeights: [CGFloat]?
    private var grabOrigins: [CGPoint] = []
    private var grabDelta: CGSize = .zero
    private var clock = GestureStepClock()

    init() {
        var shape: [CGPoint] = []
        var hold: [CGFloat] = []
        for index in 0..<Jelly.count {
            let angle: Double = Double(index) / Double(Jelly.count) * 2 * .pi - .pi / 2
            let c: Double = cos(angle)
            let s: Double = sin(angle)
            let x: Double = 86 * (c < 0 ? -1 : 1) * pow(abs(c), 0.8)
            let y: Double = s < 0 ? -72 * pow(abs(s), 0.8) : 66 * pow(abs(s), 0.42)
            shape.append(CGPoint(x: Jelly.centre.x + CGFloat(x), y: Jelly.centre.y + CGFloat(y)))
            hold.append(1 + 7 * CGFloat(GestureMath.smoothstep(0.45, 0.95, s)))
        }
        rest = shape
        anchor = hold
        points = shape
        velocities = Array(repeating: .zero, count: shape.count)
        let n: Int = shape.count
        restLength1 = (0..<n).map { GestureMath.distance(shape[$0], shape[($0 + 1) % n]) }
        restLength2 = (0..<n).map { GestureMath.distance(shape[$0], shape[($0 + 2) % n]) }
        restLength3 = (0..<n).map { GestureMath.distance(shape[$0], shape[($0 + 3) % n]) }
        restArea = SoftBodyModel.area(shape)
    }

    var isHeld: Bool { grabWeights != nil }

    var isSettled: Bool {
        guard grabWeights == nil else { return false }
        for index in points.indices {
            if GestureMath.length(velocities[index]) > 1.5 || GestureMath.distance(points[index], rest[index]) > 0.4 { return false }
        }
        return true
    }

    var centroid: CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for point in points {
            x += point.x
            y += point.y
        }
        return CGPoint(x: x / CGFloat(points.count), y: y / CGFloat(points.count))
    }

    /// Current height of the body relative to its rest height.
    var squash: CGFloat {
        let top: CGFloat = points.map(\.y).min() ?? 0
        let restTop: CGFloat = rest.map(\.y).min() ?? 0
        return ((Jelly.plateY - top) / max(Jelly.plateY - restTop, 1)).clamped(to: 0.5...1.5)
    }

    private static func area(_ polygon: [CGPoint]) -> CGFloat {
        var sum: CGFloat = 0
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    private func weights(around point: CGPoint) -> [CGFloat] {
        let sigma: CGFloat = 46
        let raw: [CGFloat] = points.map { p in
            let d: CGFloat = GestureMath.distance(p, point)
            return CGFloat(exp(-Double(d * d) / Double(2 * sigma * sigma)))
        }
        let peak: CGFloat = max(raw.max() ?? 1, 0.0001)
        return raw.map { $0 / peak }
    }

    func grab(at point: CGPoint) {
        grabWeights = weights(around: point)
        grabOrigins = points
        grabDelta = .zero
    }

    func pull(by translation: CGSize) {
        let length: CGFloat = (translation.width * translation.width + translation.height * translation.height).squareRoot()
        guard length > 0 else {
            grabDelta = .zero
            return
        }
        let limited: CGFloat = rubberBand(length, limit: 90, coefficient: 0.9)
        grabDelta = CGSize(width: translation.width / length * limited, height: translation.height / length * limited)
    }

    func release() {
        grabWeights = nil
    }

    /// A push toward the centre around `point`.
    func poke(at point: CGPoint, strength: CGFloat = 420) {
        let w = weights(around: point)
        let c = centroid
        for index in points.indices {
            let dx: CGFloat = c.x - points[index].x
            let dy: CGFloat = c.y - points[index].y
            let d: CGFloat = max((dx * dx + dy * dy).squareRoot(), 1)
            velocities[index].dx += dx / d * strength * w[index]
            velocities[index].dy += dy / d * strength * w[index]
        }
    }

    func step(to date: Date, stiffness: CGFloat, damping: CGFloat, pressure: CGFloat) {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return }
        let substeps: Int = max(Int((dt * 240).rounded(.up)), 1)
        let h: CGFloat = CGFloat(dt) / CGFloat(substeps)
        for _ in 0..<substeps {
            integrate(h: h, stiffness: stiffness, damping: damping, pressure: pressure)
        }
    }

    private func integrate(h: CGFloat, stiffness: CGFloat, damping: CGFloat, pressure: CGFloat) {
        let n: Int = points.count
        var forces: [CGVector] = Array(repeating: .zero, count: n)

        for index in 0..<n {
            // Home spring: holds the shape (and glues the base to the plate).
            forces[index].dx += (rest[index].x - points[index].x) * stiffness * anchor[index]
            forces[index].dy += (rest[index].y - points[index].y) * stiffness * anchor[index]
            forces[index].dx -= velocities[index].dx * damping
            forces[index].dy -= velocities[index].dy * damping
            spring(index, (index + 1) % n, rest: restLength1[index], k: 900, into: &forces)
            spring(index, (index + 2) % n, rest: restLength2[index], k: 520, into: &forces)
            spring(index, (index + 3) % n, rest: restLength3[index], k: 260, into: &forces)
        }

        // Pressure keeps the area: a dent on one side pushes the rest of the skin outward.
        let loss: CGFloat = (restArea - SoftBodyModel.area(points)) / restArea
        let push: CGFloat = loss * 640 * pressure
        for index in 0..<n {
            let next: Int = (index + 1) % n
            let ex: CGFloat = points[next].x - points[index].x
            let ey: CGFloat = points[next].y - points[index].y
            // Points run clockwise on screen, so (ey, −ex) points outward.
            forces[index].dx += ey * push / 2
            forces[index].dy += -ex * push / 2
            forces[next].dx += ey * push / 2
            forces[next].dy += -ex * push / 2
        }

        if let weights = grabWeights {
            for index in 0..<n where weights[index] > 0.02 {
                let tx: CGFloat = grabOrigins[index].x + grabDelta.width
                let ty: CGFloat = grabOrigins[index].y + grabDelta.height
                forces[index].dx += (tx - points[index].x) * 1500 * weights[index]
                forces[index].dy += (ty - points[index].y) * 1500 * weights[index]
                forces[index].dx -= velocities[index].dx * 18 * weights[index]
                forces[index].dy -= velocities[index].dy * 18 * weights[index]
            }
        }

        for index in 0..<n {
            velocities[index].dx += forces[index].dx * h
            velocities[index].dy += forces[index].dy * h
            points[index].x += velocities[index].dx * h
            points[index].y += velocities[index].dy * h
            // Nothing sinks through the plate.
            if points[index].y > Jelly.plateY {
                points[index].y = Jelly.plateY
                if velocities[index].dy > 0 { velocities[index].dy = 0 }
            }
        }
    }

    private func spring(_ a: Int, _ b: Int, rest length: CGFloat, k: CGFloat, into forces: inout [CGVector]) {
        let dx: CGFloat = points[b].x - points[a].x
        let dy: CGFloat = points[b].y - points[a].y
        let d: CGFloat = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let f: CGFloat = (d - length) * k
        forces[a].dx += dx / d * f
        forces[a].dy += dy / d * f
        forces[b].dx -= dx / d * f
        forces[b].dy -= dy / d * f
    }
}

private struct SoftBodyDemo: View {
    let ctx: DemoContext
    @State private var model = SoftBodyModel()
    @State private var held = false
    @State private var wake = 0
    @State private var autoStep = 0
    /// Resets on system cancellation too, so a stolen touch never leaves the jelly stretched.
    @GestureState private var pressing = false

    var body: some View {
        let stiffness = ctx.cg("stiffness")
        let damping = ctx.cg("damping")
        let pressure = ctx.cg("pressure")
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let _ = model.step(to: date, stiffness: stiffness, damping: damping, pressure: pressure)
                SoftBodyCanvas(model: model, surprised: held, tick: date)
            }
            .frame(width: Jelly.size.width, height: Jelly.size.height)
            .background(Palette.elevated, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            .contentShape(shape)
            .gesture(drag)

            DemoHint(text: L("Poke the jelly, or pull it", "戳一戳果冻，或者拉一拉"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7, delay: 0.5) { autoPoke() }
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { letGo(tapAt: nil) }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held {
                    held = true
                    model.grab(at: value.startLocation)
                    Haptics.tap(.light)
                }
                model.pull(by: value.translation)
                wake += 1
            }
            .onEnded { value in
                let moved: CGFloat = abs(value.translation.width) + abs(value.translation.height)
                letGo(tapAt: moved < 10 ? value.location : nil)
            }
    }

    private func letGo(tapAt: CGPoint?) {
        guard held else { return }
        held = false
        model.release()
        if let tapAt { poke(at: tapAt) }
        Haptics.tap(.soft)
        wake += 1
    }

    private func poke(at point: CGPoint) {
        model.poke(at: point)
        wake += 1
    }

    /// The same poke a tap delivers, walking around the upper skin.
    private func autoPoke() {
        guard !held else { return }
        autoStep += 1
        let spots: [Int] = [3, 25, 0, 6, 22]
        poke(at: model.rest[spots[autoStep % spots.count]])
    }
}

private struct SoftBodyCanvas: View {
    let model: SoftBodyModel
    let surprised: Bool
    /// Changes every frame so SwiftUI redraws (the model is a reference and compares equal).
    let tick: Date

    var body: some View {
        Canvas { context, _ in
            drawPlate(&context)
            let outline = SoftBodyCanvas.smooth(SoftBodyCanvas.relaxed(model.points))
            drawBody(&context, outline: outline)
            drawGloss(&context)
            drawFace(&context)
        }
    }

    /// One Laplacian pass, so a sharp local dent still draws as a rounded skin.
    private static func relaxed(_ points: [CGPoint]) -> [CGPoint] {
        let n: Int = points.count
        guard n > 2 else { return points }
        return (0..<n).map { index in
            let a = points[(index + n - 1) % n]
            let b = points[index]
            let c = points[(index + 1) % n]
            return CGPoint(x: a.x * 0.25 + b.x * 0.5 + c.x * 0.25, y: a.y * 0.25 + b.y * 0.5 + c.y * 0.25)
        }
    }

    /// Closed Catmull-Rom spline through the points.
    private static func smooth(_ points: [CGPoint]) -> Path {
        var path = Path()
        let n: Int = points.count
        guard n > 2 else { return path }
        path.move(to: points[0])
        for index in 0..<n {
            let p0 = points[(index + n - 1) % n]
            let p1 = points[index]
            let p2 = points[(index + 1) % n]
            let p3 = points[(index + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    private func drawPlate(_ context: inout GraphicsContext) {
        let xs: [CGFloat] = model.points.map(\.x)
        let left: CGFloat = xs.min() ?? 60
        let right: CGFloat = xs.max() ?? 240
        let plate = CGRect(x: 30, y: Jelly.plateY - 8, width: Jelly.size.width - 60, height: 24)
        context.fill(Path(ellipseIn: plate), with: .color(.primary.opacity(0.07)))
        context.stroke(Path(ellipseIn: plate), with: .color(.primary.opacity(0.14)), lineWidth: 1)
        var shadow = context
        shadow.addFilter(.blur(radius: 5))
        shadow.fill(
            Path(ellipseIn: CGRect(x: left - 4, y: Jelly.plateY - 5, width: right - left + 8, height: 14)),
            with: .color(.black.opacity(0.22))
        )
    }

    private func drawBody(_ context: inout GraphicsContext, outline: Path) {
        let c = model.centroid
        context.fill(
            outline,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFF9CC2), Palette.pink, Color(hex: 0xD2317A)]),
                startPoint: CGPoint(x: c.x, y: c.y - 80),
                endPoint: CGPoint(x: c.x, y: Jelly.plateY)
            )
        )
        // A lighter core reads as translucent gel.
        var inner = context
        inner.clip(to: outline)
        inner.addFilter(.blur(radius: 14))
        inner.fill(
            Path(ellipseIn: CGRect(x: c.x - 46, y: c.y - 44, width: 92, height: 70)),
            with: .color(.white.opacity(0.22))
        )
        context.stroke(outline, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
    }

    private func drawGloss(_ context: inout GraphicsContext) {
        // A highlight that follows the upper-left skin, pulled in toward the centre.
        let c = model.centroid
        let n: Int = model.points.count
        let indices: [Int] = [n - 6, n - 5, n - 4, n - 3]
        var gloss = Path()
        for (order, index) in indices.enumerated() {
            let p = model.points[index]
            let q = CGPoint(x: c.x + (p.x - c.x) * 0.8, y: c.y + (p.y - c.y) * 0.8)
            if order == 0 { gloss.move(to: q) } else { gloss.addLine(to: q) }
        }
        var layer = context
        layer.addFilter(.blur(radius: 1.2))
        layer.stroke(gloss, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        let top = model.points[n - 2]
        let dot = CGPoint(x: c.x + (top.x - c.x) * 0.78, y: c.y + (top.y - c.y) * 0.78)
        layer.fill(Path(ellipseIn: CGRect(x: dot.x - 3, y: dot.y - 3, width: 6, height: 6)), with: .color(.white.opacity(0.6)))
    }

    private func drawFace(_ context: inout GraphicsContext) {
        let c = model.centroid
        let shift = CGPoint(x: c.x - Jelly.centre.x - 0, y: c.y - Jelly.centre.y)
        let face = CGPoint(x: Jelly.centre.x + shift.x * 1.6, y: Jelly.centre.y + 2 + shift.y * 1.6)
        let squint: CGFloat = model.squash.clamped(to: 0.55...1.15)
        let ink = Color(hex: 0x5A1034)
        for side in [-1.0, 1.0] {
            let eye = CGPoint(x: face.x + CGFloat(side) * 17, y: face.y - 6)
            let w: CGFloat = surprised ? 9 : 8
            let hgt: CGFloat = (surprised ? 11 : 10) * squint
            context.fill(Path(ellipseIn: CGRect(x: eye.x - w / 2, y: eye.y - hgt / 2, width: w, height: hgt)), with: .color(ink))
            context.fill(Path(ellipseIn: CGRect(x: eye.x - 0.5, y: eye.y - hgt / 2 + 1, width: 3, height: 3)), with: .color(.white.opacity(0.9)))
        }
        if surprised {
            context.fill(Path(ellipseIn: CGRect(x: face.x - 4, y: face.y + 6, width: 8, height: 9)), with: .color(ink))
        } else {
            var smile = Path()
            smile.move(to: CGPoint(x: face.x - 7, y: face.y + 8))
            smile.addQuadCurve(to: CGPoint(x: face.x + 7, y: face.y + 8), control: CGPoint(x: face.x, y: face.y + 15))
            context.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }
}
