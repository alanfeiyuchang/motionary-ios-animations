import SwiftUI

extension Effect {
    static let iconsNfcTap = Effect(
        id: "icons.nfc-tap",
        category: .icons,
        interaction: .tap,
        name: L("Contactless Tap", "感应轻触"),
        summary: L("Contactless waves pulse on a reader; a card swings up to it, the reader bumps, and the waves fold into a drawn ring and tick.", "读卡器上的感应波纹持续脉动；卡片靠上来，读卡器轻轻一震，波纹收拢成一笔画出的圆环与对勾。"),
        prompt: L(
            "A rounded reader tile shows four blue contactless arcs; a brightness pulse keeps travelling outward through them at 1.4× speed. A payment card waits below, tilted 8°. On tap the card swings up 38 pt over the tile's lower edge on a spring (response 0.3 s, damping 0.6), levelling to 3°. At contact (0.26 s) the tile bumps: it jumps 5 pt and swells 5% on a decaying ring (decay 9, about 4 Hz), every arc flashes to full brightness, then the arcs fold toward their middles from the outermost in, 30 ms apart. A green ring strokes around the centre in 0.28 s, a tick draws in 0.2 s, and the pair pops about 12% while a green outline expands from the tile and fades. After a 1.2 s hold the card drops back and the arcs spring out again. Rigid haptic at contact, success at the tick.",
            "读卡器方块上四道蓝色感应弧线，亮度脉冲以1.4倍速向外传递。下方是一张倾斜8°的卡片。点击后卡片以弹簧（响应0.3秒、阻尼0.6）上摆38 pt盖住方块下缘，摆平到3°。接触瞬间（0.26秒）方块一震：上跳5 pt、放大5%，以衰减振荡回落（衰减9、约4 Hz）；弧线全部闪亮，随后从最外一道起相隔30毫秒向中点收拢。绿色圆环用0.28秒绕中心画出，对勾用0.2秒画成，两者弹大约12%，一圈绿色描边向外扩散淡出。停留1.2秒后卡片落回，弧线重新弹出。接触配清脆触感，对勾配成功触感。"
        ),
        implementation: L(
            "A TimelineView turns the seconds since the tap into the card's swing (analytic spring out, eased return), the tile's bump (a decaying cosine), each arc's symmetric trim and the ring and tick trims; the idle pulse is a sine of a rate-continuous phase clock offset per arc.",
            "TimelineView 把点击后的秒数换算成卡片的摆动（解析弹簧上摆、缓动落回）、方块的震动（衰减余弦）、每道弧线的对称 trim，以及圆环与对勾的 trim；待机脉冲是速率连续的相位时钟的正弦，并按弧线错开相位。"
        ),
        apis: ["TimelineView(.animation)", "Shape.trim(from:to:)", "Path.addArc", "scaleEffect", "rotationEffect"],
        tags: ["contactless", "tap to pay", "reader", "card", "payment", "感应", "轻触支付", "读卡器", "卡片", "支付"],
        params: [
            .slider("pulse", L("Pulse speed", "脉冲速度"), 0.5...3.0, default: 1.4, unit: "×"),
            .slider("bump", L("Bump strength", "震动强度"), 0...1.5, default: 1.0),
            .slider("hold", L("Hold time", "停留时间"), 0.6...2.5, default: 1.2, unit: "s"),
        ]
    ) { ctx in
        IconsNfcTapDemo(ctx: ctx)
    }
}

private struct IconsNfcTapDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast
    @State private var pulse = IconsPhaseClock()

    private var total: Double { IconsNfcScene.contact + 0.6 + ctx["hold"] + 0.7 }

    var body: some View {
        IconsTimeline(preview: ctx.isPreview) { date in
            let t: Double = ctx.isStill ? IconsNfcScene.contact + 0.9 : elapsed(at: date)
            let done: Bool = t > IconsNfcScene.contact + 0.3 && t < IconsNfcScene.contact + 0.6 + ctx["hold"]
            VStack(spacing: 10) {
                IconsNfcScene(
                    t: t,
                    phase: ctx.isStill ? 0 : pulse.phase(at: date, rate: ctx["pulse"] * 3.2),
                    bump: ctx["bump"],
                    hold: ctx["hold"]
                )
                .frame(width: 250, height: 226)
                .contentShape(Rectangle())
                .onTapGesture { tap() }
                Text(done ? L("Done", "完成") : L("Hold near the reader", "请靠近读卡器"), ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(done ? AnyShapeStyle(Palette.green) : AnyShapeStyle(.secondary))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.22), value: done)
                DemoHint(text: L("Tap to present the card", "点击出示卡片"), ctx: ctx)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: total + 0.5) { tap() }
        .onChange(of: ctx["pulse"]) { old, _ in pulse.rebase(oldRate: old * 3.2) }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private func tap() {
        // One tap at a time: ignored until the card is back down.
        guard elapsed(at: .now) > total else { return }
        start = .now
        Haptics.tap(.light)
        IconsHaptics.later(IconsNfcScene.contact, preview: ctx.isPreview) { Haptics.tap(.rigid) }
        IconsHaptics.later(IconsNfcScene.contact + 0.5, preview: ctx.isPreview) { Haptics.success() }
    }
}

/// One contactless arc: ±`half` degrees around the +x axis, centred on the rect's leading edge.
private struct IconsContactlessArc: Shape {
    let radius: CGFloat
    let half: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.minX, y: rect.midY), radius: radius, startAngle: .degrees(-half), endAngle: .degrees(half), clockwise: false)
        return path
    }
}

private struct IconsNfcScene: View {
    let t: Double
    let phase: Double
    let bump: Double
    let hold: Double

    static let contact: Double = 0.26
    private static let tile: CGFloat = 128
    private static let tileY: CGFloat = -46
    private static let card = CGSize(width: 118, height: 74)
    private static let green = Color(hex: 0x2CC873)

    /// When the confirmation is cleared and the card leaves.
    private var release: Double { Self.contact + 0.6 + hold }

    /// 0 = waiting below, 1 = held against the reader.
    private var presented: Double {
        IconsCurve.spring(t, response: 0.3, damping: 0.6) * (1 - IconsCurve.easeInOut(IconsCurve.seg(t, release, release + 0.4)))
    }

    /// 0 = waves, 1 = ring and tick.
    private var confirmed: Double {
        IconsCurve.seg(t, Self.contact + 0.06, Self.contact + 0.3) * (1 - IconsCurve.seg(t, release, release + 0.2))
    }

    var body: some View {
        let since: Double = t - Self.contact
        let thump: Double = bump * IconsCurve.ring(since, decay: 9, frequency: 24) * IconsCurve.seg(since, 0, 0.03)
        ZStack {
            outline(since: since)
            reader
                .scaleEffect(CGFloat(1 + 0.05 * thump))
                .offset(y: Self.tileY - CGFloat(5 * thump))
            cardView
        }
        .frame(width: 250, height: 226)
    }

    // MARK: Reader

    private var reader: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        let ok: Double = confirmed
        return ZStack {
            shape
                .fill(Palette.elevated)
                .overlay(shape.fill(Self.green.opacity(0.12 * ok)))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .overlay(shape.strokeBorder(Self.green.opacity(0.7 * ok), lineWidth: 2))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 9)
            waves
            confirmation
        }
        .frame(width: Self.tile, height: Self.tile)
    }

    private var waves: some View {
        let since: Double = t - Self.contact
        return ZStack(alignment: .leading) {
            ForEach(0..<4, id: \.self) { index in
                let order: Double = Double(3 - index)
                let fold: Double = IconsCurve.easeIn(IconsCurve.seg(since, 0.06 + 0.03 * order, 0.22 + 0.03 * order))
                let back: Double = IconsCurve.spring(t - release - 0.12 - 0.06 * Double(index), response: 0.34, damping: 0.5)
                let amount: Double = t < release ? 1 - fold : back
                let shown: Double = IconsCurve.unit(amount)
                let idle: Double = 0.4 + 0.6 * max(0, sin(phase - Double(index) * 0.9))
                // Every arc lights up at the moment of contact.
                let flash: Double = IconsCurve.bump(IconsCurve.seg(since, 0, 0.2))
                IconsContactlessArc(radius: CGFloat(14 + 15 * index), half: 40)
                    .trim(from: CGFloat(0.5 - 0.5 * shown), to: CGFloat(0.5 + 0.5 * shown))
                    .stroke(Palette.ocean, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .scaleEffect(CGFloat(0.84 + 0.16 * amount), anchor: .leading)
                    .opacity(IconsCurve.unit(shown * 2) * max(idle, flash))
            }
        }
        .frame(width: 64, height: 90, alignment: .leading)
        .offset(x: 2)
    }

    private var confirmation: some View {
        let since: Double = t - Self.contact
        let ring: Double = IconsCurve.easeOut(IconsCurve.seg(since, 0.2, 0.48))
        let tick: Double = IconsCurve.easeOut(IconsCurve.seg(since, 0.4, 0.6))
        let pop: Double = 0.26 * IconsCurve.shake(since - 0.5, decay: 9, frequency: 20)
        let leaving: Double = IconsCurve.seg(t, release, release + 0.2)
        return ZStack {
            Circle()
                .trim(from: 0, to: CGFloat(ring))
                .stroke(Self.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 70, height: 70)
            IconsCheck()
                .trim(from: 0, to: CGFloat(tick))
                .stroke(Self.green, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .frame(width: 32, height: 26)
                .opacity(tick > 0 ? 1 : 0)
        }
        .shadow(color: Self.green.opacity(0.4), radius: 8, y: 3)
        .scaleEffect(CGFloat(1 + pop) * CGFloat(1 - 0.3 * leaving))
        .opacity(ring > 0 ? 1 - leaving : 0)
    }

    /// A rounded outline that spreads from the tile as the tick lands.
    private func outline(since: Double) -> some View {
        let p: Double = IconsCurve.seg(since - 0.46, 0, 0.55)
        let live: Bool = p > 0 && p < 1
        return RoundedRectangle(cornerRadius: 34, style: .continuous)
            .stroke(Self.green.opacity(0.6 * (1 - p)), lineWidth: 4 * CGFloat(1 - p) + 0.5)
            .frame(width: Self.tile, height: Self.tile)
            .scaleEffect(CGFloat(1 + 0.32 * IconsCurve.easeOut(p)))
            .offset(y: Self.tileY)
            .opacity(live ? 1 : 0)
    }

    // MARK: Card

    private var cardView: some View {
        let near: Double = presented
        let size: CGSize = Self.card
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [Color(hex: 0x7C83FF), Color(hex: 0xA352F0)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFE08A), Color(hex: 0xF5A623)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 17)
                    .padding(.top, 14)
                    .padding(.leading, 14)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule().fill(.white.opacity(0.75)).frame(width: 17, height: 5)
                    }
                }
                .padding(.bottom, 13)
                .padding(.leading, 14)
            }
            .overlay {
                shape.fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0)], startPoint: .topLeading, endPoint: .center))
            }
            .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .frame(width: size.width, height: size.height)
            .shadow(color: Color(hex: 0x5A3FD0).opacity(0.3 + 0.15 * IconsCurve.unit(near)), radius: 10 + CGFloat(6 * IconsCurve.unit(near)), y: 6 + CGFloat(6 * IconsCurve.unit(near)))
            .rotationEffect(.degrees(IconsCurve.mix(-8, -3, near)))
            .offset(x: CGFloat(IconsCurve.mix(10, 4, near)), y: CGFloat(IconsCurve.mix(62, 24, near)))
    }
}
