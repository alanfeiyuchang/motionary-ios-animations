import SwiftUI

// MARK: - Order box

extension Effect {
    static let feedbackOrderBox = Effect(
        id: "feedback.order-box",
        category: .feedback,
        interaction: .tap,
        name: L("Packed Order Box", "打包封箱"),
        summary: L("The purchase drops into a cardboard box, the flaps fold shut, tape runs over the seam, the box hops and a green check is stamped on.", "商品落进纸箱，箱盖依次合上，胶带沿缝贴好，纸箱蹦一下，盖上一枚绿色对勾。"),
        prompt: L(
            "An open cardboard box drawn in oblique projection, its four flaps standing out at 118–125°. On 'Place order' the product tile falls into it on a spring (response 0.45 s, damping 0.8). The two short flaps fold shut in 0.3 s, then the left and right flaps slap down 80 ms apart on springs (response 0.4 s, damping 0.72), each darkening as it turns away from the light. A pale tape strip runs up the front and across the seam in 0.35 s. The sealed box crouches to 92% height, hops 34 pt and lands with a squash while its ground shadow shrinks and returns. On landing a green check stamp drops from 240% scale at −28° to 100% at −10° on a spring (response 0.28 s, damping 0.55) with an expanding ink ring and a success haptic; the caption changes to 'Order placed'.",
            "斜投影绘制的敞口纸箱，四片箱盖向外张开 118–125°。点击“提交订单”，商品方块以弹簧（响应 0.45 秒、阻尼 0.8）落入箱中。两片短盖 0.3 秒合上，左右长盖随后相隔 80 毫秒以弹簧（响应 0.4 秒、阻尼 0.72）拍下。浅色胶带 0.35 秒内从正面向上越过箱缝贴好。纸箱下蹲到 92% 高度，跳起 34 pt，落地压扁回弹，地面阴影随之收缩。随后绿色对勾印章从 240%、−28° 落到 100%、−10°（弹簧响应 0.28 秒、阻尼 0.55），墨圈向外扩散并触发成功触感，文案变为“下单成功”。"
        ),
        implementation: L(
            "The box is two Animatable Canvas layers that project 3D corner points with a fixed oblique matrix; each flap is a quad rotated about its hinge by an animatable angle, shaded by that angle. The product tile sits between the two layers so the front face hides it. The hop is a keyframeAnimator; the stamp is a spring on scale and rotation.",
            "纸箱由两层 Animatable Canvas 组成，用固定的斜投影矩阵把三维顶点投到平面；每片箱盖是绕铰链按可动画角度旋转的四边形，并按角度着色。商品方块夹在两层之间，因此会被正面挡住。跳跃由 keyframeAnimator 完成，印章是缩放与旋转上的弹簧。"
        ),
        apis: ["Canvas", "Animatable", "AnimatablePair", "keyframeAnimator(initialValue:trigger:)", "spring(response:dampingFraction:)"],
        tags: ["order", "success", "box", "package", "checkout", "下单", "成功", "纸箱", "打包"],
        params: [
            .slider("tempo", L("Tempo", "节奏"), 0.6...1.6, default: 1.0, unit: "×"),
            .slider("hop", L("Hop height", "跳起高度"), 8...60, default: 34, decimals: 0, unit: "pt"),
            .slider("stamp", L("Stamp drop scale", "印章起始缩放"), 1.4...3.6, default: 2.4, decimals: 1, unit: "×"),
        ]
    ) { ctx in
        OrderBoxDemo(ctx: ctx)
    }
}

private struct OrderBoxDemo: View {
    let ctx: DemoContext
    @State private var item: CGFloat
    @State private var minor: CGFloat
    @State private var left: CGFloat
    @State private var right: CGFloat
    @State private var tape: CGFloat
    @State private var stamped: Bool
    @State private var ring: Bool
    @State private var done: Bool
    @State private var busy = false
    @State private var hops = 0
    @State private var thuds = 0
    /// Scale the stamp starts from (the drop), or the small lift it leaves with on reset.
    @State private var stampRest: CGFloat = 1.15
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the sealed, stamped box.
        let sealed: CGFloat = ctx.isStill ? 1 : 0
        _item = State(initialValue: sealed)
        _minor = State(initialValue: sealed)
        _left = State(initialValue: sealed)
        _right = State(initialValue: sealed)
        _tape = State(initialValue: sealed)
        _stamped = State(initialValue: ctx.isStill)
        _ring = State(initialValue: ctx.isStill)
        _done = State(initialValue: ctx.isStill)
    }

    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        VStack(spacing: 8) {
            box
            caption
            button
            DemoHint(text: L("Tap Place order", "点击“提交订单”"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 5.4 / ctx["tempo"] + 0.6, delay: 0.5) { play() }
    }

    // MARK: Box

    private var box: some View {
        let hop: CGFloat = ctx.cg("hop")
        return ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 170, height: 16)
                .blur(radius: 6)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: hops) { content, scale in
                    content.scaleEffect(scale).opacity(Double(scale))
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(1.05, duration: 0.14)
                        CubicKeyframe(0.62, duration: 0.2)
                        CubicKeyframe(1.06, duration: 0.2)
                        SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                    }
                }
                .offset(x: 12, y: 86)
            ZStack {
                OrderBoxBack(minor: minor)
                OrderBoxItem()
                    .offset(x: 13, y: -92 + 110 * item)
                    .opacity(Double(min(item * 4, 1)))
                OrderBoxFront(minor: minor, left: left, right: right, tape: tape)
                stamp
            }
            .frame(width: OrderBoxGeometry.size.width, height: OrderBoxGeometry.size.height)
            .keyframeAnimator(initialValue: OrderBoxHop(), trigger: hops) { content, value in
                content
                    .scaleEffect(x: value.squashX, y: value.squashY, anchor: .bottom)
                    .offset(y: value.lift)
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    CubicKeyframe(0, duration: 0.14)
                    CubicKeyframe(-hop, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(0, duration: 0.35)
                }
                KeyframeTrack(\.squashY) {
                    CubicKeyframe(0.92, duration: 0.14)
                    CubicKeyframe(1.05, duration: 0.2)
                    CubicKeyframe(1.0, duration: 0.16)
                    CubicKeyframe(0.9, duration: 0.07)
                    SpringKeyframe(1, duration: 0.32, spring: .bouncy)
                }
                KeyframeTrack(\.squashX) {
                    CubicKeyframe(1.05, duration: 0.14)
                    CubicKeyframe(0.97, duration: 0.2)
                    CubicKeyframe(1.0, duration: 0.16)
                    CubicKeyframe(1.07, duration: 0.07)
                    SpringKeyframe(1, duration: 0.32, spring: .bouncy)
                }
            }
            .keyframeAnimator(initialValue: CGFloat(1), trigger: thuds) { content, dip in
                content.scaleEffect(dip, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(0.965, duration: 0.07)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
            }
        }
        .frame(width: OrderBoxGeometry.size.width, height: OrderBoxGeometry.size.height)
        .scaleEffect(1.1, anchor: .bottom)
        .padding(.top, 16)
    }

    private var stamp: some View {
        let dropping: Bool = stampRest > 1.3
        return ZStack {
            Circle()
                .stroke(Palette.green.opacity(ring ? 0 : 0.7), lineWidth: 2)
                .frame(width: 46, height: 46)
                .scaleEffect(ring ? 1.9 : 1)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x4BE08F), Color(hex: 0x1FA85B)], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 2.5).padding(3))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            FeedbackCheckShape()
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 19, height: 15)
        }
        .scaleEffect(stamped ? 1 : stampRest)
        .rotationEffect(.degrees(stamped || !dropping ? -10 : -28))
        .opacity(stamped ? 1 : 0)
        .position(OrderBoxGeometry.stampCentre)
    }

    // MARK: Text

    private var caption: some View {
        VStack(spacing: 2) {
            Text(done ? (zh ? "下单成功" : "Order placed") : (zh ? "无线降噪耳机" : "Wireless headphones"))
                .font(.headline)
                .contentTransition(.opacity)
            Text(done ? (zh ? "订单 A-2048 · 周四送达" : "Order A-2048 · arrives Thursday") : (zh ? "¥899.00 · 包邮" : "$129.00 · free shipping"))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .frame(height: 42)
        .id(done)
        .transition(.blurReplace)
    }

    private var button: some View {
        Button(action: tapped) {
            Text(done ? (zh ? "再来一单" : "Order again") : (zh ? "提交订单" : "Place order"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(done ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.white))
                .frame(width: 190, height: 42)
                .background {
                    if done {
                        Capsule().fill(Color.primary.opacity(0.09))
                    } else {
                        Capsule().fill(Palette.primaryStrong)
                    }
                }
                .opacity(busy ? 0.5 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: Sequence

    private func tapped() {
        guard !busy else { return }
        if done { reset() } else { pack() }
    }

    /// Preview loop and intro: pack, or reopen first when the last run is still showing.
    private func play() {
        guard !busy else { return }
        guard done else {
            pack()
            return
        }
        reset()
        token += 1
        let current = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            guard token == current else { return }
            pack()
        }
    }

    private func reset() {
        token += 1
        ring = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            stampRest = 1.15
            stamped = false
            done = false
            tape = 0
            left = 0
            right = 0
            minor = 0
        }
        withAnimation(.easeIn(duration: 0.2)) { item = 0 }
    }

    private func pack() {
        token += 1
        let current = token
        let pace: Double = 1 / max(ctx["tempo"], 0.1)
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        busy = true
        // The stamp is invisible here: move it up to its drop pose.
        stampRest = ctx.cg("stamp")
        if buzz { Haptics.tap() }
        withAnimation(.spring(response: 0.45 * pace, dampingFraction: 0.8)) { item = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.38 * pace))
            guard token == current else { return }
            withAnimation(.easeInOut(duration: 0.3 * pace)) { minor = 1 }
            try? await Task.sleep(for: .seconds(0.3 * pace))
            guard token == current else { return }
            withAnimation(.spring(response: 0.4 * pace, dampingFraction: 0.72)) { left = 1 }
            withAnimation(.spring(response: 0.4 * pace, dampingFraction: 0.72).delay(0.08 * pace)) { right = 1 }
            try? await Task.sleep(for: .seconds(0.3 * pace))
            guard token == current else { return }
            if buzz { Haptics.tap(.soft) }
            try? await Task.sleep(for: .seconds(0.16 * pace))
            guard token == current else { return }
            withAnimation(.easeInOut(duration: 0.35 * pace)) { tape = 1 }
            try? await Task.sleep(for: .seconds(0.45 * pace))
            guard token == current else { return }
            hops += 1
            try? await Task.sleep(for: .seconds(0.56))
            guard token == current else { return }
            if buzz { Haptics.tap(.medium) }
            try? await Task.sleep(for: .seconds(0.18))
            guard token == current else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { stamped = true }
            try? await Task.sleep(for: .seconds(0.11))
            guard token == current else { return }
            thuds += 1
            withAnimation(.easeOut(duration: 0.5)) { ring = true }
            withAnimation(.smooth(duration: 0.3)) { done = true }
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            busy = false
        }
    }
}

private struct OrderBoxHop {
    var lift: CGFloat = 0
    var squashX: CGFloat = 1
    var squashY: CGFloat = 1
}

// MARK: - Geometry

/// A box of W × H × D drawn in oblique projection: depth runs up and to the right.
private enum OrderBoxGeometry {
    static let size = CGSize(width: 240, height: 178)
    static let width: CGFloat = 132
    static let height: CGFloat = 82
    static let depth: CGFloat = 64
    static let origin = CGPoint(x: 40, y: 172)
    static let longFlap: CGFloat = 66
    static let shortFlap: CGFloat = 32
    static let longOpen: Double = 118
    static let shortOpen: Double = 125

    static func point(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x + z * 0.42, y: origin.y - y - z * 0.36)
    }

    static func quad(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Path {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.addLine(to: d)
        path.closeSubpath()
        return path
    }

    /// Where the stamp lands on the front face.
    static var stampCentre: CGPoint {
        CGPoint(x: origin.x + width - 36, y: origin.y - height / 2 + 2)
    }

    /// Cardboard tone: `light` 0 (in shade) … 1 (facing the light).
    static func cardboard(_ light: Double) -> Color {
        let l: Double = min(max(light, 0), 1)
        return Color(
            .sRGB,
            red: (176 + (236 - 176) * l) / 255,
            green: (124 + (192 - 124) * l) / 255,
            blue: (74 + (138 - 74) * l) / 255,
            opacity: 1
        )
    }
}

/// Behind the product: the inside of the box and the far flap.
private struct OrderBoxBack: View, Animatable {
    var minor: CGFloat

    var animatableData: CGFloat {
        get { minor }
        set { minor = newValue }
    }

    var body: some View {
        let minor: CGFloat = self.minor
        Canvas { context, _ in
            let g = OrderBoxGeometry.self
            let w: CGFloat = g.width
            let h: CGFloat = g.height
            let d: CGFloat = g.depth
            // Inside walls seen through the opening.
            let opening: Path = g.quad(g.point(0, h, 0), g.point(w, h, 0), g.point(w, h, d), g.point(0, h, d))
            context.fill(opening, with: .color(Color(hex: 0x6E4A28)))
            let innerBack: Path = g.quad(g.point(0, h, d), g.point(w, h, d), g.point(w, h - 26, d), g.point(0, h - 26, d))
            context.fill(innerBack, with: .color(Color(hex: 0x8A5F36)))
            // Far flap, hinged on the back edge.
            let angle: Double = Double(1 - minor) * g.shortOpen * .pi / 180
            let reach: CGFloat = g.shortFlap * CGFloat(cos(angle))
            let rise: CGFloat = g.shortFlap * CGFloat(sin(angle))
            let flap: Path = g.quad(g.point(0, h, d), g.point(w, h, d), g.point(w, h + rise, d - reach), g.point(0, h + rise, d - reach))
            context.fill(flap, with: .color(g.cardboard(0.45 + 0.5 * Double(minor))))
            context.stroke(flap, with: .color(Color(hex: 0x8A5F36).opacity(0.5)), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}

/// In front of the product: the faces, the near and side flaps and the tape.
private struct OrderBoxFront: View, Animatable {
    var minor: CGFloat
    var left: CGFloat
    var right: CGFloat
    var tape: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(minor, left), AnimatablePair(right, tape)) }
        set {
            minor = newValue.first.first
            left = newValue.first.second
            right = newValue.second.first
            tape = newValue.second.second
        }
    }

    var body: some View {
        let minor: CGFloat = self.minor
        let left: CGFloat = self.left
        let right: CGFloat = self.right
        let tape: CGFloat = min(max(self.tape, 0), 1)
        Canvas { context, _ in
            OrderBoxPainter.faces(&context)
            OrderBoxPainter.nearFlap(&context, closed: minor)
            OrderBoxPainter.sideFlap(&context, closed: left, onLeft: true)
            OrderBoxPainter.sideFlap(&context, closed: right, onLeft: false)
            OrderBoxPainter.tape(&context, progress: tape)
        }
        .allowsHitTesting(false)
    }
}

private enum OrderBoxPainter {
    private static let g = OrderBoxGeometry.self
    private static let edge = Color(hex: 0x8A5F36).opacity(0.55)

    static func faces(_ context: inout GraphicsContext) {
        let w: CGFloat = g.width
        let h: CGFloat = g.height
        let d: CGFloat = g.depth
        let side: Path = g.quad(g.point(w, 0, 0), g.point(w, 0, d), g.point(w, h, d), g.point(w, h, 0))
        context.fill(side, with: .color(g.cardboard(0.22)))
        let front: Path = g.quad(g.point(0, 0, 0), g.point(w, 0, 0), g.point(w, h, 0), g.point(0, h, 0))
        context.fill(
            front,
            with: .linearGradient(
                Gradient(colors: [g.cardboard(0.78), g.cardboard(0.56)]),
                startPoint: g.point(0, h, 0),
                endPoint: g.point(0, 0, 0)
            )
        )
        context.stroke(front, with: .color(edge), lineWidth: 0.6)
        context.stroke(side, with: .color(edge), lineWidth: 0.6)
        // Shipping label.
        let label = CGRect(x: g.origin.x + 12, y: g.origin.y - 40, width: 44, height: 28)
        context.fill(Path(roundedRect: label, cornerRadius: 3), with: .color(Color.white.opacity(0.92)))
        for line in 0..<3 {
            let lineWidth: CGFloat = line == 2 ? 18 : 30
            let rect = CGRect(x: label.minX + 5, y: label.minY + 6 + CGFloat(line) * 6, width: lineWidth, height: 2.4)
            context.fill(Path(roundedRect: rect, cornerRadius: 1.2), with: .color(Color.black.opacity(line == 0 ? 0.55 : 0.25)))
        }
        for bar in 0..<5 {
            let rect = CGRect(x: label.maxX - 14 + CGFloat(bar) * 2.2, y: label.maxY - 11, width: bar % 2 == 0 ? 1.4 : 0.8, height: 7)
            context.fill(Path(rect), with: .color(Color.black.opacity(0.6)))
        }
    }

    /// The near flap is hinged on the front top edge; open it leans towards the viewer.
    static func nearFlap(_ context: inout GraphicsContext, closed: CGFloat) {
        let w: CGFloat = g.width
        let h: CGFloat = g.height
        let angle: Double = Double(1 - closed) * g.shortOpen * .pi / 180
        let reach: CGFloat = g.shortFlap * CGFloat(cos(angle))
        let rise: CGFloat = g.shortFlap * CGFloat(sin(angle))
        let flap: Path = g.quad(g.point(0, h, 0), g.point(w, h, 0), g.point(w, h + rise, reach), g.point(0, h + rise, reach))
        context.fill(flap, with: .color(g.cardboard(0.5 + 0.45 * Double(closed))))
        context.stroke(flap, with: .color(edge), lineWidth: 0.6)
    }

    /// A long flap hinged on the left or right top edge; closed it lies on the top towards the middle.
    static func sideFlap(_ context: inout GraphicsContext, closed: CGFloat, onLeft: Bool) {
        let w: CGFloat = g.width
        let h: CGFloat = g.height
        let d: CGFloat = g.depth
        let angle: Double = Double(1 - closed) * g.longOpen * .pi / 180
        let reach: CGFloat = g.longFlap * CGFloat(cos(angle))
        let rise: CGFloat = g.longFlap * CGFloat(sin(angle))
        let hinge: CGFloat = onLeft ? 0 : w
        let tip: CGFloat = onLeft ? reach : w - reach
        let flap: Path = g.quad(g.point(hinge, h, 0), g.point(hinge, h, d), g.point(tip, h + rise, d), g.point(tip, h + rise, 0))
        // The top catches the light once it lies flat; the left flap's underside is the darker one while open.
        let open: Double = onLeft ? 0.38 : 0.62
        let light: Double = open + (0.98 - open) * Double(min(max(closed, 0), 1))
        context.fill(flap, with: .color(g.cardboard(light)))
        context.stroke(flap, with: .color(edge), lineWidth: 0.6)
    }

    /// Tape runs up the front face, then over the seam to the back edge.
    static func tape(_ context: inout GraphicsContext, progress: CGFloat) {
        guard progress > 0.001 else { return }
        let w: CGFloat = g.width
        let h: CGFloat = g.height
        let d: CGFloat = g.depth
        let half: CGFloat = 8
        let frontRun: CGFloat = 20
        let total: CGFloat = frontRun + d
        let drawn: CGFloat = total * progress
        let colour = Color(hex: 0xFFF3D6).opacity(0.9)
        let x0: CGFloat = w / 2 - half
        let x1: CGFloat = w / 2 + half
        let frontDrawn: CGFloat = min(drawn, frontRun)
        let front: Path = g.quad(
            g.point(x0, h - frontRun, 0),
            g.point(x1, h - frontRun, 0),
            g.point(x1, h - frontRun + frontDrawn, 0),
            g.point(x0, h - frontRun + frontDrawn, 0)
        )
        context.fill(front, with: .color(colour.opacity(0.78)))
        guard drawn > frontRun else { return }
        let z: CGFloat = drawn - frontRun
        let top: Path = g.quad(g.point(x0, h, 0), g.point(x1, h, 0), g.point(x1, h, z), g.point(x0, h, z))
        context.fill(top, with: .color(colour))
        context.stroke(top, with: .color(Color(hex: 0xC9A66B).opacity(0.6)), lineWidth: 0.5)
    }
}

/// The purchase: a small product tile that drops into the box.
private struct OrderBoxItem: View {
    var body: some View {
        Image(systemName: "headphones")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(Palette.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: Palette.indigo.opacity(0.35), radius: 8, y: 4)
    }
}
