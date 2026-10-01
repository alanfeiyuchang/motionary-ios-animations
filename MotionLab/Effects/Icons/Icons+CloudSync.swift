import SwiftUI

extension Effect {
    static let iconsCloudSync = Effect(
        id: "icons.cloud-sync",
        category: .icons,
        interaction: .tap,
        name: L("Cloud Sync", "云端同步"),
        summary: L("Arrows circulate inside a cloud as data streams up, then resolve into a drawn check, or a shaking error.", "箭头在云朵里循环转动，数据向上汇入，最后化为一笔画出的对勾，或是一阵摇晃的报错。"),
        prompt: L(
            "A glossy green cloud holding a white check. On tap the check un-draws in 0.16 s, the cloud fades to blue and two curved arrows scale in, then turn in rhythmic half-turns, each 180° easing in and out over 0.55 s, while five small dots rise from below into the cloud and it breathes ±2%. After 1.5 s the result lands. Success: the arrows spin another half-turn as they shrink away, the check draws left to right in 0.3 s and pops on a spring (response 0.34 s, damping 0.5), the cloud bumps to 110%, turns green again and releases a mint ring with a success haptic. Failure: the arrows drop out, an exclamation mark springs in, the cloud turns red, sags 4 pt and shakes 10 pt side to side on a fast decaying wobble with an error haptic. Patient while working, decisive at the end.",
            "带光泽的绿色云朵里是白色对勾。点击后对勾在0.16秒内被擦去，云朵褪回蓝色，两枚弧形箭头放大出现，随后有节奏地半圈半圈转动：每180°用0.55秒缓入缓出；五颗小圆点从下方升入云中，云朵做±2%的呼吸。1.5秒后结果落定。成功：箭头再转半圈并缩没，对勾用0.3秒从左到右画出，并以弹簧（响应0.34秒、阻尼0.5）弹一下；云朵鼓到110%、变绿，放出薄荷色圆环与成功触感。失败：箭头掉落淡出，感叹号弹入，云朵变红、下沉4 pt，以快速衰减的摆动左右摇晃10 pt，伴随错误触感。"
        ),
        implementation: L(
            "Everything is a function of the seconds since the tap inside a TimelineView: stepped eased rotation for the arrows, looping phases for the rising dots, then either a trimmed check with an analytic spring or a decaying sine shake.",
            "所有动作都是 TimelineView 中点击后秒数的函数：箭头是分段缓动的旋转，上升圆点是循环相位，结尾要么是配解析弹簧的裁剪对勾，要么是衰减正弦的摇晃。"
        ),
        apis: ["TimelineView(.animation)", "Shape.trim(from:to:)", "Path.addArc", "rotationEffect", "Image(systemName:)"],
        tags: ["cloud", "sync", "upload", "backup", "check", "error", "云", "同步", "上传", "备份", "完成", "失败"],
        params: [
            .choice("result", L("Result", "结果"), [L("Success", "成功"), L("Error", "失败"), L("Alternate", "交替")], default: 2),
            .slider("duration", L("Sync time", "同步时长"), 0.8...3.0, default: 1.5, unit: "s"),
            .slider("shake", L("Error shake", "报错摇晃"), 4...16, default: 10, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        IconsCloudSyncDemo(ctx: ctx)
    }
}

/// Two arcs chasing each other around a circle.
private struct IconsSyncArcs: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for base in [0.0, 180.0] {
            path.move(to: IconsSyncArcs.point(center, radius, base + 28))
            path.addArc(center: center, radius: radius, startAngle: .degrees(base + 28), endAngle: .degrees(base + 150), clockwise: false)
        }
        return path
    }

    static func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: Double) -> CGPoint {
        let angle: CGFloat = CGFloat(degrees) * .pi / 180
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

/// The arrowheads at the leading ends of `IconsSyncArcs`.
private struct IconsSyncHeads: Shape {
    let radius: CGFloat
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for base in [0.0, 180.0] {
            let degrees: Double = base + 156
            let angle: CGFloat = CGFloat(degrees) * .pi / 180
            let radial = CGPoint(x: cos(angle), y: sin(angle))
            let tangent = CGPoint(x: -sin(angle), y: cos(angle))
            let anchor: CGPoint = IconsSyncArcs.point(center, radius, degrees)
            path.move(to: CGPoint(x: anchor.x + tangent.x * size, y: anchor.y + tangent.y * size))
            path.addLine(to: CGPoint(x: anchor.x - tangent.x * size * 0.3 + radial.x * size, y: anchor.y - tangent.y * size * 0.3 + radial.y * size))
            path.addLine(to: CGPoint(x: anchor.x - tangent.x * size * 0.3 - radial.x * size, y: anchor.y - tangent.y * size * 0.3 - radial.y * size))
            path.closeSubpath()
        }
        return path
    }
}

private struct IconsCloudSyncDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast
    @State private var runs: Int = 0
    /// Whether the current (or last) run ends in an error.
    @State private var failing: Bool = false
    /// How the run before it ended, so the cloud can fade from that colour back to blue.
    @State private var failedBefore: Bool = false

    private var syncEnd: Double { IconsCloudScene.arrowsIn + ctx["duration"] }

    var body: some View {
        VStack(spacing: 8) {
            IconsTimeline(preview: ctx.isPreview) { date in
                let t: Double = ctx.isStill ? 10_000 : elapsed(at: date)
                VStack(spacing: 6) {
                    IconsCloudScene(t: t, end: syncEnd, failing: failing, failedBefore: failedBefore, shake: ctx["shake"])
                        .frame(width: 250, height: 196)
                    status(t: t)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { sync() }
            DemoHint(text: L("Tap the cloud to sync", "点击云朵开始同步"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: syncEnd + 1.9) { sync() }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private func status(t: Double) -> some View {
        let busy: Double = IconsCurve.seg(t, 0.05, 0.25) * (1 - IconsCurve.seg(t, syncEnd, syncEnd + 0.2))
        let done: Double = t < syncEnd ? 1 - IconsCurve.seg(t, 0, 0.15) : IconsCurve.easeOut(IconsCurve.seg(t, syncEnd + 0.1, syncEnd + 0.36))
        let rise: CGFloat = t < syncEnd ? 0 : 8 * CGFloat(1 - done)
        // Until the new result lands, the caption still belongs to the previous run.
        let failed: Bool = t < syncEnd ? failedBefore : failing
        return ZStack {
            Text(L("Syncing…", "正在同步…"), ctx.language)
                .opacity(busy)
            Text(failed ? L("Sync failed · Tap to retry", "同步失败 · 点击重试") : L("All changes saved", "所有更改已保存"), ctx.language)
                .foregroundStyle(failed ? Palette.red : Color.secondary)
                .opacity(done)
                .offset(y: rise)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(height: 20)
    }

    private func sync() {
        // A sync already under way finishes first.
        guard elapsed(at: .now) > syncEnd + 0.6 else { return }
        let mode: Int = ctx.int("result")
        let fails: Bool = mode == 1 || (mode == 2 && runs % 2 == 1)
        failedBefore = failing
        failing = fails
        runs += 1
        start = .now
        Haptics.tap(.light)
        IconsHaptics.later(syncEnd + 0.12, preview: ctx.isPreview) {
            if fails { Haptics.error() } else { Haptics.success() }
        }
    }
}

private struct IconsCloudScene: View {
    let t: Double
    /// When the sync ends and the result plays.
    let end: Double
    let failing: Bool
    let failedBefore: Bool
    let shake: Double

    static let arrowsIn: Double = 0.12
    private static let halfTurn: Double = 0.55
    private static let glyphY: CGFloat = 12

    /// Seconds since the result landed (negative while syncing).
    private var after: Double { t - end }
    private var syncing: Bool { t < end }

    var body: some View {
        let after: Double = self.after
        let breathe: Double = syncing ? 0.02 * sin(t * 6) * IconsCurve.seg(t, 0.1, 0.4) : 0
        let bump: Double = failing ? 0 : 0.2 * IconsCurve.shake(after, decay: 7, frequency: 15)
        let sway: Double = failing ? shake * IconsCurve.shake(after - 0.06, decay: 5.5, frequency: 38) : 0
        let sag: Double = failing ? 4 * IconsCurve.easeOut(IconsCurve.seg(after, 0, 0.2)) : 0
        let press: Double = 0.05 * IconsCurve.bump(IconsCurve.seg(t, 0, 0.26))
        ZStack {
            successRing(after: after)
            risingDots
            cloud(after: after)
                .overlay { glyphs(after: after).offset(y: Self.glyphY) }
                .scaleEffect(CGFloat(1 + breathe + bump - press))
                .offset(x: CGFloat(sway), y: CGFloat(sag))
        }
    }

    // MARK: Layers

    private func cloud(after: Double) -> some View {
        // While syncing the previous result's colour drains back to blue; afterwards the new one floods in.
        let tint: Double = syncing ? 1 - IconsCurve.seg(t, 0, 0.25) : IconsCurve.seg(after, 0, 0.3)
        let red: Bool = syncing ? failedBefore : failing
        let symbol = Image(systemName: "cloud.fill").font(.system(size: 132))
        return ZStack {
            symbol.foregroundStyle(LinearGradient(colors: [Color(hex: 0x6CCBFF), Palette.blue], startPoint: .top, endPoint: .bottom))
            symbol
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0x5FE0A4), Color(hex: 0x1FA866)], startPoint: .top, endPoint: .bottom))
                .opacity(red ? 0 : tint)
            symbol
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFF8A8F), Color(hex: 0xE5374D)], startPoint: .top, endPoint: .bottom))
                .opacity(red ? tint : 0)
            symbol
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.38), .white.opacity(0)], startPoint: .top, endPoint: .center))
        }
        .shadow(color: Palette.blue.opacity(0.3 * (1 - tint)), radius: 16, y: 10)
        .shadow(color: (red ? Palette.red : Palette.green).opacity(0.32 * tint), radius: 16, y: 10)
    }

    private func glyphs(after: Double) -> some View {
        ZStack {
            arrows(after: after)
            check(after: after)
            exclamation(after: after)
        }
        .foregroundStyle(.white)
    }

    private func arrows(after: Double) -> some View {
        let arrive: Double = IconsCurve.spring(t - Self.arrowsIn, response: 0.36, damping: 0.6)
        let leave: Double = IconsCurve.easeIn(IconsCurve.seg(after, 0, 0.2))
        let steps: Double = max(t - Self.arrowsIn, 0) / Self.halfTurn
        let whole: Double = steps.rounded(.down)
        let rotation: Double = 180 * (whole + IconsCurve.easeInOut(steps - whole))
        let exit: Double = failing ? -40 * leave : 180 * leave
        let scale: Double = arrive * (failing ? 1 : 1 - leave)
        return ZStack {
            IconsSyncArcs(radius: 19)
                .stroke(style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
            IconsSyncHeads(radius: 19, size: 7)
                .fill()
            IconsSyncHeads(radius: 19, size: 7)
                .stroke(style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }
        .frame(width: 60, height: 60)
        .rotationEffect(.degrees(syncing ? rotation : rotation + exit))
        .scaleEffect(CGFloat(max(scale, 0)))
        .offset(y: failing ? 10 * CGFloat(leave) : 0)
        .opacity(t < Self.arrowsIn || t > 9_000 ? 0 : 1 - leave)
    }

    private func check(after: Double) -> some View {
        // Shown at rest and after a success; un-drawn at the start of a run.
        let erased: Double = IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.16))
        let drawn: Double = IconsCurve.easeOut(IconsCurve.seg(after, 0.12, 0.42))
        let amount: Double = syncing ? (failedBefore ? 0 : 1 - erased) : (failing ? 0 : drawn)
        let pop: Double = syncing ? 1 : 0.6 + 0.4 * IconsCurve.spring(after - 0.12, response: 0.34, damping: 0.5)
        return IconsCheck()
            .trim(from: 0, to: CGFloat(amount))
            .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            .frame(width: 44, height: 36)
            .scaleEffect(CGFloat(pop))
            .opacity(amount > 0.001 ? 1 : 0)
    }

    private func exclamation(after: Double) -> some View {
        let bar: Double = failing ? IconsCurve.spring(after - 0.08, response: 0.3, damping: 0.55) : 0
        let dot: Double = failing ? IconsCurve.spring(after - 0.2, response: 0.3, damping: 0.5) : 0
        // The mark left by a failed run shrinks away when the next run starts.
        let leftover: Double = failedBefore ? 1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.16)) : 0
        return VStack(spacing: 6) {
            Capsule()
                .frame(width: 8, height: 28)
                .scaleEffect(x: 1, y: CGFloat(syncing ? leftover : max(bar, 0)), anchor: .top)
            Circle()
                .frame(width: 9, height: 9)
                .scaleEffect(CGFloat(syncing ? leftover : max(dot, 0)))
        }
        .opacity(syncing ? (leftover > 0.01 ? 1 : 0) : (failing ? 1 : 0))
    }

    private var risingDots: some View {
        let gate: Double = IconsCurve.seg(t, 0.2, 0.45) * (1 - IconsCurve.seg(t, end - 0.2, end))
        return ZStack {
            ForEach(0..<5, id: \.self) { index in
                let phase: Double = (t * 1.3 + Double(index) * 0.2).truncatingRemainder(dividingBy: 1)
                let x: CGFloat = CGFloat(index - 2) * 17 + CGFloat(sin(t * 3 + Double(index)) * 3)
                let y: CGFloat = 96 - 56 * CGFloat(IconsCurve.easeOut(phase))
                Circle()
                    .fill(Palette.sky)
                    .frame(width: 7.5, height: 7.5)
                    .scaleEffect(CGFloat(1 - 0.45 * phase))
                    .opacity(IconsCurve.bump(phase))
                    .offset(x: x, y: y)
            }
        }
        .opacity(syncing ? gate : 0)
    }

    private func successRing(after: Double) -> some View {
        let p: Double = failing ? 0 : IconsCurve.seg(after, 0.1, 0.75)
        let live: Bool = p > 0 && p < 1
        return Capsule()
            .stroke(Palette.mint.opacity(0.7 * (1 - p)), lineWidth: 5 * CGFloat(1 - p) + 0.5)
            .frame(width: 150, height: 96)
            .scaleEffect(CGFloat(1 + 0.5 * IconsCurve.easeOut(p)))
            .offset(y: 6)
            .opacity(live ? 1 : 0)
    }
}
