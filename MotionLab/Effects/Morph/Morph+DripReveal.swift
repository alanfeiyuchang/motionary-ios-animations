import SwiftUI

extension Effect {
    static let morphDripReveal = Effect(
        id: "morph.drip-reveal",
        category: .morph,
        interaction: .gesture,
        name: L("Drip Reveal", "滴落揭示"),
        summary: L(
            "The next page pours down from the top edge as thick paint: uneven drips with heavy heads fall, fuse sideways and flood the screen.",
            "下一页像浓稠的颜料从顶边淌下来：长短不一、头部沉甸甸的液柱落下，横向融合，直到漫满整屏。"
        ),
        prompt: L(
            "A flat colour page. Tapping (or dragging down to scrub) makes the next page pour over it from the top edge as viscous liquid: nine columns of uneven width, each starting after its own random delay within 70% of the run, grow downward along an accelerating curve (progress to the power 1.5) and end in a bulb 62% of the column's width, so every drip has a heavy head. A curtain follows from 25% progress and swallows the columns from above; neighbouring shapes fuse through a 9 pt blur plus alpha threshold, giving rounded metaball joints. The liquid carries a darker 6 pt lip along its leading edge and drops a soft shadow on the page below. The pour takes 1.5 s; releasing a drag under 40% sucks it back up. Gooey, heavy, satisfying.",
            "一张纯色页面。点一下（或向下拖动来回擦洗进度），下一页就像黏稠的液体从顶边淌下盖住它：九根宽窄不一的液柱，各自在全程 70% 的范围内随机延迟起步，沿加速曲线（进度的 1.5 次方）向下生长，末端是宽度为柱宽 62% 的液滴，所以每一道都有沉甸甸的头。一道帘幕从进度 25% 起跟上，自上而下吞没液柱；相邻形状经 9pt 模糊加透明度阈值相互融合，接缝圆润如融球。液体前缘带一圈 6pt 的深色唇边，并在下层页面上投下柔和的阴影。整个倾倒耗时 1.5 秒；拖动不到 40% 就松手，液体会被吸回去。黏稠、厚重。"
        ),
        implementation: L(
            "The next page is masked by a Canvas that draws the curtain, the columns and their bulbs into a layer filtered with blur and alphaThreshold. The same mask, offset and darkened, forms the lip and the shadow. An Animatable wrapper feeds the progress, a page-safe pan scrubs it, and the completion handler swaps pages.",
            "下一页由一个 Canvas 作遮罩：帘幕、液柱和液滴画进同一图层，再经模糊与 alphaThreshold 滤镜融合。同一遮罩经位移和压暗后构成唇边与阴影。Animatable 包装器提供进度，不干扰页面滚动的拖动手势可擦洗进度，动画完成回调切换页面。"
        ),
        apis: ["Canvas", "GraphicsContext.Filter.alphaThreshold", "mask", "Animatable", "withAnimation(_:completion:)"],
        tags: ["drip", "liquid", "paint", "metaball", "reveal", "滴落", "液体", "颜料", "融球", "揭示"],
        params: [
            .slider("duration", L("Pour time", "倾倒时长"), 0.6...3.0, default: 1.5, unit: "s"),
            .slider("columns", L("Columns", "液柱数量"), 4...14, default: 9, step: 1, decimals: 0),
            .slider("spread", L("Delay spread", "延迟范围"), 0.1...1.5, default: 0.7),
            .slider("goo", L("Gooeyness", "黏稠度"), 2...16, default: 9, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        DripRevealDemo(ctx: ctx)
    }
}

private enum DripLayout {
    static let size = CGSize(width: 316, height: 306)
}

private struct DripPage {
    let title: LocalizedText
    let caption: LocalizedText
    let symbol: String
    let colors: [Color]
    let ink: Color
}

private let dripPages: [DripPage] = [
    DripPage(
        title: L("Mango", "芒果"), caption: L("Sunny, loud, a little sticky", "明亮、张扬，还有点黏"),
        symbol: "sun.max.fill", colors: [Color(hex: 0xFFC53D), Color(hex: 0xFF9A2E)], ink: Color(hex: 0x4A2500)
    ),
    DripPage(
        title: L("Berry", "莓果"), caption: L("Deep, sweet, stains everything", "浓郁、甜，沾上就洗不掉"),
        symbol: "heart.fill", colors: [Color(hex: 0xF0437A), Color(hex: 0xB32BD1)], ink: .white
    ),
    DripPage(
        title: L("Mint", "薄荷"), caption: L("Cool, clean, slow to pour", "清凉、干净，倒得很慢"),
        symbol: "leaf.fill", colors: [Color(hex: 0x2FE0B0), Color(hex: 0x13A892)], ink: Color(hex: 0x00352C)
    ),
]

private struct DripRevealDemo: View {
    let ctx: DemoContext
    @State private var index = 0
    @State private var progress: Double
    @State private var pouring = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 0.52 : 0)
    }

    var body: some View {
        VStack(spacing: 10) {
            MorphAnimated(progress) { value in
                DripStage(
                    index: index,
                    progress: CGFloat(value),
                    columns: max(ctx.int("columns"), 2),
                    spread: ctx.cg("spread"),
                    goo: ctx.cg("goo"),
                    language: ctx.language
                )
            }
            .contentShape(Rectangle())
            .onTapGesture { pour() }
            .gesture(PageSafePan(directions: [.down], isEnabled: !pouring, onChanged: dragChanged, onEnded: dragEnded))
            .morphScreen()
            DemoHint(text: L("Tap, or drag down to pour", "点击，或向下拖动倾倒"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 0.7) { pour() }
    }

    private func dragChanged(_ translation: CGSize) {
        guard !pouring else { return }
        progress = Double(MorphMath.unit(translation.height / 250))
    }

    private func dragEnded(_ end: PageSafePanEnd?) {
        guard !pouring else { return }
        let predicted: CGFloat = (end?.predictedEndTranslation.height ?? 0) / 250
        if predicted > 0.4 || progress > 0.4 {
            pour()
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { progress = 0 }
        }
    }

    private func pour() {
        guard !pouring else { return }
        pouring = true
        let preview: Bool = ctx.isPreview
        if !preview { Haptics.tap(.soft) }
        let remaining: Double = max(1 - progress, 0.25)
        withAnimation(.timingCurve(0.3, 0, 0.6, 1, duration: ctx["duration"] * remaining)) {
            progress = 1
        } completion: {
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) {
                index = (index + 1) % dripPages.count
                progress = 0
            }
            pouring = false
            if !preview { Haptics.tap(.light) }
        }
    }
}

private struct DripStage: View {
    let index: Int
    let progress: CGFloat
    let columns: Int
    let spread: CGFloat
    let goo: CGFloat
    let language: AppLanguage

    var body: some View {
        let next: Int = (index + 1) % dripPages.count
        let liquid = DripLiquid(seed: index, progress: progress, columns: columns, spread: spread, goo: goo)
        ZStack {
            DripPageView(page: dripPages[index], language: language)
            // Shadow the liquid casts on the page beneath it.
            liquid
                .blur(radius: 5)
                .opacity(0.3)
                .offset(y: 7)
            // The lip: the same page a shade darker, showing 6 pt below the bright body.
            DripPageView(page: dripPages[next], language: language)
                .overlay(Color.black.opacity(0.24))
                .mask { liquid }
            DripPageView(page: dripPages[next], language: language)
                .mask { liquid.offset(y: -6) }
        }
        .frame(width: DripLayout.size.width, height: DripLayout.size.height)
    }
}

/// The liquid's silhouette: curtain, columns and bulbs fused by blur + alpha threshold.
private struct DripLiquid: View {
    let seed: Int
    let progress: CGFloat
    let columns: Int
    let spread: CGFloat
    let goo: CGFloat

    private static func hash(_ a: Int, _ b: Int) -> CGFloat {
        let value: Double = sin(Double(a) * 127.1 + Double(b) * 311.7) * 43758.5453
        return CGFloat(value - value.rounded(.down))
    }

    var body: some View {
        Canvas { context, size in
            guard progress > 0.001 else { return }
            context.addFilter(.alphaThreshold(min: 0.5, color: .black))
            context.addFilter(.blur(radius: goo))
            context.drawLayer { layer in
                let p: CGFloat = min(progress, 1)
                let slot: CGFloat = size.width / CGFloat(columns)
                // Curtain following the drips down.
                let curtain: CGFloat = (size.height + 60) * MorphMath.smooth(p, 0.25, 1) - 30
                layer.fill(Path(CGRect(x: -40, y: -80, width: size.width + 80, height: curtain + 80)), with: .color(.black))
                for column in 0..<columns {
                    let delay: CGFloat = DripLiquid.hash(column, seed * 7 + 1)
                    let local: CGFloat = MorphMath.unit(p * (1 + spread) - delay * spread)
                    guard local > 0 else { continue }
                    let width: CGFloat = slot * (0.6 + 0.5 * DripLiquid.hash(column, seed * 7 + 2))
                    let x: CGFloat = slot * (CGFloat(column) + 0.5) + slot * 0.24 * (DripLiquid.hash(column, seed * 7 + 3) - 0.5)
                    let bulb: CGFloat = width * 0.62
                    let tip: CGFloat = -bulb + (size.height + bulb * 2 + 40) * pow(local, 1.5)
                    layer.fill(
                        Path(roundedRect: CGRect(x: x - width / 2, y: -80, width: width, height: tip + 80), cornerRadius: width / 2),
                        with: .color(.black)
                    )
                    layer.fill(
                        Path(ellipseIn: CGRect(x: x - bulb, y: tip - bulb, width: bulb * 2, height: bulb * 2.15)),
                        with: .color(.black)
                    )
                }
            }
        }
        .frame(width: DripLayout.size.width, height: DripLayout.size.height)
        .allowsHitTesting(false)
    }
}

private struct DripPageView: View {
    let page: DripPage
    let language: AppLanguage

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: page.colors, startPoint: .top, endPoint: .bottom)
            Image(systemName: page.symbol)
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(page.ink.opacity(0.9))
                .frame(width: 112, height: 112)
                .background(Color.white.opacity(0.22), in: Circle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(page.title, language)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text(page.caption, language)
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.75)
            }
            .foregroundStyle(page.ink)
            .padding(20)
        }
        .frame(width: DripLayout.size.width, height: DripLayout.size.height)
    }
}
