import SwiftUI

extension Effect {
    static let iconsDoubleCheck = Effect(
        id: "icons.double-check",
        category: .icons,
        interaction: .tap,
        name: L("Message Status Ticks", "消息状态对勾"),
        summary: L("A spinning clock gives way to one drawn check, a second slides in beside it, then both wipe to blue when read.", "转动的时钟让位给一笔画出的对勾，第二个对勾滑到旁边，已读时两者一起刷成蓝色。"),
        prompt: L(
            "A chat bubble pops in and, below it, a large grey status glyph tells its story. Sending: a clock ring draws in 0.25 s and its minute hand whirls two full turns. At 0.9 s the clock shrinks to 60% and fades while a check strokes on in 0.24 s and pops on a spring (response 0.3 s, damping 0.5): sent. 0.7 s later the first check slides 15 pt left and a second one draws beside it, cutting a clean gap where the two overlap: delivered. After another 0.7 s a blue tint wipes across both checks from left to right in 0.3 s, the pair swells about 11% on a decaying wobble and a soft blue glow flares: read. The caption under the glyph rolls through the four states. A soft haptic marks each stage and a success one the last.",
            "聊天气泡弹入，下方一个放大的灰色状态图标讲述它的经历。发送中：时钟圆环用0.25秒画出，分针飞转整整两圈。0.9秒时时钟缩到60%并淡出，一个对勾用0.24秒画出，并以弹簧（响应0.3秒、阻尼0.5）弹一下：已发送。0.7秒后第一个对勾左移15 pt，第二个对勾在旁边画出，两者重叠处切出干净的缺口：已送达。再过0.7秒，蓝色从左到右用0.3秒刷过两个对勾，整体以衰减摆动放大约11%，泛起一圈柔和蓝光：已读。图标下方的文字依次滚过四种状态。每个阶段配柔和触感，最后一步配成功触感。"
        ),
        implementation: L(
            "Everything is a function of the seconds since the tap inside a TimelineView: trims for the ring and checks, analytic springs for the pops, a destinationOut stroke in a compositing group for the gap, and a masked blue copy of the checks for the read wipe.",
            "所有状态都是 TimelineView 中“点击后秒数”的函数：圆环与对勾用 trim，弹跳用解析弹簧，缺口是合成组里的 destinationOut 描边，已读的刷色是一份带遮罩的蓝色对勾。"
        ),
        apis: ["TimelineView(.animation)", "Shape.trim(from:to:)", "blendMode(.destinationOut)", "compositingGroup()", "mask"],
        tags: ["message", "status", "read receipt", "double check", "delivered", "消息", "状态", "已读", "双对勾", "送达"],
        params: [
            .slider("gap", L("Stage gap", "阶段间隔"), 0.3...1.5, default: 0.7, unit: "s"),
            .slider("draw", L("Draw time", "描绘时长"), 0.12...0.5, default: 0.24, unit: "s"),
            .slider("damping", L("Pop damping", "弹跳阻尼"), 0.3...0.9, default: 0.5),
        ]
    ) { ctx in
        IconsDoubleCheckDemo(ctx: ctx)
    }
}

private struct IconsDoubleCheckDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast

    private static let sent: Double = 0.9
    private var delivered: Double { Self.sent + ctx["gap"] }
    private var read: Double { Self.sent + 2 * ctx["gap"] }

    var body: some View {
        IconsTimeline(preview: ctx.isPreview) { date in
            let t: Double = ctx.isStill ? 100 : elapsed(at: date)
            let stage: Int = t < Self.sent ? 0 : (t < delivered ? 1 : (t < read ? 2 : 3))
            VStack(spacing: 10) {
                IconsStatusBubble(t: t, language: ctx.language)
                    .frame(width: 250, height: 62, alignment: .trailing)
                IconsStatusGlyph(t: t, sent: Self.sent, delivered: delivered, read: read, draw: ctx["draw"], damping: ctx["damping"])
                    .frame(width: 250, height: 122)
                Text(Self.caption(stage), ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(stage == 3 ? AnyShapeStyle(Palette.blue) : AnyShapeStyle(.secondary))
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.3), value: stage)
                DemoHint(text: L("Tap to send again", "点击再发一条"), ctx: ctx)
            }
            .contentShape(Rectangle())
            .onTapGesture { send() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: read + 1.5) { send() }
    }

    private static func caption(_ stage: Int) -> LocalizedText {
        switch stage {
        case 0: return L("Sending…", "发送中…")
        case 1: return L("Sent", "已发送")
        case 2: return L("Delivered", "已送达")
        default: return L("Read", "已读")
        }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private func send() {
        // One message at a time: taps are ignored until it has been read.
        guard elapsed(at: .now) > read + 0.3 else { return }
        start = .now
        Haptics.tap(.light)
        IconsHaptics.later(Self.sent, preview: ctx.isPreview) { Haptics.tap(.soft) }
        IconsHaptics.later(delivered, preview: ctx.isPreview) { Haptics.tap(.soft) }
        IconsHaptics.later(read, preview: ctx.isPreview) { Haptics.success() }
    }
}

private struct IconsStatusBubble: View {
    let t: Double
    let language: AppLanguage

    var body: some View {
        let pop: Double = IconsCurve.spring(t, response: 0.36, damping: 0.62)
        Text(L("On my way, see you at 7!", "我出发啦，七点见！"), language)
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Palette.ocean,
                in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20, style: .continuous)
            )
            .shadow(color: Palette.blue.opacity(0.3), radius: 10, y: 5)
            .scaleEffect(CGFloat(0.6 + 0.4 * pop), anchor: .bottomTrailing)
            .offset(y: CGFloat(18 * (1 - pop)))
            .opacity(IconsCurve.seg(t, 0, 0.1))
    }
}

private struct IconsStatusGlyph: View {
    let t: Double
    let sent: Double
    let delivered: Double
    let read: Double
    let draw: Double
    let damping: Double

    private static let checkSize = CGSize(width: 78, height: 60)
    private static let lineWidth: CGFloat = 12
    private static let shift: CGFloat = 15
    private static let grey = Color(hex: 0x8E8E99)

    var body: some View {
        let slide: Double = IconsCurve.spring(t - delivered, response: 0.34, damping: 0.7)
        let wipe: Double = IconsCurve.easeInOut(IconsCurve.seg(t, read, read + 0.3))
        let swell: Double = 0.2 * IconsCurve.shake(t - read - 0.12, decay: 9, frequency: 20)
        let glow: Double = IconsCurve.bump(IconsCurve.seg(t, read, read + 0.7))
        ZStack {
            clock
            checks(slide: slide)
                .foregroundStyle(Self.grey)
                .overlay {
                    checks(slide: slide)
                        .foregroundStyle(Palette.ocean)
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: 210 * CGFloat(wipe))
                        }
                }
                .frame(width: 210, height: 110)
                .shadow(color: Palette.blue.opacity(0.55 * glow), radius: 14)
                .scaleEffect(CGFloat(1 + swell))
        }
    }

    // MARK: Layers

    private var clock: some View {
        let ring: Double = IconsCurve.easeOut(IconsCurve.seg(t, 0, 0.25))
        let leaving: Double = IconsCurve.easeIn(IconsCurve.seg(t, sent - 0.04, sent + 0.14))
        let turns: Double = 720 * IconsCurve.easeInOut(IconsCurve.seg(t, 0.08, sent))
        let style = StrokeStyle(lineWidth: 10, lineCap: .round)
        return ZStack {
            Circle()
                .trim(from: 0, to: CGFloat(ring))
                .stroke(style: style)
                .rotationEffect(.degrees(-90))
            IconsLine(from: UnitPoint(x: 0.5, y: 0.5), to: UnitPoint(x: 0.5, y: 0.2))
                .stroke(style: style)
                .rotationEffect(.degrees(turns))
                .opacity(ring)
            IconsLine(from: UnitPoint(x: 0.5, y: 0.5), to: UnitPoint(x: 0.72, y: 0.5))
                .stroke(style: style)
                .rotationEffect(.degrees(turns / 12))
                .opacity(ring)
        }
        .frame(width: 76, height: 76)
        .foregroundStyle(Self.grey)
        .scaleEffect(CGFloat(1 - 0.4 * leaving))
        .opacity(1 - leaving)
    }

    private func checks(slide: Double) -> some View {
        let first: Double = IconsCurve.easeOut(IconsCurve.seg(t, sent, sent + draw))
        let second: Double = IconsCurve.easeOut(IconsCurve.seg(t, delivered, delivered + draw))
        let firstPop: Double = 0.7 + 0.3 * IconsCurve.spring(t - sent, response: 0.3, damping: damping)
        let secondPop: Double = 0.7 + 0.3 * IconsCurve.spring(t - delivered, response: 0.3, damping: damping)
        let style = StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round)
        let size: CGSize = Self.checkSize
        return ZStack {
            ZStack {
                IconsCheck()
                    .trim(from: 0, to: CGFloat(first))
                    .stroke(style: style)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(CGFloat(firstPop))
                    .offset(x: -Self.shift * CGFloat(slide))
                // The second check cuts a gap out of the first where they cross.
                IconsCheck()
                    .trim(from: 0, to: CGFloat(second))
                    .stroke(.black, style: StrokeStyle(lineWidth: Self.lineWidth * 2.1, lineCap: .round, lineJoin: .round))
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(CGFloat(secondPop))
                    .offset(x: Self.shift * 1.2)
                    .blendMode(.destinationOut)
                    .opacity(second > 0 ? 1 : 0)
            }
            .compositingGroup()
            IconsCheck()
                .trim(from: 0, to: CGFloat(second))
                .stroke(style: style)
                .frame(width: size.width, height: size.height)
                .scaleEffect(CGFloat(secondPop))
                .offset(x: Self.shift * 1.2)
                .opacity(second > 0 ? 1 : 0)
        }
        .frame(width: 210, height: 110)
    }
}
