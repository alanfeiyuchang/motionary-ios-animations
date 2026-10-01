import SwiftUI

extension Effect {
    static let morphThumbToPlayer = Effect(
        id: "morph.thumb-to-player",
        category: .morph,
        interaction: .gesture,
        name: L("Thumbnail to Player to PiP", "缩略图变播放器再变小窗"),
        summary: L(
            "A feed thumbnail grows into the player; drag it down and it shrinks under your finger into a picture-in-picture window docked in the corner.",
            "信息流里的缩略图长成播放器；向下拖，它跟着手指缩成停靠在角落的画中画小窗。"
        ),
        prompt: L(
            "A video feed whose first card holds a 292 × 164 pt thumbnail with 16 pt corners. Tapping it expands the same video surface into a full-width 316 × 178 pt player pinned to the top on a spring (response 0.5 s, damping 0.82), corners squaring off, while a details sheet with title, channel and an up-next row rises 30 pt and fades in beneath. Dragging the player down scrubs a second progress one-to-one: the surface shrinks toward a 150 pt wide window in the bottom-right corner, corners round to 12 pt, the sheet fades and the feed returns behind it. Releasing past 40% (or with a downward flick) docks it; otherwise it springs back. Tapping the window re-expands it, its close button sends it home into the thumbnail. One continuous object through three states.",
            "视频信息流的第一张卡片里有一张 292 × 164pt、16pt 圆角的缩略图。点它，同一块视频画面乘弹簧（响应 0.5 秒、阻尼 0.82）扩展成钉在顶部的 316 × 178pt 全宽播放器，圆角变直，下方的详情页（标题、频道、接下来播放）上浮 30pt 并淡入。向下拖动播放器，第二个进度一比一跟手：画面朝右下角 150pt 宽的小窗收缩，圆角变为 12pt，详情页淡出，信息流重新露出。松手时超过 40%（或带向下的甩动）就停靠成小窗，否则弹回。点小窗重新展开，点它的关闭按钮则飞回缩略图原位。"
        ),
        implementation: L(
            "Two animatable progresses (open, dock) drive one surface: its rect is lerp(lerp(thumbnail, player, open), pip, dock). The drag writes dock directly, the release animates it with a spring using the predicted end, and the overlays (play glyph, controls, PiP buttons) are keyed to sub-ranges of both values.",
            "两个可动画进度（展开、停靠）驱动同一块画面：矩形为 lerp(lerp(缩略图, 播放器, 展开), 小窗, 停靠)。拖动时直接写入停靠进度，松手后按预测落点用弹簧收尾；播放图标、控制条和小窗按钮分别对应两个进度的子区间。"
        ),
        apis: ["Animatable", "AnimatablePair", "UIGestureRecognizerRepresentable", "TimelineView", "Canvas", "spring(response:dampingFraction:)"],
        tags: ["video", "player", "picture in picture", "pip", "dock", "视频", "播放器", "画中画", "小窗"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .slider("pip", L("PiP width", "小窗宽度"), 110...190, default: 150, decimals: 0, unit: "pt"),
            .slider("threshold", L("Dock threshold", "停靠阈值"), 0.2...0.8, default: 0.4),
        ]
    ) { ctx in
        ThumbPlayerDemo(ctx: ctx)
    }
}

private enum ThumbPlayerLayout {
    static let size = CGSize(width: 316, height: 306)
    static let thumb = CGRect(x: 12, y: 52, width: 292, height: 164)
    static let player = CGRect(x: 0, y: 0, width: 316, height: 178)
    static let travel: CGFloat = 170

    static func pip(width: CGFloat) -> CGRect {
        let height: CGFloat = width * 9 / 16
        return CGRect(x: size.width - 10 - width, y: size.height - 10 - height, width: width, height: height)
    }
}

private struct ThumbPlayerDemo: View {
    let ctx: DemoContext
    @State private var open: Double
    @State private var dock: Double
    @State private var dragBase: Double?
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _open = State(initialValue: ctx.isStill ? 1 : 0)
        _dock = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    private var hint: LocalizedText {
        if open < 0.5 { return L("Tap the thumbnail", "点击缩略图") }
        if dock > 0.5 { return L("Tap the window to expand", "点击小窗重新展开") }
        return L("Drag the player down", "向下拖动播放器")
    }

    var body: some View {
        VStack(spacing: 10) {
            screen
            DemoHint(text: hint, ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.3) { autoplayStep() }
    }

    private var screen: some View {
        ZStack(alignment: .topLeading) {
            Palette.surface
            MorphAnimated(AnimatablePair(open, dock)) { value in
                ThumbPlayerScene(
                    open: CGFloat(value.first),
                    dock: CGFloat(value.second),
                    pipWidth: ctx.cg("pip"),
                    isPreview: ctx.isPreview,
                    isStill: ctx.isStill,
                    language: ctx.language,
                    onTap: { tapSurface() },
                    onDock: { setDock(1) },
                    onClose: { close() },
                    onDragChanged: { dragChanged($0) },
                    onDragEnded: { dragEnded($0) }
                )
            }
        }
        .morphScreen()
    }

    private func dragChanged(_ translation: CGSize) {
        guard open > 0.5 else { return }
        let base: Double = dragBase ?? (dock > 0.5 ? 1 : 0)
        if dragBase == nil { dragBase = base }
        let raw: Double = base + Double(translation.height / ThumbPlayerLayout.travel)
        // Soft limits past either end.
        if raw < 0 {
            dock = -Double(rubberBand(CGFloat(-raw), limit: 0.25))
        } else if raw > 1 {
            dock = 1 + Double(rubberBand(CGFloat(raw - 1), limit: 0.12))
        } else {
            dock = raw
        }
    }

    private func dragEnded(_ end: PageSafePanEnd?) {
        guard let base = dragBase else { return }
        dragBase = nil
        let travelled: CGFloat = end?.predictedEndTranslation.height ?? CGFloat(dock - base) * ThumbPlayerLayout.travel
        let predicted: Double = base + Double(travelled / ThumbPlayerLayout.travel)
        let threshold: Double = ctx["threshold"]
        let target: Double = base < 0.5
            ? (predicted > threshold ? 1 : 0)
            : (predicted < 1 - threshold ? 0 : 1)
        if !ctx.isPreview, target != base { Haptics.tap(.medium) }
        withAnimation(spring) { dock = target }
    }

    // MARK: Actions

    private func tapSurface() {
        if open < 0.5 {
            if !ctx.isPreview { Haptics.tap(.light) }
            withAnimation(spring) {
                open = 1
                dock = 0
            }
        } else if dock > 0.5 {
            setDock(0)
        }
    }

    private func setDock(_ value: Double) {
        guard open > 0.5 else { return }
        if !ctx.isPreview { Haptics.tap(.medium) }
        withAnimation(spring) { dock = value }
    }

    private func close() {
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(spring) {
            open = 0
            dock = 0
        }
    }

    private func autoplayStep() {
        switch autoStep % 5 {
        case 0: tapSurface()
        case 1: setDock(1)
        case 2: setDock(0)
        case 3: setDock(1)
        default: close()
        }
        autoStep += 1
    }
}

private struct ThumbPlayerScene: View {
    let open: CGFloat
    let dock: CGFloat
    let pipWidth: CGFloat
    let isPreview: Bool
    let isStill: Bool
    let language: AppLanguage
    let onTap: () -> Void
    let onDock: () -> Void
    let onClose: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (PageSafePanEnd?) -> Void

    private var zh: Bool { language == .zh }

    var body: some View {
        let opened: CGFloat = MorphMath.unit(open)
        let docked: CGFloat = MorphMath.unit(dock)
        let full: CGRect = MorphMath.lerp(ThumbPlayerLayout.thumb, ThumbPlayerLayout.player, open)
        let rect: CGRect = MorphMath.lerp(full, ThumbPlayerLayout.pip(width: pipWidth), dock)
        let radius: CGFloat = MorphMath.lerp(MorphMath.lerp(16, 0, opened), 12, docked)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // How much of the "full player" state is showing.
        let sheet: CGFloat = opened * (1 - MorphMath.smooth(dock, 0, 0.7))
        ZStack(alignment: .topLeading) {
            ThumbPlayerFeed(zh: zh, playing: opened)
            ThumbPlayerDetails(zh: zh)
                .offset(y: ThumbPlayerLayout.player.maxY + (1 - opened) * 30 + docked * 46)
                .opacity(Double(sheet))
                .allowsHitTesting(false)
            ThumbPlayerVideo(isPreview: isPreview, isStill: isStill)
                .overlay { overlays(opened: opened, docked: docked, width: rect.width) }
                .frame(width: rect.width, height: rect.height)
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.14 * Double(docked)), lineWidth: 1))
                .shadow(color: .black.opacity(0.14 + 0.2 * Double(docked)), radius: 8 + 10 * docked, y: 4 + 6 * docked)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .gesture(PageSafePan(directions: [.down, .up], isEnabled: open > 0.5, onChanged: onDragChanged, onEnded: onDragEnded))
                .position(x: rect.midX, y: rect.midY)
        }
        .frame(width: ThumbPlayerLayout.size.width, height: ThumbPlayerLayout.size.height, alignment: .topLeading)
    }

    private func overlays(opened: CGFloat, docked: CGFloat, width: CGFloat) -> some View {
        let controls: Double = Double(opened * (1 - MorphMath.smooth(dock, 0, 0.35)))
        let mini: Double = Double(MorphMath.smooth(dock, 0.7, 1))
        return ZStack {
            // Thumbnail state: play glyph and duration.
            Image(systemName: "play.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.4), in: Circle())
                .scaleEffect(1 + 0.5 * opened)
                .opacity(Double(1 - MorphMath.smooth(open, 0, 0.4)))
            Text(verbatim: "4:12")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(8)
                .opacity(Double(1 - MorphMath.smooth(open, 0, 0.4)))
            // Full player: minimise button.
            Button(action: onDock) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.35), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
            .opacity(controls)
            .allowsHitTesting(controls > 0.6)
            // PiP: close button.
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.black.opacity(0.45), in: Circle())
                    .contentShape(Circle().inset(by: -6))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(6)
            .opacity(mini)
            .allowsHitTesting(mini > 0.6)
        }
    }
}

/// The "video": a dusk landscape whose ridges scroll at different speeds, with a scrubber along the bottom.
private struct ThumbPlayerVideo: View {
    let isPreview: Bool
    let isStill: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: isPreview), paused: isStill)) { timeline in
            let time: Double = isStill ? 7.5 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600)
            Canvas { context, size in
                ThumbPlayerVideo.draw(&context, size: size, time: time)
            }
        }
    }

    private static func draw(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x1B1F5E), Color(hex: 0x8A3F8F), Color(hex: 0xFF8A5C), Color(hex: 0xFFD08A)]),
                startPoint: CGPoint(x: size.width * 0.4, y: 0),
                endPoint: CGPoint(x: size.width * 0.55, y: size.height)
            )
        )
        let sunRadius: CGFloat = size.height * 0.16
        let sun = CGPoint(x: size.width * 0.68, y: size.height * (0.5 + 0.02 * CGFloat(sin(time * 0.4))))
        context.fill(
            Path(ellipseIn: CGRect(x: sun.x - sunRadius * 3, y: sun.y - sunRadius * 3, width: sunRadius * 6, height: sunRadius * 6)),
            with: .radialGradient(Gradient(colors: [Color.white.opacity(0.45), .clear]), center: sun, startRadius: 0, endRadius: sunRadius * 3)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: sun.x - sunRadius, y: sun.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)),
            with: .color(Color(hex: 0xFFF1C9))
        )
        let layers: [(CGFloat, CGFloat, Double, Color)] = [
            (0.58, 0.16, 0.05, Color(hex: 0x7A3C86).opacity(0.85)),
            (0.72, 0.14, 0.11, Color(hex: 0x4A2468)),
            (0.86, 0.1, 0.2, Color(hex: 0x1F1238)),
        ]
        for (index, layer) in layers.enumerated() {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            let steps = 40
            for step in 0...steps {
                let u = Double(step) / Double(steps)
                let phase: Double = u * 5 + time * layer.2 * 3 + Double(index) * 1.7
                let ridge: Double = sin(phase) * 0.6 + sin(phase * 2.3 + 1.1) * 0.4
                let y: CGFloat = size.height * (layer.0 - layer.1 * CGFloat(ridge) * 0.5)
                path.addLine(to: CGPoint(x: size.width * CGFloat(u), y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
            context.fill(path, with: .color(layer.3))
        }
        // Scrubber.
        let played: CGFloat = CGFloat(time.truncatingRemainder(dividingBy: 24) / 24)
        let barHeight: CGFloat = max(size.height * 0.016, 2)
        context.fill(
            Path(CGRect(x: 0, y: size.height - barHeight, width: size.width, height: barHeight)),
            with: .color(.white.opacity(0.28))
        )
        context.fill(
            Path(CGRect(x: 0, y: size.height - barHeight, width: size.width * played, height: barHeight)),
            with: .color(Palette.coral)
        )
    }
}

private struct ThumbPlayerFeed: View {
    let zh: Bool
    /// 0…1: the video has left its slot.
    let playing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: zh ? "为你推荐" : "For you")
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 16)
                .frame(height: 44, alignment: .bottomLeading)
                .padding(.bottom, 8)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .frame(width: ThumbPlayerLayout.thumb.width, height: ThumbPlayerLayout.thumb.height)
                .overlay {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                        Text(verbatim: zh ? "正在播放" : "Now playing")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(Double(playing))
                }
                .padding(.horizontal, 12)
            HStack(spacing: 10) {
                Circle()
                    .fill(Palette.sunset)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: zh ? "山脊线上的黄昏延时" : "Dusk timelapse from the ridge")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(verbatim: zh ? "远山影像 · 12 万次观看" : "Farhill Films · 120K views")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Palette.sky.opacity(0.8), Palette.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: ThumbPlayerLayout.thumb.width, height: 120)
                .padding(.horizontal, 12)
                .padding(.top, 4)
        }
        .frame(width: ThumbPlayerLayout.size.width, height: ThumbPlayerLayout.size.height, alignment: .top)
    }
}

private struct ThumbPlayerDetails: View {
    let zh: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: zh ? "山脊线上的黄昏延时" : "Dusk timelapse from the ridge")
                .font(.system(size: 16, weight: .bold))
            HStack(spacing: 10) {
                Circle()
                    .fill(Palette.sunset)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: zh ? "远山影像" : "Farhill Films")
                        .font(.system(size: 13, weight: .semibold))
                    Text(verbatim: zh ? "48 万订阅" : "480K subscribers")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(verbatim: zh ? "订阅" : "Subscribe")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Color.primary, in: Capsule())
            }
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.sky.opacity(0.8), Palette.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: zh ? "接下来播放" : "Up next")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(verbatim: zh ? "云海之上的清晨" : "Morning above the clouds")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(width: ThumbPlayerLayout.size.width, height: ThumbPlayerLayout.size.height - ThumbPlayerLayout.player.maxY, alignment: .top)
        .background(Palette.surface)
    }
}
