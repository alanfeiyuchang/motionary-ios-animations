import SwiftUI

extension Effect {
    static let textCurrencyGrow = Effect(
        id: "text.currency-grow",
        category: .text,
        interaction: .tap,
        name: L("Amount Entry", "金额输入"),
        summary: L("Typed digits slide in from the right, thousands separators pop in, and the amount shrinks to fit.", "输入的数字从右侧滑入，千位分隔符随之弹出，整个金额自动缩小以适应宽度。"),
        prompt: L(
            "A payment amount above a compact keypad, set in 64 pt heavy rounded digits after a smaller currency sign. Each typed digit slides in from 28 pt to the right at 60% scale with a 6 pt blur while the existing digits glide left on one spring (response 0.38 s, damping 0.72). Whenever the count crosses a group of three, the old comma shrinks away and a new one pops in at its new place. Typing the decimal point adds two dimmed placeholder zeros that the next digits replace and darken. When the amount grows wider than 290 pt the whole line scales down around its centre on the same spring, and grows back as digits are deleted; a deleted digit drops 26 pt and fades. An entry past the limit shakes the line sideways with an error haptic.",
            "紧凑数字键盘上方的一行付款金额：较小的货币符号后跟64pt特粗圆体数字。每输入一位，新数字从右侧28pt处以60%大小、6pt模糊滑入，已有数字用同一根弹簧（响应0.38秒、阻尼0.72）向左让位。位数每跨过一个三位分组，旧逗号缩小消失，新逗号在新位置弹出。按下小数点会补出两个变淡的占位零，之后输入的数字替换它们并变回正文色。金额宽度超过290pt时，整行以同一根弹簧围绕中心缩小；删除时再放大回来，被删的数字下坠26pt并淡出。超出位数上限时，整行左右抖动并给出错误触感。"
        ),
        implementation: L(
            "The amount is an HStack of glyph pieces with stable identities (digits by index, commas by the digit they follow); a spring animation on the entry string moves survivors, custom transitions slide pieces in and out, and scaleEffect fits the line using a width computed from the piece widths.",
            "金额是一个由身份稳定的字形片段组成的 HStack（数字按序号、逗号按所跟随的数位标识）；对输入字符串施加弹簧动画让留下的片段移动，自定义转场负责滑入滑出，scaleEffect 根据各片段宽度算出的总宽把整行缩放到合适大小。"
        ),
        apis: ["AnyTransition.modifier(active:identity:)", "spring(response:dampingFraction:)", "scaleEffect", "contentTransition(.numericText)"],
        tags: ["amount", "currency", "keypad", "payment", "scale to fit", "金额", "货币", "数字键盘", "支付", "千位分隔"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.8, default: 0.38, unit: "s"),
            .slider("fit", L("Fit width", "适应宽度"), 180...300, default: 290, decimals: 0, unit: "pt"),
            .toggle("grouping", L("Thousands separators", "千位分隔符"), default: true),
        ]
    ) { ctx in
        TextCurrencyGrowDemo(ctx: ctx)
    }
}

private struct CurrencyPiece: Identifiable {
    let id: String
    let text: String
    let width: CGFloat
    var dim = false
    var isMark = false
}

private struct TextCurrencyGrowDemo: View {
    let ctx: DemoContext

    /// Raw entry: digits with at most one ".".
    @State private var entry = "1250"
    @State private var pressed: String? = nil
    @State private var shakes = 0
    @State private var step = 0
    @State private var pressTask: Task<Void, Never>?

    private static let script: [String] = ["0", "0", ".", "5", "0", "", "", "clear", "", "1", "2", "5", "0", ""]
    private static let keys: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "⌫"]]

    var body: some View {
        VStack(spacing: 10) {
            payee
            amount
            keypad
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.45) { auto() }
        .onDisappear { pressTask?.cancel() }
    }

    // MARK: Amount

    private var pieces: [CurrencyPiece] {
        let parts = entry.split(separator: ".", omittingEmptySubsequences: false)
        let whole: [Character] = Array(parts.first ?? "")
        let grouping = ctx.bool("grouping")
        var result: [CurrencyPiece] = []
        if whole.isEmpty {
            result.append(CurrencyPiece(id: "i0", text: "0", width: 40, dim: true))
        }
        for (index, digit) in whole.enumerated() {
            result.append(CurrencyPiece(id: "i\(index)", text: String(digit), width: 40))
            let after = whole.count - 1 - index
            if grouping && after > 0 && after % 3 == 0 {
                result.append(CurrencyPiece(id: "s\(index)", text: ",", width: 16, isMark: true))
            }
        }
        if entry.contains(".") {
            result.append(CurrencyPiece(id: "p", text: ".", width: 16, isMark: true))
            let cents: [Character] = parts.count > 1 ? Array(parts[1]) : []
            for index in 0..<2 {
                if index < cents.count {
                    result.append(CurrencyPiece(id: "f\(index)", text: String(cents[index]), width: 40))
                } else {
                    result.append(CurrencyPiece(id: "f\(index)", text: "0", width: 40, dim: true))
                }
            }
        }
        return result
    }

    private var amount: some View {
        let items = pieces
        let natural: CGFloat = items.reduce(30) { $0 + $1.width }
        let scale: CGFloat = min(1, ctx.cg("fit") / natural)
        let spring: Animation = .spring(response: ctx["response"], dampingFraction: 0.72)
        return TextFXPulse(trigger: shakes, duration: 0.42) { p in
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: "$")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
                ForEach(items) { piece in
                    Text(verbatim: piece.text)
                        .font(.system(size: 64, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.primary.opacity(piece.dim ? 0.25 : 1))
                        .contentTransition(.numericText())
                        .frame(width: piece.width)
                        .transition(piece.isMark ? .currencyMark : .currencyDigit)
                }
            }
            .fixedSize()
            .scaleEffect(scale)
            .offset(x: sin(Double(p) * Double.pi * 5) * 9 * Double(1 - p))
        }
        .frame(width: 320, height: 84)
        .animation(spring, value: entry)
        .animation(spring, value: scale)
    }

    private var payee: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Palette.sunset)
                .frame(width: 22, height: 22)
                .overlay {
                    Text(verbatim: "M")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            Text(L("Send to Mia", "转给 Mia"), ctx.language)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    // MARK: Keypad

    private var keypad: some View {
        VStack(spacing: 6) {
            ForEach(Self.keys.indices, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(Self.keys[row], id: \.self) { key in
                        keyView(key)
                    }
                }
            }
        }
    }

    private func keyView(_ key: String) -> some View {
        let isDown: Bool = pressed == key
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Group {
            if key == "⌫" {
                Image(systemName: "delete.left")
                    .font(.system(size: 17, weight: .semibold))
            } else {
                Text(verbatim: key)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(isDown ? Palette.indigo : Color.primary)
        .frame(width: 88, height: 40)
        .background(isDown ? Palette.indigo.opacity(0.2) : Color.primary.opacity(0.06), in: shape)
        .scaleEffect(isDown ? 0.93 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: isDown)
        .contentShape(shape)
        .onTapGesture {
            Haptics.tap(.light)
            press(key)
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            guard key == "⌫" else { return }
            Haptics.tap(.medium)
            press("clear")
        }
    }

    // MARK: Input

    private func auto() {
        let key = Self.script[step % Self.script.count]
        step += 1
        guard !key.isEmpty else { return }
        press(key)
    }

    private func press(_ key: String) {
        pressed = key == "clear" ? "⌫" : key
        pressTask?.cancel()
        pressTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            pressed = nil
        }
        apply(key)
    }

    private func apply(_ key: String) {
        var next = entry
        switch key {
        case "clear":
            next = ""
        case "⌫":
            guard !next.isEmpty else { return reject() }
            next.removeLast()
        case ".":
            guard !next.contains(".") else { return reject() }
            if next.isEmpty { next = "0" }
            next.append(".")
        default:
            if let dot = next.firstIndex(of: ".") {
                let decimals = next.distance(from: dot, to: next.endIndex) - 1
                guard decimals < 2 else { return reject() }
                next.append(key)
            } else {
                guard next.count < 9 else { return reject() }
                if next == "0" { next = key } else { next.append(key) }
            }
        }
        entry = next
    }

    private func reject() {
        shakes += 1
        Haptics.error()
    }
}

// MARK: - Transitions

private struct CurrencyShift: ViewModifier {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var scale: CGFloat = 1
    var blur: CGFloat = 0
    var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(x: x, y: y)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    /// In from the right, small and soft; out by dropping.
    static var currencyDigit: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: CurrencyShift(x: 28, scale: 0.6, blur: 6, opacity: 0), identity: CurrencyShift()),
            removal: .modifier(active: CurrencyShift(y: 26, scale: 0.7, blur: 4, opacity: 0), identity: CurrencyShift())
        )
    }

    /// Commas and the decimal point pop in place.
    static var currencyMark: AnyTransition {
        .modifier(active: CurrencyShift(y: 8, scale: 0.1, opacity: 0), identity: CurrencyShift())
    }
}
