import SwiftUI

extension Effect {
    static let scrollSpiralList = Effect(
        id: "scroll.spiral-list",
        category: .scroll,
        interaction: .scroll,
        name: L("Spiral List", "螺旋列表"),
        summary: L("Items sit on a logarithmic spiral: scrolling winds them outward one by one into the focus ring while the rest shrink into the eye.", "条目排在一条对数螺旋线上：滚动时它们一个接一个旋出来，落进焦点环，其余的越缩越小，消失在螺旋中心。"),
        prompt: L(
            "Twenty-four round items laid out on a logarithmic spiral like a nautilus shell. The focused item sits at the bottom of the spiral in a ring, at full 62 pt size; each following item is placed 50° further around and 11% smaller and closer to the centre, so the tail winds inward and vanishes into the eye. Vertical scrolling moves every item along the curve: the next one swings out, growing, and clicks into the ring (snap per item, selection haptic), while the one that leaves keeps travelling outward along the same curve, swells to 125% and fades within about one step. Size and radius use the same exponential, so the spiral looks identical at every scroll position. A faint dashed line traces the curve and a corner label rolls the index and cross-fades the title. Tapping any item scrolls it into focus in 0.6 s.",
            "二十四个圆形条目排在一条对数螺旋线上。焦点条目位于螺旋最下方的圆环里，是完整的 62 pt；之后每个条目沿曲线再转 50°、缩小 11% 并向中心靠近，尾巴一圈圈卷进螺旋中心消失。纵向滚动让所有条目沿曲线移动：下一个一边变大一边旋出来，落进圆环（逐项吸附，伴随选择触感）；离开的那个继续沿曲线向外，放大到 125% 并在一个身位内淡出。大小和半径用同一个指数，螺旋在任何位置看起来都一样。淡淡的虚线描出曲线，大的压在小的上面，角落的标签滚动显示序号。点击任意条目，它在 0.6 秒内滚到焦点。"
        ),
        implementation: L(
            "An empty snapping ScrollView supplies the physics; its offset divided by the item pitch is a continuous position. Behind it each item is placed from u = index − position: angle = 90° + u·twist, radius and scale = e^(−k·u), with zIndex = −u. A tap is hit-tested against the same positions.",
            "一个空的、带吸附的 ScrollView 只负责提供滚动物理；它的偏移量除以条目间距得到一个连续的位置。它背后的每个条目由 u = 序号 − 位置 来摆放：角度 = 90° + u·扭转角，半径与缩放 = e^(−k·u)，zIndex = −u。点击则用同一套位置做命中测试。"
        ),
        apis: ["ScrollTargetBehavior", "onScrollGeometryChange", "ScrollPosition", "zIndex", "Path", "SpatialTapGesture"],
        tags: ["spiral", "nautilus", "wheel", "picker", "logarithmic", "螺旋", "鹦鹉螺", "滚轮", "选择器", "对数螺旋"],
        params: [
            .slider("twist", L("Angle per item", "每项转角"), 30...80, default: 50, step: 1, decimals: 0, unit: "°"),
            .slider("shrink", L("Shrink rate", "收缩速率"), 0.08...0.3, default: 0.12),
            .toggle("guide", L("Show the curve", "显示曲线"), default: true),
        ]
    ) { ctx in
        ScrollSpiralDemo(ctx: ctx)
    }
}

private let scrollSpiralCount = 24
/// Scroll distance per item.
private let scrollSpiralPitch: CGFloat = 64
private let scrollSpiralRadius: CGFloat = 116
private let scrollSpiralItem: CGFloat = 62

/// Where an item sits for `u` = its index minus the scroll position (0 = in the focus ring).
private struct ScrollSpiralPlacement {
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let opacity: Double

    init(u: CGFloat, twist: CGFloat, shrink: CGFloat) {
        // Ahead of the focus the curve shrinks exponentially; behind it the item keeps going outward.
        let s: CGFloat = u >= 0 ? CGFloat(exp(-Double(shrink * u))) : 1 + (-u) * 0.25
        let angle: CGFloat = (90 + u * twist) * .pi / 180
        x = scrollSpiralRadius * s * cos(angle)
        y = scrollSpiralRadius * s * sin(angle)
        scale = s
        let leaving: CGFloat = ScrollMath.unit(-u, 0.15, 1.2)
        let vanishing: CGFloat = ScrollMath.unit(s, 0.05, 0.16)
        opacity = Double((1 - leaving) * vanishing)
    }
}

private struct ScrollSpiralDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var viewport = CGSize(width: 340, height: 340)
    @State private var position = ScrollPosition(edge: .top)
    @State private var selected = 0
    @State private var userDriven = false
    @State private var direction = 1

    /// Centre of the spiral in the stage.
    private var centre: CGPoint { CGPoint(x: viewport.width / 2, y: viewport.height / 2 - 6) }

    var body: some View {
        let p: CGFloat = offset / scrollSpiralPitch
        return ZStack(alignment: .topLeading) {
            ScrollSpiralField(
                position: p,
                twist: ctx.cg("twist"),
                shrink: ctx.cg("shrink"),
                guide: ctx.bool("guide"),
                centre: centre
            )
            ScrollSpiralLabel(index: selected, language: ctx.language)
                .padding(14)
            driver
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onChange(of: selected) {
            if !ctx.isPreview && userDriven { Haptics.selection() }
        }
        .autoplay(ctx.isPreview, every: 1.6) { autoStep() }
    }

    /// An empty scroll view: it only supplies native scrolling, snapping and inertia.
    private var driver: some View {
        ScrollView {
            Color.clear
                .frame(height: CGFloat(scrollSpiralCount - 1) * scrollSpiralPitch + viewport.height)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(ScrollStrideSnap(pitch: scrollSpiralPitch, axis: .vertical))
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGRect.self, of: { geometry in
            CGRect(origin: CGPoint(x: 0, y: geometry.contentOffset.y + geometry.contentInsets.top), size: geometry.containerSize)
        }, action: { _, newValue in
            offset = newValue.origin.y
            if newValue.height > 0 { viewport = newValue.size }
            let nearest = Int((newValue.origin.y / scrollSpiralPitch).rounded()).clamped(to: 0...(scrollSpiralCount - 1))
            if nearest != selected {
                withAnimation(.snappy(duration: 0.25)) { selected = nearest }
            }
        })
        .onScrollPhaseChange { _, newPhase in
            userDriven = newPhase == .interacting || newPhase == .decelerating || newPhase == .tracking
        }
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .local).onEnded { value in
                if let index = item(at: value.location) { focus(index, duration: 0.6) }
            }
        )
    }

    /// The front-most item under a tap, using the same placement as the drawing.
    private func item(at point: CGPoint) -> Int? {
        let p: CGFloat = offset / scrollSpiralPitch
        let first = max(Int(p.rounded(.down)) - 1, 0)
        for i in first..<scrollSpiralCount {
            let place = ScrollSpiralPlacement(u: CGFloat(i) - p, twist: ctx.cg("twist"), shrink: ctx.cg("shrink"))
            guard place.opacity > 0.3 else { continue }
            let dx: CGFloat = point.x - (centre.x + place.x)
            let dy: CGFloat = point.y - (centre.y + place.y)
            // A little slack so the small ones near the eye can still be hit.
            if hypot(dx, dy) <= max(scrollSpiralItem * place.scale / 2, 14) { return i }
        }
        return nil
    }

    private func focus(_ index: Int, duration: Double) {
        let target = index.clamped(to: 0...(scrollSpiralCount - 1))
        withAnimation(.easeInOut(duration: duration)) {
            position.scrollTo(y: CGFloat(target) * scrollSpiralPitch)
        }
    }

    private func autoStep() {
        let stride = 3
        if selected + direction * stride > scrollSpiralCount - 6 || selected + direction * stride < 0 { direction = -direction }
        focus(selected + direction * stride, duration: 1.1)
    }
}

// MARK: - Field

private struct ScrollSpiralField: View {
    let position: CGFloat
    let twist: CGFloat
    let shrink: CGFloat
    let guide: Bool
    let centre: CGPoint

    var body: some View {
        ZStack(alignment: .topLeading) {
            if guide {
                ScrollSpiralCurve(twist: twist, shrink: shrink)
                    .stroke(Color.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 5]))
                    .offset(x: centre.x, y: centre.y)
            }
            // The focus slot.
            Circle()
                .strokeBorder(Palette.primary, lineWidth: 2)
                .frame(width: scrollSpiralItem + 12, height: scrollSpiralItem + 12)
                .shadow(color: Palette.indigo.opacity(0.4), radius: 10)
                .position(x: centre.x, y: centre.y + scrollSpiralRadius)
            ForEach(visible, id: \.self) { i in
                let place = ScrollSpiralPlacement(u: CGFloat(i) - position, twist: twist, shrink: shrink)
                ScrollSpiralItem(index: i)
                    .scaleEffect(place.scale)
                    .opacity(place.opacity)
                    .position(x: centre.x + place.x, y: centre.y + place.y)
                    .zIndex(Double(position) - Double(i))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Only the items that can be seen: one behind the focus and the tail until it is a speck.
    private var visible: [Int] {
        let first = max(Int(position.rounded(.down)) - 1, 0)
        let tail = Int((3.0 / Double(max(shrink, 0.01))).rounded(.up))
        let last = min(first + tail + 2, scrollSpiralCount - 1)
        guard first <= last else { return [] }
        return Array(first...last)
    }
}

private struct ScrollSpiralItem: View {
    let index: Int

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: ScrollKit.colors(index), startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: ScrollKit.symbol(index))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5))
            .frame(width: scrollSpiralItem, height: scrollSpiralItem)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

/// The spiral itself, from just past the focus to deep inside the eye, around the origin.
private struct ScrollSpiralCurve: Shape {
    let twist: CGFloat
    let shrink: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var u: CGFloat = -0.9
        var started = false
        while u <= 26 {
            let place = ScrollSpiralPlacement(u: u, twist: twist, shrink: shrink)
            let point = CGPoint(x: place.x, y: place.y)
            if started { path.addLine(to: point) } else { path.move(to: point) }
            started = true
            u += 0.08
        }
        return path
    }
}

private struct ScrollSpiralLabel: View {
    let index: Int
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: String(format: "%02d", index + 1))
                .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.primary)
                .contentTransition(.numericText(value: Double(index)))
            Text(ScrollKit.title(index), language)
                .font(.subheadline.weight(.semibold))
                .id(index)
                .transition(.opacity)
        }
        .allowsHitTesting(false)
    }
}
