import SwiftUI

extension Effect {
    static let textGlitchIn = Effect(
        id: "text.glitch-in",
        category: .text,
        interaction: .tap,
        name: L("Glitch In", "故障入场"),
        summary: L("A headline arrives as torn, colour-split slices that snap into register one by one.", "标题以撕裂、色彩分离的横条出现，再一条条对齐锁定。"),
        prompt: L(
            "A heavy two-line headline is built from three colour channels drawn on top of each other, cut into nine horizontal slices of uneven height. For 1.1 s the signal is unstable: every slice jumps sideways to a new random offset 24 times a second, up to 46 pt at first and shrinking as its lock time approaches, flickers in and out, and its channels separate by up to 10 pt so red and blue fringes show. Slices lock roughly top to bottom: each snaps to zero with a small damped wobble over 0.18 s, its channels merge into solid text and a thin bright line flashes along its lower edge. Stray noise bars thin out, a status line switches from searching to locked, and one last 80 ms jolt confirms it. Afterwards a brief two-slice glitch recurs every few seconds.",
            "一行两排的特粗标题由三个颜色通道叠加绘成，并被切成九条高度不一的横条。前1.1秒信号不稳：每条横条每秒24次跳到新的随机水平偏移，起初最大46pt，越接近各自的锁定时刻越小，同时时隐时现，三个通道最多错开10pt，露出红蓝色边。横条大致自上而下依次锁定：每条在0.18秒内带一点阻尼摆动吸回零位，通道合成实心文字，下沿闪过一道细亮线。零星的噪点条逐渐变少，状态行从「搜索中」切到「已锁定」，最后再来一次80毫秒的整体抖动作为确认。之后每隔几秒还会有两条横条短暂地故障一下。"
        ),
        implementation: L(
            "A Canvas inside a TimelineView draws the resolved headline once per channel and slice: each slice clips to its band, translates by a hashed offset stepped at 24 Hz and blends the channels additively in dark mode (RGB) or by multiply in light mode (CMY), so aligned channels give clean text.",
            "TimelineView 里的 Canvas 按通道和横条逐次绘制已解析的标题：每条横条裁剪到自己的带状区域，按24Hz步进的哈希偏移平移，并在深色模式下以相加（RGB）、浅色模式下以正片叠底（CMY）混合通道，通道对齐时就得到干净的文字。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.clip(to:)", "GraphicsContext.blendMode", "GraphicsContext.resolve"],
        tags: ["glitch", "rgb split", "slices", "chromatic", "cyberpunk", "故障", "色彩分离", "赛博朋克", "横条", "失真"],
        params: [
            .slider("duration", L("Lock time", "锁定时长"), 0.5...2.5, default: 1.1, unit: "s"),
            .slider("slices", L("Slices", "横条数"), 4...16, default: 9, step: 1, decimals: 0),
            .slider("split", L("Channel split", "通道错位"), 2...24, default: 10, decimals: 0, unit: "pt"),
            .toggle("idle", L("Idle glitches", "空闲时故障"), default: true),
        ]
    ) { ctx in
        TextGlitchInDemo(ctx: ctx)
    }
}

private struct TextGlitchInDemo: View {
    let ctx: DemoContext
    @Environment(\.colorScheme) private var scheme
    @State private var start = Date()
    @State private var runs = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            Canvas { context, size in
                let elapsed: Double = ctx.isStill ? 1000 : timeline.date.timeIntervalSince(start)
                draw(&context, size: size, time: elapsed)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Tap to replay", "点击重播"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.rigid)
            replay()
        }
        .autoplay(ctx.isPreview, every: 3.4, delay: 3.0, intro: false) { replay() }
    }

    private func replay() {
        runs += 1
        start = Date()
    }

    /// Deterministic noise in 0..<1, different on every run.
    private func noise(_ a: Int, _ b: Int) -> Double {
        let v: Double = sin(Double(a) * 127.1 + Double(b) * 311.7 + Double(runs) * 74.7) * 43758.5453
        return v - floor(v)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        let dark = scheme == .dark
        let duration: Double = max(ctx["duration"], 0.1)
        let count: Int = max(ctx.int("slices"), 1)
        let split: Double = ctx["split"]
        let lines: [String] = ctx.language == .zh ? ["信号", "已锁定"] : ["SIGNAL", "LOCKED"]
        let font: Font = .system(size: ctx.language == .zh ? 66 : 62, weight: .black)

        // Additive RGB on dark, subtractive CMY on light: aligned channels give white or black text.
        let channelColors: [Color] = dark
            ? [Color(red: 1, green: 0, blue: 0), Color(red: 0, green: 1, blue: 0), Color(red: 0, green: 0, blue: 1)]
            : [Color(red: 0, green: 1, blue: 1), Color(red: 1, green: 0, blue: 1), Color(red: 1, green: 1, blue: 0)]
        // channels[line][channel]
        let channels: [[GraphicsContext.ResolvedText]] = lines.map { line in
            channelColors.map { color in
                context.resolve(Text(verbatim: line).font(font).foregroundColor(color))
            }
        }
        let blend: GraphicsContext.BlendMode = dark ? .plusLighter : .multiply
        let measures: [CGSize] = channels.map { $0[0].measure(in: size) }
        let lineHeight: CGFloat = (measures.map(\.height).max() ?? 70) * 0.96
        let block = CGSize(width: measures.map(\.width).max() ?? 200, height: lineHeight * CGFloat(lines.count))
        let center = CGPoint(x: size.width / 2, y: size.height / 2 - 14)
        let top: CGFloat = center.y - block.height / 2 - 4
        let height: CGFloat = block.height + 8
        let frame: Int = Int(time * 24)

        // The confirming jolt right after the last slice locks, and the idle glitches later on.
        let jolt: Bool = time > duration + 0.12 && time < duration + 0.2
        let idleClock: Double = time - duration - 2.2
        let idleBurst: Bool = ctx.bool("idle") && idleClock > 0 && idleClock.truncatingRemainder(dividingBy: 2.6) < 0.14
        let idleRound: Int = Int(max(idleClock, 0) / 2.6)

        // Uneven slice heights.
        let weights: [Double] = (0..<count).map { 0.5 + noise($0, 999) }
        let total: Double = weights.reduce(0, +)
        var y: CGFloat = top
        for index in 0..<count {
            let sliceHeight: CGFloat = height * CGFloat(weights[index] / total)
            let band = CGRect(x: 0, y: y, width: size.width, height: sliceHeight + 0.5)
            y += sliceHeight

            let order: Double = (Double(index) + noise(index, 500) * 2.2 - 1.1) / Double(max(count - 1, 1))
            let lock: Double = duration * (0.3 + 0.7 * TextFXCurve.clamp01(order))
            var dx: Double = 0
            var spread: Double = 0
            var visible = true
            var flashAlpha: Double = 0

            if time < lock {
                let u: Double = time / lock
                let amplitude: Double = 46 * pow(1 - u, 0.7) + 4
                dx = (noise(index, frame) * 2 - 1) * amplitude
                spread = split * (0.4 + 0.6 * (1 - u)) * (noise(index, frame + 13) > 0.7 ? 2.2 : 1)
                visible = noise(index, frame + 77) < 0.3 + 0.7 * u
            } else {
                let u: Double = TextFXCurve.clamp01((time - lock) / 0.18)
                let decay: Double = (1 - u) * (1 - u)
                dx = -7 * decay * sin(u * Double.pi * 2) * (index % 2 == 0 ? 1 : -1)
                spread = split * 0.35 * decay
                flashAlpha = time - lock < 0.16 ? 1 - (time - lock) / 0.16 : 0
            }
            if jolt {
                dx += 5
                spread = split * 0.5
            }
            if idleBurst && (index == Int(noise(idleRound, 31) * Double(count)) || index == Int(noise(idleRound, 57) * Double(count))) {
                dx = (noise(index, frame + 5) * 2 - 1) * 16
                spread = split * 0.8
            }

            if visible {
                var slice = context
                slice.clip(to: Path(band))
                slice.blendMode = blend
                let offsets: [Double] = [dx - spread, dx, dx + spread]
                for line in lines.indices {
                    let lineY: CGFloat = center.y - block.height / 2 + lineHeight * (CGFloat(line) + 0.5)
                    for channel in 0..<3 {
                        slice.draw(channels[line][channel], at: CGPoint(x: center.x + offsets[channel], y: lineY), anchor: .center)
                    }
                }
            }
            if flashAlpha > 0 {
                let line = CGRect(x: center.x - block.width / 2 - 14, y: band.maxY - 1, width: block.width + 28, height: 1.5)
                context.fill(Path(line), with: .color(Palette.mint.opacity(0.9 * flashAlpha)))
            }
        }

        // Stray noise bars while the signal is unstable.
        if time < duration {
            let fade: Double = 1 - time / duration
            for bar in 0..<4 where noise(bar + 40, frame) < 0.25 + 0.5 * fade {
                let barWidth: CGFloat = 30 + 130 * noise(bar + 60, frame)
                let barX: CGFloat = (size.width - barWidth) * noise(bar + 80, frame)
                let barY: CGFloat = top - 14 + (height + 28) * noise(bar + 100, frame)
                let rect = CGRect(x: barX, y: barY, width: barWidth, height: 2 + 4 * noise(bar + 120, frame))
                let color: Color = bar % 2 == 0 ? Palette.red : Palette.sky
                context.fill(Path(rect), with: .color(color.opacity(0.55 * fade)))
            }
        }

        drawStatus(&context, at: CGPoint(x: center.x, y: top + height + 22), time: time, duration: duration)
    }

    private func drawStatus(_ context: inout GraphicsContext, at point: CGPoint, time: Double, duration: Double) {
        let locked: Bool = time >= duration
        let font: Font = .system(size: 13, weight: .bold, design: .monospaced)
        let label: String
        if locked {
            label = ctx.language == .zh ? "● 已锁定 100%" : "● LOCKED 100%"
        } else {
            let percent: Int = Int(time / duration * 100)
            label = (ctx.language == .zh ? "○ 搜索信号 " : "○ SEARCHING ") + String(format: "%02d%%", percent)
        }
        let blink: Double = locked ? 1 : (Int(time * 8) % 2 == 0 ? 0.9 : 0.45)
        let color: Color = locked ? Color.adaptive(light: 0x0B8F6E, dark: 0x21D4A8) : Color.secondary
        let text = context.resolve(Text(verbatim: label).font(font).foregroundColor(color))
        var status = context
        status.opacity = blink
        status.draw(text, at: point, anchor: .center)
    }
}
