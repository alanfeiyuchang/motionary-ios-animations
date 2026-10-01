import SwiftUI

extension Effect {
    static let navigationPeekPop = Effect(
        id: "navigation.peek-pop",
        category: .navigation,
        interaction: .gesture,
        name: L("Peek & Pop", "预览与弹入"),
        summary: L(
            "Hold a message and it lifts into a preview over the blurred list; keep the finger down and drag up, and the preview grows into the full page.",
            "按住一封邮件，它抬起成为预览，列表在其后模糊；手指不放向上拖，预览就长成完整页面。"
        ),
        prompt: L(
            "An inbox of four 52 pt message rows. Holding a row sinks it to 96% for 0.35 s, then a medium haptic fires and the row itself grows into a 232 × 190 pt preview card (corners 16 → 24 pt) on a spring (response 0.45 s, damping 0.78): the sender line stays where it was while the message body and a photo fade in beneath, the list recedes to 96%, blurs 8 pt and dims 25%. Without lifting, dragging up stretches the card toward the screen edges 1:1 over 110 pt of travel, corners easing to the frame's 34 pt and a navigation bar unfolding at the top; past 45% or on a fast flick it pops to full screen with a firm haptic, otherwise it springs back to the peek. Letting go at the peek, or dragging down, drops it back into its row.",
            "收件箱里有四行 52 pt 高的邮件。按住某一行，它在 0.35 秒内沉到 96%，随后一记中等触感，这一行本身以弹簧（响应 0.45 秒、阻尼 0.78）长成 232 × 190 pt 的预览卡片（圆角 16 → 24 pt）：发件人一行留在原位，正文和照片在其下淡入；列表退到 96%、模糊 8 pt、压暗 25%。手指不抬起继续上拖，卡片在 110 pt 行程内 1:1 向屏幕四边伸展，圆角过渡到 34 pt，顶部展开导航栏；超过 45% 或快速一甩即弹入全屏，否则弹回预览。在预览时松手或向下拖，它落回原来那一行。"
        ),
        implementation: L(
            "A LongPressGesture sequenced before a DragGesture drives two numbers, lift and pop; the card's frame, corner radius and content opacity are interpolated between the row's rect, the peek rect and the full frame from them, so no view is swapped.",
            "LongPressGesture 与随后的 DragGesture 串联，驱动抬起量与弹入量两个数值；卡片的 frame、圆角与内容透明度都由它们在「行矩形、预览矩形、全屏矩形」之间插值得出，全程不替换视图。"
        ),
        apis: ["LongPressGesture", "SequenceGesture", "DragGesture", "GestureState", "blur(radius:)", "spring(response:dampingFraction:)"],
        tags: ["peek", "pop", "long press", "preview", "预览", "长按", "弹入", "3D Touch"],
        params: [
            .slider("hold", L("Hold duration", "长按时长"), 0.2...0.8, default: 0.35, unit: "s"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.8, default: 0.45, unit: "s"),
            .slider("blur", L("Background blur", "背景模糊"), 0...14, default: 8, decimals: 0, unit: "pt"),
            .toggle("sticky", L("Peek stays after release", "松手后保持预览"), default: false),
        ]
    ) { ctx in
        PeekPopDemo(ctx: ctx)
    }
}

private struct PeekMail {
    let initial: String
    let color: Color
    let sender: LocalizedText
    let subject: LocalizedText
    let time: LocalizedText
    let message: LocalizedText
    let symbol: String
    let art: [Color]
}

private let peekMails: [PeekMail] = [
    PeekMail(
        initial: "M", color: Palette.pink,
        sender: L("Mia Chen", "陈米娅"), subject: L("Photos from the ridge", "山脊上的照片"), time: L("9:41", "9:41"),
        message: L("We made it up before sunrise. The light on the lake was unreal, have a look.", "我们赶在日出前登顶了。湖面上的光美得不真实，你看看。"),
        symbol: "mountain.2.fill", art: [Palette.sky, Palette.indigo]
    ),
    PeekMail(
        initial: "K", color: Palette.indigo,
        sender: L("Kai Tanaka", "田中凯"), subject: L("Motion review at 3", "三点动效评审"), time: L("8:15", "8:15"),
        message: L("I pushed the new tab bar springs. Bring your phone, it only makes sense in the hand.", "新的标签栏弹簧我已经提交了。记得带手机，这东西得拿在手里才有感觉。"),
        symbol: "wand.and.stars", art: [Palette.violet, Palette.pink]
    ),
    PeekMail(
        initial: "L", color: Palette.mint,
        sender: L("Lena Park", "朴莉娜"), subject: L("Weekend market", "周末集市"), time: L("Tue", "周二"),
        message: L("The flower stall is back. Saturday at ten, coffee is on me this time.", "花摊回来了。周六十点见，这次咖啡我请。"),
        symbol: "leaf.fill", art: [Palette.mint, Palette.green]
    ),
    PeekMail(
        initial: "S", color: Palette.amber,
        sender: L("Sam Rivera", "里维拉"), subject: L("Your ticket to Lisbon", "你的里斯本机票"), time: L("Mon", "周一"),
        message: L("Boarding pass attached. Window seat, as promised. See you at the gate.", "登机牌在附件里。按约定给你留了靠窗的位子，登机口见。"),
        symbol: "airplane", art: [Palette.amber, Palette.coral]
    ),
]

private enum PeekMetrics {
    static let frame = CGSize(width: 260, height: 290)
    static let rowHeight: CGFloat = 52
    static let rowStep: CGFloat = 57
    static let listTop: CGFloat = 54
    static let peek = CGRect(x: 14, y: 48, width: 232, height: 190)
    static let popTravel: CGFloat = 110

    static func row(_ index: Int) -> CGRect {
        CGRect(x: 10, y: listTop + CGFloat(index) * rowStep, width: frame.width - 20, height: rowHeight)
    }
}

private enum PeekTouch: Equatable {
    case idle
    case pressing(Int)
    case held(Int)
}

private func peekLerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

private struct PeekPopDemo: View {
    let ctx: DemoContext
    /// The message that is lifted (peeked or popped).
    @State private var active: Int?
    /// 0 = in its row, 1 = preview card.
    @State private var lift: CGFloat
    /// 0 = preview card, 1 = full screen.
    @State private var pop: CGFloat = 0
    /// The row a simulated (autoplay) hold is sinking.
    @State private var autoPressing: Int?
    @State private var autoStep = 0
    @State private var autoIndex = 0
    @State private var autoTask: Task<Void, Never>?
    /// The real touch: sinking a row, then holding the lifted card. Resets by itself when the gesture ends or
    /// is cancelled.
    @GestureState private var touch: PeekTouch = .idle

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the peek.
        _active = State(initialValue: ctx.isStill ? 0 : nil)
        _lift = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: 0.78) }
    private var isFull: Bool { active != nil && pop >= 1 }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                inbox
                    .scaleEffect(1 - 0.04 * min(lift, 1))
                    .blur(radius: ctx.cg("blur") * min(max(lift, 0), 1))
                Color.black
                    .opacity(0.25 * Double(min(max(lift, 0), 1)))
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .allowsHitTesting(active != nil)
                if let index = active {
                    card(index)
                }
            }
            .frame(width: PeekMetrics.frame.width, height: PeekMetrics.frame.height, alignment: .topLeading)
            .background(Palette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
            DemoHint(text: L("Hold a message, then drag up", "按住一封邮件，再向上拖"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.4) { autoplayStep() }
        .onChange(of: touch) { oldValue, newValue in
            touchChanged(from: oldValue, to: newValue)
        }
        .onDisappear {
            autoTask?.cancel()
            autoTask = nil
            autoPressing = nil
        }
    }

    // MARK: Inbox

    private var inbox: some View {
        ZStack(alignment: .topLeading) {
            HStack {
                Text(L("Inbox", "收件箱"), ctx.language)
                    .font(.title2.weight(.bold))
                Spacer(minLength: 0)
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.blue)
            }
            .padding(.horizontal, 18)
            .frame(height: 34)
            .offset(y: 14)
            ForEach(0..<peekMails.count, id: \.self) { index in
                let rect = PeekMetrics.row(index)
                let sunk: Bool = touch == .pressing(index) || autoPressing == index
                PeekRowContent(mail: peekMails[index], language: ctx.language)
                    .frame(width: rect.width, height: rect.height)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
                    .scaleEffect(sunk ? 0.96 : 1)
                    .animation(sunk ? .easeOut(duration: ctx["hold"]) : .spring(response: 0.3, dampingFraction: 0.7), value: sunk)
                    .opacity(active == index ? 0 : 1)
                    .gesture(holdAndDrag(index))
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: PeekMetrics.frame.width, height: PeekMetrics.frame.height, alignment: .topLeading)
    }

    // MARK: Card

    private func card(_ index: Int) -> some View {
        let row = PeekMetrics.row(index)
        let peek = PeekMetrics.peek
        let l: CGFloat = lift
        let p: CGFloat = max(pop, 0)
        let x: CGFloat = peekLerp(peekLerp(row.minX, peek.minX, l), 0, p)
        let y: CGFloat = peekLerp(peekLerp(row.minY, peek.minY, l), 0, p)
        let width: CGFloat = peekLerp(peekLerp(row.width, peek.width, l), PeekMetrics.frame.width, p)
        let height: CGFloat = peekLerp(peekLerp(row.height, peek.height, l), PeekMetrics.frame.height, p)
        let radius: CGFloat = peekLerp(peekLerp(16, 24, l), 34, min(p, 1))
        return PeekCard(
            mail: peekMails[index],
            language: ctx.language,
            lift: min(max(l, 0), 1),
            pop: min(p, 1),
            onBack: { close() }
        )
        .frame(width: max(width, 40), height: max(height, 40), alignment: .topLeading)
        .background(Palette.elevated)
        .overlay(alignment: .bottom) {
            PeekHint(visible: min(max(l, 0), 1) * max(1 - p * 4, 0))
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: Color.black.opacity(0.3 * Double(min(max(l, 0), 1))), radius: 24, y: 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isFull { popFull() }
        }
        .gesture(
            PageSafePan(
                directions: [.up, .down],
                isEnabled: !isFull,
                onChanged: { cardDragChanged($0.height) },
                onEnded: { cardDragEnded(translation: $0?.translation.height ?? 0, velocity: $0?.velocity.height ?? 0) }
            )
        )
        .offset(x: x, y: y)
    }

    // MARK: Hold, then drag (one touch)

    private func holdAndDrag(_ index: Int) -> some Gesture {
        LongPressGesture(minimumDuration: ctx["hold"], maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($touch) { value, state, _ in
                switch value {
                case .first(true): state = .pressing(index)
                case .second(true, _): state = .held(index)
                default: break
                }
            }
            .onChanged { value in
                guard case .second(true, let drag) = value, let drag else { return }
                if active == nil { peek(index) }
                cardDragChanged(drag.translation.height)
            }
            .onEnded { value in
                guard case .second(true, let drag) = value, let drag else { return }
                if pop > 0.02 || drag.translation.height > 30 {
                    cardDragEnded(translation: drag.translation.height, velocity: drag.velocity.height)
                }
            }
    }

    /// The hold completing lifts the row even if the finger never moves; the finger leaving a card that was
    /// only peeked (not dragged) lets it go.
    private func touchChanged(from oldValue: PeekTouch, to newValue: PeekTouch) {
        if case .held(let index) = newValue, active == nil {
            peek(index)
        }
        if newValue == .idle, case .held = oldValue, pop < 0.02, lift > 0.98 {
            released()
        }
    }

    /// The finger lifted while peeking without a drag: stay, or drop back, depending on the parameter.
    private func released() {
        guard active != nil, !isFull else { return }
        if !ctx.bool("sticky") { close() }
    }

    private func cardDragChanged(_ dy: CGFloat) {
        guard active != nil, !isFull else { return }
        if dy <= 0 {
            let raw: CGFloat = -dy / PeekMetrics.popTravel
            pop = raw <= 1 ? raw : 1 + rubberBand(raw - 1, limit: 0.12)
            lift = 1
        } else {
            pop = 0
            lift = 1 - min(dy / 260, 0.35)
        }
    }

    private func cardDragEnded(translation: CGFloat, velocity: CGFloat) {
        guard active != nil, !isFull else { return }
        if pop > 0.45 || velocity < -600 {
            popFull()
        } else if translation > 50 || velocity > 600 {
            close()
        } else {
            withAnimation(spring) {
                pop = 0
                lift = 1
            }
            released()
        }
    }

    // MARK: Transitions

    private func peek(_ index: Int, silent: Bool = false) {
        guard active == nil else { return }
        if !ctx.isPreview && !silent { Haptics.tap(.medium) }
        active = index
        pop = 0
        withAnimation(spring) { lift = 1 }
    }

    private func popFull() {
        guard active != nil else { return }
        if !ctx.isPreview { Haptics.tap(.heavy) }
        withAnimation(.spring(response: ctx["response"] * 0.9, dampingFraction: 0.84)) {
            pop = 1
            lift = 1
        }
    }

    private func close() {
        guard active != nil else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.86)) {
            pop = 0
            lift = 0
        } completion: {
            if lift == 0 { active = nil }
        }
    }

    // MARK: Autoplay

    /// Preview loop: a simulated hold lifts the next message, a simulated drag pops it, then it closes.
    private func autoplayStep() {
        let phase = autoStep % 3
        autoStep += 1
        switch phase {
        case 0:
            if active != nil {
                // The still (or a previous run) left a card up: start the loop from a closed list.
                close()
                autoStep = 0
                return
            }
            autoPress()
        case 1:
            guard active != nil else { return }
            withAnimation(.easeInOut(duration: 0.3)) { pop = 0.5 } completion: {
                if active != nil { popFull() }
            }
        default:
            close()
        }
    }

    private func autoPress() {
        guard autoPressing == nil, active == nil else { return }
        let index = autoIndex % peekMails.count
        autoIndex += 1
        let hold: Double = ctx["hold"]
        autoPressing = index
        autoTask?.cancel()
        autoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            autoPressing = nil
            peek(index, silent: true)
        }
    }
}

// MARK: - Pieces

private struct PeekRowContent: View {
    let mail: PeekMail
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: mail.initial)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(mail.color.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(mail.sender, language)
                    .font(.subheadline.weight(.semibold))
                Text(mail.subject, language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            Text(mail.time, language)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
    }
}

/// The lifted message. The sender line is the row's own layout, so at `lift == 0` it coincides with the row.
private struct PeekCard: View {
    let mail: PeekMail
    let language: AppLanguage
    let lift: CGFloat
    let pop: CGFloat
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBar
                .frame(height: 44 * pop, alignment: .bottom)
                .opacity(Double(pop))
                .clipped()
            PeekRowContent(mail: mail, language: language)
                .frame(height: PeekMetrics.rowHeight)
            VStack(alignment: .leading, spacing: 10) {
                Text(mail.message, language)
                    .font(.footnote)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                art
                PlaceholderLines(count: 4, color: Color.primary.opacity(0.1))
                    .opacity(Double(pop))
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .opacity(Double(lift))
        }
    }

    private var navigationBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text(L("Inbox", "收件箱"), language)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Palette.blue)
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.blue)
        }
        .padding(.horizontal, 14)
    }

    private var art: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: mail.art, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 64 + 36 * pop)
            .overlay {
                Image(systemName: mail.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
    }
}

/// "Drag up" affordance at the foot of the peek; gone as soon as the pop begins.
private struct PeekHint: View {
    let visible: CGFloat
    @State private var breathing = false
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        Image(systemName: "chevron.compact.up")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.45))
            .offset(y: breathing ? -3 : 1)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                LinearGradient(colors: [Palette.elevated.opacity(0), Palette.elevated], startPoint: .top, endPoint: .center)
            )
            .opacity(Double(visible))
            .allowsHitTesting(false)
            .onAppear {
                guard !isStill else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { breathing = true }
            }
    }
}
