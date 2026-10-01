import SwiftUI

extension Effect {
    static let iconsLinkBreak = Effect(
        id: "icons.link-break",
        category: .icons,
        interaction: .tap,
        name: L("Link ↔ Unlink", "链接 ↔ 断开"),
        summary: L("Two chain links strain, snap apart with a burst of ticks and turn grey; relinking slams them together with a clink and a ring.", "两节链环先绷紧，随后啪地崩开、迸出几道短线并变灰；重新链接时猛地扣回，叮的一声荡开一圈光环。"),
        prompt: L(
            "Two blue capsule-shaped chain links, tilted 45° and interlocked, with a clean gap cut where one passes over the other. On tap they strain for 0.1 s, pulling 3 pt apart, then snap: each link springs 16 pt outward along the chain's axis (response 0.3 s, damping 0.5) and twists 9° away, overshooting before it settles, and the pair shakes 3 pt. At the break four short amber ticks shoot out across the axis, each drawing 16 pt and fading within 0.3 s, and the links fade to grey. Tapping again slams them back: they overshoot past their linked position, clink and settle, a ring expands from the joint to 240% over 0.45 s, and the blue returns. A rigid haptic marks the snap and the clink. Tense, then decisive.",
            "两节蓝色胶囊形链环倾斜45°互相扣住，一节压过另一节的地方切出干净的缺口。点击后它们先用0.1秒绷紧、被拉开3 pt，随即崩断：每节链环以弹簧（响应0.3秒、阻尼0.5）沿链条方向弹开16 pt，并扭开9°，过冲后落定，整体抖动3 pt。断开处迸出四道琥珀色短线，垂直于链条射出，各画出16 pt并在0.3秒内淡出，链环褪成灰色。再次点击，链环猛地扣回：先冲过扣合位置，“叮”地一碰再落定，一圈光环从接点在0.45秒内放大到240%，蓝色回归。崩断与扣合各有一记清脆触感。"
        ),
        implementation: L(
            "A two-state play head with a TimelineView: the separation is an analytic spring of the time since the tap (its overshoot is the clink). The over-under gap is a wider destinationOut stroke of the top link inside a compositing group, and the grey state is a cross-faded copy.",
            "双状态播放头配合 TimelineView：链环间距是“点击后秒数”的解析弹簧（过冲即那一下碰撞）。上下交叠处的缺口由合成组里上层链环更粗的 destinationOut 描边切出，灰色状态是一份交叉淡入的副本。"
        ),
        apis: ["TimelineView(.animation)", "Capsule", "blendMode(.destinationOut)", "compositingGroup()", "Shape.trim(from:to:)"],
        tags: ["link", "unlink", "chain", "break", "connect", "链接", "断开", "链条", "解除", "连接"],
        params: [
            .slider("gap", L("Break distance", "断开距离"), 8...30, default: 16, decimals: 0, unit: "pt"),
            .slider("damping", L("Damping", "阻尼"), 0.3...0.9, default: 0.5),
            .slider("ticks", L("Snap ticks", "迸出短线"), 0...6, default: 4, step: 1, decimals: 0),
        ]
    ) { ctx in
        IconsLinkBreakDemo(ctx: ctx)
    }
}

private struct IconsLinkBreakDemo: View {
    let ctx: DemoContext
    /// On = broken.
    @State private var play = IconsPlayhead(isOn: false)

    var body: some View {
        let broken: Bool = play.isOn
        VStack(spacing: 10) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsLinkScene(
                    broken: broken,
                    t: play.elapsed(at: date),
                    gap: ctx["gap"],
                    damping: ctx["damping"],
                    ticks: ctx.int("ticks")
                )
            }
            .frame(width: 250, height: 200)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            HStack(spacing: 6) {
                Image(systemName: broken ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(broken ? L("Link removed", "链接已断开") : L("Linked", "已链接"), ctx.language)
                    .contentTransition(.opacity)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .animation(.easeInOut(duration: 0.25), value: broken)
            DemoHint(text: L("Tap to break or restore the link", "点击断开或恢复链接"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.8) { toggle() }
    }

    private func toggle() {
        play.toggle(onDuration: 0.7, offDuration: 0.6)
        Haptics.tap(.light)
        IconsHaptics.later(play.isOn ? 0.1 : 0.09, preview: ctx.isPreview) { Haptics.tap(.rigid) }
    }
}

private struct IconsLinkScene: View {
    let broken: Bool
    let t: Double
    let gap: Double
    let damping: Double
    let ticks: Int

    private static let link = CGSize(width: 100, height: 62)
    private static let lineWidth: CGFloat = 12
    /// Half the distance between the two link centres while linked.
    private static let reach: CGFloat = 29
    private static let snap: Double = 0.1

    /// 0 = linked, 1 = apart. Negative while the links push past each other on the way back.
    private var apart: Double {
        if broken {
            let strain: Double = 3 / max(gap, 1) * IconsCurve.easeOut(IconsCurve.seg(t, 0, Self.snap))
            return max(strain, IconsCurve.spring(t - Self.snap, response: 0.3, damping: damping))
        }
        return 1 - IconsCurve.spring(t, response: 0.3, damping: damping)
    }

    private var greyed: Double {
        if broken { return IconsCurve.seg(t, Self.snap, Self.snap + 0.25) }
        return 1 - IconsCurve.seg(t, 0.04, 0.2)
    }

    var body: some View {
        let amount: Double = apart
        let jolt: Double = broken ? 3 * IconsCurve.shake(t - Self.snap, decay: 10, frequency: 34) : 0
        let grey: Double = greyed
        ZStack {
            clinkRing
            chain(amount: amount)
                .foregroundStyle(Palette.ocean)
                .overlay {
                    chain(amount: amount)
                        .foregroundStyle(Color(hex: 0x8E8E99))
                        .opacity(grey)
                }
                .shadow(color: Palette.blue.opacity(0.32 * (1 - grey)), radius: 12, y: 7)
            tickBurst
        }
        .rotationEffect(.degrees(-45))
        .offset(x: CGFloat(jolt), y: CGFloat(-jolt))
    }

    // MARK: Layers

    private func chain(amount: Double) -> some View {
        let shift: CGFloat = Self.reach + CGFloat(gap * amount)
        let twist: Double = 9 * amount
        let style = StrokeStyle(lineWidth: Self.lineWidth)
        return ZStack {
            ZStack {
                link(style: style)
                    .rotationEffect(.degrees(-twist))
                    .offset(x: -shift)
                // The top link cuts a gap out of the one beneath it.
                link(style: StrokeStyle(lineWidth: Self.lineWidth + 10))
                    .foregroundStyle(.black)
                    .rotationEffect(.degrees(-twist))
                    .offset(x: shift)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            link(style: style)
                .rotationEffect(.degrees(-twist))
                .offset(x: shift)
        }
        .frame(width: 250, height: 200)
    }

    private func link(style: StrokeStyle) -> some View {
        Capsule()
            .stroke(style: style)
            .frame(width: Self.link.width, height: Self.link.height)
    }

    /// Short strokes shooting out across the chain's axis at the moment it snaps.
    private var tickBurst: some View {
        let since: Double = t - Self.snap
        let p: Double = IconsCurve.seg(since, 0, 0.3)
        let live: Bool = broken && p > 0 && p < 1
        let count: Int = max(ticks, 0)
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                // Half of the ticks fly to each side of the axis, fanned ±28°.
                let side: Double = index.isMultiple(of: 2) ? -90 : 90
                let pairs: Double = Double(max((count + 1) / 2, 1))
                let fan: Double = pairs > 1 ? (Double(index / 2) / (pairs - 1) - 0.5) * 56 : 0
                Capsule()
                    .fill(Palette.amber)
                    .frame(width: CGFloat(16 * IconsCurve.bump(p)) + 2, height: 6)
                    .offset(x: CGFloat(40 + 22 * IconsCurve.easeOut(p)))
                    .rotationEffect(.degrees(side + fan))
            }
        }
        .opacity(live ? 1 - IconsCurve.easeIn(p) : 0)
    }

    /// The ring that spreads from the joint when the links meet again.
    private var clinkRing: some View {
        let p: Double = IconsCurve.seg(t - 0.09, 0, 0.45)
        let live: Bool = !broken && p > 0 && p < 1
        return Circle()
            .stroke(Palette.sky.opacity(0.7 * (1 - p)), lineWidth: 4 * CGFloat(1 - p) + 0.5)
            .frame(width: 60, height: 60)
            .scaleEffect(CGFloat(0.5 + 1.9 * IconsCurve.easeOut(p)))
            .opacity(live ? 1 : 0)
    }
}
