import SwiftUI

extension Effect {
    static let scrollTopFabRing = Effect(
        id: "scroll.top-fab-ring",
        category: .scroll,
        interaction: .scroll,
        name: L("Back-to-Top Ring Button", "回到顶部进度环按钮"),
        summary: L("A floating button pops in once you have scrolled, wears your progress as a ring, and launches you back to the top while the ring unwinds.", "滚动一段后弹出的悬浮按钮，用一圈圆环显示进度；点一下把你送回顶部，圆环随之倒转收回。"),
        prompt: L(
            "A feed scrolls under a 52 pt round glass button in the bottom-right corner. The button is absent at the top; after 120 pt of scroll it pops in, rising 18 pt while scaling from 40% on a bouncy spring (response 0.4 s, damping 0.6). A 3.5 pt gradient ring around it traces reading progress clockwise from 12 o'clock, with a glowing dot riding its tip, and while the list is moving a small percentage chip slides out to its left. Tapping it gives a medium haptic: the button dips to 86%, its arrow shoots up out of the circle and a fresh one rises from below, and the feed glides to the top in 0.9 s, so the ring visibly unwinds counter-clockwise. Near the top the button shrinks away. A tidy loop: appear, measure, launch, vanish.",
            "信息流在右下角一枚52 pt的圆形玻璃按钮下方滚动。在顶部时按钮不存在；滚动超过120 pt后才弹出，一边上升18 pt，一边从40%以带弹跳的弹簧（响应0.4秒、阻尼0.6）放大到位。按钮外围是一圈3.5 pt粗的渐变圆环，从12点方向顺时针描出阅读进度，末端带一颗发光小点；列表在动时，左侧还会滑出一枚百分比标签。点击有一次中等力度的触感：按钮下压到86%，箭头向上射出圆圈，新箭头从下方升起，信息流在0.9秒内滑回顶部，圆环随之逆时针倒转。接近顶部时按钮缩小消失。"
        ),
        implementation: L(
            "onScrollGeometryChange reports the offset and the 0…1 progress; the button is inserted with a spring transition past the threshold and its ring is a trimmed Circle. A keyframeAnimator triggered by the tap plays the press dip and the arrow hand-off, and ScrollPosition.scrollTo(edge: .top) inside a timed animation drives the unwinding.",
            "onScrollGeometryChange 报告偏移量和 0…1 的进度；越过阈值后按钮通过弹簧转场插入，圆环是 trim 过的 Circle。点击触发的 keyframeAnimator 播放下压与箭头交接，定时动画里的 ScrollPosition.scrollTo(edge: .top) 带动圆环倒转。"
        ),
        apis: ["onScrollGeometryChange", "onScrollPhaseChange", "ScrollPosition", "keyframeAnimator", "Circle().trim", "transition"],
        tags: ["back to top", "FAB", "progress ring", "scroll to top", "floating button", "回到顶部", "悬浮按钮", "进度环", "返回顶部", "阅读进度"],
        params: [
            .slider("threshold", L("Appear after", "出现阈值"), 40...300, default: 120, step: 10, decimals: 0, unit: "pt"),
            .slider("thickness", L("Ring thickness", "圆环粗细"), 2...6, default: 3.5, step: 0.5, decimals: 1, unit: "pt"),
            .slider("duration", L("Return time", "返回时长"), 0.4...1.6, default: 0.9, unit: "s"),
        ]
    ) { ctx in
        ScrollTopFabDemo(ctx: ctx)
    }
}

private struct ScrollTopFabMetrics: Equatable {
    var offset: CGFloat = 0
    var progress: Double = 0
}

private struct ScrollTopFabDemo: View {
    let ctx: DemoContext
    @State private var position = ScrollPosition(edge: .top)
    @State private var metrics: ScrollTopFabMetrics
    @State private var moving = false
    @State private var launches = 0
    @State private var step = 0

    /// A still shows the button mid-read, which is the state that explains the effect.
    init(ctx: DemoContext) {
        self.ctx = ctx
        _metrics = State(initialValue: ctx.isStill ? ScrollTopFabMetrics(offset: 400, progress: 0.62) : ScrollTopFabMetrics())
    }

    var body: some View {
        let visible = metrics.offset > ctx.cg("threshold")
        ScrollView {
            ScrollTopFabFeed(language: ctx.language)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: ScrollTopFabMetrics.self, of: { geometry in
            let offset = geometry.contentOffset.y + geometry.contentInsets.top
            let range = geometry.contentSize.height - geometry.containerSize.height
            let progress = range > 0 ? Double(offset / range).clamped(to: 0...1) : 0
            return ScrollTopFabMetrics(offset: offset, progress: progress)
        }, action: { _, newValue in
            // A still keeps its seeded mid-read state.
            guard !ctx.isStill else { return }
            metrics = newValue
        })
        .onScrollPhaseChange { _, newPhase in
            moving = newPhase != .idle
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 8) {
                if visible && (moving || ctx.isStill) {
                    ScrollTopFabChip(progress: metrics.progress)
                        .transition(.move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.8, anchor: .trailing)))
                }
                if visible {
                    ScrollTopFabButton(
                        progress: metrics.progress,
                        thickness: ctx.cg("thickness"),
                        launches: launches,
                        action: launch
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.4).combined(with: .offset(y: 18)).combined(with: .opacity),
                            removal: .scale(scale: 0.3).combined(with: .opacity)
                        )
                    )
                }
            }
            .padding(16)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: visible)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: moving)
        }
        .autoplay(ctx.isPreview, every: 1.5) { autoStep() }
    }

    /// Tap (and the autoplay's simulated tap): fire the arrow and glide the feed back to the top.
    private func launch() {
        Haptics.tap(.medium)
        launches += 1
        // A timed curve (not a spring) so the glide ends exactly on schedule and the ring unwinds evenly.
        withAnimation(.easeInOut(duration: ctx["duration"])) {
            position.scrollTo(y: 0)
        }
    }

    private func autoStep() {
        switch step % 4 {
        case 0:
            withAnimation(.easeInOut(duration: 1.0)) { position.scrollTo(y: 420) }
        case 1:
            withAnimation(.easeInOut(duration: 1.0)) { position.scrollTo(y: 980) }
        case 2:
            launch()
        default:
            break
        }
        step += 1
    }
}

private struct ScrollTopFabArrow {
    var press: CGFloat = 1
    var offset: CGFloat = 0
    var opacity: Double = 1
}

private struct ScrollTopFabButton: View {
    let progress: Double
    let thickness: CGFloat
    let launches: Int
    let action: () -> Void

    private let gradient = AngularGradient(
        colors: [Palette.mint, Palette.sky, Palette.violet, Palette.pink],
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: thickness)
                Circle()
                    .trim(from: 0, to: max(progress, 0.001))
                    .stroke(gradient, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                // The glowing tip of the ring.
                Circle()
                    .fill(Color.white)
                    .frame(width: thickness + 1.5, height: thickness + 1.5)
                    .shadow(color: Palette.pink.opacity(0.9), radius: 5)
                    .offset(y: -22)
                    .rotationEffect(.degrees(360 * progress))
                    .opacity(progress > 0.01 ? 1 : 0)
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.primary)
                    .keyframeAnimator(initialValue: ScrollTopFabArrow(), trigger: launches) { content, value in
                        content
                            .offset(y: value.offset)
                            .opacity(value.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.offset) {
                            CubicKeyframe(-26, duration: 0.18)
                            MoveKeyframe(26)
                            SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(0, duration: 0.18)
                            LinearKeyframe(0, duration: 0.04)
                            LinearKeyframe(1, duration: 0.2)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
            }
            .frame(width: 44, height: 44)
            .padding(4)
            .demoGlass(Circle(), material: .regularMaterial)
            .overlay(Circle().strokeBorder(Palette.stroke))
            .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: 1.0, trigger: launches) { content, value in
            content.scaleEffect(value)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0.86, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
            }
        }
    }
}

/// "42%" chip that keeps the button company while the feed is moving.
private struct ScrollTopFabChip: View {
    let progress: Double

    var body: some View {
        let percent = Int((progress * 100).rounded())
        Text(verbatim: "\(percent)%")
            .font(.caption.weight(.bold).monospacedDigit())
            .contentTransition(.numericText(value: Double(percent)))
            .animation(.snappy(duration: 0.2), value: percent)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .demoGlass(Capsule(), material: .regularMaterial)
            .overlay(Capsule().strokeBorder(Palette.stroke))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

/// A photo feed: a headline, then cards of artwork with a caption line.
private struct ScrollTopFabFeed: View {
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Field Journal", "野外手记"), language)
                    .font(.title2.weight(.bold))
                Text(L("12 entries this month", "本月 12 篇"), language)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(0..<12, id: \.self) { i in
                if i % 3 == 0 {
                    ScrollKitArt(index: i + 2, language: language)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    ScrollKitRow(index: i + 2, language: language)
                }
            }
        }
    }
}
