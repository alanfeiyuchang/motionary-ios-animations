import SwiftUI

extension Effect {
    static let chartsHemicycle = Effect(
        id: "charts.hemicycle",
        category: .charts,
        interaction: .tap,
        name: L("Parliament Seat Sweep", "议会席位扫入"),
        summary: L("Seats pop into a half-ring from left to right; a new result sweeps across and only the seats that change hands flip colour.", "席位自左向右弹入半环；新结果像扫描线一样扫过，只有易主的席位翻转颜色。"),
        prompt: L(
            "A parliament chart: 100 seats as 11 pt dots in five concentric half-rings, grouped by party into four coloured wedges, with a dashed majority line at the top and the leading party's seat count in the hollow centre. On appear the seats pop in along a sweep from the left end of the arc to the right over 1.1 s: each dot scales from 0 with a back-out overshoot of 1.7 as the front reaches its angle. Tapping loads the next election: a faint radial beam crosses the hemicycle again and only seats that change party react, swelling to 1.35× while their colour blends to the new party, so the moving wedge borders are obvious and the rest stays still. Legend counts and the centre figure roll in step with the beam; a success haptic lands if the leader crosses the majority line. Civic, countable, dramatic in a quiet way.",
            "议会席位图：100 个 11pt 圆点排成五层同心半环，按政党分成四个彩色扇区；顶部一条多数线虚线，中空处显示第一大党席位数。出现时席位沿从左端到右端的扫描在 1.1 秒内弹入：前沿到达某角度时，该处圆点从 0 放大，带 1.7 的回弹过冲。点击载入下一次选举：一道淡淡的径向光束再次扫过，只有易主的席位有反应——放大到 1.35 倍并过渡到新政党的颜色——扇区边界的移动一目了然，其余保持不动。图例与中心数字随光束滚动；第一大党越过多数线时触发成功触感。庄重、可数，安静中带着戏剧性。"
        ),
        implementation: L(
            "Seat positions are computed once per row count and sorted by angle, so a party is a contiguous run. A single linear 0…1 value drives everything: every seat derives its own local progress from its angle, which a Canvas turns into scale and an RGB blend between its old and new party.",
            "席位位置按行数只计算一次并按角度排序，因此每个政党是一段连续区间。一个线性的 0…1 值驱动全部动画：每个席位根据自己的角度推出局部进度，Canvas 再把它转成缩放，以及新旧政党之间的 RGB 混合。"
        ),
        apis: ["Canvas", "Animatable", "GraphicsContext", "linear(duration:)", "sin / cos"],
        tags: ["parliament", "hemicycle", "seats", "election", "议会", "半圆席位图", "选举", "席位分布"],
        params: [
            .slider("duration", L("Sweep duration", "扫描时长"), 0.5...2.5, default: 1.1, unit: "s"),
            .slider("overshoot", L("Pop overshoot", "弹出过冲"), 0...3, default: 1.7, decimals: 1),
            .slider("rows", L("Rows", "层数"), 3...6, default: 5, step: 1, decimals: 0),
        ]
    ) { ctx in
        HemicycleDemo(ctx: ctx)
    }
}

private struct HemicycleParty {
    let name: LocalizedText
    let rgb: ChartRGB
}

private let hemicycleParties: [HemicycleParty] = [
    HemicycleParty(name: L("Left", "左翼"), rgb: .coral),
    HemicycleParty(name: L("Greens", "绿党"), rgb: .green),
    HemicycleParty(name: L("Centre", "中间派"), rgb: .amber),
    HemicycleParty(name: L("Right", "右翼"), rgb: .indigo),
]

private let hemicycleShares: [[Double]] = [
    [0.30, 0.13, 0.20, 0.37],
    [0.42, 0.17, 0.14, 0.27],
    [0.22, 0.09, 0.17, 0.52],
]

private struct HemicycleLayout {
    /// Unit positions (centre at 0,0; outer radius 1; y up), sorted left to right along the arc.
    let seats: [(point: CGPoint, sweep: Double)]
    let dot: CGFloat

    init(rows: Int) {
        let count = min(max(rows, 3), 6)
        let inner = 0.44
        let gap = (1 - inner) / Double(count - 1)
        let pitch = gap * 0.8
        var all: [(point: CGPoint, sweep: Double)] = []
        for row in 0..<count {
            let radius = 1 - Double(row) * gap
            let n = max(Int((Double.pi * radius / pitch).rounded()), 3)
            for seat in 0..<n {
                let fraction = (Double(seat) + 0.5) / Double(n)
                let theta = Double.pi * (1 - fraction)
                all.append((CGPoint(x: radius * cos(theta), y: radius * sin(theta)), fraction))
            }
        }
        seats = all.sorted { $0.sweep < $1.sweep }
        dot = CGFloat(gap * 0.66)
    }

    func counts(_ shares: [Double]) -> [Int] {
        var out = shares.map { Int(($0 * Double(seats.count)).rounded()) }
        let last = out.count - 1
        out[last] = seats.count - out[0..<last].reduce(0, +)
        return out
    }

    /// Party index per seat, in sweep order.
    func assignment(_ shares: [Double]) -> [Int] {
        var out: [Int] = []
        for (party, n) in counts(shares).enumerated() { out.append(contentsOf: Array(repeating: party, count: max(n, 0))) }
        while out.count < seats.count { out.append(shares.count - 1) }
        return Array(out.prefix(seats.count))
    }
}

private struct HemicycleDemo: View {
    let ctx: DemoContext
    @State private var wave: Double = 1
    @State private var from = -1
    @State private var to = 0
    @State private var run: Task<Void, Never>?

    var body: some View {
        let layout = HemicycleLayout(rows: ctx.int("rows"))
        let toCounts = layout.counts(hemicycleShares[to])
        let fromCounts = from >= 0 ? layout.counts(hemicycleShares[from]) : [0, 0, 0, 0]
        return ChartStage(hint: L("Tap for the next election result", "点击查看下一次选举结果"), ctx: ctx) {
            HemicycleCard(
                wave: wave,
                layout: layout,
                fromSeats: from >= 0 ? layout.assignment(hemicycleShares[from]) : nil,
                toSeats: layout.assignment(hemicycleShares[to]),
                fromCounts: fromCounts,
                toCounts: toCounts,
                overshoot: ctx["overshoot"],
                year: 2017 + to * 4,
                language: ctx.language
            )
            .padding(16)
            .frame(width: 300)
            .demoCard()
            .contentShape(Rectangle())
            .onTapGesture { next() }
        }
        .onAppear {
            ChartEntrance.replay(isStill: ctx.isStill, reset: {
                wave = 0
                from = -1
            }, then: {
                withAnimation(.linear(duration: ctx["duration"])) { wave = 1 }
            })
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 2.4, delay: 2.2) { next() }
    }

    private func next() {
        Haptics.tap(.light)
        let duration = ctx["duration"]
        let layout = HemicycleLayout(rows: ctx.int("rows"))
        chartInstant {
            from = to
            to = (to + 1) % hemicycleShares.count
            wave = 0
        }
        run?.cancel()
        let leader = layout.counts(hemicycleShares[to]).max() ?? 0
        let majority = layout.seats.count / 2 + 1
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.03))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: duration)) { wave = 1 }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, !ctx.isPreview, leader >= majority else { return }
            Haptics.success()
        }
    }
}

private struct HemicycleCard: View, Animatable {
    var wave: Double
    let layout: HemicycleLayout
    let fromSeats: [Int]?
    let toSeats: [Int]
    let fromCounts: [Int]
    let toCounts: [Int]
    let overshoot: Double
    let year: Int
    let language: AppLanguage

    var animatableData: Double {
        get { wave }
        set { wave = newValue }
    }

    private static let front = 0.68
    private static let span = 0.32

    private func count(_ party: Int) -> Double {
        // A party's wedge has moved once the beam passed its borders; rolling with the wave is close enough.
        let t = ChartKit.smoothstep(0.05, 0.95, wave)
        return Double(fromCounts[party]) + Double(toCounts[party] - fromCounts[party]) * t
    }

    private var leader: Int {
        toCounts.indices.max { toCounts[$0] < toCounts[$1] } ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            ZStack(alignment: .bottom) {
                canvas
                centre
            }
            .frame(width: 268, height: 150)
            legend
        }
    }

    private var header: some View {
        let majority = layout.seats.count / 2 + 1
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Parliament", "议会席位"), language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verbatim: language == .zh ? "\(year) 年大选" : "\(year) election")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            Text(verbatim: language == .zh ? "过半需 \(majority) 席" : "\(majority) for a majority")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    private var centre: some View {
        let party = hemicycleParties[leader]
        return VStack(spacing: 0) {
            Text(verbatim: "\(Int(count(leader).rounded()))")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(party.rgb.mixed(ChartRGB(0x000000), 0.05).color())
            Text(party.name, language)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .offset(y: 2)
    }

    private var legend: some View {
        HStack(spacing: 0) {
            ForEach(hemicycleParties.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    Circle().fill(hemicycleParties[index].rgb.color()).frame(width: 7, height: 7)
                    Text(hemicycleParties[index].name, language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(Int(count(index).rounded()))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .fixedSize()
                if index < hemicycleParties.count - 1 { Spacer(minLength: 0) }
            }
        }
        .frame(width: 268)
    }

    private var canvas: some View {
        let wave = min(max(wave, 0), 1)
        return Canvas { context, size in
            let radius = min(size.width / 2, size.height) - 14
            let origin = CGPoint(x: size.width / 2, y: size.height - 8)
            let dot = layout.dot * radius

            // The beam at the front of the sweep.
            let beam = sin(Double.pi * wave)
            if beam > 0.01 {
                let theta = Double.pi * (1 - min(wave / Self.front, 1))
                var ray = Path()
                ray.move(to: CGPoint(x: origin.x + radius * 0.34 * CGFloat(cos(theta)), y: origin.y - radius * 0.34 * CGFloat(sin(theta))))
                ray.addLine(to: CGPoint(x: origin.x + (radius + 10) * CGFloat(cos(theta)), y: origin.y - (radius + 10) * CGFloat(sin(theta))))
                var glow = context
                glow.addFilter(.blur(radius: 5))
                glow.stroke(ray, with: .color(.primary.opacity(0.28 * beam)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }

            for index in layout.seats.indices {
                let seat = layout.seats[index]
                let local = ChartKit.stagger(wave, delay: seat.sweep * Self.front, span: Self.span)
                let centre = CGPoint(x: origin.x + radius * seat.point.x, y: origin.y - radius * seat.point.y)
                let target = hemicycleParties[toSeats[index]].rgb
                let scale: Double
                let colour: Color
                if let fromSeats {
                    let previous = hemicycleParties[fromSeats[index]].rgb
                    if fromSeats[index] == toSeats[index] {
                        scale = 1
                        colour = target.color()
                    } else {
                        scale = 1 + 0.35 * sin(Double.pi * local)
                        colour = previous.mixed(target, ChartKit.smoothstep(0.15, 0.7, local)).color()
                    }
                } else {
                    let empty = CGRect(x: centre.x - dot / 2, y: centre.y - dot / 2, width: dot, height: dot)
                    context.fill(Path(ellipseIn: empty), with: .color(.primary.opacity(0.07)))
                    scale = local <= 0 ? 0 : ChartKit.backOut(local, overshoot: overshoot)
                    colour = target.color()
                }
                guard scale > 0.01 else { continue }
                let d = dot * CGFloat(scale)
                context.fill(Path(ellipseIn: CGRect(x: centre.x - d / 2, y: centre.y - d / 2, width: d, height: d)), with: .color(colour))
            }

            // Majority line.
            var line = Path()
            line.move(to: CGPoint(x: origin.x, y: origin.y - radius * 0.36))
            line.addLine(to: CGPoint(x: origin.x, y: origin.y - radius - 12))
            context.stroke(line, with: .color(.primary.opacity(0.5)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 3]))
        }
    }
}
