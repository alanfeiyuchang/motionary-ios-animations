import SwiftUI

extension Effect {
    static let textImpactSlam = Effect(
        id: "text.impact-slam",
        category: .text,
        interaction: .tap,
        name: L("Impact Slam", "重击落字"),
        summary: L("Words drop out of the camera one by one and hit the page hard enough to shake the ones already there.", "词语一个个从镜头前砸向页面，力道大到让已经落下的词跟着一震。"),
        prompt: L(
            "Four heavy words in two lines arrive one at a time in reading order, 260 ms apart. Each starts 3.2 times too large, blurred 10 pt and transparent, as if right in front of the lens, and falls onto the page in 160 ms with accelerating speed. At impact it squashes about 10% and rings back through a fast damped oscillation, flashes bright for 80 ms, and a thin shock ring expands from 40% to 150% of its size behind it, fading within 0.35 s. Every word that has already landed is jolted 5 pt by the hit and shivers to rest in about a quarter second. The last word, set in a warm gradient, lands harder: a bigger ring, a stronger jolt and a heavy haptic. Each word keeps a slight tilt of up to 2°. It reads like a drum fill.",
            "两行四个特粗的词按阅读顺序逐个到场，间隔260毫秒。每个词起初放大到3.2倍、模糊10pt且完全透明，像贴在镜头前，然后用160毫秒加速砸向页面。触地瞬间它压扁约10%，再以快速的阻尼振荡弹回，同时变亮80毫秒，背后一圈细细的冲击环从自身的40%扩到150%，在0.35秒内淡去。已经落下的每个词都被这一击震开5pt，约四分之一秒内抖动着停稳。最后一个词用暖色渐变，落得更重：更大的冲击环、更强的震动和一次重触感。每个词保留最多2°的轻微倾斜。整体读起来像一段鼓点。"
        ),
        implementation: L(
            "A TimelineView supplies the time since the last start; every word derives its scale, blur, opacity, squash, shock ring and the summed jolts of later impacts from that single clock with closed-form curves, so replaying is just resetting the start date.",
            "TimelineView 提供自上次开始以来的时间；每个词都由这一个时钟、用解析曲线算出自己的缩放、模糊、透明度、压扁、冲击环，以及后续每次撞击叠加的震动，所以重播只需要重置起始时间。"
        ),
        apis: ["TimelineView(.animation)", "scaleEffect", "blur(radius:)", "rotationEffect", "Circle().strokeBorder"],
        tags: ["slam", "impact", "stamp", "shake", "kinetic", "重击", "砸落", "冲击", "震动", "逐词"],
        params: [
            .slider("interval", L("Word interval", "词间隔"), 0.12...0.6, default: 0.26, unit: "s"),
            .slider("drop", L("Start scale", "起始缩放"), 1.5...5, default: 3.2, decimals: 1, unit: "×"),
            .slider("shake", L("Jolt", "震动幅度"), 0...12, default: 5, decimals: 0, unit: "pt"),
            .toggle("ring", L("Shock ring", "冲击环"), default: true),
        ]
    ) { ctx in
        TextImpactSlamDemo(ctx: ctx)
    }
}

private struct SlamPose {
    var scale: CGFloat = 1
    var squash: CGFloat = 0
    var blur: CGFloat = 0
    var opacity: Double = 1
    var offset: CGSize = .zero
    var flash: Double = 0
    /// Time since this word's impact, nil before it.
    var sinceImpact: Double? = nil
}

private struct TextImpactSlamDemo: View {
    let ctx: DemoContext
    @State private var start = Date()
    @State private var haptics: Task<Void, Never>?

    private static let fall: Double = 0.16
    private static let tilts: [Double] = [-2, 1.2, 1.6, -1.4]

    private var lines: [[String]] {
        ctx.language == .zh ? [["字字", "落地"], ["掷地", "有声"]] : [["MAKE", "IT"], ["LAND", "HARD"]]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let time: Double = ctx.isStill ? 1000 : timeline.date.timeIntervalSince(start)
            content(time: time)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Tap to slam again", "点击再砸一次"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture { replay(byHand: true) }
        .autoplay(ctx.isPreview, every: ctx["interval"] * 4 + 2.4, delay: 2.6, intro: false) { replay(byHand: false) }
        .onDisappear { haptics?.cancel() }
    }

    private func content(time: Double) -> some View {
        let words = lines
        let count: Int = words.reduce(0) { $0 + $1.count }
        return VStack(spacing: -2) {
            ForEach(words.indices, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(words[row].indices, id: \.self) { column in
                        let index: Int = row * 2 + column
                        word(words[row][column], index: index, count: count, time: time)
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }

    private func word(_ text: String, index: Int, count: Int, time: Double) -> some View {
        let pose = pose(index: index, count: count, time: time)
        let last: Bool = index == count - 1
        let size: CGFloat = ctx.language == .zh ? 62 : 56
        return Text(verbatim: text)
            .font(.system(size: size, weight: .black))
            .foregroundStyle(last ? AnyShapeStyle(Palette.sunset) : AnyShapeStyle(Color.primary))
            .brightness(pose.flash * 0.35)
            .fixedSize()
            .background {
                if ctx.bool("ring"), let since = pose.sinceImpact, since < 0.35 {
                    let u: Double = since / 0.35
                    let grow: CGFloat = (0.4 + 1.1 * CGFloat(TextFXCurve.easeOutCubic(u))) * (last ? 1.35 : 1)
                    Capsule()
                        .strokeBorder(last ? Palette.coral : Color.primary, lineWidth: 3 * (1 - u) + 0.5)
                        .opacity(0.55 * (1 - u))
                        .padding(.horizontal, -10)
                        .scaleEffect(grow)
                }
            }
            .scaleEffect(x: pose.scale * (1 + pose.squash * 0.6), y: pose.scale * (1 - pose.squash))
            .rotationEffect(.degrees(Self.tilts[index % Self.tilts.count]))
            .blur(radius: pose.blur)
            .opacity(pose.opacity)
            .offset(pose.offset)
    }

    private func pose(index: Int, count: Int, time: Double) -> SlamPose {
        let interval: Double = ctx["interval"]
        let local: Double = time - Double(index) * interval
        var pose = SlamPose()
        guard local >= 0 else {
            pose.opacity = 0
            return pose
        }
        if local < Self.fall {
            // Falling: accelerating toward the page.
            let u: Double = local / Self.fall
            let drop: Double = ctx["drop"]
            pose.scale = CGFloat(drop + (1 - drop) * u * u)
            pose.blur = CGFloat(10 * (1 - u))
            pose.opacity = min(u * 2.5, 1)
            return pose
        }
        let since: Double = local - Self.fall
        pose.sinceImpact = since
        pose.squash = CGFloat(0.1 * exp(-since * 13) * cos(since * 36))
        pose.flash = since < 0.08 ? 1 - since / 0.08 : 0

        // Jolts from every later impact.
        var x: Double = 0
        var y: Double = 0
        for other in (index + 1)..<max(count, index + 1) {
            let hit: Double = time - (Double(other) * interval + Self.fall)
            guard hit >= 0, hit < 0.6 else { continue }
            let strength: Double = ctx["shake"] * (other == count - 1 ? 1.7 : 1)
            let wave: Double = exp(-hit * 12) * cos(hit * 58)
            let side: Double = (other + index) % 2 == 0 ? 1 : -1
            x += strength * 0.45 * wave * side
            y += strength * wave * (other / 2 >= index / 2 ? -1 : 1)
        }
        pose.offset = CGSize(width: x, height: y)
        return pose
    }

    private func replay(byHand: Bool) {
        start = Date()
        haptics?.cancel()
        guard byHand, !ctx.isPreview else { return }
        let interval: Double = ctx["interval"]
        let count: Int = lines.reduce(0) { $0 + $1.count }
        haptics = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.fall))
            for index in 0..<count {
                guard !Task.isCancelled else { return }
                Haptics.tap(index == count - 1 ? .heavy : .rigid)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
}
