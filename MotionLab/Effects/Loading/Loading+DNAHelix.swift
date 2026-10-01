import SwiftUI

extension Effect {
    static let loadingDNAHelix = Effect(
        id: "loading.dna-helix",
        category: .loading,
        interaction: .loop,
        name: L("DNA Double Helix", "DNA 双螺旋"),
        summary: L("Two strands of beads twist in depth, joined by rungs, while a reading pulse runs along them.", "两条珠链在纵深中缠绕旋转，由横档相连，一道读取脉冲沿链扫过。"),
        prompt: L(
            "Fourteen bead pairs form a horizontal double helix 236 pt long and 40 pt in radius, twisting 1.5 turns end to end and revolving once every 2.6 s. Each bead's depth is the cosine of its angle: front beads grow to 13 pt at full opacity with a soft halo, back beads shrink to 6 pt at 35%, and pairs are painted back to front so the strands truly cross. Each strand's backbone ribbon thins from 3 pt to 1 pt with depth, and a 1.5 pt rung links every pair. One strand runs mint → sky, the other violet → pink. Every 2.2 s a reading pulse travels left to right, swelling each pair by 35% and brightening its rung. Captioned 'Sequencing sample'. Scientific, hypnotic, weightless.",
            "十四对圆珠排成一条长 236 pt、半径 40 pt 的水平双螺旋，首尾扭转 1.5 圈，每 2.6 秒自转一周。每颗珠子的深度取其角度的余弦：转到前方时放大到 13 pt、不透明并带柔和光晕，转到后方时缩到 6 pt、透明度 35%，并由远到近绘制，两条链真正交叠穿插。每条链的骨架线随深度从 3 pt 变细到 1 pt，每对珠子间连着一根 1.5 pt 的横档。一条链为薄荷绿 → 天蓝，另一条为紫罗兰 → 粉。每 2.2 秒有一道读取脉冲自左向右扫过，所到之处珠子放大 35%、横档变亮。配文“正在测序样本”。科学、催眠、失重。"
        ),
        implementation: L(
            "A TimelineView feeds a phase into a Canvas; every bead is projected from an angle (x along the axis, y = sin, depth = cos), sorted by depth and filled with size and opacity taken from that depth.",
            "TimelineView 把相位传给 Canvas；每颗珠子由角度投影而来（x 沿轴线、y 取正弦、深度取余弦），按深度排序后绘制，大小与透明度都由深度决定。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.fill", "GraphicsContext.Filter.blur", "Color.mix(with:by:)"],
        tags: ["dna", "helix", "3d", "spinner", "双螺旋", "基因", "三维", "加载"],
        params: [
            .slider("period", L("Turn time", "自转周期"), 1.2...6, default: 2.6, decimals: 1, unit: "s"),
            .slider("pairs", L("Bead pairs", "珠对数量"), 8...20, default: 14, step: 1, decimals: 0),
            .slider("twist", L("Twist", "扭转圈数"), 0.5...2.5, default: 1.5, decimals: 1),
            .toggle("pulse", L("Reading pulse", "读取脉冲"), default: true),
        ]
    ) { ctx in
        DNAHelixDemo(ctx: ctx)
    }
}

/// A phase (in cycles) that stays continuous when its rate changes.
private struct HelixClock {
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

private struct DNAHelixDemo: View {
    let ctx: DemoContext

    var body: some View {
        let zh = ctx.language == .zh
        VStack(spacing: 22) {
            DNAHelixView(
                period: max(ctx["period"], 0.2),
                pairs: max(ctx.int("pairs"), 2),
                twist: ctx["twist"],
                pulse: ctx.bool("pulse"),
                preview: ctx.isPreview
            )
            .frame(width: 280, height: 136)
            VStack(spacing: 4) {
                Text(zh ? "正在测序样本" : "Sequencing sample")
                    .font(.subheadline.weight(.semibold))
                Text(zh ? "比对 3.2 亿个碱基对…" : "Aligning 320 million base pairs…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            DNABaseTicker(preview: ctx.isPreview)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Four base letters; the one being "read" lights up in turn.
private struct DNABaseTicker: View {
    let preview: Bool
    private let bases: [String] = ["A", "T", "G", "C"]
    private let colors: [Color] = [Palette.mint, Palette.sky, Palette.violet, Palette.pink]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.275)) { timeline in
            let step: Int = Int(timeline.date.timeIntervalSinceReferenceDate / 0.275)
            // A fixed pseudo-random walk over the four letters.
            let active: Int = (step &* 7 &+ (step / 3) &* 5) % 4
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    let lit: Bool = index == active
                    Text(bases[index])
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(lit ? Color.white : Color.secondary)
                        .frame(width: 26, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(lit ? colors[index] : Color.primary.opacity(0.06))
                        )
                        .scaleEffect(lit ? 1.08 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: lit)
                }
            }
        }
    }
}

private struct DNABead {
    var point: CGPoint
    var depth: Double
    var radius: CGFloat
    var color: Color
    var opacity: Double
}

private struct DNAHelixView: View {
    let period: Double
    let pairs: Int
    let twist: Double
    let pulse: Bool
    let preview: Bool
    @State private var clock = HelixClock()

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview))) { timeline in
            let phase: Double = clock.phase(at: timeline.date, rate: 1 / period)
            let seconds: Double = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                DNAHelixView.draw(in: &context, size: size, phase: phase, seconds: seconds, pairs: pairs, twist: twist, pulse: pulse)
            }
        }
        .onChange(of: period) { old, _ in clock.rebase(at: .now, oldRate: 1 / max(old, 0.2)) }
    }

    private static func strandColor(_ strand: Int, _ share: Double) -> Color {
        strand == 0
            ? Palette.mint.mix(with: Palette.sky, by: share)
            : Palette.violet.mix(with: Palette.pink, by: share)
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, phase: Double, seconds: Double, pairs: Int, twist: Double, pulse: Bool) {
        let length: CGFloat = 236
        let radius: CGFloat = 40
        let midY: CGFloat = size.height / 2
        let startX: CGFloat = (size.width - length) / 2
        // The reading pulse: a bump that travels the helix every 2.2 s (with a rest off both ends).
        let pulseHead: Double = (seconds / 2.2).truncatingRemainder(dividingBy: 1) * 1.5 - 0.25

        var beads: [DNABead] = []
        var rungs: [(from: CGPoint, to: CGPoint, alpha: Double, share: Double)] = []
        for index in 0..<pairs {
            let share: Double = pairs > 1 ? Double(index) / Double(pairs - 1) : 0.5
            let angle: Double = 2 * .pi * (phase + share * twist)
            let x: CGFloat = startX + length * CGFloat(share)
            let distance: Double = (share - pulseHead) / 0.13
            let bump: Double = pulse ? exp(-distance * distance) : 0
            // Taper the ends a little so the helix does not stop abruptly.
            let taper: CGFloat = CGFloat(0.82 + 0.18 * sin(.pi * share))
            var ends: [CGPoint] = []
            for strand in 0..<2 {
                let a: Double = angle + Double(strand) * .pi
                let depth: Double = cos(a)
                let y: CGFloat = midY + radius * taper * CGFloat(sin(a))
                let near: Double = (depth + 1) / 2
                let r: CGFloat = CGFloat(3 + 3.5 * near) * CGFloat(1 + 0.35 * bump)
                let point = CGPoint(x: x, y: y)
                ends.append(point)
                beads.append(DNABead(
                    point: point,
                    depth: depth,
                    radius: r,
                    color: strandColor(strand, share),
                    opacity: 0.35 + 0.65 * near
                ))
            }
            // A rung seen edge-on (both beads at mid depth, far apart on screen) is brightest when flat to the eye.
            let facing: Double = abs(sin(angle))
            rungs.append((ends[0], ends[1], 0.06 + 0.16 * facing + 0.45 * bump, share))
        }

        // Backbones: two continuous ribbons through the beads, thick and bright in front, thin and faint behind.
        let segments: Int = 72
        for strand in 0..<2 {
            var previous: CGPoint?
            for step in 0...segments {
                let share: Double = Double(step) / Double(segments)
                let a: Double = 2 * .pi * (phase + share * twist) + Double(strand) * .pi
                let taper: CGFloat = CGFloat(0.82 + 0.18 * sin(.pi * share))
                let point = CGPoint(x: startX + length * CGFloat(share), y: midY + radius * taper * CGFloat(sin(a)))
                if let last = previous {
                    let near: Double = (cos(a) + 1) / 2
                    var segment = Path()
                    segment.move(to: last)
                    segment.addLine(to: point)
                    context.stroke(
                        segment,
                        with: .color(strandColor(strand, share).opacity(0.12 + 0.38 * near)),
                        style: StrokeStyle(lineWidth: CGFloat(1 + 2 * near), lineCap: .round)
                    )
                }
                previous = point
            }
        }

        for rung in rungs {
            var path = Path()
            path.move(to: rung.from)
            path.addLine(to: rung.to)
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [strandColor(0, rung.share).opacity(rung.alpha), strandColor(1, rung.share).opacity(rung.alpha)]),
                startPoint: rung.from,
                endPoint: rung.to
            )
            context.stroke(path, with: shading, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        // Halos of the near beads, drawn once on a blurred layer.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            for bead in beads where bead.depth > 0.2 {
                let r: CGFloat = bead.radius * 1.5
                let rect = CGRect(x: bead.point.x - r, y: bead.point.y - r, width: r * 2, height: r * 2)
                layer.fill(Path(ellipseIn: rect), with: .color(bead.color.opacity(0.45 * bead.depth)))
            }
        }

        for bead in beads.sorted(by: { $0.depth < $1.depth }) {
            let r: CGFloat = bead.radius
            let rect = CGRect(x: bead.point.x - r, y: bead.point.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(bead.color.opacity(bead.opacity)))
            // A small specular dot on beads that face the viewer.
            if bead.depth > 0 {
                let h: CGFloat = r * 0.36
                let spot = CGRect(x: bead.point.x - r * 0.42 - h / 2, y: bead.point.y - r * 0.42 - h / 2, width: h, height: h)
                context.fill(Path(ellipseIn: spot), with: .color(.white.opacity(0.75 * bead.depth)))
            }
        }
    }
}
