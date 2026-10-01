import SwiftUI

extension Effect {
    static let chartsLeaderboard = Effect(
        id: "charts.leaderboard",
        category: .charts,
        interaction: .tap,
        name: L("Leaderboard Overtake", "排行榜超车"),
        summary: L("Scores roll and the climber lifts off the list, passes over the rows it beats and lands; the crown hops to a new leader.", "分数滚动，上升的选手从列表中抬起，越过被超过的行后落下；皇冠跳到新的榜首。"),
        prompt: L(
            "A leaderboard tile of five 36 pt rows: rank, gradient avatar, name, a rolling score and a rank-change chip. Each tap gives one player points: the score counts up over 0.5 s and, if the rank changes, that row lifts off the list (scale 1.05, 14 pt shadow, tinted background), travels up to its new slot on a spring (response 0.5 s, damping 0.72) and lands with a soft thud, while the rows it overtakes slide down underneath it 80 ms later on a tighter spring (response 0.42 s, damping 0.86). A green “▲2” chip pops beside the climber and fades after 1.2 s; overtaken rows flash a red “▼1”. Rank digits roll with a numeric transition and the crown above the top avatar hops across with a matched-geometry spring when the leader changes. One clear protagonist per update: competitive, readable, a little theatrical.",
            "排行榜卡片，五行、每行 36pt：名次、头像、名字、滚动分数与变化标签。每次点击给一位选手加分，分数用 0.5 秒滚动；若名次改变，该行从列表中抬起（放大到 1.05、14pt 投影、背景着色），以弹簧（响应 0.5 秒、阻尼 0.72）移到新位置后落下；被超过的行在 80ms 后以更紧的弹簧（响应 0.42 秒、阻尼 0.86）从下方滑过。上升者旁弹出绿色“▲2”，约 1.2 秒后淡出；被超过者闪现红色“▼1”。名次数字以数字转场滚动，榜首易主时皇冠以几何匹配弹簧跳到新头像上。每次只有一个主角。"
        ),
        implementation: L(
            "Rows sit in a ZStack and are positioned by rank with an offset. An update re-ranks the players, raises the mover's zIndex and lift state, and animates the mover and the overtaken rows with two different springs; the crown is one view moved between avatars by matchedGeometryEffect.",
            "各行放在 ZStack 中，按名次用 offset 定位。每次更新重新排名，提高移动行的 zIndex 与抬起状态，并用两种不同的弹簧分别驱动移动行与被超过的行；皇冠是同一个视图，通过 matchedGeometryEffect 在头像之间移动。"
        ),
        apis: ["ZStack", "offset", "zIndex", "matchedGeometryEffect", "contentTransition(.numericText())", "spring(response:dampingFraction:)"],
        tags: ["leaderboard", "ranking", "overtake", "score", "排行榜", "名次", "超越", "积分榜"],
        params: [
            .slider("response", L("Overtake response", "超车弹簧响应"), 0.3...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Overtake damping", "超车阻尼"), 0.45...1, default: 0.72),
            .slider("lift", L("Lift scale", "抬起缩放"), 1...1.12, default: 1.05),
        ]
    ) { ctx in
        LeaderboardDemo(ctx: ctx)
    }
}

private struct LeaderboardPlayer: Identifiable {
    let id: Int
    let name: LocalizedText
    let colors: [Color]
    var score: Double
}

private let leaderboardSeed: [LeaderboardPlayer] = [
    LeaderboardPlayer(id: 0, name: L("Mira", "米拉"), colors: [Palette.indigo, Palette.violet], score: 2480),
    LeaderboardPlayer(id: 1, name: L("Jonas", "乔纳斯"), colors: [Palette.amber, Palette.coral], score: 2310),
    LeaderboardPlayer(id: 2, name: L("Aiko", "爱子"), colors: [Palette.mint, Palette.sky], score: 2150),
    LeaderboardPlayer(id: 3, name: L("Theo", "西奥"), colors: [Palette.pink, Palette.violet], score: 1990),
    LeaderboardPlayer(id: 4, name: L("Lena", "莱娜"), colors: [Palette.sky, Palette.blue], score: 1840),
]

/// (player, points): a scripted round of gains that produces single and double overtakes, then loops.
private let leaderboardScript: [(Int, Double)] = [(3, 420), (4, 380), (1, 260), (2, 510), (0, 330), (4, 470), (3, 290), (1, 360)]

private struct LeaderboardDemo: View {
    let ctx: DemoContext
    @State private var players = leaderboardSeed
    @State private var ranks: [Int: Int] = [0: 0, 1: 1, 2: 2, 3: 3, 4: 4]
    @State private var deltas: [Int: Int] = [:]
    @State private var lifted: Int?
    @State private var leader = 0
    @State private var step = 0
    @State private var run: Task<Void, Never>?
    @Namespace private var crown

    private static let rowHeight: CGFloat = 36
    private static let rowGap: CGFloat = 4

    var body: some View {
        ChartStage(hint: L("Tap to score the next points", "点击计入下一次得分"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 10) {
                header
                ZStack(alignment: .top) {
                    ForEach(players) { player in
                        let rank = ranks[player.id] ?? player.id
                        LeaderboardRow(
                            player: player,
                            rank: rank,
                            isLeader: leader == player.id,
                            delta: deltas[player.id] ?? 0,
                            lifted: lifted == player.id,
                            liftScale: ctx.cg("lift"),
                            language: ctx.language,
                            crown: crown
                        )
                        .frame(height: Self.rowHeight)
                        .offset(y: CGFloat(rank) * (Self.rowHeight + Self.rowGap))
                        .zIndex(lifted == player.id ? 2 : 0)
                    }
                }
                .frame(height: 5 * Self.rowHeight + 4 * Self.rowGap, alignment: .top)
                .padding(.top, 5)
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { advance() }
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.7, delay: 0.7) { advance() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Weekly league", "本周联赛"), ctx.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(L("Top players", "选手排行"), ctx.language)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Palette.green).frame(width: 6, height: 6)
                    .phaseAnimator([0.35, 1.0]) { view, phase in view.opacity(phase) } animation: { _ in .easeInOut(duration: 0.8) }
                Text(L("Live", "实时"), ctx.language)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    /// Tap and autoplay: the next scripted gain. The mover gets the stage; the rows it passes follow underneath.
    private func advance() {
        let (id, gain) = leaderboardScript[step % leaderboardScript.count]
        step += 1
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        Haptics.tap(.light)
        run?.cancel()

        var updated = players
        updated[index].score += gain
        let order = updated.sorted { $0.score > $1.score }
        var newRanks: [Int: Int] = [:]
        for (rank, player) in order.enumerated() { newRanks[player.id] = rank }
        var changes: [Int: Int] = [:]
        for player in updated {
            let change = (ranks[player.id] ?? 0) - (newRanks[player.id] ?? 0)
            if change != 0 { changes[player.id] = change }
        }
        let moved = changes[id] != nil
        let response = ctx["response"]
        let damping = ctx["damping"]

        withAnimation(.easeOut(duration: 0.5)) { players[index].score += gain }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            lifted = moved ? id : nil
            deltas = changes
        }
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.14))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: response, dampingFraction: damping)) {
                ranks[id] = newRanks[id]
                leader = order.first?.id ?? leader
            }
            try? await Task.sleep(for: .seconds(0.08))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { ranks = newRanks }
            try? await Task.sleep(for: .seconds(response * 0.75))
            guard !Task.isCancelled else { return }
            if moved, !ctx.isPreview { Haptics.tap(.soft) }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { lifted = nil }
            try? await Task.sleep(for: .seconds(0.75))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { deltas = [:] }
        }
    }
}

private struct LeaderboardRow: View {
    let player: LeaderboardPlayer
    let rank: Int
    let isLeader: Bool
    let delta: Int
    let lifted: Bool
    let liftScale: CGFloat
    let language: AppLanguage
    let crown: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(rank + 1)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isLeader ? Palette.amber : Color.secondary)
                .contentTransition(.numericText())
                .frame(width: 16)
            Circle()
                .fill(LinearGradient(colors: player.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
                .overlay(
                    Text(verbatim: String(player.name(language).prefix(1)))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
                .overlay(alignment: .top) {
                    if isLeader {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.amber)
                            .shadow(color: Palette.amber.opacity(0.5), radius: 3)
                            .matchedGeometryEffect(id: "crown", in: crown)
                            .offset(y: -10)
                    }
                }
            Text(player.name, language)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            if delta != 0 {
                HStack(spacing: 1) {
                    Image(systemName: delta > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 7, weight: .bold))
                    Text(verbatim: "\(abs(delta))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(delta > 0 ? Palette.green : Palette.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((delta > 0 ? Palette.green : Palette.red).opacity(0.14), in: Capsule())
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
            ChartRollText(value: player.score) { String(Int($0.rounded())) }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(lifted ? AnyShapeStyle(Palette.elevated) : AnyShapeStyle(Color.primary.opacity(0.045)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(player.colors[0].opacity(lifted ? 0.16 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(player.colors[0].opacity(lifted ? 0.5 : 0), lineWidth: 1)
                )
                .shadow(color: .black.opacity(lifted ? 0.22 : 0), radius: lifted ? 14 : 0, y: lifted ? 8 : 0)
        }
        .scaleEffect(lifted ? liftScale : 1)
    }
}
