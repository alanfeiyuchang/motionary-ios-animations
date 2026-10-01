import SwiftUI

extension Effect {
    static let navigationCardStackDrawer = Effect(
        id: "navigation.card-stack-drawer",
        category: .navigation,
        interaction: .tap,
        name: L("Card-Stack Drawer", "卡片堆抽屉"),
        summary: L(
            "Opening the drawer does not slide a panel in: every screen of the app steps back into a tilted stack of cards, and you pick the one to go to.",
            "打开抽屉时并没有面板滑入：应用的每个页面都后退成一叠倾斜的卡片，由你挑一张进去。"
        ),
        prompt: L(
            "An app with three screens. Tapping the menu button shrinks the current screen to 62%, moves it 96 pt right and turns it 18° about the vertical axis with perspective; the other screens, hidden behind it, fan out to its left, each 32 pt apart and 7% smaller, starting 50 ms later than the one in front, all on one spring (response 0.5 s, damping 0.78). Corners round to 40 pt, a soft shadow appears, and the menu labels on the uncovered left side slide in 14 pt with the same stagger. Tapping any card, or its label, first pulls that card 46 pt out of the stack in 0.16 s, then it comes to the front and grows back to full screen while the others tuck in behind. Medium haptic on open, light on pick. Spatial: the menu is the app seen from a step back.",
            "一个有三个页面的应用。点击菜单按钮，当前页面缩到 62%、右移 96 pt，并绕竖轴带透视转过 18°；藏在身后的其他页面向左依次扇开，每张相隔 32 pt、再小 7%，比前一张晚 50 毫秒出发，共用一根弹簧（响应 0.5 秒、阻尼 0.78）。圆角变为 40 pt，出现柔和投影，左侧露出的菜单文字以同样的错峰滑入 14 pt。点击任意卡片或对应文字，它先在 0.16 秒内从卡堆抽出 46 pt，再来到最前并放大回全屏，其余收到身后。打开时中等触感，选中时轻触感。菜单就是退后一步看到的应用本身。"
        ),
        implementation: L(
            "An order array gives every screen a depth; scale, offset, rotation3DEffect and zIndex are functions of (open, depth), animated by per-card animation(_:value:) springs delayed by depth. Picking runs two phases: a short pull-out, then the reorder and close in one spring.",
            "一个顺序数组为每个页面给出深度；缩放、偏移、rotation3DEffect 与 zIndex 都是（是否打开，深度）的函数，由每张卡片各自按深度延迟的 animation(_:value:) 弹簧驱动。选中分两段：先短促抽出，再在同一根弹簧里完成重排与收起。"
        ),
        apis: ["rotation3DEffect(_:axis:anchor:perspective:)", "animation(_:value:)", "zIndex", "scaleEffect", "Task.sleep"],
        tags: ["drawer", "card stack", "menu", "3d", "抽屉", "卡片堆", "菜单", "三维"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.78),
            .slider("tilt", L("Tilt", "倾斜角度"), 0...35, default: 18, decimals: 0, unit: "°"),
            .slider("fan", L("Fan spacing", "扇开间距"), 8...44, default: 32, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        CardStackDrawerDemo(ctx: ctx)
    }
}

private struct StackScreen {
    let symbol: String
    let title: LocalizedText
    let colors: [Color]
}

private let stackScreens: [StackScreen] = [
    StackScreen(symbol: "house.fill", title: L("Home", "首页"), colors: [Palette.indigo, Palette.violet]),
    StackScreen(symbol: "chart.bar.fill", title: L("Stats", "统计"), colors: [Palette.mint, Palette.sky]),
    StackScreen(symbol: "person.fill", title: L("Profile", "我的"), colors: [Palette.pink, Palette.coral]),
]

private enum StackMetrics {
    static let frame = CGSize(width: 290, height: 284)
}

private struct CardStackDrawerDemo: View {
    let ctx: DemoContext
    @State private var open: Bool
    /// Screen indices from front to back.
    @State private var order: [Int] = [0, 1, 2]
    @State private var lifted: Int?
    @State private var pickTask: Task<Void, Never>?
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _open = State(initialValue: ctx.isStill)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                LinearGradient(
                    colors: [Color.adaptive(light: 0xDCDFEE, dark: 0x14151D), Color.adaptive(light: 0xC9CDE2, dark: 0x0B0C11)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                menu
                ForEach(0..<stackScreens.count, id: \.self) { index in
                    card(index)
                }
            }
            .frame(width: StackMetrics.frame.width, height: StackMetrics.frame.height)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
            DemoHint(text: L("Tap the menu button, then pick a card", "点击菜单按钮，再挑一张卡片"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoplayStep() }
        .onDisappear { pickTask?.cancel() }
    }

    // MARK: Menu

    private var menu: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<stackScreens.count, id: \.self) { index in
                let active: Bool = order.first == index
                HStack(spacing: 8) {
                    Image(systemName: stackScreens[index].symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(active ? stackScreens[index].colors[0] : Color.secondary)
                        .frame(width: 20)
                    Text(stackScreens[index].title, ctx.language)
                        .font(.subheadline.weight(active ? .bold : .medium))
                        .foregroundStyle(active ? Color.primary : Color.secondary)
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(Color.primary.opacity(active ? 0.08 : 0), in: Capsule())
                .contentShape(Rectangle())
                .onTapGesture { pick(index) }
                .opacity(open ? 1 : 0)
                .offset(x: open ? 0 : -14)
                .animation(spring.delay(open ? 0.06 + Double(index) * 0.05 : 0), value: open)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 14)
        .allowsHitTesting(open)
    }

    // MARK: Cards

    private func card(_ index: Int) -> some View {
        let depth: Int = order.firstIndex(of: index) ?? 0
        let d: CGFloat = CGFloat(depth)
        let pulled: Bool = lifted == index
        let scale: CGFloat = open ? 0.62 - 0.07 * d + (pulled ? 0.03 : 0) : (depth == 0 ? 1 : 0.92)
        // The front card sits furthest right; deeper cards peek out from behind its left edge.
        let x: CGFloat = open ? 96 - d * ctx.cg("fan") - (pulled ? 46 : 0) : 0
        let radius: CGFloat = open ? 40 : 32
        return StackScreenView(screen: stackScreens[index], language: ctx.language, onMenu: { toggle() })
            .frame(width: StackMetrics.frame.width, height: StackMetrics.frame.height)
            .background(Palette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                // Cards deeper in the stack sit in shade.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.black.opacity(open ? 0.14 * Double(depth) : 0))
                    .allowsHitTesting(false)
            }
            .overlay {
                if open {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { pick(index) }
                }
            }
            .shadow(color: Color.black.opacity(open ? 0.28 : 0), radius: 18, x: -8, y: 10)
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(open ? -ctx["tilt"] : 0), axis: (x: 0, y: 1, z: 0), anchor: .center, perspective: 0.6)
            .offset(x: x)
            .opacity(open || depth == 0 ? 1 : 0)
            .zIndex(Double(stackScreens.count - depth))
            .animation(spring.delay(open ? Double(depth) * 0.05 : 0), value: open)
            .animation(spring, value: order)
            .animation(.easeOut(duration: 0.16), value: lifted)
    }

    // MARK: Actions

    private func toggle() {
        guard lifted == nil else { return }
        if !ctx.isPreview { Haptics.tap(.medium) }
        open.toggle()
    }

    /// Pulls the card out of the stack, then brings it to the front and closes the drawer.
    private func pick(_ index: Int) {
        guard open, lifted == nil else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        if order.first == index {
            open = false
            return
        }
        lifted = index
        pickTask?.cancel()
        pickTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            lifted = nil
            order = [index] + order.filter { $0 != index }
            open = false
        }
    }

    private func autoplayStep() {
        if open {
            pick(order[1 + (autoStep / 2) % 2])
        } else {
            toggle()
        }
        autoStep += 1
    }
}

// MARK: - One screen of the app

private struct StackScreenView: View {
    let screen: StackScreen
    let language: AppLanguage
    let onMenu: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 38, height: 38)
                    .background(Color.primary.opacity(0.07), in: Circle())
                    .contentShape(Circle())
                    .onTapGesture(perform: onMenu)
                Text(screen.title, language)
                    .font(.title3.weight(.bold))
                Spacer(minLength: 0)
            }
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: screen.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 104)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: screen.symbol)
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(14)
                }
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(screen.colors[row % screen.colors.count].opacity(0.28))
                        .frame(width: 34, height: 34)
                    PlaceholderLines(count: 2, color: Color.primary.opacity(0.1))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}
