import SwiftUI

extension Effect {
    static let iconsGiftOpen = Effect(
        id: "icons.gift-open",
        category: .icons,
        interaction: .tap,
        name: L("Gift Open", "礼盒开启"),
        summary: L("The box crouches, the lid pops up and hovers, sparkles fan out of the opening and the bow wiggles.", "礼盒先一蹲，盒盖弹起悬停，星芒从开口呈扇形飞出，蝴蝶结随之抖动。"),
        prompt: L(
            "A pink gift box with a gold ribbon and a two-loop bow on its lid. On tap the box crouches 6% for 0.1 s, then the lid springs 56 pt up (response 0.42 s, damping 0.55), tilting 13° and drifting 10 pt aside, and keeps hovering with a slow 3 pt bob. A warm glow swells from the dark opening. From 0.16 s twelve four-point sparkles fly out in an upward fan, each on its own heading, travelling 80 to 160 pt on an ease-out with a touch of gravity, spinning as they swell, shrink and fade within 0.9 s. The bow's loops wiggle 16° on a decaying shake. While open, three small stars keep twinkling above the box. Tapping again drops the lid: it bounces twice on the rim and the box squashes 7%. A success haptic with the burst, a rigid one on closing.",
            "一只粉色礼盒，系着金色丝带，盒盖上是双环蝴蝶结。点击后礼盒先用0.1秒下蹲6%，盒盖随即以弹簧（响应0.42秒、阻尼0.55）弹起56 pt，倾斜13°、偏移10 pt，之后以3 pt幅度缓缓浮动。开口涌出暖光。0.16秒起，十二颗四角星芒呈扇形向上飞出，以缓出曲线飞行80到160 pt并略受重力，边旋转边放大、缩小，在0.9秒内淡出。蝴蝶结两环以衰减抖动摆动16°。打开期间三颗小星在上方持续闪烁。再次点击盒盖落下，在盒沿弹两下，盒身压扁7%。星芒迸出配成功触感，合上配清脆触感。"
        ),
        implementation: L(
            "A two-state play head with a TimelineView: the lid's lift is an analytic spring going up and a rectified spring coming down (so it bounces on the rim); each sparkle is a pure function of time and a hashed seed (heading, reach, spin, delay).",
            "双状态播放头配合 TimelineView：盒盖升起用解析弹簧，落下用取绝对值的弹簧（因此会在盒沿反弹）；每颗星芒都是时间与哈希种子（方向、射程、自转、延迟）的纯函数。"
        ),
        apis: ["TimelineView(.animation)", "Shape", "rotationEffect(_:anchor:)", "scaleEffect(x:y:anchor:)", "blur(radius:)"],
        tags: ["gift", "present", "open", "sparkle", "reward", "礼物", "礼盒", "开启", "星芒", "奖励"],
        params: [
            .slider("lift", L("Lid lift", "盒盖升起"), 30...80, default: 56, decimals: 0, unit: "pt"),
            .slider("sparkles", L("Sparkles", "星芒数量"), 4...18, default: 12, step: 1, decimals: 0),
            .slider("wiggle", L("Bow wiggle", "蝴蝶结抖动"), 0...30, default: 16, decimals: 0, unit: "°"),
        ]
    ) { ctx in
        IconsGiftOpenDemo(ctx: ctx)
    }
}

private struct IconsGiftOpenDemo: View {
    let ctx: DemoContext
    /// On = open.
    @State private var play = IconsPlayhead(isOn: false)

    var body: some View {
        VStack(spacing: 8) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsGiftScene(
                    open: ctx.isStill ? true : play.isOn,
                    t: ctx.isStill ? 0.46 : play.elapsed(at: date),
                    clock: ctx.isStill ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3_600),
                    lift: ctx["lift"],
                    sparkles: ctx.int("sparkles"),
                    wiggle: ctx["wiggle"]
                )
            }
            .frame(width: 250, height: 236)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            DemoHint(text: L("Tap to open or close the gift", "点击打开或合上礼盒"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.0) { toggle() }
    }

    private func toggle() {
        play.toggle(onDuration: 1.1, offDuration: 0.6)
        if play.isOn {
            Haptics.tap(.light)
            IconsHaptics.later(0.18, preview: ctx.isPreview) { Haptics.success() }
        } else {
            Haptics.tap(.light)
            IconsHaptics.later(0.14, preview: ctx.isPreview) { Haptics.tap(.rigid) }
        }
    }
}

private struct IconsGiftScene: View {
    let open: Bool
    let t: Double
    let clock: Double
    let lift: Double
    let sparkles: Int
    let wiggle: Double

    private static let box = CGSize(width: 124, height: 86)
    private static let lid = CGSize(width: 142, height: 32)
    /// Top edge of the box, relative to the scene's centre.
    private static let boxTop: CGFloat = 12
    private static let sparkColors: [Color] = [Color(hex: 0xFFD466), Color(hex: 0xFFF1B8), Color(hex: 0xFF8CBE), Color(hex: 0x7CD8FF), Color(hex: 0x8CF0C8)]

    private let ribbon = LinearGradient(colors: [Color(hex: 0xFFE08A), Color(hex: 0xF5A623)], startPoint: .leading, endPoint: .trailing)

    // MARK: Motion

    /// 0 = lid on the box, 1 = lifted.
    private var raise: Double {
        if open { return IconsCurve.spring(t - 0.1, response: 0.42, damping: 0.55) }
        // Rectified, so the lid bounces on the rim instead of passing through it.
        return abs(1 - IconsCurve.spring(t, response: 0.32, damping: 0.42))
    }

    private var squash: Double {
        if open { return 0.06 * IconsCurve.bump(IconsCurve.seg(t, 0, 0.2)) }
        return 0.07 * IconsCurve.ring(t - 0.11, decay: 12, frequency: 30) * IconsCurve.seg(t, 0.11, 0.13)
    }

    var body: some View {
        let up: Double = raise
        let press: Double = squash
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 130 * CGFloat(1 + press), height: 14)
                .blur(radius: 8)
                .offset(y: Self.boxTop + Self.box.height + 3)
            glow(up: up)
            boxBody
                .scaleEffect(x: CGFloat(1 + press * 0.6), y: CGFloat(1 - press), anchor: .bottom)
                .offset(y: Self.boxTop + Self.box.height / 2)
            twinkles(up: up)
            burst
            lidView(up: up)
                .offset(y: CGFloat(press) * Self.box.height)
        }
    }

    // MARK: Layers

    private var boxBody: some View {
        let size: CGSize = Self.box
        let shape = UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 4, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [Color(hex: 0xFF86B0), Color(hex: 0xEE4A85)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) {
                // The dark mouth of the box.
                Rectangle().fill(Color(hex: 0x9C1F52)).frame(height: 12)
            }
            .overlay { Rectangle().fill(ribbon).frame(width: 24) }
            .overlay(alignment: .top) {
                Rectangle().fill(Color.black.opacity(0.14)).frame(height: 5).offset(y: 12)
            }
            .clipShape(shape)
            .frame(width: size.width, height: size.height)
            .shadow(color: Color(hex: 0xEE4A85).opacity(0.35), radius: 14, y: 8)
    }

    private func glow(up: Double) -> some View {
        let shown: Double = IconsCurve.unit(up)
        let breathe: Double = 0.85 + 0.15 * sin(clock * 2.6)
        return Ellipse()
            .fill(RadialGradient(colors: [Color(hex: 0xFFE9A0).opacity(0.95), Color(hex: 0xFFC247).opacity(0.5), Color(hex: 0xFFC247).opacity(0)], center: .center, startRadius: 2, endRadius: 80))
            .frame(width: 160, height: 120)
            .blur(radius: 6)
            .offset(y: Self.boxTop - 22)
            .opacity(shown * breathe * (open ? 1 : 0.6))
    }

    private func lidView(up: Double) -> some View {
        let size: CGSize = Self.lid
        let bob: Double = open ? 3 * sin(clock * 2.4) * IconsCurve.seg(t, 0.8, 1.4) : 0
        let shake: Double = open
            ? IconsCurve.shake(t - 0.1, decay: 5, frequency: 20)
            : 0.4 * IconsCurve.shake(t - 0.11, decay: 8, frequency: 24)
        return VStack(spacing: -5) {
            bow(swing: wiggle * shake)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFF9CC0), Color(hex: 0xF25C93)], startPoint: .top, endPoint: .bottom))
                .overlay { Rectangle().fill(ribbon).frame(width: 24) }
                .overlay(alignment: .top) {
                    Capsule().fill(.white.opacity(0.35)).frame(height: 3).padding(.horizontal, 12).padding(.top, 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .frame(width: size.width, height: size.height)
                .shadow(color: Color(hex: 0xC2306B).opacity(0.35), radius: 6, y: 4)
        }
        .rotationEffect(.degrees(13 * up), anchor: .bottom)
        .offset(
            x: CGFloat(10 * up),
            y: Self.boxTop - 4 - (size.height + 23) / 2 + size.height / 2 - CGFloat(lift * up) + CGFloat(bob)
        )
    }

    private func bow(swing: Double) -> some View {
        ZStack {
            loop
                .rotationEffect(.degrees(-24 - swing), anchor: .bottomTrailing)
                .offset(x: -19, y: -3)
            loop
                .rotationEffect(.degrees(24 + swing), anchor: .bottomLeading)
                .offset(x: 19, y: -3)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFFE9A0), Color(hex: 0xF5A623)], startPoint: .top, endPoint: .bottom))
                .frame(width: 17, height: 17)
                .offset(y: 5)
        }
        .frame(width: 96, height: 28)
        .shadow(color: Color(hex: 0xC2861A).opacity(0.4), radius: 3, y: 2)
    }

    private var loop: some View {
        Ellipse()
            .stroke(ribbon, lineWidth: 8)
            .frame(width: 32, height: 20)
    }

    private var burst: some View {
        ZStack {
            ForEach(0..<max(sparkles, 0), id: \.self) { index in
                spark(index)
            }
        }
        .offset(y: Self.boxTop)
        .opacity(open ? 1 : 0)
    }

    private func spark(_ index: Int) -> some View {
        let count: Double = Double(max(sparkles, 1))
        let delay: Double = 0.16 + 0.14 * IconsCurve.hash(index * 3 + 1)
        let life: Double = 0.75 + 0.3 * IconsCurve.hash(index * 3 + 2)
        let p: Double = IconsCurve.seg(t, delay, delay + life)
        let eased: Double = IconsCurve.easeOut(p)
        // An upward fan from 150° to 30°, evenly spread with a little jitter.
        let spread: Double = (Double(index) + 0.5) / count
        let heading: Double = (-150 + 120 * spread + 14 * (IconsCurve.hash(index * 3 + 5) - 0.5)) * .pi / 180
        let reach: Double = 80 + 80 * IconsCurve.hash(index * 3 + 7)
        let size: CGFloat = CGFloat(16 + 13 * IconsCurve.hash(index * 3 + 9))
        let live: Bool = p > 0 && p < 1
        return IconsSparkle()
            .fill(Self.sparkColors[index % Self.sparkColors.count])
            .frame(width: size, height: size)
            .scaleEffect(CGFloat(0.3 + 1.1 * IconsCurve.bump(IconsCurve.unit(p * 1.15))))
            .rotationEffect(.degrees(200 * p * (index.isMultiple(of: 2) ? 1 : -1)))
            .offset(x: CGFloat(cos(heading) * reach * eased), y: CGFloat(sin(heading) * reach * eased + 46 * p * p))
            .opacity(live ? 1 - IconsCurve.easeIn(p) : 0)
    }

    /// Small stars that keep twinkling above the open box.
    private func twinkles(up: Double) -> some View {
        let shown: Double = open ? IconsCurve.seg(t, 0.7, 1.2) : 0
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let beat: Double = 0.5 + 0.5 * sin(clock * (2.2 + 0.5 * Double(index)) + Double(index) * 2.1)
                IconsSparkle()
                    .fill(Color(hex: 0xFFE08A))
                    .frame(width: 17, height: 17)
                    .scaleEffect(CGFloat(0.5 + 0.6 * beat))
                    .offset(x: CGFloat(-46 + 44 * index), y: Self.boxTop - 30 - CGFloat(index == 1 ? 20 : 0))
                    .opacity(shown * (0.3 + 0.7 * beat))
            }
        }
    }
}
