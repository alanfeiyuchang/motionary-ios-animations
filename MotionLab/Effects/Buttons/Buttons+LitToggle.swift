import SwiftUI

extension Effect {
    static let buttonsLitToggle = Effect(
        id: "buttons.lit-toggle",
        category: .buttons,
        interaction: .tap,
        name: L("Latching Lit Button", "自锁发光按钮"),
        summary: L(
            "A hardware-style push button that stays down and lights up; press again and it pops back, the lamp cooling off.",
            "像硬件上的自锁按键：按下后停在低位并亮起；再按一次弹回，灯慢慢冷却熄灭。"
        ),
        prompt: L(
            "A round 124 pt push button sits in a darker bezel well. Touch-down drives the cap to the bottom of its travel (91.5% scale, shadow collapsed, inner rim shadow thickening) on a fast spring (response 0.18 s, damping 0.8) with a rigid click. Release latches it: it rebounds only to 95% and stays there, and 60 ms later the lamp warms up on a spring (response 0.25 s, damping 0.5) that overshoots brighter before settling: the cap fills with a radial amber glow, the power glyph turns white with a halo, light leaks through the gap around the cap and washes the surface behind. Pressing again bottoms out, then pops fully up with overshoot (response 0.32 s, damping 0.5) while the glow cools over 0.45 s. Mechanical, weighty, trustworthy.",
            "直径 124pt 的圆形按键嵌在颜色更深的座圈里。按下时，键帽以快速弹簧（响应 0.18 秒、阻尼 0.8）压到行程底部：缩放到 91.5%，投影收拢，内缘阴影加厚，伴随一次硬朗的“咔嗒”触感。松手后自锁：只回弹到 95% 并停住；60 毫秒后灯以弹簧（响应 0.25 秒、阻尼 0.5）升温，先过冲得更亮再稳定——键帽内充满琥珀色径向辉光，电源符号变白带光晕，光从键帽四周的缝隙漏出，洒在背后的表面上。再按一次先触底，再带过冲完全弹起（响应 0.32 秒、阻尼 0.5），辉光在 0.45 秒内冷却熄灭。"
        ),
        implementation: L(
            "Two pieces of state: `pressed` from a zero-distance DragGesture and the latched `isOn`. Cap scale, shadow and inner shadow derive from both; a separate `glow` value is animated with its own delayed spring (on) or ease-out (off), so the light lags the mechanics like a real lamp.",
            "两份状态：零距离 DragGesture 给出的 `pressed`，以及自锁的 `isOn`。键帽缩放、投影与内阴影由二者共同决定；另有独立的 `glow` 数值，用带延迟的弹簧（开）或缓出（关）单独驱动，让灯光像真实灯泡一样滞后于机械动作。"
        ),
        apis: ["DragGesture", "spring(response:dampingFraction:)", "RadialGradient", "blur", "contentTransition"],
        tags: ["toggle", "latch", "push button", "lit", "glow", "自锁", "发光", "按键", "开关", "硬件"],
        params: [
            .slider("travel", L("Latch depth", "自锁深度"), 0.02...0.1, default: 0.05),
            .slider("glow", L("Glow intensity", "发光强度"), 0.3...1.0, default: 0.8),
            .slider("warm", L("Warm-up response", "升温响应"), 0.1...0.6, default: 0.25, unit: "s"),
            .choice("color", L("Lamp colour", "灯光颜色"), [L("Amber", "琥珀"), L("Mint", "薄荷"), L("Pink", "粉"), L("Sky", "天蓝")]),
        ]
    ) { ctx in
        ButtonLitDemo(ctx: ctx)
    }
}

private struct ButtonLitDemo: View {
    let ctx: DemoContext
    @State private var isOn: Bool
    @State private var pressed = false
    @State private var glow: Double
    @State private var scriptTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme

    private static let lamps: [Color] = [Palette.amber, Palette.mint, Palette.pink, Palette.sky]

    init(ctx: DemoContext) {
        self.ctx = ctx
        _isOn = State(initialValue: ctx.isStill)
        _glow = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var lamp: Color { Self.lamps[min(max(ctx.int("color"), 0), Self.lamps.count - 1)] }
    private var travel: CGFloat { ctx.cg("travel") }
    /// 0 = fully up, 1 = bottomed out; the latch rests at 0.6.
    private var depth: CGFloat { pressed ? 1 : (isOn ? 0.6 : 0) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                button
                status
            }
            Spacer()
            DemoHint(text: L("Press to latch, press again to release", "按一下锁定，再按一下弹起"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.5) {
            if ctx.isPreview { simulatePress() } else { playIntro() }
        }
        .onDisappear { scriptTask?.cancel() }
    }

    private var button: some View {
        let intensity = ctx["glow"] * glow
        return ZStack {
            // Light washing over the surface behind the button.
            Circle()
                .fill(lamp)
                .frame(width: 190, height: 190)
                .blur(radius: 34)
                .opacity(0.5 * intensity)
            bezel
            // Light leaking through the gap between cap and bezel.
            Circle()
                .strokeBorder(lamp, lineWidth: 5)
                .frame(width: 134, height: 134)
                .blur(radius: 3)
                .opacity(min(intensity * 1.1, 1))
            cap(intensity: intensity)
        }
        .frame(width: 200, height: 200)
        .contentShape(Circle())
        .gesture(pressGesture)
        .accessibilityAddTraits(.isButton)
    }

    private var bezel: some View {
        let dark = colorScheme == .dark
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: dark ? [Color(hex: 0x4A4A52), Color(hex: 0x1E1E22)] : [Color.white, Color(hex: 0xC9C9D2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 158, height: 158)
                .shadow(color: .black.opacity(dark ? 0.5 : 0.18), radius: 14, y: 10)
            Circle()
                .fill(dark ? Color(hex: 0x0B0B0D) : Color(hex: 0x8E8E99))
                .frame(width: 138, height: 138)
            Circle()
                .strokeBorder(Color.black.opacity(0.45), lineWidth: 6)
                .blur(radius: 4)
                .frame(width: 138, height: 138)
        }
    }

    private func cap(intensity: Double) -> some View {
        let dark = colorScheme == .dark
        let off: [Color] = dark ? [Color(hex: 0x45454C), Color(hex: 0x28282D)] : [Color(hex: 0xFAFAFC), Color(hex: 0xD9D9E0)]
        return ZStack {
            Circle().fill(LinearGradient(colors: off, startPoint: .top, endPoint: .bottom))
            // The lamp inside the cap: hot centre, saturated body, darker rim.
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: lamp.mix(with: .white, by: 0.65), location: 0),
                            .init(color: lamp, location: 0.55),
                            .init(color: lamp.mix(with: .black, by: 0.28), location: 1),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 64
                    )
                )
                .opacity(min(intensity * 1.15, 1))
            // The deeper the cap sits, the more the well's wall shades its edge.
            Circle()
                .strokeBorder(Color.black.opacity(0.1 + 0.3 * depth), lineWidth: 4 + 6 * depth)
                .blur(radius: 4)
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(dark ? 0.35 : 0.9), .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 1.2
                )
            Image(systemName: "power")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.45))
                .overlay {
                    Image(systemName: "power")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.9), radius: 8)
                        .opacity(min(intensity * 1.3, 1))
                }
        }
        .frame(width: 124, height: 124)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.35 - 0.2 * depth), radius: 9 - 7 * depth, y: 7 - 6 * depth)
        .scaleEffect(1 - travel * 1.7 * depth)
    }

    private var status: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isOn ? lamp : Color.primary.opacity(0.2))
                .frame(width: 7, height: 7)
                .shadow(color: lamp.opacity(isOn ? 0.9 : 0), radius: 4)
            Text(isOn ? L("Latched on", "已锁定 · 开") : L("Released", "已弹起 · 关"), ctx.language)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !pressed else { return }
                scriptTask?.cancel()
                pressDown()
                Haptics.tap(.rigid)
            }
            .onEnded { _ in
                letGo()
                Haptics.tap(.light)
            }
    }

    // MARK: Behaviour

    private func pressDown() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.8)) { pressed = true }
    }

    private func letGo() {
        let turningOn = !isOn
        withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) {
            pressed = false
            isOn = turningOn
        }
        if turningOn {
            withAnimation(.spring(response: ctx["warm"], dampingFraction: 0.5).delay(0.06)) { glow = 1 }
        } else {
            withAnimation(.easeOut(duration: 0.45)) { glow = 0 }
        }
    }

    /// One full press: down, a short dwell at the bottom, then release.
    private func simulatePress() {
        pressDown()
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            letGo()
        }
    }

    /// Detail intro: latch on, then release, so the page never arrives with the lamp left on.
    private func playIntro() {
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            pressDown()
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            letGo()
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled else { return }
            pressDown()
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            letGo()
        }
    }
}
