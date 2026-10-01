import SwiftUI

extension Effect {
    static let inputsSafeDial = Effect(
        id: "inputs.safe-dial",
        category: .inputs,
        interaction: .gesture,
        name: L("Combination Safe Dial", "保险箱密码转盘"),
        summary: L("A heavy dial that lags, coasts and ticks; each number you rest on lights a pin and the last one pulls the bolt.", "沉重的转盘会滞后、惯性滑行并逐格咔嗒；每停在一个正确数字点亮一枚销子，最后一个让锁舌缩回。"),
        prompt: L(
            "A combination safe dial: a 196 pt black face with 100 ticks and numerals every ten turns inside a brushed bezel, around a ridged metal knob; a red pointer sits at twelve o'clock. Above, a lock case shows a steel bolt and three numbered pins. Dragging turns the dial with weight: it chases the finger through a 90 ms low-pass, and on release coasts under exponential friction (2.2 per second) before settling into the nearest of 100 detents. Every passing number ticks a selection haptic and flicks the pointer up to 16°. Resting on the right number for 0.4 s sets a pin: it turns green and jumps 5 pt on a bouncy spring (response 0.3 s, damping 0.5). The third pin retracts the bolt 30 pt (response 0.5 s, damping 0.62) with a success haptic, the lock glyph opens, and it relocks 2.6 s later.",
            "保险箱密码转盘：196pt 黑色盘面刻 100 条刻度，在拉丝外圈内绕带防滑纹的金属旋钮旋转，十二点方向一枚红色指针；上方锁体有锁舌和三枚销子。转盘经 90 毫秒低通滤波追随手指，松手后在指数摩擦（每秒 2.2）下滑行，再落入最近的定位格。每经过一个数字一次选择触觉，指针最多弹开 16°。在正确数字上停留 0.4 秒即顶起一枚销子：变绿并以弹簧（响应 0.3 秒、阻尼 0.5）跳起 5pt。第三枚到位后锁舌缩回 30pt（响应 0.5 秒、阻尼 0.62），触发成功触觉，锁打开，2.6 秒后自动上锁。"
        ),
        implementation: L(
            "A small fixed-step physics loop owns the angle: while a finger or the script holds a target it low-pass follows it, otherwise angular velocity decays exponentially and the dial eases into the nearest detent. Number crossings are detected in the loop for ticks and a debounced dwell check; the face is a Canvas rotated with rotationEffect.",
            "一个小型定步长物理循环掌管角度：手指或脚本给出目标时做低通跟随，否则角速度按指数衰减并缓入最近的定位格。循环内检测数字跨越以触发咔嗒与去抖的停留判定；盘面是一张 Canvas，用 rotationEffect 旋转。"
        ),
        apis: ["Canvas", "DragGesture", "atan2", "Task", "rotationEffect", "contentTransition(.symbolEffect(.replace))"],
        tags: ["dial", "safe", "combination", "inertia", "detent", "转盘", "保险箱", "密码", "惯性", "刻度"],
        params: [
            .slider("lag", L("Dial weight", "转盘重量"), 0.03...0.25, default: 0.09, unit: "s"),
            .slider("friction", L("Friction", "摩擦"), 0.8...6, default: 2.2, decimals: 1),
            .slider("dwell", L("Dwell to set", "停留判定"), 0.2...0.9, default: 0.4, unit: "s"),
            .slider("tolerance", L("Tolerance", "容差"), 0...3, default: 1, step: 1, decimals: 0),
        ]
    ) { ctx in
        InputSafeDialDemo(ctx: ctx)
    }
}

/// Values the physics loop needs between frames but that never drive rendering directly.
private final class InputSafePhysics {
    var omega: Double = 0
    var target: Double?
    /// Follow rate override for scripted spins (nil = the finger's rate from the weight parameter).
    var scriptedRate: Double?
    var lastTheta: Double = 0
    var loop: Task<Void, Never>?
    var dwell: Task<Void, Never>?
    var relock: Task<Void, Never>?
}

private struct InputSafeDialDemo: View {
    let ctx: DemoContext
    /// Dial rotation in degrees, clockwise positive. The number under the pointer is -angle / 3.6.
    @State private var angle: Double = 0
    @State private var flick: Double = 0
    @State private var number = 0
    @State private var pins: Int
    @State private var unlocked: Bool
    @State private var step = 0
    @State private var physics = InputSafePhysics()
    @GestureState private var touching = false

    private static let combination = [30, 70, 15]
    private let face: CGFloat = 196

    init(ctx: DemoContext) {
        self.ctx = ctx
        _pins = State(initialValue: ctx.isStill ? 3 : 0)
        _unlocked = State(initialValue: ctx.isStill)
        _angle = State(initialValue: ctx.isStill ? -15 * 3.6 : 0)
        _number = State(initialValue: ctx.isStill ? 15 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                lockCase
                dial
            }
            .scaleEffect(ctx.isPreview ? 1.04 : 1)
            Spacer(minLength: 0)
            DemoHint(text: L("Turn the dial and rest on 30, then 70, then 15", "转动转盘，依次停在 30、70、15"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.4) { previewTick() }
        .onDisappear {
            physics.loop?.cancel()
            physics.dwell?.cancel()
            physics.relock?.cancel()
        }
    }

    // MARK: Lock case

    private var lockCase: some View {
        // The bolt leaves the case on the left, away from the stage's reset button.
        HStack(spacing: 8) {
            bolt
            Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(unlocked ? Palette.green : Color.secondary)
                .frame(width: 24)
                .padding(.trailing, 2)
            ForEach(0..<3, id: \.self) { index in
                pin(index)
            }
        }
        .padding(.trailing, 10)
        .frame(width: 256, height: 48, alignment: .trailing)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.stroke))
    }

    private func pin(_ index: Int) -> some View {
        let set = index < pins
        let current = index == pins && !unlocked
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Text(verbatim: "\(Self.combination[index])")
            .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(set ? Color.white : (current ? Color.primary : Color.secondary))
            .frame(width: 40, height: 30)
            .background {
                ZStack {
                    shape.fill(Color.primary.opacity(0.08))
                    shape.fill(Palette.green).opacity(set ? 1 : 0)
                    shape.strokeBorder(Color.primary.opacity(current ? 0.5 : 0), lineWidth: 1.5)
                }
            }
            .shadow(color: Palette.green.opacity(set ? 0.5 : 0), radius: 8, y: 2)
            .offset(y: set ? -5 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(set ? 0 : Double(index) * 0.06), value: set)
            .animation(.easeOut(duration: 0.2), value: current)
    }

    private var bolt: some View {
        ZStack(alignment: .trailing) {
            Capsule()
                .fill(Color.black.opacity(0.28))
                .frame(width: 62, height: 20)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xF2F4F8), Color(hex: 0x9EA3AD), Color(hex: 0xD8DBE2)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5))
                .frame(width: 56, height: 16)
                .offset(x: unlocked ? -3 : -33)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(width: 62, alignment: .trailing)
        .animation(.spring(response: 0.5, dampingFraction: 0.62), value: unlocked)
    }

    // MARK: Dial

    private var dial: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(
                    colors: [Color(white: 0.92), Color(white: 0.55), Color(white: 0.85), Color(white: 0.5), Color(white: 0.92)],
                    center: .center
                ))
                .frame(width: face + 22, height: face + 22)
                .shadow(color: .black.opacity(0.3), radius: 16, y: 10)
            InputSafeFace()
                .frame(width: face, height: face)
                .rotationEffect(.degrees(angle))
            knob
            pointer
        }
        .frame(width: face + 22, height: face + 30)
        .contentShape(Circle())
        .gesture(drag)
        .onChange(of: touching) { _, down in
            if !down { letGo() }
        }
    }

    private var knob: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(
                    colors: [Color(white: 0.96), Color(white: 0.5), Color(white: 0.88), Color(white: 0.42), Color(white: 0.96)],
                    center: .center,
                    angle: .degrees(-40)
                ))
                .shadow(color: .black.opacity(0.5), radius: 8, y: 5)
            // Grip ridges and the index line turn with the dial; the metal's highlights stay with the light.
            ZStack {
                ForEach(0..<30, id: \.self) { index in
                    Capsule()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 2, height: 8)
                        .offset(y: -41)
                        .rotationEffect(.degrees(Double(index) * 12))
                }
                Capsule()
                    .fill(Color(hex: 0xFF4D5E))
                    .frame(width: 3, height: 15)
                    .offset(y: -22)
            }
            .rotationEffect(.degrees(angle))
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.62)], startPoint: .top, endPoint: .bottom))
                .frame(width: 28, height: 28)
            Text(verbatim: String(format: "%02d", number))
                .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(white: 0.15))
        }
        .frame(width: 94, height: 94)
    }

    private var pointer: some View {
        InputSafePointer()
            .fill(Color(hex: 0xFF4D5E))
            .frame(width: 14, height: 16)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .rotationEffect(.degrees(flick), anchor: .top)
            .offset(y: -(face + 22) / 2 - 2)
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                let center: CGFloat = (face + 22) / 2
                let dx = Double(value.location.x - center)
                let dy = Double(value.location.y - (center + 4))
                guard hypot(dx, dy) > 16 else { return }
                let theta = atan2(dy, dx) * 180 / .pi
                if physics.target == nil || physics.scriptedRate != nil {
                    physics.scriptedRate = nil
                    physics.target = angle
                    physics.lastTheta = theta
                    physics.relock?.cancel()
                }
                var delta = theta - physics.lastTheta
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                physics.lastTheta = theta
                physics.target = (physics.target ?? angle) + delta
                run()
            }
            .onEnded { _ in letGo() }
    }

    /// Finger lifted or gesture cancelled: the dial keeps its angular velocity and coasts.
    private func letGo() {
        guard physics.target != nil, physics.scriptedRate == nil else { return }
        physics.target = nil
        run()
        if unlocked { scheduleRelock() }
    }

    /// Starts the physics loop if it is not already running.
    private func run() {
        guard physics.loop == nil else { return }
        physics.loop = Task { @MainActor in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(8))
                let now = Date()
                let dt = min(now.timeIntervalSince(last), 1.0 / 30)
                last = now
                guard dt > 0 else { continue }
                if !advance(dt) { break }
            }
            physics.loop = nil
        }
    }

    /// One physics step. Returns false once the dial has come to rest.
    private func advance(_ dt: Double) -> Bool {
        var next = angle
        var resting = false
        if let target = physics.target {
            let rate = physics.scriptedRate ?? 1 / max(ctx["lag"], 0.01)
            next += (target - angle) * (1 - exp(-dt * rate))
            physics.omega = (next - angle) / dt
            if physics.scriptedRate != nil, abs(target - next) < 0.2 {
                next = target
                physics.target = nil
                physics.scriptedRate = nil
                physics.omega = 0
                resting = true
            }
        } else {
            physics.omega *= exp(-ctx["friction"] * dt)
            next += physics.omega * dt
            if abs(physics.omega) < 60 {
                // Slow enough: the detent spring takes over and seats the dial on a number.
                let detent = (next / 3.6).rounded() * 3.6
                next += (detent - next) * (1 - exp(-dt * 18))
                if abs(detent - next) < 0.05, abs(physics.omega) < 8 {
                    next = detent
                    physics.omega = 0
                    resting = true
                }
            }
        }
        angle = next
        let target = (physics.omega / 40).clamped(to: -16...16)
        flick += (target - flick) * (1 - exp(-dt * 30))
        if resting { withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { flick = 0 } }
        let raw = Int((-next / 3.6).rounded()) % 100
        let value = raw < 0 ? raw + 100 : raw
        if value != number {
            number = value
            if !ctx.isPreview { Haptics.selection() }
            scheduleDwell()
        }
        return !resting
    }

    // MARK: Combination

    private func scheduleDwell() {
        physics.dwell?.cancel()
        let wait = ctx["dwell"]
        physics.dwell = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled, !unlocked, pins < Self.combination.count else { return }
            let wanted = Self.combination[pins]
            let apart = abs(number - wanted)
            guard min(apart, 100 - apart) <= ctx.int("tolerance") else { return }
            setPin()
        }
    }

    private func setPin() {
        pins += 1
        if !ctx.isPreview { Haptics.tap(.rigid) }
        guard pins == Self.combination.count else { return }
        let quiet = ctx.isPreview
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.28))
            unlocked = true
            if !quiet { Haptics.success() }
            if !quiet { scheduleRelock() }
        }
    }

    private func scheduleRelock() {
        physics.relock?.cancel()
        physics.relock = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            relock()
        }
    }

    private func relock() {
        unlocked = false
        pins = 0
    }

    // MARK: Autoplay

    /// Turns the dial to `value` in the given direction through the same follow path a finger uses.
    private func spin(to value: Int, clockwise: Bool) {
        let wanted = -Double(value) * 3.6
        var delta = (wanted - angle).truncatingRemainder(dividingBy: 360)
        if clockwise {
            while delta < 90 { delta += 360 }
        } else {
            while delta > -90 { delta -= 360 }
        }
        physics.target = angle + delta
        physics.scriptedRate = 5.5
        run()
    }

    private func previewTick() {
        let phase = step % 5
        step += 1
        switch phase {
        case 0: spin(to: 30, clockwise: true)
        case 1: spin(to: 70, clockwise: false)
        case 2: spin(to: 15, clockwise: true)
        case 3: break
        default:
            relock()
            spin(to: 0, clockwise: false)
        }
    }
}

/// Static dial face: 100 ticks and a numeral every ten, drawn once and rotated as a layer.
private struct InputSafeFace: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer: CGFloat = size.width / 2
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.07)))
            for index in 0..<100 {
                let major = index % 10 == 0
                let mid = index % 5 == 0
                let length: CGFloat = major ? 15 : (mid ? 11 : 7)
                let radians: Double = Double(index) * 3.6 * .pi / 180
                let direction = CGPoint(x: CGFloat(sin(radians)), y: -CGFloat(cos(radians)))
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + direction.x * (outer - 4), y: center.y + direction.y * (outer - 4)))
                tick.addLine(to: CGPoint(x: center.x + direction.x * (outer - 4 - length), y: center.y + direction.y * (outer - 4 - length)))
                context.stroke(tick, with: .color(Color.white.opacity(major ? 0.95 : 0.6)), lineWidth: major ? 2 : 1)
                if major {
                    var local = context
                    local.translateBy(x: center.x, y: center.y)
                    local.rotate(by: .radians(radians))
                    let label = Text(verbatim: "\(index)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                    local.draw(label, at: CGPoint(x: 0, y: -(outer - 29)))
                }
            }
        }
    }
}

private struct InputSafePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
