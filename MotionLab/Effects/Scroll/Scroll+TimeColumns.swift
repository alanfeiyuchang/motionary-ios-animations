import SwiftUI

extension Effect {
    static let scrollTimeColumns = Effect(
        id: "scroll.time-columns",
        category: .scroll,
        interaction: .scroll,
        name: L("Linked Time Wheels", "联动时间滚轮"),
        summary: L("Hour, minute and AM/PM drums under one glass band: rolling the minutes past 59 carries the hour, and the hour passing 12 flips the period.", "时、分、上午下午三个滚筒共用一条玻璃选择带：分钟滚过 59 会带动小时进位，小时越过 12 会翻转上午下午。"),
        prompt: L(
            "A time picker made of three vertical drums (hours 1–12, minutes 00–59, AM/PM) that share one rounded glass selection band with a fixed colon. Each drum is a snapping scroll list with 38 pt rows that curve away in 3D (up to 55° of tilt, fading toward the edges) and magnify to 118% inside the band; hours and minutes loop endlessly. The drums are mechanically linked like an odometer: when the minutes roll through 59 → 00 the hour drum advances one row by itself in 0.3 s ease-out (and steps back on 00 → 59), and whenever the hour passes between 11 and 12 the period drum flips. Every row that crosses the band gives a selection haptic, including the carried ones. Above, a chip keeps the result in words, rolling its digits: the chosen time and how long until it rings.",
            "由三个纵向滚筒（小时 1–12、分钟 00–59、上午/下午）组成的时间选择器，共用一条圆角玻璃选择带。每个滚筒都是带吸附的滚动列表，行高 38 pt，各行在三维里向后弯曲（最多倾斜 55°），进入选择带时放大到 118%；小时和分钟无限循环。三个滚筒像里程表一样联动：分钟从 59 滚到 00 时，小时滚筒自己用 0.3 秒缓出前进一格（反向则退一格）；小时在 11 和 12 之间越过时，上午/下午随之翻转。每一行越过选择带都有一次选择触感。上方的标签用滚动数字同步显示选中的时间和距离响铃还有多久。"
        ),
        implementation: L(
            "Three ScrollViews with a stride-snapping ScrollTargetBehavior; rows use visualEffect for the drum curvature and magnification. onScrollGeometryChange reports each drum's row; a change of lap (row ÷ 60 for minutes, row ÷ 12 for hours) scrolls the neighbouring drum's ScrollPosition by one row with a timed curve.",
            "三个 ScrollView，使用按步长吸附的 ScrollTargetBehavior；各行用 visualEffect 做滚筒弯曲和放大。onScrollGeometryChange 报告每个滚筒当前的行；圈数变化（分钟是行号 ÷ 60，小时是行号 ÷ 12）时，用定时曲线把相邻滚筒的 ScrollPosition 滚动一行。"
        ),
        apis: ["ScrollTargetBehavior", "ScrollPosition", "onScrollGeometryChange", "visualEffect", "rotation3DEffect", "LazyVStack"],
        tags: ["time picker", "wheel", "alarm", "drum", "linked", "时间选择器", "滚轮", "闹钟", "滚筒", "联动"],
        params: [
            .slider("curve", L("Drum curvature", "滚筒弯曲"), 0...75, default: 55, step: 1, decimals: 0, unit: "°"),
            .slider("magnify", L("Band magnification", "选择带放大"), 1.0...1.4, default: 1.18),
            .toggle("link", L("Carry between wheels", "滚轮联动进位"), default: true),
        ]
    ) { ctx in
        ScrollTimeColumnsDemo(ctx: ctx)
    }
}

private let scrollTimeRow: CGFloat = 38
private let scrollTimeViewport: CGFloat = 190
private let scrollTimeLaps = 60
/// 7:56 AM: a few minutes before the hour, so a short roll shows the carry.
private let scrollTimeStartMinute = scrollTimeLaps / 2 * 60 + 56
private let scrollTimeStartHour = scrollTimeLaps / 2 * 12 + 7

private struct ScrollTimeColumnsDemo: View {
    let ctx: DemoContext
    @State private var minuteRow = scrollTimeStartMinute
    @State private var hourRow = scrollTimeStartHour
    @State private var periodRow = 0
    @State private var minutePosition = ScrollPosition(edge: .top)
    @State private var hourPosition = ScrollPosition(edge: .top)
    @State private var periodPosition = ScrollPosition(edge: .top)
    /// Where the hour and period drums are headed (a carry can arrive while one is still moving).
    @State private var hourGoal = scrollTimeStartHour
    @State private var periodGoal = 0
    /// While a scripted roll of a drum is in flight its goal is authoritative; afterwards the goal
    /// follows whatever row the drum shows (a finger or a tap moved it).
    @State private var hourBusyUntil = Date.distantPast
    @State private var periodBusyUntil = Date.distantPast
    /// True while a finger (or its fling) drives a drum; scripted rolls stay silent.
    @State private var userDriven = false
    @State private var step = 0

    private var link: Bool { ctx.bool("link") }

    var body: some View {
        VStack(spacing: 14) {
            ScrollTimeReadout(hour: hourRow % 12, minute: minuteRow % 60, pm: periodRow == 1, language: ctx.language)
            wheels
            DemoHint(text: L("Roll the minutes past :59", "把分钟滚过 59 试试"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoStep() }
    }

    private var wheels: some View {
        let curve = ctx["curve"]
        let magnify = ctx.cg("magnify")
        return HStack(spacing: 0) {
            ScrollTimeDrum(
                rows: scrollTimeLaps * 12,
                startRow: scrollTimeStartHour,
                current: hourRow,
                curve: curve,
                magnify: magnify,
                position: $hourPosition,
                label: { row in String(row % 12 == 0 ? 12 : row % 12) },
                onRow: { old, new in hourChanged(from: old, to: new) },
                onPhase: { driven in userDriven = driven }
            )
            .frame(width: 70)
            Text(verbatim: ":")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 10)
                .offset(y: -2)
            ScrollTimeDrum(
                rows: scrollTimeLaps * 60,
                startRow: scrollTimeStartMinute,
                current: minuteRow,
                curve: curve,
                magnify: magnify,
                position: $minutePosition,
                label: { row in String(format: "%02d", row % 60) },
                onRow: { old, new in minuteChanged(from: old, to: new) },
                onPhase: { driven in userDriven = driven }
            )
            .frame(width: 70)
            ScrollTimeDrum(
                rows: 2,
                startRow: 0,
                current: periodRow,
                curve: curve,
                magnify: magnify,
                position: $periodPosition,
                label: { row in
                    if ctx.language == .zh { return row == 0 ? "上午" : "下午" }
                    return row == 0 ? "AM" : "PM"
                },
                onRow: { _, new in
                    periodRow = new
                    if Date() > periodBusyUntil { periodGoal = new }
                    tick()
                },
                onPhase: { driven in userDriven = driven }
            )
            .frame(width: 74)
        }
        .frame(height: scrollTimeViewport)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.24),
                    .init(color: .black, location: 0.76),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        // Behind the masked drums, so the band keeps its own rounded ends.
        .background { ScrollTimeBand() }
    }

    // MARK: Linkage

    private func tick() {
        if !ctx.isPreview && userDriven { Haptics.selection() }
    }

    private func minuteChanged(from old: Int, to new: Int) {
        minuteRow = new
        tick()
        // The jump to the starting row on appearance is not a roll.
        guard link, abs(new - old) < 30 else { return }
        let carry = floorDiv(new, 60) - floorDiv(old, 60)
        guard carry != 0 else { return }
        hourBusyUntil = Date().addingTimeInterval(0.35)
        hourGoal = (hourGoal + carry).clamped(to: 0...(scrollTimeLaps * 12 - 1))
        withAnimation(.easeOut(duration: 0.3)) {
            hourPosition.scrollTo(y: CGFloat(hourGoal) * scrollTimeRow)
        }
    }

    private func hourChanged(from old: Int, to new: Int) {
        hourRow = new
        if Date() > hourBusyUntil { hourGoal = new }
        tick()
        guard link, abs(new - old) < 6 else { return }
        // 11 → 12 (and back) is where the lap changes: the period flips there.
        let laps = floorDiv(new, 12) - floorDiv(old, 12)
        guard laps % 2 != 0 else { return }
        periodBusyUntil = Date().addingTimeInterval(0.35)
        periodGoal = 1 - periodGoal
        withAnimation(.easeOut(duration: 0.3)) {
            periodPosition.scrollTo(y: CGFloat(periodGoal) * scrollTimeRow)
        }
    }

    private func floorDiv(_ value: Int, _ divisor: Int) -> Int {
        Int((Double(value) / Double(divisor)).rounded(.down))
    }

    // MARK: Autoplay (rolls the drums through the same scroll positions a finger would)

    private func autoStep() {
        userDriven = false
        switch step % 4 {
        case 0: rollMinutes(by: 7)
        case 1: rollHours(by: 4)
        case 2: rollHours(by: -4)
        default: rollMinutes(by: -7)
        }
        step += 1
    }

    private func rollMinutes(by delta: Int) {
        withAnimation(.easeInOut(duration: 0.95)) {
            minutePosition.scrollTo(y: CGFloat(minuteRow + delta) * scrollTimeRow)
        }
    }

    private func rollHours(by delta: Int) {
        hourBusyUntil = Date().addingTimeInterval(1.0)
        hourGoal += delta
        withAnimation(.easeInOut(duration: 0.95)) {
            hourPosition.scrollTo(y: CGFloat(hourGoal) * scrollTimeRow)
        }
    }
}

// MARK: - Drum

private struct ScrollTimeDrum: View {
    let rows: Int
    let startRow: Int
    let current: Int
    let curve: Double
    let magnify: CGFloat
    @Binding var position: ScrollPosition
    let label: (Int) -> String
    let onRow: (Int, Int) -> Void
    let onPhase: (Bool) -> Void

    var body: some View {
        let pad: CGFloat = (scrollTimeViewport - scrollTimeRow) / 2
        let count = rows
        let tilt = curve
        let lens = magnify
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { i in
                    Text(verbatim: label(i))
                        .font(.system(size: 22, weight: current == i ? .semibold : .regular, design: .rounded).monospacedDigit())
                        .foregroundStyle(current == i ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: scrollTimeRow)
                        .contentShape(Rectangle())
                        .visualEffect { content, proxy in
                            let mid: CGFloat = proxy.frame(in: .scrollView).midY
                            let distance: CGFloat = mid - scrollTimeViewport / 2
                            let t: CGFloat = (distance / (scrollTimeViewport / 2)).clamped(to: -1...1)
                            let inBand: CGFloat = 1 - min(abs(distance) / scrollTimeRow, 1)
                            return content
                                .scaleEffect(1 + (lens - 1) * inBand - abs(t) * 0.1)
                                .rotation3DEffect(.degrees(-Double(t) * tilt), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                                .opacity(1 - Double(abs(t)) * 0.6)
                        }
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.3)) {
                                position.scrollTo(y: CGFloat(i) * scrollTimeRow)
                            }
                        }
                }
            }
            .padding(.vertical, pad)
        }
        .scrollTargetBehavior(ScrollStrideSnap(pitch: scrollTimeRow, axis: .vertical))
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Int.self, of: { geometry in
            let offset = geometry.contentOffset.y + geometry.contentInsets.top
            return Int((offset / scrollTimeRow).rounded()).clamped(to: 0...(count - 1))
        }, action: { oldValue, newValue in
            onRow(oldValue, newValue)
        })
        .onScrollPhaseChange { _, newPhase in
            onPhase(newPhase == .interacting || newPhase == .decelerating || newPhase == .tracking)
        }
        .onAppear { position.scrollTo(y: CGFloat(startRow) * scrollTimeRow) }
        .frame(height: scrollTimeViewport)
    }
}

/// The shared selection band: one glass bar behind all three drums.
private struct ScrollTimeBand: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        return shape
            .fill(Color.primary.opacity(0.07))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .overlay(shape.strokeBorder(Palette.stroke))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .frame(height: scrollTimeRow + 4)
            .padding(.horizontal, -8)
    }
}

/// "7:56 AM · rings in 9 h 56 min", counted from a fixed 10 PM so the demo is deterministic.
private struct ScrollTimeReadout: View {
    /// 0…11, where 0 stands for 12.
    let hour: Int
    let minute: Int
    let pm: Bool
    let language: AppLanguage

    var body: some View {
        let shown = hour == 0 ? 12 : hour
        let total = (hour + (pm ? 12 : 0)) * 60 + minute
        let until = ((total - 22 * 60) % 1440 + 1440) % 1440
        let clock = String(format: "%d:%02d", shown, minute)
        let period = language == .zh ? (pm ? "下午" : "上午") : (pm ? "PM" : "AM")
        let wait = language == .zh
            ? "\(until / 60) 小时 \(until % 60) 分钟后响铃"
            : "rings in \(until / 60) h \(until % 60) min"
        return HStack(spacing: 7) {
            Image(systemName: "alarm.fill")
                .foregroundStyle(Palette.primary)
            Text(verbatim: language == .zh ? period + " " + clock : clock + " " + period)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(verbatim: "·")
                .foregroundStyle(.tertiary)
            Text(verbatim: wait)
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentTransition(.numericText(value: Double(total)))
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .animation(.snappy(duration: 0.3), value: total)
    }
}
