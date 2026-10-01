import SwiftUI

extension Effect {
    static let backgroundsThunderstorm = Effect(
        id: "backgrounds.thunderstorm",
        category: .backgrounds,
        interaction: .tap,
        name: L("Thunderstorm", "雷暴"),
        summary: L(
            "Heavy clouds, slanting rain and forked lightning that grows down from the cloud and strikes where you tap.",
            "厚重的乌云、斜落的雨，还有自云底向下生长、劈向你点击之处的分叉闪电。"
        ),
        prompt: L(
            "A night storm over a dark skyline with a few lit windows. Three layers of heavily blurred slate clouds drift across the top third, now and then glowing from inside with silent sheet lightning, while 150 rain streaks fall at a 14° slant in two depths. Every 3 s on average, or on a tap, a bolt strikes: a jagged fractal channel built by midpoint displacement, with thinner forks branching off at 20–45°. It grows downward from the cloud base in 80 ms as a dim leader, then the return stroke flashes at full brightness and decays at 16/s, re-striking twice at 0.20 s and 0.30 s at reduced strength. Each flash lights the clouds from within, tints the whole sky pale blue, brightens the rain and throws the skyline into silhouette; a tapped bolt lands exactly on the finger with a heavy haptic. Violent, electric, cinematic.",
            "夜空下的雷暴，下方是亮着零星窗灯的天际线。三层重度模糊的石板色乌云在画面上三分之一处飘移，偶尔被片状闪电从内部照亮；150 道雨丝以 14° 倾角分两层景深落下。平均每 3 秒，或在点击时，劈下一道闪电：中点位移生成的锯齿通道，以 20–45° 分出更细的枝杈。先在 80 毫秒内以暗淡先导自云底向下生长，随后回击以全亮度闪现并以 16/s 衰减，再在 0.20 秒和 0.30 秒处减弱复闪两次。每次闪光都照亮云层、把天空染成淡蓝、提亮雨丝，并让天际线成为剪影；点击召来的闪电准确落在手指处，伴随重触感。"
        ),
        implementation: L(
            "Bolts are polylines generated once by recursive midpoint displacement and stored in a reference model; a Canvas trims them for the leader, strokes them three times (two blurred glows and a core) scaled by an analytic multi-stroke envelope, and reuses that envelope to light clouds, sky and rain.",
            "闪电是用递归中点位移一次性生成、保存在引用类型模型中的折线；Canvas 在先导阶段对其裁剪，按解析的多次回击包络描边三遍（两层模糊辉光加一条亮芯），并用同一包络照亮云层、天空与雨丝。"
        ),
        apis: ["Canvas", "Path.trimmedPath(from:to:)", "GraphicsContext.drawLayer", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "Haptics"],
        tags: ["thunderstorm", "lightning", "storm", "rain", "雷暴", "闪电", "暴风雨", "打雷"],
        params: [
            .slider("rain", L("Rain", "雨量"), 40...280, default: 150, step: 10, decimals: 0),
            .slider("wind", L("Wind slant", "风向倾角"), -30...30, default: 14, decimals: 0, unit: "°"),
            .slider("interval", L("Strike interval", "闪电间隔"), 1.2...8, default: 3.0, decimals: 1, unit: "s"),
            .slider("branching", L("Forks", "分叉"), 0...2, default: 1.0, unit: "×"),
        ]
    ) { ctx in
        ThunderstormDemo(ctx: ctx)
    }
}

private struct StormBolt {
    let main: Path
    let forks: Path
    let origin: CGPoint
    let end: CGPoint
    let born: Double
    let restrike: Double
}

private final class StormModel {
    let clock = BackgroundClock()
    private(set) var bolts: [StormBolt] = []
    private var rng = BackgroundRNG(seed: 11)
    private var nextAuto: Double = 100.7
    private var size: CGSize = .zero

    func step(now: Double, size newSize: CGSize, interval: Double, branching: Double, frozen: Bool) -> Double {
        let t = clock.advance(to: now, speed: 1)
        if newSize != size {
            size = newSize
            bolts = []
            if frozen {
                // A still shows a bolt at the peak of its return stroke.
                rng = BackgroundRNG(seed: 11)
                strike(toward: CGPoint(x: newSize.width * 0.56, y: newSize.height * 0.8), branching: branching, born: t - 0.1)
            }
        }
        guard !frozen else { return t }
        bolts.removeAll { t - $0.born > 1.3 }
        if t >= nextAuto {
            strike(toward: nil, branching: branching, born: t)
            nextAuto = t + interval * rng.range(0.6...1.4)
        } else if nextAuto - t > interval * 1.5 {
            // The interval slider was shortened.
            nextAuto = t + interval
        }
        return t
    }

    func strike(toward target: CGPoint?, branching: Double) {
        strike(toward: target, branching: branching, born: clock.phase)
    }

    private func strike(toward target: CGPoint?, branching: Double, born: Double) {
        guard size.width > 0 else { return }
        let ground = size.height * CGFloat(rng.range(0.78...0.88))
        let end = target ?? CGPoint(x: size.width * CGFloat(rng.range(0.15...0.85)), y: ground)
        let origin = CGPoint(
            x: (end.x + CGFloat(rng.range(-70...70))).clamped(to: 20...max(size.width - 20, 21)),
            y: size.height * CGFloat(rng.range(0.1...0.2))
        )
        let spine = jag(from: origin, to: end, roughness: 0.16, depth: 6)
        var main = Path()
        main.addLines(spine)

        var forks = Path()
        let count = Int((rng.range(3...5.5) * branching).rounded())
        let total = hypot(end.x - origin.x, end.y - origin.y)
        for _ in 0..<max(count, 0) {
            let index = Int(rng.range(0.12...0.72) * Double(spine.count - 1))
            let start = spine[index]
            let ahead = spine[min(index + 4, spine.count - 1)]
            let heading = atan2(ahead.y - start.y, ahead.x - start.x)
            let side: CGFloat = rng.unit() > 0.5 ? 1 : -1
            let angle = heading + side * CGFloat(rng.range(0.35...0.8))
            let length = total * CGFloat(rng.range(0.16...0.38)) * (1 - CGFloat(index) / CGFloat(spine.count))  + 14
            let tip = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            let fork = jag(from: start, to: tip, roughness: 0.2, depth: 4)
            forks.addLines(fork)
            if rng.unit() > 0.55 {
                let mid = fork[fork.count / 2]
                let twig = angle - side * CGFloat(rng.range(0.4...0.9))
                let reach = length * 0.4
                forks.addLines(jag(from: mid, to: CGPoint(x: mid.x + cos(twig) * reach, y: mid.y + sin(twig) * reach), roughness: 0.22, depth: 3))
            }
        }
        bolts.append(StormBolt(main: main, forks: forks, origin: origin, end: end, born: born, restrike: rng.range(0.4...1)))
        if bolts.count > 4 { bolts.removeFirst(bolts.count - 4) }
    }

    /// Recursive midpoint displacement between two points.
    private func jag(from a: CGPoint, to b: CGPoint, roughness: CGFloat, depth: Int) -> [CGPoint] {
        var points = [a, b]
        var amplitude = hypot(b.x - a.x, b.y - a.y) * roughness
        for _ in 0..<depth {
            var next: [CGPoint] = []
            next.reserveCapacity(points.count * 2)
            for i in 0..<(points.count - 1) {
                let p = points[i]
                let q = points[i + 1]
                let length = max(hypot(q.x - p.x, q.y - p.y), 0.001)
                let offset = CGFloat(rng.range(-1...1)) * amplitude
                next.append(p)
                next.append(CGPoint(
                    x: (p.x + q.x) / 2 - (q.y - p.y) / length * offset,
                    y: (p.y + q.y) / 2 + (q.x - p.x) / length * offset
                ))
            }
            next.append(points[points.count - 1])
            points = next
            amplitude *= 0.52
        }
        return points
    }
}

private struct ThunderstormDemo: View {
    let ctx: DemoContext
    @State private var model = StormModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0A0D1A), Color(hex: 0x1A2138), Color(hex: 0x39405C)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.step(now: now, size: size, interval: max(ctx["interval"], 0.5), branching: ctx["branching"], frozen: ctx.isStill)
                    StormPainter.draw(&context, size: size, t: t, bolts: model.bolts, rain: ctx.int("rain"), wind: ctx["wind"])
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.heavy)
            model.strike(toward: location, branching: ctx["branching"])
        }
        .backgroundsHint(L("Tap to call lightning down on that spot", "点击把闪电引到那里"), ctx)
    }
}

private enum StormPainter {
    /// Brightness of a bolt `age` seconds after it started: dim leader, return stroke, two re-strikes.
    static func envelope(age: Double, restrike: Double) -> Double {
        guard age >= 0 else { return 0 }
        if age < 0.08 { return 0.4 }
        var value = exp(-(age - 0.08) * 16)
        if age >= 0.20 { value = max(value, 0.5 * restrike * exp(-(age - 0.20) * 16)) }
        if age >= 0.30 { value = max(value, 0.7 * restrike * exp(-(age - 0.30) * 16)) }
        return value
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, bolts: [StormBolt], rain: Int, wind: Double) {
        let frame = Path(CGRect(origin: .zero, size: size))
        var flash = 0.0
        for bolt in bolts {
            flash = max(flash, envelope(age: t - bolt.born, restrike: bolt.restrike))
        }

        // Sky lit by the flash.
        if flash > 0.002 {
            context.fill(frame, with: .color(Color(hex: 0xAEC2FF).opacity(flash * 0.34)))
        }
        for bolt in bolts {
            let e = envelope(age: t - bolt.born, restrike: bolt.restrike)
            guard e > 0.002 else { continue }
            let reach = size.width * 0.9
            let halo = Gradient(colors: [Color(hex: 0xDCE6FF).opacity(e * 0.6), Color(hex: 0xDCE6FF).opacity(0)])
            context.fill(
                Path(ellipseIn: CGRect(x: bolt.origin.x - reach, y: bolt.origin.y - reach, width: reach * 2, height: reach * 2)),
                with: .radialGradient(halo, center: bolt.origin, startRadius: 0, endRadius: reach)
            )
        }

        drawBolts(&context, t: t, bolts: bolts)
        drawClouds(&context, size: size, t: t, flash: flash, bolts: bolts)
        drawRain(&context, size: size, t: t, count: rain, wind: wind, flash: flash)
        drawSkyline(&context, size: size, flash: flash)
    }

    private static func drawBolts(_ context: inout GraphicsContext, t: Double, bolts: [StormBolt]) {
        for bolt in bolts {
            let age = t - bolt.born
            let e = envelope(age: age, restrike: bolt.restrike)
            guard e > 0.01 else { continue }
            let grown = CGFloat(min(max(age / 0.08, 0), 1))
            let main = grown < 1 ? bolt.main.trimmedPath(from: 0, to: grown) : bolt.main
            let style = StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 9))
                layer.blendMode = .plusLighter
                layer.stroke(main, with: .color(Color(hex: 0x8FA8FF).opacity(min(e * 1.2, 1))), lineWidth: 7)
                if grown >= 1 {
                    layer.stroke(bolt.forks, with: .color(Color(hex: 0x8FA8FF).opacity(min(e, 1) * 0.7)), lineWidth: 4)
                }
            }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 2.5))
                layer.blendMode = .plusLighter
                layer.stroke(main, with: .color(.white.opacity(min(e * 1.3, 1))), lineWidth: 3)
            }
            if grown >= 1 {
                context.stroke(bolt.forks, with: .color(.white.opacity(min(e * 1.2, 1) * 0.85)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
                // Where it lands.
                let r = 26 + 30 * CGFloat(e)
                let impact = Gradient(colors: [.white.opacity(min(e, 1) * 0.9), .white.opacity(0)])
                squashedGlow(&context, centre: bolt.end, radius: r, squash: 0.5, gradient: impact)
            }
            context.stroke(main, with: .color(.white.opacity(min(e * 1.6, 1))), style: style)
        }
    }

    private static func drawClouds(_ context: inout GraphicsContext, size: CGSize, t: Double, flash: Double, bolts: [StormBolt]) {
        let tones: [(dark: (Double, Double, Double), y: CGFloat, speed: Double, alpha: Double)] = [
            ((0.27, 0.30, 0.41), 0.03, 5, 0.95),
            ((0.17, 0.19, 0.28), 0.11, 9, 0.95),
            ((0.08, 0.09, 0.15), 0.19, 14, 0.97),
        ]
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            for (index, tone) in tones.enumerated() {
                // The flash lights the far layers most; the nearest stays a dark underside.
                let lit = flash * (0.55 - 0.18 * Double(index))
                let color = Color(
                    .sRGB,
                    red: tone.dark.0 + (0.75 - tone.dark.0) * lit,
                    green: tone.dark.1 + (0.8 - tone.dark.1) * lit,
                    blue: tone.dark.2 + (1.0 - tone.dark.2) * lit,
                    opacity: tone.alpha
                )
                var puffs = Path()
                let span = size.width + 240
                for i in 0..<10 {
                    let key = index * 20 + i
                    let w = 120 + 90 * BackgroundMath.unit(key, 1001)
                    let hgt = w * (0.42 + 0.2 * BackgroundMath.unit(key, 1002))
                    let x = CGFloat(BackgroundMath.fract(Double(i) / 10 + BackgroundMath.rand(key, 1003) * 0.08 + t * tone.speed / Double(span))) * span - 120
                    let y = size.height * (tone.y + 0.05 * BackgroundMath.unit(key, 1004)) + 4 * CGFloat(sin(t * 0.3 + Double(key)))
                    puffs.addEllipse(in: CGRect(x: x - w / 2, y: y - hgt / 2, width: w, height: hgt))
                }
                layer.fill(puffs, with: .color(color))
            }
        }
        // Sheet lightning: glows inside the cloud deck, never a bolt.
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            for i in 0..<3 {
                let cycle = t * (0.21 + 0.07 * Double(i)) + Double(i) * 0.37
                let phase = BackgroundMath.fract(cycle)
                let seed = i * 53 + Int(cycle.rounded(.down))
                guard phase < 0.16 else { continue }
                let flicker = (1 - phase / 0.16) * (0.6 + 0.4 * sin(phase * 180))
                let c = CGPoint(x: size.width * BackgroundMath.unit(seed, 1011), y: size.height * (0.06 + 0.12 * BackgroundMath.unit(seed, 1012)))
                let r = size.width * 0.3
                let glow = Gradient(colors: [Color(hex: 0xB9C8FF).opacity(0.42 * flicker), Color(hex: 0xB9C8FF).opacity(0)])
                squashedGlow(&layer, centre: c, radius: r, squash: 0.5, gradient: glow)
            }
            for bolt in bolts {
                let e = envelope(age: t - bolt.born, restrike: bolt.restrike)
                guard e > 0.01 else { continue }
                let r = size.width * 0.34
                let glow = Gradient(colors: [.white.opacity(min(e, 1) * 0.75), .white.opacity(0)])
                squashedGlow(&layer, centre: bolt.origin, radius: r, squash: 0.6, gradient: glow)
            }
        }
    }

    /// A radial glow flattened vertically (the gradient is squashed with the shape, so it has no hard edge).
    private static func squashedGlow(_ context: inout GraphicsContext, centre: CGPoint, radius: CGFloat, squash: CGFloat, gradient: Gradient) {
        var copy = context
        copy.translateBy(x: centre.x, y: centre.y)
        copy.scaleBy(x: 1, y: squash)
        copy.fill(
            Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: radius)
        )
    }

    private static func drawRain(_ context: inout GraphicsContext, size: CGSize, t: Double, count: Int, wind: Double, flash: Double) {
        let theta = wind * .pi / 180
        let slope = CGFloat(tan(theta))
        let dirX = CGFloat(sin(theta))
        let dirY = CGFloat(cos(theta))
        var far = Path()
        var near = Path()
        for i in 0..<max(count, 0) {
            let depth = BackgroundMath.rand(i, 1021)
            let length = CGFloat(14 + 26 * depth)
            let span = size.height + length + 20
            let y = CGFloat(BackgroundMath.fract(BackgroundMath.rand(i, 1022) + t * (1.2 + 1.0 * depth))) * span - length
            let x0 = (BackgroundMath.unit(i, 1023) * 1.8 - 0.4) * size.width
            let x = x0 + slope * (y - size.height / 2)
            let head = CGPoint(x: x, y: y)
            let tail = CGPoint(x: x - length * dirX, y: y - length * dirY)
            if depth > 0.55 {
                near.move(to: tail)
                near.addLine(to: head)
            } else {
                far.move(to: tail)
                far.addLine(to: head)
            }
        }
        let tint = Color(hex: 0xC9D6FF)
        context.stroke(far, with: .color(tint.opacity(min(0.16 + flash * 0.45, 1))), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        context.stroke(near, with: .color(tint.opacity(min(0.34 + flash * 0.6, 1))), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    }

    private static func drawSkyline(_ context: inout GraphicsContext, size: CGSize, flash: Double) {
        var skyline = Path()
        var windows = Path()
        skyline.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = 0
        var i = 0
        while x < size.width {
            let w = 16 + 26 * BackgroundMath.unit(i, 1031)
            let top = size.height * (0.9 - 0.11 * BackgroundMath.unit(i, 1032))
            skyline.addLine(to: CGPoint(x: x, y: top))
            skyline.addLine(to: CGPoint(x: x + w, y: top))
            for k in 0..<3 where BackgroundMath.rand(i * 7 + k, 1033) > 0.62 {
                let wx = x + 4 + (w - 10) * BackgroundMath.unit(i * 7 + k, 1034)
                let wy = top + 5 + 9 * CGFloat(k)
                if wy < size.height - 6 { windows.addRect(CGRect(x: wx, y: wy, width: 2.2, height: 3)) }
            }
            x += w
            i += 1
        }
        skyline.addLine(to: CGPoint(x: size.width, y: size.height))
        skyline.closeSubpath()
        context.fill(skyline, with: .color(Color(hex: 0x04050A)))
        context.fill(windows, with: .color(Color(hex: 0xFFC978).opacity(0.75 - flash * 0.4)))
        // Rim light along the roofs during a flash.
        if flash > 0.02 {
            context.stroke(skyline, with: .color(Color(hex: 0xC9D6FF).opacity(min(flash, 1) * 0.35)), lineWidth: 0.8)
        }
    }
}
