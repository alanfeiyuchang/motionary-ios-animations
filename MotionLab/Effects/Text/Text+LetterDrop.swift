import SwiftUI

extension Effect {
    static let textLetterDrop = Effect(
        id: "text.letter-drop",
        category: .text,
        interaction: .tap,
        name: L("Letter Drop", "字母坠落"),
        summary: L("The word lets go: letters fall, bounce, knock into each other and pile up, then fly back into place on a tap.", "整个词松手了：字母下落、弹跳、互相碰撞并堆成一堆，再点一下又飞回原位。"),
        prompt: L(
            "A heavy rounded word hangs in the upper part of the stage above a small open tray. On tap the letters let go in random order 50 ms apart: each falls under gravity (1800 pt/s²) with a push toward the tray and its own spin, bounces off its floor keeping 45% of its speed, rolls, collides with its neighbours as a round body and and comes to rest in a two-layer pile, because the tray is narrower than the word, tinted in its own accent colour once it has left home. A second tap calls them back: left to right, 50 ms apart, each letter is pulled to its home position by a spring (response 0.5 s, damping 0.7) while its rotation unwinds to upright and the colour drains back to the text colour, overshooting slightly before the word is whole again. Playful and physical.",
            "一个特粗圆体的词悬在舞台上半部，下方是一个敞口的小托盘。点击后字母按随机顺序、间隔50毫秒松手：每个字母在重力（1800pt/s²）下坠落，带一点朝向托盘的初速和各自的旋转，撞到盘底时保留45%的速度弹起，接着滚动，并作为圆形刚体与邻居相撞，由于托盘比这个词窄，最后叠成两层的一堆；离开原位后各自染上强调色。再点一次把它们叫回来：从左到右、间隔50毫秒，每个字母被弹簧（响应0.5秒、阻尼0.7）拉回原位，旋转同时回正，颜色褪回正文色，稍微过冲后整个词重新拼好。俏皮而有实感。"
        ),
        implementation: L(
            "Each glyph is a circular body with position, velocity, angle and spin, integrated in substeps inside a TimelineView: gravity, tray floor and wall bounces, pairwise overlap resolution with an impulse, then a spring back to the measured home position; a Canvas draws every glyph translated and rotated.",
            "每个字形是一个带位置、速度、角度与角速度的圆形刚体，在 TimelineView 中分子步积分：重力、地面与墙壁反弹、两两重叠分离并施加冲量，随后用弹簧拉回测得的原位；Canvas 把每个字形平移、旋转后绘出。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.resolve", "GraphicsContext.rotate(by:)", "Task"],
        tags: ["gravity", "fall", "pile", "physics", "collision", "坠落", "重力", "堆叠", "碰撞", "物理"],
        params: [
            .slider("gravity", L("Gravity", "重力"), 600...3200, default: 1800, decimals: 0, unit: " pt/s²"),
            .slider("bounce", L("Bounce", "弹性"), 0...0.8, default: 0.45),
            .slider("stagger", L("Stagger", "错开时间"), 0...0.12, default: 0.05, unit: "s"),
        ]
    ) { ctx in
        TextLetterDropDemo(ctx: ctx)
    }
}

private struct DropBody {
    var x: Double
    var y: Double
    var vx: Double = 0
    var vy: Double = 0
    var angle: Double = 0
    var spin: Double = 0
    var radius: Double
    var delay: Double = 0
    var free = false
}

/// The tray the letters fall into: a flat floor at `base` between walls at `center ± half` that start at `rim`.
private struct DropBowl {
    let base: Double
    let center: Double
    let half: Double
    let rim: Double

    func height(at x: Double) -> Double { base }
}

private struct DropSim {
    var last: Date?
    var now: Double = 0
    var modeStart: Double = 0
    var dropped = false
    var bodies: [DropBody] = []
}

private struct TextLetterDropDemo: View {
    let ctx: DemoContext
    @State private var sim = TextFXBox(DropSim())
    @State private var dropped = false

    private let accents: [Color] = [Palette.coral, Palette.amber, Palette.mint, Palette.sky, Palette.indigo, Palette.violet, Palette.pink]

    private var glyphs: [String] {
        (ctx.language == .zh ? "文字也有重量" : "GRAVITY").map { String($0) }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            Canvas { context, size in
                draw(&context, size: size, date: timeline.date)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            DemoHint(text: dropped ? L("Tap to lift them back", "点击把它们拉回去") : L("Tap to let go", "点击松手"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(dropped ? .light : .medium)
            toggle()
        }
        .autoplay(ctx.isPreview, every: 2.7, delay: 0.9) { toggle() }
    }

    private func toggle() {
        dropped.toggle()
        var state = sim.value
        state.dropped = dropped
        state.modeStart = state.now
        let stagger: Double = ctx["stagger"]
        let order: [Int] = Array(state.bodies.indices).shuffled()
        for (slot, index) in order.enumerated() {
            if dropped {
                state.bodies[index].delay = Double(slot) * stagger
                state.bodies[index].free = false
            } else {
                state.bodies[index].delay = Double(index) * stagger
            }
        }
        sim.value = state
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, size: CGSize, date: Date) {
        let letters = glyphs
        let fontSize: CGFloat = ctx.language == .zh ? 44 : 50
        let font: Font = .system(size: fontSize, weight: .black, design: .rounded)
        var plain: [GraphicsContext.ResolvedText] = []
        var tinted: [GraphicsContext.ResolvedText] = []
        var widths: [CGFloat] = []
        for (index, letter) in letters.enumerated() {
            let base = context.resolve(Text(verbatim: letter).font(font).foregroundColor(.primary))
            plain.append(base)
            tinted.append(context.resolve(Text(verbatim: letter).font(font).foregroundColor(accents[index % accents.count])))
            widths.append(base.measure(in: CGSize(width: 200, height: 200)).width)
        }
        let total: CGFloat = widths.reduce(0, +)
        let floor: CGFloat = size.height - 46
        let homeY: CGFloat = ctx.isStill ? size.height * 0.46 : size.height * 0.34
        var homes: [CGPoint] = []
        var cursor: CGFloat = (size.width - total) / 2
        for width in widths {
            homes.append(CGPoint(x: cursor + width / 2, y: homeY))
            cursor += width
        }

        // The letters land in a tray narrower than the word, so they have to pile up.
        let bowl = DropBowl(base: Double(floor), center: Double(size.width / 2), half: 112, rim: Double(floor) - 60)
        if !ctx.isStill {
            let left: CGFloat = CGFloat(bowl.center - bowl.half) - 1
            let right: CGFloat = CGFloat(bowl.center + bowl.half) + 1
            let bottom: CGFloat = floor + 1
            let corner: CGFloat = 16
            var tray = Path()
            tray.move(to: CGPoint(x: left, y: CGFloat(bowl.rim)))
            tray.addLine(to: CGPoint(x: left, y: bottom - corner))
            tray.addQuadCurve(to: CGPoint(x: left + corner, y: bottom), control: CGPoint(x: left, y: bottom))
            tray.addLine(to: CGPoint(x: right - corner, y: bottom))
            tray.addQuadCurve(to: CGPoint(x: right, y: bottom - corner), control: CGPoint(x: right, y: bottom))
            tray.addLine(to: CGPoint(x: right, y: CGFloat(bowl.rim)))
            context.stroke(tray, with: .color(Color.primary.opacity(0.18)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }

        var bodies: [DropBody] = homes.enumerated().map { index, home in
            DropBody(x: Double(home.x), y: Double(home.y), radius: Double(max(widths[index], fontSize * 0.74)) * 0.56)
        }
        if !ctx.isStill {
            bodies = step(homes: homes, seed: bodies, bowl: bowl, width: Double(size.width), date: date)
        }

        for index in bodies.indices {
            let body = bodies[index]
            let home = homes[index]
            let away: Double = min(hypot(body.x - Double(home.x), body.y - Double(home.y)) / 50, 1)
            var layer = context
            layer.translateBy(x: CGFloat(body.x), y: CGFloat(body.y))
            layer.rotate(by: .radians(body.angle))
            layer.draw(plain[index], at: .zero, anchor: .center)
            if away > 0.01 {
                layer.opacity = away
                layer.draw(tinted[index], at: .zero, anchor: .center)
            }
        }
    }

    // MARK: Simulation

    private func step(homes: [CGPoint], seed: [DropBody], bowl: DropBowl, width: Double, date: Date) -> [DropBody] {
        var state = sim.value
        defer { sim.value = state }
        if state.bodies.count != seed.count {
            state.bodies = seed
        }
        for index in seed.indices {
            state.bodies[index].radius = seed[index].radius
        }
        guard let last = state.last else {
            state.last = date
            return state.bodies
        }
        let dt: Double = min(max(date.timeIntervalSince(last), 0), 1.0 / 20.0)
        guard dt > 0 else { return state.bodies }
        state.last = date
        state.now += dt
        let sinceMode: Double = state.now - state.modeStart

        if state.dropped {
            fall(&state, sinceMode: sinceMode, dt: dt, bowl: bowl, width: width)
        } else {
            lift(&state, homes: homes, sinceMode: sinceMode, dt: dt)
        }
        return state.bodies
    }

    private func fall(_ state: inout DropSim, sinceMode: Double, dt: Double, bowl: DropBowl, width: Double) {
        let gravity: Double = ctx["gravity"]
        let bounce: Double = ctx["bounce"]
        for index in state.bodies.indices where !state.bodies[index].free && sinceMode >= state.bodies[index].delay {
            state.bodies[index].free = true
            // A push toward the middle, so every letter clears the rim of the tray.
            state.bodies[index].vx = -(state.bodies[index].x - bowl.center) * 1.7 + Double.random(in: -30...30)
            state.bodies[index].vy = Double.random(in: -120...0)
            state.bodies[index].spin = Double.random(in: -4...4)
        }
        let substeps = 4
        let h: Double = dt / Double(substeps)
        for _ in 0..<substeps {
            for index in state.bodies.indices where state.bodies[index].free {
                var body = state.bodies[index]
                body.vy += gravity * h
                body.x += body.vx * h
                body.y += body.vy * h
                body.angle += body.spin * h
                // Floor: bounce, then roll downhill toward the middle of the bowl.
                let floor: Double = bowl.height(at: body.x)
                if body.y + body.radius > floor {
                    body.y = floor - body.radius
                    if body.vy > 0 {
                        body.vy = body.vy > 60 ? -body.vy * bounce : 0
                    }
                    body.vx *= 0.975
                    body.spin += (body.vx / body.radius - body.spin) * 0.25
                    if abs(body.vx) < 4 { body.vx = 0 }
                }
                // Tray walls, below the rim.
                if body.y + body.radius * 0.5 > bowl.rim {
                    if body.x - body.radius < bowl.center - bowl.half {
                        body.x = bowl.center - bowl.half + body.radius
                        body.vx = abs(body.vx) * bounce
                    } else if body.x + body.radius > bowl.center + bowl.half {
                        body.x = bowl.center + bowl.half - body.radius
                        body.vx = -abs(body.vx) * bounce
                    }
                }
                body.spin *= 0.997
                state.bodies[index] = body
            }
            collide(&state, restitution: bounce * 0.5, bowl: bowl)
        }
    }

    private func collide(_ state: inout DropSim, restitution: Double, bowl: DropBowl) {
        let count = state.bodies.count
        guard count > 1 else { return }
        for first in 0..<(count - 1) where state.bodies[first].free {
            for second in (first + 1)..<count where state.bodies[second].free {
                var a = state.bodies[first]
                var b = state.bodies[second]
                let dx: Double = b.x - a.x
                let dy: Double = b.y - a.y
                let distance: Double = max((dx * dx + dy * dy).squareRoot(), 0.001)
                let overlap: Double = a.radius + b.radius - distance
                guard overlap > 0 else { continue }
                let nx: Double = dx / distance
                let ny: Double = dy / distance
                a.x -= nx * overlap * 0.5
                a.y -= ny * overlap * 0.5
                b.x += nx * overlap * 0.5
                b.y += ny * overlap * 0.5
                let approach: Double = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
                if approach < 0 {
                    let impulse: Double = -(1 + restitution) * approach / 2
                    a.vx -= impulse * nx
                    a.vy -= impulse * ny
                    b.vx += impulse * nx
                    b.vy += impulse * ny
                    // Resting contacts bleed energy so the pile settles.
                    a.vx *= 0.99
                    b.vx *= 0.99
                }
                a.y = min(a.y, bowl.base - a.radius)
                b.y = min(b.y, bowl.base - b.radius)
                if a.y + a.radius * 0.5 > bowl.rim {
                    a.x = min(max(a.x, bowl.center - bowl.half + a.radius), bowl.center + bowl.half - a.radius)
                }
                if b.y + b.radius * 0.5 > bowl.rim {
                    b.x = min(max(b.x, bowl.center - bowl.half + b.radius), bowl.center + bowl.half - b.radius)
                }
                state.bodies[first] = a
                state.bodies[second] = b
            }
        }
    }

    private func lift(_ state: inout DropSim, homes: [CGPoint], sinceMode: Double, dt: Double) {
        let omega: Double = 2 * Double.pi / 0.5
        let damping: Double = 0.7
        let substeps = 3
        let h: Double = dt / Double(substeps)
        for index in state.bodies.indices {
            var body = state.bodies[index]
            guard sinceMode >= body.delay else { continue }
            body.free = false
            let homeX: Double = Double(homes[index].x)
            let homeY: Double = Double(homes[index].y)
            // Unwind to the nearest upright orientation.
            let upright: Double = (body.angle / (2 * Double.pi)).rounded() * 2 * Double.pi
            for _ in 0..<substeps {
                body.vx += (-omega * omega * (body.x - homeX) - 2 * damping * omega * body.vx) * h
                body.vy += (-omega * omega * (body.y - homeY) - 2 * damping * omega * body.vy) * h
                body.spin += (-omega * omega * (body.angle - upright) - 2 * damping * omega * body.spin) * h
                body.x += body.vx * h
                body.y += body.vy * h
                body.angle += body.spin * h
            }
            state.bodies[index] = body
        }
    }
}
