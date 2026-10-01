import SwiftUI

extension Effect {
    static let loadingScanReveal = Effect(
        id: "loading.scan-reveal",
        category: .loading,
        interaction: .gesture,
        name: L("Scan Reveal", "扫描显影"),
        summary: L("A bar of light sweeps a blurred, blocky photo and leaves it sharp in its wake.", "一道光条扫过模糊带色块的照片，所过之处变得清晰。"),
        prompt: L(
            "A 264 × 176 pt photo card starts degraded: blurred 14 pt, desaturated to 45%, and overlaid with a flickering grid of 12 pt translucent blocks. A 3 pt white scan bar with a mint glow sweeps across in 2.2 s on a (0.5, 0, 0.2, 1) curve. Behind it the photo is revealed sharp through a mask that grows with the bar, and a 48 pt band of light trails the bar and fades, so freshly scanned pixels seem to cool down. The percentage under the photo rolls with the sweep. At 100% the bar fades, the card pops 1 → 1.03 → 1, a green check springs in and a success haptic fires. Drag across the photo to scrub the bar by hand. Precise, luminous, magical.",
            "一张 264 × 176 pt 的照片卡片起初“未显影”：14 pt 模糊、饱和度降到 45%，覆盖一层闪烁的 12 pt 半透明色块网格。一道带薄荷绿辉光的 3 pt 白色光条用 2.2 秒、按 (0.5, 0, 0.2, 1) 曲线扫过。光条身后，照片透过随之增长的遮罩清晰显现，一条 48 pt 宽的光带紧跟光条并淡去，刚扫过的像素仿佛正在冷却。照片下方的百分比随扫描滚动。到 100% 时光条淡出，卡片在 1 → 1.03 → 1 间弹一下，绿色对勾弹入并伴随成功触感。也可在照片上拖动，手动推着光条走。精确、通透、有魔力。"
        ),
        implementation: L(
            "Two copies of one Canvas scene are stacked: a blurred, desaturated one with a block overlay, and a sharp one masked by a rectangle whose width is the animated progress; the bar, its trailing light and the percentage read the same value.",
            "同一幅 Canvas 场景叠放两份：一份做模糊、去饱和并盖上色块，另一份保持清晰并用宽度等于动画进度的矩形做遮罩；光条、尾随光带与百分比读取同一个进度值。"
        ),
        apis: ["mask(alignment:_:)", "blur(radius:)", "saturation", "Canvas", "Animatable", "DragGesture"],
        tags: ["scan", "reveal", "enhance", "sharpen", "扫描", "显影", "增强", "清晰化"],
        params: [
            .slider("duration", L("Sweep time", "扫描时长"), 1...5, default: 2.2, decimals: 1, unit: "s"),
            .slider("blur", L("Blur", "模糊"), 4...24, default: 14, decimals: 0, unit: "pt"),
            .choice("axis", L("Direction", "方向"), [L("Across", "横向"), L("Down", "纵向")], default: 0),
            .toggle("blocks", L("Pixel blocks", "像素色块"), default: true),
        ]
    ) { ctx in
        ScanRevealDemo(ctx: ctx)
    }
}

private let scanSize = CGSize(width: 264, height: 176)

private struct ScanRevealDemo: View {
    let ctx: DemoContext
    @State private var progress: Double
    @State private var done = false
    @State private var pops = 0
    @State private var scrubbing = false
    @State private var task: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills show the bar mid-sweep: half sharp, half still undeveloped.
        _progress = State(initialValue: ctx.isStill ? 0.56 : 0)
    }

    private var vertical: Bool { ctx.int("axis") == 1 }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                ScanPhoto(
                    progress: progress,
                    done: done,
                    blur: ctx.cg("blur"),
                    blocks: ctx.bool("blocks"),
                    vertical: vertical,
                    preview: ctx.isPreview
                )
                .gesture(scrub)
                ScanFooter(progress: progress, done: done, language: ctx.language)
            }
            .padding(12)
            .frame(width: scanSize.width + 24)
            .demoCard(cornerRadius: 28)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(1.03, duration: 0.14)
                    SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
                }
            }
            DemoHint(text: L("Tap to rescan · drag to scrub", "点击重新扫描 · 拖动手动扫描"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            start(rewind: true)
        }
        .onAppear {
            guard !ctx.isStill else { return }
            start(rewind: false)
        }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                task?.cancel()
                scrubbing = true
                let share: Double = vertical
                    ? Double(value.location.y / scanSize.height)
                    : Double(value.location.x / scanSize.width)
                var direct = Transaction()
                direct.disablesAnimations = true
                withTransaction(direct) { progress = share.clamped(to: 0...1) }
                if done { withAnimation(.easeOut(duration: 0.2)) { done = false } }
            }
            .onEnded { _ in
                scrubbing = false
                // Let go anywhere: the scan finishes on its own from there.
                start(rewind: false)
            }
    }

    private func start(rewind: Bool) {
        task?.cancel()
        let duration: Double = max(ctx["duration"], 0.3)
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let loops: Bool = ctx.isPreview
        task = Task { @MainActor in
            repeat {
                if rewind || loops, progress > 0.01 {
                    // The bar runs back and the photo goes soft again.
                    withAnimation(.easeInOut(duration: 0.4)) {
                        progress = 0
                        done = false
                    }
                    try? await Task.sleep(for: .seconds(0.55))
                } else {
                    try? await Task.sleep(for: .seconds(0.35))
                }
                if Task.isCancelled { return }
                let remaining: Double = duration * max(1 - progress, 0.15)
                withAnimation(.timingCurve(0.5, 0, 0.2, 1, duration: remaining)) { progress = 1 }
                try? await Task.sleep(for: .seconds(remaining))
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { done = true }
                pops += 1
                if buzz { Haptics.success() }
                guard loops else { return }
                try? await Task.sleep(for: .seconds(1.7))
            } while !Task.isCancelled
        }
    }
}

// MARK: - Photo

private struct ScanPhoto: View, Animatable {
    var progress: Double
    let done: Bool
    let blur: CGFloat
    let blocks: Bool
    let vertical: Bool
    let preview: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let w: CGFloat = scanSize.width
        let h: CGFloat = scanSize.height
        let p: CGFloat = CGFloat(progress)
        let barOpacity: Double = done ? 0 : min(Double(p) * 12, 1)
        ZStack(alignment: .topLeading) {
            ScanScene()
                .blur(radius: blur)
                .saturation(0.45)
                .scaleEffect(1.1)
                .overlay { if blocks { ScanBlocks(preview: preview, paused: done) } }
            ScanScene()
                .mask(alignment: .topLeading) {
                    Rectangle().frame(width: vertical ? w : w * p, height: vertical ? h * p : h)
                }
            // Light that trails the bar and fades: freshly scanned pixels are still "hot".
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.42)],
                startPoint: vertical ? .top : .leading,
                endPoint: vertical ? .bottom : .trailing
            )
            .frame(width: vertical ? w : 48, height: vertical ? 48 : h)
            .offset(x: vertical ? 0 : w * p - 48, y: vertical ? h * p - 48 : 0)
            .blendMode(.plusLighter)
            .opacity(barOpacity)
            Capsule()
                .fill(.white)
                .frame(width: vertical ? w : 3, height: vertical ? 3 : h)
                .shadow(color: Palette.mint, radius: 6)
                .shadow(color: Palette.mint.opacity(0.8), radius: 14)
                .offset(x: vertical ? 0 : w * p - 1.5, y: vertical ? h * p - 1.5 : 0)
                .opacity(barOpacity)
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.3), value: done)
    }
}

/// A flickering grid of translucent blocks: the "not yet resolved" texture.
private struct ScanBlocks: View {
    let preview: Bool
    let paused: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.14)) { timeline in
            let tick: Int = paused ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / 0.14)
            Canvas { context, size in
                let cell: CGFloat = 12
                let columns: Int = Int(ceil(size.width / cell))
                let rows: Int = Int(ceil(size.height / cell))
                for row in 0..<rows {
                    for column in 0..<columns {
                        // A cheap integer hash; a third of the cells change on every tick.
                        var hash: Int = (row &* 73_856_093) ^ (column &* 19_349_663)
                        if (row + column + tick) % 3 == 0 { hash ^= tick &* 83_492_791 }
                        let value: Double = Double(abs(hash) % 1000) / 1000
                        let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                        if value > 0.5 {
                            context.fill(Path(rect), with: .color(.white.opacity((value - 0.5) * 0.36)))
                        } else {
                            context.fill(Path(rect), with: .color(.black.opacity((0.5 - value) * 0.30)))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The photograph: dusk sky, a sun, three ridges and a tree line, with details fine enough to show sharpness.
private struct ScanScene: View {
    var body: some View {
        Canvas { context, size in
            let w: CGFloat = size.width
            let h: CGFloat = size.height
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(hex: 0x161A4A), location: 0),
                        .init(color: Color(hex: 0x5B3A9E), location: 0.38),
                        .init(color: Color(hex: 0xFF6F91), location: 0.62),
                        .init(color: Color(hex: 0xFFC27A), location: 0.8),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: h)
                )
            )
            // Stars.
            for index in 0..<22 {
                let hx: Double = abs(sin(Double(index) * 12.9898) * 43758.5453)
                let hy: Double = abs(sin(Double(index) * 78.233) * 43758.5453)
                let x: CGFloat = w * CGFloat(hx - floor(hx))
                let y: CGFloat = h * 0.42 * CGFloat(hy - floor(hy))
                let r: CGFloat = index % 5 == 0 ? 1.3 : 0.8
                context.fill(Path(ellipseIn: CGRect(x: x, y: y + 4, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.85)))
            }
            // Sun with a halo.
            let sun = CGPoint(x: w * 0.68, y: h * 0.56)
            context.fill(
                Path(ellipseIn: CGRect(x: sun.x - 60, y: sun.y - 60, width: 120, height: 120)),
                with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE9A8, opacity: 0.7), Color(hex: 0xFFE9A8, opacity: 0)]), center: sun, startRadius: 10, endRadius: 60)
            )
            context.fill(Path(ellipseIn: CGRect(x: sun.x - 20, y: sun.y - 20, width: 40, height: 40)), with: .color(Color(hex: 0xFFF1C4)))
            // Two birds.
            for (bx, by) in [(0.30, 0.30), (0.37, 0.25)] {
                var bird = Path()
                let origin = CGPoint(x: w * CGFloat(bx), y: h * CGFloat(by))
                bird.move(to: CGPoint(x: origin.x - 6, y: origin.y - 2))
                bird.addQuadCurve(to: origin, control: CGPoint(x: origin.x - 3, y: origin.y - 5))
                bird.addQuadCurve(to: CGPoint(x: origin.x + 6, y: origin.y - 2), control: CGPoint(x: origin.x + 3, y: origin.y - 5))
                context.stroke(bird, with: .color(Color(hex: 0x161A4A).opacity(0.8)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
            // Ridges, far to near.
            let ridges: [(base: Double, amp: Double, freq: Double, shift: Double, color: UInt32)] = [
                (0.66, 0.10, 2.1, 0.4, 0x8A56B8),
                (0.76, 0.12, 3.2, 1.9, 0x4B2F86),
                (0.88, 0.07, 4.6, 3.1, 0x1D1542),
            ]
            for (index, ridge) in ridges.enumerated() {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: h))
                var crest: [CGPoint] = []
                for step in 0...66 {
                    let u: Double = Double(step) / 66
                    let wave: Double = sin(u * ridge.freq * .pi + ridge.shift) * 0.6 + sin(u * ridge.freq * 2.7 * .pi + ridge.shift * 2) * 0.4
                    crest.append(CGPoint(x: w * CGFloat(u), y: h * CGFloat(ridge.base - ridge.amp * wave)))
                }
                path.addLines(crest)
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
                context.fill(path, with: .color(Color(hex: ridge.color)))
                // A tree line on the nearest ridge.
                if index == 2 {
                    for step in stride(from: 1, to: 66, by: 2) {
                        let point = crest[step]
                        let tall: CGFloat = 7 + 5 * CGFloat((Double(step) * 0.618).truncatingRemainder(dividingBy: 1))
                        var tree = Path()
                        tree.move(to: CGPoint(x: point.x - 3, y: point.y + 1))
                        tree.addLine(to: CGPoint(x: point.x, y: point.y - tall))
                        tree.addLine(to: CGPoint(x: point.x + 3, y: point.y + 1))
                        tree.closeSubpath()
                        context.fill(tree, with: .color(Color(hex: ridge.color)))
                    }
                }
            }
        }
        .frame(width: scanSize.width, height: scanSize.height)
    }
}

// MARK: - Footer

private struct ScanFooter: View, Animatable {
    var progress: Double
    let done: Bool
    let language: AppLanguage

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let zh = language == .zh
        let percent: Int = Int((progress * 100).rounded())
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.mint)
                .frame(width: 34, height: 34)
                .background(Palette.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(done ? (zh ? "照片已增强" : "Photo enhanced") : (zh ? "正在增强照片" : "Enhancing photo"))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.interpolate)
                Text(done ? "4032 × 3024" : (zh ? "超分辨率 · \(percent)%" : "Upscaling · \(percent)%"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.green)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 4)
        .frame(width: scanSize.width, height: 36)
    }
}
