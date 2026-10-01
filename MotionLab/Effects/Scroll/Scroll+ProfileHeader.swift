import SwiftUI

extension Effect {
    static let scrollProfileHeader = Effect(
        id: "scroll.profile-header",
        category: .scroll,
        interaction: .scroll,
        name: L("Profile Header Dock", "个人主页头部归位"),
        summary: L("The avatar shrinks and rides an arc into the nav bar, the name docks beside it and the cover blurs into the bar.", "头像缩小并沿弧线滑进导航栏，名字停靠在它旁边，封面图虚化成导航栏背景。"),
        prompt: L(
            "A profile page: a 120 pt cover image, a 68 pt avatar with a ring straddling its lower edge, then name, handle, a Follow button and three stats. The first 140 pt of scroll scrubs one continuous morph. The cover collapses to a 52 pt bar and blurs up to 12 pt under a 30% dark scrim; the avatar shrinks to 28 pt and travels up on an arc (vertical motion leads, horizontal eases in late) to sit beside the back chevron; the name scales to 73%, turns white and docks next to it; the handle and stats fade out within the first 40%, and the Follow button rises into the bar's trailing edge at 82%. Pulling down stretches and blurs the cover. Lifting mid-way settles in 0.35 s to the nearer state. One object, never a cut.",
            "个人主页：顶部是120 pt高的封面图，一枚带描边的68 pt头像骑在封面下沿，下面是名字、账号、关注按钮和三项数据。前140 pt的滚动连续驱动一整套形变：封面收成52 pt高的导航栏，逐渐模糊到12 pt并盖上30%的暗色遮罩；头像缩到28 pt，沿弧线上移（竖直先走，水平后段才加速），停到返回箭头旁；名字缩到73%、变白并停靠在头像右侧；账号与数据在前40%内淡出，关注按钮缩到82%升入导航栏右端。下拉时封面拉伸并虚化。半途松手，0.35秒内停到更近的状态。始终是同一个物体。"
        ),
        implementation: L(
            "onScrollGeometryChange publishes the offset; a 0…1 progress (with eased sub-ranges per element) interpolates every frame, size and opacity of an overlay drawn above the ScrollView. The cover is a blurred, clipped artwork whose height also grows with the overscroll.",
            "onScrollGeometryChange 发布偏移量；由 0…1 的进度（各元素使用不同的缓动子区间）插值计算 ScrollView 上方叠加层里每个元素的位置、尺寸和透明度。封面是经过模糊并裁剪的画面，高度还会随越界下拉增长。"
        ),
        apis: ["onScrollGeometryChange", "ScrollPosition", "onScrollPhaseChange", "blur(radius:)", "scaleEffect(_:anchor:)"],
        tags: ["profile", "header", "avatar", "cover", "nav bar", "个人主页", "头部", "头像", "封面", "导航栏"],
        params: [
            .slider("range", L("Collapse distance", "折叠距离"), 90...200, default: 140, step: 5, decimals: 0, unit: "pt"),
            .slider("blur", L("Cover blur", "封面模糊"), 0...20, default: 12, step: 1, decimals: 0, unit: "pt"),
            .toggle("snap", L("Snap to state", "自动吸附"), default: true),
        ]
    ) { ctx in
        ScrollProfileDemo(ctx: ctx)
    }
}

/// Height of the expanded header (cover, avatar, name, stats).
private let scrollProfileExpanded: CGFloat = 262
private let scrollProfileBar: CGFloat = 52
private let scrollProfileCover: CGFloat = 120

private struct ScrollProfileDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var down = false
    /// The finger's pull at the top edge (see `ScrollTopPull`).
    @State private var fingerPull: CGFloat = 0

    private var range: CGFloat { max(ctx.cg("range"), 1) }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Color.clear.frame(height: scrollProfileExpanded + fingerPull)
                ForEach(0..<14, id: \.self) { i in
                    ScrollKitRow(index: i + 1, language: ctx.language)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        }, action: { _, newValue in
            offset = newValue
        })
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .idle { snapIfNeeded() }
        }
        .overlay(alignment: .top) {
            ScrollProfileHeader(
                progress: (offset / range).clamped(to: 0...1),
                scrolled: offset.clamped(to: 0...range),
                pull: max(-offset, 0) + fingerPull,
                blur: ctx.cg("blur"),
                // The detail stage keeps its Reset button in the top-trailing corner.
                dockInset: ctx.isPreview ? 14 : 56,
                language: ctx.language
            )
            // Decorative: drags on the header scroll the list.
            .allowsHitTesting(false)
        }
        .clipped()
        .modifier(ScrollTopPull(isEnabled: !ctx.isPreview && offset <= 0.5, pull: $fingerPull))
        .autoplay(ctx.isPreview, every: 2.3) {
            down.toggle()
            withAnimation(.smooth(duration: 1.5)) {
                position.scrollTo(y: down ? 300 : 0)
            }
        }
    }

    private func snapIfNeeded() {
        guard ctx.bool("snap"), offset > 0, offset < range else { return }
        withAnimation(.smooth(duration: 0.35)) {
            position.scrollTo(y: offset < range / 2 ? 0 : range)
        }
    }
}

private struct ScrollProfileHeader: View {
    /// 0 expanded … 1 docked.
    let progress: CGFloat
    /// Points scrolled inside the collapse range (the lower block rides up by this much).
    let scrolled: CGFloat
    /// Overscroll at the top.
    let pull: CGFloat
    let blur: CGFloat
    /// Trailing inset of the Follow button once it is docked in the bar.
    let dockInset: CGFloat
    let language: AppLanguage

    var body: some View {
        let p = progress
        // The lower block (handle, stats) leaves early; the button and name dock late.
        let early: CGFloat = ScrollMath.unit(p, 0, 0.4)
        let late: CGFloat = ScrollMath.smooth(ScrollMath.unit(p, 0.35, 1))
        ZStack(alignment: .topLeading) {
            cover(p)
            lower(early)
            name(p, late)
            avatar(p)
            follow(late)
            chevron(late)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: ScrollMath.lerp(scrollProfileExpanded, scrollProfileBar, p) + pull, alignment: .top)
    }

    private func cover(_ p: CGFloat) -> some View {
        let height: CGFloat = ScrollMath.lerp(scrollProfileCover, scrollProfileBar, p) + pull
        let radius: CGFloat = blur * max(p, min(pull / 90, 1) * 0.7)
        return ScrollProfileCoverArt()
            // Blurring first and clipping after keeps the edges solid.
            .scaleEffect(1.12 + pull / 300)
            .blur(radius: radius)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .overlay(Color.black.opacity(0.3 * Double(p)))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.14 * Double(p)))
                    .frame(height: 0.5)
            }
    }

    private func avatar(_ p: CGFloat) -> some View {
        let size: CGFloat = ScrollMath.lerp(68, 28, p)
        // Arc: the vertical travel leads, the horizontal one eases in late.
        let x: CGFloat = ScrollMath.lerp(16, 44, p * p)
        let y: CGFloat = ScrollMath.lerp(scrollProfileCover - 34, 12, ScrollMath.smooth(p)) + pull
        return Circle()
            .fill(LinearGradient(colors: [Palette.amber, Palette.coral, Palette.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .strokeBorder(Palette.stage, lineWidth: ScrollMath.lerp(3.5, 0, p))
                    .padding(-ScrollMath.lerp(3.5, 0, p))
            }
            .shadow(color: .black.opacity(0.18 * Double(1 - p)), radius: 8, y: 4)
            .offset(x: x, y: y)
    }

    private func name(_ p: CGFloat, _ late: CGFloat) -> some View {
        // The name steps aside early, before it rises into the avatar's row.
        let x: CGFloat = ScrollMath.lerp(16, 80, ScrollMath.smooth(ScrollMath.unit(p, 0.1, 0.55)))
        let y: CGFloat = ScrollMath.lerp(scrollProfileCover + 42, 9, ScrollMath.smooth(p)) + pull * (1 - p)
        let title = Text(L("Mira Okafor", "林见夏"), language)
            .font(.system(size: 22, weight: .bold))
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                title.foregroundStyle(.primary).opacity(Double(1 - late))
                title.foregroundStyle(.white).opacity(Double(late))
            }
            .fixedSize()
            .scaleEffect(ScrollMath.lerp(1, 0.73, late), anchor: .topLeading)
            Text(L("128 posts", "128 条动态"), language)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize()
                .opacity(Double(ScrollMath.unit(p, 0.8, 1)))
                .offset(y: -8 + 6 * (1 - ScrollMath.unit(p, 0.8, 1)))
        }
        .offset(x: x, y: y)
    }

    /// Handle, bio line and stats: they ride up with the content and fade out early.
    private func lower(_ early: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("@mira · Motion designer in Lisbon", "@mira · 常驻里斯本的动效设计师"), language)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 18) {
                stat("128", L("Posts", "动态"))
                stat("24.6K", L("Followers", "粉丝"))
                stat("312", L("Following", "关注"))
            }
        }
        .padding(.horizontal, 16)
        .opacity(Double(1 - early))
        .offset(y: scrollProfileCover + 74 - scrolled + pull)
    }

    private func stat(_ value: String, _ label: LocalizedText) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: value)
                .font(.footnote.weight(.bold).monospacedDigit())
            Text(label, language)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func follow(_ late: CGFloat) -> some View {
        Text(L("Follow", "关注"), language)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Palette.primaryStrong, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25 * Double(late)), lineWidth: 1))
            .scaleEffect(ScrollMath.lerp(1, 0.82, late), anchor: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, ScrollMath.lerp(14, dockInset, late))
            .offset(y: ScrollMath.lerp(scrollProfileCover + 10, 9, late) + pull * (1 - late))
    }

    private func chevron(_ late: CGFloat) -> some View {
        Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .frame(width: 28, height: 28)
            .offset(x: 10, y: 12)
    }
}

/// The cover photo: a warm dusk gradient with soft light blobs (shapes only, no image assets).
private struct ScrollProfileCoverArt: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0x3B2A8C), Color(hex: 0xB0489A), Color(hex: 0xFF8A5B)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            ZStack {
                Circle()
                    .fill(Palette.amber.opacity(0.75))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                    .offset(x: 90, y: 30)
                Circle()
                    .fill(Palette.sky.opacity(0.5))
                    .frame(width: 150, height: 150)
                    .blur(radius: 36)
                    .offset(x: -110, y: -40)
                Circle()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 10)
                    .frame(width: 90, height: 90)
                    .offset(x: 120, y: -30)
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .offset(x: 40, y: -18)
            }
        }
    }
}
