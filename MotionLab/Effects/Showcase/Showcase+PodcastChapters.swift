import SwiftUI

extension Effect {
    static let showcasePodcastChapters = Effect(
        id: "showcase.podcast-chapters",
        category: .showcase,
        interaction: .gesture,
        name: L("Chapter Scrubber", "章节进度条"),
        summary: L(
            "A podcast scrubber split into chapters: the knob catches on each boundary with a click, the chapter title rolls and the artwork re-tints.",
            "按章节分段的播客进度条：旋钮在每个章节分界处被“咬住”并咔哒一下，章节标题滚动，封面随之换色。"
        ),
        prompt: L(
            "A dark podcast player card: square artwork tinted by the current chapter, a chapter counter and title, and a scrubber cut into five segments by 3 pt gaps, with elapsed and remaining time beneath and transport buttons. While it plays, the fill creeps forward. Touching the scrubber thickens the track from 4 pt to 10 pt and grows the knob from 14 pt to 22 pt on a spring (response 0.3 s, damping 0.7), and a time bubble pops up above the finger. The knob is magnetic: within 9 pt of a chapter boundary it sticks to it. Crossing a boundary fires a rigid haptic, bumps the knob to 130%, rolls the chapter title up or down according to the direction (response 0.4 s, damping 0.8) and cross-fades the artwork gradient and the card's top glow to the new chapter's colour over 0.45 s. Release shrinks everything back. Precise, editorial.",
            "深色播客播放卡片：方形封面按当前章节着色，旁边是章节序号与标题；进度条被 3pt 间隙切成五段，下方是时间与播放控制。播放时填充缓慢前进。按住进度条，轨道以弹簧（响应 0.3 秒、阻尼 0.7）从 4pt 加粗到 10pt，旋钮从 14pt 放大到 22pt，手指上方弹出时间气泡。旋钮带磁性：距章节分界 9pt 内会吸附。越过分界时触发一次硬质触感，旋钮顶到 130%，章节标题按拖动方向上下滚动（响应 0.4 秒、阻尼 0.8），封面与卡片顶部光晕在 0.45 秒内过渡到新章节的颜色。松手即收回。精确克制。"
        ),
        implementation: L(
            "A DragGesture maps x to a 0…1 fraction and snaps it to the nearest chapter start inside the magnet radius; the chapter index derived from the fraction drives an id-keyed push transition for the title and animated colours. Segments are capsules with a leading overlay sized to the played share, and a keyframeAnimator bumps the knob on each crossing.",
            "DragGesture 把 x 映射为 0…1 的比例，并在磁吸半径内吸附到最近的章节起点；由比例推导出的章节下标驱动以 id 为键的标题 push 转场和颜色动画。每一段是带前缘覆盖层的胶囊，覆盖层宽度等于已播比例；每次越界由 keyframeAnimator 让旋钮顶一下。"
        ),
        apis: ["DragGesture", "transition(.push)", "keyframeAnimator", "spring(response:dampingFraction:)", "contentTransition(.numericText)", "task"],
        tags: ["podcast", "scrubber", "chapters", "audio", "seek", "播客", "进度条", "章节", "音频", "拖动"],
        params: [
            .slider("magnet", L("Magnet radius", "磁吸半径"), 0...18, default: 9, decimals: 0, unit: "pt"),
            .slider("thick", L("Scrub thickness", "拖动时粗细"), 6...14, default: 10, decimals: 0, unit: "pt"),
            .slider("speed", L("Playback speed", "播放速度"), 0...60, default: 20, decimals: 0, unit: "×"),
        ]
    ) { ctx in
        PodcastChaptersDemo(ctx: ctx)
    }
}

private struct PodcastChapter {
    let title: LocalizedText
    let start: Double
    let color: UInt32
    let symbol: String

    static let duration: Double = 2530
    static let all: [PodcastChapter] = [
        PodcastChapter(title: L("Cold open", "开场白"), start: 0, color: 0xFF8A1F, symbol: "mic.fill"),
        PodcastChapter(title: L("Why motion matters", "动效为什么重要"), start: 0.15, color: 0xE0559A, symbol: "sparkles"),
        PodcastChapter(title: L("Springs vs. curves", "弹簧与曲线之争"), start: 0.38, color: 0x7C6CFF, symbol: "waveform.path"),
        PodcastChapter(title: L("Designing haptics", "如何设计触感"), start: 0.61, color: 0x2BB8C9, symbol: "hand.tap.fill"),
        PodcastChapter(title: L("Listener questions", "听众提问"), start: 0.83, color: 0x7BCB4E, symbol: "bubble.left.and.bubble.right.fill"),
    ]

    static func index(at fraction: Double) -> Int {
        var result = 0
        for (index, chapter) in all.enumerated() where fraction >= chapter.start - 0.0001 { result = index }
        return result
    }

    static func end(_ index: Int) -> Double {
        index + 1 < all.count ? all[index + 1].start : 1
    }
}

private struct PodcastChaptersDemo: View {
    let ctx: DemoContext
    @State private var progress: Double
    @State private var chapter: Int
    @State private var forward = true
    @State private var dragging = false
    @State private var playing = true
    @State private var crossings = 0
    @State private var script: Task<Void, Never>?
    @State private var scripting = false
    @GestureState private var finger = false

    private let trackWidth: CGFloat = 256

    init(ctx: DemoContext) {
        self.ctx = ctx
        let start = ctx.isStill ? 0.47 : 0.06
        _progress = State(initialValue: start)
        _chapter = State(initialValue: PodcastChapter.index(at: start))
    }

    private var zh: Bool { ctx.language == .zh }
    private var tint: Color { Color(hex: PodcastChapter.all[chapter].color) }

    var body: some View {
        StudioScene(hint: L("Drag the scrubber across the chapters", "拖动进度条，越过章节分界"), ctx: ctx) {
            card
        }
        .task(id: "\(playing)-\(ctx["speed"])") {
            guard playing, !ctx.isStill, ctx["speed"] > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.25))
                guard !Task.isCancelled else { return }
                guard !dragging else { continue }
                let next = progress + ctx["speed"] * 0.25 / PodcastChapter.duration
                withAnimation(.linear(duration: 0.25)) { apply(next > 1 ? 0 : next, user: false) }
            }
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 3.3, delay: 0.7) { runScript() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            scrubber
            transport
        }
        .padding(18)
        .frame(width: 292)
        .background(alignment: .top) {
            RadialGradient(colors: [tint.opacity(0.34), .clear], center: .topLeading, startRadius: 0, endRadius: 210)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .animation(.easeInOut(duration: 0.45), value: chapter)
        }
        .signatureCard()
    }

    private var header: some View {
        let info = PodcastChapter.all[chapter]
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.45), Signature.ink], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 8)
                    .frame(width: 84, height: 84)
                    .offset(x: 18, y: 20)
                Image(systemName: info.symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 66, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            .shadow(color: tint.opacity(0.5), radius: 12, y: 6)
            .animation(.easeInOut(duration: 0.45), value: chapter)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    StudioEqualizer(color: tint, height: 10, active: playing, preview: ctx.isPreview)
                    Text(verbatim: zh ? "第 \(chapter + 1) 章 / 共 \(PodcastChapter.all.count) 章" : "Chapter \(chapter + 1) of \(PodcastChapter.all.count)")
                        .font(Signature.eyebrow)
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(tint)
                        .contentTransition(.numericText(value: Double(chapter)))
                }
                ZStack(alignment: .leading) {
                    Text(info.title, ctx.language)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .id(chapter)
                        .transition(.push(from: forward ? .bottom : .top))
                }
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .clipped()
                Text(verbatim: zh ? "动效小谈 · 第 48 期" : "Motion Notes · Ep. 48")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
            }
        }
    }

    // MARK: Scrubber

    private var scrubber: some View {
        let thickness: CGFloat = dragging ? ctx.cg("thick") : 4
        let knob: CGFloat = dragging ? 22 : 14
        let x = trackWidth * CGFloat(progress)
        return VStack(spacing: 6) {
            ZStack(alignment: .leading) {
                HStack(spacing: 3) {
                    ForEach(PodcastChapter.all.indices, id: \.self) { index in
                        let start = PodcastChapter.all[index].start
                        let end = PodcastChapter.end(index)
                        let share = ((progress - start) / (end - start)).clamped(to: 0...1)
                        let width = trackWidth * CGFloat(end - start) - (index == PodcastChapter.all.count - 1 ? 0 : 3)
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(tint)
                                    .frame(width: max(width * CGFloat(share), share > 0 ? thickness : 0))
                            }
                            .clipShape(Capsule())
                            .frame(width: width, height: thickness * (dragging && index == chapter ? 1.35 : 1))
                    }
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                    .keyframeAnimator(initialValue: 1.0, trigger: crossings) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.self) {
                            CubicKeyframe(1.3, duration: 0.08)
                            SpringKeyframe(1.0, duration: 0.4, spring: .init(response: 0.28, dampingRatio: 0.5))
                        }
                    }
                    .offset(x: x - knob / 2)
                Text(verbatim: studioClock(progress * PodcastChapter.duration))
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Signature.ink)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(Color.white))
                    .contentTransition(.identity)
                    .fixedSize()
                    .scaleEffect(dragging ? 1 : 0.4, anchor: .bottom)
                    .opacity(dragging ? 1 : 0)
                    .frame(width: 60)
                    .offset(x: (x - 30).clamped(to: -8...(trackWidth - 52)), y: -26)
            }
            .frame(width: trackWidth, height: 26, alignment: .leading)
            .contentShape(Rectangle().inset(by: -8))
            .gesture(drag)
            .onChange(of: finger) { _, down in
                if !down && !scripting { endDrag() }
            }
            HStack {
                Text(verbatim: studioClock(progress * PodcastChapter.duration))
                Spacer()
                Text(verbatim: "-" + studioClock((1 - progress) * PodcastChapter.duration))
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(Signature.textSecondary)
            .contentTransition(.identity)
        }
        .padding(.top, 10)
    }

    private var transport: some View {
        HStack(spacing: 34) {
            Button { skip(-15) } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            Button {
                Haptics.tap(.medium)
                script?.cancel()
                endDrag()
                withAnimation(.snappy(duration: 0.25)) { playing.toggle() }
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(Signature.ink)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.white))
            }
            Button { skip(30) } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
        }
        .foregroundStyle(Color.white)
        .buttonStyle(SportPressStyle(scale: 0.9, dim: 0.06))
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($finger) { _, state, _ in state = true }
            .onChanged { value in
                if !dragging {
                    script?.cancel()
                    scripting = false
                    beginDrag()
                }
                scrub(to: Double(value.location.x / trackWidth), user: true)
            }
            .onEnded { _ in endDrag() }
    }

    private func beginDrag() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragging = true }
    }

    private func endDrag() {
        guard dragging else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragging = false }
    }

    /// Shared by the finger and the scripted drag: magnet, then apply.
    private func scrub(to raw: Double, user: Bool) {
        var fraction = raw.clamped(to: 0...1)
        let radius = ctx["magnet"] / Double(trackWidth)
        for boundary in PodcastChapter.all.dropFirst().map(\.start) where abs(fraction - boundary) < radius {
            fraction = boundary
        }
        apply(fraction, user: user)
    }

    private func apply(_ fraction: Double, user: Bool) {
        let index = PodcastChapter.index(at: fraction)
        if index != chapter {
            forward = index > chapter
            crossings += 1
            if user && !ctx.isPreview { Haptics.tap(.rigid) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { chapter = index }
        }
        progress = fraction
    }

    private func skip(_ seconds: Double) {
        script?.cancel()
        endDrag()
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            apply((progress + seconds * 12 / PodcastChapter.duration).clamped(to: 0...1), user: true)
        }
    }

    private func runScript() {
        guard !dragging else { return }
        script?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            let from = progress
            let target = from > 0.62 ? 0.04 : from + 0.36
            beginDrag()
            let finished = await studioScript(1.5) { t in
                scrub(to: from + (target - from) * studioEase(t), user: false)
            }
            // Cancelled means a real finger took over: leave the scrubber in its hands.
            guard finished, await studioPause(0.35) else { return }
            endDrag()
        }
    }
}
