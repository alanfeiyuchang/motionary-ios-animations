import SwiftUI

extension Effect {
    static let morphFlyToCart = Effect(
        id: "morph.fly-to-cart",
        category: .morph,
        interaction: .tap,
        name: L("Fly to Cart", "飞入购物车"),
        summary: L(
            "The product photo peels off its tile and is tossed along an arc into the cart bar, which kicks back as its badge and total roll.",
            "商品图从卡片上揭起，沿弧线被抛进购物车栏，购物车被撞得一晃，角标和总价随之滚动。"
        ),
        prompt: L(
            "A 2 × 2 product grid above a floating cart bar. Tapping a tile dips it to 96% and launches a copy of its photo: it swells 8%, squares up, then is tossed along a quadratic arc that rises up to 70 pt before falling into the cart glyph (0.75 s, ease-in, so it lands fast), shrinking to 16%, rounding into a disc, tilting 24° and leaving two fading ghosts 6% and 12% behind it. On arrival the glyph jumps to 128% and tilts −14°, settling on a loose spring (response 0.3 s, damping 0.4); the bar swells 4%, a ring ripples out, the badge pops and both the count and the total roll up. The tile's plus turns into a green check for one second. Flights can overlap. Direct, playful, impossible to miss where the item went.",
            "2 × 2 商品网格下方悬着一条购物车栏。点一张卡片，它缩到 96%，并弹出商品图的副本：副本胀大 8%、收成方形，再沿二次曲线被抛出，最多上扬 70pt 后落进购物车图标（0.75 秒，缓入，落点最快），一路缩到 16%、变成圆片、倾斜 24°，拖着落后 6% 和 12% 的两道残影。到达瞬间图标跳到 128% 并歪 −14°，乘松弛的弹簧（响应 0.3 秒、阻尼 0.4）回正；整条栏胀大 4%，涟漪荡开，角标弹出，件数与总价一起向上滚动。卡片上的加号变成绿色对勾，停留一秒。多次飞行可以重叠，一眼看清东西去了哪儿。"
        ),
        implementation: L(
            "Each tap appends a flight view that owns its own progress; an Animatable wrapper evaluates a quadratic Bézier, the scale, corner radius and two trailing ghosts from that progress, and the animation's completion handler removes the flight and kicks the cart with separate springs.",
            "每次点击追加一个自带进度的飞行视图；Animatable 包装器按进度计算二次贝塞尔位置、缩放、圆角和两道拖尾残影，动画的完成回调移除飞行视图，并用独立弹簧撞动购物车。"
        ),
        apis: ["Animatable", "withAnimation(_:completion:)", "timingCurve", "contentTransition(.numericText)", "spring(response:dampingFraction:)"],
        tags: ["cart", "add to cart", "arc", "badge", "e-commerce", "购物车", "加入购物车", "抛物线", "角标"],
        params: [
            .slider("duration", L("Flight time", "飞行时长"), 0.4...1.4, default: 0.75, unit: "s"),
            .slider("arc", L("Arc height", "弧线高度"), 0...140, default: 70, decimals: 0, unit: "pt"),
            .slider("spin", L("Tilt", "倾斜角度"), 0...180, default: 24, decimals: 0, unit: "°"),
            .slider("shrink", L("End scale", "终点缩放"), 0.08...0.4, default: 0.16),
        ]
    ) { ctx in
        FlyToCartDemo(ctx: ctx)
    }
}

private struct CartProduct {
    let name: LocalizedText
    let price: Int
    let symbol: String
    let colors: [Color]
}

private let cartProducts: [CartProduct] = [
    CartProduct(name: L("Trail Runner", "越野跑鞋"), price: 129, symbol: "shoe.fill", colors: [Palette.amber, Palette.coral]),
    CartProduct(name: L("Studio Headset", "录音棚耳机"), price: 249, symbol: "headphones", colors: [Palette.sky, Palette.blue]),
    CartProduct(name: L("Day Pack", "日用背包"), price: 89, symbol: "backpack.fill", colors: [Palette.mint, Palette.green]),
    CartProduct(name: L("Field Camera", "旅行相机"), price: 599, symbol: "camera.fill", colors: [Palette.pink, Palette.violet]),
]

private enum CartLayout {
    static let size = CGSize(width: 316, height: 306)
    /// Centre of the cart glyph inside the bottom bar.
    static let cart = CGPoint(x: 40, y: 276)
    static let bar = CGRect(x: 12, y: 254, width: 292, height: 44)
    static let tile = CGSize(width: 141, height: 94)
    static let photo = CGSize(width: 141, height: 56)

    static func tileRect(_ index: Int) -> CGRect {
        let column = CGFloat(index % 2)
        let row = CGFloat(index / 2)
        return CGRect(x: 12 + column * (tile.width + 10), y: 48 + row * (tile.height + 8), width: tile.width, height: tile.height)
    }

    static func photoCenter(_ index: Int) -> CGPoint {
        let rect: CGRect = tileRect(index)
        return CGPoint(x: rect.midX, y: rect.minY + photo.height / 2)
    }
}

private struct CartFlightItem: Identifiable {
    let id: Int
    let product: Int
}

private struct FlyToCartDemo: View {
    let ctx: DemoContext
    @State private var flights: [CartFlightItem] = []
    @State private var nextID = 0
    @State private var count: Int
    @State private var total: Int
    @State private var cartScale: CGFloat = 1
    @State private var cartTilt: Double = 0
    @State private var badgeScale: CGFloat = 1
    @State private var ripple: CGFloat = 1
    @State private var added: [Int: Int] = [:]
    @State private var dipped: Int?
    @State private var autoIndex = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _count = State(initialValue: ctx.isStill ? 2 : 0)
        _total = State(initialValue: ctx.isStill ? 218 : 0)
    }

    var body: some View {
        VStack(spacing: 10) {
            screen
            DemoHint(text: L("Tap a product", "点击任意商品"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.15) { autoplayStep() }
    }

    private var screen: some View {
        ZStack(alignment: .topLeading) {
            Palette.surface
            Text(verbatim: ctx.language == .zh ? "新品" : "New in")
                .font(.system(size: 22, weight: .bold))
                .padding(.leading, 16)
                .frame(height: 46)
            ForEach(cartProducts.indices, id: \.self) { index in
                let rect: CGRect = CartLayout.tileRect(index)
                CartTile(product: cartProducts[index], added: added[index] != nil, language: ctx.language)
                    .scaleEffect(dipped == index ? 0.96 : 1)
                    .position(x: rect.midX, y: rect.midY)
                    .onTapGesture { add(index) }
            }
            cartBar
            if ctx.isStill {
                CartFlightBody(product: 2, t: 0.56, arc: ctx.cg("arc"), spin: ctx["spin"], shrink: ctx.cg("shrink"))
            }
            ForEach(flights) { flight in
                CartFlight(
                    product: flight.product,
                    duration: ctx["duration"],
                    arc: ctx.cg("arc"),
                    spin: ctx["spin"],
                    shrink: ctx.cg("shrink")
                ) {
                    arrive(flight.id)
                }
            }
        }
        .morphScreen()
    }

    private var cartBar: some View {
        let bar: CGRect = CartLayout.bar
        let zh: Bool = ctx.language == .zh
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 50)
                Text(verbatim: zh ? "查看购物车" : "View cart")
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
                Text(verbatim: "$\(total)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(total)))
                    .padding(.trailing, 16)
            }
            .foregroundStyle(.white)
            .frame(width: bar.width, height: bar.height)
            .background(Palette.primaryStrong, in: Capsule())
            .shadow(color: Palette.indigo.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(1 + (cartScale - 1) * 0.14)
            .position(x: bar.midX, y: bar.midY)
            Circle()
                .strokeBorder(Color.white, lineWidth: 2)
                .frame(width: 30 + 44 * ripple, height: 30 + 44 * ripple)
                .opacity(Double(0.7 * (1 - ripple)))
                .position(CartLayout.cart)
            Image(systemName: "cart.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.2), in: Circle())
                .overlay(alignment: .topTrailing) {
                    Text(verbatim: "\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(count)))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Palette.red, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                        .scaleEffect(count > 0 ? badgeScale : 0.01)
                        .opacity(count > 0 ? 1 : 0)
                        .offset(x: 7, y: -6)
                }
                .scaleEffect(cartScale)
                .rotationEffect(.degrees(cartTilt))
                .position(CartLayout.cart)
        }
        .frame(width: CartLayout.size.width, height: CartLayout.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    // MARK: Actions

    private func add(_ index: Int) {
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { dipped = index }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) { dipped = nil }
        flights.append(CartFlightItem(id: nextID, product: index))
        let stamp: Int = nextID
        nextID += 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { added[index] = stamp }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard added[index] == stamp else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { added[index] = nil }
        }
    }

    private func arrive(_ id: Int) {
        let price: Int = flights.first { $0.id == id }.map { cartProducts[$0.product].price } ?? 0
        flights.removeAll { $0.id == id }
        if !ctx.isPreview { Haptics.tap(.rigid) }
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) {
            cartScale = 1.28
            cartTilt = -14
            badgeScale = 1.5
            ripple = 0
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            cartScale = 1
            cartTilt = 0
            badgeScale = 1
            count += 1
            total += price
        }
        withAnimation(.easeOut(duration: 0.55)) { ripple = 1 }
    }

    private func autoplayStep() {
        if count >= 8 {
            withAnimation(.easeOut(duration: 0.2)) {
                count = 0
                total = 0
            }
        }
        let order: [Int] = [2, 1, 3, 0]
        add(order[autoIndex % order.count])
        autoIndex += 1
    }
}

/// One photo in flight; it owns its progress so flights overlap freely.
private struct CartFlight: View {
    let product: Int
    let duration: Double
    let arc: CGFloat
    let spin: Double
    let shrink: CGFloat
    let onArrive: () -> Void
    @State private var t: Double = 0

    var body: some View {
        MorphAnimated(t) { value in
            CartFlightBody(product: product, t: CGFloat(value), arc: arc, spin: spin, shrink: shrink)
        }
        .onAppear {
            withAnimation(.timingCurve(0.5, 0, 0.9, 0.62, duration: duration)) {
                t = 1
            } completion: {
                onArrive()
            }
        }
    }
}

private struct CartFlightBody: View {
    let product: Int
    let t: CGFloat
    let arc: CGFloat
    let spin: Double
    let shrink: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ghost(lag: 0.12, opacity: 0.16)
            ghost(lag: 0.06, opacity: 0.3)
            piece(at: t, opacity: Double(1 - MorphMath.smooth(t, 0.92, 1)), solid: true)
        }
        .frame(width: CartLayout.size.width, height: CartLayout.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func point(_ u: CGFloat) -> CGPoint {
        let start: CGPoint = CartLayout.photoCenter(product)
        let end: CGPoint = CartLayout.cart
        let lift: CGFloat = arc
        // A toss: up and over first, then down into the cart.
        let control = CGPoint(x: MorphMath.lerp(start.x, end.x, 0.45), y: max(start.y - lift, 20))
        let a: CGFloat = (1 - u) * (1 - u)
        let b: CGFloat = 2 * (1 - u) * u
        let c: CGFloat = u * u
        return CGPoint(x: a * start.x + b * control.x + c * end.x, y: a * start.y + b * control.y + c * end.y)
    }

    @ViewBuilder
    private func ghost(lag: CGFloat, opacity: Double) -> some View {
        let u: CGFloat = t - lag
        if u > 0.02, t < 0.98 {
            piece(at: u, opacity: opacity * Double(MorphMath.smooth(t, 0.05, 0.3)), solid: false)
        }
    }

    private func piece(at u: CGFloat, opacity: Double, solid: Bool) -> some View {
        let item: CartProduct = cartProducts[product]
        let square: CGFloat = MorphMath.smooth(u, 0, 0.35)
        let width: CGFloat = MorphMath.lerp(CartLayout.photo.width, CartLayout.photo.height, square)
        let height: CGFloat = CartLayout.photo.height
        let swell: CGFloat = 1 + 0.08 * sin(.pi * MorphMath.unit(u / 0.3))
        let scale: CGFloat = swell * MorphMath.lerp(1, shrink, pow(MorphMath.unit(u), 1.4))
        let radius: CGFloat = MorphMath.lerp(16, height / 2, MorphMath.smooth(u, 0.2, 0.9))
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let position: CGPoint = point(u)
        return shape
            .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                if solid {
                    Image(systemName: item.symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .overlay(shape.strokeBorder(Color.white.opacity(solid ? 0.5 : 0), lineWidth: 1.5))
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(solid ? 0.28 : 0), radius: 10, y: 8)
            .scaleEffect(scale)
            .rotationEffect(.degrees(spin * Double(MorphMath.smooth(u, 0.1, 1))))
            .opacity(opacity)
            .position(position)
    }
}

private struct CartTile: View {
    let product: CartProduct
    let added: Bool
    let language: AppLanguage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 0) {
            LinearGradient(colors: product.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: CartLayout.photo.height)
                .overlay {
                    Image(systemName: product.symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(product.name, language)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(verbatim: "$\(product.price)")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: added ? "checkmark" : "plus")
                    .font(.system(size: 12, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(added ? AnyShapeStyle(Palette.green) : AnyShapeStyle(Palette.primaryStrong), in: Circle())
                    .scaleEffect(added ? 1.12 : 1)
            }
            .padding(.horizontal, 10)
            .frame(height: CartLayout.tile.height - CartLayout.photo.height)
        }
        .frame(width: CartLayout.tile.width, height: CartLayout.tile.height)
        .background(Palette.elevated)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.stroke))
        .contentShape(shape)
    }
}
