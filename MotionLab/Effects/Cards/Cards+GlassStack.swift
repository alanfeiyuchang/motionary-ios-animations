import SwiftUI

extension Effect {
    static let cardsGlassStack = Effect(
        id: "cards.glass-stack",
        category: .cards,
        interaction: .gesture,
        name: L("Glass Stack", "玻璃卡片叠层"),
        summary: L("Three frosted panes stacked in depth: drag the front one and the stack tilts, layers slide apart and the colours beneath shift.", "三片磨砂玻璃前后叠放：拖动最前面一片，整叠随之倾斜，各层错开滑动，底下的色彩也跟着游移。"),
        prompt: L(
            "Three frosted-glass panes (232×148 pt, 26 pt corners) are stacked in depth, each one behind 22 pt higher and 8% smaller, over slowly drifting colour blobs that the glass blurs. Dragging the front pane tilts the whole stack up to 14° on both axes and separates the layers by parallax: the front pane travels 22 pt with the finger, the middle 12 pt, the back 2 pt, while the blobs slide the opposite way so the tint inside the glass visibly changes. A specular sheen on each pane's top edge shifts with the tilt and the shadows fall away from it. On release everything swings back on an underdamped spring (response 0.5 s, damping 0.5), the layers settling one after another. Untouched, the stack sways gently. Airy, deep and luminous.",
            "三片磨砂玻璃（232×148 pt、圆角26 pt）前后叠放，每往后一片就上移22 pt、缩小8%，下方是缓慢漂移、被玻璃模糊的彩色光斑。拖动最前面一片时，整叠在两个轴上最多倾斜14°，并因视差而层层错开：前片随手指移动22 pt，中片12 pt，后片2 pt，光斑则朝相反方向滑动，玻璃里透出的颜色随之明显变化。每片玻璃上缘的镜面高光随倾斜移动，投影落向相反一侧。松手后一切以欠阻尼弹簧（响应0.5秒、阻尼0.5）荡回原位，各层先后稳住。无人触摸时整叠轻轻摇摆。通透、有纵深、带着光感。"
        ),
        implementation: L(
            "An Animatable scene takes a normalised tilt vector; each pane gets the same rotation3DEffect pair plus an offset scaled by its depth, and the blob layer moves by the negative. The frost is drawn rather than sampled: each pane clips a heavily blurred copy of the same blob field, registered to the scene, under a milky tint, hairline and sheen.",
            "Animatable 场景接收归一化的倾斜向量：每片玻璃使用相同的一对 rotation3DEffect，再加上按景深缩放的位移，光斑层则反向移动。磨砂质感是画出来的而非采样：每片玻璃裁切一份与场景对齐、重度模糊的同一光斑层，再叠加乳白色调、描边与高光。"
        ),
        apis: ["rotation3DEffect", "Animatable", "TimelineView", "DragGesture", "blur", "clipShape"],
        tags: ["glass", "frosted", "parallax", "stack", "磨砂玻璃", "毛玻璃", "视差", "叠层"],
        params: [
            .slider("angle", L("Max tilt", "最大倾斜"), 0...24, default: 14, step: 1, decimals: 0, unit: "°"),
            .slider("depth", L("Parallax depth", "视差深度"), 0...2, default: 1),
            .slider("damping", L("Return damping", "回弹阻尼"), 0.3...0.9, default: 0.5),
        ]
    ) { ctx in
        CardsGlassStackDemo(ctx: ctx)
    }
}

private struct CardsGlassStackDemo: View {
    let ctx: DemoContext
    /// Normalised tilt, about −1…1 on each axis.
    @State private var tilt: CGSize
    @State private var touched: Bool
    @State private var held = false
    /// Resets on system cancellation too, so a stolen touch still lets the stack swing back.
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the stack mid-tilt with the layers fanned apart.
        _tilt = State(initialValue: ctx.isStill ? CGSize(width: 0.7, height: -0.5) : .zero)
        _touched = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                let time: Double = ctx.isStill ? 2 : timeline.date.timeIntervalSinceReferenceDate
                CardsGlassScene(
                    tilt: touched ? tilt : idleTilt(at: time),
                    time: time,
                    maxAngle: ctx["angle"],
                    depth: ctx.cg("depth"),
                    language: ctx.language
                )
            }
            .frame(width: 310, height: 290)
            .overlay { hitArea }
            DemoHint(text: L("Drag the front pane", "拖动最前面的玻璃"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { release() }
        }
    }

    private func idleTilt(at t: Double) -> CGSize {
        CGSize(width: cos(t * 0.9) * 0.55, height: sin(t * 1.3) * 0.45)
    }

    /// The front pane claims the drag at once; the rest of the stage still scrolls the page.
    private var hitArea: some View {
        Color.clear
            .frame(width: 232, height: 148)
            .contentShape(Rectangle())
            .gesture(drag)
            .offset(y: 30)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touched {
                    tilt = idleTilt(at: Date().timeIntervalSinceReferenceDate)
                    touched = true
                }
                if !held {
                    held = true
                    Haptics.tap(.soft)
                }
                let x: CGFloat = rubberBand(value.translation.width / 90, limit: 1.4)
                let y: CGFloat = rubberBand(value.translation.height / 90, limit: 1.4)
                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.8)) {
                    tilt = CGSize(width: x, height: y)
                }
            }
            .onEnded { _ in release() }
    }

    /// Single, guarded end of a touch (lift or system cancellation).
    private func release() {
        guard held else { return }
        held = false
        withAnimation(.spring(response: 0.5, dampingFraction: ctx["damping"])) {
            tilt = .zero
        }
    }
}

private struct CardsGlassPane {
    let symbol: String
    let title: LocalizedText
    let detail: LocalizedText
    let tint: Color

    static let all: [CardsGlassPane] = [
        CardsGlassPane(symbol: "sun.max.fill", title: L("Daylight", "日光"), detail: L("Living room · 72%", "客厅 · 72%"), tint: Palette.amber),
        CardsGlassPane(symbol: "music.note", title: L("Now Playing", "正在播放"), detail: L("Lo-fi mix", "Lo-fi 合集"), tint: Palette.pink),
        CardsGlassPane(symbol: "lock.fill", title: L("Front Door", "入户门"), detail: L("Locked", "已上锁"), tint: Palette.mint),
    ]
}

/// Animatable so the release spring's overshoot swings every layer, not just one transform.
private struct CardsGlassScene: View, Animatable {
    var tilt: CGSize
    let time: Double
    let maxAngle: Double
    let depth: CGFloat
    let language: AppLanguage

    var animatableData: CGSize.AnimatableData {
        get { tilt.animatableData }
        set { tilt.animatableData = newValue }
    }

    var body: some View {
        ZStack {
            blobs
            // Back to front.
            ForEach([2, 1, 0], id: \.self) { layer in
                pane(layer)
            }
        }
        .frame(width: 310, height: 290)
    }

    // MARK: Colour beneath the glass

    /// Parallax of the colour field: it slides against the tilt.
    private var slide: CGSize {
        CGSize(width: -tilt.width * 34 * depth, height: -tilt.height * 26 * depth)
    }

    private var blobs: some View {
        CardsGlassBlobs(time: time)
            .offset(slide)
            .blur(radius: 5)
    }

    // MARK: Panes

    private func pane(_ layer: Int) -> some View {
        let level = CGFloat(layer)
        // Front 22 pt, middle 12 pt, back 2 pt of travel at full tilt.
        let travel: CGFloat = (22 - 10 * level) * depth
        let x: CGFloat = tilt.width * travel
        let y: CGFloat = 30 - 22 * level + tilt.height * travel
        let tiltX = Double(tilt.width.clamped(to: -1.2...1.2))
        let tiltY = Double(tilt.height.clamped(to: -1.2...1.2))
        let scale: CGFloat = 1 - 0.08 * level
        // Where the colour field sits relative to this pane (the pane view then undoes its own scale).
        let backdrop = CGSize(width: slide.width - x, height: slide.height - y)
        return CardsGlassPaneView(
            pane: CardsGlassPane.all[layer],
            sheen: tilt,
            isFront: layer == 0,
            time: time,
            backdrop: backdrop,
            backdropScale: 1 / scale,
            language: language
        )
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(-tiltY * maxAngle), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(tiltX * maxAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .shadow(
                color: .black.opacity(0.16),
                radius: 14,
                x: -CGFloat(tiltX) * 10,
                y: 10 - CGFloat(tiltY) * 8
            )
            .offset(x: x, y: y)
    }
}

/// The drifting colour field, centred in the 310×290 scene.
private struct CardsGlassBlobs: View {
    let time: Double

    var body: some View {
        ZStack {
            blob(Palette.indigo, size: 118, x: -84, y: -8, phase: 0)
            blob(Palette.pink, size: 104, x: 76, y: -52, phase: 1.7)
            blob(Palette.amber, size: 92, x: 70, y: 84, phase: 3.1)
            blob(Palette.mint, size: 84, x: -56, y: 100, phase: 4.4)
        }
        .frame(width: 310, height: 290)
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat, phase: Double) -> some View {
        let driftX = CGFloat(cos(time * 0.5 + phase)) * 16
        let driftY = CGFloat(sin(time * 0.4 + phase * 1.3)) * 14
        return Circle()
            .fill(color.opacity(0.9))
            .frame(width: size, height: size)
            .offset(x: x + driftX, y: y + driftY)
    }
}

/// One frosted pane. The frost is drawn, not sampled: an opaque base in the stage colour, a heavily blurred
/// copy of the colour field registered to the scene, and a milky tint. A system Material turns clear or
/// opaque under rotation3DEffect + shadow, and cannot be rendered into a still at all.
private struct CardsGlassPaneView: View {
    let pane: CardsGlassPane
    /// The scene's tilt: moves the specular sheen along the top edge.
    let sheen: CGSize
    let isFront: Bool
    let time: Double
    /// Offset of the scene's colour field in this pane's coordinates, and the scale that undoes the pane's own.
    let backdrop: CGSize
    let backdropScale: CGFloat
    let language: AppLanguage
    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 26, style: .continuous) }

    var body: some View {
        content
            .frame(width: 232, height: 148, alignment: .topLeading)
            .background { frost }
            .overlay { highlight }
            .overlay { rim }
    }

    private var frost: some View {
        let dark = colorScheme == .dark
        return ZStack {
            Palette.stage
            CardsGlassBlobs(time: time)
                .offset(backdrop)
                .scaleEffect(backdropScale)
                .blur(radius: 24)
                .saturation(1.25)
            Color.white.opacity(dark ? 0.1 : 0.42)
        }
        .frame(width: 232, height: 148)
        .clipShape(shape)
    }

    @ViewBuilder
    private var content: some View {
        if isFront {
            VStack(alignment: .leading, spacing: 0) {
                header(icon: 34, glyph: 15, text: 15)
                Spacer(minLength: 0)
                Text(verbatim: "72%")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(pane.detail, language)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        } else {
            // Rear panes only show a compact header in the strip that peeks above the pane in front.
            header(icon: 17, glyph: 8.5, text: 11.5)
                .padding(.horizontal, 14)
                .padding(.top, 5)
        }
    }

    private func header(icon: CGFloat, glyph: CGFloat, text: CGFloat) -> some View {
        HStack(spacing: icon > 20 ? 10 : 6) {
            Image(systemName: pane.symbol)
                .font(.system(size: glyph, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: icon, height: icon)
                .background(pane.tint.gradient, in: Circle())
            Text(pane.title, language)
                .font(.system(size: text, weight: .semibold))
            Spacer(minLength: 0)
            if !isFront {
                Text(pane.detail, language)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    /// Soft light pooled toward the corner the stack is tilted away from.
    private var highlight: some View {
        let centre = UnitPoint(x: 0.3 - sheen.width * 0.3, y: 0.0 - sheen.height * 0.2)
        return shape
            .fill(RadialGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0)], center: centre, startRadius: 0, endRadius: 190))
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var rim: some View {
        let start = UnitPoint(x: 0.2 - sheen.width * 0.3, y: 0)
        return shape
            .strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.08), Color.white.opacity(0.3)], startPoint: start, endPoint: .bottomTrailing),
                lineWidth: 1.2
            )
            .allowsHitTesting(false)
    }
}
