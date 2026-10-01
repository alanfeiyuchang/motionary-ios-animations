import SwiftUI

extension Effect {
    static let loadingHalfGauge = Effect(
        id: "loading.half-gauge",
        category: .loading,
        interaction: .tap,
        name: L("Boot-Sweep Gauge", "自检扫表仪表盘"),
        summary: L("A half-circle gauge that sweeps its needle to the stop like a car dashboard, then drops onto the reading and wobbles to rest.", "半圆仪表像汽车仪表盘那样先把指针扫到尽头，再落到读数上，晃几下才停稳。"),
        prompt: L(
            "A 220 pt half-circle speed gauge: a 14 pt track, 31 tick marks inside it, a tapered needle on a hub and a large rolling number below. On tap it boots like a dashboard. The needle sweeps from zero to the end stop in 0.8 s on an ease-in-out curve, the mint → amber → coral arc filling behind it and each tick lighting as it passes. It then drops onto the measured value on an under-damped spring (response 0.6 s, damping 0.42): it overshoots the reading by a few degrees, swings back and settles after two or three visible wobbles, with the arc, the lit ticks, the glowing tip and the number all wobbling with it. A medium haptic lands at the top of the sweep and a light one as it settles. Mechanical, confident, alive.",
            "一个 220 pt 的半圆测速仪表：14 pt 粗的轨道，内侧 31 条刻度，带轴心的锥形指针，下方是滚动的大号数字。点击后它像汽车仪表盘那样开机自检：指针用 0.8 秒、缓入缓出地从零扫到尽头，薄荷绿 → 琥珀 → 珊瑚色的圆弧跟在后面填满，刻度随指针经过逐一点亮。随后指针以欠阻尼弹簧（响应 0.6 秒、阻尼 0.42）落向测得的数值：先冲过读数几度，再荡回来，晃两三下才停稳；圆弧、亮起的刻度、发光的针尖和数字全都跟着一起晃。扫到顶端时有一下中等力度的触感，停稳时再来一下轻触感。机械感、笃定、鲜活。"
        ),
        implementation: L(
            "One Double drives everything. An Animatable view redraws a Canvas (track, conic-gradient arc, ticks, needle) for every interpolated value, so the spring's overshoot shows in all of them; the boot is an ease-in-out to 1 followed by a spring to the target.",
            "一个 Double 驱动全部。Animatable 视图针对每个插值重绘 Canvas（轨道、锥形渐变圆弧、刻度、指针），于是弹簧的过冲同时体现在所有元素上；开机自检是先缓入缓出到 1，再用弹簧落到目标值。"
        ),
        apis: ["Animatable", "Canvas", "withAnimation(.spring)", "GraphicsContext.Shading.conicGradient", "Task.sleep(for:)"],
        tags: ["gauge", "speedometer", "needle", "dashboard", "仪表盘", "测速", "指针", "半圆"],
        params: [
            .slider("damping", L("Needle damping", "指针阻尼"), 0.2...1, default: 0.42),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1.2, default: 0.6, unit: "s"),
            .slider("sweep", L("Boot sweep", "自检扫动"), 0.4...1.6, default: 0.8, decimals: 1, unit: "s"),
            .toggle("ticks", L("Tick marks", "刻度"), default: true),
        ]
    ) { ctx in
        HalfGaugeDemo(ctx: ctx)
    }
}

private struct HalfGaugeDemo: View {
    let ctx: DemoContext
    @State private var value: Double
    @State private var reading = 0
    @State private var booting = false
    @State private var task: Task<Void, Never>?

    private static let readings: [Double] = [0.72, 0.38, 0.86, 0.55, 0.24]
    private static let maximum: Double = 300

    init(ctx: DemoContext) {
        self.ctx = ctx
        _value = State(initialValue: ctx.isStill ? HalfGaugeDemo.readings[0] : 0)
    }

    var body: some View {
        let zh = ctx.language == .zh
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                GaugeFace(value: value, ticks: ctx.bool("ticks"))
                    .frame(width: 250, height: 150)
                VStack(spacing: 0) {
                    GaugeNumber(value: value, maximum: HalfGaugeDemo.maximum)
                    Text("Mbps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .offset(y: 62)
            }
            .padding(.bottom, 58)
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Palette.mint)
                Text(booting ? (zh ? "正在测速…" : "Testing…") : (zh ? "下载速度" : "Download"))
                    .contentTransition(.opacity)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            DemoHint(text: L("Tap to run the test again", "点击重新测速"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { boot() }
        .autoplay(ctx.isPreview, every: 3.6, delay: 0.4) { boot() }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    /// The boot sequence: a full sweep to the end stop, then a springy drop onto the next reading.
    private func boot() {
        if !ctx.isPreview { Haptics.tap() }
        let sweep: Double = max(ctx["sweep"], 0.1)
        let response: Double = ctx["response"]
        let damping: Double = ctx["damping"]
        let target: Double = HalfGaugeDemo.readings[reading % HalfGaugeDemo.readings.count]
        reading += 1
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        task?.cancel()
        withAnimation(.smooth(duration: 0.25)) { booting = true }
        // From wherever the needle is, back to zero first if it is not already there.
        let rewind: Double = value > 0.02 ? 0.3 : 0
        if rewind > 0 {
            withAnimation(.easeIn(duration: rewind)) { value = 0 }
        }
        task = Task { @MainActor in
            if rewind > 0 { try? await Task.sleep(for: .seconds(rewind)) }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: sweep)) { value = 1 }
            try? await Task.sleep(for: .seconds(sweep))
            guard !Task.isCancelled else { return }
            if buzz { Haptics.tap(.medium) }
            try? await Task.sleep(for: .seconds(0.06))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: response, dampingFraction: damping)) { value = target }
            try? await Task.sleep(for: .seconds(response * 1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.25)) { booting = false }
            if buzz { Haptics.tap(.light) }
        }
    }
}

private struct GaugeNumber: View, Animatable {
    var value: Double
    let maximum: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int((min(max(value, 0), 1.05) * maximum).rounded()))")
            .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
    }
}

private struct GaugeFace: View, Animatable {
    var value: Double
    let ticks: Bool

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    private static let needleColor = Color.adaptive(light: 0x2A2A33, dark: 0xF2F2F7)
    private static let tickCount: Int = 31

    var body: some View {
        Canvas { context, size in
            // The needle may swing a little past either end stop.
            let v: Double = min(max(value, -0.03), 1.05)
            let centre = CGPoint(x: size.width / 2, y: size.height - 26)
            let radius: CGFloat = 110
            let width: CGFloat = 14
            let trackRadius: CGFloat = radius - width / 2

            // Angles run from 180° (zero, left) over the top to 360° (maximum, right).
            func angle(_ fraction: Double) -> Angle { .degrees(180 + 180 * fraction) }
            func point(_ fraction: Double, _ r: CGFloat) -> CGPoint {
                let a: Double = angle(fraction).radians
                return CGPoint(x: centre.x + r * CGFloat(cos(a)), y: centre.y + r * CGFloat(sin(a)))
            }

            var track = Path()
            track.addArc(center: centre, radius: trackRadius, startAngle: angle(0), endAngle: angle(1), clockwise: false)
            context.stroke(track, with: .color(Color.primary.opacity(0.1)), style: StrokeStyle(lineWidth: width, lineCap: .round))

            let filled: Double = min(max(v, 0), 1)
            if filled > 0.004 {
                var arc = Path()
                arc.addArc(center: centre, radius: trackRadius, startAngle: angle(0), endAngle: angle(filled), clockwise: false)
                let gradient = Gradient(stops: [
                    .init(color: Palette.mint, location: 0),
                    .init(color: Palette.amber, location: 0.3),
                    .init(color: Palette.coral, location: 0.5),
                    .init(color: Palette.mint, location: 0.97),
                    .init(color: Palette.mint, location: 1),
                ])
                context.stroke(
                    arc,
                    with: .conicGradient(gradient, center: centre, angle: .degrees(180)),
                    style: StrokeStyle(lineWidth: width, lineCap: .round)
                )
            }

            if ticks {
                let last: Int = GaugeFace.tickCount - 1
                for index in 0...last {
                    let fraction: Double = Double(index) / Double(last)
                    let major: Bool = index % 5 == 0
                    let lit: Bool = fraction <= filled + 0.001
                    var tick = Path()
                    tick.move(to: point(fraction, radius - width - 7))
                    tick.addLine(to: point(fraction, radius - width - (major ? 18 : 13)))
                    context.stroke(
                        tick,
                        with: .color(Color.primary.opacity(lit ? (major ? 0.8 : 0.5) : (major ? 0.22 : 0.12))),
                        style: StrokeStyle(lineWidth: major ? 2 : 1.3, lineCap: .round)
                    )
                }
            }

            // A glowing bead where the needle meets the arc.
            let tip = point(v, trackRadius)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                layer.fill(Path(ellipseIn: CGRect(x: tip.x - 9, y: tip.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.75)))
            }
            context.fill(Path(ellipseIn: CGRect(x: tip.x - 4.5, y: tip.y - 4.5, width: 9, height: 9)), with: .color(.white))

            // The needle: a taper from the hub to just short of the ticks, with a short counterweight.
            let a: Double = angle(v).radians
            let direction = CGPoint(x: CGFloat(cos(a)), y: CGFloat(sin(a)))
            let normal = CGPoint(x: -direction.y, y: direction.x)
            let reach: CGFloat = radius - width - 24
            var needle = Path()
            needle.move(to: CGPoint(x: centre.x + direction.x * reach, y: centre.y + direction.y * reach))
            needle.addLine(to: CGPoint(x: centre.x + normal.x * 4.5, y: centre.y + normal.y * 4.5))
            needle.addLine(to: CGPoint(x: centre.x - direction.x * 16 + normal.x * 2.5, y: centre.y - direction.y * 16 + normal.y * 2.5))
            needle.addLine(to: CGPoint(x: centre.x - direction.x * 16 - normal.x * 2.5, y: centre.y - direction.y * 16 - normal.y * 2.5))
            needle.addLine(to: CGPoint(x: centre.x - normal.x * 4.5, y: centre.y - normal.y * 4.5))
            needle.closeSubpath()
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.25), radius: 4, y: 3))
                layer.fill(needle, with: .color(GaugeFace.needleColor))
            }
            context.fill(Path(ellipseIn: CGRect(x: centre.x - 9, y: centre.y - 9, width: 18, height: 18)), with: .color(GaugeFace.needleColor))
            context.fill(Path(ellipseIn: CGRect(x: centre.x - 3.5, y: centre.y - 3.5, width: 7, height: 7)), with: .color(Palette.coral))
        }
    }
}
