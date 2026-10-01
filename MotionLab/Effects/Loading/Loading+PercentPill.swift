import SwiftUI

extension Effect {
    static let loadingPercentPill = Effect(
        id: "loading.percent-pill",
        category: .loading,
        interaction: .state,
        name: L("Percent Pill", "百分比胶囊"),
        summary: L("A pill grows wider with every chunk of progress, then snaps into a circle and signs a check.", "胶囊随每一段进度变宽，完成后收缩成圆并画出对勾。"),
        prompt: L(
            "A 56 pt tall indigo → violet pill sits centred inside a faint 250 pt guide capsule and starts 72 pt wide, reading '0%'. Progress arrives in irregular chunks; each one widens the pill symmetrically on a spring (response 0.5 s, damping 0.62) so the ends overshoot and settle, while the rounded percentage rolls digit by digit and a soft sheen crosses the pill every 1.6 s. At 100% it fills the guide, holds 0.35 s, then contracts into a 56 pt circle on a spring (response 0.5 s, damping 0.68) as the fill crossfades to green, the number blurs out, a 3.5 pt white check draws in 0.3 s and one ring ripples out to 2× and fades. A success haptic lands with the check. Elastic, compact, conclusive.",
            "一枚 56 pt 高、靛蓝 → 紫罗兰的胶囊居中放在淡淡的 250 pt 引导轮廓里，起始宽 72 pt，显示“0%”。进度分段到达：每到一段，胶囊以弹簧（响应 0.5 秒、阻尼 0.62）向两侧对称变宽，两端先过冲再落定；圆体百分比逐位滚动，一道柔和高光每 1.6 秒划过。到 100% 时它填满轮廓，停留 0.35 秒，再以弹簧（响应 0.5 秒、阻尼 0.68）收缩成 56 pt 的圆：填充淡变为绿色，数字模糊淡出，3.5 pt 白色对勾在 0.3 秒内画出，一圈涟漪扩到 2 倍后消失，伴随成功触感。有弹性、紧凑、干脆。"
        ),
        implementation: L(
            "The pill is a Capsule whose frame width is interpolated from progress and animated with a spring; numericText rolls the label, and a phase flag swaps width, fill and a trimmed check path for the finish.",
            "胶囊是一个 Capsule，frame 宽度由进度插值并以弹簧动画；文字用 numericText 滚动，完成时由阶段标记切换宽度、填充色与被 trim 的对勾路径。"
        ),
        apis: ["Capsule", "contentTransition(.numericText(value:))", "spring(response:dampingFraction:)", "trim(from:to:)", "TimelineView"],
        tags: ["pill", "percent", "progress", "checkmark", "胶囊", "百分比", "进度", "对勾"],
        params: [
            .slider("speed", L("Speed", "速度"), 0.4...2.5, default: 1.0),
            .slider("damping", L("Width damping", "变宽阻尼"), 0.35...1, default: 0.62),
            .toggle("collapse", L("Collapse to check", "收缩为对勾"), default: true),
        ]
    ) { ctx in
        PercentPillDemo(ctx: ctx)
    }
}

private struct PillCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.minY + rect.height * 0.08))
        return path
    }
}

private struct PercentPillDemo: View {
    let ctx: DemoContext
    @State private var progress: Double
    @State private var done = false
    @State private var checked = false
    @State private var ripple = false
    @State private var run = 0

    private let height: CGFloat = 56
    private let minWidth: CGFloat = 72
    private let maxWidth: CGFloat = 250

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills never run `task`: show a representative part-filled pill.
        _progress = State(initialValue: ctx.isStill ? 0.64 : 0)
    }

    var body: some View {
        let zh = ctx.language == .zh
        let collapsed: Bool = done && ctx.bool("collapse")
        VStack(spacing: 20) {
            ZStack {
                guide.opacity(collapsed ? 0 : 1)
                rippleRing
                pill(collapsed: collapsed)
            }
            .frame(width: maxWidth + 20, height: 120)
            VStack(spacing: 4) {
                Text(done ? (zh ? "已存入相册" : "Saved to Photos") : (zh ? "正在导出视频" : "Exporting video"))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.interpolate)
                Text(done
                     ? (zh ? "1080p · 38.4 MB" : "1080p · 38.4 MB")
                     : String(format: zh ? "1080p · 已写入 %.1f / 38.4 MB" : "1080p · %.1f of 38.4 MB", progress * 38.4))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: progress))
            }
            DemoHint(text: L("Tap to restart", "点击重新开始"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            run += 1
        }
        .task(id: run) { await play() }
    }

    private var guide: some View {
        Capsule()
            .fill(Color.primary.opacity(0.05))
            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [3, 4])) }
            .frame(width: maxWidth, height: height)
            .animation(.easeOut(duration: 0.3), value: done)
    }

    private var rippleRing: some View {
        Circle()
            .stroke(Palette.green, lineWidth: 2)
            .frame(width: height, height: height)
            .scaleEffect(ripple ? 2 : 1)
            .opacity(ripple || !ctx.bool("collapse") ? 0 : (checked ? 0.7 : 0))
    }

    private func pill(collapsed: Bool) -> some View {
        let width: CGFloat = collapsed ? height : minWidth + (maxWidth - minWidth) * CGFloat(progress)
        let percent: Int = Int((progress * 100).rounded())
        return ZStack {
            Capsule().fill(Palette.primaryStrong)
            Capsule().fill(Palette.green).opacity(done ? 1 : 0)
            PillSheen(preview: ctx.isPreview, paused: done)
                .opacity(done ? 0 : 1)
            // A lit top edge, so the pill reads as a solid object.
            Capsule()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Text(done && !collapsed ? (ctx.language == .zh ? "完成" : "Done") : "\(percent)%")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: progress))
                .fixedSize()
                .opacity(collapsed ? 0 : 1)
                .blur(radius: collapsed ? 6 : 0)
                .scaleEffect(collapsed ? 0.5 : 1)
            PillCheck()
                .trim(from: 0, to: checked && collapsed ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 17)
        }
        .frame(width: max(width, height), height: height)
        .clipShape(Capsule())
        .shadow(color: (done ? Palette.green : Palette.indigo).opacity(0.4), radius: 14, y: 8)
    }

    private func play() async {
        // Only a run the user restarted buzzes; the automatic first run stays silent.
        let live: Bool = !ctx.isPreview && run > 0
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            ripple = false
            checked = false
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            done = false
            progress = 0
        }
        try? await Task.sleep(for: .seconds(0.7))
        while progress < 1 {
            if Task.isCancelled { return }
            let step: Double = Double.random(in: 0.06...0.17) * ctx["speed"]
            withAnimation(.spring(response: 0.5, dampingFraction: ctx["damping"])) { progress = min(1, progress + step) }
            try? await Task.sleep(for: .seconds(Double.random(in: 0.32...0.55)))
        }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) { done = true }
        try? await Task.sleep(for: .seconds(0.18))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) { checked = true }
        if ctx.bool("collapse") {
            withAnimation(.easeOut(duration: 0.7)) { ripple = true }
        }
        if live { Haptics.success() }
        guard ctx.isPreview else { return }
        try? await Task.sleep(for: .seconds(1.8))
        guard !Task.isCancelled else { return }
        run += 1
    }
}

/// A soft highlight that crosses the pill every 1.6 s.
private struct PillSheen: View {
    let preview: Bool
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: paused)) { timeline in
            let x: Double = (timeline.date.timeIntervalSinceReferenceDate / 1.6).truncatingRemainder(dividingBy: 1) * 2.2 - 0.6
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.28), location: 0.5),
                    .init(color: .white.opacity(0), location: 1),
                ],
                startPoint: UnitPoint(x: x - 0.25, y: 0.2),
                endPoint: UnitPoint(x: x + 0.25, y: 0.8)
            )
        }
        .allowsHitTesting(false)
    }
}
