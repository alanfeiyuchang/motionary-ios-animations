import SwiftUI

extension Effect {
    static let inputsVoiceField = Effect(
        id: "inputs.voice-field",
        category: .inputs,
        interaction: .tap,
        name: L("Dictation Field", "语音听写输入框"),
        summary: L("Tap the mic: the placeholder dissolves into a live waveform, then the transcript settles in word by word out of blur.", "点一下麦克风：占位文字化成实时声波，随后转写结果一个词一个词地从模糊中落定。"),
        prompt: L(
            "A 292 pt rounded text field with a placeholder and a round mic button. Tapping the mic turns the button red with a stop glyph and a ring that pulses outward every 0.9 s; the placeholder blurs out and a waveform of 28 rounded bars takes its place, rising from a flat line over 350 ms. The bars scroll from right to left like a recording, their heights driven by layered sine noise, tinted with an indigo-to-pink gradient. After 1.8 s, or when stop is tapped, the bars collapse to the centre line in 250 ms and the field grows on a spring (response 0.45 s, damping 0.8) to fit the transcript. Words arrive 70 ms apart, each rising 6 pt while sharpening from an 8 pt blur and fading in (response 0.4 s, damping 0.75).",
            "292pt 圆角输入框，内有占位文字和圆形麦克风按钮。点击后按钮变红、图标换成停止，外圈每 0.9 秒脉冲一次；占位文字模糊淡出，28 根圆头竖条组成的声波取而代之，在 350 毫秒内从一条平线升起。竖条自右向左滚动，高度由多层正弦噪声驱动，着靛蓝到粉色渐变。1.8 秒后（或点击停止时）竖条在 250 毫秒内塌回中线，输入框以弹簧（响应 0.45 秒、阻尼 0.8）长高以容纳转写文字。词语相隔 70 毫秒依次出现：每个词上移 6pt，同时从 8pt 的模糊中变清晰并淡入（响应 0.4 秒、阻尼 0.75）。"
        ),
        implementation: L(
            "A TimelineView-driven Canvas draws the bars from a noise function of bar index and time, scaled by an envelope computed from the start and stop dates. The transcript is a custom flow Layout of word views; a task reveals them one at a time and each animates its own blur, offset and opacity.",
            "由 TimelineView 驱动的 Canvas 按竖条序号与时间的噪声函数绘制声波，并乘以由开始、停止时刻算出的包络。转写文字是自定义流式 Layout 排布的词语视图；一个任务逐个显示它们，每个词各自为模糊、位移与透明度做动画。"
        ),
        apis: ["TimelineView", "Canvas", "Layout", "blur(radius:)", "phaseAnimator", "contentTransition(.symbolEffect(.replace))"],
        tags: ["voice", "dictation", "waveform", "speech", "transcript", "mic", "语音", "听写", "声波", "转写", "麦克风"],
        params: [
            .slider("bars", L("Waveform bars", "声波条数"), 16...40, default: 28, step: 1, decimals: 0),
            .slider("listen", L("Listening time", "聆听时长"), 1.0...4.0, default: 1.8, decimals: 1, unit: "s"),
            .slider("stagger", L("Word stagger", "逐词间隔"), 0.03...0.2, default: 0.07, unit: "s"),
            .slider("blur", L("Entry blur", "入场模糊"), 0...16, default: 8, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        InputVoiceFieldDemo(ctx: ctx)
    }
}

private struct InputVoiceFieldDemo: View {
    private enum Phase { case idle, listening, result }

    let ctx: DemoContext
    @State private var phase: Phase
    @State private var phraseIndex = 0
    @State private var shown: Int
    @State private var startedAt = Date.distantPast
    @State private var stoppedAt = Date.distantPast
    @State private var task: Task<Void, Never>?

    private static let phrases: [(en: [String], zh: [String])] = [
        (["Remind", "me", "to", "water", "the", "plants", "at", "seven", "tomorrow", "morning"], ["明天", "早上", "七点", "提醒我", "给", "阳台", "的", "植物", "浇水"]),
        (["Play", "something", "calm", "for", "a", "rainy", "evening", "at", "home"], ["放", "一点", "适合", "下雨", "的", "夜晚", "听的", "安静", "音乐"]),
        (["Add", "oat", "milk", "and", "coffee", "beans", "to", "my", "shopping", "list"], ["把", "燕麦奶", "和", "咖啡豆", "加到", "我的", "购物", "清单", "里"]),
    ]

    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? .result : .idle)
        _shown = State(initialValue: ctx.isStill ? 99 : 0)
    }

    private var words: [String] {
        let phrase = Self.phrases[phraseIndex % Self.phrases.count]
        return ctx.language == .zh ? phrase.zh : phrase.en
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            field
            Spacer(minLength: 0)
            DemoHint(text: L("Tap the mic and watch it listen", "点击麦克风，看它聆听"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["listen"] + 2.6, delay: 0.5) { micTapped() }
        .onDisappear { task?.cancel() }
    }

    private var field: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return HStack(alignment: .bottom, spacing: 10) {
            ZStack(alignment: .leading) {
                Text(L("Ask anything", "有什么想问的"), ctx.language)
                    .font(.system(size: 17))
                    .foregroundStyle(.tertiary)
                    .opacity(phase == .idle ? 1 : 0)
                    .blur(radius: phase == .idle ? 0 : 6)
                InputVoiceWave(bars: ctx.int("bars"), startedAt: startedAt, stoppedAt: stoppedAt, live: phase == .listening, isPreview: ctx.isPreview)
                    .frame(height: 28)
                    .opacity(phase == .listening ? 1 : 0)
                if phase == .result {
                    transcript
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .padding(.vertical, 6)
            mic
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(width: 292)
        .background(Palette.elevated, in: shape)
        .overlay(shape.strokeBorder(phase == .listening ? Palette.red.opacity(0.45) : Color.primary.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 14, y: 8)
    }

    private var transcript: some View {
        let list = words
        return InputWordFlow(spacing: ctx.language == .zh ? 0 : 5, lineSpacing: 5) {
            ForEach(Array(list.enumerated()), id: \.offset) { index, word in
                let visible = index < shown
                Text(verbatim: word)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .opacity(visible ? 1 : 0)
                    .blur(radius: visible ? 0 : ctx.cg("blur"))
                    .offset(y: visible ? 0 : 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: visible)
            }
        }
    }

    private var mic: some View {
        let listening = phase == .listening
        return Button(action: micTapped) {
            ZStack {
                if listening {
                    Circle()
                        .stroke(Palette.red, lineWidth: 2)
                        .phaseAnimator([false, true]) { view, out in
                            view
                                .scaleEffect(out ? 1.55 : 1)
                                .opacity(out ? 0 : 0.7)
                        } animation: { out in
                            out ? .easeOut(duration: 0.9) : .linear(duration: 0.01)
                        }
                }
                Circle()
                    .fill(listening ? Palette.red : Color.primary.opacity(0.08))
                Image(systemName: listening ? "stop.fill" : "mic.fill")
                    .font(.system(size: listening ? 14 : 17, weight: .semibold))
                    .foregroundStyle(listening ? Color.white : Palette.indigo)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: listening)
    }

    // MARK: Actions

    private func micTapped() {
        switch phase {
        case .idle: listen()
        case .listening: finish()
        case .result:
            // Clear the last transcript, then listen for the next phrase.
            withAnimation(.easeOut(duration: 0.2)) { phase = .idle }
            shown = 0
            phraseIndex += 1
            listen()
        }
    }

    private func listen() {
        Haptics.tap(.light)
        startedAt = .now
        stoppedAt = .distantFuture
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .listening }
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(ctx["listen"]))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        guard phase == .listening, stoppedAt == .distantFuture else { return }
        stoppedAt = .now
        shown = 0
        task?.cancel()
        task = Task { @MainActor in
            // Let the bars collapse first.
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .result }
            let total = words.count
            for index in 0..<total {
                try? await Task.sleep(for: .seconds(ctx["stagger"]))
                guard !Task.isCancelled else { return }
                shown = index + 1
            }
            if !ctx.isPreview { Haptics.success() }
        }
    }
}

/// Scrolling bar waveform. Its envelope comes from the start/stop dates, so it needs no state of its own.
private struct InputVoiceWave: View {
    let bars: Int
    let startedAt: Date
    let stoppedAt: Date
    let live: Bool
    let isPreview: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: isPreview), paused: !live)) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let rise = min(max(now.timeIntervalSince(startedAt) / 0.35, 0), 1)
                let fall = 1 - min(max(now.timeIntervalSince(stoppedAt) / 0.25, 0), 1)
                let envelope = rise * rise * (3 - 2 * rise) * fall
                let time = now.timeIntervalSinceReferenceDate
                let count = max(bars, 2)
                let pitch = size.width / CGFloat(count)
                let barWidth = min(pitch * 0.5, 4)
                let gradient = Gradient(colors: [Palette.indigo, Palette.violet, Palette.pink])
                for index in 0..<count {
                    let phase = Double(index) * 0.55 + time * 7
                    let noise = sin(phase) * 0.45 + sin(phase * 0.43 + 1.7) * 0.35 + sin(phase * 2.3 + 0.4) * 0.2
                    let swell = 0.55 + 0.45 * sin(time * 2.1 + Double(index) * 0.12)
                    let level = envelope * min(0.14 + 1.25 * abs(noise) * swell, 1)
                    let height = 3 + CGFloat(level) * (size.height - 3)
                    let rect = CGRect(x: CGFloat(index) * pitch + (pitch - barWidth) / 2, y: (size.height - height) / 2, width: barWidth, height: height)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: 0))
                    )
                }
            }
        }
    }
}

/// Minimal wrapping layout for the transcript words.
private struct InputWordFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: widest, height: y + lineHeight), origins)
    }
}
