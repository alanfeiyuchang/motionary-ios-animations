import SwiftUI

extension Effect {
    static let backgroundsPondRipples = Effect(
        id: "backgrounds.pond-ripples",
        category: .backgrounds,
        interaction: .tap,
        name: L("Pond Ripples", "池塘涟漪"),
        summary: L(
            "A still pond seen at a low angle: raindrops and touches send out ring trains that cross, sparkle where crests meet and rock the lily pads.",
            "低角度望去的一池静水：雨滴与触摸荡开一圈圈涟漪，波峰相遇处闪出亮点，睡莲叶也随波轻摇。"
        ),
        prompt: L(
            "A dark teal pond viewed obliquely, so every ripple is an ellipse flattened to 55%. Light rain lands about 1.2 times a second at random spots; a tap or drag drops stronger ripples under the finger, with a soft haptic. Each drop first flashes a small splash, then sends out a train of 3 concentric crests travelling at 62 pt/s, 14 pt apart: a bright line for the crest and a dark line half a wavelength behind for the trough, the later crests weaker, everything fading as e^(−0.55·t). Trains pass through each other, and wherever two crests cross a small glint lights up in proportion to both amplitudes, so the interference reads as moving sparkles. Four lily pads ride the surface, pushed outward and tilted by each passing crest, and two koi glide underneath. Quiet, meditative, alive.",
            "深青色的池塘以斜视角呈现，每圈涟漪都是压扁到 55% 的椭圆。细雨大约每秒 1.2 次随机落下；点击或拖动则在手指处落下更强的涟漪，伴随柔和触感。每个落点先闪出一小朵水花，再荡出 3 道同心波峰，以每秒 62pt 扩散、间距 14pt：波峰是亮线，其后半个波长处的波谷是暗线，越靠后越弱，整体按 e^(−0.55·t) 衰减。波列彼此穿过，两道波峰相交处按两者振幅的乘积亮起一粒闪光，干涉呈现为游动的光点。四片睡莲叶浮在水面，被经过的波峰推开、倾斜；两尾锦鲤在水下游弋。"
        ),
        implementation: L(
            "Ripples are stored as origin + birth time in plane coordinates; a Canvas scaled vertically strokes each crest and trough as circles in a plusLighter layer, solves circle–circle intersections between every pair of live crests for the glints, and offsets the pads by the analytic wave height at their position.",
            "涟漪以平面坐标下的“落点 + 出生时间”保存；纵向压缩的 Canvas 在 plusLighter 图层中把每道波峰与波谷描为圆，再对所有存活波峰两两求圆与圆的交点来绘制闪光，并按睡莲叶所在位置的解析波高对其偏移。"
        ),
        apis: ["Canvas", "GraphicsContext.scaleBy(x:y:)", "GraphicsContext.drawLayer", "TimelineView(.animation)", "DragGesture", "Haptics"],
        tags: ["pond", "ripples", "water", "interference", "池塘", "涟漪", "水波", "干涉"],
        params: [
            .slider("rain", L("Rain", "雨量"), 0...4, default: 1.2, decimals: 1, unit: "/s"),
            .slider("speed", L("Ripple speed", "涟漪速度"), 30...120, default: 62, decimals: 0, unit: "pt/s"),
            .slider("rings", L("Crests per drop", "每滴波峰数"), 1...5, default: 3, step: 1, decimals: 0),
            .toggle("pads", L("Lily pads", "睡莲叶"), default: true),
        ]
    ) { ctx in
        PondRipplesDemo(ctx: ctx)
    }
}

private struct PondRipple {
    /// Plane coordinates (stage x, stage y divided by the squash).
    let origin: CGPoint
    let born: Double
    let strength: Double
}

private final class PondModel {
    static let squash: CGFloat = 0.55
    static let wavelength: Double = 14
    static let life: Double = 6.5

    let clock = BackgroundClock()
    private(set) var ripples: [PondRipple] = []
    private var rng = BackgroundRNG(seed: 23)
    private var nextRain: Double = 100.3
    private var seededStill = false
    var lastDrop: CGPoint?

    func step(now: Double, size: CGSize, rain: Double, frozen: Bool) -> Double {
        let t = clock.advance(to: now, speed: 1)
        if frozen {
            if !seededStill {
                seededStill = true
                ripples = [
                    PondRipple(origin: plane(CGPoint(x: size.width * 0.34, y: size.height * 0.5)), born: t - 2.6, strength: 1),
                    PondRipple(origin: plane(CGPoint(x: size.width * 0.68, y: size.height * 0.66)), born: t - 1.5, strength: 1),
                    PondRipple(origin: plane(CGPoint(x: size.width * 0.56, y: size.height * 0.3)), born: t - 0.7, strength: 0.6),
                ]
            }
            return t
        }
        ripples.removeAll { t - $0.born > PondModel.life }
        if rain > 0.01 {
            if t >= nextRain {
                let p = CGPoint(x: size.width * CGFloat(rng.range(0.04...0.96)), y: size.height * CGFloat(rng.range(0.1...0.96)))
                add(PondRipple(origin: plane(p), born: t, strength: rng.range(0.3...0.55)))
                nextRain = t + rng.range(0.4...1.6) / rain
            } else if nextRain - t > 2 / rain {
                nextRain = t + 1 / rain
            }
        }
        return t
    }

    func plane(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: p.y / PondModel.squash)
    }

    func drop(at location: CGPoint, strength: Double) {
        add(PondRipple(origin: plane(location), born: clock.phase, strength: strength))
    }

    private func add(_ ripple: PondRipple) {
        ripples.append(ripple)
        if ripples.count > 16 { ripples.removeFirst(ripples.count - 16) }
    }
}

private struct PondRipplesDemo: View {
    let ctx: DemoContext
    @State private var model = PondModel()
    @State private var size = CGSize(width: 340, height: 340)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B5A5E), Color(hex: 0x0C3A44), Color(hex: 0x05202B)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.step(now: now, size: size, rain: ctx["rain"], frozen: ctx.isStill)
                    PondPainter.draw(
                        &context, size: size, t: t, ripples: model.ripples, speed: ctx["speed"],
                        rings: max(ctx.int("rings"), 1), pads: ctx.bool("pads")
                    )
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .backgroundsTouch { location in
            if let last = model.lastDrop {
                guard hypot(location.x - last.x, location.y - last.y) > 26 else { return }
                model.drop(at: location, strength: 0.6)
            } else {
                Haptics.tap(.soft)
                model.drop(at: location, strength: 1)
            }
            model.lastDrop = location
        } onEnded: {
            model.lastDrop = nil
        }
        .autoplay(ctx.isPreview, every: 2.3, delay: 0.5) {
            model.drop(
                at: CGPoint(x: size.width * CGFloat.random(in: 0.2...0.8), y: size.height * CGFloat.random(in: 0.3...0.85)),
                strength: 1
            )
        }
        .backgroundsChipHint(L("Tap or swipe across the water", "点击或横向划过水面"), ctx)
    }
}

private enum PondPainter {
    /// One crest of one ripple, in plane coordinates.
    private struct Crest {
        let centre: CGPoint
        let radius: CGFloat
        let amplitude: Double
    }

    /// Wave height at a plane point (positive on a crest).
    static func height(at p: CGPoint, t: Double, ripples: [PondRipple], speed: Double, rings: Int) -> Double {
        var h = 0.0
        for ripple in ripples {
            let age = t - ripple.born
            guard age > 0 else { continue }
            let d = Double(hypot(p.x - ripple.origin.x, p.y - ripple.origin.y))
            let x = (speed * age - d) / PondModel.wavelength
            guard x > -0.5, x < Double(rings) - 0.25 else { continue }
            h += ripple.strength * exp(-age * 0.55) * cos(x * BackgroundMath.tau) * (1 - max(x, 0) / Double(rings))
        }
        return h
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, ripples: [PondRipple], speed: Double, rings: Int, pads: Bool) {
        // Far water reflects a pale sky.
        let sky = Gradient(stops: [
            .init(color: Color(hex: 0x8FD0C4).opacity(0.38), location: 0),
            .init(color: Color(hex: 0x8FD0C4).opacity(0), location: 0.5),
        ])
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        var plane = context
        plane.scaleBy(x: 1, y: PondModel.squash)
        drawKoi(&plane, size: size, t: t)

        var crests: [Crest] = []
        plane.drawLayer { layer in
            for ripple in ripples {
                let age = t - ripple.born
                guard age > 0 else { continue }
                let amp = ripple.strength * exp(-age * 0.55) * min(age / 0.12, 1) * (1 - BackgroundMath.smoothstep(PondModel.life - 1.5, PondModel.life, age))
                for k in 0..<rings {
                    let r = CGFloat(speed * age - Double(k) * PondModel.wavelength)
                    guard r > 2 else { continue }
                    let a = amp * pow(1 - Double(k) / Double(rings), 1.2)
                    guard a > 0.01 else { continue }
                    let trough = r - CGFloat(PondModel.wavelength) * 0.5
                    if trough > 1 {
                        layer.stroke(
                            Path(ellipseIn: CGRect(x: ripple.origin.x - trough, y: ripple.origin.y - trough, width: trough * 2, height: trough * 2)),
                            with: .color(Color(hex: 0x01141A).opacity(min(a * 0.6, 0.65))), lineWidth: 4
                        )
                    }
                    crests.append(Crest(centre: ripple.origin, radius: r, amplitude: a))
                }
            }
        }
        plane.drawLayer { layer in
            layer.blendMode = .plusLighter
            for crest in crests {
                layer.stroke(
                    Path(ellipseIn: CGRect(x: crest.centre.x - crest.radius, y: crest.centre.y - crest.radius, width: crest.radius * 2, height: crest.radius * 2)),
                    with: .color(Color(hex: 0xC9F4EC).opacity(min(crest.amplitude * 0.7, 0.85))), lineWidth: 2.4
                )
            }
            // Splash at the moment of impact.
            for ripple in ripples {
                let age = t - ripple.born
                guard age >= 0, age < 0.32 else { continue }
                let k = 1 - age / 0.32
                layer.backgroundsGlow(at: ripple.origin, radius: CGFloat(6 + 16 * ripple.strength * (1 - k)), color: .white.opacity(k * 0.9 * ripple.strength))
            }
        }

        // A soft sheen around every crest.
        plane.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            layer.blendMode = .plusLighter
            for crest in crests {
                layer.stroke(
                    Path(ellipseIn: CGRect(x: crest.centre.x - crest.radius, y: crest.centre.y - crest.radius, width: crest.radius * 2, height: crest.radius * 2)),
                    with: .color(Color(hex: 0x7FE0D0).opacity(min(crest.amplitude * 0.5, 0.6))), lineWidth: 6
                )
            }
        }

        drawGlints(&context, crests: crests)
        if pads {
            drawPads(&plane, size: size, t: t, ripples: ripples, speed: speed, rings: rings)
        }
    }

    /// Sparkles where two crests cross (constructive interference).
    private static func drawGlints(_ context: inout GraphicsContext, crests: [Crest]) {
        guard crests.count > 1 else { return }
        var bins = [Path](repeating: Path(), count: 3)
        for i in 0..<(crests.count - 1) {
            for j in (i + 1)..<crests.count {
                let a = crests[i]
                let b = crests[j]
                let power = a.amplitude * b.amplitude
                guard power > 0.02, a.centre != b.centre else { continue }
                let dx = b.centre.x - a.centre.x
                let dy = b.centre.y - a.centre.y
                let d = hypot(dx, dy)
                guard d > 1, d < a.radius + b.radius, d > abs(a.radius - b.radius) else { continue }
                let along = (a.radius * a.radius - b.radius * b.radius + d * d) / (2 * d)
                let h2 = a.radius * a.radius - along * along
                guard h2 > 0 else { continue }
                let h = h2.squareRoot()
                let mx = a.centre.x + along * dx / d
                let my = a.centre.y + along * dy / d
                let level = min(Int(power * 9), 2)
                let r: CGFloat = 1.6 + 0.9 * CGFloat(level)
                for sign in [CGFloat(-1), 1] {
                    let p = CGPoint(x: mx + sign * h * dy / d, y: (my - sign * h * dx / d) * PondModel.squash)
                    bins[level].addEllipse(in: CGRect(x: p.x - r * 1.5, y: p.y - r * 0.7, width: r * 3, height: r * 1.4))
                }
            }
        }
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            for level in 0..<3 {
                layer.fill(bins[level], with: .color(.white.opacity(0.3 + 0.28 * Double(level))))
            }
        }
    }

    private static func koiPoint(_ i: Int, _ tau: Double, size: CGSize) -> CGPoint {
        let phase = Double(i) * 2.4
        let depth = Double(size.height / PondModel.squash)
        return CGPoint(
            x: Double(size.width) * (0.5 + 0.38 * sin(tau * 0.21 + phase) + 0.08 * sin(tau * 0.53 + phase * 2)),
            y: depth * (0.5 + 0.36 * sin(tau * 0.27 + phase * 1.7) + 0.06 * sin(tau * 0.61 + phase))
        )
    }

    /// Two koi under the surface: the spine is the fish's own path sampled backward at equal arc length,
    /// so the body bends through every turn it has just swum.
    private static func drawKoi(_ plane: inout GraphicsContext, size: CGSize, t: Double) {
        let widths: [CGFloat] = [3.4, 7.4, 9.0, 8.5, 7.2, 5.6, 4.0, 2.5, 1.3]
        let orange = Color(hex: 0xFF8A4A)
        let cream = Color(hex: 0xFFF1E4)
        plane.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.6))
            layer.opacity = 0.74
            for i in 0..<2 {
                var tau = t
                var spine: [CGPoint] = []
                for _ in widths.indices {
                    let p = koiPoint(i, tau, size: size)
                    let q = koiPoint(i, tau + 0.02, size: size)
                    let speed = max(Double(hypot(q.x - p.x, q.y - p.y)) / 0.02, 4)
                    spine.append(p)
                    tau -= 8.5 / speed
                }
                var left: [CGPoint] = []
                var right: [CGPoint] = []
                var normals: [CGVector] = []
                let last = spine.count - 1
                for k in spine.indices {
                    let a = spine[max(k - 1, 0)]
                    let b = spine[min(k + 1, last)]
                    let length = max(hypot(a.x - b.x, a.y - b.y), 0.001)
                    let n = CGVector(dx: -(a.y - b.y) / length, dy: (a.x - b.x) / length)
                    let wag = CGFloat(sin(t * 5 - Double(k) * 0.8)) * 3.2 * CGFloat(k) / CGFloat(last)
                    let c = CGPoint(x: spine[k].x + n.dx * wag, y: spine[k].y + n.dy * wag)
                    spine[k] = c
                    normals.append(n)
                    left.append(CGPoint(x: c.x + n.dx * widths[k], y: c.y + n.dy * widths[k]))
                    right.append(CGPoint(x: c.x - n.dx * widths[k], y: c.y - n.dy * widths[k]))
                }
                var body = Path()
                body.addLines(left + right.reversed())
                body.closeSubpath()
                let end = spine[last]
                let back = CGVector(dx: -normals[last].dy, dy: normals[last].dx)
                var fin = Path()
                fin.move(to: end)
                fin.addLine(to: CGPoint(x: end.x + back.dx * 13 + normals[last].dx * 8, y: end.y + back.dy * 13 + normals[last].dy * 8))
                fin.addLine(to: CGPoint(x: end.x + back.dx * 8, y: end.y + back.dy * 8))
                fin.addLine(to: CGPoint(x: end.x + back.dx * 13 - normals[last].dx * 8, y: end.y + back.dy * 13 - normals[last].dy * 8))
                fin.closeSubpath()
                let main = i == 0 ? orange : cream
                let patch = i == 0 ? cream : Color(hex: 0xF0552A)
                layer.fill(fin, with: .color(main.opacity(0.75)))
                layer.fill(body, with: .color(main))
                layer.stroke(body, with: .color(main), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                for k in [2, 5] {
                    let r = widths[k] * 0.72
                    layer.fill(Path(ellipseIn: CGRect(x: spine[k].x - r, y: spine[k].y - r, width: r * 2, height: r * 2)), with: .color(patch))
                }
            }
        }
    }

    private static func drawPads(_ plane: inout GraphicsContext, size: CGSize, t: Double, ripples: [PondRipple], speed: Double, rings: Int) {
        let anchors: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [(0.2, 0.3, 30), (0.82, 0.42, 36), (0.3, 0.78, 40), (0.74, 0.86, 28)]
        let greens: [(UInt32, UInt32)] = [(0x4FA35C, 0x1F6A3A), (0x5BAE63, 0x25733F), (0x479A58, 0x1B6236), (0x63B56A, 0x2A7A45)]
        for (i, anchor) in anchors.enumerated() {
            var centre = CGPoint(x: size.width * anchor.x, y: size.height * anchor.y / PondModel.squash)
            // Each passing crest pushes the pad away from its source and tips it.
            var tilt = 0.0
            for ripple in ripples {
                let h = height(at: centre, t: t, ripples: [ripple], speed: speed, rings: rings)
                let dx = centre.x - ripple.origin.x
                let dy = centre.y - ripple.origin.y
                let d = max(hypot(dx, dy), 1)
                centre.x += dx / d * CGFloat(h) * 5
                centre.y += dy / d * CGFloat(h) * 5
                tilt += h
            }
            let drift = t * 0.05 * (i % 2 == 0 ? 1 : -1) + Double(i) * 1.9
            let notch = drift + tilt * 0.12
            let r = anchor.r * CGFloat(1 + tilt * 0.035)

            var pad = Path()
            pad.move(to: centre)
            pad.addArc(center: centre, radius: r, startAngle: .radians(notch + 0.22), endAngle: .radians(notch - 0.22 + BackgroundMath.tau), clockwise: false)
            pad.closeSubpath()

            var shadow = plane
            shadow.translateBy(x: 3, y: 9)
            shadow.addFilter(.blur(radius: 5))
            shadow.fill(pad, with: .color(.black.opacity(0.35)))

            let fill = Gradient(colors: [Color(hex: greens[i].0), Color(hex: greens[i].1)])
            plane.fill(pad, with: .radialGradient(fill, center: CGPoint(x: centre.x - r * 0.3, y: centre.y - r * 0.4), startRadius: 0, endRadius: r * 1.5))
            var veins = Path()
            for k in 0..<9 {
                let angle = notch + 0.5 + Double(k) * (BackgroundMath.tau - 1.0) / 8
                veins.move(to: centre)
                veins.addLine(to: CGPoint(x: centre.x + CGFloat(cos(angle)) * r * 0.86, y: centre.y + CGFloat(sin(angle)) * r * 0.86))
            }
            plane.stroke(veins, with: .color(Color(hex: 0xC8F2B8).opacity(0.22)), lineWidth: 0.8)
            plane.stroke(pad, with: .color(Color(hex: 0xC8F2B8).opacity(0.4)), lineWidth: 1)
        }
    }
}
