import SwiftUI

extension Effect {
    static let navigationOnboardingMorph = Effect(
        id: "navigation.onboarding-morph",
        category: .navigation,
        interaction: .gesture,
        name: L("Dots Into Get-Started", "圆点汇成开始按钮"),
        summary: L(
            "On the last onboarding page the page dots run together like droplets, fuse into one and swell into the Get started button; swipe back and it splits into dots again.",
            "滑到引导的最后一页，页码圆点像水滴一样聚拢、融为一体，再膨胀成「开始使用」按钮；往回滑，它又分裂回圆点。"
        ),
        prompt: L(
            "A four-page onboarding carousel with 8 pt page dots; the active dot is a 22 pt capsule that hands its width to the next dot as you swipe. The final swipe is different: driven 1:1 by the same scroll fraction, during its first half the dots slide toward the centre and fuse with a metaball edge (5 pt blur, 50% alpha threshold) while the grey ones take on the accent gradient; from 35% onward the fused blob grows into a 220 × 52 pt capsule button, and in the last 30% its label fades up from 90% scale. Release settles on a spring (response 0.5 s, damping 0.8), so the button overshoots slightly as it lands, with a soft haptic. Swiping back reverses every stage. Tapping the button swaps the label for a check that scales in, then the flow restarts.",
            "四页引导轮播，下方是 8 pt 的页码圆点；当前圆点是 22 pt 的胶囊，滑动时把宽度交接给下一个。最后一次滑动不同：仍由同一个滚动进度 1:1 驱动，前半程圆点向中心靠拢，以融球边缘（5 pt 模糊、50% 透明度阈值）粘连，灰色圆点同时染上强调色渐变；进度过 35% 后，融合的液滴长成 220 × 52 pt 的胶囊按钮，最后 30% 里文字从 90% 缩放淡入。松手后以弹簧（响应 0.5 秒、阻尼 0.8）落定，按钮到位时略微过冲，伴随柔和触感。往回滑则原路倒放。点击按钮，文字换成弹入的对勾，随后流程重新开始。"
        ),
        implementation: L(
            "An Animatable scene derives the dot rects, the merge and the grow factors from one fractional page. The accent shapes are drawn in a Canvas with blur + alphaThreshold filters and used as the mask of a gradient, so separate dots and the button are literally the same surface.",
            "一个 Animatable 场景视图由小数页码推导出圆点矩形、融合系数与生长系数。强调色的形状画在带 blur 与 alphaThreshold 滤镜的 Canvas 里，再作为渐变的遮罩，所以分开的圆点和按钮确实是同一块表面。"
        ),
        apis: ["Canvas", "GraphicsContext.Filter.alphaThreshold", "Animatable", "mask(_:)", "DragGesture", "spring(response:dampingFraction:)"],
        tags: ["onboarding", "page dots", "get started", "metaball", "引导页", "页码圆点", "开始按钮", "融球"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("width", L("Button width", "按钮宽度"), 140...250, default: 220, decimals: 0, unit: "pt"),
            .slider("goo", L("Goo blur", "粘连模糊"), 0...9, default: 5, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        OnboardingMorphDemo(ctx: ctx)
    }
}

private struct OnboardPage {
    let symbol: String
    let title: LocalizedText
    let subtitle: LocalizedText
    let colors: [Color]
}

private let onboardPages: [OnboardPage] = [
    OnboardPage(symbol: "sparkles", title: L("Collect ideas", "收集灵感"), subtitle: L("Save anything in one tap", "一键保存任何内容"), colors: [Palette.amber, Palette.coral]),
    OnboardPage(symbol: "square.stack.3d.up.fill", title: L("Stay organised", "井井有条"), subtitle: L("Boards sort themselves", "看板会自动归类"), colors: [Palette.mint, Palette.sky]),
    OnboardPage(symbol: "person.2.fill", title: L("Share with friends", "和朋友分享"), subtitle: L("Edit together, live", "实时一起编辑"), colors: [Palette.pink, Palette.violet]),
    OnboardPage(symbol: "paperplane.fill", title: L("Ready to go", "准备好了"), subtitle: L("It takes ten seconds", "只需要十秒钟"), colors: [Palette.indigo, Palette.violet]),
]

private enum OnboardMetrics {
    static let frame = CGSize(width: 290, height: 284)
    static let dot: CGFloat = 8
    static let active: CGFloat = 22
    static let gap: CGFloat = 8
    static let buttonHeight: CGFloat = 52
    static let indicator = CGSize(width: 262, height: 60)

    static func smooth(_ value: CGFloat, _ from: CGFloat, _ to: CGFloat) -> CGFloat {
        let t: CGFloat = min(max((value - from) / (to - from), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// Everything the indicator needs for one fractional page.
private struct OnboardGeometry {
    /// Plain grey dots.
    var dots: [CGRect] = []
    /// Accent shapes (the active capsule, dots joining it, the growing button).
    var accent: [CGRect] = []
    var merge: CGFloat = 0
    var grow: CGFloat = 0
    var overshoot: CGFloat = 0

    init(progress: CGFloat, buttonWidth: CGFloat) {
        let count: Int = onboardPages.count
        let last: CGFloat = CGFloat(count - 1)
        let m: CGFloat = min(max(progress - (last - 1), 0), 1)
        merge = OnboardMetrics.smooth(m, 0, 0.55)
        grow = OnboardMetrics.smooth(m, 0.35, 1)
        overshoot = max(progress - last, 0)
        let size: CGSize = OnboardMetrics.indicator
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)

        var widths: [CGFloat] = []
        var nears: [CGFloat] = []
        for index in 0..<count {
            let near: CGFloat = max(0, 1 - abs(CGFloat(index) - min(max(progress, 0), last)))
            nears.append(near)
            widths.append(OnboardMetrics.dot + (OnboardMetrics.active - OnboardMetrics.dot) * near)
        }
        let total: CGFloat = widths.reduce(0, +) + OnboardMetrics.gap * CGFloat(count - 1)
        var x: CGFloat = centre.x - total / 2
        for index in 0..<count {
            let rest: CGFloat = x + widths[index] / 2
            x += widths[index] + OnboardMetrics.gap
            let cx: CGFloat = rest + (centre.x - rest) * merge
            let height: CGFloat = OnboardMetrics.dot
            dots.append(CGRect(x: cx - widths[index] / 2, y: centre.y - height / 2, width: widths[index], height: height))
            // A dot is accent-coloured as far as it is active or already merging.
            let share: CGFloat = max(nears[index], merge)
            if share > 0.02 {
                let w: CGFloat = widths[index] * min(share * 1.4, 1)
                let h: CGFloat = height * min(share * 1.4, 1)
                accent.append(CGRect(x: cx - w / 2, y: centre.y - h / 2, width: w, height: h))
            }
        }
        if grow > 0 {
            let scale: CGFloat = 1 + overshoot * 0.5
            let w: CGFloat = (OnboardMetrics.active + (buttonWidth - OnboardMetrics.active) * grow) * scale
            let h: CGFloat = (OnboardMetrics.dot + (OnboardMetrics.buttonHeight - OnboardMetrics.dot) * grow) * scale
            accent.append(CGRect(x: centre.x - w / 2, y: centre.y - h / 2, width: w, height: h))
        }
    }
}

private struct OnboardingMorphDemo: View {
    let ctx: DemoContext
    @State private var progress: CGFloat
    @State private var dragStart: CGFloat?
    @State private var done = false
    @State private var restartTask: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the finished button.
        _progress = State(initialValue: ctx.isStill ? CGFloat(onboardPages.count - 1) : 0)
    }

    private var lastIndex: CGFloat { CGFloat(onboardPages.count - 1) }

    var body: some View {
        VStack(spacing: 14) {
            OnboardScene(
                progress: progress,
                buttonWidth: ctx.cg("width"),
                goo: ctx.cg("goo"),
                done: done,
                language: ctx.language
            )
            .frame(width: OnboardMetrics.frame.width, height: OnboardMetrics.frame.height)
            .background(Palette.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
            .overlay(alignment: .bottom) { buttonTarget }
            .contentShape(Rectangle())
            .pageSafeHorizontalDrag(onChanged: dragChanged, onEnded: dragEnded)
            DemoHint(text: L("Swipe to the last page and back", "滑到最后一页，再滑回来"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.4) { autoplayStep() }
        .onDisappear { restartTask?.cancel() }
    }

    /// Tap target over the indicator: the button on the last page, "next" before that.
    private var buttonTarget: some View {
        Color.clear
            .frame(width: ctx.cg("width"), height: OnboardMetrics.indicator.height)
            .contentShape(Rectangle())
            .onTapGesture { indicatorTapped() }
            .padding(.bottom, 14)
    }

    private func indicatorTapped() {
        let page: Int = Int(progress.rounded())
        if page >= onboardPages.count - 1 {
            start()
        } else {
            settle(to: page + 1)
        }
    }

    private func start() {
        guard !done else { return }
        if !ctx.isPreview { Haptics.success() }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { done = true }
        restartTask?.cancel()
        restartTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                progress = 0
                done = false
            }
        }
    }

    private func dragChanged(_ value: DragGesture.Value) {
        guard !done else { return }
        let start: CGFloat = dragStart ?? progress
        if dragStart == nil { dragStart = progress }
        var page: CGFloat = start - value.translation.width / OnboardMetrics.frame.width
        if page < 0 { page = -rubberBand(-page, limit: 0.4) }
        if page > lastIndex { page = lastIndex + rubberBand(page - lastIndex, limit: 0.25) }
        progress = page
    }

    private func dragEnded(_ value: DragGesture.Value?) {
        guard let start = dragStart else { return }
        dragStart = nil
        let projected: CGFloat = value.map { start - $0.predictedEndTranslation.width / OnboardMetrics.frame.width } ?? progress
        let limited: CGFloat = min(max(projected, start.rounded() - 1), start.rounded() + 1)
        settle(to: Int(limited.rounded()))
    }

    private func settle(to index: Int) {
        let clamped: Int = min(max(index, 0), onboardPages.count - 1)
        if !ctx.isPreview { Haptics.tap(clamped == onboardPages.count - 1 ? .soft : .light) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            progress = CGFloat(clamped)
        }
    }

    private func autoplayStep() {
        guard !done else { return }
        let page: Int = Int(progress.rounded())
        if page >= onboardPages.count - 1 {
            start()
        } else {
            settle(to: page + 1)
        }
    }
}

// MARK: - Scene

private struct OnboardScene: View, Animatable {
    var progress: CGFloat
    let buttonWidth: CGFloat
    let goo: CGFloat
    let done: Bool
    let language: AppLanguage

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let geometry = OnboardGeometry(progress: progress, buttonWidth: buttonWidth)
        VStack(spacing: 0) {
            pages
                .frame(maxHeight: .infinity)
            indicator(geometry)
                .padding(.bottom, 14)
        }
        .frame(width: OnboardMetrics.frame.width, height: OnboardMetrics.frame.height)
    }

    // MARK: Pages

    private var pages: some View {
        ZStack {
            ForEach(0..<onboardPages.count, id: \.self) { index in
                let distance: CGFloat = CGFloat(index) - progress
                if abs(distance) < 1.4 {
                    page(onboardPages[index], distance: distance)
                }
            }
        }
        .frame(width: OnboardMetrics.frame.width)
        .clipped()
    }

    private func page(_ item: OnboardPage, distance: CGFloat) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: item.colors[0].opacity(0.4), radius: 16, y: 8)
                Image(systemName: item.symbol)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.white)
                    .offset(x: distance * 30)
            }
            .offset(x: distance * 40)
            VStack(spacing: 4) {
                Text(item.title, language)
                    .font(.title3.weight(.bold))
                Text(item.subtitle, language)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 10)
        .frame(width: OnboardMetrics.frame.width)
        .offset(x: distance * OnboardMetrics.frame.width)
        .opacity(Double(1 - min(abs(distance), 1) * 0.6))
    }

    // MARK: Indicator

    private func indicator(_ geometry: OnboardGeometry) -> some View {
        let size: CGSize = OnboardMetrics.indicator
        // Goo only while shapes are actually merging; at rest the edges stay crisp.
        let mixing: CGFloat = sin(.pi * min(max(geometry.merge * 0.5 + geometry.grow * 0.5, 0), 1))
        let blur: CGFloat = goo * mixing
        return ZStack {
            Canvas { context, _ in
                for rect in geometry.dots {
                    context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(Color.primary.opacity(0.22)))
                }
            }
            .opacity(Double(1 - geometry.merge))
            LinearGradient(colors: [Palette.indigo, Palette.violet], startPoint: .leading, endPoint: .trailing)
                .mask {
                    Canvas { context, _ in
                        if blur > 0.3 {
                            context.addFilter(.alphaThreshold(min: 0.5, color: .white))
                            context.addFilter(.blur(radius: blur))
                        }
                        context.drawLayer { layer in
                            for rect in geometry.accent {
                                layer.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2, style: .continuous), with: .color(.white))
                            }
                        }
                    }
                }
                .shadow(color: Palette.indigo.opacity(0.4 * Double(geometry.grow)), radius: 12, y: 6)
            label(geometry)
        }
        .frame(width: size.width, height: size.height)
    }

    private func label(_ geometry: OnboardGeometry) -> some View {
        let reveal: CGFloat = OnboardMetrics.smooth(geometry.grow, 0.7, 1)
        return ZStack {
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                HStack(spacing: 6) {
                    Text(L("Get started", "开始使用"), language)
                        .font(.headline)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .foregroundStyle(Color.white)
        .opacity(Double(reveal))
        .scaleEffect((0.9 + 0.1 * reveal) * (1 + geometry.overshoot * 0.5))
    }
}
