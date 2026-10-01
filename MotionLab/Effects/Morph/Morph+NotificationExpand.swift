import SwiftUI

extension Effect {
    static let morphNotificationExpand = Effect(
        id: "morph.notification-expand",
        category: .morph,
        interaction: .tap,
        name: L("Notification Expand", "通知展开"),
        summary: L(
            "A compact banner unfolds into a rich notification: its thumbnail grows into the photo and the actions rise in.",
            "紧凑的通知横幅展开为富通知：缩略图长成大图，操作按钮依次浮现。"
        ),
        prompt: L(
            "A lock screen with a frosted notification banner: a 38 pt app icon, sender, one line of text and a 38 pt photo thumbnail. Tapping it unfolds the banner into a rich notification on one spring (response 0.5 s, damping 0.8): the glass card grows downward, the message opens to three lines, and the thumbnail itself travels and widens into an 84 pt tall photo with 14 pt corners instead of cross-fading. Two action pills, Reply and Like, then rise 10 pt out of a blur, 60 ms apart. The notifications below are pushed down, shrink to 94% and dim to 45%, and the clock fades back, so the open one owns the screen. Tapping the wallpaper folds everything back into the banner. Calm, layered, unmistakably iOS.",
            "锁屏上一条磨砂通知横幅：38pt 应用图标、发件人、一行正文和 38pt 照片缩略图。点一下，横幅乘一条弹簧（响应 0.5 秒、阻尼 0.8）展开为富通知：玻璃卡片向下生长，正文展开到三行，缩略图本身飞到正文下方并拉宽成 84pt 高、14pt 圆角的大图，而不是交叉淡变。“回复”和“喜欢”两个操作胶囊随后从模糊中上浮 10pt，相隔 60 毫秒。下方的通知被推开，缩到 94%、淡到 45%，时钟一并退后，让展开的这条独占屏幕。点壁纸，一切收回横幅。沉稳、有层次，一眼就是 iOS。"
        ),
        implementation: L(
            "One glass card whose layout changes inside withAnimation, so its background resizes with the content; the compact thumbnail and the large photo are exclusive views sharing a matchedGeometryEffect id (applied before their frames), and the actions use a delayed appear modifier.",
            "同一张玻璃卡片在 withAnimation 中改变布局，背景随内容一起伸缩；紧凑缩略图与大图互斥显示并共享 matchedGeometryEffect ID（放在 frame 之前），操作按钮用带延迟的出现修饰符依次入场。"
        ),
        apis: ["matchedGeometryEffect", "@Namespace", "spring(response:dampingFraction:)", "lineLimit", "ultraThinMaterial"],
        tags: ["notification", "banner", "lock screen", "expand", "通知", "横幅", "锁屏", "展开"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.8),
            .slider("stagger", L("Action stagger", "按钮错峰"), 0...0.2, default: 0.06, unit: "s"),
            .toggle("recede", L("Recede other notifications", "其他通知后退"), default: true),
        ]
    ) { ctx in
        NotificationExpandDemo(ctx: ctx)
    }
}

private struct NotificationExpandDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var expanded: Bool
    @State private var liked = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        _expanded = State(initialValue: ctx.isStill)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        VStack(spacing: 10) {
            screen
            DemoHint(
                text: expanded ? L("Tap the wallpaper to collapse", "点击壁纸收起") : L("Tap the notification", "点击通知"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.9) { setExpanded(!expanded) }
    }

    private var screen: some View {
        let shape = RoundedRectangle(cornerRadius: 38, style: .continuous)
        let recede: Bool = expanded && ctx.bool("recede")
        return ZStack(alignment: .top) {
            NotifWallpaper()
                .contentShape(Rectangle())
                .onTapGesture { setExpanded(false) }
            VStack(spacing: 8) {
                clock
                    .opacity(expanded ? 0.55 : 1)
                    .scaleEffect(expanded ? 0.94 : 1)
                    .allowsHitTesting(false)
                mainCard
                ForEach(0..<2, id: \.self) { index in
                    NotifSibling(index: index, zh: zh)
                        .scaleEffect(recede ? 0.94 : 1, anchor: .top)
                        .opacity(recede ? 0.45 : 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
        }
        .frame(width: 316, height: 306, alignment: .top)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: Color(hex: 0x10243F).opacity(0.3), radius: 24, y: 14)
    }

    private var clock: some View {
        VStack(spacing: 0) {
            Text(verbatim: zh ? "9月30日 星期三" : "Wednesday, September 30")
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.8)
            Text(verbatim: "9:41")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .frame(height: 50)
    }

    private var mainCard: some View {
        let card = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                NotifAppIcon(symbol: "message.fill", colors: [Color(hex: 0x5BE584), Color(hex: 0x1FB855)])
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: zh ? "林一舟" : "Leo Park")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer(minLength: 4)
                        Text(verbatim: zh ? "现在" : "now")
                            .font(.system(size: 11))
                            .opacity(0.6)
                    }
                    Text(verbatim: zh
                        ? "山顶的日落太美了！刚拍到这张，云海正好被染成金色，你一定要看看。"
                        : "Sunset from the summit was unreal. Just caught this one as the clouds turned gold, you have to see it.")
                        .font(.system(size: 13))
                        .lineLimit(expanded ? 3 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(0.92)
                }
                if !expanded {
                    NotifMedia(cornerRadius: 8)
                        .matchedGeometryEffect(id: "media", in: ns)
                        .frame(width: 38, height: 38)
                }
            }
            if expanded {
                NotifMedia(cornerRadius: 14)
                    .matchedGeometryEffect(id: "media", in: ns)
                    .frame(height: 84)
                actions
            }
        }
        .padding(12)
        .foregroundStyle(.white)
        .background {
            DemoMaterial(card, material: .ultraThinMaterial, fallback: Color.white.opacity(0.22))
                .overlay(card.strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6))
                .shadow(color: .black.opacity(expanded ? 0.28 : 0.12), radius: expanded ? 22 : 10, y: expanded ? 12 : 5)
        }
        .environment(\.colorScheme, .dark)
        .contentShape(card)
        .onTapGesture { setExpanded(!expanded) }
    }

    private var actions: some View {
        let stagger: Double = ctx["stagger"]
        return HStack(spacing: 8) {
            NotifAction(symbol: "arrowshape.turn.up.left.fill", title: zh ? "回复" : "Reply", tint: .white)
                .modifier(MorphReveal(delay: 0.12, rise: 10))
            Button { toggleLike() } label: {
                NotifAction(symbol: liked ? "heart.fill" : "heart", title: zh ? "喜欢" : "Like", tint: liked ? Palette.pink : .white)
            }
            .buttonStyle(.plain)
            .modifier(MorphReveal(delay: 0.12 + stagger, rise: 10))
        }
        .transition(.opacity)
    }

    private func toggleLike() {
        if !ctx.isPreview { Haptics.tap() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { liked.toggle() }
    }

    private func setExpanded(_ value: Bool) {
        guard value != expanded else { return }
        if !ctx.isPreview { Haptics.tap(value ? .medium : .light) }
        withAnimation(spring) { expanded = value }
    }
}

private struct NotifAction: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
            Text(verbatim: title)
                .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(Color.white.opacity(0.16), in: Capsule())
        .contentShape(Capsule())
    }
}

private struct NotifAppIcon: View {
    let symbol: String
    let colors: [Color]

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .scaleEffect(0.52)
            }
    }
}

/// The attached photo: a dusk sky with a low sun and two ridgelines, drawn so it crops well at any size.
private struct NotifMedia: View {
    let cornerRadius: CGFloat

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x3B2A78), Color(hex: 0xE5567A), Color(hex: 0xFFB55A)]),
                    startPoint: CGPoint(x: size.width * 0.3, y: 0),
                    endPoint: CGPoint(x: size.width * 0.6, y: size.height)
                )
            )
            let sunRadius: CGFloat = min(size.width, size.height) * 0.2
            let sun = CGPoint(x: size.width * 0.64, y: size.height * 0.56)
            context.fill(
                Path(ellipseIn: CGRect(x: sun.x - sunRadius * 2.4, y: sun.y - sunRadius * 2.4, width: sunRadius * 4.8, height: sunRadius * 4.8)),
                with: .radialGradient(Gradient(colors: [Color.white.opacity(0.5), .clear]), center: sun, startRadius: 0, endRadius: sunRadius * 2.4)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: sun.x - sunRadius, y: sun.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)),
                with: .color(Color(hex: 0xFFE9B0))
            )
            context.fill(NotifMedia.ridge(size: size, base: 0.62, peaks: [0.18, 0.44, 0.3, 0.52, 0.36]), with: .color(Color(hex: 0x5A2D6E).opacity(0.85)))
            context.fill(NotifMedia.ridge(size: size, base: 0.78, peaks: [0.3, 0.14, 0.34, 0.2, 0.4]), with: .color(Color(hex: 0x24143F)))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private static func ridge(size: CGSize, base: CGFloat, peaks: [CGFloat]) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height * base))
        let step: CGFloat = size.width / CGFloat(peaks.count)
        for (index, peak) in peaks.enumerated() {
            let x0: CGFloat = CGFloat(index) * step
            let top = CGPoint(x: x0 + step * 0.5, y: size.height * (base - peak * 0.5))
            path.addQuadCurve(to: top, control: CGPoint(x: x0 + step * 0.3, y: top.y + 2))
            path.addQuadCurve(to: CGPoint(x: x0 + step, y: size.height * base), control: CGPoint(x: x0 + step * 0.7, y: top.y + 4))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }
}

private struct NotifSibling: View {
    let index: Int
    let zh: Bool

    var body: some View {
        let card = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let calendar: Bool = index == 0
        HStack(spacing: 10) {
            NotifAppIcon(
                symbol: calendar ? "calendar" : "envelope.fill",
                colors: calendar ? [Color(hex: 0xFF7A6B), Color(hex: 0xF0453A)] : [Color(hex: 0x5AB8FF), Color(hex: 0x2B7CF0)]
            )
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: calendar ? (zh ? "设计评审" : "Design review") : (zh ? "周报已发送" : "Weekly digest"))
                    .font(.system(size: 14, weight: .semibold))
                Text(verbatim: calendar ? (zh ? "15 分钟后 · 三楼会议室" : "In 15 min · Room 3A") : (zh ? "本周有 4 条新动态" : "4 new updates this week"))
                    .font(.system(size: 13))
                    .opacity(0.8)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .foregroundStyle(.white)
        .background {
            DemoMaterial(card, material: .ultraThinMaterial, fallback: Color.white.opacity(0.18))
                .overlay(card.strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6))
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
    }
}

private struct NotifWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0E2A47), Color(hex: 0x1F5E7A), Color(hex: 0x6FB4A8)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(colors: [Color(hex: 0xFFC58A).opacity(0.55), .clear], center: UnitPoint(x: 0.8, y: 0.95), startRadius: 0, endRadius: 230)
            RadialGradient(colors: [Color(hex: 0x7A6BFF).opacity(0.4), .clear], center: UnitPoint(x: 0.1, y: 0.15), startRadius: 0, endRadius: 200)
        }
    }
}
