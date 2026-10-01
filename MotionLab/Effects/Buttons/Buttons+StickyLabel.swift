import SwiftUI

extension Effect {
    static let buttonsStickyLabel = Effect(
        id: "buttons.sticky-label",
        category: .buttons,
        interaction: .gesture,
        name: L("Sticky Label", "黏性标签"),
        summary: L(
            "The label puck trails the finger on an elastic tether, stretching as it goes, then snaps home.",
            "标签滑块被一根弹性系带拴着，拉伸着跟在手指后面，松手后弹回原位。"
        ),
        prompt: L(
            "A 244 × 68 pt gradient capsule carries its label on a white 122 × 42 pt puck that rests in a darker inset slot. Dragging on the button pulls the puck toward the finger, but with resistance: its travel is rubber-banded to about 54 pt horizontally and 40% of that vertically, and it follows on a lagging spring (response 0.16 s, damping 0.72) so it visibly trails fast movements. A translucent tether stretches across the slot the puck has left, thinning in the middle as it lengthens, while the puck itself elongates up to 30% along the pull, narrows across it and tilts a few degrees; the whole button leans 8% of the pull. On release the puck snaps home on a bouncy spring (response 0.36 s, damping 0.42), wobbling past centre twice, with a rigid haptic as it lands. Gummy, elastic, tactile.",
            "244×68pt 的渐变胶囊按钮，文字放在一枚 122×42pt 的白色滑块上，滑块平时嵌在更深的凹槽里。在按钮上拖动会把滑块拉向手指，但带有阻力：位移被橡皮筋限制在水平约 54pt、垂直为其 40%，并由滞后的弹簧（响应 0.16 秒、阻尼 0.72）跟随，快速移动时明显拖后。一条半透明系带横跨滑块让出的凹槽，越长中段越细；滑块沿拉力最多拉长 30%、横向收窄并微倾；整个按钮随之偏移拉力的 8%。松手后滑块以高弹性弹簧（响应 0.36 秒、阻尼 0.42）弹回，越过中心晃动两次，落位时触发硬朗触感。"
        ),
        implementation: L(
            "The puck's offset is one animated CGSize. An Animatable view reads it every frame to draw the tether (a quad-curve band whose waist narrows with length) and to stretch and slightly tilt the puck from the pull's horizontal and vertical parts. A zero-distance DragGesture feeds a rubberBand-limited target.",
            "滑块的偏移是一个带动画的 CGSize。一个 Animatable 视图逐帧读取它：画出系带（腰部随长度收窄的二次曲线带），并根据拉力的水平与垂直分量拉伸、微微倾斜滑块。零距离 DragGesture 提供经 rubberBand 限制的目标位置。"
        ),
        apis: ["Animatable", "DragGesture", "spring(response:dampingFraction:)", "Path.addQuadCurve", "scaleEffect(x:y:anchor:)"],
        tags: ["sticky", "elastic", "tether", "label", "stretch", "黏性", "弹性", "系带", "拉伸", "回弹"],
        params: [
            .slider("reach", L("Reach", "可拉距离"), 20...90, default: 54, decimals: 0, unit: "pt"),
            .slider("lag", L("Follow response", "跟随响应"), 0.05...0.4, default: 0.16, unit: "s"),
            .slider("bounce", L("Snap damping", "回弹阻尼"), 0.2...0.9, default: 0.42),
            .slider("stretch", L("Stretch", "拉伸量"), 0...0.6, default: 0.3),
        ]
    ) { ctx in
        ButtonStickyDemo(ctx: ctx)
    }
}

private struct ButtonStickyDemo: View {
    let ctx: DemoContext
    @State private var pull: CGSize
    @State private var touching = false
    @State private var step = 0
    @State private var scriptTask: Task<Void, Never>?
    @State private var snapTask: Task<Void, Never>?

    private static let size = CGSize(width: 244, height: 68)
    private static let script: [CGSize] = [
        CGSize(width: 150, height: -30),
        CGSize(width: -150, height: 40),
        CGSize(width: 90, height: 60),
    ]

    init(ctx: DemoContext) {
        self.ctx = ctx
        _pull = State(initialValue: ctx.isStill ? CGSize(width: 44, height: -9) : .zero)
    }

    private var reach: CGFloat { max(ctx.cg("reach"), 1) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            button
            Spacer()
            DemoHint(text: L("Drag from the label and let go", "按住标签拖动，然后松手"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.6, delay: 0.4) { playScript() }
        .onDisappear {
            scriptTask?.cancel()
            snapTask?.cancel()
        }
    }

    private var button: some View {
        ButtonStickyBody(
            pull: pull,
            title: ctx.language == .zh ? "拉我试试" : "Pull me",
            reach: reach,
            stretch: ctx.cg("stretch"),
            size: Self.size
        )
        .scaleEffect(touching ? 0.98 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: touching)
        .contentShape(Rectangle().inset(by: -30))
        .gesture(dragGesture)
        .accessibilityAddTraits(.isButton)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !touching {
                    scriptTask?.cancel()
                    snapTask?.cancel()
                    touching = true
                    Haptics.tap(.soft)
                }
                let raw = CGSize(
                    width: value.location.x - Self.size.width / 2,
                    height: value.location.y - Self.size.height / 2
                )
                follow(raw)
            }
            .onEnded { _ in
                touching = false
                snapHome(haptics: true)
            }
    }

    // MARK: Behaviour

    /// Rubber-bands the raw finger offset and lets the puck chase it on the lagging spring.
    private func follow(_ raw: CGSize) {
        let target = CGSize(
            width: rubberBand(raw.width, limit: reach, coefficient: 0.9),
            height: rubberBand(raw.height, limit: reach * 0.4, coefficient: 0.9)
        )
        withAnimation(.spring(response: ctx["lag"], dampingFraction: 0.72)) { pull = target }
    }

    private func snapHome(haptics: Bool) {
        withAnimation(.spring(response: 0.36, dampingFraction: ctx["bounce"])) { pull = .zero }
        snapTask?.cancel()
        guard haptics, !ctx.isPreview else { return }
        snapTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.11))
            guard !Task.isCancelled else { return }
            Haptics.tap(.rigid)
        }
    }

    private func playScript() {
        guard !touching else { return }
        let raw = Self.script[step % Self.script.count]
        step += 1
        scriptTask?.cancel()
        scriptTask = Task { @MainActor in
            // A slow pull, a quick flick further, then let go.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                pull = CGSize(
                    width: rubberBand(raw.width * 0.6, limit: reach, coefficient: 0.9),
                    height: rubberBand(raw.height * 0.6, limit: reach * 0.4, coefficient: 0.9)
                )
            }
            try? await Task.sleep(for: .seconds(0.45))
            guard !Task.isCancelled else { return }
            follow(raw)
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            snapHome(haptics: false)
        }
    }
}

/// Button, tether and puck. `pull` is animatable, so the tether and the stretch follow the spring every frame.
private struct ButtonStickyBody: View, Animatable {
    var pull: CGSize
    let title: String
    let reach: CGFloat
    let stretch: CGFloat
    let size: CGSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(pull.width, pull.height) }
        set { pull = CGSize(width: newValue.first, height: newValue.second) }
    }

    var body: some View {
        let distance = hypot(pull.width, pull.height)
        let amount = min(distance / reach, 1.4)
        let direction: CGFloat = pull.width >= 0 ? 1 : -1
        let across = pull.width / reach
        let along = pull.height / (reach * 0.4)
        // Mostly a horizontal stretch; a diagonal pull adds a slight tilt toward the finger.
        let tilt = Angle.degrees(Double(across * along) * 5)
        ZStack {
            Capsule()
                .fill(Palette.primaryStrong)
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                )
                .shadow(color: Palette.indigo.opacity(0.4), radius: 14, y: 8)
            // The slot the puck lives in.
            Capsule()
                .fill(Color.black.opacity(0.22))
                .frame(width: 122, height: 42)
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.18), lineWidth: 1).frame(width: 122, height: 42))
            // The band fades in from the slot end toward the puck, so it has no hard root.
            ButtonStickyTether(pull: pull, amount: amount)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.7)],
                        startPoint: UnitPoint(x: 0.5 - 0.17 * direction, y: 0.5),
                        endPoint: UnitPoint(x: 0.5 - 0.17 * direction + pull.width / size.width, y: 0.5)
                    )
                )
            puck
                .scaleEffect(x: 1 + stretch * abs(across), y: 1 - stretch * 0.4 * abs(across) + stretch * 0.25 * abs(along))
                .rotationEffect(tilt)
                .offset(pull)
        }
        .frame(width: size.width, height: size.height)
        .offset(x: pull.width * 0.08, y: pull.height * 0.08)
    }

    private var puck: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw.fill")
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color(hex: 0x4B3FD0))
        .frame(width: 122, height: 42)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [.white, Color(hex: 0xE9E8FF)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
        )
    }
}

/// The elastic band from the slot to the puck: wide at both ends, thinner in the middle the further it stretches.
private struct ButtonStickyTether: Shape {
    var pull: CGSize
    var amount: CGFloat

    func path(in rect: CGRect) -> Path {
        let distance = hypot(pull.width, pull.height)
        guard distance > 1 else { return Path() }
        // Anchored at the end of the slot the puck is leaving, so the band spans the gap that opens up there.
        let home = CGPoint(x: rect.midX - pull.width / distance * 42, y: rect.midY - pull.height / distance * 5)
        let tip = CGPoint(x: home.x + pull.width, y: home.y + pull.height)
        let normal = CGPoint(x: -pull.height / distance, y: pull.width / distance)
        let root: CGFloat = 15
        let end: CGFloat = 17
        let waist = max(8 * (1 - 0.8 * min(amount, 1)), 1)
        let middle = CGPoint(x: (home.x + tip.x) / 2, y: (home.y + tip.y) / 2)
        func shifted(_ point: CGPoint, _ by: CGFloat) -> CGPoint {
            CGPoint(x: point.x + normal.x * by, y: point.y + normal.y * by)
        }
        var path = Path()
        path.move(to: shifted(home, root))
        path.addQuadCurve(to: shifted(tip, end), control: shifted(middle, waist))
        path.addLine(to: shifted(tip, -end))
        path.addQuadCurve(to: shifted(home, -root), control: shifted(middle, -waist))
        path.closeSubpath()
        return path
    }
}
