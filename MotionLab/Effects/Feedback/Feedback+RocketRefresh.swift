import SwiftUI

// MARK: - Rocket refresh

extension Effect {
    static let feedbackRocketRefresh = Effect(
        id: "feedback.rocket-refresh",
        category: .feedback,
        interaction: .gesture,
        name: L("Rocket Launch Refresh", "火箭发射下拉刷新"),
        summary: L("The pull drags a rocket down against a stretching coil; past the threshold it ignites, and letting go fires it up into a streaming exhaust while the list reloads.", "下拉把火箭向下拉，顶着一根越拉越长的弹簧；越过阈值点火，松手后它带着尾焰冲上去，列表随之刷新。"),
        prompt: L(
            "Pulling the list opens a night-sky strip. A small rocket rides 30 pt above the list's edge, hanging from a coil spring fixed to the top: as the pull grows, the coil's seven turns spread and narrow, and past 55% tension the rocket trembles up to 1.5 pt while a pilot flame flickers at its nozzle. Crossing the 80 pt threshold ignites it with a rigid haptic. On release the coil snaps back on a bouncy spring (response 0.35 s, damping 0.4) and the rocket leaps to the top of the 68 pt hold area (response 0.4 s, damping 0.6) as a launch puff spreads along the list's edge. While loading, 24 exhaust puffs stream down, cooling from amber to grey as they swell and fade, and stars streak past. Then the rocket accelerates off the top in 0.28 s, a new row slides in and the list springs home.",
            "下拉露出一条夜空。小火箭悬在列表边缘上方 30 pt 处，挂在固定于顶部的螺旋弹簧上：拉得越多，弹簧的七圈越被拉开、变窄；张力超过 55% 后火箭开始颤抖（最多 1.5 pt），喷口闪出引火。越过 80 pt 阈值即点火，伴随硬朗触感。松手后弹簧以弹跳弹簧（响应 0.35 秒、阻尼 0.4）缩回，火箭跃到 68 pt 停留区上部（响应 0.4 秒、阻尼 0.6），发射烟团沿列表边缘散开。加载期间 24 团尾气向下喷流，由琥珀色冷却成灰色，星星向下划过。结束时火箭 0.28 秒内加速冲出顶部，新条目滑入，列表弹回。"
        ),
        implementation: L(
            "The coil is a Shape with an animatable length; the rocket's height is derived from the pull while dragging and from a spring-animated state while refreshing. Shake, flame flicker, exhaust and stars are stateless functions of a TimelineView clock drawn in a Canvas. The pull comes from a downward-only UIPanGestureRecognizer that the page's scroll waits for.",
            "弹簧是长度可动画的 Shape；火箭高度在拖动时由下拉量推导，在刷新时由弹簧动画的状态决定。颤抖、火焰闪烁、尾气与星星都是 TimelineView 时钟的无状态函数，在 Canvas 中绘制。下拉距离来自只接受向下拖动的 UIPanGestureRecognizer，页面滚动会等它失败。"
        ),
        apis: ["Canvas", "TimelineView(.animation(minimumInterval:paused:))", "Shape", "UIGestureRecognizerRepresentable", "UIPanGestureRecognizer", "spring(response:dampingFraction:)"],
        tags: ["pull to refresh", "rocket", "launch", "particles", "spring", "下拉刷新", "火箭", "发射", "粒子", "弹簧"],
        params: [
            .slider("duration", L("Refresh time", "刷新时长"), 0.6...3.0, default: 1.6, decimals: 1, unit: "s"),
            .slider("exhaust", L("Exhaust puffs", "尾气数量"), 8...40, default: 24, step: 1, decimals: 0),
            .slider("shake", L("Charge shake", "蓄力颤抖"), 0...4, default: 1.5, decimals: 1, unit: "pt"),
        ]
    ) { ctx in
        RocketRefreshHost(ctx: ctx)
    }
}

// MARK: - Host

private struct RocketRefreshItem {
    let symbol: String
    let tint: Color
    let title: LocalizedText
    let detail: LocalizedText
}

private enum RocketRefreshData {
    static let items: [RocketRefreshItem] = [
        RocketRefreshItem(symbol: "moon.stars.fill", tint: Palette.indigo, title: L("Lunar flyby tonight", "今晚近月飞越"), detail: L("Closest approach 21:14", "最近点 21:14")),
        RocketRefreshItem(symbol: "antenna.radiowaves.left.and.right", tint: Palette.mint, title: L("Signal acquired", "已捕获信号"), detail: L("Ground station 3 · strong", "3 号地面站 · 信号强")),
        RocketRefreshItem(symbol: "fuelpump.fill", tint: Palette.coral, title: L("Fuelling complete", "燃料加注完成"), detail: L("Stage 2 · 100%", "二级 · 100%")),
        RocketRefreshItem(symbol: "cloud.sun.fill", tint: Palette.amber, title: L("Weather is go", "天气条件允许"), detail: L("Wind 6 kt · clear", "风速 6 节 · 晴")),
        RocketRefreshItem(symbol: "checklist", tint: Palette.sky, title: L("Checklist signed off", "检查单已签署"), detail: L("42 of 42 items", "42 / 42 项")),
        RocketRefreshItem(symbol: "person.3.fill", tint: Palette.violet, title: L("Crew on board", "乘组已登舱"), detail: L("Hatch closed", "舱门已关闭")),
    ]
}

/// A list with a pull area on top (see `FeedbackRefreshList` for the gesture).
private struct RocketRefreshHost: View {
    let ctx: DemoContext

    @State private var fingerPull: CGFloat = 0
    /// Extra shift of the rows: the scripted pull of previews and the hold height while refreshing.
    @State private var shift: CGFloat
    @State private var refreshing = false
    /// The rocket is flying off the top at the end of a refresh.
    @State private var leaving = false
    @State private var launchTime = Date.distantPast
    @State private var items: [Int] = [3, 2, 1, 0]
    @State private var nextItem = 4
    @State private var token = 0
    @State private var userDriven = false

    private static let threshold: CGFloat = 80
    private static let holdHeight: CGFloat = 68

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the coil stretched, just short of the threshold.
        _shift = State(initialValue: ctx.isStill ? Self.threshold * 0.9 : 0)
    }

    private var pull: CGFloat { fingerPull + shift }
    private var live: Bool { !ctx.isPreview && !ctx.isStill }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                RocketIndicator(
                    pull: pull,
                    threshold: Self.threshold,
                    holdHeight: Self.holdHeight,
                    refreshing: refreshing,
                    leaving: leaving,
                    launchTime: launchTime,
                    exhaust: max(ctx.int("exhaust"), 1),
                    shake: ctx.cg("shake"),
                    preview: ctx.isPreview,
                    buzz: userDriven && live
                )
                .frame(width: 300, height: max(pull, 1), alignment: .top)
                .clipped()
                FeedbackRefreshList(live: live, hold: shift, onPull: pullChanged, onRelease: release) {
                    list
                }
            }
            .frame(width: 300, height: 260, alignment: .top)
            .background(Color(hex: 0x0B1030))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .demoCard(cornerRadius: 22)
            DemoHint(text: L("Pull the list down", "向下拖动列表"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["duration"] + 3.6, delay: 0.6) { simulate() }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                row(RocketRefreshData.items[item % RocketRefreshData.items.count])
                    .transition(
                        AnyTransition.asymmetric(
                            insertion: AnyTransition.move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
            Spacer(minLength: 0)
        }
        .frame(width: 300, height: 260, alignment: .top)
        .background(Palette.elevated)
    }

    private func row(_ item: RocketRefreshItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title, ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.detail, ctx.language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 62)
        }
    }

    private func pullChanged(_ value: CGFloat, byFinger: Bool) {
        fingerPull = value
        if byFinger { userDriven = true }
    }

    /// Finger lifted, or the scripted pull ended: launch if past the threshold.
    private func release() {
        guard !refreshing else { return }
        guard pull >= Self.threshold else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { shift = 0 }
            return
        }
        launchTime = Date()
        leaving = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            refreshing = true
            shift = Self.holdHeight
        }
        let wait: Double = ctx["duration"]
        let buzz: Bool = live && userDriven
        if buzz { Haptics.tap(.heavy) }
        token += 1
        let current = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            guard token == current else { return }
            withAnimation(.easeIn(duration: 0.28)) { leaving = true }
            try? await Task.sleep(for: .seconds(0.24))
            guard token == current else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                items.insert(nextItem, at: 0)
                if items.count > 4 { items.removeLast() }
                shift = 0
                refreshing = false
            }
            nextItem += 1
            if buzz { Haptics.success() }
            // Once the strip has closed, put the rocket back on its coil for the next pull.
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            leaving = false
        }
    }

    private func simulate() {
        guard !refreshing else { return }
        userDriven = false
        token += 1
        let current = token
        withAnimation(.easeOut(duration: 0.6)) { shift = Self.threshold * 0.6 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            guard token == current, !refreshing else { return }
            // Linger just under the threshold so the trembling reads, then pull through.
            withAnimation(.easeOut(duration: 0.5)) { shift = Self.threshold - 5 }
            try? await Task.sleep(for: .seconds(0.75))
            guard token == current, !refreshing else { return }
            withAnimation(.easeOut(duration: 0.25)) { shift = Self.threshold + 12 }
            try? await Task.sleep(for: .seconds(0.5))
            guard token == current else { return }
            release()
        }
    }
}

// MARK: - Indicator

private struct RocketIndicator: View {
    let pull: CGFloat
    let threshold: CGFloat
    let holdHeight: CGFloat
    let refreshing: Bool
    let leaving: Bool
    let launchTime: Date
    let exhaust: Int
    let shake: CGFloat
    let preview: Bool
    let buzz: Bool

    @Environment(\.demoIsStill) private var isStill
    /// How far above the list's top edge the rocket's centre rides while it is pulled.
    private static let ride: CGFloat = 30
    private static let rocketHeight: CGFloat = 38

    private var tension: CGFloat { min(max((pull - 20) / (threshold - 20), 0), 1) }

    /// The rocket's centre: riding the pull, parked mid-strip while loading, off the top when leaving.
    private var rocketY: CGFloat {
        if leaving { return -60 }
        if refreshing { return holdHeight / 2 - 12 }
        return pull - Self.ride
    }

    var body: some View {
        let tension: CGFloat = self.tension
        let y: CGFloat = rocketY
        let coilLength: CGFloat = refreshing ? 6 : max(y - Self.rocketHeight / 2 + 2, 0)
        let active: Bool = refreshing || tension > 0.5
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(hex: 0x0B1030), Color(hex: 0x1C2A5E)], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: preview), paused: !active || isStill)) { timeline in
                let now: Double = isStill ? 3 : timeline.date.timeIntervalSinceReferenceDate
                let since: Double = isStill ? 0 : timeline.date.timeIntervalSince(launchTime)
                let charge: CGFloat = max(0, (tension - 0.55) / 0.45)
                let tremble: CGFloat = refreshing ? 0.6 : shake * charge
                let jitter: CGFloat = isStill ? 0 : tremble * CGFloat(sin(now * 83) * 0.6 + sin(now * 131) * 0.4)
                ZStack(alignment: .top) {
                    RocketSky(now: now, since: since, refreshing: refreshing, exhaust: exhaust, nozzle: CGPoint(x: 150, y: y + Self.rocketHeight / 2 - 2), edge: pull)
                    RocketCoil(length: coilLength, tension: refreshing ? 0 : tension)
                        .stroke(Color.white.opacity(refreshing ? 0.35 : 0.7), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 300, height: 120, alignment: .top)
                        .animation(.spring(response: 0.35, dampingFraction: 0.4), value: refreshing)
                    RocketShip(flame: refreshing ? 1 : (pull >= threshold ? 0.8 : charge * 0.45), flicker: isStill ? 0.5 : sin(now * 47) * 0.5 + 0.5)
                        .frame(width: 26, height: Self.rocketHeight + 22, alignment: .top)
                        // Two modifiers: the height is spring-animated at launch, the tremble changes every frame.
                        .offset(y: y - Self.rocketHeight / 2)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: refreshing)
                        .offset(x: jitter)
                }
            }
        }
        .frame(width: 300, height: 120, alignment: .top)
        .opacity(pull > 6 ? 1 : 0)
        .onChange(of: pull >= threshold) { _, past in
            guard !refreshing, past, buzz else { return }
            Haptics.tap(.rigid)
        }
    }
}

/// A coil spring hanging from the top centre: `length` of travel, turns that narrow as it is stretched.
private struct RocketCoil: Shape {
    var length: CGFloat
    var tension: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(length, tension) }
        set {
            length = newValue.first
            tension = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x: CGFloat = rect.midX
        let top: CGFloat = rect.minY
        let reach: CGFloat = max(length, 0)
        path.move(to: CGPoint(x: x, y: top))
        guard reach > 8 else {
            path.addLine(to: CGPoint(x: x, y: top + reach))
            return path
        }
        let lead: CGFloat = 4
        let amplitude: CGFloat = 7 * (1 - 0.6 * min(max(tension, 0), 1))
        let turns = 7
        let steps: Int = turns * 2
        let span: CGFloat = reach - lead * 2
        path.addLine(to: CGPoint(x: x, y: top + lead))
        for step in 1...steps {
            let side: CGFloat = step == steps ? 0 : (step % 2 == 0 ? -1 : 1)
            path.addLine(to: CGPoint(x: x + side * amplitude, y: top + lead + span * CGFloat(step) / CGFloat(steps)))
        }
        path.addLine(to: CGPoint(x: x, y: top + reach))
        return path
    }
}

/// The rocket, nose up, with a flame below its nozzle. `flame` 0…1 is its size, `flicker` 0…1 its jitter.
private struct RocketShip: View {
    let flame: CGFloat
    let flicker: Double

    var body: some View {
        ZStack(alignment: .top) {
            // Flame first, so the body covers its root.
            RocketFlame()
                .fill(LinearGradient(colors: [Color(hex: 0xFFF3B0), Palette.amber, Palette.coral.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                .frame(width: 11, height: 24)
                .scaleEffect(x: 0.8 + 0.2 * CGFloat(flicker), y: flame * (0.8 + 0.3 * CGFloat(flicker)), anchor: .top)
                .opacity(flame > 0.02 ? 1 : 0)
                .offset(y: 33)
            // Fins.
            RocketFins()
                .fill(LinearGradient(colors: [Color(hex: 0xFF7A5C), Color(hex: 0xD9432F)], startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 16)
                .offset(y: 22)
            // Body.
            RocketBody()
                .fill(LinearGradient(colors: [Color.white, Color(hex: 0xC9D2E8)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 15, height: 36)
            RocketBody()
                .fill(Color(hex: 0xFF7A5C))
                .frame(width: 15, height: 36)
                .mask(alignment: .top) { Rectangle().frame(height: 10) }
            Circle()
                .fill(Color(hex: 0x3AC4FF))
                .overlay(Circle().strokeBorder(Color(hex: 0x1C2A5E), lineWidth: 1.2))
                .frame(width: 7.5, height: 7.5)
                .offset(y: 14)
        }
    }
}

private struct RocketBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.5), control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.maxX - 1.5, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 1.5, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.5))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.14))
        path.closeSubpath()
        return path
    }
}

private struct RocketFins: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 6, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.midX - 5, y: rect.maxY - 4))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.midX + 6, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.midX + 5, y: rect.maxY - 4))
        path.closeSubpath()
        return path
    }
}

private struct RocketFlame: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.55))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.closeSubpath()
        return path
    }
}

/// Stars, exhaust and the launch puff: all stateless functions of the clock.
private struct RocketSky: View {
    let now: Double
    /// Seconds since the launch.
    let since: Double
    let refreshing: Bool
    let exhaust: Int
    let nozzle: CGPoint
    /// The list's top edge (the bottom of the strip).
    let edge: CGFloat

    var body: some View {
        Canvas { context, size in
            stars(&context, size: size)
            guard refreshing else { return }
            puffs(&context)
            launchCloud(&context, size: size)
        }
        .frame(width: 300, height: 120)
        .allowsHitTesting(false)
    }

    private func unit(_ seed: Double) -> Double {
        let value: Double = sin(seed * 127.1 + 311.7) * 43758.5453
        return value - value.rounded(.down)
    }

    /// Still while pulling; streaking down while the rocket flies.
    private func stars(_ context: inout GraphicsContext, size: CGSize) {
        let speed: Double = refreshing ? min(since / 0.3, 1) : 0
        for index in 0..<16 {
            let seed: Double = Double(index)
            let x: CGFloat = CGFloat(unit(seed)) * size.width
            let fall: Double = refreshing ? since * (70 + 90 * unit(seed + 40)) : 0
            let y: CGFloat = CGFloat((unit(seed + 20) * 110 + fall).truncatingRemainder(dividingBy: 110))
            let twinkle: Double = 0.45 + 0.55 * unit(seed + 60)
            let length: CGFloat = 1.4 + CGFloat(speed) * (5 + 6 * CGFloat(unit(seed + 80)))
            let rect = CGRect(x: x, y: y, width: 1.4, height: length)
            context.fill(Path(roundedRect: rect, cornerRadius: 0.7), with: .color(Color.white.opacity(twinkle)))
        }
    }

    private func puffs(_ context: inout GraphicsContext) {
        let life: Double = 0.55
        for index in 0..<exhaust {
            let seed: Double = Double(index)
            let age: Double = ((now / life) + seed / Double(exhaust)).truncatingRemainder(dividingBy: 1)
            // No puff is older than the launch itself.
            guard age * life <= since - 0.12 else { continue }
            let drift: CGFloat = CGFloat(unit(seed + 7) - 0.5) * 22 * CGFloat(age)
            let x: CGFloat = nozzle.x + drift
            let y: CGFloat = nozzle.y + 6 + CGFloat(age) * 34
            let radius: CGFloat = 2 + 6 * CGFloat(age)
            let heat: Double = max(0, 1 - age * 2.4)
            let colour = Color(
                .sRGB,
                red: (150 + 105 * heat) / 255,
                green: (155 + 40 * heat) / 255,
                blue: (175 - 104 * heat) / 255,
                opacity: (1 - age) * (0.35 + 0.5 * heat)
            )
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(colour))
        }
    }

    /// The burst of smoke that spreads along the list's edge right at lift-off.
    private func launchCloud(_ context: inout GraphicsContext, size: CGSize) {
        let t: Double = since / 0.6
        guard t > 0, t < 1 else { return }
        let eased: Double = 1 - pow(1 - t, 3)
        for index in 0..<10 {
            let seed: Double = Double(index)
            let side: CGFloat = index % 2 == 0 ? -1 : 1
            let reach: CGFloat = CGFloat(18 + 46 * unit(seed + 3)) * CGFloat(eased)
            let radius: CGFloat = 5 + 9 * CGFloat(eased) * CGFloat(0.6 + 0.4 * unit(seed + 9))
            let x: CGFloat = size.width / 2 + side * reach
            let y: CGFloat = edge - radius * 0.5
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color(white: 0.85).opacity(0.5 * (1 - t))))
        }
    }
}
