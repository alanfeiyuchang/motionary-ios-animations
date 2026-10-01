import SwiftUI

extension Effect {
    static let inputsBubblePicker = Effect(
        id: "inputs.bubble-picker",
        category: .inputs,
        interaction: .tap,
        name: L("Floating Bubble Picker", "漂浮气泡选择器"),
        summary: L("Genre bubbles drift and jostle with soft collisions; tapping one swells it, fills it with colour and shoves the others aside.", "风格气泡缓缓漂浮、彼此软碰撞；点一个，它鼓起来填满颜色，把其他气泡挤开。"),
        prompt: L(
            "Nine labelled bubbles of slightly different sizes float in a loose cluster, each a pale tinted disc with a coloured rim. They are a live simulation: a weak pull toward the centre keeps them together, overlapping pairs push apart with a soft spring, velocity is damped, and a slow drift keeps the cluster breathing. Tapping a bubble selects it: its radius springs to 138% with a slight overshoot (stiffness 120, damping ratio about 0.65), the fill becomes a solid gradient, the label turns white and a small check appears above it. The growth shoves its neighbours outward, helped by a radial impulse of 180 pt/s that fades with distance, so the whole cluster visibly rearranges and settles within about a second. Tapping again deflates it and the others close back in. Light haptic on select, soft on deselect.",
            "九个大小略有差别的带字气泡松散地聚在一起漂浮，每个都是浅色圆片加一圈彩色描边。它们是实时模拟：一股微弱的向心力把它们拢在一起，重叠的两个气泡以软弹簧互相推开，速度带阻尼，并缓慢漂移。点击气泡即选中：半径以带轻微过冲的弹簧（刚度 120、阻尼比约 0.65）涨到 138%，填充变成实色渐变，文字转白，上方出现一个小勾。它的膨胀把邻居向外挤，再加上一股随距离衰减、180pt/s 的径向冲量，整团气泡重新排布，约一秒内安定。再点一次它瘪回去，其余重新靠拢。选中轻触觉，取消柔和触觉。"
        ),
        implementation: L(
            "A small physics object holds position, velocity and a sprung radius per bubble and is stepped from a TimelineView with a clamped time step: centre attraction, pairwise overlap repulsion, damping and wall clamping. The bubbles are ordinary SwiftUI views positioned from that state, so each one takes its own tap.",
            "一个小型物理对象保存每个气泡的位置、速度与带弹簧的半径，由 TimelineView 以限幅的时间步长推进：向心引力、两两重叠排斥、阻尼与边界限制。气泡是按该状态定位的普通 SwiftUI 视图，各自接收自己的点击。"
        ),
        apis: ["TimelineView", "position(_:)", "onTapGesture", "contentTransition(.numericText)", "LinearGradient"],
        tags: ["bubble", "picker", "physics", "collision", "genre", "onboarding", "气泡", "选择", "物理", "碰撞", "兴趣", "多选"],
        params: [
            .slider("grow", L("Selected scale", "选中放大"), 1.1...1.8, default: 1.38, unit: "×"),
            .slider("push", L("Push impulse", "推开冲量"), 0...400, default: 180, decimals: 0, unit: "pt/s"),
            .slider("stiffness", L("Collision stiffness", "碰撞硬度"), 0.2...1.0, default: 0.6),
        ]
    ) { ctx in
        InputBubblePickerDemo(ctx: ctx)
    }
}

private struct InputGenre {
    let name: LocalizedText
    let radius: CGFloat
    let tint: Color

    static let all: [InputGenre] = [
        InputGenre(name: L("Indie", "独立"), radius: 33, tint: Palette.indigo),
        InputGenre(name: L("Jazz", "爵士"), radius: 30, tint: Palette.amber),
        InputGenre(name: L("Electronic", "电子"), radius: 38, tint: Palette.sky),
        InputGenre(name: L("Lo-fi", "低保真"), radius: 31, tint: Palette.mint),
        InputGenre(name: L("Classical", "古典"), radius: 36, tint: Palette.violet),
        InputGenre(name: L("Rock", "摇滚"), radius: 30, tint: Palette.coral),
        InputGenre(name: L("Ambient", "氛围"), radius: 34, tint: Palette.blue),
        InputGenre(name: L("Soul", "灵魂乐"), radius: 30, tint: Palette.pink),
        InputGenre(name: L("Folk", "民谣"), radius: 29, tint: Palette.green),
    ]
}

/// Reference-type simulation state, stepped from the TimelineView.
private final class InputBubbleSim {
    struct Body {
        var position: CGPoint
        var velocity: CGVector = .zero
        var radius: CGFloat
        var radiusVelocity: CGFloat = 0
        var target: CGFloat
    }

    static let size = CGSize(width: 316, height: 236)
    var bodies: [Body]
    private var lastDate: Date?
    private var clock: Double = 0

    init(selected: Set<Int>, grow: CGFloat) {
        let center = CGPoint(x: Self.size.width / 2, y: Self.size.height / 2)
        bodies = InputGenre.all.enumerated().map { index, genre in
            // Seed on a 3 × 3 grid so the cluster starts spread out and settles the same way every time.
            let column = CGFloat(index % 3) - 1
            let row = CGFloat(index / 3) - 1
            let radius = genre.radius * (selected.contains(index) ? grow : 1)
            return Body(
                position: CGPoint(x: center.x + column * 84 + row * 10, y: center.y + row * 66 + column * 6),
                radius: radius,
                target: radius
            )
        }
        for _ in 0..<240 { step(dt: 1.0 / 60.0, stiffness: 0.6) }
    }

    func setTargets(selected: Set<Int>, grow: CGFloat) {
        for index in bodies.indices {
            bodies[index].target = InputGenre.all[index].radius * (selected.contains(index) ? grow : 1)
        }
    }

    /// Radial kick from one bubble to the others, fading with distance.
    func impulse(from origin: Int, strength: CGFloat) {
        let source = bodies[origin].position
        for index in bodies.indices where index != origin {
            let dx = bodies[index].position.x - source.x
            let dy = bodies[index].position.y - source.y
            let distance = max(sqrt(dx * dx + dy * dy), 1)
            let falloff = strength / max(distance / 70, 1)
            bodies[index].velocity.dx += dx / distance * falloff
            bodies[index].velocity.dy += dy / distance * falloff
        }
    }

    func advance(to date: Date, stiffness: CGFloat) {
        let elapsed = lastDate.map { date.timeIntervalSince($0) } ?? 0
        lastDate = date
        let dt = min(max(elapsed, 0), 1.0 / 30.0)
        guard dt > 0 else { return }
        step(dt: dt / 2, stiffness: stiffness)
        step(dt: dt / 2, stiffness: stiffness)
    }

    private func step(dt: Double, stiffness: CGFloat) {
        clock += dt
        let h = CGFloat(dt)
        let center = CGPoint(x: Self.size.width / 2, y: Self.size.height / 2)
        var forces = Array(repeating: CGVector.zero, count: bodies.count)
        for index in bodies.indices {
            let body = bodies[index]
            // Pull toward the centre, weaker sideways so the cluster fills the wide stage.
            forces[index].dx += (center.x - body.position.x) * 1.6
            forces[index].dy += (center.y - body.position.y) * 4.2
            // Slow drift, different per bubble.
            forces[index].dx += CGFloat(sin(clock * 0.7 + Double(index) * 1.9)) * 9
            forces[index].dy += CGFloat(cos(clock * 0.55 + Double(index) * 2.3)) * 9
        }
        for first in bodies.indices {
            for second in bodies.indices where second > first {
                let dx = bodies[second].position.x - bodies[first].position.x
                let dy = bodies[second].position.y - bodies[first].position.y
                let distance = max(sqrt(dx * dx + dy * dy), 0.01)
                let overlap = bodies[first].radius + bodies[second].radius + 5 - distance
                guard overlap > 0 else { continue }
                let force = overlap * stiffness * 300
                forces[first].dx -= dx / distance * force
                forces[first].dy -= dy / distance * force
                forces[second].dx += dx / distance * force
                forces[second].dy += dy / distance * force
            }
        }
        let drag = max(1 - 4.5 * h, 0)
        for index in bodies.indices {
            var body = bodies[index]
            body.velocity.dx = (body.velocity.dx + forces[index].dx * h) * drag
            body.velocity.dy = (body.velocity.dy + forces[index].dy * h) * drag
            body.position.x += body.velocity.dx * h
            body.position.y += body.velocity.dy * h
            // Sprung radius: stiffness 120, damping 14.
            body.radiusVelocity += ((body.target - body.radius) * 120 - body.radiusVelocity * 14) * h
            body.radius = max(body.radius + body.radiusVelocity * h, 4)
            let r = body.radius
            if body.position.x < r { body.position.x = r; body.velocity.dx = abs(body.velocity.dx) * 0.4 }
            if body.position.x > Self.size.width - r { body.position.x = Self.size.width - r; body.velocity.dx = -abs(body.velocity.dx) * 0.4 }
            if body.position.y < r { body.position.y = r; body.velocity.dy = abs(body.velocity.dy) * 0.4 }
            if body.position.y > Self.size.height - r { body.position.y = Self.size.height - r; body.velocity.dy = -abs(body.velocity.dy) * 0.4 }
            bodies[index] = body
        }
    }
}

private struct InputBubblePickerDemo: View {
    let ctx: DemoContext
    @State private var selected: Set<Int>
    @State private var sim: InputBubbleSim
    @State private var step = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        let initial: Set<Int> = ctx.isStill ? [2, 4, 7] : [4]
        _selected = State(initialValue: initial)
        _sim = State(initialValue: InputBubbleSim(selected: initial, grow: ctx.cg("grow")))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            header
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                cluster(at: timeline.date)
            }
            .frame(width: InputBubbleSim.size.width, height: InputBubbleSim.size.height)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap the bubbles you like", "点选你喜欢的气泡"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.1, delay: 0.5) { autoTick() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(L("Pick your sound", "选出你的口味"), ctx.language)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(verbatim: ctx.language == .zh ? "已选 \(selected.count)" : "\(selected.count) selected")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.indigo)
                .contentTransition(.numericText(value: Double(selected.count)))
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Palette.indigo.opacity(0.14), in: Capsule())
                .animation(.snappy(duration: 0.25), value: selected.count)
        }
        .padding(.bottom, 4)
    }

    private func cluster(at date: Date) -> some View {
        // Stepping here keeps the simulation tied to the frames that are actually drawn.
        if !ctx.isStill {
            sim.setTargets(selected: selected, grow: ctx.cg("grow"))
            sim.advance(to: date, stiffness: ctx.cg("stiffness"))
        }
        let bodies = sim.bodies
        return ZStack {
            ForEach(0..<bodies.count, id: \.self) { index in
                InputBubbleView(
                    genre: InputGenre.all[index],
                    radius: bodies[index].radius,
                    selected: selected.contains(index),
                    language: ctx.language
                )
                .onTapGesture { toggle(index) }
                .position(bodies[index].position)
            }
        }
    }

    /// Finger and autoplay both land here.
    private func toggle(_ index: Int) {
        if selected.contains(index) {
            Haptics.tap(.soft)
            selected.remove(index)
        } else {
            Haptics.tap(.light)
            selected.insert(index)
            sim.impulse(from: index, strength: ctx.cg("push"))
        }
    }

    private func autoTick() {
        let script = [2, 7, 4, 0, 2, 5, 7, 4, 0, 5]
        toggle(script[step % script.count])
        step += 1
    }
}

private struct InputBubbleView: View {
    let genre: InputGenre
    let radius: CGFloat
    let selected: Bool
    let language: AppLanguage

    var body: some View {
        let scale = radius / genre.radius
        return ZStack {
            Circle()
                .fill(genre.tint.opacity(0.16))
            Circle()
                .fill(LinearGradient(colors: [genre.tint, genre.tint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(selected ? 1 : 0)
            Circle()
                .strokeBorder(genre.tint.opacity(selected ? 0 : 0.55), lineWidth: 1.5)
            VStack(spacing: 1) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .opacity(selected ? 1 : 0)
                    .frame(height: selected ? 10 : 0)
                Text(genre.name, language)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.85))
            .padding(.horizontal, 5)
            .scaleEffect(min(scale, 1.25))
        }
        .frame(width: radius * 2, height: radius * 2)
        .shadow(color: genre.tint.opacity(selected ? 0.45 : 0), radius: 10, y: 5)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.22), value: selected)
    }
}
