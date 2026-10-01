import SwiftUI

// MARK: - Notch drop

extension Effect {
    static let feedbackNotchDrop = Effect(
        id: "feedback.notch-drop",
        category: .feedback,
        interaction: .tap,
        name: L("Island Drop Notification", "灵动岛滴落通知"),
        summary: L("A notification drips out of the Dynamic Island like a drop of ink, widens into a banner, and is swallowed back.", "通知像一滴墨水从灵动岛里滴落，展宽成横幅，最后又被吸回去。"),
        prompt: L(
            "A black 112 × 32 pt island sits at the top of a lock screen. When a message arrives, a black blob the size of the island separates from it and drops 62 pt on a spring (response 0.5 s, damping 0.68), still joined to the island by a liquid neck that thins and snaps as it falls. 90 ms into the drop the blob widens into a 268 × 62 pt banner with 22 pt corners, and the sender, message and app tile fade in out of a 6 pt blur with a light haptic on landing. After a 1.8 s hold the content fades in 0.12 s, the banner narrows back to island size and is pulled up into the island, which swells 8% and settles as it swallows it. Organic, system-grade, a little alive.",
            "锁屏顶部是一枚 112 × 32 pt 的黑色灵动岛。消息到来时，一团与它同样大小的黑色液滴从中分离，以弹簧（响应 0.5 秒、阻尼 0.68）下落 62 pt，下落途中仍由一段液态细颈与灵动岛相连，细颈越拉越细直至断开。下落开始 90 毫秒后，液滴展宽成 268 × 62 pt、圆角 22 pt 的横幅，发件人、消息与应用图标从 6 pt 模糊中淡入，落定时有轻触感。停留 1.8 秒后内容在 0.12 秒内淡出，横幅收窄回灵动岛大小并被向上吸回；灵动岛鼓起 8%，吞下后恢复原状。有机、系统级、带一点生命感。"
        ),
        implementation: L(
            "An Animatable view takes three spring-driven values (drop, widen, swell) and redraws a Canvas whose layer stacks alphaThreshold on blur: the island, the banner and a bridge strip that narrows with the drop fuse into one liquid shape. The text is ordinary SwiftUI laid over the banner's final frame.",
            "一个 Animatable 视图接收三个由弹簧驱动的值（下落、展宽、鼓起），重绘一张图层叠加了模糊与 alphaThreshold 的 Canvas：灵动岛、横幅和一条随下落变窄的桥接条融合成同一团液体。文字是覆盖在横幅最终位置上的普通 SwiftUI 视图。"
        ),
        apis: ["Canvas", "GraphicsContext.addFilter(.alphaThreshold)", "Animatable", "AnimatablePair", "spring(response:dampingFraction:)"],
        tags: ["dynamic island", "notification", "banner", "gooey", "metaball", "灵动岛", "通知", "横幅", "融球"],
        params: [
            .slider("hold", L("Hold time", "停留时长"), 0.8...4.0, default: 1.8, decimals: 1, unit: "s"),
            .slider("damping", L("Drop damping", "下落阻尼"), 0.45...1.0, default: 0.68),
            .slider("goo", L("Stickiness", "黏稠度"), 0...12, default: 7, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        NotchDropDemo(ctx: ctx)
    }
}

private struct NotchDropDemo: View {
    let ctx: DemoContext
    @State private var drop: CGFloat
    @State private var widen: CGFloat
    @State private var swell: CGFloat = 0
    @State private var content: Bool
    @State private var shown: Bool
    @State private var token = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Still thumbnails show the banner out.
        let out: Bool = ctx.isStill
        _drop = State(initialValue: out ? 1 : 0)
        _widen = State(initialValue: out ? 1 : 0)
        _content = State(initialValue: out)
        _shown = State(initialValue: out)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                NotchWallpaper(language: ctx.language)
                NotchGoo(drop: drop, widen: widen, swell: swell, goo: ctx.cg("goo"))
                    .frame(width: 300, height: 150)
                bannerContent
                    .frame(width: NotchMetrics.bannerSize.width, height: NotchMetrics.bannerSize.height)
                    .offset(y: NotchMetrics.bannerCentre - NotchMetrics.bannerSize.height / 2)
            }
            .frame(width: 300, height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            .contentShape(Rectangle())
            .onTapGesture { tap() }
            DemoHint(text: L("Tap the screen", "点击屏幕"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["hold"] + 2.4, delay: 0.6) { present() }
    }

    private var bannerContent: some View {
        let zh = ctx.language == .zh
        return HStack(spacing: 11) {
            Image(systemName: "message.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(colors: [Color(hex: 0x5FE37F), Color(hex: 0x1FB24A)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "Mia")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Text(zh ? "现在" : "now")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(zh ? "飞机落地了，十分钟后出口见" : "Just landed. See you at arrivals in 10")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 13)
        .opacity(content ? 1 : 0)
        .blur(radius: content ? 0 : 6)
        .scaleEffect(content ? 1 : 0.92)
        .allowsHitTesting(false)
    }

    // MARK: Sequence

    private func tap() {
        if shown { retract() } else { present() }
    }

    private func present() {
        guard !shown else { return }
        token += 1
        let current = token
        let damping: Double = ctx["damping"]
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        shown = true
        withAnimation(.spring(response: 0.5, dampingFraction: damping)) { drop = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: min(damping + 0.14, 1)).delay(0.09)) { widen = 1 }
        withAnimation(.easeOut(duration: 0.26).delay(0.3)) { content = true }
        let hold: Double = ctx["hold"]
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            guard token == current else { return }
            if buzz { Haptics.tap(.light) }
            try? await Task.sleep(for: .seconds(hold + 0.3))
            guard token == current else { return }
            retract()
        }
    }

    private func retract() {
        guard shown else { return }
        token += 1
        let current = token
        shown = false
        withAnimation(.easeIn(duration: 0.12)) { content = false }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.92).delay(0.08)) { widen = 0 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86).delay(0.16)) { drop = 0 }
        Task { @MainActor in
            // The island swallows the drop: a quick swell, then it settles.
            try? await Task.sleep(for: .seconds(0.4))
            guard token == current else { return }
            withAnimation(.easeOut(duration: 0.1)) { swell = 1 }
            try? await Task.sleep(for: .seconds(0.1))
            withAnimation(.spring(response: 0.38, dampingFraction: 0.5)) { swell = 0 }
        }
    }
}

private enum NotchMetrics {
    static let islandSize = CGSize(width: 112, height: 32)
    static let islandCentre: CGFloat = 28
    static let bannerSize = CGSize(width: 268, height: 62)
    static let bannerCentre: CGFloat = 90
}

/// The island, the banner and the neck between them, fused by blur + alpha threshold.
private struct NotchGoo: View, Animatable {
    var drop: CGFloat
    var widen: CGFloat
    var swell: CGFloat
    let goo: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(drop, AnimatablePair(widen, swell)) }
        set {
            drop = newValue.first
            widen = newValue.second.first
            swell = newValue.second.second
        }
    }

    var body: some View {
        let drop: CGFloat = self.drop
        let widen: CGFloat = min(max(self.widen, 0), 1.2)
        let swell: CGFloat = self.swell
        let goo: CGFloat = self.goo
        Canvas { context, size in
            let midX: CGFloat = size.width / 2
            let island = NotchMetrics.islandSize
            let banner = NotchMetrics.bannerSize
            let islandWidth: CGFloat = island.width * (1 + 0.08 * swell)
            let islandHeight: CGFloat = island.height * (1 + 0.1 * swell)
            let islandRect = CGRect(x: midX - islandWidth / 2, y: NotchMetrics.islandCentre - islandHeight / 2, width: islandWidth, height: islandHeight)
            let width: CGFloat = island.width + (banner.width - island.width) * widen
            let height: CGFloat = island.height + (banner.height - island.height) * widen
            let centre: CGFloat = NotchMetrics.islandCentre + (NotchMetrics.bannerCentre - NotchMetrics.islandCentre) * drop
            let bannerRect = CGRect(x: midX - width / 2, y: centre - height / 2, width: width, height: height)
            let radius: CGFloat = min(island.height / 2 + (22 - island.height / 2) * widen, height / 2)
            // The neck: wide while the drop is still close, gone before it lands.
            let neck: CGFloat = max(0, 1 - drop / 0.82)
            let neckWidth: CGFloat = 54 * neck * neck
            let neckRect = CGRect(x: midX - neckWidth / 2, y: NotchMetrics.islandCentre, width: neckWidth, height: max(centre - NotchMetrics.islandCentre, 0))
            if goo >= 0.5 {
                context.addFilter(.alphaThreshold(min: 0.5, color: .black))
                context.addFilter(.blur(radius: goo))
            }
            context.drawLayer { layer in
                layer.fill(Path(roundedRect: islandRect, cornerRadius: islandHeight / 2, style: .continuous), with: .color(.black))
                if neckWidth > 1 {
                    layer.fill(Path(neckRect), with: .color(.black))
                }
                layer.fill(Path(roundedRect: bannerRect, cornerRadius: radius, style: .continuous), with: .color(.black))
            }
        }
        .allowsHitTesting(false)
    }
}

/// A lock screen: wallpaper, time and date.
private struct NotchWallpaper: View {
    let language: AppLanguage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1D2671), Color(hex: 0x6B3FA0), Color(hex: 0xE0627A), Color(hex: 0xFFB36B)],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(Color(hex: 0xFFD9A0).opacity(0.55))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(x: 60, y: 110)
            Circle()
                .fill(Color(hex: 0x3A6BFF).opacity(0.45))
                .frame(width: 170, height: 170)
                .blur(radius: 50)
                .offset(x: -90, y: -40)
            VStack(spacing: 0) {
                Text(language == .zh ? "10月1日 星期四" : "Thursday, October 1")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(verbatim: "9:41")
                    .font(.system(size: 70, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.92))
            }
            .offset(y: 62)
            Capsule()
                .fill(Color.white.opacity(0.7))
                .frame(width: 110, height: 4)
                .offset(y: 125)
        }
        .frame(width: 300, height: 270)
    }
}
