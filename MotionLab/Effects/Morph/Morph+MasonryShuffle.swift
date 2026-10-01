import SwiftUI

extension Effect {
    static let morphMasonryShuffle = Effect(
        id: "morph.masonry-shuffle",
        category: .morph,
        interaction: .tap,
        name: L("Masonry Shuffle", "瀑布流洗牌"),
        summary: L(
            "Tap a tile to feature it: the whole masonry wall re-tiles itself, every tile changing size and place in one staggered, springy move.",
            "点一块砖把它设为主角：整面瀑布墙重新铺排，每块砖都乘弹簧错峰地换了大小和位置。"
        ),
        prompt: L(
            "A wall of six photo tiles packed gap-free on a 6 × 6 unit grid with 8 pt gutters and 20 pt corners. Tapping a tile promotes it to the hero slot of the next of four layouts and re-deals the other five. Every tile keeps its identity and animates both its frame and its position on a spring (response 0.55 s, damping 0.78), starting 35 ms after the previous slot, so the wall re-tiles as a wave and settles with a small overshoot. Tiles pass over each other in a fixed stacking order with soft shadows. Content adapts to the new size inside the same motion: the glyph grows to 160% on tiles taller than 110 pt, and the caption fades in only on tiles wider than 120 pt and taller than 80 pt. A light haptic marks the shuffle. Tidy, kinetic, never a hard cut.",
            "六块照片砖无缝铺在 6 × 6 单位的网格上，间距 8pt、圆角 20pt。点任意一块，它会升到下一套布局（共四套）的主角位，其余五块重新分配。每块砖保持自己的身份，外框尺寸和位置同时乘弹簧（响应 0.55 秒、阻尼 0.78）变化，按槽位顺序每块比前一块晚 35 毫秒出发，整面墙像波浪般重铺，落定时略带过冲。砖块按固定的层叠顺序带着柔和阴影彼此掠过。内容在同一段动作里适应新尺寸：图标在高于 110pt 的砖上放大到 160%，说明文字只在宽于 120pt、高于 80pt 的砖上淡入。洗牌时给一次轻触觉反馈。"
        ),
        implementation: L(
            "Four hand-packed layouts are lists of unit rects; a tile → slot assignment maps each tile to a rect. Tiles are laid out with explicit frame and position, and each has its own delayed spring keyed to a shuffle counter, so SwiftUI interpolates size and place together.",
            "四套手工排好的布局都是单位矩形列表；「砖 → 槽位」的映射决定每块砖对应哪个矩形。砖块用显式的 frame 和 position 布局，每块各带一条由洗牌计数驱动的延迟弹簧，尺寸与位置由 SwiftUI 一并插值。"
        ),
        apis: ["frame(width:height:)", "position", "animation(_:value:)", "spring(response:dampingFraction:)", "zIndex"],
        tags: ["masonry", "grid", "shuffle", "bento", "layout", "瀑布流", "网格", "洗牌", "布局动画"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.55, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.78),
            .slider("stagger", L("Stagger", "错峰间隔"), 0...0.1, default: 0.035, decimals: 3, unit: "s"),
            .slider("gap", L("Gutter", "间距"), 2...16, default: 8, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        MasonryShuffleDemo(ctx: ctx)
    }
}

private struct MasonryTileInfo {
    let title: LocalizedText
    let caption: LocalizedText
    let symbol: String
    let colors: [Color]
}

private let masonryTiles: [MasonryTileInfo] = [
    MasonryTileInfo(title: L("Coast", "海岸"), caption: L("42 photos", "42 张照片"), symbol: "water.waves", colors: [Palette.sky, Palette.blue]),
    MasonryTileInfo(title: L("Forest", "森林"), caption: L("18 photos", "18 张照片"), symbol: "tree.fill", colors: [Palette.mint, Color(hex: 0x1B9E77)]),
    MasonryTileInfo(title: L("Dunes", "沙丘"), caption: L("27 photos", "27 张照片"), symbol: "sun.max.fill", colors: [Palette.amber, Palette.coral]),
    MasonryTileInfo(title: L("City", "城市"), caption: L("64 photos", "64 张照片"), symbol: "building.2.fill", colors: [Palette.indigo, Palette.violet]),
    MasonryTileInfo(title: L("Peaks", "雪峰"), caption: L("31 photos", "31 张照片"), symbol: "mountain.2.fill", colors: [Color(hex: 0x8E9BB8), Color(hex: 0x4B5878)]),
    MasonryTileInfo(title: L("Bloom", "花季"), caption: L("12 photos", "12 张照片"), symbol: "camera.macro", colors: [Palette.pink, Color(hex: 0xD9358A)]),
]

private enum MasonryLayout {
    static let size = CGSize(width: 316, height: 306)
    static let inset: CGFloat = 12

    /// (column, row, column span, row span) on a 6 × 6 grid; slot 0 is always the hero.
    static let layouts: [[(Int, Int, Int, Int)]] = [
        [(0, 0, 4, 3), (4, 0, 2, 2), (4, 2, 2, 4), (0, 3, 2, 3), (2, 3, 2, 2), (2, 5, 2, 1)],
        [(2, 0, 4, 2), (0, 0, 2, 4), (2, 2, 2, 2), (4, 2, 2, 3), (0, 4, 4, 2), (4, 5, 2, 1)],
        [(2, 2, 4, 4), (0, 0, 3, 2), (3, 0, 3, 2), (0, 2, 2, 2), (0, 4, 2, 1), (0, 5, 2, 1)],
        [(3, 0, 3, 3), (0, 0, 3, 2), (0, 2, 3, 1), (0, 3, 2, 3), (2, 3, 2, 3), (4, 3, 2, 3)],
    ]

    static func rect(layout: Int, slot: Int, gap: CGFloat) -> CGRect {
        let unit = layouts[layout % layouts.count][slot]
        let width: CGFloat = (size.width - inset * 2 - gap * 5) / 6
        let height: CGFloat = (size.height - inset * 2 - gap * 5) / 6
        return CGRect(
            x: inset + CGFloat(unit.0) * (width + gap),
            y: inset + CGFloat(unit.1) * (height + gap),
            width: CGFloat(unit.2) * width + CGFloat(unit.2 - 1) * gap,
            height: CGFloat(unit.3) * height + CGFloat(unit.3 - 1) * gap
        )
    }
}

private struct MasonryShuffleDemo: View {
    let ctx: DemoContext
    @State private var layout = 0
    /// Slot of every tile.
    @State private var slots: [Int] = Array(0..<6)
    @State private var shuffles = 0
    @State private var autoIndex = 0

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Palette.surface
                ForEach(0..<6, id: \.self) { index in
                    tile(index)
                }
            }
            .morphScreen()
            DemoHint(text: L("Tap a tile to feature it", "点一块砖，把它设为主角"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) {
            let order: [Int] = [3, 1, 5, 0, 4, 2]
            feature(order[autoIndex % order.count])
            autoIndex += 1
        }
    }

    private func tile(_ index: Int) -> some View {
        let slot: Int = slots[index]
        let rect: CGRect = MasonryLayout.rect(layout: layout, slot: slot, gap: ctx.cg("gap"))
        return MasonryTile(info: masonryTiles[index], size: rect.size, language: ctx.language)
            .frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle())
            .onTapGesture { feature(index) }
            .position(x: rect.midX, y: rect.midY)
            .animation(
                .spring(response: ctx["response"], dampingFraction: ctx["damping"]).delay(Double(slot) * ctx["stagger"]),
                value: shuffles
            )
            .zIndex(Double(index))
    }

    /// Promote `index` to the hero slot of the next layout and deal the others around it.
    private func feature(_ index: Int) {
        if !ctx.isPreview { Haptics.tap(.light) }
        // The others keep their relative order, shifted by one so every tile moves.
        let others: [Int] = (0..<6).filter { $0 != index }.sorted { slots[$0] < slots[$1] }
        var next: [Int] = slots
        next[index] = 0
        for (rank, tile) in others.enumerated() {
            next[tile] = 1 + (rank + 1) % 5
        }
        layout = (layout + 1) % MasonryLayout.layouts.count
        slots = next
        shuffles += 1
    }
}

private struct MasonryTile: View {
    let info: MasonryTileInfo
    let size: CGSize
    let language: AppLanguage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let roomy: Bool = size.width > 120 && size.height > 80
        let slim: Bool = size.height < 56
        let tall: Bool = roomy && size.height > 110
        ZStack {
            shape.fill(LinearGradient(colors: info.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: info.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(roomy ? 0.95 : 0.9))
                .scaleEffect(tall ? 1.6 : 1, anchor: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .opacity(slim ? 0 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.title, language)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(info.caption, language)
                    .font(.system(size: 11, weight: .medium))
                    .opacity(roomy ? 0.85 : 0)
                    .frame(height: roomy ? nil : 0)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: slim ? .leading : .bottomLeading)
            .padding(.horizontal, 12)
            .padding(.vertical, slim ? 0 : 10)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
    }
}
