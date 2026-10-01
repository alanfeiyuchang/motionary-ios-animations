import SwiftUI

extension Effect {
    static let iconsGridList = Effect(
        id: "icons.grid-list",
        category: .icons,
        interaction: .tap,
        name: L("Grid ↔ List", "宫格 ↔ 列表"),
        summary: L("Four squares stretch into four rows one after another, and the content below rearranges with the very same motion.", "四个方块依次拉伸成四行，下方的内容以完全相同的动作重新排布。"),
        prompt: L(
            "A toolbar button holds a 2 × 2 grid glyph; below it four coloured tiles sit in the same 2 × 2 layout. On tap each square travels to its own row and stretches to full width while flattening into a bar, one after another 50 ms apart in reading order, on a spring (response 0.42 s, damping 0.68) so each bar overshoots its width slightly and settles like jelly. Corner radii ease from square to pill. The four tiles perform the identical move at large scale: their icons shrink to 70% and slide to the leading edge, and two text lines fade in beside them. Tapping again reverses it, the last row leaving first, and the bars pull back into squares. The button dips to 90% on each tap with a light haptic. Orderly, elastic and perfectly in sync.",
            "工具栏按钮里是一个2 × 2宫格图标，下方四块彩色卡片以同样的2 × 2方式排列。点击后每个方块移向各自的行，同时拉伸到全宽并压扁成横条，按阅读顺序依次出发、间隔50毫秒，由弹簧（响应0.42秒、阻尼0.68）驱动，横条宽度略微过冲后像果冻般落定，圆角从方角过渡到胶囊。四块卡片以大尺寸做出完全相同的动作：卡片图标缩到70%并滑到左侧，两行文字在旁边淡入。再次点击则反向进行，最后一行先走，横条收回成方块。每次点击按钮下压到90%，配轻触感。有序、有弹性、完全同步。"
        ),
        implementation: L(
            "One geometry function returns each cell's rect for a progress value by interpolating between its grid rect and its list rect; the glyph and the tiles both call it, at 28 pt and 196 pt. Progress per cell is an analytic spring of the time since the tap, delayed by the stagger.",
            "同一个几何函数按进度在每格的宫格矩形与列表矩形之间插值；图标与卡片都调用它，尺寸分别为28 pt与196 pt。每格的进度是“点击后秒数”的解析弹簧，并按间隔错开。"
        ),
        apis: ["TimelineView(.animation)", "RoundedRectangle", "frame(width:height:)", "position(x:y:)", "scaleEffect"],
        tags: ["grid", "list", "layout", "toggle", "view mode", "宫格", "列表", "布局", "切换", "视图模式"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.7, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.68),
            .slider("stagger", L("Stagger", "错开间隔"), 0...0.12, default: 0.05, unit: "s"),
        ]
    ) { ctx in
        IconsGridListDemo(ctx: ctx)
    }
}

private enum IconsGridGeometry {
    /// The rect of cell `index` inside a square of `side`, for `p` between 0 (2 × 2 grid) and 1 (four rows).
    static func rect(_ index: Int, p: Double, side: CGFloat, gap: CGFloat, rowGap: CGFloat) -> CGRect {
        let cell: CGFloat = (side - gap) / 2
        let grid = CGRect(x: CGFloat(index % 2) * (cell + gap), y: CGFloat(index / 2) * (cell + gap), width: cell, height: cell)
        let row: CGFloat = (side - rowGap * 3) / 4
        let list = CGRect(x: 0, y: CGFloat(index) * (row + rowGap), width: side, height: row)
        let k: CGFloat = CGFloat(p)
        return CGRect(
            x: grid.minX + (list.minX - grid.minX) * k,
            y: grid.minY + (list.minY - grid.minY) * k,
            width: max(grid.width + (list.width - grid.width) * k, 1),
            height: max(grid.height + (list.height - grid.height) * k, 1)
        )
    }
}

private struct IconsGridListDemo: View {
    let ctx: DemoContext
    /// On = list.
    @State private var play = IconsPlayhead(isOn: false)
    @State private var presses: Int = 0

    private var duration: Double { 3 * ctx["stagger"] + ctx["response"] * 1.6 }

    var body: some View {
        let isList: Bool = play.isOn
        IconsTimeline(preview: ctx.isPreview) { date in
            let t: Double = play.elapsed(at: date)
            let progress: [Double] = (0..<4).map { amount($0, t: t) }
            VStack(spacing: 12) {
                HStack {
                    Text(isList ? L("List", "列表") : L("Grid", "宫格"), ctx.language)
                        .font(.headline)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.3), value: isList)
                    Spacer()
                    glyphButton(progress)
                }
                .frame(width: IconsGridTiles.side)
                IconsGridTiles(progress: progress)
                DemoHint(text: L("Tap to switch the layout", "点击切换布局"), ctx: ctx)
            }
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { toggle() }
    }

    private func amount(_ index: Int, t: Double) -> Double {
        let response: Double = ctx["response"]
        let damping: Double = ctx["damping"]
        let stagger: Double = ctx["stagger"]
        if play.isOn {
            return IconsCurve.spring(t - Double(index) * stagger, response: response, damping: damping)
        }
        return 1 - IconsCurve.spring(t - Double(3 - index) * stagger, response: response, damping: damping)
    }

    private func glyphButton(_ progress: [Double]) -> some View {
        let side: CGFloat = 28
        return ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { index in
                let rect: CGRect = IconsGridGeometry.rect(index, p: progress[index], side: side, gap: 6, rowGap: 3.5)
                RoundedRectangle(cornerRadius: min(rect.height, rect.width) * 0.3, style: .continuous)
                    .fill(Palette.primary)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .frame(width: side, height: side)
        .frame(width: 58, height: 58)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: presses) { content, value in
            content.scaleEffect(value)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0.9, duration: 0.09)
                SpringKeyframe(1.0, duration: 0.45, spring: Spring(response: 0.28, dampingRatio: 0.5))
            }
        }
    }

    private func toggle() {
        play.toggle(onDuration: duration, offDuration: duration)
        presses += 1
        Haptics.tap(.light)
    }
}

private struct IconsGridTiles: View {
    let progress: [Double]

    static let side: CGFloat = 196
    private static let symbols: [String] = ["photo.fill", "music.note", "doc.text.fill", "map.fill"]
    private static let colors: [[Color]] = [
        [Color(hex: 0x7C83FF), Color(hex: 0x5A54E0)],
        [Color(hex: 0xFF8CBE), Color(hex: 0xF04E93)],
        [Color(hex: 0xFFC45C), Color(hex: 0xFF8A2A)],
        [Color(hex: 0x5BE3C0), Color(hex: 0x14B893)],
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { index in
                tile(index)
            }
        }
        .frame(width: Self.side, height: Self.side)
    }

    private func tile(_ index: Int) -> some View {
        let p: Double = progress[index]
        let shown: Double = IconsCurve.unit(p)
        let rect: CGRect = IconsGridGeometry.rect(index, p: p, side: Self.side, gap: 12, rowGap: 10)
        let shape = RoundedRectangle(cornerRadius: CGFloat(IconsCurve.mix(24, 14, shown)), style: .continuous)
        // The icon slides from the middle of the tile to its leading edge.
        let iconX: CGFloat = CGFloat(IconsCurve.mix(Double(rect.width) / 2, 24, shown))
        return shape
            .fill(LinearGradient(colors: Self.colors[index], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                shape.fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)], startPoint: .top, endPoint: .center))
            }
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(.white.opacity(0.95)).frame(width: 78, height: 7)
                    Capsule().fill(.white.opacity(0.55)).frame(width: 48, height: 6)
                }
                .offset(x: 50 + CGFloat(18 * (1 - shown)))
                .opacity(IconsCurve.unit((p - 0.45) * 2.2))
            }
            .overlay {
                Image(systemName: Self.symbols[index])
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(CGFloat(IconsCurve.mix(1, 0.7, shown)))
                    .position(x: iconX, y: rect.height / 2)
            }
            .clipShape(shape)
            .frame(width: rect.width, height: rect.height)
            .shadow(color: Self.colors[index][1].opacity(0.3), radius: 8, y: 5)
            .position(x: rect.midX, y: rect.midY)
    }
}
