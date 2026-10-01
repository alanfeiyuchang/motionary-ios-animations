import SwiftUI

extension Effect {
    static let iconsLiveWaveform = Effect(
        id: "icons.live-waveform",
        category: .icons,
        interaction: .loop,
        name: L("Live Waveform", "实时波形"),
        summary: L("Equalizer bars dance with organic noise under falling peak caps, and drop into one flat line when paused.", "均衡器柱条随有机噪声起伏，顶上是缓缓下落的峰值帽；暂停时整体落成一条平线。"),
        prompt: L(
            "A compact equalizer glyph: five rounded 14 pt bars on a shared baseline, filled with a mint-to-blue gradient. Each bar's height follows its own blend of three sine waves at unrelated rates, sharpened so peaks stand out, with the centre bars loudest, so the motion looks like music rather than a loop. A thin cap floats above every bar: it is pushed up by peaks, hangs for a moment and falls back at a steady rate. On tap the bars drop to dots on a spring (response 0.4 s, damping 0.5), centre first and 40 ms later per step outward, each dot hopping once as it lands; the dots then flatten to 6 pt and a line springs out to join them into one flat grey stroke. Tapping again splits the line and the bars spring back up. Lively, then perfectly calm.",
            "紧凑的均衡器图标：五根14 pt宽的圆角柱条立在同一基线上，填充蓝到薄荷色的渐变。每根柱条的高度由三条频率互不相关的正弦波混合并锐化而成，中间的柱条最响，看起来像音乐而非循环动画。每根上方浮着一片薄薄的峰值帽：被峰值顶起，停留片刻，再匀速落回。点击后柱条以弹簧（响应0.4秒、阻尼0.5）落成圆点，从中间开始、每向外一格晚40毫秒，圆点落地时轻跳一下；随后圆点压扁到6 pt，一条线弹出把它们连成灰色平线。再次点击，平线裂开，柱条重新弹起。先灵动，后安静。"
        ),
        implementation: L(
            "A TimelineView evaluates a layered-sine level per bar from a rate-continuous phase clock; the peak caps are a stateless maximum over recent samples minus a linear fall. Pause and resume multiply the levels by staggered analytic springs.",
            "TimelineView 用速率连续的相位时钟为每根柱条计算多层正弦电平；峰值帽是对近期采样取最大值再减去线性下落量的无状态算法。暂停与恢复则用错开的解析弹簧去乘电平。"
        ),
        apis: ["TimelineView(.animation)", "Capsule", "LinearGradient", "contentTransition(.symbolEffect(.replace))"],
        tags: ["waveform", "equalizer", "audio", "now playing", "music", "bars", "波形", "均衡器", "音频", "正在播放", "音乐"],
        params: [
            .slider("bars", L("Bars", "柱条数量"), 3...9, default: 5, step: 1, decimals: 0),
            .slider("tempo", L("Tempo", "速度"), 0.4...2.5, default: 1.0, unit: "×"),
            .slider("energy", L("Energy", "能量"), 0.3...1.0, default: 0.85),
            .toggle("caps", L("Peak caps", "峰值帽"), default: true),
        ]
    ) { ctx in
        IconsLiveWaveformDemo(ctx: ctx)
    }
}

private struct IconsLiveWaveformDemo: View {
    let ctx: DemoContext
    /// On = paused.
    @State private var play = IconsPlayhead(isOn: false)
    @State private var phaseClock = IconsPhaseClock()
    @State private var resumeTask: Task<Void, Never>?

    private static let pauseDuration: Double = 0.95
    private static let resumeDuration: Double = 0.8

    var body: some View {
        VStack(spacing: 14) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsWaveformScene(
                    paused: play.isOn,
                    t: play.elapsed(at: date),
                    phase: ctx.isStill ? 3.1 : phaseClock.phase(at: date, rate: ctx["tempo"]),
                    bars: ctx.int("bars"),
                    energy: ctx["energy"],
                    caps: ctx.bool("caps")
                )
            }
            .frame(width: 250, height: 170)
            nowPlaying
            DemoHint(text: L("Tap to pause or play", "点击暂停或播放"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { tap() }
        .onChange(of: ctx["tempo"]) { old, _ in
            phaseClock.rebase(oldRate: old)
        }
        .autoplay(ctx.isPreview, every: 4.2, delay: 1.6) { blip() }
        .onDisappear { resumeTask?.cancel() }
    }

    private var nowPlaying: some View {
        HStack(spacing: 8) {
            Image(systemName: play.isOn ? "play.fill" : "pause.fill")
                .font(.system(size: 13, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 16)
            Text(play.isOn ? L("Paused", "已暂停") : L("Now playing", "正在播放"), ctx.language)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.opacity)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .animation(.snappy(duration: 0.3), value: play.isOn)
    }

    private func tap() {
        resumeTask?.cancel()
        toggle()
    }

    private func toggle() {
        play.toggle(onDuration: Self.pauseDuration, offDuration: Self.resumeDuration)
        Haptics.tap(play.isOn ? .rigid : .light)
    }

    /// Autoplay and the detail intro: pause, hold the flat line for a beat, then resume.
    private func blip() {
        guard !play.isOn else { return }
        toggle()
        resumeTask?.cancel()
        resumeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, play.isOn else { return }
            play.toggle(onDuration: Self.pauseDuration, offDuration: Self.resumeDuration)
        }
    }
}

private struct IconsWaveformScene: View {
    let paused: Bool
    let t: Double
    let phase: Double
    let bars: Int
    let energy: Double
    let caps: Bool

    private static let barWidth: CGFloat = 14
    private static let maxHeight: CGFloat = 132
    private static let lineHeight: CGFloat = 6

    private var count: Int { max(bars, 1) }
    private var gap: CGFloat { count > 7 ? 8 : 10 }
    private var totalWidth: CGFloat { CGFloat(count) * Self.barWidth + CGFloat(count - 1) * gap }

    // MARK: Signal

    /// Level 0…1 of bar `index` at `phase`: three unrelated sines, sharpened, loudest in the middle.
    private func level(_ index: Int, at phase: Double) -> Double {
        let s: Double = Double(index)
        let p: Double = phase * 2.4
        let a: Double = sin(p * (2.1 + 0.37 * s) + s * 1.7)
        let b: Double = sin(p * (3.3 - 0.21 * s) + s * 0.9)
        let c: Double = sin(p * 5.9 + s * 2.3)
        let raw: Double = IconsCurve.unit(0.5 + 0.28 * a + 0.17 * b + 0.08 * c)
        let middle: Double = Double(count - 1) / 2
        let edge: Double = middle > 0 ? abs(s - middle) / middle : 0
        return pow(raw, 1.4) * (1 - 0.28 * edge) * energy
    }

    /// The peak-hold cap: the highest recent level, minus a steady fall since it happened.
    private func peak(_ index: Int) -> Double {
        var best: Double = 0
        for sample in 0..<26 {
            let back: Double = Double(sample) * 0.05
            let held: Double = max(back - 0.2, 0)
            best = max(best, level(index, at: phase - back) - held * 0.55)
        }
        return best
    }

    // MARK: Motion

    private func delay(_ index: Int) -> Double {
        abs(Double(index) - Double(count - 1) / 2) * 0.04
    }

    /// 1 = playing, 0 = dropped to a dot; goes below 0 for a moment as the dot hops.
    private func liveness(_ index: Int) -> Double {
        if paused {
            return 1 - IconsCurve.spring(t - delay(index), response: 0.4, damping: 0.5)
        }
        return IconsCurve.spring(t - 0.12 - delay(index), response: 0.38, damping: 0.55)
    }

    /// 0 = dots, 1 = one flat line.
    private var flat: Double {
        if paused { return IconsCurve.spring(t - 0.42, response: 0.4, damping: 0.62) }
        return 1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.16))
    }

    var body: some View {
        let flat: Double = self.flat
        let calm: Double = IconsCurve.unit(flat)
        let grey: Double = paused ? IconsCurve.seg(t, 0.1, 0.5) : 1 - IconsCurve.seg(t, 0, 0.25)
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(0..<count, id: \.self) { index in
                    bar(index, calm: calm)
                }
            }
            Capsule()
                .frame(width: max(totalWidth * CGFloat(flat), 0.01), height: Self.lineHeight)
                .opacity(calm > 0.01 ? 1 : 0)
        }
        .foregroundStyle(LinearGradient(colors: [Palette.blue, Palette.sky, Palette.mint], startPoint: .bottom, endPoint: .top))
        .frame(height: Self.maxHeight + 14, alignment: .bottom)
        .overlay(alignment: .bottom) {
            // The settled line turns neutral grey.
            Capsule()
                .fill(Color(hex: 0x8E8E99))
                .frame(width: max(totalWidth * CGFloat(flat), 0.01), height: Self.lineHeight)
                .opacity(calm > 0.01 ? grey : 0)
        }
        .shadow(color: Palette.sky.opacity(0.35 * (1 - grey)), radius: 12, y: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bar(_ index: Int, calm: Double) -> some View {
        let live: Double = liveness(index)
        let width: CGFloat = Self.barWidth
        let rest: CGFloat = width + (Self.lineHeight - width) * CGFloat(calm)
        let reach: CGFloat = Self.maxHeight - width
        let height: CGFloat = rest + reach * CGFloat(level(index, at: phase) * max(live, 0))
        let hop: CGFloat = 22 * CGFloat(max(-live, 0))
        let capY: CGFloat = max(rest + reach * CGFloat(peak(index) * max(live, 0)), height) + 5
        let capOpacity: Double = caps ? IconsCurve.unit(live * 3) : 0
        return Capsule()
            .frame(width: width, height: height)
            .offset(y: -hop)
            .overlay(alignment: .bottom) {
                Capsule()
                    .frame(width: width, height: 4)
                    .opacity(0.85 * capOpacity)
                    .offset(y: -capY)
            }
    }
}
