import SwiftUI

extension Effect {
    static let cardsBookOpen = Effect(
        id: "cards.book-open",
        category: .cards,
        interaction: .tap,
        name: L("Book Open", "翻开书封"),
        summary: L("A hardcover opens on its spine: the cover swings over, loose pages follow, and the first page fades up.", "精装书沿书脊翻开：封面翻过去，几页纸跟着翻动，第一页内容随之浮现。"),
        prompt: L(
            "A closed hardcover (132×184 pt pages, cloth cover with gold foil) rests centred. On tap the cover rotates on its left spine from 0° to 179° with perspective, while the whole book slides right by half its width so the spread ends centred. Three loose pages trail the cover, each starting 9% of the progress later and landing 1.2° shy of the last, so the page block reads as real thickness. Every leaf darkens toward edge-on and swaps to its back face at 90°; the cover's foil catches a sheen mid-turn. The cast shadow sweeps off the right page as the chapter title, heading and text rise 10 pt and fade in, staggered. One heavy spring (response 0.9 s, damping 0.86) drives it all; dragging scrubs it.",
            "一本合上的精装书（书页132×184 pt，布面封皮配烫金）居中摆放。点击后封面绕左侧书脊带透视地从0°翻到179°，同时整本书向右平移半个书宽，摊开后恰好居中。三张散页紧随封面，每张比前一张晚9%的进度起翻、落点再少1.2°，书页的厚度由此显现。每一页越接近侧立越暗，过90°即换成背面；封面的烫金在翻转途中掠过一道光泽。投影从右页扫开，章节名、标题与正文依次上浮10 pt并淡入。全程由一条沉稳的弹簧（响应0.9秒、阻尼0.86）驱动，也可以直接拖动来翻。"
        ),
        implementation: L(
            "An Animatable view maps one progress value to every leaf's hinge angle (rotation3DEffect, anchor .leading); each leaf picks its front or mirrored back face at 90° and flips its zIndex there so the left pile stacks in reverse.",
            "Animatable 视图把同一个进度换算成每一页的铰链角度（rotation3DEffect，锚点 .leading）；每页在 90° 时切换正面或镜像后的背面，并同时翻转 zIndex，使左侧书页按相反顺序叠放。"
        ),
        apis: ["rotation3DEffect", "Animatable", "zIndex", "UnevenRoundedRectangle", "spring(response:dampingFraction:)"],
        tags: ["book", "cover", "page turn", "3D", "书本", "翻页", "封面", "铰链"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.4...1.4, default: 0.9, unit: "s"),
            .slider("pages", L("Loose pages", "散页数量"), 1...4, default: 3, step: 1, decimals: 0),
            .slider("perspective", L("Perspective", "透视强度"), 0.2...0.9, default: 0.35),
        ]
    ) { ctx in
        CardsBookDemo(ctx: ctx)
    }
}

private struct CardsBookDemo: View {
    let ctx: DemoContext
    @State private var progress: CGFloat
    @State private var isOpen: Bool
    @State private var dragStart: CGFloat?
    @State private var landing: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the open spread.
        _progress = State(initialValue: ctx.isStill ? 1 : 0)
        _isOpen = State(initialValue: ctx.isStill)
    }

    var body: some View {
        VStack(spacing: 20) {
            CardsBook(
                progress: progress,
                pages: max(ctx.int("pages"), 1),
                perspective: ctx.cg("perspective"),
                language: ctx.language
            )
            .frame(width: 300, height: 226)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            .pageSafeHorizontalDrag { value in
                if dragStart == nil {
                    dragStart = progress
                    landing?.cancel()
                }
                let start = dragStart ?? progress
                progress = (start - value.translation.width / 150).clamped(to: 0...1)
            } onEnded: { value in
                guard dragStart != nil else { return }
                dragStart = nil
                // A flick carries the cover over; a cancelled drag settles on the nearer side.
                let flick: CGFloat = value.map { -($0.predictedEndTranslation.width - $0.translation.width) / 150 } ?? 0
                settle(open: progress + flick > 0.5)
            }
            DemoHint(text: L("Tap the book, or drag the cover", "点击书本，或拖动封面"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6) { toggle() }
        .onDisappear { landing?.cancel() }
    }

    private func toggle() {
        guard dragStart == nil else { return }
        Haptics.tap(.soft)
        settle(open: !isOpen)
    }

    private func settle(open: Bool) {
        isOpen = open
        let response = ctx["response"]
        let muted = Haptics.isMuted || ctx.isPreview
        withAnimation(.spring(response: response, dampingFraction: 0.86)) {
            progress = open ? 1 : 0
        }
        landing?.cancel()
        landing = Task { @MainActor in
            // The cover lands on the table (or shuts) near the end of the spring.
            try? await Task.sleep(for: .seconds(response * 0.7))
            guard !Task.isCancelled, !muted else { return }
            Haptics.tap(open ? .light : .rigid)
        }
    }
}

private enum CardsBookLayout {
    static let page = CGSize(width: 132, height: 184)
    static let cover = CGSize(width: 138, height: 194)
    static let coverColors: [Color] = [Color(hex: 0x3A2E8C), Color(hex: 0x1C1846)]
    static let gold = LinearGradient(colors: [Color(hex: 0xF7E3A1), Color(hex: 0xC9A24B)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let paper = Color(hex: 0xFBF8F1)
    static let ink = Color(hex: 0x2A2530)

    static var pageShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 7, topTrailingRadius: 7, style: .continuous)
    }
    static var coverShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 10, topTrailingRadius: 10, style: .continuous)
    }
}

/// Animatable so each leaf's angle (and its face / stacking switch at 90°) is derived from the in-flight progress.
private struct CardsBook: View, Animatable {
    var progress: CGFloat
    let pages: Int
    let perspective: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = progress.clamped(to: 0...1)
        // Closed: the book is centred, so its spine sits half a cover to the left. Open: the spine is the centre.
        let spineX: CGFloat = -CardsBookLayout.cover.width / 2 * (1 - p)
        ZStack {
            backBoard
                .offset(x: spineX + CardsBookLayout.cover.width / 2)
            pageBlock(p)
                .offset(x: spineX + CardsBookLayout.page.width / 2)
            ForEach(0...pages, id: \.self) { index in
                leaf(index, p: p, spineX: spineX)
            }
        }
        .frame(width: 300, height: 226)
    }

    // MARK: Static right side

    private var backBoard: some View {
        CardsBookLayout.coverShape
            .fill(LinearGradient(colors: CardsBookLayout.coverColors, startPoint: .top, endPoint: .bottom))
            .frame(width: CardsBookLayout.cover.width, height: CardsBookLayout.cover.height)
            .shadow(color: .black.opacity(0.28), radius: 14, y: 10)
    }

    /// The page block under the loose leaves: stacked edges for thickness and the first page's content.
    private func pageBlock(_ p: CGFloat) -> some View {
        let size = CardsBookLayout.page
        return ZStack {
            ForEach(0..<3, id: \.self) { k in
                CardsBookLayout.pageShape
                    .fill(Color(hex: 0xE9E3D6))
                    .overlay(CardsBookLayout.pageShape.strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5))
                    .frame(width: size.width, height: size.height)
                    .offset(x: CGFloat(3 - k) * 1.2, y: CGFloat(3 - k) * 0.8)
            }
            CardsBookFirstPage(reveal: Double(p), language: language)
                .frame(width: size.width, height: size.height)
                .background(CardsBookLayout.paper)
                .overlay(alignment: .leading) { castShadow(p) }
                .clipShape(CardsBookLayout.pageShape)
        }
    }

    /// Shadow of the turning cover across the right page, plus the gutter that stays once open.
    private func castShadow(_ p: CGFloat) -> some View {
        let sweep = 0.34 * sin(Double(p) * .pi)
        return ZStack(alignment: .leading) {
            LinearGradient(colors: [Color.black.opacity(sweep), .clear], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [Color.black.opacity(0.16 * Double(p)), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 20)
        }
        .allowsHitTesting(false)
    }

    // MARK: Turning leaves (0 = cover, 1… = loose pages)

    private func leaf(_ index: Int, p: CGFloat, spineX: CGFloat) -> some View {
        // Each leaf starts 9 % later than the one above it and lands 1.2° shy of it.
        let lag: CGFloat = 0.09
        let span: CGFloat = 1 - lag * CGFloat(pages)
        let local = ((p - lag * CGFloat(index)) / span).clamped(to: 0...1)
        let angle: Double = Double(local) * (179 - Double(index) * 1.2)
        let flipped = angle > 90
        let edgeOn = sin(angle * .pi / 180)
        let size = index == 0 ? CardsBookLayout.cover : CardsBookLayout.page
        return CardsBookLeafFace(index: index, isLast: index == pages, flipped: flipped, edgeOn: edgeOn, language: language)
            .frame(width: size.width, height: size.height)
            .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: perspective)
            .offset(x: spineX + size.width / 2)
            // Right pile: the cover is on top. Left pile: the last page turned is on top.
            .zIndex(flipped ? Double(20 + index) : Double(10 - index))
    }
}

private struct CardsBookLeafFace: View {
    let index: Int
    let isLast: Bool
    let flipped: Bool
    /// 0 flat, 1 edge-on.
    let edgeOn: Double
    let language: AppLanguage

    var body: some View {
        if index == 0 {
            cover
        } else {
            page
        }
    }

    @ViewBuilder
    private var cover: some View {
        let shape = CardsBookLayout.coverShape
        if flipped {
            // Endpaper, mirrored so it reads the right way round after the turn.
            // The cloth turns in around the board, so a dark rim frames the pasted-down endpaper.
            ZStack {
                LinearGradient(colors: CardsBookLayout.coverColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                ZStack {
                    Color(hex: 0xEFE6D2)
                    CardsBookEndpaper()
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .padding(4)
            }
            .overlay(Color.black.opacity(0.3 * edgeOn))
            .clipShape(shape)
            .scaleEffect(x: -1)
        } else {
            CardsBookCoverArt(sheen: edgeOn, language: language)
                .overlay(Color.black.opacity(0.32 * edgeOn))
                .clipShape(shape)
        }
    }

    @ViewBuilder
    private var page: some View {
        let shape = CardsBookLayout.pageShape
        if flipped {
            CardsBookLeftPage(showsText: isLast, language: language)
                .background(CardsBookLayout.paper)
                .overlay(Color.black.opacity(0.26 * edgeOn))
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                .scaleEffect(x: -1)
        } else {
            CardsBookLayout.paper
                .overlay(Color.black.opacity(0.26 * edgeOn))
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
        }
    }
}

private struct CardsBookCoverArt: View {
    /// 0…1, peaks when the cover is edge-on: the foil catches the light mid-turn.
    let sheen: Double
    let language: AppLanguage

    var body: some View {
        ZStack {
            LinearGradient(colors: CardsBookLayout.coverColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            // Spine hinge groove.
            HStack(spacing: 0) {
                LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 11)
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1)
                Spacer(minLength: 0)
            }
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(CardsBookLayout.gold, lineWidth: 1)
                .padding(.leading, 22)
                .padding([.trailing, .vertical], 11)
                .opacity(0.85)
            title
                .padding(.leading, 12)
            LinearGradient(colors: [.clear, Color.white.opacity(0.5 * sheen), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .blendMode(.plusLighter)
        }
    }

    private var title: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 20, weight: .bold))
            Text(L("MOTION", "动效"), language)
                .font(.system(size: 19, weight: .bold, design: .serif))
                .tracking(language == .zh ? 8 : 3)
            Rectangle()
                .frame(width: 28, height: 1)
            Text(L("A Field Guide", "设计手记"), language)
                .font(.system(size: 10.5, weight: .medium, design: .serif))
                .tracking(1)
        }
        .foregroundStyle(CardsBookLayout.gold)
    }
}

private struct CardsBookEndpaper: View {
    var body: some View {
        VStack(spacing: 13) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 13) {
                    ForEach(0..<6, id: \.self) { column in
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(hex: 0xB8894A).opacity((row + column) % 2 == 0 ? 0.5 : 0.22))
                    }
                }
            }
        }
    }
}

/// The left page of the open spread (the back of a loose page): a short epigraph on the visible one.
private struct CardsBookLeftPage: View {
    let showsText: Bool
    let language: AppLanguage

    var body: some View {
        ZStack(alignment: .trailing) {
            if showsText {
                VStack(spacing: 8) {
                    Text(L("“Nothing moves without a reason.”", "「没有无缘无故的运动。」"), language)
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .italic()
                        .multilineTextAlignment(.center)
                    Rectangle()
                        .frame(width: 18, height: 0.8)
                        .opacity(0.5)
                }
                .foregroundStyle(CardsBookLayout.ink.opacity(0.75))
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Gutter shadow on the spine side.
            LinearGradient(colors: [.clear, Color.black.opacity(0.14)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The first right-hand page; its three blocks rise and fade in one after another as the book opens.
private struct CardsBookFirstPage: View {
    let reveal: Double
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("CHAPTER ONE", "第一章"), language)
                .font(.system(size: 8.5, weight: .semibold, design: .serif))
                .tracking(1.6)
                .foregroundStyle(Color(hex: 0xB8894A))
                .modifier(CardsBookRise(amount: stage(0.42)))
            Text(L("Easing", "缓动"), language)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(CardsBookLayout.ink)
                .padding(.top, 5)
                .modifier(CardsBookRise(amount: stage(0.52)))
            PlaceholderLines(count: 6, color: CardsBookLayout.ink.opacity(0.16))
                .padding(.top, 14)
                .modifier(CardsBookRise(amount: stage(0.62)))
            Spacer(minLength: 0)
            Text(verbatim: "1")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundStyle(CardsBookLayout.ink.opacity(0.5))
                .frame(maxWidth: .infinity)
                .modifier(CardsBookRise(amount: stage(0.62)))
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 16)
    }

    /// 0…1 over 0.3 of the opening progress, starting at `start`.
    private func stage(_ start: Double) -> Double {
        ((reveal - start) / 0.3).clamped(to: 0...1)
    }
}

private struct CardsBookRise: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content
            .opacity(amount)
            .offset(y: (1 - amount) * 10)
    }
}
