import SwiftUI

extension Effect {
    static let textBlockReveal = Effect(
        id: "text.block-reveal",
        category: .text,
        interaction: .tap,
        name: L("Block Reveal", "色块揭示"),
        summary: L("A solid colour block wipes across each line, and the text is simply there when it leaves.", "一块纯色色块扫过每一行，等它离开时，文字已经在那里了。"),
        prompt: L(
            "An editorial headline of three left-aligned heavy lines under a small kicker, all hidden at first. Each line is revealed by a flat colour block exactly as wide as its text: the block grows from the left edge to full width in 0.45 s on a strong ease-in-out, the text switches on unseen beneath it, then the block retracts toward the right edge in another 0.45 s, uncovering the words while they drift the last 6 pt into place. A second block in the text colour trails just behind the first, so a dark sliver chases the coloured edge. Lines start 110 ms apart, each with its own accent. The exit runs the same wipe again and takes the text away with it. It feels confident and graphic, like a title sequence.",
            "一组社论风格的标题：小号眉题下面是三行左对齐的特粗大字，起初全部隐藏。每一行都由一块与文字等宽的纯色色块揭开：色块先用0.45秒、以强烈的缓入缓出从左缘长到满宽，文字在它下面悄悄显示，接着色块再用0.45秒向右缘收走，露出文字，文字同时把最后6pt的位移走完。第二块文字颜色的色块紧跟在第一块后面，于是彩色边缘后面总追着一道深色窄条。各行依次晚110毫秒启动，每行一种强调色。退场时同样的色块再扫一遍，把文字一起带走。整体自信、平面感强，像片头字幕。"
        ),
        implementation: L(
            "Each line is an Animatable view driven by a monotonic phase animated linearly with a per-line delay; the phase is eased inside the view and mapped to the scaleEffect(x:anchor:) of two overlay rectangles (leading anchor while growing, trailing while retracting) and to the text's visibility.",
            "每一行是一个 Animatable 视图，由单调递增、按行延迟的线性相位驱动；相位在视图内部做缓动，再映射到两块叠加矩形的 scaleEffect(x:anchor:)（生长时锚在前缘、收走时锚在后缘）以及文字的显隐。"
        ),
        apis: ["Animatable", "scaleEffect(x:y:anchor:)", "overlay", "animation(_:value:)", "Task.sleep"],
        tags: ["block", "wipe", "reveal", "headline", "editorial", "色块", "擦除", "揭示", "标题", "片头"],
        params: [
            .slider("duration", L("Wipe duration", "扫过时长"), 0.5...1.8, default: 0.9, unit: "s"),
            .slider("stagger", L("Line stagger", "行间错开"), 0...0.3, default: 0.11, unit: "s"),
            .choice("direction", L("Direction", "方向"), [L("Right", "向右"), L("Left", "向左"), L("Alternate", "交替")], default: 0),
            .toggle("echo", L("Trailing block", "跟随色块"), default: true),
        ]
    ) { ctx in
        TextBlockRevealDemo(ctx: ctx)
    }
}

private struct TextBlockRevealDemo: View {
    let ctx: DemoContext
    /// Odd = revealed, even = hidden. Only ever increases, so replays never run backwards.
    @State private var phase: Int
    @State private var copy = 0
    @State private var busy = false
    @State private var script: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private let accents: [Color] = [Palette.coral, Palette.indigo, Palette.pink, Palette.mint]

    private var lines: [String] {
        let sets: [[String]]
        switch ctx.language {
        case .zh:
            sets = [["第 05 期 · 动效", "让每一行", "都有自己的", "出场方式。"], ["第 06 期 · 节奏", "先遮住，", "再揭开，", "才有期待。"]]
        case .en:
            sets = [["ISSUE 05 · MOTION", "Every line", "earns its", "entrance."], ["ISSUE 06 · RHYTHM", "Cover it,", "then let", "it show."]]
        }
        return sets[copy % sets.count]
    }

    var body: some View {
        let texts = lines
        let duration: Double = ctx["duration"]
        VStack(alignment: .leading, spacing: 4) {
            ForEach(texts.indices, id: \.self) { index in
                BlockRevealLine(
                    progress: CGFloat(phase),
                    text: texts[index],
                    font: index == 0
                        ? .system(size: 13, weight: .heavy, design: .rounded)
                        : .system(size: ctx.language == .zh ? 42 : 44, weight: .black),
                    tracking: index == 0 ? 1.6 : -0.5,
                    block: accents[(index + copy) % accents.count],
                    echo: ctx.bool("echo"),
                    reversed: reversed(index)
                )
                .padding(.bottom, index == 0 ? 8 : 0)
                .animation(.linear(duration: duration).delay(Double(index) * ctx["stagger"]), value: phase)
            }
        }
        .frame(width: 300, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Tap to wipe to the next headline", "点击切换到下一组标题"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.light)
            advance()
        }
        .autoplay(ctx.isPreview, every: duration * 2 + 2.6, delay: 2.4, intro: false) { advance() }
        .onAppear {
            guard !ctx.isStill, phase == 0 else { return }
            phase = 1
        }
        .onDisappear { script?.cancel() }
    }

    private func reversed(_ index: Int) -> Bool {
        switch ctx.int("direction") {
        case 1: return true
        case 2: return index % 2 == 1
        default: return false
        }
    }

    /// Wipes the current headline away, swaps the copy while everything is hidden, then reveals it.
    private func advance() {
        guard !busy else { return }
        guard phase % 2 == 1 else {
            phase += 1
            return
        }
        busy = true
        phase += 1
        let wait: Double = ctx["duration"] + ctx["stagger"] * Double(lines.count - 1) + 0.06
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            // Swap the copy in its own update, so the phase animation never cross-fades text or colours.
            copy += 1
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            phase += 1
            busy = false
        }
    }
}

private struct BlockRevealLine: View, Animatable {
    var progress: CGFloat
    let text: String
    let font: Font
    let tracking: CGFloat
    let block: Color
    let echo: Bool
    let reversed: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private static func ease(_ x: Double) -> Double {
        let u: Double = min(max(x, 0), 1)
        return u < 0.5 ? 8 * u * u * u * u : 1 - pow(-2 * u + 2, 4) / 2
    }

    /// Block width (0…1) and whether it is still growing at wipe position `a` (0…1).
    private static func cover(_ a: Double) -> (scale: CGFloat, growing: Bool) {
        if a < 0.5 { return (CGFloat(ease(a * 2)), true) }
        return (CGFloat(1 - ease((a - 0.5) * 2)), false)
    }

    var body: some View {
        // Position inside the current two-step cycle: 0…1 reveals, 1…2 wipes the text away again.
        let cycle: Double = Double(progress).truncatingRemainder(dividingBy: 2)
        let exiting: Bool = cycle > 1
        let a: Double = exiting ? cycle - 1 : cycle
        let main = Self.cover(a)
        let lag = Self.cover(a - 0.035 * sin(Double.pi * a))
        let textVisible: Bool = exiting ? a < 0.5 : a >= 0.5
        let settle: Double = exiting ? 0 : 1 - Self.ease((a - 0.5) * 2)
        // The text settles from the side the block retracts to, so it never shows outside the block.
        let side: CGFloat = reversed ? -1 : 1

        Text(verbatim: text)
            .font(font)
            .tracking(tracking)
            .lineLimit(1)
            .fixedSize()
            .opacity(textVisible ? 1 : 0)
            .offset(x: side * 6 * CGFloat(settle))
            .padding(.horizontal, 6)
            .overlay {
                if echo {
                    Rectangle()
                        .fill(Color.primary)
                        .scaleEffect(x: lag.scale, y: 1, anchor: anchor(growing: lag.growing))
                }
            }
            .overlay {
                Rectangle()
                    .fill(block)
                    .scaleEffect(x: main.scale, y: 1, anchor: anchor(growing: main.growing))
            }
            .padding(.leading, -6)
    }

    private func anchor(growing: Bool) -> UnitPoint {
        growing != reversed ? .leading : .trailing
    }
}
