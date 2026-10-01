import SwiftUI

extension Effect {
    static let navigationIslandBarPlayer = Effect(
        id: "navigation.island-bar-player",
        category: .navigation,
        interaction: .tap,
        name: L("Island Tab Bar Player", "灵动标签栏播放器"),
        summary: L(
            "Start a track and the floating tab bar re-forms into a mini player; send it back and the spinning artwork stays behind as a fifth tab.",
            "开始播放后，悬浮标签栏重组为迷你播放器；收回时，旋转的封面留下来变成第五个标签。"
        ),
        prompt: L(
            "A black floating capsule tab bar (216 × 56 pt, four icons) under a track list. Tapping a track morphs the same capsule into a 264 × 64 pt mini player on one spring (response 0.5 s, damping 0.72), so its size overshoots and settles: the tab icons shrink to 70% and blur 6 pt away in 0.16 s, and after 80 ms the title, artist, a four-bar equaliser and the play and tabs buttons blur in. The round artwork is one persistent view: it grows from 30 to 44 pt and flies from the trailing end to the leading end, spinning while music plays, with a progress ring around it. The tabs button reverses everything, but the bar comes back 46 pt wider with the small spinning artwork parked at its trailing end as a way back into the player. A medium haptic marks each morph.",
            "曲目列表下是黑色悬浮胶囊标签栏（216 × 56 pt，四个图标）。点击一首歌，同一枚胶囊以弹簧（响应 0.5 秒、阻尼 0.72）变形为 264 × 64 pt 的迷你播放器，尺寸略过冲：标签图标在 0.16 秒内缩到 70%、带 6 pt 模糊退场，80 毫秒后歌名、歌手、四根均衡器音柱与两个按钮模糊入场。圆形封面始终是同一视图：从 30 pt 长到 44 pt，由尾端飞到首端，播放时旋转，外圈有进度环。点击网格按钮一切反向，但标签栏回来时宽了 46 pt，旋转的小封面停在尾端，作为回播放器的入口。变形时有中等触感。"
        ),
        implementation: L(
            "One ZStack owns an explicit frame that changes with the mode; tabs and player contents are swapped with a blur-scale Transition, while the artwork lives outside both and only changes size and offset, so it travels instead of cross-fading. TimelineView spins the disc and drives the equaliser.",
            "一个 ZStack 持有随模式变化的显式尺寸；标签与播放器内容用「模糊加缩放」的 Transition 互换，封面则放在两者之外，只改变尺寸与偏移，因此它是飞过去而不是交叉淡化。TimelineView 负责唱片旋转与均衡器。"
        ),
        apis: ["Transition", "TimelineView", "contentTransition(.symbolEffect(.replace))", "spring(response:dampingFraction:)", "transition(.blurReplace)"],
        tags: ["tab bar", "mini player", "island", "morph", "标签栏", "迷你播放器", "灵动岛", "变形"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.45...1.0, default: 0.72),
            .slider("blur", L("Content blur", "内容模糊"), 0...12, default: 6, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        IslandBarPlayerDemo(ctx: ctx)
    }
}

private struct IslandTrack {
    let title: LocalizedText
    let artist: LocalizedText
    let symbol: String
    let colors: [Color]
}

private let islandTracks: [IslandTrack] = [
    IslandTrack(title: L("Slow Tide", "缓潮"), artist: L("Mira Lane", "米拉·莱恩"), symbol: "water.waves", colors: [Palette.sky, Palette.indigo]),
    IslandTrack(title: L("Paper Suns", "纸太阳"), artist: L("The Quiet Hours", "静默时刻"), symbol: "sun.max.fill", colors: [Palette.amber, Palette.coral]),
    IslandTrack(title: L("Night Garden", "夜花园"), artist: L("Okapi", "欧卡皮"), symbol: "leaf.fill", colors: [Palette.mint, Palette.violet]),
]

private let islandTabSymbols: [String] = ["house.fill", "magnifyingglass", "square.stack.fill", "person.fill"]

private enum IslandMode {
    case tabs
    case player
}

/// Scale + blur + fade for the contents that swap inside the capsule.
private struct IslandContentTransition: Transition {
    let blur: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.7)
            .blur(radius: phase.isIdentity ? 0 : blur)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

private struct IslandBarPlayerDemo: View {
    let ctx: DemoContext
    @State private var mode: IslandMode
    @State private var current: Int?
    @State private var playing: Bool
    @State private var tab = 0
    @State private var tabBounces: [Int] = [0, 0, 0, 0]
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the player.
        _mode = State(initialValue: ctx.isStill ? .player : .tabs)
        _current = State(initialValue: ctx.isStill ? 0 : nil)
        _playing = State(initialValue: ctx.isStill)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    private var barSize: CGSize {
        switch mode {
        case .player: return CGSize(width: 264, height: 64)
        case .tabs: return CGSize(width: current == nil ? 216 : 262, height: 56)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            screen
            DemoHint(text: L("Tap a track, then the grid button", "点一首歌，再点右侧的网格按钮"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoplayStep() }
    }

    private var screen: some View {
        ZStack(alignment: .bottom) {
            trackList
                .frame(maxHeight: .infinity, alignment: .top)
            bar
                .padding(.bottom, 14)
        }
        .frame(width: 290, height: 284)
        .background(Palette.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }

    // MARK: Track list

    private var trackList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("Up next", "接下来播放"), ctx.language)
                .font(.title3.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.bottom, 2)
            ForEach(0..<islandTracks.count, id: \.self) { index in
                trackRow(index)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
    }

    private func trackRow(_ index: Int) -> some View {
        let track: IslandTrack = islandTracks[index]
        let active: Bool = current == index
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: track.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title, ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(active ? track.colors[0] : Color.primary)
                Text(track.artist, ctx.language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: active && playing ? "speaker.wave.2.fill" : "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(active ? track.colors[0] : Color.secondary.opacity(0.6))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24)
        }
        .padding(.horizontal, 8)
        .frame(height: 46)
        .background(Color.primary.opacity(active ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { play(index) }
    }

    // MARK: Bar

    private var bar: some View {
        let size: CGSize = barSize
        return ZStack {
            Capsule()
                .fill(Color(hex: 0x0E0E12))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
                .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
            if mode == .tabs {
                tabsContent
                    .frame(width: size.width, alignment: .leading)
                    .transition(contentTransition)
            } else {
                playerContent
                    .frame(width: size.width)
                    .transition(contentTransition)
            }
            if let index = current {
                disc(islandTracks[index], barWidth: size.width)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var contentTransition: AnyTransition {
        let base = AnyTransition(IslandContentTransition(blur: ctx.cg("blur")))
        return .asymmetric(
            insertion: base.animation(spring.delay(0.08)),
            removal: base.animation(.easeIn(duration: 0.16))
        )
    }

    private var tabsContent: some View {
        HStack(spacing: 0) {
            ForEach(0..<islandTabSymbols.count, id: \.self) { index in
                Image(systemName: islandTabSymbols[index])
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(tab == index ? 1 : 0.45))
                    .symbolEffect(.bounce, value: tabBounces[index])
                    .frame(width: 50, height: 40)
                    .background {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .opacity(tab == index ? 1 : 0)
                            .scaleEffect(tab == index ? 1 : 0.6)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectTab(index) }
            }
        }
        .padding(.leading, 8)
    }

    private var playerContent: some View {
        let track: IslandTrack = islandTracks[current ?? 0]
        return HStack(spacing: 8) {
            Color.clear.frame(width: 46, height: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title, ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                Text(track.artist, ctx.language)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .lineLimit(1)
            .id(current ?? 0)
            .transition(.blurReplace)
            Spacer(minLength: 0)
            IslandEqualizer(playing: playing, color: track.colors[0], preview: ctx.isPreview)
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 40)
                .contentShape(Rectangle())
                .onTapGesture { togglePlay() }
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.14), in: Circle())
                .contentShape(Circle())
                .onTapGesture { showTabs() }
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
    }

    /// The artwork is one view in both modes: it only changes size and side.
    private func disc(_ track: IslandTrack, barWidth: CGFloat) -> some View {
        let big: Bool = mode == .player
        let diameter: CGFloat = big ? 44 : 30
        let x: CGFloat = big ? -barWidth / 2 + 10 + 22 : barWidth / 2 - 12 - 15
        return IslandDisc(track: track, playing: playing, preview: ctx.isPreview)
            .frame(width: diameter, height: diameter)
            .offset(x: x)
            .contentShape(Circle())
            .onTapGesture {
                if big { togglePlay() } else { showPlayer() }
            }
    }

    // MARK: Actions

    private func play(_ index: Int) {
        if !ctx.isPreview { Haptics.tap(.medium) }
        withAnimation(spring) {
            current = index
            playing = true
            mode = .player
        }
    }

    private func showTabs() {
        guard mode == .player else { return }
        if !ctx.isPreview { Haptics.tap(.medium) }
        withAnimation(spring) { mode = .tabs }
    }

    private func showPlayer() {
        guard mode == .tabs, current != nil else { return }
        if !ctx.isPreview { Haptics.tap(.medium) }
        withAnimation(spring) { mode = .player }
    }

    private func togglePlay() {
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.snappy(duration: 0.25)) { playing.toggle() }
    }

    private func selectTab(_ index: Int) {
        if !ctx.isPreview { Haptics.selection() }
        tabBounces[index] += 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { tab = index }
    }

    private func autoplayStep() {
        let phase: Int = autoStep % 6
        autoStep += 1
        switch phase {
        case 0: play(0)
        case 1: showTabs()
        case 2: selectTab((tab + 1) % islandTabSymbols.count)
        case 3: showPlayer()
        case 4: play(((current ?? 0) + 1) % islandTracks.count)
        default: showTabs()
        }
    }
}

// MARK: - Pieces

/// Round artwork that spins while playing, inside a progress ring.
private struct IslandDisc: View {
    let track: IslandTrack
    let playing: Bool
    let preview: Bool
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !playing || isStill)) { timeline in
            let seconds: Double = isStill ? 4 : timeline.date.timeIntervalSinceReferenceDate
            let progress: Double = seconds.truncatingRemainder(dividingBy: 14) / 14
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        Image(systemName: track.symbol)
                            .resizable()
                            .scaledToFit()
                            .fontWeight(.bold)
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(.all, 9)
                    }
                    .rotationEffect(.degrees(seconds * 42))
                    .padding(3)
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(track.colors[0], style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

private struct IslandEqualizer: View {
    let playing: Bool
    let color: Color
    let preview: Bool
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !playing || isStill)) { timeline in
            let time: Double = isStill ? 1.3 : timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<4, id: \.self) { index in
                    let wave: Double = sin(time * (5.2 + Double(index) * 1.7) + Double(index) * 1.3)
                    let level: CGFloat = playing ? CGFloat(0.5 + 0.5 * wave) : 0
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: 4 + 12 * level)
                }
            }
            .frame(width: 20, height: 18)
            .animation(.easeOut(duration: 0.2), value: playing)
        }
    }
}
