import SwiftUI

extension Effect {
    static let scrollVelocitySkew = Effect(
        id: "scroll.velocity-skew",
        category: .scroll,
        interaction: .scroll,
        name: L("Velocity Skew Strip", "速度倾斜卡片带"),
        summary: L("Cards lean and stretch with the scroll speed, like sails in the wind, then spring upright.", "卡片随滚动速度倾斜、拉伸，像被风吹动的帆，随后弹回直立。"),
        prompt: L(
            "A horizontal strip of 150 × 200 pt gradient cards with 14 pt gaps. The scroll velocity, measured in pt/s and normalised at 1800 pt/s, shears every card: at full speed the top edge trails the bottom by 16°, the card stretches 10% wider and 3.5% shorter, the artwork inside drifts 10 pt against the motion and the caption lags 8 pt behind it. A slow drag barely tilts them; a hard flick lays them over. The shear follows the velocity through a spring (response 0.32 s, damping 0.5), so when the strip stops the cards swing upright, overshoot the other way once and settle. A small gauge under the strip shows the live speed. Elastic and airy, as if the cards had mass.",
            "一排150×200 pt的渐变卡片横向排列，间距14 pt。滚动速度以pt/s计量，并以1800 pt/s归一化，用来对每张卡片做切变：全速时上沿比下沿滞后16°，卡片横向拉宽10%、纵向压矮3.5%，卡片里的画面逆着运动方向漂移10 pt，标题则滞后8 pt。慢慢拖动时几乎不倾斜，用力一甩就会明显倒伏。切变量通过弹簧（响应0.32秒、阻尼0.5）跟随速度，所以卡片带停下时，卡片会摆回直立、向反方向过冲一次再稳住。下方的小仪表显示实时速度。轻盈而有弹性，仿佛卡片真的有质量。"
        ),
        implementation: L(
            "onScrollGeometryChange feeds a frame-rate-independent velocity tracker; the normalised speed drives a shear GeometryEffect, a non-uniform scaleEffect and inner parallax offsets, all animated by one spring keyed on the velocity. A 70 ms watchdog zeroes the speed when the finger holds still.",
            "onScrollGeometryChange 把偏移喂给与帧率无关的速度跟踪器；归一化后的速度驱动切变 GeometryEffect、非等比 scaleEffect 以及内部的视差位移，全部由一个以速度为键的弹簧动画带动。手指按住不动时，一个 70 毫秒的看门狗把速度归零。"
        ),
        apis: ["onScrollGeometryChange", "GeometryEffect", "CGAffineTransform", "scaleEffect", "spring(response:dampingFraction:)"],
        tags: ["skew", "velocity", "shear", "stretch", "carousel", "倾斜", "速度", "切变", "拉伸", "轮播"],
        params: [
            .slider("angle", L("Max skew", "最大倾斜"), 0...30, default: 16, step: 1, decimals: 0, unit: "°"),
            .slider("stretch", L("Stretch", "拉伸"), 0...0.3, default: 0.1),
            .slider("damping", L("Damping", "阻尼"), 0.3...1.0, default: 0.5),
        ]
    ) { ctx in
        ScrollSkewDemo(ctx: ctx)
    }
}

private let scrollSkewTopSpeed: CGFloat = 1800

private struct ScrollSkewDemo: View {
    let ctx: DemoContext
    @State private var position = ScrollPosition(edge: .leading)
    /// Scroll velocity in pt/s (positive while the content moves left).
    @State private var velocity: CGFloat
    @State private var tracker = ScrollVelocityTracker()
    @State private var settleTask: Task<Void, Never>?
    @State private var step = 0

    private let cardSize = CGSize(width: 150, height: 200)

    /// A still shows the strip caught mid-flick, so the thumbnail reads as "skewed by speed".
    init(ctx: DemoContext) {
        self.ctx = ctx
        _velocity = State(initialValue: ctx.isStill ? 1100 : 0)
    }

    var body: some View {
        let speed: CGFloat = (velocity / scrollSkewTopSpeed).clamped(to: -1...1)
        VStack(spacing: 14) {
            strip(speed: speed)
            ScrollSkewGauge(velocity: velocity, speed: speed)
            DemoHint(text: L("Flick the strip", "用力甩动卡片带"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear { settleTask?.cancel() }
        .autoplay(ctx.isPreview, every: 1.5) { autoFlick() }
    }

    private func strip(speed: CGFloat) -> some View {
        let shear: CGFloat = CGFloat(tan(ctx["angle"] * .pi / 180)) * speed
        let stretch: CGFloat = ctx.cg("stretch") * abs(speed)
        let spring: Animation = .spring(response: 0.32, dampingFraction: ctx["damping"])
        return ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(0..<12, id: \.self) { i in
                    ScrollSkewCard(index: i, language: ctx.language, size: cardSize, speed: speed)
                        .modifier(ScrollSkewShear(shear: shear))
                        .scaleEffect(x: 1 + stretch, y: 1 - stretch * 0.35)
                        .animation(spring, value: velocity)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.x + geometry.contentInsets.leading
        }, action: { _, newValue in
            // A still keeps its seeded mid-flick speed.
            guard !ctx.isStill else { return }
            velocity = tracker.sample(newValue, limit: 3000)
            scheduleSettle()
        })
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .idle {
                settleTask?.cancel()
                settle()
            }
        }
    }

    /// Geometry only changes while the content moves, so 70 ms of silence means "stopped".
    private func scheduleSettle() {
        settleTask?.cancel()
        settleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(70))
            guard !Task.isCancelled else { return }
            settle()
        }
    }

    private func settle() {
        tracker.reset()
        velocity = 0
    }

    private func autoFlick() {
        let targets: [CGFloat] = [620, 240, 1180, 760, 1400, 0]
        let target = targets[step % targets.count]
        step += 1
        withAnimation(.spring(response: 0.75, dampingFraction: 0.92)) {
            position.scrollTo(x: target)
        }
    }
}

/// Horizontal shear about the card's vertical centre: positive values push the top edge to the right.
private struct ScrollSkewShear: GeometryEffect {
    var shear: CGFloat

    var animatableData: CGFloat {
        get { shear }
        set { shear = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(a: 1, b: 0, c: -shear, d: 1, tx: shear * size.height / 2, ty: 0))
    }
}

private struct ScrollSkewCard: View {
    let index: Int
    let language: AppLanguage
    let size: CGSize
    let speed: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        LinearGradient(colors: ScrollKit.colors(index), startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                // The glyph and its glow drift against the motion.
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 130, height: 130)
                        .blur(radius: 22)
                        .offset(x: 34, y: -50)
                    Image(systemName: ScrollKit.symbol(index))
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                        .offset(y: -22)
                }
                .offset(x: -speed * 10)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ScrollKit.title(index), language)
                        .font(.headline.weight(.bold))
                    Text(ScrollKit.subtitle(index), language)
                        .font(.caption2.weight(.medium))
                        .opacity(0.85)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(14)
                // The caption lags behind the card.
                .offset(x: speed * 8)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .shadow(color: ScrollKit.colors(index)[0].opacity(0.3), radius: 14, x: -speed * 10, y: 10)
    }
}

/// Live speed readout: a centre-zero bar and the velocity in pt/s.
private struct ScrollSkewGauge: View {
    let velocity: CGFloat
    let speed: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wind")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            ZStack {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [Palette.mint, Palette.sky, Palette.violet], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(abs(speed) * 60, 4))
                    .offset(x: speed * 30)
            }
            .frame(width: 120, height: 5)
            Text(verbatim: "\(Int((abs(velocity) / 10).rounded()) * 10) pt/s")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: speed)
    }
}
