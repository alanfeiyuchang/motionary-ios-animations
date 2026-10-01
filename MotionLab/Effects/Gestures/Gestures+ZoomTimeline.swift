import SwiftUI

extension Effect {
    static let gesturesZoomTimeline = Effect(
        id: "gestures.zoom-timeline",
        category: .gestures,
        interaction: .gesture,
        name: L("Pinch Timeline", "捏合时间轴"),
        summary: L("Pinch a week timeline between days and hours: ticks subdivide and merge, labels cross-fade and events grow titles.", "捏合一周时间轴，在“天”与“小时”之间缩放：刻度细分或合并，标签交叉淡变，日程长出标题。"),
        prompt: L(
            "A 300×150 pt week timeline in a rounded card: a ruler baseline with ticks, sticky day names, two lanes of coloured events and a red \"now\" line; a pill above shows the mode and the visible span. Pinching scales time continuously from 2.4 to 64 pt per hour around the pinch point, so the moment under the fingers stays put. Tick levels (day, 6 h, 1 h, 15 min) fade in and grow as their spacing passes 6 pt and fade out as it shrinks; hour labels thin from every hour to every 3, 6 and 12 hours by cross-fading; events stretch from dots into bars whose titles fade in past 40 pt. Beyond the limits the zoom rubber-bands and springs back (response 0.6 s, damping 0.85). Double-tap jumps between days and hours on the same spring; a light haptic marks the mode change. Continuous and legible.",
            "一条300×150 pt的一周时间轴：带刻度的基线、吸附在左侧的星期名、两行彩色日程和红色“现在”线；上方胶囊显示模式与时长。捏合以捏合点为中心连续缩放，每小时2.4–64 pt，指下那一刻始终不动。各级刻度（天、6小时、1小时、15分钟）在间距超过6 pt时淡入并长高；小时标签通过交叉淡变从每小时稀疏到每3、6、12小时；日程从圆点拉成长条，宽度超过40 pt后标题淡入。超出极限带橡皮筋阻尼，再以弹簧（响应0.6秒、阻尼0.85）弹回。双击用同一弹簧在天与小时间跳转，并有轻触感。"
        ),
        implementation: L(
            "An Animatable view carries the log scale and an anchor (time, x) as animatableData, so springs interpolate the zoom around a fixed point; its Canvas derives every tick, label and event opacity from spacing in points with smoothstep. MagnifyGesture drives the log scale from value.magnification at value.startAnchor, a DragGesture pans, a double tap toggles.",
            "一个 Animatable 视图把对数缩放和锚点（时间、x）作为 animatableData，弹簧因此围绕固定点插值缩放；其中的 Canvas 用 smoothstep 根据以 pt 计的间距推导每条刻度、标签与日程的不透明度。MagnifyGesture 以 value.startAnchor 为锚、用 value.magnification 驱动对数缩放，DragGesture 负责平移，双击切换。"
        ),
        apis: ["MagnifyGesture", "Animatable", "Canvas", "SpatialTapGesture", "contentTransition(.numericText)"],
        tags: ["pinch", "zoom", "timeline", "calendar", "semantic zoom", "捏合", "缩放", "时间轴", "日历", "语义缩放"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.3...1.0, default: 0.6, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.55...1.0, default: 0.85),
            .slider("density", L("Min tick spacing", "最小刻度间距"), 4...12, default: 6, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        ZoomTimelineDemo(ctx: ctx)
    }
}

private enum TimelineMetrics {
    static let size = CGSize(width: 300, height: 150)
    static let minScale: Double = 2.4
    static let maxScale: Double = 64
    static let hoursScale: Double = 32
    static let daysScale: Double = 2.6
    static let now: Double = 58.4
    static let week: ClosedRange<Double> = 0...168
    static let baseline: CGFloat = 112
}

private struct TimelineEvent {
    let start: Double
    let end: Double
    let lane: Int
    let color: Color
    let title: LocalizedText
}

private let timelineEvents: [TimelineEvent] = [
    TimelineEvent(start: 9, end: 10, lane: 0, color: Palette.indigo, title: L("Standup", "站会")),
    TimelineEvent(start: 13, end: 15.5, lane: 1, color: Palette.pink, title: L("Roadmap", "路线图")),
    TimelineEvent(start: 34, end: 36.5, lane: 0, color: Palette.mint, title: L("Workshop", "工作坊")),
    TimelineEvent(start: 42, end: 43.5, lane: 1, color: Palette.amber, title: L("Gym", "健身")),
    TimelineEvent(start: 57, end: 57.5, lane: 0, color: Palette.indigo, title: L("Standup", "站会")),
    TimelineEvent(start: 58, end: 60, lane: 1, color: Palette.pink, title: L("Design review", "设计评审")),
    TimelineEvent(start: 60.5, end: 61.5, lane: 0, color: Palette.amber, title: L("Lunch", "午餐")),
    TimelineEvent(start: 62, end: 65, lane: 1, color: Palette.violet, title: L("Deep work", "专注时间")),
    TimelineEvent(start: 63, end: 63.75, lane: 0, color: Palette.sky, title: L("Call", "通话")),
    TimelineEvent(start: 81, end: 84, lane: 0, color: Palette.coral, title: L("Offsite", "团建")),
    TimelineEvent(start: 86, end: 88, lane: 1, color: Palette.mint, title: L("Run", "跑步")),
    TimelineEvent(start: 106, end: 107.5, lane: 0, color: Palette.green, title: L("Demo", "演示")),
    TimelineEvent(start: 111, end: 114.5, lane: 1, color: Palette.sky, title: L("Flight", "航班")),
    TimelineEvent(start: 130, end: 134, lane: 0, color: Palette.mint, title: L("Hike", "徒步")),
    TimelineEvent(start: 155, end: 157, lane: 1, color: Palette.coral, title: L("Brunch", "早午餐")),
]

private let timelineDays: [LocalizedText] = [
    L("Mon 12", "周一 12"), L("Tue 13", "周二 13"), L("Wed 14", "周三 14"), L("Thu 15", "周四 15"),
    L("Fri 16", "周五 16"), L("Sat 17", "周六 17"), L("Sun 18", "周日 18"),
]

private struct ZoomTimelineDemo: View {
    let ctx: DemoContext
    /// Natural log of points per hour.
    @State private var logScale: Double = log(TimelineMetrics.hoursScale)
    @State private var anchorTime: Double = TimelineMetrics.now
    @State private var anchorX: Double = 150
    @State private var pinchStart: Double?
    @State private var panStart: Double?
    @State private var hoursMode = true
    /// Resets on system cancellation too, so a stolen pinch never leaves the zoom past its limits.
    @GestureState private var pinching = false

    private var scale: Double { exp(logScale) }
    private var centre: Double { anchorTime - (anchorX - Double(TimelineMetrics.size.width) / 2) / scale }
    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                header
                TimelineRuler(
                    logScale: logScale,
                    anchorTime: anchorTime,
                    anchorX: anchorX,
                    density: ctx["density"],
                    language: ctx.language
                )
                .frame(width: TimelineMetrics.size.width, height: TimelineMetrics.size.height)
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.06), .init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .contentShape(Rectangle())
                .gesture(magnify)
                .simultaneousGesture(pan)
                .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { value in toggle(at: Double(value.location.x)) })
            }
            .padding(.vertical, 14)
            .frame(width: TimelineMetrics.size.width + 16)
            .demoCard(cornerRadius: 28)

            DemoHint(text: L("Pinch to zoom, drag to pan, double-tap to switch", "捏合缩放、拖动平移，双击切换"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.4, delay: 0.7) { toggle(at: nowX, haptic: false) }
        .onChange(of: pinching) { _, isPinching in
            if !isPinching { endPinch() }
        }
    }

    private var nowX: Double {
        Double(TimelineMetrics.size.width) / 2 + (TimelineMetrics.now - centre) * scale
    }

    private var header: some View {
        let visible: Double = Double(TimelineMetrics.size.width) / min(max(scale, TimelineMetrics.minScale), TimelineMetrics.maxScale)
        let span: Double = hoursMode ? visible : visible / 24
        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: hoursMode ? "clock.fill" : "calendar")
                    .contentTransition(.symbolEffect(.replace))
                Text(hoursMode ? L("Hours", "小时") : L("Days", "天"), ctx.language)
                    .contentTransition(.interpolate)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(hoursMode ? Palette.indigo : Palette.mint, in: Capsule())

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                Text(verbatim: String(format: span < 10 ? "%.1f" : "%.0f", span))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: span))
                Text(hoursMode ? L("h in view", "小时可见") : L("days in view", "天可见"), ctx.language)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
    }

    // MARK: Gestures

    private var magnify: some Gesture {
        MagnifyGesture()
            .updating($pinching) { _, state, _ in state = true }
            .onChanged { value in
                if pinchStart == nil {
                    reanchor(at: Double(value.startAnchor.x) * Double(TimelineMetrics.size.width))
                    pinchStart = logScale
                    panStart = nil
                }
                guard let start = pinchStart else { return }
                let raw: Double = start + log(max(Double(value.magnification), 0.01))
                let low: Double = log(TimelineMetrics.minScale)
                let high: Double = log(TimelineMetrics.maxScale)
                if raw > high {
                    logScale = high + Double(rubberBand(CGFloat(raw - high), limit: 0.6))
                } else if raw < low {
                    logScale = low + Double(rubberBand(CGFloat(raw - low), limit: 0.6))
                } else {
                    logScale = raw
                }
                updateMode(haptic: true)
            }
            .onEnded { _ in endPinch() }
    }

    private func endPinch() {
        guard pinchStart != nil else { return }
        pinchStart = nil
        settle()
    }

    private var pan: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard pinchStart == nil, !pinching else { return }
                if panStart == nil { panStart = anchorTime }
                guard let start = panStart else { return }
                anchorTime = start - Double(value.translation.width) / scale
            }
            .onEnded { value in
                guard let start = panStart else { return }
                panStart = nil
                guard pinchStart == nil else { return }
                // Coast along the throw, then come to rest inside the week.
                let target: Double = start - Double(value.predictedEndTranslation.width) / scale
                withAnimation(.spring(response: 0.55, dampingFraction: 1)) { anchorTime = target }
                settle()
            }
    }

    /// Re-expresses the current view around a new anchor x without moving anything.
    private func reanchor(at x: Double) {
        let time: Double = centre + (x - Double(TimelineMetrics.size.width) / 2) / scale
        anchorX = x
        anchorTime = time
    }

    /// Springs the zoom back inside its limits and the visible centre back inside the week.
    private func settle() {
        let clampedScale: Double = min(max(logScale, log(TimelineMetrics.minScale)), log(TimelineMetrics.maxScale))
        let offset: Double = (anchorX - Double(TimelineMetrics.size.width) / 2) / exp(clampedScale)
        let centreNow: Double = anchorTime - offset
        let clampedCentre: Double = min(max(centreNow, TimelineMetrics.week.lowerBound + 4), TimelineMetrics.week.upperBound - 4)
        guard clampedScale != logScale || clampedCentre != centreNow else { return }
        withAnimation(spring) {
            logScale = clampedScale
            anchorTime = clampedCentre + offset
        }
        updateMode(haptic: false)
    }

    /// Double tap, and the autoplay: jump between the days view and the hours view around `x`.
    private func toggle(at x: Double, haptic: Bool = true) {
        guard pinchStart == nil else { return }
        reanchor(at: x.clamped(to: 20...Double(TimelineMetrics.size.width) - 20))
        let target: Double = hoursMode ? TimelineMetrics.daysScale : TimelineMetrics.hoursScale
        withAnimation(spring) { logScale = log(target) }
        updateMode(haptic: haptic)
        settle()
    }

    private func updateMode(haptic: Bool) {
        let hours: Bool = scale > 8.5
        guard hours != hoursMode else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { hoursMode = hours }
        if haptic && !ctx.isPreview { Haptics.tap(.light) }
    }
}

// MARK: - Ruler

private struct TimelineRuler: View, Animatable {
    var logScale: Double
    var anchorTime: Double
    var anchorX: Double
    let density: Double
    let language: AppLanguage

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(logScale, AnimatablePair(anchorTime, anchorX)) }
        set {
            logScale = newValue.first
            anchorTime = newValue.second.first
            anchorX = newValue.second.second
        }
    }

    private var scale: Double { exp(logScale) }

    private func x(_ time: Double) -> CGFloat {
        CGFloat(anchorX + (time - anchorTime) * scale)
    }

    var body: some View {
        Canvas { context, size in
            let first: Double = anchorTime - anchorX / scale
            let last: Double = first + Double(size.width) / scale
            drawDays(&context, size: size, first: first, last: last)
            drawEvents(&context, size: size, first: first, last: last)
            drawTicks(&context, size: size, first: first, last: last)
            drawHourLabels(&context, size: size, first: first, last: last)
            drawNow(&context, size: size)
        }
    }

    private func drawDays(_ context: inout GraphicsContext, size: CGSize, first: Double, last: Double) {
        let firstDay: Int = Int((first / 24).rounded(.down))
        let lastDay: Int = Int((last / 24).rounded(.down))
        guard lastDay >= firstDay else { return }
        for day in firstDay...lastDay {
            let x0: CGFloat = x(Double(day) * 24)
            let x1: CGFloat = x(Double(day + 1) * 24)
            let inWeek: Bool = day >= 0 && day < 7
            if !inWeek || day % 2 == 1 {
                let band = CGRect(x: x0, y: 0, width: x1 - x0, height: TimelineMetrics.baseline)
                context.fill(Path(band), with: .color(.primary.opacity(inWeek ? 0.035 : 0.07)))
            }
            guard inWeek else { continue }
            // Sticky day name: pinned to the left edge until the next day pushes it out.
            let label = context.resolve(
                Text(timelineDays[day](language))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.75))
            )
            let width: CGFloat = label.measure(in: CGSize(width: 200, height: 30)).width
            let pinned: CGFloat = min(max(x0 + 7, 24), x1 - width - 7)
            context.draw(label, at: CGPoint(x: pinned, y: 14), anchor: .leading)
        }
    }

    private func drawEvents(_ context: inout GraphicsContext, size: CGSize, first: Double, last: Double) {
        for event in timelineEvents where event.end > first - 2 && event.start < last + 2 {
            let x0: CGFloat = x(event.start)
            let natural: CGFloat = x(event.end) - x0
            let width: CGFloat = max(natural - 2, 6)
            let y: CGFloat = 32 + CGFloat(event.lane) * 30
            let rect = CGRect(x: x0 + (natural - width) / 2, y: y, width: width, height: 24)
            let radius: CGFloat = min(8, width / 2)
            let pill = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
            context.fill(pill, with: .color(event.color.opacity(0.9)))
            let titleAlpha: Double = GestureMath.smoothstep(40, 62, Double(width))
            guard titleAlpha > 0.01 else { continue }
            var clipped = context
            clipped.clip(to: pill)
            clipped.opacity = titleAlpha
            let title = Text(event.title(language))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
            clipped.draw(title, at: CGPoint(x: max(rect.minX, 16) + 7, y: rect.midY), anchor: .leading)
        }
    }

    private func drawTicks(_ context: inout GraphicsContext, size: CGSize, first: Double, last: Double) {
        let base: CGFloat = TimelineMetrics.baseline
        var line = Path()
        line.move(to: CGPoint(x: 0, y: base))
        line.addLine(to: CGPoint(x: size.width, y: base))
        context.stroke(line, with: .color(.primary.opacity(0.18)), lineWidth: 1)

        // (step in hours, the coarser step whose ticks replace this one, full height)
        let levels: [(Double, Double, CGFloat)] = [(24, 0, 20), (6, 24, 13), (1, 6, 9), (0.25, 1, 5)]
        for (step, parent, height) in levels {
            let spacing: Double = step * scale
            let alpha: Double = GestureMath.smoothstep(density, density + 9, spacing)
            guard alpha > 0.01 else { continue }
            let grow: CGFloat = CGFloat(0.45 + 0.55 * GestureMath.smoothstep(density, density + 40, spacing))
            var ticks = Path()
            var index: Int = Int((first / step).rounded(.down))
            let end: Int = Int((last / step).rounded(.up))
            while index <= end {
                let time: Double = Double(index) * step
                index += 1
                if parent > 0 && abs(time.remainder(dividingBy: parent)) < 0.001 { continue }
                let px: CGFloat = x(time)
                ticks.move(to: CGPoint(x: px, y: base))
                ticks.addLine(to: CGPoint(x: px, y: base - height * grow))
            }
            let strength: Double = step >= 24 ? 0.55 : (step >= 6 ? 0.4 : 0.28)
            context.stroke(ticks, with: .color(.primary.opacity(strength * alpha)), style: StrokeStyle(lineWidth: step >= 24 ? 1.5 : 1, lineCap: .round))
        }
    }

    private func drawHourLabels(_ context: inout GraphicsContext, size: CGSize, first: Double, last: Double) {
        let steps: [Int] = [1, 3, 6, 12]
        let alphas: [Double] = steps.map { GestureMath.smoothstep(38, 56, Double($0) * scale) }
        guard let finest = zip(steps, alphas).first(where: { $0.1 > 0.01 })?.0 else { return }
        var hour: Int = Int((first / Double(finest)).rounded(.down)) * finest
        let end: Int = Int(last.rounded(.up))
        while hour <= end {
            defer { hour += finest }
            let ofDay: Int = ((hour % 24) + 24) % 24
            var alpha: Double = 0
            for (step, value) in zip(steps, alphas) where ofDay % step == 0 { alpha = max(alpha, value) }
            guard alpha > 0.01 else { continue }
            let label = Text(verbatim: String(format: "%02d:00", ofDay))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(Color.primary.opacity(0.55 * alpha))
            context.draw(label, at: CGPoint(x: x(Double(hour)), y: TimelineMetrics.baseline + 14), anchor: .center)
        }
    }

    private func drawNow(_ context: inout GraphicsContext, size: CGSize) {
        let px: CGFloat = x(TimelineMetrics.now)
        guard px > -10, px < size.width + 10 else { return }
        var line = Path()
        line.move(to: CGPoint(x: px, y: 26))
        line.addLine(to: CGPoint(x: px, y: TimelineMetrics.baseline))
        context.stroke(line, with: .color(Palette.red), lineWidth: 1.5)
        context.fill(Path(ellipseIn: CGRect(x: px - 4, y: 22, width: 8, height: 8)), with: .color(Palette.red))
    }
}
