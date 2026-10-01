import SwiftUI

extension Effect {
    static let iconsCartBounce = Effect(
        id: "icons.cart-bounce",
        category: .icons,
        interaction: .tap,
        name: L("Cart Bounce", "购物车接货"),
        summary: L("An item drops into the cart, the cart squashes and rolls on its wheels, the load jostles and the badge pops.", "商品落进购物车，车身压扁并顺着轮子晃动，车里的货物颠一下，角标随之弹出。"),
        prompt: L(
            "A shopping cart drawn with a thick rounded frame, a violet basket and two wheels, a red count badge on its corner. On tap a coloured parcel springs into view 100 pt above the basket, turned 24°, then falls under gravity for about 0.33 s, straightening as it drops behind the basket's front wall. On impact the cart squashes 16% around the ground and rings back (decay 11, about 5 Hz), its shadow widening; it rolls 8 pt forward and back on a slower decaying swing while the wheels turn with it, and the parcels already inside hop 7 pt one after another. 40 ms after the landing the badge kicks up to about 130% and settles as its number rolls up. A light tap on touch, a medium thud on landing. Bouncy, weighty and satisfying.",
            "一辆购物车：粗圆角车架、紫色车篮、两只轮子，角上挂着红色数量角标。点击后一件彩色包裹在车篮上方100 pt处弹出，倾斜24°，随后在重力下用约0.33秒落下，边落边摆正，落到车篮前壁之后。着地瞬间车身以地面为锚点压扁16%再回弹（衰减11、约5 Hz），阴影随之变宽；车身以更慢的衰减摆动前后滚动8 pt，轮子跟着转动，车里已有的包裹依次颠起7 pt。落地40毫秒后，角标弹到约130%再落定，数字向上滚动。点击是轻触感，落地是一记中等触感。有弹性、有分量、很解压。"
        ),
        implementation: L(
            "A TimelineView feeds the seconds since the tap to the parcel's parabola, a decaying-cosine squash, a decaying-sine roll that also rotates the wheels, and the badge kick; layer order (frame, parcels, basket front, wheels) hides the parcel as it lands.",
            "TimelineView 把点击后的秒数交给包裹的抛物线、衰减余弦的压扁量、同时带动轮子转动的衰减正弦滚动，以及角标的弹跳；图层顺序（车架、包裹、车篮前壁、轮子）让包裹落下时自然被遮住。"
        ),
        apis: ["TimelineView(.animation)", "Path", "scaleEffect(x:y:anchor:)", "rotationEffect", "contentTransition(.numericText(value:))"],
        tags: ["cart", "shopping", "add to cart", "badge", "drop", "购物车", "加购", "角标", "落下", "电商"],
        params: [
            .slider("height", L("Drop height", "下落高度"), 60...130, default: 100, decimals: 0, unit: "pt"),
            .slider("squash", L("Landing squash", "落地压扁"), 0...0.3, default: 0.16),
            .slider("pop", L("Badge pop", "角标弹跳"), 0...0.8, default: 0.45),
        ]
    ) { ctx in
        IconsCartBounceDemo(ctx: ctx)
    }
}

private struct IconsCartBounceDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast
    /// Parcels dropped so far (the last one may still be falling).
    @State private var count: Int = 2
    @State private var badge: Int = 2

    private var landing: Double { IconsCartScene.landing(height: ctx["height"]) }

    var body: some View {
        VStack(spacing: 8) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsCartScene(
                    t: ctx.isStill ? 10 : elapsed(at: date),
                    count: count,
                    badge: badge,
                    height: ctx["height"],
                    squash: ctx["squash"],
                    pop: ctx["pop"]
                )
            }
            .frame(width: 250, height: 236)
            .contentShape(Rectangle())
            .onTapGesture { add() }
            DemoHint(text: L("Tap to add an item", "点击加入一件商品"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { add() }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private func add() {
        // One parcel at a time: taps are ignored while it is in the air.
        guard elapsed(at: .now) > landing + 0.25 else { return }
        start = .now
        count += 1
        Haptics.tap(.light)
        let next: Int = badge >= 99 ? 1 : badge + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + landing + 0.04) {
            withAnimation(.snappy(duration: 0.3)) { badge = next }
        }
        IconsHaptics.later(landing, preview: ctx.isPreview) { Haptics.tap(.medium) }
    }
}

/// The cart's handle and chassis: one stroked polyline.
private struct IconsCartFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: c.x - 98, y: c.y - 42))
        path.addLine(to: CGPoint(x: c.x - 78, y: c.y - 42))
        path.addLine(to: CGPoint(x: c.x - 54, y: c.y + 50))
        path.addLine(to: CGPoint(x: c.x + 64, y: c.y + 50))
        return path
    }
}

private struct IconsCartBasket: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let points: [CGPoint] = [
            CGPoint(x: c.x - 72, y: c.y - 20),
            CGPoint(x: c.x + 90, y: c.y - 20),
            CGPoint(x: c.x + 72, y: c.y + 34),
            CGPoint(x: c.x - 58, y: c.y + 34),
        ]
        return IconsPath.roundedPolygon(points) { index in index < 2 ? 7 : 13 }
    }
}

private struct IconsCartScene: View {
    let t: Double
    let count: Int
    let badge: Int
    let height: Double
    let squash: Double
    let pop: Double

    private static let ground: CGFloat = 80
    private static let slots: [CGPoint] = [CGPoint(x: -24, y: -22), CGPoint(x: 32, y: -20), CGPoint(x: 6, y: -42)]
    private static let colors: [[Color]] = [
        [Color(hex: 0xFF9A7A), Color(hex: 0xFF6048)],
        [Color(hex: 0xFFD466), Color(hex: 0xFFAA2B)],
        [Color(hex: 0x5BE3C0), Color(hex: 0x14B893)],
        [Color(hex: 0x6CD2FF), Color(hex: 0x2E9CF0)],
        [Color(hex: 0xFF8CBE), Color(hex: 0xF04E93)],
    ]

    /// When the falling parcel reaches its slot: a short hover, then a fall whose time grows with the height.
    static func landing(height: Double) -> Double {
        0.14 + 0.33 * (max(height, 1) / 100).squareRoot()
    }

    private var land: Double { Self.landing(height: height) }

    var body: some View {
        let since: Double = t - land
        let press: Double = squash * IconsCurve.ring(since, decay: 11, frequency: 30) * (since >= 0 ? 1 : 0)
        let roll: Double = 8 * IconsCurve.shake(since, decay: 5, frequency: 13)
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 150 * CGFloat(1 + press * 0.8), height: 14)
                .blur(radius: 7)
                .offset(x: CGFloat(roll), y: Self.ground + 2)
            ZStack {
                IconsCartFrame()
                    .stroke(Color.primary.opacity(0.82), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                parcels(since: since)
                basket
                wheel(roll: roll).offset(x: -40, y: 68)
                wheel(roll: roll).offset(x: 52, y: 68)
                badgeView(since: since).offset(x: 92, y: -40)
            }
            .frame(width: 250, height: 236)
            .scaleEffect(x: CGFloat(1 + press * 0.5), y: CGFloat(1 - press), anchor: UnitPoint(x: 0.5, y: 0.84))
            .offset(x: CGFloat(roll))
        }
    }

    // MARK: Layers

    private func parcels(since: Double) -> some View {
        let landed: Int = t >= land ? count : count - 1
        return ZStack {
            ForEach(0..<3, id: \.self) { slot in
                if let item = Self.latest(in: slot, landed: landed) {
                    // Parcels already in the basket hop when the new one lands (the new one does not).
                    let fresh: Bool = item == count - 1
                    let hop: Double = fresh ? 0 : 7 * IconsCurve.bump(IconsCurve.seg(since, 0.02 + 0.05 * Double(slot), 0.3 + 0.05 * Double(slot)))
                    parcel(item)
                        .rotationEffect(.degrees(Self.tilt(item)))
                        .offset(x: Self.slots[slot].x, y: Self.slots[slot].y - CGFloat(hop))
                }
            }
            falling
        }
    }

    private var falling: some View {
        let item: Int = count - 1
        let slot: CGPoint = Self.slots[((item % 3) + 3) % 3]
        let arrive: Double = IconsCurve.spring(t, response: 0.22, damping: 0.6)
        let fall: Double = IconsCurve.seg(t, 0.14, land)
        let drop: Double = fall * fall
        return parcel(item)
            .scaleEffect(CGFloat(max(arrive, 0)) * CGFloat(1 + 0.1 * fall), anchor: .center)
            .rotationEffect(.degrees(IconsCurve.mix(24, Self.tilt(item), drop)))
            .offset(x: slot.x, y: slot.y - CGFloat(height * (1 - drop)))
            .opacity(t < land ? 1 : 0)
    }

    private func parcel(_ item: Int) -> some View {
        let colors: [Color] = Self.colors[((item % Self.colors.count) + Self.colors.count) % Self.colors.count]
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return shape
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay {
                Rectangle()
                    .fill(.white.opacity(0.5))
                    .frame(width: 8)
            }
            .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
            .clipShape(shape)
            .frame(width: 38, height: 38)
            .shadow(color: colors[1].opacity(0.35), radius: 5, y: 3)
    }

    private var basket: some View {
        IconsCartBasket()
            .fill(Palette.primary)
            .overlay {
                // Wire lines of the basket.
                let wire = StrokeStyle(lineWidth: 3, lineCap: .round)
                ZStack {
                    IconsLine(from: UnitPoint(x: 0.33, y: 0.45), to: UnitPoint(x: 0.36, y: 0.61)).stroke(style: wire)
                    IconsLine(from: UnitPoint(x: 0.53, y: 0.45), to: UnitPoint(x: 0.53, y: 0.61)).stroke(style: wire)
                    IconsLine(from: UnitPoint(x: 0.74, y: 0.45), to: UnitPoint(x: 0.71, y: 0.61)).stroke(style: wire)
                }
                .foregroundStyle(.white.opacity(0.38))
            }
            .overlay {
                IconsCartBasket()
                    .fill(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0)], startPoint: .top, endPoint: .center))
            }
            .shadow(color: Palette.indigo.opacity(0.4), radius: 12, y: 7)
    }

    private func wheel(roll: Double) -> some View {
        ZStack {
            Circle().fill(Color.primary.opacity(0.85))
            Circle().fill(Color(uiColor: .systemBackground)).frame(width: 9, height: 9)
            Capsule()
                .fill(Color(uiColor: .systemBackground))
                .frame(width: 3, height: 8)
                .offset(y: -5)
        }
        .frame(width: 22, height: 22)
        .rotationEffect(.degrees(roll / 11 * 57.3))
    }

    private func badgeView(since: Double) -> some View {
        let kick: Double = pop * 1.3 * IconsCurve.shake(since - 0.04, decay: 9, frequency: 20)
        return Text(verbatim: "\(badge)")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText(value: Double(badge)))
            .frame(minWidth: 34, minHeight: 34)
            .padding(.horizontal, badge > 9 ? 5 : 0)
            .background(LinearGradient(colors: [Color(hex: 0xFF6B7A), Color(hex: 0xF0304A)], startPoint: .top, endPoint: .bottom), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 2.5))
            .shadow(color: Palette.red.opacity(0.45), radius: 7, y: 4)
            .scaleEffect(CGFloat(1 + kick))
            .offset(y: CGFloat(-10 * max(kick, 0)))
    }

    // MARK: Helpers

    /// The newest landed parcel resting in `slot`, if any.
    private static func latest(in slot: Int, landed: Int) -> Int? {
        var item: Int = landed - 1
        while item >= 0 {
            if item % 3 == slot { return item }
            item -= 1
        }
        return nil
    }

    private static func tilt(_ item: Int) -> Double {
        (IconsCurve.hash(item + 7) - 0.5) * 22
    }
}
