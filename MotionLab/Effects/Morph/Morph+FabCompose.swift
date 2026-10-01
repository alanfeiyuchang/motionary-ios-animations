import SwiftUI

extension Effect {
    static let morphFabCompose = Effect(
        id: "morph.fab-compose",
        category: .morph,
        interaction: .tap,
        name: L("FAB to Compose Sheet", "悬浮按钮变写信面板"),
        summary: L(
            "A floating action button swells into a compose sheet: its colour floods the surface, drains to paper, and the draft types itself in.",
            "悬浮按钮涨成写信面板：按钮的颜色先铺满表面，再褪成纸面，草稿随即逐字打出。"
        ),
        prompt: L(
            "An inbox with a 56 pt gradient floating action button in the bottom-right corner. Tapping it performs a container transform on one spring (response 0.5 s, damping 0.82): the circle's frame grows into a 300 × 268 pt sheet with 26 pt corners, its centre travelling on a curve because the horizontal move leads the vertical one. The button's colour floods the growing surface, then drains to the sheet's paper tone between 30% and 55% of the progress while the pencil scales up and fades; the header, recipient chip and subject rise in afterwards and the body types itself at 28 characters per second behind a blinking caret. The inbox sinks to 94% and dims. Send folds the sheet back into the button, which flashes a green check before the pencil returns.",
            "收件箱右下角有一枚 56pt 的渐变悬浮按钮。点它，乘一条弹簧（响应 0.5 秒、阻尼 0.82）完成容器变换：圆形外框长成 300 × 268pt、26pt 圆角的面板，水平位移领先于垂直位移，中心因此走出一条弧线。按钮的颜色先铺满正在变大的表面，在进度 30% 到 55% 之间褪成面板的纸色，铅笔图标放大淡出；随后标题栏、收件人胶囊和主题依次上浮，正文以每秒 28 个字符自动打出，末尾光标闪烁。收件箱缩到 94% 并压暗。点发送，面板折回按钮，按钮闪一下绿色对勾，再换回铅笔。"
        ),
        implementation: L(
            "An Animatable wrapper interpolates the progress; the surface rect lerps between the button and sheet rects with an eased x, a tint layer fades over a sub-range, and the sheet content (laid out at its final size) scales and fades in. A task types the body once the sheet is open.",
            "Animatable 包装器对进度插值；表面矩形在按钮与面板之间插值，x 方向另加缓动，着色层在一段子区间内淡出，面板内容按最终尺寸排版后缩放淡入。面板打开后由一个任务逐字打出正文。"
        ),
        apis: ["Animatable", "spring(response:dampingFraction:)", "contentTransition(.symbolEffect)", "Task.sleep", "RoundedRectangle"],
        tags: ["fab", "compose", "container transform", "sheet", "悬浮按钮", "写信", "容器变换", "面板"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .slider("fill", L("Colour hold", "颜色停留"), 0.2...0.9, default: 0.55),
            .slider("recede", L("Inbox scale", "收件箱缩放"), 0.85...1.0, default: 0.94),
        ]
    ) { ctx in
        FabComposeDemo(ctx: ctx)
    }
}

private enum FabComposeLayout {
    static let size = CGSize(width: 316, height: 306)
    static let fab = CGRect(x: 244, y: 234, width: 56, height: 56)
    static let sheet = CGRect(x: 8, y: 30, width: 300, height: 268)
}

private let fabComposeBody = L(
    "Trail opens at seven. I'll bring coffee and the good map.",
    "步道七点开放。咖啡和那张好用的地图我来带，山脚见。"
)

private struct FabComposeDemo: View {
    let ctx: DemoContext
    @State private var open: Bool
    @State private var typed: Int
    @State private var sent = false
    @State private var autoStep = 0
    @State private var task: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _open = State(initialValue: ctx.isStill)
        _typed = State(initialValue: ctx.isStill ? 200 : 0)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 10) {
            screen
            DemoHint(
                text: open ? L("Send, or close with ✕", "点发送，或点 ✕ 关闭") : L("Tap the compose button", "点击写信按钮"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7) { autoplayStep() }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private var screen: some View {
        ZStack(alignment: .topLeading) {
            Palette.surface
            FabComposeInbox(zh: ctx.language == .zh)
                .scaleEffect(open ? ctx.cg("recede") : 1)
            Color.black
                .opacity(open ? 0.28 : 0)
                .contentShape(Rectangle())
                .onTapGesture { close(sending: false) }
                .allowsHitTesting(open)
            MorphAnimated(open ? 1.0 : 0.0) { value in
                FabComposeSurface(
                    progress: CGFloat(value),
                    fillHold: ctx.cg("fill"),
                    typed: typed,
                    sent: sent,
                    language: ctx.language,
                    onOpen: { present() },
                    onClose: { close(sending: false) },
                    onSend: { close(sending: true) }
                )
            }
        }
        .morphScreen()
    }

    private func present() {
        guard !open else { return }
        task?.cancel()
        let preview: Bool = ctx.isPreview
        if !preview { Haptics.tap(.medium) }
        typed = 0
        sent = false
        withAnimation(spring) { open = true }
        let total: Int = fabComposeBody(ctx.language).count
        let wait: Double = ctx["response"] * 0.9
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            var count = 0
            while count < total, !Task.isCancelled {
                count += 1
                typed = count
                try? await Task.sleep(for: .seconds(1.0 / 28.0))
            }
        }
    }

    private func close(sending: Bool) {
        guard open else { return }
        task?.cancel()
        let preview: Bool = ctx.isPreview
        if !preview {
            if sending { Haptics.success() } else { Haptics.tap(.light) }
        }
        withAnimation(spring) {
            open = false
            sent = sending
        }
        guard sending else { return }
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.25))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { sent = false }
        }
    }

    private func autoplayStep() {
        switch autoStep % 4 {
        case 0, 2: present()
        case 1: close(sending: true)
        default: close(sending: false)
        }
        autoStep += 1
    }
}

private struct FabComposeSurface: View {
    let progress: CGFloat
    let fillHold: CGFloat
    let typed: Int
    let sent: Bool
    let language: AppLanguage
    let onOpen: () -> Void
    let onClose: () -> Void
    let onSend: () -> Void

    private var zh: Bool { language == .zh }

    var body: some View {
        let open: CGFloat = MorphMath.unit(progress)
        let fab: CGRect = FabComposeLayout.fab
        let sheet: CGRect = FabComposeLayout.sheet
        // x eases out while y stays linear, so the centre travels on an arc.
        let lead: CGFloat = progress < 0 || progress > 1 ? progress : 1 - pow(1 - progress, 1.7)
        let width: CGFloat = max(MorphMath.lerp(fab.width, sheet.width, progress), 30)
        let height: CGFloat = max(MorphMath.lerp(fab.height, sheet.height, progress), 30)
        let midX: CGFloat = MorphMath.lerp(fab.midX, sheet.midX, lead)
        let midY: CGFloat = MorphMath.lerp(fab.midY, sheet.midY, progress)
        let radius: CGFloat = min(MorphMath.lerp(28, 26, open), min(width, height) / 2)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let tint: Double = Double(1 - MorphMath.smooth(progress, fillHold * 0.55, fillHold))
        ZStack {
            shape.fill(Palette.elevated)
            FabComposeSheet(progress: progress, typed: typed, language: language, onClose: onClose, onSend: onSend)
                .frame(width: sheet.width, height: sheet.height)
                .scaleEffect(0.88 + 0.12 * open, anchor: .top)
                .frame(width: width, height: height, alignment: .top)
                .opacity(Double(MorphMath.smooth(progress, fillHold * 0.7, fillHold + 0.3)))
                .allowsHitTesting(progress > 0.7)
            shape
                .fill(sent ? AnyShapeStyle(Palette.green) : AnyShapeStyle(Palette.primary))
                .opacity(tint)
                .allowsHitTesting(false)
            Image(systemName: sent ? "checkmark" : "square.and.pencil")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .scaleEffect(1 + 1.4 * open)
                .opacity(Double(1 - MorphMath.smooth(progress, 0, 0.28)))
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.28 * tint), lineWidth: 1))
        .shadow(
            color: (sent ? Palette.green : Palette.indigo).opacity(0.38 * tint),
            radius: 12, y: 8
        )
        .shadow(color: .black.opacity(0.24 * Double(open)), radius: 24, y: 14)
        .contentShape(shape)
        .onTapGesture {
            if progress < 0.5 { onOpen() }
        }
        .position(x: midX, y: midY)
    }
}

private struct FabComposeSheet: View {
    let progress: CGFloat
    let typed: Int
    let language: AppLanguage
    let onClose: () -> Void
    let onSend: () -> Void

    private var zh: Bool { language == .zh }

    private func rise(_ step: Int) -> CGFloat {
        let start: CGFloat = 0.55 + 0.07 * CGFloat(step)
        return (1 - MorphMath.smooth(progress, start, start + 0.3)) * 14
    }

    var body: some View {
        let text: String = fabComposeBody(language)
        let shown = String(text.prefix(typed))
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.07), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text(verbatim: zh ? "新邮件" : "New Message")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Palette.primaryStrong, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)
            .offset(y: rise(0))
            field(label: zh ? "收件人" : "To") {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Palette.sunset)
                        .frame(width: 18, height: 18)
                    Text(verbatim: zh ? "陈米娅" : "Mia Chen")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.leading, 3)
                .padding(.trailing, 9)
                .frame(height: 24)
                .background(Palette.indigo.opacity(0.14), in: Capsule())
            }
            .offset(y: rise(1))
            field(label: zh ? "主题" : "Subject") {
                Text(verbatim: zh ? "周六去爬山" : "Saturday hike")
                    .font(.system(size: 14, weight: .semibold))
            }
            .offset(y: rise(2))
            FabComposeTyped(text: shown)
                .padding(.top, 12)
                .offset(y: rise(3))
            Spacer(minLength: 0)
            HStack(spacing: 18) {
                Image(systemName: "paperclip")
                Image(systemName: "photo")
                Image(systemName: "textformat")
                Spacer()
                Text(verbatim: zh ? "草稿已保存" : "Draft saved")
                    .font(.system(size: 11))
            }
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .offset(y: rise(4))
        }
        .padding(14)
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(verbatim: label)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                content()
                Spacer(minLength: 0)
            }
            .frame(height: 38)
            Rectangle()
                .fill(Palette.stroke)
                .frame(height: 1)
        }
    }
}

/// The typed body with a caret that is part of the text run, so it always sits after the last glyph.
private struct FabComposeTyped: View {
    let text: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let on: Bool = Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            (Text(verbatim: text) + Text(verbatim: "|").foregroundStyle(Palette.indigo.opacity(on ? 1 : 0)))
                .font(.system(size: 14))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FabComposeInbox: View {
    let zh: Bool

    private static let senders: [LocalizedText] = [
        L("Mia Chen", "陈米娅"), L("Studio Weekly", "工作室周报"), L("Noah Kim", "金诺亚"), L("Orbit Travel", "轨道旅行"),
    ]
    private static let subjects: [LocalizedText] = [
        L("Are we still on for Saturday?", "周六的计划还照常吗？"), L("Five things we shipped", "本周上线的五件事"),
        L("Photos from the ridge", "山脊上拍的照片"), L("Your itinerary is ready", "你的行程已生成"),
    ]
    private static let tints: [Color] = [Palette.coral, Palette.indigo, Palette.mint, Palette.amber]
    private static let times: [String] = ["9:41", "8:15", "7:02", "6:30"]

    var body: some View {
        let language: AppLanguage = zh ? .zh : .en
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: zh ? "收件箱" : "Inbox")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, 16)
                .frame(height: 52, alignment: .bottomLeading)
                .padding(.bottom, 8)
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: 11) {
                    Circle()
                        .fill(LinearGradient(colors: [FabComposeInbox.tints[index].opacity(0.7), FabComposeInbox.tints[index]], startPoint: .top, endPoint: .bottom))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(verbatim: String(FabComposeInbox.senders[index](language).prefix(1)))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(FabComposeInbox.senders[index], language)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(verbatim: FabComposeInbox.times[index])
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Text(FabComposeInbox.subjects[index], language)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Palette.stroke)
                        .frame(height: 1)
                        .padding(.leading, 63)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: FabComposeLayout.size.width, height: FabComposeLayout.size.height)
    }
}
