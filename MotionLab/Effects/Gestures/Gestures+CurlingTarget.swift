import SwiftUI

extension Effect {
    static let gesturesCurlingTarget = Effect(
        id: "gestures.curling-target",
        category: .gestures,
        interaction: .gesture,
        name: L("Curling Target", "冰壶靶心"),
        summary: L("Slide a heavy stone down the ice: friction slows it, it curls with its spin, knocks other stones, and the ring it stops in lights up.", "把沉甸甸的冰壶推上冰面：摩擦让它减速，自旋让它走弧线，还能撞开别的壶，停在哪一环，哪一环就亮起。"),
        prompt: L(
            "A 300×262 pt ice sheet seen from above: a three-ring house (72, 50 and 28 pt radii, blue, white, red) on the right, a red hog line at x = 96 and a granite stone with a coral handle waiting on the left. Dragging the stone carries it; releasing, or crossing the hog line, launches it at 38% of the finger's speed, so it feels heavy. It decelerates at a constant 200 pt/s², rotates with the spin the release gave it and drifts sideways along that spin (the curl), leaving a faint scratch on the ice. Stones collide as equal masses with 0.85 restitution. When everything rests, the ring under the last stone flashes and ripples outward for 0.6 s, a \"+3\" pops up above the stone and the total rolls; after four stones the sheet clears. Weighty, quiet, precise.",
            "俯视的300×262 pt冰道：右侧是三环大本营（半径72、50、28 pt，蓝、白、红），x=96处一条红色前掷线，左侧一只带珊瑚色手柄的花岗岩冰壶待发。拖动冰壶即带着它走；松手或越过前掷线时，以手指速度的38%出手，显得沉甸甸的。它以恒定的200 pt/s²减速，带着出手时的自旋转动并顺着旋向侧向漂移，在冰面留下淡淡划痕。冰壶之间按等质量碰撞，恢复系数0.85。全部停稳后，最后一壶所在的环闪亮并向外荡开0.6秒，壶上方弹出“+3”，总分滚动更新；投完四壶后冰面清空。"
        ),
        implementation: L(
            "A reference-type model steps every stone with constant-deceleration friction, a sideways curl acceleration that follows the spin, equal-mass circle collisions and soft side walls in 1/240 s substeps. Once all stones rest it scores them by distance to the button, lights that ring and spawns the next stone. A Canvas draws the ice, house, trails, stones and score pops.",
            "引用类型模型以1/240秒子步长推进每只冰壶：恒定减速度的摩擦、随自旋方向的侧向弧线加速度、等质量圆碰撞与柔性侧壁。全部静止后按到圆心的距离计分，点亮对应的环并生成下一壶。Canvas 绘制冰面、大本营、划痕、冰壶与得分提示。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture.Value.velocity", "GraphicsContext.draw(Text)", "contentTransition(.numericText)"],
        tags: ["curling", "friction", "slide", "target", "score", "collision", "冰壶", "摩擦", "滑行", "靶心", "得分", "碰撞"],
        params: [
            .slider("friction", L("Ice friction", "冰面摩擦"), 100...500, default: 200, step: 10, decimals: 0, unit: "pt/s²"),
            .slider("curl", L("Curl", "弧线"), 0...80, default: 26, step: 2, decimals: 0),
            .slider("bounce", L("Stone restitution", "碰撞恢复系数"), 0.3...1.0, default: 0.85),
            .slider("stones", L("Stones per end", "每局壶数"), 2...6, default: 4, step: 1, decimals: 0),
        ]
    ) { ctx in
        CurlingDemo(ctx: ctx)
    }
}

private enum Rink {
    static let size = CGSize(width: 300, height: 262)
    static let house = CGPoint(x: 212, y: 131)
    static let rings: [CGFloat] = [72, 50, 28]
    static let hog: CGFloat = 96
    static let hack = CGPoint(x: 44, y: 131)
    static let stone: CGFloat = 15
    static let weight: CGFloat = 0.38
}

private struct CurlStone {
    var position: CGPoint
    var velocity: CGVector = .zero
    var angle: Double = 0
    var spin: Double = 0
    var thrown = false
    var age: Double = 0
    var trail: [CGPoint] = []
    var tint: Int
}

private struct ScorePop {
    var at: CGPoint
    var value: Int
    var age: Double = 0
}

private final class CurlingModel {
    private(set) var stones: [CurlStone] = []
    private(set) var heldIndex: Int?
    private(set) var readyIndex: Int?
    private(set) var score = 0
    private(set) var thrownCount = 0
    private(set) var litRing: Int?
    private(set) var litAge: Double = 10
    private(set) var pops: [ScorePop] = []
    private(set) var clearing: Double?
    private var awaitingScore = false
    private var spawnDelay: Double = 0
    private var lastSample: (point: CGPoint, time: Date)?
    private var tracked: CGVector = .zero
    private var clock = GestureStepClock()
    private let h: CGFloat = 1.0 / 240.0

    init() {
        spawn()
    }

    var isSettled: Bool {
        heldIndex == nil && !awaitingScore && clearing == nil && litAge > 0.9 && pops.isEmpty && spawnDelay <= 0
            && stones.allSatisfy { $0.age > 0.6 }
    }

    private func spawn() {
        stones.append(CurlStone(position: Rink.hack, tint: thrownCount % 2))
        readyIndex = stones.count - 1
    }

    func canGrab(at point: CGPoint) -> Bool {
        guard let index = readyIndex, clearing == nil else { return false }
        return GestureMath.distance(stones[index].position, point) < Rink.stone + 22
    }

    func grab(at date: Date) {
        guard let index = readyIndex else { return }
        heldIndex = index
        tracked = .zero
        lastSample = (stones[index].position, date)
    }

    /// Returns `true` when the stone crossed the hog line and left the hand.
    func move(to point: CGPoint, at date: Date) -> Bool {
        guard let index = heldIndex else { return false }
        let r: CGFloat = Rink.stone
        let p = CGPoint(x: max(point.x, r + 4), y: point.y.clamped(to: (r + 4)...(Rink.size.height - r - 4)))
        if let last = lastSample {
            let dt: Double = date.timeIntervalSince(last.time)
            if dt > 0.004 {
                let vx: CGFloat = (p.x - last.point.x) / CGFloat(dt)
                let vy: CGFloat = (p.y - last.point.y) / CGFloat(dt)
                tracked = CGVector(dx: tracked.dx * 0.5 + vx * 0.5, dy: tracked.dy * 0.5 + vy * 0.5)
                lastSample = (p, date)
            }
        }
        stones[index].position = p
        if p.x >= Rink.hog {
            release(velocity: tracked)
            return true
        }
        return false
    }

    /// `velocity` is the finger's; the stone leaves with `Rink.weight` of it.
    func release(velocity: CGVector) {
        guard let index = heldIndex else { return }
        heldIndex = nil
        let v = CGVector(dx: velocity.dx * Rink.weight, dy: velocity.dy * Rink.weight)
        let speed: CGFloat = GestureMath.length(v)
        guard speed > 40, v.dx > 0 else {
            // Not a throw: slide back to the hack.
            stones[index].velocity = .zero
            stones[index].position = Rink.hack
            return
        }
        let capped: CGFloat = min(speed, 520) / speed
        stones[index].velocity = CGVector(dx: v.dx * capped, dy: v.dy * capped)
        // Sideways motion at release turns the handle; a straight push still gets a slow turn.
        let turn: Double = Double(v.dy) / 40
        stones[index].spin = abs(turn) < 0.8 ? (turn < 0 ? -1.4 : 1.4) : turn.clamped(to: -5...5)
        stones[index].thrown = true
        stones[index].age = 0
        readyIndex = nil
        thrownCount += 1
        awaitingScore = true
    }

    /// The speed a finger needs for the stone to stop `distance` away.
    static func fingerSpeed(toTravel distance: CGFloat, friction: CGFloat) -> CGFloat {
        (2 * friction * max(distance, 0)).squareRoot() / Rink.weight
    }

    func step(to date: Date, friction: CGFloat, curl: CGFloat, restitution: CGFloat, perEnd: Int) -> CGFloat {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return 0 }
        litAge += dt
        for index in pops.indices { pops[index].age += dt }
        pops.removeAll { $0.age > 1.3 }
        for index in stones.indices { stones[index].age += dt }

        var hardest: CGFloat = 0
        let steps: Int = min(max(Int((dt / Double(h)).rounded()), 1), 10)
        for _ in 0..<steps { hardest = max(hardest, integrate(friction: friction, curl: curl, restitution: restitution)) }
        for index in stones.indices where stones[index].thrown {
            let moving: Bool = GestureMath.length(stones[index].velocity) > 4
            if moving {
                stones[index].trail.append(stones[index].position)
                if stones[index].trail.count > 46 { stones[index].trail.removeFirst() }
            } else if !stones[index].trail.isEmpty {
                stones[index].trail.removeFirst(min(2, stones[index].trail.count))
            }
        }
        stones.removeAll { $0.thrown && $0.position.x - Rink.stone > Rink.size.width + 8 }

        if let remaining = clearing {
            clearing = remaining - dt
            if remaining - dt <= 0 {
                clearing = nil
                stones.removeAll()
                score = 0
                thrownCount = 0
                litRing = nil
                spawn()
            }
            return hardest
        }

        let allResting: Bool = stones.allSatisfy { GestureMath.length($0.velocity) < 1 }
        if awaitingScore && allResting {
            awaitingScore = false
            evaluate()
            spawnDelay = 0.45
        }
        if spawnDelay > 0 {
            spawnDelay -= dt
            if spawnDelay <= 0 {
                if thrownCount >= perEnd {
                    clearing = 1.7
                } else {
                    spawn()
                }
            }
        }
        return hardest
    }

    private func ring(of stone: CurlStone) -> Int? {
        let d: CGFloat = GestureMath.distance(stone.position, Rink.house)
        var best: Int?
        for (index, radius) in Rink.rings.enumerated() where d <= radius + 5 { best = index }
        return best
    }

    private func evaluate() {
        var total = 0
        for stone in stones where stone.thrown {
            if let ring = ring(of: stone) { total += ring + 1 }
        }
        score = total
        // The stone thrown last is the newest in the list.
        if let last = stones.last(where: { $0.thrown }), let ring = ring(of: last) {
            litRing = ring
            litAge = 0
            pops.append(ScorePop(at: last.position, value: ring + 1))
        } else {
            litRing = nil
        }
    }

    private func integrate(friction: CGFloat, curl: CGFloat, restitution: CGFloat) -> CGFloat {
        var hardest: CGFloat = 0
        for index in stones.indices where index != heldIndex {
            var v: CGVector = stones[index].velocity
            let speed: CGFloat = GestureMath.length(v)
            if speed > 0 {
                let drop: CGFloat = friction * h
                if speed <= drop {
                    v = .zero
                } else {
                    let nx: CGFloat = v.dx / speed
                    let ny: CGFloat = v.dy / speed
                    // The curl grows as the stone slows, like real ice.
                    let side: CGFloat = curl * CGFloat(stones[index].spin > 0 ? 1 : -1) * (1.3 - min(speed / 400, 1))
                    v.dx += (-nx * friction - ny * side) * h
                    v.dy += (-ny * friction + nx * side) * h
                }
            }
            stones[index].velocity = v
            stones[index].position.x += v.dx * h
            stones[index].position.y += v.dy * h
            let turning: Double = speed > 1 ? stones[index].spin : 0
            stones[index].angle += turning * Double(h)

            let r: CGFloat = Rink.stone
            if stones[index].position.y < r + 3 {
                stones[index].position.y = r + 3
                if v.dy < 0 { stones[index].velocity.dy = -v.dy * 0.4 }
            } else if stones[index].position.y > Rink.size.height - r - 3 {
                stones[index].position.y = Rink.size.height - r - 3
                if v.dy > 0 { stones[index].velocity.dy = -v.dy * 0.4 }
            }
        }

        let count: Int = stones.count
        guard count > 1 else { return hardest }
        for a in 0..<(count - 1) {
            for b in (a + 1)..<count {
                if a == heldIndex || b == heldIndex { continue }
                if !stones[a].thrown || !stones[b].thrown { continue }
                let dx: CGFloat = stones[b].position.x - stones[a].position.x
                let dy: CGFloat = stones[b].position.y - stones[a].position.y
                let d2: CGFloat = dx * dx + dy * dy
                let reach: CGFloat = Rink.stone * 2
                guard d2 < reach * reach, d2 > 0.0001 else { continue }
                let d: CGFloat = d2.squareRoot()
                let nx: CGFloat = dx / d
                let ny: CGFloat = dy / d
                let overlap: CGFloat = (reach - d) / 2
                stones[a].position.x -= nx * overlap
                stones[a].position.y -= ny * overlap
                stones[b].position.x += nx * overlap
                stones[b].position.y += ny * overlap
                let approach: CGFloat = (stones[b].velocity.dx - stones[a].velocity.dx) * nx + (stones[b].velocity.dy - stones[a].velocity.dy) * ny
                guard approach < 0 else { continue }
                let j: CGFloat = -(1 + restitution) * approach / 2
                stones[a].velocity.dx -= j * nx
                stones[a].velocity.dy -= j * ny
                stones[b].velocity.dx += j * nx
                stones[b].velocity.dy += j * ny
                if abs(stones[b].spin) < 0.5 { stones[b].spin = -stones[a].spin * 0.6 }
                hardest = max(hardest, -approach)
            }
        }
        return hardest
    }

    /// Seeds the still thumbnail: three stones in play and the red ring lit.
    func poseStill() {
        stones = [
            CurlStone(position: CGPoint(x: 196, y: 120), angle: 0.6, thrown: true, age: 5, tint: 0),
            CurlStone(position: CGPoint(x: 246, y: 176), angle: 2.1, thrown: true, age: 5, tint: 1),
            CurlStone(position: CGPoint(x: 168, y: 190), angle: -0.9, thrown: true, age: 5, tint: 0),
        ]
        thrownCount = 3
        score = 6
        litRing = 2
        litAge = 0.2
        pops = [ScorePop(at: CGPoint(x: 196, y: 120), value: 3, age: 0.35)]
        stones.append(CurlStone(position: Rink.hack, age: 5, tint: 1))
        readyIndex = stones.count - 1
    }
}

private struct CurlingDemo: View {
    let ctx: DemoContext
    @State private var model: CurlingModel
    @State private var touching = false
    @State private var grabOffset: CGSize = .zero
    @State private var userTouched = false
    @State private var wake = 0
    @State private var autoStep = 0
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = CurlingModel()
        if ctx.isStill { model.poseStill() }
        _model = State(initialValue: model)
    }

    var body: some View {
        let friction = ctx.cg("friction")
        let curl = ctx.cg("curl")
        let bounce = ctx.cg("bounce")
        let perEnd = ctx.int("stones")
        let haptics = !ctx.isPreview && userTouched
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let hit: CGFloat = ctx.isStill ? 0 : model.step(to: date, friction: friction, curl: curl, restitution: bounce, perEnd: perEnd)
                let _ = hit > 60 && haptics ? gestureAfterFrame { Haptics.tap(.rigid) } : ()
                CurlingCanvas(model: model, tick: date)
                    .overlay(alignment: .bottomLeading) {
                        CurlingScore(score: model.score, left: max(perEnd - model.thrownCount, 0), language: ctx.language)
                            .padding(10)
                    }
            }
            .frame(width: Rink.size.width, height: Rink.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
            .contentShape(Rectangle())
            .gesture(drag)

            DemoHint(text: L("Slide the stone toward the rings", "把冰壶推向圆环"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.9, delay: 0.5) { autoThrow() }
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touchEnded(velocity: .zero) }
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    touching = true
                    userTouched = true
                    script?.cancel()
                    if model.heldIndex != nil { model.release(velocity: .zero) }
                    if model.canGrab(at: value.startLocation), let index = model.readyIndex {
                        let centre = model.stones[index].position
                        grabOffset = CGSize(width: value.startLocation.x - centre.x, height: value.startLocation.y - centre.y)
                        model.grab(at: value.time)
                        Haptics.tap(.light)
                    }
                }
                touchMoved(to: CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height), at: value.time)
            }
            .onEnded { value in
                touchEnded(velocity: CGVector(dx: value.velocity.width, dy: value.velocity.height))
            }
    }

    private func touchMoved(to point: CGPoint, at date: Date) {
        if model.move(to: point, at: date) && !ctx.isPreview { Haptics.tap(.soft) }
        wake += 1
    }

    private func touchEnded(velocity: CGVector) {
        touching = false
        guard model.heldIndex != nil else { return }
        model.release(velocity: velocity)
        wake += 1
    }

    /// A scripted finger pushes the waiting stone and lets go with the speed that reaches the house.
    private func autoThrow() {
        guard !touching, model.heldIndex == nil, model.readyIndex != nil else { return }
        autoStep += 1
        let aimY: CGFloat = Rink.house.y + CGFloat(GestureMath.hash(autoStep * 5 + 2) - 0.5) * 70
        let extra: CGFloat = CGFloat(GestureMath.hash(autoStep * 11 + 7) - 0.45) * 60
        let end = CGPoint(x: 86, y: Rink.hack.y + (aimY - Rink.hack.y) * 0.3)
        let friction: CGFloat = ctx.cg("friction")
        script?.cancel()
        script = Task { @MainActor in
            model.grab(at: Date())
            let finished = await GhostFinger.drag(from: Rink.hack, to: end, duration: 0.5) { point in
                touchMoved(to: point, at: Date())
            }
            guard finished, !touching else {
                if !touching { touchEnded(velocity: .zero) }
                return
            }
            let dx: CGFloat = Rink.house.x - end.x + extra
            let dy: CGFloat = aimY - end.y
            let distance: CGFloat = (dx * dx + dy * dy).squareRoot()
            let speed: CGFloat = CurlingModel.fingerSpeed(toTravel: distance, friction: friction)
            touchEnded(velocity: CGVector(dx: dx / distance * speed, dy: dy / distance * speed))
        }
    }
}

private struct CurlingScore: View {
    let score: Int
    let left: Int
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 7) {
            Text(L("Score", "得分"), language)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: "\(score)")
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(value: Double(score)))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: score)
            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { index in
                    if index < left {
                        Circle().fill(Palette.coral).frame(width: 5, height: 5)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .demoGlass(Capsule(), material: .regularMaterial)
    }
}

private struct CurlingCanvas: View {
    let model: CurlingModel
    let tick: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark: Bool = colorScheme == .dark
        Canvas { context, size in
            drawIce(&context, size: size, dark: dark)
            drawTrails(&context, dark: dark)
            let fade: Double = model.clearing.map { min(max($0 / 0.5, 0), 1) } ?? 1
            context.drawLayer { layer in
                layer.opacity = fade
                layer.addFilter(.shadow(color: .black.opacity(0.3), radius: 4, y: 3))
                for (index, stone) in model.stones.enumerated() {
                    drawStone(&layer, stone, held: index == model.heldIndex)
                }
            }
            drawPops(&context)
        }
    }

    private func drawIce(_ context: inout GraphicsContext, size: CGSize, dark: Bool) {
        let ice: Color = dark ? Color(hex: 0x1F2A3A) : Color(hex: 0xEDF4FB)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ice))
        // Pebbled sheen.
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [.white.opacity(dark ? 0.05 : 0.6), .white.opacity(0)]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width * 0.7, y: size.height)
        ))

        let tints: [Color] = dark
            ? [Color(hex: 0x3D5FCC), Color(hex: 0x2B3950), Color(hex: 0xD9475A)]
            : [Color(hex: 0x5C86FF), .white, Color(hex: 0xFF5C6C)]
        let lit: Double = model.litRing == nil ? 0 : max(1 - model.litAge / 0.6, 0)
        for (index, radius) in Rink.rings.enumerated() {
            let rect = CGRect(x: Rink.house.x - radius, y: Rink.house.y - radius, width: radius * 2, height: radius * 2)
            let isLit: Bool = model.litRing == index
            context.fill(Path(ellipseIn: rect), with: .color(tints[index]))
            if isLit {
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.55 * lit)))
            }
        }
        let button = CGRect(x: Rink.house.x - 9, y: Rink.house.y - 9, width: 18, height: 18)
        context.fill(Path(ellipseIn: button), with: .color(dark ? Color(hex: 0x2B3950) : .white))

        if let ring = model.litRing, model.litAge < 0.6 {
            // A ripple leaving the lit ring.
            let p: CGFloat = CGFloat(model.litAge / 0.6)
            let eased: CGFloat = 1 - (1 - p) * (1 - p)
            let radius: CGFloat = Rink.rings[ring] + 26 * eased
            let rect = CGRect(x: Rink.house.x - radius, y: Rink.house.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(tints[ring == 1 ? 0 : ring].opacity(0.7 * Double(1 - p))), lineWidth: 3 * (1 - p) + 0.5)
        }

        var lines = Path()
        lines.move(to: CGPoint(x: Rink.house.x, y: 0))
        lines.addLine(to: CGPoint(x: Rink.house.x, y: size.height))
        lines.move(to: CGPoint(x: 0, y: Rink.house.y))
        lines.addLine(to: CGPoint(x: size.width, y: Rink.house.y))
        context.stroke(lines, with: .color(.primary.opacity(0.12)), lineWidth: 1)
        var hog = Path()
        hog.move(to: CGPoint(x: Rink.hog, y: 0))
        hog.addLine(to: CGPoint(x: Rink.hog, y: size.height))
        context.stroke(hog, with: .color(Color(hex: 0xFF4D5E).opacity(0.7)), lineWidth: 2.5)
    }

    private func drawTrails(_ context: inout GraphicsContext, dark: Bool) {
        for stone in model.stones where stone.trail.count > 2 {
            var path = Path()
            path.move(to: stone.trail[0])
            for point in stone.trail.dropFirst() { path.addLine(to: point) }
            context.stroke(
                path,
                with: .color(dark ? .white.opacity(0.09) : Color(hex: 0x7C93B5).opacity(0.22)),
                style: StrokeStyle(lineWidth: Rink.stone * 0.9, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawStone(_ context: inout GraphicsContext, _ stone: CurlStone, held: Bool) {
        // New stones scale in with a little overshoot.
        let appear: CGFloat = stone.thrown ? 1 : CGFloat(min(stone.age / 0.3, 1))
        let pop: CGFloat = appear < 1 ? appear * (1.7 - 0.7 * appear) : 1
        let r: CGFloat = Rink.stone * pop * (held ? 1.07 : 1)
        let p: CGPoint = stone.position
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [Color(hex: 0xC9CED8), Color(hex: 0x868C9A), Color(hex: 0x5B6070)]),
            center: CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.35),
            startRadius: 0,
            endRadius: r * 1.5
        ))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(.white.opacity(0.35)), lineWidth: 1)
        let tint: Color = stone.tint == 0 ? Palette.coral : Palette.amber
        let inner: CGFloat = r * 0.62
        context.fill(Path(ellipseIn: CGRect(x: p.x - inner, y: p.y - inner, width: inner * 2, height: inner * 2)), with: .color(tint))
        // The handle shows the spin.
        var handle = context
        handle.translateBy(x: p.x, y: p.y)
        handle.rotate(by: .radians(stone.angle))
        let grip = Path(roundedRect: CGRect(x: -r * 0.52, y: -r * 0.16, width: r * 1.04, height: r * 0.32), cornerRadius: r * 0.16)
        handle.fill(grip, with: .color(.white.opacity(0.92)))
        handle.fill(Path(ellipseIn: CGRect(x: -r * 0.2, y: -r * 0.2, width: r * 0.4, height: r * 0.4)), with: .color(.white))
    }

    private func drawPops(_ context: inout GraphicsContext) {
        for pop in model.pops {
            let t: CGFloat = CGFloat(min(pop.age / 0.35, 1))
            // Springy entrance, then a slow rise and fade.
            let scale: CGFloat = t < 1 ? t * (2.2 - 1.2 * t) : 1
            let rise: CGFloat = 26 + 16 * CGFloat(min(pop.age / 1.3, 1))
            let alpha: Double = pop.age < 0.9 ? 1 : max(1 - (pop.age - 0.9) / 0.4, 0)
            var layer = context
            layer.translateBy(x: pop.at.x, y: pop.at.y - rise)
            layer.scaleBy(x: scale, y: scale)
            layer.opacity = alpha
            let badge = Path(roundedRect: CGRect(x: -17, y: -11, width: 34, height: 22), cornerRadius: 11)
            layer.fill(badge, with: .color(Color(hex: 0x1B1D26).opacity(0.88)))
            layer.draw(
                Text(verbatim: "+\(pop.value)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white),
                at: .zero
            )
        }
    }
}
