import SwiftUI

extension Effect {
    static let textRankChange = Effect(
        id: "text.rank-change",
        category: .text,
        interaction: .tap,
        name: L("Rank Change", "排名升降"),
        summary: L("A rank that climbs rolls upward in green, a drop rolls down in red, and the leaderboard row overtakes its neighbours.", "排名上升时数字向上滚动并染绿，下降时向下滚动并染红，榜单里的那一行同时超过邻居。"),
        prompt: L(
            "A leaderboard card: a 68 pt heavy rank number with a delta chip, above a five-row slice of the board with your row highlighted. When the rank improves, the old digit rolls up out of its slot and the new one rises from below on a spring (response 0.5 s, damping 0.78), tinted green and fading back to the text colour in 0.9 s; three chevrons streak upward behind it 70 ms apart, and the chip slides up 14 pt with its arrow pointing up and the number of places gained. A drop mirrors everything downward in red. In the list, your row lifts to 104% and springs past its neighbours, which shift the other way 50 ms apart; 0.35 s later the window recentres on you with a slower spring. Clear, fair and a little triumphant.",
            "一张排行榜卡片：68pt特粗的名次数字配一枚升降胶囊，下方是榜单中的五行，其中你的那一行被高亮。名次上升时，旧数字向上滚出槽口，新数字从下方以弹簧（响应0.5秒、阻尼0.78）升入，先染成绿色，再用0.9秒褪回正文色；数字背后三道箭头依次向上掠过，间隔70毫秒；胶囊上移14pt，箭头朝上并显示上升的位数。名次下降时，一切反向并换成红色。榜单里你的那一行放大到104%，以弹簧越过邻居，邻居们则间隔50毫秒朝反方向让位；0.35秒后，窗口再以更慢的弹簧重新对准你。"
        ),
        implementation: L(
            "The hero digits reuse the rolling two-face slot (an Animatable turn counter); the list is a ForEach over a reordered id array, each row animating its own position with a delayed spring, inside a clipped window whose offset recentres from a short Task.",
            "名次数字复用滚动双面槽（Animatable 计数器）；榜单是对重排后 id 数组的 ForEach，每一行用带延迟的弹簧各自完成位移，外层是一个裁剪窗口，由一个短 Task 稍后把偏移重新居中。"
        ),
        apis: ["Animatable", "spring(response:dampingFraction:)", "ForEach", "contentTransition(.numericText)", "zIndex"],
        tags: ["rank", "leaderboard", "arrow", "up", "down", "排名", "排行榜", "升降", "名次", "箭头"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("stagger", L("Row stagger", "行间错开"), 0...0.12, default: 0.05, unit: "s"),
            .slider("flash", L("Tint fade", "染色消退"), 0.3...1.6, default: 0.9, unit: "s"),
        ]
    ) { ctx in
        TextRankChangeDemo(ctx: ctx)
    }
}

private struct TextRankChangeDemo: View {
    let ctx: DemoContext

    private static let you = 6
    private static let rowHeight: CGFloat = 34
    private static let rowSpacing: CGFloat = 4
    /// Places moved per change (negative = climbing). They sum to zero, so the loop is seamless.
    private static let moves: [Int] = [-2, -1, 2, -2, 1, 2]

    @State private var order: [Int] = Array(0..<12)
    @State private var center = TextRankChangeDemo.you
    @State private var direction = 1
    @State private var delta = 2
    @State private var pulses = 0
    @State private var step = 0
    @State private var hot = false
    @State private var settle: Task<Void, Never>?

    private var youIndex: Int { order.firstIndex(of: Self.you) ?? Self.you }
    private var tint: Color { direction > 0 ? Palette.green : Palette.red }

    private var names: [String] {
        ctx.language == .zh
            ? ["林夏", "周屿", "沈星", "陈默", "许诺", "江南", "你", "乔一", "唐棠", "顾北", "苏禾", "叶子"]
            : ["Ava", "Noah", "Mia", "Leo", "Zoe", "Eli", "You", "Ivy", "Max", "Uma", "Kai", "Ada"]
    }

    var body: some View {
        VStack(spacing: 12) {
            hero
            board
            DemoHint(text: L("Tap for the next change", "点击触发下一次变化"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.light)
            move()
        }
        .autoplay(ctx.isPreview, every: 2.0) { move() }
        .onDisappear { settle?.cancel() }
    }

    // MARK: Hero

    private var hero: some View {
        let glyphs: [String] = String(youIndex + 1).map { String($0) }
        let count = glyphs.count
        let font: Font = .system(size: 68, weight: .heavy, design: .rounded).monospacedDigit()
        return HStack(alignment: .center, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "#")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                ForEach(0..<count, id: \.self) { index in
                    TextFXRollGlyph(
                        glyph: glyphs[index],
                        direction: direction,
                        font: font,
                        slot: CGSize(width: 44, height: 80),
                        flash: tint,
                        flashHold: ctx["flash"],
                        response: ctx["response"],
                        damping: 0.78,
                        blur: 5
                    )
                    .id(count - 1 - index)
                }
            }
            .background {
                TextFXPulse(trigger: pulses, duration: 0.75) { p in
                    RankStreaks(progress: p, direction: direction, tint: tint)
                }
                .frame(width: 120, height: 84)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.3),
                            .init(color: .black, location: 0.7),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                chip
                Text(L("vs. last week", "较上周"), ctx.language)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 84)
    }

    private var chip: some View {
        TextFXPulse(trigger: pulses, duration: 0.5) { p in
            let eased: Double = TextFXCurve.easeOutCubic(Double(p))
            HStack(spacing: 5) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .heavy))
                    .rotationEffect(.degrees(direction > 0 ? 0 : 180))
                    .animation(.spring(response: 0.4, dampingFraction: 0.55), value: direction)
                Text(verbatim: "\(delta)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 1))
            .offset(y: CGFloat(direction) * 14 * (1 - eased))
            .opacity(0.3 + 0.7 * eased)
        }
        .animation(.easeOut(duration: 0.25), value: direction)
    }

    // MARK: Board

    private var board: some View {
        let pitch: CGFloat = Self.rowHeight + Self.rowSpacing
        let window: CGFloat = pitch * 5 - Self.rowSpacing
        let spring: Animation = .spring(response: ctx["response"], dampingFraction: 0.75)
        let target = youIndex
        return VStack(spacing: Self.rowSpacing) {
            ForEach(Array(order.enumerated()), id: \.element) { index, player in
                let distance: Double = Double(abs(index - target))
                row(player: player, index: index)
                    .zIndex(player == Self.you ? 1 : 0)
                    .animation(spring.delay(player == Self.you ? 0 : distance * ctx["stagger"]), value: order)
            }
        }
        .offset(y: -CGFloat(center - 2) * pitch)
        .frame(width: 292, height: window, alignment: .top)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.16),
                    .init(color: .black, location: 0.84),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func row(player: Int, index: Int) -> some View {
        let isYou: Bool = player == Self.you
        let accent: Color = Palette.spectrum[player % Palette.spectrum.count]
        let highlight: Color = hot ? tint : Palette.indigo
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        return HStack(spacing: 10) {
            Text(verbatim: "\(index + 1)")
                .font(.system(size: 14, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(isYou ? highlight : Color.secondary)
                .contentTransition(.numericText())
                .frame(width: 22)
            Circle()
                .fill(accent.opacity(isYou ? 1 : 0.75))
                .frame(width: 20, height: 20)
            Text(verbatim: names[player])
                .font(.system(size: 15, weight: isYou ? .bold : .medium))
            Spacer(minLength: 0)
            Text(verbatim: "\(3120 - index * 135)")
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .frame(height: Self.rowHeight)
        .background {
            shape.fill(isYou ? AnyShapeStyle(Palette.elevated) : AnyShapeStyle(Color.primary.opacity(0.05)))
            if isYou {
                shape.fill(highlight.opacity(0.18))
                shape.strokeBorder(highlight.opacity(0.55), lineWidth: 1)
            }
        }
        .scaleEffect(isYou && hot ? 1.04 : 1)
        .shadow(color: .black.opacity(isYou && hot ? 0.22 : 0), radius: 10, y: 5)
    }

    // MARK: Change

    private func move() {
        let amount = Self.moves[step % Self.moves.count]
        step += 1
        let from = youIndex
        let to = min(max(from + amount, 0), order.count - 1)
        guard to != from else { return }
        direction = to < from ? 1 : -1
        delta = abs(to - from)
        pulses += 1
        var next = order
        next.remove(at: from)
        next.insert(Self.you, at: to)
        order = next
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { hot = true }

        let recentre: Animation = .spring(response: ctx["response"] * 1.4, dampingFraction: 0.86)
        let hold: Double = ctx["flash"]
        settle?.cancel()
        settle = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            withAnimation(recentre) { center = min(max(to, 2), order.count - 3) }
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.45)) { hot = false }
        }
    }
}

/// Three chevrons that streak past the number in the direction of the change.
private struct RankStreaks: View {
    let progress: CGFloat
    let direction: Int
    let tint: Color

    var body: some View {
        let p: Double = Double(progress)
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let local: Double = TextFXCurve.clamp01((p - Double(index) * 0.093) / 0.7)
                let travel: Double = TextFXCurve.easeOutCubic(local)
                let alpha: Double = p >= 1 ? 0 : sin(Double.pi * local)
                Image(systemName: direction > 0 ? "chevron.up" : "chevron.down")
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(tint)
                    .opacity(0.26 * alpha)
                    .offset(y: CGFloat(direction) * CGFloat(46 - 92 * travel))
            }
        }
        .offset(x: 12)
        .allowsHitTesting(false)
    }
}
