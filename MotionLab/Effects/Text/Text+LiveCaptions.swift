import SwiftUI

extension Effect {
    static let textLiveCaptions = Effect(
        id: "text.live-captions",
        category: .text,
        interaction: .loop,
        name: L("Live Captions", "实时字幕"),
        summary: L("Speech turns into captions word by word: tentative words firm up, a misheard word corrects itself, full lines roll away.", "语音逐词变成字幕：未确认的词逐渐变实，听错的词原地改正，写满的行向上滚走。"),
        prompt: L(
            "A call with two speaker tiles above a caption card that shows two lines of 21 pt text. While someone talks, their tile wears a coloured ring and five level bars jump with every word. Words arrive about four per second, pausing at punctuation: each fades in over 0.22 s from 6 pt below with a 5 pt blur, set in grey while it is the newest, unconfirmed word and turning to the full text colour once the next one lands. When a line is full, the block springs up one line (response 0.4 s, damping 0.85) and the oldest line slides out under a soft fade at the top. One word per sentence is misheard: two words later it cross-fades to the right word, neighbours shift to fit and an amber underline marks the fix for a moment. The speaker then changes and the card clears.",
            "两位发言人的小窗下方，是一张显示两行21pt文字的字幕卡片。说话者的小窗带彩色描边，五根音量条随每个词跳动。词语以每秒约四个的速度到来，遇到标点稍作停顿：每个词用0.22秒从下方6pt处、带5pt模糊淡入；最新的、尚未确认的词是灰色，下一个词落下后才变成正文色。一行写满时，整块文字以弹簧（响应0.4秒、阻尼0.85）上移一行，最旧的一行在顶部的柔和渐隐中滑出。每句话里有一个词会被听错：两个词之后它交叉淡变为正确的词，一条琥珀色下划线短暂标出这次修正。随后换人发言，卡片清空。"
        ),
        implementation: L(
            "An async task reveals tokens on a jittered clock; the revealed words live in a wrapping Layout pinned to the bottom of a clipped, top-masked window, so a new row simply pushes the block up under a spring. Tentative colour, the correction swap and its underline are all derived from the revealed count.",
            "一个异步任务按带抖动的节拍逐个放出词语；已出现的词放在一个自动换行的 Layout 里，贴着一个裁剪并带顶部渐隐遮罩的窗口底部，于是新起一行时整块文字就被弹簧推上去。未确认的灰色、纠错替换及其下划线，全部由已出现的词数推导。"
        ),
        apis: ["Layout", "task(id:)", "AnyTransition.modifier(active:identity:)", "mask", "contentTransition(.interpolate)"],
        tags: ["captions", "subtitles", "speech", "transcription", "live", "字幕", "实时转写", "语音识别", "会议", "逐词"],
        params: [
            .slider("rate", L("Words per second", "每秒词数"), 2...9, default: 4, decimals: 1),
            .choice("lines", L("Visible lines", "显示行数"), [L("2", "2 行"), L("3", "3 行")], default: 0),
            .toggle("tentative", L("Tentative words", "未确认状态"), default: true),
        ]
    ) { ctx in
        TextLiveCaptionsDemo(ctx: ctx)
    }
}

private struct CaptionLine {
    let speaker: Int
    let tokens: [String]
    /// The token that is first misheard, and what was heard instead.
    let slip: Int
    let misheard: String
}

private struct TextLiveCaptionsDemo: View {
    let ctx: DemoContext
    @State private var sentence = 0
    @State private var revealed: Int
    @State private var clearing = false
    @State private var talking: Bool
    @State private var levels: [CGFloat] = [0.3, 0.6, 0.9, 0.5, 0.35]
    @State private var runs = 0
    @State private var blockHeight: CGFloat = 0

    private static let lineHeight: CGFloat = 27
    private static let lineSpacing: CGFloat = 5

    init(ctx: DemoContext) {
        self.ctx = ctx
        _revealed = State(initialValue: ctx.isStill ? TextLiveCaptionsDemo.script(ctx.language)[0].tokens.count : 0)
        _talking = State(initialValue: ctx.isStill)
    }

    private static func script(_ language: AppLanguage) -> [CaptionLine] {
        switch language {
        case .zh:
            return [
                CaptionLine(speaker: 0, tokens: ["所以", "思路", "很", "简单：", "字幕", "应该", "是", "活的。", "听到", "一个词", "就", "落下", "一个词，", "一行", "满了", "就", "整体", "往上", "滚。"], slip: 4, misheard: "字母"),
                CaptionLine(speaker: 1, tokens: ["对，", "识别", "结果", "改", "主意", "的", "时候，", "那个", "词", "就", "在", "原地", "换掉，", "谁", "也", "不会", "看丢", "位置。"], slip: 11, misheard: "园地"),
            ]
        case .en:
            return [
                CaptionLine(speaker: 0, tokens: ["So", "the", "idea", "is", "simple:", "captions", "should", "feel", "alive.", "Words", "land", "as", "they", "are", "heard,", "and", "a", "full", "line", "rolls", "away."], slip: 14, misheard: "hurt,"),
                CaptionLine(speaker: 1, tokens: ["Right,", "and", "when", "the", "recogniser", "changes", "its", "mind,", "the", "word", "swaps", "in", "place.", "Nobody", "loses", "their", "spot."], slip: 7, misheard: "mined,"),
            ]
        }
    }

    private var line: CaptionLine {
        let all = Self.script(ctx.language)
        return all[sentence % all.count]
    }

    private let tints: [Color] = [Palette.coral, Palette.sky]
    private var names: [String] { ctx.language == .zh ? ["小满", "阿健"] : ["Maya", "Kenji"] }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                tile(0)
                tile(1)
            }
            card
            DemoHint(text: L("Tap to pass the mic", "点击换人发言"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.light)
            runs += 1
        }
        .task(id: runs) { await run() }
    }

    // MARK: Speaker tiles

    private func tile(_ index: Int) -> some View {
        let active: Bool = line.speaker == index && talking
        let tint: Color = tints[index]
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return VStack(spacing: 7) {
            Circle()
                .fill(LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 38, height: 38)
                .overlay {
                    Text(verbatim: String(names[index].prefix(1)))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .scaleEffect(active ? 1.06 : 1)
            HStack(spacing: 6) {
                Text(verbatim: names[index])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? Color.primary : Color.secondary)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { bar in
                        Capsule()
                            .fill(tint)
                            .frame(width: 2.5, height: active ? 4 + 10 * levels[bar] : 3)
                    }
                }
                .frame(height: 14)
                .opacity(active ? 1 : 0.35)
            }
        }
        .frame(width: 144, height: 88)
        .background(Color.primary.opacity(0.05), in: shape)
        .overlay(shape.strokeBorder(tint.opacity(active ? 0.9 : 0), lineWidth: 2))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: active)
    }

    // MARK: Caption card

    private var card: some View {
        let lines: CGFloat = ctx.int("lines") == 1 ? 3 : 2
        let window: CGFloat = Self.lineHeight * lines + Self.lineSpacing * (lines - 1)
        let current = line
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(verbatim: names[current.speaker])
                    .font(.system(size: 12, weight: .bold))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(tints[current.speaker])
            .animation(.easeInOut(duration: 0.25), value: sentence)

            // The block is pinned by an explicit offset, so a new row moves every line up as one piece.
            words(current)
                .geometryGroup()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    blockHeight = height
                }
                .offset(y: ctx.isStill ? 0 : window - blockHeight)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: blockHeight)
                .frame(width: 268, height: window, alignment: ctx.isStill ? .bottomLeading : .topLeading)
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.22), .init(color: .black, location: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .padding(.top, -6)
                }
                .opacity(clearing ? 0 : 1)
                .offset(y: clearing ? -10 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .demoCard(cornerRadius: 22)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: ctx.int("lines"))
    }

    private func words(_ current: CaptionLine) -> some View {
        let isCJK: Bool = ctx.language == .zh
        let tentative: Bool = ctx.bool("tentative")
        let count: Int = min(revealed, current.tokens.count)
        return TextFXFlow(spacing: isCJK ? 0 : 5, lineSpacing: Self.lineSpacing) {
            ForEach(0..<count, id: \.self) { index in
                let newest: Bool = tentative && index == revealed - 1 && talking
                let isSlip: Bool = index == current.slip
                let fixed: Bool = revealed >= index + 3
                Text(verbatim: isSlip && !fixed ? current.misheard : current.tokens[index])
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(newest ? Color.secondary : Color.primary)
                    .contentTransition(.interpolate)
                    .frame(height: Self.lineHeight)
                    .overlay(alignment: .bottom) {
                        if isSlip {
                            Capsule()
                                .fill(Palette.amber)
                                .frame(height: 2.5)
                                .opacity(fixed && revealed <= index + 6 ? 1 : 0)
                        }
                    }
                    .transition(AnyTransition.captionWord.animation(.easeOut(duration: 0.22)))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 268, alignment: .leading)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: revealed)
        .id(sentence)
    }

    // MARK: Script

    private func run() async {
        guard !ctx.isStill else { return }
        while !Task.isCancelled {
            if revealed > 0 {
                talking = false
                withAnimation(.easeIn(duration: 0.22)) { clearing = true }
                try? await Task.sleep(for: .seconds(0.26))
                if Task.isCancelled { return }
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) {
                    sentence += 1
                    revealed = 0
                    clearing = false
                }
            }
            try? await Task.sleep(for: .seconds(0.45))
            if Task.isCancelled { return }
            talking = true
            let tokens = line.tokens
            for index in tokens.indices {
                if Task.isCancelled { return }
                revealed = index + 1
                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                    levels = (0..<5).map { _ in CGFloat.random(in: 0.2...1) }
                }
                let base: Double = 1 / max(ctx["rate"], 1)
                let lastCharacter = tokens[index].last ?? " "
                let pause: Double = "。.：:".contains(lastCharacter) ? 2.6 : (",，".contains(lastCharacter) ? 1.7 : 1)
                try? await Task.sleep(for: .seconds(base * Double.random(in: 0.7...1.3) * pause))
            }
            if Task.isCancelled { return }
            // The last word is confirmed and the speaker goes quiet.
            withAnimation(.easeOut(duration: 0.3)) { talking = false }
            try? await Task.sleep(for: .seconds(1.7))
        }
    }
}

private struct CaptionArrive: ViewModifier {
    var y: CGFloat
    var blur: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(y: y)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var captionWord: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: CaptionArrive(y: 6, blur: 5, opacity: 0), identity: CaptionArrive(y: 0, blur: 0, opacity: 1)),
            removal: .opacity
        )
    }
}
