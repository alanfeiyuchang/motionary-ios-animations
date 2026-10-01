import SwiftUI

// MARK: - Sticker slap

extension Effect {
    static let feedbackStickerSlap = Effect(
        id: "feedback.sticker-slap",
        category: .feedback,
        interaction: .tap,
        name: L("Sticker Slap", "拍上贴纸"),
        summary: L("A die-cut 'PAID' sticker is slapped onto an invoice: it accelerates in, lands askew with a wobble, kicks up a dust ring and the card flinches.", "一枚模切“已付款”贴纸被拍到账单上：加速落下，歪着贴住并晃一下，扬起一圈灰尘，卡片随之一沉。"),
        prompt: L(
            "An invoice card with a total and a 'Mark as paid' button. On tap a green die-cut sticker with a white 5 pt border falls onto it: it starts at 260% scale, 14° further rotated and sheared −0.25, and accelerates to 100% on a 0.17 s ease-in while fading in. At impact it squashes to 93% and rebounds just past 100% on a spring (response 0.3 s, damping 0.5) while its shear flicks to +0.1 and settles, leaving it resting at −12°. The card dips to 96.5% and springs back; fourteen grey dust puffs and a thin ring burst outward along an ellipse and fade in 0.55 s; a gloss band sweeps across the sticker 200 ms later. A rigid haptic marks the hit, and the due chip turns green. Emphatic, physical, satisfying.",
            "账单卡片上有总额和“标记为已付款”按钮。点击后，一枚带 5 pt 白边的绿色模切贴纸拍上来：起始 260% 大小、多转 14°、错切 −0.25，以 0.17 秒缓入加速落到 100% 并淡入。触面瞬间压到 93%，以弹簧（响应 0.3 秒、阻尼 0.5）回弹略过 100%，错切甩到 +0.1 再归零，停在 −12°。卡片下沉到 96.5% 后弹回；十四团灰色尘雾和一道细环沿椭圆向外迸开，0.55 秒内淡出；200 毫秒后一道高光扫过贴纸。拍中时有一次硬朗触感，到期标签变为绿色。干脆、有分量、解压。"
        ),
        implementation: L(
            "The approach is an ease-in on scale, rotation and a shear GeometryEffect; at the moment of contact a keyframeAnimator adds the squash and shear wobble and a second one dips the card. The dust is a Canvas driven by a TimelineView clock that measures the time since impact.",
            "落下阶段是缩放、旋转与错切 GeometryEffect 上的缓入动画；触面瞬间由 keyframeAnimator 叠加压扁与错切的晃动，另一个 keyframeAnimator 让卡片下沉。尘雾是由 TimelineView 时钟驱动的 Canvas，按拍中后经过的时间绘制。"
        ),
        apis: ["keyframeAnimator(initialValue:trigger:)", "GeometryEffect", "Canvas", "TimelineView(.animation(minimumInterval:paused:))", "rotationEffect"],
        tags: ["sticker", "stamp", "paid", "impact", "dust", "贴纸", "盖章", "已付款", "冲击", "灰尘"],
        params: [
            .slider("drop", L("Drop scale", "起始缩放"), 1.5...4.0, default: 2.6, decimals: 1, unit: "×"),
            .slider("angle", L("Resting angle", "停留角度"), -20...20, default: -12, decimals: 0, unit: "°"),
            .slider("squash", L("Impact squash", "触面压扁"), 0.0...0.16, default: 0.07),
            .slider("dust", L("Dust puffs", "尘雾数量"), 6...24, default: 14, step: 1, decimals: 0),
        ]
    ) { ctx in
        StickerSlapDemo(ctx: ctx)
    }
}

private enum StickerState {
    /// Above the card, about to fall.
    case raised
    case stuck
    /// Lifted off again.
    case peeled
}

private struct StickerWobble {
    var scale: CGFloat = 1
    var shear: CGFloat = 0
}

private struct StickerSlapDemo: View {
    let ctx: DemoContext
    @State private var state: StickerState
    @State private var impacts = 0
    @State private var impactTime: Date?
    @State private var shine = false
    @State private var busy = false
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the sticker on the invoice.
        _state = State(initialValue: ctx.isStill ? .stuck : .raised)
    }

    private var zh: Bool { ctx.language == .zh }
    private var paid: Bool { state == .stuck }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                invoice
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: impacts) { content, dip in
                        content.scaleEffect(dip)
                    } keyframes: { _ in
                        KeyframeTrack(\.self) {
                            CubicKeyframe(0.965, duration: 0.06)
                            SpringKeyframe(1, duration: 0.45, spring: Spring(response: 0.32, dampingRatio: 0.5))
                        }
                    }
                StickerDust(start: impactTime, count: max(ctx.int("dust"), 1), preview: ctx.isPreview)
                    .frame(width: 300, height: 220)
                    .offset(x: 34, y: -4)
                sticker
                    .offset(x: 34, y: -4)
            }
            .frame(width: 300, height: 220)
            button
            DemoHint(text: L("Tap the button", "点击按钮"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.3, delay: 0.6) { toggle() }
    }

    // MARK: Invoice

    private var invoice: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(zh ? "账单 #2048" : "Invoice #2048")
                        .font(.subheadline.weight(.semibold))
                    Text(zh ? "北岸设计工作室" : "Northshore Studio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(paid ? (zh ? "已结清" : "Settled") : (zh ? "10月12日到期" : "Due Oct 12"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(paid ? Palette.green : Color(hex: 0xC27A00))
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background((paid ? Palette.green : Palette.amber).opacity(0.16), in: Capsule())
                    .contentTransition(.opacity)
            }
            .padding(.bottom, 14)
            line(zh ? "品牌设计" : "Brand design", zh ? "¥6,400" : "$960")
            line(zh ? "动效规范" : "Motion guidelines", zh ? "¥2,200" : "$320")
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 10)
            HStack(alignment: .firstTextBaseline) {
                Text(zh ? "合计" : "Total")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(zh ? "¥8,600.00" : "$1,280.00")
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
            }
        }
        .padding(18)
        .frame(width: 264, height: 190)
        .demoCard(cornerRadius: 24)
    }

    private func line(_ title: String, _ amount: String) -> some View {
        HStack {
            Text(verbatim: title)
            Spacer(minLength: 0)
            Text(verbatim: amount).monospacedDigit()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(height: 24)
    }

    // MARK: Sticker

    private var sticker: some View {
        let rest: Double = ctx["angle"]
        let scale: CGFloat
        let angle: Double
        let shear: CGFloat
        let opacity: Double
        switch state {
        case .raised:
            scale = ctx.cg("drop")
            angle = rest - 14
            shear = -0.25
            opacity = 0
        case .stuck:
            scale = 1
            angle = rest
            shear = 0
            opacity = 1
        case .peeled:
            scale = 1.3
            angle = rest + 9
            shear = 0.12
            opacity = 0
        }
        return StickerFace(text: zh ? "已付款" : "PAID", shine: shine)
            .keyframeAnimator(initialValue: StickerWobble(), trigger: impacts) { content, wobble in
                content
                    .scaleEffect(wobble.scale)
                    .modifier(StickerShear(amount: wobble.shear))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1 - ctx.cg("squash"), duration: 0.05)
                    SpringKeyframe(1, duration: 0.5, spring: Spring(response: 0.3, dampingRatio: 0.5))
                }
                KeyframeTrack(\.shear) {
                    CubicKeyframe(0.1, duration: 0.07)
                    SpringKeyframe(0, duration: 0.48, spring: Spring(response: 0.3, dampingRatio: 0.45))
                }
            }
            .modifier(StickerShear(amount: shear))
            .scaleEffect(scale)
            .rotationEffect(.degrees(angle))
            .opacity(opacity)
            .allowsHitTesting(false)
    }

    private var button: some View {
        Button(action: toggle) {
            Text(paid ? (zh ? "撕下贴纸" : "Peel it off") : (zh ? "标记为已付款" : "Mark as paid"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(paid ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.white))
                .frame(width: 190, height: 42)
                .background {
                    if paid {
                        Capsule().fill(Color.primary.opacity(0.09))
                    } else {
                        Capsule().fill(Palette.primaryStrong)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Sequence

    private func toggle() {
        guard !busy else { return }
        if state == .stuck { peel() } else { slap() }
    }

    private func slap() {
        token += 1
        let current = token
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        busy = true
        shine = false
        // Jump back above the card without animating, then fall.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { state = .raised }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.03))
            guard token == current else { return }
            withAnimation(.easeIn(duration: 0.17)) { state = .stuck }
            try? await Task.sleep(for: .seconds(0.16))
            guard token == current else { return }
            impacts += 1
            impactTime = Date()
            if buzz { Haptics.tap(.rigid) }
            try? await Task.sleep(for: .seconds(0.2))
            guard token == current else { return }
            withAnimation(.easeInOut(duration: 0.55)) { shine = true }
            busy = false
            try? await Task.sleep(for: .seconds(0.6))
            guard token == current else { return }
            impactTime = nil
        }
    }

    private func peel() {
        token += 1
        impactTime = nil
        Haptics.tap()
        withAnimation(.easeIn(duration: 0.22)) { state = .peeled }
    }
}

/// A horizontal shear about the view's centre that animates (a plain `transformEffect` does not interpolate).
private struct StickerShear: GeometryEffect {
    var amount: CGFloat

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(a: 1, b: 0, c: amount, d: 1, tx: -amount * size.height / 2, ty: 0))
    }
}

/// A die-cut sticker: bold label on green, white border, soft gloss and a sweeping highlight.
private struct StickerFace: View {
    let text: String
    let shine: Bool

    var body: some View {
        let inner = RoundedRectangle(cornerRadius: 13, style: .continuous)
        let outer = RoundedRectangle(cornerRadius: 17, style: .continuous)
        HStack(spacing: 7) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .bold))
            Text(verbatim: text)
                .font(.system(size: 27, weight: .black, design: .rounded))
                .kerning(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .frame(height: 52)
        .background {
            inner.fill(LinearGradient(colors: [Color(hex: 0x3DDC84), Color(hex: 0x12924B)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            inner.fill(LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0)], startPoint: .top, endPoint: .center))
        }
        .overlay {
            GeometryReader { proxy in
                LinearGradient(colors: [.clear, Color.white.opacity(0.65), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 46)
                    .rotationEffect(.degrees(18))
                    .offset(x: shine ? proxy.size.width + 30 : -76)
            }
            .clipShape(inner)
        }
        .padding(5)
        .background(outer.fill(Color.white))
        .overlay(outer.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
    }
}

/// Dust kicked out from under the sticker at impact: puffs and a thin ring spreading along an ellipse.
private struct StickerDust: View {
    let start: Date?
    let count: Int
    let preview: Bool

    private static let life: Double = 0.55

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: start == nil)) { timeline in
            let elapsed: Double = start.map { timeline.date.timeIntervalSince($0) } ?? -1
            let t: Double = elapsed / Self.life
            Canvas { context, size in
                guard t > 0, t < 1 else { return }
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let eased: Double = 1 - pow(1 - t, 3)
                let fade: Double = (1 - t) * (1 - t)
                let ringX: CGFloat = 78 + 34 * CGFloat(eased)
                let ringY: CGFloat = 36 + 22 * CGFloat(eased)
                let ring = Path(ellipseIn: CGRect(x: centre.x - ringX, y: centre.y - ringY, width: ringX * 2, height: ringY * 2))
                context.stroke(ring, with: .color(Color.gray.opacity(0.5 * fade)), lineWidth: 1.5 * CGFloat(1 - t) + 0.3)
                for index in 0..<count {
                    let seed: Double = abs(sin(Double(index) * 12.9898))
                    let angle: Double = (Double(index) + seed * 0.6) / Double(count) * 2 * .pi
                    let reach: Double = 16 + 30 * seed
                    let x: CGFloat = centre.x + CGFloat(cos(angle)) * (74 + CGFloat(reach * eased))
                    let y: CGFloat = centre.y + CGFloat(sin(angle)) * (34 + CGFloat(reach * eased) * 0.6)
                    let radius: CGFloat = 3 + CGFloat(5 + 5 * seed) * CGFloat(eased)
                    let puff = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    context.fill(puff, with: .color(Color.gray.opacity(0.42 * fade)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
