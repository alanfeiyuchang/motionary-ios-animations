import SwiftUI

extension Effect {
    static let cardsBendFlex = Effect(
        id: "cards.bend-flex",
        category: .cards,
        interaction: .gesture,
        name: L("Bend & Flex", "弯折回弹"),
        summary: L("Push a plastic card in any direction: its leading edge curls up toward you, a highlight runs along the curve, and it twangs back flat.", "朝任意方向推一张塑料卡：前缘朝你卷起，高光沿着弧面滑动，松手后嗡地弹平。"),
        prompt: L(
            "A 236×148 pt plastic card lies flat. Dragging it bends it like a flexed bank card: the bend axis is perpendicular to the drag, the trailing edge stays pinned and the curl grows quadratically toward the leading edge, reaching 75° at a 120 pt drag and rubber-banding beyond. The surface is 40 strips projected with one shared perspective (viewer 520 pt away), so the lifted edge really gets larger. A narrow specular band sits where the surface is tilted 19° and slides inward as the curl tightens, the steep end darkens, and the shadow spreads under the raised edge. On release the bend returns on an under-damped spring (response 0.42 s, damping 0.32): the card flicks through flat, the opposite edge kicks up, and it wobbles to rest.",
            "一张236×148 pt的塑料卡平放着。拖动它，它像被掰弯的银行卡一样弯曲：弯折轴垂直于拖动方向，后缘固定不动，卷曲量朝前缘按二次曲线增大，拖动120 pt时达到75°，再往外有橡皮筋阻力。卡面由40条窄带组成，共用同一个透视（视距520 pt），抬起的一边真的会变大。表面倾斜19°的位置有一道窄高光，卷得越紧它越往里滑，最陡的一端变暗，阴影在翘起的边缘下方扩散。松手后弯曲量以欠阻尼弹簧（响应0.42秒、阻尼0.32）回弹：卡片甩过平面，另一侧翘起一下，颤动几次后静止。"
        ),
        implementation: L(
            "An Animatable view holds the bend vector. The card is drawn 40 times, each copy masked to one strip across the bend direction; a running sum of cos/sin of the local curl angle gives every strip a plane in 3D, applied with projectionEffect. The highlight and shade are per-strip overlays computed from that angle.",
            "Animatable 视图保存弯曲向量。卡片绘制40份，每份遮罩成垂直于弯曲方向的一条窄带；对局部卷曲角的 cos/sin 逐条累加，得到每条窄带在三维中的平面，再用 projectionEffect 投影。高光与暗部是按该角度计算的逐条叠加层。"
        ),
        apis: ["Animatable", "projectionEffect", "ProjectionTransform", "mask", "DragGesture", "spring(response:dampingFraction:)"],
        tags: ["bend", "flex", "plastic", "curl", "弯曲", "柔性", "塑料卡", "回弹"],
        params: [
            .slider("angle", L("Max curl", "最大卷曲"), 30...110, default: 75, step: 1, decimals: 0, unit: "°"),
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.9, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.15...1.0, default: 0.32),
            .slider("gloss", L("Gloss", "光泽"), 0...1, default: 0.7),
        ]
    ) { ctx in
        CardsBendDemo(ctx: ctx)
    }
}

private enum CardsBendLayout {
    static let card = CGSize(width: 236, height: 148)
    static let canvas: CGFloat = 290
    static let strips = 40
    static let depth: CGFloat = 520
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
}

private struct CardsBendDemo: View {
    let ctx: DemoContext
    @State private var bend: CGSize
    @State private var held = false
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the card mid-flex.
        _bend = State(initialValue: ctx.isStill ? CGSize(width: 96, height: -44) : .zero)
    }

    var body: some View {
        VStack(spacing: 2) {
            CardsBendSheet(bend: bend, maxAngle: ctx["angle"], gloss: ctx["gloss"], language: ctx.language)
                .overlay { hitArea }
            DemoHint(text: L("Drag the card in any direction", "朝任意方向拖动卡片"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.5) { autoFlex() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release() }
        }
        .onDisappear { script?.cancel() }
    }

    private var hitArea: some View {
        Color.clear
            .frame(width: CardsBendLayout.card.width, height: CardsBendLayout.card.height)
            .contentShape(Rectangle())
            .gesture(drag)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held {
                    held = true
                    script?.cancel()
                    script = nil
                    Haptics.tap(.soft)
                }
                withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.86)) {
                    bend = limited(value.translation)
                }
            }
            .onEnded { _ in release() }
    }

    /// Past 120 pt the plastic resists like a rubber band.
    private func limited(_ translation: CGSize) -> CGSize {
        let length = hypot(translation.width, translation.height)
        guard length > 120 else { return translation }
        let scale = (120 + rubberBand(length - 120, limit: 46)) / length
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }

    private func release() {
        guard held else { return }
        held = false
        Haptics.tap(.rigid)
        twang()
    }

    private func twang() {
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            bend = .zero
        }
    }

    private func autoFlex() {
        guard !held else { return }
        let targets: [CGSize] = [
            CGSize(width: 118, height: -20),
            CGSize(width: -70, height: -92),
            CGSize(width: -112, height: 36),
            CGSize(width: 60, height: 100),
        ]
        let target = targets[autoStep % targets.count]
        autoStep += 1
        withAnimation(.easeInOut(duration: 0.75)) { bend = target }
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.05))
            guard !Task.isCancelled else { return }
            twang()
        }
    }
}

/// One strip of the bent surface: where it starts in 3D and how far it is tilted.
private struct CardsBendStrip {
    let start: CGFloat
    let x: CGFloat
    let z: CGFloat
    let angle: CGFloat
}

/// The bent card. Animatable so the curl itself (not an offset) rides the release spring.
private struct CardsBendSheet: View, Animatable {
    var bend: CGSize
    let maxAngle: Double
    let gloss: Double
    let language: AppLanguage

    var animatableData: CGSize.AnimatableData {
        get { bend.animatableData }
        set { bend.animatableData = newValue }
    }

    private var canvas: CGFloat { CardsBendLayout.canvas }

    var body: some View {
        let length = hypot(bend.width, bend.height)
        let phi: CGFloat = length < 0.01 ? 0 : atan2(bend.height, bend.width)
        let strips = makeStrips(length: length, phi: phi)
        let lift = Double(min(length / 120, 1.3))
        ZStack {
            shadow(lift: lift, phi: phi)
            ZStack {
                ForEach(0..<strips.count, id: \.self) { index in
                    strip(strips[index], phi: phi)
                }
            }
            .frame(width: canvas, height: canvas)
            .rotationEffect(.radians(Double(phi)))
        }
        .frame(width: canvas, height: canvas)
    }

    /// Integrates the curl across the strips. The curl angle grows with the square of the distance from
    /// the pinned (trailing) edge, so the leading edge does most of the bending.
    private func makeStrips(length: CGFloat, phi: CGFloat) -> [CardsBendStrip] {
        let count = CardsBendLayout.strips
        let width = canvas / CGFloat(count)
        let card = CardsBendLayout.card
        // Half extent of the card along the bend direction.
        let reach: CGFloat = max(card.width / 2 * abs(cos(phi)) + card.height / 2 * abs(sin(phi)), 1)
        let peak: CGFloat = min(length / 120, 1.35) * CGFloat(maxAngle) * .pi / 180
        var raw: [CardsBendStrip] = []
        raw.reserveCapacity(count)
        var x: CGFloat = -canvas / 2
        var z: CGFloat = 0
        var centre: CGFloat = 0
        for index in 0..<count {
            let start = -canvas / 2 + CGFloat(index) * width
            let mid = start + width / 2
            let along = ((mid + reach) / (2 * reach)).clamped(to: 0...1)
            let angle = min(peak * along * along, 1.5)
            raw.append(CardsBendStrip(start: start, x: x, z: z, angle: angle))
            if start <= 0 && start + width > 0 {
                centre = x + (0 - start) * cos(angle)
            }
            x += width * cos(angle)
            z += width * sin(angle)
        }
        // Keep the card's middle where it was: only the ends appear to move.
        let slide = centre * 0.5
        return raw.map { CardsBendStrip(start: $0.start, x: $0.x - slide, z: $0.z, angle: $0.angle) }
    }

    private func strip(_ strip: CardsBendStrip, phi: CGFloat) -> some View {
        let width = canvas / CGFloat(CardsBendLayout.strips)
        let c = cos(strip.angle)
        let s = sin(strip.angle)
        // View x = 0 is s = −canvas / 2 in the bend frame.
        let lead: CGFloat = -canvas / 2 - strip.start
        let plane = CardsPlane3D(
            origin: CardsPlane3D.Vec(strip.x + lead * c + canvas / 2, 0, strip.z + lead * s),
            u: CardsPlane3D.Vec(c, 0, s),
            v: CardsPlane3D.Vec(0, 1, 0)
        )
        // A narrow band where the surface faces the light, and shade where it turns away.
        let band = (strip.angle - 0.33) / 0.15
        let glint: Double = gloss * 0.62 * Double(exp(-band * band))
        let shade: Double = 0.42 * Double(((strip.angle - 0.45) / 0.95).clamped(to: 0...1))
        return ZStack {
            CardsBendFace(language: language)
            CardsBendLayout.shape.fill(Color.white.opacity(glint))
            CardsBendLayout.shape.fill(Color.black.opacity(shade))
        }
        .frame(width: CardsBendLayout.card.width, height: CardsBendLayout.card.height)
        .rotationEffect(.radians(Double(-phi)))
        .frame(width: canvas, height: canvas)
        .mask(alignment: .leading) {
            Rectangle()
                .frame(width: width + 0.7)
                .offset(x: strip.start + canvas / 2 - 0.35)
        }
        .projectionEffect(plane.projection(eye: CGPoint(x: canvas / 2, y: canvas / 2), depth: CardsBendLayout.depth))
    }

    /// The contact shadow stays under the pinned end and spreads toward the raised edge.
    private func shadow(lift: Double, phi: CGFloat) -> some View {
        let push: CGFloat = CGFloat(lift) * 10
        return CardsBendLayout.shape
            .fill(Color.black)
            .frame(width: CardsBendLayout.card.width * 0.94, height: CardsBendLayout.card.height * 0.9)
            .blur(radius: 12 + 8 * CGFloat(lift))
            .opacity(0.3 - 0.06 * lift)
            .offset(x: cos(phi) * push, y: 12 + sin(phi) * push)
    }
}

/// A plastic transit pass: flat fills only, because it is drawn once per strip.
private struct CardsBendFace: View {
    let language: AppLanguage

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1FD1C1), Color(hex: 0x2C7BF2), Color(hex: 0x5B3BFF)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay { stripes }
            content
                .padding(16)
        }
        .frame(width: CardsBendLayout.card.width, height: CardsBendLayout.card.height)
        .clipShape(CardsBendLayout.shape)
        .overlay {
            CardsBendLayout.shape
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
    }

    private var stripes: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.1 + 0.05 * Double(index)))
                    .frame(width: 20, height: 260)
            }
        }
        .rotationEffect(.degrees(32))
        .offset(x: 66, y: 10)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(L("Metro Pass", "地铁通行卡"), language)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
                Image(systemName: "wave.3.right")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            Text(verbatim: "24.60")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack {
                Text(L("BALANCE", "余额"), language)
                Spacer(minLength: 0)
                Text(verbatim: "0421 7730")
                    .monospacedDigit()
            }
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.2)
            .opacity(0.8)
            .padding(.top, 2)
        }
        .foregroundStyle(.white)
    }
}
