import SwiftUI

// MARK: - All done list

extension Effect {
    static let feedbackAllDoneList = Effect(
        id: "feedback.all-done-list",
        category: .feedback,
        interaction: .tap,
        name: L("All-Done Checklist", "清单全部完成"),
        summary: L("Checking the last task strikes every row through in a cascade, then the list folds up like an accordion into an 'All done' badge.", "勾掉最后一项，每一行依次被划掉，整张清单像手风琴一样折起，化成一枚“全部完成”徽章。"),
        prompt: L(
            "A checklist card with four 44 pt rows, two already ticked. Tapping a row springs its circle green (response 0.3 s, damping 0.55) and writes a check in 0.2 s. When the last one is ticked the counter rolls to 4/4 and the progress bar fills; then a line strikes each title left to right in 0.22 s, 70 ms apart, each with a selection tick, as the text fades to 45%. 250 ms later the rows fold like an accordion: alternate rows hinge on their top and bottom edges and rotate to 88° with perspective, darkening as they turn away, on a spring (response 0.6 s, damping 0.86). The flattened card then contracts into a 124 pt green disc (damping 0.6); a white check is stroked, twelve rays flick outward and fade, and 'All done' rises in with a success haptic.",
            "清单卡片有四行（每行 44 pt），两项已勾选。点击一行，圆圈以弹簧（响应 0.3 秒、阻尼 0.55）变绿，对勾 0.2 秒写出。勾完最后一项，计数滚到 4/4，进度条填满；随后横线从左到右划过每行标题，每行 0.22 秒、间隔 70 毫秒，文字淡到 45%。250 毫秒后各行像手风琴一样折叠：相邻两行分别以上、下边为铰链带透视转到 88°，背光时变暗（弹簧响应 0.6 秒、阻尼 0.86）。压扁的卡片再收缩成 124 pt 绿色圆盘（阻尼 0.6），白色对勾写出，十二道光芒弹开淡出，“全部完成”上浮，伴随成功触感。"
        ),
        implementation: L(
            "The card is an Animatable view over one fold value: every frame it gives each row rotation3DEffect about its top or bottom edge and a frame height of 44 × cos(angle), so the rows stay joined while they fold. The badge is the same background shape animating its size, corner radius and fill.",
            "卡片是基于单一折叠值的 Animatable 视图：每一帧都让各行绕上边或下边做 rotation3DEffect，并把行高设为 44 × cos(角度)，折叠过程中各行始终首尾相接。徽章是同一个背景形状在动画其尺寸、圆角与填充。"
        ),
        apis: ["Animatable", "rotation3DEffect(_:axis:anchor:perspective:)", "trim(from:to:)", "contentTransition(.numericText)", "spring(response:dampingFraction:)"],
        tags: ["checklist", "todo", "complete", "fold", "strikethrough", "清单", "待办", "完成", "折叠", "删除线"],
        params: [
            .slider("stagger", L("Strike stagger", "划线间隔"), 0.02...0.16, default: 0.07, unit: "s"),
            .slider("fold", L("Fold response", "折叠响应"), 0.35...1.1, default: 0.6, unit: "s"),
            .slider("pop", L("Badge damping", "徽章阻尼"), 0.4...1.0, default: 0.6),
        ]
    ) { ctx in
        AllDoneDemo(ctx: ctx)
    }
}

private struct AllDoneTask {
    let title: LocalizedText
    let tag: LocalizedText
    let tint: Color
}

private enum AllDoneData {
    static let tasks: [AllDoneTask] = [
        AllDoneTask(title: L("Reply to Jun", "回复小俊的评审"), tag: L("Work", "工作"), tint: Palette.indigo),
        AllDoneTask(title: L("Book train to Osaka", "订去大阪的车票"), tag: L("Trip", "出行"), tint: Palette.coral),
        AllDoneTask(title: L("Water the plants", "给龟背竹浇水"), tag: L("Home", "家务"), tint: Palette.mint),
        AllDoneTask(title: L("Run 5 km", "跑步 5 公里"), tag: L("Health", "健康"), tint: Palette.amber),
    ]
    static let initial: [Bool] = [true, true, false, false]
}

private struct AllDoneDemo: View {
    let ctx: DemoContext
    @State private var checked: [Bool]
    @State private var struck: Bool
    @State private var fold: CGFloat = 0
    @State private var badge = false
    @State private var badgeCheck = false
    @State private var rays = false
    @State private var busy = false
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show every row ticked and struck through.
        _checked = State(initialValue: ctx.isStill ? [true, true, true, true] : AllDoneData.initial)
        _struck = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                AllDoneCard(
                    fold: fold,
                    badge: badge,
                    checked: checked,
                    struck: struck,
                    stagger: ctx["stagger"],
                    language: ctx.language,
                    onTap: toggle
                )
                badgeFace
            }
            .frame(width: 300, height: 262)
            .contentShape(Rectangle())
            .onTapGesture {
                if badge && !busy { reset() }
            }
            DemoHint(text: L("Tick the remaining tasks", "勾掉剩下的任务"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.25, delay: 0.6) { advance() }
    }

    private var badgeFace: some View {
        let zh = ctx.language == .zh
        return ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(index % 2 == 0 ? Palette.green : Palette.mint)
                    .frame(width: 3.5, height: index % 2 == 0 ? 13 : 8)
                    .offset(y: rays ? -96 : -70)
                    .rotationEffect(.degrees(Double(index) * 30))
                    .opacity(rays ? 0 : (badge ? 1 : 0))
            }
            FeedbackCheckShape()
                .trim(from: 0, to: badgeCheck ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                .frame(width: 52, height: 40)
                .offset(y: -22)
            VStack(spacing: 2) {
                Text(zh ? "全部完成" : "All done")
                    .font(.title3.weight(.bold))
                Text(zh ? "今天的 4 项任务" : "4 tasks today")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .offset(y: badgeCheck ? 72 : 84)
            .opacity(badgeCheck ? 1 : 0)
        }
        .allowsHitTesting(false)
    }

    // MARK: Actions

    private func toggle(_ index: Int) {
        guard !busy, !badge, checked.indices.contains(index) else { return }
        Haptics.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { checked[index].toggle() }
        if checked.allSatisfy({ $0 }) { celebrate() }
    }

    /// Preview loop and intro: tick the next open task; start over once the badge has been shown.
    private func advance() {
        guard !busy else { return }
        if badge {
            reset()
        } else if let next = checked.firstIndex(of: false) {
            toggle(next)
        }
    }

    private func reset() {
        token += 1
        rays = false
        withAnimation(.easeOut(duration: 0.15)) { badgeCheck = false }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            badge = false
            fold = 0
            struck = false
            checked = AllDoneData.initial
        }
    }

    private func celebrate() {
        token += 1
        let current = token
        busy = true
        let stagger: Double = ctx["stagger"]
        let foldResponse: Double = ctx["fold"]
        let pop: Double = ctx["pop"]
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let rows: Int = checked.count
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            guard token == current else { return }
            struck = true
            for _ in 0..<rows {
                if buzz { Haptics.selection() }
                try? await Task.sleep(for: .seconds(stagger))
            }
            try? await Task.sleep(for: .seconds(0.22 + 0.25))
            guard token == current else { return }
            withAnimation(.spring(response: foldResponse, dampingFraction: 0.86)) { fold = 1 }
            try? await Task.sleep(for: .seconds(foldResponse * 0.85))
            guard token == current else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: pop)) { badge = true }
            withAnimation(.easeOut(duration: 0.3).delay(0.16)) { badgeCheck = true }
            withAnimation(.easeOut(duration: 0.55).delay(0.12)) { rays = true }
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(1.3))
            guard token == current else { return }
            busy = false
        }
    }
}

// MARK: - Card

/// The checklist. `fold` (0…1) is interpolated every frame so each row's rotation and its projected height
/// stay in step: the rows remain joined like a paper accordion.
private struct AllDoneCard: View, Animatable {
    var fold: CGFloat
    let badge: Bool
    let checked: [Bool]
    let struck: Bool
    let stagger: Double
    let language: AppLanguage
    let onTap: (Int) -> Void

    var animatableData: CGFloat {
        get { fold }
        set { fold = newValue }
    }

    private static let rowHeight: CGFloat = 44
    private static let headerHeight: CGFloat = 58

    var body: some View {
        let amount: CGFloat = min(max(fold, 0), 1)
        let angle: Double = Double(amount) * 88
        let projected: CGFloat = Self.rowHeight * CGFloat(cos(angle * .pi / 180))
        let listHeight: CGFloat = Self.headerHeight + projected * CGFloat(checked.count) + 12
        let shape = RoundedRectangle(cornerRadius: badge ? 62 : 24, style: .continuous)
        VStack(spacing: 0) {
            header
                .frame(height: Self.headerHeight)
            ForEach(checked.indices, id: \.self) { index in
                row(index, angle: angle, projected: projected)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 272, height: listHeight, alignment: .top)
        .opacity(badge ? 0 : 1)
        .frame(width: badge ? 124 : 272, height: badge ? 124 : listHeight)
        .background {
            ZStack {
                shape.fill(Palette.elevated)
                shape
                    .fill(LinearGradient(colors: [Color(hex: 0x4BE08F), Color(hex: 0x1FA85B)], startPoint: .top, endPoint: .bottom))
                    .opacity(badge ? 1 : 0)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.stroke))
        .shadow(color: (badge ? Palette.green : Color.black).opacity(badge ? 0.35 : 0.12), radius: 18, y: 10)
        .offset(y: badge ? -22 : 0)
    }

    private var header: some View {
        let done: Int = checked.filter { $0 }.count
        let zh = language == .zh
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(zh ? "今天" : "Today")
                    .font(.headline)
                Spacer(minLength: 0)
                Text(verbatim: "\(done)/\(checked.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(done == checked.count ? AnyShapeStyle(Palette.green) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                    .contentTransition(.numericText(value: Double(done)))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.09))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.mint, Palette.green], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * CGFloat(done) / CGFloat(max(checked.count, 1)))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private func row(_ index: Int, angle: Double, projected: CGFloat) -> some View {
        let task: AllDoneTask = AllDoneData.tasks[index % AllDoneData.tasks.count]
        let isChecked: Bool = checked[index]
        let even: Bool = index % 2 == 0
        let shade: Double = sin(angle * .pi / 180) * (even ? 0.1 : 0.3)
        let strike: Animation = struck ? Animation.easeOut(duration: 0.22).delay(Double(index) * stagger) : Animation.easeOut(duration: 0.15)
        return HStack(spacing: 12) {
            AllDoneCheck(checked: isChecked)
                .frame(width: 24, height: 24)
            Text(task.title, language)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .opacity(struck ? 0.45 : 1)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.primary.opacity(0.7))
                            .frame(width: struck ? proxy.size.width + 6 : 0, height: 1.6)
                            .offset(x: -3, y: proxy.size.height / 2)
                    }
                }
                .animation(strike, value: struck)
            Spacer(minLength: 0)
            Text(task.tag, language)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(task.tint)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(task.tint.opacity(0.14), in: Capsule())
        }
        .padding(.horizontal, 18)
        .frame(width: 272, height: Self.rowHeight)
        .background(Palette.elevated)
        .overlay(Color.black.opacity(shade))
        .overlay(alignment: even ? .bottom : .top) {
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(index) }
        .rotation3DEffect(
            .degrees(even ? -angle : angle),
            axis: (x: 1, y: 0, z: 0),
            anchor: even ? .top : .bottom,
            perspective: 0.35
        )
        .frame(height: projected, alignment: even ? .top : .bottom)
    }
}

private struct AllDoneCheck: View {
    let checked: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1.6)
                .opacity(checked ? 0 : 1)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x4BE08F), Palette.green], startPoint: .top, endPoint: .bottom))
                .scaleEffect(checked ? 1 : 0.3)
                .opacity(checked ? 1 : 0)
            FeedbackCheckShape()
                .trim(from: 0, to: checked ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 10.5, height: 8)
                .animation(checked ? Animation.easeOut(duration: 0.2).delay(0.08) : Animation.linear(duration: 0.05), value: checked)
        }
    }
}
