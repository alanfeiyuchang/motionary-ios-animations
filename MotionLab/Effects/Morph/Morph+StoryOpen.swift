import SwiftUI

extension Effect {
    static let morphStoryOpen = Effect(
        id: "morph.story-open",
        category: .morph,
        interaction: .gesture,
        name: L("Story Ring Open", "快拍圆环展开"),
        summary: L(
            "A ringed avatar blooms into a full-screen story with a running progress bar; drag it down and it shrinks back into its ring.",
            "带圆环的头像绽开成全屏快拍，进度条随即走动；向下拖，它又缩回自己的圆环。"
        ),
        prompt: L(
            "A row of 52 pt avatars inside gradient story rings above a feed. Tapping one grows the avatar itself into a full-screen story on a spring (response 0.5 s, damping 0.86): the circle's frame expands and its corner radius relaxes from a full circle to 30 pt, the avatar art cross-fades into the story during the first half, and the feed behind scales to 94%, blurs and darkens. Three segmented progress bars fill linearly, 2.5 s each; a tap skips to the next and the artwork pops. Dragging down scales the story toward 55%, follows the finger and lifts the dimming; past 90 pt it flies back into its ring on a spring with damping 0.82, landing with a small bounce, and the ring turns grey as seen.",
            "信息流上方是一排 52pt 头像，各自套着渐变快拍圆环。点一个，头像本身乘弹簧（响应 0.5 秒、阻尼 0.86）长成全屏快拍：圆形外框扩张，圆角从正圆放松到 30pt，头像画面在前半程交叉淡变为快拍内容，身后的信息流缩到 94%、变模糊并压暗。顶部三段进度条匀速填充，每段 2.5 秒；点一下跳到下一段，画面随之一弹。向下拖动时快拍跟手、最多缩到 55%，压暗随之减轻；拖过 90pt 松手，它乘阻尼 0.82 的弹簧飞回自己的圆环，落位轻轻回弹，圆环变灰表示已看过。"
        ),
        implementation: L(
            "An Animatable wrapper interpolates the open progress and the drag; each frame the story's rect is a lerp from the avatar's rect to the dragged, scaled screen rect, its content laid out at full size and aspect-fill scaled into it. A task runs the segments with linear animations; a down-only UIPanGestureRecognizer drives the dismissal.",
            "Animatable 包装器对展开进度与拖动位移做插值；每帧把快拍矩形从头像矩形插值到被拖动、缩放过的屏幕矩形，内容按全尺寸排版后以填充方式缩放进去。一个任务用线性动画依次播放各段；只接受下拉的 UIPanGestureRecognizer 驱动关闭。"
        ),
        apis: ["Animatable", "AnimatablePair", "UIGestureRecognizerRepresentable", "AngularGradient", "Task.sleep"],
        tags: ["story", "ring", "avatar", "drag to dismiss", "快拍", "限时动态", "圆环", "下拉关闭"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...1.0, default: 0.5, unit: "s"),
            .slider("damping", L("Return damping", "归位阻尼"), 0.5...1.0, default: 0.82),
            .slider("segment", L("Segment duration", "每段时长"), 1...5, default: 2.5, decimals: 1, unit: "s"),
            .slider("threshold", L("Dismiss distance", "关闭距离"), 40...200, default: 90, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        StoryOpenDemo(ctx: ctx)
    }
}

private struct StoryPerson {
    let name: LocalizedText
    let colors: [Color]
    let face: String
    let scenes: [String]
    let captions: [LocalizedText]
}

private let storyPeople: [StoryPerson] = [
    StoryPerson(
        name: L("maya", "知夏"), colors: [Color(hex: 0xFF8A5B), Color(hex: 0xE5407A)], face: "sun.max.fill",
        scenes: ["sun.horizon.fill", "beach.umbrella.fill", "sailboat.fill"],
        captions: [L("Golden hour", "黄金时刻"), L("Beach day", "海边的一天"), L("Out on the water", "出海")]
    ),
    StoryPerson(
        name: L("leo", "一舟"), colors: [Color(hex: 0x4FB4FF), Color(hex: 0x5B4FE8)], face: "mountain.2.fill",
        scenes: ["mountain.2.fill", "tent.fill", "moon.stars.fill"],
        captions: [L("Summit at last", "终于登顶"), L("Camp for the night", "今晚扎营"), L("So many stars", "漫天繁星")]
    ),
    StoryPerson(
        name: L("ava", "晚晴"), colors: [Color(hex: 0x34D9A8), Color(hex: 0x1F8FB8)], face: "leaf.fill",
        scenes: ["leaf.fill", "cup.and.saucer.fill", "book.fill"],
        captions: [L("Morning walk", "清晨散步"), L("Slow coffee", "慢慢喝一杯"), L("New chapter", "新的一章")]
    ),
    StoryPerson(
        name: L("noah", "牧野"), colors: [Color(hex: 0xB86BFF), Color(hex: 0xFF5FA2)], face: "music.note",
        scenes: ["guitars.fill", "music.mic", "sparkles"],
        captions: [L("Soundcheck", "试音"), L("On stage", "登台"), L("What a night", "难忘的夜晚")]
    ),
]

private enum StoryLayout {
    static let size = CGSize(width: 316, height: 308)
    static let avatar: CGFloat = 52

    static func ring(_ index: Int) -> CGPoint {
        CGPoint(x: 47 + CGFloat(index) * 74, y: 46)
    }
}

private struct StoryOpenDemo: View {
    let ctx: DemoContext
    @State private var selected: Int
    @State private var progress: Double
    @State private var drag: CGSize = .zero
    @State private var segment: Int
    /// Segments played so far, fractional: 1.4 = first done, second 40% through.
    @State private var played: Double
    @State private var seen: Set<Int> = []
    @State private var autoIndex = 0
    @State private var runTask: Task<Void, Never>?
    @State private var flingTask: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _selected = State(initialValue: 1)
        _progress = State(initialValue: ctx.isStill ? 1 : 0)
        _segment = State(initialValue: ctx.isStill ? 1 : 0)
        _played = State(initialValue: ctx.isStill ? 1.6 : 0)
    }

    private var isOpen: Bool { progress > 0.5 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        VStack(spacing: 10) {
            MorphAnimated(AnimatablePair(progress, drag.animatableData)) { value in
                StoryScene(
                    progress: CGFloat(value.first),
                    drag: CGSize(width: value.second.first, height: value.second.second),
                    selected: selected,
                    segment: segment,
                    played: played,
                    seen: seen,
                    language: ctx.language,
                    onOpen: open,
                    onTapStory: skip
                )
            }
            .frame(width: StoryLayout.size.width, height: StoryLayout.size.height)
            .clipShape(shape)
            // Only a downward drag engages (the page scroll waits for it), and only while a story is open.
            .gesture(PageSafePan(directions: .down, isEnabled: isOpen, onChanged: dismissChanged, onEnded: dismissEnded))
            DemoHint(
                text: isOpen ? L("Tap to skip, drag down to close", "点击跳到下一段，下拉关闭") : L("Tap a story ring", "点击一个圆环"),
                ctx: ctx
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.0) { autoStep() }
        .onDisappear {
            runTask?.cancel()
            flingTask?.cancel()
            runTask = nil
            flingTask = nil
        }
    }

    private func dismissChanged(_ t: CGSize) {
        flingTask?.cancel()
        flingTask = nil
        drag = CGSize(width: t.width, height: t.height > 0 ? t.height : rubberBand(t.height, limit: 20))
    }

    /// `nil` means the system cancelled the pan: settle back without judging a flick.
    private func dismissEnded(_ end: PageSafePanEnd?) {
        let threshold: CGFloat = ctx.cg("threshold")
        if let end, end.translation.height > threshold || end.predictedEndTranslation.height > threshold * 2.5 {
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
            segment = 0
            played = 0
            progress = 0
            drag = .zero
        }
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.86)) { progress = 1 }
        run(from: 0)
    }

    /// Plays the remaining segments one after another, then closes the story.
    private func run(from first: Int) {
        runTask?.cancel()
        let duration: Double = ctx["segment"]
        let count: Int = storyPeople[selected].scenes.count
        let preview: Bool = ctx.isPreview
        runTask = Task { @MainActor in
            // One frame for the reset to land, so the bar animates from empty rather than from its old value.
            try? await Task.sleep(for: .seconds(0.05))
            for index in first..<count {
                guard !Task.isCancelled else { return }
                if index != first {
                    if !preview { Haptics.selection() }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { segment = index }
                }
                withAnimation(.linear(duration: duration)) { played = Double(index + 1) }
                try? await Task.sleep(for: .seconds(duration))
            }
            guard !Task.isCancelled else { return }
            close()
        }
    }

    /// A tap on the story: finish the current segment at once and move on (or close after the last one).
    private func skip() {
        guard isOpen else { return }
        let next: Int = segment + 1
        if !ctx.isPreview { Haptics.selection() }
        guard next < storyPeople[selected].scenes.count else {
            close()
            return
        }
        withAnimation(.easeOut(duration: 0.12)) { played = Double(next) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { segment = next }
        run(from: next)
    }

    private func close() {
        guard isOpen else { return }
        runTask?.cancel()
        flingTask?.cancel()
        runTask = nil
        flingTask = nil
        if !ctx.isPreview { Haptics.tap(.soft) }
        seen.insert(selected)
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            progress = 0
            drag = .zero
        }
    }

    /// Autoplay stand-in for a finger: open the next story, then drag it down and let go.
    private func autoStep() {
        if isOpen {
            withAnimation(.easeOut(duration: 0.32)) { drag = CGSize(width: 26, height: 150) }
            flingTask?.cancel()
            flingTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.34))
                guard !Task.isCancelled else { return }
                close()
            }
        } else {
            if seen.count == storyPeople.count { seen.removeAll() }
            open(autoIndex % storyPeople.count)
            autoIndex += 1
        }
    }
}

private struct StoryScene: View {
    let progress: CGFloat
    let drag: CGSize
    let selected: Int
    let segment: Int
    let played: Double
    let seen: Set<Int>
    let language: AppLanguage
    let onOpen: (Int) -> Void
    let onTapStory: () -> Void

    var body: some View {
        let pull: CGFloat = MorphMath.unit(drag.height / 260)
        let depth: CGFloat = MorphMath.unit(progress) * (1 - pull)
        ZStack {
            StoryFeed(selected: selected, hideSelected: progress > 0.002, seen: seen, language: language, onOpen: onOpen)
                .scaleEffect(1 - 0.06 * depth)
                .blur(radius: 5 * depth)
            Color.black
                .opacity(0.6 * Double(depth))
                .allowsHitTesting(false)
            storyLayer(pull: pull)
        }
        .frame(width: StoryLayout.size.width, height: StoryLayout.size.height)
    }

    private func storyLayer(pull: CGFloat) -> some View {
        let size: CGSize = StoryLayout.size
        let scale: CGFloat = 1 - 0.45 * pull
        let cardCenter = CGPoint(x: size.width / 2 + drag.width * 0.7, y: size.height / 2 + drag.height * 0.8)
        let openRect: CGRect = MorphMath.rect(center: cardCenter, size: CGSize(width: size.width * scale, height: size.height * scale))
        let avatarRect: CGRect = MorphMath.rect(center: StoryLayout.ring(selected), size: CGSize(width: StoryLayout.avatar, height: StoryLayout.avatar))
        let rect: CGRect = MorphMath.lerp(avatarRect, openRect, progress)
        let radius: CGFloat = min(MorphMath.lerp(26, 30, MorphMath.unit(progress)), min(rect.width, rect.height) / 2)
        let fill: CGFloat = max(rect.width / size.width, rect.height / size.height)
        let person: StoryPerson = storyPeople[selected]
        return ZStack {
            StoryAvatarArt(person: person)
            StoryContent(person: person, segment: segment, played: played, language: language)
                .frame(width: size.width, height: size.height)
                .scaleEffect(fill)
                .frame(width: rect.width, height: rect.height)
                .opacity(Double(MorphMath.smooth(progress, 0.08, 0.5)))
        }
        .frame(width: rect.width, height: rect.height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: .black.opacity(0.35 * Double(MorphMath.unit(progress))), radius: 20, y: 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if progress > 0.5 { onTapStory() } else { onOpen(selected) }
        }
        .position(x: rect.midX, y: rect.midY)
    }
}

private struct StoryAvatarArt: View {
    let person: StoryPerson

    var body: some View {
        ZStack {
            LinearGradient(colors: person.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: person.face)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.95))
                .scaleEffect(0.46)
        }
    }
}

private struct StoryContent: View {
    let person: StoryPerson
    let segment: Int
    let played: Double
    let language: AppLanguage

    var body: some View {
        let index: Int = min(max(segment, 0), person.scenes.count - 1)
        ZStack {
            LinearGradient(colors: [person.colors[0], person.colors[1], Color.black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.35), .clear], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 180)
            Image(systemName: person.scenes[index])
                .font(.system(size: 88, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                .offset(y: -6)
                .id(index)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            VStack(alignment: .leading, spacing: 10) {
                bars
                HStack(spacing: 8) {
                    StoryAvatarArt(person: person)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                    Text(person.name, language)
                        .font(.system(size: 14, weight: .semibold))
                    Text(verbatim: language == .zh ? "2 小时前" : "2h")
                        .font(.system(size: 13))
                        .opacity(0.7)
                    Spacer()
                }
                Spacer()
                Text(person.captions[index], language)
                    .font(.system(size: 22, weight: .bold))
                    .id(index)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                HStack(spacing: 12) {
                    Text(verbatim: language == .zh ? "发送消息" : "Send message")
                        .font(.system(size: 14))
                        .opacity(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                    Image(systemName: "heart")
                        .font(.system(size: 22))
                    Image(systemName: "paperplane")
                        .font(.system(size: 21))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
    }

    private var bars: some View {
        HStack(spacing: 4) {
            ForEach(person.scenes.indices, id: \.self) { index in
                let amount: CGFloat = MorphMath.unit(CGFloat(played) - CGFloat(index))
                Capsule()
                    .fill(.white.opacity(0.35))
                    .overlay {
                        Rectangle()
                            .fill(.white)
                            .scaleEffect(x: amount, anchor: .leading)
                    }
                    .clipShape(Capsule())
                    .frame(height: 3)
            }
        }
    }
}

/// The feed behind: story rings on top, one post below.
private struct StoryFeed: View {
    let selected: Int
    let hideSelected: Bool
    let seen: Set<Int>
    let language: AppLanguage
    let onOpen: (Int) -> Void

    var body: some View {
        ZStack {
            ForEach(storyPeople.indices, id: \.self) { index in
                let center: CGPoint = StoryLayout.ring(index)
                ring(index)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpen(index) }
                    .position(x: center.x, y: center.y + 9)
            }
            post
                .frame(width: 300, height: 198)
                .position(x: StoryLayout.size.width / 2, y: 203)
        }
    }

    private func ring(_ index: Int) -> some View {
        let person: StoryPerson = storyPeople[index]
        let isSeen: Bool = seen.contains(index)
        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [Palette.amber, Palette.pink, Palette.violet, Palette.amber], center: .center),
                        lineWidth: 2.5
                    )
                    .opacity(isSeen ? 0 : 1)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1.5)
                    .opacity(isSeen ? 1 : 0)
                StoryAvatarArt(person: person)
                    .frame(width: StoryLayout.avatar, height: StoryLayout.avatar)
                    .clipShape(Circle())
                    .opacity(hideSelected && index == selected ? 0 : 1)
            }
            .frame(width: 62, height: 62)
            .animation(.easeOut(duration: 0.3), value: isSeen)
            Text(person.name, language)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSeen ? .secondary : .primary)
        }
    }

    private var post: some View {
        let card = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Palette.primary)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(Color.primary.opacity(0.22)).frame(width: 84, height: 8)
                    Capsule().fill(Color.primary.opacity(0.1)).frame(width: 52, height: 7)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Palette.indigo.opacity(0.85), Palette.sky.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.7))
                }
            HStack(spacing: 16) {
                Image(systemName: "heart")
                Image(systemName: "bubble.right")
                Image(systemName: "paperplane")
                Spacer()
                Image(systemName: "bookmark")
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.primary.opacity(0.75))
        }
        .padding(12)
        .background(Palette.elevated, in: card)
        .overlay(card.strokeBorder(Palette.stroke))
    }
}
