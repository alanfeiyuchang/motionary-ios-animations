import SwiftUI

extension Effect {
    static let gesturesJiggleGrid = Effect(
        id: "gestures.jiggle-grid",
        category: .gestures,
        interaction: .gesture,
        name: L("Jiggle Mode Grid", "抖动编辑网格"),
        summary: L("Long-press an icon grid and every icon starts to jiggle; drag one and the others flow out of its way, then drop it into the gap.", "长按图标网格，所有图标开始抖动；拖起其中一个，其他图标流动着让路，再把它放进空位。"),
        prompt: L(
            "A 4×3 grid of 54 pt rounded app icons. Holding a finger on an icon for 0.4 s enters edit mode with a medium haptic: every icon rocks ±2.2° at 4.2 Hz, each on its own phase and with a 1 pt drift so the grid looks alive, and a grey minus badge pops onto each top-left corner with an overshooting spring. The pressed icon lifts to 1.16× under a deep shadow, stops jiggling and follows the finger. As it passes over another slot, the icons between its old and new slots slide one place over, wrapping across rows, on a spring (response 0.38 s, damping 0.72) with a selection tick. Dropping it springs it into the open slot and the shadow collapses. Tapping a badge shrinks that icon away and the rest close the gap; tapping Done or empty space stops the jiggle. Familiar, lively, forgiving.",
            "4×3的网格里排着54 pt的圆角应用图标。按住某个图标0.4秒进入编辑模式并带一次中等触感：所有图标以±2.2°、4.2 Hz来回晃动，相位各不相同并带1 pt漂移；每个图标左上角以带过冲的弹簧弹出灰色减号角标。被按住的图标放大到1.16倍、投下深阴影、停止抖动并跟随手指。经过别的格位时，新旧格位之间的图标依次挪动一格并可跨行折返，弹簧响应0.38秒、阻尼0.72，伴随选择触感。松手后它弹入空位，阴影收拢。点击角标让图标缩小消失、其余补位；点击“完成”或空白处停止抖动。"
        ),
        implementation: L(
            "Icons are laid out by .position from an order array; reordering mutates the array inside withAnimation so every icon springs to its new slot. One DragGesture on the grid runs a 0.4 s long-press timer, then moves the lifted icon and reinserts it at the slot nearest the finger. A TimelineView, paused outside edit mode, feeds each icon a sine rotation with a hashed phase.",
            "图标依据顺序数组用 .position 布局；重排时在 withAnimation 中修改数组，每个图标便以弹簧移向新格位。网格上的单个 DragGesture 先运行0.4秒的长按计时，随后移动被提起的图标，并把它重新插入离手指最近的格位。TimelineView 在非编辑模式下暂停，编辑时为每个图标提供带哈希相位的正弦旋转。"
        ),
        apis: ["DragGesture", "TimelineView(.animation)", "position", "withAnimation(.spring)", "rotationEffect", "zIndex"],
        tags: ["jiggle", "wiggle", "edit mode", "reorder", "grid", "home screen", "抖动", "编辑模式", "重排", "网格", "主屏幕", "长按"],
        params: [
            .slider("angle", L("Jiggle angle", "抖动角度"), 0.8...5, default: 2.2, decimals: 1, unit: "°"),
            .slider("speed", L("Jiggle rate", "抖动频率"), 2...7, default: 4.2, decimals: 1, unit: "Hz"),
            .slider("response", L("Reflow response", "让位响应"), 0.2...0.7, default: 0.38, unit: "s"),
            .slider("lift", L("Lift scale", "提起缩放"), 1.05...1.35, default: 1.16),
        ]
    ) { ctx in
        JiggleGridDemo(ctx: ctx)
    }
}

private enum IconGrid {
    static let cols = 4
    static let rows = 3
    static let icon: CGFloat = 54
    static let gapX: CGFloat = 18
    static let gapY: CGFloat = 20
    static let inset = CGPoint(x: 18, y: 16)
    static let size = CGSize(width: 306, height: 234)

    static let symbols: [String] = [
        "message.fill", "camera.fill", "map.fill", "music.note",
        "envelope.fill", "calendar", "cloud.sun.fill", "photo.fill",
        "gamecontroller.fill", "heart.fill", "book.fill", "bolt.fill",
    ]
    static let tints: [Color] = [
        Palette.green, Color(hex: 0x5B6070), Palette.sky, Palette.pink,
        Palette.blue, Palette.red, Palette.sky, Palette.amber,
        Palette.violet, Palette.pink, Palette.coral, Palette.indigo,
    ]

    static func centre(_ slot: Int) -> CGPoint {
        let col: CGFloat = CGFloat(slot % cols)
        let row: CGFloat = CGFloat(slot / cols)
        return CGPoint(x: inset.x + col * (icon + gapX) + icon / 2, y: inset.y + row * (icon + gapY) + icon / 2)
    }

    /// The slot whose centre is closest to `point`, among the first `count` slots.
    static func slot(near point: CGPoint, count: Int) -> Int {
        var best = 0
        var bestDistance: CGFloat = .greatestFiniteMagnitude
        for slot in 0..<max(count, 1) {
            let d: CGFloat = GestureMath.distance(centre(slot), point)
            if d < bestDistance {
                best = slot
                bestDistance = d
            }
        }
        return best
    }
}

private struct JiggleGridDemo: View {
    let ctx: DemoContext
    @State private var order: [Int]
    @State private var jiggling: Bool
    @State private var liftedID: Int?
    @State private var liftPoint: CGPoint
    @State private var grabOffset: CGSize = .zero
    @State private var touching = false
    @State private var touchStart: CGPoint = .zero
    @State private var pendingDelete: Int?
    @State private var pendingExit = false
    @State private var pressTimer: Task<Void, Never>?
    @State private var script: Task<Void, Never>?
    @State private var autoStep = 0
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows edit mode with one icon in the air.
        _jiggling = State(initialValue: ctx.isStill)
        _order = State(initialValue: ctx.isStill ? [0, 2, 3, 4, 5, 1, 6, 7, 8, 9, 10, 11] : Array(0..<12))
        _liftedID = State(initialValue: ctx.isStill ? 1 : nil)
        _liftPoint = State(initialValue: CGPoint(x: 132, y: 112))
    }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: !jiggling || ctx.isStill)) { timeline in
                grid(time: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: IconGrid.size.width, height: IconGrid.size.height)
            .contentShape(Rectangle())
            .gesture(drag)

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.0, delay: 0.6) { autoRearrange() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touchUp() }
        }
        .onDisappear {
            pressTimer?.cancel()
            script?.cancel()
        }
    }

    private func grid(time: Double) -> some View {
        let angle: Double = ctx["angle"]
        let speed: Double = ctx["speed"]
        return ZStack(alignment: .topLeading) {
            ForEach(order, id: \.self) { id in
                let slot: Int = order.firstIndex(of: id) ?? 0
                let lifted: Bool = liftedID == id
                let phase: Double = GestureMath.hash(id * 17 + 5) * 2 * .pi
                // Odd and even icons rock in opposite directions, like the real thing.
                let swing: Double = jiggling && !lifted ? sin(time * 2 * .pi * speed + phase) * angle * (id % 2 == 0 ? 1 : -1) : 0
                let drift: CGFloat = jiggling && !lifted ? CGFloat(cos(time * 2 * .pi * speed * 0.5 + phase)) : 0
                GridIcon(id: id, badge: jiggling && !lifted, lifted: lifted, liftScale: ctx.cg("lift"))
                    .rotationEffect(.degrees(swing))
                    .offset(x: drift, y: -drift * 0.6)
                    .position(lifted ? liftPoint : IconGrid.centre(slot))
                    .zIndex(lifted ? 10 : 0)
                    .transition(.scale(scale: 0.1).combined(with: .opacity))
            }
        }
        .frame(width: IconGrid.size.width, height: IconGrid.size.height, alignment: .topLeading)
    }

    private var footer: some View {
        ZStack {
            DemoHint(text: L("Touch and hold an icon, then drag it", "长按一个图标，然后拖动"), ctx: ctx)
                .opacity(jiggling ? 0 : 1)
            if jiggling && !ctx.isPreview {
                Button {
                    exitJiggle()
                } label: {
                    Text(L("Done", "完成"), ctx.language)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(height: 30)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    script?.cancel()
                    touchDown(at: value.startLocation)
                }
                touchMove(to: value.location)
            }
            .onEnded { _ in touchUp() }
    }

    private func icon(at point: CGPoint) -> Int? {
        for (slot, id) in order.enumerated() {
            let c: CGPoint = IconGrid.centre(slot)
            if abs(point.x - c.x) < IconGrid.icon / 2 + 7 && abs(point.y - c.y) < IconGrid.icon / 2 + 8 { return id }
        }
        return nil
    }

    // MARK: Touch handlers (the scripted finger calls the same three)

    private func touchDown(at point: CGPoint) {
        touching = true
        touchStart = point
        pendingDelete = nil
        pendingExit = false
        guard let id = icon(at: point), let slot = order.firstIndex(of: id) else {
            pendingExit = jiggling
            return
        }
        let centre: CGPoint = IconGrid.centre(slot)
        if jiggling {
            let corner = CGPoint(x: centre.x - IconGrid.icon / 2, y: centre.y - IconGrid.icon / 2)
            if GestureMath.distance(point, corner) < 17 {
                pendingDelete = id
            } else {
                lift(id, from: centre, finger: point)
            }
            return
        }
        pressTimer?.cancel()
        pressTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled, touching else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { jiggling = true }
            if !ctx.isPreview { Haptics.tap(.medium) }
            if let current = order.firstIndex(of: id) {
                lift(id, from: IconGrid.centre(current), finger: touchStart)
            }
        }
    }

    private func lift(_ id: Int, from centre: CGPoint, finger: CGPoint) {
        grabOffset = CGSize(width: finger.x - centre.x, height: finger.y - centre.y)
        liftPoint = centre
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { liftedID = id }
    }

    private func touchMove(to point: CGPoint) {
        guard touching else { return }
        guard let id = liftedID else {
            if GestureMath.distance(point, touchStart) > 10 {
                // Moved before the long press fired: not a hold, and not a tap on a badge either.
                pressTimer?.cancel()
                pendingDelete = nil
                pendingExit = false
            }
            return
        }
        let half: CGFloat = IconGrid.icon / 2
        liftPoint = CGPoint(
            x: (point.x - grabOffset.width).clamped(to: half...(IconGrid.size.width - half)),
            y: (point.y - grabOffset.height).clamped(to: half...(IconGrid.size.height - half))
        )
        let target: Int = IconGrid.slot(near: liftPoint, count: order.count)
        guard let current = order.firstIndex(of: id), current != target else { return }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.72)) {
            order.remove(at: current)
            order.insert(id, at: target)
        }
        if !ctx.isPreview { Haptics.selection() }
    }

    private func touchUp() {
        guard touching else { return }
        touching = false
        pressTimer?.cancel()
        if liftedID != nil {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.7)) { liftedID = nil }
            if !ctx.isPreview { Haptics.tap(.soft) }
        } else if let id = pendingDelete {
            remove(id)
        } else if pendingExit {
            exitJiggle()
        }
        pendingDelete = nil
        pendingExit = false
    }

    private func remove(_ id: Int) {
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.78)) {
            order.removeAll { $0 == id }
        }
        if !ctx.isPreview { Haptics.tap(.rigid) }
        guard order.isEmpty else { return }
        // Nothing left to play with: bring the set back.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            guard order.isEmpty else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                order = Array(0..<12)
                jiggling = false
            }
        }
    }

    private func exitJiggle() {
        guard jiggling else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            jiggling = false
            liftedID = nil
        }
        if !ctx.isPreview { Haptics.tap(.light) }
    }

    /// A scripted finger holds an icon until the grid jiggles, carries it to another slot, drops it,
    /// then leaves edit mode.
    private func autoRearrange() {
        guard !touching, liftedID == nil, order.count > 4 else { return }
        if jiggling {
            exitJiggle()
            return
        }
        autoStep += 1
        let moves: [(Int, Int)] = [(1, 10), (7, 0), (4, 11), (9, 2)]
        let move: (Int, Int) = moves[autoStep % moves.count]
        let from: CGPoint = IconGrid.centre(min(move.0, order.count - 1))
        let to: CGPoint = IconGrid.centre(min(move.1, order.count - 1))
        let control = CGPoint(x: (from.x + to.x) / 2 + 30, y: (from.y + to.y) / 2 - 20)
        script?.cancel()
        script = Task { @MainActor in
            touchDown(at: from)
            try? await Task.sleep(for: .seconds(0.62))
            guard !Task.isCancelled else { return }
            let finished = await GhostFinger.drag(from: from, to: to, control: control, duration: 1.0) { point in
                touchMove(to: point)
            }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            touchUp()
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled, !touching else { return }
            exitJiggle()
        }
    }
}

private struct GridIcon: View {
    let id: Int
    let badge: Bool
    let lifted: Bool
    let liftScale: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let tint: Color = IconGrid.tints[id % IconGrid.tints.count]
        shape
            .fill(LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .top, endPoint: .bottom))
            .overlay {
                Image(systemName: IconGrid.symbols[id % IconGrid.symbols.count])
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(shape.strokeBorder(.white.opacity(0.28), lineWidth: 0.7))
            .frame(width: IconGrid.icon, height: IconGrid.icon)
            .shadow(color: .black.opacity(lifted ? 0.34 : 0.14), radius: lifted ? 16 : 4, y: lifted ? 12 : 2)
            .overlay(alignment: .topLeading) {
                ZStack {
                    Circle().fill(Color(hex: 0xC7C9D1))
                    Capsule().fill(Color(hex: 0x2A2C35)).frame(width: 9, height: 2.2)
                }
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                .offset(x: -7, y: -7)
                .scaleEffect(badge ? 1 : 0.01, anchor: .topLeading)
                .opacity(badge ? 1 : 0)
            }
            .scaleEffect(lifted ? liftScale : 1)
    }
}
