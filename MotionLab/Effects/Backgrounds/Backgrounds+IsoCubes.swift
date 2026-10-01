import SwiftUI

extension Effect {
    static let backgroundsIsoCubes = Effect(
        id: "backgrounds.iso-cubes",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Isometric Cube Wave", "等距方块波浪"),
        summary: L(
            "A block of isometric pillars breathing in a wave: tops brighten as they rise, sides stay in shade, and the wave radiates from under your finger.",
            "一整块等距立柱随波起伏：柱顶升高时变亮，侧面始终留在阴影里，波纹从你的手指下方向外扩散。"
        ),
        prompt: L(
            "A 9 × 9 block of square pillars in 2:1-style isometric projection, centred on a deep navy field with a soft glow beneath. Each pillar has three flat faces: a top lit from above, a left face at 62% and a right face at 38% of the top's brightness; the bases stay fixed while the tops travel. Height follows a radial wave from a focus point, sin(0.9·d − 2.4·t) with d the distance in cells, up to ±26 pt, plus a gentle bump over the focus. Top colour tracks height through a ramp from indigo through blue and cyan to pale ice, so crests read as moving bands of light. The focus follows the finger, mapped back onto the grid, on a spring (stiffness 45, damping 0.7), and wanders slowly when untouched. Pillars are painted back to front so nearer ones overlap. Architectural, calm, tactile.",
            "9 × 9 的方柱阵列，以近似 2:1 的等距投影居中于深海军蓝背景上，下方有一片柔光。每根方柱由三个平面构成：受顶光的柱顶，以及亮度为柱顶 62% 的左侧面和 38% 的右侧面；柱底固定，只有柱顶起伏。高度取自以焦点为中心的径向波 sin(0.9·d − 2.4·t)，d 为以格计的距离，幅度最高 ±26pt，焦点上方另有一处平缓隆起。柱顶颜色随高度从靛蓝经蓝、青变到淡冰色，波峰成为游走的光带。焦点由手指位置反算回网格，以弹簧（刚度 45、阻尼 0.7）跟随，无触摸时缓慢游走。方柱由远及近绘制。沉静。"
        ),
        implementation: L(
            "A Canvas walks the grid by diagonals (i + j) so pillars are painted back to front, projects each with x = (i − j)·a, y = (i + j)·b − z, and fills three quads per pillar with colours derived from one height-driven ramp; the touch is unprojected with the inverse mapping at z = 0.",
            "Canvas 按对角线 (i + j) 遍历网格，保证由远及近绘制；每根方柱用 x = (i − j)·a、y = (i + j)·b − z 投影，并以同一条随高度变化的色带派生出的颜色填充三个四边形；触点通过 z = 0 时的逆映射反算回网格。"
        ),
        apis: ["Canvas", "Path", "TimelineView(.animation)", "DragGesture", "GraphicsContext.fill(_:with:)"],
        tags: ["isometric", "cubes", "wave", "3D", "等距", "方块", "立方体", "波浪"],
        params: [
            .slider("grid", L("Grid size", "网格数量"), 5...13, default: 9, step: 1, decimals: 0),
            .slider("height", L("Wave height", "浪高"), 6...48, default: 26, decimals: 0, unit: "pt"),
            .slider("speed", L("Speed", "速度"), 0.2...3.0, default: 1.0, unit: "×"),
            .choice("wave", L("Wave", "波形"), [L("Ripple", "涟漪"), L("Diagonal", "斜浪"), L("Noise", "噪声")]),
        ]
    ) { ctx in
        IsoCubesDemo(ctx: ctx)
    }
}

private struct IsoProjection {
    let size: CGSize
    let n: Int
    let amplitude: CGFloat

    var a: CGFloat { min(size.width, size.height * 1.05) * 0.46 / CGFloat(n) }
    var b: CGFloat { a * 0.56 }
    /// Pillar height at rest.
    var depth: CGFloat { amplitude + 16 }
    private var top: CGFloat { (size.height - (2 * CGFloat(n) * b + depth)) / 2 + b + amplitude * 0.2 }

    /// Centre of the top face of cell (i, j) lifted by z.
    func point(i: CGFloat, j: CGFloat, z: CGFloat) -> CGPoint {
        CGPoint(x: size.width / 2 + (i - j) * a, y: top + (i + j) * b - z)
    }

    /// Grid coordinates under a stage point, assuming z = 0.
    func cell(at p: CGPoint) -> CGPoint {
        let u = (p.x - size.width / 2) / a
        let v = (p.y - top) / b
        return CGPoint(x: (u + v) / 2, y: (v - u) / 2)
    }
}

private final class IsoModel {
    let clock = BackgroundClock()
    let pointer = BackgroundPointer()
}

private struct IsoCubesDemo: View {
    let ctx: DemoContext
    @State private var model = IsoModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x070A1E), Color(hex: 0x0E1438), Color(hex: 0x060817)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.clock.advance(to: now, speed: ctx["speed"])
                    let n = max(ctx.int("grid"), 2)
                    let projection = IsoProjection(size: size, n: n, amplitude: ctx.cg("height"))
                    let mid = CGFloat(n - 1) / 2
                    let idle = projection.point(
                        i: mid + mid * 0.6 * CGFloat(sin(t * 0.23)), j: mid + mid * 0.6 * CGFloat(sin(t * 0.31 + 1.4)), z: 0
                    )
                    let finger = model.pointer.step(now: now, idle: idle, stiffness: 45, damping: 0.7, frozen: ctx.isStill)
                    IsoPainter.draw(
                        &context, projection: projection, t: t, focus: projection.cell(at: finger), wave: ctx.int("wave"),
                        bump: model.pointer.strength(idle: 0.5)
                    )
                }
            }
        }
        .backgroundsTouch { location in
            if !model.pointer.userTouched { Haptics.tap(.soft) }
            model.pointer.userTouched = true
            model.pointer.touch = location
        } onEnded: {
            model.pointer.touch = nil
        }
        .backgroundsHint(L("Swipe sideways to move the wave source", "横向滑动移动波源"), ctx)
    }
}

private enum IsoPainter {
    static let ramp: [BackgroundRGB] = [.init(hex: 0x2B2F77), .init(hex: 0x4F7CFF), .init(hex: 0x3AC4FF), .init(hex: 0xCFF6FF)]

    static func draw(_ context: inout GraphicsContext, projection: IsoProjection, t: Double, focus: CGPoint, wave: Int, bump: Double) {
        let n = projection.n
        let a = projection.a
        let b = projection.b
        let amp = projection.amplitude

        // Light pooling under the block.
        let floor = projection.point(i: CGFloat(n - 1) / 2, j: CGFloat(n - 1) / 2, z: -projection.depth)
        context.backgroundsGlow(at: floor, radius: a * CGFloat(n) * 1.5, color: Color(hex: 0x4F7CFF).opacity(0.3), squash: 0.5)

        for sum in 0...(2 * n - 2) {
            for i in max(0, sum - (n - 1))...min(n - 1, sum) {
                let j = sum - i
                let dx = Double(i) - Double(focus.x)
                let dy = Double(j) - Double(focus.y)
                let d = (dx * dx + dy * dy).squareRoot()
                var h: Double
                switch wave {
                case 1:
                    h = sin(Double(i + j) * 0.55 - t * 2.2) * 0.8 + 0.2 * sin(Double(i - j) * 0.7 + t * 1.1)
                case 2:
                    h = BackgroundMath.valueNoise(Double(i) * 0.36 + t * 0.35, Double(j) * 0.36 - t * 0.22) * 2.2 - 1.1
                default:
                    h = sin(d * 0.9 - t * 2.4) * (0.55 + 0.45 / (1 + d * 0.15))
                }
                // A bump rides over the focus in every mode.
                h = (h + 0.45 * bump * exp(-d * d / 6)).clamped(to: -1...1.5)
                let z = CGFloat(h) * amp
                let c = projection.point(i: CGFloat(i), j: CGFloat(j), z: z)
                let base = projection.point(i: CGFloat(i), j: CGFloat(j), z: -projection.depth)

                let color = BackgroundRGB.ramp(ramp, (h + 1) / 2.3)
                var left = Path()
                left.move(to: CGPoint(x: c.x - a, y: c.y))
                left.addLine(to: CGPoint(x: c.x, y: c.y + b))
                left.addLine(to: CGPoint(x: base.x, y: base.y + b))
                left.addLine(to: CGPoint(x: base.x - a, y: base.y))
                left.closeSubpath()
                var right = Path()
                right.move(to: CGPoint(x: c.x + a, y: c.y))
                right.addLine(to: CGPoint(x: c.x, y: c.y + b))
                right.addLine(to: CGPoint(x: base.x, y: base.y + b))
                right.addLine(to: CGPoint(x: base.x + a, y: base.y))
                right.closeSubpath()
                var top = Path()
                top.move(to: CGPoint(x: c.x, y: c.y - b))
                top.addLine(to: CGPoint(x: c.x + a, y: c.y))
                top.addLine(to: CGPoint(x: c.x, y: c.y + b))
                top.addLine(to: CGPoint(x: c.x - a, y: c.y))
                top.closeSubpath()

                context.fill(left, with: .color(color.scaled(0.62).color()))
                context.fill(right, with: .color(color.scaled(0.38).color()))
                context.fill(top, with: .color(color.color()))
                context.stroke(top, with: .color(.white.opacity(0.16)), lineWidth: 0.6)
            }
        }
    }
}
