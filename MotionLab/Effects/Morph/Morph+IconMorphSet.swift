import SwiftUI

extension Effect {
    static let morphIconMorphSet = Effect(
        id: "morph.icon-morph-set",
        category: .morph,
        interaction: .tap,
        name: L("Icon Path Morph", "图标路径形变"),
        summary: L(
            "One glossy icon whose outline flows between heart, star, bolt and drop on a bouncy spring, with a slower echo ring trailing behind.",
            "同一枚有光泽的图标，轮廓乘着带回弹的弹簧在爱心、星形、闪电和水滴之间流动，身后跟着一圈慢半拍的回声轮廓。"
        ),
        prompt: L(
            "A single 150 pt glossy icon above a four-item picker. Each silhouette (heart, star, bolt, drop) is resampled to 120 points that start at the top and run clockwise, so any two outlines blend point by point. Tapping the icon or a picker item springs four blend weights to the new shape (response 0.55 s, damping 0.55): the path overshoots past the target before settling, so tips stretch and snap back like rubber. The gradient fill blends with the same weights (pink, amber, violet, blue), the icon winds back 18° and unwinds, and dips to 88% before springing up. A thin echo outline at 118% follows on a slower spring (response 0.9 s), lagging behind the body, while a blurred glow of the same shape breathes underneath. Elastic, juicy, mid-flight interruptible.",
            "一枚 150pt 的光泽图标，下方是四选一的切换条。爱心、星形、闪电、水滴四种轮廓都重采样为 120 个点，从顶部起顺时针排列，任意两种轮廓都能逐点混合。点图标或切换条，四个混合权重乘弹簧（响应 0.55 秒、阻尼 0.55）奔向新形状：路径会先冲过目标再回落，尖角像橡皮一样拉长又弹回。渐变填色用同一组权重混合（粉、琥珀、紫、蓝），图标先回拧 18° 再松开，并先压到 88% 再弹起。118% 大小的细回声轮廓乘更慢的弹簧（响应 0.9 秒）跟在后面，同形状的模糊辉光在底下呼吸。飞行途中可随时打断。"
        ),
        implementation: L(
            "Four outlines are resampled by arc length to the same point count; a custom VectorArithmetic holds the four blend weights, so SwiftUI springs them (negative and >1 weights give the elastic overshoot) and a Canvas draws the weighted sum, its gradient, gloss and glow each frame.",
            "四种轮廓按弧长重采样为相同点数；自定义 VectorArithmetic 保存四个混合权重，由 SwiftUI 的弹簧直接驱动（权重小于 0 或大于 1 即形成弹性过冲），Canvas 每帧绘制加权后的轮廓、渐变、高光与辉光。"
        ),
        apis: ["VectorArithmetic", "Animatable", "Canvas", "GraphicsContext.drawLayer", "spring(response:dampingFraction:)"],
        tags: ["icon", "path morph", "heart", "star", "elastic", "图标", "路径形变", "爱心", "弹性"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.2, default: 0.55, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.3...1.0, default: 0.55),
            .slider("twist", L("Twist", "回拧角度"), 0...60, default: 18, decimals: 0, unit: "°"),
            .toggle("echo", L("Echo outline", "回声轮廓"), default: true),
        ]
    ) { ctx in
        IconMorphDemo(ctx: ctx)
    }
}

/// Blend weights of the four silhouettes; SwiftUI interpolates it like any other animatable vector.
private struct IconWeights: VectorArithmetic {
    var a: Double
    var b: Double
    var c: Double
    var d: Double

    static let zero = IconWeights(a: 0, b: 0, c: 0, d: 0)

    static func one(_ index: Int) -> IconWeights {
        IconWeights(a: index == 0 ? 1 : 0, b: index == 1 ? 1 : 0, c: index == 2 ? 1 : 0, d: index == 3 ? 1 : 0)
    }

    var values: [Double] { [a, b, c, d] }

    static func + (lhs: IconWeights, rhs: IconWeights) -> IconWeights {
        IconWeights(a: lhs.a + rhs.a, b: lhs.b + rhs.b, c: lhs.c + rhs.c, d: lhs.d + rhs.d)
    }

    static func - (lhs: IconWeights, rhs: IconWeights) -> IconWeights {
        IconWeights(a: lhs.a - rhs.a, b: lhs.b - rhs.b, c: lhs.c - rhs.c, d: lhs.d - rhs.d)
    }

    mutating func scale(by rhs: Double) {
        a *= rhs
        b *= rhs
        c *= rhs
        d *= rhs
    }

    var magnitudeSquared: Double { a * a + b * b + c * c + d * d }
}

private enum IconMorphShapes {
    static let count = 120
    static let symbols: [String] = ["heart.fill", "star.fill", "bolt.fill", "drop.fill"]
    static let names: [LocalizedText] = [L("Heart", "爱心"), L("Star", "星形"), L("Bolt", "闪电"), L("Drop", "水滴")]
    /// Gradient stops (top, bottom) per shape as RGB, so they blend with the weights.
    static let colors: [[[Double]]] = [
        [[1.00, 0.45, 0.70], [1.00, 0.27, 0.40]],
        [[1.00, 0.82, 0.32], [1.00, 0.52, 0.22]],
        [[0.72, 0.48, 1.00], [0.42, 0.42, 1.00]],
        [[0.30, 0.82, 1.00], [0.26, 0.48, 1.00]],
    ]

    /// Unit outlines (roughly −1…1), all starting at the top and running clockwise.
    static let outlines: [[CGPoint]] = [heart(), star(), bolt(), drop()].map { normalised(resample($0)) }

    private static func heart() -> [CGPoint] {
        (0..<400).map { step in
            let t = Double(step) / 400 * 2 * Double.pi
            let x = 16 * pow(sin(t), 3)
            let y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
            return CGPoint(x: x, y: y)
        }
    }

    private static func star() -> [CGPoint] {
        (0..<10).map { index in
            let angle = -Double.pi / 2 + Double(index) * Double.pi / 5
            let radius: Double = index % 2 == 0 ? 1 : 0.47
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    private static func bolt() -> [CGPoint] {
        [
            CGPoint(x: 0.64, y: 0.0), CGPoint(x: 0.5, y: 0.41), CGPoint(x: 0.84, y: 0.41),
            CGPoint(x: 0.34, y: 1.0), CGPoint(x: 0.5, y: 0.59), CGPoint(x: 0.16, y: 0.59),
        ]
    }

    private static func drop() -> [CGPoint] {
        (0..<400).map { step in
            let t = Double(step) / 400 * 2 * Double.pi
            let x = sin(t) * pow(sin(t / 2), 1.5) * 0.8
            let y = -cos(t)
            return CGPoint(x: x, y: y)
        }
    }

    /// `count` points evenly spaced along the closed polyline, starting at its first vertex.
    private static func resample(_ points: [CGPoint]) -> [CGPoint] {
        var lengths: [CGFloat] = [0]
        for index in 0..<points.count {
            let a: CGPoint = points[index]
            let b: CGPoint = points[(index + 1) % points.count]
            lengths.append(lengths[index] + hypot(b.x - a.x, b.y - a.y))
        }
        let total: CGFloat = lengths[points.count]
        var result: [CGPoint] = []
        var segment = 0
        for index in 0..<count {
            let target: CGFloat = total * CGFloat(index) / CGFloat(count)
            while segment < points.count - 1, lengths[segment + 1] < target { segment += 1 }
            let span: CGFloat = max(lengths[segment + 1] - lengths[segment], 0.000001)
            let u: CGFloat = (target - lengths[segment]) / span
            result.append(MorphMath.lerp(points[segment], points[(segment + 1) % points.count], u))
        }
        return result
    }

    private static func normalised(_ points: [CGPoint]) -> [CGPoint] {
        let xs: [CGFloat] = points.map(\.x)
        let ys: [CGFloat] = points.map(\.y)
        let minX: CGFloat = xs.min() ?? 0
        let maxX: CGFloat = xs.max() ?? 1
        let minY: CGFloat = ys.min() ?? 0
        let maxY: CGFloat = ys.max() ?? 1
        let half: CGFloat = max(maxX - minX, maxY - minY) / 2
        let mid = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        return points.map { CGPoint(x: ($0.x - mid.x) / half, y: ($0.y - mid.y) / half) }
    }

    static func path(_ weights: IconWeights, center: CGPoint, radius: CGFloat) -> Path {
        let w: [Double] = weights.values
        var path = Path()
        for index in 0..<count {
            var x: CGFloat = 0
            var y: CGFloat = 0
            for shape in 0..<4 {
                x += outlines[shape][index].x * CGFloat(w[shape])
                y += outlines[shape][index].y * CGFloat(w[shape])
            }
            let point = CGPoint(x: center.x + x * radius, y: center.y + y * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    static func color(_ weights: IconWeights, stop: Int) -> Color {
        let w: [Double] = weights.values
        var rgb: [Double] = [0, 0, 0]
        for shape in 0..<4 {
            for channel in 0..<3 {
                rgb[channel] += colors[shape][stop][channel] * w[shape]
            }
        }
        return Color(red: rgb[0].clamped(to: 0...1), green: rgb[1].clamped(to: 0...1), blue: rgb[2].clamped(to: 0...1))
    }
}

private struct IconMorphDemo: View {
    let ctx: DemoContext
    @State private var current = 0
    @State private var weights = IconWeights.one(0)
    @State private var echo = IconWeights.one(0)
    @State private var kick: Double = 0
    @State private var squash: CGFloat = 1

    var body: some View {
        VStack(spacing: 14) {
            icon
            picker
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, ctx.isPreview ? 0 : 22)
        .overlay(alignment: .bottom) {
            DemoHint(text: L("Tap the icon or pick a shape", "点击图标，或在下方选形状"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .autoplay(ctx.isPreview, every: 1.35) { select((current + 1) % 4) }
    }

    private var icon: some View {
        ZStack {
            if ctx.bool("echo") {
                MorphAnimated(echo) { value in
                    IconMorphEcho(weights: value)
                }
            }
            MorphAnimated(weights) { value in
                IconMorphArt(weights: value)
            }
            .scaleEffect(squash)
        }
        .frame(width: 220, height: 210)
        .rotationEffect(.degrees(kick))
        .contentShape(Rectangle())
        .onTapGesture { select((current + 1) % 4) }
    }

    private var picker: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                let on: Bool = index == current
                Button { select(index) } label: {
                    Image(systemName: IconMorphShapes.symbols[index])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(on ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.secondary))
                        .frame(width: 52, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(alignment: .leading) {
            Capsule()
                .fill(LinearGradient(
                    colors: [IconMorphShapes.color(.one(current), stop: 0), IconMorphShapes.color(.one(current), stop: 1)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 52, height: 36)
                .offset(x: CGFloat(current) * 56)
        }
        .padding(4)
        .background(Color.primary.opacity(0.07), in: Capsule())
    }

    private func select(_ index: Int) {
        guard index != current else { return }
        if !ctx.isPreview { Haptics.tap(.soft) }
        let spring: Animation = .spring(response: ctx["response"], dampingFraction: ctx["damping"])
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) {
            kick = -ctx["twist"]
            squash = 0.88
        }
        withAnimation(spring) {
            current = index
            weights = .one(index)
            kick = 0
            squash = 1
        }
        withAnimation(.spring(response: ctx["response"] * 1.65, dampingFraction: 0.7)) { echo = .one(index) }
    }
}

private struct IconMorphArt: View {
    let weights: IconWeights

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius: CGFloat = 75
            let path: Path = IconMorphShapes.path(weights, center: center, radius: radius)
            let top: Color = IconMorphShapes.color(weights, stop: 0)
            let bottom: Color = IconMorphShapes.color(weights, stop: 1)
            let fill = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: CGPoint(x: center.x - radius * 0.4, y: center.y - radius),
                endPoint: CGPoint(x: center.x + radius * 0.4, y: center.y + radius)
            )
            // Glow: the same silhouette, blurred and dropped a little.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 16))
                layer.opacity = 0.5
                layer.translateBy(x: 0, y: 10)
                layer.fill(path, with: .color(bottom))
            }
            context.fill(path, with: fill)
            // Gloss: a soft highlight clipped to the silhouette.
            context.drawLayer { layer in
                layer.clip(to: path)
                let spot = CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.6)
                layer.fill(
                    Path(ellipseIn: CGRect(x: spot.x - radius * 1.1, y: spot.y - radius * 0.9, width: radius * 2.2, height: radius * 1.8)),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)]),
                        center: spot, startRadius: 0, endRadius: radius * 1.1
                    )
                )
                layer.fill(
                    Path(CGRect(x: 0, y: center.y + radius * 0.35, width: size.width, height: radius)),
                    with: .linearGradient(
                        Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.14)]),
                        startPoint: CGPoint(x: 0, y: center.y + radius * 0.35),
                        endPoint: CGPoint(x: 0, y: center.y + radius)
                    )
                )
            }
            context.stroke(path, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
        }
    }
}

private struct IconMorphEcho: View {
    let weights: IconWeights

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let color: Color = IconMorphShapes.color(weights, stop: 1)
            let outer: Path = IconMorphShapes.path(weights, center: center, radius: 75 * 1.18)
            context.stroke(outer, with: .color(color.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            let far: Path = IconMorphShapes.path(weights, center: center, radius: 75 * 1.34)
            context.stroke(far, with: .color(color.opacity(0.18)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        }
    }
}
