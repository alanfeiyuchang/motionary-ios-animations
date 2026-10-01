import SwiftUI

extension Effect {
    static let backgroundsSilkFolds = Effect(
        id: "backgrounds.silk-folds",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Silk Folds", "丝绸褶皱"),
        summary: L(
            "A sheet of silk in slow motion: folds drift and merge, a soft specular band rides every crest, and the cloth gathers under your finger.",
            "一匹慢动作的丝绸：褶皱缓缓游移、汇合，每道隆起都托着一条柔和的高光，布料还会向手指处聚拢。"
        ),
        prompt: L(
            "A full-bleed sheet of champagne silk lit from one side. Diagonal folds run at −24° across the frame; the surface is a main fold train about 125 pt apart with a half-wavelength harmonic, crossed by a finer, slightly skewed train near 70 pt; their phases meander slowly along the fold direction, so folds drift, pinch and merge like fabric moved by air, and fold depth swells and relaxes across the sheet. Shading comes from the surface slope: slopes facing the light are pale, slopes facing away fall into warm shadow, and a narrow satin highlight sits where the slope reaches 0.62 of its maximum, with a dimmer back-sheen on the far side. A finger gathers the cloth: fold phase is pulled by up to 2.6 rad inside a soft 100 pt region that follows the touch on a spring (stiffness 40, damping 0.75), then relaxes. Luxurious, weightless, slow.",
            "铺满画面的香槟色丝绸，侧光。褶皱沿 −24° 斜向排布；表面是间距约 125pt 的主褶加半波长谐波，再叠上一组约 70pt、略微偏斜的细褶；相位沿褶皱方向缓慢蜿蜒，褶皱像被气流拂动般游移、收拢、汇合，褶深也在布面上起伏。明暗取自表面斜率：迎光面浅亮，背光面沉入暖色阴影；斜率达最大值 0.62 处有一条窄窄的缎面高光，另一侧还有更暗的背光泽。手指会把布料聚拢：在约 100pt 的柔和范围内，褶皱相位最多被拉动 2.6 弧度，该范围以弹簧（刚度 40、阻尼 0.75）跟随触点，松手后舒展。华贵、轻盈。"
        ),
        implementation: L(
            "A rotated Canvas draws 2.5 pt strips along the fold direction; each strip is one linear gradient whose 96 stops are shaded from the analytic slope of the layered-sine height field at that strip, so the whole sheet costs about 190 gradient fills per frame.",
            "旋转后的 Canvas 沿褶皱方向绘制 2.5pt 宽的条带；每条是一个线性渐变，96 个色标由多层正弦高度场在该处的解析斜率着色，整匹布每帧约 190 次渐变填充。"
        ),
        apis: ["Canvas", "GraphicsContext.Shading.linearGradient", "TimelineView(.animation)", "DragGesture", "GraphicsContext.rotate(by:)"],
        tags: ["silk", "fabric", "folds", "satin", "丝绸", "绸缎", "褶皱", "布料"],
        params: [
            .slider("folds", L("Fold density", "褶皱密度"), 0.5...2.0, default: 1.0, unit: "×"),
            .slider("speed", L("Drift speed", "流动速度"), 0.2...3.0, default: 1.0, unit: "×"),
            .slider("sheen", L("Sheen", "光泽"), 0...1, default: 0.7),
            .choice("tone", L("Silk", "绸色"), [L("Champagne", "香槟"), L("Rose", "玫瑰"), L("Emerald", "祖母绿"), L("Midnight", "午夜蓝")]),
        ]
    ) { ctx in
        SilkFoldsDemo(ctx: ctx)
    }
}

private struct SilkTone {
    let shadow: BackgroundRGB
    let mid: BackgroundRGB
    let light: BackgroundRGB
    let highlight: BackgroundRGB

    static let all: [SilkTone] = [
        SilkTone(shadow: .init(hex: 0x7A5A3C), mid: .init(hex: 0xD9BE98), light: .init(hex: 0xF4E4C8), highlight: .init(hex: 0xFFFBF0)),
        SilkTone(shadow: .init(hex: 0x6E1F3C), mid: .init(hex: 0xD4577E), light: .init(hex: 0xF5A3B8), highlight: .init(hex: 0xFFEDF2)),
        SilkTone(shadow: .init(hex: 0x05382C), mid: .init(hex: 0x14846A), light: .init(hex: 0x4FC9A4), highlight: .init(hex: 0xE4FFF4)),
        SilkTone(shadow: .init(hex: 0x070B2A), mid: .init(hex: 0x1E2E7A), light: .init(hex: 0x4C68D0), highlight: .init(hex: 0xDCE6FF)),
    ]
}

private final class SilkModel {
    let clock = BackgroundClock()
    let pointer = BackgroundPointer()
}

private struct SilkFoldsDemo: View {
    let ctx: DemoContext
    @State private var model = SilkModel()

    var body: some View {
        let tone = SilkTone.all[min(max(ctx.int("tone"), 0), SilkTone.all.count - 1)]
        ZStack {
            tone.mid.color()
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let t = model.clock.advance(to: now, speed: ctx["speed"])
                    let idle = CGPoint(
                        x: size.width * CGFloat(0.5 + 0.3 * sin(t * 0.21)),
                        y: size.height * CGFloat(0.5 + 0.26 * sin(t * 0.33 + 1.2))
                    )
                    let finger = model.pointer.step(now: now, idle: idle, stiffness: 40, damping: 0.75, frozen: ctx.isStill)
                    SilkPainter.draw(
                        &context, size: size, t: t, tone: tone, folds: max(ctx["folds"], 0.1), sheen: ctx["sheen"],
                        finger: finger, pull: 2.6 * model.pointer.strength(idle: 0.45)
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
        .backgroundsChipHint(L("Swipe sideways to gather the silk", "横向滑动把丝绸聚拢"), ctx)
    }
}

private enum SilkPainter {
    static let angle: CGFloat = -24 * .pi / 180

    static func draw(
        _ context: inout GraphicsContext, size: CGSize, t: Double, tone: SilkTone, folds: Double, sheen: Double,
        finger: CGPoint, pull: Double
    ) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let reach = hypot(size.width, size.height) / 2 + 6
        // The finger in fabric space (u across the folds, v along them).
        let dx = finger.x - centre.x
        let dy = finger.y - centre.y
        let fu = Double(dx * cos(-angle) - dy * sin(-angle))
        let fv = Double(dx * sin(-angle) + dy * cos(-angle))

        var fabric = context
        fabric.translateBy(x: centre.x, y: centre.y)
        fabric.rotate(by: .radians(Double(angle)))

        let step: CGFloat = 2.5
        let samples = 96
        let rows = Int((reach * 2 / step).rounded(.up))
        let unit = 340.0
        for row in 0..<rows {
            let v = -reach + CGFloat(row) * step
            let vn = Double(v) / unit
            // Fold phases meander along the fold direction, so folds drift, widen and merge.
            let w1 = 1.1 * sin(vn * 1.9 + t * 0.21) + 0.6 * sin(vn * 4.3 - t * 0.16 + 1.3) + t * 0.1
            let w2 = 0.9 * sin(vn * 2.6 + t * 0.2)
            let w3 = 3.0 * vn - 1.4 * sin(vn * 2.7 + t * 0.13 + 2.0) - t * 0.06
            let dv = (Double(v) - fv) / 100
            var stops: [Gradient.Stop] = []
            stops.reserveCapacity(samples + 1)
            for k in 0...samples {
                let f = Double(k) / Double(samples)
                let u = (f * 2 - 1) * Double(reach)
                let un = u / unit * folds
                let du = (u - fu) / 100
                let gather = pull * exp(-(du * du + dv * dv))
                let main = 17.0 * un + w1 + gather
                let slope = cos(main) + 0.35 * cos(2 * main + w2) + 0.4 * cos(31.0 * un + w3 - gather * 0.6)
                // Calm stretches between deep folds.
                let depth = 0.66 + 0.34 * sin(un * 2.3 + vn * 1.7 + t * 0.1)
                let n = min(max(slope / 1.3 * depth, -1), 1)
                let diffuse = pow(0.5 + 0.5 * n, 1.2)
                var color = diffuse < 0.5
                    ? tone.shadow.mix(tone.mid, BackgroundMath.smoothstep(0, 0.5, diffuse))
                    : tone.mid.mix(tone.light, BackgroundMath.smoothstep(0.5, 1, diffuse))
                // Satin highlight where the slope faces the light, and a dimmer back-sheen.
                let spec = pow(max(0, 1 - abs(n - 0.62) / 0.24), 2)
                let back = pow(max(0, 1 - abs(n + 0.8) / 0.2), 2) * 0.22
                color = color.mix(tone.highlight, min((spec + back) * sheen, 1) * 0.95)
                stops.append(.init(color: color.color(), location: CGFloat(f)))
            }
            fabric.fill(
                Path(CGRect(x: -reach, y: v, width: reach * 2, height: step + 0.7)),
                with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: -reach, y: 0), endPoint: CGPoint(x: reach, y: 0))
            )
        }

        // The sheet falls away toward the corners.
        let edge = Gradient(stops: [
            .init(color: .clear, location: 0.5),
            .init(color: tone.shadow.scaled(0.5).color(0.42), location: 1),
        ])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(edge, center: centre, startRadius: 0, endRadius: reach * 1.08)
        )
    }
}
