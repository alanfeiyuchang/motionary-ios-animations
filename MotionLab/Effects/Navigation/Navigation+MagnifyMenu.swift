import SwiftUI

extension Effect {
    static let navigationMagnifyMenu = Effect(
        id: "navigation.magnify-menu",
        category: .navigation,
        interaction: .gesture,
        name: L("Fisheye Pull-Down Menu", "鱼眼下拉菜单"),
        summary: L(
            "Press the button, drag down through the menu and let go: rows swell under your finger like a lens passing over them, and the one you release on is chosen.",
            "按住按钮，向下拖过菜单再松手：手指经过的行像被透镜扫过一样鼓起来，松手时停在哪一行就选中哪一行。"
        ),
        prompt: L(
            "A pull-down menu of six 30 pt rows under a pill button, operated in one touch. Touch-down opens the panel from the button (scale 40% to 100% from its top-leading corner, spring response 0.4 s, damping 0.75). As the finger travels down, each row's icon and label scale by a raised-cosine falloff of its distance to the finger: 135% directly under it, back to 100% at 70 pt away. Row heights grow with the scale, so neighbours are pushed apart, and the list is re-anchored every frame so the point under the finger never drifts; the panel's edges breathe with it. The row under the finger gets a tinted highlight and a selection tick on each change. Releasing chooses it: the panel collapses back into the button and the button's icon and label blur-replace. Tapping works too.",
            "胶囊按钮下方是一个六行、每行 30 pt 的下拉菜单，一次触摸完成操作。手指按下，面板从按钮处展开（以左上角为锚点由 40% 放大到 100%，弹簧响应 0.4 秒、阻尼 0.75）。手指下移时，每行的图标和文字按它到手指距离的升余弦衰减放大：正下方 135%，70 pt 之外回到 100%。行高随缩放变大，邻居被挤开；列表每帧重新锚定，手指下的那一点始终不漂移，面板边缘随之起伏。手指所在的行带着色高亮，每换一行一次选择触感。松手即选中：面板收回按钮，按钮的图标与文字以模糊替换更新。点击同样可用。"
        ),
        implementation: L(
            "One DragGesture(minimumDistance: 0) opens the menu and reports the finger's y. Row scales come from a cosine falloff, row tops from the running sum of scaled heights, and the whole stack is shifted by the difference between the finger's base position and its mapped position, which keeps the lens under the finger.",
            "一个 DragGesture(minimumDistance: 0) 负责打开菜单并上报手指的纵坐标。各行缩放来自余弦衰减，行顶位置是缩放后行高的累加，整组再按「手指的原始位置与映射后位置之差」平移，从而让透镜始终停在手指下方。"
        ),
        apis: ["DragGesture(minimumDistance:)", "scaleEffect(_:anchor:)", "interactiveSpring", "transition(.blurReplace)", "UISelectionFeedbackGenerator"],
        tags: ["pull-down menu", "fisheye", "magnify", "drag to select", "下拉菜单", "鱼眼", "放大", "拖动选择"],
        params: [
            .slider("magnify", L("Magnification", "放大倍数"), 1.0...1.7, default: 1.35),
            .slider("radius", L("Lens radius", "透镜半径"), 30...140, default: 70, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.8, default: 0.4, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.75),
        ]
    ) { ctx in
        MagnifyMenuDemo(ctx: ctx)
    }
}

private struct MagnifyItem {
    let symbol: String
    let title: LocalizedText
    let color: Color
}

private let magnifyItems: [MagnifyItem] = [
    MagnifyItem(symbol: "tray.fill", title: L("Inbox", "收件箱"), color: Palette.blue),
    MagnifyItem(symbol: "star.fill", title: L("Starred", "星标"), color: Palette.amber),
    MagnifyItem(symbol: "clock.fill", title: L("Later", "稍后处理"), color: Palette.violet),
    MagnifyItem(symbol: "archivebox.fill", title: L("Archive", "归档"), color: Palette.mint),
    MagnifyItem(symbol: "person.2.fill", title: L("Shared", "共享"), color: Palette.pink),
    MagnifyItem(symbol: "trash.fill", title: L("Trash", "废纸篓"), color: Palette.red),
]

private enum MagnifyMetrics {
    static let frame = CGSize(width: 300, height: 284)
    static let button = CGRect(x: 16, y: 16, width: 168, height: 40)
    static let panelOrigin = CGPoint(x: 16, y: 68)
    static let panelWidth: CGFloat = 204
    static let row: CGFloat = 30
    static let inset: CGFloat = 6
    static var listHeight: CGFloat { row * CGFloat(magnifyItems.count) }
}

/// Fisheye layout of the rows for a finger position (in the list's resting coordinates).
private struct MagnifyLayout {
    var scales: [CGFloat] = []
    var tops: [CGFloat] = []
    var total: CGFloat = 0

    init(focus: CGFloat?, magnify: CGFloat, radius: CGFloat) {
        let h: CGFloat = MagnifyMetrics.row
        for index in magnifyItems.indices {
            guard let focus else {
                scales.append(1)
                continue
            }
            let distance: CGFloat = abs((CGFloat(index) + 0.5) * h - focus)
            let falloff: CGFloat = distance < radius ? 0.5 * (1 + cos(.pi * distance / radius)) : 0
            scales.append(1 + (magnify - 1) * falloff)
        }
        var y: CGFloat = 0
        for scale in scales {
            tops.append(y)
            y += h * scale
        }
        total = y
        guard let focus else { return }
        // Keep the point under the finger where it is: map it through the stretched layout and shift back.
        let clamped: CGFloat = min(max(focus, 0), MagnifyMetrics.listHeight - 0.001)
        let index: Int = Int(clamped / h)
        let mapped: CGFloat = tops[index] + (clamped - CGFloat(index) * h) * scales[index]
        let shift: CGFloat = clamped - mapped
        tops = tops.map { $0 + shift }
    }
}

private struct MagnifyMenuDemo: View {
    let ctx: DemoContext
    @State private var open: Bool
    @State private var focus: CGFloat?
    @State private var selection = 0
    @State private var lastIndex: Int?
    @State private var tracking = false
    @State private var startedOpen = false
    @State private var startedOnButton = false
    @State private var sweepTask: Task<Void, Never>?
    @State private var autoStep = 0
    /// True while the scripted sweep runs, so its delayed steps never buzz.
    @State private var simulating = false

    private var silent: Bool { ctx.isPreview || simulating }

    init(ctx: DemoContext) {
        self.ctx = ctx
        _open = State(initialValue: ctx.isStill)
        _focus = State(initialValue: ctx.isStill ? MagnifyMetrics.row * 2.5 : nil)
        _selection = State(initialValue: 0)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    private var focusedIndex: Int? {
        guard let focus, focus >= 0, focus < MagnifyMetrics.listHeight else { return nil }
        return Int(focus / MagnifyMetrics.row)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                messages
                button
                    .offset(x: MagnifyMetrics.button.minX, y: MagnifyMetrics.button.minY)
                panel
                    .offset(x: MagnifyMetrics.panelOrigin.x, y: MagnifyMetrics.panelOrigin.y)
                touchRegion
            }
            .frame(width: MagnifyMetrics.frame.width, height: MagnifyMetrics.frame.height, alignment: .topLeading)
            .background(Palette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
            .coordinateSpace(.named("magnifyMenu"))
            DemoHint(text: L("Press the button, drag down, release on a row", "按住按钮向下拖，在某一行松手"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.3) { sweep() }
        .onDisappear { sweepTask?.cancel() }
    }

    // MARK: Content behind

    private var messages: some View {
        let item: MagnifyItem = magnifyItems[selection]
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 10) {
                    Circle()
                        .fill(item.color.opacity(index == 0 ? 0.9 : 0.3))
                        .frame(width: 30, height: 30)
                    PlaceholderLines(count: 2, color: Color.primary.opacity(0.1))
                }
                .padding(.horizontal, 12)
                .frame(height: 54)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 72)
        .frame(width: MagnifyMetrics.frame.width, alignment: .topLeading)
    }

    // MARK: Button

    private var button: some View {
        let item: MagnifyItem = magnifyItems[selection]
        return HStack(spacing: 8) {
            Image(systemName: item.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .background(item.color.gradient, in: Circle())
            Text(item.title, ctx.language)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(open ? 180 : 0))
        }
        .id(selection)
        .transition(.blurReplace)
        .padding(.leading, 7)
        .padding(.trailing, 13)
        .frame(width: MagnifyMetrics.button.width, height: MagnifyMetrics.button.height)
        .background(Color.primary.opacity(open ? 0.12 : 0.07), in: Capsule())
        .scaleEffect(open ? 0.97 : 1)
    }

    // MARK: Panel

    private var panel: some View {
        let layout = MagnifyLayout(focus: focus, magnify: ctx.cg("magnify"), radius: ctx.cg("radius"))
        let top: CGFloat = layout.tops.first ?? 0
        let inset: CGFloat = MagnifyMetrics.inset
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack(alignment: .topLeading) {
            shape
                .fill(Color.clear)
                .demoGlass(shape, material: .regularMaterial)
                .overlay(shape.strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.22), radius: 20, y: 10)
                .frame(width: MagnifyMetrics.panelWidth, height: layout.total + inset * 2)
                .offset(y: top - inset)
            ForEach(0..<magnifyItems.count, id: \.self) { index in
                row(index, scale: layout.scales[index])
                    .offset(y: layout.tops[index])
            }
        }
        .frame(width: MagnifyMetrics.panelWidth, height: MagnifyMetrics.listHeight, alignment: .topLeading)
        .scaleEffect(open ? 1 : 0.4, anchor: .topLeading)
        .opacity(open ? 1 : 0)
        .blur(radius: open ? 0 : 5)
        .allowsHitTesting(false)
    }

    private func row(_ index: Int, scale: CGFloat) -> some View {
        let item: MagnifyItem = magnifyItems[index]
        let focused: Bool = focusedIndex == index
        return HStack(spacing: 9) {
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(focused ? Color.white : item.color)
                .frame(width: 22, height: 22)
                .background(item.color.opacity(focused ? 1 : 0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(item.title, ctx.language)
                .font(.system(size: 14, weight: focused ? .semibold : .medium))
                .foregroundStyle(Color.primary)
            Spacer(minLength: 0)
            if selection == index {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: (MagnifyMetrics.panelWidth - 12) / scale, height: MagnifyMetrics.row)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: MagnifyMetrics.panelWidth - 12, height: MagnifyMetrics.row * scale, alignment: .topLeading)
        .background(item.color.opacity(focused ? 0.16 : 0), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .padding(.horizontal, 6)
    }

    // MARK: Touch

    /// One gesture for the whole interaction: press the button, travel through the rows, release.
    private var touchRegion: some View {
        let height: CGFloat = open ? MagnifyMetrics.frame.height : MagnifyMetrics.button.maxY + 8
        let width: CGFloat = open ? MagnifyMetrics.frame.width : MagnifyMetrics.button.maxX + 8
        return Color.clear
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("magnifyMenu"))
                    .onChanged(touchChanged)
                    .onEnded(touchEnded)
            )
    }

    private func touchChanged(_ value: DragGesture.Value) {
        if !tracking {
            tracking = true
            sweepTask?.cancel()
            simulating = false
            startedOpen = open
            startedOnButton = MagnifyMetrics.button.insetBy(dx: -8, dy: -8).contains(value.startLocation)
            if !open && startedOnButton { setOpen(true) }
        }
        guard open else { return }
        let moved: CGFloat = hypot(value.translation.width, value.translation.height)
        // A press that began on the button only starts picking once it has actually travelled.
        if startedOnButton && moved < 6 { return }
        let x: CGFloat = value.location.x - MagnifyMetrics.panelOrigin.x
        let y: CGFloat = value.location.y - MagnifyMetrics.panelOrigin.y
        let inside: Bool = x > -20 && x < MagnifyMetrics.panelWidth + 40 && y >= 0 && y < MagnifyMetrics.listHeight
        setFocus(inside ? y : nil)
    }

    private func touchEnded(_ value: DragGesture.Value) {
        tracking = false
        let moved: CGFloat = hypot(value.translation.width, value.translation.height)
        if let index = focusedIndex {
            choose(index)
        } else if startedOnButton && moved < 6 {
            if startedOpen { setOpen(false) }
        } else {
            setFocus(nil)
            setOpen(false)
        }
    }

    private func setFocus(_ value: CGFloat?) {
        let wasNil: Bool = focus == nil
        withAnimation(wasNil || value == nil ? .spring(response: 0.3, dampingFraction: 0.8) : .interactiveSpring(response: 0.14, dampingFraction: 0.86)) {
            focus = value
        }
        let index: Int? = focusedIndex
        if index != lastIndex {
            lastIndex = index
            if index != nil, !silent { Haptics.selection() }
        }
    }

    private func setOpen(_ value: Bool) {
        if !silent { Haptics.tap(.light) }
        withAnimation(value ? spring : .spring(response: 0.32, dampingFraction: 0.9)) { open = value }
    }

    private func choose(_ index: Int) {
        if !silent { Haptics.tap(.medium) }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            selection = index
            open = false
        }
        // The lens relaxes a moment later, so the chosen row is still large while the panel leaves.
        withAnimation(.easeOut(duration: 0.2).delay(0.2)) { focus = nil }
        lastIndex = nil
    }

    // MARK: Autoplay

    /// Simulates the whole one-touch gesture: open, travel down to a row, release.
    private func sweep() {
        sweepTask?.cancel()
        let target: Int = [3, 1, 4, 0, 5, 2][autoStep % 6]
        autoStep += 1
        let destination: CGFloat = (CGFloat(target) + 0.5) * MagnifyMetrics.row
        simulating = true
        setOpen(true)
        sweepTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))
            let steps: Int = 14
            for step in 0...steps {
                guard !Task.isCancelled else { return }
                let t: CGFloat = CGFloat(step) / CGFloat(steps)
                let eased: CGFloat = t * t * (3 - 2 * t)
                setFocus(4 + (destination - 4) * eased)
                try? await Task.sleep(for: .seconds(0.045))
            }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            choose(target)
            simulating = false
        }
    }
}
