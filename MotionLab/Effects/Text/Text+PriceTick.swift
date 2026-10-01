import SwiftUI

extension Effect {
    static let textPriceTick = Effect(
        id: "text.price-tick",
        category: .text,
        interaction: .tap,
        name: L("Live Price Tick", "实时报价跳动"),
        summary: L("Only the digits that changed roll, in the direction of the move, and flash green or red.", "只有变化的数位朝涨跌方向滚动，并闪一下红或绿。"),
        prompt: L(
            "A live quote: a ticker symbol with a breathing live dot, a 64 pt rounded price and a delta chip. On every tick only the digits that changed move. For a rise the old digit rolls up and out of its clipped slot, shrinking to 75% and blurring 4 pt, while the new one rises from below on a spring (response 0.42 s, damping 0.78); a fall mirrors it downward. Changed digits start right to left 40 ms apart, arrive tinted green or red and fade back to the text colour over 0.7 s, while a soft glow of that colour blooms behind the price. The chip re-tints, its triangle flips 180° on a bouncy spring when the day change crosses zero, and it bumps to 108%.",
            "一条实时报价：带呼吸红点的代码、64pt圆体价格和一枚涨跌胶囊。每次跳动只有变化的数位在动：上涨时旧数字向上滚出裁剪槽口，缩到75%并模糊4pt，新数字从下方以弹簧（响应0.42秒、阻尼0.78）升入；下跌则整体反向。变化的数位从右到左依次启动，间隔40毫秒，到位时染成绿色或红色，再用0.7秒褪回正文色，价格背后同时晕开一团同色柔光。胶囊跟着换色，当日涨跌越过零点时小三角以带回弹的弹簧翻转180°，胶囊整体轻弹到108%。读起来像一块真实的行情屏。"
        ),
        implementation: L(
            "Each digit is an Animatable two-face slot: a turn counter animates on a delayed spring and the faces derive offset, blur and opacity from it; the flash is a colour animation on the arriving face, and the chip uses contentTransition(.numericText).",
            "每个数位是一个 Animatable 的双面槽：计数器以带延迟的弹簧推进，两面据此计算位移、模糊与透明度；闪色是到位那一面的颜色动画，胶囊文字用 contentTransition(.numericText)。"
        ),
        apis: ["Animatable", "spring(response:dampingFraction:)", "clipped()", "contentTransition(.numericText)", "rotationEffect"],
        tags: ["price", "ticker", "stock", "digits", "flash", "股价", "报价", "行情", "涨跌", "数字滚动"],
        params: [
            .slider("response", L("Roll spring", "滚动弹簧"), 0.2...0.9, default: 0.42, unit: "s"),
            .slider("stagger", L("Digit stagger", "数位间隔"), 0...0.12, default: 0.04, unit: "s"),
            .slider("flash", L("Flash fade", "闪色消退"), 0.2...1.6, default: 0.7, unit: "s"),
        ]
    ) { ctx in
        TextPriceTickDemo(ctx: ctx)
    }
}

private struct TextPriceTickDemo: View {
    let ctx: DemoContext

    private static let open: Int = 18427
    /// Price moves in cents. They sum to zero, so the loop is seamless, and cross the open twice.
    private static let moves: [Int] = [38, 127, -52, -246, -91, 64, 213, -9, -158, 114]

    @State private var cents: Int = TextPriceTickDemo.open + 71
    @State private var direction = 1
    @State private var step = 0
    @State private var glow: Double = 0
    @State private var bump = false
    @State private var livePulse = false

    private var delta: Int { cents - Self.open }
    private var rising: Bool { delta >= 0 }
    private var tint: Color { rising ? Palette.green : Palette.red }

    var body: some View {
        VStack(spacing: 18) {
            header
            price
            chip
            DemoHint(text: L("Tap for the next tick", "点击触发下一次跳动"), ctx: ctx)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            tick()
            Haptics.tap(direction > 0 ? .light : .rigid)
        }
        .autoplay(ctx.isPreview, every: 1.5) { tick() }
        .onAppear {
            guard !ctx.isStill else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { livePulse = true }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Palette.red)
                .frame(width: 7, height: 7)
                .opacity(livePulse ? 0.35 : 1)
                .scaleEffect(livePulse ? 0.8 : 1)
            Text(verbatim: "MTNY")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .tracking(1.5)
            Text(L("Motionary Inc.", "动效词典"), ctx.language)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var price: some View {
        let text = String(format: "%.2f", Double(cents) / 100)
        let glyphs: [String] = text.map { String($0) }
        let count = glyphs.count
        let font: Font = .system(size: 64, weight: .heavy, design: .rounded).monospacedDigit()
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: "$")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
            // Slots are identified from the right, so every place keeps its slot when the length changes.
            ForEach(0..<count, id: \.self) { index in
                let place = count - 1 - index
                TextFXRollGlyph(
                    glyph: glyphs[index],
                    direction: direction,
                    font: font,
                    slot: CGSize(width: glyphs[index] == "." ? 20 : 40, height: 76),
                    flash: direction > 0 ? Palette.green : Palette.red,
                    flashHold: ctx["flash"],
                    response: ctx["response"],
                    damping: 0.78,
                    delay: Double(place) * ctx["stagger"],
                    blur: 4
                )
                .id(place)
            }
        }
        .background {
            Ellipse()
                .fill(direction > 0 ? Palette.green : Palette.red)
                .frame(width: 250, height: 90)
                .blur(radius: 34)
                .opacity(glow)
        }
    }

    private var chip: some View {
        let amount = String(format: "%@%.2f", rising ? "+" : "−", abs(Double(delta)) / 100)
        let percent = String(format: "%.2f%%", abs(Double(delta)) / Double(Self.open) * 100)
        return HStack(spacing: 7) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 11, weight: .bold))
                .rotationEffect(.degrees(rising ? 0 : 180))
                .animation(.spring(response: 0.45, dampingFraction: 0.5), value: rising)
            Text(verbatim: amount)
                .contentTransition(.numericText(value: Double(delta)))
            Text(verbatim: "(\(percent))")
                .contentTransition(.numericText(value: Double(delta)))
                .opacity(0.75)
        }
        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(tint.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
        .scaleEffect(bump ? 1.08 : 1)
        .animation(.easeOut(duration: 0.3), value: rising)
    }

    private func tick() {
        let move = Self.moves[step % Self.moves.count]
        step += 1
        direction = move >= 0 ? 1 : -1
        withAnimation(.snappy(duration: 0.3)) {
            cents += move
        }
        withAnimation(.easeOut(duration: 0.12)) {
            glow = 0.3
            bump = true
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.12)) { bump = false }
        withAnimation(.easeOut(duration: ctx["flash"] + 0.2).delay(0.14)) { glow = 0 }
    }
}
