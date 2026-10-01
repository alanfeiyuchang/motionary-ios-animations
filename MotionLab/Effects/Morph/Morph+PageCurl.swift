import SwiftUI

extension Effect {
    static let morphPageCurl = Effect(
        id: "morph.page-curl",
        category: .morph,
        interaction: .gesture,
        name: L("Page Curl", "卷页翻书"),
        summary: L(
            "The page corner peels up under your finger, showing its shaded back and the next page beneath.",
            "页角随手指卷起，露出带明暗的纸背和下一页。"
        ),
        prompt: L(
            "A cream paper page on a thin stack. Dragging from it picks up the bottom-right corner: the corner follows the finger, and the paper folds along the perpendicular bisector between the corner's home and its current position. Everything beyond the fold is cut from the page to reveal the next one, and is drawn mirrored across the fold as the paper's back, slightly greyer, with the front faintly showing through at 12% and a gradient across it: a dark crease, a bright highlight band, then a soft falloff. The flap casts a blurred shadow, and the revealed page darkens along the fold. The corner cannot leave the arc the spine allows. Release past the middle and the turn completes; otherwise it settles back. A tap turns the page by itself in 0.9 s.",
            "一摞薄纸上放着一页米色纸。在上面拖动会拎起右下角：页角跟随手指，纸张沿「页角原位」与「当前位置」连线的垂直平分线折起。折线以外的部分从本页裁掉，露出下一页，并以折线为轴镜像绘制成纸背：颜色略灰，正面内容以 12% 的透明度隐约透出，表面叠一道渐变，依次是深色折痕、明亮高光带和柔和的衰减。卷起的纸投下一片模糊阴影，露出的下一页沿折线变暗。页角不会超出书脊允许的弧线范围。拖过中线松手就翻过去，否则落回原位。点一下，页面会在 0.9 秒内自己翻过。"
        ),
        implementation: L(
            "Pure 2D geometry: the fold line is derived from the clamped corner point each frame, the page rectangle is clipped against it (Sutherland–Hodgman) into the kept and lifted polygons, and the lifted polygon is reflected. The front page is clipped with a polygon Shape, the back is a Canvas, and the show-through is the same page view under a reflection transformEffect. An Animatable wrapper drives both the drag point and the automatic turn.",
            "纯二维几何：每帧由受约束的页角位置求出折线，用折线把页面矩形裁成保留与掀起两个多边形（Sutherland–Hodgman），再把掀起部分做镜像。正面用多边形 Shape 裁剪，纸背用 Canvas 绘制，透出的内容是同一页面视图加上镜像 transformEffect。Animatable 包装器同时驱动拖动点与自动翻页。"
        ),
        apis: ["Canvas", "transformEffect", "clipShape", "Animatable", "UIGestureRecognizerRepresentable", "withAnimation(_:completionCriteria:_:completion:)"],
        tags: ["page curl", "book", "page turn", "fold", "翻页", "卷页", "书页", "折角"],
        params: [
            .slider("duration", L("Turn duration", "翻页时长"), 0.4...2.0, default: 0.9, unit: "s"),
            .slider("shadow", L("Shadow depth", "阴影深度"), 0...1, default: 0.7),
            .slider("ghost", L("Paper show-through", "纸背透印"), 0...0.3, default: 0.12),
        ]
    ) { ctx in
        PageCurlDemo(ctx: ctx)
    }
}

private enum CurlLayout {
    static let page = CGSize(width: 228, height: 284)
    static let margin: CGFloat = 70
    static var home: CGPoint { CGPoint(x: page.width, y: page.height) }

    /// Where the corner is at time `t` of an automatic turn: it sweeps left while lifting off the bottom edge.
    static func autoPoint(_ t: CGFloat) -> CGPoint {
        CGPoint(x: page.width - 2 * page.width * t, y: page.height - 92 * sin(.pi * t))
    }
}

/// Fold line and polygons for a page whose bottom-right corner has been dragged to `point`.
private struct CurlGeometry {
    let active: Bool
    /// A point on the fold line and the unit normal pointing at the lifted side.
    let mid: CGPoint
    let normal: CGPoint
    /// Distance from the fold to the lifted corner.
    let depth: CGFloat
    let front: [CGPoint]
    let lifted: [CGPoint]
    let flap: [CGPoint]

    init(point: CGPoint, size: CGSize) {
        let home = CGPoint(x: size.width, y: size.height)
        let corner: CGPoint = CurlGeometry.clamp(point, size: size)
        let dx: CGFloat = home.x - corner.x
        let dy: CGFloat = home.y - corner.y
        let length: CGFloat = (dx * dx + dy * dy).squareRoot()
        let rect: [CGPoint] = [.zero, CGPoint(x: size.width, y: 0), home, CGPoint(x: 0, y: size.height)]
        guard length > 1 else {
            active = false
            mid = home
            normal = CGPoint(x: 1, y: 0)
            depth = 0
            front = rect
            lifted = []
            flap = []
            return
        }
        let n = CGPoint(x: dx / length, y: dy / length)
        let m = CGPoint(x: (home.x + corner.x) / 2, y: (home.y + corner.y) / 2)
        active = true
        mid = m
        normal = n
        depth = length / 2
        front = CurlGeometry.clip(rect, mid: m, normal: n, keepLifted: false)
        let up: [CGPoint] = CurlGeometry.clip(rect, mid: m, normal: n, keepLifted: true)
        lifted = up
        flap = up.map { p in
            let s: CGFloat = (p.x - m.x) * n.x + (p.y - m.y) * n.y
            return CGPoint(x: p.x - 2 * s * n.x, y: p.y - 2 * s * n.y)
        }
    }

    /// The corner stays on the paper side of its home and within reach of both ends of the spine.
    static func clamp(_ point: CGPoint, size: CGSize) -> CGPoint {
        var p = CGPoint(x: min(point.x, size.width), y: min(point.y, size.height))
        let low = CGPoint(x: 0, y: size.height)
        let d1: CGFloat = ((p.x - low.x) * (p.x - low.x) + (p.y - low.y) * (p.y - low.y)).squareRoot()
        if d1 > size.width {
            p = CGPoint(x: low.x + (p.x - low.x) * size.width / d1, y: low.y + (p.y - low.y) * size.width / d1)
        }
        let reach: CGFloat = (size.width * size.width + size.height * size.height).squareRoot()
        let d2: CGFloat = (p.x * p.x + p.y * p.y).squareRoot()
        if d2 > reach {
            p = CGPoint(x: p.x * reach / d2, y: p.y * reach / d2)
        }
        return p
    }

    /// Sutherland–Hodgman against the fold line.
    private static func clip(_ polygon: [CGPoint], mid: CGPoint, normal: CGPoint, keepLifted: Bool) -> [CGPoint] {
        func side(_ p: CGPoint) -> CGFloat {
            let s: CGFloat = (p.x - mid.x) * normal.x + (p.y - mid.y) * normal.y
            return keepLifted ? s : -s
        }
        var result: [CGPoint] = []
        for index in polygon.indices {
            let a: CGPoint = polygon[index]
            let b: CGPoint = polygon[(index + 1) % polygon.count]
            let sa: CGFloat = side(a)
            let sb: CGFloat = side(b)
            if sa >= 0 { result.append(a) }
            if (sa >= 0) != (sb >= 0) {
                let t: CGFloat = sa / (sa - sb)
                result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return result
    }

    /// Mirror across the fold line.
    var reflection: CGAffineTransform {
        let k: CGFloat = normal.x * mid.x + normal.y * mid.y
        return CGAffineTransform(
            a: 1 - 2 * normal.x * normal.x,
            b: -2 * normal.x * normal.y,
            c: -2 * normal.x * normal.y,
            d: 1 - 2 * normal.y * normal.y,
            tx: 2 * k * normal.x,
            ty: 2 * k * normal.y
        )
    }
}

private struct CurlPolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 2 else { return path }
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

/// Everything right of the spine is visible (the flap may hang over the other three edges).
private struct CurlWindow: Shape {
    func path(in rect: CGRect) -> Path {
        let m: CGFloat = CurlLayout.margin
        return Path(CGRect(x: rect.minX, y: rect.minY - m, width: rect.width + m, height: rect.height + 2 * m))
    }
}

private struct PageCurlDemo: View {
    let ctx: DemoContext
    @State private var index = 0
    @State private var corner: CGPoint = CurlLayout.home
    /// 0…1 while the page turns by itself; 0 while the finger owns the corner.
    @State private var autoT: Double
    @State private var turning = false
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _autoT = State(initialValue: ctx.isStill ? 0.3 : 0)
    }

    var body: some View {
        VStack(spacing: 16) {
            MorphAnimated(AnimatablePair(autoT, corner.animatableData)) { value in
                let t = CGFloat(value.first)
                let point: CGPoint = t > 0.0001 ? CurlLayout.autoPoint(t) : CGPoint(x: value.second.first, y: value.second.second)
                CurlScene(index: index, point: point, shadow: ctx.cg("shadow"), ghost: ctx["ghost"], language: ctx.language)
            }
            .frame(width: CurlLayout.page.width, height: CurlLayout.page.height)
            .contentShape(Rectangle())
            .onTapGesture { turn() }
            // A leftward or upward drag picks up the corner (the page scroll waits for it); anything else scrolls.
            .gesture(PageSafePan(directions: [.left, .up], isEnabled: !turning, onChanged: dragChanged, onEnded: dragEnded))
            DemoHint(text: L("Drag the page, or tap to turn", "拖动页面，或点击翻页"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.0) { turn() }
    }

    private func dragChanged(_ t: CGSize) {
        guard !turning else { return }
        let home: CGPoint = CurlLayout.home
        corner = CurlGeometry.clamp(CGPoint(x: home.x + t.width * 1.25, y: home.y + t.height * 1.25), size: CurlLayout.page)
    }

    /// `nil` means the system cancelled the pan: lay the page back down.
    private func dragEnded(_ end: PageSafePanEnd?) {
        guard !turning else { return }
        let flicked: Bool = (end?.velocity.width ?? 0) < -600
        if end != nil, corner.x < CurlLayout.page.width * 0.4 || flicked {
            turning = true
            token += 1
            let current: Int = token
            withAnimation(.easeOut(duration: ctx["duration"] * 0.55), completionCriteria: .logicallyComplete) {
                corner = CGPoint(x: -CurlLayout.page.width, y: CurlLayout.page.height)
            } completion: {
                commit(current)
            }
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 1)) { corner = CurlLayout.home }
        }
    }

    /// Tap and autoplay: the corner travels the whole arc by itself.
    private func turn() {
        guard !turning else { return }
        turning = true
        token += 1
        let current: Int = token
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) { corner = CurlLayout.home }
        withAnimation(.timingCurve(0.5, 0, 0.3, 1, duration: ctx["duration"]), completionCriteria: .logicallyComplete) {
            autoT = 1
        } completion: {
            commit(current)
        }
    }

    /// The page has fully turned: the next one becomes the front page, with nothing visibly changing.
    private func commit(_ current: Int) {
        guard current == token else { return }
        if !ctx.isPreview { Haptics.tap(.soft) }
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) {
            index = (index + 1) % curlPages.count
            corner = CurlLayout.home
            autoT = 0
        }
        turning = false
    }
}

private struct CurlScene: View {
    let index: Int
    let point: CGPoint
    let shadow: CGFloat
    let ghost: Double
    let language: AppLanguage

    private static let paperBack = Color(hex: 0xEFEAE0)

    var body: some View {
        let size: CGSize = CurlLayout.page
        let geometry = CurlGeometry(point: point, size: size)
        let margin: CGFloat = CurlLayout.margin
        ZStack(alignment: .topLeading) {
            CurlPage(page: curlPages[(index + 1) % curlPages.count], language: language)
                .frame(width: size.width, height: size.height)
            Canvas { context, _ in
                CurlScene.drawFoldShadow(&context, geometry: geometry, strength: shadow)
            }
            .frame(width: size.width, height: size.height)
            CurlPage(page: curlPages[index % curlPages.count], language: language)
                .frame(width: size.width, height: size.height)
                .clipShape(CurlPolygon(points: geometry.front))
            if geometry.active {
                Canvas { context, _ in
                    context.translateBy(x: margin, y: margin)
                    CurlScene.drawFlap(&context, geometry: geometry, strength: shadow)
                }
                .frame(width: size.width + margin * 2, height: size.height + margin * 2)
                .offset(x: -margin, y: -margin)
                CurlPage(page: curlPages[index % curlPages.count], language: language)
                    .frame(width: size.width, height: size.height)
                    .transformEffect(geometry.reflection)
                    .clipShape(CurlPolygon(points: geometry.flap))
                    .opacity(ghost)
                Canvas { context, _ in
                    context.translateBy(x: margin, y: margin)
                    CurlScene.drawSheen(&context, geometry: geometry, strength: shadow)
                }
                .frame(width: size.width + margin * 2, height: size.height + margin * 2)
                .offset(x: -margin, y: -margin)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(CurlWindow())
        .background { CurlStack() }
    }

    private static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 2 else { return path }
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    /// The curl standing over the next page darkens it along the fold.
    private static func drawFoldShadow(_ context: inout GraphicsContext, geometry: CurlGeometry, strength: CGFloat) {
        guard geometry.active else { return }
        let reach: CGFloat = min(max(geometry.depth * 0.7, 14), 60)
        let end = CGPoint(x: geometry.mid.x + geometry.normal.x * reach, y: geometry.mid.y + geometry.normal.y * reach)
        context.fill(
            polygon(geometry.lifted),
            with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.42 * Double(strength)), Color.black.opacity(0)]),
                startPoint: geometry.mid,
                endPoint: end
            )
        )
    }

    /// The paper's back: a cast shadow, then the flap itself.
    private static func drawFlap(_ context: inout GraphicsContext, geometry: CurlGeometry, strength: CGFloat) {
        let flap: Path = polygon(geometry.flap)
        context.drawLayer { layer in
            layer.addFilter(.shadow(
                color: Color.black.opacity(0.45 * Double(strength)),
                radius: 6 + geometry.depth * 0.12,
                x: -geometry.normal.x * (4 + geometry.depth * 0.06),
                y: -geometry.normal.y * (4 + geometry.depth * 0.06) + 3
            ))
            layer.fill(flap, with: .color(paperBack))
        }
        context.stroke(flap, with: .color(Color.black.opacity(0.08)), lineWidth: 0.6)
    }

    /// Crease, highlight band and falloff across the flap, drawn over the show-through.
    private static func drawSheen(_ context: inout GraphicsContext, geometry: CurlGeometry, strength: CGFloat) {
        let far = CGPoint(x: geometry.mid.x - geometry.normal.x * geometry.depth, y: geometry.mid.y - geometry.normal.y * geometry.depth)
        let k = Double(0.35 + 0.65 * strength)
        let gradient = Gradient(stops: [
            .init(color: Color.black.opacity(0.26 * k), location: 0),
            .init(color: Color.black.opacity(0.04 * k), location: 0.1),
            .init(color: Color.white.opacity(0.7 * k), location: 0.28),
            .init(color: Color.white.opacity(0), location: 0.6),
            .init(color: Color.black.opacity(0.12 * k), location: 1),
        ])
        context.fill(polygon(geometry.flap), with: .linearGradient(gradient, startPoint: geometry.mid, endPoint: far))
    }
}

/// The pages underneath: two paper edges and a soft shadow.
private struct CurlStack: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: 0xD9D3C6))
                .offset(x: 5, y: 5)
            Rectangle()
                .fill(Color(hex: 0xE6E1D5))
                .offset(x: 2.5, y: 2.5)
        }
        .shadow(color: .black.opacity(0.22), radius: 16, y: 10)
    }
}

private struct CurlPageContent {
    let chapter: String
    let title: LocalizedText
    let symbol: String
    let colors: [Color]
}

private let curlPages: [CurlPageContent] = [
    CurlPageContent(chapter: "01", title: L("Easing", "缓动"), symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", colors: [Palette.coral, Palette.pink]),
    CurlPageContent(chapter: "02", title: L("Springs", "弹簧"), symbol: "waveform.path", colors: [Palette.indigo, Palette.violet]),
    CurlPageContent(chapter: "03", title: L("Stagger", "错峰"), symbol: "chart.bar.fill", colors: [Palette.mint, Palette.sky]),
    CurlPageContent(chapter: "04", title: L("Light", "光影"), symbol: "sun.max.fill", colors: [Palette.amber, Palette.coral]),
]

/// Printed paper: the same in light and dark mode, like a real book.
private struct CurlPage: View {
    let page: CurlPageContent
    let language: AppLanguage

    private static let ink = Color(hex: 0x2B2622)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: language == .zh ? "第 \(page.chapter) 章" : "CHAPTER \(page.chapter)")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(page.colors[0])
                Spacer()
                Text(verbatim: language == .zh ? "动效手册" : "HANDBOOK")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(CurlPage.ink.opacity(0.4))
            }
            Text(page.title, language)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(CurlPage.ink)
                .padding(.top, 6)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: page.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 86)
                .overlay {
                    Image(systemName: page.symbol)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .padding(.top, 12)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<4, id: \.self) { line in
                    Capsule()
                        .fill(CurlPage.ink.opacity(0.16))
                        .frame(height: 6)
                        .frame(maxWidth: line == 3 ? 110 : .infinity, alignment: .leading)
                }
            }
            .padding(.top, 16)
            Spacer(minLength: 0)
            Text(verbatim: page.chapter)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(CurlPage.ink.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .background(
            LinearGradient(colors: [Color(hex: 0xFCFAF4), Color(hex: 0xF6F2E8)], startPoint: .leading, endPoint: .trailing)
        )
        .overlay(alignment: .leading) {
            LinearGradient(colors: [Color.black.opacity(0.1), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 14)
        }
    }
}
