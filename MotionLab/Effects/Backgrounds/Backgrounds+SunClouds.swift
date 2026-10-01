import SwiftUI

extension Effect {
    static let backgroundsSunClouds = Effect(
        id: "backgrounds.sun-clouds",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Sun & Drifting Clouds", "晴空流云"),
        summary: L(
            "A bright sun with a lens flare over three layers of cumulus; the flare dims and the cloud edges light up whenever a cloud slides across the sun.",
            "明亮的太阳带着镜头光晕，三层积云以不同速度飘过；每当云遮住太阳，光晕随之变暗，云边被镶上一道亮边。"
        ),
        prompt: L(
            "A fair-weather sky, deep blue falling to pale haze. A white sun with a warm additive bloom and six slowly turning rays sits upper left. Three layers of cumulus drift right at 6, 13 and 24 pt/s: far clouds small, pale and soft, near clouds large and crisp; each is a cluster of overlapping puffs on a flat base, shaded from white tops to blue-grey undersides. A lens flare lies on the line from the sun through the frame centre: six ghosts of different sizes and tints at 0.35 to 2.0 times that distance, a thin rainbow halo and a horizontal streak, all re-aligning as the sun moves. When a cloud covers the sun, flare and bloom fade to 15% within a quarter of a second and the cloud's rim near the sun glows silver. Dragging moves the sun on a spring (stiffness 50, damping 0.75). Bright, airy, optimistic.",
            "晴空自深蓝向下渐变为淡雾。左上方的白色太阳带着暖色光晕和六道缓慢转动的光芒。三层积云以每秒 6、13、24pt 向右飘移：远处的云小、淡、柔，近处的大而清晰；每朵云是一簇重叠云团加平直云底，由洁白云顶过渡到蓝灰云底。镜头光晕位于太阳与画面中心的连线上：六个大小、色调各异的光斑分布在该距离的 0.35 到 2.0 倍处，另有细彩虹光环和水平光条，随太阳移动重新对齐。云遮住太阳时，光晕与辉光在 ¼ 秒内减弱到 15%，云朵靠近太阳的边缘泛起银光。拖动以弹簧（刚度 50、阻尼 0.75）移动太阳。"
        ),
        implementation: L(
            "Cloud puffs are analytic in time, so one function feeds both the drawing and an occlusion test at the sun's position; the smoothed occlusion scales the bloom and the flare, and each cloud Path is drawn again in plusLighter with a radial gradient centred on the sun for the silver lining.",
            "云团的位置是时间的解析函数，同一个函数既用于绘制，也用于在太阳位置做遮挡测试；平滑后的遮挡值缩放辉光与镜头光晕，每朵云的 Path 还会以太阳为中心的径向渐变在 plusLighter 下重绘一次，形成银边。"
        ),
        apis: ["Canvas", "GraphicsContext.drawLayer", "GraphicsContext.Shading.radialGradient", "blendMode(.plusLighter)", "TimelineView(.animation)", "DragGesture"],
        tags: ["sun", "clouds", "lens flare", "sky", "太阳", "云", "镜头光晕", "晴天"],
        params: [
            .slider("clouds", L("Cloud cover", "云量"), 2...9, default: 5, step: 1, decimals: 0),
            .slider("wind", L("Wind", "风速"), 0.2...3.0, default: 1.0, unit: "×"),
            .slider("flare", L("Lens flare", "镜头光晕"), 0...1, default: 0.7),
        ]
    ) { ctx in
        SunCloudsDemo(ctx: ctx)
    }
}

private final class SunCloudsModel {
    let clock = BackgroundClock()
    let pointer = BackgroundPointer()
    var occlusion = 0.0
}

private struct SunCloudsDemo: View {
    let ctx: DemoContext
    @State private var model = SunCloudsModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1F6FD0), Color(hex: 0x5FA8EE), Color(hex: 0xCDE6FA)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.clock.advance(to: now, speed: ctx["wind"])
                    let idle = CGPoint(
                        x: size.width * CGFloat(0.3 + 0.05 * sin(now * 0.13)),
                        y: size.height * CGFloat(0.26 + 0.03 * sin(now * 0.19 + 1))
                    )
                    let sun = model.pointer.step(now: now, idle: idle, stiffness: 50, damping: 0.75, frozen: ctx.isStill)
                    let cover = max(ctx.int("clouds"), 1)
                    let target = SunCloudsPainter.occlusion(at: sun, size: size, t: t, cover: cover)
                    if ctx.isStill {
                        model.occlusion = target
                    } else {
                        // Reaches the new level in about a quarter of a second.
                        model.occlusion += (target - model.occlusion) * model.clock.follow(rate: 12)
                    }
                    SunCloudsPainter.draw(
                        &context, size: size, t: t, turn: now * 0.05, sun: sun, cover: cover,
                        clear: 1 - 0.85 * model.occlusion, occlusion: model.occlusion, flare: ctx["flare"]
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
        .backgroundsChipHint(L("Swipe sideways, then drag the sun", "先横向滑动，再拖动太阳"), ctx)
    }
}

private struct SunCloud {
    let puffs: [CGRect]
    let bounds: CGRect
}

private enum SunCloudsPainter {
    // Per layer: (vertical band start, band height, scale, speed pt/s, blur, opacity).
    static let layers: [(y: CGFloat, band: CGFloat, scale: CGFloat, speed: Double, blur: CGFloat, alpha: Double)] = [
        (0.12, 0.26, 0.5, 6, 2.2, 0.8),
        (0.34, 0.24, 0.8, 13, 1.2, 0.92),
        (0.6, 0.24, 1.2, 24, 0.5, 0.97),
    ]

    static func clouds(layer index: Int, size: CGSize, t: Double, cover: Int) -> [SunCloud] {
        let layer = layers[index]
        let count = max(index == 0 ? cover + 1 : (index == 1 ? cover : cover - 2), 1)
        let span = Double(size.width) + 320
        var result: [SunCloud] = []
        for i in 0..<count {
            let key = index * 40 + i
            let u = BackgroundMath.fract(Double(i) / Double(count) + 0.45 * BackgroundMath.rand(key, 2901) / Double(count) + t * layer.speed / span)
            let cx = CGFloat(u * span) - 160
            let cy = size.height * (layer.y + layer.band * BackgroundMath.unit(key, 2902))
            let width = (120 + 80 * BackgroundMath.unit(key, 2903)) * layer.scale
            var puffs: [CGRect] = []
            // A flat base, a row of puffs heaped along it (tallest in the middle) and a few towers above.
            let baseHeight = width * 0.13
            puffs.append(CGRect(x: cx - width / 2, y: cy - baseHeight / 2, width: width, height: baseHeight))
            let n = 6 + Int(BackgroundMath.rand(key, 2904) * 3)
            for k in 0..<n {
                let f = (CGFloat(k) + 0.5) / CGFloat(n)
                let hump = sin(f * .pi)
                let r = width * (0.075 + 0.085 * hump) * (0.85 + 0.3 * BackgroundMath.unit(key * 9 + k, 2905))
                let px = cx - width / 2 + width * (0.08 + 0.84 * f)
                let py = cy - r * 0.55 - 1.5 * CGFloat(sin(t * 0.25 + Double(key + k)))
                puffs.append(CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
            }
            let towers = 2 + Int(BackgroundMath.rand(key, 2906) * 2)
            for k in 0..<towers {
                let f = 0.3 + 0.4 * (CGFloat(k) + 0.5) / CGFloat(towers) + (BackgroundMath.unit(key * 5 + k, 2907) - 0.5) * 0.08
                let r = width * (0.1 + 0.05 * BackgroundMath.unit(key * 5 + k, 2908))
                let px = cx - width / 2 + width * f
                let py = cy - width * (0.16 + 0.05 * BackgroundMath.unit(key * 5 + k, 2909)) - 1.5 * CGFloat(sin(t * 0.21 + Double(key - k)))
                puffs.append(CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
            }
            var bounds = puffs[0]
            for puff in puffs { bounds = bounds.union(puff) }
            result.append(SunCloud(puffs: puffs, bounds: bounds))
        }
        return result
    }

    /// How much of the sun is behind cloud, 0...1.
    static func occlusion(at sun: CGPoint, size: CGSize, t: Double, cover: Int) -> Double {
        var value = 0.0
        for index in 0..<layers.count {
            for cloud in clouds(layer: index, size: size, t: t, cover: cover) where cloud.bounds.insetBy(dx: -20, dy: -20).contains(sun) {
                for puff in cloud.puffs {
                    let dx = Double((sun.x - puff.midX) / (puff.width / 2))
                    let dy = Double((sun.y - puff.midY) / (puff.height / 2))
                    let d = (dx * dx + dy * dy).squareRoot()
                    value = max(value, (1 - BackgroundMath.smoothstep(0.75, 1.3, d)) * layers[index].alpha)
                }
            }
        }
        return value
    }

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, turn: Double, sun: CGPoint, cover: Int, clear: Double,
        occlusion: Double, flare: Double
    ) {
        // Bloom, rays and the disc; clouds are painted over them.
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.backgroundsGlow(at: sun, radius: size.width * 0.75, color: Color(hex: 0xFFF1C4).opacity(0.36 * clear))
            layer.backgroundsGlow(at: sun, radius: size.width * 0.3, color: Color(hex: 0xFFF7DC).opacity(0.75 * clear))
            var rays = Path()
            for i in 0..<6 {
                let angle = turn + Double(i) * .pi / 3
                let length = size.width * CGFloat(0.34 + 0.08 * sin(turn * 9 + Double(i) * 2.1))
                let dir = CGPoint(x: cos(angle), y: sin(angle))
                let side = CGPoint(x: -dir.y * 2.2, y: dir.x * 2.2)
                rays.move(to: CGPoint(x: sun.x + side.x, y: sun.y + side.y))
                rays.addLine(to: CGPoint(x: sun.x + dir.x * length, y: sun.y + dir.y * length))
                rays.addLine(to: CGPoint(x: sun.x - side.x, y: sun.y - side.y))
                rays.closeSubpath()
            }
            var soft = layer
            soft.addFilter(.blur(radius: 2.5))
            soft.fill(rays, with: .radialGradient(
                Gradient(colors: [.white.opacity(0.34 * clear), .white.opacity(0)]), center: sun, startRadius: 0, endRadius: size.width * 0.4
            ))
        }
        // The disc has no hard edge: a white core that melts into the bloom.
        let disc = Gradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: 0.5),
            .init(color: .white.opacity(0), location: 1),
        ])
        context.fill(
            Path(ellipseIn: CGRect(x: sun.x - 30, y: sun.y - 30, width: 60, height: 60)),
            with: .radialGradient(disc, center: sun, startRadius: 0, endRadius: 30)
        )

        for index in 0..<layers.count {
            let layer = layers[index]
            let list = clouds(layer: index, size: size, t: t, cover: cover)
            context.drawLayer { group in
                group.addFilter(.blur(radius: layer.blur))
                group.opacity = layer.alpha
                for cloud in list where cloud.bounds.maxX > -10 && cloud.bounds.minX < size.width + 10 {
                    var path = Path()
                    for (k, puff) in cloud.puffs.enumerated() {
                        if k == 0 {
                            path.addRoundedRect(in: puff, cornerSize: CGSize(width: puff.height / 2, height: puff.height / 2))
                        } else {
                            path.addEllipse(in: puff)
                        }
                    }
                    // White tops, blue-grey undersides; far layers take on the sky's colour.
                    let under = index == 0 ? Color(hex: 0xC4DAF2) : (index == 1 ? Color(hex: 0xB4C6E0) : Color(hex: 0x9EB2D2))
                    let shade = Gradient(stops: [
                        .init(color: .white, location: 0.3),
                        .init(color: under, location: 0.95),
                    ])
                    group.fill(path, with: .linearGradient(
                        shade, startPoint: CGPoint(x: 0, y: cloud.bounds.minY), endPoint: CGPoint(x: 0, y: cloud.bounds.maxY)
                    ))
                    // A soft highlight on the upper left of every puff gives the heap some volume.
                    for puff in cloud.puffs.dropFirst() {
                        let r = puff.width / 2
                        let c = CGPoint(x: puff.midX - r * 0.25, y: puff.midY - r * 0.35)
                        group.fill(Path(ellipseIn: puff), with: .radialGradient(
                            Gradient(colors: [.white.opacity(0.7), .white.opacity(0)]), center: c, startRadius: 0, endRadius: r * 1.05
                        ))
                    }
                    // Silver lining toward the sun.
                    let reach: CGFloat = 130
                    if hypot(cloud.bounds.midX - sun.x, cloud.bounds.midY - sun.y) < reach + cloud.bounds.width {
                        var lit = group
                        lit.blendMode = .plusLighter
                        lit.fill(path, with: .radialGradient(
                            Gradient(colors: [Color(hex: 0xFFF6D8).opacity(0.75), Color(hex: 0xFFF6D8).opacity(0)]),
                            center: sun, startRadius: 0, endRadius: reach
                        ))
                    }
                }
            }
        }

        drawFlare(&context, size: size, sun: sun, strength: flare * clear)
        // The whole frame lifts a little while the sun is clear.
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFFF6DC).opacity(0.07 * clear * (0.4 + flare))))
        if occlusion > 0.01 {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x1F3C6E).opacity(0.1 * occlusion)))
        }
    }

    private static func drawFlare(_ context: inout GraphicsContext, size: CGSize, sun: CGPoint, strength: Double) {
        guard strength > 0.01 else { return }
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let axis = CGVector(dx: centre.x - sun.x, dy: centre.y - sun.y)
        let ghosts: [(f: CGFloat, r: CGFloat, color: UInt32, alpha: Double, ring: Bool)] = [
            (0.35, 13, 0xFFB45A, 0.42, false),
            (0.6, 26, 0x7CF0A8, 0.26, true),
            (0.9, 8, 0x8FB8FF, 0.5, false),
            (1.25, 38, 0xB896FF, 0.22, false),
            (1.6, 17, 0x6FE0FF, 0.34, true),
            (2.0, 56, 0xFF9AC8, 0.16, false),
        ]
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            // Horizontal streak and halo ring.
            layer.backgroundsGlow(at: sun, radius: size.width * 0.62, color: Color(hex: 0xBFDFFF).opacity(0.55 * strength), squash: 0.018)
            let halo: CGFloat = 62
            let rainbow = Gradient(colors: [
                Color(hex: 0xFF8A8A), Color(hex: 0xFFE08A), Color(hex: 0x8AFFC2), Color(hex: 0x8AC8FF), Color(hex: 0xC69AFF), Color(hex: 0xFF8A8A),
            ])
            var ring = layer
            ring.opacity = 0.2 * strength
            ring.addFilter(.blur(radius: 2))
            ring.stroke(
                Path(ellipseIn: CGRect(x: sun.x - halo, y: sun.y - halo, width: halo * 2, height: halo * 2)),
                with: .conicGradient(rainbow, center: sun), lineWidth: 4
            )
            for ghost in ghosts {
                let p = CGPoint(x: sun.x + axis.dx * ghost.f, y: sun.y + axis.dy * ghost.f)
                let color = Color(hex: ghost.color)
                let rect = CGRect(x: p.x - ghost.r, y: p.y - ghost.r, width: ghost.r * 2, height: ghost.r * 2)
                if ghost.ring {
                    // A faint disc that brightens toward a soft rim.
                    layer.fill(Path(ellipseIn: rect), with: .radialGradient(
                        Gradient(stops: [
                            .init(color: color.opacity(ghost.alpha * 0.3 * strength), location: 0),
                            .init(color: color.opacity(ghost.alpha * 0.4 * strength), location: 0.7),
                            .init(color: color.opacity(ghost.alpha * strength), location: 0.9),
                            .init(color: color.opacity(0), location: 1),
                        ]),
                        center: p, startRadius: 0, endRadius: ghost.r
                    ))
                } else {
                    layer.fill(Path(ellipseIn: rect), with: .radialGradient(
                        Gradient(colors: [color.opacity(ghost.alpha * strength), color.opacity(ghost.alpha * 0.45 * strength), color.opacity(0)]),
                        center: p, startRadius: 0, endRadius: ghost.r
                    ))
                }
            }
        }
    }
}
