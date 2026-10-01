import SwiftUI

extension Effect {
    static let loadingAtomOrbit = Effect(
        id: "loading.atom-orbit",
        category: .loading,
        interaction: .loop,
        name: L("Atom Orbits", "原子轨道"),
        summary: L("Electrons with comet tails circle a pulsing nucleus on three tilted orbits, passing behind and in front of it.", "拖着彗尾的电子沿三条倾斜轨道环绕搏动的原子核，时而绕到核后，时而掠过核前。"),
        prompt: L(
            "A classic atom, 190 pt wide. Three elliptical orbits (92 × 31 pt) are rotated 0°, 60° and 120° about a nucleus of five glossy coral and indigo nucleons that turn slowly and swell 6% every 0.9 s inside a soft halo. One electron rides each orbit at about 0.7 turns per second, each orbit at its own rate so they never line up. Depth is real: the far half of every orbit is drawn dimmer and behind the nucleus, the near half in front; an electron shrinks to 72% and fades on the far side, then grows to 118% as it sweeps across the front. Each drags a 14-sample comet tail that tapers and fades, and the whole atom precesses 6° per second. Scientific, weightless, endlessly busy.",
            "一个 190 pt 宽的经典原子图形。三条椭圆轨道（92 × 31 pt）分别旋转 0°、60°、120°，围绕由五颗带高光的珊瑚色与靛蓝核子组成的原子核；核子缓慢转动，每 0.9 秒在柔和光晕里鼓胀 6%。每条轨道上有一颗电子，约每秒 0.7 圈，各轨道速度略有不同，因此永不对齐。纵深是真实的：轨道远侧的半圈更暗、位于核后，近侧半圈位于核前；电子绕到远侧时缩到 72% 并变淡，掠过前方时放大到 118%。每颗电子拖着 14 个采样点组成、渐细渐淡的彗尾，整个原子每秒进动 6°。科学感、失重、永不停歇。"
        ),
        implementation: L(
            "A TimelineView drives one Canvas. Every electron and tail sample becomes a sprite with a depth (the sine of its orbital angle); sprites and orbit halves with negative depth are painted before the nucleus, the rest after it.",
            "TimelineView 驱动一张 Canvas。每颗电子与每个彗尾采样点都是一个带深度（轨道角的正弦）的精灵；深度为负的精灵和轨道半圈先于原子核绘制，其余的画在原子核之后。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.drawLayer", "CGAffineTransform", "radialGradient"],
        tags: ["atom", "orbit", "electron", "science", "原子", "轨道", "电子", "科学"],
        params: [
            .slider("speed", L("Orbit speed", "公转速度"), 0.2...1.6, default: 0.7, unit: "rev/s"),
            .slider("electrons", L("Electrons per orbit", "每轨电子数"), 1...3, default: 1, step: 1, decimals: 0),
            .slider("tilt", L("Orbit tilt", "轨道倾斜"), 0.18...0.6, default: 0.34),
            .toggle("tails", L("Comet tails", "彗尾"), default: true),
        ]
    ) { ctx in
        AtomOrbitDemo(ctx: ctx)
    }
}

private struct AtomOrbitDemo: View {
    let ctx: DemoContext
    @State private var clock = LoadingPhaseClock()
    @State private var started = Date()

    var body: some View {
        let speed: Double = max(ctx["speed"], 0.05)
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let turns: Double = ctx.isStill ? 0.31 : clock.phase(at: timeline.date, rate: speed)
            let seconds: Double = ctx.isStill ? 0.4 : timeline.date.timeIntervalSince(started)
            AtomCanvas(
                turns: turns,
                seconds: seconds,
                electrons: max(ctx.int("electrons"), 1),
                tilt: ctx.cg("tilt"),
                tails: ctx.bool("tails")
            )
            .frame(width: 250, height: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx["speed"]) { old, _ in
            clock.rebase(at: .now, oldRate: max(old, 0.05))
        }
    }
}

private struct AtomSprite {
    var point: CGPoint
    var radius: CGFloat
    var color: Color
    var opacity: Double
    var depth: Double
    var isHead: Bool
}

private struct AtomCanvas: View {
    let turns: Double
    let seconds: Double
    let electrons: Int
    let tilt: CGFloat
    let tails: Bool

    private static let semiMajor: CGFloat = 92
    private static let colors: [Color] = [Palette.sky, Palette.mint, Palette.violet]
    private static let rates: [Double] = [1, 0.83, 1.19]
    private static let offsets: [Double] = [0, 0.37, 0.71]

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let precession: Double = seconds * 6 * .pi / 180
            let a: CGFloat = AtomCanvas.semiMajor
            let b: CGFloat = a * tilt

            var sprites: [AtomSprite] = []
            var transforms: [CGAffineTransform] = []
            for orbit in 0..<3 {
                let rotation: Double = Double(orbit) * .pi / 3 + precession
                let transform = CGAffineTransform(translationX: centre.x, y: centre.y).rotated(by: CGFloat(rotation))
                transforms.append(transform)
                for electron in 0..<electrons {
                    let base: Double = turns * AtomCanvas.rates[orbit] + AtomCanvas.offsets[orbit] + Double(electron) / Double(electrons)
                    let samples: Int = tails ? 14 : 0
                    for sample in stride(from: samples, through: 0, by: -1) {
                        let phi: Double = (base - Double(sample) * 0.011) * 2 * .pi
                        let depth: Double = sin(phi)
                        let local = CGPoint(x: a * CGFloat(cos(phi)), y: b * CGFloat(depth))
                        let fade: Double = 1 - Double(sample) / 15
                        let scale: CGFloat = CGFloat(0.95 + 0.23 * depth)
                        sprites.append(AtomSprite(
                            point: local.applying(transform),
                            radius: (sample == 0 ? 6.5 : 5 * CGFloat(fade)) * scale,
                            color: AtomCanvas.colors[orbit],
                            opacity: (sample == 0 ? 1 : 0.5 * fade * fade) * (0.72 + 0.28 * (depth + 1) / 2),
                            depth: depth,
                            isHead: sample == 0
                        ))
                    }
                }
            }

            // Far halves of the orbits, then far sprites.
            for transform in transforms {
                AtomCanvas.strokeHalf(&context, a: a, b: b, transform: transform, near: false)
            }
            for sprite in sprites where sprite.depth < 0 {
                AtomCanvas.draw(sprite, in: &context)
            }

            AtomCanvas.drawNucleus(&context, centre: centre, seconds: seconds)

            for transform in transforms {
                AtomCanvas.strokeHalf(&context, a: a, b: b, transform: transform, near: true)
            }
            for sprite in sprites where sprite.depth >= 0 {
                AtomCanvas.draw(sprite, in: &context)
            }
        }
    }

    private static func strokeHalf(_ context: inout GraphicsContext, a: CGFloat, b: CGFloat, transform: CGAffineTransform, near: Bool) {
        var path = Path()
        let steps: Int = 36
        for step in 0...steps {
            // The near half is the lower half of the unrotated ellipse (positive local y).
            let phi: Double = (near ? 0 : Double.pi) + Double.pi * Double(step) / Double(steps)
            let point = CGPoint(x: a * CGFloat(cos(phi)), y: b * CGFloat(sin(phi))).applying(transform)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(
            path,
            with: .color(Color.primary.opacity(near ? 0.3 : 0.12)),
            style: StrokeStyle(lineWidth: near ? 1.5 : 1.1, lineCap: .round)
        )
    }

    private static func draw(_ sprite: AtomSprite, in context: inout GraphicsContext) {
        let r: CGFloat = max(sprite.radius, 0.4)
        let rect = CGRect(x: sprite.point.x - r, y: sprite.point.y - r, width: r * 2, height: r * 2)
        guard sprite.isHead else {
            context.fill(Path(ellipseIn: rect), with: .color(sprite.color.opacity(sprite.opacity)))
            return
        }
        let halo = rect.insetBy(dx: -r * 1.5, dy: -r * 1.5)
        context.fill(
            Path(ellipseIn: halo),
            with: .radialGradient(
                Gradient(colors: [sprite.color.opacity(0.45 * sprite.opacity), sprite.color.opacity(0)]),
                center: sprite.point,
                startRadius: r * 0.5,
                endRadius: r * 2.5
            )
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [Color.white, sprite.color, sprite.color.mix(with: .black, by: 0.2)]),
                center: CGPoint(x: sprite.point.x - r * 0.3, y: sprite.point.y - r * 0.35),
                startRadius: 0,
                endRadius: r * 1.5
            )
        )
    }

    private static func drawNucleus(_ context: inout GraphicsContext, centre: CGPoint, seconds: Double) {
        let beat: Double = 0.5 - 0.5 * cos(seconds * 2 * .pi / 0.9)
        let swell: CGFloat = 1 + 0.06 * CGFloat(beat)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 10))
            let r: CGFloat = 25 * swell
            layer.fill(
                Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)),
                with: .color(Palette.coral.opacity(0.4 + 0.25 * beat))
            )
        }

        // Four nucleons on a slowly turning ring and one in the middle, alternating colours.
        let spin: Double = seconds * 0.5
        for index in 0..<5 {
            let onRing: Bool = index < 4
            let angle: Double = spin + Double(index) * .pi / 2
            let orbit: CGFloat = onRing ? 8.5 * swell : 0
            let point = CGPoint(x: centre.x + orbit * CGFloat(cos(angle)), y: centre.y + orbit * CGFloat(sin(angle)) * 0.9)
            let r: CGFloat = (onRing ? 9 : 9.5) * swell
            let tint: Color = index % 2 == 0 ? Palette.coral : Palette.indigo
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                with: .radialGradient(
                    Gradient(colors: [tint.mix(with: .white, by: 0.75), tint, tint.mix(with: .black, by: 0.3)]),
                    center: CGPoint(x: point.x - r * 0.35, y: point.y - r * 0.4),
                    startRadius: 0,
                    endRadius: r * 1.45
                )
            )
        }
    }
}
