import SwiftUI

extension Effect {
    static let buttonsSplitConfirm = Effect(
        id: "buttons.split-confirm",
        category: .buttons,
        interaction: .tap,
        name: L("Gooey Split Confirm", "粘液分裂确认"),
        summary: L(
            "Delete tears into Cancel and Confirm halves joined by a gooey bridge, then fuses back into the result.",
            "“删除”撕成“取消”与“确认”两半，中间拉出粘液桥，选择后再融合成结果。"
        ),
        prompt: L(
            "A red 200 × 56 pt “Delete” pill. Tapping it tears the pill down the middle: the two halves slide apart on a spring (response 0.5 s, damping 0.62) until they sit 18 pt apart, each widening to 116 pt; the left half cools to neutral grey and reads “Cancel”, the right stays red and reads “Confirm”. For the first 0.3 s a liquid bridge still joins them: it thins into a neck with concave edges, then snaps, and both halves wobble from the overshoot. The old label blurs out while the new ones ride outward with their halves. Confirm pulls the halves back together, the goo fuses, and the pill tightens to 168 pt, turns green and shows a check with “Deleted” and a success haptic, resetting after 1.5 s. Cancel fuses them straight back into “Delete” with a small shake. Sticky, deliberate, a little dramatic.",
            "200×56pt 的红色“删除”胶囊，点击后从中间撕开：两半由弹簧（响应 0.5 秒、阻尼 0.62）驱动滑开，直到相距 18pt，各自加宽到 116pt；左半冷却成中性灰并显示“取消”，右半保持红色并显示“确认”。最初 0.3 秒里两半之间仍连着一道液态桥：它被拉成两侧内凹的细颈，随后断开，两半因过冲轻晃。原文字模糊淡出，新文字随半边外移。选“确认”后两半合拢、粘液融合，胶囊收紧到 168pt 并变绿，显示对勾与“已删除”，给出成功触感，1.5 秒后复位。选“取消”则直接融回“删除”并轻轻一晃。"
        ),
        implementation: L(
            "An Animatable view draws the two halves and a shrinking bridge blob into a Canvas with blur + alphaThreshold filters (metaballs) and uses the result as the mask of a two-stop horizontal gradient, so each half keeps its own colour while the neck blends. Split, bridge and tighten are three animatable values on separate curves.",
            "一个 Animatable 视图把两个半边和一个逐渐缩小的桥接圆画进带模糊与 alphaThreshold 滤镜的 Canvas（融球效果），并把结果作为双色横向渐变的遮罩，于是两半各自保持颜色，细颈处自然混色。分裂、桥接与收紧是三个分别使用不同曲线的可动画值。"
        ),
        apis: ["Canvas", "GraphicsContext.addFilter(.alphaThreshold)", "Animatable", "AnimatablePair", "mask", "spring(response:dampingFraction:)"],
        tags: ["confirm", "delete", "gooey", "split", "确认", "删除", "粘液", "分裂"],
        params: [
            .slider("gap", L("Gap", "间距"), 8...34, default: 18, decimals: 0, unit: "pt"),
            .slider("goo", L("Gooeyness", "粘稠度"), 4...12, default: 8, decimals: 0),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.4...1.0, default: 0.62),
        ]
    ) { ctx in
        ButtonSplitConfirmDemo(ctx: ctx)
    }
}

private enum ButtonSplitStage {
    case idle, asking, deleted
}

private struct ButtonSplitConfirmDemo: View {
    let ctx: DemoContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var stage = ButtonSplitStage.idle
    @State private var split: CGFloat = 0
    @State private var bridge: CGFloat = 1
    @State private var tighten: CGFloat = 0
    @State private var nudges = 0
    @State private var cycle = 0
    @State private var resetTask: Task<Void, Never>?
    @State private var introTask: Task<Void, Never>?

    private static let halfWidth: CGFloat = 116
    private var gap: CGFloat { ctx.cg("gap") }
    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    /// Centre of each half once they are apart.
    private var halfOffset: CGFloat { (Self.halfWidth + gap) / 2 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                fileRow
                control
            }
            Spacer()
            DemoHint(text: L("Tap Delete, then choose", "点击删除，再做选择"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, delay: 0.5) {
            if ctx.isPreview { advance() } else { playIntro() }
        }
        .onDisappear {
            resetTask?.cancel()
            introTask?.cancel()
        }
    }

    /// The thing being deleted: it fades and shrinks once the deletion is confirmed.
    private var fileRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.sunset)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "photo.fill").font(.system(size: 16)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "IMG_2048.heic")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(verbatim: "3.2 MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 250)
        .demoCard(cornerRadius: 18)
        .scaleEffect(stage == .deleted ? 0.9 : 1)
        .opacity(stage == .deleted ? 0.25 : 1)
        .blur(radius: stage == .deleted ? 3 : 0)
    }

    private var control: some View {
        let neutral = colorScheme == .dark ? Color(hex: 0x3A3B44) : Color(hex: 0xDDDEE6)
        let danger = Color(hex: 0xE5384B)
        let success = Palette.successStrong
        let leading: Color = stage == .asking ? neutral : (stage == .deleted ? success : danger)
        let trailing: Color = stage == .deleted ? success : danger
        return ZStack {
            ButtonSplitGoo(
                split: split,
                bridge: bridge,
                tighten: tighten,
                gap: gap,
                goo: ctx.cg("goo"),
                leading: leading,
                trailing: trailing
            )
            .shadow(color: trailing.opacity(0.32), radius: 14, y: 8)
            labels
            hitTargets
        }
        .frame(width: 320, height: 96)
        .keyframeAnimator(initialValue: CGFloat(0), trigger: nudges) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            // A small "no" shake when the question is withdrawn.
            KeyframeTrack(\.self) {
                CubicKeyframe(-7, duration: 0.08)
                CubicKeyframe(6, duration: 0.1)
                SpringKeyframe(0, duration: 0.35, spring: .bouncy)
            }
        }
    }

    private var labels: some View {
        ZStack {
            Label {
                Text(L("Delete", "删除"), ctx.language)
            } icon: {
                Image(systemName: "trash.fill")
            }
            .foregroundStyle(.white)
            .opacity(stage == .idle ? 1 : 0)
            .scaleEffect(stage == .idle ? 1 : 0.8)
            .blur(radius: stage == .idle ? 0 : 5)

            Text(L("Cancel", "取消"), ctx.language)
                .foregroundStyle(.primary)
                .opacity(stage == .asking ? 1 : 0)
                .blur(radius: stage == .asking ? 0 : 4)
                .offset(x: -halfOffset * split)

            Text(L("Confirm", "确认"), ctx.language)
                .foregroundStyle(.white)
                .opacity(stage == .asking ? 1 : 0)
                .blur(radius: stage == .asking ? 0 : 4)
                .offset(x: halfOffset * split)

            Label {
                Text(L("Deleted", "已删除"), ctx.language)
            } icon: {
                Image(systemName: "checkmark")
            }
            .foregroundStyle(.white)
            .opacity(stage == .deleted ? 1 : 0)
            .scaleEffect(stage == .deleted ? 1 : 0.7)
            .blur(radius: stage == .deleted ? 0 : 5)
        }
        .font(.headline)
        .allowsHitTesting(false)
    }

    private var hitTargets: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { tapped(leading: true) }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { tapped(leading: false) }
        }
        .frame(width: Self.halfWidth * 2 + gap, height: 64)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Behaviour

    private func tapped(leading: Bool) {
        introTask?.cancel()
        switch stage {
        case .idle:
            Haptics.tap(.medium)
            ask()
        case .asking:
            if leading {
                Haptics.tap(.soft)
                cancel()
            } else {
                Haptics.success()
                confirm()
            }
        case .deleted:
            break
        }
    }

    private func ask() {
        withAnimation(spring) {
            stage = .asking
            split = 1
        }
        // The bridge outlives the first part of the travel, then thins and snaps.
        withAnimation(.easeIn(duration: 0.22).delay(0.08)) { bridge = 0 }
    }

    private func fuse() {
        withAnimation(.easeOut(duration: 0.16)) { bridge = 1 }
        withAnimation(spring) { split = 0 }
    }

    private func cancel() {
        fuse()
        withAnimation(spring) { stage = .idle }
        nudges += 1
    }

    private func confirm() {
        fuse()
        withAnimation(spring) { stage = .deleted }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.12)) { tighten = 1 }
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                stage = .idle
                tighten = 0
            }
        }
    }

    /// Preview loop: ask → confirm → (resets) → ask → cancel → …
    private func advance() {
        switch stage {
        case .idle:
            ask()
        case .asking:
            if cycle % 2 == 0 { confirm() } else { cancel() }
            cycle += 1
        case .deleted:
            break
        }
    }

    /// Detail intro: ask, then take the question back, so the stage starts from rest.
    private func playIntro() {
        guard stage == .idle else { return }
        ask()
        introTask?.cancel()
        introTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled, stage == .asking else { return }
            cancel()
        }
    }
}

/// The metaball layer: two halves plus a bridge blob, thresholded into one sticky silhouette.
private struct ButtonSplitGoo: View, Animatable {
    var split: CGFloat
    var bridge: CGFloat
    var tighten: CGFloat
    let gap: CGFloat
    let goo: CGFloat
    let leading: Color
    let trailing: Color

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(split, AnimatablePair(bridge, tighten)) }
        set {
            split = newValue.first
            bridge = newValue.second.first
            tighten = newValue.second.second
        }
    }

    private let height: CGFloat = 56

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: leading, location: 0.47),
                .init(color: trailing, location: 0.53),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .overlay {
            // Soft top light, masked together with the colour.
            LinearGradient(colors: [Color.white.opacity(0.2), .clear], startPoint: .top, endPoint: .center)
        }
        .mask {
            Canvas { context, size in
                context.addFilter(.alphaThreshold(min: 0.5, color: .white))
                context.addFilter(.blur(radius: goo))
                context.drawLayer { layer in
                    for path in shapes(in: size) {
                        layer.fill(path, with: .color(.white))
                    }
                }
            }
            // Feather the thresholded edge by a fraction of a point so the curve never looks aliased.
            .blur(radius: 0.7)
        }
    }

    private func shapes(in size: CGSize) -> [Path] {
        let mid = CGPoint(x: size.width / 2, y: size.height / 2)
        // Joined: one 200 pt pill (168 pt when tightened). Apart: two 116 pt halves with `gap` between them.
        let joinedHalf = 100 - 16 * tighten
        let outer = joinedHalf + (116 + gap / 2 - joinedHalf) * split
        // Joined, each half reaches deep into the other, so their round ends leave no waist; the inner
        // ends only pull clear of each other late in the travel, which is when the neck forms.
        let overlap = joinedHalf - height / 2
        let inner = -overlap + (gap / 2 + overlap) * split
        let top = mid.y - height / 2
        let left = CGRect(x: mid.x - outer, y: top, width: outer - inner, height: height)
        let right = CGRect(x: mid.x + inner, y: top, width: outer - inner, height: height)
        var paths = [
            Path(roundedRect: left, cornerRadius: height / 2, style: .continuous),
            Path(roundedRect: right, cornerRadius: height / 2, style: .continuous),
        ]
        // The bridge: a blob between the halves that shrinks until the neck snaps.
        let amount = min(max(bridge, 0), 1)
        if amount > 0.01 {
            let radius = height * 0.36 * amount
            let stretch = max(inner, 0) + radius
            paths.append(Path(ellipseIn: CGRect(x: mid.x - stretch, y: mid.y - radius, width: stretch * 2, height: radius * 2)))
        }
        return paths
    }
}
