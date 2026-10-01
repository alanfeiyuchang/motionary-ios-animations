import SwiftUI

extension Effect {
    static let backgroundsMagneticLines = Effect(
        id: "backgrounds.magnetic-lines",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Magnetic Field Lines", "磁感线"),
        summary: L(
            "Field lines arc from one pole to the other with light streaming along them; your finger is a third pole that bends them toward it.",
            "磁感线从一极弯向另一极，光点沿线流动；你的手指是第三个磁极，把它们弯向自己。"
        ),
        prompt: L(
            "A dark indigo field with two glowing poles, a coral N on the left and a sky-blue S on the right, drifting on small slow orbits. 24 field lines leave N at even angles and are traced through the summed inverse-distance field of all poles until they reach S or leave the frame; they are drawn as thin lines shaded coral to violet to blue, with a soft bloom. Short bright dashes (3 pt every 29 pt) stream along every line from N to S at 40 pt/s, and a grid of tiny compass needles underneath turns to the local field. The finger is a third, attracting pole: it follows the touch on a spring (stiffness 70, damping 0.6), so nearby lines swing over, overshoot slightly and terminate on it, while the needles swivel. With no touch it wanders at 55% strength. Invisible forces made visible; precise and alive.",
            "深靛色的场中有两个发光磁极：左侧珊瑚色的 N 极与右侧天蓝色的 S 极，沿小而慢的轨道漂移。24 条磁感线以均匀角度从 N 极出发，沿所有磁极叠加的反比距离场描出，直到抵达 S 极或离开画面；它们是由珊瑚色经紫色过渡到蓝色的细线，带柔和辉光。短亮的虚线段（每 29pt 一段、长 3pt）以每秒 40pt 由 N 流向 S，下方一格格罗盘针随局部磁场转向。手指是第三个吸引磁极：以弹簧（刚度 70、阻尼 0.6）跟随触点，附近的磁感线甩过来、轻微过冲并终止在它上面。无触摸时它以 55% 的强度游走。让看不见的力显形。"
        ),
        implementation: L(
            "Each frame a Canvas integrates every line with midpoint (RK2) steps of 5 pt through E = Σ q·r/(|r|² + ε), strokes the combined Path with a pole-to-pole linear gradient, then strokes it again with a dashed StrokeStyle whose dashPhase advances with time to make the flowing particles.",
            "Canvas 每帧以 5pt 步长的中点法（RK2）在 E = Σ q·r/(|r|² + ε) 中积分出每条磁感线，用从一极到另一极的线性渐变为合并后的 Path 描边，再以 dashPhase 随时间推进的虚线 StrokeStyle 重描一次，形成流动的光点。"
        ),
        apis: ["Canvas", "StrokeStyle(dash:dashPhase:)", "GraphicsContext.Shading.linearGradient", "TimelineView(.animation)", "DragGesture"],
        tags: ["magnet", "field lines", "dipole", "physics", "磁场", "磁感线", "磁极", "物理"],
        params: [
            .slider("lines", L("Field lines", "磁感线数量"), 12...40, default: 24, step: 2, decimals: 0),
            .slider("pull", L("Finger strength", "手指磁力"), 0...2, default: 1.0, unit: "×"),
            .slider("flow", L("Flow speed", "流动速度"), 0...3, default: 1.0, unit: "×"),
            .toggle("repel", L("Finger repels", "手指排斥"), default: false),
        ]
    ) { ctx in
        MagneticLinesDemo(ctx: ctx)
    }
}

private final class MagneticModel {
    let clock = BackgroundClock()
    let flowClock = BackgroundClock(start: 0)
    let pointer = BackgroundPointer()
}

private struct MagneticCharge {
    let position: CGPoint
    let q: Double
}

private struct MagneticLinesDemo: View {
    let ctx: DemoContext
    @State private var model = MagneticModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x06071A), Color(hex: 0x0E0F2E), Color(hex: 0x090A1E)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.clock.advance(to: now, speed: 1)
                    let idle = CGPoint(
                        x: size.width * CGFloat(0.5 + 0.2 * sin(t * 0.45)),
                        y: size.height * CGFloat(0.5 + 0.34 * sin(t * 0.71 + 0.8))
                    )
                    let finger = model.pointer.step(now: now, idle: idle, stiffness: 70, damping: 0.6, frozen: ctx.isStill)
                    MagneticPainter.draw(
                        &context, size: size, t: t, flow: model.flowClock.advance(to: now, speed: ctx["flow"]), finger: finger,
                        strength: ctx["pull"] * model.pointer.strength(idle: 0.55), presence: model.pointer.presence,
                        lines: max(ctx.int("lines"), 2), repel: ctx.bool("repel")
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
        .backgroundsHint(L("Swipe sideways to bring a third pole", "横向滑动带来第三个磁极"), ctx)
    }
}

private enum MagneticPainter {
    static let softening: Double = 60

    static func field(at p: CGPoint, charges: [MagneticCharge]) -> CGVector {
        var ex = 0.0
        var ey = 0.0
        for charge in charges {
            let dx = Double(p.x - charge.position.x)
            let dy = Double(p.y - charge.position.y)
            let k = charge.q / (dx * dx + dy * dy + softening)
            ex += dx * k
            ey += dy * k
        }
        return CGVector(dx: ex, dy: ey)
    }

    static func direction(at p: CGPoint, charges: [MagneticCharge]) -> CGVector? {
        let e = field(at: p, charges: charges)
        let length = hypot(e.dx, e.dy)
        guard length > 1e-9 else { return nil }
        return CGVector(dx: e.dx / length, dy: e.dy / length)
    }

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, flow: Double, finger: CGPoint, strength: Double,
        presence: Double, lines: Int, repel: Bool
    ) {
        let north = CGPoint(
            x: size.width * 0.25 + CGFloat(cos(t * 0.31)) * 10,
            y: size.height * 0.42 + CGFloat(sin(t * 0.31)) * 14
        )
        let south = CGPoint(
            x: size.width * 0.75 + CGFloat(cos(t * 0.27 + 2)) * 10,
            y: size.height * 0.58 + CGFloat(sin(t * 0.27 + 2)) * 14
        )
        var charges = [MagneticCharge(position: north, q: 1), MagneticCharge(position: south, q: -1)]
        if strength > 0.01 {
            charges.append(MagneticCharge(position: finger, q: repel ? strength : -strength))
        }
        let sinks = charges.filter { $0.q < 0 }.map(\.position)

        drawNeedles(&context, size: size, charges: charges)

        // Trace every line from the north pole (and from the finger when it repels).
        var all = Path()
        let step: CGFloat = 5
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -90, dy: -90)
        var sources: [(CGPoint, Int)] = [(north, lines)]
        if repel, strength > 0.01 { sources.append((finger, max(Int(Double(lines) * 0.4 * min(strength, 1.5)), 4))) }
        for (source, count) in sources {
            for i in 0..<count {
                let angle = (Double(i) + 0.5) / Double(count) * BackgroundMath.tau
                var p = CGPoint(x: source.x + CGFloat(cos(angle)) * 11, y: source.y + CGFloat(sin(angle)) * 11)
                all.move(to: p)
                for _ in 0..<170 {
                    guard let d1 = direction(at: p, charges: charges) else { break }
                    let mid = CGPoint(x: p.x + d1.dx * step / 2, y: p.y + d1.dy * step / 2)
                    guard let d2 = direction(at: mid, charges: charges) else { break }
                    p = CGPoint(x: p.x + d2.dx * step, y: p.y + d2.dy * step)
                    if let sink = sinks.first(where: { hypot($0.x - p.x, $0.y - p.y) < 9 }) {
                        all.addLine(to: sink)
                        break
                    }
                    all.addLine(to: p)
                    if !bounds.contains(p) { break }
                }
            }
        }

        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(hex: 0xFF8A6B), Color(hex: 0xB07CFF), Color(hex: 0x4FC3FF)]),
            startPoint: north, endPoint: south
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.blendMode = .plusLighter
            layer.opacity = 0.55
            layer.stroke(all, with: shading, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
        }
        context.drawLayer { layer in
            layer.opacity = 0.62
            layer.stroke(all, with: shading, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
        // Light streaming along the lines, north to south.
        let phase = CGFloat(-(flow * 40).truncatingRemainder(dividingBy: 29))
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.stroke(all, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 26], dashPhase: phase))
        }

        drawPole(&context, at: north, color: Color(hex: 0xFF7A5C), label: "N")
        drawPole(&context, at: south, color: Color(hex: 0x3AC4FF), label: "S")
        if strength > 0.01 {
            let alpha = 0.45 + 0.55 * presence
            let tint = repel ? Color(hex: 0xFFB36B) : Color(hex: 0xB896FF)
            context.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.backgroundsGlow(at: finger, radius: 34, color: tint.opacity(0.5 * alpha))
            }
            context.stroke(Path(ellipseIn: CGRect(x: finger.x - 9, y: finger.y - 9, width: 18, height: 18)), with: .color(tint.opacity(alpha)), lineWidth: 1.6)
            context.fill(Path(ellipseIn: CGRect(x: finger.x - 2.5, y: finger.y - 2.5, width: 5, height: 5)), with: .color(.white.opacity(alpha)))
        }
    }

    private static func drawPole(_ context: inout GraphicsContext, at p: CGPoint, color: Color, label: String) {
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.backgroundsGlow(at: p, radius: 46, color: color.opacity(0.6))
        }
        let disc = CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)
        context.fill(
            Path(ellipseIn: disc),
            with: .radialGradient(Gradient(colors: [.white, color]), center: CGPoint(x: p.x - 3, y: p.y - 4), startRadius: 0, endRadius: 15)
        )
        context.draw(
            Text(label).font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: 0x10122E)),
            at: p
        )
    }

    /// A lattice of compass needles aligned with the local field.
    private static func drawNeedles(_ context: inout GraphicsContext, size: CGSize, charges: [MagneticCharge]) {
        var needles = Path()
        let pitch: CGFloat = 22
        let cols = Int(size.width / pitch) + 1
        let rows = Int(size.height / pitch) + 1
        let ox = (size.width - CGFloat(cols - 1) * pitch) / 2
        let oy = (size.height - CGFloat(rows - 1) * pitch) / 2
        for row in 0..<rows {
            for col in 0..<cols {
                let p = CGPoint(x: ox + CGFloat(col) * pitch, y: oy + CGFloat(row) * pitch)
                guard let d = direction(at: p, charges: charges) else { continue }
                needles.move(to: CGPoint(x: p.x - d.dx * 4, y: p.y - d.dy * 4))
                needles.addLine(to: CGPoint(x: p.x + d.dx * 4, y: p.y + d.dy * 4))
            }
        }
        context.stroke(needles, with: .color(Color(hex: 0x8FA0FF).opacity(0.2)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }
}
