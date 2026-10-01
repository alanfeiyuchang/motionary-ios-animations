import SwiftUI

extension Effect {
    static let chartsRadialSchedule = Effect(
        id: "charts.radial-schedule",
        category: .charts,
        interaction: .gesture,
        name: L("24-Hour Schedule Dial", "24 小时日程表盘"),
        summary: L("Blocks of the day sweep onto a 24-hour ring, a “now” hand travels round it and each block swells as the hand passes through.", "一天的日程弧段扫上 24 小时圆环，“现在”指针绕环行进，经过的弧段随之鼓起。"),
        prompt: L(
            "A 24-hour dial, midnight at the top: an 18 pt track ring with 24 hour ticks inside it and six rounded arcs for sleep, focus, lunch, meetings, gym and reading, each in its own colour. On appear the arcs sweep in clockwise one after another, 90 ms apart, on a spring (response 0.6 s, damping 0.8). A “now” hand, a short 2 pt line with a white knob riding the ring, travels round at 1.2 hours per second. As it enters a block that arc thickens by 6 pt and brightens while the rest sit at 60% opacity, easing back over the last 24 minutes before it leaves; the centre shows the rolling time, the block's icon and name cross-fading, and its start and end time. Dragging around the ring grabs the hand and scrubs the day, with a selection tick at every block boundary. Glanceable, circular, alive.",
            "24 小时表盘，零点在正上方：18pt 宽的轨道环，内侧 24 个小时刻度，六段彩色圆头弧代表睡眠、专注、午餐、会议、健身与阅读。出现时弧段顺时针依次扫入，间隔 90ms，弹簧响应 0.6 秒、阻尼 0.8。“现在”指针是一条 2pt 短线加骑在环上的白色旋钮，以每秒 1.2 小时绕行。指针进入某段时，该弧加粗 6pt 并变亮，其余保持 60% 不透明度，离开前 24 分钟内缓缓恢复；中心显示滚动的时间、交叉淡化的图标与名称，以及起止时间。沿圆环拖动可抓住指针，每越过日程边界有一次选择触感。一眼可读。"
        ),
        implementation: L(
            "A TimelineView turns elapsed time into the hand's hour; an Animatable Canvas draws each block as a stroked arc whose end follows a sweep vector and whose thickness is a smooth function of how deep the hand is inside it, so no state is needed for the active block. A zero-distance DragGesture converts the touch angle back into an hour.",
            "TimelineView 把流逝的时间换算成指针所在的小时；Animatable Canvas 把每个日程画成描边圆弧，弧的终点跟随扫入向量，粗细是“指针进入该段有多深”的平滑函数，因此不需要为当前日程保存状态。零距离的 DragGesture 把触点角度换算回小时。"
        ),
        apis: ["TimelineView", "Canvas", "Animatable", "Path.addArc", "DragGesture", "atan2"],
        tags: ["schedule", "24 hour", "radial", "day planner", "日程", "24 小时", "环形", "时间表盘"],
        params: [
            .slider("speed", L("Hand speed", "指针速度"), 0...4, default: 1.2, decimals: 1, unit: "h/s"),
            .slider("stagger", L("Sweep stagger", "扫入错峰"), 0...0.25, default: 0.09, unit: "s"),
            .slider("thickness", L("Ring thickness", "环宽"), 10...26, default: 18, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        RadialScheduleDemo(ctx: ctx)
    }
}

private struct ScheduleBlock {
    let name: LocalizedText
    let symbol: String
    let start: Double
    /// May exceed 24 for a block that wraps past midnight.
    let end: Double
    let rgb: ChartRGB

    func contains(_ hour: Double) -> Bool {
        (hour >= start && hour < end) || (hour + 24 >= start && hour + 24 < end)
    }

    /// 0…1: how firmly the hand is inside this block (eases in and out over 0.4 h).
    func weight(_ hour: Double) -> Double {
        let h = hour >= start ? hour : hour + 24
        guard h >= start, h <= end else { return 0 }
        return min(ChartKit.smoothstep(start, start + 0.4, h), 1 - ChartKit.smoothstep(end - 0.4, end, h))
    }
}

private let scheduleBlocks: [ScheduleBlock] = [
    ScheduleBlock(name: L("Sleep", "睡眠"), symbol: "moon.fill", start: 23, end: 31, rgb: .violet),
    ScheduleBlock(name: L("Focus", "专注"), symbol: "laptopcomputer", start: 9, end: 12.5, rgb: .indigo),
    ScheduleBlock(name: L("Lunch", "午餐"), symbol: "fork.knife", start: 12.5, end: 13.5, rgb: .amber),
    ScheduleBlock(name: L("Meetings", "会议"), symbol: "person.2.fill", start: 13.5, end: 17.5, rgb: .sky),
    ScheduleBlock(name: L("Gym", "健身"), symbol: "figure.run", start: 18, end: 19.5, rgb: .coral),
    ScheduleBlock(name: L("Reading", "阅读"), symbol: "book.fill", start: 20, end: 22.5, rgb: .mint),
]

private struct RadialScheduleDemo: View {
    let ctx: DemoContext
    @State private var sweep = ChartVector(repeating: 1, count: 6)
    @State private var anchorHour: Double = 10.4
    @State private var anchorDate = Date()
    @State private var dragging = false
    @State private var grab: CGFloat = 0
    @State private var lastBlock = -2
    @State private var run: Task<Void, Never>?

    private static let dial: CGFloat = 236

    var body: some View {
        ChartStage(hint: L("Drag around the ring to move the hand", "沿圆环拖动指针"), ctx: ctx) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                let hour = hour(at: timeline.date)
                ZStack {
                    RadialSchedulePlot(sweep: sweep, hour: hour, thickness: ctx.cg("thickness"), grab: grab)
                    RadialScheduleCentre(hour: hour, language: ctx.language)
                }
                .frame(width: Self.dial, height: Self.dial)
            }
            .contentShape(Circle())
            .highPriorityGesture(dragGesture)
            .padding(14)
            .demoCard(cornerRadius: 28)
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                sweep = ChartVector(repeating: 0, count: 6)
                anchorDate = Date()
            }, then: { enter() })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 7, delay: 7, intro: false) { replay() }
    }

    private func hour(at date: Date) -> Double {
        guard !ctx.isStill, !dragging else { return anchorHour }
        let raw = anchorHour + date.timeIntervalSince(anchorDate) * ctx["speed"]
        return raw - floor(raw / 24) * 24
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in scrub(value.location) }
            .onEnded { _ in
                anchorDate = Date()
                dragging = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { grab = 0 }
            }
    }

    private func scrub(_ location: CGPoint) {
        let dx = Double(location.x - Self.dial / 2)
        let dy = Double(location.y - Self.dial / 2)
        guard dx * dx + dy * dy > 18 * 18 else { return }
        var angle = atan2(dx, -dy) / (2 * .pi)
        if angle < 0 { angle += 1 }
        let hour = angle * 24
        if !dragging {
            dragging = true
            Haptics.tap(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { grab = 1 }
        }
        let block = scheduleBlocks.firstIndex { $0.contains(hour) } ?? -1
        if block != lastBlock {
            lastBlock = block
            Haptics.selection()
        }
        anchorHour = hour
        anchorDate = Date()
    }

    private func enter() {
        run?.cancel()
        run = chartSequence(steps: 6, gap: ctx["stagger"]) { step in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { sweep[step] = 1 }
        }
    }

    private func replay() {
        run?.cancel()
        withAnimation(.easeIn(duration: 0.25)) { sweep = ChartVector(repeating: 0, count: 6) }
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            enter()
        }
    }
}

private struct RadialScheduleCentre: View {
    let hour: Double
    let language: AppLanguage

    var body: some View {
        let index = scheduleBlocks.firstIndex { $0.contains(hour) }
        let block = index.map { scheduleBlocks[$0] }
        let minutes = Int(hour * 60) % 1440
        VStack(spacing: 3) {
            ZStack {
                if let block {
                    Image(systemName: block.symbol)
                        .foregroundStyle(block.rgb.color())
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .id(block.symbol)
                } else {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundStyle(.secondary)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .frame(height: 22)
            Text(verbatim: String(format: "%02d:%02d", minutes / 60, minutes % 60))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(block?.name ?? L("Free time", "空闲"), language)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            Text(verbatim: block.map { duration($0) } ?? " ")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .contentTransition(.opacity)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: index)
        .allowsHitTesting(false)
    }

    private func duration(_ block: ScheduleBlock) -> String {
        func clock(_ hour: Double) -> String {
            let h = hour >= 24 ? hour - 24 : hour
            return String(format: "%02d:%02d", Int(h), Int((h - floor(h)) * 60 + 0.5))
        }
        return "\(clock(block.start)) – \(clock(block.end))"
    }
}

private struct RadialSchedulePlot: View, Animatable {
    var sweep: ChartVector
    let hour: Double
    let thickness: CGFloat
    var grab: CGFloat

    var animatableData: AnimatablePair<ChartVector, CGFloat> {
        get { AnimatablePair(sweep, grab) }
        set {
            sweep = newValue.first
            grab = newValue.second
        }
    }

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 16
            func angle(_ hour: Double) -> Angle { .degrees(hour / 24 * 360 - 90) }
            func point(_ hour: Double, _ r: CGFloat) -> CGPoint {
                let a = angle(hour).radians
                return CGPoint(x: centre.x + r * CGFloat(cos(a)), y: centre.y + r * CGFloat(sin(a)))
            }

            var track = Path()
            track.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
            context.stroke(track, with: .color(.primary.opacity(0.07)), lineWidth: thickness)

            // Hour ticks and the four cardinal labels, inside the ring.
            let inner = radius - thickness / 2 - 5
            for tick in 0..<24 {
                let major = tick % 6 == 0
                var mark = Path()
                mark.move(to: point(Double(tick), inner))
                mark.addLine(to: point(Double(tick), inner - (major ? 6 : 3)))
                context.stroke(mark, with: .color(.primary.opacity(major ? 0.4 : 0.16)), style: StrokeStyle(lineWidth: major ? 1.5 : 1, lineCap: .round))
                if major {
                    context.draw(
                        Text(verbatim: "\(tick)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Color.secondary),
                        at: point(Double(tick), inner - 15),
                        anchor: .center
                    )
                }
            }

            for index in scheduleBlocks.indices {
                let block = scheduleBlocks[index]
                let progress = sweep[index]
                guard progress > 0.005 else { continue }
                let weight = block.weight(hour)
                let width = max(thickness - 5, 4) + 6 * CGFloat(weight)
                // Round caps add half a line width at each end: pull the arc in so neighbours keep a hairline gap.
                let cap = Double((max(thickness - 5, 4) / 2 + 1) / radius) / (2 * Double.pi) * 24
                let from = block.start + cap
                let end = from + max(block.end - block.start - cap * 2, 0.01) * progress
                var arc = Path()
                arc.addArc(center: centre, radius: radius, startAngle: angle(from), endAngle: angle(end), clockwise: false)
                if weight > 0.01 {
                    var halo = context
                    halo.addFilter(.blur(radius: 7))
                    halo.stroke(arc, with: .color(block.rgb.color(0.5 * weight)), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
                context.stroke(arc, with: .color(block.rgb.color(0.6 + 0.4 * weight)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            // The "now" hand: hairline, hub and a knob riding the ring.
            var hand = Path()
            hand.move(to: point(hour, inner - 9))
            hand.addLine(to: point(hour, radius + thickness / 2 + 5))
            context.stroke(hand, with: .color(.primary.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            let knobCentre = point(hour, radius)
            let knobRadius = thickness / 2 + 1 + 2.5 * grab
            let knob = CGRect(x: knobCentre.x - knobRadius, y: knobCentre.y - knobRadius, width: knobRadius * 2, height: knobRadius * 2)
            var shadowed = context
            shadowed.addFilter(.shadow(color: .black.opacity(0.3), radius: 4, y: 2))
            shadowed.fill(Path(ellipseIn: knob), with: .color(.white))
            let active = scheduleBlocks.first { $0.contains(hour) }
            let dot = knob.insetBy(dx: knobRadius * 0.55, dy: knobRadius * 0.55)
            context.fill(Path(ellipseIn: dot), with: .color(active?.rgb.color() ?? Color(white: 0.6)))
        }
    }
}
