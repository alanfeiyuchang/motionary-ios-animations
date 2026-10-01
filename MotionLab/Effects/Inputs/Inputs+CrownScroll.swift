import SwiftUI

extension Effect {
    static let inputsCrownScroll = Effect(
        id: "inputs.crown-scroll",
        category: .inputs,
        interaction: .gesture,
        name: L("Crown Scroll", "表冠滚动"),
        summary: L("Roll a ridged side crown to scroll a value: every step clicks into a detent, and the ends stop on rubber.", "拨动侧面的齿纹表冠滚动数值：每一格都咔哒入位，到头是橡皮筋般的止挡。"),
        prompt: L(
            "A dark watch body with a ridged crown on its right edge and a column of large rounded numerals on screen, the current one centred at full size, its neighbours 28% smaller per step and fading. Dragging vertically rolls the crown: its ridges travel with the finger, compressing and dimming toward the top and bottom edges like a turning cylinder, and the numerals scroll 22 pt of finger travel per step. Each step is a detent: the column lingers near a whole value and then slips to the next one, with a selection haptic per click, while a small scroll indicator beside the crown fades in and tracks the position. Past the first or last value the column rubber-bands up to 40 pt with a rigid haptic. On release it coasts on the fling, then settles on the nearest value with a spring (response 0.5 s, damping 0.78).",
            "一块深色手表：右侧是带齿纹的表冠，屏幕上一列圆体大数字，当前值居中，相邻数字每远一格缩小 28% 并变淡。上下拖动即转动表冠：齿纹随手指移动，靠近上下边缘时变密变暗，像转动的圆柱；手指每移动 22pt，数字滚动一格。每一格都是一个定位点：数列会在整数附近稍作停留，再滑向下一格，每次咔哒伴随一次选择触觉；表冠旁的小指示条淡入并跟随位置。越过首尾数值时，数列以橡皮筋方式最多多拉 40pt，并有一次硬朗触觉。松手后先顺着甩动滑行，再以弹簧（响应 0.5 秒、阻尼 0.78）停在最近的数值上。"
        ),
        implementation: L(
            "One continuous position drives everything through an Animatable view: a detent curve bends it toward whole numbers, a rubber-band curve limits it past the ends, and a Canvas projects the ridge phases onto a cylinder with sin and cos. The drag maps translation to position and projects the predicted end to pick the resting value.",
            "一个连续的位置值通过 Animatable 视图驱动全部内容：定位曲线把它拉向整数，橡皮筋曲线限制越界部分，Canvas 用 sin 与 cos 把齿纹相位投影到圆柱上。拖动把位移映射为位置，并用预测终点决定停靠的数值。"
        ),
        apis: ["Animatable", "Canvas", "DragGesture.predictedEndTranslation", "spring(response:dampingFraction:)", "UISelectionFeedbackGenerator"],
        tags: ["crown", "watch", "dial", "detent", "scroll", "rubber band", "表冠", "手表", "旋钮", "刻度", "滚动", "橡皮筋"],
        params: [
            .slider("unit", L("Travel per step", "每格行程"), 12...40, default: 22, decimals: 0, unit: "pt"),
            .slider("detent", L("Detent strength", "定位力度"), 0...2, default: 0.8, decimals: 1),
            .slider("limit", L("End stretch", "止挡拉伸"), 16...80, default: 40, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        InputCrownScrollDemo(ctx: ctx)
    }
}

private struct InputCrownScrollDemo: View {
    let ctx: DemoContext
    @State private var pos: CGFloat = 5
    @State private var startPos: CGFloat = 0
    @State private var dragging = false
    @State private var active: Bool
    @State private var lastIndex = 5
    @State private var atEnd = false
    /// Fling still to come, in steps (kept so a cancelled touch settles the same way).
    @State private var fling: CGFloat = 0
    @State private var step = 0
    @State private var playTask: Task<Void, Never>?
    @State private var idleTask: Task<Void, Never>?
    @GestureState private var touching = false

    private let maxValue = 12

    init(ctx: DemoContext) {
        self.ctx = ctx
        _active = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            InputCrownWatch(
                pos: pos,
                maxValue: CGFloat(maxValue),
                unit: ctx.cg("unit"),
                detent: ctx.cg("detent"),
                limit: ctx.cg("limit"),
                active: active,
                language: ctx.language
            )
            .frame(width: 230, height: 262)
            .contentShape(Rectangle())
            .gesture(drag)
            Spacer(minLength: 0)
            DemoHint(text: L("Roll the crown up or down", "上下拨动表冠"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: touching) { _, down in
            if !down { settle(projected: pos - fling * 0.4) }
        }
        .autoplay(ctx.isPreview, every: 1.4, delay: 0.5) { play() }
        .onDisappear {
            playTask?.cancel()
            idleTask?.cancel()
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { gesture in
                let unit = ctx.cg("unit")
                if !dragging {
                    playTask?.cancel()
                    dragging = true
                    startPos = pos
                    wake()
                }
                fling = (gesture.predictedEndTranslation.height - gesture.translation.height) / unit
                roll(to: startPos - gesture.translation.height / unit)
            }
            .onEnded { _ in settle(projected: pos - fling * 0.4) }
    }

    /// Finger and autoplay both land here.
    private func roll(to target: CGFloat) {
        pos = target
        let index = Int(target.rounded()).clamped(to: 0...maxValue)
        if index != lastIndex {
            lastIndex = index
            Haptics.selection()
        }
        let beyond = target < -0.05 || target > CGFloat(maxValue) + 0.05
        if beyond && !atEnd { Haptics.tap(.rigid) }
        atEnd = beyond
    }

    private func settle(projected: CGFloat) {
        guard dragging else { return }
        dragging = false
        atEnd = false
        let rest = projected.rounded().clamped(to: 0...CGFloat(maxValue))
        lastIndex = Int(rest)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { pos = rest }
        sleepSoon()
    }

    private func wake() {
        idleTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { active = true }
    }

    private func sleepSoon() {
        idleTask?.cancel()
        idleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { active = false }
        }
    }

    private func play() {
        guard !touching else { return }
        let script: [CGFloat] = [8, 13.4, 9, 3, -1.4, 5]
        let target = script[step % script.count]
        step += 1
        playTask?.cancel()
        playTask = Task { @MainActor in
            wake()
            dragging = true
            let beyond = target < 0 || target > CGFloat(maxValue)
            withAnimation(beyond ? .easeOut(duration: 0.5) : .spring(response: 0.6, dampingFraction: 0.82)) { pos = target }
            try? await Task.sleep(for: .seconds(beyond ? 0.55 : 0.7))
            guard !Task.isCancelled else { return }
            settle(projected: target)
        }
    }
}

private enum InputCrownMath {
    /// Position after the detent curve (inside the range) or the rubber band (outside it), in steps.
    static func display(_ pos: CGFloat, maxValue: CGFloat, unit: CGFloat, detent: CGFloat, limit: CGFloat, row: CGFloat) -> CGFloat {
        if pos < 0 { return rubberBand(pos * unit, limit: limit) / row }
        if pos > maxValue { return maxValue + rubberBand((pos - maxValue) * unit, limit: limit) / row }
        let base = pos.rounded()
        let offset = pos - base
        let shaped = pow(abs(offset) * 2, 1 + detent) / 2
        return base + (offset < 0 ? -shaped : shaped)
    }

    /// How far the crown surface has travelled, in points. It resists past the ends too.
    static func travel(_ pos: CGFloat, maxValue: CGFloat, unit: CGFloat, limit: CGFloat) -> CGFloat {
        if pos < 0 { return rubberBand(pos * unit, limit: limit * 1.5) }
        if pos > maxValue { return maxValue * unit + rubberBand((pos - maxValue) * unit, limit: limit * 1.5) }
        return pos * unit
    }
}

private struct InputCrownWatch: View, Animatable {
    var pos: CGFloat
    let maxValue: CGFloat
    let unit: CGFloat
    let detent: CGFloat
    let limit: CGFloat
    let active: Bool
    let language: AppLanguage

    var animatableData: CGFloat {
        get { pos }
        set { pos = newValue }
    }

    private let bodySize = CGSize(width: 166, height: 202)
    private let row: CGFloat = 62

    var body: some View {
        let shown = InputCrownMath.display(pos, maxValue: maxValue, unit: unit, detent: detent, limit: limit, row: row)
        let travel = InputCrownMath.travel(pos, maxValue: maxValue, unit: unit, limit: limit)
        return ZStack {
            strap.offset(y: -112)
            strap.offset(y: 112)
            crown(travel: travel)
                .offset(x: bodySize.width / 2 + 7, y: -34)
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0x55555C), Color(hex: 0x2A2A2F)], startPoint: .top, endPoint: .bottom))
                .frame(width: 7, height: 36)
                .offset(x: bodySize.width / 2 + 2, y: 34)
            casing
            screen(shown: shown)
        }
        .offset(x: -8)
    }

    private var strap: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x3B3B42), Color(hex: 0x26262B)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 116, height: 44)
    }

    private var casing: some View {
        let shape = RoundedRectangle(cornerRadius: 46, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [Color(hex: 0x4A4A52), Color(hex: 0x1E1E22)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .frame(width: bodySize.width, height: bodySize.height)
            .shadow(color: .black.opacity(0.3), radius: 16, y: 10)
    }

    private func screen(shown: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 38, style: .continuous)
        let nearest = Int(shown.rounded()).clamped(to: 0...Int(maxValue))
        return ZStack {
            Color.black
            ForEach(max(nearest - 2, 0)...min(nearest + 2, Int(maxValue)), id: \.self) { number in
                numeral(number, distance: CGFloat(number) - shown)
            }
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0), location: 0.3),
                    .init(color: .black.opacity(0), location: 0.72),
                    .init(color: .black, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading) {
                Text(L("TIMER", "计时"), language)
                    .foregroundStyle(Palette.amber)
                Spacer()
                Text(L("MIN", "分钟"), language)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            indicator(shown: shown)
        }
        .frame(width: bodySize.width - 16, height: bodySize.height - 16)
        .clipShape(shape)
    }

    private func numeral(_ number: Int, distance: CGFloat) -> some View {
        let far = min(abs(distance), 2)
        return Text(verbatim: "\(number)")
            .font(.system(size: 68, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.white)
            .scaleEffect(1 - far * 0.28)
            .opacity(Double(1 - far * 0.42))
            .rotation3DEffect(.degrees(Double(distance) * -28), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .offset(y: distance * row * (1 - far * 0.08))
    }

    /// The small pill that appears next to the crown while scrolling.
    private func indicator(shown: CGFloat) -> some View {
        let fraction = min(max(shown / maxValue, -0.08), 1.08)
        return Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(width: 5, height: 40)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Palette.amber)
                    .frame(width: 5, height: 14)
                    .offset(y: fraction * 26)
            }
            .clipShape(Capsule())
            .opacity(active ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 9)
            .padding(.top, 47)
    }

    private func crown(travel: CGFloat) -> some View {
        let size = CGSize(width: 18, height: 52)
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return Canvas { context, canvas in
            let radius = canvas.height / 2
            let spacing: CGFloat = 0.34
            // Angle of the cylinder surface, in radians: positive travel turns it upward.
            let turn = travel / radius
            let first = Int(((-.pi / 2 + turn) / spacing).rounded(.up))
            let last = Int(((.pi / 2 + turn) / spacing).rounded(.down))
            guard first <= last else { return }
            for index in first...last {
                let phi = CGFloat(index) * spacing - turn
                let y = radius + sin(phi) * radius
                let facing = cos(phi)
                var line = Path()
                line.move(to: CGPoint(x: 1, y: y))
                line.addLine(to: CGPoint(x: canvas.width - 1, y: y))
                context.stroke(line, with: .color(Color.black.opacity(0.55 * Double(facing))), lineWidth: max(2.4 * facing, 0.4))
                var glint = Path()
                glint.move(to: CGPoint(x: 1, y: y + 1.6 * facing))
                glint.addLine(to: CGPoint(x: canvas.width - 1, y: y + 1.6 * facing))
                context.stroke(glint, with: .color(Color.white.opacity(0.3 * Double(facing))), lineWidth: 0.8)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1F1F23), Color(hex: 0x8A8A93), Color(hex: 0xB8B8C0), Color(hex: 0x77777F), Color(hex: 0x1F1F23)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(shape)
        .overlay(shape.strokeBorder(active ? Palette.amber.opacity(0.9) : Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: Palette.amber.opacity(active ? 0.5 : 0), radius: 6)
    }
}
