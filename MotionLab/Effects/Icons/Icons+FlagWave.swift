import SwiftUI

extension Effect {
    static let iconsFlagWave = Effect(
        id: "icons.flag-wave",
        category: .icons,
        interaction: .tap,
        name: L("Flag Wave", "旗帜飘扬"),
        summary: L("A limp flag is hoisted up its pole, catches the wind and waves with a ripple that travels from the pole to the free edge.", "垂着的旗帜沿旗杆升起，迎风展开，波纹从旗杆一路传到旗尾。"),
        prompt: L(
            "A slim pole with a gold finial; an orange flag with a white stripe hangs limp at its foot, drooping and narrowed to 55%. On tap the flag is hoisted to the top on a spring (response 0.6 s, damping 0.8). From 0.25 s it unfurls (response 0.5 s, damping 0.6): the droop lifts, the cloth reaches full width, and a gust swells the wave to about double before decaying over a second while the pole sways 1.5°. Raised, it waves continuously: a sine ripple travels from the pole outward at 1.5× speed, 1.2 wavelengths across the cloth, its 8 pt amplitude growing toward the free edge. The cloth is shaded by slope, lighter on faces turned to the light and darker in the folds. Tapping again lets it go limp in 0.35 s and slide down in 0.5 s. A soft haptic marks the top.",
            "一根细旗杆，顶端是金色圆球；一面带白条纹的橙色旗帜垂在杆脚，下垂并收窄到55%。点击后旗帜以弹簧（响应0.6秒、阻尼0.8）升到杆顶。0.25秒起旗面展开（响应0.5秒、阻尼0.6）：下垂抬平，布面伸到全宽，一阵风把波幅鼓到约两倍再用一秒衰减，旗杆摆动1.5°。升起后旗帜持续飘扬：正弦波纹以1.5倍速从旗杆向外传播，旗面上约1.2个波长，8 pt的波幅越靠旗尾越大。布面按坡度着色，迎光面亮、褶皱处暗。再次点击，旗面在0.35秒内垂下并用0.5秒滑落。升到顶时配柔和触感。"
        ),
        implementation: L(
            "A Canvas samples the cloth's top edge at 29 points along a travelling sine with an amplitude envelope, fills the outline, then shades it with a horizontal gradient whose stops come from the wave's slope. A two-state play head drives the hoist, unfurl and gust, and a rate-continuous phase clock keeps the ripple smooth when the wind slider moves.",
            "Canvas 沿一条带振幅包络的行进正弦波对旗面上缘取29个采样点，填充轮廓后，再用一条按波的坡度生成色标的水平渐变着色。双状态播放头驱动升旗、展开与阵风；速率连续的相位时钟让风速滑块拖动时波纹依然平滑。"
        ),
        apis: ["Canvas", "TimelineView(.animation)", "GraphicsContext.fill", "Path", "rotationEffect"],
        tags: ["flag", "wave", "cloth", "ripple", "wind", "旗帜", "飘扬", "布料", "波纹", "标记"],
        params: [
            .slider("speed", L("Wind speed", "风速"), 0.4...3.0, default: 1.5, unit: "×"),
            .slider("amplitude", L("Wave height", "波幅"), 2...16, default: 8, decimals: 0, unit: "pt"),
            .slider("waves", L("Wavelengths", "波长数"), 0.6...2.2, default: 1.2),
        ]
    ) { ctx in
        IconsFlagWaveDemo(ctx: ctx)
    }
}

private struct IconsFlagWaveDemo: View {
    let ctx: DemoContext
    /// On = raised.
    @State private var play = IconsPlayhead(isOn: false)
    @State private var wind = IconsPhaseClock()

    var body: some View {
        let raised: Bool = ctx.isStill ? true : play.isOn
        VStack(spacing: 10) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsFlagScene(
                    raised: raised,
                    t: ctx.isStill ? 100 : play.elapsed(at: date),
                    phase: ctx.isStill ? 1.2 : wind.phase(at: date, rate: ctx["speed"] * 4.2),
                    amplitude: ctx["amplitude"],
                    waves: ctx["waves"]
                )
            }
            .frame(width: 250, height: 214)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            Text(raised ? L("Flagged", "已标记") : L("Not flagged", "未标记"), ctx.language)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: raised)
            DemoHint(text: L("Tap to raise or lower the flag", "点击升起或降下旗帜"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.8) { toggle() }
        .onChange(of: ctx["speed"]) { old, _ in wind.rebase(oldRate: old * 4.2) }
    }

    private func toggle() {
        play.toggle(onDuration: 1.3, offDuration: 0.6)
        Haptics.tap(.light)
        if play.isOn {
            IconsHaptics.later(0.42, preview: ctx.isPreview) { Haptics.tap(.soft) }
        }
    }
}

private struct IconsFlagScene: View {
    let raised: Bool
    let t: Double
    let phase: Double
    let amplitude: Double
    let waves: Double

    private static let poleX: CGFloat = 62
    private static let poleTop: CGFloat = 22
    private static let poleBottom: CGFloat = 190
    private static let cloth = CGSize(width: 126, height: 74)

    /// 0 = at the foot of the pole, 1 = at the top.
    private var hoist: Double {
        if raised { return IconsCurve.spring(t, response: 0.6, damping: 0.8) }
        return 1 - IconsCurve.easeInOut(IconsCurve.seg(t, 0.1, 0.6))
    }

    /// 0 = limp, 1 = flying.
    private var unfurl: Double {
        if raised { return IconsCurve.spring(t - 0.25, response: 0.5, damping: 0.6) }
        return 1 - IconsCurve.easeInOut(IconsCurve.seg(t, 0, 0.35))
    }

    private var gust: Double {
        guard raised, t > 0.3 else { return 0 }
        return exp(-2.6 * (t - 0.3))
    }

    var body: some View {
        let sway: Double = raised ? 1.5 * IconsCurve.shake(t - 0.3, decay: 3, frequency: 9) : 0
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.16))
                .frame(width: 96, height: 12)
                .blur(radius: 6)
                .position(x: Self.poleX + 14, y: Self.poleBottom + 6)
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0xB9BBC9), Color(hex: 0x8C8FA3)], startPoint: .top, endPoint: .bottom))
                .frame(width: 44, height: 14)
                .position(x: Self.poleX, y: Self.poleBottom + 1)
            ZStack {
                clothCanvas
                pole
            }
            .rotationEffect(.degrees(sway), anchor: UnitPoint(x: Self.poleX / 250, y: Self.poleBottom / 214))
        }
        .frame(width: 250, height: 214)
    }

    private var pole: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xE3E4EC), Color(hex: 0x9EA1B4)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 7, height: Self.poleBottom - Self.poleTop)
                .position(x: Self.poleX, y: (Self.poleTop + Self.poleBottom) / 2)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFE9A0), Color(hex: 0xF0A92A)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 9))
                .frame(width: 15, height: 15)
                .shadow(color: Palette.amber.opacity(0.5), radius: 5)
                .position(x: Self.poleX, y: Self.poleTop - 4)
        }
    }

    private var clothCanvas: some View {
        let lift: Double = hoist
        let open: Double = unfurl
        let flying: Double = IconsCurve.unit(open)
        let swell: Double = 1 + 1.1 * gust
        let amp: Double = amplitude * flying * swell
        let wavelengths: Double = waves
        let now: Double = phase
        return Canvas { context, _ in
            let size: CGSize = Self.cloth
            let top: Double = IconsCurve.mix(Double(Self.poleBottom - size.height) - 30, Double(Self.poleTop) + 8, lift)
            let width: Double = Double(size.width) * (0.55 + 0.45 * open)
            let droop: Double = 24 * (1 - flying)
            let slices: Int = 28
            let originX: Double = Double(Self.poleX) + 3

            // The top edge: the wave grows from nothing at the pole to its full height at the free edge.
            var edge: [CGPoint] = []
            var heights: [Double] = []
            var stops: [Gradient.Stop] = []
            for index in 0...slices {
                let u: Double = Double(index) / Double(slices)
                let envelope: Double = pow(u, 0.8)
                let angle: Double = u * wavelengths * 2 * .pi - now
                let sag: Double = droop * pow(u, 1.4) + 2.5 * sin(now * 0.5) * u * (1 - flying)
                edge.append(CGPoint(x: originX + width * u, y: top + amp * envelope * sin(angle) + sag))
                // The free edge is a little shorter, as cloth pulled by the wind is.
                heights.append(Double(size.height) * (1 - 0.06 * u))
                // Shade by slope: faces turned to the light brighten, the folds darken.
                let light: Double = cos(angle) * envelope * flying * min(amp / 8, 1.6)
                let shade: Color = light > 0 ? Color.white.opacity(0.3 * light) : Color(hex: 0x7A1F00).opacity(-0.4 * light)
                stops.append(Gradient.Stop(color: shade, location: CGFloat(u)))
            }

            func band(_ from: Double, _ to: Double) -> Path {
                var path = Path()
                for index in 0...slices {
                    let point = CGPoint(x: edge[index].x, y: edge[index].y + heights[index] * from)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                for index in stride(from: slices, through: 0, by: -1) {
                    path.addLine(to: CGPoint(x: edge[index].x, y: edge[index].y + heights[index] * to))
                }
                path.closeSubpath()
                return path
            }

            let cloth: Path = band(0, 1)
            context.fill(cloth, with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFF8A4A), Color(hex: 0xF5622A)]),
                startPoint: CGPoint(x: originX, y: top),
                endPoint: CGPoint(x: originX, y: top + Double(size.height))
            ))
            context.fill(band(0.38, 0.62), with: .color(.white.opacity(0.95)))
            context.fill(cloth, with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: originX, y: top),
                endPoint: CGPoint(x: originX + width, y: top)
            ))

            // The sleeve where the cloth meets the pole.
            var sleeve = Path()
            sleeve.addRoundedRect(in: CGRect(x: originX - 4, y: top - 2, width: 5, height: Double(size.height) + 4), cornerSize: CGSize(width: 2.5, height: 2.5))
            context.fill(sleeve, with: .color(Color(hex: 0xD9571F)))
        }
        .frame(width: 250, height: 214)
        .shadow(color: Color(hex: 0xFF7A3D).opacity(0.3), radius: 10, y: 6)
    }
}
