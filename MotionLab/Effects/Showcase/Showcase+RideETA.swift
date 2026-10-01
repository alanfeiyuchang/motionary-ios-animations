import SwiftUI

extension Effect {
    static let showcaseRideETA = Effect(
        id: "showcase.ride-eta",
        category: .showcase,
        interaction: .tap,
        name: L("Ride Arriving", "网约车到达"),
        summary: L(
            "A car threads the street grid toward your pin while the ETA rolls down; on arrival the driver card slides up from the map's edge.",
            "小车沿街道网格驶向你的上车点，预计时间逐分钟滚落；到达时司机卡片从地图底边滑上来。"
        ),
        prompt: L(
            "A dark ride-hailing widget: a stylised city map of rounded blocks with a park and a pond, an orange route along the streets to a pulsing pickup pin, an ETA chip in the corner and the pickup address below. Tapping requests the ride: a small top-down car with headlights drives the route in 3.4 s on an ease-in-out curve (0.4, 0, 0.2, 1), rotating through each rounded corner along the path's tangent, while the route ahead of it shortens and the ETA rolls down a minute at a time. On arrival the car pops to 125% and settles, the pin flips to a lime check with a ripple, the chip switches to Here, and the driver card slides up 84 pt from under the map's bottom edge on a spring (response 0.5 s, damping 0.74); its avatar and round call button scale in 0.1 s later. Smooth, reassuring.",
            "深色网约车组件：由圆角街区、公园和池塘组成的风格化地图，橙色路线沿街道通向脉动的上车点，角落是预计时间，下方是上车地址。点击即叫车：亮着车灯的俯视小车用 3.4 秒按缓入缓出曲线（0.4, 0, 0.2, 1）驶完全程，过弯时顺着路径切线转向，车前路线不断缩短，预计时间逐分钟滚落。到达时小车弹到 125% 再落定，上车点翻成青柠色对勾并泛开涟漪，时间标签换成“已到达”，司机卡片以弹簧（响应 0.5 秒、阻尼 0.74）从地图底边下方上滑 84pt；头像与通话按钮延迟 0.1 秒缩放出现。顺滑安心。"
        ),
        implementation: L(
            "The route is one Path built with tangent arcs; an Animatable layer takes the progress, strokes trimmedPath(from: progress, to: 1) and places the car at the trimmed path's currentPoint, with the heading from two nearby samples. A timing-curve animation drives the progress, a Task rolls the ETA and fires the arrival, and the driver card is an offset animated by a spring inside the map's clip shape.",
            "路线是一条用切线圆弧拼成的 Path；Animatable 图层接收进度，描出 trimmedPath(from: 进度, to: 1)，并把小车放在裁剪后路径的 currentPoint，朝向由相邻两个采样点求得。timingCurve 动画推进进度，一个 Task 滚动预计时间并触发到达，司机卡片则是在地图裁剪形状内由弹簧驱动的 offset。"
        ),
        apis: ["Path.trimmedPath", "Animatable", "Animation.timingCurve", "Canvas", "contentTransition(.numericText)", "keyframeAnimator"],
        tags: ["ride", "taxi", "map", "eta", "driver", "打车", "网约车", "地图", "预计到达", "司机"],
        params: [
            .slider("trip", L("Trip duration", "行程时长"), 2...6, default: 3.4, decimals: 1, unit: "s"),
            .slider("response", L("Card response", "卡片响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Card damping", "卡片阻尼"), 0.5...1.0, default: 0.74),
        ]
    ) { ctx in
        RideETADemo(ctx: ctx)
    }
}

private enum RideMap {
    static let size = CGSize(width: 258, height: 178)
    static let columns: [CGFloat] = [34, 100, 168, 226]
    static let rows: [CGFloat] = [30, 80, 130, 172]
    static let start = CGPoint(x: 34, y: 160)
    static let pickup = CGPoint(x: 222, y: 30)

    static let route: Path = {
        var path = Path()
        path.move(to: start)
        path.addArc(tangent1End: CGPoint(x: 34, y: 80), tangent2End: CGPoint(x: 168, y: 80), radius: 10)
        path.addArc(tangent1End: CGPoint(x: 168, y: 80), tangent2End: CGPoint(x: 168, y: 30), radius: 10)
        path.addArc(tangent1End: CGPoint(x: 168, y: 30), tangent2End: pickup, radius: 10)
        path.addLine(to: pickup)
        return path
    }()

    static func point(_ progress: Double) -> CGPoint {
        let p = min(max(progress, 0), 1)
        guard p > 0.0005 else { return start }
        return route.trimmedPath(from: 0, to: p).currentPoint ?? start
    }

    /// Heading in radians (0 = pointing right).
    static func heading(_ progress: Double) -> Double {
        let a = point(max(progress - 0.012, 0))
        let b = point(min(progress + 0.012, 1))
        return atan2(Double(b.y - a.y), Double(b.x - a.x))
    }
}

private struct RideETADemo: View {
    let ctx: DemoContext
    @State private var progress: Double
    @State private var eta: Int
    @State private var arrived: Bool
    @State private var arrivals = 0
    @State private var run: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 1 : 0)
        _eta = State(initialValue: ctx.isStill ? 0 : 5)
        _arrived = State(initialValue: ctx.isStill)
    }

    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        StudioScene(hint: L("Tap to request the ride", "点击叫车"), ctx: ctx) {
            card
                .sportCardTap { request(user: true) }
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: ctx["trip"] + 3.4, delay: 0.7) { request(user: false) }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            SportEyebrowRow(title: zh ? "行程 · 快车" : "Ride · Standard", symbol: "car.fill", trailing: arrived ? (zh ? "司机已到达" : "Arrived") : (zh ? "司机正在赶来" : "On the way"))
            map
            pickupRow
        }
        .padding(16)
        .frame(width: 290)
        .signatureCard()
    }

    private var map: some View {
        ZStack(alignment: .topLeading) {
            RideMapCanvas()
            RideRouteLayer(progress: progress, arrived: arrived, arrivals: arrivals, preview: ctx.isPreview)
            etaChip
                .padding(8)
        }
        .frame(width: RideMap.size.width, height: RideMap.size.height)
        .overlay(alignment: .bottom) {
            RideDriverCard(shown: arrived, zh: zh)
                .padding(8)
                .offset(y: arrived ? 0 : 84)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var etaChip: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: zh ? "预计到达" : "Arriving in")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Signature.textSecondary)
            ZStack(alignment: .leading) {
                if arrived {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(verbatim: zh ? "已到达" : "Here")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Signature.lime)
                    .transition(.scale(scale: 0.7, anchor: .leading).combined(with: .opacity))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(eta, format: .number)
                            .font(Signature.number(24))
                            .foregroundStyle(Color.white)
                            .contentTransition(.numericText(value: Double(eta)))
                        Text(verbatim: zh ? "分钟" : "min")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Signature.textSecondary)
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 28)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: 0x0E0F12).opacity(0.86)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var pickupRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.wave")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Signature.ink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Signature.accentGradient))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: zh ? "上车点" : "Pickup")
                    .signatureEyebrow()
                Text(verbatim: zh ? "松林路 28 号 · 东门" : "28 Pine Street · East gate")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(verbatim: String(format: "%.1f km", Double(eta) * 0.4))
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Signature.textSecondary)
                .contentTransition(.numericText(value: Double(eta)))
        }
        .frame(height: 30)
    }

    // MARK: Actions

    private func request(user: Bool) {
        run?.cancel()
        if user { Haptics.tap(.light) }
        let rewind = arrived || progress > 0
        if rewind {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                arrived = false
                progress = 0
                eta = 5
            }
        }
        let trip = ctx["trip"]
        run = Task { @MainActor in
            if rewind {
                guard await studioPause(0.6) else { return }
            }
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: trip)) { progress = 1 }
            for step in 1...4 {
                guard await studioPause(trip * 0.94 / 5) else { return }
                withAnimation(.snappy(duration: 0.2)) { eta = 5 - step }
            }
            guard await studioPause(trip * (0.94 / 5 + 0.06)) else { return }
            arrivals += 1
            withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
                arrived = true
                eta = 0
            }
            if user && !ctx.isPreview { Haptics.success() }
        }
    }
}

// MARK: - Map

private struct RideMapCanvas: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x16181D)))
            let xs: [CGFloat] = [-20] + RideMap.columns + [size.width + 20]
            let ys: [CGFloat] = [-20] + RideMap.rows + [size.height + 20]
            for column in 0..<(xs.count - 1) {
                for row in 0..<(ys.count - 1) {
                    let block = CGRect(x: xs[column] + 7, y: ys[row] + 7, width: xs[column + 1] - xs[column] - 14, height: ys[row + 1] - ys[row] - 14)
                    guard block.width > 0, block.height > 0 else { continue }
                    let park = column == 2 && row == 2
                    let pond = column == 3 && row == 3
                    let color = park ? Color(hex: 0x1E3B2B) : (pond ? Color(hex: 0x1A3350) : Color(hex: 0x262930))
                    context.fill(Path(roundedRect: block, cornerRadius: 6, style: .continuous), with: .color(color))
                    if park {
                        for tree in 0..<7 {
                            let seed = Double(tree)
                            let center = CGPoint(x: block.minX + block.width * CGFloat(0.12 + sportHash(seed * 3.1) * 0.76), y: block.minY + block.height * CGFloat(0.18 + sportHash(seed * 7.7) * 0.64))
                            context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(Color(hex: 0x2F6B45)))
                        }
                    } else if !pond {
                        // A few roof outlines so the blocks read as buildings.
                        let roof = block.insetBy(dx: block.width * 0.18, dy: block.height * 0.22)
                        context.stroke(Path(roundedRect: roof, cornerRadius: 3), with: .color(Color.white.opacity(0.04)), lineWidth: 1)
                    }
                }
            }
        }
    }
}

private struct RideRouteLayer: View, Animatable {
    var progress: Double
    let arrived: Bool
    let arrivals: Int
    let preview: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = min(max(progress, 0), 1)
        let car = RideMap.point(p)
        ZStack(alignment: .topLeading) {
            RideMap.route
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            RideMap.route
                .trimmedPath(from: min(p, 0.999), to: 1)
                .stroke(Signature.accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .shadow(color: Signature.accent.opacity(0.6), radius: 6)
                .opacity(arrived ? 0 : 1)
            RidePin(arrived: arrived, preview: preview)
                .position(RideMap.pickup)
            RideCar()
                .rotationEffect(.radians(RideMap.heading(p) + .pi / 2))
                .keyframeAnimator(initialValue: 1.0, trigger: arrivals) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(1.25, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.5, spring: .init(response: 0.3, dampingRatio: 0.5))
                    }
                }
                .position(x: car.x - (arrived ? 27 : 0), y: car.y)
        }
        .frame(width: RideMap.size.width, height: RideMap.size.height)
    }
}

/// Top-down car pointing up, with a pool of headlight in front.
private struct RideCar: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF1C1).opacity(0.75), .clear], center: .center, startRadius: 0, endRadius: 13))
                .frame(width: 24, height: 22)
                .offset(y: -20)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(hex: 0xD9DCE3)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 14, height: 25)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: 0x23262C))
                .frame(width: 10, height: 6)
                .offset(y: -4.5)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(hex: 0x23262C))
                .frame(width: 10, height: 4)
                .offset(y: 6.5)
            HStack(spacing: 6) {
                Capsule().fill(Color(hex: 0xFFE9A8)).frame(width: 3, height: 2)
                Capsule().fill(Color(hex: 0xFFE9A8)).frame(width: 3, height: 2)
            }
            .offset(y: -11.5)
        }
        .frame(width: 30, height: 30)
    }
}

private struct RidePin: View {
    let arrived: Bool
    let preview: Bool
    @State private var ripples = 0
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        let color = arrived ? Signature.lime : Signature.accent
        ZStack {
            if !arrived && !isStill {
                SportLiveDot(color: Signature.accent, size: 14, period: 1.5, preview: preview)
                    .transition(.opacity)
            }
            Circle()
                .stroke(Signature.lime, lineWidth: 2)
                .frame(width: 22, height: 22)
                .keyframeAnimator(initialValue: 0.0, trigger: ripples) { content, p in
                    content
                        .scaleEffect(1 + 1.8 * p)
                        .opacity(p > 0 && p < 1 ? 1 - p : 0)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(0.0)
                        CubicKeyframe(0.7, duration: 0.3)
                        CubicKeyframe(1.0, duration: 0.4)
                    }
                }
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                .shadow(color: color.opacity(0.7), radius: 6)
            Image(systemName: arrived ? "checkmark" : "figure.wave")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Signature.ink)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 44, height: 44)
        .onChange(of: arrived) { _, here in
            if here && !isStill { ripples += 1 }
        }
    }
}

private struct RideDriverCard: View {
    let shown: Bool
    let zh: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFFB45C), Color(hex: 0xE0559A)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(verbatim: "LM")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5))
                .scaleEffect(shown ? 1 : 0.4)
                .animation(.spring(response: 0.4, dampingFraction: 0.55).delay(shown ? 0.1 : 0), value: shown)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(verbatim: zh ? "林师傅" : "Leo M.")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .fixedSize()
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Signature.accent)
                    Text(verbatim: "4.9")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Signature.textSecondary)
                        .fixedSize()
                }
                HStack(spacing: 6) {
                    Text(verbatim: zh ? "白色轿车" : "White sedan")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Signature.textSecondary)
                        .fixedSize()
                    Text(verbatim: "7KL·284")
                        .font(.system(size: 10, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.white)
                        .fixedSize()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.14)))
                }
            }
            Spacer(minLength: 0)
            ForEach(["phone.fill"], id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(symbol == "phone.fill" ? Signature.ink : Color.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(symbol == "phone.fill" ? AnyShapeStyle(Signature.lime) : AnyShapeStyle(Color.white.opacity(0.12))))
                    .scaleEffect(shown ? 1 : 0.4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.55).delay(shown ? (symbol == "phone.fill" ? 0.16 : 0.1) : 0), value: shown)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2C2D33), Color(hex: 0x1D1E22)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 12, y: -2)
    }
}
