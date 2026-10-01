import SwiftUI

extension Effect {
    static let iconsSignalBars = Effect(
        id: "icons.signal-bars",
        category: .icons,
        interaction: .tap,
        name: L("Signal Bars", "信号格"),
        summary: L("Bars stand up, a searching glint sweeps across them, then they fill green one by one; losing signal collapses them under a red slash.", "信号格立起，一道搜索光扫过，随后逐格涨满绿色；信号丢失时逐格塌下，被一道红色斜杠划过。"),
        prompt: L(
            "Four rounded signal bars of rising height. With no service they are short grey stubs crossed by a red slash. On tap the slash retracts in 0.16 s and the stubs grow into full-height empty tracks, 40 ms apart. Then the search: for 1.2 s a glint sweeps left to right every 0.6 s, tinting each track blue and lifting it 4 pt as it passes. When the network answers, each bar fills green from the bottom, 90 ms apart, on a spring (response 0.36 s, damping 0.5) that stretches it about 15% taller before settling, and a network chip pops in. Tapping again drains it: the bars collapse to stubs from the tallest down, the green fades, and the slash strikes across in 0.26 s, cutting a gap through the bars as the glyph rocks 4°. Success haptic on connect, a rigid tick on the slash.",
            "四根递增的圆角信号格。无服务时是灰色短桩，划着一道红色斜杠。点击后斜杠用0.16秒收回，短桩依次长成全高的空槽，间隔40毫秒。接着搜索：1.2秒内一道光每0.6秒从左到右扫过，经过时把空槽染蓝并托起4 pt。网络应答后，每格从底部涨满绿色，间隔90毫秒，由弹簧（响应0.36秒、阻尼0.5）驱动，先拉高约15%再落定，网络标识随之弹出。再次点击信号流失：信号格从最高的开始依次塌成短桩，绿色褪去，斜杠在0.26秒内划过，切出缺口，图标晃动4°。连接配成功触感，斜杠配清脆触感。"
        ),
        implementation: L(
            "A two-state play head with a TimelineView: per bar, a growth value sets the track height and a spring sets the fill, both delayed by the stagger; the sweep is a moving triangle window over the bar index. The slash gap is a wider destinationOut stroke inside a compositing group.",
            "双状态播放头配合 TimelineView：每格由生长值决定空槽高度、由弹簧决定填充量，并按间隔错开；搜索光是在格序号上移动的三角窗口。斜杠缺口是合成组里一条更粗的 destinationOut 描边。"
        ),
        apis: ["TimelineView(.animation)", "scaleEffect(x:y:anchor:)", "blendMode(.destinationOut)", "compositingGroup()", "Shape.trim(from:to:)"],
        tags: ["signal", "cellular", "bars", "no service", "network", "信号", "蜂窝", "信号格", "无服务", "网络"],
        params: [
            .slider("bars", L("Bars", "格数"), 3...5, default: 4, step: 1, decimals: 0),
            .slider("stagger", L("Stagger", "错开间隔"), 0.03...0.2, default: 0.09, unit: "s"),
            .slider("search", L("Search time", "搜索时长"), 0.4...2.5, default: 1.2, unit: "s"),
            .slider("damping", L("Fill damping", "填充阻尼"), 0.3...0.9, default: 0.5),
        ]
    ) { ctx in
        IconsSignalBarsDemo(ctx: ctx)
    }
}

private struct IconsSignalBarsDemo: View {
    let ctx: DemoContext
    /// On = connected.
    @State private var play = IconsPlayhead(isOn: false)

    private var count: Int { max(ctx.int("bars"), 1) }
    /// When the bars start to fill, measured from the tap that connects.
    private var fillStart: Double { IconsSignalScene.searchStart + ctx["search"] }
    private var connectDuration: Double { fillStart + Double(count) * ctx["stagger"] + 0.5 }
    private var dropDuration: Double { Double(count) * ctx["stagger"] + 0.5 }

    var body: some View {
        let on: Bool = ctx.isStill ? true : play.isOn
        IconsTimeline(preview: ctx.isPreview) { date in
            let t: Double = ctx.isStill ? 100 : play.elapsed(at: date)
            let stage: Int = on ? (t < fillStart ? 1 : 2) : 0
            VStack(spacing: 10) {
                IconsSignalScene(
                    on: on,
                    t: t,
                    count: count,
                    stagger: ctx["stagger"],
                    search: ctx["search"],
                    damping: ctx["damping"]
                )
                .frame(width: 250, height: 196)
                .contentShape(Rectangle())
                .onTapGesture { toggle() }
                Text(Self.caption(stage), ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.3), value: stage)
                DemoHint(text: L("Tap to connect or drop the signal", "点击连接或断开信号"), ctx: ctx)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: max(connectDuration, dropDuration) + 0.9) { toggle() }
    }

    private static func caption(_ stage: Int) -> LocalizedText {
        switch stage {
        case 0: return L("No service", "无服务")
        case 1: return L("Searching…", "搜索中…")
        default: return L("Connected · full signal", "已连接 · 信号满格")
        }
    }

    private func toggle() {
        play.toggle(onDuration: connectDuration, offDuration: dropDuration)
        Haptics.tap(.light)
        if play.isOn {
            IconsHaptics.later(fillStart + Double(count - 1) * ctx["stagger"] + 0.1, preview: ctx.isPreview) {
                guard play.isOn else { return }
                Haptics.success()
            }
        } else {
            IconsHaptics.later(Double(count) * ctx["stagger"] + 0.3, preview: ctx.isPreview) {
                guard !play.isOn else { return }
                Haptics.tap(.rigid)
            }
        }
    }
}

private struct IconsSignalScene: View {
    let on: Bool
    let t: Double
    let count: Int
    let stagger: Double
    let search: Double
    let damping: Double

    static let searchStart: Double = 0.42
    private static let barWidth: CGFloat = 28
    private static let spacing: CGFloat = 13
    private static let tallest: CGFloat = 124
    private static let shortest: CGFloat = 34
    private static let stub: CGFloat = 16
    private static let baseline: CGFloat = 66
    private static let grey = Color(hex: 0x8E8E99)

    private var fillStart: Double { Self.searchStart + search }
    private var slashStart: Double { Double(count - 1) * stagger + 0.14 }

    // MARK: Motion

    /// 0 = stub, 1 = full-height track.
    private func growth(_ index: Int) -> Double {
        if on { return IconsCurve.easeOut(IconsCurve.seg(t, 0.1 + 0.04 * Double(index), 0.32 + 0.04 * Double(index))) }
        let order: Double = Double(count - 1 - index)
        return 1 - IconsCurve.easeIn(IconsCurve.seg(t, order * stagger, order * stagger + 0.2))
    }

    /// 0 = empty, 1 = full; springs past 1 while filling.
    private func fill(_ index: Int) -> Double {
        if on { return IconsCurve.spring(t - fillStart - Double(index) * stagger, response: 0.36, damping: damping) }
        return growth(index)
    }

    /// 0…1: how strongly the searching glint lights bar `index`.
    private func glint(_ index: Int) -> Double {
        guard on, t > Self.searchStart, t < fillStart else { return 0 }
        let cycle: Double = ((t - Self.searchStart) / 0.6).truncatingRemainder(dividingBy: 1)
        let head: Double = -1 + cycle * Double(count + 1)
        return max(0, 1 - abs(head - Double(index)))
    }

    private var slash: Double {
        if on { return 1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.16)) }
        return IconsCurve.easeOut(IconsCurve.seg(t, slashStart, slashStart + 0.26))
    }

    var body: some View {
        let cut: Double = slash
        let rock: Double = on ? 0 : -4 * IconsCurve.shake(t - slashStart - 0.2, decay: 9, frequency: 24)
        ZStack {
            ZStack {
                bars
                slashLine
                    .trim(from: 0, to: CGFloat(cut))
                    .stroke(.black, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            slashLine
                .trim(from: 0, to: CGFloat(cut))
                .stroke(Palette.red, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .shadow(color: Palette.red.opacity(0.4), radius: 6, y: 3)
            chip
        }
        .frame(width: 250, height: 196)
        .rotationEffect(.degrees(rock))
    }

    private var slashLine: some Shape {
        IconsLine(from: UnitPoint(x: 0.34, y: 0.5), to: UnitPoint(x: 0.66, y: 0.908))
    }

    // MARK: Layers

    private var bars: some View {
        HStack(alignment: .bottom, spacing: Self.spacing) {
            ForEach(0..<count, id: \.self) { index in
                bar(index)
            }
        }
        .frame(height: Self.tallest * 1.2, alignment: .bottom)
        .offset(y: Self.baseline - Self.tallest * 0.6)
    }

    private func bar(_ index: Int) -> some View {
        let step: CGFloat = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 1
        let full: CGFloat = Self.shortest + (Self.tallest - Self.shortest) * step
        let grown: Double = growth(index)
        let stub: CGFloat = max(Self.stub, full * 0.42)
        let height: CGFloat = stub + (full - stub) * CGFloat(grown)
        let level: Double = fill(index)
        let lit: Double = glint(index)
        let stretch: CGFloat = CGFloat(1 + 0.9 * max(level - 1, 0))
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return shape
            .fill(Self.grey.opacity(0.32))
            .overlay { shape.fill(Palette.sky.opacity(0.75 * lit)) }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: 0x5BE89A), Color(hex: 0x1FB86A)], startPoint: .top, endPoint: .bottom))
                    .frame(height: height * CGFloat(IconsCurve.unit(level)))
            }
            .clipShape(shape)
            .frame(width: Self.barWidth, height: height)
            .shadow(color: Color(hex: 0x1FB86A).opacity(0.35 * IconsCurve.unit(level)), radius: 8, y: 4)
            .scaleEffect(x: 1, y: on ? stretch : 1, anchor: .bottom)
            .offset(y: CGFloat(-4 * lit))
    }

    /// The network chip that pops in once every bar is full.
    private var chip: some View {
        let arrive: Double = on
            ? IconsCurve.spring(t - fillStart - Double(count) * stagger - 0.04, response: 0.32, damping: 0.5)
            : 1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.14))
        return Text(verbatim: "5G")
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(LinearGradient(colors: [Color(hex: 0x5BE89A), Color(hex: 0x1FB86A)], startPoint: .top, endPoint: .bottom), in: Capsule())
            .shadow(color: Color(hex: 0x1FB86A).opacity(0.4), radius: 6, y: 3)
            .scaleEffect(CGFloat(max(arrive, 0)))
            .offset(x: -74, y: -62)
    }
}
