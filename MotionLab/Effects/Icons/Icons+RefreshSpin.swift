import SwiftUI

extension Effect {
    static let iconsRefreshSpin = Effect(
        id: "icons.refresh-spin",
        category: .icons,
        interaction: .tap,
        name: L("Refresh Spin", "刷新旋转"),
        summary: L("The refresh arrow winds back, whips round with a ghost trail and settles on a tick.", "刷新箭头先回拧蓄力，带着残影甩出几圈，最后“咔哒”一下落定。"),
        prompt: L(
            "A circular refresh arrow, a 290° arc with a rounded arrowhead, sits in a raised disc ringed by twelve faint tick marks. On tap it winds back 24° in 0.14 s, then whips two full turns forward on a spring (response 0.85 s, damping 0.78), overshooting about 15° before settling. While it is fast, six ghost copies trail behind at 8 ms intervals with falling opacity, the arc stretches until its gap almost closes and the stroke thins, so the glyph smears like motion blur and sharpens again as it slows. Each tick flares as the arrowhead sweeps past and decays over 0.35 s. When the arrow first reaches its target all twelve ticks flash mint, a ring leaves the disc, a rigid haptic clicks and the status switches from Refreshing to Updated just now. Energetic, then precisely still.",
            "圆形刷新箭头（290°圆弧加圆角箭头）位于微微隆起的圆盘中，四周环绕十二道淡刻度。点击后先用0.14秒回拧24°，再以弹簧（响应0.85秒、阻尼0.78）向前甩出两整圈，过冲约15°后落定。高速时六道残影以8毫秒间隔拖在身后并逐级变淡，圆弧拉长到缺口几乎闭合、线条变细，像运动模糊般被抹开，减速后重新锐利。箭头掠过时刻度依次亮起，0.35秒内衰减。箭头首次抵达终点的瞬间，十二道刻度齐闪薄荷色，一道圆环离开圆盘，伴随硬朗触感，状态从“正在刷新”换成“刚刚更新”。先迅猛，后静止。"
        ),
        implementation: L(
            "The rotation is a pure function of the seconds since the tap (an eased wind-up, then an analytic spring). Ghosts are the same glyph drawn at slightly earlier times, the arc's stretch follows the finite-difference speed, and a tick flares when the swept angle crosses it.",
            "旋转角度是点击后秒数的纯函数（先缓动回拧，再接解析弹簧）。残影就是同一图标在稍早时刻的角度，圆弧拉伸量取自差分速度，扫过的角度越过某道刻度时它便亮起。"
        ),
        apis: ["TimelineView(.animation)", "Path.addArc", "rotationEffect", "StrokeStyle", "drawingGroup()"],
        tags: ["refresh", "reload", "sync", "spin", "motion blur", "trail", "刷新", "重新加载", "旋转", "残影", "运动模糊"],
        params: [
            .slider("turns", L("Turns", "圈数"), 1...4, default: 2, step: 1, decimals: 0),
            .slider("response", L("Spring response", "弹簧响应"), 0.4...1.4, default: 0.85, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.78),
            .slider("trail", L("Ghost trail", "残影数量"), 0...10, default: 6, step: 1, decimals: 0),
        ]
    ) { ctx in
        IconsRefreshSpinDemo(ctx: ctx)
    }
}

/// The refresh glyph: an arc ending in an arrowhead that points clockwise. `span` is the arc length in degrees.
private struct IconsRefreshArrow: View {
    let span: Double
    let lineWidth: CGFloat
    let radius: CGFloat

    /// Screen angle of the arrowhead at rest (0° = right, clockwise).
    static let headAngle: Double = -52

    var body: some View {
        ZStack {
            IconsRefreshArc(span: span, radius: radius)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            IconsRefreshHead(radius: radius, size: lineWidth * 1.45)
                .fill()
            IconsRefreshHead(radius: radius, size: lineWidth * 1.45)
                .stroke(style: StrokeStyle(lineWidth: lineWidth * 0.45, lineJoin: .round))
        }
    }
}

private struct IconsRefreshArc: Shape {
    let span: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let head: Double = IconsRefreshArrow.headAngle
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(head - span),
            endAngle: .degrees(head - 8),
            clockwise: false
        )
        return path
    }
}

private struct IconsRefreshHead: Shape {
    let radius: CGFloat
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        let angle: CGFloat = CGFloat(IconsRefreshArrow.headAngle) * .pi / 180
        let radial = CGPoint(x: cos(angle), y: sin(angle))
        let tangent = CGPoint(x: -sin(angle), y: cos(angle))
        let anchor = CGPoint(x: rect.midX + radial.x * radius, y: rect.midY + radial.y * radius)
        let back: CGFloat = size * 0.55
        var path = Path()
        path.move(to: CGPoint(x: anchor.x + tangent.x * size * 0.75, y: anchor.y + tangent.y * size * 0.75))
        path.addLine(to: CGPoint(x: anchor.x - tangent.x * back + radial.x * size, y: anchor.y - tangent.y * back + radial.y * size))
        path.addLine(to: CGPoint(x: anchor.x - tangent.x * back - radial.x * size, y: anchor.y - tangent.y * back - radial.y * size))
        path.closeSubpath()
        return path
    }
}

private struct IconsRefreshSpinDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast

    private var settle: Double { IconsRefreshScene.settleTime(response: ctx["response"], damping: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 10) {
            IconsTimeline(preview: ctx.isPreview) { date in
                let t: Double = ctx.isStill ? 10_000 : elapsed(at: date)
                VStack(spacing: 14) {
                    IconsRefreshScene(
                        t: t,
                        turns: Double(ctx.int("turns")),
                        response: ctx["response"],
                        damping: ctx["damping"],
                        trail: ctx.int("trail")
                    )
                    .frame(width: 210, height: 196)
                    status(t: t)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { refresh() }
            DemoHint(text: L("Tap to refresh", "点击刷新"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.4) { refresh() }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    /// Two captions cross-rolling on the same clock as the glyph.
    private func status(t: Double) -> some View {
        // One caption leaves before the other arrives, so they never overlap.
        let leaving: Double = IconsCurve.seg(t, 0, 0.1)
        let busyIn: Double = IconsCurve.easeOut(IconsCurve.seg(t, 0.1, 0.26))
        let busyOut: Double = IconsCurve.seg(t, settle, settle + 0.1)
        let arriving: Double = IconsCurve.easeOut(IconsCurve.seg(t, settle + 0.1, settle + 0.34))
        let busy: Double = busyIn * (1 - busyOut)
        let done: Double = t < settle ? 1 - leaving : arriving
        let doneShift: CGFloat = t < settle ? -8 * CGFloat(leaving) : 8 * CGFloat(1 - arriving)
        return ZStack {
            Text(L("Refreshing…", "正在刷新…"), ctx.language)
                .foregroundStyle(.secondary)
                .opacity(busy)
                .offset(y: t < settle ? 8 * CGFloat(1 - busyIn) : -8 * CGFloat(busyOut))
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.mint)
                Text(L("Updated just now", "刚刚更新"), ctx.language)
                    .foregroundStyle(.secondary)
            }
            .opacity(done)
            .offset(y: doneShift)
        }
        .font(.subheadline.weight(.semibold))
        .frame(height: 20)
    }

    private func refresh() {
        // A refresh already under way finishes first.
        guard elapsed(at: .now) > settle + 0.1 else { return }
        start = .now
        Haptics.tap(.light)
        IconsHaptics.later(settle, preview: ctx.isPreview) { Haptics.tap(.rigid) }
    }
}

private struct IconsRefreshScene: View {
    let t: Double
    let turns: Double
    let response: Double
    let damping: Double
    let trail: Int

    private static let windUp: Double = 24
    private static let windTime: Double = 0.14
    private static let ghostGap: Double = 0.008
    private static let discSize: CGFloat = 152
    private static let arcRadius: CGFloat = 33

    /// When the spring first reaches its target (for damping below 1), capped for the critically damped case.
    static func settleTime(response: Double, damping: Double) -> Double {
        let zeta: Double = min(max(damping, 0.05), 0.999)
        let root: Double = (1 - zeta * zeta).squareRoot()
        let omega: Double = 2 * .pi / max(response, 0.05)
        let crossing: Double = (.pi - acos(zeta)) / (omega * root)
        return windTime + min(crossing, response * 1.1)
    }

    /// Rotation in degrees at `time` seconds after the tap. A whole number of turns, so the rest pose is unchanged.
    private func angle(_ time: Double) -> Double {
        guard time > 0 else { return 0 }
        if time < Self.windTime {
            return -Self.windUp * IconsCurve.easeOut(time / Self.windTime)
        }
        let p: Double = IconsCurve.spring(time - Self.windTime, response: response, damping: damping)
        return -Self.windUp + (360 * turns + Self.windUp) * p
    }

    var body: some View {
        let now: Double = angle(t)
        let speed: Double = abs(now - angle(t - 0.016)) / 0.016
        let blur: Double = IconsCurve.unit(speed / 1_700)
        let settle: Double = Self.settleTime(response: response, damping: damping)
        let flash: Double = IconsCurve.seg(t, settle, settle + 0.03) * (1 - IconsCurve.seg(t, settle + 0.03, settle + 0.5))
        let press: Double = 0.06 * IconsCurve.bump(IconsCurve.seg(t, 0, 0.26)) - 0.035 * IconsCurve.shake(t - settle, decay: 9, frequency: 26)
        ZStack {
            doneRing(since: t - settle)
            disc
            ticks(flash: flash)
            glyph(angle: now, blur: blur)
        }
        .scaleEffect(CGFloat(1 - press))
    }

    // MARK: Layers

    private var disc: some View {
        Circle()
            .fill(Palette.elevated)
            .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))
            .frame(width: Self.discSize, height: Self.discSize)
            .shadow(color: .black.opacity(0.14), radius: 16, y: 9)
    }

    private func doneRing(since: Double) -> some View {
        let p: Double = IconsCurve.seg(since, 0, 0.6)
        let live: Bool = p > 0 && p < 1
        return Circle()
            .stroke(Palette.mint.opacity(0.7 * (1 - p)), lineWidth: 4 * CGFloat(1 - p) + 0.5)
            .frame(width: Self.discSize, height: Self.discSize)
            .scaleEffect(CGFloat(1 + 0.26 * IconsCurve.easeOut(p)))
            .opacity(live ? 1 : 0)
    }

    private func glyph(angle now: Double, blur: Double) -> some View {
        let span: Double = 290 + 44 * blur
        let width: CGFloat = 8.5 - 2 * CGFloat(blur)
        let ghosts: Int = max(trail, 0)
        return ZStack {
            ForEach((0..<ghosts).reversed(), id: \.self) { index in
                let lagged: Double = angle(t - Double(index + 1) * Self.ghostGap)
                IconsRefreshArrow(span: span, lineWidth: width, radius: Self.arcRadius)
                    .rotationEffect(.degrees(lagged))
                    .opacity(abs(lagged - now) > 1 ? 0.3 * (1 - Double(index) / Double(ghosts + 1)) : 0)
            }
            IconsRefreshArrow(span: span, lineWidth: width, radius: Self.arcRadius)
                .rotationEffect(.degrees(now))
        }
        .foregroundStyle(Palette.ocean)
        .frame(width: 96, height: 96)
        .drawingGroup()
    }

    private func ticks(flash: Double) -> some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                let flare: Double = tickFlare(index)
                Capsule()
                    .fill(Palette.sky)
                    .overlay(Capsule().fill(Palette.mint).opacity(flash))
                    .frame(width: 3, height: 8 + 3 * CGFloat(max(flare, flash)))
                    .opacity(0.16 + 0.84 * max(flare, flash))
                    .offset(y: -62)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }
    }

    /// 1 when the arrowhead has just swept past tick `index`, falling to 0 over 0.35 s.
    private func tickFlare(_ index: Int) -> Double {
        guard t < 20 else { return 0 }
        // Ticks are laid out from the top (0° = up); the arrowhead's rest angle is measured from the right.
        let tick: Double = Double(index) * 30 - 90
        let step: Double = 0.025
        for sample in 0..<14 {
            let end: Double = t - Double(sample) * step
            guard end > 0 else { break }
            let a: Double = (IconsRefreshArrow.headAngle + angle(end - step) - tick) / 360
            let b: Double = (IconsRefreshArrow.headAngle + angle(end) - tick) / 360
            if a.rounded(.down) != b.rounded(.down) {
                return 1 - Double(sample) / 14
            }
        }
        return 0
    }
}
