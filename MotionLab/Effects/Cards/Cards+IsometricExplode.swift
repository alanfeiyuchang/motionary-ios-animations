import SwiftUI

extension Effect {
    static let cardsIsometricExplode = Effect(
        id: "cards.isometric-explode",
        category: .cards,
        interaction: .tap,
        name: L("Isometric Explode", "等距爆炸图"),
        summary: L("A map tile drawn in isometric view lifts apart into its four layers, each with a label, then stacks back down.", "一块等距视角的地图瓦片向上拆成四层，每层带着标注，再逐层落回原位。"),
        prompt: L(
            "Four 128 pt square slabs, drawn isometrically (rotated 45°, squashed to 56% height, 7 pt thick), sit stacked 11 pt apart so they read as one finished map tile: grid base, terrain, roads, pins. On tap they separate to 46 pt apart, top layer first with 60 ms between layers, each on a spring (response 0.55 s, damping 0.68) so it overshoots and settles. The stack slides 52 pt left while a leader line and a two-line label fade in beside each layer, sliding 8 pt into place. The shadow each slab drops on the one below grows softer and fainter with the gap, and the separated slabs drift ±2.5 pt out of phase. A second tap stacks them from the bottom up; each landing is a light tick. Dragging vertically scrubs the gap directly.",
            "四块128 pt见方的薄板以等距视角绘制（旋转45°、高度压到56%、厚7 pt），相距11 pt叠成一块完整的地图瓦片：网格底图、地形、道路、图钉。点击后它们拉开到相距46 pt，最上层先动，层间间隔60毫秒，各自以弹簧（响应0.55秒、阻尼0.68）过冲后停稳。整叠向左滑52 pt，每层旁边淡入一条引线和两行标注，并滑动8 pt到位。各层投在下一层的阴影随间距变柔变淡，分开的薄板以不同相位上下漂浮±2.5 pt。再次点击，它们自下而上逐层落回，每次落位一记轻触感。上下拖动可直接调节。"
        ),
        implementation: L(
            "Each slab is a flat square view under rotationEffect(45°) and a vertical scaleEffect, with offset copies beneath for its thickness. One 0…1 amount sets every layer's offset; a per-layer animation(_:value:) with a delay makes the stagger, and a TimelineView adds the idle drift.",
            "每块薄板都是一个平面正方形视图，经过 rotationEffect(45°) 和纵向 scaleEffect，下方叠加偏移副本表现厚度。一个0…1的量决定每层的偏移；逐层带延迟的 animation(_:value:) 形成错峰，TimelineView 负责空闲时的漂浮。"
        ),
        apis: ["rotationEffect", "scaleEffect", "animation(_:value:)", "TimelineView", "DragGesture", "Canvas"],
        tags: ["isometric", "exploded view", "layers", "stack", "等距", "爆炸图", "分层", "图层"],
        params: [
            .slider("gap", L("Layer gap", "层间距"), 28...58, default: 46, step: 1, decimals: 0, unit: "pt"),
            .slider("stagger", L("Stagger", "错峰间隔"), 0...0.16, default: 0.06, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.9, default: 0.55, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.68),
        ]
    ) { ctx in
        CardsIsoDemo(ctx: ctx)
    }
}

private enum CardsIsoLayout {
    static let side: CGFloat = 128
    static let squash: CGFloat = 0.56
    static let thickness = 7
    static let rest: CGFloat = 11
    static let count = 4
    /// Half the width of a slab on screen.
    static var reach: CGFloat { side * 0.7071 }
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }
}

private extension View {
    /// Lays a flat square down in isometric view.
    func cardsIsometric() -> some View {
        self
            .rotationEffect(.degrees(45))
            .scaleEffect(x: 1, y: CardsIsoLayout.squash)
    }
}

private struct CardsIsoDemo: View {
    let ctx: DemoContext
    /// 0 stacked, 1 fully apart.
    @State private var amount: CGFloat
    @State private var exploded: Bool
    @State private var dragStart: CGFloat?
    @State private var ticks: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _amount = State(initialValue: ctx.isStill ? 1 : 0)
        _exploded = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            stack
                .frame(width: 330, height: 288)
                .contentShape(Rectangle())
                .gesture(drag)
            DemoHint(text: L("Tap to explode, drag to scrub", "点击拆开，上下拖动调节"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.1) { toggle(haptic: false) }
        .onChange(of: pressing) { _, isPressing in
            guard !isPressing else { return }
            // onEnded can arrive just after the gesture state resets, so this fallback waits a tick:
            // by then only a cancelled touch still has something to clean up.
            Task { @MainActor in
                if dragStart != nil {
                    dragStart = nil
                    set(amount > 0.5, haptic: true)
                }
            }
        }
        .onDisappear { ticks?.cancel() }
    }

    private var stack: some View {
        let gap = CardsIsoLayout.rest + (ctx.cg("gap") - CardsIsoLayout.rest) * amount
        let spring = Animation.spring(response: ctx["response"], dampingFraction: ctx["damping"])
        return ZStack {
            ForEach(0..<CardsIsoLayout.count, id: \.self) { layer in
                // Exploding starts at the top; stacking starts at the bottom.
                let order = exploded ? CardsIsoLayout.count - 1 - layer : layer
                let delay = Double(order) * ctx["stagger"]
                CardsIsoLayer(layer: layer, gap: gap, amount: amount, drifting: !ctx.isStill, preview: ctx.isPreview, language: ctx.language)
                    .animation(spring.delay(delay), value: amount)
                    .zIndex(Double(layer))
            }
        }
        // The stack makes room for the labels.
        .offset(x: -52 * amount, y: 1.5 * gap + 10)
        .animation(spring, value: amount)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if dragStart == nil {
                    dragStart = amount
                    ticks?.cancel()
                }
                guard let start = dragStart, abs(value.translation.height) > 4 else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    amount = (start - value.translation.height / 130).clamped(to: -0.08...1.12)
                }
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                if hypot(value.translation.width, value.translation.height) < 8 {
                    toggle(haptic: true)
                    return
                }
                let projected = start - value.predictedEndTranslation.height / 130
                set(projected > 0.5, haptic: true)
            }
    }

    private func toggle(haptic: Bool) {
        set(!exploded, haptic: haptic)
    }

    private func set(_ value: Bool, haptic: Bool) {
        exploded = value
        amount = value ? 1 : 0
        ticks?.cancel()
        guard haptic, !ctx.isPreview else { return }
        if value {
            Haptics.tap(.medium)
            return
        }
        let stagger = ctx["stagger"]
        let landing = ctx["response"] * 0.55
        ticks = Task { @MainActor in
            // One tick as each of the three upper slabs lands.
            try? await Task.sleep(for: .seconds(landing))
            for _ in 1..<CardsIsoLayout.count {
                guard !Task.isCancelled else { return }
                Haptics.tap(.light)
                try? await Task.sleep(for: .seconds(max(stagger, 0.03)))
            }
        }
    }
}

/// One slab with the shadow it casts on the slab below and its label.
private struct CardsIsoLayer: View {
    let layer: Int
    let gap: CGFloat
    let amount: CGFloat
    let drifting: Bool
    let preview: Bool
    let language: AppLanguage

    private static let labels: [(LocalizedText, LocalizedText)] = [
        (L("Base", "底图"), L("Grid & land", "网格与陆地")),
        (L("Terrain", "地形"), L("Parks & water", "绿地与水域")),
        (L("Roads", "道路"), L("Streets & route", "街道与路线")),
        (L("Pins", "图钉"), L("Places & names", "地点与名称")),
    ]

    var body: some View {
        let shown = Double(amount.clamped(to: 0...1))
        ZStack {
            if layer > 0 {
                // Shadow on the slab below: softer and fainter as the gap opens.
                CardsIsoLayout.shape
                    .fill(Color.black)
                    .frame(width: CardsIsoLayout.side, height: CardsIsoLayout.side)
                    .cardsIsometric()
                    .blur(radius: 3 + 9 * CGFloat(shown))
                    .opacity(0.4 - 0.18 * shown)
                    .offset(y: gap - CGFloat(CardsIsoLayout.thickness) + 2)
            } else {
                CardsIsoLayout.shape
                    .fill(Color.black)
                    .frame(width: CardsIsoLayout.side, height: CardsIsoLayout.side)
                    .cardsIsometric()
                    .blur(radius: 12)
                    .opacity(0.3)
                    .offset(y: 18)
            }
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !drifting || amount < 0.02)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let drift: CGFloat = drifting ? 2.5 * amount * CGFloat(sin(t * 1.5 + Double(layer) * 1.4)) : 0
                ZStack {
                    CardsIsoSlab(kind: layer)
                    label
                        .opacity(shown)
                        .offset(x: CardsIsoLayout.reach + 6 + 8 * CGFloat(1 - shown))
                }
                .offset(y: layer == 0 ? 0 : drift)
            }
        }
        .offset(y: -CGFloat(layer) * gap)
    }

    private var label: some View {
        let text = Self.labels[layer % Self.labels.count]
        return HStack(spacing: 6) {
            Circle()
                .fill(Color.primary.opacity(0.55))
                .frame(width: 4, height: 4)
            Rectangle()
                .fill(Color.primary.opacity(0.3))
                .frame(width: 14, height: 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(text.0, language)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(text.1, language)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
        }
        .frame(width: 130, alignment: .leading)
        .offset(x: 65)
    }
}

/// A slab seen isometrically: its top face over offset copies that read as thickness.
private struct CardsIsoSlab: View {
    let kind: Int

    private var solid: Bool { kind == 0 }

    var body: some View {
        ZStack {
            ForEach(0..<CardsIsoLayout.thickness, id: \.self) { step in
                CardsIsoLayout.shape
                    .fill(solid ? Color(hex: 0x141A2E) : Color(hex: 0x566080).opacity(0.55))
                    .frame(width: CardsIsoLayout.side, height: CardsIsoLayout.side)
                    .cardsIsometric()
                    .offset(y: CGFloat(CardsIsoLayout.thickness - step))
            }
            face
                .frame(width: CardsIsoLayout.side, height: CardsIsoLayout.side)
                .clipShape(CardsIsoLayout.shape)
                .overlay(CardsIsoLayout.shape.strokeBorder(Color.white.opacity(solid ? 0.3 : 0.42), lineWidth: 1))
                .cardsIsometric()
        }
    }

    @ViewBuilder
    private var face: some View {
        switch kind {
        case 0: base
        case 1: terrain
        case 2: roads
        default: pins
        }
    }

    /// Smoked acrylic: the upper slabs let the ones below show through.
    private var glass: some View {
        ZStack {
            Color(hex: 0x2A3350).opacity(0.5)
            LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0)], startPoint: .topLeading, endPoint: .center)
        }
    }

    private var base: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x34416A), Color(hex: 0x222B48)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                var path = Path()
                var offset: CGFloat = 16
                while offset < size.width {
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset, y: size.height))
                    path.move(to: CGPoint(x: 0, y: offset))
                    path.addLine(to: CGPoint(x: size.width, y: offset))
                    offset += 16
                }
                context.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: 0.8)
            }
        }
    }

    private var terrain: some View {
        ZStack {
            glass
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0x3DDC97).opacity(0.9))
                .frame(width: 50, height: 44)
                .offset(x: -26, y: -28)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: 0x3DDC97).opacity(0.7))
                .frame(width: 34, height: 26)
                .offset(x: 34, y: 36)
            Capsule()
                .fill(Color(hex: 0x3AC4FF).opacity(0.9))
                .frame(width: 190, height: 20)
                .rotationEffect(.degrees(-24))
                .offset(x: 4, y: 14)
        }
    }

    private var roads: some View {
        ZStack {
            glass
            Canvas { context, size in
                var streets = Path()
                streets.move(to: CGPoint(x: 0, y: size.height * 0.3))
                streets.addLine(to: CGPoint(x: size.width, y: size.height * 0.3))
                streets.move(to: CGPoint(x: size.width * 0.62, y: 0))
                streets.addLine(to: CGPoint(x: size.width * 0.62, y: size.height))
                streets.move(to: CGPoint(x: 0, y: size.height * 0.78))
                streets.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.78))
                context.stroke(streets, with: .color(.white.opacity(0.92)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                var lane = Path()
                lane.move(to: CGPoint(x: size.width * 0.26, y: 0))
                lane.addLine(to: CGPoint(x: size.width * 0.26, y: size.height * 0.78))
                context.stroke(lane, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                var route = Path()
                route.move(to: CGPoint(x: size.width * 0.26, y: size.height * 0.78))
                route.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.78))
                route.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.3))
                route.addLine(to: CGPoint(x: size.width * 0.88, y: size.height * 0.3))
                context.stroke(route, with: .color(Color(hex: 0xFF8A3C)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private var pins: some View {
        ZStack {
            glass
            pin(Color(hex: 0xFF5F6D))
                .offset(x: -30, y: 36)
            pin(Color(hex: 0x6E7BFF))
                .offset(x: 48, y: -26)
            Capsule()
                .fill(Color.white.opacity(0.92))
                .frame(width: 40, height: 9)
                .offset(x: -26, y: -32)
            Capsule()
                .fill(Color.white.opacity(0.6))
                .frame(width: 28, height: 7)
                .offset(x: 30, y: 38)
        }
    }

    private func pin(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(Circle().fill(Color.white).frame(width: 7, height: 7))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
            .shadow(color: color.opacity(0.8), radius: 6)
    }
}
