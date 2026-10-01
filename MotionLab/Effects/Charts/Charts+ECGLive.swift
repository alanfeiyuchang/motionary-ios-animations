import SwiftUI

extension Effect {
    static let chartsECGLive = Effect(
        id: "charts.ecg-live",
        category: .charts,
        interaction: .loop,
        name: L("Live ECG Trace", "实时心电波形"),
        summary: L("A monitor-style sweep: a glowing head writes each heartbeat, the tail fades behind it and the BPM pulses on every beat.", "监护仪式扫描：发光的笔头写下每一次心跳，尾迹在身后渐隐，BPM 随每一拍搏动。"),
        prompt: L(
            "A heart-rate card with a monitor trace on a faint grid. A bright head sweeps left to right across the plot every 3.2 s and wraps, writing a PQRST waveform (small P bump, sharp R spike, shallow S dip, rounded T) as a 2 pt pink line. Behind the head the line fades linearly to nothing over 80% of a sweep, so the old trace is erased just ahead of the new one; the newest stretch carries a blurred glow and the head is a white-cored dot with a halo. At each R spike the heart glyph kicks to 118% and the BPM numeral to 105%, both decaying exponentially (time constant 0.18 s). Tapping adds 45 BPM of exertion: the beats crowd together, then relax back over a few seconds. Clinical, alive and rhythmic.",
            "心率卡片：浅网格上的监护仪波形。明亮的笔头每 3.2 秒自左向右扫过图表并回卷，以 2pt 粉色线条写出 PQRST 波形（小 P 波、尖锐的 R 峰、浅 S 谷、圆润的 T 波）。笔头身后的线条在 80% 的扫描长度内线性淡出至消失，旧波形恰好在新波形到来前被擦去；最新的一段带模糊辉光，笔头是带光晕的白芯圆点。每到 R 峰，心形图标跳到 118%、BPM 数字跳到 105%，随后按指数衰减（时间常数 0.18 秒）。点击会增加 45 BPM 的「运动」负荷：心跳变密，再在几秒内缓缓回落。专业、鲜活而有节律。"
        ),
        implementation: L(
            "A TimelineView advances a small model that integrates beat phase (so rate changes stay continuous) and writes samples with timestamps into a ring buffer; a Canvas strokes the buffer in opacity bands by sample age, adds a blurred pass for the newest part and derives the pulse from the time since the last R peak.",
            "TimelineView 推进一个小模型：对心拍相位积分（心率变化时保持连续），并把带时间戳的采样写入环形缓冲；Canvas 按采样年龄分透明度档描线，为最新一段叠加模糊辉光，搏动量由距上一个 R 峰的时间算出。"
        ),
        apis: ["TimelineView", "Canvas", "GraphicsContext.addFilter", "exp", "scaleEffect"],
        tags: ["ecg", "heartbeat", "live trace", "monitor", "心电图", "心跳", "实时波形", "监护仪"],
        params: [
            .slider("bpm", L("Resting BPM", "静息心率"), 48...150, default: 72, step: 1, decimals: 0),
            .slider("trail", L("Trail length", "尾迹长度"), 0.3...0.95, default: 0.8),
            .toggle("glow", L("Glow", "辉光"), default: true),
            .toggle("grid", L("Grid", "网格"), default: true),
        ]
    ) { ctx in
        ECGLiveDemo(ctx: ctx)
    }
}

private final class ECGModel {
    static let samples = 240
    static let sweep = 3.2

    var levels = [Double](repeating: 0, count: samples)
    var stamps = [Double](repeating: -100, count: samples)
    var clock = 0.0
    var phase = 0.0
    var bpm = 72.0
    var boost = 0.0
    var lastBeat = -10.0
    var head = 0.0
    private var lastDate: Date?

    /// One heartbeat, `x` in 0…1: baseline 0, R peak 1.
    static func wave(_ x: Double) -> Double {
        func bump(_ center: Double, _ width: Double, _ amp: Double) -> Double {
            amp * exp(-pow((x - center) / width, 2))
        }
        return bump(0.14, 0.035, 0.12) + bump(0.272, 0.011, -0.13) + bump(0.3, 0.013, 1) + bump(0.334, 0.013, -0.24) + bump(0.56, 0.06, 0.28)
    }

    func advance(to date: Date, resting: Double) {
        guard let last = lastDate else {
            lastDate = date
            return
        }
        lastDate = date
        var elapsed = date.timeIntervalSince(last)
        if elapsed > 0.25 { elapsed = 1.0 / 60 }
        guard elapsed > 0 else { return }
        run(elapsed, resting: resting)
    }

    /// Fills the buffer as if the monitor had already been running.
    func prefill(_ seconds: Double, resting: Double) {
        run(seconds, resting: resting)
    }

    private func run(_ seconds: Double, resting: Double) {
        let perSample = Self.sweep / Double(Self.samples)
        var remaining = seconds
        while remaining > 0 {
            let step = min(remaining, perSample)
            remaining -= step
            clock += step
            boost *= exp(-step / 2.4)
            bpm = resting + boost
            let before = phase
            phase += step * bpm / 60
            if (phase - 0.3).rounded(.down) > (before - 0.3).rounded(.down) { lastBeat = clock }
            head += step / perSample
            if head >= Double(Self.samples) { head -= Double(Self.samples) }
            let index = min(Int(head), Self.samples - 1)
            levels[index] = Self.wave(phase - phase.rounded(.down))
            stamps[index] = clock
        }
    }
}

private struct ECGLiveDemo: View {
    let ctx: DemoContext
    @State private var model: ECGModel

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = ECGModel()
        // A still shows a trace most of the way across; live demos start with a little history too.
        model.prefill(ctx.isStill ? 2.6 : 1.2, resting: ctx["bpm"])
        _model = State(initialValue: model)
    }

    var body: some View {
        let resting = ctx["bpm"]
        let trail = ctx["trail"]
        let glow = ctx.bool("glow")
        let grid = ctx.bool("grid")
        ChartStage(hint: L("Tap to raise the heart rate", "点击让心率加快"), ctx: ctx) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                let _ = ctx.isStill ? () : model.advance(to: timeline.date, resting: resting)
                // The model is a reference, so the Canvas gets the clock as a value: without a changing
                // input SwiftUI treats the Canvas as unchanged and never redraws the trace.
                let now = model.clock
                let pulse = exp(-max(now - model.lastBeat, 0) / 0.18)
                VStack(alignment: .leading, spacing: 12) {
                    header(pulse: pulse)
                    Canvas { context, size in
                        ECGLiveDemo.draw(model, now: now, in: context, size: size, trail: trail, glow: glow, grid: grid)
                    }
                    .frame(height: 138)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { exert() }
        }
        .autoplay(ctx.isPreview, every: 4.5, delay: 1.2) { exert() }
    }

    private func header(pulse: Double) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Palette.pink.opacity(0.14 + 0.18 * pulse))
                    .frame(width: 40, height: 40)
                    .scaleEffect(1 + 0.2 * pulse)
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Palette.pink, Palette.red], startPoint: .top, endPoint: .bottom))
                    .scaleEffect(1 + 0.18 * pulse)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text(ctx.language == .zh ? "心率" : "Heart rate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: "\(Int(model.bpm.rounded()))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .fixedSize()
                        .scaleEffect(1 + 0.05 * pulse, anchor: .bottomLeading)
                    Text(verbatim: "BPM")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.pink)
                }
            }
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(Palette.red)
                    .frame(width: 6, height: 6)
                    .opacity(0.35 + 0.65 * pulse)
                Text(verbatim: "LIVE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    /// Tap and autoplay: a burst of exertion that decays back to the resting rate.
    private func exert() {
        Haptics.tap(.medium)
        model.boost = min(model.boost + 45, 80)
    }

    private static func draw(_ model: ECGModel, now: Double, in context: GraphicsContext, size: CGSize, trail: Double, glow: Bool, grid: Bool) {
        if grid {
            var lines = Path()
            let cell: CGFloat = 23
            var x = cell
            while x < size.width {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
                x += cell
            }
            var y = cell
            while y < size.height {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
                y += cell
            }
            context.stroke(lines, with: .color(Palette.pink.opacity(0.13)), lineWidth: 0.5)
        }

        let count = ECGModel.samples
        let window = ECGModel.sweep * trail
        let baseline = size.height * 0.68
        let amplitude = size.height * 0.5
        func point(_ index: Int) -> CGPoint {
            CGPoint(x: size.width * CGFloat(index) / CGFloat(count - 1), y: baseline - CGFloat(model.levels[index]) * amplitude)
        }

        let bands = 10
        var paths = [Path](repeating: Path(), count: bands)
        var fresh = Path()
        for index in 0..<(count - 1) {
            let newer = max(model.stamps[index], model.stamps[index + 1])
            let older = min(model.stamps[index], model.stamps[index + 1])
            // Skip the seam where the head meets the oldest samples.
            guard newer - older < 0.1 else { continue }
            let age = now - newer
            let alpha = 1 - age / window
            guard alpha > 0.02 else { continue }
            let band = min(Int(alpha * Double(bands)), bands - 1)
            paths[band].move(to: point(index))
            paths[band].addLine(to: point(index + 1))
            if age < 0.55 {
                fresh.move(to: point(index))
                fresh.addLine(to: point(index + 1))
            }
        }

        if glow {
            var halo = context
            halo.addFilter(.blur(radius: 5))
            halo.stroke(fresh, with: .color(Palette.pink.opacity(0.85)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        for band in 0..<bands {
            let alpha = (Double(band) + 0.5) / Double(bands)
            context.stroke(paths[band], with: .color(Palette.pink.opacity(alpha)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }

        let headIndex = min(Int(model.head), count - 1)
        let tip = point(headIndex)
        if glow {
            let halo: CGFloat = 11
            context.fill(
                Path(ellipseIn: CGRect(x: tip.x - halo, y: tip.y - halo, width: halo * 2, height: halo * 2)),
                with: .radialGradient(Gradient(colors: [Palette.pink.opacity(0.55), Palette.pink.opacity(0)]), center: tip, startRadius: 0, endRadius: halo)
            )
        }
        context.fill(Path(ellipseIn: CGRect(x: tip.x - 4, y: tip.y - 4, width: 8, height: 8)), with: .color(Palette.pink))
        context.fill(Path(ellipseIn: CGRect(x: tip.x - 2, y: tip.y - 2, width: 4, height: 4)), with: .color(.white))
    }
}
