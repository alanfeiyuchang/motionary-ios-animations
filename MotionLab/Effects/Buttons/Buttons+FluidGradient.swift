import SwiftUI

extension Effect {
    static let buttonsFluidGradient = Effect(
        id: "buttons.fluid-gradient",
        category: .buttons,
        interaction: .gesture,
        name: L("Fluid Gradient", "流体渐变"),
        summary: L(
            "Colour blobs inside the button swim after the finger like dye in water, then slosh back home.",
            "按钮里的色团像水中的颜料一样追着手指游动，松手后晃荡着回到原位。"
        ),
        prompt: L(
            "A 248 × 72 pt capsule on a deep navy base holds four soft colour blobs (pink, amber, sky, mint), each blurred by 18 pt so they melt into one living gradient; at rest they drift a few points around evenly spaced homes. Dragging across the button pulls every blob toward the finger on its own spring: the first is stiffest (stiffness 120) and each following one is 28% softer, so they string out behind the finger like a comet of dye and circle it as a slow pinwheel, each stretched along its velocity by up to 45%. The button presses to 97% while touched. On release the blobs fly home under-damped (damping ratio 0.55), overshooting and sloshing once or twice before settling. A gloss band, a bright rim and a white label stay fixed on top. Liquid and alive.",
            "248×72pt 的胶囊按钮，深海军蓝底色上浮着四个柔和色团（粉、琥珀、天蓝、薄荷），各带 18pt 模糊，融成一片活的渐变；静止时在等距的原位附近缓慢漂移。手指在按钮上拖动时，每个色团由各自的弹簧拉向手指：第一个最硬（刚度 120），后面每个依次软 28%，于是像颜料彗尾一样在指后拉开、绕着指尖缓缓旋转，并沿速度方向最多拉伸 45%。触摸期间按钮压到 97%。松手后色团以欠阻尼（阻尼比 0.55）飞回原位，过冲并晃荡一两次才停稳。顶部的高光带、亮边与白色文字始终不动。液态而鲜活。"
        ),
        implementation: L(
            "A small reference-type simulation holds each blob's position and velocity and is stepped with semi-implicit Euler from a TimelineView; a Canvas clips to the capsule and draws the blobs as velocity-aligned ellipses inside one blurred layer. The finger position comes from a zero-distance DragGesture (or a scripted path during autoplay).",
            "用一个引用类型的小型模拟保存每个色团的位置与速度，在 TimelineView 里以半隐式欧拉法逐帧推进；Canvas 裁剪到胶囊形，把色团画成沿速度方向拉伸的椭圆，并放进同一个模糊图层。手指位置来自零距离 DragGesture（自动播放时改用脚本路径）。"
        ),
        apis: ["TimelineView", "Canvas", "GraphicsContext.addFilter(.blur)", "DragGesture", "GraphicsContext.clip(to:)"],
        tags: ["fluid", "gradient", "blob", "follow", "liquid", "流体", "渐变", "色团", "跟随", "液态"],
        params: [
            .slider("stiffness", L("Follow stiffness", "跟随刚度"), 40...300, default: 120, decimals: 0),
            .slider("damping", L("Damping ratio", "阻尼比"), 0.25...1.0, default: 0.55),
            .slider("blur", L("Softness", "柔化程度"), 8...28, default: 18, decimals: 0, unit: "pt"),
            .slider("count", L("Blobs", "色团数量"), 3...6, default: 4, step: 1, decimals: 0),
        ]
    ) { ctx in
        ButtonFluidDemo(ctx: ctx)
    }
}

/// Spring-mass blobs. A reference type so the timeline can step it without invalidating the view.
private final class ButtonFluidSim {
    static let capacity = 6
    var positions: [CGPoint]
    var velocities: [CGVector]
    private var last: Date?

    init(size: CGSize, count: Int, still: Bool) {
        positions = (0..<Self.capacity).map { Self.home($0, count: count, size: size) }
        velocities = Array(repeating: .zero, count: Self.capacity)
        if still {
            // A frozen chase: blobs strung out toward the right-hand side.
            for index in 0..<Self.capacity {
                let lag = CGFloat(index) * 26
                positions[index] = CGPoint(x: size.width * 0.72 - lag, y: size.height * (index % 2 == 0 ? 0.38 : 0.64))
                velocities[index] = CGVector(dx: 180 - Double(index) * 20, dy: 0)
            }
        }
    }

    static func home(_ index: Int, count: Int, size: CGSize) -> CGPoint {
        let slots = max(count, 1)
        let x = size.width * (CGFloat(index % slots) + 0.5) / CGFloat(slots)
        let y = size.height * (index % 2 == 0 ? 0.36 : 0.66)
        return CGPoint(x: x, y: y)
    }

    func step(to date: Date, finger: CGPoint?, size: CGSize, count: Int, stiffness: Double, ratio: Double) {
        defer { last = date }
        guard let last else { return }
        let elapsed = min(date.timeIntervalSince(last), 1.0 / 20.0)
        guard elapsed > 0 else { return }
        let time = date.timeIntervalSinceReferenceDate
        let steps = 3
        let dt = elapsed / Double(steps)
        for index in 0..<min(count, Self.capacity) {
            let k = stiffness * pow(0.72, Double(index))
            let c = 2 * ratio * sqrt(k)
            let phase = Double(index) * 1.7
            let target: CGPoint
            if let finger {
                // Blobs orbit the finger as a slow pinwheel, so they never collapse into one colour.
                let orbit = time * 1.4 + Double(index) * 2 * .pi / Double(max(count, 1))
                target = CGPoint(
                    x: finger.x + CGFloat(cos(orbit)) * 34,
                    y: finger.y + CGFloat(sin(orbit)) * 15
                )
            } else {
                let home = Self.home(index, count: count, size: size)
                target = CGPoint(
                    x: home.x + CGFloat(sin(time * 0.7 + phase)) * 9,
                    y: home.y + CGFloat(cos(time * 0.55 + phase * 1.3)) * 6
                )
            }
            for _ in 0..<steps {
                let ax = k * Double(target.x - positions[index].x) - c * velocities[index].dx
                let ay = k * Double(target.y - positions[index].y) - c * velocities[index].dy
                velocities[index].dx += ax * dt
                velocities[index].dy += ay * dt
                positions[index].x += CGFloat(velocities[index].dx * dt)
                positions[index].y += CGFloat(velocities[index].dy * dt)
            }
        }
    }
}

private struct ButtonFluidDemo: View {
    let ctx: DemoContext
    @State private var sim: ButtonFluidSim
    @State private var finger: CGPoint?
    @State private var scriptStart: Date?
    @State private var scripting = false
    @State private var scriptTask: Task<Void, Never>?

    private static let size = CGSize(width: 248, height: 72)
    private static let scriptLength = 1.7

    init(ctx: DemoContext) {
        self.ctx = ctx
        _sim = State(initialValue: ButtonFluidSim(size: Self.size, count: 4, still: ctx.isStill))
    }

    private var count: Int { min(max(ctx.int("count"), 1), ButtonFluidSim.capacity) }
    private var pressed: Bool { finger != nil || scripting }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            button
            Spacer()
            DemoHint(text: L("Drag across the button", "在按钮上来回拖动"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.1, delay: 0.5) { playScript() }
        .onDisappear { scriptTask?.cancel() }
    }

    private var button: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
            let _ = advance(to: timeline.date)
            ButtonFluidCanvas(sim: sim, date: timeline.date, count: count, blur: ctx.cg("blur"))
                .frame(width: Self.size.width, height: Self.size.height)
        }
        .overlay { gloss }
        .overlay {
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                Text(ctx.language == .zh ? "开始探索" : "Explore")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        }
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1.2
            )
        )
        .shadow(color: Color(hex: 0x3A1D8F).opacity(0.45), radius: 18, y: 10)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: pressed)
        .contentShape(Capsule())
        .gesture(dragGesture)
        .accessibilityAddTraits(.isButton)
    }

    private var gloss: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color.white.opacity(0.26), .clear], startPoint: .top, endPoint: .center))
            .padding(.horizontal, 8)
            .padding(.top, 3)
            .padding(.bottom, 34)
            .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if finger == nil {
                    stopScript()
                    Haptics.tap(.soft)
                }
                finger = CGPoint(
                    x: value.location.x.clamped(to: 0...Self.size.width),
                    y: value.location.y.clamped(to: 0...Self.size.height)
                )
            }
            .onEnded { _ in
                finger = nil
                Haptics.tap(.light)
            }
    }

    private func advance(to date: Date) {
        sim.step(
            to: date,
            finger: finger ?? scriptedFinger(at: date),
            size: Self.size,
            count: count,
            stiffness: ctx["stiffness"],
            ratio: ctx["damping"]
        )
    }

    /// The autoplay finger: one sweep right and back with a gentle vertical wave.
    private func scriptedFinger(at date: Date) -> CGPoint? {
        guard let scriptStart else { return nil }
        let u = date.timeIntervalSince(scriptStart) / Self.scriptLength
        guard u >= 0, u < 1 else { return nil }
        return CGPoint(
            x: Self.size.width * (0.5 + 0.38 * sin(u * 2 * .pi)),
            y: Self.size.height * (0.5 + 0.22 * sin(u * 4 * .pi))
        )
    }

    private func playScript() {
        guard finger == nil else { return }
        scriptStart = Date()
        scripting = true
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.scriptLength))
            guard !Task.isCancelled else { return }
            scripting = false
        }
    }

    private func stopScript() {
        scriptTask?.cancel()
        scriptStart = nil
        scripting = false
    }
}

private struct ButtonFluidCanvas: View {
    let sim: ButtonFluidSim
    let date: Date
    let count: Int
    let blur: CGFloat

    private static let colors: [Color] = [Palette.pink, Palette.amber, Palette.sky, Palette.mint, Palette.violet, Palette.coral]

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x1A1B45), Color(hex: 0x34186B)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: blur))
                for index in 0..<count {
                    let position = sim.positions[index]
                    let velocity = sim.velocities[index]
                    let speed = hypot(velocity.dx, velocity.dy)
                    let stretch = 1 + min(speed / 600, 0.45)
                    let radius: CGFloat = 34 + CGFloat(index % 3) * 5
                    var blob = layer
                    blob.translateBy(x: position.x, y: position.y)
                    blob.rotate(by: .radians(atan2(velocity.dy, velocity.dx)))
                    blob.scaleBy(x: stretch, y: 1 / stretch)
                    blob.fill(
                        Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                        with: .color(Self.colors[index % Self.colors.count].opacity(0.92))
                    )
                }
            }
        }
    }
}
