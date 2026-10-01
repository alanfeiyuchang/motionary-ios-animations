import SwiftUI

extension Effect {
    static let showcaseVinylScrub = Effect(
        id: "showcase.vinyl-scrub",
        category: .showcase,
        interaction: .gesture,
        name: L("Vinyl Scratch Deck", "黑胶搓碟唱机"),
        summary: L(
            "A record spins under a sprung tonearm; grab the disc to scratch it and let it coast back to speed.",
            "唱片在弹簧唱臂下旋转；按住唱片来回搓碟，松手后带着惯性回到原速。"
        ),
        prompt: L(
            "A dark turntable widget: a 164 pt black record with fine concentric grooves and an orange centre label spins at 33⅓ rpm under a metal tonearm pivoted at the top right. On arrival the arm swings from its rest onto the outer groove with a spring (response 0.55 s, damping 0.6) and the platter spins up exponentially over about 0.6 s. Grabbing the disc locks it to the finger: its angle follows the touch 1:1 around the centre, the time readout scrubs backwards and forwards with it, a speed chip shows the live rate (for example −2.4×) and a light tick fires every 30° of scratch. On release the disc keeps the finger's angular velocity and eases back to playing speed with the same time constant. Two fixed specular wedges shimmer across the grooves and brighten with speed, so the vinyl reads as glossy and heavy.",
            "深色唱机小组件：164pt 黑胶唱片刻着细密同心纹，中心是橙色唱标，以 33⅓ 转/分在金属唱臂下旋转，唱臂枢轴位于右上角。进入时唱臂以弹簧（响应 0.55 秒、阻尼 0.6）从停靠位摆到最外圈，唱盘约 0.6 秒内按指数曲线起转。按住唱片即锁定手指：角度绕圆心 1:1 跟随，时间读数随之前后搓动，速度标签实时显示倍率（如 −2.4×），每搓过 30° 一次轻触感。松手后唱片保留手指的角速度，再按同一时间常数回到播放转速。两道固定的高光扇面在纹路上流动，转得越快越亮，黑胶显得厚重而有光泽。"
        ),
        implementation: L(
            "A small reference-type model integrates angle and angular velocity every TimelineView frame (exponential approach to the target rpm); a DragGesture converts the touch to a polar angle around the disc centre, adds the wrapped delta to the model and estimates the release velocity. The grooves are a Canvas, the highlights a fixed AngularGradient in plusLighter, and the tonearm a rotationEffect around its pivot driven by a spring.",
            "一个引用类型的小模型在 TimelineView 每帧积分角度与角速度（按指数趋近目标转速）；DragGesture 把触点换算成绕圆心的极角，把去环绕后的增量加进模型，并估算松手速度。纹路用 Canvas 绘制，高光是固定的 AngularGradient 加 plusLighter 混合，唱臂用绕枢轴的 rotationEffect 配弹簧驱动。"
        ),
        apis: ["TimelineView(.animation)", "DragGesture", "Canvas", "AngularGradient", "rotationEffect(_:anchor:)"],
        tags: ["vinyl", "turntable", "scratch", "scrub", "inertia", "黑胶", "唱机", "搓碟", "惯性", "音乐"],
        params: [
            .choice("rpm", L("Speed", "转速"), [L("33⅓ rpm", "33⅓ 转"), L("45 rpm", "45 转")], default: 0),
            .slider("inertia", L("Spin-up time", "回速时间"), 0.15...1.6, default: 0.6, unit: "s"),
            .slider("shimmer", L("Groove shimmer", "纹路高光"), 0...1, default: 0.7),
        ]
    ) { ctx in
        VinylScrubDemo(ctx: ctx)
    }
}

/// Platter physics, integrated once per frame. A class so the frame clock can advance it without
/// invalidating the view.
private final class VinylModel {
    var angle: Double = 0
    var omega: Double = 0
    var seconds: Double = 42
    var grabbed = false
    var playing = false
    var target: Double = 3.49
    var tau: Double = 0.6
    private var last: Date?

    func step(to date: Date) {
        defer { last = date }
        guard let last else { return }
        let dt = min(max(date.timeIntervalSince(last), 0), 0.05)
        guard !grabbed, dt > 0 else { return }
        let goal = playing ? target : 0
        omega += (goal - omega) * (1 - exp(-dt / max(tau, 0.05)))
        angle += omega * dt
        advance(by: omega * dt)
    }

    /// One turn at the nominal speed is one turn's worth of music, in either direction.
    func advance(by delta: Double) {
        let length = VinylScrubDemo.length
        seconds = (seconds + delta / target).truncatingRemainder(dividingBy: length)
        if seconds < 0 { seconds += length }
    }
}

private struct VinylScrubDemo: View {
    let ctx: DemoContext
    static let length: Double = 204
    private let discSize: CGFloat = 164
    private let deck = CGSize(width: 252, height: 180)

    @State private var model: VinylModel
    @State private var playing: Bool
    @State private var grabbed = false
    @State private var scripting = false
    @State private var script: Task<Void, Never>?
    @State private var lastTouchAngle: Double = 0
    @State private var lastMove = Date()
    @State private var lastTick = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        let model = VinylModel()
        model.angle = 0.5
        model.playing = ctx.isStill
        _model = State(initialValue: model)
        _playing = State(initialValue: ctx.isStill)
    }

    private var zh: Bool { ctx.language == .zh }
    private var targetOmega: Double { (ctx.int("rpm") == 1 ? 45 : 100.0 / 3.0) * 2 * .pi / 60 }

    var body: some View {
        SignatureStage {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card
                Spacer(minLength: 0)
                DemoHint(text: L("Drag the record to scratch · tap the arm", "拖动唱片搓碟 · 点击唱臂"), ctx: ctx)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard !ctx.isStill, !playing else { return }
            Task { @MainActor in
                guard await studioPause(0.3), !playing else { return }
                togglePlay()
            }
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 4.6, delay: 1.6) { runScript() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: ctx.isStill)) { timeline in
                let _ = sync(timeline.date)
                VStack(alignment: .leading, spacing: 10) {
                    turntable
                    footer(seconds: model.seconds, rate: model.omega / targetOmega)
                }
            }
        }
        .padding(16)
        .frame(width: 284)
        .signatureCard()
    }

    private func sync(_ date: Date) {
        model.target = targetOmega
        model.tau = ctx["inertia"]
        if !ctx.isStill { model.step(to: date) }
    }

    // MARK: Pieces

    /// Live playback rate; orange whenever the platter is off its nominal speed.
    private func rateChip(_ rate: Double) -> some View {
        let off = abs(rate - 1) > 0.08 && (playing || grabbed || abs(rate) > 0.05)
        return Text(verbatim: String(format: "%.1f×", rate).replacingOccurrences(of: "-", with: "−"))
            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(off ? Signature.ink : Signature.textSecondary)
            .frame(width: 46, height: 24)
            .background(Capsule().fill(off ? AnyShapeStyle(Signature.accentGradient) : AnyShapeStyle(Color.white.opacity(0.08))))
    }

    private var rpmText: String { ctx.int("rpm") == 1 ? "45 RPM" : "33⅓ RPM" }

    private var turntable: some View {
        ZStack {
            // Platter well.
            Circle()
                .fill(Color.black.opacity(0.55))
                .frame(width: discSize + 12, height: discSize + 12)
                .overlay(Circle().strokeBorder(grabbed ? Signature.accent.opacity(0.9) : Color.white.opacity(0.07), lineWidth: grabbed ? 1.5 : 1))
                .shadow(color: Signature.accent.opacity(grabbed ? 0.55 : 0), radius: 12)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: grabbed)
                .position(x: 104, y: 90)
            disc
                .position(x: 104, y: 90)
            VinylArm(lifted: !playing)
                .rotationEffect(.degrees(armAngle), anchor: UnitPoint(x: 0.5, y: 26.0 / 166.0))
                .position(x: 222, y: 87)
                .animation(.spring(response: 0.55, dampingFraction: 0.6), value: playing)
                .onTapGesture { userTogglePlay() }
            // Pivot cap, above the arm.
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xD9DADF), Color(hex: 0x6D6E75)], startPoint: .top, endPoint: .bottom))
                .frame(width: 22, height: 22)
                .overlay(Circle().fill(Color.black.opacity(0.55)).frame(width: 7, height: 7))
                .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
                .position(x: 222, y: 30)
                .allowsHitTesting(false)
        }
        .frame(width: deck.width, height: deck.height)
    }

    /// Rest is just off the record; while playing the stylus tracks inward with the music.
    private var armAngle: Double {
        playing ? 30 + 17 * model.seconds / Self.length : -3
    }

    private var disc: some View {
        let speed = min(abs(model.omega) / targetOmega, 2.2)
        return ZStack {
            VinylDisc(size: discSize)
                .rotationEffect(.radians(model.angle))
            // Light that stays put while the vinyl turns under it.
            VinylSheen(sway: sin(model.angle * 2) * 5)
                .opacity(ctx["shimmer"] * (0.45 + 0.4 * speed))
                .allowsHitTesting(false)
        }
        .frame(width: discSize, height: discSize)
        .scaleEffect(grabbed ? 0.975 : 1)
        .shadow(color: .black.opacity(0.6), radius: grabbed ? 6 : 12, y: grabbed ? 3 : 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: grabbed)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let a = polar(value.location)
                    if !grabbed {
                        script?.cancel()
                        scripting = false
                        grab(at: a)
                    } else {
                        scratch(to: a)
                    }
                }
                .onEnded { _ in release() }
        )
    }

    private func footer(seconds: Double, rate: Double) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: (zh ? "A 面 · " : "Side A · ") + rpmText)
                    .signatureEyebrow()
                Text(verbatim: zh ? "海岸公路" : "Coastal Drive")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                HStack(spacing: 4) {
                    Text(verbatim: studioClock(seconds))
                        .foregroundStyle(Signature.accentSoft)
                    Text(verbatim: "/ " + studioClock(Self.length))
                        .foregroundStyle(Signature.textSecondary)
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
            }
            Spacer(minLength: 0)
            rateChip(rate)
            Button(action: userTogglePlay) {
                Image(systemName: playing ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Signature.ink)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .background(Signature.accentGradient, in: Circle())
                    .shadow(color: Signature.accent.opacity(0.5), radius: 8, y: 3)
            }
            .buttonStyle(SportPressStyle(scale: 0.9, dim: 0.05))
            .accessibilityLabel(Text(playing ? L("Lift the arm", "抬起唱臂") : L("Drop the arm", "放下唱臂"), ctx.language))
        }
    }

    // MARK: Actions (the scripted finger calls the same functions as the gesture)

    private func polar(_ point: CGPoint) -> Double {
        atan2(Double(point.y - discSize / 2), Double(point.x - discSize / 2))
    }

    private func grab(at angle: Double) {
        lastTouchAngle = angle
        lastMove = Date()
        model.grabbed = true
        model.omega = 0
        grabbed = true
        buzz(.medium)
    }

    private func scratch(to angle: Double) {
        var delta = angle - lastTouchAngle
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        lastTouchAngle = angle
        let now = Date()
        let dt = max(now.timeIntervalSince(lastMove), 1.0 / 240.0)
        lastMove = now
        model.angle += delta
        model.advance(by: delta)
        model.omega = model.omega * 0.6 + (delta / dt) * 0.4
        let tick = Int((model.angle / (.pi / 6)).rounded(.down))
        if tick != lastTick {
            lastTick = tick
            buzz(.light)
        }
    }

    private func release() {
        guard grabbed else { return }
        // A finger that stopped before lifting hands over no spin.
        if Date().timeIntervalSince(lastMove) > 0.09 { model.omega = 0 }
        model.omega = model.omega.clamped(to: -40...40)
        model.grabbed = false
        grabbed = false
    }

    private func userTogglePlay() {
        script?.cancel()
        scripting = false
        togglePlay()
        Haptics.tap(.medium)
    }

    private func togglePlay() {
        playing.toggle()
        model.playing = playing
    }

    private func buzz(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard !ctx.isPreview, !scripting else { return }
        Haptics.tap(style)
    }

    /// Preview / arrival play: a back-and-forth scratch with the same grab → scratch → release calls.
    private func runScript() {
        script?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            if !playing { togglePlay() }
            let start = -0.7
            grab(at: start)
            let moves: [(Double, Double)] = [(-2.3, 0.42), (1.5, 0.22), (-1.2, 0.26), (2.4, 0.2)]
            var origin = start
            for (delta, duration) in moves {
                let from = origin
                guard await studioScript(duration, { t in scratch(to: from + delta * studioEase(t)) }) else {
                    release()
                    return
                }
                origin += delta
            }
            release()
        }
    }
}

// MARK: - Disc

private struct VinylDisc: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x1D1D21), Color(hex: 0x050506)], center: .center, startRadius: 20, endRadius: size / 2))
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                var radius: CGFloat = 36
                var index = 0.0
                while radius < canvasSize.width / 2 - 3 {
                    // Three silent bands split the side into tracks.
                    let gap = abs(radius - 50) < 1.2 || abs(radius - 64) < 1.2
                    let alpha = gap ? 0.0 : 0.035 + 0.075 * sportHash(index)
                    let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    context.stroke(ring, with: .color(.white.opacity(alpha)), lineWidth: 0.7)
                    radius += 1.9
                    index += 1
                }
                // A pressing flaw and two dust specks make the rotation readable.
                var flaw = Path()
                flaw.addArc(center: center, radius: 69, startAngle: .degrees(200), endAngle: .degrees(236), clockwise: false)
                context.stroke(flaw, with: .color(.white.opacity(0.16)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                for (angle, r) in [(0.6, 57.0), (2.9, 74.0), (4.4, 44.0)] {
                    let p = CGPoint(x: center.x + CGFloat(cos(angle) * r), y: center.y + CGFloat(sin(angle) * r))
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 0.9, y: p.y - 0.9, width: 1.8, height: 1.8)), with: .color(.white.opacity(0.35)))
                }
            }
            Circle()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            label
        }
        .frame(width: size, height: size)
    }

    private var label: some View {
        ZStack {
            Circle().fill(Signature.accentGradient)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(Color.black.opacity(0.22))
            Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
            VStack(spacing: 13) {
                Text(verbatim: "MOTIONARY")
                    .font(.system(size: 6.5, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Signature.ink.opacity(0.8))
                Text(verbatim: "A · 33")
                    .font(.system(size: 6.5, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            Circle()
                .fill(Color(hex: 0xC9CACF))
                .frame(width: 7, height: 7)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1))
        }
        .frame(width: 60, height: 60)
    }
}

/// Two opposite specular wedges across the grooves (not the label), lit additively.
private struct VinylSheen: View {
    let sway: Double

    var body: some View {
        Circle()
            .fill(
                AngularGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.0), location: 0.05),
                        .init(color: .white.opacity(0.34), location: 0.115),
                        .init(color: Signature.accentSoft.opacity(0.12), location: 0.16),
                        .init(color: .clear, location: 0.24),
                        .init(color: .clear, location: 0.53),
                        .init(color: .white.opacity(0.2), location: 0.615),
                        .init(color: .clear, location: 0.71),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: .center,
                    angle: .degrees(-70 + sway)
                )
            )
            .mask {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 47)
                    .padding(2)
            }
            .blendMode(.plusLighter)
    }
}

// MARK: - Tonearm

/// Drawn pointing straight down; the pivot sits 26 pt below the top of this 24 × 166 view.
private struct VinylArm: View {
    let lifted: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // Counterweight.
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x8B8C93), Color(hex: 0x3A3B40)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 16, height: 20)
            // Tube.
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xF1F1F4), Color(hex: 0x9A9BA2), Color(hex: 0x5A5B61)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 5, height: 126)
                .offset(y: 18)
            // Head shell with the orange stylus guard.
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x3A3B40), Color(hex: 0x1B1B1F)], startPoint: .top, endPoint: .bottom))
                .frame(width: 15, height: 26)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Signature.accent)
                        .frame(width: 9, height: 5)
                        .padding(.bottom, 3)
                }
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                .rotationEffect(.degrees(14))
                .offset(y: 138)
        }
        .frame(width: 24, height: 166, alignment: .top)
        .shadow(color: .black.opacity(lifted ? 0.35 : 0.6), radius: lifted ? 9 : 3, x: lifted ? 7 : 2, y: lifted ? 9 : 2)
        .scaleEffect(lifted ? 1.03 : 1, anchor: UnitPoint(x: 0.5, y: 26.0 / 166.0))
        .contentShape(Rectangle())
    }
}
