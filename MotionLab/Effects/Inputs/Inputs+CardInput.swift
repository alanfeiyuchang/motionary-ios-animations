import SwiftUI

extension Effect {
    static let inputsCardInput = Effect(
        id: "inputs.card-input",
        category: .inputs,
        interaction: .state,
        name: L("Live Card Form", "实时卡片表单"),
        summary: L("Digits land on a live card as you type, the brand mark fades in, and the security-code field flips the card over.", "输入的数字逐个落到上方卡片上，品牌标识淡入，输入安全码时卡片翻到背面。"),
        prompt: L(
            "A payment form under a live 270 × 166 pt card with 20 pt corners, a gold chip and sixteen placeholder dots. Each typed digit replaces its dot: it rises 12 pt from the field's direction, shrinking from 160% as a 3 pt blur clears, on a spring (response 0.32 s, damping 0.55), and the card pulses 1.5% per keystroke. The first digit decides the brand: the graphite card cross-fades to that brand's gradient over 0.5 s and its mark scales in from 60%. When the sixteenth digit lands, a diagonal sheen sweeps the card in 0.7 s and focus moves to the expiry, whose digits roll in. Focusing the security code flips the card 180° around its vertical axis (response 0.6 s, damping 0.78), lifting 6% at mid-turn; the back shows the magnetic stripe and the code appearing on the signature strip. Leaving the field flips it back.",
            "支付表单上方是一张实时卡片：270 × 166pt、20pt 圆角，带十六个占位圆点。每输入一位数字就替换对应圆点：从输入框方向上升 12pt，由 160% 缩回原大，3pt 模糊消散（弹簧响应 0.32 秒、阻尼 0.55），卡片随按键鼓动 1.5%。首位数字决定卡组织：石墨色卡面在 0.5 秒内渐变为品牌配色，标识从 60% 放大淡入。第十六位落定时，斜向高光在 0.7 秒内扫过卡面。聚焦安全码时，卡片绕竖轴翻转 180°（响应 0.6 秒、阻尼 0.78），中途抬升 6%；安全码出现在背面签名条上。失焦即翻回。"
        ),
        implementation: L(
            "The card is an Animatable view over the flip angle that swaps faces at 90° and adds lift from sin(angle); every digit slot uses a custom Transition for the drop-in. Three digit strings are the single source of truth for both the TextFields (through formatting bindings) and the scripted typing, and @FocusState decides which face is up.",
            "卡片是以翻转角度为动画数据的 Animatable 视图，在 90° 处切换正反面，并用 sin(角度) 叠加抬升；每个数字槽位用自定义 Transition 实现落入效果。三段数字字符串是唯一数据源，同时驱动 TextField（经格式化绑定）与脚本输入，@FocusState 决定朝上的是哪一面。"
        ),
        apis: ["rotation3DEffect", "Animatable", "Transition", "@FocusState", "TextField", "keyframeAnimator"],
        tags: ["credit card", "payment", "form", "flip", "checkout", "信用卡", "支付", "表单", "翻转", "银行卡"],
        params: [
            .slider("flip", L("Flip response", "翻转响应"), 0.3...1.2, default: 0.6, unit: "s"),
            .slider("pop", L("Digit damping", "数字阻尼"), 0.3...1.0, default: 0.55),
            .slider("depth", L("Perspective", "透视"), 0.2...1.0, default: 0.6),
            .toggle("sheen", L("Completion sheen", "完成高光"), default: true),
        ]
    ) { ctx in
        InputCardFormDemo(ctx: ctx)
    }
}

private enum InputCardField: Hashable {
    case number, expiry, code
}

private enum InputCardBrand {
    case nova, twin

    init?(_ number: String) {
        switch number.first {
        case "4": self = .nova
        case "5": self = .twin
        default: return nil
        }
    }
}

private struct InputCardFormDemo: View {
    let ctx: DemoContext
    @State private var number: String
    @State private var expiry: String
    @State private var code = ""
    /// What the two formatted fields show ("4242 4242", "12/28"); rewritten after every edit.
    @State private var numberField: String
    @State private var expiryField: String
    /// The field that looks focused: follows real focus, or the script.
    @State private var active: InputCardField?
    @State private var angle: Double = 0
    @State private var sheens = 0
    @State private var step = 0
    @State private var scriptTask: Task<Void, Never>?
    /// True while the form holds values typed by the script; the first real focus clears them.
    @State private var scripted = false
    @FocusState private var focus: InputCardField?

    private static let numbers = ["4242424242424242", "5412753498210046"]
    private let width: CGFloat = 270

    init(ctx: DemoContext) {
        self.ctx = ctx
        _number = State(initialValue: ctx.isStill ? Self.numbers[0] : "")
        _expiry = State(initialValue: ctx.isStill ? "1228" : "")
        _numberField = State(initialValue: ctx.isStill ? Self.grouped(Self.numbers[0]) : "")
        _expiryField = State(initialValue: ctx.isStill ? "12/28" : "")
    }

    private var isStatic: Bool { ctx.isPreview || ctx.isStill }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                InputCardFaces(
                    angle: angle,
                    depth: ctx.cg("depth"),
                    number: number,
                    expiry: expiryField,
                    code: code,
                    brand: InputCardBrand(number),
                    sheens: sheens,
                    damping: ctx["pop"],
                    language: ctx.language
                )
                form
            }
            Spacer(minLength: 0)
            DemoHint(text: L("Type a card number, then tap the CVV field", "输入卡号，再点安全码输入框"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { focus = nil }
        .autoplay(ctx.isPreview, every: 5.6, delay: 0.4) { runScript() }
        .onChange(of: focus) { _, field in
            if field != nil, scripted { stopScript() }
            if scriptTask == nil { active = field }
        }
        .onChange(of: active) { _, field in
            withAnimation(.spring(response: ctx["flip"], dampingFraction: 0.78)) {
                angle = field == .code ? 180 : 0
            }
        }
        .onDisappear { scriptTask?.cancel() }
    }

    // MARK: Form

    private static func grouped(_ digits: String) -> String {
        var groups: [String] = []
        var rest = Substring(digits)
        while !rest.isEmpty {
            groups.append(String(rest.prefix(4)))
            rest = rest.dropFirst(4)
        }
        return groups.joined(separator: " ")
    }

    private static func slashed(_ digits: String) -> String {
        digits.count > 2 ? String(digits.prefix(2)) + "/" + String(digits.dropFirst(2)) : digits
    }

    private var form: some View {
        VStack(spacing: 10) {
            field(.number, symbol: "creditcard", placeholder: L("Card number", "卡号"), text: Binding(
                get: { numberField },
                set: { setNumber($0) }
            ))
            HStack(spacing: 10) {
                field(.expiry, symbol: "calendar", placeholder: L("MM/YY", "月/年"), text: Binding(
                    get: { expiryField },
                    set: { setExpiry($0) }
                ))
                field(.code, symbol: "lock", placeholder: L("CVV", "安全码"), text: Binding(
                    get: { code },
                    set: { setCode($0) }
                ))
            }
        }
        .frame(width: width)
    }

    private func field(_ id: InputCardField, symbol: String, placeholder: LocalizedText, text: Binding<String>) -> some View {
        let isActive = active == id
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Palette.indigo : Color.secondary)
                .frame(width: 20)
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder, ctx.language)
                        .foregroundStyle(.tertiary)
                }
                if isStatic {
                    Text(verbatim: text.wrappedValue)
                        .foregroundStyle(.primary)
                } else {
                    TextField("", text: text)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: id)
                        .foregroundStyle(.primary)
                }
            }
            .font(.system(size: 16, weight: .medium, design: .rounded).monospacedDigit())
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Color.primary.opacity(0.06), in: shape)
        .overlay(shape.strokeBorder(Palette.indigo.opacity(isActive ? 0.9 : 0), lineWidth: 1.5))
        .scaleEffect(isActive ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .contentShape(shape)
        .onTapGesture { if !isStatic { focus = id } }
    }

    // MARK: Single source of truth (keyboard and script both write here)

    private func digits(_ text: String, limit: Int) -> String {
        String(text.filter(\.isNumber).prefix(limit))
    }

    private func setNumber(_ text: String) {
        let value = digits(text, limit: 16)
        // Always rewrite the field, so the keyboard's raw text snaps back into groups of four.
        numberField = Self.grouped(value)
        guard value != number else { return }
        let completed = value.count == 16 && number.count < 16
        number = value
        guard completed else { return }
        if ctx.bool("sheen") { sheens += 1 }
        if scriptTask == nil {
            Haptics.tap(.light)
            if focus == .number { focus = .expiry }
        }
    }

    private func setExpiry(_ text: String) {
        let value = digits(text, limit: 4)
        guard value != expiry else {
            expiryField = Self.slashed(value)
            return
        }
        withAnimation(.snappy(duration: 0.25)) {
            expiry = value
            expiryField = Self.slashed(value)
        }
        if value.count == 4, scriptTask == nil, focus == .expiry { focus = .code }
    }

    private func setCode(_ text: String) {
        let value = digits(text, limit: 3)
        guard value != code else { return }
        code = value
        if value.count == 3, scriptTask == nil, focus == .code {
            Haptics.success()
            focus = nil
        }
    }

    // MARK: Script (preview loop and the detail intro)

    private func runScript() {
        scriptTask?.cancel()
        let sample = Self.numbers[step % Self.numbers.count]
        step += 1
        scripted = true
        scriptTask = Task { @MainActor in
            active = nil
            clear()
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            active = .number
            for index in 1...sample.count {
                try? await Task.sleep(for: .milliseconds(62))
                guard !Task.isCancelled else { return }
                setNumber(String(sample.prefix(index)))
            }
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            active = .expiry
            for index in 1...4 {
                try? await Task.sleep(for: .milliseconds(110))
                guard !Task.isCancelled else { return }
                setExpiry(String("1228".prefix(index)))
            }
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            active = .code
            try? await Task.sleep(for: .seconds(0.65))
            for index in 1...3 {
                try? await Task.sleep(for: .milliseconds(170))
                guard !Task.isCancelled else { return }
                setCode(String("737".prefix(index)))
            }
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            active = nil
            scriptTask = nil
        }
    }

    /// A real field took focus: the script stops and hands over an empty form.
    private func stopScript() {
        scriptTask?.cancel()
        scriptTask = nil
        scripted = false
        clear()
    }

    private func clear() {
        number = ""
        expiry = ""
        code = ""
        numberField = ""
        expiryField = ""
    }
}

// MARK: - Card

/// Both faces of the card. Animatable over the flip angle: faces swap at 90°, the card lifts mid-turn.
private struct InputCardFaces: View, Animatable {
    var angle: Double
    let depth: CGFloat
    let number: String
    let expiry: String
    let code: String
    let brand: InputCardBrand?
    let sheens: Int
    let damping: Double
    let language: AppLanguage

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private let size = CGSize(width: 270, height: 166)

    var body: some View {
        let showsBack = angle > 90
        let lift: CGFloat = CGFloat(abs(sin(angle * .pi / 180)))
        return ZStack {
            front
                .opacity(showsBack ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: depth)
        .scaleEffect(1 + 0.06 * lift)
        .shadow(color: .black.opacity(0.22 + 0.1 * Double(lift)), radius: 16 + 10 * lift, y: 10 + 8 * lift)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: number.count) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.015, duration: 0.06)
                SpringKeyframe(1, duration: 0.25, spring: .snappy)
            }
        }
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }

    private var front: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x444857), Color(hex: 0x1D1F28)], startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [Color(hex: 0x4F6BFF), Color(hex: 0x8A45E0), Color(hex: 0x2BB8E8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(brand == .nova ? 1 : 0)
            LinearGradient(colors: [Color(hex: 0xFF9A4A), Color(hex: 0xF0506E), Color(hex: 0x9B2D8F)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(brand == .twin ? 1 : 0)
            // In an overlay so the oversized disc never stretches the card's layout.
            Color.clear.overlay {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 220, height: 220)
                    .offset(x: 120, y: -90)
            }
            frontContent
            sheen
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .animation(.smooth(duration: 0.5), value: brand)
    }

    private var frontContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFE9A8), Color(hex: 0xD9A441)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 27)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.22), lineWidth: 1)
                            .padding(6)
                    )
                Image(systemName: "wave.3.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 5)
                Spacer(minLength: 0)
                brandMark
                    .frame(height: 28)
            }
            Spacer(minLength: 0)
            numberRow
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("CARDHOLDER", "持卡人"), language)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(verbatim: "JAMIE LEE")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L("VALID THRU", "有效期"), language)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(verbatim: expiry.isEmpty ? "••/••" : expiry)
                        .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(expiry.isEmpty ? 0.5 : 1))
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(18)
    }

    @ViewBuilder
    private var brandMark: some View {
        switch brand {
        case .nova:
            Text(verbatim: "NOVA")
                .font(.system(size: 21, weight: .black, design: .rounded).italic())
                .foregroundStyle(.white)
                .transition(.scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
        case .twin:
            ZStack {
                Circle().fill(Color(hex: 0xFFD166)).frame(width: 26, height: 26).offset(x: -8)
                Circle().fill(Color.white.opacity(0.85)).frame(width: 26, height: 26).offset(x: 8)
            }
            .frame(width: 44)
            .transition(.scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
        case nil:
            EmptyView()
        }
    }

    private var numberRow: some View {
        let characters = Array(number)
        return HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { group in
                HStack(spacing: 1.5) {
                    ForEach(0..<4, id: \.self) { column in
                        let index = group * 4 + column
                        InputCardSlot(character: index < characters.count ? characters[index] : nil, damping: damping)
                    }
                }
            }
        }
    }

    private var sheen: some View {
        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 90)
            .rotationEffect(.degrees(20))
            .scaleEffect(y: 2)
            .keyframeAnimator(initialValue: CGFloat(-240), trigger: sheens) { content, x in
                content.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    MoveKeyframe(-240)
                    LinearKeyframe(240, duration: 0.7, timingCurve: .easeInOut)
                }
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var back: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x454A5C), Color(hex: 0x1F2230)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 14) {
                Color.black.opacity(0.85)
                    .frame(height: 36)
                    .padding(.top, 20)
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        Color(white: 0.92)
                        Text(verbatim: "Jamie Lee")
                            .font(.system(size: 15, weight: .regular, design: .serif).italic())
                            .foregroundStyle(Color(white: 0.3))
                            .padding(.leading, 10)
                    }
                    .frame(width: 150, height: 32)
                    HStack(spacing: 3) {
                        let characters = Array(code)
                        ForEach(0..<3, id: \.self) { index in
                            InputCardSlot(character: index < characters.count ? characters[index] : nil, damping: damping, ink: Color(white: 0.12))
                        }
                    }
                    .frame(width: 58, height: 32)
                    .background(Color.white)
                    .overlay(Rectangle().strokeBorder(Palette.indigo, lineWidth: 2))
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
                Text(L("Security code", "安全码"), language)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 18)
                    .padding(.top, -6)
                Spacer(minLength: 0)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
    }
}

/// One character cell: a placeholder dot until its digit drops in.
private struct InputCardSlot: View {
    let character: Character?
    let damping: Double
    var ink: Color = .white

    var body: some View {
        ZStack {
            if let character {
                Text(verbatim: String(character))
                    .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                    .transition(InputCardDrop())
            } else {
                Circle()
                    .fill(ink.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .transition(.opacity)
            }
        }
        .frame(width: 11, height: 26)
        .animation(.spring(response: 0.32, dampingFraction: damping), value: character)
    }
}

/// A digit arrives from the field below: rises, shrinks from oversize, sharpens.
private struct InputCardDrop: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase == .willAppear ? 1.6 : 1)
            .offset(y: phase == .willAppear ? 12 : 0)
            .blur(radius: phase == .willAppear ? 3 : 0)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
