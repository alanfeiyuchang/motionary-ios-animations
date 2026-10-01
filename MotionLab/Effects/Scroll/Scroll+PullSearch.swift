import SwiftUI

extension Effect {
    static let scrollPullSearch = Effect(
        id: "scroll.pull-search",
        category: .scroll,
        interaction: .scroll,
        name: L("Pull-to-Reveal Search", "下拉展开搜索"),
        summary: L("Pulling the list down draws the magnifier out of the nav bar into a full search field; scrolling up tucks it back.", "下拉列表时，放大镜图标从导航栏里被拉成一整条搜索框；向上滚动又收回去。"),
        prompt: L(
            "A list under a 48 pt nav bar with a large title and a 34 pt round magnifier button at the trailing edge. Pulling the list down scrubs a morph: over 62 pt of pull the button itself stretches leftward and drops below the bar into a full-width 40 pt capsule field, its glyph sliding to the leading edge while the placeholder and a mic icon fade in during the last 45%. Pulling further rubber-bands the field a few percent taller, with one tick as the threshold is crossed. Releasing past it latches the field open: the list springs down 52 pt (response 0.42 s, damping 0.72) to make room. Scrolling up 24 pt tucks it away: the capsule contracts back into the bar button on the same spring. Tapping the button toggles it. Direct and elastic.",
            "列表上方是48 pt高的导航栏，左侧大标题，右端一枚34 pt的圆形放大镜按钮。下拉列表会连续驱动一段形变：在62 pt的行程内，按钮本身向左拉长并落到导航栏下方，变成一条通栏、40 pt高的胶囊搜索框，放大镜滑到最左侧，占位文字与麦克风图标在最后45%里淡入。继续下拉，搜索框像橡皮筋一样略微增高，越过阈值的瞬间有一次触感。超过阈值松手即锁定展开：列表以弹簧（响应0.42秒、阻尼0.72）下移52 pt让出位置。向上滚动24 pt即收起：胶囊以同一弹簧缩回导航栏按钮。点击按钮也可切换。"
        ),
        implementation: L(
            "The overscroll from onScrollGeometryChange (or, when the list is nested in another scroll view, a downward UIKit pan that the page scroll waits for) gives a 0…1 pull progress; the capsule's frame is interpolated between the button's rect and the field's rect. The release latches an open amount with a spring, which also adds top padding to the list; scrolling past 24 pt releases it.",
            "onScrollGeometryChange 给出的越界量（列表嵌在另一个滚动视图里时，则是一个让页面滚动等待的向下 UIKit 平移手势）换算成 0…1 的下拉进度；胶囊的位置和尺寸在按钮矩形与搜索框矩形之间插值。松手时用弹簧把展开量锁定为 1，同时给列表增加顶部留白；向上滚过 24 pt 时解除锁定。"
        ),
        apis: ["onScrollGeometryChange", "onScrollPhaseChange", "UIGestureRecognizerRepresentable", "ScrollPosition", "spring(response:dampingFraction:)"],
        tags: ["search", "pull down", "nav bar", "reveal", "morph", "搜索", "下拉", "导航栏", "展开", "形变"],
        params: [
            .slider("threshold", L("Pull threshold", "下拉阈值"), 40...100, default: 62, step: 1, decimals: 0, unit: "pt"),
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.7, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.72),
        ]
    ) { ctx in
        ScrollPullSearchDemo(ctx: ctx)
    }
}

private let scrollPullBar: CGFloat = 48
/// Room the open field takes below the bar.
private let scrollPullSlot: CGFloat = 52

private struct ScrollPullSearchDemo: View {
    let ctx: DemoContext
    @State private var position = ScrollPosition(edge: .top)
    @State private var offset: CGFloat = 0
    /// 1 while the field is latched open (animated by the spring).
    @State private var openAmount: CGFloat
    @State private var isOpen: Bool
    /// Simulated overscroll, used by the autoplay only.
    @State private var simulatedPull: CGFloat = 0
    /// The finger's pull at the top edge (see `ScrollTopPull`).
    @State private var fingerPull: CGFloat = 0
    @State private var width: CGFloat = 340
    @State private var step = 0
    @State private var pullTask: Task<Void, Never>?

    private var threshold: CGFloat { max(ctx.cg("threshold"), 1) }
    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var pull: CGFloat { max(-offset, 0) + simulatedPull + fingerPull }

    /// A still shows the field open, which is the state that explains the effect.
    init(ctx: DemoContext) {
        self.ctx = ctx
        _openAmount = State(initialValue: ctx.isStill ? 1 : 0)
        _isOpen = State(initialValue: ctx.isStill)
    }

    var body: some View {
        let live: CGFloat = min(pull / threshold, 1)
        let progress: CGFloat = max(openAmount, live)
        // Past the threshold the field rubber-bands a little taller.
        let over: CGFloat = isOpen ? 0 : rubberBand(max(pull - threshold, 0), limit: 60)
        ScrollView {
            VStack(spacing: 10) {
                ForEach(0..<14, id: \.self) { i in
                    ScrollKitRow(index: i + 5, language: ctx.language)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, scrollPullBar + 8 + scrollPullSlot * openAmount + simulatedPull + fingerPull)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        }, action: { _, newValue in
            track(newValue)
        })
        .onScrollPhaseChange { oldPhase, newPhase in
            if oldPhase == .interacting && newPhase != .interacting { release() }
        }
        .modifier(
            ScrollTopPull(
                isEnabled: !ctx.isPreview && !isOpen && offset <= 0.5,
                pull: $fingerPull,
                onRelease: { release() }
            )
        )
        .onChange(of: pull >= threshold) { _, past in
            // One tick as the pull crosses the threshold (never for the scripted pull).
            if past && !isOpen && !ctx.isPreview && simulatedPull == 0 { Haptics.tap(.light) }
        }
        .overlay(alignment: .top) {
            ScrollPullSearchBar(
                progress: progress,
                stretch: over,
                scrolled: offset > 4,
                width: width,
                // The detail stage keeps its Reset button in the top-trailing corner.
                trailingInset: ctx.isPreview ? 16 : 58,
                language: ctx.language,
                toggle: { setOpen(!isOpen, haptic: true) }
            )
        }
        .overlay(alignment: .bottom) {
            DemoHint(text: isOpen ? L("Scroll up to tuck it away", "向上滚动即可收起") : L("Pull the list down", "向下拉动列表"), ctx: ctx)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .demoGlass(Capsule(), material: .regularMaterial)
                .overlay(Capsule().strokeBorder(Palette.stroke))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .padding(.bottom, 10)
                .opacity(ctx.isPreview ? 0 : 1)
                .allowsHitTesting(false)
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self, of: { proxy in proxy.size.width }, action: { newWidth in
            width = newWidth
        })
        .onDisappear { pullTask?.cancel() }
        .autoplay(ctx.isPreview, every: 1.5) { autoStep() }
    }

    private func track(_ newOffset: CGFloat) {
        offset = newOffset
        // Scrolling up into the content tucks the field away.
        if isOpen && newOffset > 24 { setOpen(false, haptic: false) }
    }

    /// The finger let go (or the autoplay's simulated pull ended): latch open past the threshold.
    private func release(haptic: Bool = true) {
        guard !isOpen, pull >= threshold else { return }
        setOpen(true, haptic: haptic)
    }

    private func setOpen(_ open: Bool, haptic: Bool) {
        isOpen = open
        if haptic { Haptics.tap(open ? .medium : .light) }
        withAnimation(spring) { openAmount = open ? 1 : 0 }
    }

    private func autoStep() {
        switch step % 3 {
        case 0:
            // Pull, hold a beat, let go: one whole gesture per action, so the detail page's intro play
            // never leaves the list half-pulled.
            let spring = self.spring
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { simulatedPull = threshold + 18 }
            pullTask?.cancel()
            pullTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                release(haptic: false)
                withAnimation(spring) { simulatedPull = 0 }
            }
        case 1:
            withAnimation(.smooth(duration: 0.9)) { position.scrollTo(y: 190) }
        default:
            withAnimation(.smooth(duration: 0.9)) { position.scrollTo(y: 0) }
        }
        step += 1
    }
}

private struct ScrollPullSearchBar: View {
    /// 0 = round button in the bar, 1 = full-width field below it.
    let progress: CGFloat
    let stretch: CGFloat
    let scrolled: Bool
    let width: CGFloat
    let trailingInset: CGFloat
    let language: AppLanguage
    let toggle: () -> Void

    var body: some View {
        let p = progress
        let button = CGRect(x: width - trailingInset - 34, y: 7, width: 34, height: 34)
        let field = CGRect(x: 16, y: scrollPullBar + 4, width: max(width - 32, 34), height: 40 + stretch * 0.3)
        // The capsule first drops and widens together; the drop finishes a little earlier.
        let drop: CGFloat = ScrollMath.smooth(ScrollMath.unit(p, 0, 0.8))
        let rect = CGRect(
            x: ScrollMath.lerp(button.minX, field.minX, p),
            y: ScrollMath.lerp(button.minY, field.minY, drop),
            width: ScrollMath.lerp(button.width, field.width, p),
            height: ScrollMath.lerp(button.height, field.height, p)
        )
        ZStack(alignment: .topLeading) {
            bar(p)
            capsule(rect: rect, p: p)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: scrollPullBar + scrollPullSlot * p, alignment: .top)
    }

    private func bar(_ p: CGFloat) -> some View {
        HStack {
            Text(L("Notes", "备忘录"), language)
                .font(.title3.weight(.bold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: scrollPullBar)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            DemoMaterial(Rectangle(), material: .regularMaterial)
                .frame(height: scrollPullBar + scrollPullSlot * p)
                .opacity(scrolled ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: scrolled)
        }
        .allowsHitTesting(false)
    }

    private func capsule(rect: CGRect, p: CGFloat) -> some View {
        let reveal: Double = Double(ScrollMath.unit(p, 0.55, 1))
        // The glyph starts centred in the round button and slides to the field's leading inset.
        let glyphX: CGFloat = ScrollMath.lerp((34 - 16) / 2, 13, p)
        return Button(action: toggle) {
            Capsule()
                .fill(Palette.elevated)
                .overlay(alignment: .leading) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.primary)
                        .frame(width: 16)
                        .offset(x: glyphX)
                }
                .overlay(alignment: .leading) {
                    Text(L("Search notes", "搜索备忘录"), language)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .opacity(reveal)
                        .offset(x: 38 + CGFloat(1 - reveal) * 10)
                }
                .overlay(alignment: .trailing) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .opacity(reveal)
                        .scaleEffect(0.6 + 0.4 * reveal)
                        .padding(.trailing, 13)
                }
                .frame(width: rect.width, height: rect.height)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                .contentShape(Capsule())
                .shadow(color: .black.opacity(0.1 * Double(p)), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .offset(x: rect.minX, y: rect.minY)
    }
}
