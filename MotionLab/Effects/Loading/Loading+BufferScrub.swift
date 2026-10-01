import SwiftUI

extension Effect {
    static let loadingBufferScrub = Effect(
        id: "loading.buffer-scrub",
        category: .loading,
        interaction: .gesture,
        name: L("Buffering Video Bar", "视频缓冲进度条"),
        summary: L("A player bar with separate buffered and played fills: the buffer jumps ahead in bursts, and when playback catches it the knob turns into a spinner.", "播放条上缓冲与已播放各有一层填充：缓冲一阵一阵向前跳，播放头追上它时，滑块变成转圈。"),
        prompt: L(
            "A video card with a 5 pt scrub bar: a grey track, a lighter buffered range and a red played fill ending in a 14 pt white knob. The network delivers data in uneven bursts about once a second; each burst springs the buffered range forward (response 0.45 s, damping 0.85) and the speed readout rolls. Playback advances linearly. When the knob catches the buffered edge it stalls: the knob grows to 22 pt on a spring (response 0.35 s, damping 0.7), a red arc spins inside it once every 0.7 s, the picture freezes and dims 30% under a 'Buffering' chip. Playback resumes only once 7% is buffered ahead. Dragging the bar scrubs with a time bubble; releasing outside the loaded range restarts the buffer from that point. Honest, familiar, never frozen-looking.",
            "视频卡片下方是一条 5 pt 高的进度条：灰色轨道、稍亮的已缓冲区间，以及末端带 14 pt 白色滑块的红色已播放填充。网络约每秒送来一阵大小不一的数据，缓冲区间随之以弹簧（响应 0.45 秒、阻尼 0.85）前跳，网速读数滚动；播放匀速推进。滑块追上缓冲边缘即卡顿：它以弹簧（响应 0.35 秒、阻尼 0.7）放大到 22 pt，内部红色圆弧每 0.7 秒转一圈，画面定格并压暗 30%，浮出“缓冲中”标签；前方缓冲满 7% 才恢复播放。拖动会带出时间气泡；松手处若超出已加载范围，缓冲从该点重来。诚实、熟悉。"
        ),
        implementation: L(
            "A small simulation ticks in a task: bursts move `buffered` inside withAnimation, the play head advances per tick and compares itself with the buffered edge, with hysteresis before resuming. The bar is three stacked capsules; the same scrub functions serve the drag gesture and the preview's simulated seek.",
            "一个小型模拟在 task 中逐帧推进：每一阵数据在 withAnimation 里推进 buffered，播放头每帧前进并与缓冲边缘比较，恢复播放带有回差。进度条是三层叠放的胶囊；拖动手势与预览中的模拟跳转调用同一组拖拽函数。"
        ),
        apis: ["task", "DragGesture", "withAnimation(.spring)", "Canvas", "contentTransition(.numericText)"],
        tags: ["video", "buffer", "scrubber", "stall", "视频", "缓冲", "进度条", "卡顿"],
        params: [
            .slider("burst", L("Burst size", "每阵数据量"), 0.06...0.35, default: 0.16),
            .slider("interval", L("Burst interval", "数据间隔"), 0.4...2.5, default: 1.0, decimals: 1, unit: "s"),
            .slider("length", L("Playback time", "播放时长"), 4...14, default: 6.5, decimals: 1, unit: "s"),
        ]
    ) { ctx in
        BufferScrubDemo(ctx: ctx)
    }
}

private struct BufferScrubDemo: View {
    let ctx: DemoContext
    @State private var played: Double
    @State private var bufferStart: Double = 0
    @State private var buffered: Double
    @State private var stalled = false
    @State private var scrubbing = false
    @State private var paused = false
    @State private var sinceBurst: Double = 0
    @State private var burstIndex = 0
    @State private var endedFor: Double = 0
    @State private var speed: Double = 2.4
    @State private var scrubTask: Task<Void, Never>?

    private let barWidth: CGFloat = 272
    /// Playback resumes once this much is buffered ahead.
    private let resumeGap: Double = 0.07
    /// Uneven burst sizes, as multiples of the `burst` parameter.
    private static let factors: [Double] = [1.5, 0.45, 1.3, 0.4, 1.7, 0.6, 1.1, 0.35]
    private static let videoSeconds: Double = 200

    init(ctx: DemoContext) {
        self.ctx = ctx
        _played = State(initialValue: ctx.isStill ? 0.42 : 0)
        _buffered = State(initialValue: ctx.isStill ? 0.7 : 0.1)
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                video
                bar
                controls
            }
            .padding(12)
            .frame(width: barWidth + 24)
            .demoCard(cornerRadius: 24)
            DemoHint(text: L("Drag the bar · tap the video to pause", "拖动进度条 · 点击画面暂停"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Restarted when a parameter changes, so the loop always reads the live values.
        .task(id: ctx.params) {
            guard !ctx.isStill else { return }
            let tick: Double = ctx.isPreview ? 1.0 / 30.0 : 1.0 / 60.0
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tick))
                let now = Date()
                step(min(now.timeIntervalSince(last), 0.1))
                last = now
            }
        }
        // Previews also show a seek past the loaded range.
        .autoplay(ctx.isPreview, every: 8, delay: 3.4, intro: false) { simulateScrub() }
        .onDisappear {
            scrubTask?.cancel()
            scrubTask = nil
        }
    }

    // MARK: Pieces

    private var video: some View {
        let zh = ctx.language == .zh
        return BufferScene(progress: played)
            .frame(width: barWidth, height: 150)
            .overlay(Color.black.opacity(stalled ? 0.3 : (paused ? 0.18 : 0)))
            .overlay {
                if stalled {
                    HStack(spacing: 7) {
                        BufferSpinner(color: .white, lineWidth: 2)
                            .frame(width: 13, height: 13)
                        Text(zh ? "缓冲中" : "Buffering")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(.black.opacity(0.5), in: Capsule())
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else if paused {
                    Image(systemName: "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { togglePause() }
    }

    private var bar: some View {
        let knob: CGFloat = stalled ? 22 : (scrubbing ? 20 : 14)
        let x: CGFloat = barWidth * CGFloat(played)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(width: barWidth, height: 5)
            Capsule()
                .fill(Color.primary.opacity(0.42))
                .frame(width: max(barWidth * CGFloat(buffered - bufferStart), 0), height: 5)
                .offset(x: barWidth * CGFloat(bufferStart))
            Capsule()
                .fill(LinearGradient(colors: [Palette.coral, Palette.red], startPoint: .leading, endPoint: .trailing))
                .frame(width: max(x, 0), height: 5)
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
                .overlay {
                    if stalled {
                        BufferSpinner(color: Palette.red, lineWidth: 2.4)
                            .padding(4.5)
                            .transition(.opacity)
                    } else {
                        Circle()
                            .fill(Palette.red)
                            .padding(scrubbing ? 5.5 : 4)
                            .transition(.opacity)
                    }
                }
                .frame(width: knob, height: knob)
                .offset(x: x - knob / 2)
            Text(timeString(played))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(.black.opacity(0.78), in: Capsule())
                .fixedSize()
                .scaleEffect(scrubbing ? 1 : 0.5, anchor: .bottom)
                .opacity(scrubbing ? 1 : 0)
                .frame(width: 60)
                .offset(x: (x - 30).clamped(to: -8...(barWidth - 52)), y: -28)
        }
        .frame(width: barWidth, height: 26, alignment: .leading)
        .contentShape(Rectangle().inset(by: -8))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !scrubbing { beginScrub() }
                    scrub(to: Double(value.location.x / barWidth))
                }
                .onEnded { _ in endScrub() }
        )
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Image(systemName: paused ? "play.fill" : "pause.fill")
                .font(.system(size: 14, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 20)
            Text("\(timeString(played)) / \(timeString(1))")
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .heavy))
                Text(String(format: "%.1f MB/s", buffered >= 1 ? 0 : speed))
                    .contentTransition(.numericText(value: speed))
            }
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(buffered >= 1 ? Color.secondary : Palette.green)
            Text("HD")
                .font(.system(size: 10, weight: .heavy))
                .padding(.horizontal, 5)
                .frame(height: 17)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.45), lineWidth: 1))
        }
        .frame(width: barWidth)
    }

    private func timeString(_ fraction: Double) -> String {
        let seconds: Int = Int((fraction.clamped(to: 0...1) * BufferScrubDemo.videoSeconds).rounded(.down))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Simulation

    private func step(_ dt: Double) {
        guard !scrubbing else { return }
        if buffered < 1 {
            sinceBurst += dt
            if sinceBurst >= max(ctx["interval"], 0.1) {
                sinceBurst = 0
                let factor: Double = BufferScrubDemo.factors[burstIndex % BufferScrubDemo.factors.count]
                burstIndex += 1
                let next: Double = min(buffered + ctx["burst"] * factor, 1)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    buffered = next
                    speed = (ctx["burst"] * factor * 15 * 10).rounded() / 10
                }
            }
        }
        guard !paused else { return }
        if played >= 1 {
            endedFor += dt
            if endedFor > 1.3 { restart() }
            return
        }
        if stalled {
            if buffered - played >= resumeGap || buffered >= 1 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { stalled = false }
            }
            return
        }
        let next: Double = played + dt / max(ctx["length"], 1)
        if next >= buffered, buffered < 1 {
            played = buffered
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { stalled = true }
        } else {
            played = min(next, 1)
        }
    }

    private func restart() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            played = 0
            bufferStart = 0
            buffered = 0.1
            stalled = false
        }
        sinceBurst = 0
        burstIndex = 0
        endedFor = 0
    }

    private func togglePause() {
        Haptics.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { paused.toggle() }
    }

    // MARK: Scrubbing (the drag gesture and the preview's simulated seek share these)

    private func beginScrub() {
        Haptics.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
            scrubbing = true
            stalled = false
        }
    }

    private func scrub(to fraction: Double) {
        played = fraction.clamped(to: 0...1)
    }

    private func endScrub() {
        endedFor = 0
        let outside: Bool = played < bufferStart || played > buffered
        if outside {
            // A new range request: the buffer starts over from the play head.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                bufferStart = played
                buffered = played
            }
            sinceBurst = max(ctx["interval"], 0.1) * 0.55
        }
        let starving: Bool = outside || (buffered - played < resumeGap && buffered < 1)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            scrubbing = false
            stalled = starving && played < 1
        }
    }

    private func simulateScrub() {
        guard !scrubbing, played < 0.62 else { return }
        beginScrub()
        let target: Double = min(played + 0.3, 0.9)
        withAnimation(.easeInOut(duration: 0.55)) { scrub(to: target) }
        scrubTask?.cancel()
        scrubTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            endScrub()
        }
    }
}

/// An arc that spins for as long as it is on screen.
private struct BufferSpinner: View {
    let color: Color
    let lineWidth: CGFloat
    @State private var turning = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.78)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(turning ? 360 : 0))
            .animation(.linear(duration: 0.7).repeatForever(autoreverses: false), value: turning)
            .onAppear { turning = true }
    }
}

/// The "video": a day passing over two ridges. It only moves when the play head does.
private struct BufferScene: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let p: Double = min(max(progress, 0), 1)
            let dusk: Double = pow(p, 1.6)
            let top: Color = Color(hex: 0x3C5BD8).mix(with: Color(hex: 0x2B1E66), by: dusk)
            let bottom: Color = Color(hex: 0x9AD8FF).mix(with: Color(hex: 0xFF8A5C), by: dusk)
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(Gradient(colors: [top, bottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )

            // The sun crosses the sky on an arc.
            let sun = CGPoint(x: 28 + (size.width - 56) * CGFloat(p), y: size.height * 0.78 - size.height * 0.56 * CGFloat(sin(.pi * (0.12 + 0.76 * p))))
            let halo = CGRect(x: sun.x - 46, y: sun.y - 46, width: 92, height: 92)
            context.fill(
                Path(ellipseIn: halo),
                with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF3C4).opacity(0.7), Color(hex: 0xFFF3C4).opacity(0)]), center: sun, startRadius: 8, endRadius: 46)
            )
            context.fill(Path(ellipseIn: CGRect(x: sun.x - 13, y: sun.y - 13, width: 26, height: 26)), with: .color(Color(hex: 0xFFF6D6)))

            // Clouds drift the other way.
            for index in 0..<3 {
                let x: CGFloat = size.width * (0.2 + 0.36 * CGFloat(index)) - 60 * CGFloat(p)
                let y: CGFloat = 26 + 16 * CGFloat(index % 2)
                let cloud = CGRect(x: x, y: y, width: 54, height: 13)
                context.fill(Path(roundedRect: cloud, cornerRadius: 6.5), with: .color(.white.opacity(0.42)))
                context.fill(Path(roundedRect: cloud.offsetBy(dx: 14, dy: -7).insetBy(dx: 10, dy: 0), cornerRadius: 6.5), with: .color(.white.opacity(0.42)))
            }

            // Two ridges with parallax.
            BufferScene.ridge(&context, size: size, base: 0.58, amplitude: 22, wavelength: 150, shift: 40 * CGFloat(p), color: Color(hex: 0x2E3C8C).opacity(0.75))
            BufferScene.ridge(&context, size: size, base: 0.74, amplitude: 16, wavelength: 96, shift: 110 * CGFloat(p), color: Color(hex: 0x161A45))
        }
    }

    private static func ridge(_ context: inout GraphicsContext, size: CGSize, base: CGFloat, amplitude: CGFloat, wavelength: CGFloat, shift: CGFloat, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = 0
        while x <= size.width + 6 {
            let a: CGFloat = (x + shift) / wavelength * 2 * .pi
            let y: CGFloat = size.height * base - amplitude * (sin(a) * 0.65 + sin(a * 2.3 + 1) * 0.35)
            path.addLine(to: CGPoint(x: x, y: y))
            x += 6
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }
}
