import SwiftUI

extension Effect {
    static let textScoreFlip = Effect(
        id: "text.score-flip",
        category: .text,
        interaction: .tap,
        name: L("Score Flip", "比分翻牌"),
        summary: L("A scoreboard where the scoring side's card falls over its hinge with a flash while the other side dims.", "一块记分牌：得分一方的数字牌绕铰链翻落并闪光，另一方随之变暗。"),
        prompt: L(
            "A dark scoreboard with two teams, each score on a pair of hinged flip cards. When a side scores, only its changed cards flip: the upper flap with the old digit falls around the centre hinge, accelerating like a real flap, passes 90° and lands as the lower half of the new digit, rebounding about 14° before it rests; the whole flip takes 0.45 s and the tens card follows the ones card by 80 ms. A wash of the team colour flashes over the cards as the flap lands and fades in 0.7 s, a “+3” chip floats up 20 pt and dissolves, and the opposing side dims to 45% for about a second. A short lead bar under the team in front widens on a spring. It feels mechanical, loud and unmistakable.",
            "一块深色记分牌，两队比分各由一对带铰链的翻牌显示。某一方得分时，只有发生变化的那几张牌翻动：带旧数字的上翼绕中缝下落，像真实翻片一样越落越快，越过90°后变成新数字的下半张拍到位，再回弹约14°才停稳；整次翻动0.45秒，十位牌比个位牌晚80毫秒。翻片落定的瞬间，一层队色的光漫过数字牌并在0.7秒内褪去，「+3」小标签上浮20pt后消散，对方一侧同时压暗到45%并保持约一秒。领先一方队名下的短条以弹簧变宽。整体机械、响亮、一眼就知道谁得分。"
        ),
        implementation: L(
            "Each card is an Animatable view driven by a linear turn counter: the progress is shaped into a falling-flap angle with a rebound and drives rotation3DEffect on masked upper and lower halves; the flash and the points chip replay through a small pulse view keyed on a counter.",
            "每张牌是一个由线性计数器驱动的 Animatable 视图：进度被整形为带回弹的翻片下落角度，驱动上下半张遮罩的 rotation3DEffect；闪光与得分标签由一个以计数器触发的脉冲视图重播。"
        ),
        apis: ["Animatable", "rotation3DEffect(_:axis:anchor:perspective:)", "mask(alignment:_:)", "contentTransition(.numericText)"],
        tags: ["scoreboard", "flip", "score", "sports", "flash", "记分牌", "比分", "翻牌", "体育", "得分"],
        params: [
            .slider("flip", L("Flip duration", "翻动时长"), 0.25...1.0, default: 0.45, unit: "s"),
            .slider("stagger", L("Tens delay", "十位延迟"), 0...0.25, default: 0.08, unit: "s"),
            .slider("dim", L("Opponent dim", "对方压暗"), 0...0.85, default: 0.55),
        ]
    ) { ctx in
        TextScoreFlipDemo(ctx: ctx)
    }
}

private struct TextScoreFlipDemo: View {
    let ctx: DemoContext

    private static let start: [Int] = [87, 85]
    private static let script: [(side: Int, points: Int)] = [(0, 3), (1, 2), (1, 3), (0, 2), (1, 3), (0, 2)]

    @State private var scores: [Int] = TextScoreFlipDemo.start
    @State private var dimmed: Int? = nil
    @State private var pulses: [Int] = [0, 0]
    @State private var points: [Int] = [3, 2]
    @State private var seconds = 151
    @State private var step = 0
    @State private var dimTask: Task<Void, Never>?
    @State private var livePulse = false

    private let tints: [Color] = [Palette.amber, Palette.sky]
    private let names: [LocalizedText] = [L("HOME", "主队"), L("AWAY", "客队")]

    var body: some View {
        VStack(spacing: 16) {
            board
            DemoHint(text: L("Tap a side to score", "点击任意一方得分"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { auto() }
        .onAppear {
            guard !ctx.isStill else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { livePulse = true }
        }
        .onDisappear { dimTask?.cancel() }
    }

    private var board: some View {
        VStack(spacing: 38) {
            header
            HStack(alignment: .center, spacing: 12) {
                side(0)
                VStack(spacing: 9) {
                    Circle().frame(width: 6, height: 6)
                    Circle().frame(width: 6, height: 6)
                }
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 38)
                side(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1D1D24), Color(hex: 0x0E0E12)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 20, y: 12)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Palette.red)
                .frame(width: 6, height: 6)
                .opacity(livePulse ? 0.35 : 1)
            Text(L("LIVE", "直播"), ctx.language)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: 0)
            Text(L("Q4", "第四节"), ctx.language)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Text(verbatim: String(format: "%02d:%02d", seconds / 60, seconds % 60))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: 252)
    }

    private func side(_ index: Int) -> some View {
        let tint: Color = tints[index]
        let value: Int = scores[index]
        let ahead: Bool = scores[index] > scores[1 - index]
        let flip: Double = ctx["flip"]
        let isDim: Bool = dimmed == index
        return VStack(spacing: 9) {
            HStack(spacing: 5) {
                ScoreFlipDigit(glyph: String(value / 10), duration: flip, delay: ctx["stagger"])
                ScoreFlipDigit(glyph: String(value % 10), duration: flip, delay: 0)
            }
            .overlay {
                TextFXPulse(trigger: pulses[index], duration: flip + 0.7) { p in
                    ScoreFlash(progress: p, landing: flip * 0.72 / (flip + 0.7), tint: tint)
                }
            }
            .overlay(alignment: .top) {
                TextFXPulse(trigger: pulses[index], duration: 1.1) { p in
                    ScorePop(progress: p, points: points[index], tint: tint)
                }
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tint)
                    .frame(width: 10, height: 10)
                Text(names[index], ctx.language)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Capsule()
                .fill(tint)
                .frame(width: ahead ? 46 : 10, height: 4)
                .opacity(ahead ? 1 : 0.28)
                .animation(.spring(response: 0.45, dampingFraction: 0.6), value: ahead)
        }
        .opacity(isDim ? 1 - ctx["dim"] : 1)
        .saturation(isDim ? 0.4 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.rigid)
            score(index, points: step % 2 == 0 ? 3 : 2)
        }
    }

    private func auto() {
        let entry = Self.script[step % Self.script.count]
        score(entry.side, points: entry.points)
    }

    private func score(_ index: Int, points amount: Int) {
        step += 1
        guard scores[index] + amount <= 99, !(ctx.isPreview && step % (Self.script.count + 1) == 0) else {
            // New game: every card flips back, nobody is highlighted.
            scores = Self.start
            withAnimation(.snappy(duration: 0.3)) { seconds = 151 }
            return
        }
        points[index] = amount
        scores[index] += amount
        pulses[index] += 1
        withAnimation(.snappy(duration: 0.3)) { seconds = max(seconds - 14, 9) }
        withAnimation(.easeOut(duration: 0.18)) { dimmed = 1 - index }
        dimTask?.cancel()
        dimTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.45)) { dimmed = nil }
        }
    }
}

// MARK: - Flip card

private struct ScoreFlipDigit: View {
    let glyph: String
    let duration: Double
    let delay: Double

    @State private var shown: String
    @State private var leaving: String
    @State private var turns = 0

    init(glyph: String, duration: Double, delay: Double) {
        self.glyph = glyph
        self.duration = duration
        self.delay = delay
        _shown = State(initialValue: glyph)
        _leaving = State(initialValue: glyph)
    }

    var body: some View {
        ScoreFlipFaces(turn: CGFloat(turns), target: turns, shown: shown, leaving: leaving)
            .onChange(of: glyph) { _, new in
                leaving = shown
                shown = new
                withAnimation(.linear(duration: duration).delay(delay)) { turns += 1 }
            }
    }
}

private struct ScoreFlipFaces: View, Animatable {
    var turn: CGFloat
    let target: Int
    let shown: String
    let leaving: String

    static let size = CGSize(width: 54, height: 78)

    var animatableData: CGFloat {
        get { turn }
        set { turn = newValue }
    }

    /// 0…180°: the flap falls with growing speed, hits the lower half at 72% and rebounds about 14°.
    static func angle(_ p: Double) -> Double {
        let fall: Double = 0.72
        if p < fall {
            let u: Double = p / fall
            return 180 * (0.3 * u + 0.7 * u * u)
        }
        let v: Double = (p - fall) / (1 - fall)
        return 180 - 14 * sin(Double.pi * v) * (1 - v)
    }

    var body: some View {
        let p: CGFloat = target == 0 ? 1 : min(max(turn - CGFloat(target - 1), 0), 1)
        let angle: Double = Self.angle(Double(p))
        let lean: Double = sin(angle * Double.pi / 180)
        ZStack {
            // Revealed behind the falling flap: the new upper half, in the flap's shadow at first.
            ScoreFlipHalf(glyph: shown, top: true, shade: 0.45 * max(1 - angle / 90, 0))
            // The old lower half, shadowed as the flap comes down over it.
            ScoreFlipHalf(glyph: leaving, top: false, shade: angle > 90 ? 0.5 * lean : 0)
            if angle < 90 {
                ScoreFlipHalf(glyph: leaving, top: true, shade: 0.4 * lean)
                    .rotation3DEffect(.degrees(-angle), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
            } else {
                ScoreFlipHalf(glyph: shown, top: false, shade: 0.35 * lean)
                    .rotation3DEffect(.degrees(180 - angle), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
            }
            Rectangle()
                .fill(Color.black.opacity(0.75))
                .frame(height: 1.5)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

private struct ScoreFlipHalf: View {
    let glyph: String
    let top: Bool
    let shade: Double

    var body: some View {
        let size = ScoreFlipFaces.size
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Color(hex: 0x34343E), Color(hex: 0x1F1F27)], startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            Text(verbatim: glyph)
                .font(.system(size: 58, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            shape.fill(Color.black.opacity(shade))
        }
        .frame(width: size.width, height: size.height)
        .mask(alignment: top ? .top : .bottom) {
            Rectangle().frame(height: size.height / 2)
        }
    }
}

// MARK: - Flash and points chip

private struct ScoreFlash: View {
    let progress: CGFloat
    /// Share of the pulse at which the flap lands.
    let landing: Double
    let tint: Color

    var body: some View {
        let p: Double = Double(progress)
        let rise: Double = min(max((p - landing * 0.7) / max(landing * 0.3, 0.001), 0), 1)
        let fall: Double = min(max((p - landing) / max(1 - landing, 0.001), 0), 1)
        let amount: Double = p >= 1 ? 0 : rise * (1 - fall) * (1 - fall)
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint)
            .opacity(0.5 * amount)
            .blendMode(.plusLighter)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint)
                    .blur(radius: 18)
                    .opacity(0.55 * amount)
                    .padding(-6)
            }
            .allowsHitTesting(false)
    }
}

private struct ScorePop: View {
    let progress: CGFloat
    let points: Int
    let tint: Color

    var body: some View {
        let p: Double = Double(progress)
        let rise: Double = TextFXCurve.easeOutCubic(p)
        let alpha: Double = p >= 1 ? 0 : min(p / 0.12, 1) * (1 - TextFXCurve.smoothstep((p - 0.55) / 0.45))
        let pop: Double = 0.6 + 0.4 * TextFXCurve.easeOutCubic(min(p / 0.2, 1))
        Text(verbatim: "+\(points)")
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: 0x15151A))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(tint, in: Capsule())
            .scaleEffect(pop)
            .offset(y: -10 - 20 * rise)
            .opacity(alpha)
            .allowsHitTesting(false)
    }
}
