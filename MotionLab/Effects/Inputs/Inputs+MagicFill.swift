import SwiftUI

extension Effect {
    static let inputsMagicFill = Effect(
        id: "inputs.magic-fill",
        category: .inputs,
        interaction: .tap,
        name: L("Autofill Cascade", "自动填充瀑布"),
        summary: L("One tap fills the whole form: each field wipes its value in behind a shimmer sweep and keeps a soft highlight that slowly fades.", "一键填完整张表单：每个输入框的内容跟着一道流光被擦出来，并留下一层慢慢褪去的柔和高亮。"),
        prompt: L(
            "A form card with four empty fields, each showing an icon and a placeholder label, and an Autofill button below. Tapping it fills the fields top to bottom, 110 ms apart. In each field the label shrinks to 78% and floats to the top edge on a spring (response 0.4 s, damping 0.8); the value is wiped in from the left behind a slanted band of light that crosses the row in 600 ms, sharpening from a 4 pt blur as it appears; the row takes a soft amber highlight within 200 ms and a small green check pops in at its right end with a bounce (damping 0.55). The highlight holds for 1.4 s, then fades over 0.9 s. The button morphs to Clear; tapping it empties the fields bottom to top, 50 ms apart, values blurring out and labels dropping back.",
            "表单卡片里四个空输入框，各有图标与占位标签，下方是「自动填充」按钮。点击后输入框自上而下依次填入，间隔 110 毫秒。每一行里，标签以弹簧（响应 0.4 秒、阻尼 0.8）缩到 78% 并浮到上沿；内容跟在一道倾斜的光带后面从左向右被擦出，光带 600 毫秒扫过整行，文字从 4pt 模糊变清晰；整行在 200 毫秒内染上柔和的琥珀色高亮，右端弹出一枚绿色小勾（阻尼 0.55）。高亮保持 1.4 秒，再用 0.9 秒褪去。按钮变为「清除」；点击后输入框自下而上依次清空，间隔 50 毫秒，内容模糊淡出，标签落回原位。"
        ),
        implementation: L(
            "Each row owns its sweep, reveal and highlight values and plays them when its `filled` flag flips; the parent only flips the flags in a staggered task. The value is revealed by a mask rectangle scaled from the leading edge, in step with the offset of the light band.",
            "每一行自己持有扫光、揭示与高亮的数值，在 filled 标记翻转时播放；父视图只负责在一个带间隔的任务里逐个翻转标记。内容由一个从左缘缩放的遮罩矩形揭示，与光带的位移同步。"
        ),
        apis: ["mask", "scaleEffect(x:y:anchor:)", "LinearGradient", "spring(response:dampingFraction:)", "Task.sleep", "transition(.blurReplace)"],
        tags: ["autofill", "form", "shimmer", "cascade", "highlight", "自动填充", "表单", "流光", "瀑布", "高亮"],
        params: [
            .slider("stagger", L("Field stagger", "逐行间隔"), 0.04...0.3, default: 0.11, unit: "s"),
            .slider("sweep", L("Sweep duration", "扫光时长"), 0.3...1.2, default: 0.6, unit: "s"),
            .slider("hold", L("Highlight hold", "高亮停留"), 0.4...3.0, default: 1.4, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        InputMagicFillDemo(ctx: ctx)
    }
}

private struct InputFillField {
    let symbol: String
    let label: LocalizedText
    let value: LocalizedText

    static let all: [InputFillField] = [
        InputFillField(symbol: "person.fill", label: L("Full name", "姓名"), value: L("Avery Lin", "林安然")),
        InputFillField(symbol: "envelope.fill", label: L("Email", "邮箱"), value: L("avery@example.com", "anran@example.com")),
        InputFillField(symbol: "phone.fill", label: L("Phone", "电话"), value: L("(555) 010-4821", "555 0104 821")),
        InputFillField(symbol: "house.fill", label: L("Address", "地址"), value: L("28 Juniper Lane, Apt 5", "梧桐路 28 号 5 楼")),
    ]
}

private struct InputMagicFillDemo: View {
    let ctx: DemoContext
    @State private var filled: [Bool]
    @State private var isFilled: Bool
    @State private var busy = false
    @State private var taps = 0
    @State private var task: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _filled = State(initialValue: Array(repeating: ctx.isStill, count: InputFillField.all.count))
        _isFilled = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            card
            button
                .padding(.top, 14)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap Autofill, then Clear", "点击「自动填充」，再点「清除」"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.2, delay: 0.5) { toggle() }
        .onDisappear { task?.cancel() }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 0) {
            ForEach(Array(InputFillField.all.enumerated()), id: \.offset) { index, field in
                InputFillRow(
                    field: field,
                    filled: filled[index],
                    sweepDuration: ctx["sweep"],
                    hold: ctx["hold"],
                    language: ctx.language,
                    startsFilled: ctx.isStill
                )
                if index < InputFillField.all.count - 1 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                        .padding(.leading, 46)
                }
            }
        }
        .frame(width: 288)
        .background(Palette.elevated, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 14, y: 8)
    }

    private var button: some View {
        Button(action: toggle) {
            HStack(spacing: 7) {
                Image(systemName: isFilled ? "xmark" : "wand.and.stars")
                    .contentTransition(.symbolEffect(.replace))
                Text(isFilled ? L("Clear", "清除") : L("Autofill", "自动填充"), ctx.language)
                    .id(isFilled)
                    .transition(.blurReplace)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isFilled ? Color.primary : Color.white)
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background {
                Capsule().fill(Color.primary.opacity(0.09))
                Capsule().fill(Palette.primary).opacity(isFilled ? 0 : 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(InputFillPressStyle(taps: taps))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFilled)
    }

    // MARK: Actions

    private func toggle() {
        guard !busy else { return }
        taps += 1
        if isFilled {
            clear()
        } else {
            fill()
        }
    }

    private func fill() {
        busy = true
        isFilled = true
        let stagger = ctx["stagger"]
        task?.cancel()
        task = Task { @MainActor in
            defer { busy = false }
            for index in filled.indices {
                guard !Task.isCancelled else { return }
                filled[index] = true
                if !ctx.isPreview { Haptics.tap(.light) }
                try? await Task.sleep(for: .seconds(stagger))
            }
            try? await Task.sleep(for: .seconds(ctx["sweep"] * 0.7))
            guard !Task.isCancelled else { return }
            if !ctx.isPreview { Haptics.success() }
        }
    }

    private func clear() {
        busy = true
        isFilled = false
        Haptics.tap(.light)
        task?.cancel()
        task = Task { @MainActor in
            defer { busy = false }
            for index in filled.indices.reversed() {
                guard !Task.isCancelled else { return }
                filled[index] = false
                try? await Task.sleep(for: .seconds(0.05))
            }
        }
    }
}

private struct InputFillRow: View {
    let field: InputFillField
    let filled: Bool
    let sweepDuration: Double
    let hold: Double
    let language: AppLanguage

    /// Position of the light band across the row, -0.3 (off the left) ... 1.3 (off the right).
    @State private var sweep: CGFloat = -0.3
    @State private var reveal: CGFloat
    @State private var highlight: Double
    @State private var checked: Bool
    @State private var fadeTask: Task<Void, Never>?

    private let height: CGFloat = 48
    private let width: CGFloat = 288

    init(field: InputFillField, filled: Bool, sweepDuration: Double, hold: Double, language: AppLanguage, startsFilled: Bool) {
        self.field = field
        self.filled = filled
        self.sweepDuration = sweepDuration
        self.hold = hold
        self.language = language
        _reveal = State(initialValue: startsFilled ? 1 : 0)
        _highlight = State(initialValue: startsFilled ? 1 : 0)
        _checked = State(initialValue: startsFilled)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: field.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(filled ? Palette.indigo : Color.secondary)
                .frame(width: 20)
            ZStack(alignment: .leading) {
                Text(field.label, language)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .scaleEffect(filled ? 0.78 : 1, anchor: .leading)
                    .offset(y: filled ? -11 : 0)
                Text(field.value, language)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .blur(radius: (1 - reveal) * 4)
                    .mask(alignment: .leading) {
                        Rectangle().scaleEffect(x: max(reveal, 0.001), anchor: .leading)
                    }
                    .offset(y: 8)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Palette.green)
                .scaleEffect(checked ? 1 : 0.2)
                .opacity(checked ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .frame(width: width, height: height)
        .background(Palette.amber.opacity(0.2 * highlight))
        .overlay { band }
        .clipped()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filled)
        .onChange(of: filled) { _, now in
            if now {
                play()
            } else {
                rewind()
            }
        }
        .onDisappear { fadeTask?.cancel() }
    }

    private var band: some View {
        LinearGradient(
            colors: [Palette.amber.opacity(0), Palette.amber.opacity(0.45), Color.white.opacity(0.6), Palette.amber.opacity(0.45), Palette.amber.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 56, height: height * 2.2)
        .rotationEffect(.degrees(18))
        .offset(x: (sweep - 0.5) * width)
        .allowsHitTesting(false)
    }

    private func play() {
        fadeTask?.cancel()
        withAnimation(.easeInOut(duration: sweepDuration)) {
            sweep = 1.3
            reveal = 1
        }
        withAnimation(.easeOut(duration: 0.2)) { highlight = 1 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(sweepDuration * 0.75)) { checked = true }
        fadeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(sweepDuration + hold))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.9)) { highlight = 0 }
        }
    }

    private func rewind() {
        fadeTask?.cancel()
        withAnimation(.easeIn(duration: 0.2)) {
            reveal = 0
            highlight = 0
            checked = false
        }
        // The band is off-stage on the right: move it back to the left unseen.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { sweep = -0.3 }
    }
}

private struct InputFillPressStyle: ButtonStyle {
    let taps: Int

    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(isPressed: configuration.isPressed, taps: taps) { pressed in
            configuration.label
                .scaleEffect(pressed ? 0.95 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
    }
}
