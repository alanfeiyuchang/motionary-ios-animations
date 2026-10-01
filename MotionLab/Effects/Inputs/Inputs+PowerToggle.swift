import SwiftUI

extension Effect {
    static let inputsPowerToggle = Effect(
        id: "inputs.power-toggle",
        category: .inputs,
        interaction: .tap,
        name: L("Power Button", "电源键"),
        summary: L("Tap to power on: the glyph's stroke lights up line first, a glow ring expands; powering off leaves a slow afterglow.", "点按开机：图标笔画先竖线后圆弧依次点亮，光环向外扩散；关机后留下一段缓慢消散的余辉。"),
        prompt: L(
            "A round 136 pt power button on a soft raised disc with a recessed groove and an unlit grey power glyph. Tapping presses the disc to 95%, then powers on: the glyph's vertical bar lights top-down in 180 ms, and 140 ms later the arc lights from both ends of its gap, meeting at the bottom after 420 ms. The lit stroke is a saturated tint with a blurred copy behind it as bloom; a halo fades in on a spring (response 0.5 s, damping 0.7). Two thin rings leave the rim 120 ms apart and expand to 2.2× while thinning and fading over 0.8 s. A status pill below switches its LED and label with a blur replace. Tapping again powers off: the crisp stroke dims quickly while the bloom and halo linger as an afterglow, easing out over 0.9 s.",
            "136pt 圆形电源键：微凸的圆盘带一圈凹槽，中间是未点亮的灰色电源图标。点按时圆盘压到 95%，随即开机：图标竖线在 180 毫秒内自上而下点亮，140 毫秒后圆弧从缺口两端同时亮起，420 毫秒后在底部合拢。点亮的笔画是高饱和主色，背后叠一层模糊副本作光晕，四周辉光以弹簧淡入（响应 0.5 秒、阻尼 0.7）。两道细光环相隔 120 毫秒离开边缘，在 0.8 秒内扩散到 2.2 倍，并变细变淡。下方状态胶囊以模糊替换切换。再点一次关机：清晰的笔画很快变暗，光晕与辉光却作为余辉停留，0.9 秒内缓缓熄灭。"
        ),
        implementation: L(
            "The glyph is an animatable Shape with two trims (bar, and an arc drawn from both gap ends); three copies are stacked: grey base, lit stroke, blurred bloom. Light level and bloom are separate animated values so power-off can fade them at different speeds, and each ring is an Animatable view whose scale, width and opacity come from one 0→1 value.",
            "图标是带两个 trim 的可动画 Shape（竖线，以及从缺口两端画起的圆弧），叠三层：灰色底、点亮笔画、模糊光晕。亮度与光晕是两个独立的动画值，关机时可以用不同速度消退；每道光环是一个 Animatable 视图，缩放、线宽与透明度都来自同一个 0→1 的值。"
        ),
        apis: ["Shape", "AnimatablePair", "ButtonStyle", "blur(radius:)", "spring(response:dampingFraction:)", "transition(.blurReplace)"],
        tags: ["power", "toggle", "switch", "glow", "afterglow", "电源", "开关", "辉光", "余辉", "光环"],
        params: [
            .choice("tint", L("Glow colour", "辉光颜色"), [L("Mint", "薄荷"), L("Sky", "天蓝"), L("Amber", "琥珀"), L("Pink", "粉")], default: 0),
            .slider("ring", L("Ring reach", "光环扩散"), 1.4...3.0, default: 2.2, decimals: 1, unit: "×"),
            .slider("afterglow", L("Afterglow", "余辉时长"), 0.3...2.5, default: 0.9, unit: "s"),
        ]
    ) { ctx in
        InputPowerToggleDemo(ctx: ctx)
    }
}

private struct InputPowerToggleDemo: View {
    let ctx: DemoContext
    @State private var isOn: Bool
    /// Crisp lit stroke, 0...1.
    @State private var lit: Double
    /// Bloom and halo, 0...1. Fades slower than `lit` when powering off.
    @State private var glow: Double
    @State private var bar: CGFloat
    @State private var arc: CGFloat
    @State private var ringA: CGFloat = 0
    @State private var ringB: CGFloat = 0
    @State private var taps = 0
    @State private var resetTask: Task<Void, Never>?

    private let size: CGFloat = 136

    init(ctx: DemoContext) {
        self.ctx = ctx
        let on = ctx.isStill
        _isOn = State(initialValue: on)
        _lit = State(initialValue: on ? 1 : 0)
        _glow = State(initialValue: on ? 1 : 0)
        _bar = State(initialValue: on ? 1 : 0)
        _arc = State(initialValue: on ? 1 : 0)
    }

    private var tint: Color {
        let options: [Color] = [Palette.mint, Palette.sky, Palette.amber, Palette.pink]
        return options[ctx.int("tint").clamped(to: 0...options.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                halo
                ring(ringA)
                ring(ringB)
                Button(action: toggle) { disc }
                    .buttonStyle(InputPowerPressStyle(taps: taps))
            }
            .frame(width: 300, height: 208)
            status
            Spacer(minLength: 0)
            DemoHint(text: L("Tap the power button", "点按电源键"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9, delay: 0.5) { toggle() }
        .onDisappear { resetTask?.cancel() }
    }

    // MARK: Pieces

    private var halo: some View {
        Circle()
            .fill(RadialGradient(colors: [tint.opacity(0.5), tint.opacity(0.16), tint.opacity(0)], center: .center, startRadius: 50, endRadius: 132))
            .frame(width: 264, height: 264)
            .opacity(glow)
            .scaleEffect(0.86 + 0.14 * glow)
            .allowsHitTesting(false)
    }

    private func ring(_ progress: CGFloat) -> some View {
        InputPowerRing(progress: progress, reach: ctx.cg("ring"), tint: tint, size: size)
    }

    private var disc: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Palette.elevated, Palette.surface], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.55), Color.black.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 16, y: 12)
                .shadow(color: tint.opacity(0.35 * glow), radius: 22)
            Circle()
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 5)
                .padding(11)
            Circle()
                .strokeBorder(tint.opacity(0.9 * lit), lineWidth: 1.5)
                .padding(13)
                .shadow(color: tint.opacity(glow), radius: 5)
            glyph
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }

    private var glyph: some View {
        let style = StrokeStyle(lineWidth: 7, lineCap: .round)
        return ZStack {
            InputPowerGlyph(bar: 1, arc: 1)
                .stroke(Color.primary.opacity(0.2), style: style)
            InputPowerGlyph(bar: bar, arc: arc)
                .stroke(tint, style: style)
                .blur(radius: 9)
                .opacity(glow)
            InputPowerGlyph(bar: bar, arc: arc)
                .stroke(tint, style: style)
                .opacity(lit)
            InputPowerGlyph(bar: bar, arc: arc)
                .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .opacity(lit)
        }
        .frame(width: 56, height: 56)
    }

    private var status: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isOn ? tint : Color.primary.opacity(0.25))
                .frame(width: 7, height: 7)
                .shadow(color: tint.opacity(isOn ? 0.9 : 0), radius: 4)
            Text(isOn ? L("Powered on", "已开机") : L("Standby", "待机"), ctx.language)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isOn ? Color.primary : Color.secondary)
                .id(isOn)
                .transition(.blurReplace)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .animation(.smooth(duration: 0.35), value: isOn)
    }

    // MARK: Actions

    private func toggle() {
        taps += 1
        resetTask?.cancel()
        if isOn {
            powerOff()
        } else {
            powerOn()
        }
    }

    private func powerOn() {
        isOn = true
        Haptics.tap(.medium)
        withAnimation(.easeOut(duration: 0.18)) { bar = 1 }
        withAnimation(.easeInOut(duration: 0.42).delay(0.14)) { arc = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            lit = 1
            glow = 1
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { ringA = 1 }
        withAnimation(.easeOut(duration: 0.8).delay(0.22)) { ringB = 1 }
    }

    private func powerOff() {
        isOn = false
        Haptics.tap(.soft)
        let afterglow = ctx["afterglow"]
        withAnimation(.easeOut(duration: afterglow * 0.4)) { lit = 0 }
        withAnimation(.easeOut(duration: afterglow)) { glow = 0 }
        // Rings are invisible at both ends of their travel, so they can jump home now.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            ringA = 0
            ringB = 0
        }
        // Once dark, un-draw the stroke so the next power-on lights it again.
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(afterglow + 0.05))
            guard !Task.isCancelled, !isOn else { return }
            withTransaction(instant) {
                bar = 0
                arc = 0
            }
        }
    }
}

/// One expanding ring. Animatable, so its opacity and width follow the travel instead of its end points.
private struct InputPowerRing: View, Animatable {
    var progress: CGFloat
    let reach: CGFloat
    let tint: Color
    let size: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let line = 0.8 + 4 * (1 - progress)
        return Circle()
            .strokeBorder(tint, lineWidth: line)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: line))
            .frame(width: size, height: size)
            .scaleEffect(1 + (reach - 1) * progress)
            .opacity(Double((1 - progress) * min(progress * 10, 1)))
            .allowsHitTesting(false)
    }
}

private struct InputPowerPressStyle: ButtonStyle {
    let taps: Int

    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(isPressed: configuration.isPressed, taps: taps) { pressed in
            configuration.label
                .scaleEffect(pressed ? 0.95 : 1)
                .brightness(pressed ? -0.03 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
    }
}

/// Power symbol: a bar drawn top-down and an open arc drawn from both ends of its gap.
private struct InputPowerGlyph: Shape {
    var bar: CGFloat
    var arc: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bar, arc) }
        set {
            bar = newValue.first
            arc = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.06)
        let radius = rect.width * 0.42
        var path = Path()
        let barAmount = min(max(bar, 0), 1)
        if barAmount > 0.001 {
            let top = rect.minY
            let length = rect.height * 0.46
            path.move(to: CGPoint(x: center.x, y: top))
            path.addLine(to: CGPoint(x: center.x, y: top + length * barAmount))
        }
        let arcAmount = Double(min(max(arc, 0), 1))
        if arcAmount > 0.001 {
            // Both halves start at the gap (±32° from 12 o'clock) and meet at 6 o'clock.
            let sweep = 148.0 * arcAmount
            for side in [1.0, -1.0] {
                var degrees = 32.0
                path.move(to: point(center, radius, side * degrees))
                while degrees < 32.0 + sweep {
                    degrees = min(degrees + 4, 32.0 + sweep)
                    path.addLine(to: point(center, radius, side * degrees))
                }
            }
        }
        return path
    }

    /// Point on the circle, `degrees` clockwise from 12 o'clock.
    private func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(sin(radians)), y: center.y - radius * CGFloat(cos(radians)))
    }
}
