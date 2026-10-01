import SwiftUI

extension Effect {
    static let loadingFileQueue = Effect(
        id: "loading.file-queue",
        category: .loading,
        interaction: .state,
        name: L("Upload Queue", "上传队列"),
        summary: L("Files upload one after another; each finished row draws a check, folds away, and the queue closes up behind it.", "文件一个接一个上传；每行完成后画出对勾、折叠收起，队列随即向上合拢。"),
        prompt: L(
            "A 300 pt card lists four files waiting to upload, each a 52 pt row with a tinted icon tile, name, size and a 3 pt progress track. Rows upload in order. The active row brightens, its bar fills over about 1.1 s on a (0.3, 0, 0.3, 1) curve and its percentage counts up. At 100% the bar turns green and a check draws inside a green disc over 0.3 s with a small pop (1 → 1.18 → 1) and a light haptic. After 450 ms the row folds away: its height springs to zero (response 0.45 s, damping 0.82) while it fades and shrinks to 94%, and the rows below glide up. The header count rolls '1 of 4' → '2 of 4' beside a small overall ring. When the last row folds, the card settles into a compact 'All uploaded' state. Tidy, sequential, satisfying.",
            "一张 300 pt 宽的卡片列出四个待上传文件，每行高 52 pt，含图标、文件名、大小和 3 pt 进度轨道。各行依次上传：进度条用约 1.1 秒沿 (0.3, 0, 0.3, 1) 曲线填满，百分比同步递增。到 100% 时进度条变绿，绿色圆片里的对勾用 0.3 秒画出并轻弹一下（1 → 1.18 → 1），伴随轻触感。450 毫秒后该行折叠：高度以弹簧（响应 0.45 秒、阻尼 0.82）收到零，同时淡出并缩到 94%，下方各行顺势上滑。标题计数随之滚动，旁有总进度环。最后卡片落定为紧凑的“全部上传完成”。整洁有序。"
        ),
        implementation: L(
            "An async task walks the queue: it animates one row's progress with a timing curve, marks it done, then collapses it by animating a per-row Bool that drives frame height, opacity and scale. The percentage is an Animatable view, so it counts with the bar.",
            "异步任务依次处理队列：用时间曲线动画一行的进度，标记完成，再通过一个按行的布尔值驱动高度、不透明度与缩放把它折叠。百分比是 Animatable 视图，因此与进度条同步计数。"
        ),
        apis: ["Task.sleep(for:)", "Animatable", "timingCurve(_:_:_:_:duration:)", "trim(from:to:)", "contentTransition(.numericText)"],
        tags: ["upload", "queue", "files", "list", "上传", "队列", "文件", "列表"],
        params: [
            .slider("upload", L("Upload time", "单个上传时长"), 0.5...3, default: 1.1, decimals: 1, unit: "s"),
            .slider("files", L("Files", "文件数"), 2...5, default: 4, step: 1, decimals: 0),
            .slider("damping", L("Collapse damping", "折叠阻尼"), 0.5...1, default: 0.82),
            .toggle("collapse", L("Collapse finished rows", "完成后折叠"), default: true),
        ]
    ) { ctx in
        FileQueueDemo(ctx: ctx)
    }
}

private struct QueueFile {
    let name: String
    let size: String
    let symbol: String
    let color: Color
    /// Relative upload time.
    let weight: Double

    static let all: [QueueFile] = [
        QueueFile(name: "Keynote-final.key", size: "48.2 MB", symbol: "rectangle.on.rectangle.angled.fill", color: Palette.coral, weight: 1.0),
        QueueFile(name: "IMG_2041.heic", size: "6.4 MB", symbol: "photo.fill", color: Palette.sky, weight: 0.7),
        QueueFile(name: "demo-reel.mov", size: "212 MB", symbol: "film.fill", color: Palette.violet, weight: 1.3),
        QueueFile(name: "notes.pdf", size: "1.1 MB", symbol: "doc.text.fill", color: Palette.amber, weight: 0.6),
        QueueFile(name: "mix-v3.wav", size: "34 MB", symbol: "waveform", color: Palette.mint, weight: 0.9),
    ]
}

private enum QueuePhase {
    case waiting
    case uploading
    case done
}

private struct FileQueueDemo: View {
    let ctx: DemoContext
    @State private var progress: [Double]
    @State private var phases: [QueuePhase]
    @State private var collapsed: [Bool]
    @State private var finished = false
    @State private var pops: [Int] = Array(repeating: 0, count: QueueFile.all.count)
    @State private var task: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        let total: Int = QueueFile.all.count
        var progress: [Double] = Array(repeating: 0, count: total)
        var phases: [QueuePhase] = Array(repeating: .waiting, count: total)
        if ctx.isStill {
            // Stills: one file done, the second mid-upload.
            progress[0] = 1
            phases[0] = .done
            progress[1] = 0.62
            phases[1] = .uploading
        }
        _progress = State(initialValue: progress)
        _phases = State(initialValue: phases)
        _collapsed = State(initialValue: Array(repeating: false, count: total))
    }

    private var count: Int { min(max(ctx.int("files"), 1), QueueFile.all.count) }

    var body: some View {
        VStack(spacing: 14) {
            card
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .onTapGesture {
                    Haptics.tap()
                    start()
                }
            DemoHint(text: L("Tap to upload again", "点击重新上传"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Only an idle queue is started, so a run is never cut short.
        .autoplay(ctx.isPreview, every: 1.2, delay: 0.5) {
            if task == nil { start() }
        }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private var card: some View {
        let zh = ctx.language == .zh
        let doneCount: Int = (0..<count).filter { phases[$0] == .done }.count
        let current: Int = min(doneCount + 1, count)
        let overall: Double = (0..<count).reduce(0) { $0 + progress[$1] } / Double(count)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.1), lineWidth: 3.5)
                    Circle()
                        .trim(from: 0, to: overall)
                        .stroke(finished ? Palette.green : Palette.blue, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Palette.green)
                        .scaleEffect(finished ? 1 : 0.2)
                        .opacity(finished ? 1 : 0)
                }
                .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(finished ? (zh ? "全部上传完成" : "All uploaded") : (zh ? "正在上传" : "Uploading"))
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.opacity)
                    Group {
                        if finished {
                            Text(zh ? "\(count) 个文件已同步到云端" : "\(count) files synced to the cloud")
                        } else {
                            // Only the running number rolls.
                            HStack(spacing: 3) {
                                if zh { Text("第") }
                                Text("\(current)")
                                    .contentTransition(.numericText(value: Double(current)))
                                Text(zh ? "/ \(count) 个" : "of \(count)")
                            }
                        }
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(finished ? Palette.green : Palette.blue)
                    .symbolEffect(.bounce, value: finished)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            ForEach(0..<count, id: \.self) { index in
                let hidden: Bool = collapsed[index]
                QueueRow(file: QueueFile.all[index], progress: progress[index], phase: phases[index], pops: pops[index], language: ctx.language)
                    .frame(height: hidden ? 0 : 52, alignment: .top)
                    .scaleEffect(hidden ? 0.94 : 1, anchor: .top)
                    .opacity(hidden ? 0 : 1)
                    .clipped()
            }
            Color.clear.frame(height: 6)
        }
        .frame(width: 300)
        .demoCard(cornerRadius: 24)
    }

    private func start() {
        task?.cancel()
        let total: Int = QueueFile.all.count
        let files: Int = count
        let upload: Double = max(ctx["upload"], 0.2)
        let damping: Double = ctx["damping"]
        let collapses: Bool = ctx.bool("collapse")
        let dirty: Bool = finished || phases.contains { $0 != .waiting }
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        task = Task { @MainActor in
            if dirty {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    progress = Array(repeating: 0, count: total)
                    phases = Array(repeating: .waiting, count: total)
                    collapsed = Array(repeating: false, count: total)
                    finished = false
                }
                try? await Task.sleep(for: .seconds(0.6))
            }
            for index in 0..<files {
                guard !Task.isCancelled else { return }
                let duration: Double = upload * QueueFile.all[index].weight
                withAnimation(.smooth(duration: 0.25)) { phases[index] = .uploading }
                withAnimation(.timingCurve(0.3, 0, 0.3, 1, duration: duration)) { progress[index] = 1 }
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.3)) { phases[index] = .done }
                pops[index] += 1
                if buzz { Haptics.tap() }
                try? await Task.sleep(for: .seconds(0.45))
                guard !Task.isCancelled else { return }
                if collapses {
                    withAnimation(.spring(response: 0.45, dampingFraction: damping)) { collapsed[index] = true }
                    try? await Task.sleep(for: .seconds(0.22))
                }
            }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { finished = true }
            if buzz { Haptics.success() }
            // Hold the result before the queue may be started again.
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            task = nil
        }
    }
}

private struct QueueRow: View {
    let file: QueueFile
    let progress: Double
    let phase: QueuePhase
    let pops: Int
    let language: AppLanguage

    var body: some View {
        let zh = language == .zh
        let active: Bool = phase == .uploading
        let done: Bool = phase == .done
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(file.color.opacity(phase == .waiting ? 0.16 : 0.24))
                .overlay(
                    Image(systemName: file.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(file.color)
                )
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(file.name)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Group {
                        if done {
                            Text(zh ? "完成" : "Done").foregroundStyle(Palette.green)
                        } else if active {
                            QueuePercent(value: progress).foregroundStyle(.primary)
                        } else {
                            Text(file.size).foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption.weight(.medium).monospacedDigit())
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule()
                        .fill(done ? AnyShapeStyle(Palette.green) : AnyShapeStyle(LinearGradient(colors: [Palette.sky, Palette.blue], startPoint: .leading, endPoint: .trailing)))
                        .scaleEffect(x: progress, y: 1, anchor: .leading)
                }
                .frame(height: 3)
            }
            ZStack {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(phase == .waiting ? 1 : 0)
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Palette.blue)
                    .opacity(active ? 1 : 0)
                    .offset(y: active ? 0 : 6)
                Circle()
                    .fill(Palette.green)
                    .scaleEffect(done ? 1 : 0.3)
                    .opacity(done ? 1 : 0)
                QueueCheck()
                    .trim(from: 0, to: done ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 10, height: 8)
            }
            .frame(width: 22, height: 22)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(1.18, duration: 0.12)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .opacity(phase == .waiting ? 0.62 : 1)
    }
}

private struct QueuePercent: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int((min(max(value, 0), 1) * 100).rounded()))%")
    }
}

private struct QueueCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
