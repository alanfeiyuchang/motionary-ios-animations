import SwiftUI

extension Effect {
    static let loadingRippleDrop = Effect(
        id: "loading.ripple-drop",
        category: .loading,
        interaction: .loop,
        name: L("Ripple Drop", "水滴涟漪"),
        summary: L("A drop swells, falls, punches the surface and sends rings sliding out in perspective while a bead leaps back up.", "水滴鼓起、坠落、击中水面，一圈圈涟漪按透视向外滑开，一颗小水珠回弹跃起。"),
        prompt: L(
            "A still pool drawn as a 260 pt wide ellipse squashed to 32% for perspective. Every 1.8 s a drop swells under a small nozzle for 30% of the cycle, pinches off and falls 140 pt under gravity, stretching to 190% of its height and thinning as it speeds up; a shadow on the water darkens beneath it. On impact a pale flash spreads from the point, three rings leave 160 ms apart and decelerate out to 118 pt over 1.9 s, each thinning from 3.2 pt to a hairline and fading, so the rings of the previous drop are still dying as the next one lands. A 10 pt bead leaps 46 pt back up and two smaller ones arc sideways. In the detail view a tap adds a ripple where the finger lands. Quiet, rhythmic, liquid.",
            "一池静水画成 260 pt 宽、按透视压扁到 32% 的椭圆。每 1.8 秒，一颗水滴用周期的 30% 在小喷嘴下鼓起，随后脱落，在重力下坠落 140 pt，越落越快，拉长到原高度的 190% 并变细；水面上它的影子越来越深。击中水面时落点泛起浅色闪光，三圈涟漪相隔 160 毫秒出发，在 1.9 秒内减速扩散到 118 pt，线宽从 3.2 pt 细到发丝并淡出，所以上一滴的涟漪未散，下一滴已落下。一颗 10 pt 的水珠向上回弹 46 pt，另两颗更小的向两侧划出弧线。在详情页点击水面，落点也会荡开涟漪。安静、有节奏、水润。"
        ),
        implementation: L(
            "TimelineView + Canvas. The cycle phase places the drop (growth, then y = ½gt²); every impact, timed or tapped, is an age in seconds, and each ring's radius, width and opacity are eased functions of that age, drawn as ellipses clipped to the pool.",
            "TimelineView 加 Canvas。周期相位决定水滴位置（先鼓起，再按 y = ½gt² 下落）；每一次撞击，无论定时还是点击，都只是一个以秒计的“年龄”，每圈涟漪的半径、线宽与不透明度是该年龄的缓动函数，画成裁切在水池内的椭圆。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.clip(to:)", "SpatialTapGesture", "Path(ellipseIn:)"],
        tags: ["ripple", "water", "drop", "rings", "涟漪", "水滴", "水面", "波纹"],
        params: [
            .slider("interval", L("Drop interval", "滴落间隔"), 1...3.5, default: 1.8, decimals: 1, unit: "s"),
            .slider("rings", L("Rings per drop", "每滴涟漪数"), 1...5, default: 3, step: 1, decimals: 0),
            .slider("tilt", L("Perspective", "透视压扁"), 0.18...0.5, default: 0.32),
            .toggle("rebound", L("Rebound beads", "回弹水珠"), default: true),
        ]
    ) { ctx in
        RippleDropDemo(ctx: ctx)
    }
}

private struct RippleTouch: Identifiable {
    let id = UUID()
    let date: Date
    let point: CGPoint
}

private struct RippleDropDemo: View {
    let ctx: DemoContext
    @State private var clock = LoadingPhaseClock()
    @State private var touches: [RippleTouch] = []

    private let canvasSize = CGSize(width: 290, height: 256)

    var body: some View {
        let interval: Double = max(ctx["interval"], 0.4)
        VStack(spacing: 4) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let phase: Double = ctx.isStill ? 1.66 : clock.phase(at: timeline.date, rate: 1 / interval) + 0.25
                let ages: [(age: Double, point: CGPoint)] = touches.map { (timeline.date.timeIntervalSince($0.date), $0.point) }
                RippleCanvas(
                    phase: phase,
                    interval: interval,
                    rings: max(ctx.int("rings"), 1),
                    tilt: ctx.cg("tilt"),
                    rebound: ctx.bool("rebound"),
                    touches: ages
                )
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    Haptics.tap(.soft)
                    touch(at: value.location)
                }
            )
            DemoHint(text: L("Tap the water", "点一下水面"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx["interval"]) { old, _ in
            clock.rebase(at: .now, oldRate: 1 / max(old, 0.4))
        }
    }

    private func touch(at location: CGPoint) {
        let now = Date()
        touches.removeAll { now.timeIntervalSince($0.date) > RippleCanvas.life }
        // Keep the touch on the pool: clamp it into the ellipse.
        let centre = RippleCanvas.poolCentre(in: canvasSize)
        let rx: CGFloat = RippleCanvas.poolRadius * 0.82
        let ry: CGFloat = rx * ctx.cg("tilt")
        var dx: CGFloat = (location.x - centre.x) / rx
        var dy: CGFloat = (location.y - centre.y) / max(ry, 1)
        let distance: CGFloat = (dx * dx + dy * dy).squareRoot()
        if distance > 1 {
            dx /= distance
            dy /= distance
        }
        touches.append(RippleTouch(date: now, point: CGPoint(x: centre.x + dx * rx, y: centre.y + dy * ry)))
        if touches.count > 6 { touches.removeFirst(touches.count - 6) }
    }
}

private struct RippleCanvas: View {
    /// Whole part = drop number, fraction = position in the cycle.
    let phase: Double
    let interval: Double
    let rings: Int
    let tilt: CGFloat
    let rebound: Bool
    let touches: [(age: Double, point: CGPoint)]

    static let life: Double = 1.9
    static let poolRadius: CGFloat = 130
    private static let reach: CGFloat = 118
    private static let grow: Double = 0.30
    private static let impact: Double = 0.52
    private static let fall: CGFloat = 140

    static func poolCentre(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height - 74)
    }

    var body: some View {
        Canvas { context, size in
            let centre = RippleCanvas.poolCentre(in: size)
            let p: Double = phase - floor(phase)
            let rx: CGFloat = RippleCanvas.poolRadius
            let pool = CGRect(x: centre.x - rx, y: centre.y - rx * tilt, width: rx * 2, height: rx * 2 * tilt)

            // The pool.
            context.fill(
                Path(ellipseIn: pool),
                with: .linearGradient(
                    Gradient(colors: [Palette.sky.opacity(0.12), Palette.blue.opacity(0.26)]),
                    startPoint: CGPoint(x: centre.x, y: pool.minY),
                    endPoint: CGPoint(x: centre.x, y: pool.maxY)
                )
            )
            context.stroke(Path(ellipseIn: pool), with: .color(Palette.sky.opacity(0.22)), lineWidth: 1)

            // Rings of this drop and the one before it, plus every tap.
            var water = context
            water.clip(to: Path(ellipseIn: pool))
            for back in 0...1 {
                let age: Double = (p - RippleCanvas.impact + Double(back)) * interval
                RippleCanvas.drawRings(&water, centre: centre, age: age, rings: rings, tilt: tilt, strength: 1)
            }
            for touch in touches {
                RippleCanvas.drawRings(&water, centre: touch.point, age: touch.age, rings: min(rings, 2), tilt: tilt, strength: 0.62)
            }

            // The nozzle.
            let top: CGFloat = centre.y - RippleCanvas.fall - 8
            let nozzle = CGRect(x: centre.x - 13, y: top - 9, width: 26, height: 8)
            context.fill(Path(roundedRect: nozzle, cornerRadius: 4, style: .continuous), with: .color(Color.primary.opacity(0.22)))

            // The drop.
            let dropRadius: CGFloat = 9
            if p < RippleCanvas.impact {
                let growing: Double = min(p / RippleCanvas.grow, 1)
                let u: Double = max((p - RippleCanvas.grow) / (RippleCanvas.impact - RippleCanvas.grow), 0)
                let y: CGFloat = top + dropRadius * CGFloat(growing) + RippleCanvas.fall * CGFloat(u * u)
                let stretch: CGFloat = 1 + 0.9 * CGFloat(u)
                let r: CGFloat = dropRadius * CGFloat(LoadingCurve.easeOutCubic(growing))

                // Its shadow on the water.
                let shade: CGFloat = 6 + 11 * CGFloat(u)
                let shadow = CGRect(x: centre.x - shade, y: centre.y - shade * tilt, width: shade * 2, height: shade * 2 * tilt)
                context.fill(Path(ellipseIn: shadow), with: .color(Palette.blue.opacity(0.08 + 0.3 * u)))

                RippleCanvas.drawDrop(&context, at: CGPoint(x: centre.x, y: y), radius: r, stretch: stretch, thin: 1 - 0.22 * CGFloat(u))
            }

            // Splash: a flash on the surface and beads leaping back up.
            let sinceImpact: Double = (p - RippleCanvas.impact) * interval
            if sinceImpact >= 0 {
                if sinceImpact < 0.3 {
                    let u: Double = sinceImpact / 0.3
                    let fr: CGFloat = 8 + 24 * CGFloat(LoadingCurve.easeOutCubic(u))
                    let flash = CGRect(x: centre.x - fr, y: centre.y - fr * tilt, width: fr * 2, height: fr * 2 * tilt)
                    context.fill(Path(ellipseIn: flash), with: .color(.white.opacity(0.5 * (1 - u))))
                }
                if rebound {
                    let beads: [(dx: CGFloat, height: CGFloat, radius: CGFloat, time: Double)] = [
                        (0, 46, 5, 0.46), (-26, 22, 3, 0.36), (22, 28, 2.8, 0.4),
                    ]
                    for bead in beads where sinceImpact < bead.time {
                        let u: Double = sinceImpact / bead.time
                        let point = CGPoint(
                            x: centre.x + bead.dx * CGFloat(u),
                            y: centre.y - bead.height * CGFloat(4 * u * (1 - u))
                        )
                        let speed: CGFloat = CGFloat(abs(1 - 2 * u))
                        RippleCanvas.drawDrop(&context, at: point, radius: bead.radius, stretch: 1 + 0.4 * speed, thin: 1)
                    }
                }
            }
        }
    }

    private static func drawRings(_ context: inout GraphicsContext, centre: CGPoint, age: Double, rings: Int, tilt: CGFloat, strength: Double) {
        for ring in 0..<rings {
            let local: Double = age - Double(ring) * 0.16
            guard local > 0, local < life else { continue }
            let u: Double = local / life
            let radius: CGFloat = 10 + (reach - 10) * CGFloat(1 - pow(1 - u, 2.4)) * CGFloat(0.55 + 0.45 * strength)
            let rect = CGRect(x: centre.x - radius, y: centre.y - radius * tilt, width: radius * 2, height: radius * 2 * tilt)
            let alpha: Double = pow(1 - u, 1.3) * (1 - 0.14 * Double(ring)) * strength
            let width: CGFloat = 3.2 * CGFloat(1 - u) + 0.6
            let path = Path(ellipseIn: rect)
            // Lit from behind: the far edge catches white, the near edge stays deep blue.
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [Palette.sky.opacity(alpha * 0.55), Palette.blue.opacity(alpha)]),
                    startPoint: CGPoint(x: centre.x, y: rect.minY),
                    endPoint: CGPoint(x: centre.x, y: rect.maxY)
                ),
                lineWidth: width
            )
            context.stroke(
                path.offsetBy(dx: 0, dy: -width * 0.55),
                with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(alpha * 0.6), Color.white.opacity(0)]),
                    startPoint: CGPoint(x: centre.x, y: rect.minY),
                    endPoint: CGPoint(x: centre.x, y: rect.midY)
                ),
                lineWidth: max(width * 0.4, 0.5)
            )
        }
    }

    /// A teardrop: a circle whose top is pulled into a point as `stretch` grows.
    private static func drawDrop(_ context: inout GraphicsContext, at point: CGPoint, radius: CGFloat, stretch: CGFloat, thin: CGFloat) {
        guard radius > 0.3 else { return }
        let w: CGFloat = radius * thin
        let tail: CGFloat = radius * (stretch - 1) * 2 + radius
        var path = Path()
        path.move(to: CGPoint(x: point.x, y: point.y - tail))
        path.addCurve(
            to: CGPoint(x: point.x + w, y: point.y),
            control1: CGPoint(x: point.x + w * 0.2, y: point.y - tail * 0.55),
            control2: CGPoint(x: point.x + w, y: point.y - radius * 0.7)
        )
        path.addArc(center: point, radius: w, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(
            to: CGPoint(x: point.x, y: point.y - tail),
            control1: CGPoint(x: point.x - w, y: point.y - radius * 0.7),
            control2: CGPoint(x: point.x - w * 0.2, y: point.y - tail * 0.55)
        )
        path.closeSubpath()
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [Palette.sky, Palette.blue]),
                startPoint: CGPoint(x: point.x - w, y: point.y - tail),
                endPoint: CGPoint(x: point.x + w, y: point.y + w)
            )
        )
        let gloss = CGRect(x: point.x - w * 0.5, y: point.y - w * 0.45, width: w * 0.42, height: w * 0.5)
        context.fill(Path(ellipseIn: gloss), with: .color(.white.opacity(0.6)))
    }
}
