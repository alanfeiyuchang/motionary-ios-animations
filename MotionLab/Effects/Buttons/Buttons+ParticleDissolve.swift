import SwiftUI
import UIKit

extension Effect {
    static let buttonsParticleDissolve = Effect(
        id: "buttons.particle-dissolve",
        category: .buttons,
        interaction: .tap,
        name: L("Particle Dissolve Label", "粒子消散文字"),
        summary: L(
            "The label crumbles into drifting dust, then the same particles reassemble into the next label.",
            "文字碎成飘散的尘埃，随后同一批粒子重新聚合成新的文字。"
        ),
        prompt: L(
            "A 232 × 60 pt gradient pill reading “Send invite” with a paper-plane glyph. On tap the label is sampled on a 1.5 pt grid and replaced by one square particle per sample. Disintegration sweeps left to right: each particle waits up to 0.38 s by its x position plus a random 0.14 s, then drifts up and to the right about 28 pt over 0.75 s on an ease-out, fanning out with per-particle turbulence, shrinking to 70% and fading to half opacity while it keeps bobbing. As the label empties, the pill cross-fades to a soft green state. From 0.9 s the dust is pulled into the new label “Invite sent” with a check, again left to right, each particle landing over 0.7 s with a slight overshoot and recolouring from white to green; then the crisp text swaps in. Tapping again runs it back. Magical and granular.",
            "232×60pt 的渐变胶囊，写着“发送邀请”并带纸飞机图标。点击后，文字按 1.5pt 网格采样，每个采样点换成一粒方形粒子。消散自左向右推进：每粒按横向位置最多等 0.38 秒，外加 0.14 秒内的随机延迟，再用 0.75 秒以 ease-out 向右上方飘出约 28pt，带扰动散开，缩小到 70%、透明度减半，并持续浮动。文字散尽时，胶囊淡入柔和的绿色状态。0.9 秒起，尘埃被吸入新文字“邀请已发送”与对勾，同样自左向右，每粒用 0.7 秒带过冲落位，由白变绿；最后换回清晰文字。再点一次则反向播放。"
        ),
        implementation: L(
            "Each label is rendered once into a UIImage; its alpha is read back from a grayscale CGContext to get the particle homes, and the same image is shown as the crisp label so both align exactly. A TimelineView Canvas then places every particle as a pure function of time: staggered ease-out drift from its source point, then an overshooting pull to a target point of the next label.",
            "每个文字先渲染成一张 UIImage，再从灰度 CGContext 读回 alpha 得到粒子的原位；同一张图片也用作清晰文字，保证两者完全对齐。随后 TimelineView 中的 Canvas 把每粒粒子的位置写成时间的纯函数：从源点错峰 ease-out 飘散，再带过冲地被拉向下一个文字的目标点。"
        ),
        apis: ["UIGraphicsImageRenderer", "CGContext", "TimelineView", "Canvas", "GraphicsContext.fill"],
        tags: ["particles", "dissolve", "dust", "label", "粒子", "消散", "尘埃", "文字"],
        params: [
            .slider("grain", L("Grain size", "颗粒大小"), 1...3, default: 1.5, decimals: 1, unit: "pt"),
            .slider("drift", L("Drift distance", "飘散距离"), 10...70, default: 28, decimals: 0, unit: "pt"),
            .slider("turbulence", L("Turbulence", "扰动"), 0...1, default: 0.5),
            .slider("speed", L("Speed", "速度"), 0.5...2, default: 1, unit: "×"),
        ]
    ) { ctx in
        ButtonDustDemo(ctx: ctx)
    }
}

/// A rendered label: the crisp image and the sample points (relative to its centre) that particles call home.
private struct ButtonDustLabel {
    let image: UIImage
    let points: [CGPoint]
    let width: CGFloat
}

private enum ButtonDustSampler {
    @MainActor
    static func make(text: String, symbol: String, step: CGFloat) -> ButtonDustLabel {
        let font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.white])
        let textSize = string.size()
        let icon = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        let iconSize = icon?.size ?? .zero
        let spacing: CGFloat = iconSize.width > 0 ? 8 : 0
        let size = CGSize(
            width: ceil(iconSize.width + spacing + textSize.width) + 4,
            height: ceil(max(iconSize.height, textSize.height)) + 4
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            icon?.draw(at: CGPoint(x: 2, y: (size.height - iconSize.height) / 2))
            string.draw(at: CGPoint(x: 2 + iconSize.width + spacing, y: (size.height - textSize.height) / 2))
        }
        return ButtonDustLabel(
            image: image.withRenderingMode(.alwaysTemplate),
            points: sample(image, size: size, step: step),
            width: size.width
        )
    }

    /// Reads the image's coverage on a `step`-point grid.
    private static func sample(_ image: UIImage, size: CGSize, step: CGFloat) -> [CGPoint] {
        let scale: CGFloat = 2
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        guard width > 0, height > 0, let cgImage = image.cgImage,
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGImageAlphaInfo.none.rawValue
              )
        else { return [] }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // White glyphs over black: luminance equals coverage. Row 0 of the buffer is the top of the image.
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return [] }
        let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
        let stride = context.bytesPerRow
        var points: [CGPoint] = []
        var y = step / 2
        while y < size.height {
            var x = step / 2
            while x < size.width {
                let px = min(Int(x * scale), width - 1)
                let py = min(Int(y * scale), height - 1)
                if bytes[py * stride + px] > 96 {
                    points.append(CGPoint(x: x - size.width / 2, y: y - size.height / 2))
                }
                x += step
            }
            y += step
        }
        return points
    }
}

private struct ButtonDustParticle {
    let from: CGPoint
    let to: CGPoint
    /// 0…1 horizontal position inside the source / target label: drives the left-to-right sweep.
    let fromSweep: Double
    let toSweep: Double
    let r1: Double
    let r2: Double
    let r3: Double
    let r4: Double
}

private struct ButtonDustRun {
    let start: Date
    let particles: [ButtonDustParticle]
    /// `true` when running from the first label to the second.
    let forward: Bool
}

private struct ButtonDustDemo: View {
    let ctx: DemoContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var sent = false
    @State private var labels: [ButtonDustLabel] = []
    @State private var run: ButtonDustRun?
    @State private var labelVisible = true
    @State private var taps = 0
    @State private var finishTask: Task<Void, Never>?

    private static let size = CGSize(width: 232, height: 60)
    /// Length of one run at speed 1.
    private static let total = 2.15
    private var speed: Double { max(ctx["speed"], 0.2) }
    private var labelKey: String { "\(ctx.language.rawValue)-\(ctx["grain"])" }

    private var greenInk: Color { colorScheme == .dark ? Color(hex: 0x5BE49B) : Color(hex: 0x17803F) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            control
            Spacer()
            DemoHint(text: L("Tap the button", "点击按钮"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: labelKey) { rebuildLabels() }
        .autoplay(ctx.isPreview, every: Self.total / speed + 1.1, delay: 0.5) { dissolve(haptics: false) }
        .onDisappear { finishTask?.cancel() }
    }

    private var control: some View {
        ZStack {
            face
            dust
        }
        .frame(width: 320, height: 200)
    }

    private var face: some View {
        Button {
            Haptics.tap(.medium)
            taps += 1
            dissolve(haptics: true)
        } label: {
            ZStack {
                Capsule().fill(Palette.primary)
                Capsule()
                    .fill(Palette.elevated)
                    .overlay(Capsule().fill(Palette.green.opacity(0.18)))
                    .overlay(Capsule().strokeBorder(Palette.green.opacity(0.55), lineWidth: 1.2))
                    .opacity(sent ? 1 : 0)
                crispLabel
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .shadow(color: (sent ? Palette.green : Palette.indigo).opacity(sent ? 0.2 : 0.36), radius: 16, y: 9)
        }
        .buttonStyle(ButtonDustPressStyle(taps: taps))
    }

    @ViewBuilder
    private var crispLabel: some View {
        let index = sent ? 1 : 0
        if labels.count == 2 {
            Image(uiImage: labels[index].image)
                .renderingMode(.template)
                .foregroundStyle(sent ? greenInk : Color.white)
                .opacity(labelVisible ? 1 : 0)
        } else {
            // Before the first sample (and in stills): the plain text.
            Label {
                Text(L("Send invite", "发送邀请"), ctx.language)
            } icon: {
                Image(systemName: "paperplane.fill")
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
        }
    }

    private var dust: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview), paused: run == nil)) { timeline in
            Canvas { context, size in
                guard let run else { return }
                let t = timeline.date.timeIntervalSince(run.start) * speed
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let white = Color.white.resolve(in: EnvironmentValues())
                let green = greenInk.resolve(in: EnvironmentValues())
                let source = run.forward ? white : green
                let target = run.forward ? green : white
                let grain = ctx.cg("grain")
                let drift = ctx["drift"]
                let turbulence = ctx["turbulence"]
                for particle in run.particles {
                    let state = Self.state(of: particle, at: t, drift: drift, turbulence: turbulence)
                    let side = grain * CGFloat(state.scale)
                    let mix = Float(state.settle)
                    let color = Color(
                        .sRGB,
                        red: Double(source.red + (target.red - source.red) * mix),
                        green: Double(source.green + (target.green - source.green) * mix),
                        blue: Double(source.blue + (target.blue - source.blue) * mix),
                        opacity: state.alpha
                    )
                    context.fill(
                        Path(CGRect(x: center.x + state.x - side / 2, y: center.y + state.y - side / 2, width: side, height: side)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Where one particle is `t` seconds into the run: staggered ease-out drift, then an overshooting pull home.
    private static func state(
        of particle: ButtonDustParticle,
        at t: Double,
        drift: Double,
        turbulence: Double
    ) -> (x: CGFloat, y: CGFloat, alpha: Double, scale: Double, settle: Double) {
        let leave = ((t - (particle.fromSweep * 0.38 + particle.r1 * 0.14)) / 0.75).clamped(to: 0...1)
        let out = 1 - pow(1 - leave, 3)
        // Up and to the right, fanned out by the turbulence.
        let angle = -0.62 + (particle.r2 - 0.5) * 2.4 * turbulence
        let distance = drift * (0.55 + 0.9 * particle.r3)
        let bob = 3 * turbulence * out
        let dustX = Double(particle.from.x) + cos(angle) * distance * out + sin(t * 2.1 + particle.r1 * 6.28) * bob
        let dustY = Double(particle.from.y) + sin(angle) * distance * out + cos(t * 1.7 + particle.r2 * 6.28) * bob

        let arrive = ((t - (0.92 + particle.toSweep * 0.34 + particle.r4 * 0.12)) / 0.7).clamped(to: 0...1)
        // Ease-out-back: lands a touch past home and settles.
        let back = arrive - 1
        let settle = 1 + 2.4 * back * back * back + 1.4 * back * back
        let x = dustX + (Double(particle.to.x) - dustX) * settle
        let y = dustY + (Double(particle.to.y) - dustY) * settle
        let loose = out * (1 - arrive)
        return (CGFloat(x), CGFloat(y), 1 - 0.5 * loose, 1 - 0.3 * loose, arrive)
    }

    // MARK: Behaviour

    private func rebuildLabels() {
        guard !ctx.isStill else { return }
        // A grain or language change mid-run drops the run: its particles belong to the old samples.
        finishTask?.cancel()
        run = nil
        labelVisible = true
        let step = ctx.cg("grain")
        let zh = ctx.language == .zh
        labels = [
            ButtonDustSampler.make(text: zh ? "发送邀请" : "Send invite", symbol: "paperplane.fill", step: step),
            ButtonDustSampler.make(text: zh ? "邀请已发送" : "Invite sent", symbol: "checkmark.circle.fill", step: step),
        ]
    }

    private func dissolve(haptics: Bool) {
        guard run == nil, labels.count == 2 else { return }
        let forward = !sent
        let source = labels[forward ? 0 : 1]
        let target = labels[forward ? 1 : 0]
        guard !source.points.isEmpty, !target.points.isEmpty else { return }
        run = ButtonDustRun(start: Date(), particles: Self.pair(source, target), forward: forward)
        labelVisible = false
        let length = Self.total / speed
        withAnimation(.smooth(duration: 0.55 / speed).delay(0.45 / speed)) { sent = forward }
        finishTask?.cancel()
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(length))
            guard !Task.isCancelled else { return }
            labelVisible = true
            run = nil
            // The moment the last grains click into place.
            if haptics { Haptics.tap(.soft) }
        }
    }

    /// Pairs source and target samples in left-to-right order, so the dust flows across instead of criss-crossing.
    private static func pair(_ source: ButtonDustLabel, _ target: ButtonDustLabel) -> [ButtonDustParticle] {
        let from = source.points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        let to = target.points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        let count = max(from.count, to.count)
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { index in
            let a = from[index * from.count / count]
            let b = to[index * to.count / count]
            return ButtonDustParticle(
                from: a,
                to: b,
                fromSweep: Double(a.x / source.width + 0.5),
                toSweep: Double(b.x / target.width + 0.5),
                r1: Double.random(in: 0...1, using: &generator),
                r2: Double.random(in: 0...1, using: &generator),
                r3: Double.random(in: 0...1, using: &generator),
                r4: Double.random(in: 0...1, using: &generator)
            )
        }
    }
}

private struct ButtonDustPressStyle: ButtonStyle {
    let taps: Int

    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(isPressed: configuration.isPressed, taps: taps) { pressed in
            configuration.label
                .scaleEffect(pressed ? 0.96 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
    }
}
