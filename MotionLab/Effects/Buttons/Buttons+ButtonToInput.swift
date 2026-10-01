import SwiftUI

extension Effect {
    static let buttonsButtonToInput = Effect(
        id: "buttons.button-to-input",
        category: .buttons,
        interaction: .tap,
        name: L("Button to Input", "按钮变输入框"),
        summary: L(
            "“Add tag” widens into a text field with a caret; confirming collapses it into a chip that joins the row.",
            "“添加标签”按钮展开成带光标的输入框；确认后收拢成一枚标签，飞入上方的标签行。"
        ),
        prompt: L(
            "A dashed 124 × 42 pt “Add tag” capsule sits under a row of coloured tag chips. Tapping it widens the capsule to 220 pt on a spring (response 0.42 s, damping 0.72): the dashed outline turns into a solid 1.5 pt accent border, the plus rotates 90° and fades, the label blurs out, and a blinking caret appears at the leading edge. Text is typed in at 90 ms per character with the caret riding its end, and a round confirm button with a check pops in at the trailing edge (scale 0.4 → 1, bouncy). Confirming collapses the field back to the dashed button while a new filled chip rises 52 pt out of it into the row, shrinking from 125% with the same spring; the other chips slide aside, a success haptic fires, and the oldest chip leaves once there are more than three.",
            "一排彩色标签下方是 124×42pt 的虚线“添加标签”胶囊。点击后以弹簧（响应 0.42 秒、阻尼 0.72）展宽到 220pt：虚线变成 1.5pt 的实线强调色边框，加号旋转 90° 淡出，文字模糊消失，闪烁的光标出现在左侧。文字以每字符 90 毫秒键入，光标跟在末尾；右侧弹出带对勾的圆形确认按钮（缩放 0.4 → 1，带回弹）。确认后输入框收回成虚线按钮，一枚新的实心标签从中升起 52pt 落入标签行，并用同一弹簧从 125% 缩到原大；其余标签让位，触发成功触感；超过三枚时最旧的离场。"
        ),
        implementation: L(
            "One capsule whose width, stroke style and content derive from an `editing` flag; the typed string grows from a Task and a caret view blinks with a repeating animation. Confirming appends a chip whose insertion transition (offset + scale + opacity) starts at the field's position, so it reads as the field turning into the chip. In a real app the typed string comes from a TextField.",
            "同一个胶囊的宽度、描边样式与内容都由 `editing` 标志推导；键入的字符串由 Task 逐字增长，光标视图用循环动画闪烁。确认时追加一枚标签，其插入转场（位移 + 缩放 + 透明度）从输入框的位置出发，看起来就像输入框变成了标签。在真实应用里，字符串来自 TextField。"
        ),
        apis: ["withAnimation", "transition(.asymmetric)", "StrokeStyle(dash:)", "spring(response:dampingFraction:)", "Task.sleep"],
        tags: ["add tag", "input", "expand", "chip", "text field", "添加标签", "输入框", "展开", "标签", "形变"],
        params: [
            .slider("width", L("Field width", "输入框宽度"), 170...260, default: 220, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.7, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.72),
            .slider("typing", L("Typing interval", "键入间隔"), 0.04...0.2, default: 0.09, unit: "s"),
        ]
    ) { ctx in
        ButtonTagDemo(ctx: ctx)
    }
}

private struct ButtonTagChip: Identifiable, Equatable {
    let id: Int
    let text: String
    let tint: Int
}

private struct ButtonTagDemo: View {
    let ctx: DemoContext
    @State private var chips: [ButtonTagChip]
    @State private var editing: Bool
    @State private var typed: String
    @State private var nextID = 10
    @State private var typeTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    private static let tints: [Color] = [Palette.indigo, Palette.pink, Palette.mint, Palette.coral, Palette.sky, Palette.violet]

    init(ctx: DemoContext) {
        self.ctx = ctx
        let zh = ctx.language == .zh
        _chips = State(initialValue: [ButtonTagChip(id: 0, text: zh ? "动效" : "motion", tint: 0)])
        _editing = State(initialValue: ctx.isStill)
        _typed = State(initialValue: ctx.isStill ? (zh ? "设计" : "desi") : "")
    }

    private var words: [String] {
        ctx.language == .zh ? ["设计", "灵感", "弹簧", "触感", "动效"] : ["design", "spring", "haptic", "ideas", "motion"]
    }
    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var accent: Color { Palette.indigo }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                chipRow
                control
            }
            Spacer()
            DemoHint(text: L("Tap Add tag, then the check", "点“添加标签”，再点对勾"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.3, delay: 0.5) { playScript() }
        .onDisappear {
            typeTask?.cancel()
            scriptTask?.cancel()
        }
    }

    // MARK: Pieces

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(chips) { chip in
                Button {
                    Haptics.tap(.light)
                    withAnimation(spring) { chips.removeAll { $0.id == chip.id } }
                } label: {
                    HStack(spacing: 5) {
                        Text(chip.text)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Self.tints[chip.tint % Self.tints.count], in: Capsule())
                    .shadow(color: Self.tints[chip.tint % Self.tints.count].opacity(0.35), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .transition(
                    .asymmetric(
                        insertion: .offset(y: 52).combined(with: .scale(scale: 1.25)).combined(with: .opacity),
                        removal: .scale(scale: 0.5).combined(with: .opacity)
                    )
                )
            }
        }
        .frame(height: 34)
    }

    private var control: some View {
        let width: CGFloat = editing ? ctx.cg("width") : 124
        return ZStack {
            Capsule()
                .fill(editing ? Palette.elevated : accent.opacity(0.08))
            Capsule()
                .strokeBorder(accent.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .opacity(editing ? 0 : 1)
            Capsule()
                .strokeBorder(accent, lineWidth: 1.5)
                .opacity(editing ? 1 : 0)
            // Resting label.
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .rotationEffect(.degrees(editing ? 90 : 0))
                Text(ctx.language == .zh ? "添加标签" : "Add tag")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize()
            }
            .foregroundStyle(accent)
            .opacity(editing ? 0 : 1)
            .blur(radius: editing ? 5 : 0)
            // Field content.
            HStack(spacing: 2) {
                Image(systemName: "number")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent.opacity(0.7))
                    .padding(.trailing, 4)
                Text(typed)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize()
                ButtonTagCaret(color: accent, blinking: editing && !ctx.isStill)
                Spacer(minLength: 0)
                if editing, !typed.isEmpty {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(accent, in: Circle())
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 7)
            .opacity(editing ? 1 : 0)
        }
        .frame(width: width, height: 42)
        .clipShape(Capsule())
        .shadow(color: accent.opacity(editing ? 0.22 : 0), radius: 12, y: 6)
        .contentShape(Capsule())
        .onTapGesture {
            scriptTask?.cancel()
            if editing { confirm(haptics: true) } else { expand(haptics: true) }
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Behaviour

    private func expand(haptics: Bool) {
        guard !editing else { return }
        if haptics { Haptics.tap(.light) }
        typed = ""
        withAnimation(spring) { editing = true }
        let word = words[nextID % words.count]
        let interval = max(ctx["typing"], 0.02)
        typeTask?.cancel()
        typeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))
            for character in word {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { typed.append(character) }
                if haptics { Haptics.selection() }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func confirm(haptics: Bool) {
        guard editing else { return }
        typeTask?.cancel()
        let text = typed
        withAnimation(spring) {
            editing = false
            guard !text.isEmpty else { return }
            if chips.count >= 3 { chips.removeFirst() }
            chips.append(ButtonTagChip(id: nextID, text: text, tint: nextID))
        }
        nextID += 1
        if haptics, !text.isEmpty { Haptics.success() }
    }

    /// Preview loop and detail intro: expand, let the word type itself, confirm.
    private func playScript() {
        guard !editing else { return }
        scriptTask?.cancel()
        let typing = 0.4 + max(ctx["typing"], 0.02) * 7 + 0.55
        scriptTask = Task { @MainActor in
            expand(haptics: false)
            try? await Task.sleep(for: .seconds(typing))
            guard !Task.isCancelled else { return }
            confirm(haptics: false)
        }
    }
}

private struct ButtonTagCaret: View {
    let color: Color
    let blinking: Bool
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 2, height: 18)
            .opacity(blinking && dim ? 0.1 : 1)
            .onChange(of: blinking, initial: true) { _, isBlinking in
                if isBlinking {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { dim = true }
                } else {
                    var stop = Transaction()
                    stop.disablesAnimations = true
                    withTransaction(stop) { dim = false }
                }
            }
    }
}
