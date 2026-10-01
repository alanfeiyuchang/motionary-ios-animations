import SwiftUI

extension Effect {
    static let textLetterMorph = Effect(
        id: "text.letter-morph",
        category: .text,
        interaction: .loop,
        name: L("Shared-Letter Morph", "共用字母变形"),
        summary: L("Words swap by keeping the letters they share: those glide to their new places while the rest blur in and out.", "换词时保留共有的字母：它们滑到新位置，其余字母模糊着进出。"),
        prompt: L(
            "A headline keyword in 54 pt heavy rounded type changes about every 2 s, but instead of swapping the whole word it keeps every letter the two words share. Shared letters glide horizontally to their new positions on a spring (response 0.5 s, damping 0.78) and never fade. Letters that are no longer needed shrink to 60%, blur 8 pt and fade out where they stood; new letters grow from 60% and focus in 30 ms apart, arriving in a violet tint that settles to the text colour over 0.9 s. The word stays centred as its width changes and a short gradient rule beneath it stretches to the new width on the same spring. It feels like one word rearranging itself.",
            "一个54pt粗圆体的标题关键词大约每2秒换一次，但不是整词替换，而是保留前后两个词共有的每一个字母。共有的字母以弹簧（响应0.5秒、阻尼0.78）横向滑到新位置，全程不淡出；不再需要的字母在原地缩到60%、模糊8pt并淡出；新字母从60%放大并对焦出现，彼此间隔30毫秒，到位时带一层紫色，再用0.9秒沉淀为正文色。词宽变化时单词始终居中，下方一道短短的渐变细线以同一根弹簧伸缩到新的宽度。看上去不像在换词，而像同一个词在重新排列自己。"
        ),
        implementation: L(
            "A longest-common-subsequence match between the old and new word decides which characters keep their identity; an HStack of identified Text views is updated inside withAnimation, so kept letters animate their layout position while the others use a custom blur-and-scale Transition.",
            "对新旧两个词做最长公共子序列匹配，决定哪些字符保留身份；带身份标识的 Text 组成的 HStack 在 withAnimation 中更新，保留的字母动画其布局位置，其余字母使用自定义的模糊缩放 Transition。"
        ),
        apis: ["Transition", "ForEach(id:)", "withAnimation", "spring(response:dampingFraction:)", "blur(radius:)"],
        tags: ["morph", "letters", "diff", "rotating words", "headline", "变形", "字母", "换词", "共用", "关键词"],
        params: [
            .slider("interval", L("Interval", "间隔"), 1.2...4, default: 2.0, decimals: 1, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1, default: 0.78),
            .slider("blur", L("Blur", "模糊"), 0...14, default: 8, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        TextLetterMorphDemo(ctx: ctx)
    }
}

private struct MorphLetter: Identifiable, Equatable {
    let id: Int
    let character: Character
    /// Order among the letters that were added in the same change (for the stagger).
    var arrival: Int
    var isNew: Bool
}

private struct TextLetterMorphDemo: View {
    let ctx: DemoContext
    @State private var index = 0
    @State private var letters: [MorphLetter]
    @State private var nextID: Int

    init(ctx: DemoContext) {
        self.ctx = ctx
        let first = Array(TextLetterMorphDemo.words(ctx.language)[0])
        _letters = State(initialValue: first.enumerated().map {
            MorphLetter(id: $0.offset, character: $0.element, arrival: 0, isNew: false)
        })
        _nextID = State(initialValue: first.count)
    }

    private static func words(_ language: AppLanguage) -> [String] {
        switch language {
        case .zh: return ["动效", "动效设计", "交互设计", "交互动效", "微交互", "微动效"]
        case .en: return ["creative", "reactive", "interactive", "active", "attractive"]
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(L("Make it", "认真做好"), ctx.language)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            word
            DemoHint(text: L("Tap for the next word", "点击切换下一个词"), ctx: ctx)
                .padding(.top, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            advance()
        }
        .autoplay(true, every: max(ctx["interval"], 0.6), delay: max(ctx["interval"], 0.6)) { advance() }
    }

    private var word: some View {
        HStack(spacing: 0) {
            ForEach(letters) { letter in
                MorphGlyph(letter: letter, isStill: ctx.isStill)
                    .transition(
                        MorphLetterTransition(blur: ctx.cg("blur"))
                            .animation(spring.delay(Double(letter.arrival) * 0.03))
                    )
            }
        }
        .fixedSize()
        .frame(height: 72)
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(LinearGradient(colors: [Palette.indigo, Palette.violet, Palette.pink], startPoint: .leading, endPoint: .trailing))
                .frame(height: 5)
                .padding(.horizontal, 3)
                .offset(y: 10)
        }
    }

    private var spring: Animation {
        .spring(response: ctx["response"], dampingFraction: ctx["damping"])
    }

    private func advance() {
        let all = Self.words(ctx.language)
        index += 1
        let target: [Character] = Array(all[index % all.count])
        let current = letters
        let kept = Self.commonSubsequence(current.map(\.character), target)
        var next: [MorphLetter] = []
        var id = nextID
        var arrivals = 0
        var keptCursor = 0
        for (position, character) in target.enumerated() {
            if keptCursor < kept.count && kept[keptCursor].new == position {
                var letter = current[kept[keptCursor].old]
                letter.isNew = false
                next.append(letter)
                keptCursor += 1
            } else {
                next.append(MorphLetter(id: id, character: character, arrival: arrivals, isNew: true))
                id += 1
                arrivals += 1
            }
        }
        nextID = id
        withAnimation(spring) {
            letters = next
        }
    }

    /// Longest common subsequence: index pairs (old, new) of the characters both words share, in order.
    private static func commonSubsequence(_ a: [Character], _ b: [Character]) -> [(old: Int, new: Int)] {
        guard !a.isEmpty, !b.isEmpty else { return [] }
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var pairs: [(old: Int, new: Int)] = []
        var i = 0
        var j = 0
        while i < a.count && j < b.count {
            if a[i] == b[j] {
                pairs.append((i, j))
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return pairs
    }
}

private struct MorphGlyph: View {
    let letter: MorphLetter
    let isStill: Bool
    @State private var settled: Bool

    init(letter: MorphLetter, isStill: Bool) {
        self.letter = letter
        self.isStill = isStill
        _settled = State(initialValue: !letter.isNew)
    }

    var body: some View {
        Text(verbatim: String(letter.character))
            .font(.system(size: 54, weight: .heavy, design: .rounded))
            .foregroundStyle(settled ? Color.primary : Palette.violet)
            .onAppear {
                guard !settled else { return }
                withAnimation(.easeOut(duration: 0.9).delay(0.3)) { settled = true }
            }
    }
}

private struct MorphLetterTransition: Transition {
    var blur: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.6)
            .blur(radius: phase.isIdentity ? 0 : blur)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
