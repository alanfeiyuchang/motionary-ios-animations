import SwiftUI

extension Effect {
    static let cardsStickerPeel = Effect(
        id: "cards.sticker-peel",
        category: .cards,
        interaction: .gesture,
        name: L("Sticker Peel", "贴纸揭角"),
        summary: L("Grab a die-cut sticker by a corner and peel it: the curled back follows the finger, then slaps back flat.", "捏住贴纸的一角把它揭起：卷起的背面跟着手指走，松手后啪地贴回去。"),
        prompt: L(
            "A 180 pt die-cut sticker with a white border sits on a dashed footprint. Touching it lifts the nearest corner by 22 pt at once; dragging folds the sticker along the perpendicular bisector between the corner's home and the finger, so the flap is a true mirror image of the lifted part. The flap shows a grey paper back with a dark crease, a bright curl highlight and a soft shadow cast onto the artwork, and the peel rubber-bands past 200 pt. On release the corner snaps home on a spring (response 0.3 s, damping 0.74), then the sticker squashes to 96.5% and rebounds as a rigid haptic lands. Tactile, playful and slightly sticky.",
            "一张180 pt的模切贴纸带白色描边，贴在虚线轮廓上。手指一碰，最近的那个角立刻翘起22 pt；拖动时贴纸沿「角的原位」与手指连线的垂直平分线折叠，翻起的部分正是被揭开区域的镜像。背面是灰色纸底，折痕处压暗、卷边处有一道高光，并在图案上投下柔和阴影；揭开超过200 pt后出现橡皮筋阻力。松手后角以弹簧（响应0.3秒、阻尼0.74）贴回原位，随后整张贴纸压到96.5%再回弹，同时落下一记清脆触感。手感真实、俏皮，还带一点黏性。"
        ),
        implementation: L(
            "An Animatable view turns the peel vector into a fold line; the face is masked to one half-plane, and the paper back is the same shape under a reflection CGAffineTransform (transformEffect) masked to that half-plane, with a LinearGradient laid across the fold for the curl.",
            "Animatable 视图把揭起向量换算成折线：正面用半平面遮罩裁掉被揭起的部分，背面是同一形状经镜像 CGAffineTransform（transformEffect）后再用同一半平面遮罩，并沿折线方向叠加 LinearGradient 表现卷曲。"
        ),
        apis: ["Animatable", "transformEffect", "mask", "Shape", "DragGesture", "keyframeAnimator"],
        tags: ["sticker", "peel", "curl", "fold", "贴纸", "揭开", "卷边", "折角"],
        params: [
            .slider("response", L("Slap-back response", "回贴响应"), 0.15...0.7, default: 0.3, unit: "s"),
            .slider("damping", L("Slap-back damping", "回贴阻尼"), 0.5...1.0, default: 0.74),
            .slider("shade", L("Curl shading", "卷边明暗"), 0...1, default: 0.7),
        ]
    ) { ctx in
        CardsStickerPeelDemo(ctx: ctx)
    }
}

private enum CardsStickerLayout {
    static let side: CGFloat = 180
    static let canvas: CGFloat = 300
    static let inset: CGFloat = 60
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .continuous) }

    /// Corners: 0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left. Signs pointing into the sticker.
    static func inward(_ corner: Int) -> CGVector {
        switch corner {
        case 0: return CGVector(dx: 1, dy: 1)
        case 1: return CGVector(dx: -1, dy: 1)
        case 2: return CGVector(dx: -1, dy: -1)
        default: return CGVector(dx: 1, dy: -1)
        }
    }

    static func cornerPoint(_ corner: Int) -> CGPoint {
        let v = inward(corner)
        return CGPoint(
            x: v.dx > 0 ? inset : inset + side,
            y: v.dy > 0 ? inset : inset + side
        )
    }
}

private struct CardsStickerPeelDemo: View {
    let ctx: DemoContext
    @State private var corner: Int = 2
    @State private var peel: CGSize
    @State private var held = false
    @State private var slaps = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @State private var slapTask: Task<Void, Never>?
    /// Resets on system cancellation too, so a stolen touch still lets the sticker fall back.
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the sticker half peeled.
        _peel = State(initialValue: ctx.isStill ? CGSize(width: -112, height: -88) : .zero)
    }

    var body: some View {
        VStack(spacing: 6) {
            CardsStickerSheet(peel: peel, corner: corner, shade: ctx["shade"], language: ctx.language)
                .keyframeAnimator(initialValue: CardsStickerSlap(), trigger: slaps) { content, slap in
                    content.scaleEffect(slap.scale)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(0.965, duration: 0.07)
                        SpringKeyframe(1.0, duration: 0.38, spring: Spring(response: 0.26, dampingRatio: 0.45))
                    }
                }
                .overlay { hitArea }
            DemoHint(text: L("Drag a corner of the sticker", "拖动贴纸的一角"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.4) { autoPeel() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release() }
        }
        .onDisappear {
            script?.cancel()
            slapTask?.cancel()
        }
    }

    /// Only the sticker itself takes the drag; the margin around it still scrolls the page.
    private var hitArea: some View {
        Color.clear
            .frame(width: CardsStickerLayout.side, height: CardsStickerLayout.side)
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
                    slapTask?.cancel()
                    corner = nearestCorner(to: value.startLocation)
                    Haptics.tap(.soft)
                }
                withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.85)) {
                    peel = constrained(value.translation)
                }
            }
            .onEnded { _ in release() }
    }

    private func nearestCorner(to point: CGPoint) -> Int {
        let half = CardsStickerLayout.side / 2
        let left = point.x < half
        let top = point.y < half
        if top { return left ? 0 : 1 }
        return left ? 3 : 2
    }

    /// Keeps the peel pointing into the sticker (it can't fold outward), lifts the corner by 22 pt
    /// as soon as it is touched, and rubber-bands past 200 pt.
    private func constrained(_ translation: CGSize) -> CGSize {
        let inward = CardsStickerLayout.inward(corner)
        let u: CGFloat = max(translation.width * inward.dx, 0) + 22
        let v: CGFloat = max(translation.height * inward.dy, 0) + 22
        let length = hypot(u, v)
        let limit: CGFloat = 200
        var scale: CGFloat = 1
        if length > limit {
            scale = (limit + rubberBand(length - limit, limit: 40)) / length
        }
        return CGSize(width: u * scale * inward.dx, height: v * scale * inward.dy)
    }

    /// Single, guarded end of a touch (lift or system cancellation).
    private func release() {
        guard held else { return }
        held = false
        slapBack(haptic: true)
    }

    private func slapBack(haptic: Bool) {
        let response = ctx["response"]
        withAnimation(.spring(response: response, dampingFraction: ctx["damping"])) {
            peel = .zero
        }
        slapTask?.cancel()
        slapTask = Task { @MainActor in
            // The corner reaches the surface a little after half the spring's response.
            try? await Task.sleep(for: .seconds(response * 0.55))
            guard !Task.isCancelled else { return }
            slaps += 1
            if haptic && !ctx.isPreview { Haptics.tap(.rigid) }
        }
    }

    private func autoPeel() {
        guard !held else { return }
        let corners = [2, 0, 1, 3]
        let next = corners[autoStep % corners.count]
        autoStep += 1
        corner = next
        let inward = CardsStickerLayout.inward(next)
        let muted = Haptics.isMuted || ctx.isPreview
        withAnimation(.easeInOut(duration: 0.8)) {
            peel = CGSize(width: inward.dx * 128, height: inward.dy * 104)
        }
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.15))
            guard !Task.isCancelled else { return }
            slapBack(haptic: !muted)
        }
    }
}

private struct CardsStickerSlap {
    var scale: CGFloat = 1
}

/// The fold line of a peel: the perpendicular bisector between the corner's home and where it is now.
private struct CardsPeelFold {
    let mid: CGPoint
    /// Unit normal pointing at the lifted (corner) side of the fold.
    let normal: CGVector
    /// Distance from the fold to the lifted corner (the flap's widest reach).
    let reach: CGFloat

    init(corner: Int, peel: CGSize) {
        let home = CardsStickerLayout.cornerPoint(corner)
        let inward = CardsStickerLayout.inward(corner)
        // A spring that overshoots home would fold outward: clamp each component to the inward side.
        let u: CGFloat = max(peel.width * inward.dx, 0)
        let v: CGFloat = max(peel.height * inward.dy, 0)
        let length = hypot(u, v)
        if length < 0.5 {
            // Flat: park the fold just outside the corner so nothing is lifted.
            let d: CGFloat = 0.7071
            normal = CGVector(dx: -inward.dx * d, dy: -inward.dy * d)
            mid = CGPoint(x: home.x + normal.dx * 6, y: home.y + normal.dy * 6)
            reach = 0
        } else {
            let px: CGFloat = u * inward.dx
            let py: CGFloat = v * inward.dy
            normal = CGVector(dx: -px / length, dy: -py / length)
            mid = CGPoint(x: home.x + px / 2, y: home.y + py / 2)
            reach = length / 2
        }
    }

    /// Mirror across the fold line: x' = x − 2((x − mid)·n)n.
    var reflection: CGAffineTransform {
        let nx = normal.dx
        let ny = normal.dy
        let k: CGFloat = mid.x * nx + mid.y * ny
        return CGAffineTransform(
            a: 1 - 2 * nx * nx,
            b: -2 * nx * ny,
            c: -2 * nx * ny,
            d: 1 - 2 * ny * ny,
            tx: 2 * k * nx,
            ty: 2 * k * ny
        )
    }
}

/// The half-plane on the stuck side of the fold (everything the lifted corner is not).
private struct CardsHalfPlane: Shape {
    let fold: CardsPeelFold

    func path(in rect: CGRect) -> Path {
        let n = fold.normal
        let t = CGVector(dx: -n.dy, dy: n.dx)
        let far: CGFloat = 900
        let a = CGPoint(x: fold.mid.x + t.dx * far, y: fold.mid.y + t.dy * far)
        let b = CGPoint(x: fold.mid.x - t.dx * far, y: fold.mid.y - t.dy * far)
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: CGPoint(x: b.x - n.dx * far, y: b.y - n.dy * far))
        path.addLine(to: CGPoint(x: a.x - n.dx * far, y: a.y - n.dy * far))
        path.closeSubpath()
        return path
    }
}

/// Animatable so the fold itself (not just an offset) travels with the slap-back spring.
private struct CardsStickerSheet: View, Animatable {
    var peel: CGSize
    let corner: Int
    let shade: Double
    let language: AppLanguage

    var animatableData: CGSize.AnimatableData {
        get { peel.animatableData }
        set { peel.animatableData = newValue }
    }

    private var side: CGFloat { CardsStickerLayout.side }
    private var canvas: CGFloat { CardsStickerLayout.canvas }

    var body: some View {
        let fold = CardsPeelFold(corner: corner, peel: peel)
        let lifted = Double(min(fold.reach / 30, 1))
        ZStack {
            footprint
            CardsStickerFace(language: language)
                .frame(width: side, height: side)
                .frame(width: canvas, height: canvas)
                .mask(CardsHalfPlane(fold: fold))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            flapShadow(fold)
                .opacity(0.4 * shade * lifted)
            flap(fold)
        }
        .frame(width: canvas, height: canvas)
    }

    /// Where the sticker lives: a dashed outline that shows once the corner is up.
    private var footprint: some View {
        CardsStickerLayout.shape
            .fill(Color.primary.opacity(0.05))
            .overlay {
                CardsStickerLayout.shape
                    .strokeBorder(Color.primary.opacity(0.16), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
            }
            .frame(width: side, height: side)
    }

    private func flapShadow(_ fold: CardsPeelFold) -> some View {
        CardsStickerLayout.shape
            .fill(Color.black)
            .frame(width: side, height: side)
            .frame(width: canvas, height: canvas)
            .transformEffect(fold.reflection)
            .mask(CardsHalfPlane(fold: fold))
            .blur(radius: 7)
            .offset(x: -fold.normal.dx * 6, y: -fold.normal.dy * 6 + 3)
            .allowsHitTesting(false)
    }

    /// The paper back: the sticker's own outline mirrored across the fold. The gradient is laid out
    /// before the mirror, so it runs from the crease (dark) over the curl (bright) to the corner.
    private func flap(_ fold: CardsPeelFold) -> some View {
        let reach = max(fold.reach, 1)
        let start = UnitPoint(x: fold.mid.x / canvas, y: fold.mid.y / canvas)
        let end = UnitPoint(
            x: (fold.mid.x + fold.normal.dx * reach) / canvas,
            y: (fold.mid.y + fold.normal.dy * reach) / canvas
        )
        let stops: [Gradient.Stop] = [
            .init(color: Color.black.opacity(0.34 * shade), location: 0),
            .init(color: Color.white.opacity(0.75 * shade), location: 0.3),
            .init(color: Color.white.opacity(0), location: 0.68),
            .init(color: Color.black.opacity(0.1 * shade), location: 1),
        ]
        return ZStack {
            Color(hex: 0xDEDBD3)
            LinearGradient(stops: stops, startPoint: start, endPoint: end)
        }
        .frame(width: canvas, height: canvas)
        .mask(CardsStickerLayout.shape.frame(width: side, height: side))
        .transformEffect(fold.reflection)
        .mask(CardsHalfPlane(fold: fold))
        .allowsHitTesting(false)
    }
}

/// Die-cut sticker artwork: white border, glossy gradient, a glyph and a word.
private struct CardsStickerFace: View {
    let language: AppLanguage

    var body: some View {
        let inner = RoundedRectangle(cornerRadius: 20, style: .continuous)
        ZStack {
            CardsStickerLayout.shape.fill(Color.white)
            inner
                .fill(LinearGradient(colors: CardsArt.colors(2), startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 170, height: 170)
                        .blur(radius: 26)
                        .offset(x: 62, y: -70)
                }
                .overlay { artwork }
                .clipShape(inner)
                .padding(9)
        }
    }

    private var artwork: some View {
        VStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 64, weight: .black))
                .shadow(color: .black.opacity(0.18), radius: 5, y: 4)
            Text(L("MOTION", "动效"), language)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .tracking(language == .zh ? 8 : 3)
        }
        .foregroundStyle(.white)
    }
}
