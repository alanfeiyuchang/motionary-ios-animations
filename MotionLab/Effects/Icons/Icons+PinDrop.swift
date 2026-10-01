import SwiftUI

extension Effect {
    static let iconsPinDrop = Effect(
        id: "icons.pin-drop",
        category: .icons,
        interaction: .tap,
        name: L("Pin Drop", "大头针落点"),
        summary: L("A map pin is plucked away, falls back in, squashes on landing and sends rings across the ground.", "地图大头针被拔起后重新落下，着地压扁，并在地面荡开一圈圈波纹。"),
        prompt: L(
            "A red teardrop map pin stands on a small tilted map disc. On tap it crouches for 0.07 s, then shoots 150 pt upward and fades out. At 0.36 s it falls back in 0.3 s under gravity, stretched 12% taller, while its ground shadow tightens and darkens as it nears. On impact the pin squashes 26% around its tip and rings back like jelly (decay 14, about 5 Hz); its white centre dot lags behind. It bounces twice more, 18 pt then 5 pt high, each landing with a smaller squash. Three flattened ellipse rings ripple outward from the tip 0.13 s apart, widening to 200 pt over 0.75 s as they thin and fade, and six dust specks puff sideways. A medium haptic marks the first hit; the coordinates below roll to the new place.",
            "一枚红色水滴形大头针立在倾斜的地图圆盘上。点击后它先下蹲0.07秒，随即向上射出150 pt并淡出；0.36秒时在重力下用0.3秒落回，途中被拉长12%，地面阴影随靠近而收紧变深。着地瞬间以针尖为锚点压扁26%，再像果冻般回弹（衰减14、约5 Hz），白色圆心略微滞后。之后再弹起两次，高18 pt与5 pt，压扁逐次减小。三道椭圆波纹从针尖相隔0.13秒荡开，0.75秒内扩大到200 pt并变细淡出，六粒尘埃向两侧扬起。首次着地配中等触感，下方坐标滚动到新位置。"
        ),
        implementation: L(
            "A TimelineView passes the seconds since the tap to a pose function: piecewise parabolas give the height, each impact adds a decaying cosine to the squash, and the shadow, rings and dust are derived from the same clock.",
            "TimelineView 把点击后的秒数交给姿态函数：分段抛物线给出高度，每次着地向压扁量叠加一个衰减余弦，阴影、波纹与尘埃都由同一时钟推导。"
        ),
        apis: ["TimelineView(.animation)", "Path", "scaleEffect(x:y:anchor:)", "Ellipse", "contentTransition(.numericText())"],
        tags: ["map", "pin", "location", "drop", "bounce", "squash", "地图", "大头针", "定位", "落下", "弹跳"],
        params: [
            .slider("height", L("Drop height", "下落高度"), 80...190, default: 150, decimals: 0, unit: "pt"),
            .slider("bounce", L("Bounciness", "弹性"), 0...1, default: 0.6),
            .slider("rings", L("Ripple rings", "波纹圈数"), 1...4, default: 3, step: 1, decimals: 0),
        ]
    ) { ctx in
        IconsPinDropDemo(ctx: ctx)
    }
}

private struct IconsPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + radius)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        let startAngle: CGFloat = 145 * .pi / 180
        let start = CGPoint(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        var path = Path()
        path.move(to: start)
        path.addArc(center: center, radius: radius, startAngle: .degrees(145), endAngle: .degrees(395), clockwise: false)
        path.addQuadCurve(to: tip, control: CGPoint(x: rect.midX + radius * 0.42, y: rect.minY + rect.height * 0.8))
        path.addQuadCurve(to: start, control: CGPoint(x: rect.midX - radius * 0.42, y: rect.minY + rect.height * 0.8))
        path.closeSubpath()
        return path
    }
}

private struct IconsPinPose {
    /// Points above the ground.
    var height: Double = 0
    /// Positive squashes, negative stretches.
    var squash: Double = 0
    var opacity: Double = 1
}

private struct IconsPinTimes {
    let fall: Double = 0.66
    let second: Double
    let third: Double

    init(bounce: Double) {
        let root: Double = bounce.squareRoot()
        second = 0.66 + 0.3 * root
        third = 0.66 + 0.46 * root
    }
}

private struct IconsPinPlace {
    let latitude: Double
    let longitude: Double
}

private let iconsPinPlaces: [IconsPinPlace] = [
    IconsPinPlace(latitude: 47.6101, longitude: 122.2015),
    IconsPinPlace(latitude: 47.6205, longitude: 122.3493),
    IconsPinPlace(latitude: 47.6740, longitude: 122.1215),
    IconsPinPlace(latitude: 47.5301, longitude: 122.0326),
]

private struct IconsPinDropDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast
    @State private var place: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsPinScene(
                    t: ctx.isStill ? 10 : elapsed(at: date),
                    height: ctx["height"],
                    bounce: ctx["bounce"],
                    rings: ctx.int("rings")
                )
            }
            .frame(width: 250, height: 226)
            .contentShape(Rectangle())
            .onTapGesture { drop() }
            coordinates
            DemoHint(text: L("Tap to drop the pin again", "点击重新放下大头针"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.3) { drop() }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private var coordinates: some View {
        let spot: IconsPinPlace = iconsPinPlaces[place % iconsPinPlaces.count]
        return HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.red)
            Text(verbatim: String(format: "%.4f° N, %.4f° W", spot.latitude, spot.longitude))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func drop() {
        // One drop at a time: a tap during the flight is ignored.
        guard elapsed(at: .now) > 0.9 else { return }
        start = .now
        Haptics.tap(.light)
        let times = IconsPinTimes(bounce: ctx["bounce"])
        DispatchQueue.main.asyncAfter(deadline: .now() + times.fall) {
            withAnimation(.snappy(duration: 0.4)) { place += 1 }
        }
        IconsHaptics.later(times.fall, preview: ctx.isPreview) { Haptics.tap(.medium) }
        if ctx["bounce"] > 0.15 {
            IconsHaptics.later(times.second, preview: ctx.isPreview) { Haptics.tap(.soft) }
        }
    }
}

private struct IconsPinScene: View {
    let t: Double
    let height: Double
    let bounce: Double
    let rings: Int

    private static let ground: CGFloat = 60
    private static let pinSize = CGSize(width: 54, height: 78)

    var body: some View {
        let times = IconsPinTimes(bounce: bounce)
        let pose: IconsPinPose = Self.pose(t, height: height, bounce: bounce, times: times)
        ZStack {
            mapDisc(pulse: IconsCurve.bump(IconsCurve.seg(t, times.fall, times.fall + 0.3)))
            rippleLayer(times: times)
            shadow(pose)
            dust(since: t - times.fall)
            pin(pose)
        }
    }

    // MARK: Motion

    static func pose(_ t: Double, height: Double, bounce: Double, times: IconsPinTimes) -> IconsPinPose {
        var pose = IconsPinPose()
        if t < 0.07 {
            pose.squash = 0.1 * IconsCurve.easeOut(t / 0.07)
        } else if t < 0.26 {
            let u: Double = (t - 0.07) / 0.19
            pose.height = height * u * u * u
            pose.squash = 0.1 - 0.24 * IconsCurve.unit(u * 2.5)
            pose.opacity = 1 - IconsCurve.seg(u, 0.45, 1)
        } else if t < 0.36 {
            pose.height = height
            pose.opacity = 0
        } else if t < times.fall {
            let u: Double = (t - 0.36) / 0.3
            pose.height = height * (1 - u * u)
            pose.squash = -0.12 * u
            pose.opacity = IconsCurve.seg(u, 0, 0.3)
        } else if t < times.second {
            let u: Double = (t - times.fall) / max(times.second - times.fall, 0.001)
            pose.height = 30 * bounce * 4 * u * (1 - u)
        } else if t < times.third {
            let u: Double = (t - times.second) / max(times.third - times.second, 0.001)
            pose.height = 8 * bounce * 4 * u * (1 - u)
        }
        if t >= times.fall {
            pose.squash += 0.26 * IconsCurve.ring(t - times.fall, decay: 14, frequency: 34)
        }
        if t >= times.second {
            pose.squash += 0.12 * bounce * IconsCurve.ring(t - times.second, decay: 16, frequency: 36)
        }
        if t >= times.third {
            pose.squash += 0.05 * bounce * IconsCurve.ring(t - times.third, decay: 18, frequency: 38)
        }
        return pose
    }

    // MARK: Layers

    private func pin(_ pose: IconsPinPose) -> some View {
        let size: CGSize = Self.pinSize
        let dotLag: CGFloat = CGFloat(pose.squash) * 16
        return ZStack {
            IconsPinShape()
                .fill(LinearGradient(colors: [Color(hex: 0xFF8088), Palette.red, Color(hex: 0xE2334A)], startPoint: .top, endPoint: .bottom))
            IconsPinShape()
                .fill(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .topLeading, endPoint: .center))
            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .shadow(color: Color(hex: 0xB01E33).opacity(0.5), radius: 2, y: 1)
                .offset(y: -size.height / 2 + size.width / 2 + dotLag)
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: Palette.red.opacity(0.35), radius: 10, y: 6)
        .scaleEffect(x: CGFloat(1 + pose.squash * 0.8), y: CGFloat(1 - pose.squash), anchor: .bottom)
        .offset(y: Self.ground - size.height / 2 - CGFloat(pose.height))
        .opacity(pose.opacity)
    }

    private func shadow(_ pose: IconsPinPose) -> some View {
        let near: Double = 1 - IconsCurve.unit(pose.height / max(height, 1))
        let width: CGFloat = CGFloat(16 + 26 * near + 36 * max(pose.squash, 0))
        return Ellipse()
            .fill(Color.black.opacity(0.1 + 0.3 * near))
            .frame(width: width, height: width * 0.36)
            .blur(radius: CGFloat(1.5 + 5 * (1 - near)))
            .offset(y: Self.ground)
            .opacity(pose.opacity)
    }

    private func rippleLayer(times: IconsPinTimes) -> some View {
        ZStack {
            ForEach(0..<max(rings, 1), id: \.self) { index in
                ripple(since: t - times.fall - Double(index) * 0.13, reach: 170, strength: 0.6)
            }
            ripple(since: t - times.second, reach: 70, strength: bounce > 0.15 ? 0.45 : 0)
        }
        .offset(y: Self.ground)
    }

    private func ripple(since: Double, reach: CGFloat, strength: Double) -> some View {
        let p: Double = IconsCurve.seg(since, 0, 0.75)
        let eased: Double = IconsCurve.easeOut(p)
        let width: CGFloat = 30 + reach * CGFloat(eased)
        let live: Bool = p > 0 && p < 1
        return Ellipse()
            .stroke(Palette.red.opacity(strength * (1 - p)), lineWidth: 3 * CGFloat(1 - p) + 0.6)
            .frame(width: width, height: width * 0.36)
            .opacity(live ? 1 : 0)
    }

    private func dust(since: Double) -> some View {
        let p: Double = IconsCurve.seg(since, 0, 0.5)
        let eased: Double = IconsCurve.easeOut(p)
        let live: Bool = p > 0 && p < 1
        return ZStack {
            ForEach(0..<6, id: \.self) { index in
                let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                let reach: CGFloat = CGFloat(30 + 14 * (index / 2))
                let rise: CGFloat = CGFloat(7 + 5 * (index / 2))
                Circle()
                    .fill(Palette.red.opacity(0.5 * (1 - p)))
                    .frame(width: 4 * CGFloat(1 - p) + 1, height: 4 * CGFloat(1 - p) + 1)
                    .offset(x: side * reach * CGFloat(eased), y: -rise * CGFloat(IconsCurve.bump(p)))
            }
        }
        .offset(y: Self.ground)
        .opacity(live ? 1 : 0)
    }

    private func mapDisc(pulse: Double) -> some View {
        ZStack {
            Ellipse().fill(Color.primary.opacity(0.07))
            Ellipse()
                .fill(Palette.mint.opacity(0.3))
                .frame(width: 70, height: 26)
                .offset(x: -52, y: -12)
            Ellipse()
                .fill(Palette.sky.opacity(0.3))
                .frame(width: 90, height: 40)
                .offset(x: 78, y: 30)
            IconsLine(from: UnitPoint(x: -0.05, y: 0.78), to: UnitPoint(x: 1.05, y: 0.3))
                .stroke(Color.primary.opacity(0.11), lineWidth: 7)
            IconsLine(from: UnitPoint(x: 0.3, y: -0.1), to: UnitPoint(x: 0.62, y: 1.1))
                .stroke(Color.primary.opacity(0.09), lineWidth: 5)
            IconsLine(from: UnitPoint(x: 0.62, y: -0.1), to: UnitPoint(x: 0.95, y: 0.75))
                .stroke(Color.primary.opacity(0.07), lineWidth: 4)
        }
        .frame(width: 222, height: 84)
        .clipShape(Ellipse())
        .overlay(Ellipse().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        .scaleEffect(CGFloat(1 + 0.03 * pulse))
        .offset(y: Self.ground + 6)
    }
}
