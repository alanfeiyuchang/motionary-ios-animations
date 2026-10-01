import SwiftUI

extension Effect {
    static let textMagnetLetters = Effect(
        id: "text.magnet-letters",
        category: .text,
        interaction: .gesture,
        name: L("Magnetic Letters", "磁力文字"),
        summary: L("Letters scatter away from the finger like same-pole magnets, or flock to it, then spring home.", "字母像同极磁铁一样躲开指尖，或者向它聚拢，随后弹回原位。"),
        prompt: L(
            "Two lines of 50 pt black rounded capitals rest on the stage, each letter an independent body tied to its home position by a spring. The finger carries a magnetic field of about 110 pt radius, shown as a faint glowing halo. In repel mode every letter inside the field is pushed directly away, up to 70 pt at the centre with a smooth Gaussian falloff, tilting in the direction it travels, growing up to 18% and warming from the text colour to its own accent hue the further it is displaced. Letters follow with a loose spring (response 0.45 s, damping 0.45), so they overshoot and jostle; when the finger lifts they swing home and settle. Attract mode reverses the force, pulling letters into a cluster under the finger.",
            "两行50pt的特粗圆体大字静置在舞台上，每个字母都是一个独立的小物体，由一根弹簧拴在自己的原位。指尖带着一个半径约110pt的磁场，以一圈淡淡的光晕示意。排斥模式下，磁场内的字母被沿径向推开，中心处最多推开70pt，并按高斯曲线平滑衰减；字母顺着移动方向倾斜，最多放大18%，位移越大，颜色越从正文色偏向各自的强调色。字母用一根偏松的弹簧（响应0.45秒、阻尼0.45）跟随，所以会过冲、互相挤让；手指抬起后，它们摆回原位并停稳。吸引模式则把力反过来，把字母吸成一团聚在指尖下。"
        ),
        implementation: L(
            "Every glyph has a position and velocity integrated by hand each frame toward a target computed from the finger's field; a Canvas measures the glyphs, lays out their homes and draws each one translated, rotated and tinted by its displacement.",
            "每个字形都有位置和速度，每帧手动积分，朝着由指尖磁场算出的目标移动；Canvas 测量字形、排出原位，并按位移对每个字形做平移、旋转和着色后绘制。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.resolve", "DragGesture", "GraphicsContext.Shading.radialGradient"],
        tags: ["magnet", "repel", "attract", "letters", "physics", "磁力", "排斥", "吸引", "字母", "弹簧物理"],
        params: [
            .choice("mode", L("Force", "作用力"), [L("Repel", "排斥"), L("Attract", "吸引")], default: 0),
            .slider("radius", L("Field radius", "磁场半径"), 50...200, default: 110, decimals: 0, unit: "pt"),
            .slider("strength", L("Strength", "强度"), 20...130, default: 70, decimals: 0, unit: "pt"),
            .slider("damping", L("Damping", "阻尼"), 0.2...1, default: 0.45),
        ]
    ) { ctx in
        TextMagnetLettersDemo(ctx: ctx)
    }
}

private struct MagnetSim {
    var last: Date?
    var offsets: [CGPoint] = []
    var velocities: [CGPoint] = []
    var homes: [CGPoint] = []
    var aura = TextFXSpring()
}

private struct TextMagnetLettersDemo: View {
    let ctx: DemoContext
    @State private var sim = TextFXBox(MagnetSim())
    @State private var finger = CGPoint(x: 170, y: 170)
    @State private var held = false
    @State private var script: Task<Void, Never>?
    @State private var sweeps = 0
    @GestureState private var pressing = false

    private var lines: [String] {
        ctx.language == .zh ? ["指尖磁场", "文字避让"] : ["MAGNETIC", "LETTERS"]
    }
    private var fontSize: CGFloat { ctx.language == .zh ? 58 : 50 }
    private let accents: [Color] = [Palette.amber, Palette.coral, Palette.pink, Palette.violet, Palette.indigo, Palette.sky, Palette.mint]

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            Canvas { context, size in
                draw(&context, size: size, date: timeline.date)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Drag a finger through the letters", "用手指划过这些字"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
        .gesture(drag)
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release() }
        }
        .autoplay(ctx.isPreview, every: 3.0, delay: 0.8) { simulate() }
        .onDisappear { script?.cancel() }
    }

    // MARK: Touch

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held {
                    script?.cancel()
                    Haptics.tap(.soft)
                }
                touch(at: value.location)
            }
            .onEnded { _ in
                if held { Haptics.tap(.light) }
                release()
            }
    }

    private func touch(at point: CGPoint) {
        held = true
        finger = point
    }

    private func release() {
        held = false
    }

    /// Preview / intro: a scripted finger sweeps through the word and lifts.
    private func simulate() {
        guard !held else { return }
        sweeps += 1
        let leftToRight = sweeps % 2 == 1
        let from = CGPoint(x: leftToRight ? 30 : 310, y: leftToRight ? 120 : 210)
        let to = CGPoint(x: leftToRight ? 310 : 30, y: leftToRight ? 200 : 130)
        touch(at: from)
        script?.cancel()
        script = Task { @MainActor in
            let steps = 34
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(0.045))
                guard !Task.isCancelled else { return }
                let u = CGFloat(TextFXCurve.easeInOut(Double(step) / Double(steps)))
                let bow: CGFloat = sin(u * .pi) * 18
                touch(at: CGPoint(x: from.x + (to.x - from.x) * u, y: from.y + (to.y - from.y) * u - bow))
            }
            release()
        }
    }

    // MARK: Drawing + simulation

    private func draw(_ context: inout GraphicsContext, size: CGSize, date: Date) {
        // Resolve, measure and lay out the glyphs' home positions.
        var items: [(text: GraphicsContext.ResolvedText, tint: GraphicsContext.ResolvedText, home: CGPoint)] = []
        let lineHeight: CGFloat = fontSize * 1.22
        let blockHeight: CGFloat = lineHeight * CGFloat(lines.count)
        var glyphIndex = 0
        for (row, line) in lines.enumerated() {
            let glyphs: [String] = line.map { String($0) }
            var measured: [(GraphicsContext.ResolvedText, GraphicsContext.ResolvedText, CGFloat)] = []
            var width: CGFloat = 0
            for glyph in glyphs {
                let font: Font = .system(size: fontSize, weight: .black, design: .rounded)
                let plain = context.resolve(Text(verbatim: glyph).font(font).foregroundColor(.primary))
                let accent = accents[glyphIndex % accents.count]
                let tinted = context.resolve(Text(verbatim: glyph).font(font).foregroundColor(accent))
                let glyphWidth: CGFloat = plain.measure(in: CGSize(width: 200, height: 200)).width
                measured.append((plain, tinted, glyphWidth))
                width += glyphWidth
                glyphIndex += 1
            }
            var x: CGFloat = (size.width - width) / 2
            let y: CGFloat = (size.height - blockHeight) / 2 - 8 + lineHeight * (CGFloat(row) + 0.5)
            for entry in measured {
                items.append((entry.0, entry.1, CGPoint(x: x + entry.2 / 2, y: y)))
                x += entry.2
            }
        }

        // A still shows the field at work: a finger parked between the lines.
        let finger: CGPoint = ctx.isStill ? CGPoint(x: size.width * 0.6, y: size.height * 0.47) : self.finger
        let offsets: [CGPoint] = ctx.isStill
            ? items.map { fieldTarget(home: $0.home, finger: finger) }
            : step(homes: items.map(\.home), date: date)
        let auraValue: Double = ctx.isStill ? 1 : sim.value.aura.value
        let radius: CGFloat = ctx.cg("radius")
        let attract = ctx.int("mode") == 1

        // The field around the finger.
        if auraValue > 0.01 {
            let auraRadius: CGFloat = radius * CGFloat(0.6 + 0.4 * auraValue)
            let rect = CGRect(x: finger.x - auraRadius, y: finger.y - auraRadius, width: auraRadius * 2, height: auraRadius * 2)
            let hue: Color = attract ? Palette.sky : Palette.coral
            let glow = Gradient(colors: [hue.opacity(0.22 * auraValue), hue.opacity(0.07 * auraValue), hue.opacity(0)])
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(glow, center: finger, startRadius: 0, endRadius: auraRadius)
            )
            context.stroke(
                Path(ellipseIn: rect.insetBy(dx: auraRadius * 0.35, dy: auraRadius * 0.35)),
                with: .color(hue.opacity(0.28 * auraValue)),
                lineWidth: 1
            )
        }

        for (index, item) in items.enumerated() {
            let offset: CGPoint = index < offsets.count ? offsets[index] : .zero
            let distance: CGFloat = hypot(offset.x, offset.y)
            let amount: CGFloat = min(distance / 42, 1)
            var glyphContext = context
            glyphContext.translateBy(x: item.home.x + offset.x, y: item.home.y + offset.y)
            glyphContext.rotate(by: .radians(Double(max(min(offset.x * 0.011, 0.5), -0.5))))
            let scale: CGFloat = 1 + 0.18 * amount
            glyphContext.scaleBy(x: scale, y: scale)
            glyphContext.draw(item.text, at: .zero, anchor: .center)
            if amount > 0.01 {
                glyphContext.opacity = Double(amount)
                glyphContext.draw(item.tint, at: .zero, anchor: .center)
            }
        }
    }

    /// Where the field wants a letter to be, relative to its home.
    private func fieldTarget(home: CGPoint, finger: CGPoint) -> CGPoint {
        let radius: Double = max(ctx["radius"], 1)
        let strength: Double = ctx["strength"]
        let dx: Double = Double(home.x - finger.x)
        let dy: Double = Double(home.y - finger.y)
        let distance: Double = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let falloff: Double = exp(-(distance * distance) / (radius * radius) * 1.6)
        if ctx.int("mode") == 1 {
            let pull: Double = min(strength / 90, 0.95) * falloff
            return CGPoint(x: -dx * pull, y: -dy * pull)
        }
        let push: Double = strength * falloff
        return CGPoint(x: dx / distance * push, y: dy / distance * push)
    }

    /// Advances every letter's spring toward its target and returns the current offsets.
    private func step(homes: [CGPoint], date: Date) -> [CGPoint] {
        var state = sim.value
        if state.offsets.count != homes.count {
            state.offsets = Array(repeating: .zero, count: homes.count)
            state.velocities = Array(repeating: .zero, count: homes.count)
        }
        state.homes = homes
        guard let last = state.last else {
            state.last = date
            sim.value = state
            return state.offsets
        }
        let dt: Double = min(max(date.timeIntervalSince(last), 0), 1.0 / 20.0)
        guard dt > 0 else { return state.offsets }
        state.last = date
        state.aura.step(to: held ? 1 : 0, dt: dt, response: 0.4, damping: 0.75)

        let omega: Double = 2 * Double.pi / 0.45
        let stiffness: Double = omega * omega
        let friction: Double = 2 * ctx["damping"] * omega
        let substeps = 3
        let h: Double = dt / Double(substeps)

        for index in homes.indices {
            let home = homes[index]
            let target = held ? fieldTarget(home: home, finger: finger) : CGPoint.zero
            let targetX: Double = Double(target.x)
            let targetY: Double = Double(target.y)
            var px: Double = Double(state.offsets[index].x)
            var py: Double = Double(state.offsets[index].y)
            var vx: Double = Double(state.velocities[index].x)
            var vy: Double = Double(state.velocities[index].y)
            for _ in 0..<substeps {
                vx += (-stiffness * (px - targetX) - friction * vx) * h
                vy += (-stiffness * (py - targetY) - friction * vy) * h
                px += vx * h
                py += vy * h
            }
            state.offsets[index] = CGPoint(x: px, y: py)
            state.velocities[index] = CGPoint(x: vx, y: vy)
        }
        sim.value = state
        return state.offsets
    }
}
