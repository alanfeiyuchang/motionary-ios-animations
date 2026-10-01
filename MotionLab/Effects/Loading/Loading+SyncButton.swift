import SwiftUI

extension Effect {
    static let loadingSyncButton = Effect(
        id: "loading.sync-button",
        category: .loading,
        interaction: .tap,
        name: L("Sync Button", "同步按钮"),
        summary: L("The two sync arrows wind up, spin, swallow their own tails into a check, then unspin back into place.", "两支同步箭头先蓄力再旋转，把自己的尾巴收成一个对勾，最后倒转一圈回到原位。"),
        prompt: L(
            "A 204 × 56 pt blue pill reads 'Sync now' beside two arc arrows. On tap the glyph winds back 28° in 160 ms, then spins forward about three turns over 1.6 s on a (0.5, 0, 0.2, 1) curve, fast in the middle and coasting to a stop, while a soft sheen crosses the pill every 1.1 s, the label rolls to 'Syncing…' and the caption counts items up to 128. As it stops, each arrow's tail catches up with its head: both arcs shorten to nothing on a spring (response 0.4 s, damping 0.6) and a check draws in their place over 0.28 s. The pill turns green and pops 1 → 1.05 → 1 with a success haptic. After a hold the check retracts and the arrows grow back while unspinning one full turn on a spring (response 0.6 s, damping 0.68). Purposeful, kinetic, tidy.",
            "一枚 204 × 56 pt 的蓝色胶囊写着“立即同步”，旁有两支弧形箭头。点击后图标先用 160 毫秒反向蓄力 28°，再沿 (0.5, 0, 0.2, 1) 曲线用 1.6 秒正转约三圈后滑停；其间柔光每 1.1 秒扫过胶囊，文字滚为“同步中…”，下方计数到 128。停转时箭头的尾巴追上箭头：两段弧以弹簧（响应 0.4 秒、阻尼 0.6）缩到消失，对勾用 0.28 秒在原位画出，胶囊变绿并以 1 → 1.05 → 1 轻弹，伴随成功触感。随后对勾收回，箭头一边长出、一边以弹簧（响应 0.6 秒、阻尼 0.68）倒转一整圈归位。利落。"
        ),
        implementation: L(
            "The glyph is an animatable Shape: two polyline arcs with chevron heads whose sweep and head size scale with 1 − merge, under a rotationEffect driven by a single angle. A task sequences wind-up, spin, merge and unspin with withAnimation.",
            "图标是一个可动画的 Shape：两段带箭头的折线圆弧，弧长与箭头大小随 1 − merge 缩放，外层 rotationEffect 由一个角度驱动。异步任务用 withAnimation 依次编排蓄力、旋转、合并与倒转。"
        ),
        apis: ["Shape.animatableData", "rotationEffect", "timingCurve(_:_:_:_:duration:)", "trim(from:to:)", "keyframeAnimator"],
        tags: ["sync", "refresh", "arrows", "check", "同步", "刷新", "箭头", "对勾"],
        params: [
            .slider("duration", L("Sync time", "同步时长"), 0.8...4, default: 1.6, decimals: 1, unit: "s"),
            .slider("speed", L("Spin speed", "旋转速度"), 0.8...3.5, default: 1.9, decimals: 1, unit: "rev/s"),
            .toggle("unspin", L("Unspin on reset", "复位时倒转"), default: true),
        ]
    ) { ctx in
        SyncButtonDemo(ctx: ctx)
    }
}

private enum SyncState {
    case idle
    case syncing
    case done
}

private struct SyncButtonDemo: View {
    let ctx: DemoContext
    @State private var state: SyncState
    @State private var rotation: Double
    @State private var merge: Double = 0
    @State private var check: Double = 0
    @State private var items: Double
    @State private var pops = 0
    @State private var task: Task<Void, Never>?

    private let width: CGFloat = 204
    private let height: CGFloat = 56
    private static let itemCount: Double = 128

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills catch the arrows mid-spin.
        _state = State(initialValue: ctx.isStill ? .syncing : .idle)
        _rotation = State(initialValue: ctx.isStill ? 70 : 0)
        _items = State(initialValue: ctx.isStill ? 57 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            Button(action: sync) { face }
                .buttonStyle(SyncPressStyle())
                .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(1.05, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                    }
                }
            caption
            DemoHint(text: L("Tap to sync", "点击同步"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Only an idle button is tapped, so a sync is never cut short; it resets itself.
        .autoplay(ctx.isPreview, every: 1.0, delay: 0.6) {
            if state == .idle { sync() }
        }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private var title: String {
        let zh = ctx.language == .zh
        switch state {
        case .idle: return zh ? "立即同步" : "Sync now"
        case .syncing: return zh ? "同步中…" : "Syncing…"
        case .done: return zh ? "已是最新" : "Up to date"
        }
    }

    private var face: some View {
        let done: Bool = state == .done
        return ZStack {
            Capsule().fill(LinearGradient(colors: [Color(hex: 0x3D8BFF), Color(hex: 0x3F55E0)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Capsule().fill(Palette.successStrong).opacity(done ? 1 : 0)
            if state == .syncing {
                SyncSheen(width: width)
                    .transition(.opacity)
            }
            Capsule()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            HStack(spacing: 10) {
                SyncGlyph(rotation: rotation, merge: merge, check: check)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.headline)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(.white)
        }
        .frame(width: width, height: height)
        .clipShape(Capsule())
        .shadow(color: (done ? Palette.green : Palette.blue).opacity(0.38), radius: 14, y: 8)
    }

    private var caption: some View {
        let zh = ctx.language == .zh
        return Group {
            switch state {
            case .idle:
                Text(zh ? "上次同步：2 分钟前" : "Last synced 2 min ago")
            case .syncing:
                SyncItemsText(value: items, total: Int(SyncButtonDemo.itemCount), zh: zh)
            case .done:
                Text(zh ? "刚刚同步了 128 项" : "128 items synced just now")
                    .foregroundStyle(Palette.green)
            }
        }
        .font(.footnote.weight(.medium).monospacedDigit())
        .foregroundStyle(.secondary)
        .transition(.opacity)
        .frame(height: 18)
    }

    private func sync() {
        switch state {
        case .syncing:
            return
        case .done:
            task?.cancel()
            reset()
            return
        case .idle:
            break
        }
        if !ctx.isPreview { Haptics.tap(.medium) }
        let duration: Double = max(ctx["duration"], 0.3)
        let turns: Double = max((duration * ctx["speed"]).rounded(), 1)
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let loops: Bool = ctx.isPreview
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { items = 0 }
        withAnimation(.smooth(duration: 0.25)) { state = .syncing }
        // Wind-up: a short turn against the spin.
        withAnimation(.easeOut(duration: 0.16)) { rotation -= 28 }
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.5, 0, 0.2, 1, duration: duration)) { rotation += 28 + 360 * turns }
            withAnimation(.easeInOut(duration: duration * 0.92)) { items = SyncButtonDemo.itemCount }
            try? await Task.sleep(for: .seconds(duration - 0.08))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                state = .done
                merge = 1
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.1)) { check = 1 }
            pops += 1
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(loops ? 1.5 : 2.2))
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    /// The check retracts and the arrows grow back, unspinning one turn.
    private func reset() {
        let unspin: Bool = ctx.bool("unspin")
        withAnimation(.easeIn(duration: 0.16)) { check = 0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.68)) {
            merge = 0
            state = .idle
            if unspin { rotation -= 360 }
        }
    }
}

/// Two arc arrows that shorten into nothing as `merge` goes to 1.
private struct SyncArrows: Shape {
    var merge: Double

    var animatableData: Double {
        get { merge }
        set { merge = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let keep: Double = 1 - min(max(merge, 0), 1)
        guard keep > 0.01 else { return path }
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = min(rect.width, rect.height) / 2 - 2.5
        let sweep: Double = 126 * .pi / 180 * keep
        for half in 0..<2 {
            // The head stays where it is; the tail catches up with it.
            let end: Double = (half == 0 ? -28 : 152) * .pi / 180
            let steps: Int = 14
            for step in 0...steps {
                let angle: Double = end - sweep + sweep * Double(step) / Double(steps)
                let point = CGPoint(x: centre.x + radius * CGFloat(cos(angle)), y: centre.y + radius * CGFloat(sin(angle)))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            let tip = CGPoint(x: centre.x + radius * CGFloat(cos(end)), y: centre.y + radius * CGFloat(sin(end)))
            let tangent = CGPoint(x: CGFloat(-sin(end)), y: CGFloat(cos(end)))
            let normal = CGPoint(x: CGFloat(cos(end)), y: CGFloat(sin(end)))
            let length: CGFloat = 5 * CGFloat(keep)
            let spread: CGFloat = 4.2 * CGFloat(keep)
            path.move(to: CGPoint(x: tip.x - tangent.x * length + normal.x * spread, y: tip.y - tangent.y * length + normal.y * spread))
            path.addLine(to: tip)
            path.addLine(to: CGPoint(x: tip.x - tangent.x * length - normal.x * spread, y: tip.y - tangent.y * length - normal.y * spread))
        }
        return path
    }
}

private struct SyncCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.74))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.28))
        return path
    }
}

private struct SyncGlyph: View {
    let rotation: Double
    let merge: Double
    let check: Double

    var body: some View {
        let style = StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
        ZStack {
            SyncArrows(merge: merge)
                .stroke(.white, style: style)
                .rotationEffect(.degrees(rotation))
            SyncCheck()
                .trim(from: 0, to: check)
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .opacity(check > 0.001 ? 1 : 0)
        }
    }
}

/// A band of light that crosses the pill for as long as it is on screen.
private struct SyncSheen: View {
    let width: CGFloat
    @State private var moving = false

    var body: some View {
        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.28), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 90, height: 140)
            .rotationEffect(.degrees(18))
            .offset(x: moving ? width / 2 + 60 : -width / 2 - 60)
            .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: moving)
            .onAppear { moving = true }
            .allowsHitTesting(false)
    }
}

private struct SyncItemsText: View, Animatable {
    var value: Double
    let total: Int
    let zh: Bool

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        let count: Int = Int(min(max(value, 0), Double(total)).rounded())
        Text(zh ? "正在同步 \(count) / \(total) 项" : "Syncing \(count) of \(total) items")
    }
}

private struct SyncPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
