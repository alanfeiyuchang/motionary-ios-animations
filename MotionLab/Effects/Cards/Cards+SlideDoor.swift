import SwiftUI

extension Effect {
    static let cardsSlideDoor = Effect(
        id: "cards.slide-door",
        category: .cards,
        interaction: .gesture,
        name: L("Sliding Door", "滑门揭示"),
        summary: L("A cover slides into the card's frame like a pocket door, uncovering a recessed code under a moving edge shadow.", "盖板像暗藏式推拉门一样滑进卡片边框，露出下方凹槽里的密码，门边的阴影随之移动。"),
        prompt: L(
            "A 264×172 pt card whose frame holds a recessed well with an inner shadow. A satin cover fills the well, with a grip at its leading edge and a lock glyph. Dragging it sideways slides it into the frame's pocket, tracking the finger 1:1 and rubber-banding past either stop; a tap toggles it. The cover's edge casts a 28 pt soft shadow that travels across the content, which brightens from 45% and scales from 94% to 100% as light reaches it. On release a spring (response 0.45 s, damping 0.72) carries the door to the nearer stop, taking the flick velocity into account: it bumps slightly past the stop and seats with a rigid haptic. Once open, four code digits rise 10 pt and fade in 60 ms apart and the lock glyph swaps to open. A two-leaf option parts the cover from the centre.",
            "264×172 pt的卡片，边框内是带内阴影的凹槽。缎面盖板盖住凹槽，前缘有拉手和锁形图标。横向拖动，盖板滑进边框内的暗槽，1:1跟手，超出两端止点有橡皮筋阻力；点击则开合。盖板边缘投下一道28 pt的柔和阴影扫过内容；内容随光照从45%亮度变亮，并从94%放大到100%。松手后弹簧（响应0.45秒、阻尼0.72）结合甩动速度把门送到较近的止点，略微冲过再落位，并有清脆触感。完全打开后，四位密码依次上移10 pt淡入，间隔60毫秒，锁形图标换成开锁。也可切换成从中间分开的双扇门。"
        ),
        implementation: L(
            "One open amount (0…1) offsets the cover inside a clipShape, so the part that leaves the well disappears into the frame. The edge shadow is a gradient strip attached to the door's leading edge; the well uses an inner-shadow ShapeStyle. Two leaves are the same cover drawn twice with opposite half masks.",
            "一个开合量（0…1）在 clipShape 内偏移盖板，滑出凹槽的部分就消失在边框里。门边阴影是贴在门前缘的一条渐变；凹槽使用内阴影 ShapeStyle。双扇门是把同一块盖板用相反的半边遮罩画两次。"
        ),
        apis: ["clipShape", "ShadowStyle.inner", "DragGesture", "mask", "contentTransition", "spring(response:dampingFraction:)"],
        tags: ["door", "slide", "cover", "reveal", "滑门", "推拉", "盖板", "揭示"],
        params: [
            .choice("leaves", L("Door", "门扇"), [L("Single", "单扇"), L("Double", "双扇")], default: 0),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.45, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.45...1.0, default: 0.72),
            .slider("depth", L("Well depth", "凹槽深度"), 0...1, default: 0.7),
        ]
    ) { ctx in
        CardsDoorDemo(ctx: ctx)
    }
}

private enum CardsDoorLayout {
    static let outer = CGSize(width: 264, height: 172)
    static let inner = CGSize(width: 246, height: 154)
    static var outerShape: RoundedRectangle { RoundedRectangle(cornerRadius: 27, style: .continuous) }
    static var innerShape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
    /// What stays visible of a leaf when it is fully open (it carries the grip).
    static let singleStub: CGFloat = 38
    static let doubleStub: CGFloat = 24
}

private struct CardsDoorDemo: View {
    let ctx: DemoContext
    /// 0 closed, 1 open.
    @State private var open: CGFloat
    @State private var isOpen: Bool
    @State private var dragStart: CGFloat?
    @State private var dragSign: CGFloat = 1
    @State private var latch: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the door most of the way open.
        _open = State(initialValue: ctx.isStill ? 0.8 : 0)
        _isOpen = State(initialValue: ctx.isStill)
    }

    private var double: Bool { ctx.int("leaves") == 1 }

    private var travel: CGFloat {
        double
            ? CardsDoorLayout.inner.width / 2 - CardsDoorLayout.doubleStub
            : CardsDoorLayout.inner.width - CardsDoorLayout.singleStub
    }

    var body: some View {
        VStack(spacing: 16) {
            card
                .contentShape(Rectangle())
                .gesture(drag)
            DemoHint(text: L("Slide the cover, or tap", "滑动盖板，或点击"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.8) { settle(open: !isOpen, velocity: 0, haptic: false) }
        .onChange(of: pressing) { _, isPressing in
            guard !isPressing else { return }
            // onEnded can arrive just after the gesture state resets, so this fallback waits a tick:
            // by then only a cancelled touch still has something to clean up.
            Task { @MainActor in
                if dragStart != nil {
                    dragStart = nil
                    settle(open: open > 0.5, velocity: 0, haptic: true)
                }
            }
        }
        .onDisappear { latch?.cancel() }
    }

    private var card: some View {
        let depth = ctx["depth"]
        return ZStack {
            CardsDoorLayout.outerShape
                .fill(LinearGradient(colors: [Palette.elevated, Palette.surface], startPoint: .top, endPoint: .bottom))
                .overlay(CardsDoorLayout.outerShape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
            ZStack {
                CardsDoorWell(open: open.clamped(to: 0...1), shift: double ? 0 : -CardsDoorLayout.singleStub / 2, revealed: isOpen, depth: depth, language: ctx.language)
                CardsDoorLeaves(open: open, travel: travel, double: double, unlocked: isOpen, depth: depth, language: ctx.language)
                // The well's rim shades whatever sits inside it, door included.
                CardsDoorLayout.innerShape
                    .stroke(Color.black.opacity(0.5 * depth), lineWidth: 5)
                    .blur(radius: 4)
                    .offset(y: 2.5)
            }
            .frame(width: CardsDoorLayout.inner.width, height: CardsDoorLayout.inner.height)
            .clipShape(CardsDoorLayout.innerShape)
            .overlay(CardsDoorLayout.innerShape.strokeBorder(Color.black.opacity(0.28), lineWidth: 1))
            // The whole card takes the gesture; nothing inside needs touches of its own.
            .allowsHitTesting(false)
        }
        .frame(width: CardsDoorLayout.outer.width, height: CardsDoorLayout.outer.height)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if dragStart == nil {
                    dragStart = open
                    latch?.cancel()
                    // A double door is pulled outward from whichever leaf the finger is on.
                    dragSign = double && value.startLocation.x < CardsDoorLayout.outer.width / 2 ? -1 : 1
                }
                guard let start = dragStart else { return }
                let raw = start + dragSign * value.translation.width / travel
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { open = banded(raw) }
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                if hypot(value.translation.width, value.translation.height) < 8 {
                    settle(open: !isOpen, velocity: 0, haptic: true)
                    return
                }
                let projected = start + dragSign * value.predictedEndTranslation.width / travel
                let velocity = dragSign * value.velocity.width / travel
                settle(open: projected > 0.5, velocity: velocity, haptic: true)
            }
    }

    private func banded(_ value: CGFloat) -> CGFloat {
        if value < 0 { return rubberBand(value * travel, limit: 30) / travel }
        if value > 1 { return 1 + rubberBand((value - 1) * travel, limit: 30) / travel }
        return value
    }

    private func settle(open target: Bool, velocity: CGFloat, haptic: Bool) {
        let response = ctx["response"]
        let goal: CGFloat = target ? 1 : 0
        let distance = goal - open
        // SwiftUI wants the velocity relative to the remaining distance.
        let relative: Double = abs(distance) > 0.01 ? Double((velocity / distance).clamped(to: -12...12)) : 0
        withAnimation(.interpolatingSpring(.init(response: response, dampingRatio: ctx["damping"]), initialVelocity: relative)) {
            open = goal
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isOpen = target
        }
        latch?.cancel()
        guard haptic, !ctx.isPreview else { return }
        latch = Task { @MainActor in
            try? await Task.sleep(for: .seconds(response * 0.55))
            guard !Task.isCancelled else { return }
            Haptics.tap(.rigid)
        }
    }
}

/// The recessed floor and what is written on it.
private struct CardsDoorWell: View {
    let open: CGFloat
    /// Where the content sits once open: centred in what the parked door leaves visible.
    let shift: CGFloat
    let revealed: Bool
    let depth: Double
    let language: AppLanguage

    private let digits = ["7", "4", "2", "9"]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(colors: [Color(hex: 0x10121C), Color(hex: 0x1B2032)], startPoint: .top, endPoint: .bottom)
                        .shadow(.inner(color: .black.opacity(0.7 * depth), radius: 9, y: 6))
                )
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(L("DOOR CODE", "门禁密码"), language)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                }
                .foregroundStyle(Color.white.opacity(0.55))
                HStack(spacing: 8) {
                    ForEach(0..<digits.count, id: \.self) { index in
                        digit(index)
                    }
                }
                Text(L("Valid for 10 minutes", "10 分钟内有效"), language)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            // Light reaches the content as the door clears it.
            .scaleEffect(0.94 + 0.06 * open)
            .offset(x: shift * open)
            .brightness(-0.55 * Double(1 - open))
        }
    }

    private func digit(_ index: Int) -> some View {
        Text(verbatim: digits[index])
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color(hex: 0x7DF3D0))
            .shadow(color: Color(hex: 0x21D4A8).opacity(revealed ? 0.6 : 0), radius: 8)
            .offset(y: revealed ? 0 : 10)
            .opacity(revealed ? 1 : 0.25)
            .frame(width: 38, height: 46)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(revealed ? 0.06 * Double(index) : 0), value: revealed)
    }
}

private struct CardsDoorLeaves: View {
    let open: CGFloat
    let travel: CGFloat
    let double: Bool
    let unlocked: Bool
    let depth: Double
    let language: AppLanguage

    private var size: CGSize { CardsDoorLayout.inner }

    var body: some View {
        ZStack {
            if double {
                leaf(sign: -1, range: 0...0.5)
                leaf(sign: 1, range: 0.5...1)
            } else {
                leaf(sign: 1, range: 0...1)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// One leaf: the part of the cover between `range` (fractions of the width), moving toward `sign`.
    private func leaf(sign: CGFloat, range: ClosedRange<CGFloat>) -> some View {
        let left = range.lowerBound * size.width
        let width = (range.upperBound - range.lowerBound) * size.width
        // The edge that uncovers the content: the left edge of a leaf moving right, and vice versa.
        let edge: CGFloat = sign > 0 ? left : left + width
        return ZStack(alignment: .topLeading) {
            // Shadow cast onto the well, just outside the leading edge.
            LinearGradient(
                colors: [Color.black.opacity(0.55 * depth), Color.black.opacity(0)],
                startPoint: sign > 0 ? .trailing : .leading,
                endPoint: sign > 0 ? .leading : .trailing
            )
            .frame(width: 28, height: size.height)
            .offset(x: sign > 0 ? edge - 28 : edge)
            .opacity(Double((open * 8).clamped(to: 0...1)))
            CardsDoorCover(unlocked: unlocked, language: language)
                .mask(alignment: .leading) {
                    Rectangle().frame(width: width).offset(x: left)
                }
            grip
                .offset(x: sign > 0 ? edge + 9 : edge - 9 - 12, y: (size.height - 44) / 2)
            // The leading edge is a bevel that catches light.
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 1, height: size.height)
                .offset(x: sign > 0 ? edge : edge - 1)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .offset(x: sign * open * travel)
    }

    private var grip: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(LinearGradient(colors: [Color.black.opacity(0.3), Color.white.opacity(0.45)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 2, height: 44)
            }
        }
        .frame(width: 12)
    }
}

/// The satin cover, drawn at the full size of the well.
private struct CardsDoorCover: View {
    let unlocked: Bool
    let language: AppLanguage

    var body: some View {
        let size = CardsDoorLayout.inner
        ZStack {
            LinearGradient(colors: [Color(hex: 0x6C63FF), Color(hex: 0x8F5BFF), Color(hex: 0x4B3FD9)], startPoint: .topLeading, endPoint: .bottomTrailing)
            // Satin sheen: a broad diagonal band.
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0.2),
                    .init(color: .white.opacity(0.22), location: 0.45),
                    .init(color: .white.opacity(0), location: 0.7),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: 30)
                Text(L("Slide to reveal", "滑动查看"), language)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
        }
        .frame(width: size.width, height: size.height)
    }
}
