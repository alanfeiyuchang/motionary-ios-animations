import SwiftUI

extension Effect {
    static let iconsSunMoon = Effect(
        id: "icons.sun-moon",
        category: .icons,
        interaction: .tap,
        name: L("Sun to Moon", "日月切换"),
        summary: L("Rays retract one by one as a shadow bites the sun into a crescent and stars pop out.", "光芒逐根收回，阴影把太阳咬成一弯月牙，星星随之蹦出。"),
        prompt: L(
            "A sun with eight short rays sits in a rounded sky-blue tile. On tap the rays retract clockwise one after another, 30 ms apart, each shrinking toward the disc over 0.22 s while the ray ring turns 60°. From 0.18 s a round shadow slides in from the upper right on a spring (response 0.5 s, damping 0.75) and bites the disc into a crescent as it grows to 122% and cools from amber to pale ivory; the tile cross-fades to deep indigo, the cloud drifts out and faint stars fade in. Three four-point stars pop beside the moon 90 ms apart with a bouncy overshoot, then keep twinkling. Tapping again shrinks the stars, pulls the shadow away and re-extends the rays in sequence, each overshooting its length before settling. Calm, like dusk falling in half a second.",
            "带八根短光芒的太阳位于天蓝色圆角方块中。点击后光芒按顺时针逐根收回，间隔30毫秒，每根用0.22秒缩向圆盘，光芒环同时转过60°。0.18秒起，一块圆形阴影以弹簧（响应0.5秒、阻尼0.75）从右上方滑入，把圆盘咬成月牙；圆盘放大到122%，由琥珀色冷却为淡象牙色。方块渐变为深靛蓝，云朵飘走，微弱星点浮现。三颗四角星在月亮旁相隔90毫秒弹出，带一点过冲，之后持续闪烁。再次点击时星星缩回，阴影移开，光芒依次重新伸出，每根先伸过头再回到原长。安静，像半秒内天色暗下。"
        ),
        implementation: L(
            "A two-state play head and a TimelineView give the seconds since the tap; rays, bite, tile colour and stars are staggered windows over that time. The crescent is the disc masked by a circle drawn with the destinationOut blend mode.",
            "双状态播放头加 TimelineView 给出点击后的秒数；光芒、咬合、底色与星星都是这段时间上错开的窗口。月牙是用 destinationOut 混合模式的圆对圆盘做的遮罩。"
        ),
        apis: ["TimelineView(.animation)", "mask", "blendMode(.destinationOut)", "compositingGroup()", "rotationEffect"],
        tags: ["dark mode", "theme", "sun", "moon", "toggle", "appearance", "深色模式", "主题", "太阳", "月亮", "切换", "外观"],
        params: [
            .slider("rays", L("Rays", "光芒数量"), 6...12, default: 8, step: 1, decimals: 0),
            .slider("stagger", L("Ray stagger", "光芒间隔"), 0...0.06, default: 0.03, unit: "s"),
            .slider("damping", L("Ray damping", "光芒阻尼"), 0.3...0.9, default: 0.5),
        ]
    ) { ctx in
        IconsSunMoonDemo(ctx: ctx)
    }
}

private struct IconsSunMoonDemo: View {
    let ctx: DemoContext
    @State private var play = IconsPlayhead(isOn: false)

    private static let nightDuration: Double = 0.9
    private var dayDuration: Double { 0.8 + Double(ctx.int("rays")) * ctx["stagger"] }

    var body: some View {
        VStack(spacing: 14) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsSunMoonScene(
                    night: play.isOn,
                    t: play.elapsed(at: date),
                    clock: ctx.isStill ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3_600),
                    rays: ctx.int("rays"),
                    stagger: ctx["stagger"],
                    damping: ctx["damping"]
                )
            }
            .frame(width: 210, height: 196)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            Text(play.isOn ? L("Dark appearance", "深色外观") : L("Light appearance", "浅色外观"), ctx.language)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: play.isOn)
            DemoHint(text: L("Tap to switch", "点击切换"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.0) { toggle() }
    }

    private func toggle() {
        play.toggle(onDuration: Self.nightDuration, offDuration: dayDuration)
        Haptics.tap(.light)
    }
}

private struct IconsSunMoonScene: View {
    let night: Bool
    let t: Double
    let clock: Double
    let rays: Int
    let stagger: Double
    let damping: Double

    private static let tileSize: CGFloat = 176
    private static let discSize: CGFloat = 62
    private static let tileShape = RoundedRectangle(cornerRadius: 46, style: .continuous)

    // MARK: Motion

    /// 0 = day, 1 = night; drives the tile, the cloud and the faint stars.
    private var dusk: Double {
        let p: Double = IconsCurve.smooth(IconsCurve.seg(t, 0.05, 0.6))
        return night ? p : 1 - p
    }

    /// 0 = full disc, 1 = crescent.
    private var bite: Double {
        if night { return IconsCurve.spring(t - 0.18, response: 0.5, damping: 0.75) }
        return 1 - IconsCurve.spring(t - 0.08, response: 0.45, damping: 0.8)
    }

    /// Length factor of ray `index`: 1 at rest by day, 0 by night, overshooting on the way out.
    private func rayLength(_ index: Int) -> Double {
        let delay: Double = Double(index) * stagger
        if night { return 1 - IconsCurve.easeIn(IconsCurve.seg(t, delay, delay + 0.22)) }
        return IconsCurve.spring(t - 0.3 - delay, response: 0.35, damping: damping)
    }

    private var ringTurn: Double {
        let p: Double = IconsCurve.easeInOut(IconsCurve.seg(t, 0, night ? 0.5 : 0.7))
        return night ? 60 * p : 60 * (1 - p)
    }

    private func starScale(_ index: Int) -> Double {
        let delay: Double = Double(index) * 0.09
        if night { return IconsCurve.spring(t - 0.34 - delay, response: 0.4, damping: 0.5) }
        return 1 - IconsCurve.easeIn(IconsCurve.seg(t, delay * 0.5, delay * 0.5 + 0.16))
    }

    var body: some View {
        let dusk: Double = self.dusk
        let press: Double = 0.05 * IconsCurve.bump(IconsCurve.seg(t, 0, 0.3))
        ZStack {
            sky(dusk)
            cloud(dusk)
            faintStars(dusk)
            rayRing
            disc
            popStars
        }
        .frame(width: Self.tileSize, height: Self.tileSize)
        .clipShape(Self.tileShape)
        .overlay(Self.tileShape.strokeBorder(.white.opacity(0.22), lineWidth: 1))
        .shadow(color: Color(hex: 0x3AA0FF).opacity(0.35 * (1 - dusk)), radius: 18, y: 10)
        .shadow(color: Color(hex: 0x2B2470).opacity(0.5 * dusk), radius: 18, y: 10)
        .scaleEffect(CGFloat(1 - press))
    }

    // MARK: Layers

    private func sky(_ dusk: Double) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x57C1FF), Color(hex: 0x2F86F6)], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [Color(hex: 0x151A45), Color(hex: 0x3C2E86)], startPoint: .top, endPoint: .bottom)
                .opacity(dusk)
        }
    }

    private func cloud(_ dusk: Double) -> some View {
        let drift: CGFloat = CGFloat(sin(clock * 0.6) * 4)
        return ZStack {
            Image(systemName: "cloud.fill")
                .font(.system(size: 58))
                .foregroundStyle(.white.opacity(0.92))
                .offset(x: -50 + drift - 70 * CGFloat(dusk), y: 58)
            Image(systemName: "cloud.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.6))
                .offset(x: 56 - drift + 60 * CGFloat(dusk), y: -56)
        }
        .opacity(1 - dusk)
    }

    private func faintStars(_ dusk: Double) -> some View {
        ZStack {
            ForEach(0..<9, id: \.self) { index in
                let x: CGFloat = CGFloat(IconsCurve.hash(index * 3 + 1) - 0.5) * 150
                let y: CGFloat = CGFloat(IconsCurve.hash(index * 3 + 2) - 0.5) * 150
                let twinkle: Double = 0.45 + 0.55 * (0.5 + 0.5 * sin(clock * (1.6 + Double(index) * 0.3) + Double(index)))
                Circle()
                    .fill(.white)
                    .frame(width: 2.5, height: 2.5)
                    .opacity(twinkle)
                    .offset(x: x, y: y + 14 * CGFloat(1 - dusk))
            }
        }
        .opacity(dusk * 0.8)
    }

    private var rayRing: some View {
        let count: Int = max(rays, 1)
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let length: Double = rayLength(index)
                Capsule()
                    .fill(Color(hex: 0xFFE27A))
                    .frame(width: 6.5, height: CGFloat(max(15 * length, 0.01)))
                    .offset(y: -CGFloat(41 + 7.5 * length))
                    .rotationEffect(.degrees(Double(index) / Double(count) * 360))
                    .opacity(IconsCurve.unit(length * 4))
            }
        }
        .rotationEffect(.degrees(ringTurn))
        .shadow(color: Color(hex: 0xFFD45C).opacity(0.6), radius: 6)
    }

    private var disc: some View {
        let amount: Double = bite
        let clamped: Double = IconsCurve.unit(amount)
        let size: CGFloat = Self.discSize
        let pulse: Double = night ? 0 : 0.08 * IconsCurve.bump(IconsCurve.seg(t, 0.3, 0.62))
        let scale: Double = 1 + 0.22 * amount + pulse
        let shadowX: CGFloat = CGFloat(IconsCurve.mix(64, 15, amount))
        let shadowY: CGFloat = CGFloat(IconsCurve.mix(-64, -13, amount))
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF2A6), Color(hex: 0xFFC83D), Color(hex: 0xFF9F2E)], center: .topLeading, startRadius: 2, endRadius: 70))
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFFDF0), Color(hex: 0xF3E9C4), Color(hex: 0xD8CFA8)], center: .topLeading, startRadius: 2, endRadius: 70))
                .opacity(clamped)
        }
        .frame(width: size, height: size)
        .mask {
            Rectangle()
                .overlay {
                    Circle()
                        .frame(width: size * 0.9, height: size * 0.9)
                        .offset(x: shadowX, y: shadowY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
        .shadow(color: Color(hex: 0xFFD45C).opacity(0.75 * (1 - clamped)), radius: 14)
        .shadow(color: Color(hex: 0xFFF6D0).opacity(0.55 * clamped), radius: 12)
        .rotationEffect(.degrees(-18 * (1 - amount)))
        .scaleEffect(CGFloat(scale))
    }

    private var popStars: some View {
        ZStack {
            popStar(0, x: 46, y: -40, size: 22)
            popStar(1, x: 58, y: 10, size: 13)
            popStar(2, x: -52, y: 44, size: 16)
        }
    }

    private func popStar(_ index: Int, x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        let scale: Double = max(starScale(index), 0)
        let twinkle: Double = 0.86 + 0.14 * sin(clock * 3.1 + Double(index) * 2.1)
        return IconsSparkle()
            .fill(.white)
            .frame(width: size, height: size)
            .shadow(color: .white.opacity(0.7), radius: 5)
            .scaleEffect(CGFloat(scale * twinkle))
            .rotationEffect(.degrees(30 * (1 - scale)))
            .offset(x: x, y: y)
    }
}
