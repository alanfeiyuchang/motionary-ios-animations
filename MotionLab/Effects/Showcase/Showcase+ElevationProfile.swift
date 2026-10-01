import SwiftUI

extension Effect {
    static let showcaseElevationProfile = Effect(
        id: "showcase.elevation-profile",
        category: .showcase,
        interaction: .gesture,
        name: L("Climb Elevation Profile", "爬坡海拔剖面"),
        summary: L(
            "A ride profile coloured by gradient; scrub and a tiny rider climbs the hill while distance, altitude and grade follow.",
            "按坡度着色的骑行剖面；拖动时小骑手沿山坡爬行，距离、海拔与坡度同步变化。"
        ),
        prompt: L(
            "A dark cycling widget for a 42 km mountain pass. A 264 × 120 pt elevation profile is filled in 36 vertical slices, each tinted by its own gradient (sky blue for descents, lime under 2%, yellow, orange, red above 10%) and fading towards the baseline. On arrival the profile wipes in from the left over 0.9 s and the rider rolls to 38% of the route. Scrubbing moves a bicycle glyph along the ridge line with a tight spring (response 0.18 s, damping 0.86); it tilts to the slope it is riding and drops a hairline to the baseline, the road ahead dims to 30%, and three readouts track it continuously: distance, altitude, and a grade chip that takes the slice colour. Ticks fire every 5 km and a firmer one at the summit, where the flag pops to 135% and turns orange. Sporty, legible, physical.",
            "深色骑行小组件，对象是一条 42 公里的山口路线。264 × 120pt 的海拔剖面切成 36 条竖带，每条按自身坡度着色（下坡天蓝，2% 以下青柠，随后黄、橙，超过 10% 为红），向基线渐隐。进入时剖面用 0.9 秒自左向右展开，骑手滑到路线 38% 处。拖动时骑行图标以紧致弹簧（响应 0.18 秒、阻尼 0.86）沿山脊线移动，随所在坡度倾斜，并向基线落下一条细线；前方路段暗到 30%，距离、海拔与取当前竖带颜色的坡度标签连续跟随。每 5 公里一次轻触感，山顶更重一下，旗帜弹到 135% 并变橙。运动、清晰。"
        ),
        implementation: L(
            "The card is an Animatable view over (reveal, progress). A Canvas builds one polygon per slice from the altitude function and fills it with a vertical gradient of the slice's grade colour, first dimmed, then again clipped to the travelled width at full strength. The rider's position and tilt come from the same function and its screen-space derivative; a DragGesture writes progress inside an interactive spring.",
            "卡片是以（reveal、progress）为动画数据的 Animatable 视图。Canvas 根据海拔函数为每条竖带生成多边形，并用该带坡度颜色的竖向渐变填充：先整体暗画一遍，再裁剪到已骑行宽度按全亮重画。骑手的位置与倾角来自同一函数及其屏幕空间导数；DragGesture 在交互弹簧中写入 progress。"
        ),
        apis: ["Animatable", "Canvas", "GraphicsContext.clip(to:)", "DragGesture", "interactiveSpring", "rotationEffect"],
        tags: ["elevation", "cycling", "ride", "profile", "gradient", "scrub", "海拔", "骑行", "坡度", "剖面", "爬坡"],
        params: [
            .slider("slices", L("Grade slices", "坡度分带"), 12...60, default: 36, step: 1, decimals: 0),
            .slider("relief", L("Vertical relief", "纵向起伏"), 0.4...1.0, default: 0.86),
            .slider("ahead", L("Road-ahead opacity", "前方路段不透明度"), 0.1...1.0, default: 0.3),
        ]
    ) { ctx in
        ElevationProfileDemo(ctx: ctx)
    }
}

/// The route: altitude (m) and grade (%) as functions of 0…1 along 42 km.
private enum RideProfile {
    static let distance: Double = 42
    static let floor: Double = 600
    static let ceiling: Double = 2100

    static func altitude(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        let warp = x < 0.68 ? x / 0.68 * 0.5 : 0.5 + (x - 0.68) / 0.32 * 0.5
        let hill = pow(sin(.pi * warp), 1.3)
        return 720 + 1240 * hill + 70 * sin(x * 17) + 25 * sin(x * 41 + 1)
    }

    static func grade(_ t: Double) -> Double {
        let e = 0.004
        let rise = altitude(t + e) - altitude(t - e)
        return rise / (2 * e * distance * 1000) * 100
    }

    static let summit: Double = {
        var best = 0.0
        var top = -Double.infinity
        for i in 0...400 {
            let t = Double(i) / 400
            if altitude(t) > top {
                top = altitude(t)
                best = t
            }
        }
        return best
    }()

    private static let keys: [(Double, UInt32)] = [(-2, 0x5AC8FA), (1.5, 0xC8F560), (4.5, 0xFFD24A), (7.5, 0xFF8A1F), (10.5, 0xFF4D5E)]

    static func color(_ grade: Double) -> Color {
        guard let first = keys.first, let last = keys.last else { return .white }
        if grade <= first.0 { return Color(hex: first.1) }
        for index in 1..<keys.count where grade <= keys[index].0 {
            let a = keys[index - 1]
            let b = keys[index]
            return studioMix(a.1, b.1, (grade - a.0) / (b.0 - a.0))
        }
        return Color(hex: last.1)
    }
}

private struct ElevationProfileDemo: View {
    let ctx: DemoContext
    @State private var reveal: Double
    @State private var progress: Double
    @State private var touching = false
    @State private var scripting = false
    @State private var script: Task<Void, Never>?
    @State private var lastMarker = 0
    @State private var atSummit = false
    @GestureState private var finger = false

    private let plot = CGSize(width: 264, height: 120)

    init(ctx: DemoContext) {
        self.ctx = ctx
        _reveal = State(initialValue: ctx.isStill ? 1 : 0)
        _progress = State(initialValue: ctx.isStill ? 0.56 : 0)
    }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ElevationCard(
                    reveal: reveal,
                    progress: progress,
                    slices: max(ctx.int("slices"), 4),
                    relief: ctx["relief"],
                    ahead: ctx["ahead"],
                    touching: touching,
                    zh: ctx.language == .zh,
                    plot: plot,
                    gesture: AnyGesture(
                        DragGesture(minimumDistance: 0)
                            .updating($finger) { _, state, _ in state = true }
                            .onChanged { value in
                                script?.cancel()
                                scripting = false
                                ride(to: Double(value.location.x / plot.width))
                            }
                            .onEnded { _ in lift() }
                            .map { _ in () }
                    )
                )
                .onChange(of: finger) { _, down in
                    if !down && !scripting { lift() }
                }
                Spacer(minLength: 0)
                DemoHint(text: L("Drag across the profile", "在剖面上左右拖动"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard !ctx.isStill else { return }
            withAnimation(.easeOut(duration: 0.9)) { reveal = 1 }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.25)) { progress = 0.38 }
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 6.4, delay: 1.6) { runScript() }
    }

    // MARK: Actions

    private func ride(to fraction: Double) {
        let next = fraction.clamped(to: 0...1)
        if !touching {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { touching = true }
            buzz { Haptics.tap(.light) }
        }
        let marker = Int(next * RideProfile.distance / 5)
        if marker != lastMarker {
            lastMarker = marker
            buzz { Haptics.selection() }
        }
        let summit = abs(next - RideProfile.summit) < 0.02
        if summit != atSummit {
            atSummit = summit
            if summit { buzz { Haptics.tap(.medium) } }
        }
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.86)) { progress = next }
    }

    private func lift() {
        guard touching else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { touching = false }
    }

    private func buzz(_ feedback: () -> Void) {
        guard !ctx.isPreview, !scripting else { return }
        feedback()
    }

    private func runScript() {
        script?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            let start = progress
            let legs: [(Double, Double)] = [(0.94, 2.6), (0.38, 1.3)]
            var from = start
            for (target, duration) in legs {
                let origin = from
                guard await studioScript(duration, { t in ride(to: origin + (target - origin) * studioEase(t)) }) else {
                    lift()
                    return
                }
                from = target
            }
            lift()
        }
    }
}

// MARK: - Card

private struct ElevationCard: View, Animatable {
    var reveal: Double
    var progress: Double
    let slices: Int
    let relief: Double
    let ahead: Double
    let touching: Bool
    let zh: Bool
    let plot: CGSize
    let gesture: AnyGesture<Void>

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(reveal, progress) }
        set {
            reveal = newValue.first
            progress = newValue.second
        }
    }

    var body: some View {
        let grade = RideProfile.grade(progress)
        VStack(alignment: .leading, spacing: 14) {
            SportEyebrowRow(
                title: zh ? "骑行 · 加利比耶山口" : "Ride · Col du Galibier",
                symbol: "bicycle",
                trailing: "42 km"
            )
            HStack(alignment: .bottom, spacing: 0) {
                stat(zh ? "距离" : "Distance", String(format: "%.1f", progress * RideProfile.distance), "km")
                Spacer(minLength: 0)
                stat(zh ? "海拔" : "Altitude", String(Int(RideProfile.altitude(progress).rounded())), "m")
                Spacer(minLength: 0)
                gradeChip(grade)
            }
            chart(grade: grade)
            axis
        }
        .padding(18)
        .frame(width: plot.width + 36)
        .signatureCard()
    }

    private func stat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: label)
                .signatureEyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: value)
                    .font(Signature.number(24))
                    .foregroundStyle(Color.white)
                Text(verbatim: unit)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
            }
        }
    }

    private func gradeChip(_ grade: Double) -> some View {
        let tint = RideProfile.color(grade)
        return VStack(alignment: .trailing, spacing: 4) {
            Text(verbatim: zh ? "坡度" : "Grade")
                .signatureEyebrow()
            HStack(spacing: 5) {
                // A little slope gauge: the bar leans with the road.
                Capsule()
                    .fill(Signature.ink)
                    .frame(width: 14, height: 2.5)
                    .rotationEffect(.degrees(-(grade * 3).clamped(to: -40...40)))
                Text(verbatim: String(format: "%+.1f%%", grade).replacingOccurrences(of: "-", with: "−"))
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Signature.ink)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint))
            .shadow(color: tint.opacity(0.45), radius: 8, y: 2)
        }
    }

    // MARK: Chart

    private func y(_ t: Double) -> CGFloat {
        let n = (RideProfile.altitude(t) - RideProfile.floor) / (RideProfile.ceiling - RideProfile.floor)
        return plot.height - 4 - CGFloat(n * relief) * (plot.height - 30)
    }

    private func chart(grade: Double) -> some View {
        let riderX = plot.width * CGFloat(progress)
        let riderY = y(progress)
        // Screen-space slope for the bike's tilt.
        let e = 0.01
        let tilt = atan2(Double(y(progress + e) - y(progress - e)), Double(plot.width) * 2 * e) * 180 / .pi
        let summitX = plot.width * CGFloat(RideProfile.summit)
        let nearSummit = abs(progress - RideProfile.summit) < 0.02
        return ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                draw(in: &context, riderX: riderX)
            }
            // Summit flag.
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(nearSummit ? Signature.accent : Color.white.opacity(0.6))
                .scaleEffect(nearSummit ? 1.35 : 1, anchor: .bottom)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: nearSummit)
                .position(x: summitX + 4, y: y(RideProfile.summit) - 11)
                .opacity(reveal > RideProfile.summit ? 1 : 0)
            // Hairline to the baseline.
            Rectangle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .frame(width: 1, height: max(plot.height - riderY, 0))
                .position(x: riderX, y: riderY + (plot.height - riderY) / 2)
            Circle()
                .fill(Color.white)
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(RideProfile.color(grade), lineWidth: 2.5).frame(width: 15, height: 15))
                .shadow(color: RideProfile.color(grade).opacity(0.9), radius: 6)
                .scaleEffect(touching ? 1.25 : 1)
                .position(x: riderX, y: riderY)
            Image(systemName: "figure.outdoor.cycle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .offset(y: -17)
                .rotationEffect(.degrees(tilt))
                .scaleEffect(touching ? 1.15 : 1)
                .position(x: riderX, y: riderY)
        }
        .frame(width: plot.width, height: plot.height)
        .opacity(reveal > 0.001 ? 1 : 0)
        .contentShape(Rectangle())
        .gesture(gesture)
    }

    private func draw(in context: inout GraphicsContext, riderX: CGFloat) {
        let revealX = plot.width * CGFloat(reveal)
        var ridge = Path()
        let samples = 132
        for index in 0...samples {
            let t = Double(index) / Double(samples)
            let p = CGPoint(x: plot.width * CGFloat(t), y: y(t))
            if index == 0 { ridge.move(to: p) } else { ridge.addLine(to: p) }
        }

        func paint(_ layer: inout GraphicsContext) {
            for slice in 0..<slices {
                let t0 = Double(slice) / Double(slices)
                let t1 = Double(slice + 1) / Double(slices)
                var strip = Path()
                strip.move(to: CGPoint(x: plot.width * CGFloat(t0), y: plot.height))
                var top = plot.height
                for sub in 0...4 {
                    let t = t0 + (t1 - t0) * Double(sub) / 4
                    let point = CGPoint(x: plot.width * CGFloat(t), y: y(t))
                    top = min(top, point.y)
                    strip.addLine(to: point)
                }
                strip.addLine(to: CGPoint(x: plot.width * CGFloat(t1), y: plot.height))
                strip.closeSubpath()
                let tint = RideProfile.color(RideProfile.grade((t0 + t1) / 2))
                layer.fill(
                    strip,
                    with: .linearGradient(
                        Gradient(colors: [tint.opacity(0.95), tint.opacity(0.12)]),
                        startPoint: CGPoint(x: 0, y: top),
                        endPoint: CGPoint(x: 0, y: plot.height)
                    )
                )
            }
            layer.stroke(ridge, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }

        // The road ahead, dimmed.
        var dim = context
        dim.clip(to: Path(CGRect(x: 0, y: -4, width: revealX, height: plot.height + 8)))
        dim.opacity = ahead
        paint(&dim)
        // The road behind the rider, at full strength.
        var lit = context
        lit.clip(to: Path(CGRect(x: 0, y: -4, width: min(revealX, riderX), height: plot.height + 8)))
        paint(&lit)
    }

    private var axis: some View {
        HStack(spacing: 0) {
            ForEach([0, 10, 20, 30, 40], id: \.self) { km in
                Text(verbatim: "\(km)")
                    .frame(width: plot.width * 10 / 42, alignment: .leading)
            }
        }
        .frame(width: plot.width, alignment: .leading)
        .clipped()
        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
        .foregroundStyle(Signature.textSecondary)
        .padding(.top, -8)
    }
}
