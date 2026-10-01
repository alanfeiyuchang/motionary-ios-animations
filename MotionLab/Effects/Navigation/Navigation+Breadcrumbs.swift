import SwiftUI

extension Effect {
    static let navigationBreadcrumbs = Effect(
        id: "navigation.breadcrumbs",
        category: .navigation,
        interaction: .tap,
        name: L("Folding Breadcrumbs", "折叠面包屑"),
        summary: L(
            "Each level you open unfolds a new crumb at the end of the trail; older ones fold into an ellipsis, and tapping a crumb folds the rest away one by one.",
            "每进入一层，路径末尾就展开一枚新的面包屑；更早的层级折进省略号，点击某一枚则把它后面的逐个折叠收走。"
        ),
        prompt: L(
            "A 44 pt breadcrumb bar above a folder list. Opening a folder appends a crumb that unfolds from its leading chevron like a paper flap (rotating 82° → 0° about its left edge while its width opens from 40%) on a spring (response 0.4 s, damping 0.78), and the tinted pill marking the current level slides onto it. Only three crumbs fit: when a fourth arrives, the middle ones fold shut toward the left and are swallowed by an ellipsis chip, which pops to 125% and settles each time it takes one in. Tapping any crumb pops back: the crumbs after it fold away from the right, 70 ms apart, the swallowed ones unfold out of the ellipsis as room returns, and the pill travels back with them. The list beneath slides in 40 pt from the travel direction, rows 40 ms apart.",
            "文件夹列表上方是一条 44 pt 高的面包屑栏。进入文件夹时，末尾追加的面包屑像纸片一样从箭头处展开（绕左缘从 82° 转到 0°，宽度由 40% 打开），使用弹簧（响应 0.4 秒、阻尼 0.78），标记当前层级的着色胶囊滑到它身上。栏内只放三枚：第四枚到来时，中间的向左折叠合拢，被一枚省略号吞进去，省略号每吞一枚就鼓到 125% 再回落。点击任意一枚即可返回：它后面的面包屑从右往左相隔 70 毫秒依次折叠收走，被吞掉的层级又从省略号里展开，胶囊随之退回。"
        ),
        implementation: L(
            "The trail is derived from the path array as identifiable items (crumbs plus one ellipsis) in an HStack; a custom Transition folds a crumb about its leading edge with rotation3DEffect and a horizontal scale, the current pill is a matchedGeometryEffect shape, and a multi-level pop removes one element per tick.",
            "路径数组被换算成一组可标识的条目（面包屑加一枚省略号）放进 HStack；自定义 Transition 用 rotation3DEffect 与横向缩放让面包屑绕左缘折叠，当前层级的胶囊是 matchedGeometryEffect 形状，多级返回时每个节拍移除一个元素。"
        ),
        apis: ["Transition", "rotation3DEffect", "matchedGeometryEffect", "keyframeAnimator", "ForEach(id:)", "spring(response:dampingFraction:)"],
        tags: ["breadcrumb", "path", "hierarchy", "collapse", "面包屑", "路径", "层级", "折叠"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.8, default: 0.4, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.78),
            .slider("visible", L("Visible crumbs", "可见层级数"), 2...4, default: 3, step: 1, decimals: 0),
            .slider("stagger", L("Fold stagger", "折叠间隔"), 0.02...0.15, default: 0.07, unit: "s"),
        ]
    ) { ctx in
        BreadcrumbsDemo(ctx: ctx)
    }
}

private struct Crumb: Identifiable, Equatable {
    let depth: Int
    let title: LocalizedText

    var id: Int { depth }
}

private enum CrumbItem: Identifiable {
    case crumb(Crumb)
    case ellipsis(hidden: Int)

    var id: String {
        switch self {
        case .crumb(let crumb): return "crumb-\(crumb.depth)"
        case .ellipsis: return "ellipsis"
        }
    }
}

private struct CrumbEntry {
    let symbol: String
    let title: LocalizedText
    let detail: LocalizedText
}

/// What each depth lists. Depths 0–3 hold folders (tapping one goes deeper); depth 4 holds files.
private let crumbLevels: [[CrumbEntry]] = [
    [
        CrumbEntry(symbol: "folder.fill", title: L("Projects", "项目"), detail: L("12 items", "12 项")),
        CrumbEntry(symbol: "folder.fill", title: L("Photos", "照片"), detail: L("248 items", "248 项")),
        CrumbEntry(symbol: "folder.fill", title: L("Music", "音乐"), detail: L("36 items", "36 项")),
    ],
    [
        CrumbEntry(symbol: "folder.fill", title: L("Motionary", "Motionary"), detail: L("8 items", "8 项")),
        CrumbEntry(symbol: "folder.fill", title: L("Sketches", "草图"), detail: L("31 items", "31 项")),
        CrumbEntry(symbol: "folder.fill", title: L("Archive", "归档"), detail: L("5 items", "5 项")),
    ],
    [
        CrumbEntry(symbol: "folder.fill", title: L("Assets", "素材"), detail: L("4 items", "4 项")),
        CrumbEntry(symbol: "folder.fill", title: L("Sources", "源码"), detail: L("96 items", "96 项")),
        CrumbEntry(symbol: "folder.fill", title: L("Exports", "导出"), detail: L("7 items", "7 项")),
    ],
    [
        CrumbEntry(symbol: "folder.fill", title: L("Icons", "图标"), detail: L("3 items", "3 项")),
        CrumbEntry(symbol: "folder.fill", title: L("Covers", "封面"), detail: L("9 items", "9 项")),
        CrumbEntry(symbol: "folder.fill", title: L("Clips", "片段"), detail: L("14 items", "14 项")),
    ],
    [
        CrumbEntry(symbol: "photo.fill", title: L("icon-light.png", "icon-light.png"), detail: L("84 KB", "84 KB")),
        CrumbEntry(symbol: "photo.fill", title: L("icon-dark.png", "icon-dark.png"), detail: L("91 KB", "91 KB")),
        CrumbEntry(symbol: "photo.fill", title: L("icon-tinted.png", "icon-tinted.png"), detail: L("77 KB", "77 KB")),
    ],
]

private let crumbRoot = Crumb(depth: 0, title: L("Home", "主页"))

/// Folds a crumb about its leading edge like a paper flap; the same motion unfolds a new one.
private struct CrumbFoldTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .rotation3DEffect(
                .degrees(phase.isIdentity ? 0 : 82),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.6
            )
            .scaleEffect(x: phase.isIdentity ? 1 : 0.4, y: 1, anchor: .leading)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

private struct BreadcrumbsDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var path: [Crumb]
    @State private var forward = true
    @State private var swallowed = 0
    @State private var popTask: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows a deep path, with the ellipsis.
        var seeded: [Crumb] = [crumbRoot]
        if ctx.isStill {
            for depth in 1...3 {
                seeded.append(Crumb(depth: depth, title: crumbLevels[depth - 1][0].title))
            }
        }
        _path = State(initialValue: seeded)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }
    private var maxDepth: Int { crumbLevels.count - 1 }

    /// Root, an ellipsis standing for the collapsed middle, then the last crumbs that fit.
    private var items: [CrumbItem] {
        let limit: Int = max(ctx.int("visible"), 2)
        guard path.count > limit else { return path.map { CrumbItem.crumb($0) } }
        let tail: [Crumb] = Array(path.suffix(limit - 1))
        let hidden: Int = path.count - limit
        return [.crumb(path[0]), .ellipsis(hidden: hidden)] + tail.map { CrumbItem.crumb($0) }
    }

    var body: some View {
        VStack(spacing: 12) {
            trail
            browser
            DemoHint(text: L("Open folders, then tap a crumb to go back", "打开文件夹，再点面包屑返回"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.0) { autoplayStep() }
        .onDisappear {
            popTask?.cancel()
            popTask = nil
        }
    }

    // MARK: Trail

    private var trail: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 0) {
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)
                    }
                    switch item {
                    case .crumb(let crumb):
                        crumbView(crumb)
                    case .ellipsis(let hidden):
                        ellipsisView(hidden: hidden)
                    }
                }
                .transition(CrumbFoldTransition())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: 304, height: 44)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Color.black.opacity(0.07), radius: 10, y: 5)
    }

    private func crumbView(_ crumb: Crumb) -> some View {
        let isCurrent: Bool = crumb.depth == path.count - 1
        return HStack(spacing: 5) {
            if crumb.depth == 0 {
                Image(systemName: "house.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            if crumb.depth > 0 || path.count == 1 {
                Text(crumb.title, ctx.language)
                    .font(.footnote.weight(isCurrent ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .foregroundStyle(isCurrent ? Color.adaptive(light: 0x4B57E0, dark: 0xA9B1FF) : Color.secondary)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background {
            if isCurrent {
                Capsule()
                    .fill(Palette.indigo.opacity(0.18))
                    .matchedGeometryEffect(id: "current", in: ns)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { pop(to: crumb.depth) }
    }

    private func ellipsisView(hidden: Int) -> some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 26)
            .background(Color.primary.opacity(0.08), in: Capsule())
            // It gulps each time it takes another level in.
            .keyframeAnimator(initialValue: CGFloat(1), trigger: swallowed) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    LinearKeyframe(1, duration: 0.1)
                    CubicKeyframe(1.25, duration: 0.12)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { pop(to: hidden) }
    }

    // MARK: Browser

    private var browser: some View {
        let depth: Int = path.count - 1
        let current: Crumb = path[depth]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(current.title, ctx.language)
                    .font(.title3.weight(.bold))
                    .id(depth)
                    .transition(.blurReplace)
                Spacer(minLength: 0)
                Text(verbatim: "\(depth + 1) / \(crumbLevels.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(depth)))
            }
            .padding(.horizontal, 6)
            ZStack {
                CrumbRows(
                    entries: crumbLevels[depth],
                    isLeaf: depth == maxDepth,
                    language: ctx.language,
                    direction: forward ? 1 : -1,
                    still: ctx.isStill,
                    onOpen: { push($0) }
                )
                .id(depth)
                .transition(.asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 0.97))))
            }
            .frame(height: 3 * 48 + 2 * 6)
        }
        .padding(12)
        .frame(width: 304)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Color.black.opacity(0.08), radius: 14, y: 8)
    }

    // MARK: Actions

    private func push(_ title: LocalizedText) {
        guard path.count <= maxDepth else { return }
        popTask?.cancel()
        if !ctx.isPreview { Haptics.tap(.light) }
        let limit: Int = max(ctx.int("visible"), 2)
        if path.count >= limit { swallowed += 1 }
        withAnimation(spring) {
            forward = true
            path.append(Crumb(depth: path.count, title: title))
        }
    }

    /// Pops back to `depth`, folding one crumb per beat from the right.
    private func pop(to depth: Int) {
        guard depth < path.count - 1, depth >= 0 else { return }
        popTask?.cancel()
        let stagger: Double = ctx["stagger"]
        let live: Bool = !ctx.isPreview && !Haptics.isMuted
        popTask = Task { @MainActor in
            while path.count - 1 > depth {
                if live { Haptics.selection() }
                withAnimation(spring) {
                    forward = false
                    path.removeLast()
                }
                try? await Task.sleep(for: .seconds(stagger))
                guard !Task.isCancelled else { return }
            }
        }
    }

    /// Preview loop: walk down to the deepest folder, then jump back to the root.
    private func autoplayStep() {
        if path.count <= maxDepth {
            push(crumbLevels[path.count - 1][0].title)
        } else {
            pop(to: 0)
        }
    }
}

// MARK: - Rows

private struct CrumbRows: View {
    let entries: [CrumbEntry]
    let isLeaf: Bool
    let language: AppLanguage
    let direction: CGFloat
    let onOpen: (LocalizedText) -> Void
    @State private var appeared: Bool

    init(
        entries: [CrumbEntry],
        isLeaf: Bool,
        language: AppLanguage,
        direction: CGFloat,
        still: Bool,
        onOpen: @escaping (LocalizedText) -> Void
    ) {
        self.entries = entries
        self.isLeaf = isLeaf
        self.language = language
        self.direction = direction
        self.onOpen = onOpen
        _appeared = State(initialValue: still)
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<entries.count, id: \.self) { index in
                row(entries[index])
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 40 * direction)
                    .animation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.03 + Double(index) * 0.04), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }

    private func row(_ entry: CrumbEntry) -> some View {
        let tint: Color = isLeaf ? Palette.pink : Palette.sky
        return HStack(spacing: 12) {
            Image(systemName: entry.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(entry.title, language)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(entry.detail, language)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if !isLeaf {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLeaf { onOpen(entry.title) }
        }
    }
}
