import SwiftUI

extension Effect {
    static let textGradientFlow = Effect(
        id: "text.gradient-flow",
        category: .text,
        interaction: .loop,
        name: L("Flowing Gradient Heading", "流动渐变标题"),
        summary: L("A seven-colour gradient streams endlessly through a heading while its own glow breathes underneath.", "七色渐变在标题里无尽流淌，同色的光晕在下方缓缓呼吸。"),
        prompt: L(
            "A two-line 54 pt black rounded heading is filled with a seven-colour gradient (indigo, violet, pink, coral, amber, mint, sky) tilted 20° that flows through the letters without a seam, one full cycle taking about 4.5 s. Behind it a blurred copy of the same moving gradient forms a glow of 16 pt radius whose opacity breathes between 35% and 75% and whose blur swells by a third on a 2.8 s sine cycle, so the heading seems to emit its own light. Tapping sends a pulse: the heading swells to 104% and settles on a bouncy spring (response 0.4 s, damping 0.5), the glow flares to full, and the colours rush ahead at four times the speed before easing back.",
            "一个两行、54pt的特粗圆体标题，由七种颜色（靛蓝、紫、粉、珊瑚、琥珀、薄荷、天蓝）组成的渐变填充，渐变倾斜20°，在字形里无缝流动，约4.5秒走完一轮。标题背后是同一条流动渐变的模糊副本，形成半径16pt的光晕：透明度在35%到75%之间呼吸，模糊半径同步涨落三分之一，周期2.8秒，标题像在自己发光。点击会送出一次脉冲：标题以带回弹的弹簧（响应0.4秒、阻尼0.5）鼓到104%再回落，光晕瞬间提到最亮，颜色以四倍速度向前冲一段后缓缓回落。"
        ),
        implementation: L(
            "The heading uses a LinearGradient with two periods of the palette as its foregroundStyle; a TimelineView shifts the gradient's start and end points by exactly one period per cycle, and a blurred duplicate behind it has its opacity and radius driven by a sine of time.",
            "标题以包含两个周期色板的 LinearGradient 作为 foregroundStyle；TimelineView 每个循环把渐变的起止点恰好平移一个周期，背后的模糊副本由时间的正弦驱动其透明度和半径。"
        ),
        apis: ["LinearGradient", "TimelineView", "foregroundStyle", "blur(radius:)", "UnitPoint"],
        tags: ["gradient", "flow", "glow", "heading", "rainbow", "渐变", "流动", "光晕", "标题", "彩色文字"],
        params: [
            .slider("speed", L("Flow speed", "流速"), 0.05...1.0, default: 0.22, unit: "×/s"),
            .slider("angle", L("Gradient angle", "渐变角度"), 0...90, default: 20, decimals: 0, unit: "°"),
            .slider("glow", L("Glow radius", "光晕半径"), 0...30, default: 16, decimals: 0, unit: "pt"),
            .slider("breath", L("Breath period", "呼吸周期"), 1...6, default: 2.8, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        TextGradientFlowDemo(ctx: ctx)
    }
}

private struct GradientFlowSim {
    var last: Date?
    var phase: Double = 0.18
    var boost: Double = 0
}

private struct TextGradientFlowDemo: View {
    let ctx: DemoContext
    @State private var sim = TextFXBox(GradientFlowSim())
    @State private var swell = false
    @State private var flare: Double = 0

    private static let palette: [Color] = [
        Palette.indigo, Palette.violet, Palette.pink, Palette.coral, Palette.amber, Palette.mint, Palette.sky,
    ]

    var body: some View {
        VStack(spacing: 26) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let phase = advance(to: timeline.date)
                let time: Double = ctx.isStill ? 0.7 : timeline.date.timeIntervalSinceReferenceDate
                let breath: Double = 0.5 + 0.5 * sin(time * 2 * Double.pi / max(ctx["breath"], 0.2))
                let style = gradient(phase: phase)
                ZStack {
                    heading
                        .foregroundStyle(style)
                        .blur(radius: ctx.cg("glow") * CGFloat(0.75 + 0.33 * breath))
                        .opacity(0.35 + 0.40 * breath)
                    heading
                        .foregroundStyle(style)
                        .blur(radius: ctx.cg("glow") * 1.5)
                        .opacity(flare)
                    heading
                        .foregroundStyle(style)
                }
            }
            .scaleEffect(swell ? 1.04 : 1)
            DemoHint(text: L("Tap to send a pulse", "点击送出一次脉冲"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.soft)
            pulse()
        }
        .autoplay(ctx.isPreview, every: 4.2, delay: 1.6) { pulse() }
    }

    private var heading: some View {
        Text(L("Colour\nin motion", "让色彩\n流动起来"), ctx.language)
            .font(.system(size: ctx.language == .zh ? 58 : 54, weight: .black, design: .rounded))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize()
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
    }

    /// Two periods of the palette along the tilted axis, shifted by `phase` of one period: a seamless loop.
    private func gradient(phase: Double) -> LinearGradient {
        let colors = Self.palette
        let count = colors.count
        var stops: [Gradient.Stop] = []
        for index in 0...(count * 2) {
            stops.append(.init(color: colors[index % count], location: CGFloat(index) / CGFloat(count * 2)))
        }
        let angle: Double = ctx["angle"] * Double.pi / 180
        let dx: Double = cos(angle)
        let dy: Double = sin(angle)
        let period: Double = 1.5
        let fraction: Double = phase - phase.rounded(.down)
        let startOffset: Double = -0.75 - fraction * period
        let endOffset: Double = startOffset + 2 * period
        return LinearGradient(
            stops: stops,
            startPoint: UnitPoint(x: 0.5 + dx * startOffset, y: 0.5 + dy * startOffset),
            endPoint: UnitPoint(x: 0.5 + dx * endOffset, y: 0.5 + dy * endOffset)
        )
    }

    private func advance(to date: Date) -> Double {
        guard !ctx.isStill else { return 0.18 }
        var state = sim.value
        if let last = state.last {
            let dt: Double = min(max(date.timeIntervalSince(last), 0), 0.1)
            if dt > 0 {
                state.phase += ctx["speed"] * (1 + 3 * state.boost) * dt
                state.boost *= exp(-dt * 2.4)
                state.last = date
            }
        } else {
            state.last = date
        }
        sim.value = state
        return state.phase
    }

    private func pulse() {
        sim.value.boost = 1
        withAnimation(.easeOut(duration: 0.12)) {
            swell = true
            flare = 0.9
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.12)) { swell = false }
        withAnimation(.easeOut(duration: 0.9).delay(0.14)) { flare = 0 }
    }
}
