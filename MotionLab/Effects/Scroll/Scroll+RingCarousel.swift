import SwiftUI

extension Effect {
    static let scrollRingCarousel = Effect(
        id: "scroll.ring-carousel",
        category: .scroll,
        interaction: .gesture,
        name: L("3D Ring Carousel", "3D 环形轮播"),
        summary: L("Cards stand on a ring that spins about its vertical axis with inertia and clicks the nearest one to the front.", "卡片立在一个绕竖直轴旋转的圆环上，带惯性转动，并把最近的一张吸附到正前方。"),
        prompt: L(
            "Seven 96 × 130 pt gradient cards stand on a horizontal ring of 126 pt radius, seen from 14° above, each facing outward. The front card is full size and sharp; cards shrink with perspective to about 67% at the back, where they darken by 30%, blur 2.5 pt and pass behind the front ones. A thin elliptical track marks the floor. Dragging turns the whole ring 1:1 with the finger along the arc; on release the fling velocity is projected, the ring keeps spinning and settles on the nearest card with a spring (response 0.7 s, damping 0.78) that overshoots by a few degrees. Each card passing the front gives a selection tick while dragging, and the title below cross-fades. Tapping a side card brings it round the shorter way. Weighty, like a showroom turntable.",
            "七张96×130 pt的渐变卡片立在半径126 pt的水平圆环上，从上方14°俯视，每张都朝外。正前方的卡片为原始尺寸；越往后越小，最远处约67%，同时变暗30%、模糊2.5 pt，并从前排身后经过，地面有一圈细椭圆轨道。拖动时圆环沿弧线1:1跟手转动；松手后按甩动速度推算落点，再以弹簧（响应0.7秒、阻尼0.78）停到最近的卡片并过冲几度。拖动中每有卡片经过正前方就有一次选择触感，下方标题淡入切换。点击侧面的卡片会沿较短的方向转到面前。沉稳，像展厅里的旋转展台。"
        ),
        implementation: L(
            "One rotation value (in item units) drives an Animatable ViewModifier that places each card on the ring: x = R·sin θ, depth = R·cos θ, a manual perspective scale, rotation3DEffect by θ and zIndex by depth. A DragGesture scrubs the rotation and its predicted end translation picks the card the spring settles on.",
            "用一个旋转量（以卡片为单位）驱动一个 Animatable 的 ViewModifier，把每张卡片放到圆环上：x = R·sin θ、深度 = R·cos θ，手动计算透视缩放，再按 θ 做 rotation3DEffect、按深度设置 zIndex。DragGesture 直接拖动旋转量，并用预测的终点位移决定弹簧最终停在哪一张。"
        ),
        apis: ["Animatable", "ViewModifier", "rotation3DEffect", "DragGesture", "zIndex", "spring(response:dampingFraction:)"],
        tags: ["ring", "carousel", "3D", "turntable", "inertia", "环形", "轮播", "三维", "转盘", "惯性"],
        params: [
            .slider("count", L("Cards", "卡片数量"), 5...10, default: 7, step: 1, decimals: 0),
            .slider("radius", L("Ring radius", "圆环半径"), 90...140, default: 126, step: 2, decimals: 0, unit: "pt"),
            .slider("tilt", L("View elevation", "俯视角度"), 0...28, default: 14, step: 1, decimals: 0, unit: "°"),
        ]
    ) { ctx in
        ScrollRingDemo(ctx: ctx)
    }
}

private let scrollRingCard = CGSize(width: 96, height: 130)
private let scrollRingFocal: CGFloat = 520

/// Perspective scale of a point at `depth` (R at the front, −R at the back) on a ring of `radius`.
private func scrollRingScale(depth: CGFloat, radius: CGFloat) -> CGFloat {
    scrollRingFocal / (scrollRingFocal + radius - depth)
}

private struct ScrollRingDemo: View {
    let ctx: DemoContext
    /// Ring rotation in card units: card `i` faces the viewer when `rotation == i`.
    @State private var rotation: Double = 0
    @State private var dragStart: Double?
    /// The card the ring is settling on (or the one under the finger while dragging).
    @State private var front = 0
    @State private var step = 0

    private var count: Int { max(ctx.int("count"), 3) }
    private var radius: CGFloat { ctx.cg("radius") }
    private var tilt: Double { ctx["tilt"] * .pi / 180 }
    /// Arc length between two neighbouring cards: one card of rotation per this much drag.
    private var arc: CGFloat { max(radius * 2 * .pi / CGFloat(count), 1) }

    var body: some View {
        VStack(spacing: 6) {
            ring
            caption
            DemoHint(text: L("Drag to spin · tap a card", "拖动旋转 · 点击卡片"), ctx: ctx)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7) { autoSpin() }
    }

    private var ring: some View {
        ZStack {
            ScrollRingFloor(radius: radius, tilt: tilt)
            ForEach(0..<count, id: \.self) { i in
                ScrollRingCardView(index: i, language: ctx.language)
                    .modifier(ScrollRingPlacement(rotation: rotation, index: i, count: count, radius: radius, tilt: tilt))
                    .onTapGesture { bring(i) }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 236)
        .contentShape(Rectangle())
        .gesture(drag)
    }

    private var caption: some View {
        let index = wrapped(front)
        return VStack(spacing: 3) {
            Text(ScrollKit.title(index), ctx.language)
                .font(.headline)
                .contentTransition(.interpolate)
            Text(verbatim: "\(index + 1) / \(count)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(index)))
        }
        .animation(.snappy(duration: 0.3), value: index)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let start = dragStart ?? rotation
                if dragStart == nil { dragStart = start }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    rotation = start - Double(value.translation.width / arc)
                }
                let nearest = Int(rotation.rounded())
                if nearest != front {
                    front = nearest
                    Haptics.selection()
                }
            }
            .onEnded { value in
                let start = dragStart ?? rotation
                dragStart = nil
                let projected = start - Double(value.predictedEndTranslation.width / arc)
                // A fling carries the ring at most one full turn past where the finger let go.
                let limit = Double(count)
                let target = projected.clamped(to: (rotation - limit)...(rotation + limit)).rounded()
                spin(to: target)
            }
    }

    private func wrapped(_ index: Int) -> Int { ((index % count) + count) % count }

    /// Settles the ring on `target` with the weighty spring; the same path for flings, taps and autoplay.
    private func spin(to target: Double) {
        let landing = Int(target)
        if landing != front { Haptics.tap(.soft) }
        front = landing
        withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
            rotation = target
        }
    }

    /// Brings card `i` to the front the shorter way round.
    private func bring(_ i: Int) {
        let current = rotation.rounded()
        var delta = Double(i) - current.truncatingRemainder(dividingBy: Double(count))
        let half = Double(count) / 2
        while delta > half { delta -= Double(count) }
        while delta < -half { delta += Double(count) }
        spin(to: current + delta)
    }

    private func autoSpin() {
        let moves: [Double] = [1, 1, 3, -2, 1, -4]
        spin(to: rotation.rounded() + moves[step % moves.count])
        step += 1
    }
}

/// Places a card on the ring. Animatable, so a spring on `rotation` carries every card round the
/// circle (instead of sliding it in a straight line between its start and end spots).
private struct ScrollRingPlacement: ViewModifier, Animatable {
    var rotation: Double
    let index: Int
    let count: Int
    let radius: CGFloat
    let tilt: Double

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    func body(content: Content) -> some View {
        let theta: Double = (Double(index) - rotation) / Double(count) * 2 * .pi
        let depth: CGFloat = radius * CGFloat(cos(theta))
        let scale: CGFloat = scrollRingScale(depth: depth, radius: radius)
        let x: CGFloat = radius * CGFloat(sin(theta)) * scale
        // Seen from above, the far side of the ring sits higher on screen.
        let y: CGFloat = depth * CGFloat(sin(tilt)) * scale
        // 0 at the front, 1 at the very back.
        let far: Double = (1 - cos(theta)) / 2
        return content
            .brightness(-0.3 * far)
            .blur(radius: 2.5 * far)
            .rotation3DEffect(.radians(theta), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .scaleEffect(scale)
            .offset(x: x, y: y)
            .zIndex(Double(depth))
    }
}

private struct ScrollRingCardView: View {
    let index: Int
    let language: AppLanguage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ScrollKitArt(index: index, language: language, showsTitle: false)
            .frame(width: scrollRingCard.width, height: scrollRingCard.height)
            .overlay {
                LinearGradient(colors: [Color.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                    .blendMode(.plusLighter)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
            .background(alignment: .bottom) {
                // Contact shadow on the floor; it turns with the card.
                Ellipse()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: scrollRingCard.width * 0.86, height: 12)
                    .blur(radius: 7)
                    .offset(y: 9)
            }
            .contentShape(shape)
    }
}

/// The elliptical track the cards stand on, traced through the bottom edges of the front and back cards.
private struct ScrollRingFloor: View {
    let radius: CGFloat
    let tilt: Double

    var body: some View {
        let half: CGFloat = scrollRingCard.height / 2
        let lift: CGFloat = radius * CGFloat(sin(tilt))
        let frontBottom: CGFloat = (lift + half) * scrollRingScale(depth: radius, radius: radius)
        let backBottom: CGFloat = (-lift + half) * scrollRingScale(depth: -radius, radius: radius)
        let width: CGFloat = 2 * radius * scrollRingScale(depth: 0, radius: radius)
        Ellipse()
            .strokeBorder(
                LinearGradient(
                    colors: [Color.primary.opacity(0.05), Color.primary.opacity(0.22)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1.5
            )
            .frame(width: width, height: max(frontBottom - backBottom, 2))
            .offset(y: (frontBottom + backBottom) / 2)
            .zIndex(-10_000)
    }
}
