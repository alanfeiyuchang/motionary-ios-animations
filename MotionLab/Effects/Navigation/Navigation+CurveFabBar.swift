import SwiftUI

extension Effect {
    static let navigationCurveFabBar = Effect(
        id: "navigation.curve-fab-bar",
        category: .navigation,
        interaction: .tap,
        name: L("Cradled FAB Bar", "凹槽悬浮按钮栏"),
        summary: L(
            "A centre button rests in a curved notch; tapped, it lifts out, the bar's edge heals flat with a wobble and three actions spiral out of it.",
            "中央按钮躺在弧形凹槽里；点击后它升起，标签栏边缘晃动着愈合成平线，三个操作从按钮里旋出。"
        ),
        prompt: L(
            "A 312 × 64 pt tab bar with two tabs on each side and a smooth 34 pt-deep notch in the middle of its top edge, cradling a 56 pt gradient button with a plus. Tapping it lifts the button 64 pt on a spring (response 0.45 s, damping 0.68) while the plus turns 135° into a cross and its shadow spreads. Freed of the weight, the notch closes on an under-damped spring (damping 0.42), so the edge bulges up once before lying flat. Three 48 pt action discs spiral out of the button to a radius of 86 pt, 45 ms apart, each sweeping 50° along an arc as it grows from 30% and overshoots. The page dims and blurs. Closing reverses it: discs fold in, the button drops, the notch re-forms a beat later and dips too deep, the bar bobs 4 pt, a medium haptic lands.",
            "312 × 64 pt 的标签栏左右各两个标签，顶边正中有一道深 34 pt 的平滑凹槽，托着一枚 56 pt 的渐变加号按钮。点击后，按钮以弹簧（响应 0.45 秒、阻尼 0.68）升起 64 pt，加号转过 135° 变成叉号，阴影散开。卸了重量的凹槽以欠阻尼弹簧（阻尼 0.42）闭合，边缘先向上鼓一下再躺平。三枚 48 pt 的操作圆片从按钮里旋出到 86 pt 半径，相隔 45 毫秒，各沿弧线扫过 50°，由 30% 长大过冲。关闭时原路返回：圆片收拢，按钮落下，凹槽晚一拍成形并陷得过深，标签栏下沉 4 pt，一记中等触感落地。"
        ),
        implementation: L(
            "The bar is a Shape whose notch depth is its animatableData; one Bool drives the button, the notch and the discs, each through its own animation(_:value:) spring and delay. Discs use an Animatable modifier that turns progress into a polar offset, so they travel on arcs.",
            "标签栏是一个以凹槽深度为 animatableData 的 Shape；同一个布尔值驱动按钮、凹槽与圆片，各自通过独立的 animation(_:value:) 弹簧与延迟。圆片使用 Animatable 修饰器把进度换算成极坐标偏移，因此沿弧线运动。"
        ),
        apis: ["Shape", "animatableData", "Animatable", "animation(_:value:)", "keyframeAnimator", "addCurve(to:control1:control2:)"],
        tags: ["tab bar", "FAB", "notch", "speed dial", "标签栏", "悬浮按钮", "凹槽", "快捷操作"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.8, default: 0.45, unit: "s"),
            .slider("depth", L("Notch depth", "凹槽深度"), 22...42, default: 34, decimals: 0, unit: "pt"),
            .slider("radius", L("Action radius", "操作半径"), 64...104, default: 86, decimals: 0, unit: "pt"),
            .slider("swirl", L("Arc sweep", "弧线扫角"), 0...110, default: 50, decimals: 0, unit: "°"),
        ]
    ) { ctx in
        CurveFabBarDemo(ctx: ctx)
    }
}

private let curveFabTabs: [String] = ["house.fill", "magnifyingglass", "bell.fill", "person.fill"]

private struct CurveFabAction {
    let symbol: String
    let title: LocalizedText
    let colors: [Color]
    /// Degrees, measured counter-clockwise from the positive x axis.
    let angle: CGFloat
}

private let curveFabActions: [CurveFabAction] = [
    CurveFabAction(symbol: "camera.fill", title: L("Camera", "拍摄"), colors: [Palette.pink, Palette.coral], angle: 152),
    CurveFabAction(symbol: "photo.fill", title: L("Photo", "照片"), colors: [Palette.amber, Palette.coral], angle: 90),
    CurveFabAction(symbol: "doc.text.fill", title: L("Note", "笔记"), colors: [Palette.mint, Palette.sky], angle: 28),
]

private struct CurveFabBarDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var open: Bool
    @State private var selected = 0
    @State private var landings = 0

    private let barWidth: CGFloat = 312
    private let barHeight: CGFloat = 64
    private let fabSize: CGFloat = 56
    private let liftHeight: CGFloat = 64

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the finished, opened state.
        _open = State(initialValue: ctx.isStill)
    }

    private var response: Double { ctx["response"] }

    var body: some View {
        VStack(spacing: 0) {
            NavigationScreenPlaceholder(rows: 3)
                .padding(.top, 22)
                .blur(radius: open ? 3 : 0)
                .opacity(open ? 0.45 : 1)
                .animation(.easeInOut(duration: 0.3), value: open)
            Spacer(minLength: 0)
            bar
            DemoHint(text: L("Tap the + button", "点击加号按钮"), ctx: ctx)
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if open { toggle() }
        }
        .autoplay(ctx.isPreview, every: 1.6) { toggle() }
    }

    // MARK: Bar

    private var bar: some View {
        ZStack(alignment: .top) {
            CurveFabBarShape(depth: open ? 0 : ctx.cg("depth"))
                .fill(Palette.elevated)
                .shadow(color: Color.black.opacity(0.14), radius: 16, y: 6)
                .animation(notchAnimation, value: open)
            tabs
            actions
            fab
        }
        .frame(width: barWidth, height: barHeight)
        // The landing: the whole bar dips as the button drops back into its cradle.
        .keyframeAnimator(initialValue: CGFloat(0), trigger: landings) { content, dip in
            content.offset(y: dip)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(0, duration: response * 0.45)
                CubicKeyframe(4, duration: 0.09)
                SpringKeyframe(0, duration: 0.45, spring: .bouncy)
            }
        }
        .padding(.bottom, ctx.isPreview || ctx.isStill ? 22 : 0)
    }

    /// Open: the freed edge snaps flat and wobbles. Close: the notch re-forms a beat after the button starts to fall.
    private var notchAnimation: Animation {
        open
            ? .spring(response: response * 0.9, dampingFraction: 0.42).delay(0.04)
            : .spring(response: response, dampingFraction: 0.45).delay(response * 0.25)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(0..<curveFabTabs.count, id: \.self) { index in
                if index == 2 {
                    Color.clear.frame(width: 96)
                }
                VStack(spacing: 5) {
                    Image(systemName: curveFabTabs[index])
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(index == selected ? Palette.indigo : Color.secondary)
                    ZStack {
                        if index == selected {
                            Circle()
                                .fill(Palette.indigo)
                                .matchedGeometryEffect(id: "dot", in: ns)
                        }
                    }
                    .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { select(index) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(width: barWidth, height: barHeight)
    }

    private var fab: some View {
        Button(action: toggle) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white)
                .rotationEffect(.degrees(open ? 135 : 0))
                .frame(width: fabSize, height: fabSize)
                .background(Palette.primary, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: Palette.indigo.opacity(open ? 0.5 : 0.35), radius: open ? 18 : 9, y: open ? 12 : 5)
        }
        .buttonStyle(.plain)
        .offset(y: restOffset - (open ? liftHeight : 0))
        .animation(
            open
                ? .spring(response: response, dampingFraction: 0.68)
                : .spring(response: response * 0.9, dampingFraction: 0.6),
            value: open
        )
    }

    /// The button's centre rests 4 pt above the bar's top edge, inside the notch.
    private var restOffset: CGFloat { -fabSize / 2 - 4 }

    private var actions: some View {
        ZStack {
            ForEach(0..<curveFabActions.count, id: \.self) { index in
                let action = curveFabActions[index]
                let delay: Double = open ? 0.06 + Double(index) * 0.045 : Double(curveFabActions.count - 1 - index) * 0.03
                CurveFabActionDisc(action: action, language: ctx.language)
                    .modifier(
                        CurveFabBloom(
                            progress: open ? 1 : 0,
                            angle: action.angle,
                            radius: ctx.cg("radius"),
                            swirl: ctx.cg("swirl")
                        )
                    )
                    .animation(
                        open
                            ? .spring(response: response, dampingFraction: 0.62).delay(delay)
                            : .spring(response: response * 0.7, dampingFraction: 0.9).delay(delay),
                        value: open
                    )
                    .onTapGesture { pick() }
            }
        }
        .frame(width: fabSize, height: fabSize)
        .offset(y: restOffset - liftHeight)
        .allowsHitTesting(open)
    }

    // MARK: Actions

    private func toggle() {
        let opening: Bool = !open
        let live: Bool = !ctx.isPreview && !Haptics.isMuted
        if !ctx.isPreview { Haptics.tap(.light) }
        open = opening
        guard !opening else { return }
        landings += 1
        let current = landings
        guard live else { return }
        // The haptic lands with the button, not on touch-down.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(response * 0.5))
            guard !Task.isCancelled, landings == current, !open else { return }
            Haptics.tap(.medium)
        }
    }

    private func pick() {
        if !ctx.isPreview { Haptics.success() }
        if open { toggle() }
    }

    private func select(_ index: Int) {
        if open {
            toggle()
            return
        }
        guard index != selected else { return }
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = index }
    }
}

private struct CurveFabActionDisc: View {
    let action: CurveFabAction
    let language: AppLanguage

    var body: some View {
        Image(systemName: action.symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 48, height: 48)
            .background(
                LinearGradient(colors: action.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: action.colors[0].opacity(0.4), radius: 10, y: 5)
            .overlay(alignment: .bottom) {
                Text(action.title, language)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(y: 17)
            }
            .contentShape(Circle())
    }
}

/// Turns progress into a polar offset: the disc leaves the centre along an arc, growing as it goes.
private struct CurveFabBloom: ViewModifier, Animatable {
    var progress: CGFloat
    let angle: CGFloat
    let radius: CGFloat
    let swirl: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let radians: CGFloat = (angle - swirl * (1 - progress)) * .pi / 180
        let distance: CGFloat = radius * progress
        let visible: CGFloat = min(max(progress * 1.8, 0), 1)
        content
            .scaleEffect(0.3 + 0.7 * max(progress, 0))
            .opacity(Double(visible))
            .offset(x: cos(radians) * distance, y: -sin(radians) * distance)
    }
}

private struct CurveFabBarShape: Shape {
    /// Notch depth in points. Negative values (spring overshoot) bulge the edge upward.
    var depth: CGFloat

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let corner: CGFloat = 24
        let half: CGFloat = 46
        let x: CGFloat = rect.midX
        let top: CGFloat = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: top + corner))
        path.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: top), control: CGPoint(x: rect.minX, y: top))
        path.addLine(to: CGPoint(x: x - half - 14, y: top))
        path.addCurve(
            to: CGPoint(x: x, y: top + depth),
            control1: CGPoint(x: x - half * 0.62, y: top),
            control2: CGPoint(x: x - half * 0.72, y: top + depth)
        )
        path.addCurve(
            to: CGPoint(x: x + half + 14, y: top),
            control1: CGPoint(x: x + half * 0.72, y: top + depth),
            control2: CGPoint(x: x + half * 0.62, y: top)
        )
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + corner), control: CGPoint(x: rect.maxX, y: top))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - corner, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - corner), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
