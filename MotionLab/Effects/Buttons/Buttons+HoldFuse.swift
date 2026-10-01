import SwiftUI

extension Effect {
    static let buttonsHoldFuse = Effect(
        id: "buttons.hold-fuse",
        category: .buttons,
        interaction: .gesture,
        name: L("Burning Fuse", "引线燃烧"),
        summary: L(
            "Holding lights a spark that burns around the border like a fuse; finish the lap and it detonates.",
            "按住后火花像引线一样沿边框燃烧，烧完一圈即引爆；提前松手则火花倒卷回去。"
        ),
        prompt: L(
            "A 236 × 64 pt rounded button wrapped in a dotted fuse line. Holding it lights a spark at the top centre that travels clockwise around the perimeter in 1.6 s at constant speed: a flickering white-hot core with a four-point flare and an amber halo, an ember trail over the last 14% of the path cooling from white through amber to red, and tiny sparks thrown off about 34 times a second that fall under gravity and die within 0.5 s. Burnt fuse turns to faint ash, the face warms toward coral and the button sinks to 97%. Releasing early reels the spark back at 2.5× speed and the fuse regrows. Completing the lap detonates: two expanding ring strokes, 22 radial sparks, a white flash, a pop to 108% and a heavy haptic; the button shows a hot “Armed” state, then resets after 1.7 s. Tense and theatrical.",
            "236×64pt 的圆角按钮，边框绕着一圈点状引线。按住后，顶部中点亮起一颗火花，匀速在 1.6 秒内顺时针烧完整圈：白热核心闪烁，带四角星芒与琥珀色光晕；身后是占路径 14% 的余烬尾迹，由白到琥珀再到暗红冷却；每秒约迸出 34 粒火星，受重力下坠并在 0.5 秒内熄灭。烧过的引线化为淡灰，表面泛出珊瑚色并下沉到 97%。提前松手，火花以 2.5 倍速倒卷，引线长回。烧完一圈即引爆：两道扩散环、22 粒径向火星、一次白色闪光，按钮弹到 108% 并触发重触感，变成炽热的“已启动”状态，1.7 秒后复位。"
        ),
        implementation: L(
            "Progress is a pure function of time (base + rate × elapsed), so a TimelineView Canvas can trim the border path to any instant: the unburnt fuse, the ember trail in graded segments under a blur layer, the spark at trimmedPath's end point, and stateless sparks whose birth position is the path point at their birth time. onLongPressGesture's pressing callback flips the rate between +1/duration and −speed/duration.",
            "进度是时间的纯函数（基准值 + 速率 × 经过时间），所以 TimelineView 里的 Canvas 可以把边框路径裁到任意时刻：未燃的引线、带模糊图层的分段余烬尾迹、位于 trimmedPath 终点的火花，以及无状态的火星（出生位置即其出生时刻的路径点）。onLongPressGesture 的按压回调把速率在 +1/时长 与 −倍速/时长 之间切换。"
        ),
        apis: ["TimelineView", "Canvas", "Path.trimmedPath(from:to:)", "onLongPressGesture(minimumDuration:maximumDistance:perform:onPressingChanged:)", "GraphicsContext.addFilter"],
        tags: ["hold", "fuse", "spark", "detonate", "长按", "引线", "火花", "引爆"],
        params: [
            .slider("duration", L("Burn time", "燃烧时长"), 0.8...3.0, default: 1.6, unit: "s"),
            .slider("trail", L("Ember trail", "余烬长度"), 0.05...0.3, default: 0.14),
            .slider("sparks", L("Sparks per second", "每秒火星数"), 0...60, default: 34, decimals: 0),
            .slider("reel", L("Reel-back speed", "倒卷速度"), 1...5, default: 2.5, decimals: 1, unit: "×"),
        ]
    ) { ctx in
        ButtonFuseDemo(ctx: ctx)
    }
}

/// Progress as a pure function of time, so every frame (and every spark's birth) can be evaluated statelessly.
private struct ButtonFuseClock {
    var base: Double = 0
    var rate: Double = 0
    var since = Date.distantPast

    func value(at date: Date) -> Double {
        (base + rate * date.timeIntervalSince(since)).clamped(to: 0...1)
    }
}

private enum ButtonFusePhase {
    case idle, burning, reeling, armed
}

private struct ButtonFuseDemo: View {
    let ctx: DemoContext
    @State private var clock = ButtonFuseClock()
    @State private var phase = ButtonFusePhase.idle
    @State private var boomAt = Date.distantPast
    @State private var booms = 0
    @State private var finishTask: Task<Void, Never>?
    @State private var crackleTask: Task<Void, Never>?
    @State private var scriptTask: Task<Void, Never>?

    private static let stage = CGSize(width: 320, height: 170)
    private static let face = CGSize(width: 236, height: 64)
    private var duration: Double { max(ctx["duration"], 0.2) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            control
            Spacer()
            DemoHint(text: L("Hold until the fuse burns all the way round", "一直按住，直到引线烧完一圈"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: duration * 1.7 + 2.7, delay: 0.4) { playScript() }
        .onDisappear {
            scriptTask?.cancel()
            finishTask?.cancel()
            crackleTask?.cancel()
        }
    }

    private var control: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: phase == .idle || ctx.isStill)) { timeline in
            let progress = ctx.isStill ? 0.62 : clock.value(at: timeline.date)
            ZStack {
                ButtonFuseFace(
                    progress: progress,
                    armed: phase == .armed,
                    holding: phase == .burning,
                    booms: booms,
                    language: ctx.language
                )
                .frame(width: Self.face.width, height: Self.face.height)
                ButtonFuseCanvas(
                    clock: ctx.isStill ? ButtonFuseClock(base: 0.62, rate: 0, since: timeline.date) : clock,
                    date: timeline.date,
                    burning: phase == .burning,
                    boomAge: phase == .armed ? timeline.date.timeIntervalSince(boomAt) : nil,
                    face: Self.face,
                    trail: ctx["trail"],
                    sparkRate: ctx["sparks"]
                )
                .allowsHitTesting(false)
            }
            .frame(width: Self.stage.width, height: Self.stage.height)
        }
        .overlay {
            // The hit target is the button itself (plus a little slop), not the whole spark canvas.
            Color.clear
                .frame(width: Self.face.width + 16, height: Self.face.height + 16)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 600, maximumDistance: 60) {
                } onPressingChanged: { isPressing in
                    scriptTask?.cancel()
                    if isPressing { begin(haptics: true) } else { cancel() }
                }
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Behaviour

    private func begin(haptics: Bool) {
        guard phase != .armed else { return }
        let now = Date()
        let current = clock.value(at: now)
        clock = ButtonFuseClock(base: current, rate: 1 / duration, since: now)
        phase = .burning
        if haptics { Haptics.tap(.soft) }
        finishTask?.cancel()
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds((1 - current) * duration))
            guard !Task.isCancelled else { return }
            detonate(haptics: haptics)
        }
        crackleTask?.cancel()
        guard haptics else { return }
        // The fuse crackles under the finger while it burns.
        crackleTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.14))
                guard !Task.isCancelled else { return }
                Haptics.tap(.soft)
            }
        }
    }

    private func cancel() {
        guard phase == .burning else { return }
        finishTask?.cancel()
        crackleTask?.cancel()
        let now = Date()
        let current = clock.value(at: now)
        let speed = max(ctx["reel"], 0.5)
        clock = ButtonFuseClock(base: current, rate: -speed / duration, since: now)
        phase = .reeling
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(current * duration / speed + 0.05))
            guard !Task.isCancelled else { return }
            if phase == .reeling { phase = .idle }
        }
    }

    private func detonate(haptics: Bool) {
        crackleTask?.cancel()
        let now = Date()
        clock = ButtonFuseClock(base: 1, rate: 0, since: now)
        boomAt = now
        booms += 1
        withAnimation(.smooth(duration: 0.2)) { phase = .armed }
        if haptics { Haptics.tap(.heavy) }
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            if haptics, !Task.isCancelled { Haptics.success() }
            try? await Task.sleep(for: .seconds(1.54))
            guard !Task.isCancelled else { return }
            clock = ButtonFuseClock()
            withAnimation(.smooth(duration: 0.35)) { phase = .idle }
        }
    }

    /// Preview loop and detail intro: one full burn, then a short hold that is let go and reels back.
    private func playScript() {
        guard phase == .idle else { return }
        scriptTask?.cancel()
        let burn = duration
        scriptTask = Task { @MainActor in
            begin(haptics: false)
            try? await Task.sleep(for: .seconds(burn + 2.1))
            guard !Task.isCancelled, ctx.isPreview else { return }
            begin(haptics: false)
            try? await Task.sleep(for: .seconds(burn * 0.45))
            guard !Task.isCancelled else { return }
            cancel()
        }
    }
}

private struct ButtonFuseFace: View {
    let progress: Double
    let armed: Bool
    let holding: Bool
    let booms: Int
    let language: AppLanguage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        ZStack {
            shape.fill(Palette.elevated)
            // The face warms up as the fuse burns down.
            shape.fill(Palette.coral.opacity(armed ? 0 : progress * 0.22))
            shape
                .fill(LinearGradient(colors: [Palette.amber, Palette.coral, Palette.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(armed ? 1 : 0)
            label
        }
        .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
        .shadow(color: (armed ? Palette.coral : Color.black).opacity(armed ? 0.45 : 0.12), radius: armed ? 22 : 14, y: 8)
        .scaleEffect(holding ? 0.97 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: holding)
        .keyframeAnimator(initialValue: ButtonFuseBoom(), trigger: booms) { content, boom in
            content
                .overlay(shape.fill(Color.white.opacity(boom.flash)))
                .scaleEffect(boom.scale)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.08, duration: 0.09)
                SpringKeyframe(1, duration: 0.55, spring: .bouncy)
            }
            KeyframeTrack(\.flash) {
                MoveKeyframe(0.85)
                CubicKeyframe(0, duration: 0.4)
            }
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: armed ? "bolt.fill" : "flame.fill")
                .foregroundStyle(armed ? AnyShapeStyle(Color.white) : AnyShapeStyle(Palette.coral))
                .contentTransition(.symbolEffect(.replace))
            Text(armed ? L("Armed", "已启动") : L("Hold to arm", "按住启动"), language)
                .foregroundStyle(armed ? Color.white : Color.primary)
                .contentTransition(.opacity)
        }
        .font(.headline)
    }
}

private struct ButtonFuseBoom {
    var scale: CGFloat = 1
    var flash: Double = 0
}

private struct ButtonFuseCanvas: View {
    let clock: ButtonFuseClock
    let date: Date
    let burning: Bool
    let boomAge: Double?
    let face: CGSize
    let trail: Double
    let sparkRate: Double

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(
                x: (size.width - face.width) / 2,
                y: (size.height - face.height) / 2,
                width: face.width,
                height: face.height
            ).insetBy(dx: -5, dy: -5)
            let path = Self.loop(in: rect, radius: 24)
            let progress = clock.value(at: date)
            let time = date.timeIntervalSinceReferenceDate

            if let boomAge {
                drawBoom(&context, rect: rect, age: boomAge)
            } else {
                drawFuse(&context, path: path, progress: progress)
                if progress > 0.0005 {
                    drawTrail(&context, path: path, progress: progress)
                    if burning { drawSparks(&context, path: path, time: time) }
                    drawHead(&context, at: Self.point(on: path, at: progress), time: time)
                }
            }
        }
    }

    /// The border as one closed path that starts at the top centre and runs clockwise.
    private static func loop(in rect: CGRect, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }

    private static func point(on path: Path, at fraction: Double) -> CGPoint {
        path.trimmedPath(from: 0, to: max(fraction, 0.0001)).currentPoint ?? .zero
    }

    private func drawFuse(_ context: inout GraphicsContext, path: Path, progress: Double) {
        // Ash where the spark has already been.
        if progress > 0.001 {
            context.stroke(
                path.trimmedPath(from: 0, to: progress),
                with: .color(Color.primary.opacity(0.1)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
        }
        // Unburnt fuse ahead of it.
        if progress < 0.999 {
            context.stroke(
                path.trimmedPath(from: progress, to: 1),
                with: .color(Color.primary.opacity(0.34)),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [0.5, 5])
            )
        }
    }

    private func drawTrail(_ context: inout GraphicsContext, path: Path, progress: Double) {
        let segments = 14
        let start = max(progress - trail, 0)
        guard progress - start > 0.0005 else { return }
        func strokeSegments(_ target: inout GraphicsContext, width: CGFloat) {
            for index in 0..<segments {
                let a = start + (progress - start) * Double(index) / Double(segments)
                let b = start + (progress - start) * Double(index + 1) / Double(segments)
                let heat = Double(index + 1) / Double(segments)
                let color = Palette.red.mix(with: Palette.amber, by: min(heat * 1.4, 1)).mix(with: .white, by: max(heat - 0.75, 0) * 3)
                target.stroke(
                    path.trimmedPath(from: a, to: b),
                    with: .color(color.opacity(heat * heat)),
                    style: StrokeStyle(lineWidth: width * (0.5 + 0.5 * heat), lineCap: .round)
                )
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            strokeSegments(&layer, width: 7)
        }
        strokeSegments(&context, width: 3)
    }

    private func drawHead(_ context: inout GraphicsContext, at point: CGPoint, time: Double) {
        let flicker = 0.82 + 0.18 * sin(time * 47) * sin(time * 31)
        let halo = 16 * flicker
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - halo, y: point.y - halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [Palette.amber.opacity(0.85), Palette.coral.opacity(0.35), .clear]),
                center: point,
                startRadius: 0,
                endRadius: halo
            )
        )
        // Four-point flare that slowly turns and breathes with the flicker.
        var flare = Path()
        let long = 11 * flicker
        for index in 0..<4 {
            let angle = time * 2.2 + Double(index) * .pi / 2
            flare.move(to: point)
            flare.addLine(to: CGPoint(x: point.x + CGFloat(cos(angle)) * long, y: point.y + CGFloat(sin(angle)) * long))
        }
        context.stroke(flare, with: .color(Color.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 3.2, y: point.y - 3.2, width: 6.4, height: 6.4)),
            with: .color(.white)
        )
    }

    /// Sparks are stateless: slot `n` is born at `n / rate`, at the path point the head had at that instant.
    private func drawSparks(_ context: inout GraphicsContext, path: Path, time: Double) {
        guard sparkRate > 0.5 else { return }
        let life = 0.5
        let origin = clock.since.timeIntervalSinceReferenceDate
        let newest = Int((time * sparkRate).rounded(.down))
        let oldest = newest - Int(life * sparkRate)
        for slot in stride(from: newest, through: oldest, by: -1) {
            let birth = Double(slot) / sparkRate
            guard birth >= origin else { continue }
            let age = time - birth
            guard age >= 0, age < life else { continue }
            let home = Self.point(on: path, at: min(clock.base + clock.rate * (birth - origin), 1))
            let angle = Self.hash(slot, 1) * 2 * .pi
            let speed = 30 + 70 * Self.hash(slot, 2)
            let x = home.x + CGFloat(cos(angle) * speed * age)
            let y = home.y + CGFloat(sin(angle) * speed * age + 0.5 * 220 * age * age)
            let fade = 1 - age / life
            let radius = CGFloat(0.8 + 0.9 * Self.hash(slot, 3)) * CGFloat(0.5 + 0.5 * fade)
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Palette.amber.mix(with: .white, by: fade * 0.7).opacity(fade))
            )
        }
    }

    private func drawBoom(_ context: inout GraphicsContext, rect: CGRect, age: Double) {
        for (index, delay) in [0.0, 0.09].enumerated() {
            let t = ((age - delay) / 0.6).clamped(to: 0...1)
            guard t > 0, t < 1 else { continue }
            let eased = 1 - pow(1 - t, 3)
            let grow = CGFloat(eased) * (index == 0 ? 30 : 20)
            let ring = Path(roundedRect: rect.insetBy(dx: -grow, dy: -grow), cornerRadius: 24 + grow, style: .continuous)
            context.stroke(
                ring,
                with: .color((index == 0 ? Palette.amber : Palette.coral).opacity(1 - eased)),
                lineWidth: 3.5 * CGFloat(1 - eased) + 0.6
            )
        }
        let t = (age / 0.75).clamped(to: 0...1)
        guard t < 1 else { return }
        let eased = 1 - pow(1 - t, 3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for index in 0..<22 {
            let angle = Double(index) / 22 * 2 * .pi + Self.hash(index, 4) * 0.2
            // Start on the border ellipse, fly outward, sag under gravity.
            let edge = CGPoint(
                x: center.x + CGFloat(cos(angle)) * rect.width / 2,
                y: center.y + CGFloat(sin(angle)) * rect.height / 2
            )
            let reach = CGFloat(26 + 30 * Self.hash(index, 5)) * CGFloat(eased)
            let point = CGPoint(
                x: edge.x + CGFloat(cos(angle)) * reach,
                y: edge.y + CGFloat(sin(angle)) * reach + CGFloat(70 * t * t)
            )
            let radius = CGFloat(1.2 + 1.6 * Self.hash(index, 6)) * CGFloat(1 - t * 0.6)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color((index % 3 == 0 ? Color.white : Palette.amber).opacity(1 - t * t))
            )
        }
    }

    /// Cheap deterministic 0…1 noise per (slot, channel).
    private static func hash(_ value: Int, _ channel: Int) -> Double {
        let x = sin(Double(value) * 12.9898 + Double(channel) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }
}
