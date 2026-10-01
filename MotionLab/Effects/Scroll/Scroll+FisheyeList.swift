import SwiftUI

extension Effect {
    static let scrollFisheyeList = Effect(
        id: "scroll.fisheye-list",
        category: .scroll,
        interaction: .scroll,
        name: L("Fisheye List", "鱼眼放大列表"),
        summary: L("A dense list passes under a lens: the row at the centre swells like a Dock icon and pushes its neighbours apart.", "紧凑的列表从一枚透镜下滑过：中心那一行像程序坞图标一样鼓起，并把上下邻居推开。"),
        prompt: L(
            "A compact track list of 30 pt rows (number, title, duration) scrolls behind a fixed lens band at the vertical centre. Each row's distance from the centre drives a Gaussian magnifier (σ 56 pt): the centred row's label scales to 190% from its leading edge, two rows away it is about 130%, and by five rows it is back to 100%. Rows are displaced by the integral of that scale, so they spread apart around the lens instead of overlapping and the list bulges like text under a glass dome. Near the centre the label cross-fades from secondary grey to an indigo-violet gradient and a play glyph fades in at the trailing edge. The scroll snaps a row into the lens with a selection tick per row. Dense yet effortless to read, like the macOS Dock turned on its side.",
            "一个紧凑的曲目列表，每行30 pt高（序号、标题、时长），在竖直居中的固定透镜带后面滚动。每一行到中心的距离驱动一枚高斯放大镜（σ为56 pt）：居中那一行的文字以左端为锚点放大到190%，隔两行约为130%，到第五行已回到100%。各行按这条缩放曲线的积分被推开，因此在透镜周围散开而不会互相遮挡，列表像玻璃穹顶下的文字一样鼓起。靠近中心时，文字从次要灰色过渡为靛蓝到紫色的渐变，行尾淡入播放图标。滚动会把某一行吸附进透镜，每经过一行有一次选择触感。像把macOS的程序坞竖了过来。"
        ),
        implementation: L(
            "Each row's visualEffect reads its midY in the .scrollView space and evaluates a Gaussian magnifier: scaleEffect on the label (leading anchor) and a vertical offset equal to the integral of the scale (an erf), which keeps the spacing. A second, tinted copy of the label fades in with the same weight; a stride ScrollTargetBehavior snaps.",
            "每一行的 visualEffect 读取自身在 .scrollView 坐标空间中的 midY，并计算高斯放大函数：文字以左端为锚点做 scaleEffect，纵向位移等于缩放的积分（erf），从而保持行间距。文字的另一份着色副本按同一权重淡入；按步距吸附的 ScrollTargetBehavior 负责吸附。"
        ),
        apis: ["visualEffect", "scaleEffect(_:anchor:)", "ScrollTargetBehavior", "onScrollGeometryChange", "ScrollPosition"],
        tags: ["fisheye", "dock", "magnify", "lens", "list", "鱼眼", "程序坞", "放大", "透镜", "列表"],
        params: [
            .slider("scale", L("Magnification", "放大倍率"), 1.2...2.2, default: 1.9),
            .slider("radius", L("Lens radius", "透镜半径"), 30...100, default: 56, step: 1, decimals: 0, unit: "pt"),
            .toggle("snap", L("Snap rows", "逐行吸附"), default: true),
        ]
    ) { ctx in
        ScrollFisheyeDemo(ctx: ctx)
    }
}

private let scrollFisheyeTracks: [LocalizedText] = [
    L("First Light", "第一缕光"), L("Paper Boats", "纸船"), L("Low Tide", "退潮"), L("Glasshouse", "玻璃花房"),
    L("Slow Orbit", "慢轨道"), L("Night Ferry", "夜航渡轮"), L("Amber Road", "琥珀之路"), L("Kite Weather", "放风筝的天气"),
    L("Salt & Cedar", "盐与雪松"), L("Second Wind", "再次起风"), L("Blue Hour", "蓝调时刻"), L("Open Window", "开着的窗"),
    L("Long Shadows", "长影"), L("Tin Roof Rain", "铁皮屋顶的雨"), L("Field Notes", "田野笔记"), L("Harbor Lights", "港口灯火"),
    L("Soft Machine", "柔软机器"), L("Winter Sun", "冬日暖阳"), L("Half Awake", "半梦半醒"), L("Riverbend", "河湾"),
    L("Quiet Engine", "安静的引擎"), L("Lanterns", "灯笼"), L("Snowline", "雪线"), L("Afterglow", "余晖"),
    L("North Window", "北窗"), L("Driftwood", "浮木"), L("Small Hours", "凌晨"), L("Last Train", "末班车"),
]

private let scrollFisheyeInitialIndex = 7

/// Indigo → violet, tuned per appearance so the focused row stays readable on both stages.
private let scrollFisheyeTint = LinearGradient(
    colors: [Color.adaptive(light: 0x4B57E0, dark: 0x97A1FF), Color.adaptive(light: 0x7A45D6, dark: 0xC9A4FF)],
    startPoint: .leading,
    endPoint: .trailing
)

/// Snaps to whole rows when enabled; otherwise leaves the deceleration target alone.
private struct ScrollFisheyeSnap: ScrollTargetBehavior {
    let pitch: CGFloat
    let enabled: Bool

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard enabled, pitch > 0 else { return }
        target.rect.origin.y = (target.rect.minY / pitch).rounded() * pitch
    }
}

private struct ScrollFisheyeDemo: View {
    let ctx: DemoContext
    @State private var current: Int
    @State private var position = ScrollPosition(edge: .top)
    @State private var viewport: CGFloat = 340
    @State private var direction = 1
    @State private var scripted = false

    private let rowHeight: CGFloat = 30

    /// Stills never scroll to the initial row, so row 0 sits in the lens there.
    init(ctx: DemoContext) {
        self.ctx = ctx
        _current = State(initialValue: ctx.isStill ? 0 : scrollFisheyeInitialIndex)
    }

    var body: some View {
        let peak = ctx.cg("scale")
        let sigma = ctx.cg("radius")
        let height = max(viewport, 1)
        let row = rowHeight
        let count = scrollFisheyeTracks.count
        let pad: CGFloat = max((viewport - rowHeight) / 2, 0)
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    ScrollFisheyeRow(index: i, language: ctx.language, height: height, sigma: sigma, peak: peak)
                        .frame(height: row)
                        .contentShape(Rectangle())
                        .visualEffect { content, proxy in
                            let d: CGFloat = proxy.frame(in: .scrollView).midY - height / 2
                            let lens = ScrollMath.fisheye(distance: d, sigma: sigma, peak: peak)
                            return content.offset(y: lens.position - d)
                        }
                        .onTapGesture { select(i) }
                }
            }
            .padding(.vertical, pad)
            .padding(.leading, 26)
            .padding(.trailing, 22)
        }
        .scrollTargetBehavior(ScrollFisheyeSnap(pitch: rowHeight, enabled: ctx.bool("snap")))
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Int.self, of: { geometry in
            let offset = geometry.contentOffset.y + geometry.contentInsets.top
            return Int((offset / row).rounded()).clamped(to: 0...(count - 1))
        }, action: { _, newValue in
            current = newValue
        })
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .interacting { scripted = false }
        }
        .onAppear { position.scrollTo(y: CGFloat(scrollFisheyeInitialIndex) * rowHeight) }
        .background { ScrollFisheyeLens(height: rowHeight * peak + 6) }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.14),
                    .init(color: .black, location: 0.86),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onGeometryChange(for: CGFloat.self, of: { proxy in proxy.size.height }, action: { newHeight in
            viewport = newHeight
        })
        .onChange(of: current) {
            if !ctx.isPreview && !scripted { Haptics.selection() }
        }
        .autoplay(ctx.isPreview, every: 1.5) { advance() }
    }

    private func select(_ i: Int) {
        scripted = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
            position.scrollTo(y: CGFloat(i) * rowHeight)
        }
    }

    private func advance() {
        let count = scrollFisheyeTracks.count
        let jump = 6
        scripted = true
        if current + direction * jump >= count || current + direction * jump < 0 { direction = -direction }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.88)) {
            position.scrollTo(y: CGFloat(current + direction * jump) * rowHeight)
        }
    }
}

private struct ScrollFisheyeRow: View {
    let index: Int
    let language: AppLanguage
    let height: CGFloat
    let sigma: CGFloat
    let peak: CGFloat

    var body: some View {
        let height = self.height
        let sigma = self.sigma
        let peak = self.peak
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                label
                    .foregroundStyle(.secondary)
                // The tinted copy takes over inside the lens.
                label
                    .foregroundStyle(scrollFisheyeTint)
                    .visualEffect { content, proxy in
                        let d: CGFloat = proxy.frame(in: .scrollView).midY - height / 2
                        let weight = ScrollMath.fisheye(distance: d, sigma: sigma * 0.55, peak: peak).weight
                        return content.opacity(Double(weight))
                    }
            }
            .visualEffect { content, proxy in
                let d: CGFloat = proxy.frame(in: .scrollView).midY - height / 2
                let lens = ScrollMath.fisheye(distance: d, sigma: sigma, peak: peak)
                return content.scaleEffect(lens.scale, anchor: .leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(scrollFisheyeTint)
                .visualEffect { content, proxy in
                    let d: CGFloat = proxy.frame(in: .scrollView).midY - height / 2
                    let weight = ScrollMath.fisheye(distance: d, sigma: sigma * 0.45, peak: peak).weight
                    return content
                        .opacity(Double(weight))
                        .scaleEffect(0.5 + 0.5 * weight)
                }
                .padding(.trailing, 8)
            Text(verbatim: String(format: "%d:%02d", 2 + (index * 7) % 4, (index * 37 + 12) % 60))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    private var label: some View {
        HStack(spacing: 10) {
            Text(verbatim: String(format: "%02d", index + 1))
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .opacity(0.7)
            Text(scrollFisheyeTracks[index], language)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .fixedSize()
    }
}

/// The fixed lens band behind the centred row.
private struct ScrollFisheyeLens: View {
    let height: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape
            .fill(Color.primary.opacity(0.055))
            .overlay(shape.strokeBorder(Palette.stroke))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(scrollFisheyeTint)
                    .frame(width: 3, height: height * 0.46)
                    .padding(.leading, 7)
            }
            .frame(height: height)
            .padding(.horizontal, 12)
    }
}
