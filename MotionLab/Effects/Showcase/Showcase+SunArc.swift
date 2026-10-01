import SwiftUI

extension Effect {
    static let showcaseSunArc = Effect(
        id: "showcase.sun-arc",
        category: .showcase,
        interaction: .gesture,
        name: L("Sun Arc Day Dial", "日出日落弧线"),
        summary: L(
            "Drag the sun along its daily curve: the sky, the stars and the clock follow, then it springs back to now.",
            "沿着一天的弧线拖动太阳：天空、星星与时间读数随之连续变化，松手弹回“现在”。"
        ),
        prompt: L(
            "A 300 × 270 pt sunrise/sunset widget whose whole card is the sky. A smooth cosine curve crosses a horizon line; the part above is bright, the part below dashed and dim. A glowing 22 pt sun sits on the curve at the current time under a large HH:mm readout and a line such as \"Sunset in 2 h 05 m\". Dragging horizontally moves the sun 1:1 along the curve while everything is derived from its elevation every frame: the three-stop sky gradient blends night navy, twilight violet and amber, golden hour and day blue, the sun warms from white to deep orange near the horizon with an amber bloom, and below it becomes a dim outlined disc as stars fade in and twinkle. Crossing the horizon fires a medium tick; a small ring marks \"now\". On release the sun springs back to now (response 0.6 s, damping 0.72). Serene.",
            "300 × 270pt 的日出日落小组件，整张卡片即天空。平滑余弦曲线穿过地平线：线上明亮，线下为暗淡虚线。22pt 发光太阳停在当前时刻，上方是大号 HH:mm 读数与“距日落 2 小时 05 分”。横向拖动，太阳沿曲线 1:1 移动，一切由其高度逐帧推导：三段天空渐变在深夜藏蓝、暮光紫与琥珀、金色、白昼蓝之间连续混合，太阳近地平线时由白转深橙并泛起琥珀光晕，落到线下变成暗淡描边圆，星星渐显。越过地平线有一次中等触感；小圆环标记“现在”。松手后以弹簧（响应 0.6 秒、阻尼 0.72）回到现在。宁静。"
        ),
        implementation: L(
            "The card is an Animatable view whose animatableData is the hour, so the release spring re-evaluates the whole scene per frame: elevation = (cos(2π(h − noon)/24) − c)/(1 − c), sky colours by piecewise sRGB interpolation over elevation keyframes, sun position on a sampled Path, stars in a Canvas inside a TimelineView. A DragGesture maps x to the hour.",
            "卡片是一个 Animatable 视图，animatableData 为小时数，因此松手弹簧会逐帧重算整个场景：高度 = (cos(2π(h − 正午)/24) − c)/(1 − c)，天空颜色按高度关键帧做分段 sRGB 插值，太阳位置取自采样 Path，星星用 TimelineView 里的 Canvas 绘制；DragGesture 把横坐标映射为小时。"
        ),
        apis: ["Animatable", "DragGesture", "LinearGradient", "Canvas", "TimelineView", "spring(response:dampingFraction:)"],
        tags: ["sunrise", "sunset", "weather", "sky", "scrub", "日出", "日落", "天气", "天空", "弧线"],
        params: [
            .slider("now", L("Current time", "当前时刻"), 0...24, default: 16.75, step: 0.25, unit: "h"),
            .slider("day", L("Day length", "白昼时长"), 8...16, default: 12.7, decimals: 1, unit: "h"),
            .slider("snap", L("Snap-back response", "回弹响应"), 0.3...1.2, default: 0.6, unit: "s"),
            .toggle("stars", L("Stars at night", "夜晚星空"), default: true),
        ]
    ) { ctx in
        SunArcDemo(ctx: ctx)
    }
}

/// Solar geometry of the widget (hours 0…24, elevation −1…1, zero at the horizon).
private struct SunDay {
    var dayLength: Double
    let noon: Double = 12.4

    private var c: Double { cos(.pi * dayLength / 24) }
    var sunrise: Double { noon - dayLength / 2 }
    var sunset: Double { noon + dayLength / 2 }

    func elevation(_ hour: Double) -> Double {
        (cos(2 * .pi * (hour - noon) / 24) - c) / (1 - c)
    }
}

private struct SunArcDemo: View {
    let ctx: DemoContext
    @State private var hour: Double
    @State private var grabbed = false
    /// The drag is relative: the sun moves by the finger's travel from wherever it was grabbed.
    @State private var grabHour: Double = 12
    @State private var scripting = false
    @State private var script: Task<Void, Never>?
    @GestureState private var touching = false

    private let size = CGSize(width: 300, height: 270)

    init(ctx: DemoContext) {
        self.ctx = ctx
        _hour = State(initialValue: ctx["now"])
    }

    private var day: SunDay { SunDay(dayLength: ctx["day"]) }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                SunArcCard(
                    hour: hour,
                    now: ctx["now"],
                    day: day,
                    stars: ctx.bool("stars"),
                    grabbed: grabbed,
                    zh: ctx.language == .zh,
                    preview: ctx.isPreview,
                    still: ctx.isStill
                )
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($touching) { _, state, _ in state = true }
                        .onChanged { value in
                            script?.cancel()
                            scripting = false
                            if !grabbed { grabHour = hour }
                            drag(toHour: grabHour + Double(value.translation.width / size.width) * 24)
                        }
                        .onEnded { _ in release() }
                )
                .onChange(of: touching) { _, isTouching in
                    if !isTouching && !scripting { release() }
                }
                Spacer(minLength: 0)
                DemoHint(text: L("Drag the sun through the day", "拖动太阳，走过一整天"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: ctx["now"]) { _, value in
            if !grabbed { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { hour = value } }
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 6.2, delay: 0.7) { runScript() }
    }

    // MARK: Actions (shared by the finger and the scripted drag)

    private func drag(toHour target: Double) {
        let next = target.clamped(to: 0.2...23.8)
        if !grabbed {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { grabbed = true }
            buzz(.light)
        }
        // A tick when the sun crosses the horizon.
        if (day.elevation(hour) >= 0) != (day.elevation(next) >= 0) { buzz(.medium) }
        hour = next
    }

    private func release() {
        guard grabbed else { return }
        withAnimation(.spring(response: ctx["snap"], dampingFraction: 0.72)) {
            hour = ctx["now"]
            grabbed = false
        }
    }

    private func buzz(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard !ctx.isPreview, !scripting else { return }
        Haptics.tap(style)
    }

    private func runScript() {
        script?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            let start = ctx["now"]
            let legs: [(Double, Double)] = [(22.6, 1.5), (4.6, 1.9), (9.5, 0.9)]
            var from = start
            for (target, duration) in legs {
                let origin = from
                guard await studioScript(duration, { t in drag(toHour: origin + (target - origin) * studioEase(t)) }) else { return }
                from = target
            }
            guard await studioPause(0.25) else { return }
            release()
        }
    }
}

// MARK: - Card

private struct SunArcCard: View, Animatable {
    var hour: Double
    let now: Double
    let day: SunDay
    let stars: Bool
    let grabbed: Bool
    let zh: Bool
    let preview: Bool
    let still: Bool

    var animatableData: Double {
        get { hour }
        set { hour = newValue }
    }

    private let width: CGFloat = 300
    private let height: CGFloat = 270
    private let horizon: CGFloat = 186
    private let amplitude: CGFloat = 72

    var body: some View {
        let e = day.elevation(hour)
        let sun = point(hour)
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: SunSky.colors(e), startPoint: .top, endPoint: .bottom)
            if stars {
                SunStars(amount: SunSky.smooth(0.02, -0.32, e), preview: preview, still: still)
            }
            horizonGlow(e: e, x: sun.x)
            ground
            curve
            markers
            sunView(e: e)
                .position(sun)
            readout(e: e)
                .padding(18)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
    }

    private func point(_ h: Double) -> CGPoint {
        CGPoint(x: width * CGFloat(h / 24), y: horizon - amplitude * CGFloat(day.elevation(h)))
    }

    private var curvePath: Path {
        var path = Path()
        let steps = 96
        for i in 0...steps {
            let p = point(Double(i) / Double(steps) * 24)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    private var curve: some View {
        let path = curvePath
        return ZStack {
            path
                .stroke(Color.white.opacity(0.32), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 5]))
                .mask(alignment: .bottom) { Rectangle().frame(height: height - horizon) }
            path
                .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .mask(alignment: .top) { Rectangle().frame(height: horizon) }
        }
    }

    private var ground: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(height: 1)
            Rectangle()
                .fill(LinearGradient(colors: [Color.black.opacity(0.34), Color.black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .frame(height: height - horizon)
        }
    }

    private func horizonGlow(e: Double, x: CGFloat) -> some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color(hex: 0xFFB45C).opacity(0.85), .clear], center: .center, startRadius: 0, endRadius: 90))
            .frame(width: 220, height: 90)
            .position(x: x, y: horizon)
            .opacity(max(0, 1 - abs(e) / 0.3))
            .blendMode(.plusLighter)
    }

    /// Sunrise / sunset times above the horizon (outside the arc) and the "now" ring.
    private var markers: some View {
        let nowPoint = point(now)
        return ZStack {
            Text(verbatim: "↑ " + Self.clock(day.sunrise))
                .position(x: width * CGFloat(day.sunrise / 24) - 30, y: horizon - 11)
            Text(verbatim: Self.clock(day.sunset) + " ↓")
                .position(x: width * CGFloat(day.sunset / 24) + 30, y: horizon - 11)
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                .background(Circle().fill(Color.black.opacity(0.25)))
                .frame(width: 11, height: 11)
                .position(nowPoint)
                .opacity(min(1, abs(hour - now) / 0.6))
        }
        .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(Color.white.opacity(0.7))
    }

    private func sunView(e: Double) -> some View {
        let lit = SunSky.smooth(-0.08, 0.06, e)
        let core = studioMix(0xFF8A3D, 0xFFF8E0, e / 0.45)
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [core.opacity(0.6), core.opacity(0)], center: .center, startRadius: 4, endRadius: 56))
                .frame(width: 124, height: 124)
                .opacity(lit)
                .blendMode(.plusLighter)
            // Below the horizon: a dim outlined disc.
            Circle()
                .fill(Color(hex: 0x1B2148))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5))
                .frame(width: 18, height: 18)
                .opacity(1 - lit)
            Circle()
                .fill(RadialGradient(colors: [.white, core], center: .center, startRadius: 0, endRadius: 12))
                .frame(width: 22, height: 22)
                .shadow(color: core.opacity(0.9), radius: 10)
                .opacity(lit)
            Circle()
                .strokeBorder(Color.white.opacity(0.75), lineWidth: 1.5)
                .frame(width: 40, height: 40)
                .scaleEffect(grabbed ? 1 : 0.5)
                .opacity(grabbed ? 1 : 0)
        }
        .scaleEffect(grabbed ? 1.18 : 1)
    }

    private func readout(e: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: e >= 0 ? "sun.max.fill" : "moon.stars.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(verbatim: zh ? "日出日落 · 上海" : "Sun · Shanghai")
            }
            .signatureEyebrow()
            .foregroundStyle(Color.white.opacity(0.75))
            Text(verbatim: Self.clock(hour))
                .font(Signature.number(46))
                .foregroundStyle(Color.white)
            Text(verbatim: caption)
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.78))
        }
        .shadow(color: .black.opacity(0.4), radius: 5, y: 1)
    }

    private var caption: String {
        if hour < day.sunrise {
            return zh ? "距日出 " + Self.span(day.sunrise - hour, zh: true) : "Sunrise in " + Self.span(day.sunrise - hour, zh: false)
        }
        if hour < day.sunset {
            return zh ? "距日落 " + Self.span(day.sunset - hour, zh: true) : "Sunset in " + Self.span(day.sunset - hour, zh: false)
        }
        return zh ? "日落后 " + Self.span(hour - day.sunset, zh: true) : Self.span(hour - day.sunset, zh: false) + " after sunset"
    }

    private static func clock(_ hour: Double) -> String {
        let minutes = Int((hour * 60).rounded()).clamped(to: 0...(24 * 60 - 1))
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private static func span(_ hours: Double, zh: Bool) -> String {
        let minutes = max(0, Int((hours * 60).rounded()))
        return zh
            ? String(format: "%d 小时 %02d 分", minutes / 60, minutes % 60)
            : String(format: "%d h %02d m", minutes / 60, minutes % 60)
    }
}

// MARK: - Sky

private enum SunSky {
    /// Elevation keyframes: night, twilight, golden hour, day (top / middle / bottom of the gradient).
    private static let keys: [(e: Double, top: UInt32, mid: UInt32, bottom: UInt32)] = [
        (-0.32, 0x040716, 0x0B1230, 0x18204C),
        (0.0, 0x232759, 0x8E4E7E, 0xF39B5B),
        (0.24, 0x2C5FAE, 0x86A6D4, 0xF6C98E),
        (0.6, 0x1867CC, 0x4A98E6, 0x9CCFF5),
    ]

    static func colors(_ e: Double) -> [Color] {
        guard let first = keys.first, let last = keys.last else { return [.black] }
        if e <= first.e { return [Color(hex: first.top), Color(hex: first.mid), Color(hex: first.bottom)] }
        if e >= last.e { return [Color(hex: last.top), Color(hex: last.mid), Color(hex: last.bottom)] }
        for index in 1..<keys.count where e <= keys[index].e {
            let a = keys[index - 1]
            let b = keys[index]
            let t = (e - a.e) / (b.e - a.e)
            return [studioMix(a.top, b.top, t), studioMix(a.mid, b.mid, t), studioMix(a.bottom, b.bottom, t)]
        }
        return [Color(hex: last.top), Color(hex: last.mid), Color(hex: last.bottom)]
    }

    /// Smoothstep from `from` (0) to `to` (1); works in either direction.
    static func smooth(_ from: Double, _ to: Double, _ value: Double) -> Double {
        studioEase((value - from) / (to - from))
    }
}

private struct SunStars: View {
    let amount: Double
    let preview: Bool
    let still: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: preview ? 1.0 / 15.0 : 1.0 / 30.0, paused: still || amount < 0.01)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                guard amount > 0.01 else { return }
                for index in 0..<36 {
                    let seed = Double(index)
                    let x = sportHash(seed * 1.7 + 0.3) * Double(size.width)
                    let y = sportHash(seed * 3.1 + 5.2) * 168
                    let radius = 0.5 + sportHash(seed * 7.7) * 1.0
                    let twinkle = 0.55 + 0.45 * sin(t * (0.9 + sportHash(seed * 2.3) * 2.2) + seed)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(amount * twinkle)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
