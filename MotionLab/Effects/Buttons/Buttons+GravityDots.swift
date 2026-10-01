import SwiftUI

extension Effect {
    static let buttonsGravityDots = Effect(
        id: "buttons.gravity-dots",
        category: .buttons,
        interaction: .gesture,
        name: L("Gravity Dot Field", "引力点阵"),
        summary: L(
            "A dot grid behind the button bends toward the finger like a gravity well; a press sends a shockwave through it.",
            "按钮背后的点阵像引力井一样向手指弯曲，按下按钮则激起一圈冲击波。"
        ),
        prompt: L(
            "A gradient capsule button floats over a grid of small grey dots, 22 pt apart, that fills the stage and swells by under a pixel when idle. A finger anywhere on the field becomes a gravity well about 100 pt in radius: nearby dots are pulled up to 22 pt toward it, strongest at 45% of the radius with a Gaussian falloff, so the grid bunches around the touch while those dots swell to 1.7× and tint indigo. The well chases the finger on a spring (stiffness 170, damping 20), so the dent glides and lags, and it relaxes within 0.25 s on lift. Lifting on the button fires a radial wave from its centre at 260 pt/s: a 12 pt outward bump in a ring 18 pt wide that swells dots to 2.4× and fades within 1.4 s, with a medium haptic and a bouncy press. Quietly sci-fi.",
            "渐变胶囊按钮浮在铺满舞台的灰色点阵上，点距 22pt，静止时有不到一像素的缓慢起伏。手指落在任意处都会形成半径约 100pt 的引力井：附近的点被拉向手指最多 22pt，在 45% 半径处最强并按高斯曲线衰减，点阵向触点聚拢，同时放大到 1.7 倍并染成靛蓝。引力井以弹簧（刚度 170、阻尼 20）追随手指，略有滞后，抬手后 0.25 秒内松弛。在按钮上抬手会从中心放出一圈 260pt/s 的径向波：点被外推 12pt，波环宽 18pt，经过的点放大到 2.4 倍，1.4 秒内消散，伴随中等触感与弹性按压。"
        ),
        implementation: L(
            "A TimelineView redraws a Canvas every frame; a small reference-type model integrates a spring that chases the finger and keeps the wave start times. Each dot's offset is the sum of a Gaussian-weighted pull toward the well and a radial bump around every live wave front, and the same weights drive its size and tint.",
            "TimelineView 每帧重绘 Canvas；一个引用类型的小模型积分追随手指的弹簧，并记录每道波的起始时间。每个点的位移等于朝引力井的高斯加权拉力与各道波前处径向隆起之和，同一组权重还决定它的大小与染色。"
        ),
        apis: ["TimelineView", "Canvas", "DragGesture", "GraphicsContext", "keyframeAnimator"],
        tags: ["dots", "gravity", "field", "wave", "点阵", "引力", "涟漪", "跟随"],
        params: [
            .slider("pull", L("Pull strength", "引力强度"), 0...40, default: 22, decimals: 0, unit: "pt"),
            .slider("radius", L("Well radius", "引力半径"), 50...160, default: 100, decimals: 0, unit: "pt"),
            .slider("spacing", L("Dot spacing", "点距"), 16...32, default: 22, decimals: 0, unit: "pt"),
            .slider("wave", L("Wave height", "波幅"), 0...24, default: 12, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        ButtonGravityDemo(ctx: ctx)
    }
}

/// Simulation state that changes every frame, kept out of SwiftUI's dependency graph on purpose:
/// the TimelineView already redraws the Canvas, so nothing needs to be invalidated.
private final class ButtonGravityModel {
    var well = CGPoint.zero
    var velocity = CGVector.zero
    var target: CGPoint?
    /// 0…1, eased: how much of the well is switched on.
    var strength: CGFloat = 0
    var waves: [Date] = []
    private var last: Date?
    private var seeded = false

    func step(to now: Date, center: CGPoint) {
        let dt = CGFloat(min(max(now.timeIntervalSince(last ?? now), 0), 1.0 / 30.0))
        last = now
        if !seeded {
            well = center
            seeded = true
        }
        if let target {
            // Semi-implicit Euler spring: stiffness 170, damping 20.
            let ax = (target.x - well.x) * 170 - velocity.dx * 20
            let ay = (target.y - well.y) * 170 - velocity.dy * 20
            velocity.dx += ax * dt
            velocity.dy += ay * dt
            well.x += velocity.dx * dt
            well.y += velocity.dy * dt
        } else {
            velocity = .zero
        }
        let goal: CGFloat = target == nil ? 0 : 1
        strength += (goal - strength) * min(1, dt * 12)
        waves.removeAll { now.timeIntervalSince($0) > 1.4 }
    }
}

private struct ButtonGravityDemo: View {
    let ctx: DemoContext
    @State private var model = ButtonGravityModel()
    @State private var stageSize: CGSize = .zero
    @State private var pressed = false
    @State private var presses = 0
    @State private var step = 0
    @State private var introTask: Task<Void, Never>?
    /// Resets on system cancellation too, so a cancelled touch still releases the well.
    @GestureState private var touching = false

    private static let buttonSize = CGSize(width: 176, height: 58)
    private static let path: [CGSize] = [
        CGSize(width: 96, height: -92),
        CGSize(width: -104, height: -70),
        CGSize(width: 0, height: 0),
        CGSize(width: -84, height: 96),
        CGSize(width: 110, height: 84),
        CGSize(width: 0, height: 0),
    ]

    var body: some View {
        ZStack {
            field
            button
            VStack {
                Spacer()
                DemoHint(text: L("Drag around the dots, then tap the button", "在点阵上拖动，再点一下按钮"), ctx: ctx)
                    .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            stageSize = newSize
        }
        .simultaneousGesture(dragGesture)
        .onChange(of: touching) { _, isTouching in
            if !isTouching { release() }
        }
        .autoplay(ctx.isPreview, every: 0.9, delay: 0.3) {
            if ctx.isPreview { stepPreview() } else { playIntro() }
        }
        .onDisappear { stopIntro() }
    }

    private var field: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
            ButtonGravityField(
                model: model,
                date: timeline.date,
                still: ctx.isStill,
                clearBottom: ctx.isPreview ? 0 : 48,
                pull: ctx.cg("pull"),
                radius: ctx.cg("radius"),
                spacing: ctx.cg("spacing"),
                wave: ctx.cg("wave")
            )
        }
        .allowsHitTesting(false)
    }

    private var button: some View {
        HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
            Text(ctx.language == .zh ? "发送脉冲" : "Send pulse")
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(width: Self.buttonSize.width, height: Self.buttonSize.height)
        .background(Palette.primary, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
        .shadow(color: Palette.indigo.opacity(0.4), radius: pressed ? 8 : 18, y: pressed ? 4 : 10)
        .scaleEffect(pressed ? 0.95 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
        .keyframeAnimator(initialValue: 1.0, trigger: presses) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(0.93, duration: 0.08)
                SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                stopIntro()
                model.target = value.location
                let onButton = isOnButton(value.location)
                if onButton != pressed { pressed = onButton }
            }
            .onEnded { value in
                if isOnButton(value.location) {
                    Haptics.tap(.medium)
                    pulse()
                }
                release()
            }
    }

    private func isOnButton(_ point: CGPoint) -> Bool {
        abs(point.x - stageSize.width / 2) < Self.buttonSize.width / 2
            && abs(point.y - stageSize.height / 2) < Self.buttonSize.height / 2
    }

    private func pulse() {
        model.waves.append(Date())
        presses += 1
    }

    private func release() {
        model.target = nil
        if pressed { pressed = false }
    }

    private func stepPreview() {
        guard stageSize != .zero else { return }
        let offset = Self.path[step % Self.path.count]
        step += 1
        model.target = CGPoint(x: stageSize.width / 2 + offset.width, y: stageSize.height / 2 + offset.height)
        // Every pass over the button presses it.
        if offset == .zero { pulse() }
    }

    private func playIntro() {
        stopIntro()
        introTask = Task { @MainActor in
            for _ in 0..<3 {
                stepPreview()
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
            }
            release()
            introTask = nil
        }
    }

    private func stopIntro() {
        introTask?.cancel()
        introTask = nil
    }
}

private struct ButtonGravityField: View {
    let model: ButtonGravityModel
    let date: Date
    let still: Bool
    /// Height at the bottom left free of dots, for the hint caption on the detail stage.
    let clearBottom: CGFloat
    let pull: CGFloat
    let radius: CGFloat
    let spacing: CGFloat
    let wave: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var well = model.well
            var strength = model.strength
            var ages: [Double] = []
            if still {
                // A still frame: a well beside the button and one wave on its way out.
                well = CGPoint(x: center.x + 86, y: center.y - 84)
                strength = 1
                ages = [0.42]
            } else {
                model.step(to: date, center: center)
                well = model.well
                strength = model.strength
                ages = model.waves.map { date.timeIntervalSince($0) }
            }
            let time = date.timeIntervalSinceReferenceDate
            draw(&context, size: size, center: center, well: well, strength: strength, ages: ages, time: still ? 0 : time)
        }
    }

    private func draw(
        _ context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        well: CGPoint,
        strength: CGFloat,
        ages: [Double],
        time: Double
    ) {
        let columns = Int(size.width / 2 / spacing) + 1
        let rows = Int(size.height / 2 / spacing) + 1
        let base = GraphicsContext.Shading.color(Color.primary.opacity(0.24))
        for row in -rows...rows {
            for column in -columns...columns {
                let home = CGPoint(x: center.x + CGFloat(column) * spacing, y: center.y + CGFloat(row) * spacing)
                guard home.y < size.height - clearBottom else { continue }
                var point = home
                // Idle swell, so the field is never perfectly dead.
                point.y += CGFloat(sin(time * 1.1 + Double(home.x) * 0.021 + Double(home.y) * 0.017)) * 0.8

                // Gravity well: the pull peaks at 45% of the radius, fades as a Gaussian, and never drags a dot
                // past the finger, so the grid visibly bunches up around the touch.
                let dx = well.x - home.x
                let dy = well.y - home.y
                let distance = max(hypot(dx, dy), 0.001)
                let unit = distance / (radius * 0.45)
                let amount = min(pull * unit * exp(0.5 - unit * unit / 2) * strength, distance * 0.85)
                point.x += dx / distance * amount
                point.y += dy / distance * amount
                let reach = distance / radius
                let glow = Double(strength * exp(-reach * reach * 2.4))
                var heat = glow
                var swell = 0.7 * glow

                // Shockwaves from the button.
                let cx = home.x - center.x
                let cy = home.y - center.y
                let fromCenter = max(hypot(cx, cy), 0.001)
                for age in ages {
                    let front = CGFloat(age) * 260
                    let offset = fromCenter - front
                    let life = CGFloat(max(0, 1 - age / 1.4))
                    let bump = exp(-(offset * offset) / (2 * 18 * 18)) * life
                    point.x += cx / fromCenter * wave * bump
                    point.y += cy / fromCenter * wave * bump
                    heat = max(heat, Double(bump))
                    swell = max(swell, 1.4 * Double(bump))
                }

                let dotRadius = 1.6 * (1 + CGFloat(swell))
                let rect = CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                let path = Path(ellipseIn: rect)
                if heat < 0.99 {
                    context.opacity = 1 - heat
                    context.fill(path, with: base)
                }
                if heat > 0.01 {
                    context.opacity = heat
                    context.fill(path, with: .color(Palette.indigo.mix(with: Palette.violet, by: 0.35)))
                }
            }
        }
        context.opacity = 1
    }
}
