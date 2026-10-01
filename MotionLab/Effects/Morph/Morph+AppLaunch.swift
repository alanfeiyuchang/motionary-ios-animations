import SwiftUI

extension Effect {
    static let morphAppLaunch = Effect(
        id: "morph.app-launch",
        category: .morph,
        interaction: .gesture,
        name: L("App Launch Zoom", "应用启动缩放"),
        summary: L(
            "A home-screen icon becomes the app: it zooms to full screen as the other icons fly past the camera, and a swipe up sends it home.",
            "主屏图标直接变成应用：放大铺满屏幕，其余图标从镜头旁掠过；上滑一下又把它送回原位。"
        ),
        prompt: L(
            "A home screen of 54 pt icons with a glass dock. Tapping an icon launches it: the icon's own frame grows to fill the screen on a spring (response 0.5 s, damping 0.86), its corner radius easing from 13 pt to 38 pt, while the artwork cross-fades into the app's UI during the first 45% of the flight. The whole home screen zooms 90% larger around the tapped icon and fades, as if the camera dove into it, and the wallpaper scales 12%. Swiping up from the app shrinks it into a floating card that tracks the finger, down to half size, and the icons drift back; releasing past 70 pt sends the card into its icon on a looser spring (damping 0.78) that lands with a small bounce. Direct, physical, iOS at its best.",
            "主屏上排着 54pt 图标和玻璃 Dock。点一个图标即启动：图标自身的外框乘弹簧（响应 0.5 秒、阻尼 0.86）长满屏幕，圆角从 13pt 缓变到 38pt，图标画面在飞行前 45% 的路程里交叉淡变为应用界面。整个主屏以被点图标为中心再放大 90% 并淡出，像镜头一头扎进去，壁纸同步放大 12%。在应用里向上滑，它缩成一张跟手的悬浮卡片，最小到一半大，图标随之飘回；滑过 70pt 松手，卡片乘更松的弹簧（阻尼 0.78）飞回自己的图标，落位时轻轻一弹。直接、有物理感，是 iOS 最经典的转场。"
        ),
        implementation: L(
            "No matched geometry: an Animatable wrapper interpolates one launch progress plus the drag offset, and the app layer's rect is computed each frame as a lerp from the icon rect to the (dragged, scaled) screen rect; the home screen is one group scaled around the icon's unit point. An up-only UIPanGestureRecognizer drives the home gesture.",
            "不使用几何匹配：Animatable 包装器对启动进度和拖动位移做插值，每帧把应用图层的矩形从图标矩形线性插值到（被拖动、缩放过的）屏幕矩形；主屏整体以图标所在的单位点为锚点缩放。只接受上滑的 UIPanGestureRecognizer 驱动返回主屏手势。"
        ),
        apis: ["Animatable", "AnimatablePair", "scaleEffect(_:anchor:)", "UIGestureRecognizerRepresentable", "spring(response:dampingFraction:)"],
        tags: ["app launch", "springboard", "home screen", "zoom", "启动", "主屏幕", "图标放大", "返回主屏"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Landing damping", "落位阻尼"), 0.5...1.0, default: 0.78),
            .slider("zoom", L("Home-screen zoom", "主屏放大"), 0...2, default: 0.9),
        ]
    ) { ctx in
        AppLaunchDemo(ctx: ctx)
    }
}

private struct LaunchApp {
    let symbol: String
    let colors: [Color]
    let name: LocalizedText
}

private let launchApps: [LaunchApp] = [
    LaunchApp(symbol: "cloud.sun.fill", colors: [Color(hex: 0x4FB4FF), Color(hex: 0x2B6BE8)], name: L("Weather", "天气")),
    LaunchApp(symbol: "calendar", colors: [Color(hex: 0xFF7A6B), Color(hex: 0xF0453A)], name: L("Calendar", "日历")),
    LaunchApp(symbol: "photo.fill.on.rectangle.fill", colors: [Palette.amber, Palette.coral], name: L("Photos", "照片")),
    LaunchApp(symbol: "camera.fill", colors: [Color(hex: 0x9A9AA2), Color(hex: 0x55555C)], name: L("Camera", "相机")),
    LaunchApp(symbol: "map.fill", colors: [Palette.mint, Palette.green], name: L("Maps", "地图")),
    LaunchApp(symbol: "note.text", colors: [Color(hex: 0xFFD66B), Palette.amber], name: L("Notes", "备忘录")),
    LaunchApp(symbol: "heart.fill", colors: [Palette.pink, Palette.red], name: L("Health", "健康")),
    LaunchApp(symbol: "book.fill", colors: [Color(hex: 0xFFA24F), Color(hex: 0xF06A1F)], name: L("Books", "图书")),
    LaunchApp(symbol: "waveform", colors: [Palette.violet, Palette.indigo], name: L("Podcasts", "播客")),
    LaunchApp(symbol: "gamecontroller.fill", colors: [Palette.indigo, Palette.sky], name: L("Arcade", "游戏")),
    LaunchApp(symbol: "creditcard.fill", colors: [Color(hex: 0x3A3A44), Color(hex: 0x17171C)], name: L("Wallet", "钱包")),
    LaunchApp(symbol: "gearshape.fill", colors: [Color(hex: 0x8E8E93), Color(hex: 0x5A5A60)], name: L("Settings", "设置")),
    LaunchApp(symbol: "phone.fill", colors: [Color(hex: 0x5BE584), Color(hex: 0x1FB855)], name: L("Phone", "电话")),
    LaunchApp(symbol: "safari.fill", colors: [Palette.sky, Palette.blue], name: L("Safari", "Safari")),
    LaunchApp(symbol: "message.fill", colors: [Color(hex: 0x5BE584), Color(hex: 0x1FB855)], name: L("Messages", "信息")),
    LaunchApp(symbol: "music.note", colors: [Palette.pink, Palette.red], name: L("Music", "音乐")),
]

private enum LaunchLayout {
    static let side: CGFloat = 316
    static let icon: CGFloat = 54
    static let dock = CGRect(x: 10, y: 232, width: 296, height: 72)

    /// Twelve icons in a 4 × 3 grid, then four in the dock.
    static func center(_ index: Int) -> CGPoint {
        let pitch: CGFloat = (side - 44 - icon) / 3
        let x: CGFloat = 22 + icon / 2 + CGFloat(index % 4) * pitch
        if index >= 12 { return CGPoint(x: x, y: dock.midY) }
        return CGPoint(x: x, y: 48 + CGFloat(index / 4) * 68)
    }
}

private struct AppLaunchDemo: View {
    let ctx: DemoContext
    @State private var selected: Int
    /// 0 = on the home screen, 1 = full screen.
    @State private var progress: Double
    @State private var drag: CGSize
    @State private var autoIndex = 0
    @State private var flingTask: Task<Void, Never>?

    private static let autoOrder = [5, 2, 14, 8, 0, 11]
    private static let fit: CGFloat = 0.95

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the home gesture half-way: the app as a card above its home screen.
        _selected = State(initialValue: 5)
        _progress = State(initialValue: ctx.isStill ? 1 : 0)
        _drag = State(initialValue: ctx.isStill ? CGSize(width: 0, height: -150) : .zero)
    }

    private var isOpen: Bool { progress > 0.5 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 38, style: .continuous)
        VStack(spacing: 10) {
            MorphAnimated(AnimatablePair(progress, drag.animatableData)) { value in
                LaunchScene(
                    progress: CGFloat(value.first),
                    drag: CGSize(width: value.second.first, height: value.second.second),
                    selected: selected,
                    zoom: ctx.cg("zoom"),
                    language: ctx.language,
                    onOpen: open,
                    onHome: close
                )
            }
            .frame(width: LaunchLayout.side, height: LaunchLayout.side)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            // Laid out at 316 pt, shown slightly smaller so the screen and the hint both fit the stage.
            .scaleEffect(Self.fit)
            .frame(width: LaunchLayout.side * Self.fit, height: LaunchLayout.side * Self.fit)
            .shadow(color: Color(hex: 0x1B2A6B).opacity(0.3), radius: 22, y: 12)
            // Only an upward drag engages (the page scroll waits for it), and only while an app is open.
            .gesture(PageSafePan(directions: .up, isEnabled: isOpen, onChanged: homeChanged, onEnded: homeEnded))
            DemoHint(
                text: isOpen ? L("Swipe up to go home", "向上滑动返回主屏") : L("Tap an app", "点击一个应用"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.7) { autoStep() }
        .onDisappear {
            flingTask?.cancel()
            flingTask = nil
        }
    }

    private func homeChanged(_ t: CGSize) {
        flingTask?.cancel()
        flingTask = nil
        drag = CGSize(width: t.width, height: t.height < 0 ? t.height : rubberBand(t.height, limit: 24))
    }

    /// `nil` means the system cancelled the pan: settle back into the app.
    private func homeEnded(_ end: PageSafePanEnd?) {
        if let end, -end.translation.height > 70 || -end.predictedEndTranslation.height > 220 {
            close()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { drag = .zero }
        }
    }

    private func open(_ index: Int) {
        guard !isOpen else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) {
            selected = index
            progress = 0
            drag = .zero
        }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.86)) { progress = 1 }
    }

    private func close() {
        guard isOpen else { return }
        flingTask?.cancel()
        flingTask = nil
        if !ctx.isPreview { Haptics.tap(.soft) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            progress = 0
            drag = .zero
        }
    }

    /// Autoplay stand-in for a finger: launch an app, then swipe it home.
    private func autoStep() {
        if isOpen {
            withAnimation(.easeOut(duration: 0.3)) { drag = CGSize(width: 12, height: -130) }
            flingTask?.cancel()
            flingTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.32))
                guard !Task.isCancelled else { return }
                close()
            }
        } else {
            open(Self.autoOrder[autoIndex % Self.autoOrder.count])
            autoIndex += 1
        }
    }
}

/// One frame of the launch: everything is derived from the in-flight progress and drag.
private struct LaunchScene: View {
    let progress: CGFloat
    let drag: CGSize
    let selected: Int
    let zoom: CGFloat
    let language: AppLanguage
    let onOpen: (Int) -> Void
    let onHome: () -> Void

    var body: some View {
        let side: CGFloat = LaunchLayout.side
        let pull: CGFloat = MorphMath.unit(-drag.height / 240)
        // How far "inside" the app the camera is: pulling the card down toward home brings the icons back.
        let depth: CGFloat = progress * (1 - pull)
        let focus: CGPoint = LaunchLayout.center(selected)
        ZStack {
            LaunchWallpaper()
                .scaleEffect(1 + 0.12 * depth)
            Color.black.opacity(0.3 * Double(MorphMath.unit(depth)))
            home
                .scaleEffect(max(1 + zoom * depth, 0.2), anchor: UnitPoint(x: focus.x / side, y: focus.y / side))
                .opacity(Double(1 - MorphMath.unit(depth * 1.4)))
            appLayer(pull: pull, focus: focus)
        }
        .frame(width: side, height: side)
    }

    private var home: some View {
        ZStack {
            DemoMaterial(RoundedRectangle(cornerRadius: 26, style: .continuous), material: .ultraThinMaterial, fallback: Color.white.opacity(0.22))
                .frame(width: LaunchLayout.dock.width, height: LaunchLayout.dock.height)
                .position(x: LaunchLayout.dock.midX, y: LaunchLayout.dock.midY)
            ForEach(launchApps.indices, id: \.self) { index in
                if index != selected {
                    let center: CGPoint = LaunchLayout.center(index)
                    LaunchIconArt(app: launchApps[index], radius: 13)
                        .frame(width: LaunchLayout.icon, height: LaunchLayout.icon)
                        .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(index) }
                        .position(x: center.x, y: center.y)
                }
            }
        }
    }

    private func appLayer(pull: CGFloat, focus: CGPoint) -> some View {
        let side: CGFloat = LaunchLayout.side
        let cardSide: CGFloat = side * (1 - 0.5 * pull)
        let cardCenter = CGPoint(x: side / 2 + drag.width * 0.6, y: side / 2 + drag.height * 0.36)
        let openRect: CGRect = MorphMath.rect(center: cardCenter, size: CGSize(width: cardSide, height: cardSide))
        let iconRect: CGRect = MorphMath.rect(center: focus, size: CGSize(width: LaunchLayout.icon, height: LaunchLayout.icon))
        let rect: CGRect = MorphMath.lerp(iconRect, openRect, progress)
        let radius: CGFloat = MorphMath.lerp(13, 38, MorphMath.unit(progress)) * (rect.width < LaunchLayout.icon ? rect.width / LaunchLayout.icon : 1)
        let appAlpha: CGFloat = MorphMath.smooth(progress, 0.05, 0.45)
        let app: LaunchApp = launchApps[selected]
        return ZStack {
            LaunchIconArt(app: app, radius: 0)
            LaunchAppScreen(app: app, language: language)
                .frame(width: side, height: side)
                .scaleEffect(rect.width / side)
                .frame(width: rect.width, height: rect.height)
                .opacity(Double(appAlpha))
        }
        .frame(width: rect.width, height: rect.height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: .black.opacity(0.2 + 0.2 * Double(MorphMath.unit(progress))), radius: 5 + 16 * MorphMath.unit(progress), y: 3 + 9 * MorphMath.unit(progress))
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture().onEnded { tap in
                if progress < 0.5 {
                    onOpen(selected)
                } else if tap.location.y > rect.height - 60 {
                    onHome()
                }
            }
        )
        .position(x: rect.midX, y: rect.midY)
    }
}

/// A resizable app icon: gradient plate plus a symbol that scales with its frame.
private struct LaunchIconArt: View {
    let app: LaunchApp
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(colors: app.colors, startPoint: .top, endPoint: .bottom))
            .overlay {
                Image(systemName: app.symbol)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .scaleEffect(0.5)
            }
    }
}

/// The launched app's first screen, always laid out at full size and scaled into the flying rect.
private struct LaunchAppScreen: View {
    let app: LaunchApp
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(app.name, language)
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(app.colors[0])
            }
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: app.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 112)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: app.symbol)
                            .font(.system(size: 30, weight: .semibold))
                        Capsule().fill(.white.opacity(0.85)).frame(width: 120, height: 9)
                        Capsule().fill(.white.opacity(0.5)).frame(width: 76, height: 9)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                }
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(app.colors[row % 2].opacity(0.22))
                        .frame(width: 38, height: 38)
                    PlaceholderLines(count: 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(Color.primary.opacity(0.85))
                .frame(width: 108, height: 5)
                .padding(.bottom, 8)
        }
    }
}

private struct LaunchWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x10194F), Color(hex: 0x3D4FD0), Color(hex: 0x8EC5F5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [Color(hex: 0xFF9ED8).opacity(0.5), .clear], center: UnitPoint(x: 0.9, y: 0.15), startRadius: 0, endRadius: 210)
            RadialGradient(colors: [Color(hex: 0x6BFFE1).opacity(0.3), .clear], center: UnitPoint(x: 0.1, y: 0.95), startRadius: 0, endRadius: 220)
        }
    }
}
