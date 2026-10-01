import SwiftUI

extension Effect {
    static let morphChipFilterPanel = Effect(
        id: "morph.chip-filter-panel",
        category: .morph,
        interaction: .tap,
        name: L("Chip to Filter Panel", "筛选胶囊展开面板"),
        summary: L(
            "A filter chip unrolls into a panel anchored to its own corner; applying folds it back and pops a count badge on the chip.",
            "筛选胶囊从自己的左上角铺展成面板；点应用后收回胶囊，并弹出一枚计数角标。"
        ),
        prompt: L(
            "A results screen with a row of 32 pt filter chips. Tapping the Filters chip unrolls it into a 292 × 190 pt panel on one spring (response 0.46 s, damping 0.8): the top-left corner stays pinned, the frame and corner radius (16 → 24 pt) interpolate, the chip label fades in the first 30% and the panel title, six option pills and the action button surface afterwards, each pill 45 ms after the previous, scaling from 80%. The list behind dims 30% and sinks to 97%. Toggling a pill fills it and rolls the live result count on the button. Apply folds the panel back into the chip, which turns solid, widens, and pops a count badge with an overshoot (damping 0.45) while the results blur-replace. Compact, anchored, never loses its origin.",
            "结果页顶部一排 32pt 高的筛选胶囊。点「筛选」，它乘一条弹簧（响应 0.46 秒、阻尼 0.8）铺展成 292 × 190pt 的面板：左上角钉在原位，外框与圆角（16 → 24pt）连续插值，胶囊文字在前 30% 淡出，随后面板标题、六个选项和操作按钮浮现，选项逐个间隔 45 毫秒、从 80% 放大到位。背后的列表压暗 30% 并缩到 97%。点选项即填色，按钮上的结果数实时滚动。点应用，面板收回胶囊，胶囊变为实色并加宽，计数角标带过冲弹出（阻尼 0.45），结果列表以模糊替换刷新。始终看得出它从哪里来。"
        ),
        implementation: L(
            "An Animatable wrapper interpolates one progress; each frame the surface rect is a lerp between the chip and panel rects (same top-left), and the chip label, panel content and each pill are keyed to sub-ranges of that progress. Selection and the applied set are separate states, so dismissing by the scrim discards the draft.",
            "Animatable 包装器对单一进度做插值；每帧把表面矩形在胶囊与面板矩形之间插值（共用左上角），胶囊文字、面板内容和每个选项各自对应进度的一段区间。草稿选择与已应用集合是两份状态，点遮罩关闭即丢弃草稿。"
        ),
        apis: ["Animatable", "spring(response:dampingFraction:)", "contentTransition(.numericText)", "blurReplace", "RoundedRectangle"],
        tags: ["filter", "chip", "panel", "badge", "popover", "筛选", "胶囊", "面板", "角标"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.46, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("stagger", L("Pill stagger", "选项错峰"), 0...0.12, default: 0.045, decimals: 3, unit: "s"),
            .slider("dim", L("Backdrop dim", "背景压暗"), 0...0.6, default: 0.3),
        ]
    ) { ctx in
        ChipFilterDemo(ctx: ctx)
    }
}

private enum ChipFilterLayout {
    static let size = CGSize(width: 316, height: 306)
    static let chipY: CGFloat = 56
    static let chipHeight: CGFloat = 32
    static let panel = CGRect(x: 12, y: 56, width: 292, height: 190)
    static let results: [Int] = [128, 64, 37, 21, 12, 7, 3]

    static func chip(badged: Bool) -> CGRect {
        CGRect(x: 12, y: chipY, width: badged ? 112 : 88, height: chipHeight)
    }
}

private let chipFilterOptions: [LocalizedText] = [
    L("Entire home", "整套房源"), L("Pool", "泳池"), L("Wi-Fi", "无线网络"),
    L("Kitchen", "厨房"), L("Pets", "可带宠物"), L("Parking", "停车位"),
]

private struct ChipFilterDemo: View {
    let ctx: DemoContext
    @State private var open: Bool
    @State private var draft: Set<Int>
    @State private var applied: Set<Int>
    @State private var badgeScale: CGFloat = 1
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _open = State(initialValue: ctx.isStill)
        _draft = State(initialValue: ctx.isStill ? [1, 3] : [])
        _applied = State(initialValue: [])
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        VStack(spacing: 10) {
            screen
            DemoHint(
                text: open ? L("Pick options, then apply", "选几项，再点应用") : L("Tap the Filters chip", "点击「筛选」胶囊"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.85) { autoplayStep() }
    }

    private var screen: some View {
        ZStack(alignment: .topLeading) {
            Palette.surface
            backdrop
                .scaleEffect(open ? 0.97 : 1)
            Color.black
                .opacity(open ? ctx["dim"] : 0)
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .allowsHitTesting(open)
            MorphAnimated(open ? 1.0 : 0.0) { value in
                ChipFilterSurface(
                    progress: CGFloat(value),
                    stagger: ctx.cg("stagger"),
                    draft: draft,
                    appliedCount: applied.count,
                    badgeScale: badgeScale,
                    language: ctx.language,
                    onOpen: { present() },
                    onToggle: { toggle($0) },
                    onReset: { reset() },
                    onApply: { apply() }
                )
            }
        }
        .morphScreen()
    }

    private var backdrop: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: zh ? "京都的住处" : "Stays in Kyoto")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                Text(verbatim: "\(ChipFilterLayout.results[min(applied.count, 6)])")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(-applied.count)))
                    .foregroundStyle(.secondary)
                Text(verbatim: zh ? "个结果" : "results")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 46, alignment: .bottom)
            HStack(spacing: 8) {
                Color.clear.frame(width: ChipFilterLayout.chip(badged: !applied.isEmpty).width, height: 32)
                ChipFilterStaticChip(title: zh ? "价格" : "Price", symbol: "chevron.down")
                ChipFilterStaticChip(title: zh ? "日期" : "Dates", symbol: "chevron.down")
            }
            .padding(.leading, 12)
            .padding(.top, 10)
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    ChipFilterRow(index: (row + applied.count) % 4, zh: zh)
                }
            }
            .id(applied.count)
            .transition(.blurReplace)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .frame(width: ChipFilterLayout.size.width, height: ChipFilterLayout.size.height)
    }

    // MARK: Actions (the autoplay calls the same ones)

    private func present() {
        guard !open else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        draft = applied
        withAnimation(spring) { open = true }
    }

    private func dismiss() {
        guard open else { return }
        withAnimation(spring) { open = false }
    }

    private func toggle(_ index: Int) {
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if draft.contains(index) { draft.remove(index) } else { draft.insert(index) }
        }
    }

    private func reset() {
        guard !draft.isEmpty else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { draft = [] }
    }

    private func apply() {
        guard open else { return }
        let changed: Bool = draft != applied
        if !ctx.isPreview { Haptics.success() }
        withAnimation(spring) {
            open = false
            applied = draft
        }
        guard changed, !draft.isEmpty else { return }
        // The badge lands a beat after the chip has re-formed.
        badgeScale = 0.2
        withAnimation(.spring(response: 0.34, dampingFraction: 0.45).delay(ctx["response"] * 0.55)) { badgeScale = 1 }
    }

    private func autoplayStep() {
        switch autoStep % 7 {
        case 0:
            // Each lap starts from a clean chip.
            if !applied.isEmpty {
                withAnimation(spring) { applied = [] }
            }
            present()
        case 1: toggle(1)
        case 2: toggle(3)
        case 3: apply()
        case 4: present()
        case 5: toggle(4)
        default: apply()
        }
        autoStep += 1
    }
}

/// The morphing surface: a chip at progress 0, the panel at 1.
private struct ChipFilterSurface: View {
    let progress: CGFloat
    let stagger: CGFloat
    let draft: Set<Int>
    let appliedCount: Int
    let badgeScale: CGFloat
    let language: AppLanguage
    let onOpen: () -> Void
    let onToggle: (Int) -> Void
    let onReset: () -> Void
    let onApply: () -> Void

    private var zh: Bool { language == .zh }

    var body: some View {
        let open: CGFloat = MorphMath.unit(progress)
        let chip: CGRect = ChipFilterLayout.chip(badged: appliedCount > 0)
        let panel: CGRect = ChipFilterLayout.panel
        // Same origin for both rects: the top-left corner never moves, even on the overshoot.
        let width: CGFloat = max(MorphMath.lerp(chip.width, panel.width, progress), 20)
        let height: CGFloat = max(MorphMath.lerp(chip.height, panel.height, progress), 20)
        let radius: CGFloat = min(MorphMath.lerp(16, 24, open), height / 2)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let tint: Double = appliedCount > 0 ? Double(1 - MorphMath.smooth(progress, 0.05, 0.45)) : 0
        ZStack(alignment: .topLeading) {
            shape.fill(Palette.elevated)
            shape.fill(Palette.primaryStrong).opacity(tint)
            panelContent
                .frame(width: panel.width, height: panel.height, alignment: .topLeading)
                .opacity(Double(MorphMath.smooth(progress, 0.3, 0.7)))
                .allowsHitTesting(progress > 0.6)
            chipLabel(tinted: appliedCount > 0)
                .frame(width: chip.width, height: chip.height)
                .opacity(Double(1 - MorphMath.smooth(progress, 0, 0.3)))
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.stroke))
        .shadow(color: .black.opacity(0.08 + 0.16 * Double(open)), radius: 4 + 20 * open, y: 2 + 12 * open)
        .contentShape(shape)
        .onTapGesture {
            if progress < 0.5 { onOpen() }
        }
        .offset(x: chip.minX, y: chip.minY)
    }

    private func chipLabel(tinted: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
            Text(verbatim: zh ? "筛选" : "Filters")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
            if tinted {
                Text(verbatim: "\(appliedCount)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: 0x4B57E0))
                    .frame(width: 18, height: 18)
                    .background(Color.white, in: Circle())
                    .scaleEffect(badgeScale)
            }
        }
        .foregroundStyle(tinted ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
    }

    private func reveal(_ step: Int) -> CGFloat {
        let start: CGFloat = 0.38 + CGFloat(step) * stagger * 1.6
        return MorphMath.smooth(progress, start, start + 0.3)
    }

    private var panelContent: some View {
        let count: Int = ChipFilterLayout.results[min(draft.count, 6)]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: zh ? "筛选条件" : "Filters")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: onReset) {
                    Text(verbatim: zh ? "重置" : "Reset")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(draft.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Palette.indigo))
                        .frame(height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 24)
            .padding(.bottom, 12)
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { column in
                            pill(row * 3 + column)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Button(action: onApply) {
                HStack(spacing: 5) {
                    Text(verbatim: zh ? "查看" : "Show")
                    Text(verbatim: "\(count)")
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(count)))
                    Text(verbatim: zh ? "个结果" : "stays")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Palette.primaryStrong, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(Double(reveal(6)))
            .offset(y: (1 - reveal(6)) * 10)
        }
        .padding(14)
    }

    private func pill(_ index: Int) -> some View {
        let on: Bool = draft.contains(index)
        let shown: CGFloat = reveal(index)
        return Button { onToggle(index) } label: {
            Text(chipFilterOptions[index], language)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(on ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background {
                    ZStack {
                        Capsule().fill(Color.primary.opacity(0.07))
                        Capsule().fill(Palette.primaryStrong).opacity(on ? 1 : 0)
                    }
                }
                .scaleEffect(on ? 1.0 : 0.97)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(Double(shown))
        .scaleEffect(0.8 + 0.2 * shown)
    }
}

private struct ChipFilterStaticChip: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: title)
                .font(.system(size: 13, weight: .semibold))
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Palette.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.stroke))
    }
}

private struct ChipFilterRow: View {
    let index: Int
    let zh: Bool

    private static let names: [LocalizedText] = [
        L("Cedar Loft", "雪松阁楼"), L("Kamo Riverside House", "鸭川河畔町屋"),
        L("Bamboo Courtyard", "竹影小院"), L("Lantern Machiya", "灯笼町屋"),
    ]
    private static let prices: [String] = ["$128", "$214", "$96", "$172"]
    private static let ratings: [String] = ["4.9", "4.8", "4.7", "4.9"]
    private static let tints: [[Color]] = [
        [Palette.amber, Palette.coral], [Palette.sky, Palette.blue],
        [Palette.mint, Palette.green], [Palette.pink, Palette.violet],
    ]
    private static let symbols: [String] = ["house.fill", "water.waves", "leaf.fill", "lamp.table.fill"]

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: ChipFilterRow.tints[index], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: ChipFilterRow.symbols[index])
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(ChipFilterRow.names[index], zh ? .zh : .en)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Palette.amber)
                    Text(verbatim: ChipFilterRow.ratings[index])
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(verbatim: ChipFilterRow.prices[index])
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
        }
        .padding(8)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
