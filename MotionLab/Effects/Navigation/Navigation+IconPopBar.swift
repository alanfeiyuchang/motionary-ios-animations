import SwiftUI

extension Effect {
    static let navigationIconPopBar = Effect(
        id: "navigation.icon-pop-bar",
        category: .navigation,
        interaction: .tap,
        name: L("Character Icon Tab Bar", "性格图标标签栏"),
        summary: L(
            "Every tab icon has its own way of saying \"selected\": the house jumps, the compass spins, the heart beats twice, the bell swings and the plane flies off and comes back.",
            "每个标签图标都有自己的「被选中」方式：房子起跳、指南针旋转、心跳两下、铃铛摇摆、纸飞机飞出去再飞回来。"
        ),
        prompt: L(
            "A five-tab bar where selection is acted out per icon instead of sharing one indicator. On tap the outline symbol is replaced by its filled variant in the tab's own colour, the label takes that colour, and eight small dots burst 26 pt outward from behind the icon, shrinking and fading over 0.55 s. Then each icon performs: the house squashes to 72%, jumps 14 pt with a stretch and lands with a second squash; the compass turns a full 360° on an underdamped spring; the heart beats twice (130%, then 118%); the bell swings from its top through 24°, −20°, 14°, −8°; the paper plane flies 18 pt up and away while fading, then re-enters from the opposite corner on a bouncy spring. All run on keyframe tracks of roughly 0.6 s, with a light haptic on tap. Playful, yet each motion says what the icon is.",
            "五标签的标签栏，选中不靠共用指示器，而是每个图标自己演出来。点击后，线框符号替换为该标签专属颜色的填充版本，文字变色，八颗小圆点从图标背后迸出 26 pt，在 0.55 秒内缩小淡出。随后各显性格：房子压扁到 72%，拉长着跳起 14 pt，落地再压一下；指南针用欠阻尼弹簧转满 360°；心跳两下（130%，再 118%）；铃铛绕顶端摆过 24°、−20°、14°、−8°；纸飞机向右上飞出 18 pt 并淡出，再从对角弹回。均由约 0.6 秒的关键帧轨道驱动，点击有轻触感。俏皮，却都在说明图标是什么。"
        ),
        implementation: L(
            "Each icon is wrapped in its own keyframeAnimator, triggered by a per-tab counter, with separate tracks for squash, offset, rotation and opacity; the particle burst is a KeyframeAnimator that maps one 0→1 value to dot radius, size and alpha.",
            "每个图标各自包在一个 keyframeAnimator 里，由每个标签的计数器触发，压缩、位移、旋转与透明度分别走独立轨道；粒子迸发是一个 KeyframeAnimator，把 0→1 的单一数值映射为圆点的半径、大小与透明度。"
        ),
        apis: ["keyframeAnimator(initialValue:trigger:)", "KeyframeTrack", "SpringKeyframe", "symbolVariant", "contentTransition(.symbolEffect(.replace))"],
        tags: ["tab bar", "icon animation", "keyframes", "particles", "标签栏", "图标动画", "关键帧", "粒子"],
        params: [
            .slider("amount", L("Motion amount", "动作幅度"), 0.3...1.6, default: 1.0),
            .slider("particles", L("Particles", "粒子数量"), 0...14, default: 8, step: 1, decimals: 0),
            .slider("speed", L("Speed", "速度"), 0.5...2.0, default: 1.0, unit: "×"),
        ]
    ) { ctx in
        IconPopBarDemo(ctx: ctx)
    }
}

private struct PopTab {
    let symbol: String
    let label: LocalizedText
    let color: Color
}

private let popTabs: [PopTab] = [
    PopTab(symbol: "house", label: L("Home", "首页"), color: Palette.indigo),
    PopTab(symbol: "safari", label: L("Explore", "探索"), color: Palette.mint),
    PopTab(symbol: "heart", label: L("Likes", "喜欢"), color: Palette.pink),
    PopTab(symbol: "bell", label: L("Alerts", "通知"), color: Palette.amber),
    PopTab(symbol: "paperplane", label: L("Inbox", "私信"), color: Palette.sky),
]

private struct PopPose {
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var x: CGFloat = 0
    var y: CGFloat = 0
    var angle: Double = 0
    var opacity: Double = 1
}

private struct IconPopBarDemo: View {
    let ctx: DemoContext
    @State private var selection = 0
    @State private var pops: [Int] = Array(repeating: 0, count: popTabs.count)

    var body: some View {
        VStack(spacing: 14) {
            screen
            DemoHint(text: L("Tap each tab", "逐个点击标签"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.2) { select((selection + 1) % popTabs.count) }
    }

    private var screen: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            bar
        }
        .padding(12)
        .frame(width: 300, height: 284)
        .background(Palette.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(popTabs[selection].label, ctx.language)
                .font(.title2.weight(.bold))
                .id(selection)
                .transition(.blurReplace)
                .padding(.leading, 6)
                .padding(.top, 8)
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(popTabs[selection].color.opacity(row == 0 ? 0.32 : 0.18))
                        .frame(width: 36, height: 36)
                    PlaceholderLines(count: 2, color: Color.primary.opacity(0.09))
                }
                .padding(.horizontal, 10)
                .frame(height: 54)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(0..<popTabs.count, id: \.self) { index in
                tabButton(index)
            }
        }
        .frame(height: 64)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.stroke))
    }

    private func tabButton(_ index: Int) -> some View {
        let tab: PopTab = popTabs[index]
        let active: Bool = selection == index
        let tint: Color = active ? tab.color : Color.secondary
        return VStack(spacing: 4) {
            ZStack {
                PopBurst(trigger: pops[index], count: ctx.int("particles"), color: tab.color, speed: ctx["speed"])
                PopIcon(index: index, trigger: pops[index], amount: ctx.cg("amount"), speed: ctx["speed"]) {
                    Image(systemName: tab.symbol)
                        .symbolVariant(active ? .fill : .none)
                        .font(.system(size: 21, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(tint)
                        .frame(width: 30, height: 28)
                }
            }
            .frame(height: 30)
            Text(tab.label, ctx.language)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { select(index) }
    }

    private func select(_ index: Int) {
        if !ctx.isPreview { Haptics.tap(.light) }
        pops[index] += 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = index }
    }
}

// MARK: - Icon performances

private extension View {
    /// Applies a keyframed pose (callable from the animator's nonisolated content closure).
    nonisolated func popPosed(_ pose: PopPose, anchor: UnitPoint) -> some View {
        self
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: anchor)
            .rotationEffect(.degrees(pose.angle), anchor: anchor)
            .offset(x: pose.x, y: pose.y)
            .opacity(pose.opacity)
    }
}

/// Plays the icon's own keyframe routine every time `trigger` changes.
private struct PopIcon<Content: View>: View {
    let index: Int
    let trigger: Int
    let amount: CGFloat
    let speed: Double
    @ViewBuilder let content: Content

    private var unit: Double { 1 / max(speed, 0.1) }

    var body: some View {
        switch index {
        case 0: house
        case 1: compass
        case 2: heart
        case 3: bell
        default: plane
        }
    }

    /// Squash, jump with a stretch, land with a second squash.
    private var house: some View {
        let a: CGFloat = amount
        let u: Double = unit
        return content.keyframeAnimator(initialValue: PopPose(), trigger: trigger) { view, pose in
            view.popPosed(pose, anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack(\.scaleY) {
                CubicKeyframe(1 - 0.28 * a, duration: 0.1 * u)
                CubicKeyframe(1 + 0.18 * a, duration: 0.14 * u)
                CubicKeyframe(1, duration: 0.14 * u)
                CubicKeyframe(1 - 0.16 * a, duration: 0.08 * u)
                SpringKeyframe(1, duration: 0.3 * u, spring: .bouncy)
            }
            KeyframeTrack(\.scaleX) {
                CubicKeyframe(1 + 0.2 * a, duration: 0.1 * u)
                CubicKeyframe(1 - 0.1 * a, duration: 0.14 * u)
                CubicKeyframe(1, duration: 0.14 * u)
                CubicKeyframe(1 + 0.12 * a, duration: 0.08 * u)
                SpringKeyframe(1, duration: 0.3 * u, spring: .bouncy)
            }
            KeyframeTrack(\.y) {
                CubicKeyframe(0, duration: 0.1 * u)
                CubicKeyframe(-14 * a, duration: 0.16 * u)
                CubicKeyframe(0, duration: 0.14 * u)
            }
        }
    }

    /// One full turn on an underdamped spring, with a small swell.
    private var compass: some View {
        let a: CGFloat = amount
        let u: Double = unit
        return content.keyframeAnimator(initialValue: PopPose(), trigger: trigger) { view, pose in
            view.popPosed(pose, anchor: .center)
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                SpringKeyframe(360, duration: 0.75 * u, spring: Spring(response: 0.45 * u, dampingRatio: 0.55))
                MoveKeyframe(0)
            }
            KeyframeTrack(\.scaleX) {
                CubicKeyframe(1 + 0.16 * a, duration: 0.18 * u)
                SpringKeyframe(1, duration: 0.4 * u, spring: .bouncy)
            }
            KeyframeTrack(\.scaleY) {
                CubicKeyframe(1 + 0.16 * a, duration: 0.18 * u)
                SpringKeyframe(1, duration: 0.4 * u, spring: .bouncy)
            }
        }
    }

    /// Two beats: a big one and a smaller echo.
    private var heart: some View {
        let a: CGFloat = amount
        let u: Double = unit
        return content.keyframeAnimator(initialValue: PopPose(), trigger: trigger) { view, pose in
            view.popPosed(pose, anchor: .center)
        } keyframes: { _ in
            KeyframeTrack(\.scaleX) {
                CubicKeyframe(1 - 0.25 * a, duration: 0.08 * u)
                CubicKeyframe(1 + 0.3 * a, duration: 0.14 * u)
                CubicKeyframe(1 - 0.04 * a, duration: 0.12 * u)
                CubicKeyframe(1 + 0.18 * a, duration: 0.12 * u)
                SpringKeyframe(1, duration: 0.25 * u, spring: .bouncy)
            }
            KeyframeTrack(\.scaleY) {
                CubicKeyframe(1 - 0.25 * a, duration: 0.08 * u)
                CubicKeyframe(1 + 0.3 * a, duration: 0.14 * u)
                CubicKeyframe(1 - 0.04 * a, duration: 0.12 * u)
                CubicKeyframe(1 + 0.18 * a, duration: 0.12 * u)
                SpringKeyframe(1, duration: 0.25 * u, spring: .bouncy)
            }
        }
    }

    /// A decaying swing from the top, like a real bell.
    private var bell: some View {
        let a: Double = Double(amount)
        let u: Double = unit
        return content.keyframeAnimator(initialValue: PopPose(), trigger: trigger) { view, pose in
            view.popPosed(pose, anchor: .top)
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                CubicKeyframe(24 * a, duration: 0.1 * u)
                CubicKeyframe(-20 * a, duration: 0.13 * u)
                CubicKeyframe(14 * a, duration: 0.12 * u)
                CubicKeyframe(-8 * a, duration: 0.11 * u)
                SpringKeyframe(0, duration: 0.25 * u, spring: .smooth)
            }
        }
    }

    /// Flies off up and to the right, then re-enters from the opposite corner.
    private var plane: some View {
        let a: CGFloat = amount
        let u: Double = unit
        return content.keyframeAnimator(initialValue: PopPose(), trigger: trigger) { view, pose in
            view.popPosed(pose, anchor: .center)
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                CubicKeyframe(-3 * a, duration: 0.08 * u)
                CubicKeyframe(18 * a, duration: 0.18 * u)
                MoveKeyframe(-16 * a)
                SpringKeyframe(0, duration: 0.4 * u, spring: .bouncy)
            }
            KeyframeTrack(\.y) {
                CubicKeyframe(3 * a, duration: 0.08 * u)
                CubicKeyframe(-18 * a, duration: 0.18 * u)
                MoveKeyframe(16 * a)
                SpringKeyframe(0, duration: 0.4 * u, spring: .bouncy)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.12 * u)
                LinearKeyframe(0, duration: 0.14 * u)
                LinearKeyframe(1, duration: 0.16 * u)
            }
        }
    }
}

/// A ring of dots thrown outward from behind the icon.
private struct PopBurst: View {
    let trigger: Int
    let count: Int
    let color: Color
    let speed: Double

    var body: some View {
        KeyframeAnimator(initialValue: 0.0, trigger: trigger) { progress in
            let eased: Double = 1 - pow(1 - progress, 3)
            let visible: Bool = progress > 0.001 && progress < 0.999
            ZStack {
                ForEach(0..<max(count, 0), id: \.self) { index in
                    let angle: Double = Double(index) / Double(max(count, 1)) * 2 * .pi - .pi / 2
                    let radius: Double = 8 + 18 * eased
                    Circle()
                        .fill(index % 2 == 0 ? color : color.opacity(0.55))
                        .frame(width: index % 2 == 0 ? 4.5 : 3, height: index % 2 == 0 ? 4.5 : 3)
                        .scaleEffect(1 - 0.85 * progress)
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                }
            }
            .opacity(visible ? 1 - progress * progress : 0)
        } keyframes: { _ in
            KeyframeTrack {
                MoveKeyframe(0.0)
                LinearKeyframe(1.0, duration: 0.55 / max(speed, 0.1))
                MoveKeyframe(0.0)
            }
        }
        .allowsHitTesting(false)
    }
}
