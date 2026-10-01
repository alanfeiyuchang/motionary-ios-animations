import SwiftUI

extension Effect {
    static let cardsSplitReveal = Effect(
        id: "cards.split-reveal",
        category: .cards,
        interaction: .tap,
        name: L("Split Reveal", "裂开揭示"),
        summary: L("A boarding pass parts along its perforation: the two halves lift away from each other and the details appear in the gap.", "登机牌沿着齿孔线裂开：上下两半彼此分离抬起，详情出现在中间的缝隙里。"),
        prompt: L(
            "A 252×124 pt boarding pass with a dashed perforation and two side notches across its middle. On tap it parts along that line: the halves move 56 pt up and down on one spring (response 0.46 s, damping 0.7), overshooting a few points, while each tips 5° about its outer edge so the cut edges rise toward the viewer and their shadows deepen. Between them a recessed panel is uncovered, shaded along both cut edges, and three detail rows come up from 8 pt below, each fading in over its own slice of the opening so they arrive top to bottom. A second tap reverses it: rows go first, the halves clap shut, the whole pass squashes to 97% and rebounds, and a rigid haptic marks the join. Dragging either half vertically scrubs the gap with rubber-banded limits.",
            "一张252×124 pt的登机牌，中间横着一道虚线齿孔和两侧的半圆缺口。点击后它沿这条线裂开：上下两半以同一条弹簧（响应0.46秒、阻尼0.7）各移动56 pt，略微过冲，同时各绕外侧边倾斜5°，切口朝观看者翘起，投影加深。两半之间露出一块下沉的面板，贴着切口处有阴影；三行详情从下方8 pt处升起，各在开合过程的不同区段淡入，自上而下依次出现。再次点击反向进行：详情先消失，两半合拢，整张登机牌压到97%再回弹，伴随一记清脆触感。上下拖动任意一半可直接调节缝隙，两端有橡皮筋阻力。"
        ),
        implementation: L(
            "The pass is drawn once and shown through two masks, one per half; each half is offset by half the gap and tilted with projectionEffect about its outer edge. The detail rows derive opacity and offset from the gap itself, so they follow the spring and the drag alike.",
            "登机牌只绘制一次，通过上下两个遮罩分别显示；每一半偏移半个缝隙，并用 projectionEffect 绕外侧边倾斜。详情行的透明度和偏移直接由缝隙大小推导，因此既跟随弹簧，也跟随拖动。"
        ),
        apis: ["mask", "projectionEffect", "Animatable", "DragGesture", "keyframeAnimator", "spring(response:dampingFraction:)"],
        tags: ["split", "reveal", "boarding pass", "perforation", "裂开", "分离", "登机牌", "展开详情"],
        params: [
            .slider("gap", L("Opening", "开口大小"), 80...140, default: 112, step: 1, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.8, default: 0.46, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.7),
            .slider("tilt", L("Half tilt", "半片倾斜"), 0...12, default: 5, step: 0.5, decimals: 1, unit: "°"),
        ]
    ) { ctx in
        CardsSplitDemo(ctx: ctx)
    }
}

private enum CardsSplitLayout {
    static let size = CGSize(width: 252, height: 124)
    static let half: CGFloat = 62
    static let notch: CGFloat = 9
}

private struct CardsSplitDemo: View {
    let ctx: DemoContext
    /// 0 closed, 1 fully open.
    @State private var amount: CGFloat
    @State private var isOpen: Bool
    @State private var claps = 0
    @State private var dragStart: CGFloat?
    @State private var dragSign: CGFloat = 1
    @State private var clap: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _amount = State(initialValue: ctx.isStill ? 1 : 0)
        _isOpen = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 12) {
            CardsSplitPass(amount: amount, gap: ctx.cg("gap"), tilt: ctx.cg("tilt"), language: ctx.language)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: claps) { content, squash in
                    content.scaleEffect(x: 2 - squash, y: squash)
                } keyframes: { _ in
                    CubicKeyframe(0.97, duration: 0.06)
                    SpringKeyframe(1, duration: 0.4, spring: Spring(response: 0.24, dampingRatio: 0.5))
                }
                .frame(width: CardsSplitLayout.size.width, height: 262)
                .contentShape(Rectangle())
                .gesture(drag)
            DemoHint(text: L("Tap the pass, or pull the halves apart", "点击登机牌，或把两半拉开"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { set(!isOpen, haptic: false) }
        .onChange(of: pressing) { _, isPressing in
            guard !isPressing else { return }
            // onEnded can arrive just after the gesture state resets, so this fallback waits a tick:
            // by then only a cancelled touch still has something to clean up.
            Task { @MainActor in
                if dragStart != nil {
                    dragStart = nil
                    set(amount > 0.5, haptic: true)
                }
            }
        }
        .onDisappear { clap?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if dragStart == nil {
                    dragStart = amount
                    clap?.cancel()
                    // Pull the top half up or the bottom half down.
                    dragSign = value.startLocation.y < 131 ? -1 : 1
                }
                guard let start = dragStart, abs(value.translation.height) > 4 else { return }
                let travel = ctx.cg("gap") / 2
                let raw = start + dragSign * value.translation.height / travel
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { amount = banded(raw, travel: travel) }
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                if hypot(value.translation.width, value.translation.height) < 8 {
                    set(!isOpen, haptic: true)
                    return
                }
                let projected = start + dragSign * value.predictedEndTranslation.height / (ctx.cg("gap") / 2)
                set(projected > 0.5, haptic: true)
            }
    }

    private func banded(_ value: CGFloat, travel: CGFloat) -> CGFloat {
        if value < 0 { return rubberBand(value * travel, limit: 24) / travel }
        if value > 1 { return 1 + rubberBand((value - 1) * travel, limit: 24) / travel }
        return value
    }

    private func set(_ open: Bool, haptic: Bool) {
        let response = ctx["response"]
        let buzz = haptic && !ctx.isPreview
        let wasApart = amount > 0.2
        isOpen = open
        withAnimation(.spring(response: response, dampingFraction: ctx["damping"])) {
            amount = open ? 1 : 0
        }
        clap?.cancel()
        if open {
            if buzz { Haptics.tap(.light) }
            return
        }
        guard wasApart else { return }
        clap = Task { @MainActor in
            // The halves meet a little after half the spring's response.
            try? await Task.sleep(for: .seconds(response * 0.6))
            guard !Task.isCancelled else { return }
            claps += 1
            if buzz { Haptics.tap(.rigid) }
        }
    }
}

/// The pass with its two halves `amount` apart. Animatable so the rows can follow the spring's overshoot.
private struct CardsSplitPass: View, Animatable {
    var amount: CGFloat
    let gap: CGFloat
    let tilt: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    private var size: CGSize { CardsSplitLayout.size }

    var body: some View {
        let open = gap * amount
        let lift = amount.clamped(to: 0...1.2)
        ZStack {
            panel(open: open, lift: lift)
            half(top: true, open: open, lift: lift)
            half(top: false, open: open, lift: lift)
        }
        .frame(width: size.width, height: size.height + gap + 20)
    }

    private func half(top: Bool, open: CGFloat, lift: CGFloat) -> some View {
        let angle = tilt * .pi / 180 * lift
        // Each half hinges on its outer edge, so the cut edge comes toward the viewer.
        let plane: CardsPlane3D = top
            ? .hingeX(lineY: 0, angle: angle)
            : .hingeX(lineY: size.height, angle: -angle)
        return CardsSplitFace(language: language)
            .overlay(alignment: top ? .bottom : .top) {
                // The freshly cut edge catches a line of light.
                Rectangle()
                    .fill(Color.white.opacity(0.5 * Double(lift.clamped(to: 0...1))))
                    .frame(height: 1)
                    .offset(y: top ? -CardsSplitLayout.half : CardsSplitLayout.half)
            }
            .mask(alignment: top ? .top : .bottom) {
                Rectangle().frame(height: CardsSplitLayout.half)
            }
            .projectionEffect(plane.projection(eye: CGPoint(x: size.width / 2, y: size.height / 2), depth: 600))
            .shadow(color: .black.opacity(0.14 + 0.14 * Double(lift.clamped(to: 0...1))), radius: 6 + 10 * lift, y: 4 + 6 * lift)
            .offset(y: (top ? -1 : 1) * open / 2)
    }

    /// The recessed panel between the halves.
    private func panel(open: CGFloat, lift: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let height = max(open + 8, 0)
        return ZStack {
            shape.fill(Palette.surface)
            rows
            VStack {
                LinearGradient(colors: [Color.black.opacity(0.3), Color.black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 14)
                Spacer(minLength: 0)
                LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.22)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 12)
            }
        }
        .frame(width: size.width - 18, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .opacity(Double((amount * 6).clamped(to: 0...1)))
    }

    private var rows: some View {
        let items: [(String, LocalizedText, String)] = [
            ("door.left.hand.open", L("Gate", "登机口"), "B12"),
            ("clock", L("Boarding", "登机时间"), "18:40"),
            ("carseat.right.fill", L("Seat", "座位"), "14A"),
        ]
        return VStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                // Each row owns a slice of the opening: 30% → 60%, 45% → 75%, 60% → 90%.
                let shown = ((amount - 0.3 - 0.15 * CGFloat(index)) / 0.3).clamped(to: 0...1)
                HStack(spacing: 10) {
                    Image(systemName: items[index].0)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.blue)
                        .frame(width: 20)
                    Text(items[index].1, language)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(verbatim: items[index].2)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .frame(height: 30)
                .opacity(Double(shown))
                .offset(y: 8 * (1 - shown))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 100)
    }
}

/// The whole pass, drawn at full size; each half shows it through a mask.
private struct CardsSplitFace: View {
    let language: AppLanguage

    var body: some View {
        let size = CardsSplitLayout.size
        VStack(spacing: 0) {
            top
                .frame(height: CardsSplitLayout.half)
            bottom
                .frame(height: CardsSplitLayout.half)
        }
        .foregroundStyle(.white)
        .frame(width: size.width, height: size.height)
        .background {
            LinearGradient(colors: [Color(hex: 0x2BB8F5), Color(hex: 0x3A7BFF), Color(hex: 0x5B48F0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .overlay {
            Line()
                .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(height: 1)
                .padding(.horizontal, CardsSplitLayout.notch + 4)
        }
        .clipShape(CardsSplitTicket())
    }

    private var top: some View {
        HStack(alignment: .center, spacing: 10) {
            airport("SFO", L("San Francisco", "旧金山"))
            Spacer(minLength: 0)
            Image(systemName: "airplane")
                .font(.system(size: 15, weight: .semibold))
                .opacity(0.9)
            Spacer(minLength: 0)
            airport("HND", L("Tokyo", "东京"), trailing: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private var bottom: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("FLIGHT", "航班"), language)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.2)
                    .opacity(0.7)
                Text(verbatim: "ML 204")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            Spacer(minLength: 0)
            Text(L("On time", "准点"), language)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.22), in: Capsule())
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .bold))
                .opacity(0.8)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }

    private func airport(_ code: String, _ city: LocalizedText, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            Text(verbatim: code)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            Text(city, language)
                .font(.system(size: 10, weight: .medium))
                .opacity(0.8)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// A rounded ticket with a half-round notch on each side of the perforation.
private struct CardsSplitTicket: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 20
        let notch = CardsSplitLayout.notch
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notch))
        path.addArc(center: CGPoint(x: rect.maxX, y: rect.midY), radius: notch, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + notch))
        path.addArc(center: CGPoint(x: rect.minX, y: rect.midY), radius: notch, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
