import SwiftUI

extension Effect {
    static let gesturesStickyGoo = Effect(
        id: "gestures.sticky-goo",
        category: .gestures,
        interaction: .gesture,
        name: L("Sticky Goo", "黏液球"),
        summary: L("A slime blob stuck to a wall: pull until its neck snaps, carry it, and it flies to the nearest edge and sticks again.", "黏在墙上的黏液球：拉到颈部崩断后随手带走，松手飞向最近的边并重新黏住。"),
        prompt: L(
            "A 34 pt-radius lime-to-mint slime blob sits pressed against the top wall of a 300×270 pt rounded tray, a flat puddle spreading at its foot. Dragging it stretches a metaball neck from the wall: the head follows the finger on a stiff spring, shrinking up to 18% while the neck thins toward its middle. At 140 pt the neck snaps with a medium haptic; both stubs recoil with a wobble, the residue on the wall drains away, and the freed blob trails the finger with a soft velocity smear. On release it flies on a spring to the nearest wall along its throw direction, lands with a soft haptic, flattens and jiggles to rest (damping 0.4). Released before the snap, it rubber-bands back and wobbles. Sticky, squishy and alive.",
            "一颗半径34 pt、青柠到薄荷渐变的黏液球贴在300×270 pt圆角托盘的上壁，脚下摊开一小片黏液。拖动它，墙面拉出融球状的颈部：头部以较硬的弹簧跟手，最多缩小18%，颈部越往中间越细。拉到140 pt时颈部崩断，一次中等触感；两端残段晃动着缩回，墙上的残留收干，脱离的黏液球跟着手指走，并随速度被轻轻拉长。松手后它顺着甩出的方向以弹簧飞向最近的墙面，落地时柔和触感，压扁、抖动几下后停稳（阻尼0.4）。崩断前松手，则像橡皮筋一样弹回。黏、软、有生命感。"
        ),
        implementation: L(
            "A reference-type model integrates the head, the two neck stubs and the wall residue as springs in 1/120 s substeps inside a TimelineView; a Canvas draws circles along the neck through blur + alphaThreshold filters and is used as the mask of a gradient, so separate circles fuse into one liquid shape.",
            "引用类型模型在 TimelineView 中以 1/120 秒子步长把头部、两段残颈和墙面残留当作弹簧积分；Canvas 沿颈部画出一串圆，经 blur + alphaThreshold 滤镜后作为渐变的遮罩，让分散的圆融合成一整团液体。"
        ),
        apis: ["Canvas", "GraphicsContext.Filter.alphaThreshold", "TimelineView(.animation)", "DragGesture.Value.velocity", "mask"],
        tags: ["goo", "slime", "sticky", "metaball", "snap", "黏液", "史莱姆", "粘性", "融球", "拉断"],
        params: [
            .slider("snap", L("Snap distance", "崩断距离"), 90...200, default: 140, step: 5, decimals: 0, unit: "pt"),
            .slider("size", L("Blob radius", "黏液球半径"), 22...40, default: 34, step: 1, decimals: 0, unit: "pt"),
            .slider("damping", L("Jiggle damping", "抖动阻尼"), 0.15...0.9, default: 0.4),
        ]
    ) { ctx in
        StickyGooDemo(ctx: ctx)
    }
}

private enum GooTray {
    static let size = CGSize(width: 300, height: 270)
    /// Extra canvas around the tray so goo pressed into a wall is blurred from "inside" the wall.
    static let pad: CGFloat = 24
    static let corner: CGFloat = 30
}

private enum GooEvent {
    case snap
    case land
}

private final class StickyGooModel {
    private(set) var anchor = CGPoint(x: 150, y: 0)
    private(set) var normal = CGVector(dx: 0, dy: 1)
    private(set) var head = CGPoint(x: 150, y: 21)
    private(set) var velocity: CGVector = .zero
    /// Connected to `anchor` by goo.
    private(set) var stuck = true
    /// Flying to a wall after a release.
    private(set) var flying = false
    var finger: CGPoint?

    /// Stub left on the wall after a snap.
    private(set) var residueAt = CGPoint.zero
    private(set) var residueNormal = CGVector(dx: 0, dy: 1)
    private(set) var residue: CGFloat = 0
    private(set) var stubDirection = CGVector(dx: 0, dy: 1)
    private(set) var wallStub: CGFloat = 0
    private var wallStubVelocity: CGFloat = 0
    private(set) var headStub: CGFloat = 0
    private var headStubVelocity: CGFloat = 0

    private var clock = GestureStepClock()

    var isSettled: Bool {
        finger == nil && stuck && !flying && GestureMath.length(velocity) < 1
            && GestureMath.distance(head, rest(radius: lastRadius)) < 0.3
            && residue < 0.01 && abs(headStub) < 0.3
    }

    private var lastRadius: CGFloat = 34

    func rest(radius: CGFloat) -> CGPoint {
        CGPoint(x: anchor.x + normal.dx * radius * 0.62, y: anchor.y + normal.dy * radius * 0.62)
    }

    /// 0 at rest, 1 at the snap distance.
    func stretch(snap: CGFloat) -> CGFloat {
        guard stuck else { return 0 }
        return (GestureMath.distance(head, anchor) / max(snap, 1)).clamped(to: 0...1)
    }

    func reset(radius: CGFloat) {
        lastRadius = radius
        if stuck && finger == nil && !flying && GestureMath.length(velocity) < 1 { head = rest(radius: radius) }
    }

    func step(to date: Date, radius: CGFloat, snap: CGFloat, damping: CGFloat) -> [GooEvent] {
        lastRadius = radius
        let dt: Double = clock.delta(to: date)
        guard dt > 0 else { return [] }
        let substeps: Int = max(Int((dt * 120).rounded(.up)), 1)
        let h: CGFloat = CGFloat(dt) / CGFloat(substeps)
        var events: [GooEvent] = []
        for _ in 0..<substeps {
            if let event = integrate(h: h, radius: radius, snap: snap, damping: damping) { events.append(event) }
        }
        return events
    }

    private func integrate(h: CGFloat, radius: CGFloat, snap: CGFloat, damping: CGFloat) -> GooEvent? {
        var event: GooEvent?
        let target: CGPoint
        let stiffness: CGFloat
        let friction: CGFloat
        if let finger {
            target = finger
            stiffness = stuck ? 380 : 520
            friction = stuck ? 30 : 34
        } else {
            target = rest(radius: radius)
            stiffness = flying ? 150 : 260
            friction = flying ? 6 : 2 * damping * stiffness.squareRoot()
        }
        velocity.dx += (stiffness * (target.x - head.x) - friction * velocity.dx) * h
        velocity.dy += (stiffness * (target.y - head.y) - friction * velocity.dy) * h
        head.x += velocity.dx * h
        head.y += velocity.dy * h

        if stuck, finger != nil {
            let d: CGFloat = GestureMath.distance(head, anchor)
            if d > snap {
                stuck = false
                residueAt = anchor
                residueNormal = normal
                residue = 1
                stubDirection = CGVector(dx: (head.x - anchor.x) / d, dy: (head.y - anchor.y) / d)
                wallStub = d * 0.42
                headStub = d * 0.36
                wallStubVelocity = 0
                headStubVelocity = 0
                event = .snap
            }
        }

        if flying {
            let depth: CGFloat = (head.x - anchor.x) * normal.dx + (head.y - anchor.y) * normal.dy
            if depth <= radius * 0.66 {
                flying = false
                stuck = true
                // Stick where it actually touched down.
                let inset: CGFloat = GooTray.corner + radius * 0.6
                if abs(normal.dy) > 0.5 {
                    anchor.x = head.x.clamped(to: inset...(GooTray.size.width - inset))
                } else {
                    anchor.y = head.y.clamped(to: inset...(GooTray.size.height - inset))
                }
                event = .land
            }
        }

        // Stubs recoil like under-damped springs; the wall residue then drains away.
        let k: CGFloat = 320
        let c: CGFloat = 2 * max(damping, 0.2) * k.squareRoot()
        wallStubVelocity += (-k * wallStub - c * wallStubVelocity) * h
        wallStub += wallStubVelocity * h
        headStubVelocity += (-k * headStub - c * headStubVelocity) * h
        headStub += headStubVelocity * h
        if abs(wallStub) < 14 { residue *= CGFloat(exp(-Double(h) * 5)) }
        return event
    }

    func release(velocity releaseVelocity: CGVector, radius: CGFloat) {
        finger = nil
        guard !stuck else { return }
        let vx: CGFloat = releaseVelocity.dx.clamped(to: -2400...2400)
        let vy: CGFloat = releaseVelocity.dy.clamped(to: -2400...2400)
        velocity = CGVector(dx: vx * 0.6, dy: vy * 0.6)
        let aim = CGPoint(x: head.x + vx * 0.22, y: head.y + vy * 0.22)
        let w: CGFloat = GooTray.size.width
        let hgt: CGFloat = GooTray.size.height
        let inset: CGFloat = GooTray.corner + radius * 0.6
        let options: [(CGFloat, CGPoint, CGVector)] = [
            (aim.y, CGPoint(x: aim.x.clamped(to: inset...(w - inset)), y: 0), CGVector(dx: 0, dy: 1)),
            (hgt - aim.y, CGPoint(x: aim.x.clamped(to: inset...(w - inset)), y: hgt), CGVector(dx: 0, dy: -1)),
            (aim.x, CGPoint(x: 0, y: aim.y.clamped(to: inset...(hgt - inset))), CGVector(dx: 1, dy: 0)),
            (w - aim.x, CGPoint(x: w, y: aim.y.clamped(to: inset...(hgt - inset))), CGVector(dx: -1, dy: 0)),
        ]
        guard let best = options.min(by: { $0.0 < $1.0 }) else { return }
        anchor = best.1
        normal = best.2
        flying = true
    }
}

private struct StickyGooDemo: View {
    let ctx: DemoContext
    @State private var model = StickyGooModel()
    @State private var held = false
    @State private var grabOffset: CGSize = .zero
    @State private var wake = 0
    @State private var script: Task<Void, Never>?
    @State private var autoStep = 0
    /// Resets on system cancellation too, so a stolen touch never leaves the goo stretched to a ghost finger.
    @GestureState private var pressing = false

    var body: some View {
        let radius = ctx.cg("size")
        let snap = ctx.cg("snap")
        let damping = ctx.cg("damping")
        VStack(spacing: 12) {
            GestureSimulation(isPreview: ctx.isPreview, wake: wake, isSettled: { model.isSettled }) { date in
                let events = model.step(to: date, radius: radius, snap: snap, damping: damping)
                let _ = events.isEmpty ? () : buzz(events)
                GooLayer(model: model, radius: radius, snap: snap, tick: date)
                    // Only a disc around the blob takes touches, so swipes elsewhere still scroll the page.
                    .contentShape(GooGrabArea(center: model.head, radius: radius + 26))
                    .gesture(drag(radius: radius))
            }
            .frame(width: GooTray.size.width, height: GooTray.size.height)
            .background(GooTrayBackground())

            DemoHint(text: L("Pull the goo off the wall", "把黏液从墙上拽下来"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6, delay: 0.4) { autoPull() }
        .onChange(of: ctx.params) {
            model.reset(radius: ctx.cg("size"))
            wake += 1
        }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { letGo(velocity: .zero) }
        }
        .onDisappear { script?.cancel() }
    }

    private func drag(radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held {
                    script?.cancel()
                    held = true
                    grabOffset = CGSize(width: value.startLocation.x - model.head.x, height: value.startLocation.y - model.head.y)
                    if !ctx.isPreview { Haptics.tap(.light) }
                }
                moveFinger(CGPoint(x: value.location.x - grabOffset.width, y: value.location.y - grabOffset.height))
            }
            .onEnded { value in
                letGo(velocity: CGVector(dx: value.velocity.width, dy: value.velocity.height))
            }
    }

    private func moveFinger(_ point: CGPoint) {
        let inset: CGFloat = 6
        model.finger = CGPoint(
            x: point.x.clamped(to: inset...(GooTray.size.width - inset)),
            y: point.y.clamped(to: inset...(GooTray.size.height - inset))
        )
        wake += 1
    }

    private func letGo(velocity: CGVector) {
        guard model.finger != nil else { return }
        held = false
        model.release(velocity: velocity, radius: ctx.cg("size"))
        wake += 1
    }

    /// A scripted finger pulls the blob off its wall and throws it at the next one, through the same
    /// `moveFinger` / `letGo` the real gesture calls.
    private func autoPull() {
        guard !held, model.finger == nil, model.stuck, !model.flying else { return }
        autoStep += 1
        let start = model.head
        let n = model.normal
        let side: CGFloat = autoStep.isMultiple(of: 2) ? 1 : -1
        let reach: CGFloat = ctx.cg("snap") + 34
        let tangent = CGVector(dx: -n.dy * side, dy: n.dx * side)
        let end = CGPoint(
            x: (start.x + n.dx * reach + tangent.dx * 46).clamped(to: 40...(GooTray.size.width - 40)),
            y: (start.y + n.dy * reach + tangent.dy * 46).clamped(to: 40...(GooTray.size.height - 40))
        )
        let fling = CGVector(dx: tangent.dx * 900 + n.dx * 200, dy: tangent.dy * 900 + n.dy * 200)
        script?.cancel()
        script = Task { @MainActor in
            let finished = await GhostFinger.drag(from: start, to: end, duration: 0.8) { point in moveFinger(point) }
            guard finished else { return }
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            letGo(velocity: fling)
        }
    }

    private func buzz(_ events: [GooEvent]) {
        guard !ctx.isPreview else { return }
        // Never fire side effects while SwiftUI is evaluating the view.
        DispatchQueue.main.async {
            for event in events {
                switch event {
                case .snap: Haptics.tap(.medium)
                case .land: Haptics.tap(.soft)
                }
            }
        }
    }
}

private struct GooGrabArea: Shape {
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

private struct GooTrayBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GooTray.corner, style: .continuous)
        shape
            .fill(Palette.elevated)
            .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }
}

private struct GooLayer: View {
    let model: StickyGooModel
    let radius: CGFloat
    let snap: CGFloat
    /// Changes every frame so SwiftUI redraws (the model is a reference and compares equal).
    let tick: Date

    private static let colors: [Color] = [Color(hex: 0xC8F56A), Palette.green, Palette.mint]

    var body: some View {
        let pad: CGFloat = GooTray.pad
        let shape = RoundedRectangle(cornerRadius: GooTray.corner, style: .continuous)
        ZStack {
            LinearGradient(colors: GooLayer.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .mask {
                    Canvas { context, _ in
                        context.addFilter(.alphaThreshold(min: 0.5, color: .white))
                        context.addFilter(.blur(radius: 7))
                        context.drawLayer { layer in
                            layer.translateBy(x: pad, y: pad)
                            drawGoo(&layer)
                        }
                    }
                }
                .shadow(color: Palette.green.opacity(0.35), radius: 9, y: 5)
            Canvas { context, _ in
                context.translateBy(x: pad, y: pad)
                drawGloss(&context)
            }
        }
        .frame(width: GooTray.size.width + pad * 2, height: GooTray.size.height + pad * 2)
        .drawingGroup()
        .frame(width: GooTray.size.width, height: GooTray.size.height)
        .clipShape(shape)
    }

    private var headRadius: CGFloat {
        radius * (1 - 0.18 * model.stretch(snap: snap))
    }

    private func circle(_ context: inout GraphicsContext, _ centre: CGPoint, _ r: CGFloat) {
        guard r > 0.5 else { return }
        context.fill(Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)), with: .color(.white))
    }

    private func puddle(_ context: inout GraphicsContext, at point: CGPoint, normal: CGVector, halfWidth: CGFloat, depth: CGFloat) {
        guard halfWidth > 1, depth > 0.5 else { return }
        let horizontalWall: Bool = abs(normal.dy) > 0.5
        let rect: CGRect = horizontalWall
            ? CGRect(x: point.x - halfWidth, y: point.y - depth, width: halfWidth * 2, height: depth * 2)
            : CGRect(x: point.x - depth, y: point.y - halfWidth, width: depth * 2, height: halfWidth * 2)
        context.fill(Path(ellipseIn: rect), with: .color(.white))
    }

    private func drawGoo(_ context: inout GraphicsContext) {
        let head = model.head
        let rHead: CGFloat = headRadius

        if model.stuck {
            let anchor = model.anchor
            let d: CGFloat = GestureMath.distance(head, anchor)
            let stretch: CGFloat = model.stretch(snap: snap)
            // Pressed closer than its rest height the foot spreads; pulled away it narrows.
            let press: CGFloat = (1 - d / (radius * 0.62)).clamped(to: -1...1)
            puddle(&context, at: anchor, normal: model.normal, halfWidth: radius * (1.3 + 0.45 * press - 0.35 * stretch), depth: radius * 0.42)
            if d > radius * 0.3 {
                let count: Int = max(Int(d / 5), 2)
                for index in 0...count {
                    let t: CGFloat = CGFloat(index) / CGFloat(count)
                    let waist: CGFloat = 1 - 0.8 * stretch * pow(sin(.pi * t), 0.8)
                    let r: CGFloat = GestureMath.lerp(radius * 0.85, rHead, t) * waist
                    circle(&context, GestureMath.lerp(anchor, head, t), r)
                }
            }
        }

        // Wall residue and its recoiling stub.
        if model.residue > 0.01 {
            let at = model.residueAt
            let amount: CGFloat = model.residue
            puddle(&context, at: at, normal: model.residueNormal, halfWidth: radius * 0.95 * amount, depth: radius * 0.36 * amount)
            let length: CGFloat = max(model.wallStub, 0)
            if length > 2 {
                let count: Int = max(Int(length / 5), 1)
                for index in 0...count {
                    let t: CGFloat = CGFloat(index) / CGFloat(count)
                    let centre = CGPoint(x: at.x + model.stubDirection.dx * length * t, y: at.y + model.stubDirection.dy * length * t)
                    circle(&context, centre, GestureMath.lerp(radius * 0.5 * amount, 4, t))
                }
            }
        }

        // Head stub pointing back at the wall it left.
        let back: CGFloat = max(model.headStub, 0)
        if back > 2 {
            let count: Int = max(Int(back / 5), 1)
            for index in 0...count {
                let t: CGFloat = CGFloat(index) / CGFloat(count)
                let centre = CGPoint(x: head.x - model.stubDirection.dx * back * t, y: head.y - model.stubDirection.dy * back * t)
                circle(&context, centre, GestureMath.lerp(rHead * 0.72, 4, t))
            }
        }

        // Velocity smear for the free blob.
        if !model.stuck {
            let speed: CGFloat = GestureMath.length(model.velocity)
            if speed > 40 {
                let smear: CGFloat = min(speed * 0.035, radius * 0.9)
                let centre = CGPoint(x: head.x - model.velocity.dx / speed * smear, y: head.y - model.velocity.dy / speed * smear)
                circle(&context, centre, rHead * 0.78)
            }
        }
        circle(&context, head, rHead)
    }

    private func drawGloss(_ context: inout GraphicsContext) {
        let r: CGFloat = headRadius
        // Keep the highlight on the visible part when the blob is half sunk into a wall.
        let head = CGPoint(
            x: model.head.x.clamped(to: r * 0.7...(GooTray.size.width - r * 0.3)),
            y: model.head.y.clamped(to: r * 0.8...(GooTray.size.height - r * 0.2))
        )
        var gloss = context
        gloss.addFilter(.blur(radius: 1.5))
        gloss.fill(
            Path(ellipseIn: CGRect(x: head.x - r * 0.52, y: head.y - r * 0.6, width: r * 0.5, height: r * 0.32)),
            with: .color(.white.opacity(0.6))
        )
        gloss.fill(
            Path(ellipseIn: CGRect(x: head.x + r * 0.1, y: head.y - r * 0.5, width: r * 0.14, height: r * 0.12)),
            with: .color(.white.opacity(0.5))
        )
    }
}
