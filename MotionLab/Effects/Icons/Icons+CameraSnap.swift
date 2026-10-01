import SwiftUI

extension Effect {
    static let iconsCameraSnap = Effect(
        id: "icons.camera-snap",
        category: .icons,
        interaction: .tap,
        name: L("Camera Snap", "相机快门"),
        summary: L("The shutter button dips, the iris blades whirl shut, a flash bursts and the body kicks back before a print slides out.", "快门键按下，光圈叶片旋转合拢，闪光迸出，机身向后一震，随后吐出一张相片。"),
        prompt: L(
            "A friendly camera: silver top, indigo body, a big lens whose six-blade iris rests open on blue glass. On tap the red shutter button dips 4 pt. From 0.05 s the iris closes in 0.12 s on an ease-in, the blades turning 50° as the hexagonal opening shrinks to nothing, holds for 70 ms, then reopens on a spring (response 0.36 s, damping 0.6). At 0.15 s the flash fires: a four-point star scales from 20% to 240% and fades in 0.3 s under a white bloom, and the body kicks back, tilting 3.6° and shrinking 4% before ringing out (decay 9, about 4 Hz). At 0.4 s a small print rises 44 pt from the top on a spring, tilted 8°, then drifts up and fades as the photo counter rolls. A light tap, then a rigid click with the flash. Snappy and mechanical.",
            "一台相机：银色顶盖、靛蓝机身，大镜头里六片光圈叶片敞开，露出蓝色镜片。点击后红色快门键下沉4 pt。0.05秒起光圈以缓入曲线用0.12秒合拢，叶片旋转50°，六边形开口缩到消失，停70毫秒后以弹簧（响应0.36秒、阻尼0.6）重新张开。0.15秒时闪光灯触发：四角星芒从20%放大到240%，随一片白色辉光在0.3秒内淡出；机身向后一震，倾斜3.6°、缩小4%再衰减回弹（衰减9、约4 Hz）。0.4秒时一张小相片从顶部弹起44 pt、倾斜8°，随后飘走淡出，照片计数加一。"
        ),
        implementation: L(
            "The iris is one even-odd Shape: a disc minus a rotating polygon, plus blade seams running from each vertex to the rim. A TimelineView maps the seconds since the tap to the opening, the flash star and bloom, the recoil (a decaying cosine) and the print's rise.",
            "光圈是一个奇偶填充的 Shape：圆盘减去一个旋转的多边形，再从每个顶点向边缘画出叶片接缝。TimelineView 把点击后的秒数映射为开口大小、闪光星芒与辉光、后坐（衰减余弦）以及相片的升起。"
        ),
        apis: ["TimelineView(.animation)", "Shape", "FillStyle(eoFill:)", "RadialGradient", "rotationEffect", "contentTransition(.numericText(value:))"],
        tags: ["camera", "shutter", "iris", "flash", "photo", "相机", "快门", "光圈", "闪光", "拍照"],
        params: [
            .slider("blades", L("Iris blades", "光圈叶片"), 5...9, default: 6, step: 1, decimals: 0),
            .slider("flash", L("Flash strength", "闪光强度"), 0...1, default: 0.7),
            .slider("recoil", L("Recoil", "后坐力"), 0...1, default: 0.6),
        ]
    ) { ctx in
        IconsCameraSnapDemo(ctx: ctx)
    }
}

private struct IconsCameraSnapDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast
    @State private var shots: Int = 24

    var body: some View {
        VStack(spacing: 8) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsCameraScene(
                    t: ctx.isStill ? 10 : elapsed(at: date),
                    shot: shots,
                    blades: ctx.int("blades"),
                    flash: ctx["flash"],
                    recoil: ctx["recoil"]
                )
            }
            .frame(width: 250, height: 216)
            .contentShape(Rectangle())
            .onTapGesture { snap() }
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                Text(verbatim: "\(shots)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shots)))
                Text(L("photos", "张照片"), ctx.language)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            DemoHint(text: L("Tap to take a photo", "点击拍一张"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.2) { snap() }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private func snap() {
        guard elapsed(at: .now) > 0.7 else { return }
        start = .now
        Haptics.tap(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.snappy(duration: 0.3)) { shots += 1 }
        }
        IconsHaptics.later(0.15, preview: ctx.isPreview) { Haptics.tap(.rigid) }
    }
}

/// The iris seen through the lens: a disc with a polygonal opening, and the seams between its blades.
private struct IconsIrisBlades: Shape {
    let blades: Int
    /// 0 = shut, 1 = wide open.
    let opening: Double
    let turn: Double

    private func vertices(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        let count: Int = max(blades, 3)
        return (0..<count).map { index in
            let angle: Double = turn + Double(index) / Double(count) * 2 * .pi
            return CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer: CGFloat = min(rect.width, rect.height) / 2
        let points: [CGPoint] = vertices(center: center, radius: outer * 0.9 * CGFloat(max(opening, 0.001)))
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2))
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    /// One seam per blade: the polygon edge extended past its vertex out to the rim.
    func seams(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer: CGFloat = min(rect.width, rect.height) / 2
        let points: [CGPoint] = vertices(center: center, radius: outer * 0.9 * CGFloat(max(opening, 0.001)))
        var path = Path()
        for index in points.indices {
            let from: CGPoint = points[index]
            let previous: CGPoint = points[(index + points.count - 1) % points.count]
            var dx: CGFloat = from.x - previous.x
            var dy: CGFloat = from.y - previous.y
            let length: CGFloat = max((dx * dx + dy * dy).squareRoot(), 0.001)
            dx /= length
            dy /= length
            path.move(to: from)
            path.addLine(to: CGPoint(x: from.x + dx * outer * 2, y: from.y + dy * outer * 2))
        }
        return path
    }
}

private struct IconsIrisSeams: Shape {
    let iris: IconsIrisBlades

    func path(in rect: CGRect) -> Path { iris.seams(in: rect) }
}

private struct IconsCameraScene: View {
    let t: Double
    let shot: Int
    let blades: Int
    let flash: Double
    let recoil: Double

    private static let bodySize = CGSize(width: 184, height: 122)
    private static let fire: Double = 0.15
    private static let flashSpot = CGPoint(x: -58, y: -22)

    /// 0 = shut, 1 = resting open.
    private var opening: Double {
        let closing: Double = IconsCurve.easeIn(IconsCurve.seg(t, 0.05, 0.17))
        let reopening: Double = IconsCurve.spring(t - 0.24, response: 0.36, damping: 0.6)
        return t < 0.24 ? 1 - closing : reopening
    }

    var body: some View {
        let kick: Double = recoil * IconsCurve.ring(t - Self.fire, decay: 9, frequency: 24) * IconsCurve.seg(t, Self.fire, Self.fire + 0.03)
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 170, height: 14)
                .blur(radius: 8)
                .offset(y: 92)
            ZStack {
                photoPrint
                camera
            }
            .scaleEffect(CGFloat(1 - 0.07 * kick))
            .rotationEffect(.degrees(-6 * kick))
            .offset(y: 20 + CGFloat(5 * kick))
            bloom
        }
    }

    // MARK: Camera

    private var camera: some View {
        let size: CGSize = Self.bodySize
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let press: CGFloat = CGFloat(4 * IconsCurve.bump(IconsCurve.seg(t, 0, 0.22)))
        return ZStack {
            // Shutter button and viewfinder hump, behind the body's top edge.
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xFF7A85), Color(hex: 0xE8334A)], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 16)
                .offset(x: 52, y: -size.height / 2 - 3 + press)
            UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous)
                .fill(Color(hex: 0xC9CAD6))
                .frame(width: 66, height: 18)
                .offset(x: -6, y: -size.height / 2 - 6)
            shape
                .fill(LinearGradient(colors: [Color(hex: 0x7C83FF), Color(hex: 0x5A54E0)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(hex: 0xFAFAFD), Color(hex: 0xD9DAE4)], startPoint: .top, endPoint: .bottom))
                        .frame(height: 34)
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.black.opacity(0.14)).frame(height: 1.5).offset(y: 34)
                }
                .clipShape(shape)
                .overlay(shape.strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .frame(width: size.width, height: size.height)
                .shadow(color: Color(hex: 0x4A44C8).opacity(0.4), radius: 14, y: 8)
            flashWindow
            lens.offset(x: 14, y: 12)
        }
        .frame(width: size.width, height: size.height)
    }

    private var flashWindow: some View {
        let lit: Double = flash * (1 - IconsCurve.easeOut(IconsCurve.seg(t, Self.fire, Self.fire + 0.4))) * (t >= Self.fire ? 1 : 0)
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color(hex: 0xFFF3C4))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.white.opacity(lit)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
            .frame(width: 30, height: 16)
            .shadow(color: .white.opacity(lit), radius: 10)
            .offset(x: Self.flashSpot.x, y: Self.flashSpot.y - 20)
    }

    private var lens: some View {
        let open: Double = opening
        let iris = IconsIrisBlades(blades: blades, opening: 0.8 * open, turn: (1 - IconsCurve.unit(open)) * 50 * .pi / 180)
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x4A4B5C), Color(hex: 0x1D1D28)], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(.white.opacity(0.28), lineWidth: 2)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0x7CC6FF), Color(hex: 0x3550E0), Color(hex: 0x141A5A)], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 2, endRadius: 34))
                Circle()
                    .fill(.white.opacity(0.75))
                    .frame(width: 10, height: 10)
                    .offset(x: -9, y: -10)
                Circle()
                    .fill(.white.opacity(0.4))
                    .frame(width: 5, height: 5)
                    .offset(x: 8, y: 9)
                iris.fill(Color(hex: 0x2A2B38), style: FillStyle(eoFill: true))
                IconsIrisSeams(iris: iris)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            Circle()
                .strokeBorder(Color.black.opacity(0.5), lineWidth: 2)
                .frame(width: 62, height: 62)
        }
        .frame(width: 88, height: 88)
        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
    }

    // MARK: Flash and print

    private var bloom: some View {
        let since: Double = t - Self.fire
        let live: Bool = since >= 0 && since < 0.5
        let star: Double = IconsCurve.easeOut(IconsCurve.seg(since, 0, 0.3))
        let veil: Double = flash * (1 - IconsCurve.easeOut(IconsCurve.seg(since, 0, 0.45)))
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.95 * veil), .white.opacity(0.4 * veil), .white.opacity(0)], center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
            IconsSparkle()
                .fill(.white)
                .frame(width: 60, height: 60)
                .scaleEffect(CGFloat(0.2 + 2.2 * star))
                .rotationEffect(.degrees(30 * star))
                .opacity(flash > 0.02 ? 1 - star : 0)
                .shadow(color: Palette.amber.opacity(0.8), radius: 8)
        }
        .offset(x: Self.flashSpot.x, y: Self.flashSpot.y)
        .opacity(live ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// The print that slides out of the top after the shot (drawn behind the body).
    private var photoPrint: some View {
        let rise: Double = IconsCurve.spring(t - 0.4, response: 0.4, damping: 0.62)
        let leave: Double = IconsCurve.easeIn(IconsCurve.seg(t, 1.0, 1.4))
        let colors: [Color] = [Palette.spectrum[((shot % 7) + 7) % 7], Palette.spectrum[((shot % 7) + 10) % 7]]
        let live: Bool = t >= 0.4 && t < 1.4
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.white)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 30)
                    .padding(.top, 5)
            }
            .frame(width: 44, height: 50)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .rotationEffect(.degrees(8 * rise))
            .offset(x: -58, y: -Self.bodySize.height / 2 + 26 - CGFloat(44 * rise) - CGFloat(22 * leave))
            .opacity(live ? 1 - leave : 0)
    }
}
