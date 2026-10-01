import SwiftUI

extension Effect {
    static let iconsEyeBlink = Effect(
        id: "icons.eye-blink",
        category: .icons,
        interaction: .tap,
        name: L("Password Eye", "密码眼睛"),
        summary: L("The eye shuts into a lashed line and a slash cuts across; reopening, it widens, blinks and glances at the password.", "眼睛合成一条带睫毛的弧线，斜杠划过；再次睁开时先睁大、眨一下，再瞥一眼密码。"),
        prompt: L(
            "A large outlined eye with an indigo iris sits above a password field showing its characters. On tap the upper and lower lids close on a spring (response 0.38 s, damping 0.8) into a single downward arc while the iris shrinks away behind them; four lashes sprout beneath the arc 35 ms apart with a small overshoot, then a diagonal slash draws across in 0.27 s, cutting a clean gap through the strokes it crosses. Below, the characters turn into dots from left to right, 30 ms apart, each blurring out as its dot scales in. Tapping again retracts the slash and lashes, springs the lids open slightly too wide (damping 0.55), blinks once at 0.52 s and lets the iris glance down at the revealed password. Expressive and a little alive, yet instantly readable.",
            "带靛蓝虹膜的大号描边眼睛，下方是显示明文的密码框。点击后上下眼睑以弹簧（响应0.38秒、阻尼0.8）合拢成一条向下弯的弧线，虹膜随之缩没；四根睫毛相隔35毫秒从弧线下长出，略带过冲；随后一道斜杠用0.27秒划过，在经过的线条上切出干净缺口。下方字符从左到右相隔30毫秒变成圆点，字符模糊淡出，圆点放大出现。再次点击时斜杠与睫毛收回，眼睑弹开且略微睁得过大（阻尼0.55），0.52秒时眨一下，虹膜向下瞥一眼刚显示的密码。有表情、有生命感，却一眼能读懂。"
        ),
        implementation: L(
            "The lids are one Shape whose two quadratic control points move with an openness value computed from the seconds since the tap; the iris is masked by the same shape. The slash's gap is a wider copy stroked with destinationOut inside a compositing group.",
            "眼睑是一个 Shape，两条二次曲线的控制点随“睁开度”移动，而睁开度由点击后的秒数算出；虹膜用同一形状做遮罩。斜杠的缺口是合成组内一条更粗、以 destinationOut 描边的副本。"
        ),
        apis: ["TimelineView(.animation)", "Shape", "Path.addQuadCurve", "blendMode(.destinationOut)", "compositingGroup()", "trim(from:to:)"],
        tags: ["password", "eye", "show", "hide", "visibility", "secure field", "密码", "眼睛", "显示", "隐藏", "可见性"],
        params: [
            .slider("lashes", L("Lashes", "睫毛数量"), 0...6, default: 4, step: 1, decimals: 0),
            .toggle("blink", L("Blink on reopen", "睁开时眨眼"), default: true),
            .slider("response", L("Lid response", "眼睑响应"), 0.25...0.7, default: 0.38, unit: "s"),
            .slider("stagger", L("Character stagger", "字符间隔"), 0...0.06, default: 0.03, unit: "s"),
        ]
    ) { ctx in
        IconsEyeBlinkDemo(ctx: ctx)
    }
}

/// An almond eye outline. `open` 1 = wide open, 0 = both lids on one downward arc.
private struct IconsEyeShape: Shape {
    var open: Double

    static let sag: CGFloat = 0.2
    static let lift: CGFloat = 0.92

    func path(in rect: CGRect) -> Path {
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        let closed: CGFloat = rect.height * Self.sag
        let reach: CGFloat = rect.height * Self.lift
        let amount: CGFloat = CGFloat(open)
        let upper: CGFloat = rect.midY + closed + (-reach - closed) * amount
        let lower: CGFloat = rect.midY + closed + (reach - closed) * amount
        var path = Path()
        path.move(to: left)
        path.addQuadCurve(to: right, control: CGPoint(x: rect.midX, y: upper))
        path.addQuadCurve(to: left, control: CGPoint(x: rect.midX, y: lower))
        path.closeSubpath()
        return path
    }
}

/// Lashes hanging from the closed-lid arc; `lengths[i]` is 0…1+ for each lash.
private struct IconsLashShape: Shape {
    let lengths: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count: Int = lengths.count
        guard count > 0 else { return path }
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        let control = CGPoint(x: rect.midX, y: rect.midY + rect.height * IconsEyeShape.sag)
        for index in 0..<count {
            let length: CGFloat = CGFloat(lengths[index])
            guard length > 0.02 else { continue }
            let u: CGFloat = count == 1 ? 0.5 : 0.2 + 0.6 * CGFloat(index) / CGFloat(count - 1)
            let x: CGFloat = (1 - u) * (1 - u) * left.x + 2 * u * (1 - u) * control.x + u * u * right.x
            let y: CGFloat = (1 - u) * (1 - u) * left.y + 2 * u * (1 - u) * control.y + u * u * right.y
            let fan: CGFloat = (u - 0.5) * 1.1
            let root = CGPoint(x: x + sin(fan) * 7, y: y + cos(fan) * 7)
            path.move(to: root)
            path.addLine(to: CGPoint(x: root.x + sin(fan) * 12 * length, y: root.y + cos(fan) * 12 * length))
        }
        return path
    }
}

private struct IconsEyeBlinkDemo: View {
    let ctx: DemoContext
    /// On = hidden (eye shut and slashed).
    @State private var play = IconsPlayhead(isOn: false)

    private static let hideDuration: Double = 0.75
    private static let showDuration: Double = 0.95

    var body: some View {
        VStack(spacing: 12) {
            IconsTimeline(preview: ctx.isPreview) { date in
                let t: Double = play.elapsed(at: date)
                VStack(spacing: 18) {
                    IconsEyeGlyph(
                        hidden: play.isOn,
                        t: t,
                        lashes: ctx.int("lashes"),
                        blink: ctx.bool("blink"),
                        response: ctx["response"]
                    )
                    .frame(width: 180, height: 122)
                    IconsPasswordField(hidden: play.isOn, t: t, stagger: ctx["stagger"])
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            DemoHint(text: L("Tap to hide or show the password", "点击隐藏或显示密码"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.1) { toggle() }
    }

    private func toggle() {
        play.toggle(onDuration: Self.hideDuration, offDuration: Self.showDuration)
        Haptics.tap(.light)
        if play.isOn {
            IconsHaptics.later(0.5, preview: ctx.isPreview) { Haptics.tap(.rigid) }
        }
    }
}

private struct IconsEyeGlyph: View {
    let hidden: Bool
    let t: Double
    let lashes: Int
    let blink: Bool
    let response: Double

    private static let eyeSize = CGSize(width: 132, height: 74)
    private static let strokeWidth: CGFloat = 8

    // MARK: Motion

    private var openness: Double {
        if hidden {
            return 1 - IconsCurve.spring(t, response: response, damping: 0.8)
        }
        let opened: Double = IconsCurve.spring(t - 0.1, response: response, damping: 0.55)
        let shut: Double = blink ? IconsCurve.bump(IconsCurve.seg(t, 0.52, 0.72)) : 0
        return opened * (1 - shut)
    }

    private func lashLength(_ index: Int) -> Double {
        if hidden {
            return IconsCurve.spring(t - 0.16 - Double(index) * 0.035, response: 0.3, damping: 0.55)
        }
        return 1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.14))
    }

    private var slash: Double {
        if hidden { return IconsCurve.easeOut(IconsCurve.seg(t, 0.28, 0.55)) }
        return 1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.16))
    }

    /// The iris looks down at the field once the eye is open again.
    private var glance: Double {
        hidden ? 0 : IconsCurve.bump(IconsCurve.seg(t, 0.76, 1.3))
    }

    var body: some View {
        let open: Double = openness
        let cut: Double = slash
        let dim: Double = hidden ? IconsCurve.seg(t, 0, 0.3) : 1 - IconsCurve.seg(t, 0, 0.3)
        let nudge: CGFloat = hidden ? 3 * CGFloat(IconsCurve.bump(IconsCurve.seg(t, 0.05, 0.4))) : 0
        ZStack {
            eye(open: open)
            slashLine
                .trim(from: 0, to: CGFloat(cut))
                .stroke(.black, style: StrokeStyle(lineWidth: Self.strokeWidth * 2.3, lineCap: .round))
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .overlay {
            slashLine
                .trim(from: 0, to: CGFloat(cut))
                .stroke(Color.primary, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))
        }
        .opacity(1 - 0.35 * dim)
        .offset(y: nudge)
    }

    private var slashLine: some Shape {
        IconsLine(from: UnitPoint(x: 0.21, y: 0.17), to: UnitPoint(x: 0.79, y: 0.83))
    }

    private func eye(open: Double) -> some View {
        let size: CGSize = Self.eyeSize
        let shown: Double = IconsCurve.unit(open)
        let count: Int = max(lashes, 0)
        let lengths: [Double] = (0..<count).map { lashLength($0) }
        return ZStack {
            iris
                .scaleEffect(CGFloat(0.55 + 0.45 * min(open, 1.15)))
                .offset(y: CGFloat(7 * glance + 10 * (1 - shown)))
                .mask(IconsEyeShape(open: open).frame(width: size.width, height: size.height))
                .opacity(IconsCurve.unit(shown * 3))
            IconsEyeShape(open: open)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size.width, height: size.height)
            IconsLashShape(lengths: lengths)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: Self.strokeWidth * 0.8, lineCap: .round))
                .frame(width: size.width, height: size.height)
        }
    }

    private var iris: some View {
        ZStack {
            Circle().fill(Palette.primary)
            Circle()
                .fill(Color(hex: 0x1B1640))
                .frame(width: 16, height: 16)
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 8, height: 8)
                .offset(x: -8, y: -9)
        }
        .frame(width: 40, height: 40)
    }
}

private struct IconsPasswordField: View {
    let hidden: Bool
    let t: Double
    let stagger: Double

    private static let characters: [String] = ["M", "o", "t", "i", "o", "n", "2", "6"]

    /// 0 = dot, 1 = readable character.
    private func reveal(_ index: Int) -> Double {
        let delay: Double = Double(index) * stagger
        if hidden {
            return 1 - IconsCurve.easeOut(IconsCurve.seg(t, 0.1 + delay, 0.3 + delay))
        }
        return IconsCurve.easeOut(IconsCurve.seg(t, 0.2 + delay, 0.42 + delay))
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                ForEach(Self.characters.indices, id: \.self) { index in
                    slot(index)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(width: 236, height: 52)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
    }

    private func slot(_ index: Int) -> some View {
        let shown: Double = reveal(index)
        return ZStack {
            Circle()
                .fill(Color.primary)
                .frame(width: 9, height: 9)
                .scaleEffect(CGFloat(1 - 0.6 * shown))
                .opacity(1 - shown)
            Text(verbatim: Self.characters[index])
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .blur(radius: CGFloat(5 * (1 - shown)))
                .offset(y: CGFloat(6 * (1 - shown)))
                .opacity(shown)
        }
        .frame(width: 19, height: 28)
    }
}
