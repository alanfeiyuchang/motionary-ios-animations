import SwiftUI

extension Effect {
    static let textSquiggleUnderline = Effect(
        id: "text.squiggle-underline",
        category: .text,
        interaction: .tap,
        name: L("Squiggle Underline", "波浪下划线"),
        summary: L("A marker squiggle draws under the key word, twangs once like a plucked string and settles.", "一道马克笔波浪线划到关键词下方，像被拨动的弦一样颤一下再停稳。"),
        prompt: L(
            "A 30 pt bold sentence with three key words; one of them carries a hand-drawn squiggle underline. When a key word is chosen, the old underline is wiped away from its starting end in 0.22 s and the new one draws left to right in 0.5 s with ease-in-out: five crests, slightly irregular like a quick marker stroke, a 4 pt line that tapers to about half at both ends. The instant it finishes it twangs: the wave height kicks to 190% and the crests slide half a wavelength, both settling on a loose spring (response 0.5 s, damping 0.35) while the word hops 4 pt and takes the underline's colour. A light haptic lands with the twang. Playful emphasis that feels drawn, not rendered.",
            "一句30pt粗体的话里有三个关键词，其中一个带着手绘的波浪下划线。选中某个关键词时，旧的下划线在0.22秒内从起笔一端被抹掉，新的下划线用0.5秒以缓入缓出从左画到右：五个波峰，略带不规则，像马克笔快速划过，线宽4pt，两端收细到一半左右。画完的瞬间它会颤一下：浪高猛地涨到190%，波峰顺势滑过半个波长，再一起由一根偏松的弹簧（响应0.5秒、阻尼0.35）收回；同时关键词向上跳4pt并染成下划线的颜色，一下轻触感落在颤动的那一刻。俏皮的强调，像画出来的，而不是渲染出来的。"
        ),
        implementation: L(
            "The underline is a filled Shape built as a variable-width ribbon around a sine centreline; its start, end, amplitude and phase are animatableData, so one easeInOut draws it and one spring twangs it. Words sit in a custom wrapping Layout and each owns its underline state.",
            "下划线是一个填充的 Shape，沿正弦中心线构造出宽度变化的带状轮廓；起点、终点、振幅和相位都是 animatableData，一段 easeInOut 负责绘制，一根弹簧负责颤动。单词放在自定义换行 Layout 中，各自持有下划线的状态。"
        ),
        apis: ["Shape", "AnimatablePair", "Layout", "spring(response:dampingFraction:)", "overlay(alignment:)"],
        tags: ["underline", "squiggle", "wavy", "marker", "emphasis", "下划线", "波浪线", "手绘", "强调", "划重点"],
        params: [
            .slider("duration", L("Draw duration", "绘制时长"), 0.2...1.2, default: 0.5, unit: "s"),
            .slider("crests", L("Crests", "波峰数"), 2...9, default: 5, step: 1, decimals: 0),
            .slider("damping", L("Twang damping", "颤动阻尼"), 0.15...1, default: 0.35),
            .slider("width", L("Stroke width", "笔画粗细"), 2...8, default: 4, decimals: 1, unit: "pt"),
        ]
    ) { ctx in
        TextSquiggleUnderlineDemo(ctx: ctx)
    }
}

private struct SquiggleToken: Identifiable {
    let id: Int
    let text: String
    /// Index among the key words, or nil for plain words.
    let key: Int?
}

private struct TextSquiggleUnderlineDemo: View {
    let ctx: DemoContext
    @State private var active = 0

    private let colors: [Color] = [Palette.coral, Palette.indigo, Palette.mint]

    private var tokens: [SquiggleToken] {
        let raw: [(String, Bool)] = ctx.language == .zh
            ? [("把", false), ("重点", true), ("画出来，", false), ("一眼", true), ("就能", false), ("看见", true), ("。", false)]
            : [("Make", false), ("the", false), ("important", true), ("words", false), ("impossible", true), ("to", false), ("miss.", true)]
        var key = 0
        var result: [SquiggleToken] = []
        for (index, item) in raw.enumerated() {
            result.append(SquiggleToken(id: index, text: item.0, key: item.1 ? key : nil))
            if item.1 { key += 1 }
        }
        return result
    }

    var body: some View {
        let isCJK = ctx.language == .zh
        VStack(spacing: 34) {
            TextFXFlow(spacing: isCJK ? 0 : 9, lineSpacing: 20, centered: true) {
                ForEach(tokens) { token in
                    SquiggleWord(
                        token: token,
                        isActive: token.key == active,
                        color: colors[(token.key ?? 0) % colors.count],
                        fontSize: isCJK ? 40 : 30,
                        ctx: ctx
                    )
                    .onTapGesture {
                        Haptics.selection()
                        if let key = token.key { active = key } else { next() }
                    }
                }
            }
            .frame(width: 304)
            DemoHint(text: L("Tap a key word", "点击任意关键词"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            next()
        }
        .autoplay(ctx.isPreview, every: ctx["duration"] + 1.9) { next() }
    }

    private func next() {
        active = (active + 1) % colors.count
    }
}

private struct SquiggleWord: View {
    let token: SquiggleToken
    let isActive: Bool
    let color: Color
    let fontSize: CGFloat
    let ctx: DemoContext

    @State private var from: CGFloat = 0
    @State private var to: CGFloat
    @State private var amplitude: CGFloat = 1
    @State private var phase: CGFloat = 0
    @State private var hop = false
    @State private var tinted: Bool
    @State private var task: Task<Void, Never>?

    init(token: SquiggleToken, isActive: Bool, color: Color, fontSize: CGFloat, ctx: DemoContext) {
        self.token = token
        self.isActive = isActive
        self.color = color
        self.fontSize = fontSize
        self.ctx = ctx
        _to = State(initialValue: isActive ? 1 : 0)
        _tinted = State(initialValue: isActive)
    }

    var body: some View {
        Text(verbatim: token.text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(tinted ? color : Color.primary)
            .offset(y: hop ? -4 : 0)
            .overlay(alignment: .bottom) {
                if token.key != nil {
                    SquiggleRibbon(
                        from: from,
                        to: to,
                        amplitude: amplitude,
                        phase: phase,
                        crests: ctx["crests"],
                        thickness: ctx.cg("width")
                    )
                    .fill(color)
                    .frame(height: 13)
                    .padding(.horizontal, -3)
                    .offset(y: 10)
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onChange(of: isActive) { _, now in
                if now { draw() } else { erase() }
            }
            .onDisappear { task?.cancel() }
    }

    private func draw() {
        task?.cancel()
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            from = 0
            to = 0
            amplitude = 1
        }
        let duration: Double = ctx["duration"]
        let damping: Double = ctx["damping"]
        let silent = ctx.isPreview
        task = Task { @MainActor in
            // Let the old underline start leaving first.
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: duration)) { to = 1 }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            if !silent { Haptics.tap(.light) }
            // The twang: kick, then release everything on one loose spring.
            withAnimation(.easeOut(duration: 0.07)) {
                amplitude = 1.9
                hop = true
            }
            withAnimation(.easeOut(duration: 0.2)) { tinted = true }
            try? await Task.sleep(for: .seconds(0.07))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: damping)) {
                amplitude = 1
                phase += .pi
                hop = false
            }
        }
    }

    private func erase() {
        task?.cancel()
        withAnimation(.easeIn(duration: 0.22)) { from = 1 }
        withAnimation(.easeOut(duration: 0.3)) {
            tinted = false
            hop = false
        }
    }
}

/// A marker stroke: a sine centreline thickened into a ribbon that is fuller in the middle than at its ends.
private struct SquiggleRibbon: Shape {
    var from: CGFloat
    var to: CGFloat
    var amplitude: CGFloat
    var phase: CGFloat
    var crests: Double
    var thickness: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(from, to), AnimatablePair(amplitude, phase)) }
        set {
            from = newValue.first.first
            to = newValue.first.second
            amplitude = newValue.second.first
            phase = newValue.second.second
        }
    }

    private func centre(_ p: CGFloat, in rect: CGRect) -> CGPoint {
        let u = Double(p)
        let envelope: Double = 0.6 + 0.4 * sin(Double.pi * u)
        let main: Double = sin(u * Double.pi * 2 * crests + Double(phase))
        let wander: Double = 0.22 * sin(u * Double.pi * 2 * crests * 0.37 + 1.7)
        let height: CGFloat = rect.height * 0.26 * amplitude
        return CGPoint(
            x: rect.minX + rect.width * p,
            // A real stroke climbs a little as the hand moves right.
            y: rect.midY + height * CGFloat(envelope * (main + wander)) - (p - 0.5) * 2.5
        )
    }

    func path(in rect: CGRect) -> Path {
        let start: CGFloat = min(max(from, 0), 1)
        let end: CGFloat = min(max(to, 0), 1)
        guard end - start > 0.004 else { return Path() }
        let steps: Int = max(Int((end - start) * 90), 4)
        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        for step in 0...steps {
            let p: CGFloat = start + (end - start) * CGFloat(step) / CGFloat(steps)
            let point = centre(p, in: rect)
            let ahead = centre(min(p + 0.004, 1), in: rect)
            let behind = centre(max(p - 0.004, 0), in: rect)
            let dx: CGFloat = ahead.x - behind.x
            let dy: CGFloat = ahead.y - behind.y
            let length: CGFloat = max(hypot(dx, dy), 0.0001)
            // Pressure: fuller in the middle of the whole stroke, lighter where the pen lands and lifts.
            let pressure: CGFloat = 0.5 + 0.5 * CGFloat(pow(sin(Double.pi * Double(p)), 0.55))
            let half: CGFloat = thickness * pressure / 2
            let nx: CGFloat = -dy / length * half
            let ny: CGFloat = dx / length * half
            upper.append(CGPoint(x: point.x + nx, y: point.y + ny))
            lower.append(CGPoint(x: point.x - nx, y: point.y - ny))
        }
        var path = Path()
        path.addLines(upper + lower.reversed())
        path.closeSubpath()
        // Round the two ends.
        for index in [0, upper.count - 1] {
            let a = upper[index]
            let b = lower[index]
            let radius: CGFloat = hypot(a.x - b.x, a.y - b.y) / 2
            let middle = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            path.addEllipse(in: CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}
