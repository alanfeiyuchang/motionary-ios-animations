import SwiftUI

extension Effect {
    static let showcaseTipSelector = Effect(
        id: "showcase.tip-selector",
        category: .showcase,
        interaction: .tap,
        name: L("Tip Selector", "小费选择器"),
        summary: L(
            "Tip chips with a gliding selection pill and a rolling total; Custom springs a slider open underneath.",
            "选中胶囊在小费选项间滑动，合计金额随之滚动；选“自定”时下方弹开一条滑杆。"
        ),
        prompt: L(
            "A dark bill widget: a subtotal line, a recessed track with four chips (15%, 18%, 20%, Custom), a dashed divider, the tip amount and a large total. Tapping a chip glides the orange selection pill to it on a spring (response 0.38 s, damping 0.72) so it overshoots slightly, the chip's label flips to dark ink, and the tip and total roll digit by digit to their new values. Choosing Custom springs a slider open below the chips: the card grows by 56 pt on the same spring while the slider scales up from 85% and fades in. Dragging its thumb sets 0 to 30% in whole steps with a selection haptic per percent; the thumb swells from 22 pt to 28 pt and a percentage bubble rides above it while the amounts keep rolling. Picking a preset collapses the slider again. Quick, confident, checkout-ready.",
            "深色账单组件：一行小计，一条内凹轨道里放着四个选项（15%、18%、20%、自定），其下是虚线分隔、小费金额和大号合计。点击某个选项，橙色选中胶囊以弹簧（响应 0.38 秒、阻尼 0.72）滑过去并略微过冲，选项文字变为深色，小费与合计逐位滚动到新值。选“自定”时，选项下方弹开一条滑杆：卡片按同一弹簧增高 56pt，滑杆从 85% 放大并淡入。拖动滑块可在 0 到 30% 间按整数调节，每 1% 一次选择触感；滑块从 22pt 涨到 28pt，上方跟着百分比气泡。改选预设档位时滑杆收起。干脆、笃定。"
        ),
        implementation: L(
            "The selection pill is a matchedGeometryEffect background that moves between chips under withAnimation(.spring). Amounts are Text with contentTransition(.numericText(value:)). The slider lives in a frame whose height animates between 0 and 46 pt, clipped, and a DragGesture maps x to a whole percentage.",
            "选中胶囊是 matchedGeometryEffect 背景，在 withAnimation(.spring) 下于各选项间移动。金额是带 contentTransition(.numericText(value:)) 的 Text。滑杆放在高度于 0 与 46pt 之间动画的裁剪容器里，DragGesture 把 x 映射成整数百分比。"
        ),
        apis: ["matchedGeometryEffect", "contentTransition(.numericText)", "DragGesture", "withAnimation(.spring)", "frame(height:)", "Namespace"],
        tags: ["tip", "checkout", "chips", "segmented", "total", "小费", "结账", "选项", "分段", "合计"],
        params: [
            .slider("response", L("Pill response", "胶囊响应"), 0.2...0.8, default: 0.38, unit: "s"),
            .slider("damping", L("Pill damping", "胶囊阻尼"), 0.4...1.0, default: 0.72),
            .slider("bill", L("Subtotal", "小计金额"), 20...200, default: 48, step: 1, decimals: 0),
        ]
    ) { ctx in
        TipSelectorDemo(ctx: ctx)
    }
}

private struct TipSelectorDemo: View {
    let ctx: DemoContext
    @State private var choice: Int
    @State private var custom: Double = 12
    @State private var sliding = false
    @State private var script: Task<Void, Never>?
    @State private var scripting = false
    @GestureState private var finger = false
    @Namespace private var pill

    private let presets: [Double] = [15, 18, 20]
    private let sliderWidth: CGFloat = 244

    init(ctx: DemoContext) {
        self.ctx = ctx
        _choice = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var zh: Bool { ctx.language == .zh }
    private var currency: String { zh ? "¥" : "$" }
    private var isCustom: Bool { choice == 3 }
    private var percent: Double { isCustom ? custom : presets[choice] }
    private var bill: Double { ctx["bill"] + 0.6 }
    private var tip: Double { (bill * percent).rounded() / 100 }
    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        StudioScene(hint: L("Pick a tip, or try Custom", "选一个小费档位，或试试“自定”"), ctx: ctx) {
            card
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.7) { autoStep() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            SportEyebrowRow(title: zh ? "账单 · 7 号桌" : "Bill · Table 7", symbol: "fork.knife", trailing: zh ? "2 位" : "2 guests")
            row(zh ? "小计" : "Subtotal", value: bill, size: 15, color: Color.white.opacity(0.85))
            chips
            slider
                .frame(height: isCustom ? 46 : 0, alignment: .top)
                .clipped()
                .padding(.top, isCustom ? 0 : -10)
            DashLine()
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(height: 1)
            row((zh ? "小费 " : "Tip ") + "\(Int(percent))%", value: tip, size: 15, color: Signature.accentSoft)
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: zh ? "合计" : "Total")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Spacer()
                Text(verbatim: currency + String(format: "%.2f", bill + tip))
                    .font(Signature.number(36))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText(value: bill + tip))
            }
        }
        .padding(16)
        .frame(width: 288)
        .signatureCard()
    }

    private func row(_ title: String, value: Double, size: CGFloat, color: Color) -> some View {
        HStack {
            Text(verbatim: title)
                .contentTransition(.numericText(value: percent))
            Spacer()
            Text(verbatim: currency + String(format: "%.2f", value))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
        }
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .foregroundStyle(color)
    }

    // MARK: Chips

    private var chips: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                let selected = index == choice
                Button {
                    guard index != choice else { return }
                    script?.cancel()
                    Haptics.tap(.light)
                    select(index)
                } label: {
                    Group {
                        if index < 3 {
                            Text(verbatim: "\(Int(presets[index]))%")
                        } else {
                            Text(verbatim: zh ? "自定" : "Custom")
                        }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? Signature.ink : Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background {
                        if selected {
                            Capsule()
                                .fill(Signature.accentGradient)
                                .shadow(color: Signature.accent.opacity(0.5), radius: 8, y: 3)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(SportPressStyle(scale: 0.94, dim: 0.03))
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: Custom slider

    private var slider: some View {
        let knob: CGFloat = sliding ? 28 : 22
        let x = sliderWidth * CGFloat(custom / 30)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(height: 6)
            Capsule()
                .fill(Signature.accentGradient)
                .frame(width: max(x, 6), height: 6)
            Circle()
                .fill(Color.white)
                .frame(width: knob, height: knob)
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                .offset(x: x - knob / 2)
            Text(verbatim: "\(Int(custom))%")
                .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Signature.ink)
                .contentTransition(.numericText(value: custom))
                .frame(width: 38, height: 20)
                .background(Capsule().fill(Color.white))
                .scaleEffect(sliding ? 1 : 0.5, anchor: .bottom)
                .opacity(sliding ? 1 : 0)
                .offset(x: x - 19, y: -24)
        }
        .frame(width: sliderWidth, height: 30)
        .padding(.top, 16)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($finger) { _, state, _ in state = true }
                .onChanged { value in
                    if !sliding {
                        script?.cancel()
                        scripting = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { sliding = true }
                    }
                    setCustom(Double((value.location.x - 6) / sliderWidth) * 30, user: true)
                }
                .onEnded { _ in endSlide() }
        )
        .onChange(of: finger) { _, down in
            if !down && !scripting { endSlide() }
        }
        .scaleEffect(isCustom ? 1 : 0.85, anchor: .top)
        .opacity(isCustom ? 1 : 0)
        .allowsHitTesting(isCustom)
    }

    // MARK: Actions

    private func select(_ index: Int) {
        withAnimation(spring) { choice = index }
    }

    private func setCustom(_ raw: Double, user: Bool) {
        let value = raw.rounded().clamped(to: 0...30)
        guard value != custom else { return }
        withAnimation(.snappy(duration: 0.18)) { custom = value }
        if user && !ctx.isPreview { Haptics.selection() }
    }

    private func endSlide() {
        guard sliding else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { sliding = false }
    }

    private func autoStep() {
        script?.cancel()
        let next = (choice + 1) % 4
        select(next)
        guard next == 3 else { return }
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            guard await studioPause(0.45) else { return }
            let from = custom
            let target: Double = from > 18 ? 10 : 25
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { sliding = true }
            let finished = await studioScript(0.55) { t in
                setCustom(from + (target - from) * studioEase(t), user: false)
            }
            guard finished else { return }
            endSlide()
        }
    }
}

private struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
