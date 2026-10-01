import SwiftUI

extension Effect {
    static let gesturesSwipeUpUnlock = Effect(
        id: "gestures.swipe-up-unlock",
        category: .gestures,
        interaction: .gesture,
        name: L("Swipe Up to Unlock", "上滑解锁"),
        summary: L("A lock screen that lifts with your finger, shrinking and blurring, then flies off as the home icons rush in.", "锁屏内容随手指上移、缩小并模糊，越过阈值后飞走，主屏图标随之涌入。"),
        prompt: L(
            "A 210×300 pt phone screen shows a lock screen: padlock glyph, a large 9:41, the date, one notification and, at the bottom, three chevrons pulsing upward in a 1.4 s wave above a home bar. Dragging up lifts the lock content 1:1 with the finger while it scales toward 88%, blurs up to 12 pt and fades, and the wallpaper's dim layer clears. Behind it sixteen app icons zoom in from 180% toward their places, the outer ones arriving later. Past 35% of the travel (or a flick faster than 700 pt/s) the padlock snaps open with a light haptic; releasing there throws the content off on a spring (response 0.5 s, damping 0.82) and the icons land with a success haptic. Releasing earlier lets everything bounce back. Tapping the home screen locks it again. Familiar, fluid, weightless.",
            "210×300 pt的手机屏幕显示锁屏：挂锁图标、大号9:41、日期、一条通知，底部三个箭头以1.4秒一轮的波浪向上闪动。向上拖动时锁屏内容1:1跟手抬起，同时缩小到88%、模糊至最多12 pt并变淡，壁纸暗层褪去；背后十六个应用图标从180%朝各自位置缩入，越靠外到得越晚。越过行程的35%（或以超过700 pt/s一甩），挂锁打开并有轻触感；此时松手，内容由弹簧（响应0.5秒、阻尼0.82）甩出屏幕，图标落位，成功触感响起。提前松手则全部弹回；点击主屏幕重新锁定。流畅、轻盈。"
        ),
        implementation: L(
            "One progress value (drag distance ∕ travel) drives everything: the lock layer's offset, scale, blur and opacity, and an Animatable icon grid that remaps progress per icon by its distance from the centre, so springs keep the stagger. DragGesture's onEnded compares progress and predicted velocity with the threshold to commit or cancel.",
            "一个进度值（拖动距离 ∕ 行程）驱动全部效果：锁屏层的位移、缩放、模糊与不透明度，以及一个 Animatable 的图标网格，它按每个图标到中心的距离重新映射进度，使弹簧动画也保留错峰。DragGesture 的 onEnded 把进度和预测速度与阈值比较，决定提交还是取消。"
        ),
        apis: ["DragGesture", "Animatable", "blur(radius:)", "contentTransition(.symbolEffect(.replace))", "TimelineView(.animation)"],
        tags: ["unlock", "lock screen", "swipe up", "home screen", "threshold", "解锁", "锁屏", "上滑", "主屏幕", "阈值"],
        params: [
            .slider("threshold", L("Unlock threshold", "解锁阈值"), 0.2...0.6, default: 0.35),
            .slider("response", L("Spring response", "弹簧响应"), 0.3...0.8, default: 0.5, unit: "s"),
            .slider("blur", L("Max blur", "最大模糊"), 0...20, default: 12, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        SwipeUpUnlockDemo(ctx: ctx)
    }
}

private enum LockScreen {
    static let size = CGSize(width: 210, height: 300)
    static let travel: CGFloat = 270
    static let corner: CGFloat = 36
}

private struct SwipeUpUnlockDemo: View {
    let ctx: DemoContext
    /// 0 = locked, 1 = unlocked.
    @State private var progress: CGFloat = 0
    @State private var unlocked = false
    @State private var armed = false
    @State private var held = false
    @State private var script: Task<Void, Never>?
    /// Resets on system cancellation too, so a stolen touch never leaves the lock screen half lifted.
    @GestureState private var pressing = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: LockScreen.corner, style: .continuous)
        VStack(spacing: 12) {
            ZStack {
                LockWallpaper()
                HomeIcons(progress: progress)
                Color.black.opacity(0.3 * Double(1 - min(progress, 1)))
                LockContent(language: ctx.language, open: armed || unlocked, animateHint: !ctx.isStill)
                    .scaleEffect(1 - 0.12 * min(progress, 1), anchor: .top)
                    .blur(radius: ctx.cg("blur") * min(progress, 1))
                    .opacity(Double(1 - min(progress, 1) * 0.95))
                    .offset(y: -progress * LockScreen.travel)
            }
            .frame(width: LockScreen.size.width, height: LockScreen.size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            .overlay(shape.strokeBorder(Color.black.opacity(0.5), lineWidth: 3).padding(-3))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            .contentShape(shape)
            .gesture(drag)
            .onTapGesture {
                if unlocked { lock() }
            }

            DemoHint(text: unlocked ? L("Tap the screen to lock it again", "点击屏幕重新锁定") : L("Swipe up to unlock", "向上轻扫解锁"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 3.4, delay: 0.6) { autoSwipe() }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing && held { release(velocity: 0) }
        }
        .onDisappear { script?.cancel() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                guard !unlocked else { return }
                if !held {
                    held = true
                    script?.cancel()
                }
                dragChanged(-value.translation.height)
            }
            .onEnded { value in
                guard held else { return }
                release(velocity: value.velocity.height)
            }
    }

    /// Finger (or ghost finger) is `lift` points above where it started.
    private func dragChanged(_ lift: CGFloat) {
        let raw: CGFloat = lift / LockScreen.travel
        progress = raw >= 0 ? min(raw, 1) : -rubberBand(-raw, limit: 0.08)
        let nowArmed: Bool = progress >= ctx.cg("threshold")
        if nowArmed != armed {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { armed = nowArmed }
            if held && !ctx.isPreview { Haptics.tap(.light) }
        }
    }

    private func release(velocity: CGFloat) {
        held = false
        guard !unlocked else { return }
        if armed || velocity < -700 {
            withAnimation(.spring(response: ctx["response"], dampingFraction: 0.82)) {
                progress = 1
                unlocked = true
                armed = false
            }
            if !ctx.isPreview { Haptics.success() }
        } else {
            withAnimation(.spring(response: ctx["response"] * 0.8, dampingFraction: 0.68)) {
                progress = 0
                armed = false
            }
        }
    }

    private func lock() {
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.86)) {
            progress = 0
            unlocked = false
            armed = false
        }
        if !ctx.isPreview { Haptics.tap(.rigid) }
    }

    /// A scripted finger swipes up past the threshold and lets go, then the screen locks again;
    /// all through the same dragChanged / release / lock the real touch calls.
    private func autoSwipe() {
        guard !held else { return }
        if unlocked {
            lock()
            return
        }
        let reach: CGFloat = LockScreen.travel * min(ctx.cg("threshold") + 0.14, 0.9)
        script?.cancel()
        script = Task { @MainActor in
            let finished = await GhostFinger.drag(from: .zero, to: CGPoint(x: 0, y: reach), duration: 0.7) { point in
                dragChanged(point.y)
            }
            guard finished else { return }
            release(velocity: -500)
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, unlocked, !held else { return }
            lock()
        }
    }
}

// MARK: - Layers

private struct LockWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2B1B6B), Color(hex: 0x6A3CC8), Color(hex: 0xE8608F), Color(hex: 0xFFB36B)],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(Color(hex: 0x4FA3FF).opacity(0.55))
                .frame(width: 190, height: 190)
                .blur(radius: 46)
                .offset(x: -70, y: -40)
            Circle()
                .fill(Color(hex: 0xFF5FA2).opacity(0.5))
                .frame(width: 170, height: 170)
                .blur(radius: 44)
                .offset(x: 80, y: 70)
        }
    }
}

private struct LockContent: View {
    let language: AppLanguage
    let open: Bool
    let animateHint: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: open ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(.white)
                .scaleEffect(open ? 1.2 : 1)
                .frame(height: 22)
                .padding(.top, 16)
            Text(L("Tuesday, January 14", "1月14日 星期二"), language)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 6)
            Text(verbatim: "9:41")
                .font(.system(size: 58, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, -4)

            LockNotification(language: language)
                .padding(.top, 14)
                .padding(.horizontal, 12)

            Spacer(minLength: 0)

            HStack {
                LockRoundButton(symbol: "flashlight.off.fill")
                Spacer()
                LockChevrons(animated: animateHint)
                Spacer()
                LockRoundButton(symbol: "camera.fill")
            }
            .padding(.horizontal, 18)
            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: 74, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
    }
}

private struct LockNotification: View {
    let language: AppLanguage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Palette.mint, Palette.sky], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "message.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Mina", "小敏"), language)
                    .font(.system(size: 12, weight: .bold))
                Text(L("Are we still on for tonight?", "今晚还照常见面吗？"), language)
                    .font(.system(size: 11))
                    .opacity(0.85)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(shape.fill(.white.opacity(0.2)))
        .overlay(shape.strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
    }
}

private struct LockRoundButton: View {
    let symbol: String

    var body: some View {
        Circle()
            .fill(.black.opacity(0.28))
            .frame(width: 34, height: 34)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// Three chevrons lighting up from bottom to top in a wave.
private struct LockChevrons: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate / 1.4
            let cycle: Double = t - t.rounded(.down)
            VStack(spacing: -4) {
                ForEach(0..<3, id: \.self) { index in
                    // Index 2 is the bottom chevron; the wave climbs.
                    let phase: Double = cycle - Double(2 - index) * 0.16
                    let wave: Double = animated ? max(0, 1 - abs(phase - 0.3) / 0.3) : (index == 0 ? 1 : 0.5)
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3 + 0.7 * wave))
                        .offset(y: CGFloat(-3 * wave))
                }
            }
        }
        .frame(height: 40)
    }
}

/// The home screen behind the lock: every icon zooms into place, outer ones arriving later.
private struct HomeIcons: View, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private static let symbols: [String] = [
        "message.fill", "phone.fill", "camera.fill", "map.fill",
        "music.note", "envelope.fill", "calendar", "cloud.sun.fill",
        "photo.fill", "gamecontroller.fill", "heart.fill", "book.fill",
        "cart.fill", "bolt.fill", "gearshape.fill", "safari.fill",
    ]
    private static let tints: [Color] = [
        Palette.green, Palette.mint, Color(hex: 0x4A4A55), Palette.sky,
        Palette.pink, Palette.blue, Palette.red, Palette.sky,
        Palette.amber, Palette.violet, Palette.pink, Palette.coral,
        Palette.indigo, Palette.amber, Color(hex: 0x6B6B78), Palette.blue,
    ]

    var body: some View {
        let icon: CGFloat = 36
        let gap: CGFloat = 13
        let pitch: CGFloat = icon + gap
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                let column: CGFloat = CGFloat(index % 4) - 1.5
                let row: CGFloat = CGFloat(index / 4) - 1.5
                let distance: CGFloat = (column * column + row * row).squareRoot() / 2.13
                // Outer icons start later, so the grid assembles from the centre outward.
                let delay: CGFloat = distance * 0.3
                let local: CGFloat = ((progress - delay) / (1 - delay)).clamped(to: 0...1.2)
                let eased: CGFloat = 1 - (1 - min(local, 1)) * (1 - min(local, 1))
                let spread: CGFloat = 1.8 - 0.8 * eased + (local > 1 ? -(local - 1) * 0.25 : 0)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [HomeIcons.tints[index].opacity(0.95), HomeIcons.tints[index].opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        Image(systemName: HomeIcons.symbols[index])
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                    .frame(width: icon, height: icon)
                    .scaleEffect(spread)
                    .opacity(Double(min(local * 1.6, 1)))
                    .offset(x: column * pitch * spread, y: (row * pitch - 6) * spread)
            }
        }
    }
}
