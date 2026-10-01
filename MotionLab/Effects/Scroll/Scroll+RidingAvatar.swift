import SwiftUI

extension Effect {
    static let scrollRidingAvatar = Effect(
        id: "scroll.riding-avatar",
        category: .scroll,
        interaction: .scroll,
        name: L("Riding Avatars Thread", "头像随行的群聊"),
        summary: L("In a group chat each sender's avatar rides the bottom edge alongside its run of bubbles, a date chip floats while you scroll, and your own bubbles shift hue down the screen.", "群聊里每位发言者的头像贴着底边陪着自己那一串气泡走，滚动时日期标签悬浮在顶部，自己的气泡颜色随屏幕位置渐变。"),
        prompt: L(
            "A group chat. Incoming bubbles are grouped per sender, with tight 6 pt corners between bubbles of one run and one 30 pt avatar per run. The avatar does not scroll with its last bubble: while any part of the run crosses the bottom edge it stays pinned 10 pt above that edge, riding alongside the run, and it is only carried away when the run's first bubble pushes it out. Outgoing bubbles take their colour from where they are on screen: the hue rotates up to 40° from top to bottom, so a long thread reads as one gradient sliding under the text. The day label is a frosted chip pinned at the top and pushed off by the next day's chip; it fades out 0.9 s after scrolling stops (0.3 s ease-out) and returns at once on the next touch. All of it is position-driven, with no lag.",
            "群聊界面。收到的消息按发言者成组：同一串气泡之间用 6 pt 小圆角相连，每串只有一个 30 pt 头像。头像不跟着最后一条气泡滚走：只要这一串还有一部分跨在底边上，它就钉在底边上方 10 pt 处陪着走，直到第一条气泡把它顶出去。自己发出的气泡按屏幕位置取色：从上到下色相最多旋转 40°，一长串对话像一整条渐变在文字下面滑动。日期标签是吸在顶部的磨砂小胶囊，会被下一天的标签顶走；停止滚动 0.9 秒后以 0.3 秒缓出淡出，再次触摸立刻回来。一切由位置驱动，紧跟手指，没有延迟。"
        ),
        implementation: L(
            "Each run draws its avatar in a column as tall as the run; a visualEffect reads that column's frame and the scroll view's bounds and offsets it up by the amount it overflows the bottom edge, clamped to the run's height. Outgoing bubbles use visualEffect hueRotation keyed to their midY. Day chips use the same trick against the top edge of their day, and their opacity follows the scroll phase.",
            "每一串消息把头像画在一条和这串消息等高的竖列里；visualEffect 读取这条竖列的位置和滚动视图的边界，把它向上偏移“超出底边的那部分”，并限制在这一串的高度之内。自己发出的气泡用 visualEffect 的 hueRotation，按自身 midY 取值。日期标签用同样的办法贴住所在那一天的顶边，透明度跟随滚动阶段变化。"
        ),
        apis: ["visualEffect", "GeometryProxy.bounds(of:)", "hueRotation", "onScrollPhaseChange", "UnevenRoundedRectangle"],
        tags: ["chat", "messages", "avatar", "sticky", "date chip", "聊天", "消息", "头像", "吸附", "日期标签"],
        params: [
            .toggle("ride", L("Avatars ride", "头像随行"), default: true),
            .slider("hue", L("Hue shift", "色相偏移"), 0...90, default: 40, step: 5, decimals: 0, unit: "°"),
            .slider("delay", L("Chip hide delay", "标签隐藏延迟"), 0.3...2.5, default: 0.9, unit: "s"),
        ]
    ) { ctx in
        ScrollRidingDemo(ctx: ctx)
    }
}

// MARK: - Thread data

private struct ScrollRidingRun {
    /// 0 is the user; 1…3 are the other members.
    let sender: Int
    let lines: [LocalizedText]
}

private struct ScrollRidingDay {
    let label: LocalizedText
    let runs: [ScrollRidingRun]
}

private let scrollRidingMembers: [(name: LocalizedText, initial: LocalizedText, colors: [Color])] = [
    (L("You", "我"), L("Y", "我"), [Palette.blue, Palette.indigo]),
    (L("Noor", "小诺"), L("N", "诺"), [Palette.coral, Palette.pink]),
    (L("Idris", "阿迪"), L("I", "迪"), [Palette.mint, Palette.sky]),
    (L("June", "六月"), L("J", "六"), [Palette.amber, Palette.coral]),
]

private let scrollRidingDays: [ScrollRidingDay] = [
    ScrollRidingDay(label: L("Monday", "周一"), runs: [
        ScrollRidingRun(sender: 1, lines: [
            L("Did anyone look at the build?", "有人看过新版本了吗？"),
            L("The list feels different", "列表的手感变了"),
            L("In a good way I think", "我觉得是变好了"),
        ]),
        ScrollRidingRun(sender: 0, lines: [L("That's the new spring", "那是新调的弹簧"), L("Damping went from 0.9 to 0.78", "阻尼从 0.9 改到了 0.78")]),
        ScrollRidingRun(sender: 2, lines: [
            L("I can tell", "感觉得出来"),
            L("It settles a touch later but it feels alive", "停得稍微晚一点，但是活了"),
        ]),
    ]),
    ScrollRidingDay(label: L("Yesterday", "昨天"), runs: [
        ScrollRidingRun(sender: 3, lines: [
            L("Quick one", "问个小问题"),
            L("Should the date chip stay visible?", "日期标签要一直显示吗？"),
            L("It covers the first message", "它会挡住第一条消息"),
            L("Maybe hide it when idle", "不如停下来就藏起来"),
        ]),
        ScrollRidingRun(sender: 0, lines: [L("Hide after a beat", "停一拍再藏"), L("Bring it back on touch", "一碰就回来")]),
        ScrollRidingRun(sender: 1, lines: [L("Yes please", "就这么办"), L("And keep my avatar next to my wall of text", "还有，让头像陪着我那一大串字")]),
        ScrollRidingRun(sender: 0, lines: [L("Already riding along", "已经在跟着走了")]),
    ]),
    ScrollRidingDay(label: L("Today", "今天"), runs: [
        ScrollRidingRun(sender: 2, lines: [
            L("Shipping at four?", "四点发版？"),
            L("I still need to check dark mode", "我还得看一眼深色模式"),
            L("And the long names", "还有那些很长的名字"),
        ]),
        ScrollRidingRun(sender: 3, lines: [L("Dark mode is clean", "深色模式没问题"), L("I went through every screen", "每个界面我都过了一遍")]),
        ScrollRidingRun(sender: 0, lines: [L("Then four it is", "那就四点"), L("Thanks, all of you", "辛苦各位")]),
        ScrollRidingRun(sender: 1, lines: [L("See you at the launch", "发布会见")]),
    ]),
]

// MARK: - Demo

private struct ScrollRidingDemo: View {
    let ctx: DemoContext
    @State private var position = ScrollPosition(edge: .top)
    /// True once the list has been still for the delay: pinned day chips fade out.
    @State private var chipsHidden = false
    @State private var hideToken = 0
    @State private var down = false

    var body: some View {
        let ride = ctx.bool("ride")
        let hue: Double = ctx["hue"]
        let hidden = chipsHidden
        return ScrollView {
            VStack(spacing: 10) {
                ForEach(scrollRidingDays.indices, id: \.self) { d in
                    VStack(spacing: 10) {
                        // The chip's place in the flow; the chip itself floats in the overlay below.
                        Color.clear.frame(height: scrollRidingChipHeight)
                        ForEach(scrollRidingDays[d].runs.indices, id: \.self) { r in
                            ScrollRidingRunView(run: scrollRidingDays[d].runs[r], ride: ride, hue: hue, language: ctx.language)
                        }
                    }
                    .overlay(alignment: .top) {
                        // A column as tall as the day: the chip sticks to the top edge while any of
                        // the day is on screen and is carried off by the day's last message.
                        Color.clear
                            .frame(maxHeight: .infinity)
                            .overlay(alignment: .top) {
                                ScrollRidingChip(label: scrollRidingDays[d].label, language: ctx.language)
                            }
                            .visualEffect { content, proxy in
                                let frame = proxy.frame(in: .scrollView)
                                let room: CGFloat = max(frame.height - scrollRidingChipHeight, 0)
                                let shift: CGFloat = (2 - frame.minY).clamped(to: 0...room)
                                // Only a chip that is actually pinned hides; one sitting in the flow stays.
                                return content
                                    .offset(y: shift)
                                    .opacity(shift > 0.5 && hidden ? 0 : 1)
                            }
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollPhaseChange { _, newPhase in
            phaseChanged(idle: newPhase == .idle)
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { phaseChanged(idle: true) }
        .autoplay(ctx.isPreview, every: 2.6) {
            down.toggle()
            withAnimation(.easeInOut(duration: 2.0)) {
                position.scrollTo(y: down ? 560 : 0)
            }
        }
    }

    private func phaseChanged(idle: Bool) {
        hideToken += 1
        let token = hideToken
        guard idle else {
            withAnimation(.easeOut(duration: 0.12)) { chipsHidden = false }
            return
        }
        let delay = ctx["delay"]
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard token == hideToken else { return }
            withAnimation(.easeOut(duration: 0.3)) { chipsHidden = true }
        }
    }
}

// MARK: - Pieces

private struct ScrollRidingChip: View {
    let label: LocalizedText
    let language: AppLanguage

    var body: some View {
        Text(label, language)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .demoGlass(Capsule(), material: .regularMaterial)
            .overlay(Capsule().strokeBorder(Palette.stroke))
            .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
            .frame(maxWidth: .infinity)
            .frame(height: scrollRidingChipHeight)
    }
}

private let scrollRidingChipHeight: CGFloat = 32

private let scrollRidingAvatar: CGFloat = 30

private struct ScrollRidingRunView: View {
    let run: ScrollRidingRun
    let ride: Bool
    let hue: Double
    let language: AppLanguage

    var body: some View {
        if run.sender == 0 { outgoing } else { incoming }
    }

    private var outgoing: some View {
        VStack(alignment: .trailing, spacing: 3) {
            ForEach(run.lines.indices, id: \.self) { i in
                Text(run.lines[i], language)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(colors: scrollRidingMembers[0].colors, startPoint: .top, endPoint: .bottom),
                        in: bubbleShape(index: i, mine: true)
                    )
                    .visualEffect { content, proxy in
                        let viewport: CGFloat = max(proxy.bounds(of: .scrollView)?.height ?? 340, 1)
                        let t: CGFloat = (proxy.frame(in: .scrollView).midY / viewport).clamped(to: 0...1)
                        return content.hueRotation(.degrees(Double(t) * hue))
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 54)
    }

    private var incoming: some View {
        let member = scrollRidingMembers[run.sender]
        return VStack(alignment: .leading, spacing: 3) {
            Text(member.name, language)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(member.colors[0])
                .padding(.leading, 12)
            ForEach(run.lines.indices, id: \.self) { i in
                Text(run.lines[i], language)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Palette.elevated, in: bubbleShape(index: i, mine: false))
                    .overlay(bubbleShape(index: i, mine: false).strokeBorder(Palette.stroke))
            }
        }
        .padding(.leading, scrollRidingAvatar + 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 40)
        // A column exactly as tall as the run; the avatar sits at its bottom and the whole column
        // is lifted by however much it overflows the viewport's bottom edge.
        .background(alignment: .leading) {
            Color.clear
                .frame(width: scrollRidingAvatar)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { avatar(member) }
                .visualEffect { content, proxy in
                    guard ride, let bounds = proxy.bounds(of: .scrollView) else { return content.offset(y: 0) }
                    let frame = proxy.frame(in: .scrollView)
                    let overflow: CGFloat = frame.maxY - (bounds.height - 10)
                    let room: CGFloat = max(frame.height - scrollRidingAvatar, 0)
                    return content.offset(y: -overflow.clamped(to: 0...room))
                }
        }
    }

    private func avatar(_ member: (name: LocalizedText, initial: LocalizedText, colors: [Color])) -> some View {
        Circle()
            .fill(LinearGradient(colors: member.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Text(member.initial, language)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: scrollRidingAvatar, height: scrollRidingAvatar)
            .shadow(color: member.colors[0].opacity(0.35), radius: 5, y: 2)
    }

    /// Bubbles of one run are joined on the sender's side by tight corners; the last keeps a small tail corner.
    private func bubbleShape(index: Int, mine: Bool) -> UnevenRoundedRectangle {
        let big: CGFloat = 17
        let tight: CGFloat = 6
        let first = index == 0
        let last = index == run.lines.count - 1
        let top: CGFloat = first ? big : tight
        let bottom: CGFloat = last ? 4 : tight
        return UnevenRoundedRectangle(
            topLeadingRadius: mine ? big : top,
            bottomLeadingRadius: mine ? big : bottom,
            bottomTrailingRadius: mine ? bottom : big,
            topTrailingRadius: mine ? top : big,
            style: .continuous
        )
    }
}
