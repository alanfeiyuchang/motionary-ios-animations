import SwiftUI

extension Effect {
    static let buttonsMeshBreath = Effect(
        id: "buttons.mesh-breath",
        category: .buttons,
        interaction: .loop,
        name: L("Breathing Mesh", "呼吸网格渐变"),
        summary: L(
            "A button filled with a slowly breathing mesh gradient and a soft bloom; a press sends a ripple through the colours.",
            "按钮内是缓慢呼吸的网格渐变，外圈晕着柔光；按下时一道涟漪穿过这些色彩。"
        ),
        prompt: L(
            "A 244 × 72 pt capsule filled with a 4 × 3 mesh gradient of indigo, violet, pink, coral and amber. It never sits still: the control points drift by up to 10% on slow, out-of-phase sine waves and the colours lean toward their neighbours and back once every 4.5 s, in step with a blurred copy of the gradient behind the button that swells from 106% to 111% as an outer bloom. Touching the button presses it to 96.5% and launches a pulse from the finger: a ring-shaped wavefront travels outward at 320 pt/s, pushing each mesh point up to 16 pt away as it passes, so the colours visibly bulge and snap back, while a soft white ring rides the front and the bloom flashes brighter, all fading within 0.9 s. Release springs it back (response 0.35 s, damping 0.6). Calm, rich, alive.",
            "244×72pt 的胶囊按钮，填充 4×3 的网格渐变，由靛蓝、紫罗兰、粉、珊瑚与琥珀组成。控制点沿相位错开的慢速正弦波漂移，幅度最多 10%；颜色每 4.5 秒向相邻色靠拢再返回，与按钮背后那份模糊的渐变副本同步——后者作为外圈柔光，在 106% 到 111% 之间起伏。触摸时按钮压到 96.5%，并从指尖发出脉冲：环形波前以 320pt/s 向外扩散，经过时把网格点最多推开 16pt，色彩鼓起又弹回；一圈白光随波前而行，柔光同时变亮，0.9 秒内消退。松手后以弹簧（响应 0.35 秒、阻尼 0.6）回弹。"
        ),
        implementation: L(
            "A TimelineView recomputes the 12 MeshGradient points every frame: a sine drift per point plus, for each live pulse, a radial push weighted by a Gaussian around the expanding wavefront (edge points stay on their edges). The same mesh is drawn twice, once blurred behind the capsule as the bloom; pulses are stored as origin and start date.",
            "TimelineView 每帧重新计算 MeshGradient 的 12 个控制点：每个点有各自的正弦漂移；每道存活的脉冲再叠加一次径向推挤，权重是围绕扩散波前的高斯函数（边缘点只沿边缘移动）。同一份网格画两次，其中一份模糊后放在胶囊背后作为柔光；脉冲只记录起点与开始时间。"
        ),
        apis: ["MeshGradient", "TimelineView", "blur", "blendMode(.plusLighter)", "DragGesture"],
        tags: ["mesh gradient", "breathing", "bloom", "pulse", "glow", "网格渐变", "呼吸", "柔光", "脉冲", "辉光"],
        params: [
            .slider("period", L("Breath period", "呼吸周期"), 2...8, default: 4.5, decimals: 1, unit: "s"),
            .slider("drift", L("Drift", "漂移幅度"), 0...0.2, default: 0.1),
            .slider("bloom", L("Bloom", "外圈柔光"), 0...1, default: 0.6),
            .slider("pulse", L("Pulse strength", "脉冲强度"), 0...1, default: 0.6),
        ]
    ) { ctx in
        ButtonMeshDemo(ctx: ctx)
    }
}

private struct ButtonMeshPulse {
    let origin: CGPoint
    let start: Date
}

private struct ButtonMeshDemo: View {
    let ctx: DemoContext
    @State private var pulses: [ButtonMeshPulse] = []
    @State private var pressed = false
    @State private var step = 0
    @State private var scriptTask: Task<Void, Never>?

    private static let size = CGSize(width: 244, height: 72)
    private static let life = 0.9
    private static let script: [CGPoint] = [
        CGPoint(x: 52, y: 40),
        CGPoint(x: 196, y: 30),
        CGPoint(x: 122, y: 36),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                button(at: ctx.isStill ? Date(timeIntervalSinceReferenceDate: 40) : timeline.date)
            }
            Spacer()
            DemoHint(text: L("Tap anywhere on the button", "点击按钮任意位置"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.3, delay: 0.8) { playScript() }
        .onDisappear { scriptTask?.cancel() }
    }

    private func button(at date: Date) -> some View {
        let time = date.timeIntervalSinceReferenceDate
        let breath = sin(time * 2 * .pi / max(ctx["period"], 0.5))
        let strength = ctx["pulse"]
        let points = ButtonMeshField.points(
            time: time,
            drift: ctx["drift"],
            breath: breath,
            pulses: pulses,
            date: date,
            strength: strength,
            size: Self.size,
            life: Self.life
        )
        let colors = ButtonMeshField.colors(breath: breath)
        let flash = pulses.map { pulse -> Double in
            let u = date.timeIntervalSince(pulse.start) / Self.life
            return u >= 0 && u < 1 ? (1 - u) * (1 - u) * strength : 0
        }.max() ?? 0
        let bloom = ctx["bloom"]

        return ZStack {
            MeshGradient(width: 4, height: 3, points: points, colors: colors)
                .frame(width: Self.size.width, height: Self.size.height)
                .clipShape(Capsule())
                .blur(radius: 22)
                .scaleEffect(1.085 + 0.025 * breath + 0.1 * flash)
                .opacity(min(bloom * (0.7 + 0.2 * breath) + 0.5 * flash, 1))
            MeshGradient(width: 4, height: 3, points: points, colors: colors)
                .frame(width: Self.size.width, height: Self.size.height)
                .overlay { rings(at: date, strength: strength) }
                .overlay {
                    LinearGradient(colors: [Color.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                }
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.65), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.2
                    )
                )
            HStack(spacing: 8) {
                Text(ctx.language == .zh ? "立即开始" : "Get started")
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
        .scaleEffect(pressed ? 0.965 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: pressed)
        .frame(width: Self.size.width, height: Self.size.height)
        .contentShape(Capsule())
        .gesture(pressGesture)
        .accessibilityAddTraits(.isButton)
    }

    /// The visible wavefront: a soft white ring riding each pulse.
    private func rings(at date: Date, strength: Double) -> some View {
        ZStack {
            ForEach(Array(pulses.enumerated()), id: \.offset) { _, pulse in
                let age = date.timeIntervalSince(pulse.start)
                let u = age / Self.life
                if u >= 0, u < 1 {
                    let radius = CGFloat(age * ButtonMeshField.speed)
                    Circle()
                        .stroke(Color.white.opacity(0.6 * strength * (1 - u)), lineWidth: 12)
                        .frame(width: radius * 2, height: radius * 2)
                        .blur(radius: 7)
                        .position(pulse.origin)
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !pressed else { return }
                scriptTask?.cancel()
                pressed = true
                Haptics.tap(.soft)
                pulse(from: value.location)
            }
            .onEnded { _ in
                pressed = false
                Haptics.tap(.light)
            }
    }

    private func pulse(from origin: CGPoint) {
        let now = Date()
        var next = pulses.filter { now.timeIntervalSince($0.start) < Self.life }
        next.append(
            ButtonMeshPulse(
                origin: CGPoint(x: origin.x.clamped(to: 0...Self.size.width), y: origin.y.clamped(to: 0...Self.size.height)),
                start: now
            )
        )
        pulses = next
    }

    private func playScript() {
        guard !pressed else { return }
        let origin = Self.script[step % Self.script.count]
        step += 1
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            pressed = true
            pulse(from: origin)
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            pressed = false
        }
    }
}

private enum ButtonMeshField {
    /// Wavefront speed in points per second.
    static let speed = 320.0

    private static let base: [Color] = [
        Palette.indigo, Palette.violet, Palette.pink, Palette.coral,
        Palette.blue, Color(hex: 0x8F5BFF), Color(hex: 0xFF6FA8), Palette.amber,
        Palette.sky, Palette.indigo, Palette.violet, Palette.pink,
    ]

    /// Each colour leans toward its right-hand neighbour with the breath.
    static func colors(breath: Double) -> [Color] {
        let lean = 0.3 * (0.5 + 0.5 * breath)
        return (0..<12).map { index in
            let row = index / 4
            let neighbour = row * 4 + (index % 4 + 1) % 4
            return base[index].mix(with: base[neighbour], by: lean)
        }
    }

    static func points(
        time: Double,
        drift: Double,
        breath: Double,
        pulses: [ButtonMeshPulse],
        date: Date,
        strength: Double,
        size: CGSize,
        life: Double
    ) -> [SIMD2<Float>] {
        var result: [SIMD2<Float>] = []
        result.reserveCapacity(12)
        for row in 0..<3 {
            for column in 0..<4 {
                let onVerticalEdge = column == 0 || column == 3
                let onHorizontalEdge = row == 0 || row == 2
                let phase = Double(column) * 1.9 + Double(row) * 2.7
                var x = Double(column) / 3
                var y = Double(row) / 2
                if !onVerticalEdge {
                    x += drift * sin(time * 0.9 + phase)
                }
                if !onHorizontalEdge {
                    y += drift * 1.8 * cos(time * 0.7 + phase * 1.3) + 0.06 * breath * (column % 2 == 0 ? 1 : -1)
                }
                // Pulses push the point away from their origin as the wavefront passes it.
                var px = x * Double(size.width)
                var py = y * Double(size.height)
                for pulse in pulses {
                    let age = date.timeIntervalSince(pulse.start)
                    guard age >= 0, age < life else { continue }
                    let dx = px - Double(pulse.origin.x)
                    let dy = py - Double(pulse.origin.y)
                    let distance = max((dx * dx + dy * dy).squareRoot(), 0.001)
                    let offset = distance - age * speed
                    let push = strength * 27 * exp(-(offset * offset) / (46 * 46)) * (1 - age / life)
                    px += dx / distance * push
                    py += dy / distance * push
                }
                let ux = onVerticalEdge ? Double(column) / 3 : (px / Double(size.width)).clamped(to: 0.04...0.96)
                let uy = onHorizontalEdge ? Double(row) / 2 : (py / Double(size.height)).clamped(to: 0.06...0.94)
                result.append(SIMD2(Float(ux), Float(uy)))
            }
        }
        return result
    }
}
