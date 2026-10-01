import SwiftUI

extension Effect {
    static let cardsFoldHalf = Effect(
        id: "cards.fold-half",
        category: .cards,
        interaction: .tap,
        name: L("Fold in Half", "对折翻面"),
        summary: L("A ticket folds shut along its middle crease, then opens the other way to show its back.", "票券沿中线对折合上，再朝另一侧打开，露出背面。"),
        prompt: L(
            "A 236×216 pt ticket with a horizontal crease across its middle. On tap the top half falls forward about the crease, accelerating like something dropped (0.42 s ease-in), and lands on the lower half: the packet squashes to 96% and rebounds, with a medium haptic. During the fall the half darkens as it tips over, its paper back comes into view past 90°, and it casts a growing shadow onto the half below. After 100 ms the lower half swings up from behind the crease on a spring (response 0.5 s, damping 0.6), starting edge-on and dark, brightening as it flattens, rocking a few degrees past flat before it settles. The card has turned itself inside out: both halves now show the back, and a faint crease line stays where the paper was folded.",
            "一张236×216 pt的票券，中间有一道横向折痕。点击后，上半张绕折痕向前倒下，像掉落的东西一样越来越快（0.42秒缓入），落在下半张上：整叠压到96%再回弹，并有一记中等触感。下落过程中，这半张随着翻倒逐渐变暗，过了90°露出纸背，并在下半张上投下越来越大的阴影。100毫秒后，下半张从折痕后方以弹簧（响应0.5秒、阻尼0.6）向上甩开，起初侧立而暗，展平时逐渐变亮，越过平面几度后才摆回停稳。卡片就这样把自己里外翻了过来：两半现在显示的都是背面，折过的地方留下一道淡淡的折痕。"
        ),
        implementation: L(
            "One animatable progress drives two panels hinged on the same line, each drawn with projectionEffect. Each panel shows the front content or the vertically mirrored back content, masked to its half and switched at 90°. A first eased animation runs the fall, a delayed spring runs the unfold.",
            "一个可动画进度值驱动共用同一条铰链线的两块面板，各自用 projectionEffect 绘制。每块面板显示正面内容或上下镜像的背面内容，遮罩到自己的那一半，并在90°时切换。先用一段缓入动画完成下落，再用延迟的弹簧完成展开。"
        ),
        apis: ["Animatable", "projectionEffect", "mask", "keyframeAnimator", "spring(response:dampingFraction:)"],
        tags: ["fold", "crease", "paper", "ticket", "对折", "折痕", "纸张", "票券"],
        params: [
            .slider("fall", L("Fold duration", "对折时长"), 0.25...0.9, default: 0.42, unit: "s"),
            .slider("response", L("Unfold response", "展开响应"), 0.3...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Unfold damping", "展开阻尼"), 0.4...1.0, default: 0.6),
            .slider("shade", L("Fold shading", "折叠明暗"), 0...1, default: 0.7),
        ]
    ) { ctx in
        CardsFoldDemo(ctx: ctx)
    }
}

private enum CardsFoldLayout {
    static let size = CGSize(width: 236, height: 216)
    static let half: CGFloat = 108
    static let depth: CGFloat = 720
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }
}

private struct CardsFoldDemo: View {
    let ctx: DemoContext
    /// Two units per flip: 0…1 the top half falls, 1…2 the lower half swings up behind it.
    @State private var progress: Double
    @State private var steps = 0
    @State private var thuds = 0
    @State private var busy = false
    @State private var script: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still catches the top half on its way down.
        _progress = State(initialValue: ctx.isStill ? 0.3 : 0)
    }

    var body: some View {
        VStack(spacing: 14) {
            CardsFoldCard(progress: progress, shade: ctx["shade"], language: ctx.language)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: thuds) { content, squash in
                    content.scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
                } keyframes: { _ in
                    CubicKeyframe(0.96, duration: 0.07)
                    SpringKeyframe(1, duration: 0.4, spring: Spring(response: 0.26, dampingRatio: 0.5))
                }
                .contentShape(Rectangle())
                .onTapGesture { fold() }
            DemoHint(text: L("Tap the ticket", "点击票券"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.4) { fold() }
        .onDisappear { script?.cancel() }
    }

    private func fold() {
        guard !busy else { return }
        busy = true
        let muted = Haptics.isMuted || ctx.isPreview
        if !muted { Haptics.tap(.light) }
        let fall = ctx["fall"]
        let response = ctx["response"]
        let base = Double(steps * 2)
        steps += 1
        withAnimation(.timingCurve(0.55, 0, 0.9, 0.55, duration: fall)) {
            progress = base + 1
        }
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(fall))
            guard !Task.isCancelled else { return }
            thuds += 1
            if !muted { Haptics.tap(.medium) }
            try? await Task.sleep(for: .seconds(0.1))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: response, dampingFraction: ctx["damping"])) {
                progress = base + 2
            }
            try? await Task.sleep(for: .seconds(response * 0.9))
            guard !Task.isCancelled else { return }
            busy = false
        }
    }
}

private struct CardsFoldCard: View, Animatable {
    var progress: Double
    let shade: Double
    let language: AppLanguage

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private var size: CGSize { CardsFoldLayout.size }
    private var half: CGFloat { CardsFoldLayout.half }
    private var eye: CGPoint { CGPoint(x: size.width / 2, y: half) }

    var body: some View {
        let cycle = (progress / 2).rounded(.down)
        let local = progress - cycle * 2
        // Every completed flip swaps which side is "inside".
        let showing = Int(cycle) % 2 == 0 ? 0 : 1
        let hidden = 1 - showing
        // The top half falls 0 → 180°; the lower half then rises from edge-on (90°) to flat (180°).
        let fall = CGFloat(min(local, 1)) * .pi
        let rise: CGFloat = local <= 1 ? 0 : .pi / 2 + CGFloat(local - 1) * .pi / 2
        ZStack {
            groundShadow(fall: fall, rise: rise)
            lower(front: showing, back: hidden, fall: fall, rise: rise)
            upper(front: showing, back: hidden, fall: fall)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The half that starts on top and falls forward onto the other one.
    private func upper(front: Int, back: Int, fall: CGFloat) -> some View {
        let showsBack = fall > .pi / 2
        let tip = Double(sin(fall))
        let dark: Double = showsBack ? 0 : 0.5 * shade * tip
        let lit: Double = showsBack ? 0.3 * shade * tip : 0
        let plane = CardsPlane3D.hingeX(lineY: half, angle: -fall)
        return CardsFoldSide(kind: showsBack ? back : front, mirrored: showsBack, language: language)
            .overlay(CardsFoldLayout.shape.fill(Color.black.opacity(dark)))
            .overlay(CardsFoldLayout.shape.fill(Color.white.opacity(lit)))
            .mask(alignment: .top) { Rectangle().frame(height: half) }
            .projectionEffect(plane.projection(eye: eye, depth: CardsFoldLayout.depth))
    }

    /// The half that stays put during the fall, then swings up behind the folded packet.
    private func lower(front: Int, back: Int, fall: CGFloat, rise: CGFloat) -> some View {
        let showsBack = rise > .pi / 2
        // While the top half falls it shades this one, darkest at the crease.
        let cast: Double = rise > 0 ? 0 : 0.5 * shade * Double(fall / .pi)
        // Edge-on it is in the packet's shadow; it brightens as it flattens.
        let turned = Double(((rise - .pi / 2) / (.pi / 2)).clamped(to: 0...1))
        let dark: Double = showsBack ? 0.55 * shade * (1 - turned) : 0
        let plane = CardsPlane3D.hingeX(lineY: half, angle: -rise)
        return CardsFoldSide(kind: showsBack ? back : front, mirrored: showsBack, language: language)
            .overlay {
                LinearGradient(colors: [Color.black.opacity(cast), Color.black.opacity(cast * 0.25)], startPoint: .center, endPoint: .bottom)
                    .clipShape(CardsFoldLayout.shape)
            }
            .overlay(CardsFoldLayout.shape.fill(Color.black.opacity(dark)))
            .mask(alignment: .bottom) { Rectangle().frame(height: half) }
            .projectionEffect(plane.projection(eye: eye, depth: CardsFoldLayout.depth))
            // Hidden behind the packet until it clears the crease.
            .opacity(rise > 0 && !showsBack ? 0 : 1)
    }

    /// A soft shadow under whatever part of the card is standing over the surface.
    private func groundShadow(fall: CGFloat, rise: CGFloat) -> some View {
        let top: CGFloat = rise > 0 ? max(-cos(rise), 0) : max(cos(fall), 0)
        let height = half * (1 + top)
        return CardsFoldLayout.shape
            .fill(Color.black)
            .frame(width: size.width * 0.92, height: height)
            .blur(radius: 14)
            .opacity(0.26)
            .frame(height: size.height, alignment: .bottom)
            .offset(y: 12)
    }
}

/// One side of the ticket, optionally mirrored top to bottom (a folded-over half shows its back upside down).
private struct CardsFoldSide: View {
    let kind: Int
    let mirrored: Bool
    let language: AppLanguage

    var body: some View {
        Group {
            if kind == 0 {
                CardsFoldFront(language: language)
            } else {
                CardsFoldBack(language: language)
            }
        }
        .overlay { crease }
        .clipShape(CardsFoldLayout.shape)
        .scaleEffect(x: 1, y: mirrored ? -1 : 1)
    }

    /// The fold line stays visible on the flat card.
    private var crease: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black.opacity(0.16)).frame(height: 0.8)
            Rectangle().fill(Color.white.opacity(0.22)).frame(height: 0.8)
        }
    }
}

private struct CardsFoldFront: View {
    let language: AppLanguage

    var body: some View {
        let size = CardsFoldLayout.size
        VStack(spacing: 0) {
            top
                .frame(height: CardsFoldLayout.half)
            bottom
                .frame(height: CardsFoldLayout.half)
        }
        .foregroundStyle(.white)
        .frame(width: size.width, height: size.height)
        .background {
            LinearGradient(colors: [Color(hex: 0xFF8A4C), Color(hex: 0xFF4F8B), Color(hex: 0x7A3FE0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 18)
                .frame(width: 170, height: 170)
                .offset(x: 56, y: -70)
        }
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "music.mic")
                    .font(.system(size: 12, weight: .bold))
                Text(L("LIVE · ONE NIGHT", "现场 · 仅此一夜"), language)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
            }
            .opacity(0.85)
            Spacer(minLength: 0)
            Text(L("Neon Nights", "霓虹之夜"), language)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottom: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Harbour Hall · Doors 19:30", "海港音乐厅 · 19:30 入场"), language)
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.9)
                .padding(.top, 10)
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                field(L("DATE", "日期"), "10.24")
                Spacer(minLength: 0)
                field(L("ROW", "排"), "F")
                Spacer(minLength: 0)
                field(L("SEAT", "座"), "18")
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field(_ label: LocalizedText, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label, language)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .opacity(0.75)
            Text(verbatim: value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }
}

private struct CardsFoldBack: View {
    let language: AppLanguage

    private let ink = Color(hex: 0x2A2630)

    var body: some View {
        let size = CardsFoldLayout.size
        VStack(spacing: 0) {
            top
                .frame(height: CardsFoldLayout.half)
            bottom
                .frame(height: CardsFoldLayout.half)
        }
        .foregroundStyle(ink)
        .frame(width: size.width, height: size.height)
        .background {
            LinearGradient(colors: [Color(hex: 0xFBF7EF), Color(hex: 0xEDE6D8)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var top: some View {
        HStack(spacing: 14) {
            CardsFoldCode()
                .frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 3) {
                Text(L("ADMIT ONE", "凭票入场"), language)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                Text(L("Scan at gate B", "请在 B 口扫码"), language)
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.6)
                Text(verbatim: "NN-1024-F18")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .opacity(0.6)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var bottom: some View {
        VStack(alignment: .leading, spacing: 9) {
            CardsFoldBarcode()
                .frame(height: 38)
            HStack {
                Text(L("Non-transferable", "不可转让"), language)
                Spacer(minLength: 0)
                Text(L("No re-entry", "离场后不可再入"), language)
            }
            .font(.system(size: 10, weight: .semibold))
            .opacity(0.55)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }
}

/// A QR-like block of modules (fixed pattern, not a real code).
private struct CardsFoldCode: View {
    var body: some View {
        Canvas { context, size in
            let cells = 11
            let cell = size.width / CGFloat(cells)
            var seed: UInt64 = 0x9E3779B97F4A7C15
            for row in 0..<cells {
                for column in 0..<cells {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let corner = (row < 3 || row > cells - 4) && (column < 3 || column > cells - 4) && !(row > cells - 4 && column > cells - 4)
                    let on = corner ? (row % (cells - 1) == 0 || column % (cells - 1) == 0 || row == 2 || column == 2 || row == cells - 3 || column == cells - 3 || (row == 1 && column == 1) || (row == 1 && column == cells - 2) || (row == cells - 2 && column == 1)) : (seed >> 33) % 5 < 2
                    if on {
                        let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell + 0.3, height: cell + 0.3)
                        context.fill(Path(rect), with: .color(Color(hex: 0x2A2630)))
                    }
                }
            }
        }
    }
}

private struct CardsFoldBarcode: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            var seed: UInt64 = 0x51F15EED
            while x < size.width {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let width = CGFloat(1 + (seed >> 40) % 3)
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let gap = CGFloat(1 + (seed >> 40) % 3)
                context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(Color(hex: 0x2A2630)))
                x += width + gap
            }
        }
    }
}
