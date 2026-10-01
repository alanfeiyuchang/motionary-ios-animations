import SwiftUI

extension Effect {
    static let iconsArchiveBox = Effect(
        id: "icons.archive-box",
        category: .icons,
        interaction: .tap,
        name: L("Archive Box", "归档入箱"),
        summary: L("Two cardboard flaps swing open, a document drops in, the flaps slap shut and tape seals the box.", "两片纸箱盖板弹开，文件落入，盖板啪地合上，再由胶带封箱。"),
        prompt: L(
            "A cardboard box seen from the front, its two top flaps closed, with a document hovering above and bobbing gently. On tap the left flap swings open 128° about its outer corner on a spring (response 0.32 s, damping 0.6) and the right one follows 0.06 s later. The document hops 14 pt with a 7° counter-tilt, then falls into the box in 0.28 s on an ease-in, shrinking to 82% and disappearing behind the front wall. The box squashes 10% and rings back, its ground shadow widening. The flaps slap shut one after the other, bouncing off the rim, and a strip of tape slides 26 pt down the front while a green check pops onto the label. A fresh document springs in and the counter rolls up. Tidy and tactile: filing as a small pleasure.",
            "一个正面视角的纸箱，顶部两片盖板合着，上方悬着一份轻轻浮动的文件。点击后左盖板以弹簧（响应0.32秒、阻尼0.6）绕外侧顶角弹开128°，右盖板晚0.06秒跟上。文件先向上轻跳14 pt并反向倾斜7°，随后以缓入曲线在0.28秒内落入箱中，缩到82%，消失在箱体前壁之后。箱体压扁10%再回弹，地面阴影随之变宽。两片盖板先后啪地合上，在箱沿上弹一下；一条胶带沿正面滑下26 pt，标签上弹出绿色对勾。新文件弹入原位，计数向上滚动。利落而有手感，把归档做成一件小乐事。"
        ),
        implementation: L(
            "A TimelineView turns the seconds since the tap into flap angles (analytic springs, rectified so the flaps bounce on the rim), the document's path, a decaying-cosine squash and the tape's height; layer order hides the document behind the front wall.",
            "TimelineView 把点击后的秒数换算成盖板角度（解析弹簧并取绝对值，让盖板在箱沿反弹）、文件轨迹、衰减余弦的压扁量与胶带高度；借图层顺序让文件隐入前壁之后。"
        ),
        apis: ["TimelineView(.animation)", "rotationEffect(_:anchor:)", "scaleEffect(x:y:anchor:)", "UnevenRoundedRectangle", "contentTransition(.numericText(value:))"],
        tags: ["archive", "box", "file", "store", "pack", "归档", "纸箱", "收纳", "存档", "打包"],
        params: [
            .slider("flap", L("Flap angle", "盖板角度"), 80...160, default: 128, step: 1, decimals: 0, unit: "°"),
            .slider("bounce", L("Flap bounce", "合盖弹性"), 0...0.6, default: 0.4),
            .slider("squash", L("Landing squash", "落底压扁"), 0...0.2, default: 0.1),
        ]
    ) { ctx in
        IconsArchiveBoxDemo(ctx: ctx)
    }
}

private struct IconsArchiveBoxDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast
    @State private var plays: Int = 0
    @State private var archived: Int = 12

    /// The document lands at this moment of a play.
    private static let landing: Double = 0.56
    private static let busy: Double = 1.35

    var body: some View {
        VStack(spacing: 8) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsArchiveScene(
                    t: ctx.isStill ? 0.43 : elapsed(at: date),
                    clock: ctx.isStill ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3_600),
                    sealedBefore: plays > 1,
                    played: plays > 0 || ctx.isStill,
                    flap: ctx["flap"],
                    bounce: ctx["bounce"],
                    squash: ctx["squash"]
                )
            }
            .frame(width: 250, height: 222)
            .contentShape(Rectangle())
            .onTapGesture { archive() }
            counter
            DemoHint(text: L("Tap to archive the document", "点击归档文件"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.5) { archive() }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private var counter: some View {
        HStack(spacing: 6) {
            Text(verbatim: "\(archived)")
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(archived)))
            Text(L("documents archived", "份文件已归档"), ctx.language)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func archive() {
        // One document at a time: taps are ignored until the box is sealed.
        guard elapsed(at: .now) > Self.busy else { return }
        start = .now
        plays += 1
        Haptics.tap(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.landing) {
            withAnimation(.snappy(duration: 0.35)) { archived += 1 }
        }
        IconsHaptics.later(Self.landing, preview: ctx.isPreview) { Haptics.tap(.medium) }
        IconsHaptics.later(0.9, preview: ctx.isPreview) { Haptics.tap(.rigid) }
    }
}

private struct IconsArchiveScene: View {
    let t: Double
    let clock: Double
    /// The box was already taped by an earlier play, so this play starts by peeling the tape.
    let sealedBefore: Bool
    let played: Bool
    let flap: Double
    let bounce: Double
    let squash: Double

    private static let boxSize = CGSize(width: 136, height: 86)
    private static let flapThickness: CGFloat = 11
    private static let boxTop: CGFloat = 10
    private static let docRest: CGFloat = -64

    private let cardboard = LinearGradient(colors: [Color(hex: 0xEDBE7E), Color(hex: 0xCB8D4B)], startPoint: .top, endPoint: .bottom)
    private let flapFill = LinearGradient(colors: [Color(hex: 0xF6D09A), Color(hex: 0xE0A862)], startPoint: .top, endPoint: .bottom)

    // MARK: Motion

    private func openAngle(delay: Double) -> Double {
        let opening: Double = IconsCurve.spring(t - 0.05 - delay, response: 0.32, damping: 0.6)
        let closing: Double = IconsCurve.spring(t - 0.66 - delay * 1.4, response: 0.36, damping: 1 - bounce)
        return flap * opening * abs(1 - closing)
    }

    private var bodySquash: Double {
        squash * IconsCurve.ring(t - 0.56, decay: 12, frequency: 30)
            + 0.035 * IconsCurve.ring(t - 0.92, decay: 14, frequency: 32)
    }

    /// 0…1: tape down the front and the check on the label.
    private var seal: Double {
        let fresh: Double = IconsCurve.easeOut(IconsCurve.seg(t, 1.0, 1.22))
        guard sealedBefore else { return played ? fresh : 0 }
        return max(1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.12)), fresh)
    }

    var body: some View {
        let squashNow: Double = bodySquash
        ZStack {
            groundShadow(squash: squashNow)
            ZStack {
                interior
                document
                front
                flaps
            }
            .frame(width: 250, height: 222)
            .scaleEffect(x: CGFloat(1 + squashNow * 0.6), y: CGFloat(1 - squashNow), anchor: UnitPoint(x: 0.5, y: 0.93))
            freshDocument
        }
    }

    // MARK: Layers

    private func groundShadow(squash: Double) -> some View {
        Ellipse()
            .fill(Color.black.opacity(0.2))
            .frame(width: Self.boxSize.width * CGFloat(1.02 + squash * 1.2), height: 16)
            .blur(radius: 7)
            .offset(y: Self.boxTop + Self.boxSize.height + 2)
    }

    /// The dark mouth of the box, seen once the flaps are open.
    private var interior: some View {
        UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
            .fill(Color(hex: 0x7A4E26))
            .frame(width: Self.boxSize.width - 8, height: 14)
            .offset(y: Self.boxTop + 3)
    }

    private var front: some View {
        let size: CGSize = Self.boxSize
        return UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 5, style: .continuous)
            .fill(cardboard)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(hex: 0xA86C33).opacity(0.5))
                    .frame(height: 3)
            }
            .overlay(alignment: .top) { tape }
            .overlay { label.offset(y: 12) }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 5, style: .continuous))
            .frame(width: size.width, height: size.height)
            .offset(y: Self.boxTop + size.height / 2)
    }

    private var tape: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            .frame(width: 30, height: CGFloat(26 * seal))
    }

    private var label: some View {
        let stamp: Double = IconsCurve.spring(t - 1.12, response: 0.34, damping: 0.5)
        let stamped: Double = sealedBefore ? max(1 - IconsCurve.seg(t, 0, 0.12), stamp) : (played ? stamp : 0)
        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .frame(width: 64, height: 32)
            .overlay {
                HStack(spacing: 7) {
                    ZStack {
                        Circle().fill(Palette.green)
                        IconsCheck()
                            .stroke(.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .frame(width: 9, height: 8)
                    }
                    .frame(width: 17, height: 17)
                    .scaleEffect(CGFloat(max(stamped, 0)))
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(Color(hex: 0x8A6A45).opacity(0.55)).frame(width: 26, height: 4)
                        Capsule().fill(Color(hex: 0x8A6A45).opacity(0.3)).frame(width: 18, height: 4)
                    }
                }
            }
            .shadow(color: Color(hex: 0x7A4E26).opacity(0.3), radius: 2, y: 1)
    }

    private var flaps: some View {
        let half: CGFloat = Self.boxSize.width / 2 + 2
        let thickness: CGFloat = Self.flapThickness
        return HStack(spacing: 0) {
            flapPiece
                .frame(width: half, height: thickness)
                .rotationEffect(.degrees(-openAngle(delay: 0)), anchor: .bottomLeading)
            flapPiece
                .frame(width: half, height: thickness)
                .rotationEffect(.degrees(openAngle(delay: 0.06)), anchor: .bottomTrailing)
        }
        .offset(y: Self.boxTop - thickness / 2 + 1)
    }

    private var flapPiece: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(flapFill)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color(hex: 0xB67A3C).opacity(0.55), lineWidth: 1))
    }

    private var document: some View {
        // Settled: the sheet waits above the box and bobs.
        let resting: Bool = t > 1.9
        let hop: Double = resting ? 0 : IconsCurve.easeOut(IconsCurve.seg(t, 0.08, 0.28))
        let fall: Double = resting ? 0 : IconsCurve.easeIn(IconsCurve.seg(t, 0.28, 0.56))
        let bob: Double = resting ? 3 * sin(clock * 2.2) * IconsCurve.seg(t, 1.9, 2.5) : 0
        let y: Double = Double(Self.docRest) - 14 * hop + 126 * fall + bob
        let tilt: Double = -7 * hop + 17 * fall
        // After the landing the sheet stays hidden until the fresh one has taken its place.
        let visible: Bool = t < 0.6 || resting
        return IconsArchiveDocument()
            .scaleEffect(CGFloat(1 - 0.18 * fall))
            .rotationEffect(.degrees(tilt))
            .offset(y: CGFloat(y))
            .opacity(visible ? 1 : 0)
    }

    /// The next document, springing in above the sealed box (outside the squashing group).
    private var freshDocument: some View {
        let arrive: Double = IconsCurve.spring(t - 1.3, response: 0.4, damping: 0.6)
        let live: Bool = t >= 1.3 && t <= 1.9
        return IconsArchiveDocument()
            .scaleEffect(CGFloat(0.5 + 0.5 * arrive))
            .offset(y: Self.docRest - CGFloat(26 * (1 - arrive)))
            .opacity(live ? IconsCurve.seg(t, 1.3, 1.42) : 0)
    }
}

private struct IconsArchiveDocument: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.white)
            .frame(width: 56, height: 70)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(Palette.ocean).frame(width: 26, height: 6)
                    Capsule().fill(Color.black.opacity(0.14)).frame(width: 36, height: 4)
                    Capsule().fill(Color.black.opacity(0.14)).frame(width: 36, height: 4)
                    Capsule().fill(Color.black.opacity(0.14)).frame(width: 22, height: 4)
                }
                .padding(10)
            }
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 5)
    }
}
