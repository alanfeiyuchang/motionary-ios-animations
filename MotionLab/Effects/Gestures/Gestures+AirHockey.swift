import SwiftUI

extension Effect {
    static let gesturesAirHockey = Effect(
        id: "gestures.air-hockey",
        category: .gestures,
        interaction: .gesture,
        name: L("Air Hockey", "桌上冰球"),
        summary: L("Strike a gliding puck with a mallet that follows your finger: it rebounds off the rails, an opponent hits back, and goals flash.", "用跟手的击球器撞击滑行的冰球：它在围栏间反弹，对手会回击，进球时球门闪亮。"),
        prompt: L(
            "A 224×292 pt portrait table with a rail, centre line and an 84 pt goal mouth at each end. A 40 pt coral mallet in the lower half tracks the finger almost instantly and carries its velocity; a sky-blue opponent mallet defends the top, limited to 400 pt/s. The 24 pt puck glides on an air cushion (drag 0.35/s), rebounds off the rails with 0.9 restitution and off a mallet with the mallet's velocity added, capped at 1,300 pt/s, leaving a short fading streak. A hit gives a rigid haptic scaled by impact. When the puck slips through a goal mouth, a glow in the scorer's colour floods from that end and fades in 0.5 s, the big score digit bumps to 1.3× and springs back, and the puck is served again from the centre after 0.7 s. Fast, arcade, competitive.",
            "224×292 pt的竖向球桌，带围栏、中线，两端各有84 pt宽的球门。下半场40 pt的珊瑚色击球器几乎无延迟地跟手并带着手指的速度；上半场天蓝色的对手负责防守，速度上限400 pt/s。24 pt的冰球在气垫上滑行（阻力0.35/s），撞围栏以0.9的恢复系数反弹，撞击球器时叠加其速度，上限1300 pt/s，身后拖着渐隐的光痕。击球有与力度相应的硬朗触感。进球时，得分方颜色的辉光从球门漫开并在0.5秒内淡出，比分数字放大到1.3倍再弹回，0.7秒后从中圈重新发球。街机感十足。"
        ),
        implementation: L(
            "A reference-type model integrates the puck in 1/240 s substeps: exponential drag, rail reflections that leave the goal mouths open, and circle collisions against two kinematic mallets whose velocity comes from their own motion. The finger sets the lower mallet's target; a small chase-and-strike routine drives the opponent (and the lower mallet during autoplay). A Canvas draws table, streak, puck, mallets and the goal flash.",
            "引用类型模型以1/240秒子步长推进冰球：指数阻力、留出球门口的围栏反射，以及与两个运动学击球器的圆碰撞（击球器速度取自自身运动）。手指设定下方击球器的目标；一段简单的“追击”逻辑驱动对手（自动演示时也驱动下方击球器）。Canvas 绘制球桌、光痕、冰球、击球器与进球闪光。"
        ),
        apis: ["TimelineView(.animation)", "Canvas", "DragGesture", "GraphicsContext.addFilter(.shadow)", "GraphicsContext.draw(Text)"],
        tags: ["air hockey", "puck", "mallet", "restitution", "goal", "game", "桌上冰球", "冰球", "击球器", "反弹", "进球", "游戏"],
        params: [
            .slider("bounce", L("Rail restitution", "围栏恢复系数"), 0.5...1.0, default: 0.9),
            .slider("drag", L("Puck drag", "冰球阻力"), 0.05...1.5, default: 0.35, unit: "/s"),
            .slider("rival", L("Opponent speed", "对手速度"), 150...700, default: 400, step: 10, decimals: 0, unit: "pt/s"),
        ]
    ) { ctx in
        AirHockeyDemo(ctx: ctx)
    }
}

private enum Hockey {
    static let size = CGSize(width: 224, height: 292)
    static let puck: CGFloat = 12
    static let mallet: CGFloat = 20
    static let goal: CGFloat = 84
    static let corner: CGFloat = 24
    static let top = Color(hex: 0x3AC4FF)
    static let bottom = Color(hex: 0xFF7A5C)
}

private final class AirHockeyModel {
    private(set) var puck = CGPoint(x: Hockey.size.width / 2, y: Hockey.size.height / 2)
    private(set) var puckVelocity = CGVector(dx: 70, dy: 190)
    private(set) var mine = CGPoint(x: Hockey.size.width / 2, y: Hockey.size.height - 54)
    private(set) var rival = CGPoint(x: Hockey.size.width / 2, y: 54)
    private var mineVelocity: CGVector = .zero
    private var rivalVelocity: CGVector = .zero
    private var mineTarget = CGPoint(x: Hockey.size.width / 2, y: Hockey.size.height - 54)
    private(set) var myScore = 0
    private(set) var rivalScore = 0
    /// +1 when the lower player scored (into the top goal), −1 when the opponent did.
    private(set) var flashSide = 0
    private(set) var flashAge: Double = 10
    private(set) var trail: [CGPoint] = []
    private var serveIn: Double = 0
    private var serveToward: CGFloat = 1
    private var serveCount = 0
    private var idle: Double = 0
    private var strikes = 0
    /// After a strike a computer-driven mallet follows through and is slow to get back: that opening is
    /// what lets goals happen.
    private var rivalRecover: Double = 0
    private var mineRecover: Double = 0
    var autopilot = true
    private var autoLimit: CGFloat = 360
    var fingerDown = false
    private var clock = GestureStepClock()
    private let h: CGFloat = 1.0 / 240.0

    func moveMallet(to point: CGPoint) {
        let r: CGFloat = Hockey.mallet
        mineTarget = CGPoint(
            x: point.x.clamped(to: r...(Hockey.size.width - r)),
            y: point.y.clamped(to: (Hockey.size.height / 2 + r)...(Hockey.size.height - r))
        )
    }

    var isSettled: Bool {
        !autopilot && !fingerDown && flashAge > 0.6 && serveIn <= 0 && GestureMath.length(puckVelocity) < 3
            && GestureMath.length(rivalVelocity) < 3 && GestureMath.length(mineVelocity) < 3 && puck.y > Hockey.size.height / 2
    }

    /// Returns the hardest mallet impact of the frame and whether a goal was scored.
    func step(to date: Date, restitution: CGFloat, drag: CGFloat, rivalSpeed: CGFloat) -> (impact: CGFloat, goal: Bool) {
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return (0, false) }
        flashAge += dt
        rivalRecover = max(rivalRecover - dt, 0)
        mineRecover = max(mineRecover - dt, 0)
        var impact: CGFloat = 0
        var goal = false

        if serveIn > 0 {
            serveIn -= dt
            if serveIn <= 0 {
                serveCount += 1
                let sideways: CGFloat = CGFloat(GestureMath.hash(serveCount * 7 + 3) - 0.5) * 220
                puckVelocity = CGVector(dx: sideways, dy: 200 * serveToward)
            }
        }

        let steps: Int = min(max(Int((dt / Double(h)).rounded()), 1), 10)
        for _ in 0..<steps {
            if autopilot && !fingerDown {
                let plan = chase(from: mine, side: 1)
                autoLimit = rivalSpeed * 0.95 * plan.pace
                moveMallet(to: plan.point)
            }
            advanceMine()
            advanceRival(speed: rivalSpeed)
            guard serveIn <= 0 else { continue }
            puckVelocity.dx *= CGFloat(exp(-Double(drag * h)))
            puckVelocity.dy *= CGFloat(exp(-Double(drag * h)))
            puck.x += puckVelocity.dx * h
            puck.y += puckVelocity.dy * h
            let mineHit: CGFloat = strike(mallet: mine, velocity: mineVelocity)
            if mineHit > 0 { mineRecover = 0.55 }
            let rivalHit: CGFloat = strike(mallet: rival, velocity: rivalVelocity)
            if rivalHit > 0 { rivalRecover = 0.55 }
            impact = max(impact, mineHit, rivalHit)
            if rails(restitution: restitution) { goal = true }
        }

        if serveIn <= 0 {
            trail.append(puck)
            if trail.count > 14 { trail.removeFirst() }
        } else if !trail.isEmpty {
            trail.removeFirst()
        }

        // A puck left dead in the opponent's half gets fetched by the chase logic; one that
        // stalls on the centre line is nudged so autoplay never freezes.
        if GestureMath.length(puckVelocity) < 8 && serveIn <= 0 && abs(puck.y - Hockey.size.height / 2) < 14 {
            idle += dt
            if idle > 1.2 {
                idle = 0
                puckVelocity = CGVector(dx: 40, dy: -150)
            }
        } else {
            idle = 0
        }
        return (impact, goal)
    }

    private func advanceMine() {
        let blend: CGFloat = fingerDown ? 0.2 : 1
        let limit: CGFloat = fingerDown ? 4000 : autoLimit * (mineRecover > 0 ? 0.3 : 1)
        var dx: CGFloat = (mineTarget.x - mine.x) * blend
        var dy: CGFloat = (mineTarget.y - mine.y) * blend
        let d: CGFloat = (dx * dx + dy * dy).squareRoot()
        let maxStep: CGFloat = limit * h
        if d > maxStep {
            dx *= maxStep / d
            dy *= maxStep / d
        }
        mine.x += dx
        mine.y += dy
        mineVelocity = CGVector(dx: mineVelocity.dx * 0.8 + dx / h * 0.2, dy: mineVelocity.dy * 0.8 + dy / h * 0.2)
    }

    private func advanceRival(speed: CGFloat) {
        let plan = chase(from: rival, side: -1)
        var dx: CGFloat = plan.point.x - rival.x
        var dy: CGFloat = plan.point.y - rival.y
        let d: CGFloat = (dx * dx + dy * dy).squareRoot()
        let maxStep: CGFloat = speed * plan.pace * (rivalRecover > 0 ? 0.3 : 1) * h
        if d > maxStep {
            dx *= maxStep / d
            dy *= maxStep / d
        }
        let r: CGFloat = Hockey.mallet
        rival.x = (rival.x + dx).clamped(to: r...(Hockey.size.width - r))
        rival.y = (rival.y + dy).clamped(to: r...(Hockey.size.height / 2 - r))
        rivalVelocity = CGVector(dx: rivalVelocity.dx * 0.8 + dx / h * 0.2, dy: rivalVelocity.dy * 0.8 + dy / h * 0.2)
    }

    /// Where a computer-driven mallet wants to be. `side` is −1 for the top half, +1 for the bottom.
    private func chase(from mallet: CGPoint, side: CGFloat) -> (point: CGPoint, pace: CGFloat) {
        let mid: CGFloat = Hockey.size.height / 2
        let homeY: CGFloat = side < 0 ? 46 : Hockey.size.height - 46
        let inHalf: Bool = side < 0 ? puck.y < mid + 6 : puck.y > mid - 6
        let inFront: Bool = side < 0 ? puck.y > mallet.y + 4 : puck.y < mallet.y - 4
        let slow: Bool = GestureMath.length(puckVelocity) < 520
        if inHalf && inFront && slow && serveIn <= 0 {
            // Come at the puck from behind and drive through it toward the far goal.
            // Aim for the side of the goal mouth the defender has left open.
            let keeper: CGPoint = side < 0 ? mine : rival
            let open: CGFloat = keeper.x > Hockey.size.width / 2 ? -1 : 1
            let aim: CGFloat = open * (22 + 12 * CGFloat(GestureMath.hash(strikes * 3 + 1)))
            let target = CGPoint(x: Hockey.size.width / 2 + aim, y: side < 0 ? Hockey.size.height : 0)
            let ax: CGFloat = target.x - puck.x
            let ay: CGFloat = target.y - puck.y
            let al: CGFloat = max((ax * ax + ay * ay).squareRoot(), 1)
            let behind = CGPoint(x: puck.x - ax / al * 26, y: puck.y - ay / al * 26)
            let lined: CGFloat = (puck.x - mallet.x) * ax / al + (puck.y - mallet.y) * ay / al
            let through: Bool = (lined > 16 && GestureMath.distance(mallet, behind) < 22) || lined > 26
            return (through ? puck : behind, 1)
        }
        if inHalf && !inFront {
            // The puck got behind: fall back toward the goal line beside it.
            let dodge: CGFloat = puck.x < Hockey.size.width / 2 ? 34 : -34
            return (CGPoint(x: (puck.x + dodge).clamped(to: 30...(Hockey.size.width - 30)), y: side < 0 ? 24 : Hockey.size.height - 24), 1)
        }
        // Guard the goal from near its middle: shots at the edges of the mouth can get through.
        let centre: CGFloat = Hockey.size.width / 2
        return (CGPoint(x: centre + ((puck.x - centre) * 0.4).clamped(to: -26...26), y: homeY), 0.45)
    }

    private func strike(mallet: CGPoint, velocity: CGVector) -> CGFloat {
        let dx: CGFloat = puck.x - mallet.x
        let dy: CGFloat = puck.y - mallet.y
        let reach: CGFloat = Hockey.puck + Hockey.mallet
        let d2: CGFloat = dx * dx + dy * dy
        guard d2 < reach * reach else { return 0 }
        let d: CGFloat = max(d2.squareRoot(), 0.001)
        let nx: CGFloat = dx / d
        let ny: CGFloat = dy / d
        puck.x = mallet.x + nx * reach
        puck.y = mallet.y + ny * reach
        let approach: CGFloat = (puckVelocity.dx - velocity.dx) * nx + (puckVelocity.dy - velocity.dy) * ny
        guard approach < 0 else { return 0 }
        strikes += 1
        puckVelocity.dx -= 1.9 * approach * nx
        puckVelocity.dy -= 1.9 * approach * ny
        let speed: CGFloat = GestureMath.length(puckVelocity)
        if speed > 1300 {
            puckVelocity.dx *= 1300 / speed
            puckVelocity.dy *= 1300 / speed
        }
        return -approach
    }

    /// Reflects off the rails; returns `true` when the puck left through a goal mouth.
    private func rails(restitution: CGFloat) -> Bool {
        let r: CGFloat = Hockey.puck
        let w: CGFloat = Hockey.size.width
        let hgt: CGFloat = Hockey.size.height
        // Rounded corners: keep the centre inside a circle of radius (corner − r) around the corner centre.
        let c: CGFloat = Hockey.corner
        let cx: CGFloat = puck.x < c ? c : (puck.x > w - c ? w - c : puck.x)
        let cy: CGFloat = puck.y < c ? c : (puck.y > hgt - c ? hgt - c : puck.y)
        if cx != puck.x && cy != puck.y {
            let dx: CGFloat = puck.x - cx
            let dy: CGFloat = puck.y - cy
            let d: CGFloat = (dx * dx + dy * dy).squareRoot()
            let limit: CGFloat = max(c - r, 0)
            if d > limit && d > 0.001 {
                let nx: CGFloat = dx / d
                let ny: CGFloat = dy / d
                puck.x = cx + nx * limit
                puck.y = cy + ny * limit
                let vn: CGFloat = puckVelocity.dx * nx + puckVelocity.dy * ny
                if vn > 0 {
                    puckVelocity.dx -= (1 + restitution) * vn * nx
                    puckVelocity.dy -= (1 + restitution) * vn * ny
                }
            }
            return false
        }
        if puck.x < r {
            puck.x = r
            if puckVelocity.dx < 0 { puckVelocity.dx = -puckVelocity.dx * restitution }
        } else if puck.x > w - r {
            puck.x = w - r
            if puckVelocity.dx > 0 { puckVelocity.dx = -puckVelocity.dx * restitution }
        }
        let inMouth: Bool = abs(puck.x - w / 2) < Hockey.goal / 2 - r * 0.5
        if puck.y < r {
            if inMouth {
                if puck.y < -r {
                    score(side: 1)
                    return true
                }
            } else {
                puck.y = r
                if puckVelocity.dy < 0 { puckVelocity.dy = -puckVelocity.dy * restitution }
            }
        } else if puck.y > hgt - r {
            if inMouth {
                if puck.y > hgt + r {
                    score(side: -1)
                    return true
                }
            } else {
                puck.y = hgt - r
                if puckVelocity.dy > 0 { puckVelocity.dy = -puckVelocity.dy * restitution }
            }
        }
        return false
    }

    private func score(side: Int) {
        if side > 0 { myScore += 1 } else { rivalScore += 1 }
        if myScore > 9 || rivalScore > 9 {
            myScore = side > 0 ? 1 : 0
            rivalScore = side > 0 ? 0 : 1
        }
        flashSide = side
        flashAge = 0
        puck = CGPoint(x: Hockey.size.width / 2, y: Hockey.size.height / 2)
        puckVelocity = .zero
        trail.removeAll()
        serveIn = 0.7
        // Serve toward whoever conceded.
        serveToward = side > 0 ? -1 : 1
    }

    /// Seeds the still thumbnail: a rally in progress.
    func poseStill() {
        puck = CGPoint(x: 142, y: 128)
        trail = (0..<12).map { CGPoint(x: 88 + CGFloat($0) * 4.5, y: 196 - CGFloat($0) * 5.7) }
        mine = CGPoint(x: 80, y: 214)
        rival = CGPoint(x: 128, y: 52)
        myScore = 2
        rivalScore = 1
    }
}

private struct AirHockeyDemo: View {
    let ctx: DemoContext
    @State private var model: AirHockeyModel
    @State private var touching = false
    @State private var grabOffset: CGSize = .zero
    @State private var wake = 0
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = AirHockeyModel()
        if ctx.isStill { model.poseStill() }
        _model = State(initialValue: model)
    }

    var body: some View {
        let bounce = ctx.cg("bounce")
        let drag = ctx.cg("drag")
        let rival = ctx.cg("rival")
        let haptics = !ctx.isPreview
        let shape = RoundedRectangle(cornerRadius: Hockey.corner, style: .continuous)
        VStack(spacing: 10) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let result = ctx.isStill ? (impact: CGFloat(0), goal: false) : model.step(to: date, restitution: bounce, drag: drag, rivalSpeed: rival)
                let _ = haptics ? buzz(impact: result.impact, goal: result.goal) : ()
                AirHockeyCanvas(model: model, tick: date)
            }
            .frame(width: Hockey.size.width, height: Hockey.size.height)
            .clipShape(shape)
            .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
            .contentShape(shape)
            .gesture(dragGesture)

            DemoHint(text: L("Move the lower mallet and strike the puck", "移动下方击球器撞击冰球"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx.params) { wake += 1 }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { touchEnded() }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !touching {
                    touching = true
                    // From the first touch on, the lower mallet belongs to the player.
                    model.autopilot = false
                    model.fingerDown = true
                    let near: Bool = GestureMath.distance(value.startLocation, model.mine) < 46
                    grabOffset = near
                        ? CGSize(width: value.startLocation.x - model.mine.x, height: value.startLocation.y - model.mine.y)
                        : .zero
                }
                model.moveMallet(to: CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
                wake += 1
            }
            .onEnded { _ in touchEnded() }
    }

    private func touchEnded() {
        touching = false
        model.fingerDown = false
        wake += 1
    }

    private func buzz(impact: CGFloat, goal: Bool) {
        if goal {
            gestureAfterFrame { Haptics.success() }
        } else if impact > 120 {
            let hard: Bool = impact > 600
            gestureAfterFrame { Haptics.tap(hard ? .rigid : .light) }
        }
    }
}

private struct AirHockeyCanvas: View {
    let model: AirHockeyModel
    let tick: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark: Bool = colorScheme == .dark
        Canvas { context, size in
            drawTable(&context, size: size, dark: dark)
            drawScores(&context, size: size)
            drawFlash(&context, size: size)
            drawPuck(&context)
            drawMallet(&context, at: model.rival, tint: Hockey.top)
            drawMallet(&context, at: model.mine, tint: Hockey.bottom)
        }
    }

    private func drawTable(_ context: inout GraphicsContext, size: CGSize, dark: Bool) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(dark ? Color(hex: 0x141925) : Color(hex: 0xF5F7FC)))
        let line: Color = dark ? .white.opacity(0.14) : Color(hex: 0x2B3A67).opacity(0.14)
        var marks = Path()
        marks.move(to: CGPoint(x: 0, y: size.height / 2))
        marks.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        marks.addEllipse(in: CGRect(x: size.width / 2 - 34, y: size.height / 2 - 34, width: 68, height: 68))
        marks.move(to: CGPoint(x: size.width / 2 + 56, y: 0))
        marks.addArc(center: CGPoint(x: size.width / 2, y: 0), radius: 56, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        marks.move(to: CGPoint(x: size.width / 2 + 56, y: size.height))
        marks.addArc(center: CGPoint(x: size.width / 2, y: size.height), radius: 56, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        context.stroke(marks, with: .color(line), lineWidth: 2)

        // Rails: the top half in the opponent's colour, the bottom half in the player's.
        let rail = Path(roundedRect: rect.insetBy(dx: 2.5, dy: 2.5), cornerRadius: Hockey.corner - 2.5, style: .continuous)
        context.stroke(rail, with: .linearGradient(
            Gradient(stops: [
                .init(color: Hockey.top, location: 0),
                .init(color: Hockey.top, location: 0.49),
                .init(color: Hockey.bottom, location: 0.51),
                .init(color: Hockey.bottom, location: 1),
            ]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)
        ), lineWidth: 5)

        // Goal mouths: gaps in the rail with a glowing sill.
        let table: Color = dark ? Color(hex: 0x141925) : Color(hex: 0xF5F7FC)
        for (y, tint) in [(CGFloat(2.5), Hockey.top), (size.height - 2.5, Hockey.bottom)] {
            var gap = Path()
            gap.move(to: CGPoint(x: size.width / 2 - Hockey.goal / 2, y: y))
            gap.addLine(to: CGPoint(x: size.width / 2 + Hockey.goal / 2, y: y))
            context.stroke(gap, with: .color(table), lineWidth: 7)
            var sill = context
            sill.addFilter(.blur(radius: 3))
            sill.stroke(gap, with: .color(tint.opacity(0.55)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }

    private func drawScores(_ context: inout GraphicsContext, size: CGSize) {
        let bump: CGFloat = model.flashAge < 0.5 ? 1 + 0.3 * CGFloat(sin(model.flashAge / 0.5 * .pi)) : 1
        let entries: [(Int, CGFloat, Color, Bool)] = [
            (model.rivalScore, size.height / 2 - 30, Hockey.top, model.flashSide < 0),
            (model.myScore, size.height / 2 + 30, Hockey.bottom, model.flashSide > 0),
        ]
        for (value, y, tint, bumped) in entries {
            var layer = context
            layer.translateBy(x: 26, y: y)
            let s: CGFloat = bumped ? bump : 1
            layer.scaleBy(x: s, y: s)
            layer.draw(
                Text(verbatim: "\(value)").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(tint.opacity(0.75)),
                at: .zero
            )
        }
    }

    private func drawFlash(_ context: inout GraphicsContext, size: CGSize) {
        guard model.flashAge < 0.5, model.flashSide != 0 else { return }
        let p: Double = model.flashAge / 0.5
        let tint: Color = model.flashSide > 0 ? Hockey.bottom : Hockey.top
        let origin = CGPoint(x: size.width / 2, y: model.flashSide > 0 ? 0 : size.height)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [tint.opacity(0.75 * (1 - p)), tint.opacity(0)]),
            center: origin,
            startRadius: 0,
            endRadius: 110 + 190 * CGFloat(p)
        ))
    }

    private func drawPuck(_ context: inout GraphicsContext) {
        let trail: [CGPoint] = model.trail
        if trail.count > 2, let tail = trail.first, let head = trail.last, GestureMath.distance(tail, head) > 2 {
            // One stroke that fades toward its tail.
            var streak = Path()
            streak.move(to: tail)
            for point in trail.dropFirst() { streak.addLine(to: point) }
            context.stroke(
                streak,
                with: .linearGradient(
                    Gradient(colors: [Palette.mint.opacity(0), Palette.mint.opacity(0.55)]),
                    startPoint: tail,
                    endPoint: head
                ),
                style: StrokeStyle(lineWidth: Hockey.puck * 1.25, lineCap: .round, lineJoin: .round)
            )
        }
        let r: CGFloat = Hockey.puck
        let rect = CGRect(x: model.puck.x - r, y: model.puck.y - r, width: r * 2, height: r * 2)
        var layer = context
        layer.addFilter(.shadow(color: Palette.mint.opacity(0.7), radius: 6))
        layer.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0x10C9A0)))
        context.fill(Path(ellipseIn: rect.insetBy(dx: 3.5, dy: 3.5)), with: .color(Color(hex: 0x7BF0D2)))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.6)), lineWidth: 1)
    }

    private func drawMallet(_ context: inout GraphicsContext, at p: CGPoint, tint: Color) {
        let r: CGFloat = Hockey.mallet
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        var layer = context
        layer.addFilter(.shadow(color: .black.opacity(0.32), radius: 5, y: 4))
        layer.fill(Path(ellipseIn: rect), with: .color(tint))
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [.white.opacity(0.45), .white.opacity(0), .black.opacity(0.22)]),
            center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.4),
            startRadius: 0,
            endRadius: r * 1.6
        ))
        let knob = rect.insetBy(dx: r * 0.45, dy: r * 0.45)
        context.fill(Path(ellipseIn: knob), with: .color(.white.opacity(0.9)))
        context.fill(Path(ellipseIn: knob.insetBy(dx: 3, dy: 3)), with: .color(tint))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.5)), lineWidth: 1)
    }
}
