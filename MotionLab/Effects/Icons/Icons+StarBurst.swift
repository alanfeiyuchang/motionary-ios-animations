import SwiftUI

extension Effect {
    static let iconsStarBurst = Effect(
        id: "icons.star-burst",
        category: .icons,
        interaction: .tap,
        name: L("Star Burst", "星标迸发"),
        summary: L("A favourite star winds up, spins as it fills with gold, throws rays and lands with a tiny hop.", "收藏星标先蓄力，再旋转着填满金色，射出光芒，最后轻轻一跳落定。"),
        prompt: L(
            "A 112 pt rounded five-point star drawn as a grey outline. On tap it winds up for 0.1 s, shrinking to 72% while turning back 18°, then springs past full size to about 106% (response 0.42 s, damping 0.45) as it spins forward 144° and fills with a gold gradient under a white flash. At the peak a thick ring expands and thins out, ten rays leave from 62 pt: five tapering streaks that fly 48 pt, alternating with five coloured dots that shrink as they fly; three four-point sparkles pop in sequence. At 0.74 s the star hops 8 pt and lands with a 7% squash. Un-favouriting dips to 84%, turns back 72° and drains the gold. Celebratory but brief: a reward for one tap.",
            "一枚112 pt的圆角五角星，未收藏时只有灰色描边。点击后先用0.1秒蓄力：缩到72%并回拧18°；随后以弹簧（响应0.42秒、阻尼0.45）弹过原大至约106%，同时向前旋转144°，在白色闪光下填满金色渐变。峰值处一圈粗环扩散变细，十道光芒从62 pt处射出：五道飞出48 pt的拖尾光条与五颗边飞边缩小的彩色圆点交替；三颗四角星芒依次闪现。0.74秒时星星轻跳8 pt，落下时压扁7%。取消收藏时缩到84%、回转72°，金色褪去。热烈而短促，是给一次点击的奖赏。"
        ),
        implementation: L(
            "A TimelineView feeds the seconds since the tap into pure functions: an analytic spring gives scale and spin, eased windows give the fill, flash, ring, rays and hop. The star is a Path with tangent-arc corners.",
            "TimelineView 把点击后经过的秒数交给一组纯函数：解析弹簧给出缩放与旋转，分段缓动给出填色、闪光、圆环、光芒与小跳。星形是用切线圆弧倒角的 Path。"
        ),
        apis: ["TimelineView(.animation)", "Path.addArc(tangent1End:tangent2End:radius:)", "rotationEffect", "scaleEffect(x:y:anchor:)", "contentTransition(.numericText(value:))"],
        tags: ["star", "favourite", "favorite", "rating", "burst", "sparkle", "星标", "收藏", "迸发", "光芒", "评分"],
        params: [
            .slider("spin", L("Spin", "旋转角度"), 0...360, default: 144, step: 72, decimals: 0, unit: "°"),
            .slider("rays", L("Rays", "光芒数量"), 6...14, default: 10, step: 2, decimals: 0),
            .slider("distance", L("Ray travel", "光芒射程"), 24...70, default: 48, decimals: 0, unit: "pt"),
            .slider("damping", L("Pop damping", "弹出阻尼"), 0.3...0.9, default: 0.45),
        ]
    ) { ctx in
        IconsStarBurstDemo(ctx: ctx)
    }
}

private struct IconsStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer: CGFloat = min(rect.width, rect.height) / 2
        let inner: CGFloat = outer * 0.5
        var points: [CGPoint] = []
        for index in 0..<10 {
            let radius: CGFloat = index.isMultiple(of: 2) ? outer : inner
            let angle: CGFloat = -.pi / 2 + CGFloat(index) * .pi / 5
            points.append(CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
        }
        return IconsPath.roundedPolygon(points) { $0.isMultiple(of: 2) ? outer * 0.13 : outer * 0.06 }
    }
}

private struct IconsStarPose {
    var scale: Double = 1
    var rotation: Double = 0
    var lift: Double = 0
    var squash: Double = 0
    var fill: Double = 0
    var flash: Double = 0
}

private struct IconsStarBurstDemo: View {
    let ctx: DemoContext
    @State private var play: IconsPlayhead
    @State private var count: Int

    private static let onDuration: Double = 1.1
    private static let offDuration: Double = 0.5

    init(ctx: DemoContext) {
        self.ctx = ctx
        _play = State(initialValue: IconsPlayhead(isOn: ctx.isStill))
        _count = State(initialValue: ctx.isStill ? 129 : 128)
    }

    var body: some View {
        VStack(spacing: 8) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsStarScene(
                    on: play.isOn,
                    t: play.elapsed(at: date),
                    spin: ctx["spin"],
                    rays: ctx.int("rays"),
                    distance: ctx["distance"],
                    damping: ctx["damping"]
                )
            }
            .frame(width: 250, height: 216)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            caption
            DemoHint(text: L("Tap the star", "点击星标"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { toggle() }
    }

    private var caption: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(play.isOn ? Palette.amber : Color.secondary.opacity(0.6))
            Text(verbatim: "\(count)")
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
            Text(L("favourites", "次收藏"), ctx.language)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .animation(.snappy(duration: 0.3), value: play.isOn)
    }

    private func toggle() {
        play.toggle(onDuration: Self.onDuration, offDuration: Self.offDuration)
        let on: Bool = play.isOn
        withAnimation(.snappy(duration: 0.35)) { count += on ? 1 : -1 }
        if on {
            Haptics.tap(.medium)
            IconsHaptics.later(0.96, preview: ctx.isPreview) { Haptics.tap(.soft) }
        } else {
            Haptics.selection()
        }
    }
}

private struct IconsStarScene: View {
    let on: Bool
    let t: Double
    let spin: Double
    let rays: Int
    let distance: Double
    let damping: Double

    private static let burstStart: Double = 0.14
    private static let rayOrigin: Double = 62

    private var gold: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFFE680), Palette.amber, Color(hex: 0xFF9A2E)], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let pose: IconsStarPose = on ? onPose : offPose
        ZStack {
            glow(pose)
            ring
            rayLayer
            star(pose)
            sparkles
        }
    }

    // MARK: Poses

    private var onPose: IconsStarPose {
        var pose = IconsStarPose()
        let wind: Double = IconsCurve.easeOut(IconsCurve.seg(t, 0, 0.1))
        let pop: Double = IconsCurve.spring(t - 0.1, response: 0.42, damping: damping)
        let turn: Double = IconsCurve.spring(t - 0.1, response: 0.6, damping: min(damping + 0.27, 1))
        pose.scale = t < 0.1 ? 1 - 0.28 * wind : 0.72 + 0.28 * pop
        pose.rotation = t < 0.1 ? -18 * wind : -18 + (spin + 18) * turn
        pose.fill = IconsCurve.seg(t, 0.08, 0.2)
        pose.flash = IconsCurve.seg(t, 0.08, 0.13) * (1 - IconsCurve.seg(t, 0.13, 0.45))
        pose.lift = 8 * IconsCurve.bump(IconsCurve.seg(t, 0.74, 0.96))
        pose.squash = 0.07 * IconsCurve.bump(IconsCurve.seg(t, 0.94, 1.1))
        return pose
    }

    private var offPose: IconsStarPose {
        var pose = IconsStarPose()
        let dip: Double = IconsCurve.easeOut(IconsCurve.seg(t, 0, 0.1))
        let back: Double = IconsCurve.spring(t - 0.1, response: 0.35, damping: 0.55)
        pose.scale = t < 0.1 ? 1 - 0.16 * dip : 0.84 + 0.16 * back
        pose.rotation = -72 * IconsCurve.easeInOut(IconsCurve.seg(t, 0, 0.42))
        pose.fill = 1 - IconsCurve.seg(t, 0, 0.16)
        return pose
    }

    // MARK: Layers

    private func star(_ pose: IconsStarPose) -> some View {
        ZStack {
            IconsStarShape()
                .stroke(Color.secondary.opacity(0.75), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
                .padding(3)
                .opacity(1 - pose.fill)
            IconsStarShape()
                .fill(gold)
                .overlay {
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .topLeading, endPoint: .center)
                        .mask(IconsStarShape())
                }
                .overlay(IconsStarShape().stroke(Color(hex: 0xF08A12).opacity(0.55), lineWidth: 1.5))
                .opacity(pose.fill)
            IconsStarShape()
                .fill(.white)
                .opacity(pose.flash * 0.85)
        }
        .frame(width: 112, height: 112)
        .shadow(color: Palette.amber.opacity(0.5 * pose.fill), radius: 16, y: 6)
        .rotationEffect(.degrees(pose.rotation))
        .scaleEffect(x: CGFloat(1 + pose.squash * 0.7), y: CGFloat(1 - pose.squash), anchor: .bottom)
        .scaleEffect(CGFloat(pose.scale))
        .offset(y: CGFloat(4 - pose.lift))
    }

    private func glow(_ pose: IconsStarPose) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Palette.amber.opacity(0.55), Palette.amber.opacity(0)], center: .center, startRadius: 8, endRadius: 100))
            .frame(width: 200, height: 200)
            .scaleEffect(CGFloat(0.7 + 0.3 * pose.scale))
            .opacity(0.5 * pose.fill + 0.5 * pose.flash)
            .offset(y: 4)
    }

    private var ring: some View {
        let p: Double = on ? IconsCurve.seg(t, 0.1, 0.46) : 0
        let eased: Double = IconsCurve.easeOut(p)
        let diameter: CGFloat = 64 + 120 * CGFloat(eased)
        let live: Bool = p > 0 && p < 1
        return Circle()
            .stroke(Palette.amber.opacity(0.75 * (1 - p * p)), lineWidth: 14 * CGFloat(1 - eased))
            .frame(width: diameter, height: diameter)
            .opacity(live ? 1 : 0)
            .offset(y: 4)
    }

    private var rayLayer: some View {
        let total: Int = max(rays, 2)
        return ZStack {
            ForEach(0..<total, id: \.self) { index in
                if index.isMultiple(of: 2) {
                    streak(index, of: total)
                } else {
                    dot(index, of: total)
                }
            }
        }
        .offset(y: 4)
        .opacity(on ? 1 : 0)
    }

    private func streak(_ index: Int, of total: Int) -> some View {
        let start: Double = Self.burstStart
        let head: Double = IconsCurve.easeOut(IconsCurve.seg(t, start, start + 0.3))
        let tail: Double = IconsCurve.easeOut(IconsCurve.seg(t, start + 0.12, start + 0.5))
        let near: Double = Self.rayOrigin + distance * tail
        let far: Double = Self.rayOrigin + distance * head
        let live: Bool = head > 0 && tail < 1
        return Capsule()
            .fill(Palette.amber)
            .frame(width: CGFloat(5.5 - 3 * tail), height: CGFloat(max(far - near, 0.5)))
            .offset(y: -CGFloat((near + far) / 2))
            .rotationEffect(.degrees(Double(index) / Double(total) * 360))
            .opacity(live ? 1 : 0)
    }

    private func dot(_ index: Int, of total: Int) -> some View {
        let start: Double = Self.burstStart + 0.02
        let p: Double = IconsCurve.easeOut(IconsCurve.seg(t, start, start + 0.54))
        let radius: Double = Self.rayOrigin - 6 + distance * 1.25 * p
        let size: CGFloat = CGFloat(9 * (1 - p) + 1.5)
        let fade: Double = IconsCurve.seg(t, start, start + 0.04) * (1 - IconsCurve.seg(t, start + 0.34, start + 0.54))
        return Circle()
            .fill(Palette.spectrum[(index / 2) % Palette.spectrum.count])
            .frame(width: size, height: size)
            .offset(y: -CGFloat(radius))
            .rotationEffect(.degrees(Double(index) / Double(total) * 360))
            .opacity(fade)
    }

    private var sparkles: some View {
        ZStack {
            sparkle(x: 80, y: -66, size: 30, delay: 0.3)
            sparkle(x: -88, y: -34, size: 20, delay: 0.38)
            sparkle(x: 72, y: 70, size: 17, delay: 0.46)
        }
        .opacity(on ? 1 : 0)
    }

    private func sparkle(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double) -> some View {
        let p: Double = IconsCurve.seg(t, delay, delay + 0.5)
        return IconsSparkle()
            .fill(Color(hex: 0xFFC83D))
            .frame(width: size, height: size)
            .scaleEffect(CGFloat(IconsCurve.bump(p)))
            .rotationEffect(.degrees(60 * p))
            .offset(x: x, y: y)
    }
}
