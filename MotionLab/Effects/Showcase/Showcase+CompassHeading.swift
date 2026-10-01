import SwiftUI

extension Effect {
    static let showcaseCompassHeading = Effect(
        id: "showcase.compass-heading",
        category: .showcase,
        interaction: .tap,
        name: L("Compass Heading Swing", "指南针航向摆动"),
        summary: L(
            "The compass rose swings to a new heading with weight and overshoot; the degrees roll and the letters stay upright.",
            "罗盘带着重量摆向新航向并过冲回摆；度数随之滚动，方位字始终保持正立。"
        ),
        prompt: L(
            "A dark compass widget: a 178 pt dial with 2° ticks, numerals every 30° and the four cardinal letters, under a fixed orange lubber triangle at 12 o'clock, with a large degree readout and the direction name above. Tapping picks a new heading and the whole rose rotates there along the shorter way on an under-damped spring (response 0.9 s, damping 0.42), overshooting and swinging back twice like a needle with real rotational inertia. The readout is derived from the animating angle, so the degrees run and settle with the dial, while every letter and numeral counter-rotates to stay upright. The north marker glows orange more strongly the closer it gets to the lubber, with a tick each time the dial passes a 30° mark. Dragging turns the rose directly; on release it coasts by 0.3 s of its angular velocity before settling. Mechanical, weighty.",
            "深色指南针小组件：178pt 表盘刻着每 2° 一格的刻度、每 30° 一个数字和四个方位字，顶部是固定的橙色指示三角，上方为大号度数与方位名称。点击后选定新航向，整个罗盘沿较短方向转过去，用欠阻尼弹簧（响应 0.9 秒、阻尼 0.42）过冲并回摆两次，像一根真有转动惯量的指针。读数由动画中的角度推导，度数跟着表盘一起跑动；所有文字反向旋转，始终正立。北向标记越接近指示三角，橙色辉光越强；表盘每过一个 30° 刻度有一次轻触感。也可直接拖动转盘，松手后按 0.3 秒的角速度滑行再落定。厚重。"
        ),
        implementation: L(
            "The card is an Animatable view whose animatableData is the unbounded heading, so the spring interpolates the angle and the body recomputes the readout, the north glow and the labels' counter-rotation per frame. Ticks are drawn once in a Canvas and rotated with rotationEffect. A DragGesture accumulates wrapped polar deltas, estimates angular velocity and projects the release target.",
            "卡片是 Animatable 视图，animatableData 为不设上限的航向角，弹簧插值角度，body 逐帧重算读数、北向辉光与文字的反向旋转。刻度在 Canvas 中一次绘制后用 rotationEffect 旋转。DragGesture 累加去环绕后的极角增量、估算角速度，并据此推算松手后的目标角度。"
        ),
        apis: ["Animatable", "spring(response:dampingFraction:)", "rotationEffect", "Canvas", "DragGesture", "onChange(of:)"],
        tags: ["compass", "heading", "rotation", "inertia", "overshoot", "指南针", "航向", "罗盘", "惯性", "过冲"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.4...1.6, default: 0.9, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.2...1.0, default: 0.42),
            .toggle("upright", L("Upright letters", "文字保持正立"), default: true),
            .slider("glow", L("North glow", "北向辉光"), 0...1.5, default: 1.0),
        ]
    ) { ctx in
        CompassHeadingDemo(ctx: ctx)
    }
}

private struct CompassHeadingDemo: View {
    let ctx: DemoContext
    @State private var heading: Double = 247
    @State private var step = 0
    @State private var dragging = false
    @State private var moved: CGFloat = 0
    @State private var lastAngle: Double = 0
    @State private var lastMove = Date()
    @State private var omega: Double = 0
    /// Haptics follow the dial only when a finger set it in motion.
    @State private var userDriven = false
    @GestureState private var finger = false

    private let dial: CGFloat = 178
    private static let targets: [Double] = [12, 138, 301, 64, 355, 190, 247]

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                CompassCard(
                    heading: heading,
                    upright: ctx.bool("upright"),
                    glow: ctx["glow"],
                    zh: ctx.language == .zh,
                    haptics: userDriven && !ctx.isPreview,
                    dial: dial,
                    gesture: AnyGesture(turnGesture.map { _ in () })
                )
                .onChange(of: finger) { _, down in
                    if !down { release() }
                }
                Spacer(minLength: 0)
                DemoHint(text: L("Tap for a new heading · drag to turn", "点击换一个航向 · 拖动转盘"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .autoplay(ctx.isPreview, every: 2.4, delay: 0.6) {
            userDriven = false
            swing()
        }
    }

    private var spring: Animation {
        .spring(response: ctx["response"], dampingFraction: ctx["damping"])
    }

    /// Rotates to the next heading the shorter way round.
    private func swing() {
        let target = Self.targets[step % Self.targets.count]
        step += 1
        let current = heading.truncatingRemainder(dividingBy: 360)
        var delta = (target - current).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        withAnimation(spring) { heading += delta }
    }

    private var turnGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($finger) { _, state, _ in state = true }
            .onChanged { value in
                let angle = atan2(Double(value.location.y - dial / 2), Double(value.location.x - dial / 2)) * 180 / .pi
                if !dragging {
                    dragging = true
                    userDriven = true
                    moved = 0
                    omega = 0
                    lastAngle = angle
                    lastMove = Date()
                    return
                }
                var delta = angle - lastAngle
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                lastAngle = angle
                moved = max(moved, abs(value.translation.width) + abs(value.translation.height))
                guard moved > 6 else { return }
                let now = Date()
                let dt = max(now.timeIntervalSince(lastMove), 1.0 / 240.0)
                lastMove = now
                omega = omega * 0.6 + (delta / dt) * 0.4
                // Turning the rose clockwise lowers the heading under the lubber.
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { heading -= delta }
            }
            .onEnded { _ in
                if moved <= 6 {
                    dragging = false
                    Haptics.tap(.light)
                    swing()
                } else {
                    release()
                }
            }
    }

    private func release() {
        guard dragging else { return }
        dragging = false
        guard moved > 6 else { return }
        let coast = Date().timeIntervalSince(lastMove) > 0.09 ? 0 : omega.clamped(to: -900...900) * 0.3
        withAnimation(spring) { heading = (heading - coast).rounded() }
    }
}

// MARK: - Card

private struct CompassCard: View, Animatable {
    var heading: Double
    let upright: Bool
    let glow: Double
    let zh: Bool
    let haptics: Bool
    let dial: CGFloat
    let gesture: AnyGesture<Void>

    var animatableData: Double {
        get { heading }
        set { heading = newValue }
    }

    private var normalized: Double {
        let value = heading.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// 0…1, strongest when north sits under the lubber.
    private var northness: Double {
        let distance = min(normalized, 360 - normalized)
        return max(0, 1 - distance / 24)
    }

    var body: some View {
        let degrees = Int(normalized.rounded()) % 360
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(degrees)°")
                    .font(Signature.number(38))
                    .foregroundStyle(Color.white)
                    .fixedSize()
                Text(verbatim: sector(degrees))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Signature.accent)
                    .contentTransition(.opacity)
                    .fixedSize()
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(verbatim: "31.23°N")
                    Text(verbatim: "121.47°E")
                }
                .signatureEyebrow()
                .fixedSize()
            }
            face
        }
        .padding(16)
        .frame(width: 280)
        .signatureCard()
        .onChange(of: Int((heading / 30).rounded(.down))) { _, _ in
            if haptics { Haptics.tap(.light) }
        }
    }

    private func sector(_ degrees: Int) -> String {
        let en = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let cn = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let index = Int((Double(degrees) + 22.5) / 45) % 8
        return zh ? cn[index] + " " + en[index] : en[index]
    }

    private var face: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x26262B), Color(hex: 0x0C0C0F)], center: .center, startRadius: 30, endRadius: dial / 2))
            Circle()
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            rose
                .rotationEffect(.degrees(-heading))
            // Fixed parts: crosshair, glass sheen, lubber.
            crosshair
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .center))
                .padding(3)
                .allowsHitTesting(false)
            CompassLubber()
                .fill(Signature.accentGradient)
                .frame(width: 16, height: 13)
                .shadow(color: Signature.accent.opacity(0.4 + 0.6 * min(northness * glow, 1)), radius: 4 + 8 * northness * glow)
                .offset(y: -dial / 2 - 1)
        }
        .frame(width: dial, height: dial)
        .contentShape(Circle())
        .gesture(gesture)
        .padding(.top, 8)
    }

    private var rose: some View {
        let north = northness * glow
        return ZStack {
            CompassTicks()
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30
                if index % 3 != 0 {
                    label(String(Int(angle)), size: 10, weight: .semibold, color: Color.white.opacity(0.6), angle: angle, radius: dial / 2 - 26)
                }
            }
            ForEach(0..<4, id: \.self) { index in
                let letters = zh ? ["北", "东", "南", "西"] : ["N", "E", "S", "W"]
                label(
                    letters[index],
                    size: 16,
                    weight: .heavy,
                    color: index == 0 ? Signature.accent : Color.white,
                    angle: Double(index) * 90,
                    radius: dial / 2 - 30
                )
            }
            // North marker with its glow.
            CompassLubber()
                .fill(Signature.accentHot)
                .frame(width: 9, height: 10)
                .rotationEffect(.degrees(180))
                .shadow(color: Signature.accent.opacity(min(north, 1)), radius: 3 + 9 * north)
                .shadow(color: Signature.accentSoft.opacity(min(north * 0.8, 1)), radius: 14 * north)
                .offset(y: -dial / 2 + 9)
        }
    }

    private func label(_ text: String, size: CGFloat, weight: Font.Weight, color: Color, angle: Double, radius: CGFloat) -> some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .rotationEffect(.degrees(upright ? heading - angle : 0))
            .offset(y: -radius)
            .rotationEffect(.degrees(angle))
    }

    private var crosshair: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.2)).frame(width: 34, height: 1)
            Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 34)
            Circle()
                .fill(Signature.cardHigh)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        }
        .allowsHitTesting(false)
    }
}

private struct CompassTicks: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.width / 2 - 5
            for index in 0..<180 {
                let degrees = index * 2
                // The north marker replaces the tick at 0°.
                if degrees == 0 { continue }
                let major = degrees % 30 == 0
                let mid = degrees % 10 == 0
                let length: CGFloat = major ? 10 : (mid ? 7 : 4)
                let angle = Double(degrees) * .pi / 180 - .pi / 2
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * (outer - length), y: center.y + CGFloat(sin(angle)) * (outer - length)))
                tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer, y: center.y + CGFloat(sin(angle)) * outer))
                context.stroke(
                    tick,
                    with: .color(.white.opacity(major ? 0.9 : (mid ? 0.5 : 0.24))),
                    style: StrokeStyle(lineWidth: major ? 2 : 1, lineCap: .round)
                )
            }
        }
    }
}

/// A triangle pointing down.
private struct CompassLubber: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
