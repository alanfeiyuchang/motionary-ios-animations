import SwiftUI

extension Effect {
    static let cardsCollapseChip = Effect(
        id: "cards.collapse-chip",
        category: .cards,
        interaction: .gesture,
        name: L("Collapse to Chip", "收成侧边小标"),
        summary: L("Flick a timer card toward the edge and it shrinks into a small chip docked there; tap the chip and it grows back.", "把计时卡片朝屏幕边缘一甩，它缩成一枚停靠在边上的小圆标；点一下小圆标，它又长回卡片。"),
        prompt: L(
            "A 250×150 pt focus-timer card floats over a dimmed page. Tapping its minimise button, or dragging it sideways past a third of the way, collapses it into a 52 pt chip docked against that edge, 10 pt tucked off-screen. One spring (response 0.5 s, damping 0.72) drives everything: width leads height, so the card first narrows into a pill, then rounds into a circle as the corner radius eases from 26 pt to a full round; the content blurs and fades out in the first 40%, and the chip's ring and minutes fade in over the last 40%. The spring overshoots, so the chip bumps the edge, squashes about 10% and settles with a rigid haptic, while the page behind brightens and scales from 97% to 100%. Tapping or dragging the chip inward plays it back.",
            "一张250×150 pt的专注计时卡片浮在压暗的页面上方。点击最小化按钮，或把它横向拖过三分之一的距离，它就收成一枚52 pt的小圆标，停靠在那一侧边缘，其中10 pt藏到屏幕外。全程由一条弹簧（响应0.5秒、阻尼0.72）驱动：宽度先于高度变化，卡片先收窄成胶囊再变圆；内容在前40%内模糊淡出，小圆标的进度环和分钟数在最后40%内淡入。弹簧过冲让小圆标撞上边缘、压扁约10%再停稳，并落下一记清脆触感，背后的页面随之变亮，从97%放大到100%。点击小圆标或把它向内拖，则反向播放。"
        ),
        implementation: L(
            "An Animatable view takes one morph progress and derives the frame, corner radius, position, content fade and chip fade from it with different easing windows. The drag writes the same progress directly, and a GeometryReader supplies the dock position at the stage's edge.",
            "Animatable 视图接收一个形变进度，用不同的缓动区间从中推导出尺寸、圆角、位置、内容淡出和小圆标淡入。拖动直接写入同一个进度，GeometryReader 提供舞台边缘的停靠位置。"
        ),
        apis: ["Animatable", "GeometryReader", "DragGesture", "clipShape", "blur", "spring(response:dampingFraction:)"],
        tags: ["collapse", "chip", "dock", "minimize", "收起", "停靠", "最小化", "小圆标"],
        params: [
            .choice("edge", L("Dock edge", "停靠边"), [L("Right", "右侧"), L("Left", "左侧")], default: 0),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.72),
            .slider("chip", L("Chip size", "小标尺寸"), 40...64, default: 52, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        CardsChipDemo(ctx: ctx)
    }
}

private enum CardsChipLayout {
    static let card = CGSize(width: 250, height: 150)
    static let dockY: CGFloat = 54
    static let tuck: CGFloat = 10
}

private struct CardsChipDemo: View {
    let ctx: DemoContext
    /// 0 card, 1 chip.
    @State private var morph: CGFloat
    @State private var collapsed: Bool
    /// −1 left edge, +1 right edge.
    @State private var side: CGFloat
    @State private var dragStart: CGFloat?
    @State private var bump: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _morph = State(initialValue: 0)
        _collapsed = State(initialValue: false)
        _side = State(initialValue: ctx.int("edge") == 1 ? -1 : 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                stage(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(height: 280)
            DemoHint(text: L("Flick the card to an edge, tap the chip to restore", "把卡片甩向边缘，点击小圆标还原"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { set(!collapsed, to: ctx.int("edge") == 1 ? -1 : 1, haptic: false) }
        .onChange(of: pressing) { _, isPressing in
            guard !isPressing else { return }
            // onEnded can arrive just after the gesture state resets, so this fallback waits a tick:
            // by then only a cancelled touch still has something to clean up.
            Task { @MainActor in
                if dragStart != nil {
                    dragStart = nil
                    set(morph > 0.5, to: side, haptic: true)
                }
            }
        }
        .onChange(of: ctx.int("edge")) { _, edge in
            if collapsed { set(true, to: edge == 1 ? -1 : 1, haptic: false) }
        }
        .onDisappear { bump?.cancel() }
    }

    private func stage(width: CGFloat, height: CGFloat) -> some View {
        let chip = ctx.cg("chip")
        let dock = width / 2 - chip / 2 + CardsChipLayout.tuck
        return ZStack {
            CardsChipPage(clear: morph.clamped(to: 0...1))
                .frame(width: min(width - 36, 300), height: height - 16)
            CardsChipMorph(morph: morph, side: side, dock: dock, chip: chip, language: ctx.language, still: ctx.isStill)
                .gesture(drag(dock: dock))
        }
        .frame(width: width, height: height)
    }

    private func drag(dock: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if dragStart == nil {
                    dragStart = morph
                    bump?.cancel()
                }
                guard let start = dragStart, abs(value.translation.width) > 4 else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if start < 0.5 {
                        // The card follows the finger toward whichever edge it is dragged to.
                        side = value.translation.width >= 0 ? 1 : -1
                        morph = (abs(value.translation.width) / dock).clamped(to: 0...1.05)
                    } else {
                        // The chip is pulled back inward.
                        morph = (1 - max(-side * value.translation.width, 0) / dock).clamped(to: 0...1.05)
                    }
                }
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                if hypot(value.translation.width, value.translation.height) < 8 {
                    if start > 0.5 {
                        // A tap restores the chip.
                        set(false, to: side, haptic: true)
                    } else if value.startLocation.x > CardsChipLayout.card.width - 62, value.startLocation.y < 62 {
                        // On the card, only the minimise button in its top-right corner collapses it.
                        set(true, to: ctx.int("edge") == 1 ? -1 : 1, haptic: true)
                    }
                    return
                }
                let flick = abs(value.predictedEndTranslation.width) / dock
                if start < 0.5 {
                    set(morph > 0.33 || flick > 0.6, to: side, haptic: true)
                } else {
                    let inward = max(-side * value.predictedEndTranslation.width, 0) / dock
                    set(inward < 0.33, to: side, haptic: true)
                }
            }
    }

    private func set(_ collapse: Bool, to edge: CGFloat, haptic: Bool) {
        let response = ctx["response"]
        let buzz = haptic && !ctx.isPreview
        let changed = collapse != collapsed
        collapsed = collapse
        if collapse { side = edge }
        withAnimation(.spring(response: response, dampingFraction: ctx["damping"])) {
            morph = collapse ? 1 : 0
        }
        bump?.cancel()
        guard buzz, changed else { return }
        if !collapse {
            Haptics.tap(.light)
            return
        }
        bump = Task { @MainActor in
            // The chip reaches the edge a little after half the spring's response.
            try? await Task.sleep(for: .seconds(response * 0.55))
            guard !Task.isCancelled else { return }
            Haptics.tap(.rigid)
        }
    }
}

/// The card ↔ chip surface for one morph progress.
private struct CardsChipMorph: View, Animatable {
    var morph: CGFloat
    let side: CGFloat
    let dock: CGFloat
    let chip: CGFloat
    let language: AppLanguage
    let still: Bool

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    var body: some View {
        let m = morph.clamped(to: 0...1)
        let over = max(morph - 1, 0)
        // Width leads, height follows: card → pill → circle.
        let wide = Self.ease((m / 0.75).clamped(to: 0...1))
        let tall = Self.ease(((m - 0.2) / 0.8).clamped(to: 0...1))
        let card = CardsChipLayout.card
        let width = card.width + (chip - card.width) * wide
        let height = card.height + (chip - card.height) * tall
        let radius = 26 + (chip / 2 - 26) * tall
        let shape = RoundedRectangle(cornerRadius: min(radius, min(width, height) / 2), style: .continuous)
        let content = Double((1 - m / 0.4).clamped(to: 0...1))
        let glyph = Double(((m - 0.6) / 0.4).clamped(to: 0...1))
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2B2F45), Color(hex: 0x16182A)], startPoint: .topLeading, endPoint: .bottomTrailing)
            CardsChipTimer(language: language, still: still, compact: false)
                .frame(width: card.width, height: card.height)
                .blur(radius: 8 * (1 - content))
                .opacity(content)
            CardsChipTimer(language: language, still: still, compact: true)
                .frame(width: chip, height: chip)
                .scaleEffect(0.6 + 0.4 * glyph)
                .opacity(glyph)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .contentShape(shape)
        // Hitting the edge squashes the chip against it.
        .scaleEffect(x: 1 - min(over * 2.4, 0.2), y: 1 + min(over * 1.2, 0.1), anchor: side > 0 ? .trailing : .leading)
        .shadow(color: .black.opacity(0.3), radius: 16 - 8 * m, y: 10 - 5 * m)
        .offset(x: side * dock * morph, y: CardsChipLayout.dockY * Self.ease(m) - 8 * (1 - m))
    }

    private static func ease(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }
}

/// The timer, as the full card content or as the chip's ring.
private struct CardsChipTimer: View {
    let language: AppLanguage
    let still: Bool
    let compact: Bool

    private let total: Double = 25 * 60

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            // A 25-minute session, somewhere in its first half, counting down live.
            let elapsed = still ? 396 : (396 + timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600))
            let left = max(total - elapsed, 0)
            if compact {
                chip(left: left)
            } else {
                card(left: left)
            }
        }
    }

    private func ring(left: Double, width: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: width)
            Circle()
                .trim(from: 0, to: left / total)
                .stroke(LinearGradient(colors: [Palette.mint, Palette.sky], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    private func chip(left: Double) -> some View {
        ZStack {
            ring(left: left, width: 3.5)
                .padding(6)
            Text(verbatim: "\(Int(left / 60))")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    private func card(left: Double) -> some View {
        let minutes = Int(left) / 60
        let seconds = Int(left) % 60
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.mint)
                Text(L("Focus session", "专注时段"), language)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                Spacer(minLength: 0)
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 14) {
                ring(left: left, width: 6)
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: String(format: "%02d:%02d", minutes, seconds))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                    Text(L("Deep work · round 2 of 4", "深度工作 · 第 2 / 4 轮"), language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .padding(16)
    }
}

/// The page the card floats over: dimmed and slightly small while the card is up.
private struct CardsChipPage: View {
    let clear: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color.primary.opacity(0.22))
                .frame(width: 120, height: 14)
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.spectrum[(row * 2) % Palette.spectrum.count].opacity(0.55))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Color.primary.opacity(0.2)).frame(height: 9)
                        Capsule().fill(Color.primary.opacity(0.12)).frame(width: 110, height: 9)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .scaleEffect(0.97 + 0.03 * clear)
        .opacity(0.35 + 0.65 * Double(clear))
    }
}
