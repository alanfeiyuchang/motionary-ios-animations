import SwiftUI

extension Effect {
    static let iconsMuteSlash = Effect(
        id: "icons.mute-slash",
        category: .icons,
        interaction: .tap,
        name: L("Mute Slash", "静音斜杠"),
        summary: L("Sound waves fold away from the outside in and a slash strikes the speaker; unmuting thumps and replays them outward.", "声波由外向内逐道收起，一道斜杠划过扬声器；取消静音时扬声器一震，声波由内向外重新弹出。"),
        prompt: L(
            "A blue speaker glyph with three curved sound waves. On tap the waves collapse one by one from the outermost in, 70 ms apart: each arc shortens toward its middle over 0.18 s while sliding 10 pt back to the cone and fading, and the speaker glides to the centre. As the last one goes, a red slash draws corner to corner in 0.26 s, cutting a clean gap through the speaker, which turns grey and rocks 5° on a decaying wobble as the slash lands. Unmuting retracts the slash in 0.16 s, the speaker thumps to about 109% and rings back, and the waves spring out from the innermost in the same 70 ms cadence (response 0.34 s, damping 0.5), each overshooting its size before settling. While sound is on, a soft brightness pulse keeps travelling outward through the waves. Clear, rhythmic and unmistakable.",
            "蓝色扬声器图标带三道弧形声波。点击后声波从最外一道起逐道收起，间隔70毫秒：每道圆弧用0.18秒向中点缩短，同时后退10 pt并淡出，扬声器滑到正中。最后一道消失时，红色斜杠在0.26秒内划过，在扬声器上切出干净缺口；扬声器变灰，并在斜杠落下时以衰减摆动晃动5°。取消静音时斜杠用0.16秒收回，扬声器“咚”地放大到约109%再回弹，声波以同样的70毫秒节奏从最内一道弹出（响应0.34秒、阻尼0.5），每道先放大过头再落定。有声时，一道柔和的亮度脉冲持续沿声波向外传递。"
        ),
        implementation: L(
            "A two-state play head with a TimelineView: each wave is an arc trimmed symmetrically around its middle by a staggered window (ease-in to collapse, analytic spring to return). The slash gap is a wider destinationOut stroke inside a compositing group.",
            "双状态播放头配合 TimelineView：每道声波是一段以中点为中心对称裁剪的圆弧，由错开的时间窗口驱动（收起用缓入，弹出用解析弹簧）。斜杠缺口是合成组里一条更粗的 destinationOut 描边。"
        ),
        apis: ["TimelineView(.animation)", "Shape.trim(from:to:)", "blendMode(.destinationOut)", "compositingGroup()", "rotationEffect"],
        tags: ["mute", "unmute", "speaker", "volume", "sound", "slash", "静音", "取消静音", "扬声器", "音量", "声音"],
        params: [
            .slider("waves", L("Waves", "声波数量"), 1...4, default: 3, step: 1, decimals: 0),
            .slider("stagger", L("Wave stagger", "声波间隔"), 0.02...0.15, default: 0.07, unit: "s"),
            .slider("damping", L("Wave damping", "声波阻尼"), 0.3...0.9, default: 0.5),
        ]
    ) { ctx in
        IconsMuteSlashDemo(ctx: ctx)
    }
}

/// The speaker body: a short box that flares into a cone, with rounded corners.
private struct IconsSpeakerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w: CGFloat = rect.width
        let h: CGFloat = rect.height
        let points: [CGPoint] = [
            CGPoint(x: rect.minX, y: rect.minY + h * 0.3),
            CGPoint(x: rect.minX + w * 0.4, y: rect.minY + h * 0.3),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX + w * 0.4, y: rect.minY + h * 0.7),
            CGPoint(x: rect.minX, y: rect.minY + h * 0.7),
        ]
        return IconsPath.roundedPolygon(points) { index in
            index == 1 || index == 4 ? w * 0.06 : w * 0.14
        }
    }
}

/// One sound wave: an arc of ±`half` degrees around the +x axis, centred on the rect's leading edge.
private struct IconsWaveArc: Shape {
    let radius: CGFloat
    let half: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(-half),
            endAngle: .degrees(half),
            clockwise: false
        )
        return path
    }
}

private struct IconsMuteSlashDemo: View {
    let ctx: DemoContext
    /// On = muted.
    @State private var play = IconsPlayhead(isOn: false)

    private var muteDuration: Double { Double(ctx.int("waves")) * ctx["stagger"] + 0.5 }
    private var unmuteDuration: Double { Double(ctx.int("waves")) * ctx["stagger"] + 0.7 }

    var body: some View {
        VStack(spacing: 12) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsMuteScene(
                    muted: play.isOn,
                    t: play.elapsed(at: date),
                    clock: ctx.isStill ? 0.5 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3_600),
                    waves: ctx.int("waves"),
                    stagger: ctx["stagger"],
                    damping: ctx["damping"]
                )
            }
            .frame(width: 250, height: 190)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            Text(play.isOn ? L("Muted", "已静音") : L("Sound on", "声音已开启"), ctx.language)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: play.isOn)
            DemoHint(text: L("Tap to mute or unmute", "点击静音或取消静音"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.0) { toggle() }
    }

    private func toggle() {
        play.toggle(onDuration: muteDuration, offDuration: unmuteDuration)
        if play.isOn {
            Haptics.tap(.light)
            IconsHaptics.later(Double(ctx.int("waves")) * ctx["stagger"] + 0.3, preview: ctx.isPreview) { Haptics.tap(.rigid) }
        } else {
            Haptics.tap(.medium)
        }
    }
}

private struct IconsMuteScene: View {
    let muted: Bool
    let t: Double
    let clock: Double
    let waves: Int
    let stagger: Double
    let damping: Double

    private static let speakerSize = CGSize(width: 62, height: 84)
    private static let strokeWidth: CGFloat = 9
    private static let firstRadius: CGFloat = 22
    private static let radiusStep: CGFloat = 20

    private var count: Int { max(waves, 1) }
    /// When the slash starts to draw (after the last wave has begun to fold).
    private var slashStart: Double { Double(count) * stagger + 0.04 }

    // MARK: Motion

    /// 0 = folded away, 1 = shown; springs past 1 on the way out.
    private func waveAmount(_ index: Int) -> Double {
        if muted {
            let order: Double = Double(count - 1 - index)
            return 1 - IconsCurve.easeIn(IconsCurve.seg(t, order * stagger, order * stagger + 0.18))
        }
        return IconsCurve.spring(t - 0.14 - Double(index) * stagger, response: 0.34, damping: damping)
    }

    private var slash: Double {
        if muted { return IconsCurve.easeOut(IconsCurve.seg(t, slashStart, slashStart + 0.26)) }
        return 1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.16))
    }

    /// 0 = sound on (blue), 1 = muted (grey).
    private var greyed: Double {
        if muted { return IconsCurve.seg(t, 0, slashStart + 0.2) }
        return 1 - IconsCurve.seg(t, 0, 0.2)
    }

    /// 0 = speaker beside its waves, 1 = speaker alone, slid to the middle of the stage.
    private var centred: Double {
        if muted { return IconsCurve.spring(t - Double(count) * stagger * 0.4, response: 0.45, damping: 0.8) }
        return 1 - IconsCurve.spring(t, response: 0.4, damping: 0.75)
    }

    var body: some View {
        let cut: Double = slash
        let grey: Double = greyed
        let rock: Double = muted ? -5 * IconsCurve.shake(t - slashStart - 0.2, decay: 9, frequency: 24) : 0
        let thump: Double = muted ? 0 : 0.16 * IconsCurve.shake(t - 0.1, decay: 9, frequency: 22)
        ZStack {
            glyph(grey: grey, thump: thump)
            slashLine
                .trim(from: 0, to: CGFloat(cut))
                .stroke(.black, style: StrokeStyle(lineWidth: Self.strokeWidth * 2.3, lineCap: .round))
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .overlay {
            slashLine
                .trim(from: 0, to: CGFloat(cut))
                .stroke(Palette.red, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))
                .shadow(color: Palette.red.opacity(0.4), radius: 6, y: 3)
        }
        .rotationEffect(.degrees(rock))
    }

    private var slashLine: some Shape {
        IconsLine(from: UnitPoint(x: 0.31, y: 0.25), to: UnitPoint(x: 0.69, y: 0.75))
    }

    // MARK: Layers

    private func glyph(grey: Double, thump: Double) -> some View {
        let size: CGSize = Self.speakerSize
        return HStack(spacing: 10) {
            IconsSpeakerShape()
                .frame(width: size.width, height: size.height)
                .scaleEffect(CGFloat(1 + thump), anchor: .trailing)
            ZStack(alignment: .leading) {
                ForEach(0..<count, id: \.self) { index in
                    wave(index)
                }
            }
            .frame(width: Self.firstRadius + Self.radiusStep * 3 + 6, height: 150, alignment: .leading)
        }
        .foregroundStyle(Palette.ocean)
        .overlay {
            // The same glyph in grey, cross-faded in while muted.
            HStack(spacing: 10) {
                IconsSpeakerShape()
                    .frame(width: size.width, height: size.height)
                Color.clear
                    .frame(width: Self.firstRadius + Self.radiusStep * 3 + 6, height: 150)
            }
            .foregroundStyle(Color(hex: 0x8E8E99))
            .opacity(grey)
        }
        .shadow(color: Palette.blue.opacity(0.3 * (1 - grey)), radius: 12, y: 7)
        .offset(x: 6 + 43 * CGFloat(centred))
    }

    private func wave(_ index: Int) -> some View {
        let amount: Double = waveAmount(index)
        let shown: Double = IconsCurve.unit(amount)
        let radius: CGFloat = Self.firstRadius + Self.radiusStep * CGFloat(index)
        // A brightness pulse travelling outward while the sound is on.
        let pulse: Double = 0.7 + 0.3 * max(0, sin(clock * 3.4 - Double(index) * 0.95))
        return IconsWaveArc(radius: radius, half: 40)
            .trim(from: CGFloat(0.5 - 0.5 * shown), to: CGFloat(0.5 + 0.5 * shown))
            .stroke(style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))
            .scaleEffect(CGFloat(0.82 + 0.18 * amount), anchor: .leading)
            .offset(x: -10 * CGFloat(1 - shown))
            .opacity(IconsCurve.unit(shown * 2.2) * pulse)
    }
}
