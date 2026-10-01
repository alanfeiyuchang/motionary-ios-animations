import SwiftUI

// MARK: - Progress toast

extension Effect {
    static let feedbackProgressToast = Effect(
        id: "feedback.progress-toast",
        category: .feedback,
        interaction: .tap,
        name: L("Progress Ring Toast", "进度环吐司"),
        summary: L("An upload toast whose ring fills file by file, turns into a check and tightens before it leaves.", "上传吐司里的圆环逐个文件填满，化作对勾，吐司收紧后离场。"),
        prompt: L(
            "A dark capsule toast, 48 pt tall, drops 70 pt from the top of a file list on a spring (response 0.5 s, damping 0.72), scaling from 80% out of an 8 pt blur. Inside, a 28 pt ring with a 3 pt sky-to-mint stroke fills in uneven ease-in-out segments, one per file, around a bobbing arrow; the title counts 'Uploading 2 of 4' with rolling digits, the percentage runs continuously beneath it, and each finished row in the list pops a green check. At 100% a green disc springs into the ring (response 0.4 s, damping 0.55), a white check is stroked in 0.25 s, the two lines blur-replace into one short line and the capsule tightens around it with a 94% squeeze and a success haptic. After 1.4 s it rises away. Informative, calm, satisfying.",
            "深色胶囊吐司高 48 pt，从文件列表顶部落下 70 pt：弹簧（响应 0.5 秒、阻尼 0.72），由 80% 放大并从 8 pt 模糊中清晰。内部 28 pt 圆环的 3 pt 天蓝到薄荷绿描边按文件分段、以不均匀的缓入缓出填充，中间箭头上下浮动；标题“正在上传 2/4”数字滚动，百分比连续跳动，列表每完成一行弹出绿色对勾。到 100% 时绿色圆盘弹入圆环（响应 0.4 秒、阻尼 0.55），白色对勾 0.25 秒写出，两行文字模糊替换成一行短句，胶囊收紧并挤压到 94%，伴随成功触感。1.4 秒后向上离场。清楚、从容、满足。"
        ),
        implementation: L(
            "The toast is a Capsule sized by its content, so swapping the two-line progress text for one short line inside a spring makes it tighten; the ring is a trimmed Circle animated per file, the percentage is an Animatable view that follows the same animation, and a keyframeAnimator adds the squeeze.",
            "吐司是由内容决定尺寸的 Capsule，在弹簧动画里把两行进度文字换成一行短句，它就自然收紧；圆环是按文件分段动画的 trim 圆，百分比是跟随同一动画的 Animatable 视图，keyframeAnimator 负责挤压。"
        ),
        apis: ["Animatable", "trim(from:to:)", "contentTransition(.numericText)", "transition(.blurReplace)", "keyframeAnimator(initialValue:trigger:)"],
        tags: ["toast", "progress", "upload", "ring", "吐司", "进度", "上传", "圆环"],
        params: [
            .slider("duration", L("Upload time", "上传时长"), 1.5...6.0, default: 3.0, decimals: 1, unit: "s"),
            .slider("files", L("Files", "文件数"), 2...5, default: 4, step: 1, decimals: 0),
            .slider("damping", L("Drop damping", "落下阻尼"), 0.5...1.0, default: 0.72),
        ]
    ) { ctx in
        ProgressToastDemo(ctx: ctx)
    }
}

private enum ProgressToastStage {
    case hidden
    case uploading
    case done
}

private struct ProgressToastFile {
    let name: String
    let size: String
    let symbol: String
    let tint: Color
}

private struct ProgressToastDemo: View {
    let ctx: DemoContext
    @State private var stage: ProgressToastStage
    @State private var progress: Double
    @State private var finished: Int
    @State private var squeezes = 0
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the toast mid-upload.
        _stage = State(initialValue: ctx.isStill ? .uploading : .hidden)
        _progress = State(initialValue: ctx.isStill ? 0.62 : 0)
        _finished = State(initialValue: ctx.isStill ? 2 : 0)
    }

    private static let files: [ProgressToastFile] = [
        ProgressToastFile(name: "IMG_2041.heic", size: "3.2 MB", symbol: "photo.fill", tint: Palette.sky),
        ProgressToastFile(name: "Invoice-0924.pdf", size: "640 KB", symbol: "doc.text.fill", tint: Palette.coral),
        ProgressToastFile(name: "Demo-cut.mov", size: "48 MB", symbol: "film.fill", tint: Palette.violet),
        ProgressToastFile(name: "Notes.md", size: "12 KB", symbol: "note.text", tint: Palette.amber),
        ProgressToastFile(name: "Logo.svg", size: "88 KB", symbol: "scribble.variable", tint: Palette.mint),
    ]

    /// Uneven shares of the upload time, so the ring stalls and catches up like a real transfer.
    private static let weights: [Double] = [1.25, 0.7, 1.45, 0.6, 1.0]

    private var count: Int { min(max(ctx.int("files"), 2), Self.files.count) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                fileCard
                toast
                    .padding(.top, 12)
            }
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .demoCard(cornerRadius: 26)
            DemoHint(text: L("Tap Upload", "点击“上传”"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 3.6, delay: 0.4) { start() }
    }

    // MARK: Scene

    private var fileCard: some View {
        let zh = ctx.language == .zh
        return VStack(spacing: 0) {
            Text(zh ? "共享文件夹" : "Shared folder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(height: 68)
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    fileRow(index)
                }
            }
            Spacer(minLength: 0)
            Button(action: start) {
                Label {
                    Text(zh ? "上传 \(count) 个文件" : "Upload \(count) files")
                } icon: {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 268, height: 38)
                .background(Palette.primaryStrong, in: Capsule())
                .opacity(stage == .uploading ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(width: 300, height: 300)
        .background(Palette.elevated)
    }

    private func fileRow(_ index: Int) -> some View {
        let file = Self.files[index]
        let isDone: Bool = index < finished
        let isActive: Bool = stage == .uploading && index == finished
        return HStack(spacing: 10) {
            Image(systemName: file.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(file.tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(verbatim: file.name)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            ZStack {
                Text(verbatim: file.size)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .opacity(isDone ? 0 : (isActive ? 1 : 0.6))
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.green)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Color.primary.opacity(isActive ? 0.05 : 0))
    }

    // MARK: Toast

    private var toast: some View {
        let visible: Bool = stage != .hidden
        let done: Bool = stage == .done
        return HStack(spacing: 10) {
            ProgressToastRing(progress: progress, done: done)
                .frame(width: 28, height: 28)
            toastText(done: done)
        }
        .padding(.leading, 10)
        .padding(.trailing, done ? 16 : 18)
        .frame(height: 48)
        .background {
            Capsule()
                .fill(Color(hex: 0x101014))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        }
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: squeezes) { content, squeeze in
            content.scaleEffect(x: squeeze, y: 2 - squeeze)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(0.94, duration: 0.14)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
            }
        }
        .scaleEffect(visible ? 1 : 0.8)
        .blur(radius: visible ? 0 : 8)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : -70)
    }

    @ViewBuilder
    private func toastText(done: Bool) -> some View {
        let zh = ctx.language == .zh
        if done {
            Text(zh ? "已上传 \(count) 个文件" : "\(count) files uploaded")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize()
                .transition(.blurReplace)
        } else {
            let current: Int = min(finished + 1, count)
            VStack(alignment: .leading, spacing: 1) {
                Text(zh ? "正在上传 \(current)/\(count)" : "Uploading \(current) of \(count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(current)))
                HStack(spacing: 4) {
                    Text(verbatim: Self.files[min(finished, count - 1)].name)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                    Text(verbatim: "·")
                    ProgressToastPercent(value: progress)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 150, alignment: .leading)
            .transition(.blurReplace)
        }
    }

    // MARK: Sequence

    private func start() {
        guard stage != .uploading else { return }
        token += 1
        let current = token
        let total: Int = count
        let upload: Double = ctx["duration"]
        let drop = Animation.spring(response: 0.5, dampingFraction: ctx["damping"])
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let preview: Bool = ctx.isPreview
        if buzz { Haptics.tap() }
        Task { @MainActor in
            if stage == .done {
                // A tap while the result is still showing: let it leave first.
                withAnimation(.easeIn(duration: 0.2)) { stage = .hidden }
                try? await Task.sleep(for: .seconds(0.25))
                guard token == current else { return }
            }
            progress = 0
            finished = 0
            withAnimation(drop) { stage = .uploading }
            try? await Task.sleep(for: .seconds(0.35))
            let weights: [Double] = Array(Self.weights.prefix(total))
            let sum: Double = weights.reduce(0, +)
            for index in 0..<total {
                guard token == current else { return }
                let segment: Double = upload * weights[index] / sum
                withAnimation(.easeInOut(duration: segment)) { progress = Double(index + 1) / Double(total) }
                try? await Task.sleep(for: .seconds(segment))
                guard token == current else { return }
                if index < total - 1 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { finished = index + 1 }
                    if buzz { Haptics.selection() }
                }
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                finished = total
                stage = .done
            }
            squeezes += 1
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(1.4))
            guard token == current else { return }
            withAnimation(.easeIn(duration: 0.28)) { stage = .hidden }
            guard preview else { return }
            try? await Task.sleep(for: .seconds(0.6))
            guard token == current else { return }
            withAnimation(.smooth(duration: 0.3)) { finished = 0 }
        }
    }
}

/// The percentage follows the ring's own animation instead of jumping per file.
private struct ProgressToastPercent: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        // The value changes every frame of the ring's animation: swap the digits without a cross-fade.
        Text(verbatim: "\(Int((value * 100).rounded()))%")
            .contentTransition(.identity)
    }
}

private struct ProgressToastCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct ProgressToastRing: View {
    let progress: Double
    let done: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(colors: [Palette.sky, Palette.mint], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(done ? 0 : 1)
            Image(systemName: "arrow.up")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .phaseAnimator([false, true]) { content, up in
                    content.offset(y: up ? -1.5 : 1.5)
                } animation: { _ in
                    .easeInOut(duration: 0.55)
                }
                .scaleEffect(done ? 0.2 : 1)
                .opacity(done ? 0 : 1)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x4BE08F), Palette.green], startPoint: .top, endPoint: .bottom))
                .frame(width: 31, height: 31)
                .scaleEffect(done ? 1 : 0.3)
                .opacity(done ? 1 : 0)
            ProgressToastCheck()
                .trim(from: 0, to: done ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 9)
                .animation(done ? Animation.easeOut(duration: 0.25).delay(0.12) : Animation.linear(duration: 0.05), value: done)
        }
    }
}
