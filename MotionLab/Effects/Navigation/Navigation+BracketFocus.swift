import SwiftUI
import UIKit

extension Effect {
    static let navigationBracketFocus = Effect(
        id: "navigation.bracket-focus",
        category: .navigation,
        interaction: .tap,
        name: L("Bracket Focus Tabs", "对焦框标签"),
        summary: L(
            "Four corner brackets let go of one label, stretch across the row and clamp onto the next like a camera locking focus.",
            "四枚角标松开当前标签，拉长着飞过整行，再像相机锁焦一样夹住下一个标签。"
        ),
        prompt: L(
            "A camera-style mode row (Photo, Video, Portrait, Pano) under a viewfinder card. The selection is not a pill but four L-shaped corner brackets (9 pt arms, 2 pt rounded stroke) hugging the active label. On tap the brackets first open 5 pt outward in 0.12 s and dim, then fly: the front pair travels on a quick spring (0.7 × the 0.42 s response) while the rear pair follows on a slower one (1.3 ×), so the frame stretches wide in flight. On arrival they clamp shut with an underdamped spring (0.28 s, damping 0.45), pinching 1 pt past rest before settling; the label brightens and grows to 106% and a light haptic fires on the clamp. The viewfinder above re-crops to the mode's aspect ratio on the same spring. Precise, optical, instrument-like.",
            "取景器卡片下方是一排相机模式（照片、视频、人像、全景）。选中指示不是胶囊，而是四枚 L 形角标（臂长 9 pt、2 pt 圆头描边）夹住当前标签。点击后，角标先在 0.12 秒内向外张开 5 pt 并变暗，随后起飞：前方一对用较快的弹簧（0.42 秒响应的 0.7 倍），后方一对用较慢的（1.3 倍）跟上，飞行中框被拉宽。到位时以欠阻尼弹簧（0.28 秒、阻尼 0.45）合拢，越过静止位置约 1 pt 再回稳；标签变亮并放大到 106%，合拢瞬间一次轻触感。取景器用同一根弹簧裁切到该模式的画幅。精准，带光学仪器感。"
        ),
        implementation: L(
            "The left and right bracket pairs are separate views positioned from two indices; each pair carries its own animation(_:value:) spring chosen by travel direction, which produces the stretch. A third value, open, is eased out on tap and sprung back by a short Task to make the clamp.",
            "左右两对角标是各自独立的视图，位置由两个索引决定；每对带有按移动方向选取的 animation(_:value:) 弹簧，由此产生拉伸。第三个数值 open 在点击时缓出、再由一个短 Task 用弹簧收回，形成夹紧动作。"
        ),
        apis: ["animation(_:value:)", "Shape", "spring(response:dampingFraction:)", "contentTransition(.symbolEffect(.replace))", "Task.sleep"],
        tags: ["brackets", "focus", "camera modes", "tab indicator", "角标", "对焦框", "相机模式", "标签指示器"],
        params: [
            .slider("response", L("Flight response", "飞行响应"), 0.25...0.8, default: 0.42, unit: "s"),
            .slider("grip", L("Clamp damping", "夹紧阻尼"), 0.25...1.0, default: 0.45),
            .slider("open", L("Opening", "张开距离"), 0...10, default: 5, decimals: 0, unit: "pt"),
            .slider("arm", L("Arm length", "角标臂长"), 5...14, default: 9, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        BracketFocusDemo(ctx: ctx)
    }
}

private struct BracketMode {
    let title: LocalizedText
    let symbol: String
    let colors: [Color]
    let size: CGSize
}

private let bracketModes: [BracketMode] = [
    BracketMode(title: L("PHOTO", "照片"), symbol: "camera.fill", colors: [Palette.indigo, Palette.violet], size: CGSize(width: 216, height: 162)),
    BracketMode(title: L("VIDEO", "视频"), symbol: "video.fill", colors: [Palette.coral, Palette.pink], size: CGSize(width: 280, height: 158)),
    BracketMode(title: L("PORTRAIT", "人像"), symbol: "person.crop.square.fill", colors: [Palette.mint, Palette.sky], size: CGSize(width: 132, height: 172)),
    BracketMode(title: L("PANO", "全景"), symbol: "pano.fill", colors: [Palette.amber, Palette.coral], size: CGSize(width: 300, height: 104)),
]

private enum BracketMetrics {
    static let fontSize: CGFloat = 13
    static let kerning: CGFloat = 0.8
    /// Two-character Chinese labels get more air than the longer English ones.
    static func padding(_ language: AppLanguage) -> CGFloat { language == .zh ? 20 : 13 }
    static let rowHeight: CGFloat = 36
    /// How far inside the cell the brackets rest.
    static let inset = CGSize(width: 3, height: 4)

    /// Label width measured with UIKit, so the bracket frame is known without a layout pass (stills included).
    static func labelWidth(_ string: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let size = (string as NSString).size(withAttributes: [.font: font, .kern: kerning])
        return ceil(size.width)
    }
}

/// One L-shaped corner (top-left); the other three are mirrored copies.
private struct BracketCorner: Shape {
    var arm: CGFloat

    var animatableData: CGFloat {
        get { arm }
        set { arm = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = min(4, arm * 0.45)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: arm))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
        path.addLine(to: CGPoint(x: arm, y: 0))
        return path
    }
}

private struct BracketFocusDemo: View {
    let ctx: DemoContext
    @State private var selection = 0
    /// Cell whose leading edge the left bracket pair sits on, and whose trailing edge the right pair sits on.
    @State private var leftIndex = 0
    @State private var rightIndex = 0
    /// The label currently clamped (none while the brackets are in flight).
    @State private var gripped: Int? = 0
    @State private var open: CGFloat = 0
    @State private var movingRight = true
    @State private var clampTask: Task<Void, Never>?

    private var cells: [CGRect] {
        var x: CGFloat = 0
        return bracketModes.map { mode in
            let width: CGFloat = BracketMetrics.labelWidth(mode.title(ctx.language)) + BracketMetrics.padding(ctx.language) * 2
            defer { x += width }
            return CGRect(x: x, y: 0, width: width, height: BracketMetrics.rowHeight)
        }
    }

    private func edgeSpring(front: Bool) -> Animation {
        .spring(response: ctx["response"] * (front ? 0.7 : 1.3), dampingFraction: front ? 0.78 : 0.86)
    }

    var body: some View {
        VStack(spacing: 16) {
            viewfinder
            row
            DemoHint(text: L("Tap a mode, or swipe the viewfinder", "点击模式，或左右滑动取景器"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { select((selection + 1) % bracketModes.count) }
        .onDisappear { clampTask?.cancel() }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        let mode: BracketMode = bracketModes[selection]
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: mode.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            thirdsGrid
            Image(systemName: mode.symbol)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.94))
                .contentTransition(.symbolEffect(.replace))
                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
        }
        .frame(width: mode.size.width, height: mode.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: mode.colors[0].opacity(0.35), radius: 18, y: 10)
        .frame(width: 300, height: 174)
        .contentShape(Rectangle())
        .pageSafeHorizontalDrag(onChanged: { _ in }, onEnded: swiped)
    }

    private var thirdsGrid: some View {
        ZStack {
            HStack(spacing: 0) {
                Spacer()
                Rectangle().frame(width: 0.5)
                Spacer()
                Rectangle().frame(width: 0.5)
                Spacer()
            }
            VStack(spacing: 0) {
                Spacer()
                Rectangle().frame(height: 0.5)
                Spacer()
                Rectangle().frame(height: 0.5)
                Spacer()
            }
        }
        .foregroundStyle(Color.white.opacity(0.28))
    }

    // MARK: Mode row

    private var row: some View {
        let frames: [CGRect] = cells
        let total: CGFloat = frames.last?.maxX ?? 0
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(0..<bracketModes.count, id: \.self) { index in
                    label(index, width: frames[index].width)
                }
            }
            brackets(frames)
        }
        .frame(width: total, height: BracketMetrics.rowHeight, alignment: .topLeading)
    }

    private func label(_ index: Int, width: CGFloat) -> some View {
        let active: Bool = gripped == index
        return Text(bracketModes[index].title, ctx.language)
            .font(.system(size: BracketMetrics.fontSize, weight: .semibold))
            .kerning(BracketMetrics.kerning)
            .foregroundStyle(active ? Color.primary : Color.secondary.opacity(0.75))
            .scaleEffect(active ? 1.06 : 1)
            .fixedSize()
            .frame(width: width, height: BracketMetrics.rowHeight)
            .contentShape(Rectangle())
            .onTapGesture { select(index) }
    }

    /// Left pair and right pair animate separately, so the frame stretches while it travels.
    private func brackets(_ frames: [CGRect]) -> some View {
        let arm: CGFloat = ctx.cg("arm")
        let spread: CGFloat = open * ctx.cg("open")
        let left: CGFloat = frames[min(leftIndex, frames.count - 1)].minX + BracketMetrics.inset.width - spread
        let right: CGFloat = frames[min(rightIndex, frames.count - 1)].maxX - BracketMetrics.inset.width + spread
        let top: CGFloat = BracketMetrics.inset.height - spread
        let bottom: CGFloat = BracketMetrics.rowHeight - BracketMetrics.inset.height + spread
        let tint: Color = Palette.indigo.opacity(1 - 0.45 * Double(open))
        return ZStack(alignment: .topLeading) {
            Group {
                corner(arm, flipX: false, flipY: false).offset(x: left, y: top)
                corner(arm, flipX: false, flipY: true).offset(x: left, y: bottom - arm)
            }
            .animation(edgeSpring(front: !movingRight), value: leftIndex)
            Group {
                corner(arm, flipX: true, flipY: false).offset(x: right - arm, y: top)
                corner(arm, flipX: true, flipY: true).offset(x: right - arm, y: bottom - arm)
            }
            .animation(edgeSpring(front: movingRight), value: rightIndex)
        }
        .foregroundStyle(tint)
        .allowsHitTesting(false)
    }

    private func corner(_ arm: CGFloat, flipX: Bool, flipY: Bool) -> some View {
        BracketCorner(arm: arm)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: arm, height: arm)
            .scaleEffect(x: flipX ? -1 : 1, y: flipY ? -1 : 1)
    }

    // MARK: Actions

    private func swiped(_ value: DragGesture.Value?) {
        guard let value, abs(value.translation.width) > 30 else { return }
        let next: Int = selection + (value.translation.width < 0 ? 1 : -1)
        guard bracketModes.indices.contains(next) else { return }
        select(next)
    }

    private func select(_ index: Int) {
        guard index != selection else { return }
        movingRight = index > selection
        clampTask?.cancel()
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.8)) { selection = index }
        withAnimation(.easeOut(duration: 0.12)) {
            open = 1
            gripped = nil
        }
        leftIndex = index
        rightIndex = index
        let travel: Double = ctx["response"] * 0.62
        let grip: Double = ctx["grip"]
        let silent: Bool = ctx.isPreview
        clampTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(travel))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: grip)) {
                open = 0
                gripped = index
            }
            if !silent { Haptics.tap(.light) }
        }
    }
}
