import SwiftUI

extension Effect {
    static let buttonsIconKick = Effect(
        id: "buttons.icon-kick",
        category: .buttons,
        interaction: .tap,
        name: L("Icon Kick", "图标踢起"),
        summary: L(
            "A tap kicks the leading icon into a spinning jump; it falls under gravity and lands with a squash.",
            "点击把前置图标踢得翻转跃起，受重力落下，着地时压扁回弹。"
        ),
        prompt: L(
            "A 224 × 60 pt pill button with a leading bolt icon and a label. On tap the button dips to 96% and the icon crouches for 90 ms (70% tall, 118% wide, anchored at its base), then launches: it follows a true parabola 46 pt high over 0.52 s while spinning one full turn at constant angular speed, stretched 14% along the take-off. Its contact shadow on the button shrinks and fades with height. The label is nudged 5 pt away and springs back. On landing the icon squashes to 70% tall, two short impact streaks shoot outward and fade in 0.3 s, a rigid haptic fires, then a second hop one sixth as high settles it with a bouncy spring. Playful, weighty, satisfying.",
            "224×60pt 的胶囊按钮，左侧是闪电图标，右侧是文字。点击时按钮下沉到 96%，图标先下蹲 90 毫秒（以底部为锚点压到 70% 高、118% 宽），随后弹射：沿真实抛物线跃起 46pt，滞空 0.52 秒，同时匀角速度翻转一整圈，起跳瞬间纵向拉长 14%。它投在按钮上的接触阴影随高度缩小变淡。文字被顶开 5pt 再弹回。落地时图标压扁到 70% 高，两道短促的冲击线向两侧射出并在 0.3 秒内淡出，同时触发一次硬朗触感；接着再来一次高度只有六分之一的小跳，由弹簧收稳。俏皮、有分量、令人满足。"
        ),
        implementation: L(
            "One keyframeAnimator drives a values struct: linear 0→1 tracks for the main flight and the small hop are turned into parabolas (4h·t·(1−t)) and a rotation in the content closure, while separate tracks animate squash, label nudge, press scale and the impact streaks.",
            "用一个 keyframeAnimator 驱动一组数值：主跳与小跳各有一条 0→1 的线性轨道，在内容闭包里换算成抛物线（4h·t·(1−t)）与旋转角；压扁、文字位移、按压缩放和冲击线各用独立轨道。"
        ),
        apis: ["keyframeAnimator", "KeyframeTrack", "SpringKeyframe", "scaleEffect(x:y:anchor:)", "rotationEffect"],
        tags: ["icon", "kick", "jump", "squash", "gravity", "图标", "跳跃", "压扁", "重力", "翻转"],
        params: [
            .slider("height", L("Jump height", "跳跃高度"), 20...80, default: 46, decimals: 0, unit: "pt"),
            .slider("spins", L("Spins", "翻转圈数"), 0...3, default: 1, step: 1, decimals: 0),
            .slider("air", L("Air time", "滞空时间"), 0.3...0.9, default: 0.52, unit: "s"),
            .slider("squash", L("Landing squash", "落地压扁"), 0...0.5, default: 0.3),
        ]
    ) { ctx in
        ButtonKickDemo(ctx: ctx)
    }
}

private struct ButtonKickValues {
    /// 0→1 over the main flight, 0→1 again over the small second hop.
    var flight: Double = 0
    var hop: Double = 0
    var squashX: CGFloat = 1
    var squashY: CGFloat = 1
    var nudge: CGFloat = 0
    var press: CGFloat = 1
    /// 0→1 travel of the impact streaks; 1 means gone.
    var impact: Double = 1
}

private struct ButtonKickDemo: View {
    let ctx: DemoContext
    @State private var kicks = 0
    @State private var landTask: Task<Void, Never>?

    private var air: Double { max(ctx["air"], 0.1) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Button(action: kick) {
                if ctx.isStill {
                    ButtonKickFace(values: Self.stillValues, ctx: ctx)
                } else {
                    animatedFace
                }
            }
            .buttonStyle(.plain)
            Spacer()
            DemoHint(text: L("Tap the button", "点击按钮"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7, delay: 0.4) { kick() }
        .onDisappear { landTask?.cancel() }
    }

    private static var stillValues: ButtonKickValues {
        var values = ButtonKickValues()
        values.flight = 0.42
        values.nudge = 3
        return values
    }

    private var animatedFace: some View {
        let air = air
        let squash = ctx.cg("squash")
        return ButtonKickFace(values: ButtonKickValues(), ctx: ctx)
            .keyframeAnimator(initialValue: ButtonKickValues(), trigger: kicks) { _, values in
                ButtonKickFace(values: values, ctx: ctx)
            } keyframes: { _ in
                KeyframeTrack(\.flight) {
                    LinearKeyframe(0, duration: 0.09)
                    LinearKeyframe(1, duration: air)
                }
                KeyframeTrack(\.hop) {
                    LinearKeyframe(0, duration: 0.09 + air + 0.05)
                    LinearKeyframe(1, duration: air * 0.4)
                }
                KeyframeTrack(\.squashY) {
                    CubicKeyframe(0.7, duration: 0.09)
                    CubicKeyframe(1.14, duration: 0.07)
                    CubicKeyframe(1, duration: air - 0.1)
                    CubicKeyframe(1 - squash, duration: 0.06)
                    CubicKeyframe(1.04, duration: air * 0.2)
                    CubicKeyframe(1, duration: air * 0.2)
                    CubicKeyframe(1 - squash * 0.4, duration: 0.05)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                }
                KeyframeTrack(\.squashX) {
                    CubicKeyframe(1.18, duration: 0.09)
                    CubicKeyframe(0.9, duration: 0.07)
                    CubicKeyframe(1, duration: air - 0.1)
                    CubicKeyframe(1 + squash * 0.8, duration: 0.06)
                    CubicKeyframe(0.98, duration: air * 0.2)
                    CubicKeyframe(1, duration: air * 0.2)
                    CubicKeyframe(1 + squash * 0.3, duration: 0.05)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                }
                KeyframeTrack(\.nudge) {
                    CubicKeyframe(-1.5, duration: 0.09)
                    CubicKeyframe(5, duration: 0.1)
                    SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.press) {
                    CubicKeyframe(0.96, duration: 0.09)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    LinearKeyframe(1, duration: max(air - 0.4, 0.01))
                    CubicKeyframe(0.985, duration: 0.05)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
                KeyframeTrack(\.impact) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.09 + air - 0.01)
                    MoveKeyframe(0)
                    CubicKeyframe(1, duration: 0.3)
                }
            }
    }

    private func kick() {
        kicks += 1
        Haptics.tap(.light)
        landTask?.cancel()
        guard !ctx.isPreview else { return }
        let landing = 0.09 + air
        landTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(landing))
            guard !Task.isCancelled else { return }
            Haptics.tap(.rigid)
        }
    }
}

private struct ButtonKickFace: View {
    let values: ButtonKickValues
    let ctx: DemoContext

    private var height: CGFloat { ctx.cg("height") }

    /// Height above the button right now: the main parabola, then a hop one sixth as high.
    private var lift: CGFloat {
        let main = 4 * values.flight * (1 - values.flight)
        let small = 4 * values.hop * (1 - values.hop)
        return height * CGFloat(main) + height / 6 * CGFloat(small)
    }

    var body: some View {
        let lift = lift
        let closeness = 1 - min(lift / max(height, 1), 1)
        HStack(spacing: 10) {
            icon(lift: lift, closeness: closeness)
            Text(ctx.language == .zh ? "立即加速" : "Boost now")
                .font(.headline)
                .offset(x: values.nudge)
        }
        .foregroundStyle(.white)
        .frame(width: 224, height: 60)
        .background(Palette.primaryStrong, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        )
        .shadow(color: Palette.indigo.opacity(0.4), radius: 14, y: 8)
        .scaleEffect(values.press)
        .contentShape(Capsule())
    }

    private func icon(lift: CGFloat, closeness: CGFloat) -> some View {
        let turn = Angle.degrees(360 * ctx["spins"].rounded() * values.flight)
        return ZStack {
            // Contact shadow on the button face: tight when the icon is down, wide and faint when it is up.
            Ellipse()
                .fill(Color.black.opacity(0.1 + 0.25 * closeness))
                .frame(width: 12 + 12 * closeness, height: 5)
                .blur(radius: 1.5)
                .offset(y: 13)
            ButtonKickStreaks(travel: values.impact)
                .offset(y: 11)
            Image(systemName: "bolt.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Palette.amber)
                .shadow(color: Palette.amber.opacity(0.6), radius: 5)
                .rotationEffect(turn)
                .scaleEffect(x: values.squashX, y: values.squashY, anchor: .bottom)
                .offset(y: -lift)
        }
        .frame(width: 26, height: 30)
    }
}

/// Two short streaks that shoot sideways from the landing point.
private struct ButtonKickStreaks: View {
    let travel: Double

    var body: some View {
        let fade = 1 - travel
        HStack(spacing: 14 + 22 * travel) {
            Capsule().frame(width: 9 * fade + 2, height: 2.4)
            Capsule().frame(width: 9 * fade + 2, height: 2.4)
        }
        .foregroundStyle(Color.white.opacity(0.9 * fade))
    }
}
