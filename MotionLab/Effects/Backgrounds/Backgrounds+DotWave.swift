import SwiftUI

extension Effect {
    static let backgroundsDotWave = Effect(
        id: "backgrounds.dot-wave",
        category: .backgrounds,
        interaction: .tap,
        name: L("Dot Wave Terrain", "点阵波浪地形"),
        summary: L(
            "A dot matrix laid out as a floor in perspective: slow swells roll through it, and a tap drops a ripple that lifts and lights the dots.",
            "一张以透视铺成地面的点阵：缓慢的涌浪穿行其间，点击落下一圈涟漪，把点托起并点亮。"
        ),
        prompt: L(
            "A dark indigo void with a horizon glow. A 46 × 34 dot matrix lies flat like a floor and recedes in perspective, rows packing tighter, dots shrinking and dimming toward the horizon. Its height field is two crossing sine swells travelling at different speeds; each dot is lifted on screen in proportion to its height (34 pt per unit in the front row), grows from about 1.5 to 6.5 pt across and shifts from dim indigo through cyan to white at the crests, with the brightest dots blooming. Tapping the floor drops a ripple exactly where the finger lands on the plane: a ring wave packet expanding at 0.55 plane-units/s whose crest has a Gaussian profile, trails one trough, and decays as e^(−1.1·t); ripples superimpose with the swell. A light haptic marks each drop. Calm, spatial, like sonar over a dark sea.",
            "深靛色的虚空，地平线处有一抹微光。46 × 34 的点阵像地面一样平铺并沿透视退向远方，越靠近地平线行距越密、点越小越暗。高度场是两道以不同速度交叉行进的正弦涌浪；每个点按自身高度被托起（最前排每单位高度 34pt），直径从约 1.5pt 长到 6.5pt，颜色从暗靛经青色变为波峰处的白色。点击地面，涟漪正好落在手指对应的平面位置：一圈以每秒 0.55 个平面单位扩散的环形波包，波峰呈高斯剖面、后面拖一道波谷，按 e^(−1.1·t) 衰减，并与涌浪叠加。点击伴随轻触感。沉静，像黑暗海面上的声呐。"
        ),
        implementation: L(
            "A Canvas projects each grid node (u, v) with s = 1/(1 + k·v), evaluates swell + ripple heights analytically, and batches dots into six brightness Paths drawn far-to-near; taps are unprojected through the inverse mapping to plane coordinates.",
            "Canvas 用 s = 1/(1 + k·v) 投影每个网格点 (u, v)，解析计算涌浪与涟漪的高度，再把点按亮度分入六条 Path、由远及近绘制；点击位置通过逆映射还原为平面坐标。"
        ),
        apis: ["Canvas", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "GraphicsContext.drawLayer", "Haptics"],
        tags: ["dots", "wave", "perspective", "ripple", "点阵", "波浪", "透视", "涟漪"],
        params: [
            .slider("height", L("Wave height", "浪高"), 6...60, default: 34, decimals: 0, unit: "pt"),
            .slider("speed", L("Swell speed", "涌浪速度"), 0.2...3.0, default: 1.0, unit: "×"),
            .slider("tilt", L("Perspective", "透视强度"), 0.2...3.0, default: 1.6),
            .slider("ripple", L("Ripple speed", "涟漪速度"), 0.2...1.2, default: 0.55),
        ]
    ) { ctx in
        DotWaveDemo(ctx: ctx)
    }
}

/// Maps the plane (u in −1...1 across, v in 0...1 from near to far) to the stage and back.
private struct DotWaveProjection {
    let size: CGSize
    let tilt: CGFloat

    private var far: CGFloat { 1 / (1 + tilt) }
    private var yNear: CGFloat { size.height * 1.0 }
    private var yFar: CGFloat { size.height * (0.07 + 0.17 * min(tilt / 1.6, 1)) }
    private var halfNear: CGFloat { size.width * 0.55 * (1 + tilt) }

    /// 0 at the far edge, 1 in the front row.
    func nearness(_ v: CGFloat) -> CGFloat { (scale(v) - far) / (1 - far) }

    func scale(_ v: CGFloat) -> CGFloat { 1 / (1 + tilt * v) }

    func point(u: CGFloat, v: CGFloat) -> CGPoint {
        let s = scale(v)
        let y = yNear - (yNear - yFar) * (1 - s) / (1 - far)
        return CGPoint(x: size.width / 2 + u * halfNear * s, y: y)
    }

    func plane(_ p: CGPoint) -> CGPoint {
        let q = ((yNear - p.y) / (yNear - yFar)).clamped(to: 0...1)
        let s = max(1 - q * (1 - far), 0.01)
        let v = (1 / s - 1) / tilt
        let u = (p.x - size.width / 2) / (halfNear * s)
        return CGPoint(x: u, y: v)
    }
}

private struct DotRipple {
    let origin: CGPoint
    let born: Double
}

private final class DotWaveModel {
    let clock = BackgroundClock()
    private(set) var ripples: [DotRipple] = []

    func drop(at plane: CGPoint, now: Double) {
        ripples.append(DotRipple(origin: plane, born: now))
        if ripples.count > 6 { ripples.removeFirst(ripples.count - 6) }
    }

    func live(at now: Double) -> [DotRipple] {
        ripples.removeAll { now - $0.born > 5 }
        return ripples
    }
}

private struct DotWaveDemo: View {
    let ctx: DemoContext
    @State private var model = DotWaveModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        let tilt = max(ctx.cg("tilt"), 0.1)
        ZStack {
            LinearGradient(colors: [Color(hex: 0x03040C), Color(hex: 0x0A0C26), Color(hex: 0x060714)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let t = model.clock.advance(to: now, speed: ctx["speed"])
                DotWaveCanvas(
                    t: t, now: now, ripples: model.live(at: now), tilt: tilt,
                    height: ctx.cg("height"), rippleSpeed: max(ctx["ripple"], 0.05), still: ctx.isStill
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.light)
            drop(at: location)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .autoplay(ctx.isPreview, every: 2.2, delay: 0.4) {
            drop(at: CGPoint(x: size.width * CGFloat.random(in: 0.25...0.75), y: size.height * CGFloat.random(in: 0.45...0.85)))
        }
        .backgroundsChipHint(L("Tap the floor to drop a ripple", "点击地面落下一圈涟漪"), ctx)
    }

    private func drop(at location: CGPoint) {
        let projection = DotWaveProjection(size: size, tilt: max(ctx.cg("tilt"), 0.1))
        model.drop(at: projection.plane(location), now: Date().timeIntervalSinceReferenceDate)
    }
}

private struct DotWaveCanvas: View {
    let t: Double
    let now: Double
    let ripples: [DotRipple]
    let tilt: CGFloat
    let height: CGFloat
    let rippleSpeed: Double
    let still: Bool

    private static let levels = 6
    private static let palette: [Color] = [
        Color(hex: 0x4A52B8).opacity(0.75),
        Color(hex: 0x4C6BE6),
        Color(hex: 0x4F8BFF),
        Color(hex: 0x3AC4FF),
        Color(hex: 0x9FE9FF),
        Color.white,
    ]

    var body: some View {
        Canvas { context, size in
            let projection = DotWaveProjection(size: size, tilt: tilt)
            // Horizon glow.
            let horizon = projection.point(u: 0, v: 1)
            let glow = Gradient(colors: [Color(hex: 0x5A6CFF).opacity(0.38), Color(hex: 0x5A6CFF).opacity(0)])
            let reach = size.width * 0.75
            context.drawLayer { layer in
                layer.translateBy(x: horizon.x, y: horizon.y)
                layer.scaleBy(x: 1, y: 0.32)
                layer.fill(
                    Path(ellipseIn: CGRect(x: -reach, y: -reach, width: reach * 2, height: reach * 2)),
                    with: .radialGradient(glow, center: .zero, startRadius: 0, endRadius: reach)
                )
            }

            var bins = [Path](repeating: Path(), count: DotWaveCanvas.levels)
            let cols = 46
            let rows = 34
            // A still shows one ripple in full bloom.
            let active: [(origin: CGPoint, age: Double)] = still
                ? [(CGPoint(x: 0.1, y: 0.3), 0.55)]
                : ripples.map { ($0.origin, now - $0.born) }
            for row in (0..<rows).reversed() {
                let v = CGFloat(row) / CGFloat(rows - 1)
                let s = projection.scale(v)
                for col in 0..<cols {
                    let u = (CGFloat(col) / CGFloat(cols - 1)) * 2 - 1
                    let ud = Double(u)
                    let vd = Double(v)
                    let swellA = 0.45 * sin(ud * 2.2 + vd * 1.6 - t * 1.1)
                    let swellB = 0.3 * sin(vd * 5.0 + ud * 1.0 + t * 0.7)
                    var z = swellA + swellB
                    for ripple in active {
                        let d = Double(hypot((u - ripple.origin.x) * 0.5, v - ripple.origin.y))
                        let x = (d - ripple.age * rippleSpeed) / 0.09
                        guard abs(x) < 4 else { continue }
                        // Gaussian crest followed by one trough.
                        let crest = exp(-x * x) * (1 - 0.9 * max(-x, 0))
                        z += 1.5 * exp(-ripple.age * 1.1) * crest / (1 + d * 2)
                    }
                    let base = projection.point(u: u, v: v)
                    guard base.x > -6, base.x < size.width + 6 else { continue }
                    let lift = CGFloat(z) * height * s
                    let energy = min(max((z + 0.75) / 1.6, 0.2), 1)
                    // Far rows sink into the dark, so depth reads even without the lift.
                    let near = projection.nearness(v)
                    let radius = (0.8 + 1.9 * CGFloat(energy)) * (0.4 + 0.85 * near)
                    let shade = energy * Double(0.55 + 0.45 * near)
                    let level = min(Int(shade * Double(DotWaveCanvas.levels)), DotWaveCanvas.levels - 1)
                    bins[level].addEllipse(in: CGRect(x: base.x - radius, y: base.y - lift - radius, width: radius * 2, height: radius * 2))
                }
            }
            for level in 0..<DotWaveCanvas.levels {
                context.fill(bins[level], with: .color(DotWaveCanvas.palette[level]))
            }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 4))
                layer.blendMode = .plusLighter
                layer.fill(bins[DotWaveCanvas.levels - 1], with: .color(Color(hex: 0x7CD8FF).opacity(0.9)))
                layer.fill(bins[DotWaveCanvas.levels - 2], with: .color(Color(hex: 0x4F8BFF).opacity(0.5)))
            }
        }
    }
}
