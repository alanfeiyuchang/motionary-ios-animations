import SwiftUI

extension Effect {
    static let textFocusPull = Effect(
        id: "text.focus-pull",
        category: .text,
        interaction: .gesture,
        name: L("Rack Focus", "移焦"),
        summary: L("Three lines sit at different depths; focus racks from one to another, hunting slightly before it locks.", "三行文字处在不同景深；焦点从一行拉到另一行，轻微来回寻焦后锁定。"),
        prompt: L(
            "Three lines of type are staged like subjects at different distances: a huge near word, a headline in the middle and a small far caption, with a few coloured lights behind. One focus distance drives them all: each line is blurred in proportion to how far it is from the focal plane (14 pt of blur per half of the range), fades to 60% and swells 5% when fully out of focus, while the lights grow into soft bokeh discs. Tapping a line racks focus to it on a spring (response 0.75 s, damping 0.55), so the lens overshoots and hunts once before settling; an autofocus bracket contracts onto the line, amber while hunting and green once locked. The frame breathes about 4% with the pull. Dragging the focus scale pulls focus by hand.",
            "三行文字像不同距离的被摄体一样摆放：近处一个巨大的词，中间是标题，远处是一行小字，背后还有几盏彩色的灯。它们都由同一个对焦距离驱动：每行的模糊量与它离焦平面的距离成正比（每半个量程14pt模糊），完全失焦时淡到60%并放大5%，灯光则晕成柔和的焦外光斑。点击某一行，焦点以弹簧（响应0.75秒、阻尼0.55）拉过去，镜头会先越过一点、来回寻焦一次再停稳；自动对焦框收拢到这一行上，寻焦时为琥珀色，合焦后变绿。画面随移焦有约4%的呼吸。拖动下方的对焦刻度则可以手动移焦。"
        ),
        implementation: L(
            "The scene is one Animatable view whose animatable value is the focus distance; every layer derives blur, opacity and scale from |focus − depth|, so a single spring on the focus produces the overshoot on all layers at once. The scale below is a DragGesture that sets the same value directly.",
            "整个场景是一个 Animatable 视图，可动画的值就是对焦距离；每一层都由 |焦点 − 景深| 推算模糊、透明度与缩放，于是只要给焦点加一根弹簧，所有层就一起出现过冲。下方刻度是一个直接设置该值的 DragGesture。"
        ),
        apis: ["Animatable", "blur(radius:)", "spring(response:dampingFraction:)", "DragGesture", "scaleEffect"],
        tags: ["focus", "rack focus", "depth of field", "bokeh", "camera", "对焦", "移焦", "景深", "焦外", "镜头"],
        params: [
            .slider("aperture", L("Blur amount", "模糊量"), 4...28, default: 14, decimals: 0, unit: "pt"),
            .slider("response", L("Pull duration", "移焦时长"), 0.3...1.4, default: 0.75, unit: "s"),
            .slider("damping", L("Hunting damping", "寻焦阻尼"), 0.35...1, default: 0.55),
            .toggle("breathing", L("Focus breathing", "呼吸效应"), default: true),
        ]
    ) { ctx in
        TextFocusPullDemo(ctx: ctx)
    }
}

private struct TextFocusPullDemo: View {
    let ctx: DemoContext
    @State private var focus: Double = 0.5
    @State private var target: Int? = 1
    @State private var step = 0

    private static let tour: [Int] = [0, 1, 2, 1]

    var body: some View {
        VStack(spacing: 10) {
            FocusPullScene(
                focus: focus,
                target: target,
                aperture: ctx.cg("aperture"),
                breathing: ctx.bool("breathing"),
                language: ctx.language,
                onPick: { index in
                    Haptics.tap(.light)
                    pick(index)
                },
                onScrub: { scrub($0) }
            )
            DemoHint(text: L("Tap a line, or drag the focus scale", "点击某一行，或拖动对焦刻度"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) {
            pick(Self.tour[step % Self.tour.count])
            step += 1
        }
    }

    private func pick(_ index: Int) {
        target = index
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            focus = FocusPullScene.depths[index]
        }
    }

    private func scrub(_ value: Double) {
        let clamped: Double = min(max(value, 0), 1)
        focus = clamped
        let depths = FocusPullScene.depths
        let nearest: Int = depths.indices.min { abs(depths[$0] - clamped) < abs(depths[$1] - clamped) } ?? 1
        let next: Int? = abs(depths[nearest] - clamped) < 0.12 ? nearest : nil
        guard next != target else { return }
        target = next
        if next != nil { Haptics.selection() }
    }
}

private struct FocusPullScene: View, Animatable {
    var focus: Double
    let target: Int?
    let aperture: CGFloat
    let breathing: Bool
    let language: AppLanguage
    let onPick: (Int) -> Void
    let onScrub: (Double) -> Void

    /// Near, middle, far.
    static let depths: [Double] = [0, 0.5, 1]
    private static let rulerWidth: CGFloat = 250

    var animatableData: Double {
        get { focus }
        set { focus = newValue }
    }

    var body: some View {
        let breathe: CGFloat = breathing ? 1 + 0.08 * CGFloat(focus - 0.5) : 1
        VStack(spacing: 6) {
            ZStack {
                bokeh
                plane(2).offset(x: 58, y: -84)
                plane(1).offset(x: 4, y: -22)
                plane(0).offset(x: -40, y: 58)
            }
            .frame(width: 330, height: 228)
            .scaleEffect(breathe)
            ruler
        }
    }

    // MARK: Planes

    private func label(_ index: Int) -> some View {
        let zh = language == .zh
        return Group {
            switch index {
            case 0:
                Text(verbatim: zh ? "近景" : "NEAR")
                    .font(.system(size: zh ? 84 : 78, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.sunset)
            case 1:
                Text(verbatim: zh ? "把焦点拉到这里" : "Pull focus here")
                    .font(.system(size: zh ? 32 : 34, weight: .heavy))
                    .foregroundStyle(.primary)
            default:
                Text(verbatim: zh ? "远处亮着几盏灯" : "lights in the distance")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.8))
            }
        }
        .lineLimit(1)
        .fixedSize()
    }

    private func plane(_ index: Int) -> some View {
        let defocus: Double = abs(focus - Self.depths[index])
        let locked: Bool = defocus < 0.035
        let picked: Bool = target == index
        return label(index)
            .blur(radius: aperture * CGFloat(defocus) * 2)
            .opacity(1 - 0.4 * min(defocus, 1))
            .scaleEffect(1 + 0.05 * CGFloat(min(defocus, 1)))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay {
                FocusBracket()
                    .stroke(locked ? Palette.green : Palette.amber, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .opacity(picked ? 1 : 0)
                    .scaleEffect(picked ? 1 : 1.25)
                    .animation(.spring(response: 0.35, dampingFraction: 0.65), value: picked)
            }
            .contentShape(Rectangle())
            .onTapGesture { onPick(index) }
    }

    private var bokeh: some View {
        let lights: [(x: CGFloat, y: CGFloat, color: Color, size: CGFloat)] = [
            (-118, -80, Palette.amber, 1.0), (-62, -98, Palette.pink, 0.7), (-20, -70, Palette.sky, 0.85),
            (120, -40, Palette.violet, 0.9), (132, 30, Palette.amber, 0.6), (84, 6, Palette.mint, 0.75),
            (-136, -18, Palette.sky, 0.55),
        ]
        // The lights sit behind the far line, so they are never fully sharp.
        let defocus: Double = abs(focus - 1.3)
        let diameter: CGFloat = 6 + aperture * CGFloat(defocus) * 2.6
        let alpha: Double = 0.8 / (1 + defocus * 2.4)
        return ZStack {
            ForEach(lights.indices, id: \.self) { index in
                let light = lights[index]
                Circle()
                    .fill(light.color.opacity(alpha))
                    .overlay(Circle().strokeBorder(light.color.opacity(alpha * 0.9), lineWidth: 1))
                    .frame(width: diameter * light.size, height: diameter * light.size)
                    .offset(x: light.x, y: light.y)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Focus scale

    private var ruler: some View {
        let width: CGFloat = Self.rulerWidth
        let x: CGFloat = CGFloat(min(max(focus, -0.05), 1.05)) * width
        let marks: [String] = ["0.5 m", "2 m", "∞"]
        return VStack(spacing: 3) {
            ZStack(alignment: .leading) {
                FocusTicks()
                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                    .frame(width: width, height: 14)
                Capsule()
                    .fill(Palette.amber)
                    .frame(width: 3, height: 24)
                    .shadow(color: Palette.amber.opacity(0.6), radius: 5)
                    .offset(x: x - 1.5)
            }
            .frame(width: width, height: 26)
            HStack {
                ForEach(marks.indices, id: \.self) { index in
                    let near: Bool = abs(focus - Self.depths[index]) < 0.035
                    Text(verbatim: marks[index])
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(near ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : (index == 1 ? .center : .trailing))
                }
            }
            .frame(width: width + 24)
        }
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onScrub(Double((value.location.x - 14 - 12) / width))
                }
        )
    }
}

/// Four corner brackets, like a camera's autofocus frame.
private struct FocusBracket: Shape {
    func path(in rect: CGRect) -> Path {
        let arm: CGFloat = min(12, min(rect.width, rect.height) / 3)
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
        }
        return path
    }
}

private struct FocusTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = 24
        for index in 0...count {
            let x: CGFloat = rect.minX + rect.width * CGFloat(index) / CGFloat(count)
            let tall: Bool = index % 12 == 0
            let mid: Bool = index % 6 == 0
            let height: CGFloat = tall ? rect.height : (mid ? rect.height * 0.7 : rect.height * 0.4)
            path.move(to: CGPoint(x: x, y: rect.midY - height / 2))
            path.addLine(to: CGPoint(x: x, y: rect.midY + height / 2))
        }
        return path
    }
}
