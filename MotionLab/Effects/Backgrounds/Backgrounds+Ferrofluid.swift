import SwiftUI

extension Effect {
    static let backgroundsFerrofluid = Effect(
        id: "backgrounds.ferrofluid",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Ferrofluid", "磁流体"),
        summary: L(
            "A glossy black drop of ferrofluid bristles into spikes that reach for your finger like a magnet.",
            "一滴乌黑发亮的磁流体，手指像磁铁一样靠近时，它会竖起尖刺迎上来。"
        ),
        prompt: L(
            "A glossy, jet-black drop of ferrofluid (80 pt radius) rests on a softly lit steel-blue dish, its edge breathing by a few points. The finger is a magnet. As it approaches, 24 cone-shaped spikes up to 46 pt long erupt on the side facing it, tallest on the axis and shrinking with cos^1.2 of the angle; the whole drop leans 14 pt toward the magnet and bulges 16% on that side while its body shrinks 10% to keep its volume. Magnet position and field strength both ride underdamped springs (stiffness 90 and 120, damping 0.32), so spikes overshoot when the magnet arrives, sway as it moves and collapse with a jelly-like ring-down when it leaves. With the finger directly over the drop the spikes spread into a full crown. Rim light, a soft specular and a thin highlight on every spike sell the liquid metal. Alien, magnetic, alive.",
            "一滴乌黑发亮的磁流体（半径 80pt）静卧在柔光照亮的钢蓝色浅盘上。手指就是磁铁：靠近时，朝向它的一侧迸出 24 根最长 46pt 的锥形尖刺，轴线上最高，随夹角按 cos^1.2 递减；液滴向磁铁倾斜 14pt，该侧鼓出 16%，本体收缩 10% 以保持体积。磁铁位置与磁场强度都由欠阻尼弹簧驱动（刚度 90 与 120，阻尼 0.32），所以尖刺在磁铁到来时过冲，移动时摇摆，离开时像果冻一样余振着塌回。手指悬在液滴正上方时，尖刺展开成一圈完整的冠。边缘光与尖刺上的细亮线做足金属质感。带磁性、仿佛活物。"
        ),
        implementation: L(
            "The outline is a polar curve r(θ) sampled 540 times: base radius + directional bulge + envelope × a raised-cosine spike profile whose phase tracks the magnet angle. Two springs integrated per frame drive it; a Canvas fills, clips and lights the Path.",
            "轮廓是一条采样 540 次的极坐标曲线 r(θ)：基础半径 + 方向性鼓起 + 包络 × 升余弦尖刺剖面，剖面相位跟随磁铁方向。两个逐帧积分的弹簧驱动它；Canvas 负责填充、裁剪并为这条 Path 打光。"
        ),
        apis: ["Canvas", "Path", "GraphicsContext.clip(to:)", "TimelineView(.animation)", "DragGesture", "Haptics"],
        tags: ["ferrofluid", "magnet", "spikes", "liquid metal", "磁流体", "磁铁", "尖刺", "液态金属"],
        params: [
            .slider("spikes", L("Spikes", "尖刺数量"), 10...44, default: 24, step: 1, decimals: 0),
            .slider("length", L("Spike length", "尖刺长度"), 10...70, default: 46, decimals: 0, unit: "pt"),
            .slider("damping", L("Damping", "阻尼"), 0.15...1.0, default: 0.32),
            .slider("size", L("Drop size", "液滴大小"), 48...100, default: 80, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        FerrofluidDemo(ctx: ctx)
    }
}

private final class FerroModel {
    private var last: Double?
    var touch: CGPoint?
    var userTouched = false
    private(set) var magnet = CGPoint(x: 260, y: 90)
    private var magnetVelocity = CGVector.zero
    private(set) var strength: CGFloat = 0
    private var strengthVelocity: CGFloat = 0
    private(set) var engaged = false
    private var seeded = false

    func step(now: Double, size: CGSize, damping: CGFloat, simulate: Bool, frozen: Bool) {
        if frozen {
            magnet = CGPoint(x: size.width * 0.8, y: size.height * 0.26)
            strength = 1
            engaged = true
            return
        }
        var dt = 1.0 / 60.0
        if let last = last { dt = min(max(now - last, 0), 1.0 / 30.0) }
        last = now
        let h = CGFloat(dt)

        var target = magnet
        var wanted: CGFloat = 0
        if let touch {
            target = touch
            wanted = 1
        } else if simulate {
            // A ghost magnet circles the drop and switches on and off.
            let angle = now * 0.7
            let radius = 0.36 + 0.08 * sin(now * 1.3)
            target = CGPoint(
                x: size.width * CGFloat(0.5 + radius * cos(angle)),
                y: size.height * CGFloat(0.47 + radius * sin(angle))
            )
            wanted = CGFloat(min(max(0.75 + 1.4 * sin(now * 0.8), 0), 1))
        }
        engaged = wanted > 0.05
        if !seeded {
            seeded = true
            magnet = target
        }
        (magnet, magnetVelocity) = BackgroundMath.spring(value: magnet, velocity: magnetVelocity, target: target, stiffness: 90, damping: damping, dt: h)
        let c = 2 * CGFloat(120).squareRoot() * damping
        strengthVelocity += (120 * (wanted - strength) - c * strengthVelocity) * h
        strength += strengthVelocity * h
    }
}

private struct FerrofluidDemo: View {
    let ctx: DemoContext
    @State private var model = FerroModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2A3346), Color(hex: 0x151A26), Color(hex: 0x0A0C12)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    model.step(
                        now: now, size: size, damping: ctx.cg("damping"),
                        simulate: ctx.isPreview || !model.userTouched, frozen: ctx.isStill
                    )
                    FerroPainter.draw(
                        &context, size: size, t: now.truncatingRemainder(dividingBy: 1000),
                        magnet: model.magnet, strength: model.strength, engaged: model.engaged,
                        spikes: max(ctx.int("spikes"), 3), length: ctx.cg("length"), radius: ctx.cg("size")
                    )
                }
            }
        }
        .backgroundsTouch { location in
            if model.touch == nil { Haptics.tap(.soft) }
            model.userTouched = true
            model.touch = location
        } onEnded: {
            model.touch = nil
        }
        .backgroundsHint(L("Tap or swipe sideways: your finger is the magnet", "点击或横向滑动：手指就是磁铁"), ctx)
    }
}

private enum FerroPainter {
    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, magnet: CGPoint, strength: CGFloat, engaged: Bool,
        spikes: Int, length: CGFloat, radius: CGFloat
    ) {
        let home = CGPoint(x: size.width / 2, y: size.height * 0.47)
        let mx = magnet.x - home.x
        let my = magnet.y - home.y
        let distance = max(hypot(mx, my), 0.001)
        let phi = Double(atan2(my, mx))
        let pull = strength * (1.35 - distance / 260).clamped(to: 0.25...1)
        let focus = CGFloat(BackgroundMath.smoothstep(Double(radius) * 0.4, Double(radius) * 1.6, Double(distance)))
        let centre = CGPoint(x: home.x + mx / distance * 14 * pull * focus, y: home.y + my / distance * 14 * pull * focus)
        let body = radius * (1 - 0.1 * max(pull, 0))

        func radiusAt(_ theta: Double) -> CGFloat {
            let facing = cos(theta - phi)
            let directional = CGFloat(pow(max(facing, 0), 1.2))
            let envelope = max(pull, -0.2) * ((1 - focus) * 0.6 + focus * directional)
            let bulge = 1 + 0.16 * pull * focus * CGFloat(facing)
            let breathing = 2.4 * CGFloat(sin(3 * theta + t * 0.9)) + 1.4 * CGFloat(sin(5 * theta - t * 1.3))
            let profile = CGFloat(pow(0.5 + 0.5 * cos(Double(spikes) * (theta - phi)), 2.4))
            return body * bulge + breathing + length * envelope * profile
        }

        var outline = Path()
        let samples = 540
        for i in 0..<samples {
            let theta = Double(i) / Double(samples) * BackgroundMath.tau
            let r = radiusAt(theta)
            let p = CGPoint(x: centre.x + r * CGFloat(cos(theta)), y: centre.y + r * CGFloat(sin(theta)))
            if i == 0 { outline.move(to: p) } else { outline.addLine(to: p) }
        }
        outline.closeSubpath()

        // The lit dish under the drop.
        let dishRadius = min(size.width, size.height) * 0.62
        let dish = Gradient(stops: [
            .init(color: Color(hex: 0x8FA6D6).opacity(0.62), location: 0),
            .init(color: Color(hex: 0x5C6F9C).opacity(0.3), location: 0.55),
            .init(color: Color(hex: 0x5C6F9C).opacity(0), location: 1),
        ])
        context.fill(
            Path(ellipseIn: CGRect(x: home.x - dishRadius, y: home.y - dishRadius, width: dishRadius * 2, height: dishRadius * 2)),
            with: .radialGradient(dish, center: home, startRadius: 0, endRadius: dishRadius)
        )

        // Magnet marker: a faint ring that pulses while the field is on.
        if engaged {
            let pulse = CGFloat(0.5 + 0.5 * sin(t * 4))
            let r = 15 + 3 * pulse
            context.stroke(
                Path(ellipseIn: CGRect(x: magnet.x - r, y: magnet.y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.16 + 0.12 * Double(pulse))), lineWidth: 1.2
            )
        }

        // Contact shadow.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            layer.translateBy(x: 0, y: 12)
            layer.fill(outline, with: .color(.black.opacity(0.55)))
        }

        let lightPoint = CGPoint(x: centre.x - body * 0.45, y: centre.y - body * 0.5)
        let fill = Gradient(stops: [
            .init(color: Color(hex: 0x353B4C), location: 0),
            .init(color: Color(hex: 0x0D0E14), location: 0.5),
            .init(color: .black, location: 1),
        ])
        context.fill(outline, with: .radialGradient(fill, center: lightPoint, startRadius: 0, endRadius: body * 1.5))

        context.drawLayer { layer in
            layer.clip(to: outline)
            // Soft specular.
            layer.drawLayer { soft in
                soft.addFilter(.blur(radius: 9))
                let w = body * 0.5
                let hgt = body * 0.26
                let spot = Path(ellipseIn: CGRect(x: -w, y: -hgt, width: w * 2, height: hgt * 2))
                    .applying(CGAffineTransform(translationX: lightPoint.x, y: lightPoint.y).rotated(by: -0.6))
                soft.fill(spot, with: .color(.white.opacity(0.5)))
            }
            // Rim light: cool from the top-left, a warm bounce from below.
            let rim = Gradient(stops: [
                .init(color: Color(hex: 0xBFD0FF).opacity(0.9), location: 0),
                .init(color: Color(hex: 0xBFD0FF).opacity(0), location: 0.45),
                .init(color: Color(hex: 0xFF9BD6).opacity(0), location: 0.7),
                .init(color: Color(hex: 0xFF9BD6).opacity(0.4), location: 1),
            ])
            let span = body + length
            layer.stroke(
                outline,
                with: .linearGradient(
                    rim,
                    startPoint: CGPoint(x: centre.x - span, y: centre.y - span),
                    endPoint: CGPoint(x: centre.x + span, y: centre.y + span)
                ),
                lineWidth: 2.4
            )
        }
        // Crisp glint.
        let glint = Path(ellipseIn: CGRect(x: -body * 0.16, y: -body * 0.05, width: body * 0.32, height: body * 0.1))
            .applying(CGAffineTransform(translationX: lightPoint.x + body * 0.04, y: lightPoint.y - body * 0.04).rotated(by: -0.6))
        context.fill(glint, with: .color(.white.opacity(0.75)))

        // One thin highlight along the lit side of every spike.
        var lines = Path()
        let lightAngle = -Double.pi * 0.75
        for k in 0..<spikes {
            let theta = phi + Double(k) / Double(spikes) * BackgroundMath.tau
            let tip = radiusAt(theta)
            let base = body * (1 + 0.16 * pull * focus * CGFloat(cos(theta - phi)))
            let height = tip - base
            guard height > 5 else { continue }
            // Shift the streak toward the light.
            let side = sin(lightAngle - theta) > 0 ? 0.07 : -0.07
            let a = theta + side * 2.2 / Double(spikes) * 12
            let from = base + height * 0.12
            let to = base + height * 0.86
            lines.move(to: CGPoint(x: centre.x + from * CGFloat(cos(a)), y: centre.y + from * CGFloat(sin(a))))
            lines.addLine(to: CGPoint(x: centre.x + to * CGFloat(cos(theta)), y: centre.y + to * CGFloat(sin(theta))))
        }
        context.stroke(lines, with: .color(Color(hex: 0xD6E0FF).opacity(0.5)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }
}
