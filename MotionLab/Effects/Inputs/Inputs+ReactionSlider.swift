import SwiftUI

extension Effect {
    static let inputsReactionSlider = Effect(
        id: "inputs.reaction-slider",
        category: .inputs,
        interaction: .gesture,
        name: L("Reaction Dock", "表情滑选条"),
        summary: L("Slide across a row of emoji: they swell under your finger like a dock, and the one you let go on bounces into place as the reaction.", "手指滑过一排表情，它们像程序坞一样在指下鼓起；松手时所在的那个弹跳一下，成为你的回应。"),
        prompt: L(
            "A reaction bar of six emoji in a floating capsule above a message bubble. Touching the bar wakes it on a spring (response 0.3 s, damping 0.65); while the finger slides, each emoji scales by a Gaussian of its distance to the finger, up to 190% directly under it with a 40 pt spread, growing from its bottom edge and rising slightly. Neighbours are pushed apart so nothing overlaps and the capsule widens to hold them. A small name tag follows above the largest emoji, and a selection haptic ticks whenever the nearest one changes. On release the bar relaxes to rest size (response 0.4 s, damping 0.7) while the chosen emoji hops 14 pt and overshoots to 135% before settling, and a reaction badge pops onto the bubble's corner from 30% scale with a bouncy spring (damping 0.5).",
            "消息气泡上方悬浮着胶囊形回应栏，内有六个表情。触碰回应栏时它以弹簧（响应 0.3 秒、阻尼 0.65）被唤醒；手指滑动时，每个表情按它到手指距离的高斯函数缩放：正下方最大到 190%，影响范围 40pt，从底边向上长大。相邻表情被挤开，胶囊随之变宽。最大的那个表情上方跟着一枚小名称标签，最近的表情每换一个就有一次选择触觉。松手后回应栏以弹簧（响应 0.4 秒、阻尼 0.7）回到静止大小，被选中的表情跳起 14pt、过冲到 135% 再落定；同时回应角标从 30% 弹到气泡一角（阻尼 0.5）。"
        ),
        implementation: L(
            "The bar is an Animatable view over the finger position and an activity amount: each frame it computes a Gaussian scale per emoji, lays them out by the running sum of their scaled widths, and sizes the capsule to the total. Autoplay simply animates the finger position, so the same code path sweeps the wave across.",
            "回应栏是以手指位置和激活程度为动画数据的 Animatable 视图：每帧为每个表情计算高斯缩放，按缩放后宽度的累加排布，并让胶囊适应总宽。自动演示只需给手指位置做动画，同一套代码就让波峰扫过整排。"
        ),
        apis: ["Animatable", "DragGesture", "scaleEffect(_:anchor:)", "keyframeAnimator", "spring(response:dampingFraction:)"],
        tags: ["reaction", "emoji", "dock", "magnify", "rating", "表情", "回应", "放大", "程序坞", "评分"],
        params: [
            .slider("scale", L("Max scale", "最大放大"), 1.3...2.4, default: 1.9, decimals: 1, unit: "×"),
            .slider("spread", L("Spread", "影响范围"), 20...80, default: 40, decimals: 0, unit: "pt"),
            .slider("damping", L("Badge bounce damping", "角标弹跳阻尼"), 0.3...0.9, default: 0.5),
        ]
    ) { ctx in
        InputReactionSliderDemo(ctx: ctx)
    }
}

private struct InputReaction {
    let emoji: String
    let name: LocalizedText

    static let all: [InputReaction] = [
        InputReaction(emoji: "❤️", name: L("Love", "喜欢")),
        InputReaction(emoji: "👍", name: L("Nice", "赞")),
        InputReaction(emoji: "😂", name: L("Haha", "哈哈")),
        InputReaction(emoji: "😮", name: L("Wow", "哇")),
        InputReaction(emoji: "🎉", name: L("Yay", "庆祝")),
        InputReaction(emoji: "🔥", name: L("Fire", "太燃了")),
    ]

    static let cell: CGFloat = 40
    static var restWidth: CGFloat { cell * CGFloat(all.count) }
}

private struct InputReactionSliderDemo: View {
    let ctx: DemoContext
    /// Finger position along the resting row, 0...restWidth.
    @State private var fingerX: CGFloat
    @State private var active: CGFloat
    @State private var selected: Int? = 4
    @State private var hovered = -1
    @State private var bounces: [Int] = Array(repeating: 0, count: InputReaction.all.count)
    @State private var step = 0
    @State private var playTask: Task<Void, Never>?
    @GestureState private var touching = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _fingerX = State(initialValue: InputReaction.cell * 3.5)
        _active = State(initialValue: ctx.isStill ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                bubble
                    .offset(y: 62)
                InputReactionBar(
                    fingerX: fingerX,
                    active: active,
                    maxScale: ctx.cg("scale"),
                    spread: ctx.cg("spread"),
                    bounces: bounces,
                    language: ctx.language
                )
                .offset(y: -38)
                Color.clear
                    .frame(width: InputReaction.restWidth + 24, height: 76)
                    .contentShape(Rectangle())
                    .gesture(drag)
                    .offset(y: -44)
            }
            .frame(width: 310, height: 250)
            Spacer(minLength: 0)
            DemoHint(text: L("Slide across the reactions, then let go", "在表情上滑动，再松手"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: touching) { _, down in
            if !down { release() }
        }
        .autoplay(ctx.isPreview, every: 2.0, delay: 0.5) { play() }
        .onDisappear { playTask?.cancel() }
    }

    private var bubble: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 6, bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            Text(L("We just shipped the update!", "新版本刚刚上线啦！"), ctx.language)
                .font(.callout)
                .foregroundStyle(.primary)
            Text(L("Go try the new animations.", "快去试试新的动效。"), ctx.language)
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 244, alignment: .leading)
        .background(Palette.elevated, in: shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) { badge }
    }

    @ViewBuilder private var badge: some View {
        if let selected {
            Text(verbatim: InputReaction.all[selected].emoji)
                .font(.system(size: 16))
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(Palette.elevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
                .offset(x: -10, y: 14)
                .id(selected)
                .transition(.scale(scale: 0.3).combined(with: .opacity))
        }
    }

    // MARK: Gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { gesture in
                playTask?.cancel()
                if active != 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { active = 1 }
                }
                hover(at: gesture.location.x - 12)
            }
            .onEnded { _ in release() }
    }

    private func hover(at x: CGFloat) {
        let clamped = x.clamped(to: 0...InputReaction.restWidth)
        withAnimation(.interactiveSpring(response: 0.14, dampingFraction: 0.85)) { fingerX = clamped }
        let index = Int(clamped / InputReaction.cell).clamped(to: 0...InputReaction.all.count - 1)
        if index != hovered {
            hovered = index
            Haptics.selection()
        }
    }

    /// Finger lift, cancelled touch and autoplay all end here.
    private func release() {
        guard hovered >= 0 else { return }
        let choice = hovered
        hovered = -1
        Haptics.tap(.medium)
        bounces[choice] += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { active = 0 }
        withAnimation(.spring(response: 0.38, dampingFraction: ctx["damping"])) { selected = choice }
    }

    private func play() {
        guard !touching else { return }
        let script = [1, 5, 2, 4, 0, 3]
        let target = script[step % script.count]
        step += 1
        playTask?.cancel()
        playTask = Task { @MainActor in
            let from: CGFloat = target >= 3 ? 14 : InputReaction.restWidth - 14
            fingerX = from
            hovered = Int(from / InputReaction.cell)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { active = 1 }
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.75)) { fingerX = (CGFloat(target) + 0.5) * InputReaction.cell }
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            hovered = target
            release()
        }
    }
}

/// The dock. Animatable over the finger position and the activity amount.
private struct InputReactionBar: View, Animatable {
    var fingerX: CGFloat
    var active: CGFloat
    let maxScale: CGFloat
    let spread: CGFloat
    let bounces: [Int]
    let language: AppLanguage

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(fingerX, active) }
        set {
            fingerX = newValue.first
            active = newValue.second
        }
    }

    private func scale(_ index: Int) -> CGFloat {
        let center = (CGFloat(index) + 0.5) * InputReaction.cell
        let distance = fingerX - center
        let falloff = exp(-(distance * distance) / (2 * spread * spread))
        return 1 + (maxScale - 1) * falloff * active
    }

    var body: some View {
        let count = InputReaction.all.count
        let scales = (0..<count).map(scale)
        let widths = scales.map { InputReaction.cell * (1 + ($0 - 1) * 0.8) }
        let total = widths.reduce(0, +)
        var centers: [CGFloat] = []
        var cursor = -total / 2
        for width in widths {
            centers.append(cursor + width / 2)
            cursor += width
        }
        let nearest = Int(fingerX / InputReaction.cell).clamped(to: 0...count - 1)
        let presence = Double(min(max(active, 0), 1))
        return ZStack {
            Capsule()
                .fill(Palette.elevated)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
                .frame(width: total + 20, height: 52)
            ForEach(0..<count, id: \.self) { index in
                Text(verbatim: InputReaction.all[index].emoji)
                    .font(.system(size: 27))
                    .keyframeAnimator(initialValue: InputReactionBounce(), trigger: bounces[index]) { view, value in
                        view
                            .scaleEffect(value.scale, anchor: .bottom)
                            .offset(y: value.lift)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.35, duration: 0.16, spring: .snappy)
                            SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                        }
                        KeyframeTrack(\.lift) {
                            SpringKeyframe(-14, duration: 0.16, spring: .snappy)
                            SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                        }
                    }
                    .scaleEffect(scales[index], anchor: .bottom)
                    .offset(x: centers[index], y: -(scales[index] - 1) * 5)
            }
            Text(InputReaction.all[nearest].name, language)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(Color.black.opacity(0.72), in: Capsule())
                .fixedSize()
                .opacity(presence)
                .scaleEffect(0.6 + 0.4 * presence)
                .offset(x: centers[nearest], y: -12 - 31 * scales[nearest] + 14 * (1 - presence))
        }
        .frame(width: InputReaction.restWidth + 20, height: 52)
    }
}

private struct InputReactionBounce {
    var scale: CGFloat = 1
    var lift: CGFloat = 0
}
