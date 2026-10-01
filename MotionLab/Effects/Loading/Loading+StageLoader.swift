import SwiftUI

extension Effect {
    static let loadingStageLoader = Effect(
        id: "loading.stage-loader",
        category: .loading,
        interaction: .state,
        name: L("Stage Loader", "分阶段加载"),
        summary: L("A label rolls through named stages while the bar steps from checkpoint to checkpoint.", "标题在各阶段名称间滚动切换，进度条一站一站地推进并逐个打勾。"),
        prompt: L(
            "A 300 pt card splits one job into four stages. A 6 pt track carries four 22 pt checkpoints, one at the end of each stage. During a stage the mint → sky fill creeps toward 82% of its segment on a 1.2 s ease-out, so it never stalls, and the checkpoint ahead wears a spinning 30% arc. When the stage finishes, the fill snaps to the checkpoint on a spring (response 0.42 s, damping 0.72), the node floods green and pops 1 → 1.28 → 1, a white check draws in over 0.25 s with a light haptic, and the title rolls upward — old line out through a 5 pt blur, new one in from 16 pt below — to the next stage name. After the last checkpoint the bar turns green and reads 'All done'. Orderly, reassuring, crisp.",
            "一张 300 pt 的卡片把任务拆成四个阶段。6 pt 高的轨道上有四个 22 pt 的检查点，位于各阶段末尾。阶段进行中，薄荷绿 → 天蓝的填充用 1.2 秒缓出爬向本段的 82%，从不停滞；前方检查点套着一段旋转的 30% 圆弧。阶段完成时，填充以弹簧（响应 0.42 秒、阻尼 0.72）扑到检查点，节点灌满绿色并在 1 → 1.28 → 1 间弹一下，白色对勾用 0.25 秒画出并伴随轻触感，标题向上滚动：旧文字带 5 pt 模糊滑出，新文字从下方 16 pt 升入。全部完成后进度条变绿并显示“全部完成”。有条理、令人安心。"
        ),
        implementation: L(
            "An async task alternates an ease-out creep with a spring step per stage; the title is re-identified per stage and swapped with a custom blur-and-slide transition, and each node derives pending / active / done from the completed count.",
            "异步任务在每个阶段交替执行缓出爬行与弹簧跃进；标题按阶段更换 id，用自定义的模糊滑动转场切换，每个节点由“已完成数量”推导出待办、进行中、完成三种状态。"
        ),
        apis: ["task(id:)", "AnyTransition.modifier(active:identity:)", "trim(from:to:)", "keyframeAnimator", "Animatable"],
        tags: ["steps", "stages", "checklist", "progress", "步骤", "阶段", "检查点", "进度"],
        params: [
            .slider("stage", L("Stage time", "每阶段时长"), 0.6...3, default: 1.2, decimals: 1, unit: "s"),
            .slider("stages", L("Stages", "阶段数"), 3...5, default: 4, step: 1, decimals: 0),
            .slider("damping", L("Step damping", "跃进阻尼"), 0.4...1, default: 0.72),
        ]
    ) { ctx in
        StageLoaderDemo(ctx: ctx)
    }
}

private enum StageNames {
    static let titles: [LocalizedText] = [
        L("Uploading…", "正在上传…"),
        L("Analyzing…", "正在分析…"),
        L("Rendering…", "正在渲染…"),
        L("Optimizing…", "正在优化…"),
        L("Publishing…", "正在发布…"),
    ]
    static let short: [LocalizedText] = [
        L("Upload", "上传"),
        L("Analyze", "分析"),
        L("Render", "渲染"),
        L("Optimize", "优化"),
        L("Publish", "发布"),
    ]
    static let done = L("All done", "全部完成")

    /// The last stage is always "Publish", whatever the stage count.
    static func slot(_ index: Int, of count: Int) -> Int {
        index >= count - 1 ? titles.count - 1 : index
    }
}

private struct StageLoaderDemo: View {
    let ctx: DemoContext
    @State private var progress: Double
    @State private var completed: Int
    @State private var pops = 0
    @State private var run = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills never run `task`: show the loader mid-way, two stages checked.
        let count: Double = max(ctx["stages"], 1)
        _progress = State(initialValue: ctx.isStill ? 2.6 / count : 0)
        _completed = State(initialValue: ctx.isStill ? 2 : 0)
    }

    private var count: Int { min(max(ctx.int("stages"), 1), StageNames.titles.count) }

    var body: some View {
        VStack(spacing: 18) {
            StageCard(progress: progress, completed: min(completed, count), count: count, language: ctx.language, preview: ctx.isPreview)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(1.03, duration: 0.14)
                        SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
                    }
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
        .onChange(of: count) { run += 1 }
    }

    private func play() async {
        // Only a run the user restarted buzzes; the automatic first run stays silent.
        let live: Bool = !ctx.isPreview && run > 0
        let total: Int = count
        withAnimation(.smooth(duration: 0.4)) {
            progress = 0
            completed = 0
        }
        try? await Task.sleep(for: .seconds(0.6))
        for stage in 0..<total {
            if Task.isCancelled { return }
            let time: Double = max(ctx["stage"], 0.2)
            withAnimation(.easeOut(duration: time)) { progress = (Double(stage) + 0.82) / Double(total) }
            try? await Task.sleep(for: .seconds(time))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.42, dampingFraction: ctx["damping"])) {
                progress = Double(stage + 1) / Double(total)
                completed = stage + 1
            }
            if live {
                if stage == total - 1 { Haptics.success() } else { Haptics.tap(.light) }
            }
            try? await Task.sleep(for: .seconds(0.3))
        }
        guard !Task.isCancelled else { return }
        pops += 1
        guard ctx.isPreview else { return }
        try? await Task.sleep(for: .seconds(1.8))
        guard !Task.isCancelled else { return }
        run += 1
    }
}

private struct StageRoll: ViewModifier {
    let offset: CGFloat
    let hidden: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .blur(radius: hidden ? 5 : 0)
            .opacity(hidden ? 0 : 1)
    }
}

private struct StagePercent: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int((min(max(value, 0), 1) * 100).rounded()))%")
            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
    }
}

private struct StageCard: View {
    let progress: Double
    let completed: Int
    let count: Int
    let language: AppLanguage
    let preview: Bool

    private let trackWidth: CGFloat = 260
    private let node: CGFloat = 22

    var body: some View {
        let allDone: Bool = completed >= count
        VStack(alignment: .leading, spacing: 18) {
            header(allDone: allDone)
            VStack(alignment: .leading, spacing: 8) {
                track(allDone: allDone)
                labels
            }
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        .demoCard(cornerRadius: 26)
    }

    private func header(allDone: Bool) -> some View {
        let title: LocalizedText = allDone ? StageNames.done : StageNames.titles[StageNames.slot(min(completed, count - 1), of: count)]
        let roll = AnyTransition.asymmetric(
            insertion: .modifier(active: StageRoll(offset: 16, hidden: true), identity: StageRoll(offset: 0, hidden: false)),
            removal: .modifier(active: StageRoll(offset: -16, hidden: true), identity: StageRoll(offset: 0, hidden: false))
        )
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                ZStack(alignment: .leading) {
                    Text(title, language)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(allDone ? Palette.green : Color.primary)
                        .id(completed)
                        .transition(roll)
                }
                .frame(height: 26, alignment: .leading)
                Text(language == .zh
                     ? "第 \(min(completed + 1, count)) 步，共 \(count) 步"
                     : "Step \(min(completed + 1, count)) of \(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            StagePercent(value: progress)
                .foregroundStyle(allDone ? Palette.green : Color.primary)
        }
    }

    private func track(allDone: Bool) -> some View {
        let fill: CGFloat = trackWidth * CGFloat(min(max(progress, 0), 1.05))
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(width: trackWidth, height: 6)
            Capsule()
                .fill(LinearGradient(colors: [Palette.mint, Palette.sky], startPoint: .leading, endPoint: .trailing))
                .overlay { Capsule().fill(Palette.green).opacity(allDone ? 1 : 0) }
                .frame(width: max(fill, 6), height: 6)
                .shadow(color: (allDone ? Palette.green : Palette.sky).opacity(0.5), radius: 5)
            ForEach(0..<count, id: \.self) { index in
                StageNode(index: index, state: state(of: index), preview: preview)
                    .offset(x: trackWidth * CGFloat(index + 1) / CGFloat(count) - node)
            }
        }
        .frame(width: trackWidth, height: 30, alignment: .leading)
        .animation(.easeOut(duration: 0.3), value: allDone)
    }

    private var labels: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                let current: StageNodeState = state(of: index)
                Text(StageNames.short[StageNames.slot(index, of: count)], language)
                    .font(.caption2.weight(current == .pending ? .regular : .semibold))
                    .foregroundStyle(current == .pending ? Color.secondary : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: trackWidth / CGFloat(count), alignment: .trailing)
            }
        }
        .frame(width: trackWidth)
    }

    private func state(of index: Int) -> StageNodeState {
        if index < completed { return .done }
        return index == completed ? .active : .pending
    }
}

private enum StageNodeState {
    case pending
    case active
    case done
}

private struct StageCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.minY + rect.height * 0.1))
        return path
    }
}

private struct StageNode: View {
    let index: Int
    let state: StageNodeState
    let preview: Bool

    var body: some View {
        let done: Bool = state == .done
        ZStack {
            Circle().fill(Palette.elevated)
            Circle().strokeBorder(Color.primary.opacity(state == .pending ? 0.14 : 0), lineWidth: 1.5)
            if state == .active {
                StageSpinner(preview: preview)
                    .transition(.opacity)
            }
            Circle()
                .fill(LinearGradient(colors: [Palette.mint, Palette.green], startPoint: .topLeading, endPoint: .bottomTrailing))
                .scaleEffect(done ? 1 : 0.01)
                .opacity(done ? 1 : 0)
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(state == .active ? Color.primary : Color.secondary)
                .opacity(done ? 0 : 1)
            StageCheck()
                .trim(from: 0, to: done ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 10, height: 8)
                .animation(done ? .easeOut(duration: 0.25).delay(0.08) : .easeOut(duration: 0.15), value: done)
        }
        .frame(width: 22, height: 22)
        .shadow(color: Palette.green.opacity(done ? 0.45 : 0), radius: 5, y: 2)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: done) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(done ? 1.28 : 1, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
            }
        }
    }
}

private struct StageSpinner: View {
    let preview: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview))) { timeline in
            let turn: Double = (timeline.date.timeIntervalSinceReferenceDate / 0.8).truncatingRemainder(dividingBy: 1)
            ZStack {
                Circle().strokeBorder(Palette.sky.opacity(0.22), lineWidth: 2)
                Circle()
                    .inset(by: 1)
                    .trim(from: 0, to: 0.3)
                    .stroke(Palette.sky, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(turn * 360))
            }
        }
    }
}
