import SwiftUI

extension Effect {
    static let showcaseCalendarAgenda = Effect(
        id: "showcase.calendar-agenda",
        category: .showcase,
        interaction: .tap,
        name: L("Day Agenda", "今日日程"),
        summary: L(
            "A day agenda with a creeping now-line; tapping an event expands it in place and squeezes the others to make room.",
            "带“此刻”指示线的日程；点开某个事件就地展开，其余事件被挤窄让位。"
        ),
        prompt: L(
            "A dark agenda widget: a date header and three stacked event blocks, each a tinted rounded rectangle with a colour bar, a title and a time range, its start time in a left gutter. An orange now-line led by a rolling HH:mm pill lies across the list and creeps down continuously, mapped to the clock time inside each block; the block it crosses glows slightly and finished events dim to 55%. Tapping an event grows it in place from 46 pt to 82 pt on a spring (response 0.45 s, damping 0.78) while the other two squeeze to 28 pt, dropping their time line, so the card never changes height. Inside the open block the location, three overlapping avatars and a Join pill fade up 8 pt, 0.08 s late. Tapping it again, or another event, redistributes the heights with the same spring. Calm and orderly.",
            "深色日程组件：日期标题下叠放三个事件块，每块是带色条的着色圆角矩形，写着标题与时段，左侧留一列开始时间。一条由滚动 HH:mm 胶囊领头的橙色“此刻”线横贯列表，按各块内的钟点映射持续下移；它经过的事件块微亮，已结束的降到 55% 不透明度。点击某个事件，它就地从 46pt 长到 82pt（弹簧响应 0.45 秒、阻尼 0.78），另外两块被挤到 28pt 并收起时间行，卡片总高不变。展开的块里，地点、三个叠放头像和“加入”胶囊延迟 0.08 秒上浮 8pt 淡入。再点则按同一弹簧重新分配高度。从容有序。"
        ),
        implementation: L(
            "Row heights are derived from one optional expanded index, so the three frames always sum to the same total and animate together under withAnimation(.spring). The now-line's y is computed from the same heights by mapping minutes piecewise through the rows; a task advances the minutes in half-second linear steps, and numericText rolls the label.",
            "各行高度由一个可选的“展开下标”推导，三行高度之和恒定，并在 withAnimation(.spring) 下一起变化。“此刻”线的 y 由同一组高度按分钟分段映射得出；一个 task 以半秒为步长线性推进分钟数，标签用 numericText 滚动。"
        ),
        apis: ["withAnimation(.spring)", "frame(height:)", "offset", "contentTransition(.numericText)", "task", "transition(.opacity)"],
        tags: ["calendar", "agenda", "schedule", "expand", "accordion", "日历", "日程", "展开", "手风琴", "时间线"],
        params: [
            .slider("response", L("Expand response", "展开响应"), 0.2...0.9, default: 0.45, unit: "s"),
            .slider("damping", L("Expand damping", "展开阻尼"), 0.4...1.0, default: 0.78),
            .slider("speed", L("Clock speed", "时间流速"), 1...20, default: 6, decimals: 0, unit: " min/s"),
        ]
    ) { ctx in
        CalendarAgendaDemo(ctx: ctx)
    }
}

private struct AgendaEvent {
    let title: LocalizedText
    let place: LocalizedText
    let start: Double
    let end: Double
    let color: Color

    static let all: [AgendaEvent] = [
        AgendaEvent(title: L("Design review", "设计评审"), place: L("Studio 2", "二号工作室"), start: 9 * 60 + 30, end: 10 * 60 + 15, color: Color(hex: 0x5AA8FF)),
        AgendaEvent(title: L("Motion sync", "动效同步会"), place: L("Video call", "视频会议"), start: 10 * 60 + 30, end: 11 * 60 + 30, color: Signature.accent),
        AgendaEvent(title: L("Lunch with Mia", "和 Mia 午餐"), place: L("Corner Bistro", "街角小馆"), start: 12 * 60, end: 13 * 60, color: Color(hex: 0xC8F560)),
    ]

    static func clock(_ minutes: Double) -> String {
        let whole = Int(minutes)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

private struct CalendarAgendaDemo: View {
    let ctx: DemoContext
    @State private var expanded: Int?
    @State private var now: Double
    @State private var step = 0

    private let normal: CGFloat = 46
    private let open: CGFloat = 82
    private let squeezed: CGFloat = 28
    private let gap: CGFloat = 6
    private let dayStart: Double = 9 * 60 + 12
    private let dayEnd: Double = 13 * 60 + 12

    init(ctx: DemoContext) {
        self.ctx = ctx
        _expanded = State(initialValue: ctx.isStill ? 1 : nil)
        _now = State(initialValue: ctx.isStill ? 10 * 60 + 52 : 9 * 60 + 40)
    }

    private var zh: Bool { ctx.language == .zh }

    private func height(_ index: Int) -> CGFloat {
        guard let expanded else { return normal }
        return expanded == index ? open : squeezed
    }

    private func top(_ index: Int) -> CGFloat {
        (0..<index).reduce(CGFloat(0)) { $0 + height($1) + gap }
    }

    /// The now-line's y inside the list: linear inside each event, linear across the gaps between them.
    private var nowY: CGFloat {
        let events = AgendaEvent.all
        let total = top(events.count - 1) + height(events.count - 1)
        var previousEnd = dayStart
        var previousBottom: CGFloat = -4
        for (index, event) in events.enumerated() {
            let y = top(index)
            if now < event.start {
                let f = CGFloat((now - previousEnd) / max(event.start - previousEnd, 1))
                return previousBottom + (y - previousBottom) * f
            }
            if now <= event.end {
                return y + height(index) * CGFloat((now - event.start) / (event.end - event.start))
            }
            previousEnd = event.end
            previousBottom = y + height(index)
        }
        let f = CGFloat((now - previousEnd) / max(dayEnd - previousEnd, 1))
        return previousBottom + (total + 4 - previousBottom) * min(f, 1)
    }

    var body: some View {
        StudioScene(hint: L("Tap an event to expand it", "点击事件就地展开"), ctx: ctx) {
            card
        }
        .task(id: ctx["speed"]) {
            guard !ctx.isStill else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                if now >= dayEnd {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { now = dayStart }
                } else {
                    withAnimation(.linear(duration: 0.5)) { now = min(dayEnd, now + ctx["speed"] * 0.5) }
                }
            }
        }
        .autoplay(ctx.isPreview, every: 1.7, delay: 0.8) { autoStep() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            SportEyebrowRow(title: zh ? "今天" : "Today", symbol: "calendar", trailing: zh ? "3 个日程" : "3 events")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "1")
                    .font(Signature.number(30))
                    .foregroundStyle(Color.white)
                Text(verbatim: zh ? "周四 · 十月" : "Thursday · October")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
            }
            list
        }
        .padding(16)
        .frame(width: 292)
        .signatureCard()
    }

    private var list: some View {
        VStack(spacing: gap) {
            ForEach(AgendaEvent.all.indices, id: \.self) { index in
                let event = AgendaEvent.all[index]
                HStack(alignment: .top, spacing: 7) {
                Text(verbatim: AgendaEvent.clock(event.start))
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(now > event.end ? Color.white.opacity(0.3) : Signature.textSecondary)
                    .frame(width: 32, alignment: .trailing)
                    .padding(.top, 8)
                Button {
                    Haptics.tap(.light)
                    toggle(index)
                } label: {
                    AgendaRow(
                        event: event,
                        height: height(index),
                        isOpen: expanded == index,
                        isSqueezed: expanded != nil && expanded != index,
                        live: now >= event.start && now <= event.end,
                        past: now > event.end,
                        language: ctx.language
                    )
                }
                .buttonStyle(SportPressStyle(scale: 0.98, dim: 0.03))
                }
            }
        }
        .overlay(alignment: .topLeading) { nowLine }
    }

    private var nowLine: some View {
        HStack(spacing: 0) {
            Text(verbatim: AgendaEvent.clock(now))
                .font(.system(size: 9, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Signature.ink)
                .contentTransition(.numericText(value: now))
                .frame(width: 36, height: 15)
                .background(Capsule().fill(Signature.accent))
            Rectangle()
                .fill(LinearGradient(colors: [Signature.accent, Signature.accent.opacity(0.25)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
        }
        .shadow(color: Signature.accent.opacity(0.7), radius: 5)
        .frame(height: 15)
        .offset(x: -2, y: nowY - 7.5)
        .allowsHitTesting(false)
    }

    private func toggle(_ index: Int?) {
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            expanded = expanded == index ? nil : index
        }
    }

    private func autoStep() {
        let order: [Int?] = [1, 2, 0, nil]
        let target = order[step % order.count]
        step += 1
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) { expanded = target }
    }
}

private struct AgendaRow: View {
    let event: AgendaEvent
    let height: CGFloat
    let isOpen: Bool
    let isSqueezed: Bool
    let live: Bool
    let past: Bool
    let language: AppLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(event.color)
                .frame(width: 4)
                .padding(.vertical, isSqueezed ? 6 : 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title, language)
                    .font(.system(size: isSqueezed ? 12.5 : 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                if !isSqueezed {
                    Text(verbatim: AgendaEvent.clock(event.start) + " – " + AgendaEvent.clock(event.end))
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(event.color.opacity(0.95))
                        .transition(.opacity)
                }
                if isOpen {
                    details
                        .transition(.asymmetric(
                            insertion: .offset(y: 8).combined(with: .opacity).animation(.easeOut(duration: 0.28).delay(0.08)),
                            removal: .opacity.animation(.easeIn(duration: 0.1))
                        ))
                }
            }
            .padding(.top, isSqueezed ? 6 : 7)
            Spacer(minLength: 0)
            if !isSqueezed {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .padding(.top, 11)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(event.color.opacity(live ? 0.24 : 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(event.color.opacity(isOpen ? 0.55 : (live ? 0.35 : 0)), lineWidth: 1)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(past && !isOpen ? 0.55 : 1)
        .animation(.smooth(duration: 0.3), value: live)
        .animation(.smooth(duration: 0.3), value: past)
    }

    private var details: some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Signature.textSecondary)
            Text(event.place, language)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.8))
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            HStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill([Color(hex: 0xFFB45C), Color(hex: 0x8FC9F0), Color(hex: 0xE58BB8)][index])
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(verbatim: ["M", "J", "K"][index])
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(Signature.ink)
                        )
                        .overlay(Circle().strokeBorder(Signature.card, lineWidth: 1.5))
                }
            }
            Text(verbatim: language == .zh ? "加入" : "Join")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Signature.ink)
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(Capsule().fill(event.color))
        }
        .padding(.top, 6)
        .padding(.trailing, -14)
    }
}
