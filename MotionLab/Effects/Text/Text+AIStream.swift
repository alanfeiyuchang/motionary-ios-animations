import SwiftUI

extension Effect {
    static let textAIStream = Effect(
        id: "text.ai-stream",
        category: .text,
        interaction: .tap,
        name: L("AI Token Stream", "AI 逐词流式输出"),
        summary: L("An answer streams in token by token: each word focuses out of blur behind a soft glowing caret.", "回答逐词流出：每个词在发光光标后面由模糊对焦成形。"),
        prompt: L(
            "An assistant answer in 19 pt medium type streams in token by token under a small sparkle avatar. Tokens arrive about 14 per second in an uneven rhythm, with a longer beat after punctuation. Each one fades in over 0.35 s with ease-out while rising 6 pt and sharpening from a 6 pt blur; the two newest tokens carry a violet tint that settles to the text colour. A rounded 3 pt gradient caret with a soft glow glides to the end of the newest token on a quick spring (0.22 s) and breathes while it waits. When the answer is complete the caret shrinks away and three action icons fade up 60 ms apart. Tapping regenerates: the text blurs out and the next answer streams.",
            "助手的回答以19pt中等字重逐词流出，上方是一枚小小的星芒头像。词元以每秒约14个、略不均匀的节奏到来，标点之后多停一拍。每个词用0.35秒缓出淡入，同时上升6pt，并从6pt模糊对焦清晰；最新的两个词带一层紫色，随后沉淀为正文色。一枚3pt宽、带柔光的圆角渐变光标以很快的弹簧（0.22秒）滑到最新词的末尾，等待时轻轻呼吸。回答结束后光标缩小消失，三个操作图标以60毫秒间隔依次浮现。点击即重新生成：文字整体模糊退去，下一段回答重新流出。安静、有思考感的节奏。"
        ),
        implementation: L(
            "Every token is its own Text in a custom wrapping Layout, so the paragraph never reflows; a task advances a reveal index with jittered sleeps, tokens animate opacity, blur and offset from it, and the caret is a layout subview placed after the newest token.",
            "每个词元是自定义换行 Layout 中的一个独立 Text，段落因此不会重排；任务以带抖动的间隔推进揭示索引，词元据此动画透明度、模糊和位移，光标是布局中被放在最新词元之后的子视图。"
        ),
        apis: ["Layout", "Task.sleep", "blur(radius:)", "spring(response:dampingFraction:)", "symbolEffect"],
        tags: ["ai", "stream", "token", "chat", "caret", "流式", "逐词", "大模型", "对话", "光标"],
        params: [
            .slider("rate", L("Tokens per second", "每秒词元数"), 4...30, default: 14, decimals: 0),
            .slider("fade", L("Token fade", "词元淡入"), 0.1...0.8, default: 0.35, unit: "s"),
            .slider("blur", L("Blur", "模糊"), 0...12, default: 6, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        TextAIStreamDemo(ctx: ctx)
    }
}

private struct TextAIStreamDemo: View {
    let ctx: DemoContext
    @State private var answer = 0
    @State private var revealed: Int
    @State private var done: Bool
    @State private var clearing = false
    @State private var breathe = false
    /// Bumped by a tap or the autoplay: restarts the stream with the next answer.
    @State private var runs = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        let count = TextAIStreamDemo.answers(ctx.language)[0].count
        _revealed = State(initialValue: ctx.isStill ? count : 0)
        _done = State(initialValue: ctx.isStill)
    }

    private static func answers(_ language: AppLanguage) -> [[String]] {
        switch language {
        case .zh:
            return [
                ["好的", "动效", "只做", "三件", "事：", "立刻", "回应", "手指，", "把", "前后", "两个", "状态", "连", "起来，", "然后", "安静", "地", "退场。", "先", "保证", "100", "毫秒", "内", "有", "反馈，", "再用", "弹簧", "衔接，", "最后", "删掉", "多余", "的", "装饰。"],
                ["可以", "这样", "调：", "响应", "0.35", "秒、", "阻尼", "0.8，", "按下", "即时，", "松手", "回弹。", "幅度", "越小，", "越", "显得", "高级；", "拿", "不准", "时，", "就", "再", "慢", "一点", "点。"],
            ]
        case .en:
            return [
                ["Great", "motion", "does", "three", "things:", "it", "answers", "the", "finger", "at", "once,", "links", "one", "state", "to", "the", "next,", "then", "gets", "out", "of", "the", "way.", "Cut", "what", "only", "decorates."],
                ["Try", "this:", "response", "0.35 s,", "damping", "0.8.", "Press", "is", "instant,", "release", "is", "elastic.", "Smaller", "moves", "read", "as", "more", "premium;", "when", "unsure,", "slow", "it", "down", "a", "touch."],
            ]
        }
    }

    private var tokens: [String] {
        let all = Self.answers(ctx.language)
        return all[answer % all.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            paragraph
                .frame(width: 290, alignment: .leading)
                .frame(minHeight: 160, alignment: .topLeading)
            actions
        }
        .frame(width: 290, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Tap to regenerate", "点击重新生成"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.light)
            regenerate()
        }
        .autoplay(ctx.isPreview, every: 6.5, delay: 5.2, intro: false) { regenerate() }
        .task(id: runs) { await stream(restart: runs > 0) }
        .onAppear {
            guard !ctx.isStill else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating, isActive: !done && !ctx.isStill)
                .frame(width: 28, height: 28)
                .background(Palette.primary, in: Circle())
                .shadow(color: Palette.violet.opacity(done ? 0 : 0.55), radius: done ? 0 : 8)
                .animation(.easeInOut(duration: 0.4), value: done)
            Text(verbatim: "Motionary AI")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(done ? L("Answered", "已回答") : L("Writing…", "正在输出…"), ctx.language)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: done)
        }
    }

    private var paragraph: some View {
        let words = tokens
        let isCJK = ctx.language == .zh
        return TextFXFlow(spacing: isCJK ? 0 : 5, lineSpacing: 7, markerAfter: min(revealed, words.count) - 1) {
            ForEach(words.indices, id: \.self) { index in
                TextAIToken(
                    text: words[index],
                    shown: index < revealed,
                    fresh: index >= revealed - 2 && !done,
                    fade: ctx["fade"],
                    blur: ctx.cg("blur")
                )
            }
            caret
        }
        .opacity(clearing ? 0 : 1)
        .blur(radius: clearing ? 8 : 0)
        .id(answer)
    }

    private var caret: some View {
        Capsule()
            .fill(LinearGradient(colors: [Palette.indigo, Palette.violet], startPoint: .top, endPoint: .bottom))
            .frame(width: 3, height: 21)
            .shadow(color: Palette.violet.opacity(0.8), radius: 5)
            .opacity(breathe ? 0.45 : 1)
            .padding(.leading, 3)
            .scaleEffect(y: done ? 0.01 : 1)
            .opacity(done ? 0 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: revealed)
            .animation(.easeOut(duration: 0.25), value: done)
    }

    private var actions: some View {
        let symbols = ["doc.on.doc", "hand.thumbsup", "arrow.clockwise"]
        return HStack(spacing: 18) {
            ForEach(symbols.indices, id: \.self) { index in
                Image(systemName: symbols[index])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(done ? 1 : 0)
                    .offset(y: done ? 0 : 6)
                    .animation(.easeOut(duration: 0.3).delay(done ? 0.15 + Double(index) * 0.06 : 0), value: done)
            }
        }
    }

    private func regenerate() {
        runs += 1
    }

    private func stream(restart: Bool) async {
        guard !ctx.isStill else { return }
        if restart {
            withAnimation(.easeIn(duration: 0.25)) { clearing = true }
            try? await Task.sleep(for: .seconds(0.28))
            if Task.isCancelled { return }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                answer += 1
                revealed = 0
                done = false
                clearing = false
            }
        } else {
            revealed = 0
            done = false
        }
        try? await Task.sleep(for: .seconds(0.5))
        let words = tokens
        for index in words.indices {
            if Task.isCancelled { return }
            revealed = index + 1
            let base: Double = 1 / max(ctx["rate"], 1)
            let jitter: Double = Double.random(in: 0.55...1.5)
            let last = words[index].last ?? " "
            let pause: Double = "。.：:；;".contains(last) ? 3.2 : (",，、".contains(last) ? 1.9 : 1)
            try? await Task.sleep(for: .seconds(base * jitter * pause))
        }
        if Task.isCancelled { return }
        try? await Task.sleep(for: .seconds(0.25))
        if Task.isCancelled { return }
        done = true
    }
}

private struct TextAIToken: View {
    let text: String
    let shown: Bool
    let fresh: Bool
    let fade: Double
    let blur: CGFloat

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(fresh ? Palette.violet : Color.primary)
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : blur)
            .offset(y: shown ? 0 : 6)
            .animation(.easeOut(duration: fade), value: shown)
            .animation(.easeOut(duration: 0.6), value: fresh)
    }
}
