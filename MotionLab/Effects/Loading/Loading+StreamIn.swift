import SwiftUI
import UIKit

extension Effect {
    static let loadingStreamIn = Effect(
        id: "loading.stream-in",
        category: .loading,
        interaction: .tap,
        name: L("Streaming Answer", "流式回答"),
        summary: L("Words condense out of blur behind a gliding caret while the skeleton ahead of it is eaten away.", "文字跟在滑动的光标后从模糊中凝结成形，前方的骨架行被一点点“吃掉”。"),
        prompt: L(
            "An assistant reply card, 296 pt wide, first shows only shimmering skeleton lines and a pulsing 9 pt violet dot ('Thinking…'). After 0.7 s the dot stretches into a 3 × 17 pt gradient caret and tokens arrive in irregular bursts of one to three, about 14 per second, pausing 160 ms at punctuation. Each token rises 5 pt out of a 6 pt blur over 0.38 s ease-out and stays violet for a moment before cooling to the text colour. The caret springs to the end of the newest token (response 0.22 s, damping 0.85); on its line the skeleton retreats ahead of it and past lines lose theirs. At the end the caret fades and three action icons pop in 60 ms apart with a success haptic. Fluid, legible, alive.",
            "一张 296 pt 宽的助手回复卡片，起初只有流光骨架行和一个脉动的 9 pt 紫色圆点（“思考中…”）。0.7 秒后圆点拉伸成 3 × 17 pt 的渐变光标，词元每次一到三个不规则到达，约每秒 14 个，遇标点停顿 160 毫秒。每个词元用 0.38 秒缓出从 6 pt 模糊中上浮 5 pt 显现，先保持片刻紫色，再冷却为正文色。光标以弹簧（响应 0.22 秒、阻尼 0.85）跳到最新词元末尾；所在行的骨架在它前方后退，写完的行不再保留骨架。结束时光标淡出，三个操作图标间隔 60 毫秒弹出，伴随成功触感。流畅、清晰。"
        ),
        implementation: L(
            "Tokens are measured once with UIFont and laid out by hand, so every token is its own Text whose opacity, blur and offset animate from a single revealed-count; the caret and each skeleton line read their frames from the same layout.",
            "先用 UIFont 量出每个词元并手动排版，每个词元都是独立的 Text，其透明度、模糊与位移由同一个“已显示数量”驱动；光标与每条骨架行的位置也取自这份排版结果。"
        ),
        apis: ["NSString.size(withAttributes:)", "blur(radius:)", "spring(response:dampingFraction:)", "TimelineView", "mask"],
        tags: ["streaming", "ai", "typing", "caret", "流式", "打字", "光标", "生成"],
        params: [
            .slider("rate", L("Tokens per second", "每秒词元"), 5...30, default: 14, decimals: 0),
            .slider("blur", L("Entry blur", "入场模糊"), 0...12, default: 6, decimals: 0, unit: "pt"),
            .toggle("skeleton", L("Skeleton ahead", "前方骨架"), default: true),
        ]
    ) { ctx in
        StreamInDemo(ctx: ctx)
    }
}

// MARK: - Layout

private struct StreamToken: Identifiable {
    let id: Int
    let text: String
    let x: CGFloat
    let line: Int
    let width: CGFloat
    let pausesAfter: Bool
}

private struct StreamLayout {
    static let fontSize: CGFloat = 15
    static let lineHeight: CGFloat = 23
    static let width: CGFloat = 260

    let tokens: [StreamToken]
    let lineWidths: [CGFloat]

    var height: CGFloat { CGFloat(lineWidths.count) * StreamLayout.lineHeight }

    static let english = StreamLayout(
        pieces: "Springs feel natural because they carry velocity. Start with a response near 0.4 s and a damping of 0.8, then lower the damping until the motion gains a little life."
            .split(separator: " ").map { StreamPiece(text: String($0), latin: false) },
        spaced: true
    )

    static let chinese = StreamLayout(
        pieces: StreamLayout.split(chinese: "弹簧动画显得自然，是因为它会延续速度。先把响应设在 0.4 秒左右、阻尼设为 0.8，再一点点调低阻尼，直到动作带上一丝生命力。"),
        spaced: false
    )

    /// One token per Han character; Latin and digit runs stay whole and punctuation hangs on the token before it.
    private static func split(chinese text: String) -> [StreamPiece] {
        var pieces: [StreamPiece] = []
        var run = ""
        let closing: Set<Character> = ["，", "。", "、", "！", "？"]
        for character in text {
            if character == " " {
                if !run.isEmpty { pieces.append(StreamPiece(text: run, latin: true)); run = "" }
                continue
            }
            if character.isASCII {
                run.append(character)
                continue
            }
            if !run.isEmpty { pieces.append(StreamPiece(text: run, latin: true)); run = "" }
            if closing.contains(character), !pieces.isEmpty {
                pieces[pieces.count - 1].text.append(character)
            } else {
                pieces.append(StreamPiece(text: String(character), latin: false))
            }
        }
        if !run.isEmpty { pieces.append(StreamPiece(text: run, latin: true)) }
        return pieces
    }

    init(pieces: [StreamPiece], spaced: Bool) {
        let font = UIFont.systemFont(ofSize: StreamLayout.fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let space: CGFloat = spaced ? (" " as NSString).size(withAttributes: attributes).width : 0
        // Latin runs inside Chinese text get a little air on both sides (none at the start of a line).
        let air: CGFloat = 3
        var tokens: [StreamToken] = []
        var widths: [CGFloat] = []
        var x: CGFloat = 0
        var line: Int = 0
        var trailing: CGFloat = 0
        for (index, piece) in pieces.enumerated() {
            let width: CGFloat = ceil((piece.text as NSString).size(withAttributes: attributes).width * 10) / 10
            let lead: CGFloat = piece.latin && x > 0 ? air : 0
            if x > 0, x + lead + width > StreamLayout.width {
                widths.append(x - trailing)
                x = 0
                line += 1
            } else {
                x += lead
            }
            let last: Character = piece.text.last ?? " "
            let pauses: Bool = [",", ".", "，", "。", "、"].contains(last)
            tokens.append(StreamToken(id: index, text: piece.text, x: x, line: line, width: width, pausesAfter: pauses))
            trailing = space + (piece.latin && !pauses ? air : 0)
            x += width + trailing
        }
        widths.append(max(x - trailing, 0))
        self.tokens = tokens
        self.lineWidths = widths
    }
}

private struct StreamPiece {
    var text: String
    let latin: Bool
}

// MARK: - Demo

private enum StreamPhase {
    case thinking
    case writing
    case done
}

private struct StreamInDemo: View {
    let ctx: DemoContext
    @State private var count: Int
    @State private var phase: StreamPhase
    @State private var run = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills never run `task`: show the finished answer.
        let layout = ctx.language == .zh ? StreamLayout.chinese : StreamLayout.english
        _count = State(initialValue: ctx.isStill ? layout.tokens.count : 0)
        _phase = State(initialValue: ctx.isStill ? .done : .thinking)
    }

    private var layout: StreamLayout { ctx.language == .zh ? StreamLayout.chinese : StreamLayout.english }

    var body: some View {
        VStack(spacing: 16) {
            StreamCard(
                layout: layout,
                count: min(count, layout.tokens.count),
                phase: phase,
                blur: ctx.cg("blur"),
                skeleton: ctx.bool("skeleton"),
                language: ctx.language,
                preview: ctx.isPreview
            )
            DemoHint(text: L("Tap to regenerate", "点击重新生成"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            run += 1
        }
        .task(id: run) { await stream() }
        .onChange(of: ctx.language) { run += 1 }
    }

    private func stream() async {
        // Only a run the user restarted buzzes; the automatic first run stays silent.
        let live: Bool = !ctx.isPreview && run > 0
        let total: Int = layout.tokens.count
        withAnimation(.easeOut(duration: 0.25)) {
            count = 0
            phase = .thinking
        }
        try? await Task.sleep(for: .seconds(0.7))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { phase = .writing }
        while count < total {
            // Tokens arrive in bursts of one to three, like a real stream.
            let burst: Int = min(Int.random(in: 1...3), total - count)
            let next: Int = count + burst
            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) { count = next }
            // Chinese tokens are single characters, so they flow twice as fast.
            let rate: Double = max(ctx["rate"], 1) * (ctx.language == .zh ? 2 : 1)
            var wait: Double = Double(burst) / rate * Double.random(in: 0.7...1.3)
            if layout.tokens[next - 1].pausesAfter { wait += 0.16 }
            try? await Task.sleep(for: .seconds(wait))
            if Task.isCancelled { return }
        }
        try? await Task.sleep(for: .seconds(0.25))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { phase = .done }
        if live { Haptics.success() }
        guard ctx.isPreview else { return }
        try? await Task.sleep(for: .seconds(2.0))
        guard !Task.isCancelled else { return }
        run += 1
    }
}

private struct StreamCard: View {
    let layout: StreamLayout
    let count: Int
    let phase: StreamPhase
    let blur: CGFloat
    let skeleton: Bool
    let language: AppLanguage
    let preview: Bool

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ZStack(alignment: .topLeading) {
                if skeleton {
                    StreamSkeleton(layout: layout, caret: caretPoint, count: count, preview: preview, paused: phase == .done)
                }
                ForEach(layout.tokens) { token in
                    StreamWord(token: token, shown: token.id < count, fresh: phase != .done && token.id >= count - 3, blur: blur)
                }
                caret
            }
            .frame(width: StreamLayout.width, height: layout.height, alignment: .topLeading)
            footer
        }
        .padding(18)
        .frame(width: 296, alignment: .leading)
        .background(Palette.elevated, in: shape)
        .overlay { shape.strokeBorder(Palette.stroke) }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
    }

    /// Top-left corner of the caret: just after the newest token.
    private var caretPoint: CGPoint {
        guard count > 0, count <= layout.tokens.count else { return CGPoint(x: 0, y: 0) }
        let token = layout.tokens[count - 1]
        return CGPoint(x: token.x + token.width + 3, y: CGFloat(token.line) * StreamLayout.lineHeight)
    }

    private var caret: some View {
        let thinking: Bool = phase == .thinking
        let point = caretPoint
        return Capsule()
            .fill(LinearGradient(colors: [Palette.violet, Palette.pink], startPoint: .top, endPoint: .bottom))
            .frame(width: thinking ? 9 : 3, height: thinking ? 9 : 17)
            .shadow(color: Palette.violet.opacity(0.7), radius: 5)
            .phaseAnimator([false, true]) { content, dim in
                content.opacity(thinking && dim ? 0.35 : 1)
            } animation: { _ in .easeInOut(duration: 0.45) }
            .frame(width: 9, height: StreamLayout.lineHeight, alignment: .leading)
            .opacity(phase == .done ? 0 : 1)
            .scaleEffect(phase == .done ? 0.4 : 1)
            .offset(x: point.x, y: point.y)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(LinearGradient(colors: [Palette.violet, Palette.pink], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            Text(language == .zh ? "助手" : "Assistant")
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            Text(status, language)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.interpolate)
        }
    }

    private var status: LocalizedText {
        switch phase {
        case .thinking: return L("Thinking…", "思考中…")
        case .writing: return L("Writing…", "撰写中…")
        case .done: return L("Done", "已完成")
        }
    }

    private var footer: some View {
        let done: Bool = phase == .done
        let symbols: [String] = ["doc.on.doc", "hand.thumbsup", "arrow.clockwise"]
        return HStack(spacing: 8) {
            ForEach(0..<symbols.count, id: \.self) { index in
                Image(systemName: symbols[index])
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 26)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .scaleEffect(done ? 1 : 0.4)
                    .opacity(done ? 1 : 0)
                    .animation(
                        done ? .spring(response: 0.36, dampingFraction: 0.6).delay(Double(index) * 0.06) : .easeOut(duration: 0.15),
                        value: done
                    )
            }
        }
        .frame(height: 26)
    }
}

private struct StreamWord: View {
    let token: StreamToken
    let shown: Bool
    let fresh: Bool
    let blur: CGFloat

    var body: some View {
        Text(token.text)
            .font(.system(size: StreamLayout.fontSize))
            .foregroundStyle(fresh ? Palette.violetText : Color.primary)
            .fixedSize()
            .frame(height: StreamLayout.lineHeight)
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : blur)
            .offset(x: token.x, y: CGFloat(token.line) * StreamLayout.lineHeight + (shown ? 0 : 5))
            .animation(.easeOut(duration: 0.38), value: shown)
            .animation(.easeOut(duration: 0.6), value: fresh)
    }
}

/// One skeleton bar from `start` to `end`. A spring may overshoot either value, so the shape clamps
/// them itself instead of animating a frame width (which must never go negative).
private struct StreamBar: Shape {
    var start: CGFloat
    var end: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(start, end) }
        set {
            start = newValue.first
            end = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let from: CGFloat = min(max(start, 0), rect.width)
        let to: CGFloat = min(max(end, 0), rect.width)
        guard to - from >= 8 else { return Path() }
        return Path(roundedRect: CGRect(x: from, y: rect.minY, width: to - from, height: rect.height), cornerRadius: rect.height / 2)
    }
}

/// Skeleton bars for everything not written yet: whole lines below the caret, and the rest of the caret's line.
private struct StreamSkeleton: View {
    let layout: StreamLayout
    let caret: CGPoint
    let count: Int
    let preview: Bool
    let paused: Bool

    var body: some View {
        bars(Color.primary.opacity(0.08))
            .overlay {
                TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: paused)) { timeline in
                    let x: Double = (timeline.date.timeIntervalSinceReferenceDate / 1.5).truncatingRemainder(dividingBy: 1) * 2.4 - 0.7
                    LinearGradient(
                        stops: [
                            .init(color: Palette.violet.opacity(0), location: 0),
                            .init(color: Palette.violet.opacity(0.5), location: 0.45),
                            .init(color: Palette.pink.opacity(0.45), location: 0.6),
                            .init(color: Palette.pink.opacity(0), location: 1),
                        ],
                        startPoint: UnitPoint(x: x - 0.4, y: 0.5),
                        endPoint: UnitPoint(x: x + 0.4, y: 0.5)
                    )
                }
                .mask { bars(.black) }
            }
            .allowsHitTesting(false)
    }

    private func bars(_ color: Color) -> some View {
        let currentLine: Int = count > 0 ? layout.tokens[min(count, layout.tokens.count) - 1].line : 0
        return ZStack(alignment: .topLeading) {
            ForEach(0..<layout.lineWidths.count, id: \.self) { line in
                let full: CGFloat = layout.lineWidths[line]
                // On the caret's line the bar starts a little ahead of the caret; lines above it are finished.
                let start: CGFloat = line < currentLine ? full : (line == currentLine ? min(caret.x + 12, full) : 0)
                StreamBar(start: start, end: full)
                    .fill(color)
                    .frame(width: StreamLayout.width, height: 9)
                    .offset(y: CGFloat(line) * StreamLayout.lineHeight + (StreamLayout.lineHeight - 9) / 2)
            }
        }
        .frame(width: StreamLayout.width, height: layout.height, alignment: .topLeading)
    }
}
