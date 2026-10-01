import SwiftUI

extension Effect {
    static let iconsFaceIDScan = Effect(
        id: "icons.faceid-scan",
        category: .icons,
        interaction: .tap,
        name: L("Face Scan", "面容扫描"),
        summary: L("Corner brackets breathe, a light bar sweeps the face, then the brackets close into a ring and the smile becomes a check.", "四角括号呼吸，光条扫过面部，随后括号闭合成圆环，微笑变成对勾。"),
        prompt: L(
            "A face glyph (two eyes, a nose, a smile) framed by four rounded corner brackets that breathe ±2.5%. On tap the brackets tighten to 95% and a glowing light bar sweeps top to bottom and back in 1.2 s, trailing a soft gradient; each feature brightens to cyan and swells 8% as the bar crosses it. Then the brackets grow along their edges while the corner radius rounds out until they join into one circle, on a spring (response 0.5 s, damping 0.72). The eyes and nose shrink into the centre and the smile's stroke morphs point by point into a check within 0.35 s. Everything turns green, the glyph pops to 106%, a ring ripples outward and a success haptic lands. A second tap opens the ring back into brackets and scans again. Confident and reassuring.",
            "面部图标（双眼、鼻子、微笑）被四个圆角括号框住，括号做±2.5%的呼吸。点击后括号收紧到95%，一道发光光条在1.2秒内从上扫到下再扫回，身后拖着柔和渐变；光条经过哪个五官，它就亮成青色并放大8%。随后括号沿边延伸、圆角变圆，直到连成一个完整的圆（弹簧响应0.5秒、阻尼0.72）。眼睛和鼻子缩向中心消失，微笑的线条在0.35秒内逐点形变为对勾。整体变绿，图标弹到106%，一道圆环向外荡开，成功触感落下。再次点击时圆环重新打开成括号并再扫一次。笃定、让人安心。"
        ),
        implementation: L(
            "A TimelineView supplies the seconds since the tap. The brackets are one Shape with arm length and corner radius as inputs, the mouth is a Shape that interpolates five control points between a smile and a check, and each feature's glow is a Gaussian of its distance to the bar.",
            "TimelineView 提供点击后的秒数。括号是一个以臂长和圆角半径为输入的 Shape；嘴是在微笑与对勾之间插值五个控制点的 Shape；每个五官的亮度取它到光条距离的高斯函数。"
        ),
        apis: ["TimelineView(.animation)", "Shape", "Path.addArc(tangent1End:tangent2End:radius:)", "Path.addQuadCurve", "mask", "LinearGradient"],
        tags: ["face id", "biometric", "scan", "authenticate", "unlock", "verify", "面容", "生物识别", "扫描", "认证", "解锁", "验证"],
        params: [
            .slider("duration", L("Scan time", "扫描时长"), 0.6...2.4, default: 1.2, unit: "s"),
            .slider("passes", L("Sweeps", "扫描次数"), 1...3, default: 2, step: 1, decimals: 0),
            .slider("glow", L("Bar glow", "光条辉光"), 0...1, default: 0.7),
        ]
    ) { ctx in
        IconsFaceScanDemo(ctx: ctx)
    }
}

/// Four corner brackets of a rounded square. `close` 0 = brackets, 1 = arms meet and the corners become a circle.
private struct IconsFaceBrackets: Shape {
    var close: Double

    func path(in rect: CGRect) -> Path {
        let side: CGFloat = min(rect.width, rect.height)
        let half: CGFloat = side / 2
        let amount: CGFloat = CGFloat(min(max(close, 0), 1))
        let radius: CGFloat = half * (0.44 + 0.56 * amount)
        let restArm: CGFloat = half * 0.1
        let arm: CGFloat = restArm + (half - radius - restArm) * amount
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        // Each corner: an arm, the rounded corner, an arm.
        let signs: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        for (sx, sy) in signs {
            let corner = CGPoint(x: center.x + sx * half, y: center.y + sy * half)
            let horizontal = CGPoint(x: corner.x - sx * (radius + arm), y: corner.y)
            let vertical = CGPoint(x: corner.x, y: corner.y - sy * (radius + arm))
            path.move(to: horizontal)
            path.addArc(tangent1End: corner, tangent2End: vertical, radius: radius)
            path.addLine(to: vertical)
        }
        return path
    }
}

/// The mouth: a smile at `check` 0, a check mark at 1 (five control points interpolated).
private struct IconsFaceMouth: Shape {
    var check: Double

    func path(in rect: CGRect) -> Path {
        let p: CGFloat = CGFloat(min(max(check, 0), 1))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // start, control 1, middle, control 2, end — offsets from the glyph centre.
        let smile: [CGPoint] = [CGPoint(x: -22, y: 24), CGPoint(x: -12, y: 33), CGPoint(x: 0, y: 33), CGPoint(x: 12, y: 33), CGPoint(x: 22, y: 24)]
        let mark: [CGPoint] = [CGPoint(x: -25, y: 2), CGPoint(x: -17, y: 11), CGPoint(x: -9, y: 20), CGPoint(x: 9, y: 0), CGPoint(x: 27, y: -20)]
        var points: [CGPoint] = []
        for index in 0..<5 {
            let x: CGFloat = smile[index].x + (mark[index].x - smile[index].x) * p
            let y: CGFloat = smile[index].y + (mark[index].y - smile[index].y) * p
            points.append(CGPoint(x: center.x + x, y: center.y + y))
        }
        var path = Path()
        path.move(to: points[0])
        path.addQuadCurve(to: points[2], control: points[1])
        path.addQuadCurve(to: points[4], control: points[3])
        return path
    }
}

private struct IconsFaceNose: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: center.x + 3, y: center.y - 14))
        path.addLine(to: CGPoint(x: center.x + 3, y: center.y + 4))
        path.addQuadCurve(to: CGPoint(x: center.x - 5, y: center.y + 10), control: CGPoint(x: center.x + 3, y: center.y + 10))
        return path
    }
}

private struct IconsFaceScanDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast
    @State private var runs: Int = 0

    private var scanEnd: Double { IconsFaceScene.scanStart + ctx["duration"] }

    var body: some View {
        VStack(spacing: 8) {
            IconsTimeline(preview: ctx.isPreview) { date in
                let t: Double = ctx.isStill ? IconsFaceScene.scanStart + ctx["duration"] * 0.3 : elapsed(at: date)
                VStack(spacing: 8) {
                    IconsFaceScene(
                        t: t,
                        clock: ctx.isStill ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3_600),
                        idle: runs == 0 && !ctx.isStill,
                        reopening: runs > 1,
                        duration: ctx["duration"],
                        passes: ctx.int("passes"),
                        glow: ctx["glow"]
                    )
                    .frame(width: 250, height: 200)
                    status(t: t)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { scan() }
            DemoHint(text: L("Tap to scan", "点击开始扫描"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: scanEnd + 2.0) { scan() }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private func status(t: Double) -> some View {
        let idle: Bool = runs == 0 && !ctx.isStill
        let scanning: Double = idle ? 0 : IconsCurve.seg(t, 0.1, 0.3) * (1 - IconsCurve.seg(t, scanEnd, scanEnd + 0.2))
        let done: Double = idle ? 0 : (t < scanEnd ? 1 - IconsCurve.seg(t, 0, 0.15) : IconsCurve.easeOut(IconsCurve.seg(t, scanEnd + 0.15, scanEnd + 0.4)))
        let verified: Bool = runs > 1 || t >= scanEnd
        return ZStack {
            Text(L("Ready to scan", "准备扫描"), ctx.language)
                .opacity(idle ? 1 : 0)
            Text(L("Scanning…", "正在扫描…"), ctx.language)
                .opacity(scanning)
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal.fill")
                Text(L("Verified", "验证通过"), ctx.language)
            }
            .foregroundStyle(Palette.green)
            .opacity(verified ? done : 0)
            .offset(y: t < scanEnd ? 0 : 8 * CGFloat(1 - done))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(height: 20)
    }

    private func scan() {
        // A scan already under way finishes first.
        guard elapsed(at: .now) > scanEnd + 0.7 else { return }
        runs += 1
        start = .now
        Haptics.tap(.light)
        IconsHaptics.later(scanEnd + 0.12, preview: ctx.isPreview) { Haptics.success() }
    }
}

private struct IconsFaceScene: View {
    let t: Double
    let clock: Double
    /// Before the first scan: brackets breathe, nothing else moves.
    let idle: Bool
    /// The previous run ended in the check, so this run first opens the ring back into brackets.
    let reopening: Bool
    let duration: Double
    let passes: Int
    let glow: Double

    static let scanStart: Double = 0.3
    private static let frameSize: CGFloat = 138
    private static let strokeWidth: CGFloat = 7.5

    private var scanEnd: Double { Self.scanStart + duration }
    private var after: Double { idle ? -1 : t - scanEnd }

    // MARK: Motion

    /// 0 = brackets and face, 1 = ring and check.
    private var closed: Double {
        guard !idle else { return 0 }
        if t < scanEnd {
            return reopening ? 1 - IconsCurve.easeInOut(IconsCurve.seg(t, 0, 0.28)) : 0
        }
        return IconsCurve.spring(after, response: 0.5, damping: 0.72)
    }

    private var checkMorph: Double {
        guard !idle else { return 0 }
        if t < scanEnd {
            return reopening ? 1 - IconsCurve.easeInOut(IconsCurve.seg(t, 0, 0.28)) : 0
        }
        return IconsCurve.easeInOut(IconsCurve.seg(after, 0.05, 0.4))
    }

    /// Scan bar position, -1 (top) … 1 (bottom); nil when no scan is running.
    private var barPosition: Double? {
        guard !idle, t >= Self.scanStart, t < scanEnd else { return nil }
        let u: Double = (t - Self.scanStart) / max(duration, 0.01)
        return -cos(.pi * Double(max(passes, 1)) * u)
    }

    private var barOpacity: Double {
        guard !idle else { return 0 }
        return IconsCurve.seg(t, Self.scanStart, Self.scanStart + 0.12) * (1 - IconsCurve.seg(t, scanEnd - 0.12, scanEnd))
    }

    var body: some View {
        let closed: Double = self.closed
        let green: Double = IconsCurve.unit(closed * 1.4)
        let breathe: Double = idle ? 0.025 * sin(clock * 2.2) : 0
        let tighten: Double = idle || t >= scanEnd ? 0 : 0.05 * IconsCurve.easeOut(IconsCurve.seg(t, 0.05, 0.3))
        let pop: Double = 0.115 * IconsCurve.shake(after, decay: 8, frequency: 15)
        ZStack {
            ripple
            Circle()
                .fill(Palette.green.opacity(0.14 * green))
                .frame(width: Self.frameSize, height: Self.frameSize)
                .scaleEffect(CGFloat(0.8 + 0.2 * IconsCurve.unit(closed)))
            scanBar
            face
            brackets(closed: closed, green: green)
                .scaleEffect(CGFloat(1 + breathe - tighten))
        }
        .scaleEffect(CGFloat(1 + pop))
    }

    // MARK: Layers

    private func brackets(closed: Double, green: Double) -> some View {
        let scanning: Double = barOpacity
        return ZStack {
            IconsFaceBrackets(close: closed)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round, lineJoin: .round))
            IconsFaceBrackets(close: closed)
                .stroke(Palette.sky, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round, lineJoin: .round))
                .opacity(scanning)
            IconsFaceBrackets(close: closed)
                .stroke(Palette.green, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round, lineJoin: .round))
                .opacity(green)
        }
        .frame(width: Self.frameSize, height: Self.frameSize)
    }

    private var face: some View {
        let morph: Double = checkMorph
        let gone: Double = IconsCurve.unit(morph * 2.2)
        let green: Double = IconsCurve.unit(morph * 1.5)
        return ZStack {
            feature(y: -18, boostScale: 0.08) {
                HStack(spacing: 34) {
                    Capsule().frame(width: 8.5, height: 20)
                    Capsule().frame(width: 8.5, height: 20)
                }
                .offset(y: -18)
            }
            .scaleEffect(CGFloat(1 - 0.7 * gone))
            .opacity(1 - gone)
            feature(y: -2, boostScale: 0.08) {
                IconsFaceNose()
                    .stroke(style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round, lineJoin: .round))
            }
            .scaleEffect(CGFloat(1 - 0.7 * gone))
            .opacity(1 - gone)
            feature(y: 30, boostScale: 0.08 * (1 - morph)) {
                IconsFaceMouth(check: morph)
                    .stroke(style: StrokeStyle(lineWidth: Self.strokeWidth + 1.5 * CGFloat(morph), lineCap: .round, lineJoin: .round))
            }
            .overlay {
                IconsFaceMouth(check: morph)
                    .stroke(Palette.green, style: StrokeStyle(lineWidth: Self.strokeWidth + 1.5 * CGFloat(morph), lineCap: .round, lineJoin: .round))
                    .opacity(green)
            }
        }
        .frame(width: Self.frameSize, height: Self.frameSize)
    }

    /// A facial feature that lights up as the scan bar crosses height `y`.
    private func feature<Content: View>(y: CGFloat, boostScale: Double, @ViewBuilder content: () -> Content) -> some View {
        let boost: Double = featureBoost(y: y)
        let view = content()
        return ZStack {
            view.foregroundStyle(Color.primary)
            view.foregroundStyle(Palette.sky).opacity(boost)
        }
        .scaleEffect(CGFloat(1 + boostScale * boost))
        .shadow(color: Palette.sky.opacity(0.7 * boost * glow), radius: 8)
    }

    private func featureBoost(y: CGFloat) -> Double {
        guard let position = barPosition else { return 0 }
        let barY: Double = position * Double(Self.frameSize) * 0.42
        let distance: Double = (barY - Double(y)) / 15
        return exp(-distance * distance) * barOpacity
    }

    private var scanBar: some View {
        let position: Double = barPosition ?? 0
        let u: Double = (t - Self.scanStart) / max(duration, 0.01)
        // Travel direction: the tail hangs behind the bar.
        let down: Bool = sin(.pi * Double(max(passes, 1)) * u) >= 0
        let y: CGFloat = CGFloat(position) * Self.frameSize * 0.42
        let tail = LinearGradient(
            colors: [Palette.sky.opacity(0), Palette.sky.opacity(0.32)],
            startPoint: down ? .top : .bottom,
            endPoint: down ? .bottom : .top
        )
        return ZStack {
            Rectangle()
                .fill(tail)
                .frame(width: Self.frameSize - 18, height: 34)
                .offset(y: y + (down ? -17 : 17))
            Capsule()
                .fill(LinearGradient(colors: [Palette.sky.opacity(0.2), .white, Palette.sky.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                .frame(width: Self.frameSize - 14, height: 3.5)
                .shadow(color: Palette.sky.opacity(glow), radius: 4 + 8 * CGFloat(glow))
                .offset(y: y)
        }
        .frame(width: Self.frameSize, height: Self.frameSize)
        .mask(RoundedRectangle(cornerRadius: Self.frameSize * 0.22, style: .continuous).padding(6))
        .opacity(barOpacity)
    }

    private var ripple: some View {
        let p: Double = IconsCurve.seg(after, 0.12, 0.8)
        let live: Bool = p > 0 && p < 1
        return Circle()
            .stroke(Palette.green.opacity(0.6 * (1 - p)), lineWidth: 5 * CGFloat(1 - p) + 0.5)
            .frame(width: Self.frameSize, height: Self.frameSize)
            .scaleEffect(CGFloat(1 + 0.42 * IconsCurve.easeOut(p)))
            .opacity(live ? 1 : 0)
    }
}
