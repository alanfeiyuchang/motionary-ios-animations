import SwiftUI

extension Effect {
    static let iconsClockTick = Effect(
        id: "icons.clock-tick",
        category: .icons,
        interaction: .loop,
        name: L("Ticking Clock", "走针时钟"),
        summary: L("A live clock whose second hand snaps to each tick with a tiny overshoot; tap and time whirls forward, hands trailing ghosts.", "一只实时走动的时钟，秒针每一格都带着细小的过冲落定；点击后时间飞速前进，指针拖出残影。"),
        prompt: L(
            "A round clock face with twelve ticks, dark hour and minute hands and a red second hand with a counterweight, showing the real time. Every second the second hand jumps 6° on a stiff spring (response 0.2 s, damping 0.4), overshooting about 1.5° and trembling into place like a quartz movement; the minute hand creeps with it. On tap, time whirls forward 3 hours over roughly 1.1 s on an ease-in-out: the minute hand sweeps three full turns leaving four fading ghost copies behind it, the hour hand glides a quarter turn, and both overshoot their final angle slightly and ring out (decay 9). The digital readout below races along and the sun or moon beside it swaps as day turns to night. Selection ticks mark each passing hour and a soft thud the landing. Precise, mechanical and a little playful.",
            "圆形钟面上有十二道刻度、深色的时针与分针，以及带配重的红色秒针，显示真实时间。每过一秒，秒针以偏硬的弹簧（响应0.2秒、阻尼0.4）跳动6°，过冲约1.5°后微颤着落定，像石英机芯；分针随之缓缓挪动。点击后，时间以缓入缓出曲线在约1.1秒内向前飞转3小时：分针扫过整整三圈，身后拖着四道渐隐的残影，时针滑过四分之一圈，两者都略微冲过终点再衰减回摆（衰减9）。下方数字读数飞速滚动，旁边的太阳或月亮随昼夜切换。每过一小时有一下选择触感，落定时一记柔和触感。"
        ),
        implementation: L(
            "A TimelineView reads the calendar time each frame. The second hand's angle is 6° × (whole seconds − 1 + an analytic spring of the fractional second); a tap adds an eased time offset, and the ghosts are the minute hand evaluated a few hundredths of a second earlier.",
            "TimelineView 每帧读取日历时间。秒针角度为 6° ×（整秒 − 1 + 秒内小数的解析弹簧）；点击会叠加一段缓动的时间偏移，残影则是把分针放在几百分之一秒之前求值得到的。"
        ),
        apis: ["TimelineView(.animation)", "Calendar.dateComponents", "rotationEffect(_:anchor:)", "contentTransition(.symbolEffect(.replace))", "monospacedDigit()"],
        tags: ["clock", "tick", "time", "second hand", "watch", "时钟", "走针", "时间", "秒针", "钟表"],
        params: [
            .slider("damping", L("Tick damping", "跳秒阻尼"), 0.2...1.0, default: 0.4),
            .slider("hours", L("Hours per tap", "每次前进小时"), 1...12, default: 3, step: 1, decimals: 0, unit: "h"),
            .toggle("sweep", L("Smooth sweep", "平滑扫秒"), default: false),
        ]
    ) { ctx in
        IconsClockTickDemo(ctx: ctx)
    }
}

private struct IconsClockTickDemo: View {
    let ctx: DemoContext
    /// Hours already added by finished spins.
    @State private var banked: Double = 0
    /// Hours the running (or last) spin adds.
    @State private var spinning: Double = 0
    @State private var start: Date = .distantPast

    private static func duration(hours: Double) -> Double {
        min(0.86 + 0.08 * hours, 1.7)
    }

    var body: some View {
        IconsTimeline(preview: ctx.isPreview) { date in
            let t: Double = elapsed(at: date)
            let length: Double = Self.duration(hours: spinning)
            let pose = IconsClockPose(
                date: date,
                still: ctx.isStill,
                banked: banked,
                spinning: spinning,
                t: t,
                length: length
            )
            VStack(spacing: 12) {
                IconsClockFace(
                    pose: pose,
                    ghosts: (1...4).map { pose.minuteAngle(at: t - 0.022 * Double($0)) },
                    blur: pose.speed(at: t),
                    damping: ctx["damping"],
                    sweep: ctx.bool("sweep")
                )
                .frame(width: 196, height: 196)
                .contentShape(Circle())
                .onTapGesture { spin() }
                readout(pose)
                DemoHint(text: L("Tap to spin time forward", "点击让时间向前飞转"), ctx: ctx)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.6) { spin() }
    }

    private func readout(_ pose: IconsClockPose) -> some View {
        let minutes: Int = pose.minutesOfDay(at: pose.t)
        let isDay: Bool = (6 * 60..<18 * 60).contains(minutes)
        return HStack(spacing: 7) {
            Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill")
                .foregroundStyle(isDay ? Palette.amber : Palette.indigo)
                .contentTransition(.symbolEffect(.replace))
                .animation(.snappy(duration: 0.3), value: isDay)
            Text(verbatim: String(format: "%02d:%02d", minutes / 60, minutes % 60))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.primary)
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private func spin() {
        // One spin at a time.
        guard elapsed(at: .now) > Self.duration(hours: spinning) + 0.45 else { return }
        banked = (banked + spinning).truncatingRemainder(dividingBy: 24)
        spinning = Double(max(ctx.int("hours"), 1))
        start = .now
        Haptics.tap(.light)
        let length: Double = Self.duration(hours: spinning)
        let hours: Int = Int(spinning)
        for hour in 1..<max(hours, 1) {
            IconsHaptics.later(length * (0.2 + 0.6 * Double(hour) / Double(hours)), preview: ctx.isPreview) { Haptics.selection() }
        }
        IconsHaptics.later(length, preview: ctx.isPreview) { Haptics.tap(.soft) }
    }
}

/// The time the clock shows: wall time plus the hours added by taps.
private struct IconsClockPose {
    /// Seconds since midnight, without the tap offsets.
    let base: Double
    let banked: Double
    let spinning: Double
    let t: Double
    let length: Double

    init(date: Date, still: Bool, banked: Double, spinning: Double, t: Double, length: Double) {
        if still {
            base = 10 * 3_600 + 9 * 60 + 36.4
        } else {
            let parts = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
            base = Double(parts.hour ?? 0) * 3_600 + Double(parts.minute ?? 0) * 60 + Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1_000_000_000
        }
        self.banked = banked
        self.spinning = spinning
        self.t = t
        self.length = length
    }

    var seconds: Double { base.truncatingRemainder(dividingBy: 60) }

    /// Hours added so far by the running spin.
    private func added(at time: Double) -> Double {
        spinning * IconsCurve.easeInOut(IconsCurve.seg(time, 0, length))
    }

    /// Wall time in hours, including every offset.
    private func hours(at time: Double) -> Double {
        base / 3_600 + banked + added(at: time)
    }

    /// The landing wobble, in units of "hours of minute-hand travel".
    private func wobble(at time: Double) -> Double {
        0.022 * IconsCurve.shake(time - length, decay: 9, frequency: 20)
    }

    func minuteAngle(at time: Double) -> Double {
        (hours(at: time) + wobble(at: time)) * 360
    }

    func hourAngle(at time: Double) -> Double {
        (hours(at: time) + wobble(at: time) * 4) * 30
    }

    func minutesOfDay(at time: Double) -> Int {
        let total: Double = (hours(at: time) * 60).rounded(.down)
        let day: Double = total.truncatingRemainder(dividingBy: 1_440)
        return Int(day < 0 ? day + 1_440 : day)
    }

    /// 0…1: how fast the hands are spinning (drives the ghosts).
    func speed(at time: Double) -> Double {
        guard time < length else { return 0 }
        return IconsCurve.bump(IconsCurve.seg(time, 0, length))
    }
}

private struct IconsClockFace: View {
    let pose: IconsClockPose
    let ghosts: [Double]
    let blur: Double
    let damping: Double
    let sweep: Bool

    private var secondAngle: Double {
        let seconds: Double = pose.seconds
        if sweep { return seconds * 6 }
        let whole: Double = seconds.rounded(.down)
        return 6 * (whole - 1 + IconsCurve.spring(seconds - whole, response: 0.2, damping: damping))
    }

    var body: some View {
        ZStack {
            face
            ticks
            ForEach(Array(ghosts.enumerated()), id: \.offset) { offset, angle in
                hand(width: 6, length: 68, tail: 0)
                    .foregroundStyle(Color.primary.opacity(0.22 * blur * (1 - Double(offset) * 0.2)))
                    .rotationEffect(.degrees(angle))
            }
            hand(width: 8, length: 46, tail: 0)
                .foregroundStyle(Color.primary.opacity(0.92))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
                .rotationEffect(.degrees(pose.hourAngle(at: pose.t)))
            hand(width: 6, length: 68, tail: 0)
                .foregroundStyle(Color.primary.opacity(0.92))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
                .rotationEffect(.degrees(pose.minuteAngle(at: pose.t)))
            hand(width: 2.5, length: 76, tail: 18)
                .foregroundStyle(Palette.red)
                .shadow(color: Palette.red.opacity(0.35), radius: 3, y: 2)
                .rotationEffect(.degrees(secondAngle))
            Circle()
                .fill(Palette.red)
                .frame(width: 11, height: 11)
            Circle()
                .fill(Color(uiColor: .systemBackground))
                .frame(width: 4, height: 4)
        }
        .frame(width: 196, height: 196)
    }

    private var face: some View {
        Circle()
            .fill(Palette.elevated)
            .overlay {
                Circle().fill(RadialGradient(colors: [.white.opacity(0.1), .white.opacity(0)], center: UnitPoint(x: 0.35, y: 0.25), startRadius: 4, endRadius: 150))
            }
            .overlay {
                Circle().strokeBorder(
                    LinearGradient(colors: [Color(hex: 0x8A93FF), Color(hex: 0xA352F0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 6
                )
            }
            .shadow(color: Palette.indigo.opacity(0.28), radius: 18, y: 10)
    }

    private var ticks: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                let major: Bool = index.isMultiple(of: 3)
                Capsule()
                    .fill(Color.primary.opacity(major ? 0.75 : 0.3))
                    .frame(width: major ? 4 : 3, height: major ? 13 : 8)
                    .offset(y: -76 + (major ? 0 : -2.5))
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }
    }

    /// A hand pointing at 12 o'clock, pivoting on the face's centre.
    private func hand(width: CGFloat, length: CGFloat, tail: CGFloat) -> some View {
        Capsule()
            .frame(width: width, height: length + tail)
            .offset(y: -(length - tail) / 2)
    }
}
