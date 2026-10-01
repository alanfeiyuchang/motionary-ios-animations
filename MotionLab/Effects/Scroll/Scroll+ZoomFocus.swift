import SwiftUI

extension Effect {
    static let scrollZoomFocus = Effect(
        id: "scroll.zoom-focus",
        category: .scroll,
        interaction: .scroll,
        name: L("Zoom Focus Row", "对焦放大选择行"),
        summary: L("The centred tile swells and snaps into focus while its neighbours shrink, dim and blur out of the way.", "居中的图块放大并对上焦，两侧的图块缩小、变暗、虚化并向外让位。"),
        prompt: L(
            "A row of 72 pt rounded-square gradient tiles, 18 pt apart, scrolls under a fixed set of camera-style focus brackets. Each tile's distance from the centre feeds a Gaussian lens (σ ≈ 68 pt): at the centre it is scaled to 170%, fully saturated and sharp; one step away it is back to natural size, dimmed 40%, desaturated and blurred about 2.5 pt, and further out tiles rest at 86%. Neighbours are pushed outward by exactly the room the big tile needs, so nothing overlaps and the row seems to bulge under the lens. Everything scrubs with the finger. The scroll snaps one tile to the centre; when a new tile lands, the brackets pinch from 112% back to 100% on a bouncy spring with a selection tick, and the name below cross-fades. Like racking focus on a lens.",
            "一排72 pt的圆角方形渐变图块，间距18 pt，在一组固定的相机式对焦框下方滚动。每个图块到中心的距离被送入一枚高斯透镜（σ约68 pt）：位于中心时放大到170%，色彩饱满、清晰锐利；偏离一格就回到原始大小，变暗约40%、饱和度降低并模糊约2.5 pt，更远处停在86%。两侧图块恰好被推开大图块所需的空间，互不重叠，整排像在透镜下鼓起。全程跟手。滚动会把一个图块吸附到中心；新图块落位时，对焦框从112%以带弹跳的弹簧收回到100%，伴随一次选择触感，下方名称淡入切换。像镜头拉焦。"
        ),
        implementation: L(
            "Each tile's visualEffect reads its midX in the .scrollView space and runs it through a Gaussian magnifier: the scale, plus an offset equal to the integral of the scale (an erf), so neighbours are displaced rather than overlapped; blur, opacity and saturation use the same weight. A stride ScrollTargetBehavior snaps and a keyframeAnimator pinches the brackets.",
            "每个图块的 visualEffect 读取自身在 .scrollView 坐标空间中的 midX，并送入高斯放大函数：得到缩放，以及等于缩放积分（erf）的位移，因此邻居是被推开而不是被盖住；模糊、不透明度和饱和度共用同一权重。按步距吸附的 ScrollTargetBehavior 负责吸附，keyframeAnimator 让对焦框收缩。"
        ),
        apis: ["visualEffect", "ScrollTargetBehavior", "onScrollGeometryChange", "keyframeAnimator", "ScrollPosition"],
        tags: ["zoom", "focus", "lens", "carousel", "snap", "放大", "对焦", "透镜", "轮播", "吸附"],
        params: [
            .slider("scale", L("Focus scale", "中心放大"), 1.2...2.0, default: 1.7),
            .slider("blur", L("Neighbour blur", "两侧模糊"), 0...8, default: 3, step: 0.5, decimals: 1, unit: "pt"),
            .slider("dim", L("Neighbour dimming", "两侧变暗"), 0...0.8, default: 0.5),
        ]
    ) { ctx in
        ScrollZoomFocusDemo(ctx: ctx)
    }
}

private let scrollZoomInitialIndex = 4

private struct ScrollZoomFocusDemo: View {
    let ctx: DemoContext
    @State private var current: Int
    @State private var position = ScrollPosition(edge: .leading)
    @State private var width: CGFloat = 340
    @State private var direction = 1
    /// True while autoplay scrolls the row, so scripted ticks stay silent.
    @State private var scripted = false

    private let count = 12
    private let side: CGFloat = 72
    private let pitch: CGFloat = 90

    /// Stills never scroll to the initial tile, so tile 0 sits under the lens there.
    init(ctx: DemoContext) {
        self.ctx = ctx
        _current = State(initialValue: ctx.isStill ? 0 : scrollZoomInitialIndex)
    }

    var body: some View {
        VStack(spacing: 4) {
            row
            caption
            DemoHint(text: L("Swipe the row · tap a tile", "滑动这一排 · 点击图块"), ctx: ctx)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: current) {
            if !ctx.isPreview && !scripted { Haptics.selection() }
        }
        .autoplay(ctx.isPreview, every: 1.3) { advance() }
    }

    private var row: some View {
        let peak = ctx.cg("scale")
        let blur = ctx.cg("blur")
        let dim = ctx["dim"]
        let viewport = max(width, 1)
        let sigma: CGFloat = pitch * 0.76
        let count = self.count
        let pitch = self.pitch
        return ScrollView(.horizontal) {
            LazyHStack(spacing: pitch - side) {
                ForEach(0..<count, id: \.self) { i in
                    ScrollZoomTile(index: i, side: side)
                        .visualEffect { content, proxy in
                            let d: CGFloat = proxy.frame(in: .scrollView).midX - viewport / 2
                            let lens = ScrollMath.fisheye(distance: d, sigma: sigma, peak: peak, base: 0.86)
                            let away = Double(1 - lens.weight)
                            return content
                                .scaleEffect(lens.scale)
                                .offset(x: lens.position - d)
                                .blur(radius: blur * CGFloat(away))
                                .saturation(1 - 0.55 * away)
                                .opacity(1 - dim * away)
                        }
                        .onTapGesture { select(i) }
                }
            }
            .padding(.horizontal, max((width - side) / 2, 0))
        }
        .scrollTargetBehavior(ScrollStrideSnap(pitch: pitch))
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .onScrollGeometryChange(for: Int.self, of: { geometry in
            let offset = geometry.contentOffset.x + geometry.contentInsets.leading
            return Int((offset / pitch).rounded()).clamped(to: 0...(count - 1))
        }, action: { _, newValue in
            current = newValue
        })
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .interacting { scripted = false }
        }
        .onAppear { position.scrollTo(x: CGFloat(scrollZoomInitialIndex) * pitch) }
        .frame(height: 186)
        .overlay {
            ScrollZoomBrackets(side: side * peak + 16)
                .keyframeAnimator(initialValue: 1.0, trigger: current) { content, value in
                    content.scaleEffect(value)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.12, duration: 0.09)
                        SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                    }
                }
                .allowsHitTesting(false)
        }
        .onGeometryChange(for: CGFloat.self, of: { proxy in proxy.size.width }, action: { newWidth in
            width = newWidth
        })
    }

    private var caption: some View {
        VStack(spacing: 3) {
            Text(ScrollKit.title(current), ctx.language)
                .font(.title3.weight(.bold))
                .contentTransition(.interpolate)
            Text(ScrollKit.subtitle(current), ctx.language)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.interpolate)
        }
        .animation(.snappy(duration: 0.28), value: current)
    }

    private func select(_ i: Int) {
        scripted = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
            position.scrollTo(x: CGFloat(i) * pitch)
        }
    }

    private func advance() {
        let jump = 2
        scripted = true
        if current + direction * jump >= count || current + direction * jump < 0 { direction = -direction }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
            position.scrollTo(x: CGFloat(current + direction * jump) * pitch)
        }
    }
}

private struct ScrollZoomTile: View {
    let index: Int
    let side: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
        let colors = ScrollKit.colors(index)
        Image(systemName: ScrollKit.symbol(index))
            .font(.system(size: side * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            .frame(width: side, height: side)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: shape)
            .overlay {
                shape
                    .fill(LinearGradient(colors: [Color.white.opacity(0.32), .clear], startPoint: .top, endPoint: .center))
                    .blendMode(.plusLighter)
            }
            .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 0.75))
            .shadow(color: colors[0].opacity(0.35), radius: 9, y: 5)
            .contentShape(shape)
    }
}

/// Four camera-style corner brackets around the focused tile.
private struct ScrollZoomBrackets: View {
    let side: CGFloat

    var body: some View {
        ScrollZoomBracketShape(arm: 13, radius: side * 0.26)
            .stroke(Color.primary.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
    }
}

private struct ScrollZoomBracketShape: Shape {
    let arm: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(radius, min(rect.width, rect.height) / 2)
        // Each corner: a short arm, the rounded corner, a short arm.
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
        ]
        for (corner, sx, sy) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + sy * (r + arm)))
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + sy * r))
            path.addQuadCurve(to: CGPoint(x: corner.x + sx * r, y: corner.y), control: corner)
            path.addLine(to: CGPoint(x: corner.x + sx * (r + arm), y: corner.y))
        }
        return path
    }
}
