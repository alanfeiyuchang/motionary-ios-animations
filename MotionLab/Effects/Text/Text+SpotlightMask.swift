import SwiftUI

extension Effect {
    static let textSpotlightMask = Effect(
        id: "text.spotlight-mask",
        category: .text,
        interaction: .gesture,
        name: L("Spotlight Reading", "聚光灯阅读"),
        summary: L("A paragraph sleeps at low contrast until a soft spotlight passes over it; the light follows your finger.", "整段文字低对比地沉睡着，直到一束柔光经过才亮起；光跟着手指走。"),
        prompt: L(
            "A paragraph of 22 pt bold type rests at 14% opacity, barely readable. A soft circular spotlight of 95 pt radius wanders across it in a slow figure-eight; inside it the same text is shown at full contrast through a radial mask whose edge feathers over the outer 60% of the radius, and at the core the letters warm into a coral-to-violet gradient, with a faint glow on the surface behind. Touching the stage takes over: the light glides to the finger on a quick spring (response 0.22 s, damping 0.8) and widens 15%, trailing slightly behind fast movement. On release it shrinks back and drifts into its figure-eight on a slower spring. Quiet, intimate, like reading by torchlight.",
            "一段22pt粗体文字以14%的不透明度静静躺着，几乎读不清。一束半径95pt的圆形柔光沿着缓慢的“8”字在段落上游走：光圈内，同一段文字透过径向蒙版以完整对比度显现，蒙版边缘在半径外侧的60%范围内羽化；光心处的文字还会暖成珊瑚到紫色的渐变，背后的底面泛起一层淡淡的光晕。手指按上舞台即可接管：光以很快的弹簧（响应0.22秒、阻尼0.8）滑向指尖并放大15%，快速移动时略微滞后。松手后光圈缩回，再由一根更慢的弹簧带回“8”字轨迹。安静、私密，像打着手电读书。"
        ),
        implementation: L(
            "Three copies of the same Text are stacked: a dim one, a full-contrast one and a gradient one, the last two masked by RadialGradient circles positioned at the light; a TimelineView steps a spring that chases either the figure-eight point or the finger.",
            "同一段 Text 叠三层：暗淡的一层、完整对比度的一层和渐变的一层，后两层以放在光点位置的 RadialGradient 圆形作蒙版；TimelineView 步进一根弹簧，让光追随“8”字轨迹上的点或手指。"
        ),
        apis: ["mask(alignment:_:)", "RadialGradient", "TimelineView", "DragGesture", "position(_:)"],
        tags: ["spotlight", "mask", "reveal", "torch", "focus", "聚光灯", "蒙版", "手电", "聚焦", "阅读"],
        params: [
            .slider("radius", L("Light radius", "光圈半径"), 50...160, default: 95, decimals: 0, unit: "pt"),
            .slider("softness", L("Edge softness", "边缘柔和度"), 0.1...0.95, default: 0.6),
            .slider("dim", L("Resting opacity", "静置不透明度"), 0.04...0.4, default: 0.14),
            .slider("speed", L("Wander speed", "游走速度"), 0.1...1.5, default: 0.6),
        ]
    ) { ctx in
        TextSpotlightMaskDemo(ctx: ctx)
    }
}

private struct SpotlightSim {
    var last: Date?
    var theta: Double = 0.9
    var x = TextFXSpring()
    var y = TextFXSpring()
    var grow = TextFXSpring()
    var started = false
}

private struct SpotlightFrame {
    var centre: CGPoint
    var scale: CGFloat
}

private struct TextSpotlightMaskDemo: View {
    let ctx: DemoContext
    @State private var sim = TextFXBox(SpotlightSim())
    @State private var finger = CGPoint.zero
    @State private var held = false
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    private let stage = CGSize(width: 304, height: 250)

    var body: some View {
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let frame = advance(to: timeline.date)
                layers(frame)
            }
            .frame(width: stage.width, height: stage.height)
            .contentShape(Rectangle())
            .gesture(drag)
            .onChange(of: pressing) { _, isPressing in
                if !isPressing { release() }
            }
            DemoHint(text: L("Drag the light across the text", "拖动光圈扫过文字"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear { script?.cancel() }
    }

    private var paragraph: some View {
        Text(
            L(
                "Look closer. The best details hide in plain sight: a softer shadow, a spring that settles, a pause before the reveal. Light finds them one at a time.",
                "凑近一点看。最好的细节都藏在明处：柔一点的阴影，恰好停稳的弹簧，揭晓前的那一下停顿。光一次只照亮一处。"
            ),
            ctx.language
        )
        .font(.system(size: ctx.language == .zh ? 26 : 22, weight: .bold))
        .lineSpacing(ctx.language == .zh ? 8 : 6)
        .multilineTextAlignment(.leading)
        .frame(width: stage.width, height: stage.height, alignment: .leading)
    }

    private func layers(_ frame: SpotlightFrame) -> some View {
        let radius: CGFloat = ctx.cg("radius") * frame.scale
        return ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Palette.coral.opacity(0.20), Palette.violet.opacity(0.08), Palette.violet.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius * 1.15
                ))
                .frame(width: radius * 2.3, height: radius * 2.3)
                .position(frame.centre)
            paragraph
                .foregroundStyle(Color.primary.opacity(ctx["dim"]))
            paragraph
                .foregroundStyle(Color.primary)
                .mask { light(at: frame.centre, radius: radius, softness: ctx.cg("softness")) }
            paragraph
                .foregroundStyle(LinearGradient(colors: [Palette.coral, Palette.pink, Palette.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                .mask { light(at: frame.centre, radius: radius * 0.62, softness: 0.9) }
        }
    }

    private func light(at centre: CGPoint, radius: CGFloat, softness: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [.black, .black.opacity(0)],
                center: .center,
                startRadius: radius * (1 - softness),
                endRadius: radius
            ))
            .frame(width: radius * 2, height: radius * 2)
            .position(centre)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if !held { Haptics.tap(.soft) }
                script?.cancel()
                touch(at: value.location)
            }
            .onEnded { _ in release() }
    }

    private func touch(at point: CGPoint) {
        held = true
        finger = point
    }

    private func release() {
        held = false
    }

    /// The figure-eight the light follows on its own.
    private func wander(_ theta: Double) -> CGPoint {
        CGPoint(
            x: stage.width / 2 + CGFloat(sin(theta)) * stage.width * 0.36,
            y: stage.height / 2 + CGFloat(sin(theta * 2)) * stage.height * 0.26
        )
    }

    private func advance(to date: Date) -> SpotlightFrame {
        var state = sim.value
        if ctx.isStill {
            return SpotlightFrame(centre: wander(state.theta), scale: 1)
        }
        if !state.started {
            let start = wander(state.theta)
            state.x.value = Double(start.x)
            state.y.value = Double(start.y)
            state.started = true
        }
        if let last = state.last {
            let dt: Double = min(max(date.timeIntervalSince(last), 0), 0.1)
            if dt > 0 {
                if !held { state.theta += ctx["speed"] * dt * 1.6 }
                let target: CGPoint = held ? finger : wander(state.theta)
                let response: Double = held ? 0.22 : 0.7
                let damping: Double = held ? 0.8 : 0.9
                state.x.step(to: Double(target.x), dt: dt, response: response, damping: damping)
                state.y.step(to: Double(target.y), dt: dt, response: response, damping: damping)
                state.grow.step(to: held ? 1 : 0, dt: dt, response: 0.35, damping: 0.6)
                state.last = date
            }
        } else {
            state.last = date
        }
        sim.value = state
        return SpotlightFrame(
            centre: CGPoint(x: state.x.value, y: state.y.value),
            scale: 1 + 0.15 * CGFloat(state.grow.value)
        )
    }
}
