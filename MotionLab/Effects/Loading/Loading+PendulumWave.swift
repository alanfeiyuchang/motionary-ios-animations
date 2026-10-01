import SwiftUI

extension Effect {
    static let loadingPendulumWave = Effect(
        id: "loading.pendulum-wave",
        category: .loading,
        interaction: .loop,
        name: L("Pendulum Wave", "钟摆波"),
        summary: L("A row of pendulums seen end-on, each a little faster than the last, drifting through snakes, braids and chaos back into line.", "一排钟摆从端头看去，一个比一个快一点，从蛇形、辫形、混乱再回到整齐一线。"),
        prompt: L(
            "Twelve pendulums hang from one rail and are seen end-on, so their bobs stack into a column: the front one is the longest (205 pt, 20 pt bob), the back one the shortest (80 pt, 12 pt bob). All start together at 28° and swing as pure cosines, but each completes exactly one more swing per 30 s cycle than its longer neighbour (24, 25, 26 …). The column therefore shears into a travelling snake, splits into two and three interleaved braids, dissolves into apparent chaos and, at the end of the cycle, snaps back into one straight line without any easing. Bobs are glossy spheres tinted sky → violet → amber along the row, with two fading ghost copies as motion blur, hairline strings and a faint ribbon threaded through their centres while the wave is smooth. Hypnotic, mathematical, calm.",
            "十二个钟摆挂在同一根横梁上，从端头看去摆球叠成一列：最前面的最长（205 pt、摆球 20 pt），最后面的最短（80 pt、摆球 12 pt）。摆球从 28° 同时释放，各做纯余弦摆动，但在 30 秒的周期里每一个都比更长的邻居恰好多摆一次（24、25、26 …）。于是整列先错开成游动的蛇，再分成两三股交织的辫子，继而散成看似混乱的点阵，周期结束时无需任何缓动便排回一条直线。摆球带高光，沿队列由天蓝过渡到紫再到琥珀，身后拖两层渐淡残影，细线悬挂；波形平滑时一条淡淡的丝带穿过各球球心。催眠、精确。"
        ),
        implementation: L(
            "One Canvas inside a TimelineView: pendulum i's angle is swing × cos(2π (n + i) τ) for a shared cycle phase τ, so everything realigns when τ wraps. Bobs are drawn back to front with radial gradients; a tap restarts τ and cross-fades the angles from the old phase.",
            "TimelineView 里的一张 Canvas：第 i 个钟摆的角度是 摆幅 × cos(2π (n + i) τ)，τ 为共享的周期相位，τ 归零时全部自然重合。摆球由后向前绘制并用径向渐变着色；点击会重置 τ，并把角度从旧相位平滑过渡过去。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.Shading.radialGradient", "Path", "Color.mix(with:by:)"],
        tags: ["pendulum", "wave", "physics", "harmonic", "钟摆", "摆波", "物理", "谐波"],
        params: [
            .slider("count", L("Pendulums", "钟摆数量"), 7...15, default: 12, step: 1, decimals: 0),
            .slider("cycle", L("Realign cycle", "重合周期"), 10...60, default: 30, decimals: 0, unit: "s"),
            .slider("swing", L("Swing angle", "摆幅"), 10...40, default: 28, decimals: 0, unit: "°"),
            .toggle("ribbon", L("Wave ribbon", "波形丝带"), default: true),
        ]
    ) { ctx in
        PendulumWaveDemo(ctx: ctx)
    }
}

private struct PendulumWaveDemo: View {
    let ctx: DemoContext
    @State private var clock = LoadingPhaseClock()
    /// The clock that was running before the last tap, blended out over `blendTime`.
    @State private var previous: LoadingPhaseClock?
    @State private var switchedAt = Date.distantPast

    private let blendTime: Double = 0.55

    var body: some View {
        let cycle: Double = max(ctx["cycle"], 2)
        VStack(spacing: 4) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let raw: Double = clock.phase(at: timeline.date, rate: 1 / cycle)
                let tau: Double = ctx.isStill ? 0.058 : raw
                let since: Double = timeline.date.timeIntervalSince(switchedAt)
                let blend: Double = LoadingCurve.smoothstep(since / blendTime)
                let oldTau: Double? = blend < 1 ? previous?.phase(at: timeline.date, rate: 1 / cycle) : nil
                PendulumCanvas(
                    tau: tau,
                    oldTau: oldTau,
                    blend: blend,
                    count: max(ctx.int("count"), 2),
                    swing: ctx["swing"] * .pi / 180,
                    ribbon: ctx.bool("ribbon"),
                    baseSwings: max((cycle / 1.25).rounded(), 4),
                    ghostStep: 0.02 / cycle
                )
            }
            .frame(width: 300, height: 262)
            .contentShape(Rectangle())
            .onTapGesture { realign() }
            DemoHint(text: L("Tap to line them up again", "点击让它们重新对齐"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx["cycle"]) { old, _ in
            clock.rebase(at: .now, oldRate: 1 / max(old, 2))
        }
    }

    private func realign() {
        Haptics.tap()
        previous = clock
        switchedAt = .now
        clock.restart()
    }
}

private struct PendulumCanvas: View {
    let tau: Double
    let oldTau: Double?
    let blend: Double
    let count: Int
    let swing: Double
    let ribbon: Bool
    /// Swings of the longest pendulum per cycle (about one every 1.25 s); each next one makes one more.
    let baseSwings: Double
    let ghostStep: Double

    private static let stops: [Color] = [Palette.sky, Palette.indigo, Palette.violet, Palette.pink, Palette.coral, Palette.amber]

    private static func color(_ u: Double) -> Color {
        let x: Double = min(max(u, 0), 1) * Double(stops.count - 1)
        let index: Int = min(Int(x), stops.count - 2)
        return stops[index].mix(with: stops[index + 1], by: x - Double(index))
    }

    private func angle(_ index: Int, at phase: Double) -> Double {
        swing * cos(2 * .pi * (baseSwings + Double(index)) * phase)
    }

    private func blendedAngle(_ index: Int, back: Double) -> Double {
        let now: Double = angle(index, at: tau - back)
        guard let oldTau else { return now }
        let before: Double = angle(index, at: oldTau - back)
        return before + (now - before) * blend
    }

    var body: some View {
        Canvas { context, size in
            let last: Double = Double(max(count - 1, 1))
            let front = CGPoint(x: size.width / 2 - 9, y: 28)
            let railStep = CGSize(width: 18 / last, height: -12 / last)

            // The rail, receding up and to the right.
            var rail = Path()
            rail.move(to: CGPoint(x: front.x - 5, y: front.y + 3))
            rail.addLine(to: CGPoint(x: front.x + 23, y: front.y - 15))
            context.stroke(rail, with: .color(Color.primary.opacity(0.28)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

            var centres: [CGPoint] = []
            // Back (shortest) to front (longest).
            for index in stride(from: count - 1, through: 0, by: -1) {
                let u: Double = Double(index) / last
                let pivot = CGPoint(x: front.x + railStep.width * CGFloat(index), y: front.y + railStep.height * CGFloat(index))
                let length: CGFloat = 205 - 125 * CGFloat(u)
                let radius: CGFloat = 10 - 4 * CGFloat(u)
                let tint: Color = PendulumCanvas.color(u)
                let depth: Double = 1 - 0.3 * u

                for ghost in stride(from: 2, through: 0, by: -1) {
                    let theta: Double = blendedAngle(index, back: Double(ghost) * ghostStep * 1.6)
                    let bob = CGPoint(x: pivot.x + length * CGFloat(sin(theta)), y: pivot.y + length * CGFloat(cos(theta)))
                    if ghost > 0 {
                        let r: CGFloat = radius * (1 - 0.12 * CGFloat(ghost))
                        let rect = CGRect(x: bob.x - r, y: bob.y - r, width: r * 2, height: r * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.2 / Double(ghost) * depth)))
                        continue
                    }
                    centres.append(bob)
                    var string = Path()
                    string.move(to: pivot)
                    string.addLine(to: bob)
                    context.stroke(string, with: .color(Color.primary.opacity(0.16 * depth)), lineWidth: 0.8)

                    let halo = CGRect(x: bob.x - radius * 2.2, y: bob.y - radius * 2.2, width: radius * 4.4, height: radius * 4.4)
                    context.fill(
                        Path(ellipseIn: halo),
                        with: .radialGradient(
                            Gradient(colors: [tint.opacity(0.32 * depth), tint.opacity(0)]),
                            center: bob,
                            startRadius: radius * 0.6,
                            endRadius: radius * 2.2
                        )
                    )
                    let rect = CGRect(x: bob.x - radius, y: bob.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [tint.mix(with: .white, by: 0.7), tint, tint.mix(with: .black, by: 0.28)]),
                            center: CGPoint(x: bob.x - radius * 0.35, y: bob.y - radius * 0.4),
                            startRadius: 0,
                            endRadius: radius * 1.5
                        )
                    )
                }
            }

            // Neighbours drift apart by one turn per cycle; the ribbon only shows while they still form a smooth wave.
            let drift: Double = cos(2 * .pi * tau)
            let ribbonAlpha: Double = LoadingCurve.smoothstep((drift - 0.25) / 0.45) * (oldTau == nil ? 1 : blend)
            if ribbon, ribbonAlpha > 0.01, centres.count > 2 {
                // A smooth curve through the bob centres makes the wave itself visible.
                var curve = Path()
                curve.move(to: centres[0])
                for index in 1..<centres.count - 1 {
                    let mid = CGPoint(x: (centres[index].x + centres[index + 1].x) / 2, y: (centres[index].y + centres[index + 1].y) / 2)
                    curve.addQuadCurve(to: mid, control: centres[index])
                }
                curve.addLine(to: centres[centres.count - 1])
                context.stroke(
                    curve,
                    with: .linearGradient(
                        Gradient(colors: [Palette.amber.opacity(0.55 * ribbonAlpha), Palette.violet.opacity(0.55 * ribbonAlpha), Palette.sky.opacity(0.55 * ribbonAlpha)]),
                        startPoint: CGPoint(x: size.width / 2, y: 90),
                        endPoint: CGPoint(x: size.width / 2, y: 240)
                    ),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}
