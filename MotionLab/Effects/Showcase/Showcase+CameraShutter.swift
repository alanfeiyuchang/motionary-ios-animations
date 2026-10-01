import SwiftUI

extension Effect {
    static let showcaseCameraShutter = Effect(
        id: "showcase.camera-shutter",
        category: .showcase,
        interaction: .tap,
        name: L("Camera Shutter", "相机快门"),
        summary: L(
            "Press the shutter: the disc contracts, the frame blinks white and the shot flies into the corner thumbnail; modes slide under a fixed marker.",
            "按下快门：内圆收缩、画面一闪，照片飞进角落的缩略图；拍摄模式在固定标记下滑动切换。"
        ),
        prompt: L(
            "A dark camera widget: a viewfinder with rule-of-thirds lines, a strip of mode names passing under a fixed tinted capsule, and a row with a thumbnail, a ringed shutter and a flip button. Pressing the shutter shrinks its white inner disc to 86% on a spring (response 0.22 s, damping 0.6) with a rigid haptic; the viewfinder blinks to 85% white for 50 ms, fades back over 0.3 s and dips to 98.5% scale. A white-outlined copy of the frame shrinks to 90% in 0.12 s, then flies along a shallow arc into the thumbnail slot in 0.45 s, squashing to a square; the thumbnail pops to 118% and its counter rolls up. Swiping the strip glides the next mode under the marker (response 0.4 s, damping 0.78) as the scene blurs 7 pt and cross-fades. In Video the disc turns red and becomes a rounded square while recording. Snappy.",
            "深色相机组件：带三分线的取景框，一排从固定胶囊下滑过的模式名，以及缩略图、快门键和翻转键。按下快门，白色内圆以弹簧（响应 0.22 秒、阻尼 0.6）缩到 86%，伴随硬质触感；取景框在 50 毫秒内闪到 85% 白，0.3 秒淡回并微缩到 98.5%。带白边的画面副本先用 0.12 秒缩到 90%，再用 0.45 秒沿浅弧飞进缩略图并压成方形；缩略图弹到 118%，计数滚动。横扫模式条，下一模式滑到标记下（响应 0.4 秒、阻尼 0.78），画面模糊 7pt 后淡入。视频模式下内圆变红，录制时变方块。干脆利落。"
        ),
        implementation: L(
            "The shutter is a ButtonStyle built on a latched press so quick taps still show the contraction. Three keyframeAnimators share the shot counter: the white flash and dip on the viewfinder, the flying copy (scale x/y, position, opacity tracks) and the thumbnail pop, which a task releases when the flight lands. The mode strip is an HStack offset by the selected index under a fixed capsule.",
            "快门是基于“锁存按压”的 ButtonStyle，快速轻点也能看到内圆收缩。三个 keyframeAnimator 共用拍摄计数：取景框的白闪与微缩、飞行副本（横纵缩放、位置、透明度各一条轨道），以及由 task 在落点时触发的缩略图弹跳。模式条是按选中下标偏移的 HStack，上面盖着固定的胶囊标记。"
        ),
        apis: ["ButtonStyle", "keyframeAnimator", "KeyframeTrack", "DragGesture", "contentTransition(.numericText)", "spring(response:dampingFraction:)"],
        tags: ["camera", "shutter", "capture", "flash", "mode switch", "相机", "快门", "拍照", "闪光", "模式切换"],
        params: [
            .slider("press", L("Pressed disc scale", "按下时内圆缩放"), 0.7...0.96, default: 0.86),
            .slider("flash", L("Flash strength", "闪白强度"), 0...1, default: 0.85),
            .slider("fly", L("Flight duration", "飞行时长"), 0.25...0.9, default: 0.45, unit: "s"),
        ]
    ) { ctx in
        CameraShutterDemo(ctx: ctx)
    }
}

private enum CameraLayout {
    static let width: CGFloat = 244
    static let finder = CGSize(width: 244, height: 132)
    static let thumb: CGFloat = 44
    static let cell: CGFloat = 62
    static let modes: [LocalizedText] = [L("Video", "视频"), L("Photo", "照片"), L("Portrait", "人像"), L("Pano", "全景")]
    static let seeds = [4, 0, 1, 2]
    /// Thumbnail centre, in the card's content coordinates.
    static let thumbCenter = CGPoint(x: 22, y: 206)
}

private struct CameraShutterDemo: View {
    let ctx: DemoContext
    @State private var mode = 1
    @State private var shots = 0
    @State private var shotSeed = 0
    @State private var thumbSeed: Int?
    @State private var count: Int
    @State private var thumbPops = 0
    @State private var modeChanges = 0
    @State private var recording = false
    @State private var recordStart = Date()
    @State private var autoPressed = false
    @State private var taps = 0
    @State private var step = 0
    @State private var flips = 0
    @State private var stripDrag: CGFloat = 0
    @State private var pending: Task<Void, Never>?
    @State private var press: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _thumbSeed = State(initialValue: ctx.isStill ? 1 : nil)
        _count = State(initialValue: ctx.isStill ? 3 : 0)
    }

    private var zh: Bool { ctx.language == .zh }
    private var fly: Double { max(ctx["fly"], 0.1) }
    private var video: Bool { mode == 0 }

    var body: some View {
        StudioScene(hint: L("Press the shutter · swipe the modes", "按下快门 · 横扫切换模式"), ctx: ctx) {
            card
        }
        .onDisappear {
            pending?.cancel()
            press?.cancel()
        }
        .autoplay(ctx.isPreview, every: 1.45, delay: 0.7) { autoStep() }
    }

    private var card: some View {
        VStack(spacing: 8) {
            finder
            strip
            controls
        }
        .frame(width: CameraLayout.width)
        .overlay(alignment: .topLeading) { flyingShot }
        .padding(16)
        .signatureCard()
    }

    // MARK: Viewfinder

    private var finder: some View {
        let size = CameraLayout.finder
        let flash = ctx["flash"]
        return ZStack {
            LandscapeArt(seed: CameraLayout.seeds[mode])
                .id(mode)
                .transition(.opacity)
            CameraGrid()
                .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
            VStack {
                HStack {
                    chip {
                        Image(systemName: "bolt.slash.fill")
                    }
                    Spacer()
                    if recording {
                        TimelineView(.periodic(from: recordStart, by: 0.5)) { timeline in
                            let seconds = timeline.date.timeIntervalSince(recordStart)
                            chip {
                                Circle()
                                    .fill(Color(hex: 0xFF3B30))
                                    .frame(width: 6, height: 6)
                                    .opacity(Int(seconds * 2) % 2 == 0 ? 1 : 0.25)
                                Text(verbatim: studioClock(seconds))
                            }
                        }
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        chip {
                            Text(verbatim: video ? "4K · 60" : (mode == 2 ? "ƒ 2.8" : "HDR"))
                                .contentTransition(.opacity)
                        }
                    }
                }
                Spacer()
            }
            .padding(8)
        }
        .frame(width: size.width, height: size.height)
        .keyframeAnimator(initialValue: 0.0, trigger: modeChanges) { content, blur in
            content.blur(radius: blur)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(7, duration: 0.14)
                CubicKeyframe(0, duration: 0.3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .keyframeAnimator(initialValue: CameraBlink(), trigger: shots) { content, value in
            content
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(value.flash * flash)))
                .scaleEffect(value.scale)
        } keyframes: { _ in
            KeyframeTrack(\.flash) {
                LinearKeyframe(1, duration: 0.05)
                CubicKeyframe(0, duration: 0.3)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.985, duration: 0.06)
                SpringKeyframe(1, duration: 0.35, spring: .init(response: 0.25, dampingRatio: 0.6))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) { content() }
            .font(.system(size: 9, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.white)
            .padding(.horizontal, 7)
            .frame(height: 18)
            .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    /// The copy of the frame that flies into the thumbnail.
    private var flyingShot: some View {
        let size = CameraLayout.finder
        let target = CameraLayout.thumbCenter
        let duration = fly
        return LandscapeArt(seed: shotSeed)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white, lineWidth: 3))
            .keyframeAnimator(initialValue: CameraFlight(), trigger: shots) { content, value in
                content
                    .scaleEffect(x: value.sx, y: value.sy)
                    .position(x: value.x, y: value.y)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.sx) {
                    MoveKeyframe(1)
                    CubicKeyframe(0.9, duration: 0.12)
                    CubicKeyframe(CameraLayout.thumb / size.width, duration: duration)
                }
                KeyframeTrack(\.sy) {
                    MoveKeyframe(1)
                    CubicKeyframe(0.9, duration: 0.12)
                    CubicKeyframe(CameraLayout.thumb / size.height, duration: duration)
                }
                KeyframeTrack(\.x) {
                    MoveKeyframe(size.width / 2)
                    LinearKeyframe(size.width / 2, duration: 0.12)
                    CubicKeyframe(target.x, duration: duration)
                }
                KeyframeTrack(\.y) {
                    MoveKeyframe(size.height / 2)
                    LinearKeyframe(size.height / 2, duration: 0.12)
                    CubicKeyframe(size.height / 2 - 12, duration: duration * 0.3)
                    CubicKeyframe(target.y, duration: duration * 0.7)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.1 + duration)
                    LinearKeyframe(0, duration: 0.05)
                }
            }
            .allowsHitTesting(false)
    }

    // MARK: Mode strip

    private var strip: some View {
        HStack(spacing: 0) {
            ForEach(CameraLayout.modes.indices, id: \.self) { index in
                Text(CameraLayout.modes[index], ctx.language)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(zh ? 2 : 0.5)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(index == mode ? Signature.accent : Color.white.opacity(0.5))
                    .frame(width: CameraLayout.cell, height: 26)
                    .contentShape(Rectangle())
                    .onTapGesture { setMode(index, user: true) }
            }
        }
        .offset(x: -(CGFloat(mode) - 1.5) * CameraLayout.cell + stripDrag)
        .frame(width: CameraLayout.width, height: 26)
        .background {
            Capsule()
                .fill(Signature.accent.opacity(0.16))
                .overlay(Capsule().strokeBorder(Signature.accent.opacity(0.4), lineWidth: 1))
                .frame(width: CameraLayout.cell - 4, height: 22)
        }
        .mask {
            LinearGradient(
                stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.22), .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    stripDrag = rubberBand(value.translation.width, limit: CameraLayout.cell * 1.5)
                }
                .onEnded { value in
                    let steps = Int((-value.predictedEndTranslation.width / CameraLayout.cell).rounded())
                    let target = (mode + steps.clamped(to: -1...1)).clamped(to: 0...(CameraLayout.modes.count - 1))
                    if target == mode {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { stripDrag = 0 }
                    } else {
                        setMode(target, user: true)
                    }
                }
        )
    }

    // MARK: Controls

    private var controls: some View {
        HStack {
            thumbnail
            Spacer(minLength: 0)
            Button(action: {
                taps += 1
                shoot(user: true)
            }) {
                Color.clear.frame(width: 64, height: 64)
            }
            .buttonStyle(CameraShutterStyle(scale: ctx.cg("press"), taps: taps, forced: autoPressed, video: video, recording: recording))
            Spacer(minLength: 0)
            Button {
                Haptics.tap(.light)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { flips += 1 }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .rotationEffect(.degrees(Double(flips) * 180))
                    .frame(width: CameraLayout.thumb, height: CameraLayout.thumb)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(SportPressStyle(scale: 0.9, dim: 0.06))
        }
        .frame(height: 64)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08))
            if let thumbSeed {
                LandscapeArt(seed: thumbSeed)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .id(count)
                    .transition(.identity)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .frame(width: CameraLayout.thumb, height: CameraLayout.thumb)
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5))
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                Text(verbatim: "\(count)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Signature.ink)
                    .contentTransition(.numericText(value: Double(count)))
                    .frame(minWidth: 17, minHeight: 17)
                    .background(Capsule().fill(Signature.accent))
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .keyframeAnimator(initialValue: 1.0, trigger: thumbPops) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.18, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.45, spring: .init(response: 0.3, dampingRatio: 0.5))
            }
        }
    }

    // MARK: Actions

    private func shoot(user: Bool) {
        if video {
            if user { Haptics.tap(.medium) }
            recordStart = Date()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { recording.toggle() }
            return
        }
        if user { Haptics.tap(.rigid) }
        pending?.cancel()
        shotSeed = CameraLayout.seeds[mode]
        shots += 1
        let seed = shotSeed
        pending = Task { @MainActor in
            guard await studioPause(0.12 + fly) else { return }
            thumbSeed = seed
            thumbPops += 1
            withAnimation(.snappy(duration: 0.25)) { count += 1 }
            if user && !ctx.isPreview { Haptics.tap(.soft) }
        }
    }

    private func setMode(_ index: Int, user: Bool) {
        guard index != mode else { return }
        if user { Haptics.selection() }
        modeChanges += 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            mode = index
            stripDrag = 0
            recording = false
        }
    }

    /// Preview loop: shoot, then move one mode along.
    private func autoStep() {
        if step % 2 == 0 {
            press?.cancel()
            autoPressed = true
            shoot(user: false)
            press = Task { @MainActor in
                _ = await studioPause(0.16)
                autoPressed = false
            }
        } else {
            setMode((mode + 1) % CameraLayout.modes.count, user: false)
        }
        step += 1
    }
}

private struct CameraBlink {
    var flash: Double = 0
    var scale: Double = 1
}

private struct CameraFlight {
    var sx: CGFloat = 1
    var sy: CGFloat = 1
    var x: CGFloat = CameraLayout.finder.width / 2
    var y: CGFloat = CameraLayout.finder.height / 2
    var opacity: Double = 0
}

private struct CameraGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 1...2 {
            let x = rect.minX + rect.width * CGFloat(index) / 3
            let y = rect.minY + rect.height * CGFloat(index) / 3
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

/// Ring + inner disc: the disc contracts on press and morphs into a rounded square while recording.
private struct CameraShutterStyle: ButtonStyle {
    let scale: CGFloat
    let taps: Int
    let forced: Bool
    let video: Bool
    let recording: Bool

    func makeBody(configuration: Configuration) -> some View {
        LatchedPress(isPressed: configuration.isPressed, taps: taps, forced: forced) { pressed in
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 3.5)
                    .frame(width: 62, height: 62)
                RoundedRectangle(cornerRadius: recording ? 7 : 26, style: .continuous)
                    .fill(video ? Color(hex: 0xFF3B30) : Color.white)
                    .frame(width: recording ? 26 : 52, height: recording ? 26 : 52)
                    .scaleEffect(pressed ? scale : 1)
            }
            .frame(width: 64, height: 64)
            .contentShape(Circle())
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: recording)
            .animation(.smooth(duration: 0.25), value: video)
        }
    }
}
