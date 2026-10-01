import SwiftUI

extension Effect {
    static let morphAvatarProfile = Effect(
        id: "morph.avatar-profile",
        category: .morph,
        interaction: .tap,
        name: L("Avatar to Profile", "头像展开资料卡"),
        summary: L(
            "A contact row opens into a profile card: the avatar's colour floods the header, the name glides to the centre and the stats count up.",
            "联系人行展开为资料卡：头像的颜色铺成头图，名字滑到中央，数据滚动计数。"
        ),
        prompt: L(
            "A list of contact rows, each with a 44 pt gradient avatar, name and role. Tapping a row grows it into a full profile card (28 pt corners) on one spring (response 0.5 s, damping 0.82): the avatar's coloured disc swells into the 104 pt header band, its initials fly into a 72 pt medallion overlapping the band's lower edge, and the name and role glide from the left edge to the centre while growing. The other rows shrink to 95% and fade. About 200 ms in, three stats rise 50 ms apart and count up from zero over 0.9 s on an exponential ease-out, and a Follow pill fades up last; tapping it springs to Following with a tick. Closing folds every piece back into its row. Personal, fluid, confident.",
            "一列联系人，每行是 44pt 渐变头像、名字和职位。点一行，它乘一条弹簧（响应 0.5 秒、阻尼 0.82）长成完整资料卡（28pt 圆角）：头像的彩色圆片涨成 104pt 高的头图，姓名缩写飞进压在头图下沿的 72pt 圆章，名字和职位从左侧滑到中央并放大。其余行缩到 95% 并淡出。约 200 毫秒后，三项数据相隔 50 毫秒依次浮起，用 0.9 秒的指数缓出从 0 数到目标值，“关注”胶囊最后淡入；点它会弹成带对勾的“已关注”。关闭时每个元素都收回原来那一行。亲切、流畅、笃定。"
        ),
        implementation: L(
            "Row and card are exclusive views sharing matchedGeometryEffect ids for the surface, the avatar tint, the initials, the name and the role; the stats are an Animatable view whose number is driven by an eased 0→1 state after the card appears.",
            "列表行与资料卡互斥显示，底板、头像色块、姓名缩写、名字与职位各自共享 matchedGeometryEffect ID；数据是一个 Animatable 视图，卡片出现后由 0→1 的缓动状态驱动数字。"
        ),
        apis: ["matchedGeometryEffect", "Animatable", "UnevenRoundedRectangle", "timingCurve", "spring(response:dampingFraction:)"],
        tags: ["profile", "avatar", "contact", "count up", "头像", "资料卡", "联系人", "数字滚动"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .slider("count", L("Count-up duration", "计数时长"), 0.2...2.0, default: 0.9, unit: "s"),
        ]
    ) { ctx in
        AvatarProfileDemo(ctx: ctx)
    }
}

private struct ProfilePerson {
    let name: LocalizedText
    let role: LocalizedText
    let initials: LocalizedText
    let colors: [Color]
    let stats: [Int]
}

private let profilePeople: [ProfilePerson] = [
    ProfilePerson(name: L("Maya Chen", "陈知夏"), role: L("Product designer", "产品设计师"), initials: L("MC", "夏"), colors: [Palette.violet, Palette.pink], stats: [128, 2409, 312]),
    ProfilePerson(name: L("Leo Park", "林一舟"), role: L("iOS engineer", "iOS 工程师"), initials: L("LP", "舟"), colors: [Palette.sky, Palette.blue], stats: [86, 1730, 204]),
    ProfilePerson(name: L("Ava Stone", "苏晚晴"), role: L("Motion artist", "动效设计师"), initials: L("AS", "晴"), colors: [Palette.amber, Palette.coral], stats: [342, 9120, 518]),
    ProfilePerson(name: L("Noah Reed", "周牧野"), role: L("Illustrator", "插画师"), initials: L("NR", "野"), colors: [Palette.mint, Palette.green], stats: [57, 864, 149]),
]

private let profileStatNames: [LocalizedText] = [L("Posts", "作品"), L("Followers", "粉丝"), L("Following", "关注")]

private struct AvatarProfileDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var selected: Int?
    @State private var following = false
    /// Unmatched card content (stats, button) fades out ahead of the collapse, so it never floats outside the shrinking card.
    @State private var detail = true
    @State private var autoIndex = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        _selected = State(initialValue: ctx.isStill ? 0 : nil)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                list
                    .scaleEffect(selected == nil ? 1 : 0.95)
                    .opacity(selected == nil ? 1 : 0.4)
                if let index = selected {
                    ProfileCard(
                        person: profilePeople[index],
                        index: index,
                        ns: ns,
                        language: ctx.language,
                        countDuration: ctx["count"],
                        following: following,
                        detail: detail,
                        onFollow: toggleFollow,
                        onClose: close
                    )
                    .zIndex(2)
                }
            }
            .frame(width: 316, height: 300)
            DemoHint(
                text: selected == nil ? L("Tap a person", "点击一位联系人") : L("Tap the header to close", "点击头图关闭"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.1) { autoStep() }
    }

    private var list: some View {
        VStack(spacing: 8) {
            ForEach(profilePeople.indices, id: \.self) { index in
                if selected == index {
                    Color.clear.frame(height: 62)
                } else {
                    ProfileRow(person: profilePeople[index], index: index, ns: ns, language: ctx.language)
                        .onTapGesture { open(index) }
                }
            }
        }
    }

    private func autoStep() {
        if selected == nil {
            open(autoIndex % profilePeople.count)
            autoIndex += 1
        } else {
            close()
        }
    }

    private func open(_ index: Int) {
        guard selected == nil else { return }
        if !ctx.isPreview { Haptics.tap(.medium) }
        following = false
        detail = true
        withAnimation(spring) { selected = index }
    }

    private func close() {
        guard selected != nil, detail else { return }
        if !ctx.isPreview { Haptics.tap(.soft) }
        // A view that is being removed no longer updates, so the fade has to start a beat before the collapse.
        withAnimation(.easeOut(duration: 0.12)) { detail = false }
        let collapse: Animation = spring
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.06))
            withAnimation(collapse) { selected = nil }
        }
    }

    private func toggleFollow() {
        if !ctx.isPreview {
            if following { Haptics.tap() } else { Haptics.success() }
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) { following.toggle() }
    }
}

private struct ProfileRow: View {
    let person: ProfilePerson
    let index: Int
    let ns: Namespace.ID
    let language: AppLanguage

    var body: some View {
        let surface = RoundedRectangle(cornerRadius: 18, style: .continuous)
        HStack(spacing: 12) {
            ZStack {
                ProfileTint(colors: person.colors, top: 22, bottom: 22)
                    .matchedGeometryEffect(id: "tint\(index)", in: ns)
                Text(person.initials, language)
                    .font(.system(size: language == .zh ? 18 : 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .matchedGeometryEffect(id: "face\(index)", in: ns)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name, language)
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize()
                    .matchedGeometryEffect(id: "name\(index)", in: ns)
                Text(person.role, language)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .matchedGeometryEffect(id: "role\(index)", in: ns)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .background {
            surface
                .fill(Palette.elevated)
                .overlay(surface.strokeBorder(Palette.stroke))
                .shadow(color: .black.opacity(0.07), radius: 8, y: 4)
                .matchedGeometryEffect(id: "bg\(index)", in: ns)
        }
        .contentShape(Rectangle())
    }
}

private struct ProfileCard: View {
    let person: ProfilePerson
    let index: Int
    let ns: Namespace.ID
    let language: AppLanguage
    let countDuration: Double
    let following: Bool
    let detail: Bool
    let onFollow: () -> Void
    let onClose: () -> Void

    var body: some View {
        let surface = RoundedRectangle(cornerRadius: 28, style: .continuous)
        VStack(spacing: 0) {
            header
            VStack(spacing: 3) {
                Text(person.name, language)
                    .font(.system(size: 21, weight: .bold))
                    .fixedSize()
                    .matchedGeometryEffect(id: "name\(index)", in: ns)
                Text(person.role, language)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .matchedGeometryEffect(id: "role\(index)", in: ns)
            }
            .padding(.top, 44)
            ProfileStats(person: person, language: language, duration: countDuration)
                .padding(.top, 14)
                .opacity(detail ? 1 : 0)
            followButton
                .padding(.top, 14)
                .modifier(MorphReveal(delay: 0.36, rise: 10))
                .opacity(detail ? 1 : 0)
            Spacer(minLength: 0)
        }
        .frame(width: 316, height: 300, alignment: .top)
        .background {
            surface
                .fill(Palette.elevated)
                .overlay(surface.strokeBorder(Palette.stroke))
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                .matchedGeometryEffect(id: "bg\(index)", in: ns)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottom) {
            ProfileTint(colors: person.colors, top: 28, bottom: 0)
                .matchedGeometryEffect(id: "tint\(index)", in: ns)
                .overlay(alignment: .topLeading) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.22), in: Circle())
                        .padding(12)
                        .opacity(detail ? 1 : 0)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
            ZStack {
                Circle()
                    .fill(Palette.elevated)
                    .shadow(color: person.colors[1].opacity(0.35), radius: 12, y: 6)
                Circle()
                    .strokeBorder(LinearGradient(colors: person.colors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5)
                    .padding(4)
                Text(person.initials, language)
                    .font(.system(size: language == .zh ? 28 : 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: person.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .fixedSize()
                    .matchedGeometryEffect(id: "face\(index)", in: ns)
            }
            .frame(width: 72, height: 72)
            .offset(y: 36)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
        .frame(height: 104)
    }

    private var followButton: some View {
        Button(action: onFollow) {
            HStack(spacing: 6) {
                if following {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(verbatim: following ? (language == .zh ? "已关注" : "Following") : (language == .zh ? "关注" : "Follow"))
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.interpolate)
            }
            .foregroundStyle(following ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.white))
            .frame(width: following ? 150 : 132, height: 40)
            .background {
                ZStack {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: person.colors, startPoint: .leading, endPoint: .trailing))
                        .opacity(following ? 0 : 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileStats: View {
    let person: ProfilePerson
    let language: AppLanguage
    let duration: Double
    @State private var shown: Double = 0
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { column in
                VStack(spacing: 1) {
                    ProfileCount(value: Double(person.stats[column]) * (isStill ? 1 : shown))
                    Text(profileStatNames[column], language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .modifier(MorphReveal(delay: 0.2 + 0.05 * Double(column), rise: 10))
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            // Exponential ease-out: the digits race at first and crawl into the final value.
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: duration).delay(0.2)) { shown = 1 }
        }
    }
}

private struct ProfileCount: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(verbatim: ProfileCount.format(Int(value.rounded())))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
    }

    private static func format(_ number: Int) -> String {
        guard number >= 1000 else { return "\(number)" }
        let rest: Int = number % 1000
        let padded: String = rest < 10 ? "00\(rest)" : (rest < 100 ? "0\(rest)" : "\(rest)")
        return "\(number / 1000),\(padded)"
    }
}

/// The avatar disc and the header band are the same shape with different corner radii, so the frame morph never
/// passes through an ellipse.
private struct ProfileTint: View {
    let colors: [Color]
    let top: CGFloat
    let bottom: CGFloat

    var body: some View {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(topLeading: top, bottomLeading: bottom, bottomTrailing: bottom, topTrailing: top),
            style: .continuous
        )
        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
