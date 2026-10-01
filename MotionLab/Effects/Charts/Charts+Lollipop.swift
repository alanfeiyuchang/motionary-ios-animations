import SwiftUI

extension Effect {
    static let chartsLollipop = Effect(
        id: "charts.lollipop",
        category: .charts,
        interaction: .tap,
        name: L("Lollipop Drop & Sort", "棒棒糖落点与排序"),
        summary: L("Stems rise, the dots fall onto their tips and bounce, and sorting slides every lollipop to its rank.", "细杆升起，圆点落到杆顶弹跳，排序时每根棒棒糖滑向自己的名次。"),
        prompt: L(
            "A lollipop chart of eight regions: 3 pt stems on a hairline baseline, each topped by an 18 pt gradient dot with its value above. On appear the stems grow on a spring (response 0.5 s, damping 0.8), 60 ms apart; 0.22 s later each dot is released from above the plot and falls onto its stem tip under gravity, rebounding three times with restitution 0.45 over 0.8 s and squashing 20% at each impact, then its value fades in. Tapping Sort re-orders by value: every lollipop slides to its new slot on a spring (response 0.5 s, damping 0.74), staggered 35 ms by rank, while its dot hops 12 pt and settles. The Sort chip tints and its arrows flip. A soft haptic rains down with the landings. Playful, physical and still exact.",
            "八个地区的棒棒糖图：细基线上立着 3pt 细杆，杆顶是 18pt 渐变圆点，上方标注数值。出现时细杆以弹簧（响应 0.5 秒、阻尼 0.8）依次升起，间隔 60 毫秒；0.22 秒后圆点从图表上方被释放，在重力下落到杆顶，以恢复系数 0.45 弹跳三次（共 0.8 秒），每次触地压扁 20%，随后数值淡入。点「排序」按数值重排：每根棒棒糖以弹簧（响应 0.5 秒、阻尼 0.74）滑到新位置，按名次错开 35 毫秒，同时圆点跳起 12pt 再落稳，排序标签着色、箭头翻转。落点伴随雨点般的轻触感。俏皮而精确。"
        ),
        implementation: L(
            "Each lollipop is an Animatable view: the stem height and a linear drop clock are interpolated, and the clock is mapped through a parabolic bounce function for height and squash. Sorting only changes the slot offset, animated with a rank-delayed spring; a keyframeAnimator adds the hop.",
            "每根棒棒糖是一个 Animatable 视图：插值细杆高度与线性的下落时钟，再把时钟映射到抛物线弹跳函数得到高度与压扁量。排序只改变槽位偏移，用按名次延迟的弹簧驱动；keyframeAnimator 叠加跳起动作。"
        ),
        apis: ["Animatable", "keyframeAnimator", "spring(response:dampingFraction:)", "Animation.delay", "offset"],
        tags: ["lollipop", "dot plot", "sort", "bounce", "棒棒糖图", "排序", "弹跳", "点图"],
        params: [
            .slider("stagger", L("Stagger", "错峰间隔"), 0...0.15, default: 0.06, unit: "s"),
            .slider("bounce", L("Restitution", "恢复系数"), 0...0.7, default: 0.45),
            .slider("response", L("Sort response", "排序弹簧响应"), 0.3...0.9, default: 0.5, unit: "s"),
        ]
    ) { ctx in
        LollipopDemo(ctx: ctx)
    }
}

private struct LollipopItem {
    let code: String
    let value: Double
    let color: Color
}

private let lollipopItems: [LollipopItem] = [
    LollipopItem(code: "US", value: 62, color: Palette.indigo),
    LollipopItem(code: "JP", value: 88, color: Palette.violet),
    LollipopItem(code: "DE", value: 45, color: Palette.pink),
    LollipopItem(code: "FR", value: 73, color: Palette.coral),
    LollipopItem(code: "UK", value: 34, color: Palette.amber),
    LollipopItem(code: "BR", value: 95, color: Palette.mint),
    LollipopItem(code: "IN", value: 56, color: Palette.sky),
    LollipopItem(code: "KR", value: 68, color: Palette.blue),
]

/// Slot of each item when sorted by value, largest first.
private let lollipopRanks: [Int] = {
    let order = lollipopItems.indices.sorted { lollipopItems[$0].value > lollipopItems[$1].value }
    var ranks = [Int](repeating: 0, count: lollipopItems.count)
    for (rank, index) in order.enumerated() { ranks[index] = rank }
    return ranks
}()

private struct LollipopDemo: View {
    let ctx: DemoContext
    @State private var grow: [Double] = Array(repeating: 1, count: lollipopItems.count)
    @State private var drop: [Double] = Array(repeating: 1, count: lollipopItems.count)
    @State private var sorted = false
    @State private var sortCount = 0
    @State private var autoStep = 0
    @State private var rain: Task<Void, Never>?

    private let plotWidth: CGFloat = 268
    private let plotHeight: CGFloat = 150

    var body: some View {
        ChartStage(hint: L("Tap Sort, or the chart to drop again", "点「排序」，或点图表让圆点重新落下"), ctx: ctx) {
            VStack(alignment: .leading, spacing: 8) {
                header
                plot
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.tap(.light)
                        replay()
                    }
            }
            .padding(16)
            .frame(width: 300)
            .demoCard()
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: { clear() }, then: { play() })
        }
        .onDisappear { rain?.cancel() }
        .autoplay(ctx.isPreview, every: 2.1, delay: 2.4, intro: false) { autoAdvance() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ctx.language == .zh ? "各地区下载量" : "Downloads by region")
                    .font(.subheadline.weight(.semibold))
                Text(ctx.language == .zh ? "千次 · 本周" : "Thousands · this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                toggleSort()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(sorted ? 180 : 0))
                    Text(ctx.language == .zh ? "排序" : "Sort")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(sorted ? Color.white : Color.primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(sorted ? AnyShapeStyle(Palette.primaryStrong) : AnyShapeStyle(Color.primary.opacity(0.08)), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: sorted)
        }
    }

    private var plot: some View {
        let slot = plotWidth / CGFloat(lollipopItems.count)
        return ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.primary.opacity(0.14))
                .frame(width: plotWidth, height: 1)
                .offset(y: -18)
            ForEach(lollipopItems.indices, id: \.self) { index in
                let position = sorted ? lollipopRanks[index] : index
                LollipopMark(
                    item: lollipopItems[index],
                    grow: grow[index],
                    drop: drop[index],
                    restitution: ctx["bounce"],
                    plotHeight: plotHeight,
                    hop: sortCount,
                    hopDelay: Double(position) * 0.035
                )
                .frame(width: slot, height: plotHeight + 18, alignment: .bottom)
                .offset(x: CGFloat(position) * slot)
                .animation(.spring(response: ctx["response"], dampingFraction: 0.74).delay(Double(position) * 0.035), value: sorted)
            }
        }
        .frame(width: plotWidth, height: plotHeight + 18, alignment: .bottomLeading)
    }

    private func clear() {
        grow = Array(repeating: 0, count: lollipopItems.count)
        drop = Array(repeating: 0, count: lollipopItems.count)
    }

    private func replay() {
        rain?.cancel()
        chartInstant {
            clear()
            sorted = false
        }
        rain = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.05))
            guard !Task.isCancelled else { return }
            play()
        }
    }

    private func play() {
        let stagger = ctx["stagger"]
        for index in lollipopItems.indices {
            let delay = Double(index) * stagger
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) { grow[index] = 1 }
            withAnimation(.linear(duration: 0.8).delay(0.22 + delay)) { drop[index] = 1 }
        }
        guard !ctx.isPreview else { return }
        // One soft tick per landing; silent during the arrival quiet window, so only a tap-triggered drop rains.
        let impact = 0.8 * ChartKit.firstImpact(restitution: ctx["bounce"])
        rain = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.22 + impact))
            for _ in lollipopItems.indices {
                guard !Task.isCancelled else { return }
                Haptics.tap(.soft)
                try? await Task.sleep(for: .seconds(max(stagger, 0.02)))
            }
        }
    }

    /// The Sort chip and autoplay share this.
    private func toggleSort() {
        Haptics.selection()
        sorted.toggle()
        sortCount += 1
    }

    private func autoAdvance() {
        autoStep += 1
        if autoStep % 3 == 0 { replay() } else { toggleSort() }
    }
}

private struct LollipopMark: View, Animatable {
    let item: LollipopItem
    var grow: Double
    var drop: Double
    let restitution: Double
    let plotHeight: CGFloat
    let hop: Int
    let hopDelay: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(grow, drop) }
        set {
            grow = newValue.first
            drop = newValue.second
        }
    }

    private static let dot: CGFloat = 18

    var body: some View {
        let full = (plotHeight - 30) * CGFloat(item.value / 100)
        let stem = max(full * CGFloat(grow), 0)
        let height = CGFloat(ChartKit.bounceHeight(drop, restitution: restitution))
        let squash = CGFloat(ChartKit.bounceSquash(drop, restitution: restitution))
        let fall = height * (plotHeight - full + 8)
        let labelAlpha = ChartKit.smoothstep(0.7, 1, drop)

        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(LinearGradient(colors: [item.color.opacity(0.75), item.color.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: stem)
                VStack(spacing: 2) {
                    Text(verbatim: "\(Int(item.value))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .opacity(labelAlpha)
                    Circle()
                        .fill(item.color.gradient)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5))
                        .frame(width: Self.dot, height: Self.dot)
                        .scaleEffect(x: 1 + squash, y: 1 - squash, anchor: .bottom)
                        .shadow(color: item.color.opacity(0.45), radius: 5, y: 3)
                }
                .opacity(drop > 0.002 ? 1 : 0)
                .offset(y: -(full - Self.dot / 2) - fall)
                .keyframeAnimator(initialValue: CGFloat(0), trigger: hop) { content, lift in
                    content.offset(y: lift)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(CGFloat(0), duration: max(hopDelay, 0.001))
                        SpringKeyframe(CGFloat(-12), duration: 0.2, spring: .snappy)
                        SpringKeyframe(CGFloat(0), duration: 0.5, spring: .bouncy)
                    }
                }
            }
            .frame(height: plotHeight, alignment: .bottom)
            Text(verbatim: item.code)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(height: 14)
        }
    }
}
