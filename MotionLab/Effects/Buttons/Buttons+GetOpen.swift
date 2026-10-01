import SwiftUI

extension Effect {
    static let buttonsGetOpen = Effect(
        id: "buttons.get-open",
        category: .buttons,
        interaction: .tap,
        name: L("Get → Open", "获取 → 打开"),
        summary: L(
            "A store-style GET pill shrinks into a progress ring, fills, then grows back as a solid OPEN.",
            "应用商店式的“获取”胶囊收缩成进度环，走满后再展开成实心的“打开”。"
        ),
        prompt: L(
            "An app row with a 64 pt icon and, on the right, a tinted 78 × 34 pt “GET” capsule. Tapping collapses the capsule to a 34 pt circle on a spring (response 0.4 s, damping 0.62) while the label blurs out; a 70% arc spins for 0.45 s as the request starts, then becomes a 3 pt progress ring with a small stop square in its centre. Progress advances over 1.8 s in four uneven eased steps (22%, 58%, 83%, 100%), mirrored by a pie wipe over the dimmed app icon. At 100% the ring flashes, the circle springs open into an 86 pt solid blue “OPEN” capsule with white text that pops to 108% and settles, and the icon bounces with a success haptic. Tapping the ring cancels back to GET; tapping OPEN resets. Crisp, familiar, rewarding.",
            "应用列表行：左侧是 64pt 的应用图标，右侧是 78×34pt 的浅色“获取”胶囊。点击后胶囊以弹簧（响应 0.4 秒、阻尼 0.62）收缩成 34pt 的圆，文字模糊淡出；一段 70% 的圆弧先旋转 0.45 秒，随后变成 3pt 粗的进度环，中心是小停止方块。进度在 1.8 秒内分四段缓动推进（22%、58%、83%、100%），变暗的应用图标上同步出现扇形进度。到 100% 时圆环一闪，弹开成 86pt 的实心蓝色“打开”胶囊，弹到 108% 再回落，图标一跳，触发成功触感。点圆环可取消，点“打开”则复位。"
        ),
        implementation: L(
            "One capsule whose width, fill and stroke derive from a four-case phase; the label, spinner, ring and stop square cross-fade inside it. A Task scripts the download as a few withAnimation(.easeInOut) steps on a progress value, which also drives an animatable pie Shape over the app icon.",
            "同一个胶囊的宽度、填充与描边都由四种阶段推导；文字、旋转弧、进度环与停止方块在其中交叉淡入淡出。一个 Task 把下载脚本化为对进度值的几段 withAnimation(.easeInOut)，该进度同时驱动应用图标上的可动画扇形 Shape。"
        ),
        apis: ["withAnimation", "Shape.trim(from:to:)", "Animatable", "keyframeAnimator", "spring(response:dampingFraction:)"],
        tags: ["download", "get", "open", "progress ring", "morph", "获取", "打开", "下载", "进度环", "形变"],
        params: [
            .slider("duration", L("Download time", "下载时长"), 0.8...4.0, default: 1.8, unit: "s"),
            .slider("response", L("Morph response", "形变响应"), 0.25...0.7, default: 0.4, unit: "s"),
            .slider("damping", L("Morph damping", "形变阻尼"), 0.4...1.0, default: 0.62),
        ]
    ) { ctx in
        ButtonGetOpenDemo(ctx: ctx)
    }
}

private enum ButtonGetPhase {
    case get, waiting, loading, open
}

private struct ButtonGetOpenDemo: View {
    let ctx: DemoContext
    @State private var phase: ButtonGetPhase
    @State private var progress: Double
    @State private var spin = false
    @State private var pops = 0
    @State private var task: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? .loading : .get)
        _progress = State(initialValue: ctx.isStill ? 0.62 : 0)
    }

    private var morph: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var busy: Bool { phase == .waiting || phase == .loading }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            row
            Spacer()
            DemoHint(text: L("Tap GET; tap the ring to cancel", "点“获取”；点圆环可取消"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: max(ctx["duration"], 0.2) + 3.4, delay: 0.5) { start(haptics: false) }
        .onDisappear { task?.cancel() }
    }

    private var row: some View {
        HStack(spacing: 14) {
            ButtonGetIcon(progress: progress, busy: busy)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(0.9, duration: 0.1)
                        SpringKeyframe(1, duration: 0.55, spring: .bouncy)
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(ctx.language == .zh ? "动效手册" : "Motion Notes")
                    .font(.headline)
                Text(statusText, ctx.language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
            Button {
                tapped()
            } label: {
                pill
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 308)
        .demoCard(cornerRadius: 26)
    }

    private var statusText: LocalizedText {
        switch phase {
        case .get: return L("Design tools", "设计工具")
        case .waiting: return L("Waiting…", "正在等待…")
        case .loading: return L("Downloading…", "正在下载…")
        case .open: return L("Installed", "已安装")
        }
    }

    private var pill: some View {
        let width: CGFloat = busy ? 34 : (phase == .open ? 86 : 78)
        return ZStack {
            Capsule()
                .fill(phase == .open ? Palette.blue : Palette.blue.opacity(busy ? 0 : 0.16))
            // Ring track + progress.
            Circle()
                .stroke(Color.primary.opacity(0.14), lineWidth: 3)
                .padding(1.5)
                .opacity(phase == .loading ? 1 : 0)
            Circle()
                .trim(from: 0, to: phase == .loading ? max(progress, 0.02) : 0)
                .stroke(Palette.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.5)
                .opacity(phase == .loading ? 1 : 0)
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Palette.blue)
                .frame(width: 10, height: 10)
                .scaleEffect(phase == .loading ? 1 : 0.2)
                .opacity(phase == .loading ? 1 : 0)
            // Indeterminate arc while the request is pending.
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Palette.blue.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .padding(1.5)
                .opacity(phase == .waiting ? 1 : 0)
            label(L("GET", "获取"), color: Palette.blue, shown: phase == .get)
            label(L("OPEN", "打开"), color: .white, shown: phase == .open)
        }
        .frame(width: width, height: 34)
        .contentShape(Capsule())
        .keyframeAnimator(initialValue: ButtonGetPop(), trigger: pops) { content, pop in
            content
                .overlay(Capsule().fill(Color.white.opacity(pop.flash)))
                .scaleEffect(pop.scale)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.08, duration: 0.12)
                SpringKeyframe(1, duration: 0.5, spring: .bouncy)
            }
            KeyframeTrack(\.flash) {
                MoveKeyframe(0.7)
                CubicKeyframe(0, duration: 0.35)
            }
        }
        // Keeps the trailing edge fixed while the pill changes width.
        .frame(width: 86, alignment: .trailing)
    }

    private func label(_ text: LocalizedText, color: Color, shown: Bool) -> some View {
        Text(text, ctx.language)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .fixedSize()
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : 5)
            .scaleEffect(shown ? 1 : 0.7)
    }

    // MARK: Behaviour

    private func tapped() {
        switch phase {
        case .get:
            Haptics.tap(.light)
            start(haptics: true)
        case .waiting, .loading:
            Haptics.tap(.light)
            reset()
        case .open:
            Haptics.tap(.light)
            reset()
        }
    }

    private func start(haptics: Bool) {
        guard phase == .get else { return }
        task?.cancel()
        progress = 0
        spin = false
        withAnimation(morph) { phase = .waiting }
        withAnimation(.linear(duration: 0.7).repeatForever(autoreverses: false)) { spin = true }
        let total = max(ctx["duration"], 0.2)
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.25)) { phase = .loading }
            // Uneven steps read as a real network transfer.
            let steps: [(Double, Double)] = [(0.22, 0.2), (0.58, 0.34), (0.83, 0.22), (1, 0.24)]
            for (value, share) in steps {
                withAnimation(.easeInOut(duration: total * share)) { progress = value }
                try? await Task.sleep(for: .seconds(total * share))
                guard !Task.isCancelled else { return }
            }
            pops += 1
            withAnimation(morph) { phase = .open }
            if haptics { Haptics.success() }
            guard ctx.isPreview else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    private func reset() {
        task?.cancel()
        withAnimation(morph) { phase = .get }
        withAnimation(.smooth(duration: 0.25)) { progress = 0 }
        var stop = Transaction()
        stop.disablesAnimations = true
        withTransaction(stop) { spin = false }
    }
}

private struct ButtonGetPop {
    var scale: CGFloat = 1
    var flash: Double = 0
}

/// The app icon with the home-screen style install overlay: dimmed, with a pie that wipes away as progress grows.
private struct ButtonGetIcon: View {
    let progress: Double
    let busy: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        ZStack {
            shape.fill(Palette.aurora)
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(busy ? 0.25 : 1)
            shape
                .fill(Color.black.opacity(0.45))
                .opacity(busy ? 1 : 0)
            ButtonGetPie(progress: progress)
                .fill(Color.white.opacity(0.85))
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 2).frame(width: 38, height: 38))
                .opacity(busy ? 1 : 0)
                .scaleEffect(busy ? 1 : 0.6)
        }
        .frame(width: 64, height: 64)
        .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: Palette.sky.opacity(0.3), radius: 8, y: 4)
    }
}

private struct ButtonGetPie: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(
            center: center,
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * progress.clamped(to: 0...1)),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
