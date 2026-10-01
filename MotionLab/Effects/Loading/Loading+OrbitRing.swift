import SwiftUI

extension Effect {
    static let loadingOrbitRing = Effect(
        id: "loading.orbit-ring",
        category: .loading,
        interaction: .loop,
        name: L("Comet Progress Ring", "彗星进度环"),
        summary: L("The ring's head is a glowing dot that drags a comet tail and sheds sparks as it carries the percentage around.", "进度环的端点是一颗发光的圆点，拖着彗尾、洒着火花，把百分比一路带到终点。"),
        prompt: L(
            "A 172 pt ring with a 10 pt track at 9% ink. Progress is an arc that starts faint indigo at twelve o'clock and brightens through violet to pink toward its head, so the whole arc reads as a comet tail; the last 16% carries a blurred glow. The head is an 18 pt pink dot with a white core and a halo that breathes ±12% while it waits. Progress arrives in five uneven steps, each eased in and out over 1 s with a 0.45 s pause, and while the head moves it sheds tiny sparks that drift off the ring and fade in 0.7 s. The centre percentage rolls digit by digit. At 100% the ring flashes, the head runs one victory lap in 0.8 s, then the tail reels in to the head in 0.45 s and the loop restarts. Luminous, energetic, precise.",
            "一个 172 pt 的圆环，轨道 10 pt 粗、9% 墨色。进度弧从十二点处淡淡的靛蓝起，经紫色到端点的粉色越来越亮，整段弧就像一条彗尾；末端 16% 另带一层模糊辉光。端点是一颗 18 pt 的粉色圆点，白色内核，等待时光晕以 ±12% 呼吸。进度分五段大小不一的步进到来，每段用 1 秒缓入缓出，间隔 0.45 秒；端点移动时会洒出细小火花，飘离圆环并在 0.7 秒内淡出。中央百分比逐位滚动。到 100% 时圆环闪亮一下，端点用 0.8 秒跑完一圈庆祝，随后尾巴在 0.45 秒内收向端点，循环重新开始。明亮、有冲劲、精确。"
        ),
        implementation: L(
            "Progress is a scripted function of time evaluated in a TimelineView. A Canvas strokes the arc with a conic gradient whose bright stop sits at the head, redraws its last part through a blur filter, and places sparks from the head's position at their birth times; the number is a Text with a numeric content transition.",
            "进度是关于时间的脚本函数，在 TimelineView 中求值。Canvas 用锥形渐变描出圆弧，把亮色停靠点放在端点处，再经模糊滤镜重画末段，并按火花诞生时刻的端点位置放置火花；数字是带数字内容转场的 Text。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.Shading.conicGradient", "GraphicsContext.addFilter(.blur)", "contentTransition(.numericText)"],
        tags: ["ring", "comet", "progress", "sparks", "圆环", "彗星", "进度", "火花"],
        params: [
            .slider("step", L("Step time", "每步时长"), 0.4...2.5, default: 1.0, decimals: 1, unit: "s"),
            .slider("thickness", L("Ring thickness", "圆环粗细"), 5...16, default: 10, decimals: 0, unit: "pt"),
            .toggle("sparks", L("Sparks", "火花"), default: true),
        ]
    ) { ctx in
        OrbitRingDemo(ctx: ctx)
    }
}

/// The scripted run: five eased steps, a victory lap, a hold and the tail reeling in.
private struct OrbitScript {
    let step: Double

    static let targets: [Double] = [0.16, 0.39, 0.58, 0.86, 1]
    static let pause: Double = 0.45
    static let lap: Double = 0.8
    static let hold: Double = 0.7
    static let reel: Double = 0.45

    var loadEnd: Double { Double(OrbitScript.targets.count) * (step + OrbitScript.pause) }
    var total: Double { loadEnd + OrbitScript.lap + OrbitScript.hold + OrbitScript.reel + 0.25 }

    /// Loading progress (0…1) at `time` seconds into the run.
    func progress(_ time: Double) -> Double {
        let slot: Double = step + OrbitScript.pause
        let index: Int = Int(max(time, 0) / slot)
        guard index < OrbitScript.targets.count else { return 1 }
        let from: Double = index == 0 ? 0 : OrbitScript.targets[index - 1]
        let to: Double = OrbitScript.targets[index]
        let u: Double = (max(time, 0) - Double(index) * slot) / step
        return from + (to - from) * LoadingCurve.easeInOutCubic(u)
    }

    /// Whether the head is travelling at `time`.
    func moving(_ time: Double) -> Bool {
        guard time >= 0, time < loadEnd else { return false }
        let slot: Double = step + OrbitScript.pause
        let local: Double = time - floor(time / slot) * slot
        return local > step * 0.08 && local < step * 0.92
    }
}

private struct OrbitRingDemo: View {
    let ctx: DemoContext
    @State private var started = Date()

    var body: some View {
        let zh = ctx.language == .zh
        let script = OrbitScript(step: max(ctx["step"], 0.1))
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let raw: Double = max(timeline.date.timeIntervalSince(started), 0)
            // Stills sit in the middle of the fourth step, with sparks in the air.
            let time: Double = ctx.isStill
                ? 3 * (script.step + OrbitScript.pause) + script.step * 0.62
                : raw.truncatingRemainder(dividingBy: script.total)
            let progress: Double = script.progress(time)
            let percent: Int = Int((progress * 100).rounded())
            let complete: Bool = time >= script.loadEnd && time < script.loadEnd + OrbitScript.lap + OrbitScript.hold
            ZStack {
                OrbitRingCanvas(script: script, time: time, thickness: ctx.cg("thickness"), sparks: ctx.bool("sparks"))
                    .frame(width: 250, height: 250)
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(percent)")
                            .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText(value: Double(percent)))
                        Text("%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .scaleEffect(complete ? 1.08 : 1)
                    .animation(.snappy(duration: 0.22), value: percent)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: complete)
                    Text(complete ? (zh ? "同步完成" : "Synced") : (zh ? "正在同步资料库" : "Syncing library"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(complete ? Palette.pink : Color.secondary)
                        .contentTransition(.opacity)
                        .animation(.smooth(duration: 0.3), value: complete)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            started = .now
        }
    }
}

private struct OrbitRingCanvas: View {
    let script: OrbitScript
    let time: Double
    let thickness: CGFloat
    let sparks: Bool

    private static let radius: CGFloat = 86

    private static func point(_ centre: CGPoint, turn: Double, radius: CGFloat) -> CGPoint {
        let angle: Double = turn * 2 * .pi - .pi / 2
        return CGPoint(x: centre.x + radius * CGFloat(cos(angle)), y: centre.y + radius * CGFloat(sin(angle)))
    }

    private static func arc(_ centre: CGPoint, from: Double, to: Double) -> Path {
        var path = Path()
        path.addArc(
            center: centre,
            radius: radius,
            startAngle: .radians(from * 2 * .pi - .pi / 2),
            endAngle: .radians(to * 2 * .pi - .pi / 2),
            clockwise: false
        )
        return path
    }

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let r: CGFloat = OrbitRingCanvas.radius
            let afterLoad: Double = time - script.loadEnd
            let lapU: Double = afterLoad / OrbitScript.lap
            let reelU: Double = (afterLoad - OrbitScript.lap - OrbitScript.hold) / OrbitScript.reel

            // Where the arc starts and where its head is, in turns from twelve o'clock.
            var tail: Double = 0
            var head: Double = script.progress(time)
            if afterLoad >= 0 {
                head = 1 + LoadingCurve.easeOutCubic(lapU)
                tail = head - 1
                if reelU > 0 {
                    // The tail reels in to the head.
                    tail = head - 1 + LoadingCurve.easeInOutCubic(reelU) * 0.999
                }
            }
            let span: Double = max(head - tail, 0)
            let fadeOut: Double = reelU > 0 ? 1 - LoadingCurve.smoothstep((reelU - 0.75) / 0.25) : 1
            let flash: Double = afterLoad >= 0 ? exp(-max(afterLoad, 0) * 3.2) : 0

            // Track.
            context.stroke(
                Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)),
                with: .color(Color.primary.opacity(0.09)),
                lineWidth: thickness
            )

            if span > 0.002 {
                // The gradient's bright stop sits exactly at the head; past it the colour falls back to
                // the tail colour so the round cap at the start is not painted pink.
                let headStop: Double = min(span, 0.998)
                let gradient = Gradient(stops: [
                    .init(color: Palette.indigo.opacity(0.28 + 0.5 * flash), location: 0),
                    .init(color: Palette.violet.opacity(0.8), location: headStop * 0.6),
                    .init(color: Palette.pink, location: headStop),
                    .init(color: Palette.indigo.opacity(0.28 + 0.5 * flash), location: min(headStop + 0.002, 1)),
                    .init(color: Palette.indigo.opacity(0.28 + 0.5 * flash), location: 1),
                ])
                let shading = GraphicsContext.Shading.conicGradient(
                    gradient,
                    center: centre,
                    angle: .radians(tail * 2 * .pi - .pi / 2)
                )
                let arc = OrbitRingCanvas.arc(centre, from: tail, to: head)
                var ring = context
                ring.opacity = fadeOut
                ring.stroke(arc, with: shading, style: StrokeStyle(lineWidth: thickness, lineCap: .round))

                // Glow on the part nearest the head.
                let glowFrom: Double = max(head - min(span, 0.16), tail)
                ring.drawLayer { layer in
                    layer.addFilter(.blur(radius: 7))
                    layer.stroke(
                        OrbitRingCanvas.arc(centre, from: glowFrom, to: head),
                        with: .color(Palette.pink.opacity(0.75 + 0.25 * flash)),
                        style: StrokeStyle(lineWidth: thickness * (1 + 0.5 * CGFloat(flash)), lineCap: .round)
                    )
                }
            }

            if sparks {
                // Sparks are born on a fixed clock, at wherever the head was then, while it was moving.
                let rate: Double = 0.055
                let life: Double = 0.7
                let newest: Int = Int(floor(time / rate))
                let oldest: Int = Int(floor((time - life) / rate))
                for index in max(oldest, 0)...max(newest, 0) {
                    let born: Double = Double(index) * rate
                    let age: Double = time - born
                    guard age >= 0, age < life, script.moving(born) else { continue }
                    let u: Double = age / life
                    let side: CGFloat = LoadingCurve.hash(index) > 0.5 ? 1 : -1
                    let drift: CGFloat = side * (thickness / 2 + 3 + 18 * CGFloat(LoadingCurve.hash(index * 3 + 1)) * CGFloat(LoadingCurve.easeOutCubic(u)))
                    let turn: Double = script.progress(born) - 0.012 * u
                    let point = OrbitRingCanvas.point(centre, turn: turn, radius: r + drift)
                    let dot: CGFloat = (1.9 + 1.2 * CGFloat(LoadingCurve.hash(index * 5 + 2))) * CGFloat(1 - u)
                    let tint: Color = LoadingCurve.hash(index * 7) > 0.5 ? Palette.pink : Palette.amber
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)),
                        with: .color(tint.opacity(0.9 * (1 - u)))
                    )
                }
            }

            // The head.
            let waiting: Bool = !script.moving(time) && afterLoad < 0
            let breathe: CGFloat = waiting ? 1 + 0.12 * CGFloat(sin(time * 5)) : 1
            let headPoint = OrbitRingCanvas.point(centre, turn: head, radius: r)
            let dot: CGFloat = 9
            var headContext = context
            // The head fades back in at the top when a new run begins.
            headContext.opacity = fadeOut * LoadingCurve.smoothstep(time / 0.25)
            let halo: CGFloat = dot * 2.6 * breathe
            headContext.fill(
                Path(ellipseIn: CGRect(x: headPoint.x - halo, y: headPoint.y - halo, width: halo * 2, height: halo * 2)),
                with: .radialGradient(
                    Gradient(colors: [Palette.pink.opacity(0.55), Palette.pink.opacity(0)]),
                    center: headPoint,
                    startRadius: dot * 0.5,
                    endRadius: halo
                )
            )
            headContext.fill(
                Path(ellipseIn: CGRect(x: headPoint.x - dot, y: headPoint.y - dot, width: dot * 2, height: dot * 2)),
                with: .color(Palette.pink)
            )
            let core: CGFloat = dot * 0.48
            headContext.fill(
                Path(ellipseIn: CGRect(x: headPoint.x - core, y: headPoint.y - core, width: core * 2, height: core * 2)),
                with: .color(.white)
            )
        }
    }
}
