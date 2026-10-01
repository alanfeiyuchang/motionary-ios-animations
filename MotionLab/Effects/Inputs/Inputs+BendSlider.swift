import SwiftUI

extension Effect {
    static let inputsBendSlider = Effect(
        id: "inputs.bend-slider",
        category: .inputs,
        interaction: .gesture,
        name: L("Elastic Band Slider", "皮筋滑块"),
        summary: L("The track is a rubber band between two pegs: the thumb presses it into a V while you drag, and it twangs straight on release.", "轨道是绷在两枚图钉之间的皮筋：拖动时被滑块压成 V 形，松手后嗡地弹直。"),
        prompt: L(
            "A slider whose 264 pt track is an 8 pt elastic band stretched between two small pegs, tinted on the left of the thumb and grey on the right. Touching the 30 pt white thumb presses the band down 12 pt on a spring (response 0.25 s, damping 0.6): both halves run as straight lines from the pegs and round into the thumb, so the track forms a soft V. Dragging sideways moves the apex with the value 1:1; vertical finger movement pulls the band further up or down with rubber-band resistance, up to 46 pt. On release the band snaps straight on an underdamped spring (response 0.28 s, damping 0.3), overshooting past the centre line and vibrating three or four times like a plucked string, while the thumb rides it. Light haptic on touch, soft on release.",
            "一条 264pt 的滑块轨道，是绷在两枚小图钉之间的 8pt 皮筋：滑块左侧着色，右侧灰色。按住 30pt 的白色滑块时，皮筋以弹簧（响应 0.25 秒、阻尼 0.6）被向下压 12pt：两段各自从图钉笔直伸出，到滑块处圆滑收拢，整条轨道成为柔和的 V 形。横向拖动时顶点随数值 1:1 移动；手指上下移动会带着皮筋继续上拉或下压，带橡皮筋阻尼，最多 46pt。松手后皮筋以欠阻尼弹簧（响应 0.28 秒、阻尼 0.3）弹直，越过中线来回振动三四次，像被拨动的琴弦，滑块骑在上面一起晃。按下轻触觉，松手柔和触觉。"
        ),
        implementation: L(
            "An Animatable view takes the value and the bend and rebuilds two cubic paths each frame (peg → thumb), so the release spring's overshoot is drawn as a real vibration. Vertical drag translation goes through a rubber-band curve before it becomes the bend.",
            "一个 Animatable 视图接收数值与弯曲量，每帧重建两段三次曲线（图钉 → 滑块），松手弹簧的过冲因此被画成真实的振动。纵向拖动位移先经过橡皮筋曲线，再变成弯曲量。"
        ),
        apis: ["Animatable", "Path.addCurve", "DragGesture", "spring(response:dampingFraction:)", "contentTransition(.numericText)"],
        tags: ["slider", "elastic", "band", "string", "bend", "滑块", "皮筋", "弹性", "琴弦", "弯曲"],
        params: [
            .slider("sag", L("Press depth", "按压深度"), 0...30, default: 12, decimals: 0, unit: "pt"),
            .slider("limit", L("Bend limit", "弯曲上限"), 20...70, default: 46, decimals: 0, unit: "pt"),
            .slider("response", L("Snap response", "回弹响应"), 0.15...0.6, default: 0.28, unit: "s"),
            .slider("damping", L("Snap damping", "回弹阻尼"), 0.15...0.9, default: 0.3),
        ]
    ) { ctx in
        InputBendSliderDemo(ctx: ctx)
    }
}

private struct InputBendSliderDemo: View {
    let ctx: DemoContext
    @State private var value: CGFloat = 0.62
    @State private var bend: CGFloat
    @State private var pressing: Bool
    @State private var startValue: CGFloat = 0
    @State private var step = 0
    @State private var playTask: Task<Void, Never>?
    @GestureState private var touching = false

    private let width: CGFloat = 264
    private let height: CGFloat = 150

    init(ctx: DemoContext) {
        self.ctx = ctx
        _bend = State(initialValue: ctx.isStill ? 30 : 0)
        _pressing = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            readout
            InputBendBand(value: value, bend: bend, pressing: pressing)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .gesture(drag)
            Spacer(minLength: 0)
            DemoHint(text: L("Drag the thumb, pull it up or down, let go", "拖动滑块，上下拉扯，再松手"), ctx: ctx)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: touching) { _, down in
            if !down { release() }
        }
        .autoplay(ctx.isPreview, every: 1.7, delay: 0.5) { play() }
        .onDisappear { playTask?.cancel() }
    }

    private var readout: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(Int((value * 100).rounded()))")
                .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.primary)
                .contentTransition(.numericText(value: Double(value)))
                .animation(.snappy(duration: 0.25), value: Int((value * 100).rounded()))
            Text(L("Tension", "张力"), ctx.language)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { gesture in
                if !pressing {
                    playTask?.cancel()
                    startValue = value
                    Haptics.tap(.light)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        pressing = true
                        bend = ctx.cg("sag")
                    }
                    return
                }
                let pull = rubberBand(gesture.translation.height, limit: ctx.cg("limit"))
                withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.86)) {
                    value = (startValue + gesture.translation.width / width).clamped(to: 0...1)
                    bend = ctx.cg("sag") + pull
                }
            }
            .onEnded { _ in release() }
    }

    /// Finger lift, cancelled touch and autoplay all end here.
    private func release() {
        guard pressing else { return }
        Haptics.tap(.soft)
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            bend = 0
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressing = false }
    }

    private func play() {
        guard !touching else { return }
        let script: [(CGFloat, CGFloat)] = [(0.86, 1), (0.28, -0.8), (0.62, 0.9)]
        let target = script[step % script.count]
        step += 1
        playTask?.cancel()
        playTask = Task { @MainActor in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                pressing = true
                bend = ctx.cg("sag")
            }
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.5)) {
                value = target.0
                bend = ctx.cg("sag") + rubberBand(target.1 * 150, limit: ctx.cg("limit"))
            }
            try? await Task.sleep(for: .seconds(0.56))
            guard !Task.isCancelled else { return }
            release()
        }
    }
}

/// Band, pegs and thumb. Animatable over value and bend so springs redraw the curve every frame.
private struct InputBendBand: View, Animatable {
    var value: CGFloat
    var bend: CGFloat
    let pressing: Bool

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(value, bend) }
        set {
            value = newValue.first
            bend = newValue.second
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 8
            let mid = proxy.size.height / 2
            let left = CGPoint(x: inset, y: mid)
            let right = CGPoint(x: proxy.size.width - inset, y: mid)
            let span = right.x - left.x
            let thumb = CGPoint(x: left.x + span * min(max(value, 0), 1), y: mid + bend)
            let style = StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
            ZStack {
                Path { path in
                    path.move(to: left)
                    path.addLine(to: right)
                }
                .stroke(Color.primary.opacity(0.07), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 5]))
                .opacity(Double(min(abs(bend) / 10, 1)))
                segment(from: right, to: thumb)
                    .stroke(Color.primary.opacity(0.16), style: style)
                segment(from: left, to: thumb)
                    .stroke(LinearGradient(colors: [Palette.indigo, Palette.violet], startPoint: .leading, endPoint: .trailing), style: style)
                    .shadow(color: Palette.indigo.opacity(0.35), radius: 6, y: 3)
                peg.position(left)
                peg.position(right)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().fill(Palette.violet).frame(width: 9, height: 9))
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(pressing ? 0.3 : 0.2), radius: pressing ? 10 : 5, y: pressing ? 6 : 3)
                    .scaleEffect(pressing ? 1.14 : 1)
                    .position(thumb)
            }
        }
    }

    private var peg: some View {
        Circle()
            .fill(Palette.elevated)
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1.5))
            .frame(width: 14, height: 14)
    }

    /// One half of the band: straight out of the peg, rounding into the thumb.
    private func segment(from peg: CGPoint, to thumb: CGPoint) -> Path {
        var path = Path()
        path.move(to: peg)
        let dx = thumb.x - peg.x
        let ease = min(abs(dx) * 0.5, 22) * (dx < 0 ? -1 : 1)
        let control1 = CGPoint(x: peg.x + dx * 0.6, y: peg.y + (thumb.y - peg.y) * 0.6)
        let control2 = CGPoint(x: thumb.x - ease, y: thumb.y)
        path.addCurve(to: thumb, control1: control1, control2: control2)
        return path
    }
}
