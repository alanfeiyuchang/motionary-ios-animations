import SwiftUI

extension Effect {
    static let cardsStoryTap = Effect(
        id: "cards.story-tap",
        category: .cards,
        interaction: .tap,
        name: L("Story Tap", "快拍点按"),
        summary: L("Tap the right or left side of a story card: that side dips, the next story pushes in, and holding pauses the progress bar.", "点按快拍卡片的右侧或左侧：那一侧微微下沉，下一条推入画面；按住则暂停进度条。"),
        prompt: L(
            "A 196×284 pt story card with five progress segments along its top; the active one fills linearly over 4 s and then advances by itself. Touching the card pauses the fill at once and dips the touched side 9° into the screen about the vertical centre line (spring, response 0.25 s, damping 0.7), with a soft shade on that side and the shadow sliding the other way. A quick release advances: right goes forward, left goes back. The outgoing image slides 30% away and dims while the new one pushes in from the edge at full width on a spring (response 0.38 s, damping 0.86), and the tilt lets go on a looser spring (damping 0.5), so the card rocks once. Holding longer than 250 ms is a pause instead: the card settles to 97%, the bars and header fade out, and release resumes without advancing.",
            "一张196×284 pt的快拍卡片，顶部有五段进度条；当前一段在4秒内线性填满，然后自动进入下一条。手指一碰，进度立即暂停，被按的一侧绕竖直中线向屏幕内倾斜9°（弹簧响应0.25秒、阻尼0.7），这一侧略微压暗，投影朝另一边滑动。快速松手即切换：右侧前进，左侧后退。旧画面滑走30%并变暗，新画面从边缘整幅推入（响应0.38秒、阻尼0.86）；倾斜以更松的弹簧（阻尼0.5）放开，卡片会晃一下。按住超过250毫秒则只是暂停：卡片缩到97%，进度条和头部信息淡出，松手后继续，不切换。"
        ),
        implementation: L(
            "The segment fill is computed in a TimelineView from a start date that is shifted by the time spent paused, and a task keyed on that date fires the auto-advance. A zero-distance DragGesture reads the touch side and duration; the tilt is a projectionEffect about the centre line, and the two pages are offset inside one clipShape.",
            "进度填充在 TimelineView 中由一个起始时间算出，暂停多久就把起始时间后移多久，并用一个以该时间为键的 task 触发自动切换。零距离 DragGesture 读取触点在哪一侧以及按压时长；倾斜是绕中线的 projectionEffect，两页内容在同一个 clipShape 内偏移。"
        ),
        apis: ["TimelineView", "DragGesture", "projectionEffect", "task(id:)", "clipShape", "spring(response:dampingFraction:)"],
        tags: ["story", "stories", "tap", "progress", "快拍", "故事", "进度条", "点按切换"],
        params: [
            .slider("duration", L("Story duration", "单条时长"), 2...8, default: 4, step: 0.5, decimals: 1, unit: "s"),
            .slider("tilt", L("Tap tilt", "点按倾斜"), 0...16, default: 9, step: 1, decimals: 0, unit: "°"),
            .slider("response", L("Push response", "推入响应"), 0.2...0.7, default: 0.38, unit: "s"),
        ]
    ) { ctx in
        CardsStoryDemo(ctx: ctx)
    }
}

private enum CardsStoryLayout {
    static let size = CGSize(width: 196, height: 284)
    static let count = 5
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 26, style: .continuous) }
}

private struct CardsStoryDemo: View {
    let ctx: DemoContext
    @State private var index: Int
    @State private var previous: Int?
    @State private var direction: CGFloat = 1
    /// 0 → 1 while the new page pushes in.
    @State private var slide: CGFloat = 1
    @State private var started: Date
    @State private var pausedAt: Date?
    /// −1 left side pressed, +1 right side, 0 flat.
    @State private var tilt: CGFloat = 0
    @State private var holding = false
    @State private var touching = false
    @State private var touchSide: CGFloat = 1
    @State private var holdTask: Task<Void, Never>?
    @State private var autoTask: Task<Void, Never>?
    @State private var autoStep = 0
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let now = Date()
        // A still shows the second story part-way through.
        _index = State(initialValue: ctx.isStill ? 1 : 0)
        _started = State(initialValue: ctx.isStill ? now.addingTimeInterval(-0.6 * ctx["duration"]) : now)
        _pausedAt = State(initialValue: ctx.isStill ? now : nil)
    }

    private struct TimerKey: Hashable {
        let index: Int
        let started: Date
        let running: Bool
        let duration: Double
    }

    var body: some View {
        VStack(spacing: 10) {
            card
                .gesture(touch)
            DemoHint(text: L("Tap left or right, hold to pause", "点按左右两侧，按住暂停"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.5, intro: false) { autoTap() }
        .task(id: TimerKey(index: index, started: started, running: pausedAt == nil, duration: ctx["duration"])) {
            guard pausedAt == nil, !ctx.isStill else { return }
            let remaining = ctx["duration"] - Date().timeIntervalSince(started)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            advance(1)
        }
        .onChange(of: pressing) { _, isPressing in
            guard !isPressing else { return }
            // onEnded can arrive just after the gesture state resets, so this fallback waits a tick:
            // by then only a cancelled touch still has something to clean up.
            Task { @MainActor in
                lift(advance: false)
            }
        }
        .onDisappear {
            holdTask?.cancel()
            autoTask?.cancel()
        }
    }

    private var card: some View {
        let size = CardsStoryLayout.size
        let angle = -tilt * ctx.cg("tilt") * .pi / 180
        let plane = CardsPlane3D.hingeY(lineX: size.width / 2, angle: angle)
        return ZStack {
            pages
            sideShade
            chrome
                .opacity(holding ? 0 : 1)
            pauseBadge
        }
        .frame(width: size.width, height: size.height)
        .clipShape(CardsStoryLayout.shape)
        .overlay(CardsStoryLayout.shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .contentShape(Rectangle())
        .projectionEffect(plane.projection(eye: CGPoint(x: size.width / 2, y: size.height / 2), depth: 620))
        .scaleEffect(holding ? 0.97 : 1)
        .shadow(color: .black.opacity(0.24), radius: 16, x: -tilt * 9, y: 12)
    }

    private var pages: some View {
        let size = CardsStoryLayout.size
        return ZStack {
            if let previous {
                CardsDeckFace(index: previous, language: ctx.language, width: size.width, height: size.height)
                    .offset(x: -direction * size.width * 0.3 * slide)
                    .brightness(-0.3 * Double(slide))
            }
            CardsDeckFace(index: index, language: ctx.language, width: size.width, height: size.height)
                .offset(x: direction * size.width * (1 - slide))
                .shadow(color: .black.opacity(0.35), radius: 12)
        }
    }

    /// The pressed side sinks away from the light.
    private var sideShade: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.3), Color.black.opacity(0)],
            startPoint: tilt >= 0 ? .trailing : .leading,
            endPoint: .center
        )
        .opacity(Double(abs(tilt)))
        .allowsHitTesting(false)
    }

    private var chrome: some View {
        VStack(spacing: 9) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: pausedAt != nil)) { timeline in
                CardsStoryBars(index: index, fill: fill(at: timeline.date))
            }
            HStack(spacing: 7) {
                Image(systemName: "airplane")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.25), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1.2))
                Text(L("Wander", "漫游志"), ctx.language)
                    .font(.system(size: 12, weight: .bold))
                Text(verbatim: "2h")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.7)
                Spacer(minLength: 0)
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.top, 12)
        .background(alignment: .top) {
            LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 76)
        }
    }

    private var pauseBadge: some View {
        Image(systemName: "pause.fill")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(Color.black.opacity(0.4), in: Circle())
            .scaleEffect(holding ? 1 : 0.6)
            .opacity(holding ? 1 : 0)
    }

    private func fill(at date: Date) -> CGFloat {
        let now = pausedAt ?? date
        return CGFloat((now.timeIntervalSince(started) / ctx["duration"]).clamped(to: 0...1))
    }

    private var touch: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                guard !touching else { return }
                touching = true
                autoTask?.cancel()
                touchSide = value.startLocation.x < CardsStoryLayout.size.width / 2 ? -1 : 1
                pause()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { tilt = touchSide }
                holdTask?.cancel()
                holdTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.25))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { holding = true }
                    Haptics.tap(.soft)
                }
            }
            .onEnded { _ in lift(advance: true) }
    }

    /// Single end of a touch: a short one is a tap that advances, a long one only resumes.
    private func lift(advance wantsAdvance: Bool) {
        guard touching else { return }
        touching = false
        holdTask?.cancel()
        let wasHolding = holding
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { holding = false }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { tilt = 0 }
        resume()
        if wantsAdvance && !wasHolding {
            Haptics.tap(.light)
            advance(Int(touchSide))
        }
    }

    private func pause() {
        guard pausedAt == nil else { return }
        pausedAt = Date()
    }

    private func resume() {
        guard let paused = pausedAt else { return }
        started = started.addingTimeInterval(Date().timeIntervalSince(paused))
        pausedAt = nil
    }

    private func advance(_ step: Int) {
        let count = CardsStoryLayout.count
        let target = index + step
        started = Date()
        if pausedAt != nil { pausedAt = started }
        // Going back from the first story just restarts it.
        guard target >= 0 else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            previous = index
            direction = step >= 0 ? 1 : -1
            index = target % count
            slide = 0
        }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.86)) { slide = 1 }
    }

    /// Preview: the same press-then-release a finger makes, mostly on the right side.
    private func autoTap() {
        guard !touching else { return }
        let side: CGFloat = autoStep % 4 == 3 ? -1 : 1
        autoStep += 1
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { tilt = side }
        autoTask?.cancel()
        autoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { tilt = 0 }
            advance(Int(side))
        }
    }
}

private struct CardsStoryBars: View {
    let index: Int
    let fill: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<CardsStoryLayout.count, id: \.self) { segment in
                let amount: CGFloat = segment < index ? 1 : (segment == index ? fill : 0)
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.white)
                                .frame(width: proxy.size.width * amount)
                        }
                    }
                    .clipShape(Capsule())
            }
        }
    }
}
