import SwiftUI

extension Effect {
    static let textTerminalLog = Effect(
        id: "text.terminal-log",
        category: .text,
        interaction: .loop,
        name: L("Terminal Log", "终端日志"),
        summary: L("A command types itself, log lines stream in and scroll, and each status tag spins before it colours in.", "命令自己敲出来，日志一行行涌入并上滚，每个状态标签先转圈再亮起颜色。"),
        prompt: L(
            "A dark terminal window with a title bar and monospaced 12.5 pt text. After a green prompt, a command is typed at about 26 characters per second with uneven, human gaps, a solid block caret riding the end of the line. On return, log lines appear one at a time: each slides up 8 pt and fades in over 0.2 s with a grey bracketed tag holding a spinning braille glyph while the step runs; a build step fills a small bar of blocks with a rolling percentage. When the step finishes, the tag snaps to OK, WARN or INFO, its background flashing in the status colour and decaying to a faint tint over 0.5 s. Once nine lines are filled, the oldest fades out and the rest move up. A green summary line closes the run, and a fresh prompt waits with a caret blinking twice a second.",
            "带标题栏的深色终端窗口，12.5pt等宽字体。绿色提示符之后，一条命令以每秒约26个字符、间隔不均匀的节奏敲出，实心方块光标紧跟在行尾。回车后，日志逐行出现：每行上移8pt并在0.2秒内淡入，前面是一个灰色方括号标签，运行期间里面有一个旋转的盲文字符；编译那一步还会用一排方块填出进度条。步骤完成时，标签立刻变成OK、WARN或INFO，底色闪出对应的状态色，再用0.5秒衰减成淡淡的底纹。写满九行后，最旧的一行淡出，其余上移。最后以一行绿色总结收尾，新提示符的光标每秒闪两次。"
        ),
        implementation: L(
            "An async task appends and mutates an array of line models (typing, pending, resolved); the window shows the last nine in a VStack with insertion and removal transitions, the spinner and the caret blink come from periodic TimelineViews, and the tag flash is a pulse keyed on the resolved state.",
            "一个异步任务不断追加并修改行模型数组（输入中、等待中、已完成）；窗口用 VStack 显示最后九行并带插入与移除转场，转圈字符和光标闪烁来自周期性的 TimelineView，标签闪色是一个由完成状态触发的脉冲。"
        ),
        apis: ["task(id:)", "TimelineView(.periodic)", "transition(_:)", "Font.Design.monospaced", "Task.sleep"],
        tags: ["terminal", "console", "log", "cli", "caret", "终端", "命令行", "日志", "控制台", "光标"],
        params: [
            .slider("speed", L("Typing speed", "输入速度"), 8...60, default: 26, decimals: 0, unit: " ch/s"),
            .slider("interval", L("Line interval", "行间隔"), 0.05...0.5, default: 0.14, unit: "s"),
            .choice("caret", L("Caret", "光标"), [L("Block", "方块"), L("Bar", "竖线"), L("Underscore", "下划线")], default: 0),
        ]
    ) { ctx in
        TextTerminalLogDemo(ctx: ctx)
    }
}

private enum TermTag {
    case ok, warn, info

    var label: String {
        switch self {
        case .ok: return " OK "
        case .warn: return "WARN"
        case .info: return "INFO"
        }
    }

    var color: Color {
        switch self {
        case .ok: return Color(hex: 0x3DDC84)
        case .warn: return Color(hex: 0xFFC247)
        case .info: return Color(hex: 0x4FB8FF)
        }
    }
}

private enum TermKind {
    case command, log, result, note
}

private struct TermLine: Identifiable {
    let id: Int
    var kind: TermKind
    var text: String
    var tag: TermTag = .ok
    var resolved = true
}

private struct TermStep {
    let tag: TermTag
    let running: String
    let done: String
    var progress = false
    var work: Double = 0.4
}

private struct TermScript {
    let command: String
    let steps: [TermStep]
    let summary: String
}

private struct TextTerminalLogDemo: View {
    let ctx: DemoContext
    @State private var lines: [TermLine]
    @State private var nextID: Int
    @State private var typing = false
    @State private var running = false
    @State private var round = 0
    @State private var runs = 0

    private static let maxLines = 9
    private static let lineHeight: CGFloat = 19

    init(ctx: DemoContext) {
        self.ctx = ctx
        if ctx.isStill {
            let script = TextTerminalLogDemo.scripts(ctx.language)[0]
            var seeded: [TermLine] = [TermLine(id: 0, kind: .command, text: script.command)]
            for (index, step) in script.steps.enumerated() {
                seeded.append(TermLine(id: index + 1, kind: .log, text: step.done, tag: step.tag))
            }
            seeded.append(TermLine(id: 90, kind: .result, text: script.summary))
            seeded.append(TermLine(id: 91, kind: .command, text: ""))
            _lines = State(initialValue: seeded)
            _nextID = State(initialValue: 100)
        } else {
            _lines = State(initialValue: [TermLine(id: 0, kind: .command, text: "")])
            _nextID = State(initialValue: 1)
        }
    }

    private static func scripts(_ language: AppLanguage) -> [TermScript] {
        let zh = language == .zh
        return [
            TermScript(
                command: "motionary build --release",
                steps: [
                    TermStep(tag: .info, running: zh ? "解析依赖" : "Resolving packages", done: zh ? "已解析 42 个依赖" : "Resolved 42 packages", work: 0.35),
                    TermStep(tag: .ok, running: zh ? "编译" : "Compiling", done: zh ? "已编译 214 个文件" : "Compiled 214 files", progress: true, work: 1.1),
                    TermStep(tag: .warn, running: zh ? "检查资源" : "Checking assets", done: zh ? "3 个资源未被引用" : "3 assets are unused", work: 0.4),
                    TermStep(tag: .ok, running: zh ? "链接" : "Linking", done: zh ? "已链接 MotionLab" : "Linked MotionLab", work: 0.45),
                    TermStep(tag: .ok, running: zh ? "签名" : "Signing", done: zh ? "已签名 · 18.4 MB" : "Signed · 18.4 MB", work: 0.3),
                ],
                summary: zh ? "✓ 构建完成，用时 4.2 秒" : "✓ Build finished in 4.2s"
            ),
            TermScript(
                command: "motionary test --ui",
                steps: [
                    TermStep(tag: .info, running: zh ? "启动模拟器" : "Booting simulator", done: zh ? "模拟器已就绪" : "Simulator ready", work: 0.5),
                    TermStep(tag: .ok, running: zh ? "运行界面测试" : "Running UI tests", done: zh ? "128 项测试通过" : "128 tests passed", progress: true, work: 1.2),
                    TermStep(tag: .warn, running: zh ? "重试" : "Retrying", done: zh ? "1 项不稳定，重试后通过" : "1 flaky test retried", work: 0.45),
                    TermStep(tag: .ok, running: zh ? "比对截图" : "Diffing snapshots", done: zh ? "截图无差异" : "Snapshots are clean", work: 0.4),
                ],
                summary: zh ? "✓ 全部通过，用时 12.8 秒" : "✓ All green in 12.8s"
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            window
            DemoHint(text: L("Tap to interrupt and run the next command", "点击中断并运行下一条命令"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap(.rigid)
            runs += 1
        }
        .task(id: runs) { await run() }
    }

    // MARK: Window

    private var window: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let visible: [TermLine] = Array(lines.suffix(Self.maxLines))
        let lastID: Int = lines.last?.id ?? -1
        return VStack(spacing: 0) {
            titleBar
            VStack(alignment: .leading, spacing: 0) {
                ForEach(visible) { line in
                    TermLineView(
                        line: line,
                        showCaret: line.id == lastID && line.kind == .command,
                        blinking: !typing && !ctx.isStill,
                        caretStyle: ctx.int("caret")
                    )
                    .frame(height: Self.lineHeight)
                    .transition(.asymmetric(
                        insertion: .offset(y: 8).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .frame(width: 276, height: Self.lineHeight * CGFloat(Self.maxLines), alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .clipped()
            .animation(.easeOut(duration: 0.2), value: lines.map(\.id))
        }
        .frame(width: 304)
        .background(Color(hex: 0x12141A), in: shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(shape)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }

    private var titleBar: some View {
        ZStack {
            HStack(spacing: 7) {
                ForEach([Color(hex: 0xFF5F57), Color(hex: 0xFEBC2E), Color(hex: 0x28C840)], id: \.self) { color in
                    Circle().fill(color).frame(width: 10, height: 10)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text(verbatim: "zsh — motionary")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Circle()
                    .fill(Color(hex: 0x3DDC84))
                    .frame(width: 5, height: 5)
                    .opacity(running ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: running)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 32)
        .background(Color.white.opacity(0.06))
    }

    // MARK: Script

    private func append(_ kind: TermKind, _ text: String, tag: TermTag = .ok, resolved: Bool = true) -> Int {
        let id = nextID
        nextID += 1
        lines.append(TermLine(id: id, kind: kind, text: text, tag: tag, resolved: resolved))
        if lines.count > 40 { lines.removeFirst(lines.count - 40) }
        return id
    }

    private func update(_ id: Int, _ change: (inout TermLine) -> Void) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        change(&lines[index])
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    private func run() async {
        guard !ctx.isStill else { return }
        // Interrupted mid-run: leave a ^C and open a fresh prompt.
        if running || typing {
            for index in lines.indices where !lines[index].resolved {
                lines[index].resolved = true
                lines[index].tag = .warn
            }
            _ = append(.note, "^C")
            _ = append(.command, "")
            running = false
            typing = false
        }
        while !Task.isCancelled {
            let all = Self.scripts(ctx.language)
            let script = all[round % all.count]
            round += 1
            guard await pause(0.7) else { return }

            // Type the command on the waiting prompt line.
            let promptID: Int = lines.last?.kind == .command ? (lines.last?.id ?? 0) : append(.command, "")
            typing = true
            for character in script.command {
                update(promptID) { $0.text.append(character) }
                let base: Double = 1 / max(ctx["speed"], 1)
                let factor: Double = character == " " ? 2.2 : Double.random(in: 0.5...1.6)
                guard await pause(base * factor) else { return }
            }
            guard await pause(0.28) else { return }
            typing = false
            running = true

            for step in script.steps {
                let id = append(.log, step.running + (step.progress ? "" : "…"), tag: step.tag, resolved: false)
                if step.progress {
                    let ticks = 14
                    for tick in 0...ticks {
                        let filled: Int = tick * 10 / ticks
                        let bar: String = String(repeating: "▰", count: filled) + String(repeating: "▱", count: 10 - filled)
                        let percent: String = String(format: "%3d%%", tick * 100 / ticks)
                        update(id) { $0.text = step.running + " " + bar + " " + percent }
                        guard await pause(step.work / Double(ticks)) else { return }
                    }
                } else {
                    guard await pause(step.work) else { return }
                }
                update(id) {
                    $0.text = step.done
                    $0.resolved = true
                }
                guard await pause(ctx["interval"]) else { return }
            }
            _ = append(.result, script.summary)
            running = false
            guard await pause(0.5) else { return }
            _ = append(.command, "")
            guard await pause(1.9) else { return }
        }
    }
}

// MARK: - Line

private struct TermLineView: View {
    let line: TermLine
    let showCaret: Bool
    let blinking: Bool
    let caretStyle: Int

    private var font: Font { .system(size: 12.5, weight: .medium, design: .monospaced) }

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            switch line.kind {
            case .command:
                Text(verbatim: "❯")
                    .font(.system(size: 12.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: 0x3DDC84))
            case .log:
                TermTagView(tag: line.tag, resolved: line.resolved)
            case .result, .note:
                EmptyView()
            }
            HStack(alignment: .center, spacing: 1) {
                Text(verbatim: line.text)
                    .font(font)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                if showCaret {
                    TermCaret(style: caretStyle, blinking: blinking)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var textColor: Color {
        switch line.kind {
        case .command: return .white.opacity(0.95)
        case .log: return .white.opacity(line.resolved ? 0.8 : 0.55)
        case .result: return Color(hex: 0x3DDC84)
        case .note: return .white.opacity(0.45)
        }
    }
}

private struct TermTagView: View {
    let tag: TermTag
    let resolved: Bool
    @Environment(\.demoIsStill) private var isStill

    private static let frames: [String] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    var body: some View {
        let font: Font = .system(size: 11, weight: .heavy, design: .monospaced)
        TextFXPulse(trigger: resolved ? 1 : 0, duration: 0.5) { p in
            if resolved {
                let decay: Double = isStill ? 0 : Double(1 - p) * Double(1 - p)
                Text(verbatim: tag.label)
                    .font(font)
                    .foregroundStyle(decay > 0.5 ? Color(hex: 0x12141A) : tag.color)
                    .frame(width: 40, height: 15)
                    .background(tag.color.opacity(0.16 + 0.84 * decay), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                TimelineView(.periodic(from: .now, by: 0.08)) { timeline in
                    let frame: Int = Int(timeline.date.timeIntervalSinceReferenceDate / 0.08) % Self.frames.count
                    Text(verbatim: "[ \(Self.frames[frame]) ]")
                        .font(font)
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 40, height: 15)
                }
            }
        }
    }
}

private struct TermCaret: View {
    let style: Int
    let blinking: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let on: Bool = !blinking || Int(timeline.date.timeIntervalSinceReferenceDate / 0.25) % 2 == 0
            shape
                .opacity(on ? 1 : 0)
        }
        .frame(width: 9, height: 15)
    }

    @ViewBuilder private var shape: some View {
        let color = Color.white.opacity(0.9)
        switch style {
        case 1:
            Rectangle().fill(color).frame(width: 2, height: 15).frame(width: 9, alignment: .leading)
        case 2:
            Rectangle().fill(color).frame(width: 8, height: 2).frame(height: 15, alignment: .bottom)
        default:
            Rectangle().fill(color).frame(width: 8, height: 15)
        }
    }
}
