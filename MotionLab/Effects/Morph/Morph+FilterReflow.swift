import SwiftUI

extension Effect {
    static let morphFilterReflow = Effect(
        id: "morph.filter-reflow",
        category: .morph,
        interaction: .tap,
        name: L("Filter Reflow", "筛选重排"),
        summary: L(
            "Change the filter and the grid re-packs in three beats: leavers shrink away, survivors glide to their new slots, newcomers pop in last.",
            "切换筛选，网格分三拍重排：离开的先缩小消失，留下的滑向新位置，新来的最后弹出。"
        ),
        prompt: L(
            "A 4 × 3 grid of 66 pt media tiles under a segmented filter with a sliding highlight. Choosing a filter re-packs the grid in three overlapping beats. Tiles that no longer match shrink to 40%, blur 4 pt and fade in 0.18 s with an ease-in, staying where they were. The tiles that remain glide to their new slots on a spring (response 0.5 s, damping 0.72), each delayed 30 ms more than the one before it in the new order, so the grid closes up as a ripple from the first slot with a small overshoot on landing. Tiles that return appear directly in their slot and pop from 40% on a bouncier spring (damping 0.6) after the gliders have left. The item count rolls. Orderly, causal, easy to follow.",
            "分段筛选器（带滑动高亮）下方是 4 × 3 的媒体网格，每格 66pt。切换筛选后网格分三拍重叠完成重排。不再匹配的格子原地缩到 40%、模糊 4pt，并在 0.18 秒内缓入淡出。留下的格子乘弹簧（响应 0.5 秒、阻尼 0.72）滑向新位置，按新顺序每一格比前一格多延迟 30 毫秒，于是网格从第一格开始像波纹一样合拢，落位时带一点过冲。重新出现的格子直接出现在自己的位置上，等滑动的格子让开后，乘更有弹性的弹簧（阻尼 0.6）从 40% 弹出。条目计数随之滚动。有秩序、有因果，一眼看得懂。"
        ),
        implementation: L(
            "Every tile is positioned explicitly from its rank among the visible items. Two scoped modifiers per tile do the choreography: a transaction keyed to its slot (a delayed spring, or none for a tile that was hidden) and an animation keyed to its visibility (ease-in out, delayed bouncy spring in).",
            "每个格子按自己在可见条目中的名次显式定位。每格有两个限定作用域的修饰符负责编排：由槽位驱动的 transaction（带延迟的弹簧，原先隐藏的格子则不做位移动画），以及由可见性驱动的 animation（缓入消失、带延迟的弹性弹入）。"
        ),
        apis: ["transaction(value:_:)", "animation(_:value:)", "position", "spring(response:dampingFraction:)", "matchedGeometryEffect", "contentTransition(.numericText)"],
        tags: ["filter", "grid", "reflow", "reorder", "layout", "筛选", "网格", "重排", "布局动画"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.72),
            .slider("stagger", L("Stagger", "错峰间隔"), 0...0.08, default: 0.03, decimals: 3, unit: "s"),
            .slider("exit", L("Exit scale", "离场缩放"), 0.1...0.9, default: 0.4),
        ]
    ) { ctx in
        FilterReflowDemo(ctx: ctx)
    }
}

private enum ReflowLayout {
    static let size = CGSize(width: 316, height: 306)
    static let tile: CGFloat = 66
    static let gap: CGFloat = 9
    static let top: CGFloat = 66
    static let types: [Int] = [0, 1, 0, 2, 1, 0, 2, 1, 0, 1, 2, 0]
    static let symbols: [String] = ["photo.fill", "play.fill", "waveform"]
    static let colors: [[Color]] = [
        [Palette.pink, Palette.coral], [Palette.indigo, Palette.violet], [Palette.amber, Color(hex: 0xFF9A2E)],
    ]
    static let filters: [LocalizedText] = [L("All", "全部"), L("Photos", "照片"), L("Videos", "视频"), L("Audio", "音频")]

    static func center(slot: Int) -> CGPoint {
        let column = CGFloat(slot % 4)
        let row = CGFloat(slot / 4)
        let left: CGFloat = (size.width - tile * 4 - gap * 3) / 2
        return CGPoint(x: left + tile / 2 + column * (tile + gap), y: top + tile / 2 + row * (tile + gap))
    }

    /// Slot of every item for `filter` (0 = all); `nil` when the item is filtered out.
    static func slots(filter: Int) -> [Int?] {
        var next = 0
        return types.map { type in
            guard filter == 0 || type == filter - 1 else { return nil }
            next += 1
            return next - 1
        }
    }
}

private struct FilterReflowDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var filter = 0
    /// Current slot of every tile; a hidden tile keeps the last slot it had.
    @State private var slots: [Int] = Array(0..<12)
    @State private var shown: [Bool] = Array(repeating: true, count: 12)
    /// Tiles that were visible before the last change and still are: only these glide.
    @State private var glides: [Bool] = Array(repeating: true, count: 12)

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                Palette.surface
                header
                    .padding(.top, 14)
                ForEach(0..<12, id: \.self) { index in
                    tile(index)
                }
            }
            .morphScreen()
            DemoHint(text: L("Tap a filter", "点击筛选项"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { select((filter + 1) % 4) }
    }

    private var header: some View {
        let count: Int = shown.filter { $0 }.count
        return HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    let on: Bool = index == filter
                    Button { select(index) } label: {
                        Text(ReflowLayout.filters[index], ctx.language)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(on ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.secondary))
                            .frame(width: 54, height: 30)
                            .background {
                                if on {
                                    Capsule()
                                        .fill(Palette.primaryStrong)
                                        .matchedGeometryEffect(id: "pill", in: ns)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Palette.elevated, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.stroke))
            Spacer(minLength: 0)
            Text(verbatim: "\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
                .fixedSize()
                .padding(.trailing, 26)
        }
        .padding(.horizontal, 12)
    }

    private func tile(_ index: Int) -> some View {
        let visible: Bool = shown[index]
        let slot: Int = slots[index]
        let delay: Double = Double(slot) * ctx["stagger"]
        let glide: Animation? = glides[index]
            ? .spring(response: ctx["response"], dampingFraction: ctx["damping"]).delay(0.06 + delay)
            : nil
        let appear: Animation = visible
            ? .spring(response: 0.42, dampingFraction: 0.6).delay(0.16 + delay)
            : .easeIn(duration: 0.18)
        return ReflowTile(index: index)
            .scaleEffect(visible ? 1 : ctx.cg("exit"))
            .opacity(visible ? 1 : 0)
            .blur(radius: visible ? 0 : 4)
            .animation(appear, value: visible)
            .position(ReflowLayout.center(slot: slot))
            // A returning tile takes its slot at once (no travel); only tiles that stayed visible glide.
            .transaction(value: slot) { transaction in
                transaction.animation = glide
                transaction.disablesAnimations = glide == nil
            }
            .allowsHitTesting(false)
    }

    private func select(_ value: Int) {
        guard value != filter else { return }
        if !ctx.isPreview { Haptics.selection() }
        let target: [Int?] = ReflowLayout.slots(filter: value)
        var newSlots: [Int] = slots
        var newShown: [Bool] = shown
        var newGlides: [Bool] = glides
        for index in 0..<12 {
            if let slot = target[index] {
                newGlides[index] = shown[index]
                newSlots[index] = slot
                newShown[index] = true
            } else {
                newGlides[index] = false
                newShown[index] = false
            }
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
            filter = value
            slots = newSlots
            shown = newShown
            glides = newGlides
        }
    }
}

private struct ReflowTile: View {
    let index: Int

    var body: some View {
        let type: Int = ReflowLayout.types[index]
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        // A slightly different shade per tile, so each one can be followed by eye.
        let shade: Double = Double(index % 4) * 0.045
        shape
            .fill(LinearGradient(colors: ReflowLayout.colors[type], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.fill(Color.black.opacity(shade)))
            .overlay {
                Image(systemName: ReflowLayout.symbols[type])
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(verbatim: String(format: "%02d", index + 1))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(7)
            }
            .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .frame(width: ReflowLayout.tile, height: ReflowLayout.tile)
            .shadow(color: ReflowLayout.colors[type][1].opacity(0.3), radius: 6, y: 4)
    }
}
