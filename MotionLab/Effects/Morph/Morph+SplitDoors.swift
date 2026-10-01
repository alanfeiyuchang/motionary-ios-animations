import SwiftUI

extension Effect {
    static let morphSplitDoors = Effect(
        id: "morph.split-doors",
        category: .morph,
        interaction: .tap,
        name: L("Split Doors", "对开门转场"),
        summary: L(
            "The screen cracks down the middle and its two halves swing away like doors, while the next room steps forward out of their shadow.",
            "画面沿中线裂开，两半像门一样向里转开，下一个房间从门影里迎面走出来。"
        ),
        prompt: L(
            "A full-bleed poster with a hairline seam and two small handles at its centre. Tapping first lights the seam: a 2 pt white line flares and fades within the first 30% of the motion. The poster is drawn twice, clipped to its left and right halves; each half swings inward 92° about its outer edge with perspective, on one spring (response 0.9 s, damping 0.86), darkening up to 55% as it turns away and catching a thin highlight on its free edge. Behind them the next poster waits at 86% scale under a 50% shade; it scales up to 100% and brightens as the gap widens, with soft shadows cast from both door edges sliding outward across it. The doors fade over the last 18%. A Slide style parts the halves sideways instead. Theatrical, weighty, a true threshold.",
            "一张铺满画面的海报，中线有一道细缝和两只小门把手。点一下，门缝先亮起：一条 2pt 的白线在动作的前 30% 内闪亮又淡去。海报被画了两遍，分别裁成左右两半；每一半绕自己的外侧边带透视向内转开 92°，共用一条弹簧（响应 0.9 秒、阻尼 0.86），转离时最多压暗 55%，自由边上带一道细高光。门后，下一张海报以 86% 的比例停在 50% 的阴影里；门缝越开越大，它随之放大到 100% 并变亮，两扇门边投下的柔和阴影在它上面向外滑走。最后 18% 的行程里门逐渐淡出。「平移」样式则让两半向两侧滑开。"
        ),
        implementation: L(
            "An Animatable wrapper interpolates the progress. The current page is rendered twice inside half-width clipped frames, each with rotation3DEffect anchored at its outer edge (or an x offset in Slide style); the next page underneath is scaled and shaded from the same progress, and the completion handler swaps pages and resets the progress.",
            "Animatable 包装器对进度插值。当前页在两个半宽裁切框里各渲染一次，各自以外侧边为锚点做 rotation3DEffect（平移样式下改为 x 位移）；下方的下一页按同一进度缩放和调暗，动画完成回调切换页面并把进度归零。"
        ),
        apis: ["rotation3DEffect", "Animatable", "clipped", "withAnimation(_:completion:)", "LinearGradient"],
        tags: ["doors", "split", "reveal", "3d", "transition", "对开门", "分屏", "揭示", "转场"],
        params: [
            .choice("style", L("Style", "样式"), [L("Swing", "转开"), L("Slide", "平移")], default: 0),
            .slider("response", L("Spring response", "弹簧响应"), 0.4...1.6, default: 0.9, unit: "s"),
            .slider("angle", L("Swing angle", "转开角度"), 70...100, default: 92, decimals: 0, unit: "°"),
            .slider("depth", L("Next page scale", "下一页初始比例"), 0.7...1.0, default: 0.86),
        ]
    ) { ctx in
        SplitDoorsDemo(ctx: ctx)
    }
}

private enum DoorLayout {
    static let size = CGSize(width: 316, height: 306)
}

private struct DoorPage {
    let number: String
    let title: LocalizedText
    let caption: LocalizedText
    let symbol: String
    let colors: [Color]
}

private let doorPages: [DoorPage] = [
    DoorPage(
        number: "01", title: L("Light", "光"), caption: L("Hall of daylight studies", "日光研究展厅"),
        symbol: "sun.max.fill", colors: [Color(hex: 0x1B1848), Color(hex: 0x5A3FD6)]
    ),
    DoorPage(
        number: "02", title: L("Colour", "色"), caption: L("Pigments and gradients", "颜料与渐变展厅"),
        symbol: "paintpalette.fill", colors: [Color(hex: 0xFF8A5C), Color(hex: 0xF0437A)]
    ),
    DoorPage(
        number: "03", title: L("Form", "形"), caption: L("Solids, voids and edges", "体块、留白与边线"),
        symbol: "cube.fill", colors: [Color(hex: 0x0B6B5C), Color(hex: 0x1FC79E)]
    ),
]

private struct SplitDoorsDemo: View {
    let ctx: DemoContext
    @State private var index = 0
    @State private var progress: Double
    @State private var opening = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 0.4 : 0)
    }

    var body: some View {
        VStack(spacing: 10) {
            MorphAnimated(progress) { value in
                DoorStage(
                    index: index,
                    progress: CGFloat(value),
                    slide: ctx.int("style") == 1,
                    angle: ctx["angle"],
                    depth: ctx.cg("depth"),
                    language: ctx.language
                )
            }
            .contentShape(Rectangle())
            .onTapGesture { open() }
            .morphScreen()
            DemoHint(text: L("Tap the doors", "点击这扇门"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { open() }
    }

    private func open() {
        guard !opening else { return }
        opening = true
        let preview: Bool = ctx.isPreview
        if !preview { Haptics.tap(.medium) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.86)) {
            progress = 1
        } completion: {
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) {
                index = (index + 1) % doorPages.count
                progress = 0
            }
            opening = false
            if !preview { Haptics.tap(.soft) }
        }
    }
}

private struct DoorStage: View {
    let index: Int
    let progress: CGFloat
    let slide: Bool
    let angle: Double
    let depth: CGFloat
    let language: AppLanguage

    var body: some View {
        let p: CGFloat = MorphMath.unit(progress)
        let size: CGSize = DoorLayout.size
        let half: CGFloat = size.width / 2
        let next: Int = (index + 1) % doorPages.count
        let theta: Double = angle * Double(progress)
        // Where each door's free edge sits on screen (flat approximation, good enough for the shadows).
        let edge: CGFloat = slide ? half * (1 - p) : half * CGFloat(max(cos(theta * Double.pi / 180), 0))
        let fade: Double = Double(1 - MorphMath.smooth(p, 0.82, 1))
        ZStack {
            Color.black
            DoorPageView(page: doorPages[next], doors: true, language: language)
                .scaleEffect(MorphMath.lerp(depth, 1, p))
                .overlay(Color.black.opacity(0.5 * Double(pow(1 - p, 1.4))))
                .overlay { shadows(edge: edge, strength: Double(1 - p)) }
            door(leading: true, theta: theta, p: p)
                .opacity(fade)
            door(leading: false, theta: theta, p: p)
                .opacity(fade)
            // The crack of light as the seam opens.
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: size.height)
                .shadow(color: .white, radius: 10)
                .shadow(color: .white.opacity(0.7), radius: 24)
                .opacity(Double(sin(Double.pi * Double(MorphMath.unit(p / 0.3)))))
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
    }

    private func shadows(edge: CGFloat, strength: Double) -> some View {
        let half: CGFloat = DoorLayout.size.width / 2
        let width: CGFloat = 56
        return ZStack {
            LinearGradient(colors: [.black.opacity(0.55 * strength), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width)
                .position(x: half - edge + width / 2, y: DoorLayout.size.height / 2)
            LinearGradient(colors: [.clear, .black.opacity(0.55 * strength)], startPoint: .leading, endPoint: .trailing)
                .frame(width: width)
                .position(x: half + edge - width / 2, y: DoorLayout.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    private func door(leading: Bool, theta: Double, p: CGFloat) -> some View {
        let size: CGSize = DoorLayout.size
        let half: CGFloat = size.width / 2
        let turned: Double = slide ? 0 : Double(p)
        let panel = DoorPageView(page: doorPages[index], doors: true, language: language)
            .frame(width: half, height: size.height, alignment: leading ? .leading : .trailing)
            .clipped()
            .overlay(Color.black.opacity(0.55 * turned))
            .overlay(alignment: leading ? .trailing : .leading) {
                // Free edge catching the light from the next room.
                LinearGradient(
                    colors: [.white.opacity(0.65), .white.opacity(0)],
                    startPoint: leading ? .trailing : .leading,
                    endPoint: leading ? .leading : .trailing
                )
                .frame(width: 10)
                .opacity(Double(MorphMath.smooth(p, 0.02, 0.25)))
            }
        return Group {
            if slide {
                panel.offset(x: (leading ? -1 : 1) * (half + 8) * progress)
            } else {
                panel.rotation3DEffect(
                    .degrees(leading ? theta : -theta),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: leading ? .leading : .trailing,
                    perspective: 0.7
                )
            }
        }
        .frame(width: size.width, height: size.height, alignment: leading ? .leading : .trailing)
        .allowsHitTesting(false)
    }
}

private struct DoorPageView: View {
    let page: DoorPage
    let doors: Bool
    let language: AppLanguage

    var body: some View {
        let size: CGSize = DoorLayout.size
        ZStack {
            LinearGradient(colors: page.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.22), .clear], center: UnitPoint(x: 0.85, y: 0.1), startRadius: 0, endRadius: 240)
            Image(systemName: page.symbol)
                .font(.system(size: 120, weight: .bold))
                .foregroundStyle(.white.opacity(0.16))
                .position(x: size.width - 70, y: 96)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: language == .zh ? "展厅" : "GALLERY")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(language == .zh ? 4 : 2)
                    .opacity(0.75)
                Spacer()
                Text(verbatim: page.number)
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text(page.title, language)
                    .font(.system(size: 26, weight: .bold))
                Text(page.caption, language)
                    .font(.system(size: 13, weight: .medium))
                    .opacity(0.8)
                    .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(width: size.width, height: size.height, alignment: .leading)
            if doors {
                // Seam and handles: it reads as a pair of doors before anything moves.
                Rectangle()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 1, height: size.height)
                HStack(spacing: 20) {
                    Capsule().frame(width: 4, height: 36)
                    Capsule().frame(width: 4, height: 36)
                }
                .foregroundStyle(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
