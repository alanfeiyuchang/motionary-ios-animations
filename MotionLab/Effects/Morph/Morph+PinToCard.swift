import SwiftUI

extension Effect {
    static let morphPinToCard = Effect(
        id: "morph.pin-to-card",
        category: .morph,
        interaction: .tap,
        name: L("Pin to Place Card", "地图图钉变卡片"),
        summary: L(
            "A map pin lifts off the ground and its head unrolls into a place card while the map glides under it; closing drops the pin back with a bounce.",
            "地图图钉先离地抬起，钉头再铺展成地点卡片，地图在它身下滑动；关闭时图钉落回原位并弹一下。"
        ),
        prompt: L(
            "A stylised map with three coloured teardrop pins. Tapping a pin first lifts it 14 pt on a quick springy pop (response 0.26 s, damping 0.6) as its ground shadow spreads; 160 ms later the 34 pt head unrolls into a 292 × 128 pt place card docked at the bottom on a spring (response 0.5 s, damping 0.8): the head's frame and corner radius interpolate, its colour drains to the card surface, the tail retracts, and the photo tile, name, rating and buttons surface in sequence. The map pans so the pin's spot sits above the card, blurs 2.5 pt and dims; the other pins shrink. Closing reverses the morph in mid-air, then the pin drops on a loose spring (damping 0.42), bouncing as a ring ripples from its tip.",
            "简化地图上立着三枚彩色水滴图钉。点一枚，它先以轻快的弹跳（响应 0.26 秒、阻尼 0.6）抬离地面 14pt，地面投影随之散开；160 毫秒后，34pt 的钉头乘弹簧（响应 0.5 秒、阻尼 0.8）铺展成停靠在底部的 292 × 128pt 地点卡片：钉头的外框与圆角连续插值，颜色褪成卡片底色，钉尾收起，照片块、店名、评分和按钮依次浮现。地图平移，让图钉原位停在卡片上方，并模糊 2.5pt、压暗，其余图钉缩小。关闭时卡片在半空变回图钉，再乘松弛的弹簧（阻尼 0.42）落下、回弹，钉尖处荡开一圈涟漪。"
        ),
        implementation: L(
            "An Animatable wrapper interpolates the morph progress and the lift; each frame the body rect is a lerp between the pin head and the card rect, with the tail, glyph and card content keyed to sub-ranges of the progress. The map is a Canvas offset by the same progress, and tasks sequence lift → morph and morph → drop.",
            "Animatable 包装器对形变进度与抬起量做插值；每帧把主体矩形在钉头与卡片矩形之间插值，钉尾、图标和卡片内容各自对应进度的一段区间。地图是按同一进度偏移的 Canvas，任务负责串联「抬起 → 形变」与「形变 → 落下」。"
        ),
        apis: ["Animatable", "AnimatablePair", "Canvas", "spring(response:dampingFraction:)", "Task.sleep"],
        tags: ["map", "pin", "place card", "annotation", "地图", "图钉", "地点卡片", "标注"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("lift", L("Lift height", "抬起高度"), 0...30, default: 14, decimals: 0, unit: "pt"),
            .slider("blur", L("Map blur", "地图模糊"), 0...6, default: 2.5, decimals: 1, unit: "pt"),
        ]
    ) { ctx in
        PinToCardDemo(ctx: ctx)
    }
}

private struct PinPlace {
    let name: LocalizedText
    let kind: LocalizedText
    let distance: LocalizedText
    let symbol: String
    let color: Color
    let rating: String
    let reviews: String
    /// Where the pin's tip touches the map.
    let spot: CGPoint
}

private let pinPlaces: [PinPlace] = [
    PinPlace(
        name: L("Fern & Flour", "蕨与麦"), kind: L("Bakery · Café", "烘焙 · 咖啡"), distance: L("350 m", "350 米"),
        symbol: "cup.and.saucer.fill", color: Palette.coral, rating: "4.8", reviews: "1,204", spot: CGPoint(x: 92, y: 106)
    ),
    PinPlace(
        name: L("Harbor Books", "海港书店"), kind: L("Bookshop", "独立书店"), distance: L("600 m", "600 米"),
        symbol: "books.vertical.fill", color: Palette.indigo, rating: "4.6", reviews: "382", spot: CGPoint(x: 232, y: 142)
    ),
    PinPlace(
        name: L("Kite Hill Park", "风筝山公园"), kind: L("Park · Viewpoint", "公园 · 观景点"), distance: L("1.2 km", "1.2 公里"),
        symbol: "tree.fill", color: Palette.green, rating: "4.9", reviews: "2,671", spot: CGPoint(x: 150, y: 222)
    ),
]

private enum PinLayout {
    static let size = CGSize(width: 316, height: 308)
    static let card = CGRect(x: 12, y: 170, width: 292, height: 128)
    static let head: CGFloat = 34
    /// Head centre above the tip.
    static let stem: CGFloat = 30
    /// Where the selected pin's tip is brought to while its card is open.
    static let focus = CGPoint(x: 158, y: 120)
}

private struct PinToCardDemo: View {
    let ctx: DemoContext
    @State private var selected: Int
    @State private var progress: Double
    @State private var lift: Double = 0
    @State private var ripple: Double = 1
    @State private var autoIndex = 0
    @State private var task: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _selected = State(initialValue: 0)
        _progress = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var isOpen: Bool { progress > 0.5 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        VStack(spacing: 10) {
            MorphAnimated(AnimatablePair(progress, lift)) { value in
                PinScene(
                    progress: CGFloat(value.first),
                    lift: CGFloat(value.second),
                    ripple: CGFloat(ripple),
                    selected: selected,
                    liftHeight: ctx.cg("lift"),
                    blur: ctx.cg("blur"),
                    language: ctx.language,
                    onOpen: open,
                    onClose: close
                )
            }
            .frame(width: PinLayout.size.width, height: PinLayout.size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.stroke))
            DemoHint(
                text: isOpen ? L("Tap the map to close", "点击地图关闭") : L("Tap a pin", "点击图钉"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.1) { autoStep() }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func autoStep() {
        if isOpen {
            close()
        } else {
            open(autoIndex % pinPlaces.count)
            autoIndex += 1
        }
    }

    /// Lift first, then unroll into the card.
    private func open(_ index: Int) {
        guard !isOpen else { return }
        task?.cancel()
        let preview: Bool = ctx.isPreview
        if !preview { Haptics.tap(.light) }
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) {
            selected = index
            ripple = 1
        }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.6)) { lift = 1 }
        let morph: Animation = .spring(response: ctx["response"], dampingFraction: ctx["damping"])
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            if !preview { Haptics.tap(.medium) }
            withAnimation(morph) {
                progress = 1
                lift = 0
            }
        }
    }

    /// Fold back into a pin held in the air, then let it drop.
    private func close() {
        guard isOpen else { return }
        task?.cancel()
        let preview: Bool = ctx.isPreview
        let response: Double = ctx["response"]
        withAnimation(.spring(response: response, dampingFraction: 0.9)) {
            progress = 0
            lift = 1
        }
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(response * 0.6))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) { lift = 0 }
            try? await Task.sleep(for: .seconds(0.11))
            guard !Task.isCancelled else { return }
            if !preview { Haptics.tap(.rigid) }
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { ripple = 0 }
            withAnimation(.easeOut(duration: 0.7)) { ripple = 1 }
        }
    }
}

private struct PinScene: View {
    let progress: CGFloat
    let lift: CGFloat
    let ripple: CGFloat
    let selected: Int
    let liftHeight: CGFloat
    let blur: CGFloat
    let language: AppLanguage
    let onOpen: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        let open: CGFloat = MorphMath.unit(progress)
        let place: PinPlace = pinPlaces[selected]
        let shift = CGSize(
            width: (PinLayout.focus.x - place.spot.x) * progress,
            height: (PinLayout.focus.y - place.spot.y) * progress
        )
        ZStack {
            PinMap()
                .frame(width: 620, height: 640)
                .offset(shift)
                .blur(radius: blur * open)
                .frame(width: PinLayout.size.width, height: PinLayout.size.height)
                .overlay(Color.black.opacity(0.14 * Double(open)))
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
            PinUserDot()
                .position(x: 204 + shift.width, y: 76 + shift.height)
                .opacity(Double(1 - 0.5 * open))
            ForEach(pinPlaces.indices, id: \.self) { index in
                if index != selected {
                    idlePin(index, shift: shift, open: open)
                }
            }
            ground(place: place, shift: shift, open: open)
            morphBody(place: place, shift: shift, open: open)
        }
        .frame(width: PinLayout.size.width, height: PinLayout.size.height)
    }

    private func idlePin(_ index: Int, shift: CGSize, open: CGFloat) -> some View {
        let place: PinPlace = pinPlaces[index]
        return PinMarker(place: place)
            .scaleEffect(1 - 0.22 * open, anchor: .bottom)
            .opacity(Double(1 - 0.45 * open))
            .contentShape(Rectangle())
            .onTapGesture {
                if progress > 0.5 { onClose() } else { onOpen(index) }
            }
            .position(x: place.spot.x + shift.width, y: place.spot.y + shift.height - PinMarker.height / 2)
    }

    /// Contact shadow and landing ripple at the pin's tip.
    private func ground(place: PinPlace, shift: CGSize, open: CGFloat) -> some View {
        let tip = CGPoint(x: place.spot.x + shift.width, y: place.spot.y + shift.height)
        let airborne: CGFloat = MorphMath.unit(lift)
        return ZStack {
            Ellipse()
                .fill(Color.black.opacity(Double((0.32 - 0.16 * airborne) * (1 - open))))
                .frame(width: 16 + 12 * airborne, height: 6 + 3 * airborne)
                .blur(radius: 1.5 + 2 * airborne)
            Ellipse()
                .strokeBorder(place.color, lineWidth: 2)
                .frame(width: 18 + 62 * ripple, height: (18 + 62 * ripple) * 0.46)
                .opacity(Double(0.7 * (1 - ripple)))
        }
        .position(tip)
        .allowsHitTesting(false)
    }

    private func morphBody(place: PinPlace, shift: CGSize, open: CGFloat) -> some View {
        let raise: CGFloat = liftHeight * lift
        let headCenter = CGPoint(
            x: place.spot.x + shift.width,
            y: place.spot.y + shift.height - PinLayout.stem - raise
        )
        let headRect: CGRect = MorphMath.rect(center: headCenter, size: CGSize(width: PinLayout.head, height: PinLayout.head))
        let rect: CGRect = MorphMath.lerp(headRect, PinLayout.card, progress)
        let radius: CGFloat = min(MorphMath.lerp(PinLayout.head / 2, 26, open), min(rect.width, rect.height) / 2)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let tint: CGFloat = 1 - MorphMath.smooth(progress, 0.12, 0.6)
        let tail: CGFloat = 1 - MorphMath.smooth(progress, 0, 0.32)
        return ZStack {
            PinTail()
                .fill(place.color)
                .frame(width: 20, height: 20)
                .scaleEffect(tail, anchor: .top)
                .opacity(Double(tail))
                .position(x: rect.midX, y: rect.maxY + 5)
            ZStack {
                shape.fill(Palette.elevated)
                shape.fill(LinearGradient(colors: [place.color.opacity(0.85), place.color], startPoint: .top, endPoint: .bottom))
                    .opacity(Double(tint))
                PinCardContent(place: place, progress: progress, language: language, onClose: onClose)
                    .frame(width: PinLayout.card.width, height: PinLayout.card.height)
                    .scaleEffect(0.86 + 0.14 * open)
                    .frame(width: rect.width, height: rect.height)
                Image(systemName: place.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(1 + 0.8 * MorphMath.unit(progress * 2))
                    .opacity(Double(1 - MorphMath.smooth(progress, 0.05, 0.3)))
            }
            .frame(width: rect.width, height: rect.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.5 * Double(tint)), lineWidth: 1.5))
            .overlay(shape.strokeBorder(Palette.stroke.opacity(Double(open))))
            .shadow(color: .black.opacity(0.22), radius: 4 + 18 * open + 4 * lift, y: 2 + 10 * open + 4 * lift)
            .contentShape(Rectangle())
            .onTapGesture {
                if progress < 0.5 { onOpen(selected) }
            }
            .position(x: rect.midX, y: rect.midY)
        }
    }
}

/// The little triangle under the pin head, with a softly rounded tip.
private struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX + 1.5, y: rect.maxY - 2), control: CGPoint(x: rect.midX + 5, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX - 1.5, y: rect.maxY - 2), control: CGPoint(x: rect.midX, y: rect.maxY + 1))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX - 5, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// A resting pin: head, tail and glyph, with its tip at the bottom centre of the frame.
private struct PinMarker: View {
    static let height: CGFloat = PinLayout.stem + PinLayout.head / 2
    let place: PinPlace

    var body: some View {
        ZStack(alignment: .top) {
            PinTail()
                .fill(place.color)
                .frame(width: 20, height: 20)
                .offset(y: PinLayout.head - 8)
            Circle()
                .fill(LinearGradient(colors: [place.color.opacity(0.85), place.color], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
                .frame(width: PinLayout.head, height: PinLayout.head)
                .overlay {
                    Image(systemName: place.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
        .frame(width: PinLayout.head, height: PinMarker.height, alignment: .top)
        .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
        .background(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(0.32))
                .frame(width: 16, height: 6)
                .blur(radius: 1.5)
                .offset(y: 3)
        }
    }
}

private struct PinCardContent: View {
    let place: PinPlace
    let progress: CGFloat
    let language: AppLanguage
    let onClose: () -> Void

    private func alpha(_ step: Int) -> Double {
        let start: CGFloat = 0.4 + 0.1 * CGFloat(step)
        return Double(MorphMath.smooth(progress, start, start + 0.28))
    }

    private func rise(_ step: Int) -> CGFloat {
        CGFloat(1 - alpha(step)) * 12
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [place.color.opacity(0.75), place.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: place.symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 88, height: 100)
                .opacity(alpha(0))
                .scaleEffect(0.9 + 0.1 * alpha(0))
            VStack(alignment: .leading, spacing: 5) {
                Text(place.name, language)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .opacity(alpha(1))
                    .offset(y: rise(1))
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Palette.amber)
                    Text(verbatim: place.rating)
                        .fontWeight(.semibold)
                    Text(verbatim: "(\(place.reviews))")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
                .opacity(alpha(2))
                .offset(y: rise(2))
                Text(verbatim: place.kind(language) + " · " + place.distance(language))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(alpha(2))
                    .offset(y: rise(2))
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text(verbatim: language == .zh ? "路线" : "Directions")
                            .fixedSize()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Palette.blue, in: Capsule())
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.blue)
                        .frame(width: 32, height: 32)
                        .background(Palette.blue.opacity(0.14), in: Circle())
                }
                .padding(.top, 3)
                .opacity(alpha(3))
                .offset(y: rise(3))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .padding(14)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.08), in: Circle())
                .contentShape(Circle())
                .onTapGesture(perform: onClose)
                .padding(10)
                .opacity(alpha(3))
        }
    }
}

/// "You are here": a blue dot with a slow pulsing halo.
private struct PinUserDot: View {
    var body: some View {
        ZStack {
            // Time-driven rather than phaseAnimator: an implicit animation here would also catch the dot's
            // position while the map pans, and the halo would trail behind it.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let wave: Double = (sin(timeline.date.timeIntervalSinceReferenceDate * 2.2) + 1) / 2
                Circle()
                    .fill(Palette.blue.opacity(0.25))
                    .frame(width: 34, height: 34)
                    .scaleEffect(0.5 + 0.5 * wave)
                    .opacity(1 - 0.65 * wave)
            }
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            Circle()
                .fill(Palette.blue)
                .frame(width: 11, height: 11)
        }
        .allowsHitTesting(false)
    }
}

/// A drawn city map: tilted street grid, an avenue, a river and two parks. Larger than the stage so it can pan.
private struct PinMap: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark: Bool = colorScheme == .dark
        let land: Color = dark ? Color(hex: 0x22262C) : Color(hex: 0xECE8DF)
        let block: Color = dark ? Color(hex: 0x282D34) : Color(hex: 0xE3DED3)
        let road: Color = dark ? Color(hex: 0x3A4048) : Color.white
        let avenue: Color = dark ? Color(hex: 0x5C4D26) : Color(hex: 0xFFE49B)
        let water: Color = dark ? Color(hex: 0x17364E) : Color(hex: 0xA8D3F2)
        let park: Color = dark ? Color(hex: 0x224430) : Color(hex: 0xBFE3B2)
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(land))
            // Work in stage coordinates: the stage sits centred in this larger canvas.
            context.translateBy(x: (size.width - PinLayout.size.width) / 2, y: (size.height - PinLayout.size.height) / 2)

            var river = Path()
            river.move(to: CGPoint(x: -160, y: 250))
            river.addCurve(to: CGPoint(x: 120, y: 330), control1: CGPoint(x: -60, y: 230), control2: CGPoint(x: 40, y: 330))
            river.addCurve(to: CGPoint(x: 480, y: 300), control1: CGPoint(x: 240, y: 330), control2: CGPoint(x: 360, y: 250))
            river.addLine(to: CGPoint(x: 480, y: 520))
            river.addLine(to: CGPoint(x: -160, y: 520))
            river.closeSubpath()
            context.fill(river, with: .color(water))

            context.rotate(by: .degrees(-11))
            for column in -3..<8 {
                for row in -3..<7 where (column + row * 3) % 4 == 0 {
                    let rect = CGRect(x: CGFloat(column) * 78 + 12, y: CGFloat(row) * 64 + 10, width: 54, height: 44)
                    context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(block))
                }
            }
            context.fill(Path(roundedRect: CGRect(x: 60, y: 200, width: 136, height: 58), cornerRadius: 16), with: .color(park))
            context.fill(Path(roundedRect: CGRect(x: 250, y: 20, width: 60, height: 108), cornerRadius: 16), with: .color(park))

            var streets = Path()
            for row in -3..<8 {
                let y: CGFloat = CGFloat(row) * 64
                streets.move(to: CGPoint(x: -300, y: y))
                streets.addLine(to: CGPoint(x: 700, y: y))
            }
            for column in -3..<9 {
                let x: CGFloat = CGFloat(column) * 78
                streets.move(to: CGPoint(x: x, y: -300))
                streets.addLine(to: CGPoint(x: x, y: 240))
            }
            context.stroke(streets, with: .color(road), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            var main = Path()
            main.move(to: CGPoint(x: -300, y: 180))
            main.addCurve(to: CGPoint(x: 700, y: 60), control1: CGPoint(x: 60, y: 200), control2: CGPoint(x: 300, y: 40))
            context.stroke(main, with: .color(avenue), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        }
    }
}
