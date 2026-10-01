import SwiftUI

extension Effect {
    static let loadingShapeShifter = Effect(
        id: "loading.shape-shifter",
        category: .loading,
        interaction: .loop,
        name: L("Shape Shifter", "变形体"),
        summary: L("One shape hops, and in mid-air turns from circle to square to triangle to star.", "一个图形原地起跳，在空中由圆变方、变三角、再变星形。"),
        prompt: L(
            "A single 72 pt shape hops on the spot once every 1.0 s and is a different shape each time it lands: circle → rounded square → triangle → five-point star, then round again. Each beat starts with a 12% anticipation squash, launches into a 34 pt parabolic hop stretched 10% taller, and morphs during the middle 70% of the flight by interpolating the outline's radius at 120 angles, while the body spins through a symmetry angle of the new shape (72–120°) so it always lands upright. It lands with a 16% squash that rings out as a damped cosine. The fill blends mint → sky → violet → amber in step with the morph, and the contact shadow shrinks and fades at the apex. Playful, elastic, alive.",
            "一个 72 pt 的图形每 1.0 秒原地跳一次，每次落地都换了形状：圆 → 圆角方 → 三角 → 五角星，再回到圆。每一拍先下蹲压扁 12% 蓄力，随后沿抛物线跳起 34 pt、身体拉长 10%，在腾空的中间 70% 时间里完成形变——在 120 个角度上对轮廓半径做插值，同时转过新形状的一个对称角（72–120°），所以落地时总是端正的。落地时压扁 16%，再以阻尼余弦回弹收住。填充色随形变在薄荷绿 → 天蓝 → 紫罗兰 → 琥珀之间过渡，接触阴影在最高点缩小变淡。俏皮、有弹性、鲜活。"
        ),
        implementation: L(
            "Each outline is a radius function of the angle, sampled 120 times; a TimelineView blends two neighbouring samples and feeds squash, hop height and rotation from the same beat phase into one animatable-free Shape.",
            "每种轮廓都写成“角度 → 半径”的函数并采样 120 次；TimelineView 在相邻两组采样之间混合，并用同一个节拍相位算出压扁、跳高与旋转，交给一个 Shape 绘制。"
        ),
        apis: ["TimelineView", "Shape", "Path.addLines", "scaleEffect(x:y:anchor:)", "Color.mix(with:by:)"],
        tags: ["morph", "shape", "squash", "hop", "形变", "图形", "挤压拉伸", "加载"],
        params: [
            .slider("beat", L("Beat", "节拍"), 0.6...2.0, default: 1.0, decimals: 1, unit: "s"),
            .slider("hop", L("Hop height", "跳跃高度"), 0...60, default: 34, decimals: 0, unit: "pt"),
            .slider("squash", L("Squash", "挤压量"), 0...0.3, default: 0.16),
        ]
    ) { ctx in
        ShapeShifterDemo(ctx: ctx)
    }
}

private struct ShifterClock {
    var anchorDate = Date()
    var anchorPhase: Double = 0

    func phase(at date: Date, rate: Double) -> Double {
        anchorPhase + date.timeIntervalSince(anchorDate) * rate
    }

    mutating func rebase(at date: Date, oldRate: Double) {
        anchorPhase = phase(at: date, rate: oldRate)
        anchorDate = date
    }
}

private enum ShifterOutline {
    static let samples = 120

    /// Distance from the centre to a star-shaped polygon's edge along `angle` (unit circumradius).
    private static func radius(of vertices: [CGPoint], angle: Double) -> Double {
        let dx: Double = cos(angle)
        let dy: Double = sin(angle)
        var best: Double = .greatestFiniteMagnitude
        for index in 0..<vertices.count {
            let a = vertices[index]
            let b = vertices[(index + 1) % vertices.count]
            let ex: Double = Double(b.x - a.x)
            let ey: Double = Double(b.y - a.y)
            let denominator: Double = dx * ey - dy * ex
            guard abs(denominator) > 1e-9 else { continue }
            let t: Double = (Double(a.x) * ey - Double(a.y) * ex) / denominator
            let s: Double = (Double(a.x) * dy - Double(a.y) * dx) / denominator
            if t > 0, s >= -1e-6, s <= 1 + 1e-6 { best = min(best, t) }
        }
        return best == .greatestFiniteMagnitude ? 1 : best
    }

    private static func polygon(sides: Int, inner: Double? = nil, rotation: Double, scale: Double) -> [Double] {
        var vertices: [CGPoint] = []
        let count: Int = inner == nil ? sides : sides * 2
        for index in 0..<count {
            let angle: Double = rotation + 2 * .pi * Double(index) / Double(count)
            let r: Double = (inner != nil && index % 2 == 1) ? (inner ?? 1) : 1
            vertices.append(CGPoint(x: cos(angle) * r, y: sin(angle) * r))
        }
        return (0..<samples).map { sample in
            radius(of: vertices, angle: 2 * .pi * Double(sample) / Double(samples)) * scale
        }
    }

    /// Circle, square, triangle, star: scaled so the four read as the same visual weight.
    static let all: [[Double]] = [
        [Double](repeating: 0.9, count: samples),
        polygon(sides: 4, rotation: .pi / 4, scale: 1.12),
        polygon(sides: 3, rotation: -.pi / 2, scale: 1.18),
        polygon(sides: 5, inner: 0.5, rotation: -.pi / 2, scale: 1.12),
    ]

    static let colors: [Color] = [Palette.mint, Palette.sky, Palette.violet, Palette.amber]
    /// A rotation that maps each shape onto itself (the circle borrows the square's quarter turn).
    static let turns: [Double] = [90, 90, 120, 72]
    /// How far (in units of the half side) each outline must sink so that all four rest on the same floor.
    static let drops: [Double] = [0, 0.9 - 0.79, 0.9 - 0.59, 0]
}

/// A closed outline given as radii at evenly spaced angles; corners are softened by the stroke's round join.
private struct ShifterShape: Shape {
    let radii: [Double]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let unit: CGFloat = min(rect.width, rect.height) / 2
        var points: [CGPoint] = []
        points.reserveCapacity(radii.count)
        for index in 0..<radii.count {
            let angle: Double = 2 * .pi * Double(index) / Double(radii.count)
            let r: CGFloat = unit * CGFloat(radii[index])
            points.append(CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle))))
        }
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

private struct ShifterPose {
    var radii: [Double]
    var color: Color
    var lift: CGFloat
    var drop: CGFloat
    var scaleX: CGFloat
    var scaleY: CGFloat
    var degrees: Double
    var air: Double

    static func smooth(_ x: Double) -> Double {
        let u: Double = min(max(x, 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// One beat: squash (0…0.14) → flight (0.14…0.7) → landing ring-out (0.7…1).
    static func at(phase: Double, hop: CGFloat, squash: Double) -> ShifterPose {
        let count: Int = ShifterOutline.all.count
        let beat: Int = Int(floor(phase))
        let u: Double = phase - floor(phase)
        let from: Int = ((beat % count) + count) % count
        let to: Int = (from + 1) % count

        let launch: Double = 0.14
        let land: Double = 0.70
        var lift: Double = 0
        var stretch: Double = 0   // > 0 taller, < 0 flatter
        var flight: Double = 0
        if u < launch {
            // Anticipation: sink and come back up to neutral at take-off.
            stretch = -0.75 * squash * sin(.pi * u / launch)
        } else if u < land {
            flight = (u - launch) / (land - launch)
            lift = 4 * flight * (1 - flight)
            // Stretched on the way up, a little less on the way down, round at the apex.
            let along: Double = abs(cos(.pi * flight)) * (flight < 0.5 ? 1 : 0.6)
            stretch = 0.625 * squash * along * smooth(flight / 0.12)
        } else {
            flight = 1
            let w: Double = (u - land) / (1 - land)
            let ring: Double = -squash * exp(-4.5 * w) * cos(2.5 * .pi * w) * (1 - w)
            let attack: Double = smooth(w / 0.12)
            stretch = 0.375 * squash * (1 - attack) + ring * attack
        }

        let blend: Double = smooth((flight - 0.15) / 0.7)
        let a: [Double] = ShifterOutline.all[from]
        let b: [Double] = ShifterOutline.all[to]
        var radii: [Double] = a
        for index in 0..<radii.count { radii[index] = a[index] + (b[index] - a[index]) * blend }
        let drop: Double = ShifterOutline.drops[from] + (ShifterOutline.drops[to] - ShifterOutline.drops[from]) * blend

        return ShifterPose(
            radii: radii,
            color: ShifterOutline.colors[from].mix(with: ShifterOutline.colors[to], by: blend),
            lift: hop * CGFloat(lift),
            drop: CGFloat(drop),
            scaleX: CGFloat(1 - stretch * 0.8),
            scaleY: CGFloat(1 + stretch),
            // The body spins through a symmetry angle of the shape it is becoming, so it lands upright.
            degrees: ShifterOutline.turns[to] * smooth(flight),
            air: lift
        )
    }
}

private struct ShapeShifterDemo: View {
    let ctx: DemoContext
    @State private var clock = ShifterClock()

    var body: some View {
        let zh = ctx.language == .zh
        let beat: Double = max(ctx["beat"], 0.2)
        VStack(spacing: 20) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                // Stills freeze mid-morph in the air so the thumbnail shows the idea.
                let phase: Double = ctx.isStill ? 1.42 : clock.phase(at: timeline.date, rate: 1 / beat)
                let pose = ShifterPose.at(phase: phase, hop: ctx.cg("hop"), squash: ctx["squash"])
                ShifterBody(pose: pose)
            }
            .frame(width: 200, height: 170)
            VStack(spacing: 4) {
                Text(zh ? "正在准备画布" : "Preparing your canvas")
                    .font(.subheadline.weight(.semibold))
                Text(zh ? "载入形状、图层与样式…" : "Loading shapes, layers and styles…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx["beat"]) { old, _ in clock.rebase(at: .now, oldRate: 1 / max(old, 0.2)) }
    }
}

private struct ShifterBody: View {
    let pose: ShifterPose
    private let side: CGFloat = 72

    var body: some View {
        let shape = ShifterShape(radii: pose.radii)
        let fill = LinearGradient(
            colors: [pose.color.mix(with: .white, by: 0.28), pose.color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                shape.fill(fill)
                // The round-joined stroke softens every corner the radius function produces.
                shape.stroke(fill, style: StrokeStyle(lineWidth: 9, lineJoin: .round))
                shape
                    .fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: UnitPoint(x: 0.34, y: 0.3), startRadius: 0, endRadius: side * 0.5))
            }
            .frame(width: side, height: side)
            .rotationEffect(.degrees(pose.degrees))
            .offset(y: pose.drop * side / 2)
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            .shadow(color: pose.color.opacity(0.4), radius: 14, y: 8)
            .offset(y: -pose.lift)
            Ellipse()
                .fill(Color.primary.opacity(0.16 - 0.10 * pose.air))
                .frame(width: side * CGFloat(0.95 - 0.4 * pose.air), height: 9)
                .blur(radius: 3)
                .padding(.top, 12)
        }
        .padding(.bottom, 8)
    }
}
