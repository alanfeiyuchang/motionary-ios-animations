import SwiftUI

// MARK: - Payment done

extension Effect {
    static let feedbackPaymentDone = Effect(
        id: "feedback.payment-done",
        category: .feedback,
        interaction: .tap,
        name: L("Payment Done", "支付完成"),
        summary: L("A spinning arc closes into a ring, a check is stroked in and a soft bloom breathes out behind it.", "旋转的弧线闭合成圆环，对勾写入，背后绽开一圈柔光。"),
        prompt: L(
            "A payment sheet shows a small card, the merchant and amount, and a 72 pt indicator. On tap a 5 pt blue arc spins at 1.4 turns per second on a faint track, its length breathing between 18% and 34% of the circle. After 0.9 s the arc keeps turning while its tail runs ahead and closes the ring in 0.35 s with a cubic ease-out and a light haptic. The closed ring pulses to 110% and back on a spring (response 0.35 s, damping 0.5), a blurred blue bloom swells from 70% to 190% while fading over 0.6 s, and the check is stroked in 0.28 s, short leg first, ending on a success haptic. The card nods 14° toward the viewer and 'Done' rises 10 pt out of a blur. Quiet, certain, unmistakably finished.",
            "支付面板上是一张小卡片、商户与金额，以及 72 pt 的指示器。点击后，5 pt 蓝色弧线在淡色轨道上以每秒 1.4 圈旋转，弧长在圆周的 18% 到 34% 之间呼吸。0.9 秒后弧线继续转动，尾端向前追上，用 0.35 秒三次缓出把圆环闭合，伴随轻触感。闭合的圆环以弹簧（响应 0.35 秒、阻尼 0.5）鼓到 110% 再回落，背后模糊的蓝色光晕从 70% 扩到 190% 并在 0.6 秒内淡出，对勾 0.28 秒写出，以成功触感收尾。卡片朝观者点头 14°，“完成”从下方 10 pt 带模糊升起。安静、笃定。"
        ),
        implementation: L(
            "A TimelineView computes the arc's rotation and trim from the time since the tap and since the close began, so the spinner flows into the closed ring without a hand-off; the check is a trimmed Shape, and keyframeAnimators keyed on a counter run the ring pulse, the bloom and the card's nod.",
            "TimelineView 按“点击后经过的时间”和“开始闭合后经过的时间”计算弧线的旋转与 trim，于是加载弧线直接流动成闭合圆环，没有切换的断点；对勾是 trim 的 Shape，以计数器为触发器的 keyframeAnimator 驱动圆环脉冲、光晕与卡片点头。"
        ),
        apis: ["TimelineView(.animation)", "trim(from:to:)", "keyframeAnimator(initialValue:trigger:)", "rotation3DEffect(_:axis:perspective:)", "blur(radius:)"],
        tags: ["payment", "success", "apple pay", "checkmark", "支付", "成功", "对勾", "完成"],
        params: [
            .slider("processing", L("Processing time", "处理时长"), 0.4...2.5, default: 0.9, decimals: 1, unit: "s"),
            .slider("draw", L("Check draw time", "对勾绘制时长"), 0.15...0.6, default: 0.28, unit: "s"),
            .slider("bloom", L("Bloom strength", "光晕强度"), 0...1, default: 0.6),
        ]
    ) { ctx in
        PaymentDoneDemo(ctx: ctx)
    }
}

private enum PaymentDonePhase {
    case idle
    case processing
    case closing
    case done
}

private struct PaymentDoneDemo: View {
    let ctx: DemoContext
    @State private var phase: PaymentDonePhase
    @State private var spinStart = Date.distantPast
    @State private var closeStart = Date.distantPast
    @State private var completions = 0
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the finished state.
        _phase = State(initialValue: ctx.isStill ? .done : .idle)
    }

    private static let blue = Color(hex: 0x0A84FF)

    var body: some View {
        let zh = ctx.language == .zh
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                miniCard
                    .padding(.top, 26)
                Text(zh ? "街角咖啡" : "Corner Café")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                Text(zh ? "¥58.00" : "$8.50")
                    .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                    .padding(.top, 1)
                indicator
                    .frame(width: 72, height: 72)
                    .padding(.top, 18)
                caption(zh: zh)
                    .frame(height: 22)
                    .padding(.top, 12)
                Spacer(minLength: 0)
            }
            .frame(width: 280, height: 300)
            .demoCard(cornerRadius: 30)
            .contentShape(Rectangle())
            .onTapGesture { pay() }
            DemoHint(text: L("Tap to pay", "点击付款"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["processing"] + 3.6, delay: 0.5) { pay() }
    }

    // MARK: Card

    private var miniCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2E3A59), Color(hex: 0x0E1220)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFFE39A), Color(hex: 0xD9A441)], startPoint: .top, endPoint: .bottom))
                .frame(width: 17, height: 13)
                .padding(.leading, 10)
                .padding(.top, 12)
            Text(verbatim: "•••• 4821")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 10)
                .padding(.bottom, 8)
        }
        .frame(width: 104, height: 66)
        .shadow(color: .black.opacity(0.22), radius: 8, y: 5)
        .keyframeAnimator(initialValue: 0.0, trigger: completions) { content, nod in
            content.rotation3DEffect(.degrees(nod), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(-14.0, duration: 0.16)
                SpringKeyframe(0.0, duration: 0.6, spring: .bouncy)
            }
        }
    }

    // MARK: Indicator

    private var indicator: some View {
        let done: Bool = phase == .done
        let running: Bool = phase == .processing || phase == .closing
        let bloom: Double = ctx["bloom"]
        return ZStack {
            Circle()
                .fill(Self.blue)
                .blur(radius: 16)
                .keyframeAnimator(initialValue: PaymentBloom(), trigger: completions) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .opacity(value.opacity * bloom)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(0.7)
                        CubicKeyframe(1.9, duration: 0.6)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0.9)
                        LinearKeyframe(0, duration: 0.6, timingCurve: .easeOut)
                    }
                }
            Circle()
                .stroke(Color.primary.opacity(0.09), lineWidth: 5)
                .opacity(done ? 0 : 1)
            Image(systemName: "wave.3.right")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Self.blue)
                .phaseAnimator([false, true]) { content, dim in
                    content.opacity(dim ? 0.45 : 1)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
                .scaleEffect(phase == .idle ? 1 : 0.4)
                .opacity(phase == .idle ? 1 : 0)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !running)) { timeline in
                PaymentArc(
                    now: timeline.date,
                    spinStart: spinStart,
                    closeStart: phase == .closing ? closeStart : nil,
                    full: done,
                    color: Self.blue
                )
            }
            .opacity(phase == .idle ? 0 : 1)
            PaymentCheck()
                .trim(from: 0, to: done ? 1 : 0)
                .stroke(Self.blue, style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
                .frame(width: 30, height: 23)
                .animation(done ? Animation.easeOut(duration: ctx["draw"]).delay(0.04) : Animation.linear(duration: 0.08), value: done)
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: completions) { content, pulse in
            content.scaleEffect(pulse)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.1, duration: 0.12)
                SpringKeyframe(1, duration: 0.5, spring: Spring(response: 0.35, dampingRatio: 0.5))
            }
        }
        .animation(.easeOut(duration: 0.2), value: phase == .idle)
    }

    @ViewBuilder
    private func caption(zh: Bool) -> some View {
        ZStack {
            switch phase {
            case .idle:
                Text(zh ? "轻点付款" : "Tap to Pay")
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            case .processing, .closing:
                Text(zh ? "处理中" : "Processing")
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            case .done:
                Text(zh ? "完成" : "Done")
                    .foregroundStyle(Self.blue)
                    .transition(.offset(y: 10).combined(with: .opacity).combined(with: PaymentBlurTransition.transition))
            }
        }
        .font(.headline)
    }

    // MARK: Sequence

    private func pay() {
        switch phase {
        case .processing, .closing:
            return
        case .done:
            token += 1
            withAnimation(.smooth(duration: 0.3)) { phase = .idle }
            return
        case .idle:
            break
        }
        token += 1
        let current = token
        let live: Bool = !ctx.isPreview
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = live && !Haptics.isMuted
        let processing: Double = ctx["processing"]
        let draw: Double = ctx["draw"]
        if buzz { Haptics.tap() }
        spinStart = Date()
        withAnimation(.easeOut(duration: 0.2)) { phase = .processing }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(processing))
            guard token == current else { return }
            closeStart = Date()
            withAnimation(.easeOut(duration: 0.2)) { phase = .closing }
            if buzz { Haptics.tap(.light) }
            try? await Task.sleep(for: .seconds(PaymentArc.closeDuration))
            guard token == current else { return }
            completions += 1
            withAnimation(.easeOut(duration: 0.3).delay(0.12)) { phase = .done }
            try? await Task.sleep(for: .seconds(draw + 0.04))
            guard token == current else { return }
            if buzz { Haptics.success() }
            guard !live else { return }
            try? await Task.sleep(for: .seconds(2.0))
            guard token == current else { return }
            withAnimation(.smooth(duration: 0.3)) { phase = .idle }
        }
    }
}

private struct PaymentBloom {
    var scale: CGFloat = 1.9
    var opacity: Double = 0
}

/// Blur that a transition can remove; `.blurReplace` would also scale the text.
private struct PaymentBlurTransition: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }

    static var transition: AnyTransition {
        .modifier(active: PaymentBlurTransition(radius: 5), identity: PaymentBlurTransition(radius: 0))
    }
}

private struct PaymentCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// The spinner arc: spins on the time since `spinStart`; once `closeStart` is set its tail runs ahead until
/// the ring is whole.
private struct PaymentArc: View {
    let now: Date
    let spinStart: Date
    let closeStart: Date?
    let full: Bool
    let color: Color

    static let closeDuration: Double = 0.35
    static let turnsPerSecond: Double = 1.4

    var body: some View {
        let elapsed: Double = max(now.timeIntervalSince(spinStart), 0)
        // The arc's length breathes between 18% and 34% of the circle.
        let breathing: Double = 0.26 + 0.08 * sin(elapsed * 4.2)
        // Fades the arc in from a dot over the first 0.25 s.
        let grow: Double = min(elapsed / 0.25, 1)
        let sweep: Double = full ? 1 : closing(from: breathing * grow)
        Circle()
            .trim(from: 0, to: CGFloat(sweep))
            .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .rotationEffect(.degrees(elapsed * Self.turnsPerSecond * 360 - 90))
    }

    private func closing(from length: Double) -> Double {
        guard let closeStart else { return length }
        let u: Double = min(max(now.timeIntervalSince(closeStart) / Self.closeDuration, 0), 1)
        let eased: Double = 1 - pow(1 - u, 3)
        return length + (1 - length) * eased
    }
}
