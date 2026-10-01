import SwiftUI

extension Effect {
    static let loadingMilestones = Effect(
        id: "loading.milestones",
        category: .loading,
        interaction: .gesture,
        name: L("Milestone Progress", "里程碑进度条"),
        summary: L("Markers along a progress line pop, light up and label themselves the moment the fill reaches them.", "进度线上的标记在填充到达的一刻弹起、点亮，并自己亮出标签。"),
        prompt: L(
            "A 260 pt progress line, 6 pt thick, carries four evenly spaced 28 pt milestone markers, the last one flush with its end. Unreached markers are hollow discs with a grey icon. A mint → sky fill with a glowing white head advances one marker every 0.9 s, easing slightly into and out of each marker without ever stopping. The instant the head arrives, the marker floods with the gradient, its icon turns white and it pops on a spring (response 0.38 s, damping 0.5) while a ring expands to 2.1× and fades in 0.55 s; its label rises 8 pt into place below and a small timestamp drops in above 80 ms later. The percentage in the header counts continuously. At 100% the line and markers turn green. Drag along the line to scrub: markers un-pop behind the finger with selection ticks. Clear, rewarding, informative.",
            "一条 260 pt 长、6 pt 粗的进度线上等距排列四个 28 pt 的里程碑标记，最后一个与线尾齐平。薄荷绿 → 天蓝的填充带着发光的白色端点，每 0.9 秒推进一个标记，经过标记时略缓但不停。端点到达的一瞬间，标记灌满渐变色、图标变白，并以弹簧（响应 0.38 秒、阻尼 0.5）弹起，一圈圆环放大到 2.1 倍并在 0.55 秒内淡出；标签从下方上浮 8 pt 就位，80 毫秒后上方落下时间戳。标题里的百分比持续计数，到 100% 时整条线变绿。沿线拖动可来回拖拽：手指退回时标记逐个熄灭，伴随选择触感。清晰、有成就感。"
        ),
        implementation: L(
            "A TimelineView computes progress from elapsed time (or takes it from the drag), and each marker compares it with its own position; that Bool drives implicit springs, and an onChange on it triggers the ring's keyframe animation.",
            "TimelineView 按已过时间算出进度（拖动时则直接取手指位置），每个标记把它和自己的位置比较；得到的布尔值驱动隐式弹簧动画，对它的 onChange 再触发圆环的关键帧动画。"
        ),
        apis: ["TimelineView", "animation(_:value:)", "keyframeAnimator", "DragGesture", "onChange(of:)"],
        tags: ["milestone", "steps", "tracker", "progress", "里程碑", "节点", "物流", "进度"],
        params: [
            .slider("segment", L("Segment time", "每段时长"), 0.4...2.5, default: 0.9, decimals: 1, unit: "s"),
            .slider("count", L("Milestones", "里程碑数量"), 3...5, default: 4, step: 1, decimals: 0),
            .slider("damping", L("Pop damping", "弹起阻尼"), 0.3...1, default: 0.5),
        ]
    ) { ctx in
        MilestonesDemo(ctx: ctx)
    }
}

private struct MilestoneInfo {
    let name: LocalizedText
    let symbol: String
    let time: String

    static let all: [MilestoneInfo] = [
        MilestoneInfo(name: L("Ordered", "已下单"), symbol: "cart.fill", time: "09:12"),
        MilestoneInfo(name: L("Packed", "已打包"), symbol: "shippingbox.fill", time: "11:40"),
        MilestoneInfo(name: L("Shipped", "运输中"), symbol: "airplane", time: "14:05"),
        MilestoneInfo(name: L("Nearby", "派送中"), symbol: "bicycle", time: "17:30"),
        MilestoneInfo(name: L("Delivered", "已送达"), symbol: "house.fill", time: "18:02"),
    ]

    /// Which of the five stages a row of `count` markers shows.
    static func slots(_ count: Int) -> [Int] {
        switch count {
        case ...3: return [0, 2, 4]
        case 4: return [0, 1, 2, 4]
        default: return [0, 1, 2, 3, 4]
        }
    }
}

private struct MilestonesDemo: View {
    let ctx: DemoContext
    @State private var started = Date()
    /// Set while (and after) the finger scrubs; `nil` means the timed run is in charge.
    @State private var manual: Double?
    @State private var dragging = false

    private let width: CGFloat = 260

    private static let hold: Double = 1.7

    /// Where marker `index` sits on the line, as a fraction of its width. Markers are evenly spaced and the
    /// last one ends flush with the line.
    private func position(_ index: Int, of count: Int) -> Double {
        Double(14 + (width - 28) * CGFloat(index + 1) / CGFloat(count)) / Double(width)
    }

    /// Progress of the timed run: one marker per `segment` seconds, eased a little at each one.
    private func timed(_ elapsed: Double, segment: Double, count: Int) -> Double {
        let run: Double = min(max(elapsed / segment, 0), Double(count))
        let whole: Int = min(Int(run), count - 1)
        let u: Double = run - Double(whole)
        let eased: Double = 0.55 * u + 0.45 * LoadingCurve.smoothstep(u)
        let from: Double = whole == 0 ? 0 : position(whole - 1, of: count)
        let to: Double = whole == count - 1 ? 1 : position(whole, of: count)
        return min(from + (to - from) * eased, 1)
    }

    var body: some View {
        let slots: [Int] = MilestoneInfo.slots(ctx.int("count"))
        let count: Int = slots.count
        let segment: Double = max(ctx["segment"], 0.1)
        let run: Double = segment * Double(count) + MilestonesDemo.hold
        VStack(spacing: 16) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let since: Double = max(timeline.date.timeIntervalSince(started) - 0.5, 0)
                // Previews loop; the detail page plays once and then waits for the finger.
                let elapsed: Double = ctx.isPreview ? since.truncatingRemainder(dividingBy: run + 0.5) : since
                let progress: Double = ctx.isStill ? 0.6 : (manual ?? timed(elapsed, segment: segment, count: count))
                content(progress: progress, slots: slots)
            }
            DemoHint(text: L("Drag along the line · tap to replay", "沿线拖动 · 点击重播"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(progress: Double, slots: [Int]) -> some View {
        let zh = ctx.language == .zh
        let count: Int = slots.count
        let done: Bool = progress >= 0.999
        let percent: Int = Int((progress * 100).rounded())
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(zh ? "订单 #2048" : "Order #2048")
                        .font(.headline)
                    Text(done ? (zh ? "包裹已送达" : "Your parcel has arrived") : (zh ? "正在路上" : "On its way"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                        .animation(.smooth(duration: 0.3), value: done)
                }
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(done ? Palette.green : Color.primary)
                    .animation(.smooth(duration: 0.4), value: done)
            }
            .frame(width: width)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: width, height: 6)
                Capsule()
                    .fill(done
                          ? LinearGradient(colors: [Palette.green, Palette.mint], startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Palette.mint, Palette.sky], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(width * CGFloat(progress), 6), height: 6)
                    .animation(.smooth(duration: 0.4), value: done)
                // The glowing head.
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: Palette.sky.opacity(0.9), radius: 6)
                    .scaleEffect(dragging ? 1.6 : 1)
                    .opacity(done ? 0 : 1)
                    .offset(x: width * CGFloat(progress) - 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragging)
                ForEach(0..<count, id: \.self) { index in
                    let at: Double = position(index, of: count)
                    MilestoneMarker(
                        info: MilestoneInfo.all[slots[index]],
                        reached: progress >= at - 0.0005,
                        done: done,
                        damping: ctx["damping"],
                        language: ctx.language,
                        buzz: dragging && !ctx.isPreview
                    )
                    .offset(x: width * CGFloat(at) - 14)
                }
            }
            .frame(width: width, height: 112, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(scrub)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .demoCard(cornerRadius: 24)
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard abs(value.translation.width) > 4 || dragging else { return }
                dragging = true
                manual = Double((value.location.x / width).clamped(to: 0...1))
            }
            .onEnded { _ in
                if dragging {
                    dragging = false
                } else {
                    replay()
                }
            }
    }

    private func replay() {
        Haptics.tap()
        manual = nil
        started = .now
    }
}

private struct MilestoneMarker: View {
    let info: MilestoneInfo
    let reached: Bool
    let done: Bool
    let damping: Double
    let language: AppLanguage
    let buzz: Bool
    @State private var bursts = 0

    var body: some View {
        let spring: Animation = .spring(response: 0.38, dampingFraction: damping)
        let tint: LinearGradient = done
            ? LinearGradient(colors: [Palette.green, Palette.mint], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Palette.mint, Palette.sky], startPoint: .topLeading, endPoint: .bottomTrailing)
        ZStack {
            Circle()
                .stroke(done ? Palette.green : Palette.sky, lineWidth: 2)
                .frame(width: 28, height: 28)
                .keyframeAnimator(initialValue: MilestoneRing(), trigger: bursts) { content, ring in
                    content
                        .scaleEffect(ring.scale)
                        .opacity(ring.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1, duration: 0.01)
                        CubicKeyframe(2.1, duration: 0.54)
                    }
                    KeyframeTrack(\.opacity) {
                        CubicKeyframe(0.7, duration: 0.01)
                        CubicKeyframe(0, duration: 0.54)
                    }
                }
            Circle()
                .fill(Palette.elevated)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.16), lineWidth: 1.5))
                .frame(width: 28, height: 28)
            Circle()
                .fill(tint)
                .frame(width: 28, height: 28)
                .shadow(color: (done ? Palette.green : Palette.sky).opacity(reached ? 0.45 : 0), radius: 7, y: 3)
                .scaleEffect(reached ? 1 : 0.2)
                .opacity(reached ? 1 : 0)
            Image(systemName: info.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(reached ? Color.white : Color.secondary.opacity(0.7))
        }
        .frame(width: 28, height: 28)
        .scaleEffect(reached ? 1 : 0.86)
        .overlay(alignment: .top) {
            Text(info.name, language)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize()
                .offset(y: reached ? 36 : 44)
                .opacity(reached ? 1 : 0)
        }
        .overlay(alignment: .bottom) {
            Text(info.time)
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
                .offset(y: reached ? -34 : -44)
                .opacity(reached ? 1 : 0)
                .animation(spring.delay(reached ? 0.08 : 0), value: reached)
        }
        .animation(spring, value: reached)
        .animation(.smooth(duration: 0.4), value: done)
        .onChange(of: reached) { _, now in
            if now { bursts += 1 }
            if buzz { Haptics.selection() }
        }
    }
}

private struct MilestoneRing {
    var scale: CGFloat = 1
    var opacity: Double = 0
}
