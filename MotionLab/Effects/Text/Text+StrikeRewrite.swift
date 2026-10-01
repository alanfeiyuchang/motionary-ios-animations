import SwiftUI

extension Effect {
    static let textStrikeRewrite = Effect(
        id: "text.strike-rewrite",
        category: .text,
        interaction: .tap,
        name: L("Strike & Rewrite", "划掉重写"),
        summary: L("An editor's pen strikes a phrase out, the lines part, and the correction is written in above it.", "编辑的笔划掉一个词，行距被撑开，改正的词写在它的上方。"),
        prompt: L(
            "A two-line statement in bold 36 pt type; one phrase in the second line is wrong. An ink line is drawn through it left to right in 0.3 s with an ease-out: a 3.5 pt round-capped marker stroke that overshoots the phrase by 5 pt on each side, wavers about 1.6 pt and climbs slightly, like a quick hand. The struck phrase then dims to 40% and the gap above the line opens by 32 pt on a curve that overshoots once. Into that gap the correction is written in handwriting in the same ink, tilted −3°: a soft-edged mask sweeps left to right over 0.5 s behind a small pen dot that bobs as it travels and lifts off at the end, and a short underline flicks under the new words. The next tap moves on to another sentence. It feels decisive and human.",
            "一句两行的粗体陈述，第二行里有一个词是错的。一道墨线用0.3秒从左到右缓出地划过它：3.5pt粗、圆头的马克笔笔触，两端各多划出5pt，带约1.6pt的抖动并略微上扬，像随手一划。被划掉的词随即淡到40%，这一行上方的空隙沿一条带一次过冲的曲线撑开32pt。改正的词以同色墨水的手写体写进这个空隙，倾斜−3°：一道软边遮罩用0.5秒从左扫到右，前面是一个随行进上下轻颤的小笔尖，写完后笔尖抬起，新词下面再甩出一道短短的下划线。再次点击则换下一句。整体干脆、有人味。"
        ),
        implementation: L(
            "A TimelineView clock since the last start drives everything in closed form: the trim of a wavy strike Shape, the dim, the eased line gap, the stops of a LinearGradient mask that reveals the correction, a pen dot positioned from the same progress, and the trim of the underline.",
            "由 TimelineView 提供的、自上次开始以来的时间以解析形式驱动一切：波浪删除线 Shape 的 trim、变淡、带缓动的行距、用来揭示改正词的 LinearGradient 遮罩的色标、由同一进度定位的笔尖，以及下划线的 trim。"
        ),
        apis: ["TimelineView(.animation)", "Shape.trim(from:to:)", "mask", "LinearGradient(stops:)", "Font.custom"],
        tags: ["strikethrough", "correction", "rewrite", "edit", "handwriting", "删除线", "修改", "划掉", "批注", "手写"],
        params: [
            .slider("strike", L("Strike duration", "划线时长"), 0.15...0.8, default: 0.3, unit: "s"),
            .slider("write", L("Write duration", "书写时长"), 0.2...1.2, default: 0.5, unit: "s"),
            .slider("wobble", L("Hand wobble", "手抖幅度"), 0...4, default: 1.6, decimals: 1, unit: "pt"),
            .choice("ink", L("Ink", "墨水"), [L("Red", "红"), L("Blue", "蓝"), L("Green", "绿")], default: 0),
        ]
    ) { ctx in
        TextStrikeRewriteDemo(ctx: ctx)
    }
}

private struct StrikeCopy {
    let first: String
    let prefix: String
    let wrong: String
    let suffix: String
    let right: String
}

private struct TextStrikeRewriteDemo: View {
    let ctx: DemoContext
    @State private var start: Date? = nil
    @State private var copy = 0
    @State private var played = false

    private var copies: [StrikeCopy] {
        switch ctx.language {
        case .zh:
            return [
                StrikeCopy(first: "这个版本", prefix: "", wrong: "下个月", suffix: "上线。", right: "本周五"),
                StrikeCopy(first: "动效应该是", prefix: "一种", wrong: "装饰", suffix: "。", right: "反馈"),
                StrikeCopy(first: "把这个标志", prefix: "再", wrong: "放大一点", suffix: "。", right: "留点呼吸"),
            ]
        case .en:
            return [
                StrikeCopy(first: "This version", prefix: "ships ", wrong: "next month", suffix: ".", right: "on Friday"),
                StrikeCopy(first: "Motion should", prefix: "be ", wrong: "decoration", suffix: ".", right: "feedback"),
                StrikeCopy(first: "Make the logo", prefix: "", wrong: "bigger", suffix: ".", right: "breathe"),
            ]
        }
    }

    private var ink: Color {
        switch ctx.int("ink") {
        case 1: return Palette.blue
        case 2: return Color.adaptive(light: 0x1E9E5A, dark: 0x34C77B)
        default: return Palette.red
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let time: Double = ctx.isStill ? 1000 : (start.map { timeline.date.timeIntervalSince($0) } ?? -1)
            sentence(time: time)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Tap to correct the next sentence", "点击修改下一句"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.light)
            play()
        }
        .autoplay(ctx.isPreview, every: 3.6, delay: 0.7) { play() }
    }

    private func play() {
        if played { copy += 1 }
        played = true
        start = Date()
    }

    // MARK: Choreography

    private static func easeOutBack(_ x: Double) -> Double {
        let u: Double = min(max(x, 0), 1) - 1
        let c: Double = 2.2
        return 1 + (c + 1) * u * u * u + c * u * u
    }

    private func sentence(time: Double) -> some View {
        let text = copies[copy % copies.count]
        let swapped: Bool = copy > 0
        let strikeStart: Double = swapped ? 0.55 : 0.1
        let strikeDuration: Double = max(ctx["strike"], 0.05)
        let writeStart: Double = strikeStart + strikeDuration + 0.14
        let writeDuration: Double = max(ctx["write"], 0.05)

        let arrive: Double = swapped ? TextFXCurve.easeOutCubic(time / 0.3) : 1
        let strike: Double = TextFXCurve.easeOutCubic((time - strikeStart) / strikeDuration)
        let dim: Double = TextFXCurve.clamp01((time - strikeStart - strikeDuration * 0.7) / 0.2)
        let gap: Double = Self.easeOutBack((time - strikeStart - strikeDuration * 0.6) / 0.4)
        let write: Double = TextFXCurve.easeInOut((time - writeStart) / writeDuration)
        let lift: Double = TextFXCurve.clamp01((time - writeStart - writeDuration) / 0.15)
        let underline: Double = TextFXCurve.easeOutCubic((time - writeStart - writeDuration - 0.05) / 0.2)
        let font: Font = .system(size: ctx.language == .zh ? 42 : 36, weight: .bold)

        return VStack(spacing: 2 + 32 * gap) {
            Text(verbatim: text.first)
                .font(font)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: text.prefix)
                    .font(font)
                Text(verbatim: text.wrong)
                    .font(font)
                    .opacity(1 - 0.6 * dim)
                    .overlay {
                        StrikeLine(wobble: ctx.cg("wobble"))
                            .trim(from: 0, to: strike)
                            .stroke(ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    }
                    .overlay(alignment: .top) {
                        correction(text.right, write: write, lift: lift, underline: underline)
                            .fixedSize()
                            .alignmentGuide(.top) { $0[.bottom] - 5 }
                    }
                Text(verbatim: text.suffix)
                    .font(font)
            }
        }
        .padding(.bottom, 10)
        .opacity(arrive)
        .offset(y: 10 * (1 - arrive))
        .id(copy)
    }

    private func correction(_ text: String, write: Double, lift: Double, underline: Double) -> some View {
        let font: Font = ctx.language == .zh
            ? .system(size: 31, weight: .heavy, design: .rounded)
            : .custom("Noteworthy-Bold", size: 31)
        let edge: Double = write * 1.12
        return Text(verbatim: text)
            .font(font)
            .foregroundStyle(ink)
            .padding(.horizontal, 6)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: min(max(edge - 0.12, 0), 1)),
                        .init(color: .clear, location: min(max(edge, 0.0001), 1)),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .overlay {
                GeometryReader { proxy in
                    Circle()
                        .fill(ink)
                        .frame(width: 8, height: 8)
                        .scaleEffect(write > 0.001 ? 1 - lift : 0)
                        .position(
                            x: proxy.size.width * write,
                            y: proxy.size.height * 0.55 + 6 * sin(write * 26)
                        )
                }
            }
            .overlay(alignment: .bottom) {
                StrikeLine(wobble: 1.2)
                    .trim(from: 0, to: underline)
                    .stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(height: 6)
                    .padding(.horizontal, 8)
                    .offset(y: 3)
            }
            .rotationEffect(.degrees(-3))
    }
}

/// A quick hand-drawn line: slightly wavy, slightly rising, overshooting the bounds on both sides.
private struct StrikeLine: Shape {
    var wobble: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 28
        for index in 0...steps {
            let u: CGFloat = CGFloat(index) / CGFloat(steps)
            let x: CGFloat = rect.minX - 5 + (rect.width + 10) * u
            let y: CGFloat = rect.midY + 2 + sin(u * .pi * 3.3 + 0.6) * wobble - (u - 0.5) * 4
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
