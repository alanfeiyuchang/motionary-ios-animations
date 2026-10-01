import SwiftUI

extension Effect {
    static let showcaseXPLevel = Effect(
        id: "showcase.xp-level",
        category: .showcase,
        interaction: .tap,
        name: L("XP Level-Up", "经验值升级"),
        summary: L(
            "An XP bar that fills per reward; overflowing it flips the level number, bursts rays and sparkles, then resets under a shine and takes the remainder.",
            "每次奖励都让经验条前进；溢出时等级数字翻面，光芒与星屑迸发，经验条在一道高光中清空，再填入余量。"
        ),
        prompt: L(
            "A dark progression widget: a hexagonal orange badge with the level number, the rank title, an XP counter, a 16 pt capsule bar with a glossy orange fill and an add-XP pill. Tapping awards XP: a +XP chip floats up 26 pt and fades, the fill advances on a spring (response 0.55 s, damping 0.8) and the counter counts along every frame. If the gain overflows, the fill first runs to the end in 0.3 s; then the badge pops to 122%, the number flips around its horizontal axis (90° out in 0.15 s, swap, spring back from −90°), twelve rays shoot out to 1.6× and 20 sparkles burst, LEVEL UP slams in from 170% with a success haptic and the rank title pushes up. 0.45 s later a white shine sweeps the bar as it drains in 0.3 s, and the remainder fills on the same spring. Triumphant, game-like.",
            "深色成长组件：六边形橙色徽章里是等级，旁边是段位名称，下方是 16pt 高的橙色胶囊进度条、经验计数和按钮。点击：“+XP”标签上浮 26pt 淡出，填充以弹簧（响应 0.55 秒、阻尼 0.8）前进，计数逐帧跟随。若溢出，填充先用 0.3 秒冲到头；随后徽章弹到 122%，数字绕水平轴翻面（0.15 秒转出 90°，换数，再从 −90° 弹回），十二道光芒射到 1.6 倍，20 颗星屑迸发，“升级”从 170% 砸入并伴随成功触感。0.45 秒后白色高光扫过，进度条 0.3 秒内清空，余量按同一弹簧填入。像游戏通关。"
        ),
        implementation: L(
            "The bar and its counter are an Animatable view keyed on the XP value. A Task sequences the overflow: fill to the cap, bump triggers for keyframeAnimators (badge pop, rotation3DEffect flip, rays, slam text, shine sweep), swap the level mid-flip, drain, then spring to the remainder. Sparkles are a TimelineView + Canvas burst.",
            "进度条与计数是以经验值为 animatableData 的 Animatable 视图。一个 Task 编排溢出过程：先填满，再递增各个 keyframeAnimator 的触发值（徽章弹跳、rotation3DEffect 翻面、光芒、砸入文字、高光扫过），在翻面中途更换等级，清空，最后以弹簧填入余量。星屑是 TimelineView 加 Canvas 的一次迸发。"
        ),
        apis: ["Animatable", "keyframeAnimator", "rotation3DEffect", "TimelineView(.animation)", "Canvas", "transition(.push)"],
        tags: ["xp", "level up", "progress", "gamification", "reward", "经验值", "升级", "进度条", "游戏化", "奖励"],
        params: [
            .slider("gain", L("XP per tap", "每次经验"), 60...400, default: 210, step: 10, decimals: 0, unit: " XP"),
            .slider("response", L("Fill response", "填充响应"), 0.3...1.0, default: 0.55, unit: "s"),
            .slider("sparkles", L("Sparkles", "星屑数量"), 0...32, default: 20, step: 1, decimals: 0),
        ]
    ) { ctx in
        XPLevelDemo(ctx: ctx)
    }
}

private enum XPData {
    static let cap: Double = 500
    static let ranks: [LocalizedText] = [L("Trailblazer", "开路者"), L("Pathfinder", "寻径者"), L("Summiteer", "登顶者"), L("Legend", "传奇")]
}

private struct XPLevelDemo: View {
    let ctx: DemoContext
    @State private var xp: Double
    @State private var level = 7
    @State private var gains = 0
    @State private var flips = 0
    @State private var levelUps = 0
    @State private var shines = 0
    @State private var burst: Date?
    @State private var busy = false
    @State private var run: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _xp = State(initialValue: ctx.isStill ? 330 : 120)
    }

    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        StudioScene(hint: L("Tap to earn XP", "点击获得经验"), ctx: ctx) {
            card
                .sportCardTap { gain(user: true) }
        }
        .onDisappear { run?.cancel() }
        .autoplay(ctx.isPreview, every: 1.9, delay: 0.7) { gain(user: false) }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                badge
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: zh ? "当前段位" : "Current rank")
                        .signatureEyebrow()
                    ZStack(alignment: .leading) {
                        Text(XPData.ranks[(level + 1) % XPData.ranks.count], ctx.language)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .id(level)
                            .transition(.push(from: .bottom))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                    Text(verbatim: zh ? "第 \(level + 1) 级解锁新徽章" : "New badge at level \(level + 1)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Signature.textSecondary)
                        .contentTransition(.numericText(value: Double(level)))
                }
            }
            XPBar(xp: xp, zh: zh, shines: shines)
                .overlay(alignment: .topTrailing) { gainChip }
                .overlay { slam }
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text(verbatim: zh ? "完成任务 +\(Int(ctx["gain"])) XP" : "Complete quest +\(Int(ctx["gain"])) XP")
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Signature.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Capsule().fill(Signature.accentGradient))
            .shadow(color: Signature.accent.opacity(0.4), radius: 10, y: 4)
        }
        .padding(18)
        .frame(width: 292)
        .signatureCard()
    }

    // MARK: Badge

    private var badge: some View {
        ZStack {
            XPRays()
                .stroke(Signature.accentSoft, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 76, height: 76)
                .keyframeAnimator(initialValue: 0.0, trigger: levelUps) { content, p in
                    content
                        .scaleEffect(0.7 + 0.9 * p)
                        .opacity(p > 0 && p < 1 ? 1 - p : 0)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        MoveKeyframe(0.0)
                        CubicKeyframe(0.75, duration: 0.3)
                        CubicKeyframe(1.0, duration: 0.35)
                    }
                }
            XPHexagon()
                .fill(Signature.accentGradient)
                .overlay(XPHexagon().stroke(Color.white.opacity(0.35), lineWidth: 1.2))
                .overlay(XPHexagon().stroke(Signature.ink.opacity(0.25), lineWidth: 2).padding(7))
                .frame(width: 72, height: 72)
                .shadow(color: Signature.accent.opacity(0.55), radius: 12, y: 5)
            Text(verbatim: "\(level)")
                .font(Signature.number(30))
                .foregroundStyle(Signature.ink)
                .keyframeAnimator(initialValue: 0.0, trigger: flips) { content, angle in
                    content.rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(90, duration: 0.15)
                        MoveKeyframe(-90)
                        SpringKeyframe(0, duration: 0.5, spring: .init(response: 0.32, dampingRatio: 0.5))
                    }
                }
        }
        .frame(width: 72, height: 72)
        .overlay {
            StudioBurst(start: burst, count: ctx.int("sparkles"), reach: 96, preview: ctx.isPreview)
                .frame(width: 240, height: 240)
        }
        .keyframeAnimator(initialValue: 1.0, trigger: levelUps) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(1.22, duration: 0.14)
                SpringKeyframe(1.0, duration: 0.6, spring: .init(response: 0.35, dampingRatio: 0.45))
            }
        }
    }

    private var gainChip: some View {
        Text(verbatim: "+\(Int(ctx["gain"])) XP")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(Signature.lime)
            .keyframeAnimator(initialValue: XPFloat(), trigger: gains) { content, value in
                content
                    .offset(y: value.y)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    MoveKeyframe(0)
                    CubicKeyframe(-26, duration: 0.7)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: 0.35)
                    LinearKeyframe(0, duration: 0.35)
                }
            }
            .offset(y: -18)
            .allowsHitTesting(false)
    }

    private var slam: some View {
        Text(verbatim: zh ? "升级！" : "LEVEL UP")
            .font(.system(size: 20, weight: .black, design: .rounded))
            .tracking(zh ? 4 : 3)
            .foregroundStyle(Color.white)
            .shadow(color: Signature.accent, radius: 10)
            .keyframeAnimator(initialValue: XPSlam(), trigger: levelUps) { content, value in
                content
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(1.7)
                    SpringKeyframe(1.0, duration: 0.4, spring: .init(response: 0.28, dampingRatio: 0.55))
                    LinearKeyframe(1.0, duration: 0.45)
                    CubicKeyframe(0.9, duration: 0.2)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0)
                    LinearKeyframe(1, duration: 0.1)
                    LinearKeyframe(1, duration: 0.75)
                    LinearKeyframe(0, duration: 0.2)
                }
            }
            .offset(y: -8)
            .allowsHitTesting(false)
    }

    // MARK: Actions

    private func gain(user: Bool) {
        guard !busy else { return }
        if user { Haptics.tap(.light) }
        let amount = ctx["gain"]
        let response = ctx["response"]
        let total = xp + amount
        gains += 1
        guard total >= XPData.cap else {
            withAnimation(.spring(response: response, dampingFraction: 0.8)) { xp = total }
            return
        }
        busy = true
        withAnimation(.easeIn(duration: 0.3)) { xp = XPData.cap }
        run = Task { @MainActor in
            defer { busy = false }
            guard await studioPause(0.32) else { return }
            flips += 1
            levelUps += 1
            burst = Date()
            if user && !ctx.isPreview { Haptics.success() }
            guard await studioPause(0.15) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { level += 1 }
            guard await studioPause(0.3) else { return }
            shines += 1
            withAnimation(.easeInOut(duration: 0.3)) { xp = 0 }
            guard await studioPause(0.36) else { return }
            withAnimation(.spring(response: response, dampingFraction: 0.8)) { xp = min(total - XPData.cap, XPData.cap * 0.9) }
        }
    }
}

private struct XPFloat {
    var y: Double = 0
    var opacity: Double = 0
}

private struct XPSlam {
    var scale: Double = 1
    var opacity: Double = 0
}

/// The bar and its counter, recomputed every frame of the XP animation.
private struct XPBar: View, Animatable {
    var xp: Double
    let zh: Bool
    let shines: Int

    var animatableData: Double {
        get { xp }
        set { xp = newValue }
    }

    var body: some View {
        let share = (xp / XPData.cap).clamped(to: 0...1)
        VStack(spacing: 7) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.4))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    Capsule()
                        .fill(LinearGradient(colors: [Signature.accentHot, Signature.accent, Signature.accentSoft], startPoint: .leading, endPoint: .trailing))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Color.white.opacity(0.35))
                                .frame(height: 4)
                                .padding(.horizontal, 5)
                                .padding(.top, 2.5)
                        }
                        .frame(width: max(width * CGFloat(share), share > 0.001 ? 16 : 0))
                        .shadow(color: Signature.accent.opacity(0.6), radius: 6)
                    // The reset shine: a white band crossing the whole bar.
                    LinearGradient(colors: [.clear, Color.white.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 70)
                        .keyframeAnimator(initialValue: -0.4, trigger: shines) { content, position in
                            content.offset(x: width * CGFloat(position))
                        } keyframes: { _ in
                            KeyframeTrack(\.self) {
                                MoveKeyframe(1.1)
                                CubicKeyframe(-0.4, duration: 0.45)
                            }
                        }
                        .blendMode(.plusLighter)
                }
                .clipShape(Capsule())
            }
            .frame(height: 16)
            HStack {
                Text(verbatim: "\(Int(xp.rounded())) / \(Int(XPData.cap)) XP")
                    .foregroundStyle(Color.white)
                Spacer()
                Text(verbatim: zh ? "距升级还差 \(Int((XPData.cap - xp).rounded()))" : "\(Int((XPData.cap - xp).rounded())) to next level")
                    .foregroundStyle(Signature.textSecondary)
            }
            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
        }
    }
}

/// Pointy-top hexagon with softened corners.
private struct XPHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let corners = (0..<6).map { index -> CGPoint in
            let angle = Double(index) * .pi / 3 - .pi / 2
            return CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
        }
        var path = Path()
        let first = CGPoint(x: (corners[5].x + corners[0].x) / 2, y: (corners[5].y + corners[0].y) / 2)
        path.move(to: first)
        for index in 0..<6 {
            path.addArc(tangent1End: corners[index], tangent2End: corners[(index + 1) % 6], radius: radius * 0.16)
        }
        path.closeSubpath()
        return path
    }
}

/// Twelve short rays around the badge.
private struct XPRays: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        for index in 0..<12 {
            let angle = Double(index) / 12 * 2 * .pi
            let inner = outer * (index % 2 == 0 ? 0.72 : 0.82)
            path.move(to: CGPoint(x: center.x + inner * CGFloat(cos(angle)), y: center.y + inner * CGFloat(sin(angle))))
            path.addLine(to: CGPoint(x: center.x + outer * CGFloat(cos(angle)), y: center.y + outer * CGFloat(sin(angle))))
        }
        return path
    }
}
