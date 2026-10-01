import SwiftUI

extension Effect {
    static let scrollDateStrip = Effect(
        id: "scroll.date-strip",
        category: .scroll,
        interaction: .scroll,
        name: L("Paging Date Strip", "按周翻页日期条"),
        summary: L("A week strip pages under a pill that stays on its weekday; picking a day slides the pill like a worm and the month rolls over.", "按周翻页的日期条：选中胶囊停在同一个星期几上，选日期时像蠕虫一样滑过去，跨月时月份滚动切换。"),
        prompt: L(
            "A calendar header: a large month title, a week-number chip, and a strip of seven day cells (weekday letter, date, event dot). The selected day sits in a gradient pill and its text is white through a mask, so glyphs recolour exactly at the pill's edge. Tapping another day slides the pill there with a worm stretch: the leading edge springs first (response 0.28 s), the trailing edge follows (0.4 s, damping 0.72), so it elongates and snaps back. Swiping pages the strip one week with a spring (0.45 s, damping 0.86) and rubber-bands at the ends; the pill keeps its column and pinches to 88% while dates slide beneath. When the selection crosses into another month, the title rolls vertically in the direction of travel, and the agenda card below blurs into the new day's events.",
            "日历头部：大号月份标题、周数标签，以及七个日期格（星期、日期、事件圆点）组成的日期条。选中的那天位于渐变胶囊内，文字通过遮罩显示为白色，字形恰好在胶囊边缘处变色。点击另一天，胶囊以蠕虫式拉伸滑过去：前沿先弹出（响应0.28秒），后沿随后跟上（0.4秒、阻尼0.72）。左右滑动让日期条以弹簧（0.45秒、阻尼0.86）翻过一周，首尾有橡皮筋阻尼；胶囊留在原来的列上，并在日期从下面滑过时收缩到88%。选中日期跨月时，标题沿移动方向纵向滚动切换，下方日程卡片模糊过渡到新一天。"
        ),
        implementation: L(
            "The strip is an HStack of week pages offset by a page position that a DragGesture scrubs and a spring settles. It is drawn twice: once in normal colours and once in white, masked by the pill, whose leading and trailing edges are two separately animated values. The month title uses an id plus a custom push-like Transition that reads the travel direction when it runs.",
            "日期条是一排周页面组成的 HStack，按页位置做偏移；DragGesture 直接拖动这个位置，松手后由弹簧落定。它被绘制两遍：一遍正常配色，一遍白色并用胶囊做遮罩；胶囊的前沿和后沿是两个分别做动画的数值。月份标题用 id 配合自定义的 push 式 Transition，在转场执行时读取移动方向。"
        ),
        apis: ["DragGesture", "mask(alignment:_:)", "Calendar", "Transition", "contentTransition(.numericText)", "spring(response:dampingFraction:)"],
        tags: ["calendar", "week strip", "date picker", "pill", "paging", "日历", "周视图", "日期选择", "胶囊", "翻页"],
        params: [
            .choice("start", L("Week starts on", "每周起始日"), [L("Monday", "周一"), L("Sunday", "周日")], default: 0),
            .slider("response", L("Pill response", "胶囊响应"), 0.25...0.7, default: 0.4, unit: "s"),
            .toggle("stretch", L("Worm stretch", "蠕虫拉伸"), default: true),
        ]
    ) { ctx in
        ScrollDateStripDemo(ctx: ctx)
    }
}

// MARK: - Calendar model

private struct ScrollDateDay: Hashable {
    let year: Int
    let month: Int
    let day: Int
    /// Days since the anchor day (negative before it); the anchor is "today".
    let serial: Int

    var isToday: Bool { serial == 0 }
    /// Deterministic number of events (0…3) for the agenda; the anchor day has two.
    var eventCount: Int { [2, 1, 3, 2, 0, 1, 3][abs(serial &+ 700) % 7] }
}

private enum ScrollDateModel {
    static let weeksBefore = 6
    static let weekCount = 13

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }()

    /// Wednesday 30 September 2026: its week straddles two months whichever day the week starts on.
    private static let anchor: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 30
        components.hour = 12
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 1_790_769_600)
    }()

    /// Column of the anchor day: Wednesday is column 2 in a Monday week and 3 in a Sunday week.
    static func todayColumn(sundayFirst: Bool) -> Int { sundayFirst ? 3 : 2 }

    static func day(week: Int, column: Int, sundayFirst: Bool) -> ScrollDateDay {
        let serial = (week - weeksBefore) * 7 + column - todayColumn(sundayFirst: sundayFirst)
        let date = calendar.date(byAdding: .day, value: serial, to: anchor) ?? anchor
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return ScrollDateDay(year: parts.year ?? 2026, month: parts.month ?? 9, day: parts.day ?? 30, serial: serial)
    }

    /// ISO-like week number of the page (weeks counted from the anchor's week 40).
    static func weekNumber(_ week: Int) -> Int { 40 + week - weeksBefore }

    static let monthsEN = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    static func monthName(_ month: Int, _ language: AppLanguage) -> String {
        let index = (month - 1).clamped(to: 0...11)
        return language == .zh ? "\(index + 1)月" : monthsEN[index]
    }

    static func weekdayLetter(column: Int, sundayFirst: Bool, _ language: AppLanguage) -> String {
        let en = ["M", "T", "W", "T", "F", "S", "S"]
        let zh = ["一", "二", "三", "四", "五", "六", "日"]
        let index = (column + (sundayFirst ? 6 : 0)) % 7
        return language == .zh ? zh[index] : en[index]
    }

    static let events: [LocalizedText] = [
        L("Design review", "设计评审"), L("Lunch with Noor", "和小诺午餐"), L("Ship build 42", "发布第 42 版"),
        L("Climbing gym", "攀岩馆"), L("Motion study", "动效研究"), L("Call the studio", "给工作室回电"),
        L("Pick up film scans", "取胶片扫描件"),
    ]
}

// MARK: - Demo

private struct ScrollDateStripDemo: View {
    let ctx: DemoContext
    /// Page position in weeks (fractional while dragging or settling).
    @State private var page: CGFloat = CGFloat(ScrollDateModel.weeksBefore)
    @State private var week = ScrollDateModel.weeksBefore
    @State private var column: Int
    /// Leading and trailing edges of the pill, in columns.
    @State private var pillLead: CGFloat
    @State private var pillTrail: CGFloat
    @State private var dragStart: CGFloat?
    @State private var paging = false
    /// +1 when the selection last moved forward in time, −1 backward (title roll direction).
    /// A reference, so the outgoing title's transition reads the direction of the move that removes it
    /// (a value captured in `body` would still be the previous move's).
    @State private var direction = ScrollDateDirection()
    @State private var width: CGFloat = 340
    @State private var step = 0

    private var sundayFirst: Bool { ctx.int("start") == 1 }
    private var stripWidth: CGFloat { max(width - 24, 70) }
    private var cell: CGFloat { stripWidth / 7 }
    private var selected: ScrollDateDay { ScrollDateModel.day(week: week, column: column, sundayFirst: sundayFirst) }

    init(ctx: DemoContext) {
        self.ctx = ctx
        let today = ScrollDateModel.todayColumn(sundayFirst: ctx.int("start") == 1)
        _column = State(initialValue: today)
        _pillLead = State(initialValue: CGFloat(today))
        _pillTrail = State(initialValue: CGFloat(today + 1))
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            strip
            ScrollDateAgenda(day: selected, language: ctx.language)
            DemoHint(text: L("Tap a day · swipe to change week", "点击日期 · 左右滑动换周"), ctx: ctx)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self, of: { proxy in proxy.size.width }, action: { newWidth in
            width = newWidth
        })
        .onChange(of: sundayFirst) {
            // The same date keeps the selection when the first weekday changes.
            let today = ScrollDateModel.todayColumn(sundayFirst: sundayFirst)
            column = today
            pillLead = CGFloat(today)
            pillTrail = CGFloat(today + 1)
            week = ScrollDateModel.weeksBefore
            page = CGFloat(ScrollDateModel.weeksBefore)
        }
        .autoplay(ctx.isPreview, every: 1.25) { autoStep() }
    }

    // MARK: Header

    private var header: some View {
        let day = selected
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: ScrollDateModel.monthName(day.month, ctx.language))
                .font(.system(size: 26, weight: .bold))
                .id(day.month)
                .transition(ScrollDateRoll(direction: direction))
            Text(verbatim: String(day.year))
                .font(.system(size: 26, weight: .regular).monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(day.year)))
            Spacer(minLength: 0)
            Text(verbatim: (ctx.language == .zh ? "第 " : "W") + String(ScrollDateModel.weekNumber(week)) + (ctx.language == .zh ? " 周" : ""))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(week)))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.07), in: Capsule())
        }
        .padding(.leading, 6)
        // The detail stage keeps its Reset button in the top-trailing corner.
        .padding(.trailing, ctx.isPreview ? 6 : 40)
        .clipped()
    }

    // MARK: Strip

    private var strip: some View {
        ZStack(alignment: .leading) {
            pillShape
                .fill(Palette.primaryStrong)
                .shadow(color: Palette.indigo.opacity(0.4), radius: 10, y: 5)
                .frame(width: pillWidth, height: 62)
                .scaleEffect(paging ? 0.88 : 1)
                .offset(x: pillX)
            pages(inverted: false)
            pages(inverted: true)
                .mask(alignment: .leading) {
                    pillShape
                        .frame(width: pillWidth, height: 62)
                        .scaleEffect(paging ? 0.88 : 1)
                        .offset(x: pillX)
                }
                .allowsHitTesting(false)
        }
        .frame(width: stripWidth, height: 70, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(drag)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: paging)
    }

    private var pillShape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
    private var pillWidth: CGFloat { max((pillTrail - pillLead) * cell - 8, 20) }
    private var pillX: CGFloat { pillLead * cell + 4 }

    private func pages(inverted: Bool) -> some View {
        let sundayFirst = self.sundayFirst
        return HStack(spacing: 0) {
            ForEach(0..<ScrollDateModel.weekCount, id: \.self) { w in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { c in
                        ScrollDateCell(
                            day: ScrollDateModel.day(week: w, column: c, sundayFirst: sundayFirst),
                            letter: ScrollDateModel.weekdayLetter(column: c, sundayFirst: sundayFirst, ctx.language),
                            inverted: inverted
                        )
                        .frame(width: cell, height: 70)
                        .contentShape(Rectangle())
                        .onTapGesture { select(column: c, haptic: true) }
                    }
                }
            }
        }
        .offset(x: -page * stripWidth)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let start = dragStart ?? page
                if dragStart == nil {
                    dragStart = start
                    paging = true
                }
                var raw: CGFloat = start - value.translation.width / stripWidth
                // Rubber band past the first and last week.
                let last = CGFloat(ScrollDateModel.weekCount - 1)
                if raw < 0 { raw = -rubberBand(-raw * stripWidth, limit: 90) / stripWidth }
                if raw > last { raw = last + rubberBand((raw - last) * stripWidth, limit: 90) / stripWidth }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { page = raw }
            }
            .onEnded { value in
                let start = dragStart ?? page
                dragStart = nil
                let projected: CGFloat = start - value.predictedEndTranslation.width / stripWidth
                // One week per swipe.
                let target = Int(projected.rounded().clamped(to: (start - 1)...(start + 1)))
                turn(to: target, haptic: true)
            }
    }

    // MARK: Actions (shared by touch and autoplay)

    private func select(column newColumn: Int, haptic: Bool) {
        guard newColumn != column else { return }
        let forward = newColumn > column
        direction.value = forward ? 1 : -1
        if haptic { Haptics.selection() }
        let response = ctx["response"]
        let slow: Animation = .spring(response: response, dampingFraction: 0.72)
        // The edge that leads the move is faster, so the pill stretches and then closes up.
        let fast: Animation = ctx.bool("stretch") ? .spring(response: response * 0.7, dampingFraction: 0.8) : slow
        withAnimation(forward ? fast : slow) { pillTrail = CGFloat(newColumn + 1) }
        withAnimation(forward ? slow : fast) { pillLead = CGFloat(newColumn) }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { column = newColumn }
    }

    private func turn(to target: Int, haptic: Bool) {
        let clamped = target.clamped(to: 0...(ScrollDateModel.weekCount - 1))
        if clamped != week {
            direction.value = clamped > week ? 1 : -1
            if haptic { Haptics.selection() }
        }
        // The pill stays pinched while the dates slide beneath it, then lets go.
        paging = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            page = CGFloat(clamped)
            week = clamped
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            if dragStart == nil { paging = false }
        }
    }

    private func autoStep() {
        let today = ScrollDateModel.todayColumn(sundayFirst: sundayFirst)
        let home = ScrollDateModel.weeksBefore
        switch step % 8 {
        case 0: select(column: min(today + 2, 6), haptic: false)
        case 1: turn(to: home + 1, haptic: false)
        case 2: select(column: 1, haptic: false)
        case 3: turn(to: home, haptic: false)
        case 4: select(column: 0, haptic: false)
        case 5: turn(to: home - 1, haptic: false)
        case 6: select(column: 5, haptic: false)
        default:
            turn(to: home, haptic: false)
            select(column: today, haptic: false)
        }
        step += 1
    }
}

/// Direction of the latest selection move: +1 forward in time, −1 backward.
private final class ScrollDateDirection {
    var value = 1
}

/// The month title's roll: like `.push`, but the edge is read when the transition runs, so the outgoing
/// title always leaves the way the selection just moved (forward: out through the top, in from the bottom).
private struct ScrollDateRoll: Transition {
    let direction: ScrollDateDirection

    func body(content: Content, phase: TransitionPhase) -> some View {
        let sign = CGFloat(direction.value)
        let y: CGFloat = phase == .willAppear ? 30 * sign : (phase == .didDisappear ? -30 * sign : 0)
        return content
            .offset(y: y)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

private struct ScrollDateCell: View {
    let day: ScrollDateDay
    let letter: String
    /// The white copy shown through the pill mask.
    let inverted: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(verbatim: letter)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(inverted ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(.secondary))
            Text(verbatim: String(day.day))
                .font(.system(size: 19, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(numberStyle)
            Circle()
                .fill(inverted ? AnyShapeStyle(Color.white) : AnyShapeStyle(Palette.coral))
                .frame(width: 4, height: 4)
                .opacity(day.eventCount > 0 ? 1 : 0)
        }
    }

    private var numberStyle: AnyShapeStyle {
        if inverted { return AnyShapeStyle(Color.white) }
        return day.isToday ? AnyShapeStyle(Palette.violetText) : AnyShapeStyle(.primary)
    }
}

/// The selected day's events; the card blurs from one day's list into the next.
private struct ScrollDateAgenda: View {
    let day: ScrollDateDay
    let language: AppLanguage

    var body: some View {
        let count = day.eventCount
        VStack(alignment: .leading, spacing: 10) {
            if count == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(Palette.amber)
                    Text(L("Nothing planned", "没有安排"), language)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(0..<count, id: \.self) { i in
                    row(i)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .id(day.serial)
        .transition(.blurReplace)
        .padding(14)
        .demoCard(cornerRadius: 20)
    }

    private func row(_ i: Int) -> some View {
        let seed = abs(day.serial &* 5 &+ i &* 3 &+ day.day)
        let color = Palette.spectrum[seed % Palette.spectrum.count]
        return HStack(spacing: 10) {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 26)
            Text(ScrollDateModel.events[seed % ScrollDateModel.events.count], language)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(verbatim: String(format: "%d:%02d", 9 + (seed % 3) + i * 3, (seed % 2) * 30))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
