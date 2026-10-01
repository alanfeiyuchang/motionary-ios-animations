import SwiftUI

extension Effect {
    static let scrollPinnedZoom = Effect(
        id: "scroll.pinned-zoom",
        category: .scroll,
        interaction: .scroll,
        name: L("Pinned Hero Zoom", "固定头图放大"),
        summary: L("A rounded hero card stays pinned and grows to full bleed, its layers zooming at different depths, while the page slides over it.", "圆角头图卡片固定不动并撑满整屏，画面各层以不同深度放大，页面内容从它上方滑过。"),
        prompt: L(
            "A hero card sits inset 16 pt with 28 pt continuous corners: a dusk landscape of sky, sun and two ridge lines, with an eyebrow and title in its top-left corner. It never scrolls. Over the first 110 pt of scroll it grows to full bleed and its corners flatten to 0, while the layers zoom at different rates (sky 108%, sun 125%, far ridge 115%, near ridge 140%) so the scene gains depth, like a slow dolly-in. The first caption lifts 10 pt and fades out by the midpoint; a second caption fades up from 10 pt below in the second half. Meanwhile the content sheet, with 24 pt top corners and a soft upward shadow, slides over the image, which then dims 30% and drifts at a quarter of the scroll speed. Pulling down swells the card 8%. Cinematic and calm.",
            "头图卡片四周留白16 pt，带28 pt连续圆角：一幅由天空、落日和两道山脊组成的黄昏风景，左上角有标题。它始终不随内容滚动。前110 pt的滚动里，卡片撑满整屏、圆角收平到0，同时各层以不同倍率放大（天空108%、太阳125%、远山115%、近山140%），像镜头缓缓推进。第一段文案上移10 pt，在行程过半时淡出；第二段在后半程从下方10 pt处淡入。同时，带24 pt顶部圆角和向上投影的内容面板从图片上方滑过，随后图片压暗30%，并以滚动速度的四分之一漂移。下拉时卡片放大8%。"
        ),
        implementation: L(
            "The hero is drawn behind a ScrollView whose content starts with a clear spacer, so it stays pinned. onScrollGeometryChange gives the offset; a 0…1 progress interpolates the card's inset, corner radius and height, the per-layer scaleEffect and the two captions' opacity and offset.",
            "头图画在 ScrollView 的后面，ScrollView 的内容以一段透明占位开头，所以头图固定不动。onScrollGeometryChange 给出偏移量；由 0…1 的进度插值计算卡片的留白、圆角与高度，各图层的 scaleEffect，以及两段文案的透明度和位移。"
        ),
        apis: ["onScrollGeometryChange", "scaleEffect(_:anchor:)", "RoundedRectangle", "ScrollPosition", "Shape"],
        tags: ["hero", "pinned", "zoom", "full bleed", "depth", "头图", "固定", "放大", "全出血", "纵深"],
        params: [
            .slider("range", L("Scroll range", "滚动行程"), 60...200, default: 110, step: 5, decimals: 0, unit: "pt"),
            .slider("zoom", L("Depth zoom", "纵深放大"), 1.0...1.8, default: 1.4),
            .slider("radius", L("Corner radius", "圆角"), 0...40, default: 28, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        ScrollPinnedZoomDemo(ctx: ctx)
    }
}

private let scrollPinnedInset: CGFloat = 16
private let scrollPinnedTop: CGFloat = 14
private let scrollPinnedHeight: CGFloat = 224

private struct ScrollPinnedZoomDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var down = false
    /// The finger's pull at the top edge (see `ScrollTopPull`).
    @State private var fingerPull: CGFloat = 0

    private var range: CGFloat { max(ctx.cg("range"), 1) }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollPinnedHero(
                progress: (offset / range).clamped(to: 0...1),
                beyond: max(offset - range, 0),
                pull: max(-offset, 0) + fingerPull,
                zoom: ctx.cg("zoom"),
                radius: ctx.cg("radius"),
                language: ctx.language
            )
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: scrollPinnedTop + scrollPinnedHeight + 14 + fingerPull * 0.5)
                    sheet
                }
            }
            .scrollIndicators(.hidden)
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            }, action: { _, newValue in
                offset = newValue
            })
        }
        .clipped()
        .modifier(ScrollTopPull(isEnabled: !ctx.isPreview && offset <= 0.5, pull: $fingerPull))
        .autoplay(ctx.isPreview, every: 2.6) {
            down.toggle()
            withAnimation(.smooth(duration: 1.9)) {
                position.scrollTo(y: down ? range + 8 : 0)
            }
        }
    }

    private var sheet: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            Capsule()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
            Text(L("Itinerary", "行程"), ctx.language)
                .font(.title3.weight(.bold))
                .padding(.top, 2)
            ForEach(0..<10, id: \.self) { i in
                ScrollKitRow(index: i + 6, language: ctx.language)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(Palette.surface, in: shape)
        .shadow(color: .black.opacity(0.22), radius: 18, y: -6)
    }
}

private struct ScrollPinnedHero: View {
    /// 0 = inset rounded card, 1 = full bleed.
    let progress: CGFloat
    /// Points scrolled past the morph range.
    let beyond: CGFloat
    let pull: CGFloat
    let zoom: CGFloat
    let radius: CGFloat
    let language: AppLanguage

    var body: some View {
        let p = ScrollMath.smooth(progress)
        let inset: CGFloat = ScrollMath.lerp(scrollPinnedInset, 0, p)
        let top: CGFloat = ScrollMath.lerp(scrollPinnedTop, 0, p)
        let height: CGFloat = scrollPinnedHeight + (scrollPinnedTop - top) + 14 * p
        let shape = RoundedRectangle(cornerRadius: ScrollMath.lerp(radius, 0, p), style: .continuous)
        ScrollPinnedScene(progress: p, zoom: zoom)
            .offset(y: -min(beyond * 0.25, 40))
            .overlay(Color.black.opacity(0.3 * Double(ScrollMath.unit(beyond, 0, 120))))
            .overlay(alignment: .topLeading) { captions(p) }
            .frame(height: height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.14 * Double(1 - p)), lineWidth: 1))
            .shadow(color: .black.opacity(0.2 * Double(1 - p)), radius: 16, y: 10)
            .padding(.horizontal, inset)
            .padding(.top, top)
            .scaleEffect(1 + min(pull / 100, 1) * 0.08, anchor: .top)
    }

    private func captions(_ p: CGFloat) -> some View {
        let first: CGFloat = 1 - ScrollMath.unit(p, 0, 0.5)
        let second: CGFloat = ScrollMath.unit(p, 0.5, 1)
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L("CHAPTER 01", "第一章"), language)
                    .font(.caption2.weight(.heavy))
                    .tracking(1.2)
                    .opacity(0.85)
                Text(L("Dusk over the ridge", "山脊上的黄昏"), language)
                    .font(.title2.weight(.bold))
            }
            .opacity(Double(first))
            .offset(y: -10 * (1 - first))
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Alpe di Siusi", "休西高原"), language)
                    .font(.title2.weight(.bold))
                HStack(spacing: 5) {
                    Image(systemName: "mountain.2.fill")
                    Text(L("2,100 m · 19:42", "海拔 2100 米 · 19:42"), language)
                }
                .font(.caption.weight(.semibold))
                .opacity(0.9)
            }
            .opacity(Double(second))
            .offset(y: 10 * (1 - second))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }
}

/// A dusk landscape in four layers that zoom at different rates (sky, sun, far ridge, near ridge).
private struct ScrollPinnedScene: View {
    let progress: CGFloat
    let zoom: CGFloat

    var body: some View {
        let depth: CGFloat = max(zoom - 1, 0) * progress
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2B2A7A), Color(hex: 0x8B4BB0), Color(hex: 0xFF7A6B), Color(hex: 0xFFC56B)],
                startPoint: .top,
                endPoint: .bottom
            )
            .scaleEffect(1 + depth * 0.2)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF3C4), Color(hex: 0xFFB45E)], center: .center, startRadius: 2, endRadius: 30))
                .frame(width: 56, height: 56)
                .shadow(color: Color(hex: 0xFFC56B).opacity(0.9), radius: 26)
                .offset(x: 54, y: 4)
                .scaleEffect(1 + depth * 0.625, anchor: .bottom)
            ScrollPinnedRidge(base: 0.56, amplitude: 0.11, frequency: 2.1, phase: 0.6)
                .fill(LinearGradient(colors: [Color(hex: 0x6C3F9E), Color(hex: 0x3B2A6E)], startPoint: .top, endPoint: .bottom))
                .scaleEffect(1 + depth * 0.375, anchor: .bottom)
            ScrollPinnedRidge(base: 0.72, amplitude: 0.13, frequency: 1.4, phase: 2.4)
                .fill(LinearGradient(colors: [Color(hex: 0x2A1E52), Color(hex: 0x15102B)], startPoint: .top, endPoint: .bottom))
                .scaleEffect(1 + depth, anchor: .bottom)
        }
    }
}

/// A rolling ridge line: the area below a sum of two sines.
private struct ScrollPinnedRidge: Shape {
    let base: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 48
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let wave = sin(t * frequency * 2 * .pi + phase) + 0.45 * sin(t * frequency * 5.3 * .pi + phase * 2.1)
            let y = rect.minY + rect.height * (base - amplitude * wave)
            path.addLine(to: CGPoint(x: rect.minX + rect.width * t, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
