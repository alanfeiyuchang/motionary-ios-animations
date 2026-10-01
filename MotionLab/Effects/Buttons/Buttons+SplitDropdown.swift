import SwiftUI

extension Effect {
    static let buttonsSplitDropdown = Effect(
        id: "buttons.split-dropdown",
        category: .buttons,
        interaction: .tap,
        name: L("Split Button Menu", "分体按钮菜单"),
        summary: L(
            "The caret half of a split button grows into a menu; picking an option rolls the primary label.",
            "分体按钮的箭头一侧长成菜单，选中后主按钮的文字滚动切换。"
        ),
        prompt: L(
            "A 264 × 54 pt green split button: a wide primary segment with icon and label, a 2 pt seam, and a 50 pt caret segment. Tapping the caret flips the chevron 180° and the menu panel grows out of the caret itself: from the caret's exact frame it springs to a 264 × 150 pt card 8 pt below the button (response 0.42 s, damping 0.78), corners relaxing from 10 to 18 pt, while three option rows fade down 8 pt out of a 4 pt blur, staggered 45 ms apart. A soft highlight and the checkmark slide between rows with matched geometry. Choosing a row ticks a selection haptic, the panel collapses back into the caret, and the primary label rolls: the old one leaves upward into a 6 pt blur as the new one rises from below. Tapping the primary segment presses it with a quick sheen.",
            "264×54pt 的绿色分体按钮：主操作段带图标与文字，隔着 2pt 接缝是 50pt 的箭头段。点击后箭头翻转 180°，菜单面板从箭头段里长出来：自原位出发，以弹簧（响应 0.42 秒、阻尼 0.78）展开成按钮下方 8pt 处的 264×150pt 卡片，圆角从 10pt 放松到 18pt，三行选项由 4pt 模糊中下移 8pt 淡入，各错开 45 毫秒。高亮底与对勾以几何匹配在行间滑动。选中一行时给出选择触感，面板收回箭头段，主文字滚动：旧文字上滑入 6pt 模糊，新文字自下升起。点击主操作段则有按压与一道光泽。"
        ),
        implementation: L(
            "The panel is one view whose frame, offset and corner radius switch between the caret's rect and the menu's rect inside a spring, with the rows laid out at full size and clipped; the row highlight and the check use matchedGeometryEffect. The primary label is keyed by the selection and swapped with a custom blur-roll Transition.",
            "面板是同一个视图，尺寸、偏移与圆角在弹簧中于箭头段矩形与菜单矩形之间切换，各行始终按完整尺寸布局并被裁剪；行高亮与对勾使用 matchedGeometryEffect。主按钮文字以选中项为 id，通过自定义的模糊滚动 Transition 切换。"
        ),
        apis: ["matchedGeometryEffect", "Transition", "UnevenRoundedRectangle", "spring(response:dampingFraction:)", "keyframeAnimator"],
        tags: ["split button", "dropdown", "menu", "caret", "分体按钮", "下拉菜单", "展开", "选项"],
        params: [
            .slider("stagger", L("Row stagger", "行间错峰"), 0...0.1, default: 0.045, decimals: 3, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.8, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.78),
            .slider("blur", L("Label roll blur", "文字滚动模糊"), 0...12, default: 6, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        ButtonSplitDropdownDemo(ctx: ctx)
    }
}

private struct ButtonSplitOption {
    let symbol: String
    let title: LocalizedText
    let detail: LocalizedText
}

private struct ButtonSplitDropdownDemo: View {
    let ctx: DemoContext
    @Namespace private var namespace
    @State private var open: Bool
    @State private var selection = 0
    @State private var primaryTaps = 0
    @State private var closeTask: Task<Void, Never>?
    @State private var introTask: Task<Void, Never>?

    private static let width: CGFloat = 264
    private static let height: CGFloat = 54
    private static let caretWidth: CGFloat = 50
    private static let rowHeight: CGFloat = 46
    private static let menuHeight: CGFloat = rowHeight * 3 + 12
    private static let fill = LinearGradient(colors: [Color(hex: 0x1F9D57), Color(hex: 0x17803F)], startPoint: .top, endPoint: .bottom)

    private let options: [ButtonSplitOption] = [
        ButtonSplitOption(symbol: "arrow.triangle.merge", title: L("Merge commit", "合并提交"), detail: L("Keep every commit", "保留全部提交")),
        ButtonSplitOption(symbol: "square.stack.3d.down.right.fill", title: L("Squash & merge", "压缩合并"), detail: L("Combine into one", "压成一个提交")),
        ButtonSplitOption(symbol: "arrow.triangle.branch", title: L("Rebase & merge", "变基合并"), detail: L("Replay on top", "在主干上重放")),
    ]

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still thumbnail shows the finished state: the menu open.
        _open = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .topTrailing) {
                panel
                splitButton
            }
            .frame(width: Self.width, height: Self.height + 8 + Self.menuHeight, alignment: .topTrailing)
            Spacer()
            DemoHint(text: L("Tap the caret, then pick an option", "点击箭头，再选一个选项"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Tapping outside closes the menu.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { if open { toggle(haptics: true) } }
                .allowsHitTesting(open)
        }
        .autoplay(ctx.isPreview, every: 1.25, delay: 0.5) {
            if ctx.isPreview { advance() } else { playIntro() }
        }
        .onDisappear {
            closeTask?.cancel()
            introTask?.cancel()
        }
    }

    // MARK: Button

    private var splitButton: some View {
        HStack(spacing: 2) {
            primary
            caret
        }
        .frame(width: Self.width, height: Self.height)
        .shadow(color: Color(hex: 0x17803F).opacity(0.35), radius: 14, y: 8)
    }

    private var primary: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 17, bottomLeadingRadius: 17, bottomTrailingRadius: 5, topTrailingRadius: 5, style: .continuous)
        return Button {
            Haptics.tap(.medium)
            primaryTaps += 1
        } label: {
            HStack(spacing: 9) {
                Image(systemName: options[selection].symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                ZStack {
                    Text(options[selection].title, ctx.language)
                        .id(selection)
                        .transition(ButtonSplitRoll(distance: 20, blur: ctx.cg("blur")))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.leading, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(Self.fill))
            .overlay(shape.fill(LinearGradient(colors: [Color.white.opacity(0.2), .clear], startPoint: .top, endPoint: .center)))
            .clipShape(shape)
            .keyframeAnimator(initialValue: -1.0, trigger: primaryTaps) { content, travel in
                content.overlay {
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 60)
                        .rotationEffect(.degrees(18))
                        .offset(x: CGFloat(travel) * 170)
                        .blendMode(.plusLighter)
                        .mask(shape)
                        .allowsHitTesting(false)
                }
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    MoveKeyframe(-1)
                    CubicKeyframe(1, duration: 0.5)
                }
            }
        }
        .buttonStyle(ButtonSplitPressStyle(taps: primaryTaps))
    }

    private var caret: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 17, topTrailingRadius: 17, style: .continuous)
        return Button {
            introTask?.cancel()
            toggle(haptics: true)
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(open ? -180 : 0))
                .frame(width: Self.caretWidth, height: Self.height)
                .background(shape.fill(Self.fill))
                .overlay(shape.fill(Color.black.opacity(open ? 0.2 : 0)))
                .clipShape(shape)
                .contentShape(Rectangle())
        }
        .buttonStyle(ButtonSplitPressStyle(taps: 0))
        .accessibilityLabel(Text(L("More merge options", "更多合并方式"), ctx.language))
    }

    // MARK: Menu

    /// One surface that lives at the caret's rect when closed and at the menu's rect when open.
    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: open ? 18 : 10, style: .continuous)
        return rows
            .frame(width: Self.width, height: Self.menuHeight)
            .frame(
                width: open ? Self.width : Self.caretWidth,
                height: open ? Self.menuHeight : Self.height,
                alignment: .topTrailing
            )
            .background(shape.fill(Palette.elevated))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(open ? 0.16 : 0), radius: 18, y: 10)
            .opacity(open ? 1 : 0)
            .offset(y: open ? Self.height + 8 : 0)
            .allowsHitTesting(open)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                row(index)
                    .opacity(open ? 1 : 0)
                    .offset(y: open ? 0 : -8)
                    .blur(radius: open ? 0 : 4)
                    .animation(
                        open ? spring.delay(0.06 + Double(index) * ctx["stagger"]) : .easeOut(duration: 0.12),
                        value: open
                    )
            }
        }
        .padding(6)
    }

    private func row(_ index: Int) -> some View {
        let option = options[index]
        let selected = index == selection
        return Button {
            introTask?.cancel()
            choose(index, haptics: true)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: option.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? Color(hex: 0x1F9D57) : Color.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.title, ctx.language)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(option.detail, ctx.language)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: 0x1F9D57))
                        .matchedGeometryEffect(id: "check", in: namespace)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: Self.rowHeight)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: 0x1F9D57).opacity(0.13))
                        .matchedGeometryEffect(id: "highlight", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Behaviour

    private func toggle(haptics: Bool) {
        if haptics { Haptics.tap(open ? .soft : .light) }
        withAnimation(spring) { open.toggle() }
    }

    private func choose(_ index: Int, haptics: Bool) {
        guard open else { return }
        if haptics { Haptics.selection() }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { selection = index }
        closeTask?.cancel()
        closeTask = Task { @MainActor in
            // Let the check land before the panel folds away.
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            withAnimation(spring) { open = false }
        }
    }

    /// Preview loop: open, pick the next option (which closes), repeat.
    private func advance() {
        if open {
            choose((selection + 1) % options.count, haptics: false)
        } else {
            toggle(haptics: false)
        }
    }

    /// Detail intro: open, pick the next option, end closed.
    private func playIntro() {
        guard !open else { return }
        toggle(haptics: false)
        introTask?.cancel()
        introTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            choose((selection + 1) % options.count, haptics: false)
        }
    }
}

private struct ButtonSplitPressStyle: ButtonStyle {
    let taps: Int

    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(isPressed: configuration.isPressed, taps: taps) { pressed in
            configuration.label
                .brightness(pressed ? -0.07 : 0)
                .scaleEffect(pressed ? 0.97 : 1)
                .animation(.spring(response: 0.26, dampingFraction: 0.65), value: pressed)
        }
    }
}

/// The primary label's swap: out upward into blur, in from below.
private struct ButtonSplitRoll: Transition {
    let distance: CGFloat
    let blur: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .offset(y: phase == .willAppear ? distance : (phase == .didDisappear ? -distance : 0))
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : blur)
    }
}
