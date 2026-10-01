import SwiftUI

extension Effect {
    static let iconsAirdropRings = Effect(
        id: "icons.airdrop-rings",
        category: .icons,
        interaction: .tap,
        name: L("Nearby Share Rings", "附近分享光环"),
        summary: L("Open rings radiate while searching; on a match they snap to fixed radii, close into circles, turn green and a check pops at the centre.", "搜索时带缺口的圆环不断向外扩散；匹配成功后圆环弹到固定半径、合拢成整圆并变绿，中心弹出对勾。"),
        prompt: L(
            "Three blue rings, each with an 80° notch, radiate from a breathing centre dot: every ring is born small, expands to 88 pt and fades over 1.6 s, thinning as it goes, while the notches slowly rotate. On tap they lock on: one after another, 70 ms apart, each ring springs to its own fixed radius (response 0.42 s, damping 0.55) with a visible overshoot, its notch closing into a full circle and its rotation easing home, as the colour shifts from blue to green. At 0.22 s the centre dot swells into a 44 pt green badge on a spring, a white check strokes in over 0.22 s, and one confirmation ring expands to 260% and fades. The caption names the device found. Tapping again releases the rings back into the search. Success haptic on lock. Calm seeking, then a confident lock.",
            "三道各带80°缺口的蓝色圆环，从一枚呼吸着的中心圆点向外扩散：每道圆环在1.6秒内由小扩到88 pt并淡出，越远越细，缺口缓缓旋转。点击后进入锁定：圆环相隔70毫秒依次以弹簧（响应0.42秒、阻尼0.55）弹到各自固定的半径，过冲清晰可见，缺口合拢成整圆，旋转归位，颜色由蓝转绿。0.22秒时中心圆点以弹簧鼓成44 pt的绿色徽章，白色对勾用0.22秒画出，一道确认光环放大到260%后淡出。说明文字显示找到的设备。再次点击，圆环重新散开继续搜索。锁定时配成功触感。"
        ),
        implementation: L(
            "Each ring blends two poses by a per-ring lock value (an analytic spring): the search pose derived from a rate-continuous phase clock and the locked pose with a fixed radius. The notch is an arc Shape whose gap shrinks with the lock; the check is a trimmed stroke.",
            "每道圆环按各自的锁定值（解析弹簧）在两种姿态间混合：由速率连续的相位时钟推导的搜索姿态，以及半径固定的锁定姿态。缺口是一个弧形 Shape，缺口角随锁定收小；对勾是 trim 描边。"
        ),
        apis: ["TimelineView(.animation)", "Shape", "Path.addArc", "Shape.trim(from:to:)", "scaleEffect"],
        tags: ["nearby", "share", "rings", "radiate", "pairing", "discover", "附近", "分享", "光环", "扩散", "配对"],
        params: [
            .slider("rings", L("Rings", "圆环数量"), 2...4, default: 3, step: 1, decimals: 0),
            .slider("period", L("Ring period", "扩散周期"), 0.8...3.0, default: 1.6, unit: "s"),
            .slider("damping", L("Lock damping", "锁定阻尼"), 0.3...0.9, default: 0.55),
        ]
    ) { ctx in
        IconsAirdropRingsDemo(ctx: ctx)
    }
}

private struct IconsAirdropRingsDemo: View {
    let ctx: DemoContext
    /// On = locked on.
    @State private var play = IconsPlayhead(isOn: false)
    @State private var cycle = IconsPhaseClock()

    var body: some View {
        let locked: Bool = ctx.isStill ? true : play.isOn
        VStack(spacing: 10) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsShareRingsScene(
                    locked: locked,
                    t: ctx.isStill ? 100 : play.elapsed(at: date),
                    phase: ctx.isStill ? 0.3 : cycle.phase(at: date, rate: 1 / max(ctx["period"], 0.1)),
                    rings: ctx.int("rings"),
                    damping: ctx["damping"]
                )
            }
            .frame(width: 250, height: 204)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            Text(locked ? L("Connected to Mia's phone", "已连接 Mia 的手机") : L("Looking for nearby devices…", "正在寻找附近的设备…"), ctx.language)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: locked)
            DemoHint(text: L("Tap to lock on or search again", "点击锁定或重新搜索"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.4) { toggle() }
        .onChange(of: ctx["period"]) { old, _ in cycle.rebase(oldRate: 1 / max(old, 0.1)) }
    }

    private func toggle() {
        play.toggle(onDuration: 1.0, offDuration: 0.4)
        if play.isOn {
            Haptics.tap(.light)
            IconsHaptics.later(0.3, preview: ctx.isPreview) { Haptics.success() }
        } else {
            Haptics.tap(.soft)
        }
    }
}

/// A ring with a notch at the bottom; `gap` is the notch's full angle in degrees.
private struct IconsNotchedRing: Shape {
    let gap: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if gap < 0.5 {
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        } else {
            path.addArc(center: center, radius: radius, startAngle: .degrees(90 + gap / 2), endAngle: .degrees(450 - gap / 2), clockwise: false)
        }
        return path
    }
}

private struct IconsShareRingsScene: View {
    let locked: Bool
    let t: Double
    /// Search cycles elapsed (one unit = one ring period).
    let phase: Double
    let rings: Int
    let damping: Double

    private static let reach: Double = 88
    private static let inner: Double = 16
    private static let firstLocked: Double = 36
    private static let green = Color(hex: 0x2CC873)

    private var count: Int { max(rings, 1) }

    private func lock(_ index: Int) -> Double {
        if locked { return IconsCurve.spring(t - 0.05 - 0.07 * Double(index), response: 0.42, damping: damping) }
        return 1 - IconsCurve.easeOut(IconsCurve.seg(t, 0, 0.35))
    }

    var body: some View {
        let tint: Double = IconsCurve.unit(lock(0))
        ZStack {
            confirmRing
            ForEach(0..<count, id: \.self) { index in
                ring(index, tint: tint)
            }
            centre(tint: tint)
        }
        .frame(width: 250, height: 204)
    }

    // MARK: Layers

    private func ring(_ index: Int, tint: Double) -> some View {
        let amount: Double = lock(index)
        let held: Double = IconsCurve.unit(amount)
        // Search pose: born at the centre, grows and fades.
        let cycle: Double = phase + Double(index) / Double(count)
        let p: Double = cycle - floor(cycle)
        let searchRadius: Double = IconsCurve.mix(Self.inner, Self.reach, IconsCurve.easeOut(p))
        let searchOpacity: Double = pow(IconsCurve.bump(p), 0.7)
        let searchWidth: Double = 8 - 4.5 * p
        var spin: Double = (phase * 70 + Double(index) * 47).truncatingRemainder(dividingBy: 360)
        if spin > 180 { spin -= 360 }
        // Locked pose: evenly spaced, fully closed, fading slightly outward.
        let step: Double = count > 1 ? (Self.reach - Self.firstLocked) / Double(count - 1) : 0
        let lockedRadius: Double = Self.firstLocked + step * Double(index)
        let radius: Double = max(IconsCurve.mix(searchRadius, lockedRadius, amount), 2)
        let opacity: Double = IconsCurve.mix(searchOpacity, 1 - 0.22 * Double(index), held)
        let width: Double = IconsCurve.mix(searchWidth, 7, held)
        return IconsNotchedRing(gap: 80 * (1 - held))
            .stroke(Self.blend(tint), style: StrokeStyle(lineWidth: CGFloat(width), lineCap: .round))
            .frame(width: CGFloat(radius * 2), height: CGFloat(radius * 2))
            .rotationEffect(.degrees(spin * (1 - held)))
            .opacity(opacity)
    }

    private func centre(tint: Double) -> some View {
        let swell: Double = locked
            ? IconsCurve.spring(t - 0.22, response: 0.34, damping: 0.5)
            : 1 - IconsCurve.easeIn(IconsCurve.seg(t, 0, 0.18))
        let breathe: Double = 1 + 0.12 * sin(phase * 2 * .pi)
        let size: Double = IconsCurve.mix(18 * breathe, 44, swell)
        let stroke: Double = locked ? IconsCurve.easeOut(IconsCurve.seg(t, 0.34, 0.56)) : 1 - IconsCurve.seg(t, 0, 0.1)
        return ZStack {
            Circle()
                .fill(Self.blend(tint))
                .shadow(color: Self.blend(tint).opacity(0.5), radius: 8, y: 3)
            IconsCheck()
                .trim(from: 0, to: CGFloat(stroke))
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 17)
                .opacity(stroke > 0 ? 1 : 0)
        }
        .frame(width: CGFloat(max(size, 1)), height: CGFloat(max(size, 1)))
    }

    private var confirmRing: some View {
        let p: Double = IconsCurve.seg(t - 0.3, 0, 0.6)
        let live: Bool = locked && p > 0 && p < 1
        return Circle()
            .stroke(Self.green.opacity(0.6 * (1 - p)), lineWidth: 5 * CGFloat(1 - p) + 0.5)
            .frame(width: 88, height: 88)
            .scaleEffect(CGFloat(0.5 + 2.1 * IconsCurve.easeOut(p)))
            .opacity(live ? 1 : 0)
    }

    /// Blue while searching, green once locked.
    private static func blend(_ tint: Double) -> Color {
        let k: Double = IconsCurve.unit(tint)
        return Color(
            red: IconsCurve.mix(0.227, 0.173, k),
            green: IconsCurve.mix(0.545, 0.784, k),
            blue: IconsCurve.mix(1.0, 0.451, k)
        )
    }
}
