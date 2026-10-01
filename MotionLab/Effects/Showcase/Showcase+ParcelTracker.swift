import SwiftUI

extension Effect {
    static let showcaseParcelTracker = Effect(
        id: "showcase.parcel-tracker",
        category: .showcase,
        interaction: .tap,
        name: L("Parcel Route Tracker", "包裹路线追踪"),
        summary: L(
            "A van glides along a winding road from stop to stop; each stage lights with a ripple and the last one bursts a check.",
            "小货车沿弯曲的道路一站站滑行；每到一站亮起并泛开涟漪，终点迸出对勾。"
        ),
        prompt: L(
            "A dark delivery-tracking widget: a status title with a detail line, an ETA in minutes, and a winding S-shaped road with four stops (pickup, transit, courier, home). Tapping sends a white van badge ringed in orange to the next stop over 1.1 s on an ease-in-out curve (0.45, 0, 0.2, 1); it follows the road's tangent, tilting through the bends, while the driven part of the road fills with the orange gradient behind it and the ETA rolls down minute by minute. On arrival the van pops to 118% and settles on a spring, the stop lights up and a ring ripples out to 2.8× while fading over 0.7 s, and the title pushes up to the new status. At the last stop the van shrinks into the house, which turns lime as a check draws in 0.35 s and 14 confetti flecks burst outward. Reassuring.",
            "深色快递追踪组件：状态标题与说明、以分钟计的预计到达时间，以及一条带四个站点（揽收、转运、派送、到家）的 S 形弯路。点击后，白底橙边的货车徽标用 1.1 秒按缓入缓出曲线（0.45, 0, 0.2, 1）驶向下一站；车身顺着道路切线在弯道中倾斜，驶过的路段在身后填上橙色渐变，预计时间逐分钟滚落。到站时货车弹到 118% 再以弹簧落定，站点点亮，一圈涟漪扩到 2.8 倍并在 0.7 秒内淡出，标题向上推入新状态。到终点时货车缩进小房子，房子变青柠色，对勾用 0.35 秒画出，14 片彩屑向外迸开。安心。"
        ),
        implementation: L(
            "The road is three cubic Béziers evaluated by hand; an Animatable view receives the fractional stage, draws the driven polyline and places the van with the curve's derivative as its rotation. A timing-curve animation moves the stage value while a Task rolls the ETA with numericText and fires the arrival: ripple (scale + opacity), a keyframe pop, and a trim-drawn check with offset-animated confetti at the end.",
            "道路由三段手工求值的三次贝塞尔组成；Animatable 视图接收带小数的阶段值，绘制已行驶的折线，并以曲线导数作为货车的旋转角。timingCurve 动画推进阶段值，同时一个 Task 用 numericText 滚动预计时间并触发到站：涟漪（缩放加透明度）、关键帧弹跳，以及终点用 trim 画出的对勾和以 offset 动画迸开的彩屑。"
        ),
        apis: ["Animatable", "Animation.timingCurve", "Path", "keyframeAnimator", "contentTransition(.numericText)", "trim(from:to:)"],
        tags: ["delivery", "parcel", "tracking", "route", "courier", "快递", "包裹", "物流", "追踪", "路线"],
        params: [
            .slider("leg", L("Leg duration", "每段用时"), 0.5...2.0, default: 1.1, unit: "s"),
            .slider("ripple", L("Ripple scale", "涟漪倍数"), 1.5...4.0, default: 2.8, decimals: 1, unit: "×"),
            .slider("confetti", L("Confetti flecks", "彩屑数量"), 0...24, default: 14, step: 1, decimals: 0),
        ]
    ) { ctx in
        ParcelTrackerDemo(ctx: ctx)
    }
}

/// The road: three cubic segments joined at the four stops (level tangents at every stop).
private enum ParcelRoad {
    static let size = CGSize(width: 264, height: 112)
    static let stops: [CGPoint] = [CGPoint(x: 18, y: 70), CGPoint(x: 94, y: 30), CGPoint(x: 172, y: 66), CGPoint(x: 246, y: 28)]

    private static func controls(_ segment: Int) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let a = stops[segment]
        let b = stops[segment + 1]
        let reach = (b.x - a.x) * 0.5
        return (a, CGPoint(x: a.x + reach, y: a.y), CGPoint(x: b.x - reach, y: b.y), b)
    }

    static func point(_ travel: Double) -> CGPoint {
        let clamped = min(max(travel, 0), Double(stops.count - 1))
        let segment = min(Int(clamped), stops.count - 2)
        let u = CGFloat(clamped - Double(segment))
        let (p0, p1, p2, p3) = controls(segment)
        let v = 1 - u
        let x = v * v * v * p0.x + 3 * v * v * u * p1.x + 3 * v * u * u * p2.x + u * u * u * p3.x
        let y = v * v * v * p0.y + 3 * v * v * u * p1.y + 3 * v * u * u * p2.y + u * u * u * p3.y
        return CGPoint(x: x, y: y)
    }

    /// Heading in degrees (0 = level, positive = nose down).
    static func heading(_ travel: Double) -> Double {
        let a = point(travel - 0.02)
        let b = point(travel + 0.02)
        return atan2(Double(b.y - a.y), Double(b.x - a.x)) * 180 / .pi
    }

    static func path(to travel: Double) -> Path {
        var path = Path()
        let steps = max(Int(travel * 28), 1)
        for index in 0...steps {
            let p = point(travel * Double(index) / Double(steps))
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
}

private struct ParcelStage {
    let title: LocalizedText
    let detail: LocalizedText
    let label: LocalizedText
    let symbol: String
    let eta: Int

    static let all: [ParcelStage] = [
        ParcelStage(title: L("Picked up", "已揽收"), detail: L("Shenzhen Bao'an hub", "深圳宝安集散中心"), label: L("Pickup", "揽收"), symbol: "shippingbox.fill", eta: 28),
        ParcelStage(title: L("In transit", "运输中"), detail: L("Arrived at Hangzhou sorting centre", "已到达杭州转运中心"), label: L("Transit", "转运"), symbol: "building.2.fill", eta: 17),
        ParcelStage(title: L("Out for delivery", "派送中"), detail: L("Your courier is 6 minutes away", "快递员距你还有 6 分钟"), label: L("Courier", "派送"), symbol: "figure.walk", eta: 6),
        ParcelStage(title: L("Delivered", "已送达"), detail: L("Left at the front desk", "已由前台代收"), label: L("Home", "到家"), symbol: "house.fill", eta: 0),
    ]
}

private struct ParcelTrackerDemo: View {
    let ctx: DemoContext
    @State private var stage: Int
    @State private var travel: Double
    @State private var lit: Int
    @State private var eta: Int
    @State private var arrivals = 0
    @State private var delivered = false
    @State private var run: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        let start = ctx.isStill ? 2 : 0
        _stage = State(initialValue: start)
        _travel = State(initialValue: Double(start))
        _lit = State(initialValue: start)
        _eta = State(initialValue: ParcelStage.all[start].eta)
    }

    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card
                    .sportCardTap { advance(user: true) }
                Spacer(minLength: 0)
                DemoHint(text: L("Tap to send the van to the next stop", "点击，让货车驶向下一站"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: max(ctx["leg"] + 0.9, 1.9), delay: 0.7) { advance(user: false) }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            SportEyebrowRow(title: zh ? "包裹 · SF 2841 0937" : "Parcel · SF 2841 0937", symbol: "shippingbox.fill")
            HStack(alignment: .top) {
                status
                Spacer(minLength: 8)
                etaView
            }
            road
        }
        .padding(18)
        .frame(width: 300)
        .signatureCard()
    }

    private var status: some View {
        let info = ParcelStage.all[lit]
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 3) {
                Text(info.title, ctx.language)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(delivered ? Signature.lime : Color.white)
                Text(info.detail, ctx.language)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .id(lit)
            .transition(.push(from: .bottom))
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
        .clipped()
    }

    private var etaView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(verbatim: zh ? "预计" : "ETA")
                .signatureEyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(eta, format: .number)
                    .font(Signature.number(30))
                    .foregroundStyle(delivered ? Signature.lime : Color.white)
                    .contentTransition(.numericText(value: Double(eta)))
                Text(verbatim: zh ? "分钟" : "min")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
            }
        }
    }

    private var road: some View {
        ZStack(alignment: .topLeading) {
            ParcelRouteLayer(travel: travel, arrivals: arrivals, hidden: delivered)
            ForEach(ParcelStage.all.indices, id: \.self) { index in
                let last = index == ParcelStage.all.count - 1
                ParcelStop(
                    info: ParcelStage.all[index],
                    reached: index <= lit,
                    current: index == lit,
                    done: last && delivered,
                    ripple: ctx.cg("ripple"),
                    confetti: last ? ctx.int("confetti") : 0,
                    language: ctx.language
                )
                .position(ParcelRoad.stops[index])
            }
        }
        .frame(width: ParcelRoad.size.width, height: ParcelRoad.size.height)
    }

    // MARK: Actions

    private func advance(user: Bool) {
        run?.cancel()
        let count = ParcelStage.all.count
        if stage >= count - 1 {
            // Back to the depot: the van rewinds along the road.
            if user { Haptics.tap(.light) }
            stage = 0
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                travel = 0
                lit = 0
                delivered = false
                eta = ParcelStage.all[0].eta
            }
            return
        }
        if user { Haptics.tap(.light) }
        let from = stage
        let target = stage + 1
        let leg = ctx["leg"]
        stage = target
        // A tap during a leg finishes the previous arrival at once.
        if lit != from {
            withAnimation(.smooth(duration: 0.2)) { lit = from }
        }
        withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: leg)) { travel = Double(target) }
        let startEta = eta
        let endEta = ParcelStage.all[target].eta
        run = Task { @MainActor in
            let steps = max(startEta - endEta, 1)
            for step in 1...steps {
                guard await studioPause(leg * 0.92 / Double(steps)) else { return }
                withAnimation(.snappy(duration: 0.18)) { eta = startEta - step }
            }
            guard await studioPause(leg * 0.08) else { return }
            arrivals += 1
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                lit = target
                eta = endEta
                delivered = target == count - 1
            }
            if user && !ctx.isPreview {
                if target == count - 1 { Haptics.success() } else { Haptics.tap(.medium) }
            }
        }
    }
}

// MARK: - Road + van

private struct ParcelRouteLayer: View, Animatable {
    var travel: Double
    let arrivals: Int
    let hidden: Bool

    var animatableData: Double {
        get { travel }
        set { travel = newValue }
    }

    var body: some View {
        let whole = ParcelRoad.path(to: Double(ParcelRoad.stops.count - 1))
        let driven = ParcelRoad.path(to: max(travel, 0.001))
        let van = ParcelRoad.point(travel)
        ZStack(alignment: .topLeading) {
            whole
                .stroke(Color.white.opacity(0.09), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            whole
                .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 7]))
            driven
                .stroke(Signature.accentGradient, style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                .shadow(color: Signature.accent.opacity(0.55), radius: 8)
            driven
                .stroke(Signature.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 7]))
            Image(systemName: "box.truck.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Signature.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(LinearGradient(colors: [.white, Color(hex: 0xFFD9B0)], startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(Signature.accent, lineWidth: 2))
                .shadow(color: .black.opacity(0.5), radius: 5, y: 3)
                .rotationEffect(.degrees(ParcelRoad.heading(travel)))
                .keyframeAnimator(initialValue: 1.0, trigger: arrivals) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(1.18, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.45, spring: .init(response: 0.3, dampingRatio: 0.5))
                    }
                }
                .scaleEffect(hidden ? 0.3 : 1)
                .opacity(hidden ? 0 : 1)
                .position(van)
                .zIndex(2)
        }
        .frame(width: ParcelRoad.size.width, height: ParcelRoad.size.height)
    }
}

// MARK: - Stop

private struct ParcelStop: View {
    let info: ParcelStage
    let reached: Bool
    let current: Bool
    let done: Bool
    let ripple: CGFloat
    let confetti: Int
    let language: AppLanguage

    /// Bumped on arrival; each bump plays one ripple / one confetti burst from 0 to 1.
    @State private var ripples = 0
    @State private var bursts = 0
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        ZStack {
            if confetti > 0 {
                let count = confetti
                ForEach(0..<confetti, id: \.self) { index in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .keyframeAnimator(initialValue: 0.0, trigger: bursts) { _, p in
                            Self.fleck(index, p, of: count)
                        } keyframes: { _ in
                            KeyframeTrack(\.self) {
                                MoveKeyframe(0.0)
                                CubicKeyframe(0.82, duration: 0.3)
                                CubicKeyframe(1.0, duration: 0.5)
                            }
                        }
                }
            }
            Circle()
                .stroke(done ? Signature.lime : Signature.accent, lineWidth: 2)
                .frame(width: 24, height: 24)
                .keyframeAnimator(initialValue: 0.0, trigger: ripples) { content, p in
                    content
                        .scaleEffect(1 + (ripple - 1) * p)
                        .opacity(p > 0 && p < 1 ? 1 - p : 0)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(0.0)
                        CubicKeyframe(0.7, duration: 0.3)
                        CubicKeyframe(1.0, duration: 0.4)
                    }
                }
            Circle()
                .fill(done ? AnyShapeStyle(Signature.lime) : (reached ? AnyShapeStyle(Signature.cardHigh) : AnyShapeStyle(Signature.card)))
                .frame(width: done ? 30 : 24, height: done ? 30 : 24)
                .overlay(Circle().strokeBorder(reached ? (done ? Signature.lime : Signature.accent) : Color.white.opacity(0.18), lineWidth: 1.5))
                .shadow(color: (done ? Signature.lime : Signature.accent).opacity(reached ? 0.5 : 0), radius: 7)
            Image(systemName: info.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(reached ? Color.white : Color.white.opacity(0.4))
                .opacity(done ? 0 : 1)
            ParcelCheck()
                .trim(from: 0, to: done ? 1 : 0)
                .stroke(Signature.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 13, height: 10)
                .animation(.easeOut(duration: 0.35).delay(done ? 0.12 : 0), value: done)
            Text(info.label, language)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(reached ? Color.white.opacity(0.9) : Signature.textSecondary)
                .fixedSize()
                .offset(y: 27)
        }
        // The van (zIndex 2 in the route layer) passes over stops; the current stop pops slightly.
        .scaleEffect(current && !done ? 1.08 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: reached)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: done)
        .onChange(of: current) { _, isCurrent in
            if isCurrent && !isStill { ripples += 1 }
        }
        .onChange(of: done) { _, isDone in
            if isDone && !isStill { bursts += 1 }
        }
    }

    nonisolated private static func fleck(_ index: Int, _ p: Double, of confetti: Int) -> some View {
        let seed = Double(index)
        let angle = seed / Double(max(confetti, 1)) * 2 * .pi + sportHash(seed) * 0.5
        let reach = 26 + sportHash(seed * 3.7) * 24
        let colors: [Color] = [Signature.lime, Signature.accent, .white, Signature.accentSoft]
        return RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(colors[index % colors.count])
            .frame(width: 4, height: index % 2 == 0 ? 8 : 4)
            .rotationEffect(.degrees(sportHash(seed * 9.1) * 540 * p))
            // Flecks fly out and sag a little, like paper.
            .offset(x: CGFloat(cos(angle) * reach * p), y: CGFloat(sin(angle) * reach * p + 10 * p * p))
            .opacity(p > 0 && p < 1 ? min(1, (1 - p) * 3) : 0)
    }
}

private struct ParcelCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
