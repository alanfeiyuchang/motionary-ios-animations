import SwiftUI

extension Effect {
    static let loadingSkeletonResolve = Effect(
        id: "loading.skeleton-resolve",
        category: .loading,
        interaction: .state,
        name: L("Staggered Skeleton Resolve", "骨架逐块显影"),
        summary: L("Each skeleton block hands over to its own piece of content, one after another, rising out of a blur.", "骨架屏的每一块依次交棒给各自的内容，从模糊中上浮显现。"),
        prompt: L(
            "An article card (296 pt wide) made of six blocks: hero image, avatar, byline, headline, body text, action row. While loading, every block is a rounded placeholder at 10% ink with a soft highlight sweeping left to right every 1.3 s. After 0.9 s the blocks resolve one by one, 120 ms apart, top to bottom: the placeholder fades and shrinks to 97% while the real content cross-fades in over it, rising 10 pt and clearing from a 6 pt blur on a spring (response 0.5 s, damping 0.8). Placeholders match the size of what replaces them, so nothing jumps. The order can also be text-first, with the image arriving last, as on a slow network. Tap the card to load it again. Calm, layered, perceptibly fast.",
            "一张 296 pt 宽的文章卡片由六块组成：头图、头像、署名、标题、正文、操作栏。加载中，每一块都是 10% 墨色的圆角占位块，一道柔和高光每 1.3 秒从左向右扫过。0.9 秒后各块自上而下依次显影，间隔 120 毫秒：占位块淡出并缩到 97%，真实内容在它上方交叉淡入，同时以弹簧（响应 0.5 秒、阻尼 0.8）上浮 10 pt、从 6 pt 模糊变清晰。占位块与替换它的内容尺寸一致，所以没有任何跳动。顺序也可以改为文字优先、图片最后到达，就像慢速网络下那样。点击卡片可重新加载。从容、有层次、感知上更快。"
        ),
        implementation: L(
            "Each block is a ZStack of placeholder and content driven by one Bool; an async task inserts block indices into a Set with a spring and a stagger sleep. The shimmer is a moving LinearGradient masked to each placeholder shape.",
            "每一块都是占位与内容叠放的 ZStack，由一个布尔值驱动；异步任务带着弹簧动画、按错峰间隔把块序号逐个放入 Set。微光是一条移动的 LinearGradient，以各占位形状为遮罩。"
        ),
        apis: ["withAnimation(.spring)", "Task.sleep(for:)", "blur(radius:)", "LinearGradient", "TimelineView"],
        tags: ["skeleton", "placeholder", "stagger", "content", "骨架屏", "占位", "错峰", "显影"],
        params: [
            .slider("stagger", L("Stagger", "错峰间隔"), 0.03...0.4, default: 0.12, unit: "s"),
            .slider("rise", L("Rise", "上浮距离"), 0...28, default: 10, decimals: 0, unit: "pt"),
            .slider("blur", L("Blur", "初始模糊"), 0...14, default: 6, decimals: 0, unit: "pt"),
            .choice("order", L("Order", "顺序"), [L("Top-down", "自上而下"), L("Text first", "文字优先"), L("Shuffled", "乱序")]),
        ]
    ) { ctx in
        SkeletonResolveDemo(ctx: ctx)
    }
}

private struct SkeletonResolveDemo: View {
    let ctx: DemoContext
    @State private var shown: Set<Int>
    @State private var task: Task<Void, Never>?

    private static let orders: [[Int]] = [
        [0, 1, 2, 3, 4, 5],
        [3, 2, 4, 1, 5, 0],
        [4, 0, 5, 2, 1, 3],
    ]

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills catch the card half resolved.
        _shown = State(initialValue: ctx.isStill ? [0, 1, 2] : [])
    }

    var body: some View {
        VStack(spacing: 14) {
            card
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .onTapGesture {
                    Haptics.tap()
                    play()
                }
            DemoHint(text: L("Tap the card to reload", "点击卡片重新加载"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.6, delay: 0.3) { play() }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func block<Content: View, Bones: View>(
        _ index: Int,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bones: () -> Bones
    ) -> some View {
        let visible: Bool = shown.contains(index)
        return ZStack(alignment: .topLeading) {
            bones()
                .opacity(visible ? 0 : 1)
                .scaleEffect(visible ? 0.97 : 1)
            content()
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : ctx.cg("rise"))
                .blur(radius: visible ? 0 : ctx.cg("blur"))
        }
    }

    private var card: some View {
        let zh = ctx.language == .zh
        return VStack(alignment: .leading, spacing: 10) {
            block(0) {
                ResolveHero(caption: zh ? "4 分钟" : "4 min")
                    .frame(height: 86)
            } bones: {
                ResolveBone(shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(height: 86)
            }
            HStack(spacing: 10) {
                block(1) {
                    Circle()
                        .fill(Palette.aurora)
                        .overlay(Text("LM").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white))
                        .frame(width: 36, height: 36)
                } bones: {
                    ResolveBone(shape: Circle()).frame(width: 36, height: 36)
                }
                block(2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(zh ? "林夏" : "Lena Morales")
                            .font(.subheadline.weight(.semibold))
                        Text(zh ? "2 小时前 · 里斯本" : "2 h ago · Lisbon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 36, alignment: .leading)
                } bones: {
                    VStack(alignment: .leading, spacing: 7) {
                        ResolveBone(shape: Capsule()).frame(width: 104, height: 11)
                        ResolveBone(shape: Capsule()).frame(width: 76, height: 9)
                    }
                    .frame(height: 36, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            block(3) {
                Text(zh ? "云海之上的日出山脊徒步" : "Sunrise ridge walk above the clouds")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            } bones: {
                ResolveBone(shape: Capsule())
                    .frame(width: 236, height: 14)
                    .frame(height: 22)
            }
            block(4) {
                Text(zh ? "六公里山路，一壶热咖啡，还有一年里最好的那束光。" : "Six kilometres, one thermos of coffee and the best light of the whole year.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
            } bones: {
                VStack(alignment: .leading, spacing: 9) {
                    ResolveBone(shape: Capsule()).frame(height: 9)
                    ResolveBone(shape: Capsule()).frame(width: 168, height: 9)
                }
                .frame(height: 36, alignment: .top)
                .padding(.top, 4)
            }
            block(5) {
                HStack(spacing: 14) {
                    Label("248", systemImage: "heart.fill")
                        .foregroundStyle(Palette.pink)
                    Label("32", systemImage: "bubble.left.fill")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(zh ? "阅读" : "Read")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 32)
                        .background(Palette.primaryStrong, in: Capsule())
                }
                .font(.footnote.weight(.semibold).monospacedDigit())
                .frame(height: 32)
            } bones: {
                HStack(spacing: 12) {
                    ResolveBone(shape: Capsule()).frame(width: 48, height: 14)
                    ResolveBone(shape: Capsule()).frame(width: 40, height: 14)
                    Spacer(minLength: 0)
                    ResolveBone(shape: Capsule()).frame(width: 72, height: 32)
                }
                .frame(height: 32)
            }
        }
        .padding(14)
        .frame(width: 296)
        .demoCard(cornerRadius: 24)
    }

    private func play() {
        task?.cancel()
        let order: [Int] = SkeletonResolveDemo.orders[min(max(ctx.int("order"), 0), 2)]
        let stagger: Double = max(ctx["stagger"], 0.01)
        let wasLoaded: Bool = !shown.isEmpty
        task = Task { @MainActor in
            if wasLoaded {
                withAnimation(.easeInOut(duration: 0.3)) { shown = [] }
                try? await Task.sleep(for: .seconds(0.3))
            }
            try? await Task.sleep(for: .seconds(0.9))
            for index in order {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { _ = shown.insert(index) }
                try? await Task.sleep(for: .seconds(stagger))
            }
        }
    }
}

/// A placeholder shape with a highlight sweeping across it.
private struct ResolveBone<S: Shape>: View {
    let shape: S
    @Environment(\.demoIsStill) private var isStill
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shape
            .fill(Color.primary.opacity(0.10))
            .overlay {
                if !isStill {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let seconds: Double = timeline.date.timeIntervalSinceReferenceDate
                        let u: Double = (seconds / 1.3).truncatingRemainder(dividingBy: 1)
                        let x: CGFloat = -0.6 + 2.2 * CGFloat(u)
                        let highlight: Color = colorScheme == .dark ? .white.opacity(0.10) : .white.opacity(0.65)
                        LinearGradient(
                            colors: [highlight.opacity(0), highlight, highlight.opacity(0)],
                            startPoint: UnitPoint(x: x - 0.4, y: 0.4),
                            endPoint: UnitPoint(x: x + 0.4, y: 0.6)
                        )
                    }
                    .mask(shape)
                }
            }
    }
}

/// The hero "photo": a dawn sky, a sun and two ridges.
private struct ResolveHero: View {
    let caption: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [Color(hex: 0x5B4BD6), Color(hex: 0xFF6B8B), Color(hex: 0xFFC36B)],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(Color(hex: 0xFFF1C2))
                .frame(width: 34, height: 34)
                .shadow(color: Color(hex: 0xFFE39A), radius: 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(x: 46, y: 6)
            ResolveRidge(peaks: [0.0, 0.55, 0.28, 0.7, 0.4, 0.62, 0.2])
                .fill(Color(hex: 0x3B2A7A).opacity(0.55))
            ResolveRidge(peaks: [0.25, 0.1, 0.42, 0.18, 0.5, 0.3, 0.46])
                .fill(Color(hex: 0x241A52).opacity(0.85))
            Label(caption, systemImage: "clock")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(.black.opacity(0.35), in: Capsule())
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ResolveRidge: Shape {
    /// Heights (0…1 of the rect) at evenly spaced points, left to right.
    let peaks: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard peaks.count > 1 else { return path }
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for (index, peak) in peaks.enumerated() {
            let x: CGFloat = rect.minX + rect.width * CGFloat(index) / CGFloat(peaks.count - 1)
            path.addLine(to: CGPoint(x: x, y: rect.maxY - rect.height * peak))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
