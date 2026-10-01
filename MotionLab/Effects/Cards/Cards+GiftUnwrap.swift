import SwiftUI

extension Effect {
    static let cardsGiftUnwrap = Effect(
        id: "cards.gift-unwrap",
        category: .cards,
        interaction: .tap,
        name: L("Gift Unwrap", "拆礼物"),
        summary: L("A wrapped gift unties its bow, folds its four paper flaps open and lets a glowing gift card rise out.", "包好的礼物松开蝴蝶结，四片包装纸向外翻开，一张发光的礼品卡从里面升起。"),
        prompt: L(
            "A wrapped 168×124 pt gift seen from above: dotted paper, a gold ribbon cross and a bow. On tap the bow's loops collapse into the knot and the ribbons slip off toward the edges in 0.28 s (ease-in). The paper then opens as four triangular flaps meeting at the centre, each hinged on its own edge of the box: they swing up toward the viewer and over to 128°, 50 ms apart, on a spring (response 0.55 s, damping 0.62), showing a pale inner side past 90° and shading as they turn. From the dark interior a gift card rises 66 pt, growing from 78% to 100% on a slightly slower spring and tilting 4°; behind it an amber glow swells, rays turn slowly, and seven sparkles burst and fade with a success haptic. A second tap lowers the card, closes the flaps and re-ties the bow with a bounce.",
            "一份俯视的礼物（168×124 pt）：圆点包装纸、十字金丝带和蝴蝶结。点击后，蝴蝶结收进结里，丝带在0.28秒内缓入滑向边缘。接着包装纸分成四片在中心相接的三角翻盖，各以盒子的一条边为铰链，掀起并翻到128°，间隔50毫秒，弹簧响应0.55秒、阻尼0.62，过90°后露出浅色内面，明暗随转动变化。礼品卡从盒内升起66 pt，由78%放大到100%，弹簧稍慢，倾斜4°；身后琥珀色光晕胀开，光芒缓转，七颗星芒迸出后淡去，并有成功触感。再次点击，卡片降回，翻盖合上，蝴蝶结弹跳着系好。"
        ),
        implementation: L(
            "Each flap is the wrapping drawn at full size, masked to one triangle and placed with projectionEffect on a plane hinged at its edge, switching to the inner colour past 90°. Three state values (ribbon, flaps, card) are animated in sequence from one task; the rays are an AngularGradient turned by a TimelineView.",
            "每片翻盖都是整张包装纸遮罩成一个三角形，再用 projectionEffect 放到以对应边为铰链的平面上，转过90°后换成内面颜色。丝带、翻盖、卡片三个状态值由同一个 task 依次触发动画；光芒是一个由 TimelineView 转动的 AngularGradient。"
        ),
        apis: ["projectionEffect", "Animatable", "mask", "TimelineView", "AngularGradient", "keyframeAnimator"],
        tags: ["gift", "unwrap", "ribbon", "reward", "礼物", "拆开", "丝带", "礼品卡"],
        params: [
            .slider("angle", L("Flap angle", "翻盖角度"), 95...160, default: 128, step: 1, decimals: 0, unit: "°"),
            .slider("rise", L("Card rise", "卡片升起"), 40...84, default: 66, step: 1, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.35...0.9, default: 0.55, unit: "s"),
            .slider("glow", L("Glow", "光晕"), 0...1, default: 0.8),
        ]
    ) { ctx in
        CardsGiftDemo(ctx: ctx)
    }
}

private enum CardsGiftLayout {
    static let box = CGSize(width: 168, height: 124)
    static let card = CGSize(width: 142, height: 90)
    static let boxY: CGFloat = 28
    static let depth: CGFloat = 520
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }
}

private struct CardsGiftDemo: View {
    let ctx: DemoContext
    @State private var opened: Bool
    /// 0 tied, 1 ribbon gone.
    @State private var untie: CGFloat
    /// 0 closed, 1 open, one per flap (top, right, bottom, left).
    @State private var flaps: [CGFloat]
    /// 0 inside the box, 1 risen.
    @State private var lift: CGFloat
    @State private var bursts = 0
    @State private var busy = false
    @State private var script: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        let done: CGFloat = ctx.isStill ? 1 : 0
        _opened = State(initialValue: ctx.isStill)
        _untie = State(initialValue: done)
        _flaps = State(initialValue: Array(repeating: done, count: 4))
        _lift = State(initialValue: done)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                gift
                    .offset(y: CardsGiftLayout.boxY)
                risen
            }
            .frame(width: 320, height: 290)
            .contentShape(Rectangle())
            .onTapGesture { toggle(haptic: true) }
            DemoHint(text: L("Tap the gift", "点击礼物"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.7) { toggle(haptic: false) }
        .onDisappear { script?.cancel() }
    }

    private var gift: some View {
        let size = CardsGiftLayout.box
        return ZStack {
            CardsGiftLayout.shape
                .fill(Color.black)
                .frame(width: size.width * 0.94, height: size.height * 0.9)
                .blur(radius: 14)
                .opacity(0.3)
                .offset(y: 14)
            CardsGiftInterior(glow: ctx["glow"] * Double(lift.clamped(to: 0...1)))
            ForEach(0..<4, id: \.self) { index in
                CardsGiftFlap(side: index, open: flaps[index], maxAngle: ctx.cg("angle"))
            }
            CardsGiftRibbon(untie: untie)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The glow, rays, sparkles and the card: above the box once it is out.
    private var risen: some View {
        let up = lift
        let y = CardsGiftLayout.boxY - ctx.cg("rise") * up
        return ZStack {
            CardsGiftRays(strength: ctx["glow"] * Double(up.clamped(to: 0...1)), animated: !ctx.isStill, preview: ctx.isPreview)
            CardsGiftSparkles(trigger: bursts)
            CardsGiftCard(language: ctx.language)
                .scaleEffect(0.78 + 0.22 * up)
                .rotationEffect(.degrees(-4 * Double(up)))
                .shadow(color: .black.opacity(0.3 * Double(up.clamped(to: 0...1))), radius: 14, y: 10)
                .opacity(Double((up * 5).clamped(to: 0...1)))
        }
        .offset(y: y)
        .allowsHitTesting(false)
    }

    private func toggle(haptic: Bool) {
        guard !busy else { return }
        busy = true
        let buzz = haptic && !ctx.isPreview
        let response = ctx["response"]
        script?.cancel()
        if !opened {
            opened = true
            if buzz { Haptics.tap(.light) }
            withAnimation(.easeIn(duration: 0.28)) { untie = 1 }
            script = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.24))
                guard !Task.isCancelled else { return }
                for index in 0..<4 {
                    withAnimation(.spring(response: response, dampingFraction: 0.62).delay(0.05 * Double(index))) {
                        flaps[index] = 1
                    }
                }
                try? await Task.sleep(for: .seconds(0.2))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: response * 1.15, dampingFraction: 0.6)) { lift = 1 }
                bursts += 1
                if buzz { Haptics.success() }
                try? await Task.sleep(for: .seconds(response * 0.8))
                busy = false
            }
        } else {
            opened = false
            if buzz { Haptics.tap(.light) }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) { lift = 0 }
            script = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.18))
                guard !Task.isCancelled else { return }
                for index in 0..<4 {
                    withAnimation(.spring(response: response * 0.8, dampingFraction: 0.86).delay(0.04 * Double(3 - index))) {
                        flaps[index] = 0
                    }
                }
                try? await Task.sleep(for: .seconds(response * 0.55))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.58)) { untie = 0 }
                if buzz { Haptics.tap(.soft) }
                try? await Task.sleep(for: .seconds(0.3))
                busy = false
            }
        }
    }
}

// MARK: - Wrapping

/// One triangular flap of wrapping paper, hinged on an edge of the box. `side`: 0 top, 1 right, 2 bottom, 3 left.
private struct CardsGiftFlap: View, Animatable {
    let side: Int
    var open: CGFloat
    let maxAngle: CGFloat

    var animatableData: CGFloat {
        get { open }
        set { open = newValue }
    }

    var body: some View {
        let size = CardsGiftLayout.box
        let angle = max(open, -0.05) * maxAngle * .pi / 180
        let inside = angle > .pi / 2
        let turned = Double(abs(sin(angle)))
        ZStack {
            if inside {
                // The paper's plain inner side.
                LinearGradient(colors: [Color(hex: 0xFFF3E4), Color(hex: 0xF2D9C0)], startPoint: .top, endPoint: .bottom)
                Color.black.opacity(0.16 * (1 - turned))
            } else {
                CardsGiftPaper()
                Color.black.opacity(0.34 * turned)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(CardsGiftLayout.shape)
        .mask(CardsGiftTriangle(side: side))
        .projectionEffect(plane(angle).projection(eye: CGPoint(x: size.width / 2, y: size.height / 2), depth: CardsGiftLayout.depth))
    }

    private func plane(_ angle: CGFloat) -> CardsPlane3D {
        let size = CardsGiftLayout.box
        switch side {
        case 0: return .hingeX(lineY: 0, angle: angle)
        case 1: return .hingeY(lineX: size.width, angle: -angle)
        case 2: return .hingeX(lineY: size.height, angle: -angle)
        default: return .hingeY(lineX: 0, angle: angle)
        }
    }
}

private struct CardsGiftTriangle: Shape {
    let side: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
        ]
        var path = Path()
        path.move(to: corners[side % 4])
        path.addLine(to: corners[(side + 1) % 4])
        path.addLine(to: centre)
        path.closeSubpath()
        return path
    }
}

private struct CardsGiftPaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xFF6F91), Color(hex: 0xE8437A), Color(hex: 0xB9306E)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                let step: CGFloat = 20
                var row = 0
                var y: CGFloat = 8
                while y < size.height {
                    var x: CGFloat = row % 2 == 0 ? 8 : 18
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)), with: .color(.white.opacity(0.32)))
                        x += step
                    }
                    y += step * 0.8
                    row += 1
                }
            }
        }
    }
}

/// What is under the paper: a dark box that fills with warm light.
private struct CardsGiftInterior: View {
    let glow: Double

    var body: some View {
        let size = CardsGiftLayout.box
        ZStack {
            CardsGiftLayout.shape
                .fill(
                    LinearGradient(colors: [Color(hex: 0x2B1524), Color(hex: 0x1A0D18)], startPoint: .top, endPoint: .bottom)
                        .shadow(.inner(color: .black.opacity(0.8), radius: 10, y: 6))
                )
            RadialGradient(colors: [Color(hex: 0xFFC56B).opacity(0.85 * glow), Color(hex: 0xFF8A3C).opacity(0)], center: .center, startRadius: 4, endRadius: 100)
                .clipShape(CardsGiftLayout.shape)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Ribbon cross and bow. As `untie` runs 0 → 1 the loops fold into the knot and the bands slip off.
private struct CardsGiftRibbon: View {
    let untie: CGFloat

    private var gold: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFFE9A8), Color(hex: 0xE9B24A), Color(hex: 0xC48A22)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        let size = CardsGiftLayout.box
        let u = untie.clamped(to: 0...1.2)
        let slip = ((u - 0.25) / 0.75).clamped(to: 0...1)
        let fold = (u / 0.55).clamped(to: 0...1)
        ZStack {
            // Each band is two halves that slide off toward their own edge.
            band(vertical: true, sign: -1, slip: slip)
            band(vertical: true, sign: 1, slip: slip)
            band(vertical: false, sign: -1, slip: slip)
            band(vertical: false, sign: 1, slip: slip)
            bow(fold: fold)
                .scaleEffect(untie < 0 ? 1 - untie * 0.6 : 1)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(CardsGiftLayout.shape.inset(by: -40))
        .allowsHitTesting(false)
    }

    private func band(vertical: Bool, sign: CGFloat, slip: CGFloat) -> some View {
        let size = CardsGiftLayout.box
        let length = (vertical ? size.height : size.width) / 2
        let shown = length * (1 - slip)
        return Rectangle()
            .fill(gold)
            .overlay {
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: vertical ? 3 : nil, height: vertical ? nil : 3)
            }
            .frame(width: vertical ? 20 : max(shown, 0), height: vertical ? max(shown, 0) : 20)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .offset(
                x: vertical ? 0 : sign * (length - shown / 2),
                y: vertical ? sign * (length - shown / 2) : 0
            )
            .opacity(slip >= 1 ? 0 : 1)
    }

    private func bow(fold: CGFloat) -> some View {
        let scale = 1 - fold
        return ZStack {
            loop
                .scaleEffect(x: scale, y: 0.6 + 0.4 * scale, anchor: .trailing)
                .rotationEffect(.degrees(18 + 30 * Double(fold)), anchor: .trailing)
                .offset(x: -19)
            loop
                .scaleEffect(x: scale, y: 0.6 + 0.4 * scale, anchor: .leading)
                .rotationEffect(.degrees(-18 - 30 * Double(fold)), anchor: .leading)
                .offset(x: 19)
            Circle()
                .fill(gold)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.14), lineWidth: 0.8))
                .scaleEffect(1 - 0.9 * fold)
        }
        .shadow(color: .black.opacity(0.25 * Double(scale)), radius: 4, y: 3)
        .opacity(fold >= 1 ? 0 : 1)
    }

    private var loop: some View {
        Ellipse()
            .fill(gold)
            .frame(width: 38, height: 26)
            .overlay {
                Ellipse()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: 20, height: 10)
            }
            .overlay(Ellipse().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.8))
    }
}

// MARK: - What comes out

private struct CardsGiftCard: View {
    let language: AppLanguage

    var body: some View {
        let size = CardsGiftLayout.card
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(L("GIFT CARD", "礼品卡"), language)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                Spacer(minLength: 0)
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
            }
            .opacity(0.9)
            Spacer(minLength: 0)
            Text(verbatim: "50")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text(L("For you, with thanks", "送给你，谢谢你"), language)
                .font(.system(size: 9, weight: .semibold))
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(width: size.width, height: size.height)
        .background {
            LinearGradient(colors: [Color(hex: 0x6E5BFF), Color(hex: 0xA95CFF), Color(hex: 0xFF7AB8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 110, height: 110)
                .offset(x: 36, y: -60)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}

/// A soft glow with slowly turning rays behind the card.
private struct CardsGiftRays: View {
    let strength: Double
    let animated: Bool
    let preview: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !animated || strength < 0.02)) { timeline in
            let turn = animated ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 36) * 10 : 14
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFD27A).opacity(0.75), Color(hex: 0xFF9A4A).opacity(0)], center: .center, startRadius: 6, endRadius: 100))
                    .frame(width: 200, height: 200)
                AngularGradient(
                    stops: Self.stops,
                    center: .center,
                    angle: .degrees(turn)
                )
                .frame(width: 216, height: 216)
                .mask {
                    RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 30, endRadius: 106)
                }
                .blendMode(.plusLighter)
            }
            .scaleEffect(0.5 + 0.5 * strength)
            .opacity(strength)
        }
    }

    /// Twelve soft rays.
    private static let stops: [Gradient.Stop] = {
        var result: [Gradient.Stop] = []
        let rays = 12
        for ray in 0..<rays {
            let start = Double(ray) / Double(rays)
            let width = 1.0 / Double(rays)
            result.append(.init(color: Color(hex: 0xFFE2A0).opacity(0), location: start))
            result.append(.init(color: Color(hex: 0xFFE2A0).opacity(0.5), location: start + width * 0.25))
            result.append(.init(color: Color(hex: 0xFFE2A0).opacity(0), location: start + width * 0.5))
        }
        result.append(.init(color: Color(hex: 0xFFE2A0).opacity(0), location: 1))
        return result
    }()
}

private struct CardsGiftSparkles: View {
    let trigger: Int

    private struct Burst {
        var reach: CGFloat = 0
        var fade: Double = 0
    }

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                let angle = Double(index) * 2 * .pi / 7 - 1.2
                Image(systemName: "sparkle")
                    .font(.system(size: index % 2 == 0 ? 16 : 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFFE9A8))
                    .keyframeAnimator(initialValue: Burst(), trigger: trigger) { content, burst in
                        content
                            .scaleEffect(0.3 + 0.9 * burst.reach)
                            .offset(x: CGFloat(cos(angle)) * (40 + 78 * burst.reach), y: CGFloat(sin(angle)) * (28 + 54 * burst.reach))
                            .opacity(burst.fade)
                    } keyframes: { _ in
                        KeyframeTrack(\.reach) {
                            MoveKeyframe(0)
                            LinearKeyframe(0, duration: 0.03 * Double(index) + 0.01)
                            SpringKeyframe(1, duration: 0.7, spring: Spring(response: 0.45, dampingRatio: 0.72))
                        }
                        KeyframeTrack(\.fade) {
                            MoveKeyframe(0)
                            LinearKeyframe(1, duration: 0.03 * Double(index) + 0.08)
                            LinearKeyframe(1, duration: 0.3)
                            LinearKeyframe(0, duration: 0.4)
                        }
                    }
            }
        }
    }
}
