import SwiftUI

extension Effect {
    static let morphBlobCycle = Effect(
        id: "morph.blob-cycle",
        category: .morph,
        interaction: .gesture,
        name: L("Jelly Blob", "果冻形变体"),
        summary: L(
            "A soft body that gulps and wobbles into each new shape, and stretches after your finger like jelly.",
            "一团软体：每次换形都先一缩再晃着长出来，手指一拉还会像果冻一样被扯长。"
        ),
        prompt: L(
            "A glossy 160 pt blob with a gradient body, a soft top-left highlight and a coloured glow underneath. Its outline is 72 radial points, each on its own under-damped spring (stiffness 140, damping 6) and coupled to its neighbours, so a disturbance travels around the rim as a wave instead of the whole shape easing at once. Tapping cycles squircle → five-petal flower → pebble → rounded triangle: the body gulps inward, then the new silhouette pushes out, overshoots and jiggles for about a second while the colours blend to the next pair. Dragging pulls the nearest part of the rim after the finger, up to 1.45× the radius; letting go snaps it back with a wobble. At rest it breathes faintly and turns slowly. Gooey, tactile, alive.",
            "一团约 160pt 的光泽软体：渐变主体、左上角柔和高光、身下一层同色辉光。轮廓由 72 个径向点组成，每个点挂在各自的欠阻尼弹簧上（刚度 140、阻尼 6），并与相邻点耦合，所以扰动会沿边缘像波一样传开，而不是整个形状一起缓动。点一下依次切换：超椭圆 → 五瓣花 → 卵石 → 圆角三角。主体先向内一缩，新轮廓再顶出来、冲过头并晃动约一秒，颜色同时过渡到下一组。拖动时离手指最近的边缘被拉出，最远到半径的 1.45 倍；松手后带着晃动弹回。静止时它微微呼吸、缓慢转动。黏稠、有手感、有生命。"
        ),
        implementation: L(
            "A small soft-body solver held in a reference type: per-point radius and velocity integrated with fixed 1/240 s sub-steps (spring to the target silhouette, damping, and a Laplacian term on the deviation). TimelineView drives a Canvas that steps the solver and draws the closed curve with a glow layer, gradient fill and clipped highlights.",
            "一个保存在引用类型里的小型软体求解器：逐点的半径与速度以固定 1/240 秒子步积分（指向目标轮廓的弹簧、阻尼，以及作用在偏差上的拉普拉斯耦合项）。TimelineView 驱动 Canvas 推进求解器，并绘制闭合曲线、辉光图层、渐变填充与裁剪高光。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "GraphicsContext.drawLayer", "UIGestureRecognizerRepresentable", "Path"],
        tags: ["blob", "soft body", "jelly", "gooey", "软体", "果冻", "黏性", "形变"],
        params: [
            .slider("stiffness", L("Stiffness", "刚度"), 40...320, default: 140, decimals: 0),
            .slider("damping", L("Damping", "阻尼"), 1...20, default: 6, decimals: 1),
            .slider("tension", L("Surface tension", "表面张力"), 0...1, default: 0.5),
            .toggle("spin", L("Slow rotation", "缓慢转动"), default: true),
        ]
    ) { ctx in
        BlobCycleDemo(ctx: ctx)
    }
}

private let blobNames: [LocalizedText] = [
    L("Squircle", "超椭圆"), L("Flower", "五瓣花"), L("Pebble", "卵石"), L("Trillium", "圆角三角"),
]

/// Gradient pairs per shape, as RGB so they can be blended while the shape changes.
private let blobPalettes: [[[Double]]] = [
    [[0.13, 0.83, 0.66], [0.23, 0.60, 1.00]],
    [[1.00, 0.45, 0.66], [0.60, 0.36, 1.00]],
    [[1.00, 0.76, 0.28], [1.00, 0.42, 0.36]],
    [[0.43, 0.48, 1.00], [0.25, 0.80, 1.00]],
]

private final class BlobBody {
    static let count = 72
    var radius: [Double]
    var velocity: [Double]
    /// Number of shape changes so far; the silhouette is `shape % 4`.
    var shape: Int
    /// Follows `shape` smoothly, for the colour blend.
    var tint: Double
    var clock: Double = 0
    var last: TimeInterval?
    /// Finger in the body's polar frame: angle (radians) and distance in radii.
    var poke: (angle: Double, reach: Double)?

    init(shape: Int) {
        self.shape = shape
        tint = Double(shape)
        radius = (0..<BlobBody.count).map { BlobBody.target(shape, Double($0) / Double(BlobBody.count) * 2 * .pi) }
        velocity = Array(repeating: 0, count: BlobBody.count)
    }

    /// Radius of silhouette `shape` at angle `theta`, in units of the blob's base radius.
    static func target(_ shape: Int, _ theta: Double) -> Double {
        switch ((shape % 4) + 4) % 4 {
        case 0:
            let n = 4.6
            return 0.8 / pow(pow(abs(cos(theta)), n) + pow(abs(sin(theta)), n), 1 / n)
        case 1:
            return 0.8 + 0.17 * cos(5 * theta)
        case 2:
            return 0.83 + 0.1 * sin(2 * theta + 0.5) + 0.07 * cos(3 * theta - 1)
        default:
            return 0.82 + 0.13 * cos(3 * theta - .pi / 2)
        }
    }

    func rotation(spin: Bool) -> Double {
        spin ? clock * 0.16 : 0
    }

    func gulp() {
        shape += 1
        for index in velocity.indices { velocity[index] -= 1.6 }
    }

    func step(now: TimeInterval, stiffness: Double, damping: Double, tension: Double) {
        let elapsed: Double = min(max(now - (last ?? now), 0), 0.05)
        last = now
        tint += (Double(shape) - tint) * min(elapsed * 5, 1)
        var remaining: Double = elapsed
        let h = 1.0 / 240
        while remaining > 0 {
            let dt: Double = min(h, remaining)
            integrate(dt, stiffness: stiffness, damping: damping, coupling: tension * stiffness * 20)
            remaining -= dt
        }
    }

    private func integrate(_ dt: Double, stiffness: Double, damping: Double, coupling: Double) {
        clock += dt
        let n: Int = BlobBody.count
        var deviation = [Double](repeating: 0, count: n)
        var goal = [Double](repeating: 0, count: n)
        for index in 0..<n {
            let theta: Double = Double(index) / Double(n) * 2 * .pi
            var wanted: Double = BlobBody.target(shape, theta)
            wanted += 0.012 * sin(clock * 1.6 + 2 * theta) + 0.008 * sin(clock * 1.1 - 3 * theta)
            if let poke {
                var delta: Double = (theta - poke.angle).truncatingRemainder(dividingBy: 2 * .pi)
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                let weight: Double = exp(-(delta / 0.55) * (delta / 0.55))
                wanted += weight * (poke.reach - wanted) * 0.9
            }
            goal[index] = wanted
            deviation[index] = radius[index] - wanted
        }
        for index in 0..<n {
            let left: Double = deviation[(index + n - 1) % n]
            let right: Double = deviation[(index + 1) % n]
            let laplacian: Double = left + right - 2 * deviation[index]
            let force: Double = stiffness * (goal[index] - radius[index]) + coupling * laplacian - damping * velocity[index]
            velocity[index] += force * dt
        }
        for index in 0..<n {
            radius[index] = min(max(radius[index] + velocity[index] * dt, 0.2), 1.7)
        }
    }

    func colors() -> (Color, Color) {
        let base: Double = max(tint, 0).rounded(.down)
        let t: Double = min(max(tint - base, 0), 1)
        let a: [[Double]] = blobPalettes[Int(base) % 4]
        let b: [[Double]] = blobPalettes[(Int(base) + 1) % 4]
        func mix(_ index: Int) -> Color {
            Color(
                .sRGB,
                red: a[index][0] + (b[index][0] - a[index][0]) * t,
                green: a[index][1] + (b[index][1] - a[index][1]) * t,
                blue: a[index][2] + (b[index][2] - a[index][2]) * t,
                opacity: 1
            )
        }
        return (mix(0), mix(1))
    }
}

private struct BlobCycleDemo: View {
    let ctx: DemoContext
    @State private var model: BlobBody
    @State private var step: Int
    @State private var touchStart: CGPoint = .zero

    private static let canvas = CGSize(width: 320, height: 300)
    private static let baseRadius: CGFloat = 96
    private static let overhang: CGFloat = 34

    init(ctx: DemoContext) {
        self.ctx = ctx
        _model = State(initialValue: BlobBody(shape: 1))
        _step = State(initialValue: 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                BlobCanvas(
                    model: model,
                    now: timeline.date.timeIntervalSinceReferenceDate,
                    baseRadius: Self.baseRadius,
                    stiffness: ctx["stiffness"],
                    damping: ctx["damping"],
                    tension: ctx["tension"],
                    spin: ctx.bool("spin")
                )
            }
            .frame(width: Self.canvas.width, height: Self.canvas.height)
            // The canvas is taller than its layout slot, so a stretched blob can reach over the caption.
            .padding(.vertical, -Self.overhang)
            .contentShape(Rectangle())
            .onTapGesture { next() }
            // Any direction: the blob takes the drag (the page scroll waits for it) and is poked by it.
            .gesture(PageSafePan(directions: [.up, .down, .left, .right], onChanged: pokeChanged, onEnded: pokeEnded, onBegan: { touchStart = $0 }))
            VStack(spacing: 8) {
                Text(blobNames[step % blobNames.count], ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .id(step)
                    .transition(.blurReplace)
                HStack(spacing: 6) {
                    ForEach(blobNames.indices, id: \.self) { index in
                        Capsule()
                            .fill(Color.primary.opacity(index == step % blobNames.count ? 0.55 : 0.15))
                            .frame(width: index == step % blobNames.count ? 16 : 6, height: 6)
                    }
                }
            }
            .allowsHitTesting(false)
            DemoHint(text: L("Tap to morph, drag to stretch", "点击换形，拖动拉扯"), ctx: ctx)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7) { next() }
    }

    private func next() {
        if !ctx.isPreview { Haptics.tap(.soft) }
        model.gulp()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step = model.shape }
    }

    private func pokeChanged(_ t: CGSize) {
        let dx: CGFloat = touchStart.x + t.width - Self.canvas.width / 2
        // Touches are reported in the layout slot, which is `overhang` shorter than the canvas at each end.
        let dy: CGFloat = touchStart.y + t.height - (Self.canvas.height / 2 - Self.overhang)
        let distance: Double = Double((dx * dx + dy * dy).squareRoot() / Self.baseRadius)
        let angle: Double = Double(atan2(dy, dx)) - model.rotation(spin: ctx.bool("spin"))
        model.poke = (angle: angle, reach: min(max(distance, 0.35), 1.45))
    }

    private func pokeEnded(_ end: PageSafePanEnd?) {
        guard model.poke != nil else { return }
        model.poke = nil
        if !ctx.isPreview { Haptics.tap(.light) }
    }
}

private struct BlobCanvas: View {
    let model: BlobBody
    let now: TimeInterval
    let baseRadius: CGFloat
    let stiffness: Double
    let damping: Double
    let tension: Double
    let spin: Bool

    var body: some View {
        Canvas { context, size in
            model.step(now: now, stiffness: stiffness, damping: damping, tension: tension)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outline: Path = BlobCanvas.outline(model: model, center: center, radius: baseRadius, rotation: model.rotation(spin: spin))
            let bounds: CGRect = outline.boundingRect
            let (first, second) = model.colors()

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 22))
                layer.opacity = 0.5
                layer.fill(outline.offsetBy(dx: 0, dy: 12), with: .color(second))
            }
            context.fill(
                outline,
                with: .linearGradient(
                    Gradient(colors: [first, second]),
                    startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                    endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)
                )
            )
            context.drawLayer { layer in
                layer.clip(to: outline)
                let glint = CGPoint(x: bounds.minX + bounds.width * 0.3, y: bounds.minY + bounds.height * 0.24)
                layer.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)]),
                        center: glint,
                        startRadius: 0,
                        endRadius: bounds.width * 0.55
                    )
                )
                let shade = CGPoint(x: bounds.minX + bounds.width * 0.7, y: bounds.maxY + bounds.height * 0.1)
                layer.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [Color.black.opacity(0.22), Color.black.opacity(0)]),
                        center: shade,
                        startRadius: 0,
                        endRadius: bounds.width * 0.6
                    )
                )
                layer.addFilter(.blur(radius: 5))
                let spot = CGRect(x: bounds.minX + bounds.width * 0.2, y: bounds.minY + bounds.height * 0.15, width: bounds.width * 0.2, height: bounds.height * 0.1)
                layer.fill(Path(ellipseIn: spot), with: .color(Color.white.opacity(0.6)))
            }
            context.stroke(outline, with: .color(Color.white.opacity(0.4)), lineWidth: 1.2)
        }
    }

    /// Closed curve through the rim points (quadratic segments between midpoints, so it is smooth everywhere).
    private static func outline(model: BlobBody, center: CGPoint, radius: CGFloat, rotation: Double) -> Path {
        let n: Int = BlobBody.count
        var points: [CGPoint] = []
        points.reserveCapacity(n)
        for index in 0..<n {
            let theta: Double = Double(index) / Double(n) * 2 * .pi + rotation
            let r: CGFloat = radius * CGFloat(model.radius[index])
            points.append(CGPoint(x: center.x + r * CGFloat(cos(theta)), y: center.y + r * CGFloat(sin(theta))))
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        var path = Path()
        path.move(to: mid(points[n - 1], points[0]))
        for index in 0..<n {
            path.addQuadCurve(to: mid(points[index], points[(index + 1) % n]), control: points[index])
        }
        path.closeSubpath()
        return path
    }
}
