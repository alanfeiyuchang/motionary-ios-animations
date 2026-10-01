import SwiftUI

extension Effect {
    static let backgroundsRidgeLines = Effect(
        id: "backgrounds.ridge-lines",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Ridge Lines", "脉冲星山脊线"),
        summary: L(
            "Stacked white traces in the manner of a pulsar plot: each line hides the ones behind it, peaks jostle in the middle, and the range follows your finger.",
            "仿脉冲星图的层叠白色曲线：每条线遮住身后的线，山峰在中段此起彼伏，整片山脉跟着手指移动。"
        ),
        prompt: L(
            "A black field with 30 thin white traces stacked from top to bottom, each spanning the middle 80% of the width. Every trace is flat and faintly noisy at its ends and rises into jagged peaks inside a Gaussian window (σ = 16% of the width), up to 64 pt tall; the peaks come from two octaves of smooth noise raised to the power 1.6, scrolling at different rates per line so neighbouring traces are related but never identical. Each trace is filled with black below itself before its 1.2 pt stroke is drawn, back to front, so nearer ridges cleanly occlude farther ones. Far lines are dimmer and bluish, near lines pure white. The window's centre follows the finger on an underdamped spring (stiffness 50, damping 0.5) and the whole range sloshes after it; untouched, it sways slowly. Stark, graphic, iconic.",
            "黑色背景上自上而下层叠着 30 条白色细线，每条横跨画面中间 80% 的宽度。每条线两端平直、带轻微噪声，在高斯窗（σ 为宽度的 16%）内隆起成参差的尖峰，最高 64pt；尖峰来自两个倍频的平滑噪声并取 1.6 次幂，各线以不同速率滚动，相邻曲线相似却不相同。每条线先把自己下方填成黑色，再画 1.2pt 的描边，由远及近绘制，近处的山脊干净地遮住远处的。远处的线更暗偏蓝，近处纯白。高斯窗中心以欠阻尼弹簧（刚度 50、阻尼 0.5）跟随手指，整片山脉随之晃荡。冷峻、图形化、经典。"
        ),
        implementation: L(
            "A Canvas builds each trace as a 150-sample polyline from value noise shaped by a Gaussian envelope, fills a closed copy with the background colour and strokes the open one, iterating far to near so the painter's algorithm does the hidden-line removal.",
            "Canvas 用经高斯包络整形的值噪声为每条曲线生成 150 个采样点的折线，先用背景色填充其闭合副本，再对开放折线描边；由远及近迭代，以画家算法完成隐线消除。"
        ),
        apis: ["Canvas", "Path", "TimelineView(.animation)", "DragGesture", "GraphicsContext.stroke(_:with:style:)"],
        tags: ["ridge", "joy division", "pulsar", "lines", "山脊线", "脉冲星", "线条", "波形"],
        params: [
            .slider("lines", L("Lines", "线条数量"), 12...48, default: 30, step: 1, decimals: 0),
            .slider("height", L("Peak height", "峰高"), 20...110, default: 64, decimals: 0, unit: "pt"),
            .slider("roughness", L("Roughness", "粗糙度"), 0...1, default: 0.55),
            .slider("speed", L("Speed", "速度"), 0.2...3.0, default: 1.0, unit: "×"),
        ]
    ) { ctx in
        RidgeLinesDemo(ctx: ctx)
    }
}

private final class RidgeModel {
    let clock = BackgroundClock()
    let pointer = BackgroundPointer()
}

private struct RidgeLinesDemo: View {
    let ctx: DemoContext
    @State private var model = RidgeModel()

    var body: some View {
        ZStack {
            Color(hex: 0x050506)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.clock.advance(to: now, speed: ctx["speed"])
                    let idle = CGPoint(x: size.width * CGFloat(0.5 + 0.08 * sin(t * 0.37)), y: size.height / 2)
                    let finger = model.pointer.step(now: now, idle: idle, stiffness: 50, damping: 0.5, frozen: ctx.isStill)
                    RidgePainter.draw(
                        &context, size: size, t: t, focus: finger.x, lines: max(ctx.int("lines"), 2),
                        height: ctx.cg("height"), roughness: ctx["roughness"]
                    )
                }
            }
        }
        .backgroundsTouch { location in
            if !model.pointer.userTouched { Haptics.tap(.soft) }
            model.pointer.userTouched = true
            model.pointer.touch = location
        } onEnded: {
            model.pointer.touch = nil
        }
        .backgroundsHint(L("Swipe sideways to move the peaks", "横向滑动移动山峰"), ctx)
    }
}

private enum RidgePainter {
    static let background = Color(hex: 0x050506)

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, focus: CGFloat, lines: Int, height: CGFloat, roughness: Double) {
        let left = size.width * 0.1
        let right = size.width * 0.9
        let top = size.height * 0.26
        let bottom = size.height * 0.86
        let samples = 150
        let sigma = Double(size.width) * 0.16
        let far = BackgroundRGB(hex: 0x7F93E8)
        let near = BackgroundRGB(1, 1, 1)

        for line in 0..<lines {
            let f = Double(line) / Double(lines - 1)
            let base = top + (bottom - top) * CGFloat(f)
            let rate = 0.35 + 0.3 * BackgroundMath.rand(line, 2701)
            let offset = Double(line) * 3.71
            var trace = Path()
            for k in 0...samples {
                let x = left + (right - left) * CGFloat(k) / CGFloat(samples)
                let dx = Double(x - focus)
                let window = exp(-dx * dx / (2 * sigma * sigma))
                let xs = Double(x) / 340
                let broad = BackgroundMath.valueNoise(xs * 17 + offset, t * rate + offset)
                let fine = BackgroundMath.valueNoise(xs * 52 - offset, t * rate * 1.7 + offset * 2)
                let peaks = pow(broad * (1 - roughness * 0.75) + broad * fine * roughness * 1.6, 1.6) * 1.7
                let hiss = (BackgroundMath.valueNoise(xs * 90 + offset, t * 1.4 + offset) - 0.5) * (0.6 + 2.2 * roughness)
                let y = base - height * CGFloat(min(peaks, 1.15) * window) - CGFloat(hiss)
                if k == 0 {
                    trace.move(to: CGPoint(x: x, y: y))
                } else {
                    trace.addLine(to: CGPoint(x: x, y: y))
                }
            }
            // Hide whatever lies behind this ridge, then draw it.
            var mask = trace
            mask.addLine(to: CGPoint(x: right, y: base + 14))
            mask.addLine(to: CGPoint(x: left, y: base + 14))
            mask.closeSubpath()
            context.fill(mask, with: .color(background))
            let color = far.mix(near, f).color(0.5 + 0.5 * f)
            context.stroke(trace, with: .color(color), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
    }
}
