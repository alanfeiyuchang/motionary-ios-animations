import SwiftUI
import UIKit

extension Effect {
    static let morphParticlesAssemble = Effect(
        id: "morph.particles-assemble",
        category: .morph,
        interaction: .loop,
        name: L("Particles Assemble", "粒子聚合成形"),
        summary: L(
            "Hundreds of glowing particles spring into a glyph, hold it shimmering, then burst apart and regroup as the next one.",
            "数百颗发光粒子乘弹簧聚成一个图形，微微闪烁地停住，再炸散并重组成下一个。"
        ),
        prompt: L(
            "A dark panel holding 700 luminous particles. Each owns a target sampled from the filled silhouette of a glyph (bolt, heart, star, paper plane) and is pulled to it by its own spring, stiffness 60 scaled 0.6–1.4× per particle and damped to 62% of critical, so the shape condenses unevenly and settles with a faint wobble. Targets are sorted left to right, so a blue-violet-pink gradient reads cleanly across every glyph. After a 1.6 s hold the swarm bursts outward at up to 320 pt/s with a swirl, drifts under drag for 0.55 s, then springs into the next glyph. Moving particles draw as streaks along their velocity, additively blended over a blurred glow. A tap bursts from the touch point; a dragged finger repels particles within 64 pt. Alive, weightless, precise on arrival.",
            "深色面板里有 700 颗发光粒子：每颗粒子都有一个从图形实心轮廓（闪电、爱心、星形、纸飞机）中采样的目标点，并由各自的弹簧拉向它：刚度 60，按粒子缩放 0.6–1.4 倍，阻尼为临界值的 62%，图形因此不均匀地凝聚，落定时略带轻颤。目标点按从左到右排序，蓝紫粉渐变得以干净地横贯每个图形。停留 1.6 秒后，粒子群带着旋涡以最高每秒 320pt 向外炸开，在阻力下漂 0.55 秒，再弹向下一个图形。运动中的粒子沿速度方向画成拖尾，加色叠在模糊辉光上。点击从触点炸开；拖动手指会推开 64pt 内的粒子。"
        ),
        implementation: L(
            "Each glyph is rasterised once from an SF Symbol into a small alpha bitmap and its filled pixels become targets. A reference-type simulation integrates per-particle springs, the burst impulse and the finger's repulsion with a clamped time step inside a TimelineView; a Canvas draws the streaks with plusLighter over a blurred layer.",
            "每个图形先由 SF Symbol 光栅化成一张小的透明度位图，实心像素即目标点。引用类型的模拟器在 TimelineView 中以限幅步长积分每颗粒子的弹簧、爆散冲量与手指斥力；Canvas 用 plusLighter 在模糊图层之上绘制拖尾。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "GraphicsContext.blendMode", "UIGraphicsImageRenderer", "UIGestureRecognizerRepresentable"],
        tags: ["particles", "assemble", "swarm", "logo reveal", "scatter", "粒子", "聚合", "汇聚", "打散"],
        params: [
            .slider("count", L("Particles", "粒子数量"), 200...1400, default: 700, step: 50, decimals: 0),
            .slider("stiffness", L("Spring stiffness", "弹簧刚度"), 20...160, default: 60, decimals: 0),
            .slider("burst", L("Burst speed", "爆散速度"), 100...700, default: 320, decimals: 0, unit: "pt/s"),
            .slider("hold", L("Hold time", "停留时间"), 0.4...4, default: 1.6, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        ParticlesAssembleDemo(ctx: ctx)
    }
}

private enum ParticleField {
    static let size = CGSize(width: 316, height: 306)
    static let center = CGPoint(x: 158, y: 146)
    static let radius: CGFloat = 96
    static let symbols: [String] = ["bolt.fill", "heart.fill", "star.fill", "paperplane.fill"]

    /// Filled pixels of each glyph in unit coordinates (−1…1), rasterised once.
    static let masks: [[CGPoint]] = symbols.map { mask(of: $0) }

    private static func mask(of symbol: String) -> [CGPoint] {
        let side = 88
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let box = CGSize(width: side, height: side)
        let image: UIImage = UIGraphicsImageRenderer(size: box, format: format).image { _ in
            let configuration = UIImage.SymbolConfiguration(pointSize: 60, weight: .bold)
            guard let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
            let fit: CGFloat = min(CGFloat(side - 6) / glyph.size.width, CGFloat(side - 6) / glyph.size.height)
            let width: CGFloat = glyph.size.width * fit
            let height: CGFloat = glyph.size.height * fit
            glyph.draw(in: CGRect(x: (CGFloat(side) - width) / 2, y: (CGFloat(side) - height) / 2, width: width, height: height))
        }
        guard let cgImage = image.cgImage else { return fallback }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return fallback }
        var points: [CGPoint] = []
        for y in 0..<side {
            for x in 0..<side where pixels[(y * side + x) * 4 + 3] > 127 {
                points.append(CGPoint(
                    x: (CGFloat(x) + 0.5) / CGFloat(side) * 2 - 1,
                    y: (CGFloat(y) + 0.5) / CGFloat(side) * 2 - 1
                ))
            }
        }
        return points.count > 50 ? points : fallback
    }

    /// A disc, should a symbol ever fail to rasterise.
    private static let fallback: [CGPoint] = (0..<900).map { index in
        let angle = Double(index) * 2.399963
        let radius = sqrt(Double(index) / 900) * 0.8
        return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
    }
}

private final class ParticleSwarm {
    private(set) var count = 0
    var x: [Double] = []
    var y: [Double] = []
    var vx: [Double] = []
    var vy: [Double] = []
    private var seed: [Double] = []
    /// `targets[shape][particle]`, in panel points.
    private var targets: [[CGPoint]] = []
    private(set) var shape = 0
    /// Seconds since the current glyph started assembling; negative while the burst is drifting.
    private var clock: Double = 0
    private var drifting = false
    private var time: Double = 0
    private var last: TimeInterval?
    var finger: CGPoint?

    init(count: Int, settled: Bool) {
        rebuild(count: count, settled: settled)
    }

    private static func hash(_ index: Int, _ salt: Int) -> Double {
        var value = UInt64(truncatingIfNeeded: index &* 374_761_393 &+ salt &* 668_265_263)
        value = (value ^ (value >> 13)) &* 1_274_126_177
        value ^= value >> 16
        return Double(value % 100_000) / 100_000
    }

    func rebuild(count newCount: Int, settled: Bool) {
        count = newCount
        seed = (0..<count).map { ParticleSwarm.hash($0, 7) }
        targets = ParticleField.masks.enumerated().map { shapeIndex, mask in
            var picks: [CGPoint] = (0..<count).map { index in
                let pixel: CGPoint = mask[Int(ParticleSwarm.hash(index, 31 + shapeIndex) * Double(mask.count)) % mask.count]
                let jitterX = (ParticleSwarm.hash(index, 53 + shapeIndex) - 0.5) * 0.024
                let jitterY = (ParticleSwarm.hash(index, 71 + shapeIndex) - 0.5) * 0.024
                return CGPoint(
                    x: ParticleField.center.x + (pixel.x + jitterX) * ParticleField.radius,
                    y: ParticleField.center.y + (pixel.y + jitterY) * ParticleField.radius
                )
            }
            // Left to right, so particle index (and with it the colour) sweeps across the glyph.
            picks.sort { $0.x < $1.x }
            return picks
        }
        x = [Double](repeating: 0, count: count)
        y = [Double](repeating: 0, count: count)
        vx = [Double](repeating: 0, count: count)
        vy = [Double](repeating: 0, count: count)
        for index in 0..<count {
            if settled {
                x[index] = Double(targets[shape][index].x)
                y[index] = Double(targets[shape][index].y)
            } else {
                x[index] = ParticleSwarm.hash(index, 3) * Double(ParticleField.size.width)
                y[index] = ParticleSwarm.hash(index, 5) * Double(ParticleField.size.height)
            }
        }
        clock = settled ? 1.2 : 0
        drifting = false
    }

    /// Blow the swarm apart from `origin` and queue the next glyph.
    func burst(from origin: CGPoint, speed: Double) {
        for index in 0..<count {
            let dx: Double = x[index] - Double(origin.x)
            let dy: Double = y[index] - Double(origin.y)
            let distance: Double = max((dx * dx + dy * dy).squareRoot(), 1)
            let power: Double = speed * (0.35 + 0.65 * seed[index])
            let swirl: Double = 0.55
            vx[index] += (dx / distance - dy / distance * swirl) * power
            vy[index] += (dy / distance + dx / distance * swirl) * power
        }
        shape = (shape + 1) % ParticleField.masks.count
        drifting = true
        clock = 0
    }

    func step(to date: Date, count wanted: Int, stiffness: Double, burstSpeed: Double, hold: Double) {
        if wanted != count { rebuild(count: wanted, settled: false) }
        let now: TimeInterval = date.timeIntervalSinceReferenceDate
        let elapsed: Double = min(max(now - (last ?? now), 0), 1.0 / 30.0)
        last = now
        guard elapsed > 0 else { return }
        time += elapsed
        clock += elapsed
        if drifting, clock > 0.55 {
            drifting = false
            clock = 0
        } else if !drifting, clock > 1.1 + hold {
            burst(from: ParticleField.center, speed: burstSpeed)
        }
        let steps = 2
        let dt: Double = elapsed / Double(steps)
        for _ in 0..<steps {
            integrate(dt: dt, stiffness: stiffness)
        }
    }

    private func integrate(dt: Double, stiffness: Double) {
        let current: [CGPoint] = targets[shape]
        let push: CGPoint? = finger
        for index in 0..<count {
            var ax: Double = 0
            var ay: Double = 0
            if drifting {
                ax = -vx[index] * 2.4
                ay = -vy[index] * 2.4
            } else {
                let k: Double = stiffness * (0.6 + 0.8 * seed[index])
                let c: Double = 2 * k.squareRoot() * 0.62
                let shimmer: Double = sin(time * 2.2 + seed[index] * 40) * 0.5
                ax = k * (Double(current[index].x) + shimmer - x[index]) - c * vx[index]
                ay = k * (Double(current[index].y) - shimmer - y[index]) - c * vy[index]
            }
            if let push {
                let dx: Double = x[index] - Double(push.x)
                let dy: Double = y[index] - Double(push.y)
                let distance: Double = max((dx * dx + dy * dy).squareRoot(), 0.5)
                if distance < 64 {
                    let falloff: Double = 1 - distance / 64
                    ax += dx / distance * falloff * falloff * 9000
                    ay += dy / distance * falloff * falloff * 9000
                }
            }
            vx[index] += ax * dt
            vy[index] += ay * dt
            x[index] += vx[index] * dt
            y[index] += vy[index] * dt
        }
    }
}

private struct ParticlesAssembleDemo: View {
    let ctx: DemoContext
    @State private var swarm: ParticleSwarm
    @State private var touchStart: CGPoint = .zero

    init(ctx: DemoContext) {
        self.ctx = ctx
        _swarm = State(initialValue: ParticleSwarm(count: max(ctx.int("count"), 50), settled: ctx.isStill))
    }

    var body: some View {
        VStack(spacing: 10) {
            panel
            DemoHint(text: L("Tap to burst · drag to push", "点击炸散 · 拖动推开粒子"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panel: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
            let _ = advance(to: timeline.date)
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0A0E24), Color(hex: 0x161A3E)], startPoint: .top, endPoint: .bottom)
                RadialGradient(
                    colors: [Palette.violet.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.5, y: 0.48), startRadius: 0, endRadius: 190
                )
                ParticleCanvas(swarm: swarm, tick: timeline.date)
                ParticleDots(current: swarm.shape)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 14)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            if !ctx.isPreview { Haptics.tap(.rigid) }
            swarm.burst(from: location, speed: ctx["burst"])
        }
        .gesture(PageSafePan(
            directions: [.up, .down, .left, .right],
            onChanged: { translation in
                swarm.finger = CGPoint(x: touchStart.x + translation.width, y: touchStart.y + translation.height)
            },
            onEnded: { _ in swarm.finger = nil },
            onBegan: { touchStart = $0 }
        ))
        .morphScreen()
    }

    private func advance(to date: Date) {
        guard !ctx.isStill else { return }
        swarm.step(
            to: date,
            count: max(ctx.int("count"), 50),
            stiffness: ctx["stiffness"],
            burstSpeed: ctx["burst"],
            hold: ctx["hold"]
        )
    }
}

private struct ParticleCanvas: View {
    let swarm: ParticleSwarm
    /// The swarm is a reference, so the view needs a value that changes every frame to be redrawn.
    let tick: Date

    private static let stops: [[Double]] = [
        [0.24, 0.78, 1.00], [0.45, 0.50, 1.00], [0.70, 0.42, 1.00], [1.00, 0.40, 0.68],
    ]

    private static func color(_ u: Double) -> Color {
        let scaled: Double = min(max(u, 0), 0.9999) * 3
        let index = Int(scaled)
        let t: Double = scaled - Double(index)
        let a: [Double] = stops[index]
        let b: [Double] = stops[index + 1]
        return Color(red: a[0] + (b[0] - a[0]) * t, green: a[1] + (b[1] - a[1]) * t, blue: a[2] + (b[2] - a[2]) * t)
    }

    /// 24 colour buckets, so particles batch into a few paths per frame.
    private static let palette: [Color] = (0..<24).map { color(Double($0) / 23) }

    var body: some View {
        Canvas { context, _ in
            let count: Int = swarm.count
            guard count > 0 else { return }
            var streaks = [Path](repeating: Path(), count: ParticleCanvas.palette.count)
            for index in 0..<count {
                let bucket: Int = index * ParticleCanvas.palette.count / count
                let head = CGPoint(x: swarm.x[index], y: swarm.y[index])
                let tail = CGPoint(x: swarm.x[index] - swarm.vx[index] * 0.03, y: swarm.y[index] - swarm.vy[index] * 0.03)
                streaks[bucket].move(to: tail)
                streaks[bucket].addLine(to: head)
            }
            context.blendMode = .plusLighter
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                for (bucket, path) in streaks.enumerated() {
                    layer.stroke(path, with: .color(ParticleCanvas.palette[bucket].opacity(0.55)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
            }
            for (bucket, path) in streaks.enumerated() {
                context.stroke(path, with: .color(ParticleCanvas.palette[bucket].opacity(0.95)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ParticleDots: View {
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(ParticleField.symbols.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index == current ? 0.9 : 0.25))
                    .frame(width: index == current ? 16 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: current)
        .allowsHitTesting(false)
    }
}
