import SwiftUI

extension Effect {
    static let scrollMaskReveal = Effect(
        id: "scroll.mask-reveal",
        category: .scroll,
        interaction: .scroll,
        name: L("Mask Reveal Feed", "遮罩揭示图片流"),
        summary: L("Each picture opens through a growing mask as it enters, while the image inside settles from a zoom and drifts against the scroll.", "每张图片进入时透过一块逐渐张开的遮罩显现，里面的画面从放大状态落定，并逆着滚动方向缓缓漂移。"),
        prompt: L(
            "A feed of 190 pt tall pictures with a caption under each. A picture is not simply scrolled into view: its slot arrives as a faint empty frame and the image is revealed through a mask scrubbed by the scroll, starting when the slot's top is 20 pt inside the viewport and ending when its bottom edge has cleared the bottom by 20 pt (smoothstep). The mask is an iris growing from the centre, an inset rounded rectangle that opens from 34% inset and 60 pt corners to full size with 24 pt corners, or a curtain rising with a bowed edge. Inside it the image scales from 125% down to 100% and keeps drifting ±26 pt against the scroll for depth. The caption follows over the last 40% of the reveal, rising 12 pt as it fades in. Scrolling back closes each mask the same way.",
            "一列 190 pt 高的图片，每张下面带一行说明。图片不是简单地滚进视野：它的位置先以淡淡的空框出现，画面再透过一块由滚动驱动的遮罩显现——从空框顶边进入视口 20 pt 时开始，到底边越过视口下沿 20 pt 时结束。遮罩可以是从中心张开的光圈，可以是从 34% 内缩、60 pt 圆角张开到满幅、24 pt 圆角的圆角矩形，也可以是带弧形边缘升起的幕布。遮罩里的画面从 125% 缩回 100%，并逆着滚动方向漂移 ±26 pt 制造纵深。说明文字在最后 40% 跟上：上移 12 pt 并淡入。往回滚动时遮罩原样合上。"
        ),
        implementation: L(
            "Cards sit on a fixed pitch, so each card's reveal progress is computed from the scroll offset and viewport height published by onScrollGeometryChange. The progress drives a custom Shape used as clipShape, plus the scale and offset of an oversized image behind it.",
            "卡片按固定行距排列，所以每张卡片的揭示进度可以由 onScrollGeometryChange 发布的偏移量和视口高度直接算出。这个进度驱动一个用作 clipShape 的自定义 Shape，以及遮罩后面那张加大尺寸画面的缩放和偏移。"
        ),
        apis: ["Shape", "clipShape", "onScrollGeometryChange", "scaleEffect", "ScrollPosition"],
        tags: ["mask", "reveal", "parallax", "image", "feed", "遮罩", "揭示", "视差", "图片", "信息流"],
        params: [
            .choice("shape", L("Mask", "遮罩形状"), [L("Iris", "光圈"), L("Inset", "内缩"), L("Curtain", "幕布")], default: 1),
            .slider("parallax", L("Inner parallax", "内部视差"), 0...50, default: 26, step: 2, decimals: 0, unit: "pt"),
            .slider("zoom", L("Start zoom", "起始放大"), 1.0...1.6, default: 1.25),
        ]
    ) { ctx in
        ScrollMaskRevealDemo(ctx: ctx)
    }
}

private let scrollRevealCard: CGFloat = 190
private let scrollRevealCaption: CGFloat = 38
private let scrollRevealPitch: CGFloat = 240
private let scrollRevealTop: CGFloat = 12
private let scrollRevealCount = 7

private struct ScrollMaskRevealDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var viewport: CGFloat = 340
    @State private var position = ScrollPosition(edge: .top)
    @State private var down = false

    /// 0 closed … 1 fully open, from where the card sits in the viewport.
    private func reveal(_ i: Int) -> CGFloat {
        let top: CGFloat = scrollRevealTop + CGFloat(i) * scrollRevealPitch - offset
        let entered: CGFloat = viewport - top
        return ScrollMath.smooth(ScrollMath.unit(entered, 20, scrollRevealCard + 20))
    }

    /// −1 at the bottom of the viewport … +1 at the top: drives the inner drift.
    private func drift(_ i: Int) -> CGFloat {
        let mid: CGFloat = scrollRevealTop + CGFloat(i) * scrollRevealPitch + scrollRevealCard / 2 - offset
        return (1 - 2 * mid / max(viewport, 1)).clamped(to: -1.4...1.4)
    }

    var body: some View {
        let style = ctx.int("shape")
        let parallax: CGFloat = ctx.cg("parallax")
        let zoom: CGFloat = ctx.cg("zoom")
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<scrollRevealCount, id: \.self) { i in
                    ScrollRevealCard(
                        index: i,
                        progress: reveal(i),
                        drift: drift(i),
                        style: style,
                        parallax: parallax,
                        zoom: zoom,
                        language: ctx.language
                    )
                    .frame(height: scrollRevealPitch, alignment: .top)
                }
            }
            .padding(.top, scrollRevealTop)
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGSize.self, of: { geometry in
            CGSize(width: geometry.contentOffset.y + geometry.contentInsets.top, height: geometry.containerSize.height)
        }, action: { _, newValue in
            offset = newValue.width
            if newValue.height > 0 { viewport = newValue.height }
        })
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.0) {
            down.toggle()
            withAnimation(.easeInOut(duration: 2.5)) {
                position.scrollTo(y: down ? scrollRevealPitch * 2.6 : 0)
            }
        }
    }
}

private struct ScrollRevealCard: View {
    let index: Int
    let progress: CGFloat
    let drift: CGFloat
    let style: Int
    let parallax: CGFloat
    let zoom: CGFloat
    let language: AppLanguage

    var body: some View {
        let slot = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let caption: CGFloat = ScrollMath.unit(progress, 0.6, 1)
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                // The empty slot the picture opens into.
                slot
                    .fill(Color.primary.opacity(0.05))
                    .overlay(slot.strokeBorder(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    .opacity(Double(1 - progress))
                ScrollRevealArt(index: index)
                    .frame(height: scrollRevealCard + parallax * 2)
                    .scaleEffect(ScrollMath.lerp(zoom, 1, progress))
                    .offset(y: -drift * parallax)
                    .frame(height: scrollRevealCard)
                    .clipShape(ScrollRevealMask(progress: progress, style: style))
                    .shadow(color: ScrollKit.colors(index + 1)[0].opacity(0.28 * Double(progress)), radius: 14, y: 8)
            }
            .frame(height: scrollRevealCard)
            HStack(alignment: .firstTextBaseline) {
                Text(ScrollKit.title(index + 1), language)
                    .font(.subheadline.weight(.bold))
                Text(ScrollKit.subtitle(index + 1), language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "heart")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(height: scrollRevealCaption)
            .opacity(Double(caption))
            .offset(y: 12 * (1 - caption))
        }
    }
}

/// The picture: a gradient landscape of soft shapes, larger than its window so it can drift.
private struct ScrollRevealArt: View {
    let index: Int

    var body: some View {
        let colors = ScrollKit.colors(index + 1)
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.26))
                        .frame(width: 200, height: 200)
                        .blur(radius: 34)
                        .offset(x: 80, y: -70)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 18)
                        .frame(width: 180, height: 180)
                        .offset(x: -90, y: 60)
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 260, height: 260)
                        .offset(x: 120, y: 150)
                    Image(systemName: ScrollKit.symbol(index + 1))
                        .font(.system(size: 76, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
                }
            }
    }
}

/// The opening mask. `progress` 0 is closed, 1 is the full 24 pt rounded card.
private struct ScrollRevealMask: Shape {
    let progress: CGFloat
    let style: Int

    func path(in rect: CGRect) -> Path {
        let full = Path(roundedRect: rect, cornerRadius: 24, style: .continuous)
        let p = progress.clamped(to: 0...1)
        guard p < 0.999 else { return full }
        switch style {
        case 0:
            // Iris: a circle growing from the centre until it covers the corners.
            let radius: CGFloat = hypot(rect.width, rect.height) / 2 * p
            let circle = Path(ellipseIn: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))
            return circle.intersection(full)
        case 2:
            // Curtain: rises from the bottom with a bowed leading edge that flattens as it arrives.
            let top: CGFloat = rect.maxY - (rect.height + 30) * p
            let bow: CGFloat = 46 * (1 - p)
            var curtain = Path()
            curtain.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            curtain.addLine(to: CGPoint(x: rect.minX, y: top + bow))
            curtain.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + bow), control: CGPoint(x: rect.midX, y: top - bow))
            curtain.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            curtain.closeSubpath()
            return curtain.intersection(full)
        default:
            // Inset: a rounded rectangle opening from 34% inset and 60 pt corners.
            let inset: CGFloat = 0.34 * (1 - p)
            let opened = rect.insetBy(dx: rect.width * inset, dy: rect.height * inset)
            let radius: CGFloat = min(ScrollMath.lerp(60, 24, p), min(opened.width, opened.height) / 2)
            return Path(roundedRect: opened, cornerRadius: radius, style: .continuous)
        }
    }
}
