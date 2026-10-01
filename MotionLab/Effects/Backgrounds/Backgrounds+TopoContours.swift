import SwiftUI

extension Effect {
    static let backgroundsTopoContours = Effect(
        id: "backgrounds.topo-contours",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Living Contours", "流动等高线"),
        summary: L(
            "A topographic map whose terrain never sits still: contour lines merge, split and re-form, and your finger raises a new summit.",
            "一张地形永不静止的等高线图：等高线不断合并、分裂、重组，手指按下处会隆起一座新的山峰。"
        ),
        prompt: L(
            "A dark map sheet covered with thin contour lines of a slowly changing landscape. The terrain is the sum of seven broad Gaussian hills and hollows whose centres drift on independent sine paths with 40–110 s periods, so rings of lines swell, pinch into saddles, split and merge without ever repeating. 13 elevation levels are traced; every fourth is an index contour drawn 1.8 pt thick against 0.9 pt, and colour climbs with altitude from deep teal through mint to warm sand. Faint tinted glows sit under the summits and the highest one carries a small triangle and an elevation label. Touching the map raises a new peak under the finger on an underdamped spring (stiffness 40, damping 0.5): concentric rings bloom outward, overshoot, settle, and sink back on release. A soft haptic marks the touch. Quiet, cartographic, endlessly evolving.",
            "深色的地图纸面上布满纤细的等高线，描绘一片缓慢变化的地貌。地形由七个宽阔的高斯山丘与洼地叠加而成，它们的中心各自沿周期 40–110 秒的正弦轨迹漂移，于是一圈圈等高线不断鼓起、收束成鞍部、分裂又合并。共描出 13 级高程；每隔三条是一条计曲线，线宽 1.8pt（其余 0.9pt），颜色随海拔由深青经薄荷绿过渡到暖沙色。山顶下有淡淡的色晕，最高峰标着小三角与高程数字。触摸地图会在指下由欠阻尼弹簧（刚度 40、阻尼 0.5）托起一座新峰：同心环向外绽开、过冲、稳定，松手后沉回。并有轻柔触感。"
        ),
        implementation: L(
            "The height field is sampled on a 6 pt grid each frame and contoured with marching squares (linear interpolation on cell edges); each level's segments go into its own Path and are stroked once, so a frame is about 13 strokes.",
            "每帧在 6pt 网格上采样高度场，并用 marching squares（单元边上线性插值）提取等值线；每一级的线段汇入各自的 Path 后一次描边，一帧大约 13 次描边。"
        ),
        apis: ["Canvas", "Path", "TimelineView(.animation)", "GraphicsContext.resolve(Text)", "DragGesture", "Haptics"],
        tags: ["contours", "topographic", "isolines", "map", "等高线", "地形图", "等值线", "地图"],
        params: [
            .slider("levels", L("Contour levels", "等高线级数"), 6...22, default: 13, step: 1, decimals: 0),
            .slider("speed", L("Drift speed", "演变速度"), 0...4, default: 1.0, unit: "×"),
            .slider("scale", L("Hill size", "山体大小"), 0.6...1.6, default: 1.0, unit: "×"),
            .choice("palette", L("Sheet", "图纸"), [L("Survey", "测绘"), L("Desert", "沙漠"), L("Blueprint", "蓝图")]),
        ]
    ) { ctx in
        TopoContoursDemo(ctx: ctx)
    }
}

private struct TopoPalette {
    let ground: [Color]
    let low: (Double, Double, Double)
    let mid: (Double, Double, Double)
    let high: (Double, Double, Double)

    func color(_ u: Double) -> Color {
        let (a, b, k) = u < 0.5 ? (low, mid, u / 0.5) : (mid, high, (u - 0.5) / 0.5)
        return Color(.sRGB, red: a.0 + (b.0 - a.0) * k, green: a.1 + (b.1 - a.1) * k, blue: a.2 + (b.2 - a.2) * k, opacity: 0.5 + 0.5 * u)
    }

    static let all: [TopoPalette] = [
        TopoPalette(ground: [Color(hex: 0x0A2226), Color(hex: 0x05100F)], low: (0.14, 0.50, 0.55), mid: (0.31, 0.88, 0.71), high: (1.0, 0.84, 0.55)),
        TopoPalette(ground: [Color(hex: 0x2A1A0C), Color(hex: 0x120A05)], low: (0.60, 0.36, 0.18), mid: (1.0, 0.70, 0.30), high: (1.0, 0.95, 0.82)),
        TopoPalette(ground: [Color(hex: 0x0E2250), Color(hex: 0x060E26)], low: (0.24, 0.44, 0.86), mid: (0.60, 0.78, 1.0), high: (1.0, 1.0, 1.0)),
    ]
}

private final class TopoModel {
    let clock = BackgroundClock()
    private var wall = BackgroundClock()
    /// Normalised (0...1) position of the finger, `nil` when released.
    var touch: CGPoint?
    private(set) var peak = CGPoint(x: 0.5, y: 0.5)
    private(set) var lift: Double = 0
    private var liftVelocity: Double = 0
    private var ghostUntil: Double = -1
    private var ghost = CGPoint(x: 0.5, y: 0.5)

    func step(now: Double, speed: Double, frozen: Bool) -> Double {
        let t = clock.advance(to: now, speed: speed)
        guard !frozen else { return t }
        let real = wall.advance(to: now, speed: 1)
        let h = wall.delta
        let active = touch ?? (real < ghostUntil ? ghost : nil)
        if let active { peak = active }
        let wanted = active == nil ? 0.0 : 1.25
        let c = 2 * 40.0.squareRoot() * 0.5
        liftVelocity += (40 * (wanted - lift) - c * liftVelocity) * h
        lift += liftVelocity * h
        return t
    }

    /// Autoplay: an invisible finger presses the map for a moment.
    func poke(at point: CGPoint) {
        ghost = point
        ghostUntil = wall.phase + 1.7
    }
}

private struct TopoContoursDemo: View {
    let ctx: DemoContext
    @State private var model = TopoModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        let palette = TopoPalette.all[min(max(ctx.int("palette"), 0), TopoPalette.all.count - 1)]
        ZStack {
            LinearGradient(colors: palette.ground, startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let t = model.step(now: timeline.date.timeIntervalSinceReferenceDate, speed: ctx["speed"], frozen: ctx.isStill)
                TopoCanvas(
                    t: t, peak: model.peak, lift: model.lift, levels: max(ctx.int("levels"), 2),
                    scale: max(ctx["scale"], 0.2), palette: palette
                )
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .backgroundsTouch { location in
            if model.touch == nil { Haptics.tap(.soft) }
            model.touch = CGPoint(x: location.x / max(size.width, 1), y: location.y / max(size.height, 1))
        } onEnded: {
            model.touch = nil
        }
        .autoplay(ctx.isPreview, every: 4.2, delay: 0.8) {
            model.poke(at: CGPoint(x: CGFloat.random(in: 0.25...0.75), y: CGFloat.random(in: 0.25...0.75)))
        }
        .backgroundsHint(L("Tap or swipe sideways to raise a summit", "点击或横向滑动隆起一座山峰"), ctx)
    }
}

private struct TopoHill {
    let x: Double
    let y: Double
    let amplitude: Double
    let sigma: Double
}

private struct TopoCanvas: View {
    let t: Double
    let peak: CGPoint
    let lift: Double
    let levels: Int
    let scale: Double
    let palette: TopoPalette

    private static let amplitudes: [Double] = [1.0, 0.8, -0.7, 0.62, -0.5, 0.9, 0.55]

    var body: some View {
        Canvas { context, size in
            let aspect = Double(size.height / max(size.width, 1))
            var hills: [TopoHill] = TopoCanvas.amplitudes.enumerated().map { k, amplitude in
                let px = BackgroundMath.tau / (40 + 70 * BackgroundMath.rand(k, 901))
                let py = BackgroundMath.tau / (40 + 70 * BackgroundMath.rand(k, 902))
                return TopoHill(
                    x: 0.5 + 0.44 * sin(t * px + BackgroundMath.rand(k, 903) * BackgroundMath.tau),
                    y: (0.5 + 0.44 * sin(t * py + BackgroundMath.rand(k, 904) * BackgroundMath.tau)) * aspect,
                    amplitude: amplitude,
                    sigma: (0.17 + 0.12 * BackgroundMath.rand(k, 905)) * scale
                )
            }
            if abs(lift) > 0.01 {
                hills.append(TopoHill(x: Double(peak.x), y: Double(peak.y) * aspect, amplitude: lift, sigma: 0.15 * scale))
            }

            // Hypsometric tint under the summits.
            let unit = Double(size.width)
            for hill in hills where hill.amplitude > 0 {
                let r = CGFloat(hill.sigma * unit * 1.5)
                let c = CGPoint(x: hill.x * unit, y: hill.y * unit)
                let tint = Gradient(colors: [palette.color(0.75).opacity(0.16 * min(hill.amplitude, 1)), palette.color(0.75).opacity(0)])
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .radialGradient(tint, center: c, startRadius: 0, endRadius: r))
            }

            let paths = TopoCanvas.contours(size: size, hills: hills, levels: levels)
            for level in 0..<levels {
                let u = levels == 1 ? 0.5 : Double(level) / Double(levels - 1)
                let index = level % 4 == 0
                context.stroke(
                    paths[level], with: .color(palette.color(u).opacity(index ? 1 : 0.72)),
                    style: StrokeStyle(lineWidth: index ? 1.8 : 0.9, lineCap: .round, lineJoin: .round)
                )
            }

            // Summit markers.
            if let top = hills.first {
                TopoCanvas.marker(&context, at: CGPoint(x: top.x * unit, y: top.y * unit), text: "2481", color: palette.color(1), size: size)
            }
            if lift > 0.25 {
                let label = String(Int((lift * 1200).rounded()))
                TopoCanvas.marker(&context, at: CGPoint(x: Double(peak.x) * unit, y: Double(peak.y) * aspect * unit), text: label, color: palette.color(1), size: size)
            }
        }
    }

    private static func marker(_ context: inout GraphicsContext, at point: CGPoint, text: String, color: Color, size: CGSize) {
        guard point.x > 12, point.y > 12, point.x < size.width - 40, point.y < size.height - 12 else { return }
        var triangle = Path()
        triangle.move(to: CGPoint(x: point.x, y: point.y - 4.5))
        triangle.addLine(to: CGPoint(x: point.x + 4.5, y: point.y + 3.5))
        triangle.addLine(to: CGPoint(x: point.x - 4.5, y: point.y + 3.5))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(color))
        let label = Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(color)
        context.draw(context.resolve(label), at: CGPoint(x: point.x + 8, y: point.y), anchor: .leading)
    }

    private static func field(_ x: Double, _ y: Double, hills: [TopoHill]) -> Double {
        var value = 0.0
        for hill in hills {
            let dx = x - hill.x
            let dy = y - hill.y
            value += hill.amplitude * exp(-(dx * dx + dy * dy) / (hill.sigma * hill.sigma))
        }
        return value
    }

    /// Marching squares over a 6 pt grid; returns one Path of line segments per level.
    private static func contours(size: CGSize, hills: [TopoHill], levels: Int) -> [Path] {
        let step: CGFloat = 6
        let cols = Int((size.width / step).rounded(.up))
        let rows = Int((size.height / step).rounded(.up))
        let unit = Double(size.width)
        var values = [Double](repeating: 0, count: (cols + 1) * (rows + 1))
        for row in 0...rows {
            for col in 0...cols {
                values[row * (cols + 1) + col] = field(Double(CGFloat(col) * step) / unit, Double(CGFloat(row) * step) / unit, hills: hills)
            }
        }
        let lowest = -0.75
        let spacing = 2.3 / Double(levels)
        var paths = [Path](repeating: Path(), count: levels)

        func cross(_ a: CGPoint, _ b: CGPoint, _ va: Double, _ vb: Double, _ level: Double) -> CGPoint {
            let k = CGFloat((level - va) / (vb - va))
            return CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
        }

        for row in 0..<rows {
            for col in 0..<cols {
                let v0 = values[row * (cols + 1) + col]
                let v1 = values[row * (cols + 1) + col + 1]
                let v2 = values[(row + 1) * (cols + 1) + col + 1]
                let v3 = values[(row + 1) * (cols + 1) + col]
                let low = min(min(v0, v1), min(v2, v3))
                let high = max(max(v0, v1), max(v2, v3))
                let first = max(Int(((low - lowest) / spacing - 0.5).rounded(.up)), 0)
                let last = min(Int(((high - lowest) / spacing - 0.5).rounded(.down)), levels - 1)
                guard first <= last else { continue }
                let p0 = CGPoint(x: CGFloat(col) * step, y: CGFloat(row) * step)
                let p1 = CGPoint(x: p0.x + step, y: p0.y)
                let p2 = CGPoint(x: p0.x + step, y: p0.y + step)
                let p3 = CGPoint(x: p0.x, y: p0.y + step)
                for level in first...last {
                    let value = lowest + (Double(level) + 0.5) * spacing
                    // Up to four edge crossings, kept on the stack.
                    var points = (CGPoint.zero, CGPoint.zero, CGPoint.zero, CGPoint.zero)
                    var count = 0
                    func add(_ p: CGPoint) {
                        switch count {
                        case 0: points.0 = p
                        case 1: points.1 = p
                        case 2: points.2 = p
                        default: points.3 = p
                        }
                        count += 1
                    }
                    if (v0 > value) != (v1 > value) { add(cross(p0, p1, v0, v1, value)) }
                    if (v1 > value) != (v2 > value) { add(cross(p1, p2, v1, v2, value)) }
                    if (v2 > value) != (v3 > value) { add(cross(p2, p3, v2, v3, value)) }
                    if (v3 > value) != (v0 > value) { add(cross(p3, p0, v3, v0, value)) }
                    guard count >= 2 else { continue }
                    paths[level].move(to: points.0)
                    paths[level].addLine(to: points.1)
                    if count == 4 {
                        paths[level].move(to: points.2)
                        paths[level].addLine(to: points.3)
                    }
                }
            }
        }
        return paths
    }
}
