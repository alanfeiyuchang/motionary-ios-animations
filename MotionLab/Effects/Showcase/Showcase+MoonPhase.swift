import SwiftUI

extension Effect {
    static let showcaseMoonPhase = Effect(
        id: "showcase.moon-phase",
        category: .showcase,
        interaction: .gesture,
        name: L("Moon Phase Scrubber", "月相拖动"),
        summary: L(
            "Drag to run the lunar month: the terminator sweeps across a cratered moon, stars fade as it brightens and the illumination rolls.",
            "拖动走完一个朔望月：明暗界线扫过布满环形山的月面，月亮越亮星星越淡，照明百分比随之滚动。"
        ),
        prompt: L(
            "A dark moon-phase widget: a 124 pt cratered moon on a starfield at the left, the phase name, illumination percentage and lunar day at the right, and a day ruler with a fixed orange pointer below. Dragging horizontally scrubs the phase: the lit region is a half disc joined to an elliptical terminator whose width follows the cosine of the phase, softened by a 1.5 pt blur, with the dark side kept as faint earthshine. A white halo behind the moon grows with the illumination and the twinkling stars dim toward 40%. The ruler slides with the finger and ticks a selection haptic on each lunar day; the percentage and day count update continuously and the phase name cross-fades. On release the phase carries its velocity and settles on the nearest of the eight principal phases with a spring (response 0.55 s, damping 0.72). Quiet, astronomical.",
            "深色月相组件：左侧星空里是一轮 124pt、布满环形山的月亮，右侧是月相名称、照明百分比与月龄，下方是带固定橙色指针的日期刻度尺。水平拖动即可拖过月相：亮面由半圆加一条椭圆形明暗界线围成，界线宽度随月相的余弦变化，以 1.5pt 模糊柔化，暗面保留微弱地照。月亮背后的白色光晕随照明度增强，闪烁的星星暗到 40%。刻度尺跟手滑动，每过一个月龄日给一次选择触感；百分比连续更新，月相名称交叉淡化。松手后以弹簧（响应 0.55 秒、阻尼 0.72）停在八个主要月相中最近的一个。安静，带天文感。"
        ),
        implementation: L(
            "The card body is an Animatable view keyed on the phase, so the lit-region Shape, the Canvas ruler and the readouts all follow the release spring frame by frame. The moon texture is one Canvas (gradient, maria, craters) shown twice: darkened as the base and masked by the blurred lit shape on top. Stars twinkle in a TimelineView Canvas.",
            "卡片主体是以月相为 animatableData 的 Animatable 视图，亮面 Shape、Canvas 刻度尺与读数都能逐帧跟随松手后的弹簧。月面纹理是一张 Canvas（渐变、月海、环形山），显示两次：压暗的作为底，上层用模糊后的亮面形状做遮罩。星星在 TimelineView 的 Canvas 中闪烁。"
        ),
        apis: ["Animatable", "DragGesture", "Canvas", "mask", "TimelineView(.animation)", "spring(response:dampingFraction:)"],
        tags: ["moon", "phase", "lunar", "astronomy", "scrub", "月相", "月亮", "天文", "拖动", "星空"],
        params: [
            .slider("travel", L("Drag per cycle", "一个周期的拖动距离"), 240...720, default: 420, decimals: 0, unit: "pt"),
            .toggle("snap", L("Snap to principal phases", "吸附到主要月相"), default: true),
            .slider("stars", L("Stars", "星星数量"), 0...60, default: 34, step: 1, decimals: 0),
            .slider("glow", L("Halo strength", "光晕强度"), 0...1, default: 0.6),
        ]
    ) { ctx in
        MoonPhaseDemo(ctx: ctx)
    }
}

private struct MoonPhaseDemo: View {
    let ctx: DemoContext
    /// Lunar cycles since new moon (unbounded, so the release spring can cross a new moon).
    @State private var phase: Double
    @State private var dragStart: Double?
    @State private var script: Task<Void, Never>?
    @State private var scripting = false
    @GestureState private var finger = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _phase = State(initialValue: ctx.isStill ? 0.36 : 0.25)
    }

    var body: some View {
        StudioScene(hint: L("Drag left or right to change the phase", "左右拖动，改变月相"), ctx: ctx) {
            MoonCard(phase: phase, stars: ctx.int("stars"), glow: ctx["glow"], language: ctx.language, preview: ctx.isPreview)
                .padding(16)
                .frame(width: 288)
                .signatureCard()
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .gesture(drag)
                .onChange(of: finger) { _, down in
                    if !down && !scripting && dragStart != nil { release(to: phase) }
                }
        }
        .onDisappear { script?.cancel() }
        .autoplay(ctx.isPreview, every: 3.4, delay: 0.7) { runScript() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($finger) { _, state, _ in state = true }
            .onChanged { value in
                if dragStart == nil {
                    script?.cancel()
                    scripting = false
                    dragStart = phase
                }
                scrub(to: (dragStart ?? phase) + Double(value.translation.width) / ctx["travel"], user: true)
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                release(to: start + Double(value.predictedEndTranslation.width) / ctx["travel"])
            }
    }

    /// Shared by the finger and the scripted drag.
    private func scrub(to value: Double, user: Bool) {
        let before = Int((phase * 29.53).rounded(.down))
        phase = value
        if user && !ctx.isPreview && Int((value * 29.53).rounded(.down)) != before { Haptics.selection() }
    }

    private func release(to target: Double) {
        dragStart = nil
        let rest = ctx.bool("snap") ? (target * 8).rounded() / 8 : target
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { phase = rest }
    }

    private func runScript() {
        guard dragStart == nil else { return }
        script?.cancel()
        script = Task { @MainActor in
            scripting = true
            defer { scripting = false }
            let from = phase
            let finished = await studioScript(1.5) { t in
                scrub(to: from + 0.31 * studioEase(t), user: false)
            }
            guard finished else { return }
            release(to: phase + 0.05)
        }
    }
}

private enum MoonMath {
    static let names: [LocalizedText] = [
        L("New Moon", "新月"), L("Waxing Crescent", "蛾眉月"), L("First Quarter", "上弦月"), L("Waxing Gibbous", "盈凸月"),
        L("Full Moon", "满月"), L("Waning Gibbous", "亏凸月"), L("Last Quarter", "下弦月"), L("Waning Crescent", "残月"),
    ]

    static func wrapped(_ phase: Double) -> Double {
        let p = phase.truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }

    static func illumination(_ phase: Double) -> Double {
        (1 - cos(2 * .pi * phase)) / 2
    }

    static func nameIndex(_ phase: Double) -> Int {
        Int((wrapped(phase) * 8 + 0.5).rounded(.down)) % 8
    }
}

private struct MoonCard: View, Animatable {
    var phase: Double
    let stars: Int
    let glow: Double
    let language: AppLanguage
    let preview: Bool

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    private var zh: Bool { language == .zh }

    var body: some View {
        let p = MoonMath.wrapped(phase)
        let lit = MoonMath.illumination(p)
        let index = MoonMath.nameIndex(p)
        VStack(alignment: .leading, spacing: 10) {
            SportEyebrowRow(title: zh ? "月相" : "Moon phase", symbol: "moon.stars.fill", trailing: zh ? "十月" : "October")
            HStack(spacing: 14) {
                sky(p: p, lit: lit)
                VStack(alignment: .leading, spacing: 3) {
                    Text(MoonMath.names[index], language)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .id(index)
                        .transition(.opacity)
                        .frame(height: 38, alignment: .bottomLeading)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(verbatim: "\(Int((lit * 100).rounded()))")
                            .font(Signature.number(38))
                            .foregroundStyle(Color.white)
                        Text(verbatim: "%")
                            .font(Signature.number(17))
                            .foregroundStyle(Signature.accentSoft)
                    }
                    .lineLimit(1)
                    .fixedSize()
                    Text(verbatim: zh ? "照明度" : "Sunlit")
                        .signatureEyebrow()
                    Text(verbatim: zh ? String(format: "月龄 %.1f 天", p * 29.53) : String(format: "Day %.1f", p * 29.53))
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Signature.textSecondary)
                        .padding(.top, 4)
                }
                .animation(.easeOut(duration: 0.2), value: index)
                Spacer(minLength: 0)
            }
            MoonRuler(phase: phase)
                .frame(height: 30)
        }
    }

    private func sky(p: Double, lit: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x0A0E22), Color(hex: 0x161B3A)], startPoint: .top, endPoint: .bottom))
            MoonStars(count: stars, preview: preview)
                .opacity(1 - 0.6 * lit)
            Circle()
                .fill(Color(hex: 0xDCE6FF))
                .frame(width: 118, height: 118)
                .blur(radius: 22)
                .opacity(glow * (0.06 + 0.5 * lit))
            ZStack {
                MoonTexture()
                    .overlay(Color(hex: 0x070A16).opacity(0.87))
                MoonTexture()
                    .mask {
                        MoonLit(phase: p)
                            .fill(Color.white)
                            .blur(radius: 1.5)
                    }
            }
            .frame(width: 124, height: 124)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .frame(width: 148, height: 148)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// The sunlit part of the disc: the limb on one side, an elliptical terminator on the other.
private struct MoonLit: Shape {
    /// 0…1, 0 = new, 0.5 = full.
    var phase: Double

    func path(in rect: CGRect) -> Path {
        let r = Double(min(rect.width, rect.height) / 2) + 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let side: Double = phase < 0.5 ? 1 : -1
        let squash = cos(2 * .pi * phase)
        var path = Path()
        let steps = 40
        // Down the limb…
        for index in 0...steps {
            let y = -r + 2 * r * Double(index) / Double(steps)
            let half = (max(r * r - y * y, 0)).squareRoot()
            let point = CGPoint(x: center.x + CGFloat(side * half), y: center.y + CGFloat(y))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        // …and back up the terminator.
        for index in 0...steps {
            let y = r - 2 * r * Double(index) / Double(steps)
            let half = (max(r * r - y * y, 0)).squareRoot()
            path.addLine(to: CGPoint(x: center.x + CGFloat(side * squash * half), y: center.y + CGFloat(y)))
        }
        path.closeSubpath()
        return path
    }
}

/// Procedural moon: a shaded disc, soft dark maria and rimmed craters.
private struct MoonTexture: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let w = size.width
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xF4F1EA), Color(hex: 0xD9D5CC), Color(hex: 0xAFAAA0)]),
                    center: CGPoint(x: w * 0.42, y: w * 0.38),
                    startRadius: 0,
                    endRadius: w * 0.68
                )
            )
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                let maria: [(Double, Double, Double, Double)] = [(0.34, 0.30, 0.30, 0.22), (0.58, 0.44, 0.26, 0.30), (0.40, 0.62, 0.34, 0.20), (0.70, 0.72, 0.16, 0.14), (0.22, 0.52, 0.14, 0.18)]
                for sea in maria {
                    let box = CGRect(x: w * CGFloat(sea.0 - sea.2 / 2), y: w * CGFloat(sea.1 - sea.3 / 2), width: w * CGFloat(sea.2), height: w * CGFloat(sea.3))
                    layer.fill(Path(ellipseIn: box), with: .color(Color(hex: 0x7F7B76).opacity(0.5)))
                }
            }
            for index in 0..<16 {
                let seed = Double(index)
                let angle = sportHash(seed * 2.7) * 2 * .pi
                let distance = sportHash(seed * 5.1).squareRoot() * 0.44
                let center = CGPoint(x: w * CGFloat(0.5 + cos(angle) * distance), y: w * CGFloat(0.5 + sin(angle) * distance))
                let radius = w * CGFloat(0.018 + sportHash(seed * 8.3) * 0.04)
                let box = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: box), with: .color(Color(hex: 0x8C8880).opacity(0.5)))
                context.stroke(Path(ellipseIn: box.offsetBy(dx: 0.6, dy: 0.7)), with: .color(Color.white.opacity(0.5)), lineWidth: 0.8)
            }
        }
    }
}

private struct MoonStars: View {
    let count: Int
    let preview: Bool
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: isStill)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for index in 0..<count {
                    let seed = Double(index)
                    let point = CGPoint(x: size.width * CGFloat(sportHash(seed * 3.9)), y: size.height * CGFloat(sportHash(seed * 6.7)))
                    let twinkle = 0.5 + 0.5 * sin(t * (0.8 + sportHash(seed * 1.9) * 2.2) + seed * 1.7)
                    let radius = CGFloat(0.5 + sportHash(seed * 9.1) * 1.1)
                    context.opacity = 0.25 + 0.75 * twinkle
                    if index % 7 == 0 {
                        context.fill(studioSparkle(at: point, radius: radius * 3.2), with: .color(.white))
                    } else {
                        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(.white))
                    }
                }
            }
        }
    }
}

/// A ruler of lunar days sliding under a fixed pointer; a taller tick every 5 days, 30 ticks per cycle.
private struct MoonRuler: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 9
            let position = phase * 30
            let first = Int(position.rounded(.down)) - 18
            for tick in first...(first + 36) {
                let x = size.width / 2 + CGFloat(Double(tick) - position) * spacing
                guard x > -4, x < size.width + 4 else { continue }
                let day = ((tick % 30) + 30) % 30
                let major = day % 5 == 0
                let fade = Double(1 - min(abs(x - size.width / 2) / (size.width / 2), 1))
                var line = Path()
                line.move(to: CGPoint(x: x, y: 2))
                line.addLine(to: CGPoint(x: x, y: major ? 14 : 9))
                context.opacity = 0.2 + 0.8 * fade
                context.stroke(line, with: .color(Color.white.opacity(major ? 0.8 : 0.35)), style: StrokeStyle(lineWidth: major ? 1.6 : 1, lineCap: .round))
                if major {
                    context.draw(
                        Text(verbatim: "\(day)").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(Color.white.opacity(0.6)),
                        at: CGPoint(x: x, y: 23)
                    )
                }
            }
            context.opacity = 1
            var pointer = Path()
            pointer.move(to: CGPoint(x: size.width / 2, y: 0))
            pointer.addLine(to: CGPoint(x: size.width / 2, y: 17))
            context.stroke(pointer, with: .color(Signature.accent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }
}
