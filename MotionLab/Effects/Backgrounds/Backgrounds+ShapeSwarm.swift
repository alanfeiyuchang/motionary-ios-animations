import SwiftUI
import UIKit
import CoreText

extension Effect {
    static let backgroundsShapeSwarm = Effect(
        id: "backgrounds.shape-swarm",
        category: .backgrounds,
        interaction: .tap,
        name: L("Shape Swarm", "粒子集群成形"),
        summary: L(
            "A swarm of glowing particles snaps into a heart, a star or a letter, holds its breath, then blows apart and regroups as the next shape.",
            "一群发光粒子倏地聚成爱心、星星或字母，屏息片刻，随即炸散，再重组为下一个形状。"
        ),
        prompt: L(
            "A dark violet-black field holding a swarm of 380 small glowing particles. Each shape (heart, star, ring, bolt, or the letters of MOTION) is filled with evenly spread target points. To form, every particle is pulled to its own target by a spring (stiffness 70, damping ratio 0.75) after a random stagger of up to 0.45 s, so the figure condenses from a cloud, overshoots a little and settles; particles are streaks along their velocity, white-hot when fast and cooling to the shape's tint as they lock in, while a soft glow blooms behind the finished figure. After a 2.2 s hold it dissolves: an impulse of up to 420 pt/s blasts outward from a point, with a sideways swirl, and the particles ride a curling flow field for 1.3 s before the next shape calls them. Tapping detonates the figure from the finger. Playful, magical, crisp.",
            "深紫黑背景里游着 380 粒发光粒子。各形状（爱心、星星、圆环、闪电，或 MOTION 的各个字母）内部均匀布满目标点。成形时，每粒粒子在最多 0.45 秒的随机错峰后，被弹簧（刚度 70、阻尼比 0.75）拉向自己的目标点，图形从云雾中凝结、略微过冲再稳定；粒子是沿速度方向的拖影，快时白热，锁定后冷却为形状的主题色，图案背后晕开一片同色柔光。保持 2.2 秒后图形消散：最高每秒 420pt 的冲量从某一点向外炸开并带侧向旋涡，粒子随卷曲的流场漂移 1.3 秒，再被下个形状召回。点击从手指处引爆图形。"
        ),
        implementation: L(
            "Targets are sampled once per shape by testing a Halton sequence against Path.contains (letters come from CTFontCreatePathForGlyph); a reference model integrates spring or flow-field forces per particle each frame, and a Canvas batches velocity streaks into four speed bins plus a blurred plusLighter pass.",
            "每个形状的目标点只采样一次：用 Halton 序列逐点做 Path.contains 测试（字母来自 CTFontCreatePathForGlyph）；引用类型模型每帧为每粒粒子积分弹簧力或流场力，Canvas 把速度拖影按快慢合并为四条 Path，再叠加一遍模糊的 plusLighter 辉光。"
        ),
        apis: ["Canvas", "Path.contains(_:eoFill:)", "CTFontCreatePathForGlyph", "TimelineView(.animation)", "onTapGesture(coordinateSpace:perform:)", "Haptics"],
        tags: ["swarm", "particles", "morph", "letters", "粒子", "集群", "成形", "字母"],
        params: [
            .slider("count", L("Particles", "粒子数量"), 150...600, default: 380, step: 10, decimals: 0),
            .slider("hold", L("Hold time", "保持时长"), 0.8...5, default: 2.2, decimals: 1, unit: "s"),
            .slider("stiffness", L("Spring stiffness", "弹簧刚度"), 20...140, default: 70, decimals: 0),
            .choice("set", L("Figures", "图形"), [L("Shapes", "形状"), L("Letters", "字母")]),
        ]
    ) { ctx in
        ShapeSwarmDemo(ctx: ctx)
    }
}

// MARK: - Figures

private enum SwarmFigures {
    static let shapeTints: [UInt32] = [0xFF5F8F, 0xFFC247, 0x3AC4FF, 0x7CF0A8]
    static let letterTints: [UInt32] = [0xA46BFF, 0x3AC4FF, 0x21D4A8, 0xFFC247, 0xFF7A5C, 0xFF5FA2]
    static let letters: [Character] = ["M", "O", "T", "I", "O", "N"]

    static func count(set: Int) -> Int { set == 1 ? letters.count : 4 }

    static func tint(set: Int, index: Int) -> BackgroundRGB {
        let list = set == 1 ? letterTints : shapeTints
        return BackgroundRGB(hex: list[index % list.count])
    }

    /// The figure in a unit-ish box; it is fitted to the stage afterwards.
    static func path(set: Int, index: Int) -> Path {
        if set == 1 { return glyph(letters[index % letters.count]) }
        switch index % 4 {
        case 0: return heart()
        case 1: return star()
        case 2: return ring()
        default: return bolt()
        }
    }

    private static func heart() -> Path {
        var p = Path()
        let samples = 90
        for i in 0..<samples {
            let a = Double(i) / Double(samples) * BackgroundMath.tau
            let x = 16 * pow(sin(a), 3)
            let y = -(13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a))
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }

    private static func star() -> Path {
        var p = Path()
        for i in 0..<10 {
            let angle = -Double.pi / 2 + Double(i) * .pi / 5
            let r = i % 2 == 0 ? 1.0 : 0.46
            let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }

    private static func ring() -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        p.addEllipse(in: CGRect(x: -0.56, y: -0.56, width: 1.12, height: 1.12))
        return p
    }

    private static func bolt() -> Path {
        var p = Path()
        let points: [(CGFloat, CGFloat)] = [(0.2, -1), (-0.62, 0.14), (-0.06, 0.14), (-0.3, 1), (0.62, -0.22), (0.06, -0.22)]
        for (i, point) in points.enumerated() {
            if i == 0 { p.move(to: CGPoint(x: point.0, y: point.1)) } else { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
        }
        p.closeSubpath()
        return p
    }

    private static func glyph(_ character: Character) -> Path {
        var base = UIFont.systemFont(ofSize: 200, weight: .heavy)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            base = UIFont(descriptor: rounded, size: 200)
        }
        let font = base as CTFont
        var chars = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count),
              let outline = CTFontCreatePathForGlyph(font, glyphs[0], nil) else { return ring() }
        // Glyph outlines are y-up.
        return Path(outline).applying(CGAffineTransform(scaleX: 1, y: -1))
    }

    static func halton(_ index: Int, _ base: Int) -> Double {
        var f = 1.0
        var r = 0.0
        var i = index
        while i > 0 {
            f /= Double(base)
            r += f * Double(i % base)
            i /= base
        }
        return r
    }

    /// `count` evenly spread points inside the figure, fitted to the stage.
    static func targets(set: Int, index: Int, count: Int, size: CGSize) -> [CGPoint] {
        let raw = path(set: set, index: index)
        let box = raw.boundingRect
        guard box.width > 0, box.height > 0, count > 0 else { return [] }
        let side = min(size.width, size.height) * 0.6
        let scale = side / max(box.width, box.height)
        let centre = CGPoint(x: size.width / 2, y: size.height * 0.48)
        var points: [CGPoint] = []
        points.reserveCapacity(count)
        func fitted(_ p: CGPoint) -> CGPoint {
            CGPoint(x: centre.x + (p.x - box.midX) * scale, y: centre.y + (p.y - box.midY) * scale)
        }
        // A third of the particles sit in a band along the outline so the silhouette reads crisply.
        let band = raw.strokedPath(StrokeStyle(lineWidth: max(box.width, box.height) * 0.08))
        let rim = count * 3 / 10
        var k = 1
        while points.count < rim, k < count * 60 {
            let p = CGPoint(x: box.minX + box.width * CGFloat(halton(k, 2)), y: box.minY + box.height * CGFloat(halton(k, 3)))
            k += 1
            guard band.contains(p), raw.contains(p, eoFill: true) else { continue }
            points.append(fitted(p))
        }
        k = 1
        while points.count < count, k < count * 40 {
            let p = CGPoint(x: box.minX + box.width * CGFloat(halton(k, 5)), y: box.minY + box.height * CGFloat(halton(k, 7)))
            k += 1
            guard raw.contains(p, eoFill: true) else { continue }
            points.append(fitted(p))
        }
        while points.count < count { points.append(centre) }
        return points
    }
}

// MARK: - Simulation

private final class SwarmModel {
    private enum Phase {
        case forming
        case roaming
    }

    let clock = BackgroundClock()
    private(set) var positions: [CGPoint] = []
    private(set) var velocities: [CGVector] = []
    private var targets: [CGPoint] = []
    private var phase = Phase.forming
    private var phaseStart: Double = 100
    private(set) var figure = 0
    private var key = ""
    private var size: CGSize = .zero
    private var set = 0
    private var rng = BackgroundRNG(seed: 41)

    /// 0 while roaming, 1 once the figure has locked in (drives the glow behind it).
    private(set) var formed: Double = 0

    func step(now: Double, size newSize: CGSize, count: Int, set newSet: Int, hold: Double, stiffness: Double, frozen: Bool) {
        let t = clock.advance(to: now, speed: 1)
        let newKey = "\(Int(newSize.width))x\(Int(newSize.height))-\(count)-\(newSet)"
        if newKey != key {
            let fresh = key.isEmpty
            key = newKey
            size = newSize
            if set != newSet { figure = 0 }
            set = newSet
            targets = SwarmFigures.targets(set: set, index: figure, count: count, size: size)
            if fresh || positions.count != count {
                rng = BackgroundRNG(seed: 41)
                positions = (0..<count).map { i in
                    frozen ? targets[i] : CGPoint(x: size.width * CGFloat(rng.unit()), y: size.height * CGFloat(rng.unit()))
                }
                velocities = [CGVector](repeating: .zero, count: count)
            }
            phase = .forming
            phaseStart = t
        }
        if frozen {
            formed = 1
            return
        }
        let dt = CGFloat(clock.delta)
        guard dt > 0, positions.count == targets.count else { return }

        switch phase {
        case .forming:
            let age = t - phaseStart
            let k = CGFloat(stiffness)
            let c = 2 * k.squareRoot() * 0.75
            for i in positions.indices {
                var v = velocities[i]
                let p = positions[i]
                if age > 0.45 * BackgroundMath.rand(i, 2601) {
                    // The settled figure keeps breathing: a slow swell plus a tiny private orbit.
                    let swell = 1 + 0.025 * CGFloat(sin(t * 1.7))
                    let tx = size.width / 2 + (targets[i].x - size.width / 2) * swell + 1.3 * CGFloat(cos(t * 2.3 + Double(i)))
                    let ty = size.height * 0.48 + (targets[i].y - size.height * 0.48) * swell + 1.3 * CGFloat(sin(t * 1.9 + Double(i) * 1.7))
                    v.dx += (k * (tx - p.x) - c * v.dx) * dt
                    v.dy += (k * (ty - p.y) - c * v.dy) * dt
                } else {
                    v.dx *= 1 - 2 * dt
                    v.dy *= 1 - 2 * dt
                }
                velocities[i] = v
                positions[i] = CGPoint(x: p.x + v.dx * dt, y: p.y + v.dy * dt)
            }
            formed += (BackgroundMath.smoothstep(0.5, 1.3, age) - formed) * clock.follow(rate: 8)
            if age > 1.3 + hold {
                dissolve(from: CGPoint(
                    x: size.width * CGFloat(rng.range(0.3...0.7)), y: size.height * CGFloat(rng.range(0.35...0.65))
                ))
            }
        case .roaming:
            let age = t - phaseStart
            for i in positions.indices {
                var v = velocities[i]
                var p = positions[i]
                // A curling flow field carries the loose particles; a weak pull keeps them on stage.
                let angle = BackgroundMath.valueNoise(Double(p.x) * 0.011 + t * 0.2, Double(p.y) * 0.011 - t * 0.15) * BackgroundMath.tau * 2
                let ux = CGFloat(cos(angle)) * 70 + (size.width / 2 - p.x) * 0.5
                let uy = CGFloat(sin(angle)) * 70 + (size.height / 2 - p.y) * 0.5
                let rate = min(1.6 * dt, 1)
                v.dx += (ux - v.dx) * rate
                v.dy += (uy - v.dy) * rate
                p.x += v.dx * dt
                p.y += v.dy * dt
                velocities[i] = v
                positions[i] = p
            }
            formed += (0 - formed) * clock.follow(rate: 10)
            if age > 1.3 {
                figure = (figure + 1) % SwarmFigures.count(set: set)
                var next = SwarmFigures.targets(set: set, index: figure, count: positions.count, size: size)
                next.shuffle(using: &rng)
                targets = next
                phase = .forming
                phaseStart = t
            }
        }
    }

    /// Blow the figure apart from `point` (the automatic cycle and a tap both end the hold this way).
    func dissolve(from point: CGPoint) {
        guard !positions.isEmpty else { return }
        for i in positions.indices {
            let dx = positions[i].x - point.x
            let dy = positions[i].y - point.y
            let d = max(hypot(dx, dy), 1)
            let kick = 420 / (1 + d / 70) * CGFloat(0.6 + 0.4 * BackgroundMath.rand(i, 2602))
            velocities[i].dx += dx / d * kick - dy / d * kick * 0.35
            velocities[i].dy += dy / d * kick + dx / d * kick * 0.35
        }
        phase = .roaming
        phaseStart = clock.phase
    }
}

private struct ShapeSwarmDemo: View {
    let ctx: DemoContext
    @State private var model = SwarmModel()

    var body: some View {
        let set = ctx.int("set")
        ZStack {
            LinearGradient(colors: [Color(hex: 0x07060F), Color(hex: 0x15112B), Color(hex: 0x0A0916)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    model.step(
                        now: now, size: size, count: max(ctx.int("count"), 10), set: set, hold: ctx["hold"],
                        stiffness: max(ctx["stiffness"], 1), frozen: ctx.isStill
                    )
                    SwarmPainter.draw(
                        &context, size: size, positions: model.positions, velocities: model.velocities,
                        tint: SwarmFigures.tint(set: set, index: model.figure), formed: model.formed
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            Haptics.tap(.medium)
            model.dissolve(from: location)
        }
        .backgroundsHint(L("Tap to blow the swarm apart", "点击把粒子群炸散"), ctx)
    }
}

private enum SwarmPainter {
    static func draw(
        _ context: inout GraphicsContext, size: CGSize, positions: [CGPoint], velocities: [CGVector], tint: BackgroundRGB, formed: Double
    ) {
        if formed > 0.01 {
            context.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.backgroundsGlow(
                    at: CGPoint(x: size.width / 2, y: size.height * 0.48), radius: min(size.width, size.height) * 0.56,
                    color: tint.color(0.26 * formed)
                )
            }
        }
        let levels = 4
        var bins = [Path](repeating: Path(), count: levels)
        for i in positions.indices {
            let p = positions[i]
            let v = velocities[i]
            let speed = hypot(v.dx, v.dy)
            let level = min(Int(speed / 70), levels - 1)
            // A streak along the velocity; a settled particle collapses to a round dot.
            let k = min(0.028, 16 / max(speed, 1))
            bins[level].move(to: CGPoint(x: p.x - v.dx * k, y: p.y - v.dy * k))
            bins[level].addLine(to: CGPoint(x: p.x + 0.01, y: p.y))
        }
        let white = BackgroundRGB(1, 1, 1)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.blendMode = .plusLighter
            for level in 0..<levels {
                layer.stroke(bins[level], with: .color(tint.color(0.55)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        for level in 0..<levels {
            let color = tint.mix(white, 0.15 + 0.28 * Double(level)).color()
            context.stroke(bins[level], with: .color(color), style: StrokeStyle(lineWidth: 2.6 - 0.3 * CGFloat(level), lineCap: .round))
        }
    }
}
