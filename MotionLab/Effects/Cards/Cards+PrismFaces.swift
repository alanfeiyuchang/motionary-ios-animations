import SwiftUI

extension Effect {
    static let cardsPrismFaces = Effect(
        id: "cards.prism-faces",
        category: .cards,
        interaction: .gesture,
        name: L("Prism Faces", "三棱柱卡片"),
        summary: L("Three cards wrapped around a triangular prism: roll it up or down and the next face turns into view under changing light.", "三张卡片贴在一根三棱柱上：上下拨动，下一面在变化的光照中转到眼前。"),
        prompt: L(
            "Three 250×150 pt account cards are the faces of a triangular prism lying on its side. Dragging vertically rolls it about its long axis, 120° per 150 pt, and each face turns around the prism's centre 43 pt behind it, so the outgoing face tips back and travels up while the next one rises from below, with real perspective (viewer 600 pt away). Light comes from above and in front: a face brightens as it tilts toward the light, darkens as it turns downward, and a thin bevel highlight runs along its top edge. On release the roll snaps to the nearest face, or one face further after a flick, on a spring (response 0.5 s, damping 0.68) that overshoots about 6° and rocks back, with a tick as the face seats. The ground shadow swells mid-turn and three side dots follow the active face.",
            "三张250×150 pt的账户卡片是一根横放三棱柱的三个面。上下拖动让它绕长轴滚动，每150 pt转120°；每个面都绕着身后43 pt处的棱柱中心转动，所以离开的那一面向后仰、向上移，下一面从下方升起，并带有真实透视（视距600 pt）。光来自前上方：面朝向光时变亮，转向下方时变暗，上沿还有一道细细的倒角高光。松手后滚动吸附到最近的一面，快速甩动则多转一面，弹簧（响应0.5秒、阻尼0.68）会过冲约6°再摆回，卡面落位时有一记轻触感。转到一半时地面阴影胀大，侧边三个圆点指示当前面。"
        ),
        implementation: L(
            "An Animatable view holds the roll angle. Each face is placed as a plane in 3D (rotated about the prism's axis at the inradius behind it) and drawn with projectionEffect; faces whose normal points away from the eye are skipped, zIndex follows cos(angle), and the shading is the dot product of the face normal and a fixed light.",
            "Animatable 视图保存滚动角度。每个面都作为三维中的一个平面（绕其后方内切圆半径处的棱柱轴旋转）用 projectionEffect 绘制；法线背向视点的面不绘制，zIndex 取 cos(角度)，明暗取面法线与固定光源方向的点积。"
        ),
        apis: ["Animatable", "projectionEffect", "ProjectionTransform", "DragGesture", "zIndex", "spring(response:dampingFraction:)"],
        tags: ["prism", "3D", "roll", "faces", "三棱柱", "立体", "滚动", "切换"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.68),
            .slider("depth", L("Viewer distance", "视距"), 300...1400, default: 600, step: 10, decimals: 0, unit: "pt"),
            .slider("shade", L("Light contrast", "明暗对比"), 0...1, default: 0.65),
        ]
    ) { ctx in
        CardsPrismDemo(ctx: ctx)
    }
}

private enum CardsPrismLayout {
    static let face = CGSize(width: 250, height: 150)
    /// Distance from a face to the prism's axis (inradius of the equilateral cross-section).
    static let inradius: CGFloat = 150 / (2 * 1.7320508)
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
}

private struct CardsPrismDemo: View {
    let ctx: DemoContext
    /// Roll in degrees; a multiple of 120 shows one face head-on.
    @State private var angle: Double
    @State private var dragStart: Double?
    @State private var settle: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the prism mid-roll, two faces visible.
        _angle = State(initialValue: ctx.isStill ? 38 : 0)
    }

    var body: some View {
        VStack(spacing: 4) {
            CardsPrism(angle: angle, depth: ctx.cg("depth"), shade: ctx["shade"], language: ctx.language)
                .frame(width: 300, height: 262)
                .contentShape(Rectangle())
                .gesture(drag)
            DemoHint(text: L("Drag up or down, or tap", "上下拖动，或点击"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { roll(to: (angle / 120).rounded() * 120 + 120, haptic: false) }
        .onChange(of: pressing) { _, isPressing in
            guard !isPressing else { return }
            // onEnded can arrive just after the gesture state resets, so this fallback waits a tick:
            // by then only a cancelled touch still has something to clean up.
            Task { @MainActor in
                if let start = dragStart {
                    dragStart = nil
                    roll(to: (start / 120).rounded() * 120, haptic: true)
                }
            }
        }
        .onDisappear { settle?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if dragStart == nil {
                    dragStart = angle
                    settle?.cancel()
                }
                guard let start = dragStart else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    angle = start - Double(value.translation.height) / 150 * 120
                }
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                let home = (start / 120).rounded() * 120
                let moved = hypot(value.translation.width, value.translation.height)
                if moved < 8 {
                    // A tap rolls one face forward.
                    roll(to: home + 120, haptic: true)
                    return
                }
                let projected = start - Double(value.predictedEndTranslation.height) / 150 * 120
                let steps = ((projected - home) / 120).rounded().clamped(to: -1...1)
                roll(to: home + steps * 120, haptic: true)
            }
    }

    private func roll(to target: Double, haptic: Bool) {
        let response = ctx["response"]
        withAnimation(.spring(response: response, dampingFraction: ctx["damping"])) {
            angle = target
        }
        settle?.cancel()
        guard haptic, !ctx.isPreview else { return }
        settle = Task { @MainActor in
            // The face reaches its seat a little after half the spring's response.
            try? await Task.sleep(for: .seconds(response * 0.6))
            guard !Task.isCancelled else { return }
            Haptics.tap(.rigid)
        }
    }
}

private struct CardsPrism: View, Animatable {
    var angle: Double
    let depth: CGFloat
    let shade: Double
    let language: AppLanguage

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        // How far the prism is from showing one face head-on: 0 seated, 1 on an edge.
        let offEdge = abs(sin(angle * .pi / 120))
        HStack(spacing: 14) {
            ZStack {
                groundShadow(offEdge: offEdge)
                ForEach(0..<3, id: \.self) { index in
                    face(index)
                }
            }
            .frame(width: CardsPrismLayout.face.width, height: CardsPrismLayout.face.height)
            dots
        }
        .offset(x: 10)
    }

    /// Roll of face `index`, wrapped to −180…180: 0 is head-on, positive tips its top away.
    private func roll(_ index: Int) -> Double {
        var value = (angle - Double(index) * 120).truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }

    @ViewBuilder
    private func face(_ index: Int) -> some View {
        let degrees = roll(index)
        let a = CGFloat(degrees * .pi / 180)
        let r = CardsPrismLayout.inradius
        // Only faces whose front is turned toward the eye are drawn.
        if cos(a) * (depth + r) - r > 0 {
            let size = CardsPrismLayout.face
            let half = size.height / 2
            let plane = CardsPlane3D(
                origin: CardsPlane3D.Vec(0, half - half * cos(a) - r * sin(a), -half * sin(a) + r * cos(a) - r),
                u: CardsPlane3D.Vec(1, 0, 0),
                v: CardsPlane3D.Vec(0, cos(a), sin(a))
            )
            // Light from above and in front of the prism.
            let lit = 0.5 * sin(Double(a)) + 0.87 * cos(Double(a))
            let dark = ((0.87 - lit) / 0.87).clamped(to: 0...1) * 0.75 * shade
            let bright = ((lit - 0.87) / 0.13).clamped(to: 0...1) * 0.22 * shade
            CardsPrismFace(index: index, language: language)
                .overlay { CardsPrismLayout.shape.fill(Color.black.opacity(dark)) }
                .overlay { CardsPrismLayout.shape.fill(Color.white.opacity(bright)) }
                .projectionEffect(plane.projection(eye: CGPoint(x: size.width / 2, y: half), depth: depth))
                .zIndex(Double(cos(a)))
        }
    }

    private func groundShadow(offEdge: Double) -> some View {
        Ellipse()
            .fill(Color.black)
            .frame(width: CardsPrismLayout.face.width * (0.86 + 0.06 * offEdge), height: 26 + 10 * offEdge)
            .blur(radius: 14)
            .opacity(0.32 - 0.08 * offEdge)
            .offset(y: CardsPrismLayout.face.height / 2 + 18)
            .zIndex(-2)
    }

    private var dots: some View {
        let turns = (angle / 120).rounded()
        let active = ((Int(turns) % 3) + 3) % 3
        return VStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(index == active ? 0.7 : 0.2))
                    .frame(width: 5, height: index == active ? 16 : 5)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: active)
    }
}

private struct CardsPrismFace: View {
    let index: Int
    let language: AppLanguage

    private struct Model {
        let title: LocalizedText
        let amount: String
        let delta: String
        let symbol: String
        let theme: Int
    }

    private static let models: [Model] = [
        Model(title: L("Everyday", "日常账户"), amount: "4,280.16", delta: "+2.4%", symbol: "creditcard.fill", theme: 0),
        Model(title: L("Savings", "储蓄"), amount: "18,905.00", delta: "+0.8%", symbol: "leaf.fill", theme: 4),
        Model(title: L("Invest", "投资"), amount: "9,612.47", delta: "+6.1%", symbol: "chart.line.uptrend.xyaxis", theme: 2),
    ]

    var body: some View {
        let model = Self.models[index % Self.models.count]
        let size = CardsPrismLayout.face
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: model.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.2), in: Circle())
                Text(model.title, language)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
                Text(verbatim: model.delta)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.18), in: Capsule())
            }
            Spacer(minLength: 0)
            Text(L("BALANCE", "余额"), language)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .opacity(0.75)
            Text(verbatim: model.amount)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(width: size.width, height: size.height)
        .background {
            LinearGradient(colors: CardsArt.colors(model.theme), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 170, height: 170)
                .offset(x: 60, y: -96)
        }
        .clipShape(CardsPrismLayout.shape)
        .overlay(alignment: .top) {
            // Bevel: the top edge catches the light.
            Capsule()
                .fill(Color.white.opacity(0.55))
                .frame(height: 1.2)
                .padding(.horizontal, 14)
        }
        .overlay(CardsPrismLayout.shape.strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }
}
