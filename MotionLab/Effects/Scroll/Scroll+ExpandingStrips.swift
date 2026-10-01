import SwiftUI

extension Effect {
    static let scrollExpandingStrips = Effect(
        id: "scroll.expanding-strips",
        category: .scroll,
        interaction: .gesture,
        name: L("Expanding Strip Gallery", "展开式竖条画廊"),
        summary: L("A row of narrow pills: the one at the centre opens into a full card while the one leaving closes, so the row keeps its length.", "一排细长胶囊：到中间的那条展开成整张卡片，离开的那条同步收拢，整排长度不变。"),
        prompt: L(
            "A horizontal gallery of nine tall strips. At rest eight are 44 pt wide pills (200 pt tall) showing a gradient, an icon and a title rotated 90°; the focused one is a 190 × 236 pt card with a large icon, title, subtitle and a round arrow button. Dragging scrubs a continuous position: the strip leaving the centre narrows exactly as the next one widens (smoothstep weights that always sum to one), so the row never changes length and the open card stays centred. Inside each strip the artwork is a fixed-width picture revealed like a window, the vertical label fades out over the first half and the caption rises 10 pt and fades in over the second. Release settles with a spring (0.5 s, damping 0.78) on the projected strip; tapping any pill opens it. A selection haptic ticks per strip, and the ends rubber-band.",
            "九条竖向画幅组成的横向画廊。静止时八条是 44 pt 宽、200 pt 高的胶囊，露出渐变、图标和竖排标题；焦点那条是 190×236 pt 的卡片，带标题和箭头按钮。拖动驱动一个连续位置：离开中心的那条收窄多少，下一条就展宽多少，整排长度不变，展开的卡片始终居中。每条内部的画面宽度固定，像一扇窗被拉开；竖排标题在前半程淡出，说明文字在后半程上移 10 pt 淡入。松手后以弹簧（0.5 秒、阻尼 0.78）停到预测的那一条，点任意一条也会展开；每经过一条有一次选择触感，两端有橡皮筋阻尼。"
        ),
        implementation: L(
            "One CGFloat position drives an Animatable row view. Each strip's weight is smoothstep(1 − |i − position|); width, height, corner radius and caption opacity interpolate on it, and the HStack is offset so the weighted centre of the open strips sits in the middle. A page-safe horizontal drag scrubs the position and a spring settles it.",
            "用一个 CGFloat 位置驱动一个 Animatable 的行视图。每条的权重是 smoothstep(1 − |i − position|)，宽度、高度、圆角与说明文字透明度都按它插值；HStack 整体偏移，让展开部分的加权中心落在正中。不抢页面滚动的横向拖拽直接改这个位置，松手后由弹簧落定。"
        ),
        apis: ["Animatable", "DragGesture", "HStack", "rotationEffect", "spring(response:dampingFraction:)", "clipShape"],
        tags: ["gallery", "accordion", "expanding cards", "carousel", "pill", "画廊", "手风琴", "展开卡片", "轮播", "胶囊"],
        params: [
            .slider("collapsed", L("Pill width", "胶囊宽度"), 30...70, default: 44, step: 2, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.78),
        ]
    ) { ctx in
        ScrollStripsDemo(ctx: ctx)
    }
}

private let scrollStripsCount = 9
/// Finger travel that moves the gallery by one strip.
private let scrollStripsDragPitch: CGFloat = 110

private struct ScrollStripsDemo: View {
    let ctx: DemoContext
    @State private var position: CGFloat = 2
    @State private var selected = 2
    @State private var dragStart: CGFloat?
    @State private var direction = 1
    @State private var width: CGFloat = 340

    var body: some View {
        VStack(spacing: 14) {
            ScrollStripsRow(
                position: position,
                collapsed: ctx.cg("collapsed"),
                width: width,
                language: ctx.language,
                onTap: { i in settle(on: i, haptic: true) }
            )
            .frame(height: 240)
            .contentShape(Rectangle())
            .pageSafeHorizontalDrag(
                onChanged: { value in dragChanged(value.translation.width) },
                onEnded: { value in dragEnded(value?.predictedEndTranslation.width) }
            )
            ScrollStripsDots(count: scrollStripsCount, current: selected)
            DemoHint(text: L("Drag sideways · tap a strip", "左右拖动 · 点击任意一条"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self, of: { proxy in proxy.size.width }, action: { newWidth in
            width = newWidth
        })
        .clipped()
        .autoplay(ctx.isPreview, every: 1.5) { autoStep() }
    }

    private func dragChanged(_ translation: CGFloat) {
        let start = dragStart ?? position
        if dragStart == nil { dragStart = start }
        var raw: CGFloat = start - translation / scrollStripsDragPitch
        let last = CGFloat(scrollStripsCount - 1)
        if raw < 0 { raw = -rubberBand(-raw * scrollStripsDragPitch, limit: 80) / scrollStripsDragPitch }
        if raw > last { raw = last + rubberBand((raw - last) * scrollStripsDragPitch, limit: 80) / scrollStripsDragPitch }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { position = raw }
        let nearest = Int(raw.rounded()).clamped(to: 0...(scrollStripsCount - 1))
        if nearest != selected {
            selected = nearest
            Haptics.selection()
        }
    }

    private func dragEnded(_ predicted: CGFloat?) {
        let start = dragStart ?? position
        dragStart = nil
        // A cancelled drag settles on the nearest strip; a flick may carry up to two strips.
        let projected: CGFloat = predicted.map { start - $0 / scrollStripsDragPitch } ?? position
        let target = Int(projected.rounded().clamped(to: (position - 2)...(position + 2)).rounded())
        settle(on: target, haptic: false)
    }

    /// The single settle path: drags, taps and autoplay all land here.
    private func settle(on index: Int, haptic: Bool) {
        let target = index.clamped(to: 0...(scrollStripsCount - 1))
        if target != selected {
            if haptic { Haptics.selection() }
            selected = target
        }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            position = CGFloat(target)
        }
    }

    private func autoStep() {
        if selected + direction >= scrollStripsCount - 1 || selected + direction < 1 { direction = -direction }
        settle(on: selected + direction, haptic: false)
    }
}

/// The row itself. Animatable, so a spring on `position` re-lays the strips out on every frame.
private struct ScrollStripsRow: View, Animatable {
    var position: CGFloat
    let collapsed: CGFloat
    let width: CGFloat
    let language: AppLanguage
    let onTap: (Int) -> Void

    private let expanded: CGFloat = 190
    private let spacing: CGFloat = 8

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    private func weight(_ i: Int) -> CGFloat {
        ScrollMath.smooth(1 - abs(CGFloat(i) - position))
    }

    private func stripWidth(_ i: Int) -> CGFloat {
        ScrollMath.lerp(collapsed, expanded, weight(i))
    }

    /// x of the weighted centre of the open strip(s) inside the HStack.
    private var focusCentre: CGFloat {
        var x: CGFloat = 0
        var centre: CGFloat = 0
        var total: CGFloat = 0
        for i in 0..<scrollStripsCount {
            let w = stripWidth(i)
            let k = weight(i)
            centre += (x + w / 2) * k
            total += k
            x += w + spacing
        }
        // Past either end (rubber band) no strip is open: follow the nearest one.
        guard total > 0.001 else {
            return position < 0 ? collapsed / 2 + position * 60 : x - spacing - collapsed / 2 + (position - CGFloat(scrollStripsCount - 1)) * 60
        }
        let edge: CGFloat = position < 0 ? position * 60 : max(position - CGFloat(scrollStripsCount - 1), 0) * 60
        return centre / total + edge
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<scrollStripsCount, id: \.self) { i in
                ScrollStrip(index: i, weight: weight(i), width: stripWidth(i), expanded: expanded, language: language)
                    .onTapGesture { onTap(i) }
            }
        }
        .frame(width: width, alignment: .leading)
        .offset(x: width / 2 - focusCentre)
    }
}

private struct ScrollStrip: View {
    let index: Int
    /// 0 collapsed pill … 1 open card.
    let weight: CGFloat
    let width: CGFloat
    let expanded: CGFloat
    let language: AppLanguage

    var body: some View {
        let height: CGFloat = ScrollMath.lerp(200, 236, weight)
        let shape = RoundedRectangle(cornerRadius: ScrollMath.lerp(min(width / 2, 22), 28, weight), style: .continuous)
        let label: CGFloat = 1 - ScrollMath.unit(weight, 0, 0.5)
        let caption: CGFloat = ScrollMath.unit(weight, 0.5, 1)
        return ZStack {
            art
            verticalLabel.opacity(Double(label))
            captionBlock
                .opacity(Double(caption))
                .offset(y: 10 * (1 - caption))
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: ScrollKit.colors(index)[0].opacity(0.35 * Double(weight)), radius: 16, y: 10)
        .contentShape(shape)
    }

    /// A picture of fixed width: the strip is a window that opens onto it.
    private var art: some View {
        ZStack {
            LinearGradient(colors: ScrollKit.colors(index), startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 150, height: 150)
                .blur(radius: 26)
                .offset(x: 40, y: -70)
            Circle()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 14)
                .frame(width: 130, height: 130)
                .offset(x: -50, y: 40)
            Image(systemName: ScrollKit.symbol(index))
                .font(.system(size: ScrollMath.lerp(20, 58, weight), weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .offset(y: ScrollMath.lerp(-72, -34, weight))
            LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .center, endPoint: .bottom)
        }
        .frame(width: expanded, height: 236)
    }

    /// Latin titles are rotated a quarter turn; Chinese ones are set upright, one character per line.
    @ViewBuilder
    private var verticalLabel: some View {
        if language == .zh {
            Text(ScrollKit.title(index), language)
                .font(.system(size: 14, weight: .bold))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(width: 16)
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: 24)
        } else {
            Text(ScrollKit.title(index), language)
                .font(.system(size: 14, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.white)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .offset(y: 24)
        }
    }

    private var captionBlock: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ScrollKit.title(index), language)
                    .font(.system(size: 20, weight: .bold))
                Text(ScrollKit.subtitle(index), language)
                    .font(.caption.weight(.medium))
                    .opacity(0.85)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ScrollKit.colors(index)[0])
                .frame(width: 30, height: 30)
                .background(Color.white, in: Circle())
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: expanded, height: 236, alignment: .bottom)
    }
}

private struct ScrollStripsDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? AnyShapeStyle(Palette.primary) : AnyShapeStyle(Color.primary.opacity(0.18)))
                    .frame(width: i == current ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: current)
    }
}
