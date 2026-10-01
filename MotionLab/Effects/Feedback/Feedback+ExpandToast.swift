import SwiftUI

// MARK: - Expand toast

extension Effect {
    static let feedbackExpandToast = Effect(
        id: "feedback.expand-toast",
        category: .feedback,
        interaction: .tap,
        name: L("Expanding Detail Toast", "可展开详情吐司"),
        summary: L("A compact toast that grows into a detail card in place: the header stays put, the details cascade in, and the page steps back.", "紧凑吐司原地长成详情卡片：标题行不动，详情逐行落位，页面随之后退。"),
        prompt: L(
            "A dark 236 × 54 pt toast with a 27 pt corner radius sits at the top of a page: an amber plane tile, 'Delayed 45 min' and a chevron. Tapping it expands the same surface to 272 × 212 pt on a spring (response 0.5 s, damping 0.78); the corners ease to 26 pt, the tile grows from 32 to 38 pt and the chevron turns 180°. The header keeps its place while the details arrive beneath it 80 ms later, staggered 50 ms: a route line along which a small plane slides to 38%, three fact tiles (the old departure time struck through, the new one in amber), then two buttons. Each rises 12 pt out of a 6 pt blur. Behind, the page scales to 96% and dims 18%. Tapping again fades the details in 0.15 s and the surface springs closed.",
            "页面顶部一条深色吐司，236 × 54 pt、圆角 27 pt：琥珀色飞机方块、“航班延误 45 分钟”和箭头。点击后同一块表面以弹簧（响应 0.5 秒、阻尼 0.78）展开到 272 × 212 pt，圆角收到 26 pt，方块从 32 pt 长到 38 pt，箭头转 180°。详情 80 毫秒后依次到达，间隔 50 毫秒：航线上小飞机滑到 38% 处，三个信息块（原起飞时间划掉、新时间为琥珀色），再是两枚按钮；每项上浮 12 pt 并从 6 pt 模糊中清晰。背后页面缩到 96%、压暗 18%。再次点击，详情 0.15 秒淡出，表面弹回收起。"
        ),
        implementation: L(
            "One surface with an explicit frame and corner radius animated by a value-keyed spring; the details live in the same ZStack the whole time and are revealed by per-index delayed springs on opacity, offset and blur, so nothing is inserted or replaced. The plane's position on the route is an offset on the same flag.",
            "同一块表面的尺寸与圆角由按值触发的弹簧驱动；详情始终留在同一个 ZStack 里，通过按序号递增延迟的弹簧改变透明度、位移与模糊来揭示，因此没有任何视图被插入或替换。航线上飞机的位置是同一标志驱动的 offset。"
        ),
        apis: ["animation(_:value:)", "spring(response:dampingFraction:)", "clipShape", "blur(radius:)", "keyframeAnimator(initialValue:trigger:)"],
        tags: ["toast", "expand", "details", "in place", "吐司", "展开", "详情", "原地形变"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.78),
            .slider("stagger", L("Detail stagger", "详情间隔"), 0.0...0.14, default: 0.05, unit: "s"),
        ]
    ) { ctx in
        ExpandToastDemo(ctx: ctx)
    }
}

private struct ExpandToastDemo: View {
    let ctx: DemoContext
    @State private var expanded: Bool
    @State private var presses = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the expanded card.
        _expanded = State(initialValue: ctx.isStill)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                page
                toast
                    .padding(.top, 14)
            }
            .feedbackScene(height: 270)
            DemoHint(text: L("Tap the toast", "点击吐司"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.4, delay: 0.8) { toggle() }
    }

    private var page: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 76)
            FeedbackMockRows(count: 4, rowHeight: 46)
            Spacer(minLength: 0)
        }
        .frame(width: 300, height: 270)
        .scaleEffect(expanded ? 0.96 : 1)
        .overlay(Color.black.opacity(expanded ? 0.18 : 0))
        .animation(spring, value: expanded)
    }

    // MARK: Toast

    private var toast: some View {
        let width: CGFloat = expanded ? 272 : 236
        let height: CGFloat = expanded ? 212 : 54
        let shape = RoundedRectangle(cornerRadius: expanded ? 26 : 27, style: .continuous)
        return ZStack(alignment: .top) {
            details
                .padding(.top, 62)
            header
        }
        .frame(width: width, height: height, alignment: .top)
        .background {
            shape.fill(LinearGradient(colors: [Color(hex: 0x25252C), Color(hex: 0x151519)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(expanded ? 0.34 : 0.24), radius: expanded ? 22 : 12, y: expanded ? 12 : 6)
        .animation(spring, value: expanded)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: presses) { content, squeeze in
            content.scaleEffect(squeeze)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(0.965, duration: 0.09)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
        }
        .contentShape(shape)
        .onTapGesture { toggle() }
    }

    private var header: some View {
        let tile: CGFloat = expanded ? 38 : 32
        return HStack(spacing: 11) {
            Image(systemName: "airplane")
                .font(.system(size: expanded ? 17 : 14, weight: .bold))
                .foregroundStyle(Color(hex: 0x3A2300))
                .frame(width: tile, height: tile)
                .background(
                    LinearGradient(colors: [Color(hex: 0xFFD56B), Palette.amber], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: expanded ? 12 : 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(zh ? "航班延误 45 分钟" : "Delayed 45 min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(zh ? "ML 837 · 旧金山 → 东京" : "ML 837 · SFO → NRT")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.1), in: Circle())
                .rotationEffect(.degrees(expanded ? 180 : 0))
        }
        .padding(.leading, expanded ? 14 : 11)
        .padding(.trailing, 14)
        // Explicit width: the ZStack is as wide as the (always present) details, not as the compact toast.
        .frame(width: expanded ? 272 : 236, height: expanded ? 62 : 54)
    }

    private var details: some View {
        VStack(spacing: 12) {
            route
                .modifier(reveal(0))
            HStack(spacing: 8) {
                fact(label: zh ? "起飞" : "Dep", old: "18:40", value: "19:25", highlight: true)
                fact(label: zh ? "登机口" : "Gate", old: nil, value: "B7", highlight: false)
                fact(label: zh ? "座位" : "Seat", old: nil, value: "24A", highlight: false)
            }
            .modifier(reveal(1))
            HStack(spacing: 8) {
                Text(zh ? "改签" : "Rebook")
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(.white, in: Capsule())
                Text(zh ? "知道了" : "Got it")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.13), in: Capsule())
            }
            .font(.footnote.weight(.semibold))
            .modifier(reveal(2))
        }
        .padding(.horizontal, 14)
        .frame(width: 272)
        .allowsHitTesting(false)
    }

    private var route: some View {
        let track: CGFloat = 150
        return HStack(spacing: 10) {
            Text(verbatim: "SFO")
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: track, height: 3)
                Capsule()
                    .fill(Palette.amber)
                    .frame(width: expanded ? track * 0.38 : 0, height: 3)
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.amber)
                    .frame(width: 16, height: 16)
                    .offset(x: (expanded ? track * 0.38 : 0) - 4)
            }
            .frame(width: track, height: 16)
            .animation(expanded ? Animation.spring(response: 0.9, dampingFraction: 0.85).delay(0.18) : Animation.easeOut(duration: 0.15), value: expanded)
            Text(verbatim: "NRT")
        }
        .font(.caption.weight(.bold).monospaced())
        .foregroundStyle(.white.opacity(0.75))
        .frame(height: 20)
    }

    private func fact(label: String, old: String?, value: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(verbatim: label)
                if let old {
                    Text(verbatim: old)
                        .monospacedDigit()
                        .strikethrough()
                }
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
            Text(verbatim: value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(highlight ? Palette.amber : .white)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 46)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func reveal(_ index: Int) -> ExpandToastReveal {
        let rise = Animation.spring(response: ctx["response"] * 0.9, dampingFraction: 0.82).delay(0.08 + Double(index) * ctx["stagger"])
        return ExpandToastReveal(shown: expanded, animation: expanded ? rise : Animation.easeOut(duration: 0.15))
    }

    private func toggle() {
        Haptics.tap()
        presses += 1
        expanded.toggle()
    }
}

/// A detail row rising out of a blur once the toast is open.
private struct ExpandToastReveal: ViewModifier {
    let shown: Bool
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .blur(radius: shown ? 0 : 6)
            .animation(animation, value: shown)
    }
}
