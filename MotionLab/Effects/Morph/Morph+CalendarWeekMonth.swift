import SwiftUI

extension Effect {
    static let morphCalendarWeekMonth = Effect(
        id: "morph.calendar-week-month",
        category: .morph,
        interaction: .gesture,
        name: L("Week to Month", "周历展开月历"),
        summary: L(
            "A week strip unfolds into the month like an accordion: the other weeks hinge flat above and below the selected one, which never leaves your sight.",
            "周历条像风琴一样展开成月历：其余几周在选中周的上下翻平，选中的那一周始终留在眼前。"
        ),
        prompt: L(
            "A calendar card showing one week, the selected day in a filled gradient circle, with the day's agenda beneath. Pulling the card down, or tapping its Week/Month pill, unfolds the month like an accordion: the other four weeks are rigid panels folded edge-on above and below the selected week, and each hinges flat, its tilt always the arccosine of how far it has opened, neighbours leaning opposite ways and shaded while tilted. The nearest weeks lead the farthest by a quarter of the travel. The card grows with them on a spring (response 0.5 s, damping 0.8) and overshoots slightly, pushing the agenda down. The drag tracks the finger 1:1 across 152 pt and snaps to the nearer state on release. The selection circle glides between days, and its week anchors the next fold.",
            "一张日历卡片只显示一周，选中的日期套着渐变实心圆，下方是当天日程。向下拉卡片，或点“周 / 月”胶囊，月历像风琴一样展开：其余四周是折起、侧对着你的刚性面板，夹在选中周上下，随后逐一翻平，倾角始终等于展开比例的反余弦，相邻两周朝相反方向倾斜，倾斜时带一层阴影。离得近的周比最远的周领先四分之一个行程。卡片乘弹簧（响应 0.5 秒、阻尼 0.8）随之长高并略微过冲，把日程往下推。拖动在 152pt 行程内 1:1 跟手，松手吸附到较近的状态。选中圆在日期间滑动，它所在的那一周就是下次折叠的锚点。"
        ),
        implementation: L(
            "One progress value, interpolated by an Animatable wrapper, gives every week row a lagged open fraction; rows are stacked by their projected heights (row height × fraction) and tilted with rotation3DEffect by arccos(fraction), so they fold like rigid panels. A vertical UIPanGestureRecognizer maps translation to the same progress.",
            "一个进度值经 Animatable 包装器插值后，为每一周算出带滞后的展开比例；各行按投影高度（行高 × 比例）依次堆叠，并用 rotation3DEffect 倾斜 arccos(比例)，像刚性面板一样折叠。纵向 UIPanGestureRecognizer 把位移映射到同一个进度。"
        ),
        apis: ["Animatable", "rotation3DEffect", "UIGestureRecognizerRepresentable", "spring(response:dampingFraction:)", "mask"],
        tags: ["calendar", "week", "month", "unfold", "日历", "周视图", "月视图", "展开"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("stagger", L("Row stagger", "行错峰"), 0...1, default: 0.5),
            .slider("shade", L("Fold shading", "折叠明暗"), 0...1, default: 0.5),
        ]
    ) { ctx in
        CalendarWeekMonthDemo(ctx: ctx)
    }
}

/// October 2026 (starts on a Thursday), five week rows.
private enum WeekMonth {
    static let leading = 4
    static let rows = 5
    static let rowHeight: CGFloat = 38
    static let gridWidth: CGFloat = 294
    static let cell: CGFloat = gridWidth / 7
    static let today = 8
    static let busy: Set<Int> = [6, 8, 13, 15, 21, 23, 29]
    static let letters: [LocalizedText] = [L("S", "日"), L("M", "一"), L("T", "二"), L("W", "三"), L("T", "四"), L("F", "五"), L("S", "六")]
    static let weekdays: [LocalizedText] = [
        L("Sun", "星期日"), L("Mon", "星期一"), L("Tue", "星期二"), L("Wed", "星期三"),
        L("Thu", "星期四"), L("Fri", "星期五"), L("Sat", "星期六"),
    ]

    static func slot(of day: Int) -> Int { day + leading - 1 }
    static func row(of day: Int) -> Int { slot(of: day) / 7 }
    static func column(of day: Int) -> Int { slot(of: day) % 7 }
    static func day(row: Int, column: Int) -> Int { row * 7 + column - leading + 1 }
}

private struct CalendarWeekMonthDemo: View {
    let ctx: DemoContext
    /// 0 = week strip, 1 = month grid.
    @State private var progress: Double
    @State private var selected = 15
    @State private var dragBase: Double?
    @State private var autoStep = 0

    private static let travel: CGFloat = WeekMonth.rowHeight * CGFloat(WeekMonth.rows - 1)
    private static let autoDays = [23, 6, 29, 15]

    init(ctx: DemoContext) {
        self.ctx = ctx
        _progress = State(initialValue: ctx.isStill ? 1 : 0)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var isMonth: Bool { progress > 0.5 }

    var body: some View {
        VStack(spacing: 10) {
            MorphAnimated(progress) { value in
                WeekMonthScene(
                    progress: CGFloat(value),
                    selected: selected,
                    stagger: ctx.cg("stagger"),
                    shade: ctx.cg("shade"),
                    language: ctx.language,
                    onSelect: select,
                    onToggle: { setMonth(!isMonth) }
                )
            }
            .frame(width: 316, height: 306, alignment: .top)
            .mask {
                LinearGradient(
                    stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            // Pull down to open the month, push up to fold it (the page scroll waits for that direction only).
            .gesture(PageSafePan(directions: isMonth ? .up : .down, onChanged: dragChanged, onEnded: dragEnded))
            DemoHint(
                text: isMonth ? L("Push up to fold, tap a day to select", "向上推收起，点击日期选择") : L("Pull the week down", "向下拉开周历"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5) { autoplayStep() }
    }

    private func dragChanged(_ t: CGSize) {
        let base: Double = dragBase ?? progress
        if dragBase == nil { dragBase = base }
        let raw: Double = base + Double(t.height / Self.travel)
        // 1:1 inside the range, a little rubber past either end.
        let over: Double = raw < 0 ? raw : max(raw - 1, 0)
        progress = min(max(raw, 0), 1) + Double(rubberBand(CGFloat(over) * Self.travel, limit: 18) / Self.travel)
    }

    /// `nil` means the system cancelled the pan: settle on the nearer state.
    private func dragEnded(_ end: PageSafePanEnd?) {
        let base: Double = dragBase ?? progress
        dragBase = nil
        var projected: Double = progress
        if let end { projected = base + Double(end.predictedEndTranslation.height / Self.travel) }
        let month: Bool = projected > 0.5
        if !ctx.isPreview { Haptics.tap(month ? .medium : .light) }
        withAnimation(spring) { progress = month ? 1 : 0 }
    }

    private func setMonth(_ month: Bool) {
        if !ctx.isPreview { Haptics.tap(month ? .medium : .light) }
        withAnimation(spring) { progress = month ? 1 : 0 }
    }

    private func select(_ day: Int) {
        guard day != selected else { return }
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selected = day }
    }

    /// Autoplay: open the month, pick a day in another week, fold onto that week, pick a neighbour.
    private func autoplayStep() {
        switch autoStep % 4 {
        case 0:
            setMonth(true)
        case 1:
            select(Self.autoDays[(autoStep / 4) % Self.autoDays.count])
        case 2:
            setMonth(false)
        default:
            let column: Int = WeekMonth.column(of: selected)
            let shifted: Int = selected + (column < 4 ? 2 : -2)
            select(min(max(shifted, 1), 31))
        }
        autoStep += 1
    }
}

private struct WeekMonthScene: View {
    let progress: CGFloat
    let selected: Int
    let stagger: CGFloat
    let shade: CGFloat
    let language: AppLanguage
    let onSelect: (Int) -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            card
            WeekMonthAgenda(day: selected, language: language)
        }
        .frame(width: 316, height: 306, alignment: .top)
    }

    private var card: some View {
        let surface = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { column in
                    Text(WeekMonth.letters[column], language)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: WeekMonth.cell)
                }
            }
            .frame(height: 20)
            grid
                .frame(width: WeekMonth.gridWidth, height: gridHeight, alignment: .top)
                .clipped()
            Capsule()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 36, height: 5)
                .frame(height: 18)
        }
        .padding(.horizontal, 11)
        .padding(.top, 6)
        .background {
            surface
                .fill(Palette.elevated)
                .overlay(surface.strokeBorder(Palette.stroke))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        }
        .contentShape(surface)
    }

    private var header: some View {
        let month: Bool = progress > 0.5
        return HStack {
            Text(verbatim: language == .zh ? "2026年10月" : "October 2026")
                .font(.system(size: 18, weight: .bold))
            Spacer()
            HStack(spacing: 5) {
                Text(verbatim: month ? (language == .zh ? "月" : "Month") : (language == .zh ? "周" : "Week"))
                    .font(.system(size: 12, weight: .semibold))
                    .id(month)
                    .transition(.blurReplace)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(180 * Double(MorphMath.unit(progress))))
            }
            .foregroundStyle(Palette.indigo)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Palette.indigo.opacity(0.14), in: Capsule())
            .animation(.easeOut(duration: 0.2), value: month)
            .contentShape(Capsule())
            .onTapGesture(perform: onToggle)
        }
        .padding(.horizontal, 6)
        .frame(height: 40)
    }

    /// Progress of one week row: weeks farther from the selected one start later, and all land together.
    private func local(_ distance: Int, farthest: Int) -> CGFloat {
        guard distance > 0, farthest > 0, progress < 1 else { return max(progress, 0) }
        let lag: CGFloat = stagger * 0.5 * CGFloat(distance) / CGFloat(farthest)
        return MorphMath.unit((progress - lag) / (1 - lag))
    }

    /// Top edge and unfolded fraction of every week row. A folded row is a rigid panel seen at an angle, so it
    /// takes `rowHeight × fraction` of height; the selected week is always flat.
    private var slots: [(top: CGFloat, open: CGFloat)] {
        let anchor: Int = WeekMonth.row(of: selected)
        let farthest: Int = max(anchor, WeekMonth.rows - 1 - anchor)
        var result: [(top: CGFloat, open: CGFloat)] = []
        var top: CGFloat = 0
        for row in 0..<WeekMonth.rows {
            let open: CGFloat = row == anchor ? 1 : local(abs(row - anchor), farthest: farthest)
            result.append((top: top, open: open))
            top += WeekMonth.rowHeight * open
        }
        return result
    }

    private var gridHeight: CGFloat {
        slots.reduce(0) { $0 + WeekMonth.rowHeight * $1.open }
    }

    private var grid: some View {
        let anchor: Int = WeekMonth.row(of: selected)
        let layout: [(top: CGFloat, open: CGFloat)] = slots
        return ZStack(alignment: .topLeading) {
            Circle()
                .fill(Palette.primary)
                .shadow(color: Palette.indigo.opacity(0.4), radius: 6, y: 3)
                .frame(width: 32, height: 32)
                .position(
                    x: (CGFloat(WeekMonth.column(of: selected)) + 0.5) * WeekMonth.cell,
                    y: layout[anchor].top + WeekMonth.rowHeight / 2
                )
            ForEach(0..<WeekMonth.rows, id: \.self) { row in
                let open: CGFloat = layout[row].open
                let flat: CGFloat = MorphMath.unit(open)
                // Accordion: the panel's projected height is rowHeight × cos(tilt), and neighbours tilt opposite ways.
                let tilt: Double = acos(Double(flat)) * 180 / .pi
                let forward: Bool = abs(row - anchor) % 2 == 1
                WeekMonthRow(row: row, selected: selected, language: language, onSelect: onSelect)
                    .overlay {
                        Rectangle()
                            .fill(Color.black.opacity(Double(shade) * 0.5 * Double(1 - flat) * (forward ? 1 : 0.4)))
                            .allowsHitTesting(false)
                    }
                    .rotation3DEffect(.degrees(forward ? -tilt : tilt), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.35)
                    .opacity(row == anchor ? 1 : Double(MorphMath.smooth(open, 0.02, 0.4)))
                    .offset(y: layout[row].top)
                    .allowsHitTesting(row == anchor || open > 0.6)
            }
        }
    }
}

private struct WeekMonthRow: View {
    let row: Int
    let selected: Int
    let language: AppLanguage
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { column in
                cell(WeekMonth.day(row: row, column: column))
                    .frame(width: WeekMonth.cell, height: WeekMonth.rowHeight)
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: Int) -> some View {
        if day < 1 {
            Text(verbatim: "\(30 + day)")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        } else {
            let isSelected: Bool = day == selected
            let isToday: Bool = day == WeekMonth.today
            VStack(spacing: 2) {
                Text(verbatim: "\(day)")
                    .font(.system(size: 15, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : (isToday ? AnyShapeStyle(Palette.indigo) : AnyShapeStyle(Color.primary)))
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.9) : Palette.pink)
                    .frame(width: 4, height: 4)
                    .opacity(WeekMonth.busy.contains(day) ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onSelect(day) }
        }
    }
}

/// The selected day's agenda under the calendar; it is pushed down as the month opens.
private struct WeekMonthAgenda: View {
    let day: Int
    let language: AppLanguage

    private struct Item {
        let time: String
        let title: LocalizedText
        let color: Color
    }

    private static let pool: [Item] = [
        Item(time: "09:30", title: L("Design review", "设计评审"), color: Palette.violet),
        Item(time: "13:00", title: L("Ship build 2.4", "发布 2.4 版本"), color: Palette.sky),
        Item(time: "18:30", title: L("Pottery class", "陶艺课"), color: Palette.coral),
        Item(time: "10:00", title: L("Sprint planning", "迭代计划会"), color: Palette.indigo),
        Item(time: "19:00", title: L("Climbing gym", "攀岩"), color: Palette.mint),
        Item(time: "12:30", title: L("Lunch with Maya", "和知夏吃午饭"), color: Palette.amber),
    ]

    var body: some View {
        let weekday: LocalizedText = WeekMonth.weekdays[WeekMonth.column(of: day)]
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: language == .zh ? "10月\(day)日 \(weekday.zh)" : "\(weekday.en), Oct \(day)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .padding(.leading, 6)
            ForEach(0..<2, id: \.self) { index in
                let item: Item = Self.pool[(day * 2 + index * 3) % Self.pool.count]
                HStack(spacing: 10) {
                    Capsule()
                        .fill(item.color)
                        .frame(width: 4, height: 26)
                    Text(item.title, language)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(verbatim: item.time)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(item.color)
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(item.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .id(day * 10 + index)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .frame(width: 316, alignment: .leading)
    }
}
