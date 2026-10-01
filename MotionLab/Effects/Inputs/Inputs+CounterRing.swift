import SwiftUI

extension Effect {
    static let inputsCounterRing = Effect(
        id: "inputs.counter-ring",
        category: .inputs,
        interaction: .tap,
        name: L("Character Limit Ring", "字数上限圆环"),
        summary: L("A text area whose corner ring fills as you type, grows and turns amber near the limit, then goes red and shakes the field when you hit it.", "文本框角落的圆环随输入填满，接近上限时变大转琥珀色，触顶后变红并带着输入框一起抖动。"),
        prompt: L(
            "A 288 pt wide text area with a small 22 pt progress ring in its bottom-right corner. As text is typed the ring's indigo arc fills clockwise from 12 o'clock. When 20 characters remain, the ring springs to 130% (response 0.35 s, damping 0.6), turns amber and shows the remaining count inside it; every new character rolls that number and pops the ring to 118% and back. At zero the ring closes, turns red and the number reads 0. Typing past the limit is refused: the whole field shakes sideways through ±8 pt in four decaying swings over 0.3 s, its border flashes red and fades over 0.6 s, the ring thumps to 145% and an error haptic fires. Clearing empties the text with a quick fade while the ring unwinds on a spring and shrinks back to indigo.",
            "288pt 宽的文本框，右下角是一枚 22pt 的进度小圆环。输入时，靛蓝色圆弧从 12 点方向顺时针填充。还剩 20 个字时，圆环以弹簧（响应 0.35 秒、阻尼 0.6）放大到 130%，转为琥珀色，并在环内显示剩余字数；之后每输入一个字，数字滚动一次，圆环弹到 118% 再回落。剩余为零时圆环闭合、变红，数字停在 0。超出上限的输入会被拒绝：整个输入框在 0.3 秒内左右抖动 ±8pt 四次并衰减；边框闪红并在 0.6 秒内褪去，圆环猛地鼓到 145%，同时一次错误触觉。清空时文字淡出，圆环回卷并恢复靛蓝。"
        ),
        implementation: L(
            "The typing is scripted (no keyboard): a task appends characters from a sample text. The ring is a trimmed circle whose colour and scale come from the remaining count; the per-character pop, the limit thump and the field shake are keyframe animators triggered by counters.",
            "输入由脚本模拟（不弹键盘）：一个任务从示例文本里逐字追加。圆环是 trim 过的圆，颜色与缩放由剩余字数决定；逐字弹跳、触顶重击与输入框抖动都是由计数器触发的关键帧动画。"
        ),
        apis: ["trim(from:to:)", "keyframeAnimator", "contentTransition(.numericText)", "TimelineView", "spring(response:dampingFraction:)"],
        tags: ["counter", "character limit", "ring", "text area", "shake", "字数", "上限", "圆环", "文本框", "抖动"],
        params: [
            .slider("limit", L("Character limit", "字数上限"), 40...100, default: 72, step: 1, decimals: 0),
            .slider("warn", L("Warn at remaining", "预警剩余字数"), 5...30, default: 20, step: 1, decimals: 0),
            .slider("shake", L("Shake distance", "抖动幅度"), 2...16, default: 8, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        InputCounterRingDemo(ctx: ctx)
    }
}

private struct InputCounterRingDemo: View {
    let ctx: DemoContext
    @State private var count: Int
    @State private var shakes = 0
    @State private var flash: Double = 0
    @State private var typing = false
    @State private var refusals = 0
    @State private var task: Task<Void, Never>?

    private static let sample = L(
        "Shipped the new onboarding today. Every screen now eases in on one shared spring, and the haptics finally land on the beat. Tell me what feels off.",
        "今天把新的引导流程上线了。每一屏都用同一个弹簧缓缓进场，触觉反馈也终于踩在点上。周末再把设置页的转场顺一遍，然后发一版测试包，欢迎大家来挑毛病，越细越好，哪怕只是一帧不顺也请告诉我。先谢谢各位，我们下周见，到时候再聊。"
    )

    init(ctx: DemoContext) {
        self.ctx = ctx
        _count = State(initialValue: ctx.isStill ? max(ctx.int("limit") - 8, 0) : 0)
    }

    private var limit: Int { max(ctx.int("limit"), 1) }
    private var shownCount: Int { min(count, limit) }
    private var remaining: Int { limit - shownCount }
    private var script: String { Self.sample(ctx.language) }
    private var typed: String { String(script.prefix(shownCount)) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            field
                .keyframeAnimator(initialValue: CGFloat(0), trigger: shakes) { view, x in
                    view.offset(x: x)
                } keyframes: { _ in
                    let reach = ctx.cg("shake")
                    LinearKeyframe(-reach, duration: 0.05)
                    LinearKeyframe(reach, duration: 0.07)
                    LinearKeyframe(-reach * 0.6, duration: 0.06)
                    LinearKeyframe(reach * 0.35, duration: 0.06)
                    SpringKeyframe(0, duration: 0.2, spring: .snappy)
                }
            Spacer(minLength: 0)
            DemoHint(text: L("Tap the field to type; keep going past the limit", "点击输入框打字，一直打到超出上限"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.85, delay: 0.4) { autoTick() }
        .onDisappear { task?.cancel() }
    }

    private var field: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Text(L("What's new?", "有什么新鲜事？"), ctx.language)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            textBody
            Spacer(minLength: 6)
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 288, height: 212, alignment: .topLeading)
        .background(Palette.elevated, in: shape)
        .overlay(shape.strokeBorder(Palette.red.opacity(flash), lineWidth: 2))
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 14, y: 8)
        .contentShape(shape)
        .onTapGesture { typeBurst() }
    }

    private var textBody: some View {
        TimelineView(.periodic(from: .now, by: 0.53)) { timeline in
            let blink = Int(timeline.date.timeIntervalSinceReferenceDate / 0.53) % 2 == 0
            let caret = Text(verbatim: "|")
                .foregroundStyle(Palette.indigo.opacity(typing || blink ? 1 : 0))
                .fontWeight(.light)
            Text("\(Text(verbatim: typed))\(caret)")
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .contentTransition(.opacity)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: clear) {
                Text(L("Clear", "清空"), ctx.language)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(count > 0 ? Palette.indigo : Color.secondary.opacity(0.5))
                    .padding(.vertical, 6)
                    .padding(.trailing, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            Spacer(minLength: 0)
            InputLimitRing(count: shownCount, limit: limit, warn: ctx.int("warn"), thumps: shakes)
        }
        .frame(height: 34)
    }

    // MARK: Actions

    /// Types the next few characters, one at a time. Finger and autoplay both land here.
    private func typeBurst() {
        guard !typing else { return }
        if remaining <= 0 {
            refuse()
            return
        }
        typing = true
        task?.cancel()
        task = Task { @MainActor in
            defer { typing = false }
            for _ in 0..<18 {
                guard !Task.isCancelled else { return }
                if remaining <= 0 {
                    refuse()
                    return
                }
                withAnimation(.easeOut(duration: 0.15)) { count = shownCount + 1 }
                try? await Task.sleep(for: .seconds(0.04))
            }
        }
    }

    private func refuse() {
        if !ctx.isPreview { Haptics.error() }
        refusals += 1
        shakes += 1
        flash = 1
        withAnimation(.easeOut(duration: 0.6)) { flash = 0 }
    }

    private func clear() {
        task?.cancel()
        typing = false
        refusals = 0
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { count = 0 }
    }

    private func autoTick() {
        if refusals >= 2 {
            clear()
        } else {
            typeBurst()
        }
    }
}

private struct InputLimitRing: View {
    let count: Int
    let limit: Int
    let warn: Int
    let thumps: Int

    private var remaining: Int { limit - count }
    private var warning: Bool { remaining <= warn }
    private var tint: Color {
        if remaining <= 0 { return Palette.red }
        return warning ? Palette.amber : Palette.indigo
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(count) / CGFloat(limit))
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: "\(remaining)")
                .font(.system(size: 9.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: Double(remaining)))
                .opacity(warning ? 1 : 0)
                .scaleEffect(warning ? 1 : 0.4)
        }
        .frame(width: 22, height: 22)
        .scaleEffect(warning ? 1.3 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: warning)
        .animation(.easeOut(duration: 0.2), value: remaining <= 0)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: warning ? count : 0) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.18, duration: 0.08, spring: .snappy)
            SpringKeyframe(1, duration: 0.25, spring: .bouncy)
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: thumps) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.45, duration: 0.1, spring: .snappy)
            SpringKeyframe(1, duration: 0.4, spring: .bouncy)
        }
        .padding(.trailing, 4)
    }
}
