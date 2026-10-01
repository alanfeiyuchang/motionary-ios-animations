import SwiftUI

// MARK: - Screenshot thumbnail

extension Effect {
    static let feedbackScreenshotThumb = Effect(
        id: "feedback.screenshot-thumb",
        category: .feedback,
        interaction: .tap,
        name: L("Screenshot Thumbnail", "截屏缩略图"),
        summary: L("The screen flashes white, a frozen copy of it shrinks into a bordered thumbnail in the corner, waits, then slides off; or you swipe it away.", "屏幕白光一闪，定格的画面缩成角落里带白边的缩略图，停留片刻后滑走；也可以亲手把它划走。"),
        prompt: L(
            "A weather screen inside a phone frame. Capturing flashes a white layer at 85% opacity that fades over 0.35 s. Under the flash a frozen copy of the screen appears and, 80 ms later, shrinks toward the bottom-left corner on a spring (response 0.5 s, damping 0.82) to 30% size with a 12 pt margin. As it shrinks it gains a white border that reads 3 pt at its final size, its corners settle at 10 pt and a soft shadow lifts it off the live screen, which keeps moving behind it. After a 1.8 s hold it slides off the left edge on a 0.3 s ease-in. Dragging the thumbnail left follows the finger and, past 40 pt or with a flick, throws it out; otherwise it springs back and the hold restarts. A medium haptic fires with the flash.",
            "手机边框里是一屏天气界面。截屏时，一层 85% 不透明度的白光闪现并在 0.35 秒内淡出。白光之下出现一份定格的屏幕副本，80 毫秒后以弹簧（响应 0.5 秒、阻尼 0.82）向左下角缩小到 30%，四周留出 12 pt 边距。缩小过程中它长出白色描边（最终尺寸下约 3 pt），圆角收到 10 pt，柔和的阴影把它托离仍在活动的屏幕。停留 1.8 秒后，它以 0.3 秒缓入从左侧滑出。向左拖动缩略图时它跟手移动，超过 40 pt 或快速一甩就被甩出，否则弹回原位并重新计时。白光闪现的同时有一次中等力度的触感。"
        ),
        implementation: L(
            "The frozen copy is a second instance of the screen whose clock is stopped, wrapped in an Animatable modifier: one progress value sets the scale (anchored bottom-leading), the margin offset, and the corner radius, border and shadow divided by the current scale so they read constant on screen.",
            "定格副本是时钟被停住的另一份屏幕实例，外面包着一个 Animatable 修饰器：同一个进度值决定缩放（以左下角为锚点）、边距位移，以及按当前缩放比例反算的圆角、描边与阴影，让它们在屏幕上看起来恒定。"
        ),
        apis: ["Animatable", "ViewModifier", "scaleEffect(_:anchor:)", "DragGesture", "spring(response:dampingFraction:)"],
        tags: ["screenshot", "capture", "thumbnail", "flash", "system", "截屏", "截图", "缩略图", "闪光", "系统"],
        params: [
            .slider("scale", L("Thumbnail scale", "缩略图比例"), 0.2...0.45, default: 0.3),
            .slider("hold", L("Hold time", "停留时长"), 0.8...4.0, default: 1.8, decimals: 1, unit: "s"),
            .slider("flash", L("Flash strength", "闪光强度"), 0.3...1.0, default: 0.85),
        ]
    ) { ctx in
        ScreenshotThumbDemo(ctx: ctx)
    }
}

private struct ScreenshotThumbDemo: View {
    let ctx: DemoContext
    /// Whether a frozen copy exists at all.
    @State private var captured: Bool
    /// 0 = full screen, 1 = thumbnail in the corner.
    @State private var shrink: CGFloat
    @State private var flash: Double = 0
    /// Horizontal offset of the thumbnail: the live drag, or the slide off the edge.
    @State private var slide: CGFloat = 0
    /// The moment the copy was frozen (its clock shows this time).
    @State private var frozenAt: Double = 100
    @State private var token = 0

    private static let screen = CGSize(width: 250, height: 280)

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the screenshot resting in the corner.
        _captured = State(initialValue: ctx.isStill)
        _shrink = State(initialValue: ctx.isStill ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                ScreenshotScene(frozen: ctx.isStill ? 100 : nil, preview: ctx.isPreview, language: ctx.language)
                if captured {
                    ScreenshotScene(frozen: frozenAt, preview: ctx.isPreview, language: ctx.language)
                        .modifier(ScreenshotShrink(progress: shrink, thumb: ctx.cg("scale")))
                        .offset(x: slide)
                        .pageSafeHorizontalDrag(onChanged: dragChanged, onEnded: dragEnded)
                }
                Color.white
                    .opacity(flash)
                    .allowsHitTesting(false)
            }
            .frame(width: Self.screen.width, height: Self.screen.height)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color(hex: 0x0E0E10), lineWidth: 5))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            .contentShape(Rectangle())
            .onTapGesture { capture() }
            DemoHint(text: L("Tap to capture, swipe the thumbnail away", "点击截屏，把缩略图划走"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["hold"] + 2.4, delay: 0.6) { capture() }
    }

    // MARK: Sequence

    private func capture() {
        token += 1
        let current = token
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        if buzz { Haptics.tap(.medium) }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            frozenAt = Date().timeIntervalSinceReferenceDate
            captured = true
            shrink = 0
            slide = 0
            flash = ctx["flash"]
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.03))
            guard token == current else { return }
            withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
            try? await Task.sleep(for: .seconds(0.08))
            guard token == current else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { shrink = 1 }
            await holdThenLeave(current)
        }
    }

    private func holdThenLeave(_ current: Int) async {
        try? await Task.sleep(for: .seconds(0.5 + ctx["hold"]))
        guard token == current else { return }
        leave(duration: 0.3)
    }

    private func leave(duration: Double) {
        token += 1
        let current = token
        withAnimation(.easeIn(duration: duration)) { slide = -160 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.05))
            guard token == current else { return }
            captured = false
            slide = 0
            shrink = 0
        }
    }

    // MARK: Gesture

    private func dragChanged(_ value: DragGesture.Value) {
        guard captured, shrink > 0.9 else { return }
        // Holding the thumbnail keeps it on screen.
        token += 1
        let x: CGFloat = value.translation.width
        slide = x < 0 ? x : rubberBand(x, limit: 40)
    }

    private func dragEnded(_ value: DragGesture.Value?) {
        guard captured, shrink > 0.9 else { return }
        let velocity: CGFloat = value?.velocity.width ?? 0
        if slide < -40 || velocity < -400 {
            Haptics.tap(.light)
            let remaining: CGFloat = 160 + slide
            let duration: Double = Double(min(max(remaining / max(-velocity, 500), 0.12), 0.3))
            leave(duration: duration)
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { slide = 0 }
        token += 1
        let current = token
        Task { @MainActor in
            await holdThenLeave(current)
        }
    }
}

/// Shrinks the frozen screen into the bottom-left corner. Corner radius, border and shadow are divided by the
/// current scale, so they look constant on screen while the copy gets smaller.
private struct ScreenshotShrink: ViewModifier, Animatable {
    var progress: CGFloat
    let thumb: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p: CGFloat = progress
        let scale: CGFloat = max(1 - (1 - thumb) * p, 0.05)
        let framed: CGFloat = min(max(p * 3, 0), 1)
        let radius: CGFloat = (34 + (10 - 34) * min(max(p, 0), 1)) / scale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white, lineWidth: 3 / scale * framed))
            .shadow(color: .black.opacity(0.35 * Double(framed)), radius: 10 / scale, y: 5 / scale)
            .scaleEffect(scale, anchor: .bottomLeading)
            .offset(x: 12 * p, y: -12 * p)
    }
}

// MARK: - Screen

/// A weather screen. With `frozen` set its clock stops at that time: that is the screenshot.
private struct ScreenshotScene: View {
    let frozen: Double?
    let preview: Bool
    let language: AppLanguage

    var body: some View {
        TimelineView(.animation(minimumInterval: preview ? 1.0 / 20.0 : 1.0 / 30.0, paused: frozen != nil)) { timeline in
            let t: Double = frozen ?? timeline.date.timeIntervalSinceReferenceDate
            content(t)
        }
        .frame(width: 250, height: 280)
    }

    private func content(_ t: Double) -> some View {
        let zh = language == .zh
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x3C7BEA), Color(hex: 0x7DB7FF), Color(hex: 0xFFD9A8)], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF3B0), Color(hex: 0xFFC247)], center: .center, startRadius: 2, endRadius: 30))
                .frame(width: 58, height: 58)
                .shadow(color: Color(hex: 0xFFD56B).opacity(0.8), radius: 18)
                .scaleEffect(1 + 0.04 * CGFloat(sin(t * 1.6)))
                .offset(x: 62, y: -66)
            cloud(width: 88)
                .offset(x: 26 + CGFloat(16 * sin(t * 0.45)), y: -112)
            cloud(width: 60)
                .opacity(0.8)
                .offset(x: 74 + CGFloat(12 * sin(t * 0.3 + 2)), y: -22)
            ScreenshotHills()
                .fill(LinearGradient(colors: [Color(hex: 0x4FA36B), Color(hex: 0x2C7A55)], startPoint: .top, endPoint: .bottom))
                .frame(width: 250, height: 90)
                .offset(y: 95)
            VStack(alignment: .leading, spacing: 0) {
                Text(zh ? "京都 · 周六" : "Kyoto · Saturday")
                    .font(.footnote.weight(.semibold))
                    .opacity(0.9)
                Text(verbatim: "24°")
                    .font(.system(size: 62, weight: .semibold, design: .rounded))
                Text(zh ? "晴，微风" : "Sunny, light breeze")
                    .font(.subheadline.weight(.medium))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(width: 214, alignment: .leading)
            .offset(y: -26)
            HStack(spacing: 8) {
                forecast("sun.max.fill", "26°", zh ? "日" : "Sun")
                forecast("cloud.sun.fill", "23°", zh ? "一" : "Mon")
                forecast("cloud.rain.fill", "19°", zh ? "二" : "Tue")
                forecast("sun.max.fill", "25°", zh ? "三" : "Wed")
            }
            .offset(y: 96)
        }
        .frame(width: 250, height: 280)
        .clipped()
    }

    private func cloud(width: CGFloat) -> some View {
        ZStack {
            Capsule().frame(width: width, height: width * 0.3).offset(y: width * 0.1)
            Circle().frame(width: width * 0.42).offset(x: -width * 0.14)
            Circle().frame(width: width * 0.32).offset(x: width * 0.16, y: width * 0.03)
        }
        .foregroundStyle(Color.white.opacity(0.9))
    }

    private func forecast(_ symbol: String, _ temperature: String, _ day: String) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: day)
                .font(.caption2.weight(.semibold))
                .opacity(0.8)
            Image(systemName: symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 15))
                .frame(height: 18)
            Text(verbatim: temperature)
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .frame(width: 48, height: 66)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ScreenshotHills: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.45),
            control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY - rect.height * 0.1)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3),
            control: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.85)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
