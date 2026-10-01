import SwiftUI

extension Effect {
    static let showcaseVoiceMemo = Effect(
        id: "showcase.voice-memo",
        category: .showcase,
        interaction: .tap,
        name: L("Voice Memo Capture", "语音备忘录音"),
        summary: L(
            "Live bars stream in while recording; stop squeezes the whole take into a playback pill you can scrub.",
            "录音时波形柱不断流入；停止后整段录音被压进一枚可拖动的播放胶囊。"
        ),
        prompt: L(
            "A dark voice-memo widget with a large m:ss.t timer, a 252 × 60 pt waveform strip and a record button whose red core morphs from a circle to a 24 pt rounded square while recording. Twelve times a second a new white bar scales up at a red record head on the right and the row slides left one 6.5 pt step linearly, fading out at the left edge. Tapping stop squeezes the whole take into a playback pill: every bar, including those that scrolled away, springs (response 0.6 s, damping 0.78) to one of 30 merged slots, newest first with a 4 ms stagger, while a play button pops in on the left and the seconds roll back to 0:00. Playback then sweeps a glowing white playhead and turns played bars orange; dragging the pill scrubs with a selection tick per bar. Crisp and satisfying.",
            "深色语音备忘小组件：大号 m:ss.t 计时、252 × 60pt 波形带，以及红芯会在录音时由圆形变为 24pt 圆角方块的录音键。每秒 12 次，一根白色柱子在右侧红色录音头处长出，整排线性左移 6.5pt，并在左缘淡出。点击停止，整段录音被压进播放胶囊：所有柱子（包括已滚出画面的）以弹簧（响应 0.6 秒、阻尼 0.78）归并到 30 个槽位，最新的先动、逐根错开 4 毫秒；左侧弹出播放键，秒数滚回 0:00。随后白色发光播放头扫过，已播放的柱子变橙；拖动胶囊即可定位，每过一根有一次选择触感。干脆而解压。"
        ),
        implementation: L(
            "Every sample is one Capsule with an explicit x offset: while recording it is placed from the right by its age and appended inside a linear withAnimation, so the row scrolls; in review the same views get the offset and height of their merged slot, and a per-bar spring with an index delay produces the squeeze. A task(id:) loop feeds samples and another advances the playhead; a DragGesture maps x to progress.",
            "每个采样是一根带显式 x 偏移的 Capsule：录音时按“年龄”从右侧排布，并在线性 withAnimation 中追加，于是整排滚动；回放时同一批视图改用所属合并槽位的偏移与高度，配合按索引延迟的逐根弹簧形成“压缩”。一个 task(id:) 循环写入采样，另一个推进播放头；DragGesture 把横坐标映射为进度。"
        ),
        apis: ["task(id:)", "withAnimation(.linear)", "offset(x:)", "contentTransition(.numericText)", "DragGesture", "mask"],
        tags: ["voice memo", "recording", "waveform", "scrubber", "audio", "录音", "语音备忘录", "波形", "播放", "进度"],
        params: [
            .slider("bars", L("Playback bars", "回放柱数"), 18...44, default: 30, step: 1, decimals: 0),
            .slider("rate", L("Samples per second", "每秒采样"), 8...16, default: 12, step: 1, decimals: 0),
            .slider("gain", L("Input gain", "输入增益"), 0.5...1.5, default: 1.0),
        ]
    ) { ctx in
        VoiceMemoDemo(ctx: ctx)
    }
}

private enum VoiceMode {
    case recording
    case review
}

private struct VoiceMemoDemo: View {
    let ctx: DemoContext
    @State private var mode: VoiceMode = .review
    @State private var samples: [CGFloat]
    @State private var duration: Double
    @State private var playhead: Double
    @State private var playing = false
    @State private var scrubbing = false
    @State private var resumeAfterScrub = false
    @State private var recordStart = Date()
    @State private var cap: Double = 12
    @State private var userDriven = false
    @State private var take = 3
    @State private var lastSlot = -1

    private static let red = Color(hex: 0xFF453A)

    init(ctx: DemoContext) {
        self.ctx = ctx
        let seeded = (0..<84).map { VoiceMemoDemo.amplitude($0, take: 3, gain: 1) }
        _samples = State(initialValue: seeded)
        _duration = State(initialValue: 7.0)
        _playhead = State(initialValue: ctx.isStill ? 0.44 : 0)
    }

    private var zh: Bool { ctx.language == .zh }
    private var rate: Double { max(ctx["rate"], 4) }
    private var slots: Int { max(ctx.int("bars"), 8) }
    private var recording: Bool { mode == .recording }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card
                Spacer(minLength: 0)
                DemoHint(text: L("Tap to record, tap to stop · drag the pill", "点击录音，再点停止 · 拖动胶囊定位"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: "\(recording)-\(take)-\(rate)") { await record() }
        .task(id: "\(playing)-\(scrubbing)") { await play() }
        .autoplay(ctx.isPreview, every: 8.4, delay: 0.8) {
            guard !recording else { return }
            start(cap: 3.8, user: false)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            timer
            VoiceWave(
                samples: samples,
                recording: recording,
                slots: slots,
                playhead: playhead,
                playing: playing,
                onPlay: userTogglePlay,
                onScrub: scrub,
                onScrubEnd: endScrub
            )
            controls
        }
        .padding(18)
        .frame(width: 288)
        .signatureCard()
    }

    private var header: some View {
        HStack(spacing: 6) {
            ZStack {
                if recording {
                    SportLiveDot(color: Self.red, preview: ctx.isPreview)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "waveform")
                        .foregroundStyle(Signature.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 24, height: 24)
            Text(verbatim: (zh ? "新录音 " : "New memo ") + "\(take)")
            Spacer(minLength: 0)
            Text(verbatim: recording ? (zh ? "录音中" : "Recording") : (zh ? "已保存" : "Saved"))
                .foregroundStyle(recording ? Self.red : Signature.lime)
                .contentTransition(.opacity)
        }
        .signatureEyebrow()
    }

    private var timer: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            let t = recording ? max(0, timeline.date.timeIntervalSince(recordStart)) : playhead * duration
            let whole = Int(t)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: studioClock(t))
                    .font(Signature.number(44))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText(value: Double(whole)))
                    .animation(.snappy(duration: 0.25), value: whole)
                Text(verbatim: "." + String(Int(t * 10) % 10))
                    .font(Signature.number(24))
                    .foregroundStyle(Signature.textSecondary)
                Spacer(minLength: 0)
                Text(verbatim: "/ " + studioClock(duration))
                    .font(Signature.number(14))
                    .foregroundStyle(Signature.textSecondary)
                    .opacity(recording ? 0 : 1)
            }
        }
    }

    private var controls: some View {
        HStack {
            Text(verbatim: recording ? (zh ? "轻点停止" : "Tap to stop") : (zh ? "轻点重录" : "Tap to record"))
                .signatureEyebrow()
                .contentTransition(.opacity)
                .frame(width: 84, alignment: .leading)
            Spacer(minLength: 0)
            Button(action: userPrimary) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                        .frame(width: 60, height: 60)
                    RoundedRectangle(cornerRadius: recording ? 7 : 24, style: .continuous)
                        .fill(Self.red)
                        .frame(width: recording ? 24 : 48, height: recording ? 24 : 48)
                        .shadow(color: Self.red.opacity(recording ? 0.7 : 0.3), radius: recording ? 12 : 5)
                }
                .contentShape(Circle())
            }
            .buttonStyle(SportPressStyle(scale: 0.92, dim: 0.05))
            .accessibilityLabel(Text(recording ? L("Stop", "停止") : L("Record", "录音"), ctx.language))
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                Text(verbatim: "AAC")
            }
            .signatureEyebrow()
            .frame(width: 84, alignment: .trailing)
        }
    }

    // MARK: Actions

    private func userPrimary() {
        if recording {
            Haptics.tap(.medium)
            stop()
        } else {
            Haptics.tap(.light)
            start(cap: 12, user: true)
        }
    }

    private func start(cap limit: Double, user: Bool) {
        cap = limit
        userDriven = user
        recordStart = Date()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            playing = false
            playhead = 0
            samples = []
            take += 1
            mode = .recording
        }
    }

    private func stop() {
        guard recording else { return }
        duration = max(Double(samples.count) / rate, 0.5)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
            mode = .review
            playhead = 0
        }
        let finishedTake = take
        Task { @MainActor in
            guard await studioPause(0.7), mode == .review, take == finishedTake, !playing else { return }
            playing = true
        }
    }

    private func userTogglePlay() {
        Haptics.tap(.light)
        if !playing && playhead >= 0.999 { playhead = 0 }
        playing.toggle()
    }

    private func scrub(_ fraction: Double) {
        if !scrubbing {
            resumeAfterScrub = playing
            scrubbing = true
        }
        let clamped = fraction.clamped(to: 0...1)
        playhead = clamped
        let slot = Int(clamped * Double(slots))
        if slot != lastSlot {
            lastSlot = slot
            Haptics.selection()
        }
    }

    private func endScrub() {
        guard scrubbing else { return }
        scrubbing = false
        if resumeAfterScrub && playhead < 0.999 { playing = true }
    }

    private func record() async {
        guard recording else { return }
        let interval = 1.0 / rate
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, recording else { return }
            let index = samples.count
            let value = Self.amplitude(index, take: take, gain: ctx["gain"])
            withAnimation(.linear(duration: interval)) { samples.append(value) }
            if Double(index + 1) * interval >= cap {
                if userDriven { Haptics.tap(.medium) }
                stop()
                return
            }
        }
    }

    private func play() async {
        guard playing, !scrubbing, mode == .review else { return }
        let frame = 1.0 / 30.0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(frame))
            guard !Task.isCancelled else { return }
            let next = playhead + frame / duration
            if next >= 1 {
                withAnimation(.linear(duration: frame)) { playhead = 1 }
                playing = false
                return
            }
            withAnimation(.linear(duration: frame)) { playhead = next }
        }
    }

    /// Speech-like level: hashed syllable peaks under a slow phrase envelope.
    static func amplitude(_ index: Int, take: Int, gain: Double) -> CGFloat {
        let x = Double(index)
        let seed = Double(take) * 17.3
        let peak = pow(sportHash(x * 1.37 + seed), 1.5)
        let phrase = 0.3 + 0.7 * abs(sin(x * 0.17 + seed))
        return CGFloat((0.1 + 0.9 * peak * phrase) * gain).clamped(to: 0.07...1)
    }
}

// MARK: - Waveform strip / playback pill

private struct VoiceWave: View {
    let samples: [CGFloat]
    let recording: Bool
    let slots: Int
    let playhead: Double
    let playing: Bool
    let onPlay: () -> Void
    let onScrub: (Double) -> Void
    let onScrubEnd: () -> Void

    private let width: CGFloat = 252
    private let height: CGFloat = 60
    private let livePitch: CGFloat = 6.5
    private let headInset: CGFloat = 18
    /// The pill's bars start after the play button.
    private let pillLead: CGFloat = 54
    private let pillTrail: CGFloat = 16
    @GestureState private var touching = false

    private var pillWidth: CGFloat { width - pillLead - pillTrail }
    private var slotPitch: CGFloat { pillWidth / CGFloat(slots) }

    var body: some View {
        let levels = recording ? [] : slotLevels
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.07))
                .overlay(Capsule().strokeBorder(Signature.hairline, lineWidth: 1))
                .opacity(recording ? 0 : 1)
                .scaleEffect(x: recording ? 1.06 : 1, y: recording ? 0.8 : 1)
            bars(levels: levels)
                .mask {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing)
                            .frame(width: recording ? 80 : 0)
                        Color.white
                    }
                }
            // Record head.
            Capsule()
                .fill(Color(hex: 0xFF453A))
                .frame(width: 2, height: height)
                .shadow(color: Color(hex: 0xFF453A).opacity(0.9), radius: 5)
                .offset(x: width - headInset + livePitch - 1)
                .opacity(recording ? 1 : 0)
            // Playhead.
            Capsule()
                .fill(Color.white)
                .frame(width: 2, height: height - 16)
                .shadow(color: .white.opacity(0.7), radius: 4)
                .offset(x: pillLead + pillWidth * CGFloat(playhead) - 1)
                .opacity(recording ? 0 : 1)
            playButton
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($touching) { _, state, _ in state = true }
                .onChanged { value in
                    guard !recording else { return }
                    onScrub(Double((value.location.x - pillLead) / pillWidth))
                }
                .onEnded { _ in onScrubEnd() }
        )
        .onChange(of: touching) { _, isTouching in
            if !isTouching { onScrubEnd() }
        }
    }

    private var playButton: some View {
        Button(action: onPlay) {
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Signature.ink)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 38, height: 38)
                .background(Signature.accentGradient, in: Circle())
                .shadow(color: Signature.accent.opacity(0.5), radius: 6, y: 2)
        }
        .buttonStyle(SportPressStyle(scale: 0.88, dim: 0.05))
        .offset(x: 9)
        .scaleEffect(recording ? 0.2 : 1)
        .opacity(recording ? 0 : 1)
        .allowsHitTesting(!recording)
    }

    private func bars(levels: [CGFloat]) -> some View {
        let count = samples.count
        let slotBar: CGFloat = max(2, slotPitch * 0.56)
        return ZStack(alignment: .leading) {
            ForEach(samples.indices, id: \.self) { index in
                let slot: Int = min(slots - 1, index * slots / max(count, 1))
                let age: CGFloat = CGFloat(count - 1 - index)
                let played: Bool = Double(slot) + 0.5 < playhead * Double(slots)
                let restTint: Color = played ? Signature.accent : Color(white: 0.4)
                let tint: Color = recording ? Color(white: 0.94) : restTint
                let level: CGFloat = slot < levels.count ? levels[slot] : 0.1
                let liveHeight: CGFloat = max(4, samples[index] * height)
                let restHeight: CGFloat = max(4, level * (height - 22))
                let liveX: CGFloat = width - headInset - age * livePitch
                let restX: CGFloat = pillLead + CGFloat(slot) * slotPitch + (slotPitch - slotBar) / 2
                let squeezeDelay: Double = min(Double(age) * 0.004, 0.3)
                Capsule()
                    .fill(tint)
                    .frame(width: recording ? 3.5 : slotBar, height: recording ? liveHeight : restHeight)
                    .offset(x: recording ? liveX : restX)
                    .transition(.scale(scale: 0.05).combined(with: .opacity))
                    // The squeeze: newest bars leave first.
                    .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(squeezeDelay), value: recording)
            }
        }
        .frame(width: width, height: height, alignment: .leading)
        .clipped()
    }

    /// Peak-leaning level of every merged slot.
    private var slotLevels: [CGFloat] {
        let count = samples.count
        guard count > 0 else { return Array(repeating: 0.1, count: slots) }
        var sums = Array(repeating: CGFloat(0), count: slots)
        var peaks = Array(repeating: CGFloat(0), count: slots)
        var counts = Array(repeating: CGFloat(0), count: slots)
        for index in 0..<count {
            let slot = min(slots - 1, index * slots / count)
            sums[slot] += samples[index]
            peaks[slot] = max(peaks[slot], samples[index])
            counts[slot] += 1
        }
        // More slots than samples: empty slots borrow the nearest filled one.
        var result = Array(repeating: CGFloat(0.1), count: slots)
        var lastFilled: CGFloat = 0.1
        for slot in 0..<slots {
            if counts[slot] > 0 {
                lastFilled = 0.5 * peaks[slot] + 0.5 * sums[slot] / counts[slot]
            }
            result[slot] = lastFilled
        }
        return result
    }
}
