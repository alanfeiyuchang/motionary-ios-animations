import SwiftUI

// MARK: - Autosave pulse

extension Effect {
    static let feedbackAutosavePulse = Effect(
        id: "feedback.autosave-pulse",
        category: .feedback,
        interaction: .tap,
        name: L("Autosave Pulse", "自动保存脉冲"),
        summary: L("An inline status that goes from an amber 'Edited' dot to a pulsing 'Saving' to a cloud and check that draw themselves.", "行内状态从琥珀色“已编辑”圆点，到脉冲的“保存中”，再到自己画出来的云朵与对勾。"),
        prompt: L(
            "An editor's toolbar carries a small status pill. Typing turns it to an amber 10 pt dot and 'Edited'. Half a second after the last keystroke the dot turns indigo and pulses: every 0.9 s a ring expands from it to 2.6 times its size while fading and the dot dips to 80%, next to 'Saving' with three dots that step in turn. When the save lands the dot gives way to a 27 pt cloud outline that draws itself in 0.45 s (ease-in-out), a green check is stroked inside over the next 0.27 s, the label blur-replaces to 'Saved', the version number rolls up by one, and the pill resizes on a spring (response 0.4 s, damping 0.8) with a light haptic. Unobtrusive and reassuring: you never wonder whether your work is safe.",
            "编辑器工具栏上有一枚状态胶囊。输入时它变成 10 pt 琥珀色圆点和“已编辑”。最后一次按键半秒后，圆点转为靛蓝并开始脉冲：每 0.9 秒扩散出一圈圆环，放大到 2.6 倍并淡出，圆点同时缩到 80%，旁边是“保存中”和依次点亮的三个小点。保存完成时，圆点让位给 27 pt 的云朵轮廓，在 0.45 秒内（缓入缓出）自己画出，随后 0.27 秒里绿色对勾在云中写出，文字模糊替换为“已保存”，版本号向上滚动加一，胶囊以弹簧（响应 0.4 秒、阻尼 0.8）调整宽度，伴随轻触感。不打扰，又让人安心。"
        ),
        implementation: L(
            "A status enum drives a pill sized by its content; the pulse is a TimelineView whose ring scale and opacity come from the phase within the period, the cloud is a single Path built from three arcs and a base line so trim(from:to:) can draw it, and the version uses contentTransition(.numericText).",
            "状态枚举驱动一枚由内容决定尺寸的胶囊；脉冲是 TimelineView，圆环的缩放与透明度取自周期内的相位；云朵是由三段圆弧加底线组成的单条 Path，因此可以用 trim(from:to:) 画出；版本号使用 contentTransition(.numericText)。"
        ),
        apis: ["trim(from:to:)", "Path.addArc", "TimelineView(.animation)", "contentTransition(.numericText(value:))", "transition(.blurReplace)"],
        tags: ["autosave", "saving", "status", "cloud", "自动保存", "保存中", "状态", "云同步"],
        params: [
            .slider("save", L("Save time", "保存时长"), 0.5...3.0, default: 1.2, decimals: 1, unit: "s"),
            .slider("period", L("Pulse period", "脉冲周期"), 0.5...1.6, default: 0.9, decimals: 1, unit: "s"),
            .slider("draw", L("Cloud draw time", "云朵绘制时长"), 0.2...0.8, default: 0.45, unit: "s"),
        ]
    ) { ctx in
        AutosaveDemo(ctx: ctx)
    }
}

private enum AutosaveStatus {
    case edited
    case saving
    case saved
}

private struct AutosaveDemo: View {
    let ctx: DemoContext
    @State private var status: AutosaveStatus = .saved
    @State private var shownTokens: Int
    @State private var version = 12
    @State private var token = 0

    private static let startTokens = 15

    init(ctx: DemoContext) {
        self.ctx = ctx
        _shownTokens = State(initialValue: Self.startTokens)
    }

    private static let english: [String] = [
        "Ship ", "the ", "new ", "onboarding ", "on ", "Friday. ", "Keep ", "the ", "copy ", "short, ", "lead ", "with ",
        "the ", "demo, ", "and ", "let ", "the ", "motion ", "explain ", "what ", "words ", "would ", "only ", "slow ",
        "down. ", "Every ", "screen ", "earns ", "its ", "place.",
    ]
    private static let chinese: [String] = [
        "周五", "上线", "新的", "引导", "流程。", "文案", "要短，", "先放", "演示，", "让", "动效", "去", "解释",
        "文字", "说不清", "的", "部分。", "每一屏", "都要", "有", "存在", "的", "理由，", "多余", "的", "就", "删掉。",
    ]

    private var words: [String] { ctx.language == .zh ? Self.chinese : Self.english }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                toolbar
                Divider()
                editor
                footer
            }
            .frame(width: 300, height: 300)
            .demoCard(cornerRadius: 26)
            .contentShape(Rectangle())
            .onTapGesture { edit() }
            DemoHint(text: L("Tap the page to type", "点击页面继续输入"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["save"] + 3.4, delay: 0.5) { edit() }
    }

    // MARK: Scene

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.indigo)
            Text(ctx.language == .zh ? "发布笔记" : "Launch notes")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            AutosavePill(
                status: status,
                version: version,
                language: ctx.language,
                period: max(ctx["period"], 0.2),
                draw: ctx["draw"],
                preview: ctx.isPreview
            )
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(height: 58)
    }

    private var editor: some View {
        let text: String = words.prefix(min(shownTokens, words.count)).joined()
        return TimelineView(.periodic(from: .now, by: 0.53)) { timeline in
            let blink: Bool = Int(timeline.date.timeIntervalSinceReferenceDate / 0.53) % 2 == 0
            // The caret stays lit while typing and blinks at rest.
            let lit: Bool = status == .edited || blink || ctx.isStill
            let caret: Text = Text(verbatim: "|").foregroundStyle(lit ? Palette.indigo : Color.clear).fontWeight(.light)
            (Text(verbatim: text) + caret)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var footer: some View {
        let zh = ctx.language == .zh
        let count: Int = 128 + shownTokens
        return HStack {
            Text(zh ? "\(count) 词" : "\(count) words")
                .contentTransition(.numericText(value: Double(count)))
            Spacer(minLength: 0)
            Text(zh ? "自动保存已开启" : "Autosave on")
        }
        .font(.caption2.weight(.medium).monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 36)
    }

    // MARK: Sequence

    private func edit() {
        token += 1
        let current = token
        let save: Double = ctx["save"]
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let resize = Animation.spring(response: 0.4, dampingFraction: 0.8)
        if buzz { Haptics.selection() }
        withAnimation(resize) { status = .edited }
        Task { @MainActor in
            // Three words per burst; wrap around when the paragraph is complete.
            for _ in 0..<3 {
                guard token == current else { return }
                withAnimation(.snappy(duration: 0.18)) {
                    shownTokens = shownTokens >= words.count ? Self.startTokens : shownTokens + 1
                }
                try? await Task.sleep(for: .seconds(0.13))
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            withAnimation(resize) { status = .saving }
            try? await Task.sleep(for: .seconds(save))
            guard token == current else { return }
            withAnimation(resize) {
                status = .saved
                version += 1
            }
            if buzz { Haptics.tap(.light) }
        }
    }
}

// MARK: - Status pill

private struct AutosavePill: View {
    let status: AutosaveStatus
    let version: Int
    let language: AppLanguage
    let period: Double
    let draw: Double
    let preview: Bool

    var body: some View {
        let zh = language == .zh
        HStack(spacing: 6) {
            AutosaveGlyph(status: status, period: period, draw: draw, preview: preview)
                .frame(width: 27.5, height: 20)
            switch status {
            case .edited:
                Text(zh ? "已编辑" : "Edited")
                    .foregroundStyle(.secondary)
                    .transition(.blurReplace)
            case .saving:
                HStack(spacing: 1) {
                    Text(zh ? "保存中" : "Saving")
                    AutosaveEllipsis(period: period, preview: preview)
                }
                .foregroundStyle(.secondary)
                .transition(.blurReplace)
            case .saved:
                HStack(spacing: 5) {
                    Text(zh ? "已保存" : "Saved")
                        .foregroundStyle(.primary)
                    Text(verbatim: "v\(version)")
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(version)))
                }
                .transition(.blurReplace)
            }
        }
        .font(.footnote.weight(.semibold).monospacedDigit())
        .fixedSize()
        .padding(.leading, 9)
        .padding(.trailing, 13)
        .frame(height: 36)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

private struct AutosaveEllipsis: View {
    let period: Double
    let preview: Bool
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: isStill)) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate / period
            let active: Int = Int((t - t.rounded(.down)) * 3)
            HStack(spacing: 1.5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .frame(width: 2.5, height: 2.5)
                        .opacity(index <= active ? 1 : 0.25)
                }
            }
            .offset(y: 2.5)
        }
    }
}

private struct AutosaveGlyph: View {
    let status: AutosaveStatus
    let period: Double
    let draw: Double
    let preview: Bool
    @State private var cloud: CGFloat
    @State private var check: CGFloat

    init(status: AutosaveStatus, period: Double, draw: Double, preview: Bool) {
        self.status = status
        self.period = period
        self.draw = draw
        self.preview = preview
        // A glyph created in the saved state (arrival, stills) is already drawn.
        _cloud = State(initialValue: status == .saved ? 1 : 0)
        _check = State(initialValue: status == .saved ? 1 : 0)
    }

    var body: some View {
        let saved: Bool = status == .saved
        ZStack {
            AutosaveDot(pulsing: status == .saving, period: period, preview: preview)
                .scaleEffect(saved ? 0.2 : 1)
                .opacity(saved ? 0 : 1)
            AutosaveCloud()
                .trim(from: 0, to: cloud)
                .stroke(Color.primary.opacity(0.75), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                .opacity(saved ? 1 : 0)
            AutosaveCheck()
                .trim(from: 0, to: check)
                .stroke(Palette.green, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .opacity(saved ? 1 : 0)
        }
        .onChange(of: status) { _, now in
            if now == .saved {
                withAnimation(.easeInOut(duration: draw)) { cloud = 1 }
                withAnimation(.easeOut(duration: draw * 0.6).delay(draw * 0.85)) { check = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.12)) {
                    cloud = 0
                    check = 0
                }
            }
        }
    }
}

private struct AutosaveDot: View {
    let pulsing: Bool
    let period: Double
    let preview: Bool
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        let colour: Color = pulsing ? Palette.indigo : Palette.amber
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !pulsing || isStill)) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate / period
            let phase: Double = pulsing ? t - t.rounded(.down) : 0
            let eased: Double = 1 - pow(1 - phase, 2)
            ZStack {
                Circle()
                    .stroke(colour, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                    .scaleEffect(1 + 1.6 * eased)
                    .opacity(pulsing ? 0.7 * (1 - phase) : 0)
                Circle()
                    .fill(colour)
                    .frame(width: 10, height: 10)
                    // Dips to 80% at the start of each pulse and recovers.
                    .scaleEffect(pulsing ? 0.8 + 0.2 * min(phase * 2.5, 1) : 1)
            }
        }
        .animation(.easeOut(duration: 0.25), value: pulsing)
    }
}

/// A cloud outline as one continuous path (left lobe, crown, right lobe, base) so it can be drawn with `trim`.
/// Designed in a 22 × 16 box.
private struct AutosaveCloud: Shape {
    func path(in rect: CGRect) -> Path {
        let s: CGFloat = min(rect.width / 22, rect.height / 16)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: point(5, 14.2))
        path.addArc(center: point(5, 10.2), radius: 4 * s, startAngle: .degrees(90), endAngle: .degrees(264), clockwise: false)
        path.addArc(center: point(10, 7.2), radius: 5.5 * s, startAngle: .degrees(190.3), endAngle: .degrees(340.8), clockwise: false)
        path.addArc(center: point(16.5, 9.7), radius: 4.5 * s, startAngle: .degrees(253.1), endAngle: .degrees(450), clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct AutosaveCheck: Shape {
    func path(in rect: CGRect) -> Path {
        let s: CGFloat = min(rect.width / 22, rect.height / 16)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 7.6 * s, y: rect.minY + 9.9 * s))
        path.addLine(to: CGPoint(x: rect.minX + 10 * s, y: rect.minY + 12.1 * s))
        path.addLine(to: CGPoint(x: rect.minX + 14.2 * s, y: rect.minY + 7.3 * s))
        return path
    }
}
