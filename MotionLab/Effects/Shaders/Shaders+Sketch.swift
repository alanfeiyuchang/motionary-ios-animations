import SwiftUI

extension Effect {
    static let shaderSketchEdges = Effect(
        id: "shader.sketch-edges",
        category: .shaders,
        interaction: .tap,
        name: L("Pencil Sketch", "铅笔素描"),
        summary: L(
            "The picture redraws itself as a pencil sketch from your tap: outlines first, cross-hatching after, on toned paper.",
            "画面从触点开始把自己重画成铅笔素描：先勾轮廓，再排线，落在有底色的纸上。"
        ),
        prompt: L(
            "Tapping a colourful cottage scene turns it into a pencil drawing, spreading from the finger at a steady pace over 1.8 s with a rough, uneven front. Behind the front the colour first fades to cream paper, then graphite outlines appear along every edge of the picture, and a moment later hatching fills in: one direction of 5 pt strokes in the mid-tones, a second crossing it in the shadows, a third in the darkest areas. The graphite breaks up on the paper's tooth. Once drawn, the sketch stays alive: its lines re-jitter by about a point eight times a second, like hand-drawn animation. Tapping again floods the colour back from the new touch point. Handmade, warm and a little alive.",
            "点击一幅彩色的小屋风景，它便从指尖开始变成铅笔画，在 1.8 秒内带着粗糙不齐的前沿匀速向外蔓延。前沿之后，色彩先褪成米白的纸面，接着石墨线条沿画面的每一道边缘显现，稍后排线填入：中间调是一组间距 5pt 的斜线，暗部再叠一组交叉线，最暗处还有第三组。石墨在纸面的纹理上断断续续。画完之后素描并不静止：线条每秒八次、以约一个点的幅度重新抖动，像手绘动画那样。再点一次，色彩从新的触点漫回来。手作、温暖、带一点生气。"
        ),
        implementation: L(
            "A [[stitchable]] layer shader runs a Sobel filter on luminance for outlines, adds three thresholded hatch directions and paper-tooth noise, and jitters its sampling position with noise re-rolled at 8 fps. An arrival field (distance from the tap plus noise) compared with an Animatable progress stages paper, lines and hatching.",
            "[[stitchable]] layerEffect 着色器对亮度做 Sobel 滤波得到轮廓，再加上按阈值开启的三个方向排线与纸纹噪声，并用每秒重新生成 8 次的噪声抖动采样位置。“到达场”（到触点的距离加噪声）与 Animatable 进度比较，依次呈现纸面、线条与排线。"
        ),
        apis: ["layerEffect", "Animatable", "TimelineView", "onTapGesture(coordinateSpace:)", "Metal"],
        tags: ["sketch", "pencil", "edge detection", "hatching", "sobel", "素描", "铅笔", "边缘检测", "排线", "手绘"],
        params: [
            .slider("duration", L("Redraw time", "重画时长"), 0.8...4, default: 1.8, decimals: 1, unit: "s"),
            .slider("weight", L("Line weight", "线条力度"), 1...6, default: 2.4, decimals: 1),
            .slider("hatch", L("Hatching", "排线"), 0...1, default: 0.7),
            .choice("paper", L("Paper", "纸张"), [L("Cream", "米白"), L("Blueprint", "蓝图"), L("Chalkboard", "黑板")]),
        ]
    ) { ctx in
        SketchDemo(ctx: ctx)
    }
}

private struct SketchDemo: View {
    let ctx: DemoContext
    @State private var clock = BackgroundClock(start: 1)
    @State private var progress: Double
    @State private var toSketch: Bool
    @State private var origin = CGPoint(x: 40, y: 60)
    @State private var busy = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Live demos start as the photo (the far end of a sketch → photo run), so the first play draws the
        // sketch; a still shows the drawing half-way across the picture.
        _progress = State(initialValue: ctx.isStill ? 0.56 : 1)
        _toSketch = State(initialValue: ctx.isStill)
    }

    private var inks: (paper: Color, pencil: Color) {
        switch ctx.int("paper") {
        case 1: return (Color(hex: 0x1D4E9E), Color(hex: 0xEAF3FF))
        case 2: return (Color(hex: 0x23362E), Color(hex: 0xF3F1E4))
        default: return (Color(hex: 0xF5EEDD), Color(hex: 0x34353F))
        }
    }

    var body: some View {
        let inks = self.inks
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let time = ctx.isStill ? 1.3 : clock.advance(to: timeline.date.timeIntervalSinceReferenceDate, speed: 1)
                ShaderCottageScene()
                    .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
                    .modifier(SketchModifier(
                        progress: progress, time: time, weight: ctx["weight"], hatch: ctx["hatch"], boil: 0.9,
                        paper: inks.paper, pencil: inks.pencil, origin: origin, toSketch: toSketch
                    ))
            }
            .shaderCard()
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in redraw(from: location) }
            DemoHint(text: L("Tap to redraw · tap again for colour", "点击重画 · 再点恢复色彩"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 1.3, delay: 0.5) {
            redraw(from: CGPoint(x: CGFloat.random(in: 40...220), y: CGFloat.random(in: 60...240)))
        }
    }

    private func redraw(from point: CGPoint) {
        guard !busy else { return }
        busy = true
        Haptics.tap(.soft)
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            // Same picture, expressed from the other end: fully "there" in the old direction is 0 in the new one.
            toSketch.toggle()
            origin = point
            progress = 0
        }
        // Linear: the front crosses the picture at a steady pace and each pixel stages itself behind it.
        withAnimation(.linear(duration: ctx["duration"])) {
            progress = 1
        } completion: {
            busy = false
        }
    }
}

private struct SketchModifier: ViewModifier, Animatable {
    var progress: Double
    var time: Double
    var weight: Double
    var hatch: Double
    var boil: Double
    var paper: Color
    var pencil: Color
    var origin: CGPoint
    var toSketch: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.mlSketch(
                .float2(ShaderKit.card), .float(time), .float(weight), .float(hatch), .float(boil),
                .color(paper), .color(pencil), .float2(origin), .float(progress), .float(toSketch ? 1 : 0)
            ),
            maxSampleOffset: CGSize(width: boil + 2, height: boil + 2)
        )
    }
}
