import SwiftUI

extension Effect {
    static let backgroundsHoloFoil = Effect(
        id: "backgrounds.holo-foil",
        category: .backgrounds,
        interaction: .gesture,
        name: L("Holographic Foil", "镭射箔面"),
        summary: L(
            "A sheet of holographic foil: rainbow bands slide and faceted glitter flashes as the light moves with your finger.",
            "一整面镭射箔纸：光源随手指移动，彩虹色带滑动，棱面闪粉依次闪亮。"
        ),
        prompt: L(
            "A full-bleed sheet of holographic foil on a pale silver-lilac base. Two layers of pastel rainbow bands (pink, gold, mint, sky, violet) cross it: the main one runs at 32° with a 120 pt period, the second at 12° with a 1.7× period, blended as soft light for a moiré shimmer. A virtual light follows the finger on an underdamped spring (stiffness 60, damping 0.55), and the bands slide by one full period per 190 pt of light travel, so colour chases the touch and overshoots slightly when it stops. On top, a 14 pt diamond lattice of facets glitters: each facet has its own random normal and flashes white only when the light passes its angle, with a sharp power-14 falloff. A broad specular sheen sits under the light. With no touch the light sweeps a slow figure-eight. Precious, tactile, collectible.",
            "铺满画面的镭射箔纸，底色是淡银紫。两层柔和的彩虹色带（粉、金、薄荷、天蓝、紫）交叠：主层沿 32° 排布、周期 120pt，第二层沿 12°、周期为 1.7 倍，以柔光混合出摩尔纹般的流光。虚拟光源由欠阻尼弹簧（刚度 60、阻尼 0.55）跟随手指，光源每移动 190pt 色带滑过一个周期，颜色追着手指走，停下时轻微过冲。上层是 14pt 的菱形棱面格：每个棱面有自己的随机法线，只有光扫过对应角度时才闪出白光，按 14 次幂急剧衰减。光源下方有一片宽阔的高光。无触摸时光源缓慢走 8 字。贵气，像收藏卡。"
        ),
        implementation: L(
            "A Canvas fills the stage with two repeating linear gradients whose start points slide along their axes with the light position, then appends lattice diamonds to four brightness Paths (plusLighter) from cos¹⁴ of each facet's angle against the light, plus a radial specular.",
            "Canvas 用两层重复线性渐变铺满舞台，渐变起点随光源位置沿各自轴线滑动；再按每个棱面角度与光源夹角的 cos¹⁴ 把菱形分入四条亮度 Path（plusLighter 叠加），并叠上一层径向高光。"
        ),
        apis: ["Canvas", "GraphicsContext.Shading.linearGradient", "blendMode(.softLight)", "TimelineView(.animation)", "DragGesture"],
        tags: ["holographic", "foil", "iridescent", "rainbow", "镭射", "全息", "彩虹", "箔面"],
        params: [
            .slider("band", L("Band width", "色带宽度"), 60...220, default: 120, decimals: 0, unit: "pt"),
            .slider("shift", L("Colour shift", "变色灵敏度"), 0.3...2.5, default: 1.0, unit: "×"),
            .slider("sparkle", L("Glitter", "闪粉"), 0...1, default: 0.65),
            .choice("pattern", L("Facets", "棱面"), [L("Diamonds", "菱格"), L("Stripes", "细条")]),
        ]
    ) { ctx in
        HoloFoilDemo(ctx: ctx)
    }
}

private final class HoloModel {
    private var last: Double?
    var touch: CGPoint?
    var userTouched = false
    private(set) var light = CGPoint(x: 170, y: 170)
    private var velocity = CGVector.zero
    private var seeded = false

    func step(now: Double, size: CGSize, frozen: Bool) {
        let idle = CGPoint(
            x: size.width * CGFloat(0.5 + 0.34 * sin(now * 0.55)),
            y: size.height * CGFloat(0.5 + 0.28 * sin(now * 1.1))
        )
        if frozen {
            light = CGPoint(x: size.width * 0.36, y: size.height * 0.34)
            return
        }
        let target = touch ?? idle
        if !seeded {
            seeded = true
            light = target
        }
        var dt = 1.0 / 60.0
        if let last = last { dt = min(max(now - last, 0), 1.0 / 30.0) }
        last = now
        (light, velocity) = BackgroundMath.spring(value: light, velocity: velocity, target: target, stiffness: 60, damping: 0.55, dt: CGFloat(dt))
    }
}

private struct HoloFoilDemo: View {
    let ctx: DemoContext
    @State private var model = HoloModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xE9E6F4), Color(hex: 0xC9CADF), Color(hex: 0xDDD3EA)], startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    model.step(now: now, size: size, frozen: ctx.isStill)
                    HoloFoilPainter.draw(
                        &context, size: size, light: model.light,
                        band: max(ctx.cg("band"), 20), shift: ctx.cg("shift"), sparkle: ctx["sparkle"], stripes: ctx.int("pattern") == 1
                    )
                }
            }
        }
        .backgroundsTouch { location in
            if !model.userTouched { Haptics.tap(.soft) }
            model.userTouched = true
            model.touch = location
        } onEnded: {
            model.touch = nil
        }
        // The foil is bright in both appearances, so the hint is dark ink on a frosted chip.
        .overlay(alignment: .bottom) {
            if !ctx.isPreview {
                Text(L("Swipe sideways to tilt the foil", "横向滑动让箔面变色"), ctx.language)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x2A1E55).opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.55), in: Capsule())
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
    }
}

private enum HoloFoilPainter {
    static let spectrum: [Color] = [
        Color(hex: 0xFF7AD9), Color(hex: 0xFFD27A), Color(hex: 0x86FFC0), Color(hex: 0x7AD6FF), Color(hex: 0xB896FF),
    ]

    static func draw(_ context: inout GraphicsContext, size: CGSize, light: CGPoint, band: CGFloat, shift: CGFloat, sparkle: Double, stripes: Bool) {
        let rect = Path(CGRect(origin: .zero, size: size))
        let travel = (light.x * 0.8 + light.y * 0.6) * shift / 190

        context.fill(rect, with: bands(size: size, angle: 32 * .pi / 180, period: band, phase: travel))
        context.drawLayer { layer in
            layer.blendMode = .softLight
            layer.opacity = 0.5
            layer.fill(rect, with: bands(size: size, angle: 12 * .pi / 180, period: band * 1.7, phase: -travel * 0.6))
        }

        // Broad sheen under the light.
        let reach = max(size.width, size.height) * 0.75
        let sheen = Gradient(stops: [
            .init(color: .white.opacity(0.7), location: 0),
            .init(color: .white.opacity(0.18), location: 0.45),
            .init(color: .white.opacity(0), location: 1),
        ])
        context.drawLayer { layer in
            layer.blendMode = .softLight
            layer.fill(rect, with: .radialGradient(sheen, center: light, startRadius: 0, endRadius: reach))
        }

        if sparkle > 0.001 {
            drawFacets(&context, size: size, light: light, sparkle: sparkle, stripes: stripes)
        }

        // Edge darkening so the sheet reads as a curved, glossy surface.
        let edge = Gradient(stops: [
            .init(color: .clear, location: 0.55),
            .init(color: Color(hex: 0x2A1E55).opacity(0.28), location: 1),
        ])
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        context.fill(rect, with: .radialGradient(edge, center: centre, startRadius: 0, endRadius: hypot(size.width, size.height) * 0.62))
    }

    /// A repeating pastel spectrum along `angle`; `phase` (in periods) slides it along its axis.
    private static func bands(size: CGSize, angle: CGFloat, period: CGFloat, phase: CGFloat) -> GraphicsContext.Shading {
        let diagonal = hypot(size.width, size.height)
        let repeats = Int((diagonal / period).rounded(.up)) + 3
        var stops: [Gradient.Stop] = []
        let n = spectrum.count
        for k in 0..<repeats {
            for j in 0..<n {
                let location = (CGFloat(k) + CGFloat(j) / CGFloat(n)) / CGFloat(repeats)
                stops.append(.init(color: spectrum[j].opacity(0.9), location: location))
            }
        }
        stops.append(.init(color: spectrum[0].opacity(0.9), location: 1))
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let length = CGFloat(repeats) * period
        let wrapped = phase - phase.rounded(.down)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let offset = -length / 2 + (wrapped - 1) * period + period
        let start = CGPoint(x: centre.x + direction.dx * (offset - period), y: centre.y + direction.dy * (offset - period))
        let end = CGPoint(x: start.x + direction.dx * length, y: start.y + direction.dy * length)
        return .linearGradient(Gradient(stops: stops), startPoint: start, endPoint: end)
    }

    private static func drawFacets(_ context: inout GraphicsContext, size: CGSize, light: CGPoint, sparkle: Double, stripes: Bool) {
        let levels = 4
        var bins = [Path](repeating: Path(), count: levels)
        let pitch: CGFloat = 14
        let cols = Int(size.width / pitch) + 2
        let rows = Int(size.height / (pitch / 2)) + 2
        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * 131 + col
                let cx = CGFloat(col) * pitch + (row % 2 == 0 ? 0 : pitch / 2)
                let cy = CGFloat(row) * pitch / 2
                // Each facet reflects the light only near its own angle.
                let normal = BackgroundMath.rand(index, 301) * BackgroundMath.tau
                let toLight = Double(atan2(light.y - cy, light.x - cx))
                let distance = Double(hypot(light.x - cx, light.y - cy))
                let facing = 0.5 + 0.5 * cos(normal - toLight * 2 + distance * 0.035)
                let flash = pow(facing, 14) * sparkle
                guard flash > 0.06 else { continue }
                let level = min(Int(flash * Double(levels)), levels - 1)
                if stripes {
                    let h = pitch * 0.22
                    bins[level].addRoundedRect(in: CGRect(x: cx - pitch * 0.42, y: cy - h / 2, width: pitch * 0.84, height: h), cornerSize: CGSize(width: h / 2, height: h / 2))
                } else {
                    let r = pitch * 0.4
                    bins[level].move(to: CGPoint(x: cx, y: cy - r / 2))
                    bins[level].addLine(to: CGPoint(x: cx + r, y: cy))
                    bins[level].addLine(to: CGPoint(x: cx, y: cy + r / 2))
                    bins[level].addLine(to: CGPoint(x: cx - r, y: cy))
                    bins[level].closeSubpath()
                }
            }
        }
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            for level in 0..<levels {
                let alpha = (Double(level) + 1) / Double(levels)
                layer.fill(bins[level], with: .color(.white.opacity(alpha * 0.75)))
            }
        }
    }
}
