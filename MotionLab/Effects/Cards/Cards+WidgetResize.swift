import SwiftUI

extension Effect {
    static let cardsWidgetResize = Effect(
        id: "cards.widget-resize",
        category: .cards,
        interaction: .gesture,
        name: L("Widget Resize", "小组件缩放"),
        summary: L("Drag a weather widget's corner through small, medium and large: content reflows live and the icons around it make room.", "拖动天气小组件的角，在小、中、大三种尺寸间缩放：内容实时重排，周围的图标随之让位。"),
        prompt: L(
            "A weather widget sits top-left on a home-screen grid with a curved grab handle around its bottom-right corner. Dragging the handle resizes it freely between 142 and 300 pt on each axis, rubber-banding beyond, and everything inside is a function of the live size: as it widens, the condition block glides from bottom-left to top-right and five hourly columns rise 8 pt and fade in one after another; as it grows taller, four daily rows with temperature bars slide in as the edge passes them. App icons the widget is about to cover shrink to 70% and fade out. On release it snaps to the nearest of three sizes (142×142, 300×142, 300×300) on a bouncy spring (response 0.5 s, damping 0.72) with a rigid haptic. Tapping cycles the sizes.",
            "天气小组件位于主屏网格左上角，右下角外有一道弧形把手。拖动把手可让它在每个方向142到300 pt之间自由缩放，超出时有橡皮筋阻力，内部的一切都是实时尺寸的函数：变宽时，天气状况从左下滑到右上，五列逐小时预报依次上浮8 pt并淡入；变高时，四行带温度条的每日预报在边缘经过时逐行滑入。即将被覆盖的应用图标缩小到70%并淡出。松手后以带回弹的弹簧（响应0.5秒、阻尼0.72）吸附到三种尺寸（142×142、300×142、300×300）中最近的一种，伴随清脆触感。点击可循环切换。"
        ),
        implementation: L(
            "The widget is an Animatable view whose animatableData is its CGSize, so the snap spring re-runs the layout every frame: each element's position and opacity is computed from the width and height fractions rather than animated on its own.",
            "小组件是以 CGSize 作为 animatableData 的 Animatable 视图，吸附弹簧的每一帧都会重新计算布局：每个元素的位置与透明度都由宽、高的比例推导，而不是各自单独做动画。"
        ),
        apis: ["Animatable", "DragGesture", "rubberBand", "spring(response:dampingFraction:)", "Path.addArc"],
        tags: ["widget", "resize", "reflow", "home screen", "小组件", "缩放", "重排", "主屏幕"],
        params: [
            .slider("response", L("Snap response", "吸附响应"), 0.3...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Snap damping", "吸附阻尼"), 0.5...1.0, default: 0.72),
            .toggle("rubber", L("Rubber-band edges", "橡皮筋边缘"), default: true),
        ]
    ) { ctx in
        CardsWidgetDemo(ctx: ctx)
    }
}

private enum CardsWidgetLayout {
    static let small: CGFloat = 142
    static let large: CGFloat = 300
    static let sizes: [CGSize] = [
        CGSize(width: 142, height: 142),
        CGSize(width: 300, height: 142),
        CGSize(width: 300, height: 300),
    ]
    static let radius: CGFloat = 28
}

private struct CardsWidgetDemo: View {
    let ctx: DemoContext
    @State private var size: CGSize
    @State private var kind: Int
    @State private var dragStart: CGSize?
    /// Resets on system cancellation too, so a stolen touch still snaps the widget to a size.
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the medium widget: hourly row in, icons below still visible.
        let start = ctx.isStill ? 1 : 0
        _kind = State(initialValue: start)
        _size = State(initialValue: CardsWidgetLayout.sizes[start])
    }

    var body: some View {
        VStack(spacing: 14) {
            CardsWidgetScene(size: size, grabbed: dragStart != nil, language: ctx.language)
                .frame(width: CardsWidgetLayout.large, height: CardsWidgetLayout.large, alignment: .topLeading)
                .overlay(alignment: .topLeading) { tapArea }
                .overlay(alignment: .topLeading) { handleArea }
            DemoHint(text: L("Drag the corner handle, or tap the widget", "拖动角上的把手，或点击小组件"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { cycle() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release(predicted: nil) }
        }
    }

    private var tapArea: some View {
        Color.clear
            .frame(width: max(size.width - 24, 40), height: max(size.height - 24, 40))
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap(.soft)
                cycle()
            }
    }

    /// A 60 pt square around the bottom-right corner takes the resize drag at once.
    private var handleArea: some View {
        Color.clear
            .frame(width: 60, height: 60)
            .contentShape(Rectangle())
            .gesture(drag)
            .offset(x: size.width - 38, y: size.height - 38)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if dragStart == nil {
                    dragStart = size
                    Haptics.tap(.soft)
                }
                let start = dragStart ?? size
                size = CGSize(
                    width: resisted(start.width + value.translation.width),
                    height: resisted(start.height + value.translation.height)
                )
            }
            .onEnded { value in
                let extra = CGSize(
                    width: value.predictedEndTranslation.width - value.translation.width,
                    height: value.predictedEndTranslation.height - value.translation.height
                )
                release(predicted: extra)
            }
    }

    private func resisted(_ raw: CGFloat) -> CGFloat {
        let low = CardsWidgetLayout.small
        let high = CardsWidgetLayout.large
        guard ctx.bool("rubber") else { return raw.clamped(to: low...high) }
        if raw < low { return low + rubberBand(raw - low, limit: 40) }
        if raw > high { return high + rubberBand(raw - high, limit: 40) }
        return raw
    }

    /// Single, guarded end of a resize (lift, with the flick's extra travel, or system cancellation).
    private func release(predicted: CGSize?) {
        guard dragStart != nil else { return }
        dragStart = nil
        let aim = CGSize(
            width: size.width + (predicted?.width ?? 0) * 0.5,
            height: size.height + (predicted?.height ?? 0) * 0.5
        )
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, candidate) in CardsWidgetLayout.sizes.enumerated() {
            let distance = hypot(candidate.width - aim.width, candidate.height - aim.height)
            if distance < bestDistance {
                best = index
                bestDistance = distance
            }
        }
        if best != kind { Haptics.tap(.rigid) }
        snap(to: best)
    }

    private func cycle() {
        guard dragStart == nil else { return }
        snap(to: (kind + 1) % CardsWidgetLayout.sizes.count)
    }

    private func snap(to index: Int) {
        kind = index
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            size = CardsWidgetLayout.sizes[index]
        }
    }
}

/// Home-screen patch: icon grid, the widget and its handle. Animatable on the widget size, so the reflow
/// follows the snap spring frame by frame (bounce included).
private struct CardsWidgetScene: View, Animatable {
    var size: CGSize
    let grabbed: Bool
    let language: AppLanguage

    var animatableData: CGSize.AnimatableData {
        get { size.animatableData }
        set { size.animatableData = newValue }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            icons
            CardsWeatherWidget(size: size, language: language)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
            handle
        }
        .frame(width: CardsWidgetLayout.large, height: CardsWidgetLayout.large, alignment: .topLeading)
    }

    /// 4×4 app-icon slots (62 pt, 79.33 pt pitch); the ones the widget reaches shrink and fade.
    private var icons: some View {
        let pitch: CGFloat = (CardsWidgetLayout.large - 62) / 3
        return ForEach(0..<16, id: \.self) { slot in
            let column: CGFloat = CGFloat(slot % 4)
            let row: CGFloat = CGFloat(slot / 4)
            let centreX: CGFloat = column * pitch + 31
            let centreY: CGFloat = row * pitch + 31
            // Positive once the icon's centre is clear of the widget on either axis.
            let clearance: CGFloat = max(centreX - size.width, centreY - size.height)
            let amount: CGFloat = ((clearance + 22) / 34).clamped(to: 0...1)
            let tint: Color = Palette.spectrum[(slot * 3) % Palette.spectrum.count].opacity(0.3)
            let iconScale: CGFloat = 0.7 + 0.3 * amount
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(tint)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                }
                .frame(width: 62, height: 62)
                .scaleEffect(iconScale)
                .opacity(Double(amount))
                .offset(x: column * pitch, y: row * pitch)
        }
    }

    /// The iOS-style curved resize handle hugging the bottom-right corner.
    private var handle: some View {
        let radius = CardsWidgetLayout.radius
        let centre = CGPoint(x: size.width - radius, y: size.height - radius)
        return Path { path in
            path.addArc(center: centre, radius: radius + 7, startAngle: .degrees(14), endAngle: .degrees(76), clockwise: false)
        }
        .stroke(Color.primary.opacity(grabbed ? 0.7 : 0.4), style: StrokeStyle(lineWidth: grabbed ? 5 : 4, lineCap: .round))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: grabbed)
        .allowsHitTesting(false)
    }
}

private struct CardsWeatherWidget: View {
    let size: CGSize
    let language: AppLanguage

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: CardsWidgetLayout.radius, style: .continuous) }

    var body: some View {
        let span: CGFloat = CardsWidgetLayout.large - CardsWidgetLayout.small
        let fw = ((size.width - CardsWidgetLayout.small) / span).clamped(to: 0...1)
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0x2F7BEA), Color(hex: 0x5AB4F6)], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 190, height: 190)
                .blur(radius: 34)
                .offset(x: size.width - 120, y: -90)
            header
                .offset(x: 16, y: 14)
            condition(fw)
            hourly(fw)
                .frame(width: max(size.width - 32, 1), height: 54)
                .offset(x: 16, y: 78)
            daily
                .frame(width: max(size.width - 32, 1), alignment: .leading)
                .offset(x: 16, y: 146)
        }
        .foregroundStyle(.white)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: -2) {
            HStack(spacing: 4) {
                Text(L("Cupertino", "库比蒂诺"), language)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
            }
            Text(verbatim: "22°")
                .font(.system(size: 44, weight: .light))
        }
        .fixedSize()
    }

    /// Glides from under the temperature (small) to the top-right corner (medium / large); its leading- and
    /// trailing-aligned variants cross-fade half-way.
    private func condition(_ fw: CGFloat) -> some View {
        let x: CGFloat = 16 + (size.width - 32 - 110) * fw
        let y: CGFloat = 84 - 66 * fw
        let trailing = Double(((fw - 0.45) / 0.25).clamped(to: 0...1))
        let leading = Double((1 - fw / 0.4).clamped(to: 0...1))
        return ZStack {
            conditionBlock(alignment: .leading)
                .frame(width: 110, alignment: .leading)
                .opacity(leading)
            conditionBlock(alignment: .trailing)
                .frame(width: 110, alignment: .trailing)
                .opacity(trailing)
        }
        .offset(x: x, y: y)
    }

    private func conditionBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 16))
            Text(L("Partly Cloudy", "局部多云"), language)
                .font(.system(size: 12, weight: .semibold))
            Text(L("H:25° L:14°", "最高 25° 最低 14°"), language)
                .font(.system(size: 11.5, weight: .medium))
                .opacity(0.85)
        }
        .fixedSize()
    }

    private static let hours: [(label: LocalizedText, symbol: String, temp: String)] = [
        (L("Now", "现在"), "cloud.sun.fill", "22°"),
        (L("10", "10时"), "sun.max.fill", "23°"),
        (L("11", "11时"), "sun.max.fill", "24°"),
        (L("12", "12时"), "cloud.sun.fill", "25°"),
        (L("13", "13时"), "cloud.fill", "24°"),
    ]

    private func hourly(_ fw: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.hours.count, id: \.self) { k in
                let hour = Self.hours[k]
                // Column k starts 10 % of the widening later than the one before it.
                let reveal = ((fw - 0.3 - 0.1 * CGFloat(k)) / 0.28).clamped(to: 0...1)
                VStack(spacing: 5) {
                    Text(hour.label, language)
                        .font(.system(size: 10.5, weight: .semibold))
                        .opacity(0.85)
                    Image(systemName: hour.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 14))
                        .frame(height: 16)
                    Text(verbatim: hour.temp)
                        .font(.system(size: 13, weight: .semibold))
                }
                .fixedSize()
                .frame(maxWidth: .infinity)
                .opacity(Double(reveal))
                .offset(y: (1 - reveal) * 8)
            }
        }
    }

    private static let days: [(day: LocalizedText, symbol: String, low: Int, high: Int)] = [
        (L("Tue", "周二"), "cloud.rain.fill", 13, 21),
        (L("Wed", "周三"), "sun.max.fill", 14, 26),
        (L("Thu", "周四"), "cloud.sun.fill", 15, 24),
        (L("Fri", "周五"), "cloud.bolt.fill", 12, 20),
    ]

    private var daily: some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.days.count, id: \.self) { k in
                // Fully shown once the widget's bottom edge has passed the row; starts 24 pt earlier.
                let rowBottom: CGFloat = 150 + CGFloat(k + 1) * 36
                let reveal = ((size.height - rowBottom) / 24 + 1).clamped(to: 0...1)
                dayRow(k)
                    .frame(height: 36)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.22))
                            .frame(height: 0.6)
                    }
                    .opacity(Double(reveal))
                    .offset(y: (1 - reveal) * -10)
            }
        }
    }

    private func dayRow(_ k: Int) -> some View {
        let day = Self.days[k]
        let start = CGFloat(day.low - 10) / 18
        let end = CGFloat(day.high - 10) / 18
        return HStack(spacing: 8) {
            Text(day.day, language)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 40, alignment: .leading)
            Image(systemName: day.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 14))
                .frame(width: 24)
            Text(verbatim: "\(day.low)°")
                .font(.system(size: 13, weight: .medium))
                .opacity(0.7)
                .frame(width: 28, alignment: .trailing)
            Capsule()
                .fill(Color.black.opacity(0.16))
                .frame(height: 4)
                .overlay {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: 0x9BE7C4), Color(hex: 0xFFD45E)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(proxy.size.width * (end - start), 0))
                            .offset(x: proxy.size.width * start)
                    }
                }
            Text(verbatim: "\(day.high)°")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, alignment: .trailing)
        }
    }
}
