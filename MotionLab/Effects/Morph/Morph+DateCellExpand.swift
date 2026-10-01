import SwiftUI

extension Effect {
    static let morphDateCellExpand = Effect(
        id: "morph.date-cell-expand",
        category: .morph,
        interaction: .tap,
        name: L("Date Cell Expand", "日期格展开"),
        summary: L(
            "A calendar day swells into its event sheet, the date numeral flying up to become the title, then folds back into its cell.",
            "日历上的一天膨胀为日程面板，日期数字飞到顶部变成标题，再收回自己的格子。"
        ),
        prompt: L(
            "A month grid of 40 pt day tiles with 12 pt corners; days with events carry a tint and coloured dots. Tapping a day grows that very tile into an event sheet covering the month (26 pt corners) on one spring (response 0.5 s, damping 0.8). Its numeral travels from the cell's centre to the top-left corner while scaling from 15 pt to 46 pt, so the date itself becomes the title. The weekday fades in beside it, then the event rows rise 12 pt out of a blur, 70 ms apart, each with a colour bar, time and place. Behind, the month recedes to 94%, blurs 3 pt and dims to half. Closing shrinks the sheet back into the exact cell it came from. Spatial and precise: you always know which day you are in.",
            "月视图由 40pt、圆角 12pt 的日期方块组成，有日程的日子带一层色调和彩色圆点。点某一天，这块方块本身乘一条弹簧（响应 0.5 秒、阻尼 0.8）长成盖住整月的日程面板（26pt 圆角）。日期数字从格子中央飞到左上角，同时从 15pt 放大到 46pt，日期自己变成了标题。星期在旁边淡入，随后日程行从模糊中上浮 12pt，相隔 70 毫秒依次出现，每行带色条、时间和地点。身后的月历缩到 94%、模糊 3pt、压暗一半。关闭时面板精准缩回它出发的那一格。空间感明确：你始终知道自己在哪一天。"
        ),
        implementation: L(
            "The tapped tile is swapped for the sheet; tile background and sheet surface share one matchedGeometryEffect id and the two numerals share another, so frame and position interpolate while the font cross-fades. Event rows use a delayed appear modifier.",
            "被点的方块替换为面板；方块底色与面板底板共享一个 matchedGeometryEffect ID，两个日期数字共享另一个，外框与位置插值、字号交叉淡变。日程行用带延迟的出现修饰符错峰入场。"
        ),
        apis: ["matchedGeometryEffect", "@Namespace", "spring(response:dampingFraction:)", "blur(radius:)", "zIndex"],
        tags: ["calendar", "date", "event", "expand", "日历", "日期", "日程", "展开"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("stagger", L("Row stagger", "行错峰"), 0...0.2, default: 0.07, unit: "s"),
            .toggle("recede", L("Recede the month", "月历后退"), default: true),
        ]
    ) { ctx in
        DateCellExpandDemo(ctx: ctx)
    }
}

private struct DateEvent {
    let time: String
    let title: LocalizedText
    let place: LocalizedText
    let color: Color
}

/// October 2026 (starts on a Thursday).
private enum DateMonth {
    static let leading = 4
    static let today = 8
    static let weekdays: [LocalizedText] = [
        L("Sunday", "星期日"), L("Monday", "星期一"), L("Tuesday", "星期二"), L("Wednesday", "星期三"),
        L("Thursday", "星期四"), L("Friday", "星期五"), L("Saturday", "星期六"),
    ]
    static let letters: [LocalizedText] = [L("S", "日"), L("M", "一"), L("T", "二"), L("W", "三"), L("T", "四"), L("F", "五"), L("S", "六")]

    static let events: [Int: [DateEvent]] = [
        6: [DateEvent(time: "18:30", title: L("Pottery class", "陶艺课"), place: L("Clay Studio", "泥巴工作室"), color: Palette.coral)],
        8: [
            DateEvent(time: "10:00", title: L("Sprint planning", "迭代计划会"), place: L("Room 3A", "三楼会议室"), color: Palette.indigo),
            DateEvent(time: "19:00", title: L("Climbing gym", "攀岩"), place: L("Vertical World", "岩时攀岩馆"), color: Palette.mint),
        ],
        13: [DateEvent(time: "12:30", title: L("Lunch with Maya", "和知夏吃午饭"), place: L("Noodle bar", "面馆"), color: Palette.amber)],
        15: [
            DateEvent(time: "09:30", title: L("Design review", "设计评审"), place: L("Room 3A", "三楼会议室"), color: Palette.violet),
            DateEvent(time: "13:00", title: L("Ship build 2.4", "发布 2.4 版本"), place: L("TestFlight", "TestFlight"), color: Palette.sky),
            DateEvent(time: "20:00", title: L("Film night", "电影之夜"), place: L("Egyptian Theatre", "百老汇影城"), color: Palette.pink),
        ],
        21: [DateEvent(time: "08:00", title: L("Flight to Tokyo", "飞往东京"), place: L("SEA → HND", "西雅图 → 羽田"), color: Palette.blue)],
        23: [
            DateEvent(time: "11:00", title: L("teamLab visit", "teamLab 展览"), place: L("Azabudai Hills", "麻布台之丘"), color: Palette.mint),
            DateEvent(time: "18:00", title: L("Dinner in Shibuya", "涩谷晚餐"), place: L("Izakaya Toki", "居酒屋 时"), color: Palette.coral),
        ],
        29: [DateEvent(time: "15:00", title: L("Dentist", "看牙医"), place: L("Bellevue Dental", "口腔诊所"), color: Palette.red)],
    ]

    static func day(at cell: Int) -> Int { cell - leading + 1 }
    static func weekday(of day: Int) -> Int { (day + leading - 1) % 7 }
}

private struct DateCellExpandDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var selected: Int?
    /// Unmatched sheet content fades out ahead of the collapse, so it never floats outside the shrinking sheet.
    @State private var detail = true
    @State private var autoIndex = 0

    private static let autoDays = [15, 8, 23, 20]

    init(ctx: DemoContext) {
        self.ctx = ctx
        _selected = State(initialValue: ctx.isStill ? 15 : nil)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        let recede: Bool = selected != nil && ctx.bool("recede")
        VStack(spacing: 12) {
            ZStack {
                month
                    .scaleEffect(recede ? 0.94 : 1)
                    .blur(radius: recede ? 3 : 0)
                    .opacity(recede ? 0.5 : 1)
                if let day = selected {
                    DateSheet(day: day, ns: ns, language: ctx.language, stagger: ctx["stagger"], detail: detail, onClose: close)
                        .zIndex(2)
                }
            }
            .frame(width: 316, height: 296)
            DemoHint(
                text: selected == nil ? L("Tap a day", "点击某一天") : L("Tap the sheet to close", "点击面板关闭"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { autoStep() }
    }

    private var month: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: ctx.language == .zh ? "2026年10月" : "October 2026")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
                    .padding(.leading, 14)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .frame(height: 34)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { column in
                    Text(DateMonth.letters[column], ctx.language)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
            }
            VStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { column in
                            cell(DateMonth.day(at: row * 7 + column))
                        }
                    }
                }
            }
        }
        .frame(width: 316, height: 296, alignment: .top)
    }

    @ViewBuilder
    private func cell(_ day: Int) -> some View {
        if day < 1 {
            Text(verbatim: "\(30 + day)")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(width: 40, height: 40)
        } else if selected == day {
            Color.clear.frame(width: 40, height: 40)
        } else {
            DateTile(day: day, ns: ns)
                .onTapGesture { open(day) }
        }
    }

    private func autoStep() {
        if selected == nil {
            open(Self.autoDays[autoIndex % Self.autoDays.count])
            autoIndex += 1
        } else {
            close()
        }
    }

    private func open(_ day: Int) {
        guard selected == nil else { return }
        if !ctx.isPreview { Haptics.tap(.medium) }
        detail = true
        withAnimation(spring) { selected = day }
    }

    private func close() {
        guard selected != nil, detail else { return }
        if !ctx.isPreview { Haptics.tap(.soft) }
        // A view that is being removed no longer updates, so the fade has to start a beat before the collapse.
        withAnimation(.easeOut(duration: 0.12)) { detail = false }
        let collapse: Animation = spring
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.06))
            withAnimation(collapse) { selected = nil }
        }
    }
}

private struct DateTile: View {
    let day: Int
    let ns: Namespace.ID

    var body: some View {
        let events: [DateEvent] = DateMonth.events[day] ?? []
        let today: Bool = day == DateMonth.today
        let tint: Color = events.first?.color ?? Color.primary
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(events.isEmpty ? Color.primary.opacity(0.045) : tint.opacity(0.16))
                .overlay {
                    if today {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.indigo, lineWidth: 1.5)
                    }
                }
                .matchedGeometryEffect(id: "cell\(day)", in: ns)
            Text(verbatim: "\(day)")
                .font(.system(size: 15, weight: today ? .bold : .medium, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize()
                .matchedGeometryEffect(id: "num\(day)", in: ns)
                .offset(y: events.isEmpty ? 0 : -4)
            if !events.isEmpty {
                HStack(spacing: 3) {
                    ForEach(events.indices, id: \.self) { index in
                        Circle()
                            .fill(events[index].color)
                            .frame(width: 4.5, height: 4.5)
                    }
                }
                .offset(y: 11)
            }
        }
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }
}

private struct DateSheet: View {
    let day: Int
    let ns: Namespace.ID
    let language: AppLanguage
    let stagger: Double
    let detail: Bool
    let onClose: () -> Void

    var body: some View {
        let events: [DateEvent] = DateMonth.events[day] ?? []
        let tint: Color = events.first?.color ?? Palette.indigo
        let surface = RoundedRectangle(cornerRadius: 26, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(verbatim: "\(day)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize()
                    .matchedGeometryEffect(id: "num\(day)", in: ns)
                VStack(alignment: .leading, spacing: 1) {
                    Text(DateMonth.weekdays[DateMonth.weekday(of: day)], language)
                        .font(.system(size: 16, weight: .semibold))
                    Text(verbatim: language == .zh ? "2026年10月" : "October 2026")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .modifier(MorphReveal(delay: 0.08, rise: 8))
                .opacity(detail ? 1 : 0)
                Spacer(minLength: 0)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.08), in: Circle())
                    .modifier(MorphReveal(delay: 0.08, rise: 0))
                    .opacity(detail ? 1 : 0)
            }
            .frame(height: 50)
            Group {
                if events.isEmpty {
                    emptyState
                        .modifier(MorphReveal(delay: 0.14, rise: 12))
                } else {
                    ForEach(events.indices, id: \.self) { index in
                        DateEventRow(event: events[index], language: language)
                            .modifier(MorphReveal(delay: 0.14 + stagger * Double(index), rise: 12))
                    }
                }
                Spacer(minLength: 0)
                if !events.isEmpty && events.count < 3 {
                    footer(count: events.count)
                        .modifier(MorphReveal(delay: 0.14 + stagger * Double(events.count), rise: 12))
                }
            }
            .opacity(detail ? 1 : 0)
        }
        .padding(18)
        .frame(width: 316, height: 296, alignment: .topLeading)
        .background {
            surface
                .fill(Palette.elevated)
                .overlay {
                    surface.fill(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)], startPoint: .top, endPoint: .center))
                }
                .overlay(surface.strokeBorder(Palette.stroke))
                .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
                .matchedGeometryEffect(id: "cell\(day)", in: ns)
        }
        .contentShape(surface)
        .onTapGesture(perform: onClose)
    }

    private func footer(count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Palette.indigo)
            Text(verbatim: language == .zh ? "新建日程" : "New event")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.indigo)
            Spacer()
            Text(verbatim: language == .zh ? "共 \(count) 项" : (count == 1 ? "1 event" : "\(count) events"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Palette.primary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: language == .zh ? "这一天还没有安排" : "Nothing planned yet")
                    .font(.system(size: 15, weight: .semibold))
                Text(verbatim: language == .zh ? "新建日程" : "Add an event")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DateEventRow: View {
    let event: DateEvent
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(event.color)
                .frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title, language)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(event.place, language)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(verbatim: event.time)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(event.color)
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
        .background(event.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
