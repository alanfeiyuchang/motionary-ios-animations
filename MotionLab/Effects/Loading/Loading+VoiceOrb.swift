import SwiftUI

extension Effect {
    static let loadingVoiceOrb = Effect(
        id: "loading.voice-orb",
        category: .loading,
        interaction: .gesture,
        name: L("Listening Voice Orb", "聆听语音光球"),
        summary: L("A dark glass orb with drifting colour blobs that swells and ripples while you hold it.", "深色玻璃光球内彩色光团缓缓游动，按住时随“声音”鼓动并荡出涟漪。"),
        prompt: L(
            "A 150 pt dark glass orb holds five colour blobs (sky, violet, pink, mint, amber), each an ellipse on its own small orbit, blurred 18 pt and screen-blended so overlaps bloom toward white. At rest they drift slowly and the orb breathes about 2%. Press and hold: a listening level eases to 1 with a 0.18 s time constant, the blobs spin up to 2.4× speed and swing wider, the orb pulses up to 12% with a speech-like envelope, an outer halo brightens, and three hairline rings ripple outward 46 pt as they fade. A five-bar meter and the label switch to 'Listening…'. On release the level decays over 0.45 s. Soft haptics mark press and release. Attentive, liquid, alive.",
            "一颗 150 pt 的深色玻璃光球，内含五个彩色光团（天蓝、紫罗兰、粉、薄荷绿、琥珀），各自是沿小轨道运行的椭圆，经 18 pt 模糊并以滤色混合，重叠处向白色溢出。静止时光团缓慢游动，光球呼吸约 2%。按住后，聆听强度以 0.18 秒的时间常数升到 1：光团转速提到 2.4 倍、摆幅变大，光球按近似语音的包络鼓动，最大 12%，外圈光晕变亮，三道细线圆环向外荡出 46 pt 并淡去；五格音量条和文字切换为“正在聆听…”。松手后强度在 0.45 秒内回落。按下与松开各有轻柔触感。专注、流动。"
        ),
        implementation: L(
            "A TimelineView evaluates a closed-form exponential envelope (and its integral, for the spin phase) from the last press or release, then a Canvas draws the blobs on a blurred, screen-blended layer clipped to the circle.",
            "TimelineView 根据最近一次按下或松开的时刻，用指数包络的闭式解（及其积分，用作旋转相位）求出当前强度，再由 Canvas 在裁切为圆形的模糊滤色图层上绘制光团。"
        ),
        apis: ["Canvas", "TimelineView", "GraphicsContext.blendMode", "GraphicsContext.Filter.blur", "DragGesture(minimumDistance:)"],
        tags: ["siri", "voice", "orb", "listening", "语音", "光球", "聆听", "助手"],
        params: [
            .slider("blobs", L("Blobs", "光团数量"), 3...6, default: 5, step: 1, decimals: 0),
            .slider("soft", L("Softness", "柔化"), 8...28, default: 18, decimals: 0, unit: "pt"),
            .slider("gain", L("Reaction", "反应强度"), 0.3...1.6, default: 1.0),
        ]
    ) { ctx in
        VoiceOrbDemo(ctx: ctx)
    }
}

/// A level that eases exponentially toward a target; `value` and its running integral are closed-form
/// functions of time, so the view never has to integrate frame by frame.
private struct OrbEnvelope {
    var start = Date()
    var from: Double = 0
    var target: Double = 0
    var tau: Double = 0.45
    var area: Double = 0

    func value(at date: Date) -> Double {
        let dt: Double = max(date.timeIntervalSince(start), 0)
        return target + (from - target) * exp(-dt / tau)
    }

    /// ∫ level dt since the demo appeared.
    func integral(at date: Date) -> Double {
        let dt: Double = max(date.timeIntervalSince(start), 0)
        return area + target * dt + (from - target) * tau * (1 - exp(-dt / tau))
    }

    mutating func retarget(_ newTarget: Double, tau newTau: Double, at date: Date) {
        let level: Double = value(at: date)
        area = integral(at: date)
        from = level
        target = newTarget
        tau = newTau
        start = date
    }
}

private struct VoiceOrbDemo: View {
    let ctx: DemoContext
    @State private var envelope = OrbEnvelope()
    @State private var listening = false
    @State private var pressedAt = Date.distantPast
    @State private var releaseTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let level: Double = ctx.isStill ? 0.85 : envelope.value(at: timeline.date)
                let spin: Double = ctx.isStill ? 2.0 : envelope.integral(at: timeline.date)
                let t: Double = ctx.isStill ? 3.1 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                VStack(spacing: 16) {
                    VoiceOrbView(
                        t: t,
                        spin: spin,
                        level: level,
                        blobs: max(ctx.int("blobs"), 1),
                        soft: ctx.cg("soft"),
                        gain: ctx["gain"]
                    )
                    .frame(width: 250, height: 216)
                    .contentShape(Circle().inset(by: 20))
                    .gesture(hold)
                    VoiceOrbMeter(t: t, level: level, gain: ctx["gain"])
                }
            }
            VStack(spacing: 6) {
                Text(listening ? L("Listening…", "正在聆听…") : L("Ask me anything", "有什么可以帮你"), ctx.language)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.interpolate)
                    .animation(.smooth(duration: 0.3), value: listening)
                DemoHint(text: L("Press and hold the orb", "按住光球"), ctx: ctx)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.4, delay: 0.8) { simulate() }
        .onDisappear {
            releaseTask?.cancel()
            releaseTask = nil
            listening = false
            envelope = OrbEnvelope()
        }
    }

    private var hold: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !listening || releaseTask != nil { begin() }
            }
            .onEnded { _ in end() }
    }

    private func begin() {
        releaseTask?.cancel()
        releaseTask = nil
        guard !listening else { return }
        listening = true
        pressedAt = .now
        envelope.retarget(1, tau: 0.18, at: .now)
        Haptics.tap(.soft)
    }

    /// A quick tap still listens for a moment, so the reaction is always visible.
    private func end() {
        let remaining: Double = 1.1 - Date.now.timeIntervalSince(pressedAt)
        releaseTask?.cancel()
        guard remaining > 0 else {
            release()
            return
        }
        releaseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            release()
        }
    }

    private func release() {
        releaseTask = nil
        guard listening else { return }
        listening = false
        envelope.retarget(0, tau: 0.45, at: .now)
        Haptics.tap(.light)
    }

    /// Preview / intro: the same begin → end path a finger takes, held for 2.2 s.
    private func simulate() {
        begin()
        releaseTask?.cancel()
        releaseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            Haptics.isMuted = true
            release()
            Haptics.isMuted = false
        }
    }
}

private enum OrbVoice {
    /// A speech-like loudness in 0…1: syllables riding on slower phrases.
    static func loudness(_ t: Double) -> Double {
        let syllable: Double = abs(sin(t * 7.1) * sin(t * 2.9 + 0.7))
        let phrase: Double = 0.6 + 0.4 * sin(t * 1.3 + 2)
        return min(0.25 + 0.9 * pow(syllable, 0.7) * phrase, 1)
    }
}

private struct VoiceOrbView: View {
    let t: Double
    let spin: Double
    let level: Double
    let blobs: Int
    let soft: CGFloat
    let gain: Double

    private let diameter: CGFloat = 150
    private static let colors: [Color] = [Palette.sky, Palette.violet, Palette.pink, Palette.mint, Palette.amber, Palette.indigo]
    private static let rates: [Double] = [0.55, -0.42, 0.78, -0.66, 0.36, -0.9]

    var body: some View {
        let voice: Double = level * OrbVoice.loudness(t) * gain
        let breath: Double = 0.02 * sin(t * 1.5)
        let scale: CGFloat = CGFloat(1 + breath + 0.12 * min(voice, 1.4))
        ZStack {
            rings
            halo(voice: voice)
            orb(voice: voice)
                .scaleEffect(scale)
        }
    }

    private var rings: some View {
        Canvas { context, size in
            guard level > 0.02 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for index in 0..<3 {
                let p: Double = (t * 0.7 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                let r: CGFloat = diameter / 2 + 4 + 46 * CGFloat(p)
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                let alpha: Double = 0.5 * level * (1 - p) * min(p * 6, 1)
                context.stroke(Path(ellipseIn: rect), with: .color(Palette.violet.opacity(alpha)), lineWidth: 1.5)
            }
        }
        .allowsHitTesting(false)
    }

    private func halo(voice: Double) -> some View {
        Circle()
            .fill(AngularGradient(colors: [Palette.sky, Palette.violet, Palette.pink, Palette.mint, Palette.sky], center: .center, angle: .degrees(t * 40)))
            .frame(width: diameter, height: diameter)
            .scaleEffect(CGFloat(1.0 + 0.10 * min(voice, 1.4)))
            .blur(radius: 18)
            .opacity(0.28 + 0.45 * min(voice, 1))
    }

    private func orb(voice: Double) -> some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let radius: CGFloat = size.width / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            context.clip(to: Path(ellipseIn: rect))
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0x1C2150), Color(hex: 0x0A0B22)]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            let reach: Double = 0.34 + 0.24 * min(voice, 1.3)
            context.blendMode = .plusLighter
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: soft))
                layer.blendMode = .screen
                for index in 0..<blobs {
                    let rate: Double = VoiceOrbView.rates[index % VoiceOrbView.rates.count]
                    // Base drift plus the extra turns earned while listening (1.4 × the level's integral).
                    let angle: Double = (t + 1.4 * spin) * rate * 2.2 + Double(index) * 2.1
                    let wobble: Double = 0.5 + 0.5 * sin(t * (0.9 + 0.23 * Double(index)) + Double(index))
                    let distance: CGFloat = radius * CGFloat(reach * (0.7 + 0.3 * wobble))
                    let w: CGFloat = radius * CGFloat(0.66 + 0.18 * wobble + 0.22 * min(voice, 1))
                    let h: CGFloat = w * 0.62
                    let x: CGFloat = center.x + distance * CGFloat(cos(angle))
                    let y: CGFloat = center.y + distance * CGFloat(sin(angle))
                    var blob = layer
                    blob.translateBy(x: x, y: y)
                    blob.rotate(by: .radians(angle * 0.8))
                    let ellipse = Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                    blob.fill(ellipse, with: .color(VoiceOrbView.colors[index % VoiceOrbView.colors.count].opacity(0.78)))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay {
            // Glass: a soft top-left specular and a rim that is brighter on the lit side.
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 84, height: 44)
                .blur(radius: 6)
                .offset(x: -14, y: -42)
        }
        .overlay {
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
        }
        .shadow(color: Palette.violet.opacity(0.35), radius: 18, y: 10)
    }
}

private struct VoiceOrbMeter: View {
    let t: Double
    let level: Double
    let gain: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                let voice: Double = OrbVoice.loudness(t - Double(index) * 0.07) * (index == 2 ? 1 : (index % 4 == 0 ? 0.55 : 0.8))
                let height: CGFloat = 4 + 16 * CGFloat(min(level * voice * gain, 1))
                Capsule()
                    .fill(LinearGradient(colors: [Palette.sky, Palette.violet], startPoint: .bottom, endPoint: .top))
                    .frame(width: 4, height: height)
                    .opacity(0.35 + 0.65 * min(level, 1))
            }
        }
        .frame(height: 22)
    }
}
